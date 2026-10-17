---
kind: lesson
id_key: git/first-commits/amend
course: git
section: first-commits
section_title: "Setup and First Commits"
section_position: 2
title: "Fixing the Last Commit with --amend"
position: 4
estimated_minutes: 7
source:
  - git-commit(1) manual page, --amend
  - Pro Git book, ch. 2.4 "Undoing Things"
---

## Why this matters

You commit, then notice a typo in the message or a file you forgot to add.
Making a second commit called "oops" clutters history. `git commit --amend`
fixes the last commit instead, as long as nobody else has it yet.

## Mental model: reseal the envelope (with a new envelope)

Amend does **not** edit the old commit. Commits never change. Amend builds a
**new** commit from the current index, with the same parent as the old one, and
moves the branch to it. The old commit is left behind, unreachable.

```
BEFORE amend                         AFTER git commit --amend

 A---B---C  <- main                   A---B---C'  <- main
                                           \
                                            C (orphaned, still in reflog)
```

`C'` has a different hash from `C`, because its content or message differs.

## See it work

### Add a forgotten file

```bash
git commit -m "Update readme"
git add main.sh                         # forgot this one
git commit --amend -m "Update README and script"
git log --oneline
```

What this does: the first commit misses `main.sh`; amend replaces that commit
with one that has both files and a better message. Expected output:

```
b94e2d1 (HEAD -> main) Update README and script
7a03c55 Add main script and gitignore
3f1c9ab Add README
```

Only three commits. The "Update readme" commit is gone from the branch.

### Fix only the message

```bash
git commit --amend -m "Fix crash when cart is empty"
```

With nothing staged, amend keeps the same snapshot and only changes the
message.

### Keep the message, add a file

```bash
git add forgotten.txt
git commit --amend --no-edit
```

`--no-edit` reuses the existing message without opening the editor.

### Why amend is dangerous after pushing

```
 your laptop:  A---B---C'   (amended)
 origin     :  A---B---C    (teammates already pulled C)
```

Your branch and the server now disagree. A normal `git push` is rejected, and a
force push would remove `C` from under your teammates' feet.

```knowledge-check
{ "questions": [
  { "id": "git-first-amend-q1", "type": "mcq",
    "prompt": "Why should you not amend a commit you already pushed?",
    "options": [
      {"id":"a","text":"Amend creates a new commit with a new hash, so the pushed one diverges from your local branch"},
      {"id":"b","text":"Amend deletes the remote repository"},
      {"id":"c","text":"Amend only works on the first commit"},
      {"id":"d","text":"Amend is not a real command"}],
    "correct": "a",
    "explanation": "The amended commit is a different object. Anyone who already has the old one now has diverging history. Amend never touches the remote, works on any last commit, and is a standard option of git commit." }
] }
```

## Try it

You committed "Add tax calcualtor" (typo) one minute ago and have not pushed.
Fix the message without changing the files.

<details>
<summary>Show answer</summary>

```bash
git commit --amend -m "Add tax calculator"
```

Make sure nothing is staged first (`git status`), or that staged change will be
folded into the commit too.

</details>

## Common mistakes

- **Amending with unrelated changes staged.** Amend takes the **whole current
  index**. Check `git status` first.
- **Amending a pushed commit on a shared branch.** Make a new commit instead.
  On your own feature branch it is fine, followed by
  `git push --force-with-lease` (Section 8).
- **Thinking the old commit is destroyed.** It is still in the reflog for weeks
  (Section 9), so a bad amend can be undone.

## Remember

- `--amend` replaces the last commit with a new one (new hash).
- `--amend -m "..."` fixes the message; `--amend --no-edit` adds staged files.
- Never amend commits others already have.
- The old commit stays recoverable through the reflog.

**Self-check:**

1. Does amend modify the old commit?
2. What does `--no-edit` do?
3. What goes wrong if you amend a commit your teammate already pulled?
