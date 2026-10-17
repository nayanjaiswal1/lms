---
kind: lesson
id_key: git/capstone/course-review
course: git
section: capstone
section_title: "Capstone: Team Workflow"
section_position: 14
title: "Course Review: Flashcards for Spaced Recall"
position: 1
estimated_minutes: 12
source:
  - All sections of this course
---

## How to use this page

Cover the right column and answer each prompt out loud, then check. Mark the
ones you missed and come back to them tomorrow, in three days and in a week.
Spaced, effortful recall beats re-reading.

## Core model

| Prompt | Answer |
|---|---|
| What is a commit? | A full snapshot (root tree) + parent(s) + author/committer + message, named by its hash |
| What is a branch? | A movable ref (41-byte file) holding one commit hash |
| What is HEAD? | A pointer to the current branch (or directly to a commit when detached) |
| The three areas | Working tree -> index (staging) -> repository |
| Four object types | blob (content), tree (names), commit, annotated tag |
| Why does rewriting change hashes? | A hash covers content and parent hash, so any change ripples forward |
| `origin/main` is... | Your last-known snapshot of the server's main; moves only on fetch/pull/push |

## Everyday commands

| Prompt | Answer |
|---|---|
| See what the next commit will contain | `git diff --staged` |
| Stage part of a file | `git add -p` |
| Fix the last unpushed commit | `git commit --amend` |
| Untrack a committed file, keep it on disk | `git rm --cached <file>` (+ `.gitignore`) |
| Publish a new branch with tracking | `git push -u origin <branch>` |
| Download without integrating | `git fetch` |
| pull = | fetch + merge (or rebase) |
| Push rejected "fetch first" | Integrate (pull/rebase), then push. Never `--force` on shared branches |

## Branching, merging, rebasing

| Prompt | Answer |
|---|---|
| When is a merge a fast-forward? | When the current branch is an ancestor of the merged branch |
| `--no-ff` vs `--squash` | Always a merge commit vs one plain commit with no link to the branch |
| Conflict markers: top half is... | Ours = HEAD = the branch you are on (in a merge) |
| ours/theirs during a rebase | Flipped: ours = new base, theirs = your commit |
| Golden rule of rebase | Never rebase commits others have built on |
| squash vs fixup | Both meld; squash keeps the message, fixup drops it |
| Safe overwrite of a pushed branch | `git push --force-with-lease` (+ `--force-if-includes`) |
| Remember conflict resolutions | `git config rerere.enabled true` |

## Undo and recovery

| Prompt | Answer |
|---|---|
| Discard an uncommitted edit | `git restore <file>` (permanent) |
| Unstage | `git restore --staged <file>` |
| reset modes | soft: staged stays; mixed: edits stay unstaged; hard: everything goes |
| Undo a pushed commit | `git revert <hash>` (`-m 1` for merges) |
| Lost commits after reset/rebase | `git reflog`, then `reset --hard` or `branch` to the hash |
| Dropped stash | `git fsck --no-reflogs --unreachable`, then `git stash apply <hash>` |
| Copy one commit to another branch | `git cherry-pick -x <hash>` |
| Park unfinished work incl. new files | `git stash push -u -m "msg"` |
| What Git can never recover | Edits that were never staged or committed |

## Investigation

| Prompt | Answer |
|---|---|
| Who last changed line 10? | `git blame -L10,10 <file>` (`-w` reformat, `-C` moved code) |
| When was a string added/removed? | `git log -S '<string>'` |
| When did a line's value change? | `git log -G '<regex>'` |
| History across a rename | `git log --follow -- <file>` |
| Find the breaking commit | `git bisect start BAD GOOD` + `git bisect run <test>`; exit 0 good, 125 skip |

## Team practice and scale

| Prompt | Answer |
|---|---|
| GitHub flow in one line | Branch -> PR with review and CI -> merge -> deploy main |
| Release tag | `git tag -a v1.2.0 -m "..."`, then `git push origin v1.2.0` |
| SemVer | MAJOR breaking, MINOR features, PATCH fixes |
| Share hooks | Versioned folder + `core.hooksPath`; enforce for real in CI |
| SSH signing | `gpg.format ssh`, `user.signingKey`, `commit.gpgSign true` |
| Second checkout of the same repo | `git worktree add ../dir -b branch` |
| Submodule stores | `.gitmodules` URL + a gitlink commit hash |
| Huge repo, full history, fast clone | `git clone --filter=blob:none` (+ sparse-checkout) |
| Big binaries | Git LFS, set up before the first commit |
| Committed a secret | Rotate first, then `git filter-repo`, then prevent |

## Self-check

1. Explain to a friend, in three sentences, why `git reset --hard` is usually
   recoverable but `git restore <file>` is not.
2. Draw the graph before and after rebasing a two-commit branch onto a main that
   gained one commit.
3. Your team deploys main ten times a day. Which branching strategy and which
   merge settings would you propose, and why?
