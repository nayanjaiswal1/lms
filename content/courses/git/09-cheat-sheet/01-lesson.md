---
kind: lesson
id_key: git/cheat-sheet/lesson
course: git
section: cheat-sheet
section_title: Cheat Sheet
section_position: 9
title: One-Page Git Cheat Sheet
position: 0
estimated_minutes: 10
source:
  - Pro Git book (git-scm.com/book)
  - git-scm.com/docs command reference
---

Safety legend: **safe** changes nothing you cannot recover, **rewrites** creates new commits and
leaves the old ones only in the reflog, **destructive** can lose uncommitted work.

## Inspect (read-only)

| Command | What it changes | Safety |
|---|---|---|
| `git status` / `git status -s` | Nothing, shows the three areas | safe |
| `git diff` / `git diff --staged` | Nothing, working vs index / index vs HEAD | safe |
| `git log --oneline --graph --all` | Nothing, draws the commit graph | safe |
| `git show <rev>` / `git show <rev>:<path>` | Nothing, one commit or file version | safe |
| `git blame -L a,b -w -C <file>` | Nothing, who last changed each line | safe |
| `git log -S str` / `-G regex` / `--follow file` | Nothing, searches history | safe |
| `git reflog` | Nothing, where HEAD has been | safe |

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
    "explanation": "git diff alone shows unstaged changes." }
] }
```

## Record and share

| Command | What it changes | Safety |
|---|---|---|
| `git add <path>` | Index | safe |
| `git commit -m msg` | Adds a commit, moves the branch | safe |
| `git commit --amend` | Replaces the last commit | rewrites |
| `git clone <url>` | Creates a repo with origin and tracking branches | safe |
| `git fetch` | Remote-tracking branches only | safe |
| `git pull` | fetch + merge (or rebase) into current branch | safe, may conflict |
| `git push` / `git push -u origin <branch>` | Remote branch (fast-forward only) | safe |
| `git push --force-with-lease` | Overwrites the remote branch if unchanged since your fetch | rewrites (shared) |
| `git push --force` | Overwrites the remote branch blindly | destructive for teammates |
| `git tag -a v1 -m msg` + `git push origin v1` | Adds an annotated tag | safe |

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
    "explanation": "pull would also integrate into the current branch." }
] }
```

## Branch, merge, rebase

| Command | What it changes | Safety |
|---|---|---|
| `git switch -c <name>` | New branch pointer, moves HEAD | safe |
| `git merge <branch>` | Fast-forwards or adds a merge commit | safe, may conflict |
| `git merge --no-ff <branch>` | Always adds a merge commit | safe |
| `git merge --abort` | Returns to the pre-merge state | safe |
| `git branch -d <name>` | Deletes a merged branch pointer | safe |
| `git branch -D <name>` | Deletes an unmerged branch pointer | destructive (recoverable via reflog) |
| `git rebase <base>` | Replays your commits with new hashes | rewrites |
| `git rebase -i <base>` | Squash, reword, reorder, drop | rewrites |
| `git rebase --continue` / `--abort` | Continue after a fix / go back | safe |
| `git config rerere.enabled true` | Remembers conflict resolutions | safe |

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
    "explanation": "Rewriting shared history makes everyone else's copy diverge." }
] }
```

## Undo and recover

| Command | What it changes | Safety |
|---|---|---|
| `git restore <file>` | Working tree file from index | destructive (uncommitted edits lost) |
| `git restore --staged <file>` | Index only | safe |
| `git reset --soft <rev>` | Branch pointer only, changes stay staged | rewrites |
| `git reset --mixed <rev>` (default) | Branch + index, changes stay in working tree | rewrites |
| `git reset --hard <rev>` | Branch + index + working tree | destructive |
| `git revert <rev>` / `git revert -m 1 <merge>` | Adds a commit that undoes another | safe (shared branches) |
| `git cherry-pick <rev>` | Copies one commit onto the current branch | safe, may conflict |
| `git stash push -m msg` / `git stash pop` | Parks / restores uncommitted work | safe |
| `git reflog` + `git reset --hard <hash>` | Recovers commits lost by reset or amend | safe if done within ~90 days |
| `git bisect start BAD GOOD` + `git bisect run <cmd>` | Temporarily checks out commits, then `git bisect reset` | safe |

```
              HEAD    INDEX    WORKING TREE
 --soft       moves   keeps    keeps
 --mixed      moves   reset    keeps
 --hard       moves   reset    reset
```

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
    "explanation": "The reflog keeps old positions of HEAD until garbage collection." },
  { "id": "git-cheat-undo-q2", "type": "mcq",
    "prompt": "Which undo is safe on a shared branch?",
    "options": [
      {"id":"a","text":"git revert"},
      {"id":"b","text":"git reset --hard plus force push"},
      {"id":"c","text":"git commit --amend plus force push"},
      {"id":"d","text":"git rebase -i plus force push"}],
    "correct": "a",
    "explanation": "revert only appends history." }
] }
```
