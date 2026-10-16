---
kind: lesson
id_key: git/branch-merge/merge-types
course: git
section: branch-merge
section_title: Branching and Merging
section_position: 5
title: "Fast-Forward, Merge Commits, --no-ff and Squash Merges"
position: 1
estimated_minutes: 9
source:
  - Pro Git book, ch. 3.2 "Basic Branching and Merging"
  - git-merge(1) manual page
---

## Why this matters

`git merge` produces different history shapes depending on the situation and
the flags. Teams choose a shape on purpose: a straight line, visible feature
bubbles, or one commit per pull request. You need to predict what a merge will
do before you run it.

## Mental model: catching up vs joining

- **Fast-forward** = catching up. Your branch is simply behind; slide the label
  forward. No new commit.
- **Three-way merge** = joining. Both sides moved; Git makes a new commit with
  **two parents** that ties the lines together.

You always merge **into the branch you are on**: `git switch main` then
`git merge feature`.

## See it work

### Fast-forward

```
BEFORE                                AFTER  git switch main; git merge feature/greeting

 A---B---C  <- main                    A---B---C---D  <- main, feature/greeting
          \
           D  <- feature/greeting
```

```bash
git switch main
git merge feature/greeting
```

Expected output:

```
Updating 5e13a9b..2ab9c40
Fast-forward
 greeting.txt | 1 +
 1 file changed, 1 insertion(+)
```

```knowledge-check
{ "questions": [
  { "id": "git-branch-ff-q1", "type": "mcq",
    "prompt": "When can Git fast-forward a merge?",
    "options": [
      {"id":"a","text":"When both branches have new commits"},
      {"id":"b","text":"When the current branch is an ancestor of the branch being merged"},
      {"id":"c","text":"Only for the main branch"},
      {"id":"d","text":"When there are no files changed"}],
    "correct": "b",
    "explanation": "Nothing diverged, so the pointer simply moves ahead. If both sides have new commits a merge commit is needed; branch names and file counts do not matter." }
] }
```

### Three-way merge commit

Now `main` has `D` while `feature/cart` still starts from `C`. Git compares
three snapshots: the **merge base** (common ancestor `C`), your tip and their
tip.

```
BEFORE                                  AFTER  git merge feature/cart

 A---B---C---D  <- main                  A---B---C---D---M  <- main
          \                                       \     /
           E---F  <- feature/cart                  E---F  <- feature/cart
```

```bash
git merge feature/cart -m "Merge feature/cart"
git log --oneline --graph
```

Expected output:

```
*   e5a1d77 (HEAD -> main) Merge feature/cart
|\
| * 77d1e0a (feature/cart) Add cart totals
| * 0c4f8e2 Add cart file
* | 2ab9c40 Add greeting
|/
* 5e13a9b Add checkout
```

`M^1` (first parent) is the branch you were on; `M^2` is the branch you merged.

```knowledge-check
{ "questions": [
  { "id": "git-branch-merge-q1", "type": "mcq",
    "prompt": "How many parents does a normal merge commit have?",
    "options": [
      {"id":"a","text":"One"},
      {"id":"b","text":"Two"},
      {"id":"c","text":"Three"},
      {"id":"d","text":"None"}],
    "correct": "b",
    "explanation": "One parent per merged line of history: the target branch and the merged-in branch. Only the root commit has none, normal commits have one, and three or more happens only with rare octopus merges." }
] }
```

### Choosing the shape

```
 without --no-ff (fast-forward)         with --no-ff

 A---B---C---F  <- main                  A---B---C-------M  <- main
 (feature commits look like main's)               \     /
                                                   F---G  <- feature/footer
```

| Command | Result | Typical use |
|---|---|---|
| `git merge X` | Fast-forward if possible, else merge commit | Default |
| `git merge --no-ff X` | Always a merge commit | Keep each feature as one visible unit you can revert |
| `git merge --ff-only X` | Fast-forward or refuse | Updating local main from origin/main safely |
| `git merge --squash X` + `git commit` | One ordinary commit with all X's changes; X's commits are not linked | One clean commit per pull request |

Hosting services offer the same choices as buttons: "Create a merge commit",
"Squash and merge", "Rebase and merge".

```knowledge-check
{ "questions": [
  { "id": "git-branch-noff-q1", "type": "mcq",
    "prompt": "Why use git merge --no-ff?",
    "options": [
      {"id":"a","text":"It is faster"},
      {"id":"b","text":"It records a merge commit so the feature branch stays visible in history even when a fast-forward was possible"},
      {"id":"c","text":"It deletes the feature branch"},
      {"id":"d","text":"It rewrites commit hashes"}],
    "correct": "b",
    "explanation": "The merge commit groups the branch's commits and gives you one commit to revert later. It is not faster, deletes nothing, and leaves existing hashes alone." }
] }
```

## Try it

You want to update your local `main` from `origin/main`, but if you have
accidentally committed on `main` you want Git to stop rather than create a
merge commit. Which command?

<details>
<summary>Show answer</summary>

```bash
git merge --ff-only origin/main
```

or `git pull --ff-only`. If `main` has diverged it fails with
`fatal: Not possible to fast-forward, aborting.`, and nothing changes.

</details>

## Common mistakes

- **Merging in the wrong direction.** `git merge main` while on `feature`
  brings main into feature, not the other way round. Check `git branch` first.
- **Expecting `--squash` to delete or merge the branch.** It only stages the
  combined changes; you still commit, and Git does not record the branch as
  merged, so `git branch -d` will refuse afterwards (use `-D`).
- **Forgetting the merge base.** A three-way merge compares against the common
  ancestor, not just the two tips. That is why unchanged-on-one-side edits merge
  cleanly.

## Remember

- Merge into the branch you are on.
- Fast-forward = slide the label; merge commit = two parents.
- `--no-ff` always records a merge, `--ff-only` refuses to, `--squash` makes one plain commit.
- `M^1` = your side, `M^2` = merged side.

**Self-check:**

1. What is the merge base?
2. Which flag guarantees no merge commit is created?
3. What is the difference between `--no-ff` and `--squash`?
