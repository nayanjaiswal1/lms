---
kind: lesson
id_key: git/power-tools/worktrees
course: git
section: power-tools
section_title: "Power Tools: Worktrees, Submodules and Large Repos"
section_position: 12
title: "Worktrees: Several Branches Checked Out at Once"
position: 0
estimated_minutes: 7
source:
  - git-worktree(1) manual page
---

## Why this matters

You are deep in a feature with a running dev server and half-edited files.
An urgent hotfix arrives. Stashing, switching, rebuilding, then switching back
is slow and risky. A **worktree** gives you a second folder with another branch
checked out, sharing the same repository. Fix the bug there; your feature
folder is untouched.

## Mental model: two desks, one filing cabinet

One `.git` database (the filing cabinet), several working directories (desks),
each with its own branch, index and files. Commits made at any desk land in the
same cabinet, so every desk sees them immediately. No second clone, no second
download.

```
 ~/work/shop          (main worktree)     branch feature/coupons
 ~/work/shop-hotfix   (linked worktree)   branch hotfix/price
        \_______________ share _______________/
                     ~/work/shop/.git
```

## See it work

### Add a worktree

```bash
cd ~/work/shop
git worktree add ../shop-hotfix -b hotfix/price main
git worktree list
```

What this does: creates folder `../shop-hotfix`, creates branch
`hotfix/price` from `main`, and checks it out there. Expected output:

```
Preparing worktree (new branch 'hotfix/price')
HEAD is now at c46b46c Add checkout
/home/labuser/work/shop         c46b46c [feature/coupons]
/home/labuser/work/shop-hotfix  c46b46c [hotfix/price]
```

### Work in it

```bash
cd ../shop-hotfix
# fix, test, commit as usual
git commit -am "Fix price rounding"
git push -u origin hotfix/price
cd ../shop
git log --oneline hotfix/price -1      # the commit is visible here too
```

### Clean up

```bash
git worktree remove ../shop-hotfix     # deletes the folder (refuses if it has uncommitted changes)
git worktree prune                      # forget worktrees whose folders you deleted by hand
```

The branch `hotfix/price` stays; only the extra folder goes.

### The one rule

A branch can be checked out in **only one** worktree at a time:

```
fatal: 'main' is already used by worktree at '/home/labuser/work/shop'
```

That prevents two folders from moving the same branch in different directions.
Use `--detach` if you just want to look at a commit.

### Good uses

- Hotfix or review a PR without disturbing current work.
- Run a long test suite on one branch while coding on another.
- Compare behaviour of two versions side by side.
- Give each AI coding agent or script its own isolated checkout.

## Try it

You want to review a colleague's branch `feature/search` (already fetched) in a
separate folder without creating a new local branch name. What command?

<details>
<summary>Show answer</summary>

```bash
git worktree add ../review-search feature/search
```

If a local `feature/search` does not exist yet, Git creates it tracking
`origin/feature/search` (like `git switch`). Use
`git worktree add --detach ../review origin/feature/search` to avoid a local
branch entirely.

</details>

## Common mistakes

- **Deleting the folder with `rm -rf` and forgetting.** Git still thinks the
  branch is checked out there; run `git worktree prune`.
- **Cloning the repo twice instead.** Two clones double disk use and do not see
  each other's commits without fetching.
- **Creating a worktree inside the main working tree.** Put it next to it
  (`../name`) so the main tree does not see it as untracked files.

## Remember

- `git worktree add <path> -b <new-branch> <start>` = new folder + branch.
- All worktrees share one `.git`: commits are visible everywhere at once.
- One branch per worktree at a time.
- `git worktree list`, `remove`, `prune` to manage.

**Self-check:**

1. What is shared between worktrees, and what is separate?
2. Why can't `main` be checked out in two worktrees?
3. What does `git worktree prune` clean up?
