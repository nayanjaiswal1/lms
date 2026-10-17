---
kind: lesson
id_key: git/undo-recovery/reflog
course: git
section: undo-recovery
section_title: "Undo and Recovery"
section_position: 9
title: "reflog: The Safety Net Under Everything"
position: 2
estimated_minutes: 7
source:
  - Pro Git book, ch. 7.1 "RefLog Shortnames" and ch. 10.7 "Data Recovery"
  - git-reflog(1), git-config(1) gc.reflogExpire manual pages
---

## Why this matters

A bad `reset --hard`, a botched rebase, a deleted branch, an amend you regret:
all of them look like lost work. They are almost never lost. The **reflog**
records every position your branches and HEAD have had, so you can walk back to
any of them.

## Mental model: your browser history

`git log` is the official story of a branch. The reflog is your **browser
history**: every place HEAD has been, in order, including detours that are no
longer part of any branch. It is **local** (never pushed or cloned) and private
to your repository.

```
 git reflog
 4be2c19 HEAD@{0}: reset: moving to HEAD~2
 a91d6f3 HEAD@{1}: commit: Add April entries      <-- the "lost" commit
 5c07b8e HEAD@{2}: commit: Add March entries

 git reset --hard a91d6f3     main points at April again:  A---B---C---D---E <- main
```

## See it work

### Find and restore lost commits

```bash
git reflog
```

Expected output (top = most recent):

```
4be2c19 (HEAD -> main) HEAD@{0}: reset: moving to HEAD~2
a91d6f3 HEAD@{1}: commit: Add April entries
5c07b8e HEAD@{2}: commit: Add March entries
4be2c19 (HEAD -> main) HEAD@{3}: reset: moving to HEAD~1
```

Pick the line from **before** the mistake and go back to it:

```bash
git reset --hard a91d6f3          # or: git reset --hard HEAD@{1}
```

Expected:

```
HEAD is now at a91d6f3 Add April entries
```

If you only want to look or keep both versions, create a branch instead:
`git branch rescue a91d6f3`.

```knowledge-check
{ "questions": [
  { "id": "git-undo-reflog-q1", "type": "mcq",
    "prompt": "You ran git reset --hard and lost commits. What is your first move?",
    "options": [
      {"id":"a","text":"Re-clone the repo"},
      {"id":"b","text":"git reflog to find the old commit hash, then reset or branch to it"},
      {"id":"c","text":"git gc --prune=now"},
      {"id":"d","text":"Nothing - it is gone"}],
    "correct": "b",
    "explanation": "The reflog keeps previous positions of HEAD (entries for commits no longer on a branch expire after 30 days by default). Re-cloning only gets what was pushed, and gc --prune=now could delete exactly the objects you need." }
] }
```

### Per-branch reflogs and time travel

```bash
git reflog show feature/login        # history of one branch
git log -g --oneline                 # reflog as a log
git show main@{yesterday}            # where main was yesterday
git diff main@{1} main               # what the last move of main changed
```

### What the reflog can and cannot save

| Situation | Recoverable? |
|---|---|
| `reset --hard`, bad rebase, bad amend | Yes, find the old HEAD |
| Deleted branch (`branch -D`) | Yes, its last commit is in HEAD's reflog if you had it checked out |
| Dropped stash | Not in the reflog; use `git fsck --unreachable` (Section 13) |
| Uncommitted, unstaged edits | **No** - Git never stored them |
| Work in a clone you deleted | **No** - the reflog lived inside it |

Default expiry: 90 days for entries still reachable from the branch, 30 days
for entries pointing at commits no longer on it (`gc.reflogExpire`,
`gc.reflogExpireUnreachable`).

## Try it

You ran `git rebase -i main`, dropped a commit by mistake, and the rebase
finished. Recover the branch exactly as it was before the rebase.

<details>
<summary>Show answer</summary>

```bash
git reflog
# find the line just before "rebase (start)", e.g. "HEAD@{5}: commit: ..."
git reset --hard HEAD@{5}
```

Right after a rebase, `git reset --hard ORIG_HEAD` also works.

</details>

## Common mistakes

- **Panicking and running `git gc --prune=now`.** That can delete the very
  objects the reflog points at.
- **Expecting the reflog on another machine.** It is local; a fresh clone has
  none of your history of moves.
- **Choosing the wrong line.** Each line is the state *after* that action. To
  undo an action, pick the line below it.

## Remember

- `git reflog` = every place HEAD has been, newest first.
- Recover with `git reset --hard <hash>` or `git branch rescue <hash>`.
- `HEAD@{n}`, `main@{yesterday}` and `ORIG_HEAD` are handy names.
- Local only; entries expire (30/90 days); never-committed edits are not in it.

**Self-check:**

1. Is the reflog pushed to the server?
2. Which line do you pick to undo the latest action?
3. Name one thing the reflog cannot recover.
