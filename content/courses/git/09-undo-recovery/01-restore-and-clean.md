---
kind: lesson
id_key: git/undo-recovery/restore-clean
course: git
section: undo-recovery
section_title: "Undo and Recovery"
section_position: 9
title: "restore and clean: Undo Uncommitted Changes"
position: 0
estimated_minutes: 7
source:
  - Pro Git book, ch. 2.4 "Undoing Things" and ch. 7.3 "Stashing and Cleaning"
  - git-restore(1), git-clean(1) manual pages
---

## Why this matters

"I just deleted my work" is something everyone says once. This section gives
you the right undo for every situation. Start with the simplest: changes you
have **not committed yet**. These are also the only undos that can destroy work
for good, so learn exactly what each one throws away.

## Mental model: three erasers for three places

| Situation | Eraser | Touches | Reversible? |
|---|---|---|---|
| Unwanted edit in a tracked file | `git restore <file>` | Working tree | **No** |
| File staged by mistake | `git restore --staged <file>` | Index only | Yes (edit stays on disk) |
| Untracked junk files | `git clean` | Untracked files | **No** |

None of these move a branch or touch commits.

```
 BEFORE                                   AFTER
 HEAD   : ledger v1                       HEAD   : ledger v1
 index  : ledger v1                       index  : ledger v1
 working: ledger v1 + GARBAGE             working: ledger v1       git restore ledger.txt

 git restore --staged secret.txt:  index loses the file, working copy untouched
```

## See it work

### Discard an edit

```bash
cd ~/work/ledger
git status -s
git diff ledger.txt          # look before you throw away
git restore ledger.txt
```

What this does: copies the index version of `ledger.txt` over your working
copy. Expected `git status -s` before and after both restores (below):

```
 M ledger.txt
A  secret.txt
(after both restores)
?? secret.txt
```

### Unstage a file

```bash
git restore --staged secret.txt
```

What this does: copies HEAD's version into the index (for a new file, removes it
from the index). The file stays on disk, now untracked. Then add it to
`.gitignore`.

```knowledge-check
{ "questions": [
  { "id": "git-undo-restore-q1", "type": "mcq",
    "prompt": "Which command removes a file from the staging area without deleting your edits?",
    "options": [
      {"id":"a","text":"git restore --staged <file>"},
      {"id":"b","text":"git restore <file>"},
      {"id":"c","text":"git reset --hard"},
      {"id":"d","text":"git clean -f"}],
    "correct": "a",
    "explanation": "Plain git restore <file> would discard the working-tree edits instead. reset --hard discards all changes, and clean -f deletes untracked files." }
] }
```

### Restore from any commit

```bash
git restore --source=HEAD~2 ledger.txt        # the version from two commits ago
git restore --source=main --staged --worktree app.sh   # both index and file from main
```

Older equivalents you will see in guides: `git checkout -- file` (= restore)
and `git reset HEAD file` (= restore --staged).

### Remove untracked files

```bash
git clean -n        # dry run: list what WOULD be deleted
git clean -f        # delete untracked files
git clean -fd       # ... and untracked directories
git clean -fdx      # ... and ignored files too (build output, .env!)
```

Always run `-n` first. `-x` deletes ignored files, including local secrets and
caches you may want.

## Try it

You ran `git add .` and staged `debug.log` along with real work. You want to
keep the real work staged and stop `debug.log` from being committed, but keep
the log on disk. Which command?

<details>
<summary>Show answer</summary>

```bash
git restore --staged debug.log
echo "*.log" >> .gitignore
```

Only the index entry is removed; the file and your other staged changes stay.

</details>

## Common mistakes

- **`git restore <file>` when you meant `--staged`.** Your edits are gone; they
  were never stored, so even the reflog cannot help.
- **`git clean -fdx` without a dry run.** It deletes ignored files like `.env`
  and local databases.
- **Expecting restore to undo a commit.** It does not move branches; use
  `reset` or `revert` (next lessons).

## Remember

- `git restore <file>` discards uncommitted edits (permanent).
- `git restore --staged <file>` unstages; edits stay.
- `--source=<commit>` restores a file from any commit.
- `git clean -n` before `git clean -f`; `-x` also removes ignored files.

**Self-check:**

1. Which of these undos can lose work permanently?
2. What is the modern replacement for `git checkout -- file`?
3. What does `git clean -n` do?
