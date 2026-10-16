---
kind: lesson
id_key: git/first-commits/three-areas
course: git
section: first-commits
section_title: "Setup and First Commits"
section_position: 2
title: "The Three Areas: Working Tree, Index and Repository"
position: 0
estimated_minutes: 8
source:
  - Pro Git book, ch. 1.3 "The Three States" and ch. 2.1 "Getting a Git Repository"
  - git-init(1), git-status(1) manual pages
---

## Why this matters

Day 1 at Brightside. Maya hands you an empty folder: "Start the hello tool.
Commit as you go; the whole team will read this history." Almost every beginner
confusion ("why is my change not in the commit?") comes from not knowing which
of Git's three areas a file is in. Learn the areas once and `git status` becomes
easy to read.

## Mental model: desk, outbox, archive

| Area | Analogy | What it holds |
|---|---|---|
| **Working tree** | Your desk | The files you see and edit |
| **Index** (staging area) | The outbox tray | Exactly what the next commit will contain |
| **Repository** (`.git`) | The archive | Every commit ever made |

You work at the desk, put finished pages in the outbox, and when the outbox is
ready you seal it into the archive as one commit.

```
 WORKING TREE            INDEX (staging)             REPOSITORY (.git)
 files you edit   --->   next commit's snapshot --->  permanent history
                 git add                    git commit
       <---------------- git restore -----------------
```

> **One-sentence definition:** the **index** is a draft of your next commit.
> `git add` updates the draft; `git commit` saves the draft as a snapshot.

Why have a draft at all? Because you often edit five files but want to commit
only two of them as one tidy change.

## See it work

### Create a repository

```bash
mkdir -p ~/work/hello && cd ~/work/hello
git init
git status
```

What this does: `git init` creates the hidden `.git` directory (the repository).
Nothing is committed yet. Expected output:

```
Initialized empty Git repository in /home/labuser/work/hello/.git/
On branch main

No commits yet

nothing to commit (create/copy files and use "git add" to track)
```

The first branch is called `main` because of the setting
`init.defaultBranch`. Older Git versions used `master`. You can set it once with
`git config --global init.defaultBranch main`.

### Watch a file move through the areas

```bash
echo "# Hello" > README.md
git status -s       # ?? README.md   -> untracked: only on your desk
git add README.md
git status -s       # A  README.md   -> added to the index (outbox)
```

- **Untracked** = Git has never seen this file. It is not in the index or any
  commit.
- **Tracked** = the file is in the index (and usually in the last commit).

Never delete or edit files inside `.git` by hand. It is Git's database.

```knowledge-check
{ "questions": [
  { "id": "git-first-areas-q1", "type": "mcq",
    "prompt": "Which area does git commit actually snapshot?",
    "options": [
      {"id":"a","text":"The working tree"},
      {"id":"b","text":"The index (staging area)"},
      {"id":"c","text":"The remote repository"},
      {"id":"d","text":"Only files modified in the last hour"}],
    "correct": "b",
    "explanation": "A commit is built from the index. Edits you did not git add are not part of it, the remote is not involved, and time does not matter." }
] }
```

## Try it

You edit `a.txt` and `b.txt`, then run `git add a.txt` and `git commit -m
"Update a"`. Where is your change to `b.txt` now?

<details>
<summary>Show answer</summary>

Still only in the working tree (on your desk). It was never added to the index,
so it is not in the commit. `git status` lists it under "Changes not staged for
commit".

</details>

## Common mistakes

- **Running `git init` in your home directory.** Then every file you own looks
  untracked. Run it inside the project folder. If it happened, delete only that
  stray `~/.git` directory.
- **Thinking `git add` is only for new files.** You `git add` every change you
  want in the next commit, including edits to tracked files.
- **Editing after `git add` and expecting the edit to be committed.** The index
  holds the version from the moment you ran `git add`. Add again after editing.

## Remember

- Three areas: working tree (desk) -> index (outbox) -> repository (archive).
- `git add` = put into the next commit. `git commit` = save the index.
- `git status` tells you which area every changed file is in.
- `git init` creates `.git`; never edit it by hand.

**Self-check:**

1. What does the index contain?
2. What does `??` mean in `git status -s`?
3. You edited a file after `git add`. Which version will the commit contain?
