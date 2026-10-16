---
kind: lesson
id_key: git/branch-merge/branches
course: git
section: branch-merge
section_title: Branching and Merging
section_position: 5
title: "Creating, Switching and Deleting Branches"
position: 0
estimated_minutes: 8
source:
  - Pro Git book, ch. 3.1 "Branches in a Nutshell" and ch. 3.3 "Branch Management"
  - git-branch(1), git-switch(1) manual pages
---

## Why this matters

Maya is mid-release: "Don't touch main. Do your login form on a branch." On a
team, every change starts on a branch so that `main` stays releasable. You need
to create branches, move between them and clean them up without fear.

## Mental model: bookmarks in one book

All branches live in one book of commits. A branch is a bookmark; `HEAD` is
your finger saying which bookmark you are reading. Switching branches swaps the
pages on your desk (the working tree) to that bookmark's snapshot.

```
BEFORE  git switch -c feature/greeting     AFTER one commit on the new branch

 A---B---C  <- main <- HEAD                 A---B---C  <- main
                                                     \
                                                      D  <- feature/greeting <- HEAD
```

Under the hood a branch is a 41-byte file (40 hex characters + newline) in
`.git/refs/heads/`. Creating one copies a pointer, nothing else.

## See it work

### Create and switch

```bash
cd ~/work/shop
git switch -c feature/greeting       # create + switch (old style: git checkout -b)
echo hello > greeting.txt && git add greeting.txt && git commit -m "Add greeting"
git log --oneline --graph --all
```

Expected output (hashes differ):

```
* 2ab9c40 (HEAD -> feature/greeting) Add greeting
| * 77d1e0a (feature/cart) Add cart totals
| * 0c4f8e2 Add cart file
|/
* 5e13a9b (main) Add checkout
* 9b2d6c1 Add product list
* 1f0a7d3 Initial commit
```

`git log --oneline --graph --all` is the single most useful command for seeing
branches. Make an alias: `git config --global alias.lg "log --oneline --graph --all"`,
then type `git lg`.

```knowledge-check
{ "questions": [
  { "id": "git-branch-pointer-q1", "type": "mcq",
    "prompt": "What does creating a new branch copy?",
    "options": [
      {"id":"a","text":"All files in the repository"},
      {"id":"b","text":"Only a pointer to the current commit"},
      {"id":"c","text":"The whole history"},
      {"id":"d","text":"The staging area only"}],
    "correct": "b",
    "explanation": "Branches are cheap because they are just references to commits. No files, history or index are copied." }
] }
```

### The everyday branch commands

| Command | What it does |
|---|---|
| `git branch` | List local branches; `*` marks the current one |
| `git switch <name>` | Move to an existing branch |
| `git switch -c <name> [start]` | Create (optionally from `start`) and switch |
| `git switch -` | Jump back to the previous branch |
| `git branch -m <new>` | Rename the current branch |
| `git branch -d <name>` | Delete a branch that is fully merged |
| `git branch -D <name>` | Force-delete, even if unmerged |
| `git branch --merged` | List branches already merged into the current one |

`git checkout` does both switching and file restoring; the newer `switch` and
`restore` split those jobs so mistakes are harder. You will still see
`checkout` in older guides.

### Uncommitted changes travel with you

If you switch with uncommitted edits, Git carries them along when it can. If
the target branch has a different version of the same file, Git refuses:

```
error: Your local changes to the following files would be overwritten by checkout:
	app.sh
Please commit your changes or stash them before you switch branches.
```

Commit or stash (Section 9) first.

### Deleting branches

```bash
git branch -d feature/greeting
```

Deleting a branch removes only the label. Commits that are reachable from
another branch (for example, merged into `main`) are untouched.

```knowledge-check
{ "questions": [
  { "id": "git-branch-noff-q2", "type": "mcq",
    "prompt": "git branch -d refuses to delete a branch. What does that usually mean?",
    "options": [
      {"id":"a","text":"The branch has commits not yet merged into the current branch"},
      {"id":"b","text":"The branch is too old"},
      {"id":"c","text":"You must be root"},
      {"id":"d","text":"The repo is read-only"}],
    "correct": "a",
    "explanation": "-d is the safe delete. Use -D only when you are sure the work is disposable. Age, root access and read-only repos are not the reason." }
] }
```

### Detached HEAD in one paragraph

`git switch --detach <commit>` (or `git checkout <hash>`) puts `HEAD` directly
on a commit instead of on a branch. Fine for looking around. If you commit
there, no branch points to the new commits, so they are easy to lose. Before
leaving, save them with `git switch -c rescue-branch`. Section 7 explains why.

## Try it

You are on `main` with no changes. Create a branch `fix/typo` from the commit
two before `main`'s tip, without switching to it.

<details>
<summary>Show answer</summary>

```bash
git branch fix/typo main~2
```

`git branch <name> <start>` creates without switching. `main~2` means "two
commits before main" (Section 7 covers this syntax).

</details>

## Common mistakes

- **Starting work on `main` by accident.** Run `git switch -c feature/x` before
  the first edit. If you already committed, Section 13 shows how to move the
  commits.
- **Reaching for `-D` when `-d` refuses.** Check `git log main..branch` first to
  see what you would orphan.
- **Branch names with spaces.** Use `feature/login-form` style.

## Remember

- Branch = 41-byte pointer file. `HEAD` = which branch you are on.
- `git switch -c` creates, `git switch` moves, `git branch -d` deletes merged ones.
- `git log --oneline --graph --all` shows every branch.
- Deleting a branch deletes only the label.

**Self-check:**

1. What is stored in a branch file?
2. Why does `git branch -d` sometimes refuse?
3. What risk comes with committing on a detached HEAD?
