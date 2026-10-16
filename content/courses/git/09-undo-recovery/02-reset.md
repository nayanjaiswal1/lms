---
kind: lesson
id_key: git/undo-recovery/reset
course: git
section: undo-recovery
section_title: Undo and Recovery
section_position: 9
title: "reset: --soft, --mixed and --hard"
position: 1
estimated_minutes: 9
source:
  - Pro Git book, ch. 7.7 "Reset Demystified"
  - git-reset(1) manual page
---

## Why this matters

`git reset` is the most powerful undo for **local, unpushed** commits: redo a
commit, unstage everything, or throw commits away. It is also the command that
scares people most, because one flag decides whether your work survives. Learn
the three modes as three levels of rewind.

## Mental model: rewind the tape, choose how far

Reset always does step 1, and the mode decides whether it continues:

1. **Move the branch** (and HEAD) to the target commit. *(all modes)*
2. **Make the index match** that commit. *(`--mixed`, `--hard`)*
3. **Make the working tree match** that commit. *(`--hard` only)*

```
              moves HEAD    resets INDEX    overwrites WORKING TREE
 --soft           yes            no                 no
 --mixed (default) yes           yes                no
 --hard           yes            yes                yes   (destructive)
```

Mnemonic: **S**oft = **S**taged stays, **M**ixed = **M**odified (unstaged)
stays, **H**ard = **H**istory and changes **H**ave gone.

```
BEFORE: A---B---C  <- main (HEAD)         git reset X HEAD~1

 --soft :  A---B  <- main   index = C's content (staged)   working = C's content
 --mixed:  A---B  <- main   index = B              working = C's content (unstaged)
 --hard :  A---B  <- main   index = B              working = B      (C's changes gone)
           C is now unreachable (but in the reflog)
```

## See it work

### --soft: redo the last commit

```bash
git reset --soft HEAD~1
git commit -m "Add March entries"
```

What this does: un-commits "Add Marsh entries" but keeps every change staged, so
the next commit recreates it with a better message. (Same result as
`git commit --amend` here; soft reset also works for squashing the last 3
commits: `git reset --soft HEAD~3 && git commit`.)

### --mixed: un-commit and unstage

```bash
git reset HEAD~1          # --mixed is the default
git status -s
```

Expected output:

```
 M ledger.txt
```

The commit is gone from the branch; its changes are plain unstaged edits, ready
to be split into different commits.

### --hard: throw it all away

```bash
git reset --hard HEAD~2
```

Expected output:

```
HEAD is now at 4be2c19 Add February entries
```

The two commits are off the branch (recoverable via the reflog, next lesson).
Any **uncommitted** edits are destroyed for good.

```knowledge-check
{ "questions": [
  { "id": "git-undo-reset-q1", "type": "mcq",
    "prompt": "After git reset --soft HEAD~1, where do the undone commit's changes live?",
    "options": [
      {"id":"a","text":"Staged in the index"},
      {"id":"b","text":"Unstaged in the working tree"},
      {"id":"c","text":"Deleted"},
      {"id":"d","text":"In a stash"}],
    "correct": "a",
    "explanation": "--soft leaves index and working tree alone; --mixed unstages; --hard discards. Nothing goes into a stash." },
  { "id": "git-undo-reset-q2", "type": "mcq",
    "prompt": "Which reset mode can destroy uncommitted work?",
    "options": [
      {"id":"a","text":"--soft"},
      {"id":"b","text":"--mixed"},
      {"id":"c","text":"--hard"},
      {"id":"d","text":"None of them"}],
    "correct": "c",
    "explanation": "--hard overwrites the working tree, and uncommitted edits are not in the reflog. --soft and --mixed keep your working tree as it is." }
] }
```

### Useful targets

| Target | Meaning |
|---|---|
| `HEAD~1` | One commit back |
| `origin/main` | Make my branch match the server (drop my local commits) |
| `ORIG_HEAD` | Where HEAD was before the last reset/merge/rebase (quick undo) |
| `<hash from reflog>` | Any earlier state |

`git reset --keep <target>` is a safer `--hard`: it refuses if it would
overwrite uncommitted changes.

## Try it

You made three small local commits on `feature` and want them as one commit
before pushing. Do it with reset.

<details>
<summary>Show answer</summary>

```bash
git reset --soft HEAD~3
git commit -m "Add search feature"
```

`--soft` keeps all three commits' changes staged, so one commit captures them.
Interactive rebase with `fixup` does the same with more control.

</details>

## Common mistakes

- **Resetting commits that are already pushed to a shared branch.** Your branch
  then disagrees with the server; others keep the old commits. Use `revert`.
- **`--hard` with uncommitted work you wanted.** Commit or stash first, or use
  `--keep`.
- **Confusing `git reset <file>` with `git reset --hard`.** With a path, reset
  only unstages that file (like `restore --staged`); it never moves the branch.

## Remember

- Reset moves the branch; the mode decides what else rewinds.
- `--soft` keeps staged, `--mixed` keeps edits unstaged, `--hard` keeps nothing.
- Only for local, unpushed commits.
- Lost commits after reset are recoverable; lost uncommitted edits are not.

**Self-check:**

1. Which mode is the default?
2. How do you squash the last three commits with reset?
3. Why is `--hard` dangerous but `--soft` not?
