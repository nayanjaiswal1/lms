---
kind: lesson
id_key: git/first-commits/status-diff
course: git
section: first-commits
section_title: "Setup and First Commits"
section_position: 2
title: "Reading status and diff"
position: 3
estimated_minutes: 8
source:
  - git-status(1), git-diff(1), git-add(1) manual pages
---

## Why this matters

Before every commit you should know exactly what you are about to save.
`git status` tells you **which** files changed and in which area. `git diff`
tells you **what** changed inside them. Reading both takes ten seconds and stops
you committing debug prints, secrets and half-finished work.

## Mental model: two comparisons

There are two gaps between the three areas, and one command for each gap:

```
 working tree --git diff--> index --git diff --staged--> HEAD (last commit)

 README.md  (edited, added)       -> shows under "Changes to be committed"
 main.sh    (edited, not added)   -> shows under "Changes not staged"
```

- `git diff` = desk vs outbox (what you have **not** staged yet).
- `git diff --staged` (same as `--cached`) = outbox vs archive (what the next
  commit **will** contain).
- `git diff HEAD` = desk vs archive (everything changed since the last commit).

## See it work

### The short status format

```bash
echo "Learning git" >> README.md && git add README.md
echo "echo done" >> main.sh
git status -s
```

Expected output:

```
M  README.md
 M main.sh
```

Read it as two columns:

| Left column | Right column |
|---|---|
| index vs HEAD (staged) | working tree vs index (not staged) |

So `M ` (left) means staged, ` M` (right) means modified but not staged, and
`MM` means "staged once, then edited again". Other letters: `A` added, `D`
deleted, `R` renamed, `??` untracked, `UU` conflict.

### The two diffs

```bash
git diff            # shows only main.sh (unstaged)
git diff --staged   # shows only README.md (staged)
```

Expected output of `git diff --staged`:

```
diff --git a/README.md b/README.md
index 1b3e6c2..5d6a0f4 100644
--- a/README.md
+++ b/README.md
@@ -1 +1,2 @@
 # Hello
+Learning git
```

How to read a diff:

- `---` / `+++` name the old and new versions.
- `@@ -1 +1,2 @@` = the hunk starts at line 1; old had 1 line, new has 2.
- Lines starting with `+` were added, `-` removed, a space means unchanged
  context.

Useful variations: `git diff --stat` (summary per file), `git diff --word-diff`
(changes inside long lines), `git diff main feature` (two branches).

```knowledge-check
{ "questions": [
  { "id": "git-first-diff-q1", "type": "mcq",
    "prompt": "git diff prints nothing but git status shows a file under 'Changes to be committed'. Why?",
    "options": [
      {"id":"a","text":"The change is already staged, and plain git diff only compares working tree to index"},
      {"id":"b","text":"The file was ignored"},
      {"id":"c","text":"Git diff only works on binary files"},
      {"id":"d","text":"The repository is corrupt"}],
    "correct": "a",
    "explanation": "Use git diff --staged to see index versus HEAD. An ignored file would not appear in status at all, git diff works on text, and nothing is corrupt." }
] }
```

### Stage only part of a file

```bash
git add -p main.sh
```

What this does: shows each changed hunk and asks `Stage this hunk [y,n,q,a,d,s,e,?]?`.
Answer `y` or `n` per hunk. This is how you split one messy edit into two clean
commits.

## Try it

`git status -s` prints `MM app.py`. What happened, and what does
`git diff --staged` show versus `git diff`?

<details>
<summary>Show answer</summary>

You edited `app.py`, ran `git add`, then edited it again. `git diff --staged`
shows the first edit (what will be committed). `git diff` shows the second edit
(not staged yet). Run `git add app.py` again if you want both in the commit.

</details>

## Common mistakes

- **Using `git add .` blindly.** It stages everything, including stray debug
  files. Look at `git status` first, or stage files by name.
- **Reading only `git diff` before committing.** It hides staged changes. Use
  `git diff --staged` to review what you are about to commit.
- **Panicking at `MM`.** It only means the file has both staged and unstaged
  changes.

## Remember

- `git status -s`: left column = staged, right column = not staged.
- `git diff` = not staged yet. `git diff --staged` = what the commit will contain.
- `git add -p` stages hunk by hunk.
- Always review `git diff --staged` before `git commit`.

**Self-check:**

1. Which command shows what the next commit will contain?
2. What does ` M` (space, M) mean in short status?
3. How do you stage only half of the changes in one file?
