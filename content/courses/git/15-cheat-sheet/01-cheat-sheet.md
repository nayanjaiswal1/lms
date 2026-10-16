---
kind: lesson
id_key: git/cheat-sheet/lesson
course: git
section: cheat-sheet
section_title: "Cheat Sheet"
section_position: 15
title: One-Page Git Cheat Sheet
position: 0
estimated_minutes: 10
source:
  - Pro Git book (git-scm.com/book)
  - git-scm.com/docs command reference
---

> **Everything from the course, as reference.** Keep it open until the commands
> are muscle memory. Lessons explain the why; this page is for looking up.

Safety legend: **safe** changes nothing you cannot recover, **rewrites** creates
new commits and leaves the old ones only in the reflog, **destructive** can lose
uncommitted work.

## Setup

| Command | What it does |
|---|---|
| `git config --global user.name "Name"` / `user.email` | Identity stored in every commit |
| `git config --global init.defaultBranch main` | First branch name for new repos |
| `git config --global pull.rebase true` | `pull` rebases instead of merging |
| `git config --global push.autoSetupRemote true` | First push of a new branch sets upstream |
| `git config --global merge.conflictStyle zdiff3` | Conflicts also show the ancestor |
| `git config --global rerere.enabled true` | Remember conflict resolutions |
| `git config --list --show-origin` | Every setting and its file |

## Inspect (read-only)

| Command | What it changes | Safety |
|---|---|---|
| `git status` / `git status -s` | Nothing, shows the three areas | safe |
| `git diff` / `git diff --staged` | Nothing, working vs index / index vs HEAD | safe |
| `git log --oneline --graph --all` | Nothing, draws the commit graph | safe |
| `git log main..feature` | Nothing, commits on feature not on main | safe |
| `git show <rev>` / `git show <rev>:<path>` | Nothing, one commit or file version | safe |
| `git blame -L a,b -w -C <file>` | Nothing, who last changed each line | safe |
| `git log -S str` / `-G regex` / `--follow file` / `-L :func:file` | Nothing, searches history | safe |
| `git reflog` | Nothing, where HEAD has been | safe |
| `git cat-file -p <obj>` / `git ls-files -s` | Nothing, raw objects / index | safe |

```
 working tree --git diff--> index --git diff --staged--> HEAD
```

```knowledge-check
{ "questions": [
  { "id": "git-cheat-inspect-q1", "type": "mcq",
    "prompt": "Which command shows what is staged for the next commit?",
    "options": [
      {"id":"a","text":"git diff --staged"},
      {"id":"b","text":"git diff"},
      {"id":"c","text":"git reflog"},
      {"id":"d","text":"git blame"}],
    "correct": "a",
    "explanation": "git diff alone shows unstaged changes; reflog lists HEAD moves and blame annotates lines." }
] }
```

## Record and share

| Command | What it changes | Safety |
|---|---|---|
| `git add <path>` / `git add -p` | Index | safe |
| `git commit -m msg` | Adds a commit, moves the branch | safe |
| `git commit --amend` | Replaces the last commit | rewrites |
| `git rm --cached <file>` | Untracks, keeps file on disk | safe |
| `git clone <url>` (`--depth 1`, `--filter=blob:none`) | Creates a repo with origin and tracking branches | safe |
| `git remote -v` / `add` / `set-url` | Remote names and URLs | safe |
| `git fetch` (`--prune`) | Remote-tracking branches only | safe |
| `git pull` (`--rebase`, `--ff-only`) | fetch + merge (or rebase) into current branch | safe, may conflict |
| `git push` / `git push -u origin <branch>` | Remote branch (fast-forward only) | safe |
| `git push --force-with-lease --force-if-includes` | Overwrites the remote branch if unchanged since your fetch | rewrites (shared) |
| `git push --force` | Overwrites the remote branch blindly | destructive for teammates |
| `git push origin --delete <branch>` | Deletes a server branch | destructive (server) |

```
 local commits --git push--> origin        origin --git fetch--> origin/* --merge/rebase--> branch
```

```knowledge-check
{ "questions": [
  { "id": "git-cheat-share-q1", "type": "mcq",
    "prompt": "Which command updates origin/main in your clone without touching your own branches?",
    "options": [
      {"id":"a","text":"git fetch"},
      {"id":"b","text":"git pull"},
      {"id":"c","text":"git merge"},
      {"id":"d","text":"git reset --hard"}],
    "correct": "a",
    "explanation": "pull would also integrate into the current branch; merge and reset change your branch." }
] }
```

## Branch, merge, rebase

| Command | What it changes | Safety |
|---|---|---|
| `git switch -c <name> [start]` | New branch pointer, moves HEAD | safe |
| `git merge <branch>` | Fast-forwards or adds a merge commit | safe, may conflict |
| `git merge --no-ff` / `--ff-only` / `--squash` | Always merge commit / never / one plain commit | safe |
| `git merge --abort` | Returns to the pre-merge state | safe |
| `git checkout --ours <file>` / `--theirs` | Takes one side during a conflict | safe |
| `git branch -d <name>` | Deletes a merged branch pointer | safe |
| `git branch -D <name>` | Deletes an unmerged branch pointer | destructive (recoverable via reflog) |
| `git rebase <base>` | Replays your commits with new hashes | rewrites |
| `git rebase -i <base>` (`--autosquash`) | Squash, reword, reorder, drop | rewrites |
| `git rebase --onto <new> <old> <branch>` | Moves only a branch's own commits | rewrites |
| `git rebase --continue` / `--skip` / `--abort` | Continue / drop commit / go back | safe |

```
 merge:   A---B---M          rebase:   A---B---C'---D'
           \     /                     (C, D replaced by copies)
            C---D
```

```knowledge-check
{ "questions": [
  { "id": "git-cheat-branch-q1", "type": "mcq",
    "prompt": "Which of these should never be done to a branch others have already pulled?",
    "options": [
      {"id":"a","text":"Rebase it and force push"},
      {"id":"b","text":"Merge into it"},
      {"id":"c","text":"Revert a commit on it"},
      {"id":"d","text":"Tag it"}],
    "correct": "a",
    "explanation": "Rewriting shared history makes everyone else's copy diverge. Merging, reverting and tagging only add history." }
] }
```

## Undo and recover

| Command | What it changes | Safety |
|---|---|---|
| `git restore <file>` (`--source=<rev>`) | Working tree file from index (or a commit) | destructive (uncommitted edits lost) |
| `git restore --staged <file>` | Index only | safe |
| `git clean -n` / `-fd` | Lists / deletes untracked files | destructive |
| `git reset --soft <rev>` | Branch pointer only, changes stay staged | rewrites |
| `git reset --mixed <rev>` (default) | Branch + index, changes stay in working tree | rewrites |
| `git reset --hard <rev>` | Branch + index + working tree | destructive |
| `git revert <rev>` / `git revert -m 1 <merge>` | Adds a commit that undoes another | safe (shared branches) |
| `git cherry-pick -x <rev>` | Copies one commit onto the current branch | safe, may conflict |
| `git stash push -u -m msg` / `git stash pop` | Parks / restores uncommitted work | safe |
| `git reflog` + `git reset --hard <hash>` | Recovers commits lost by reset, rebase or amend | safe within the expiry (30 days unreachable) |
| `git fsck --no-reflogs --unreachable` | Finds dangling commits (dropped stashes) | safe |
| `git bisect start BAD GOOD` + `git bisect run <cmd>` | Temporarily checks out commits, then `git bisect reset` | safe |

```
              HEAD    INDEX    WORKING TREE
 --soft       moves   keeps    keeps
 --mixed      moves   reset    keeps
 --hard       moves   reset    reset
```

Which undo? **Not committed** -> restore. **Committed, not pushed** -> reset /
amend / rebase -i. **Pushed to a shared branch** -> revert.

```knowledge-check
{ "questions": [
  { "id": "git-cheat-undo-q1", "type": "mcq",
    "prompt": "You ran reset --hard and need the commits back. What do you do?",
    "options": [
      {"id":"a","text":"git reflog, find the hash, git reset --hard <hash>"},
      {"id":"b","text":"git clone again"},
      {"id":"c","text":"git gc"},
      {"id":"d","text":"Nothing, they are gone"}],
    "correct": "a",
    "explanation": "The reflog keeps old positions of HEAD until they expire. A fresh clone lacks unpushed commits and gc could delete them." },
  { "id": "git-cheat-undo-q2", "type": "mcq",
    "prompt": "Which undo is safe on a shared branch?",
    "options": [
      {"id":"a","text":"git revert"},
      {"id":"b","text":"git reset --hard plus force push"},
      {"id":"c","text":"git commit --amend plus force push"},
      {"id":"d","text":"git rebase -i plus force push"}],
    "correct": "a",
    "explanation": "revert only appends history; the others rewrite commits teammates already have." }
] }
```

## Releases, hooks, signing

| Command | What it does |
|---|---|
| `git tag -a v1.2.0 -m msg [rev]` | Annotated release tag |
| `git push origin v1.2.0` / `--follow-tags` | Publish tags |
| `git describe` | Nearest tag + distance, e.g. `v1.2.0-3-g9d4b0c2` |
| `git config core.hooksPath .githooks` | Use versioned hooks |
| `git commit --no-verify` | Skips client hooks (why CI must enforce) |
| `git config --global gpg.format ssh` + `user.signingKey` + `commit.gpgSign true` | Sign commits with SSH |
| `git verify-commit HEAD` / `git log --show-signature` | Check signatures |

## Scale and structure

| Command | What it does |
|---|---|
| `git worktree add ../dir -b branch [start]` / `list` / `remove` | Extra checkouts of one repo |
| `git submodule add <url> <path>` | Pin another repo at a commit |
| `git clone --recurse-submodules` / `git submodule update --init --recursive` | Fetch submodule contents |
| `git clone --filter=blob:none` | Partial clone: contents on demand |
| `git sparse-checkout set <dirs>` | Only some folders on disk |
| `git maintenance start` | Background repo upkeep |
| `git lfs track "*.psd"` | Store big binaries outside history |
| `git filter-repo --invert-paths --path <file>` | Remove a file from all history (after rotating secrets) |
