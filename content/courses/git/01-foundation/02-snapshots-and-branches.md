---
kind: lesson
id_key: git/foundation/snapshots-branches
course: git
section: foundation
section_title: "Big Picture: Why Git"
section_position: 1
title: "Commits Are Snapshots, Branches Are Pointers"
position: 1
estimated_minutes: 9
source:
  - Pro Git book, ch. 1.3 "What is Git?" and ch. 3.1 "Branches in a Nutshell"
---

## Why this matters

Two ideas explain most of Git: a **commit** is a full snapshot with a unique
name, and a **branch** is a tiny label pointing at one commit. Once these click,
commands like merge, rebase and reset stop feeling like magic.

## Mental model: a chain of photos with sticky notes

Imagine taking a photo of your whole desk every time you finish a task. Each
photo has a caption and says which photo came before it. That is a commit.

Now put a sticky note saying "main" on the newest photo. When you take the next
photo, you move the sticky note forward. That sticky note is a branch.

```
 A <-- B <-- C          each commit points to its parent
             ^
            main        a branch is a label on one commit
             ^
            HEAD        HEAD says which label you are using
```

## See it work

### A commit is a snapshot, not a diff

When you commit, Git stores the **whole project** as it looked at that moment
(it reuses unchanged files internally, so this is cheap). Git can still show you
the differences between two snapshots on demand.

Each commit gets a 40-character ID called a **hash**, computed from:

- the snapshot of files,
- the author, date and message,
- the hash of the **parent** commit.

```bash
git log --format='%h %p %s'
```

What this does: prints each commit's short hash, its parent's short hash and
its message. Expected output (hashes differ):

```
9e41c2d 3f1c9ab Add summary stub
3f1c9ab         Add quarterly report
```

The first commit has no parent. It is called the **root commit**.

Because each hash includes the parent's hash, changing any old commit would
change every hash after it. This is why history cannot be edited silently.

### Getting a file back from a snapshot

Committed snapshots stay in the repository. If you overwrite a tracked file by
accident, Git can copy the committed version back:

```bash
git status            # report.txt shows as "modified"
git restore report.txt
git status
```

Expected output of the last command:

```
On branch main
nothing to commit, working tree clean
```

```knowledge-check
{ "questions": [
  { "id": "git-foundation-q1", "type": "mcq",
    "prompt": "You overwrote a tracked file by accident and had committed it earlier. Is the old content lost?",
    "options": [
      {"id":"a","text":"Yes, the file is gone for good"},
      {"id":"b","text":"No, Git still has the committed snapshot and can restore it"},
      {"id":"c","text":"Only if you have a remote"},
      {"id":"d","text":"Only if you saved a backup copy"}],
    "correct": "b",
    "explanation": "Committed snapshots stay in the repository. git restore brings the file back. A remote is not needed, and no manual backup is needed." }
] }
```

### A branch is just a pointer

```
 main        A---B
                  \
 experiment        C     <- your risky idea, isolated
```

```bash
git switch -c experiment   # create a branch here and move onto it
```

Creating a branch writes one small file containing a commit hash. It does not
copy your files. That is why branches are instant and free. Try a bold idea on a
branch; if it fails, delete the branch and `main` never noticed.

```knowledge-check
{ "questions": [
  { "id": "git-foundation-q2", "type": "mcq",
    "prompt": "What is a Git branch?",
    "options": [
      {"id":"a","text":"A full copy of all project files"},
      {"id":"b","text":"A movable pointer to a commit"},
      {"id":"c","text":"A separate repository"},
      {"id":"d","text":"A list of changed lines"}],
    "correct": "b",
    "explanation": "A branch is a tiny pointer, which is why creating one is instant. It copies no files, is not a separate repository, and stores no line changes." }
] }
```

## Try it

Look at this history:

```
 A---B---C   <- main
      \
       D     <- fix
```

1. What is D's parent?
2. If you commit while on `main`, which label moves?

<details>
<summary>Show answer</summary>

1. B. The line from D goes back to B.
2. `main` moves to the new commit. `fix` stays on D. Only the branch you are on
   (the one HEAD points to) moves when you commit.

</details>

## Common mistakes

- **Thinking a commit stores only the changed lines.** It stores a full
  snapshot. Diffs are calculated when you ask for them.
- **Thinking a branch is a folder copy.** Nothing is copied. Switching
  branches just swaps which snapshot your folder shows.
- **Fearing the hash.** You never need to type all 40 characters. The first 7
  are usually enough, and branch names work almost everywhere a hash does.

## Remember

- Commit = full snapshot + author + message + parent link, named by a hash.
- Changing an old commit changes every hash after it.
- Branch = movable label on one commit. HEAD = the label you are using.
- `git restore <file>` copies the committed version back over your edits.

**Self-check:**

1. What three kinds of information go into a commit's hash?
2. Why is creating a branch instant?
3. Which branch moves when you commit?
