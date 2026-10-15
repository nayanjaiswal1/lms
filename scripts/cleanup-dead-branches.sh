#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/cleanup-dead-branches.sh — Remove local branches and agent worktrees
# whose pull request was MERGED, which `git branch --merged` misses because the
# repo squash-merges.
#
# It also brings the default branch up to date (fast-forward only, never a merge).
#
# Usage: scripts/cleanup-dead-branches.sh [--apply] [--remote]
#   (default)  dry run: print what would be removed / pulled
#   --apply    actually delete and pull
#   --remote   also delete the matching origin branch (off in the cron job: turn on
#              "Automatically delete head branches" in the GitHub repo settings instead)
#
# A branch is dead only when ALL hold:
#   - a merged PR exists with that head branch AND its head commit is the branch's
#     tip (so a commit made after the merge is never thrown away)
#   - no open PR uses the branch
#   - it is not the default branch and not checked out in the main worktree
# A worktree is removed only when it is under .claude/worktrees, its branch is dead
# and it has no uncommitted changes. Needs `gh` logged in.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

apply="" remote=""
for a in "$@"; do
  case "$a" in
    --apply) apply=1 ;;
    --remote) remote=1 ;;
    *) echo "usage: $0 [--apply] [--remote]" >&2; exit 2 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"
command -v gh >/dev/null || { echo "cleanup: gh is required" >&2; exit 1; }
default="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)"
[[ -n "$default" ]] || { echo "cleanup: cannot read the default branch from GitHub" >&2; exit 1; }
current="$(git branch --show-current)"

# Fast-forward the default branch to origin. Checked out and clean: `git pull --ff-only`. Checked out with
# local changes: skipped (never touches the work). Not checked out: `git fetch origin default:default`, which
# refuses anything but a fast-forward.
pull_default() {
  git fetch -q --prune origin || { echo "pull: fetch failed, skipping" >&2; return 0; }
  local ahead; ahead="$(git rev-list --count "refs/heads/$default..refs/remotes/origin/$default" 2>/dev/null || echo 0)"
  [[ "$ahead" == "0" ]] && { echo "pull: $default is up to date"; return 0; }
  if [[ "$current" == "$default" ]]; then
    if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then echo "pull: $default has uncommitted changes, not pulling"; return 0; fi
    act git pull -q --ff-only origin "$default"
  else
    act git fetch -q origin "$default:$default"
  fi
}

act() { if [[ -n "$apply" ]]; then echo "running: $*"; "$@"; else echo "would run: $*"; fi; }

pull_default

# worktree path per branch
declare -A wt
while IFS= read -r line; do
  case "$line" in
    "worktree "*) path="${line#worktree }" ;;
    "branch refs/heads/"*) wt["${line#branch refs/heads/}"]="$path" ;;
  esac
done < <(git worktree list --porcelain)

merged_tip() { # merged PR head sha for a branch, empty if none
  gh pr list --state merged --head "$1" --json headRefOid -q '.[0].headRefOid // empty'
}
has_open_pr() { [[ -n "$(gh pr list --state open --head "$1" --json number -q '.[0].number // empty')" ]]; }

removed=0 kept=0
while IFS= read -r b; do
  [[ "$b" == "$default" || "$b" == "$current" ]] && continue
  tip="$(git rev-parse "refs/heads/$b")"
  m="$(merged_tip "$b")"
  if [[ -z "$m" ]]; then kept=$((kept+1)); continue; fi
  if has_open_pr "$b"; then echo "keep $b: has an open PR"; kept=$((kept+1)); continue; fi
  if [[ "$m" != "$tip" ]]; then echo "keep $b: has commits after its merged PR"; kept=$((kept+1)); continue; fi
  p="${wt[$b]:-}"
  if [[ -n "$p" ]]; then
    case "$p" in
      "$PWD"/.claude/worktrees/*) ;;
      *) echo "keep $b: checked out in $p"; kept=$((kept+1)); continue ;;
    esac
    if [[ -n "$(git -C "$p" status --porcelain)" ]]; then echo "keep $b: worktree $p has uncommitted changes"; kept=$((kept+1)); continue; fi
    act git worktree remove "$p"
  fi
  act git branch -D "$b"
  if [[ -n "$remote" ]] && [[ "$(git ls-remote --heads origin "$b" | cut -f1)" == "$tip" ]]; then
    act git push origin --delete "$b"
  fi
  removed=$((removed+1))
done < <(git for-each-ref --format='%(refname:short)' refs/heads)

# worktrees whose branch is already gone, and anything git no longer tracks
[[ -n "$apply" ]] && git worktree prune
if [[ -n "$apply" ]]; then verb=removed; else verb=found; fi
echo "cleanup: $removed dead branch(es) $verb, $kept kept"
