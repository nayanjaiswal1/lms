---
kind: lesson
id_key: git/branch-merge/lesson
course: git
section: branch-merge
section_title: Branching and Merging
section_position: 5
title: "Lab: Branch, Fast-Forward and Merge"
position: 2
estimated_minutes: 30
source:
  - Pro Git book, ch. 3 "Git Branching"
  - git-branch(1), git-switch(1), git-merge(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 40
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    umask 000
    git config --system init.defaultBranch main
    git config --system safe.directory '*'
    git config --system user.name "Lab Student"
    git config --system user.email "student@lab.local"
    rm -rf /home/labuser/work/shop
    mkdir /home/labuser/work/shop && cd /home/labuser/work/shop
    git init -q
    M() { git add -A; GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
    echo "# Shop" > README.md; M 2024-02-01 "Initial commit"
    echo "apple" > products.txt; M 2024-02-02 "Add product list"
    echo "pay" > checkout.txt; M 2024-02-03 "Add checkout"
    git switch -q -c feature/cart
    echo "cart" > cart.txt; M 2024-02-04 "Add cart file"
    echo "cart total" >> cart.txt; M 2024-02-05 "Add cart totals"
    git switch -q main
    chmod -R a+rwX /home/labuser/work/shop
  tasks:
    - id_key: create-branch
      title: Create a branch and commit on it
      points: 15
      is_stateful: true
      description: In ~/work/shop create a branch feature/greeting from main, add greeting.txt and commit it with the message "Add greeting". main must stay untouched.
      verification_script: |
        r=/home/labuser/work/shop
        [ "$(git -C $r log feature/greeting -1 --format=%s)" = "Add greeting" ] &&
        [ "$(git -C $r rev-list --count main)" = 3 ] &&
        [ "$(git -C $r rev-list --count main..feature/greeting)" = 1 ]
      hint_context: git switch -c feature/greeting creates and switches in one step. Check git branch afterwards.
      explanation_context: A branch is only a movable pointer to a commit. Creating one is instant; committing moves just the pointer of the branch you are on.
      solution_script: |
        cd ~/work/shop
        git switch -c feature/greeting
        echo "hello" > greeting.txt
        git add greeting.txt
        git commit -m "Add greeting"
    - id_key: fast-forward
      title: Fast-forward main
      points: 15
      is_stateful: true
      description: Switch back to main and merge feature/greeting. Because main has not moved, Git should fast-forward without creating a merge commit.
      verification_script: |
        r=/home/labuser/work/shop
        [ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ] &&
        [ "$(git -C $r rev-parse main)" = "$(git -C $r rev-parse feature/greeting)" ] &&
        [ "$(git -C $r rev-list --merges --count main)" = 0 ] &&
        [ "$(git -C $r rev-list --count main)" = 4 ]
      hint_context: Merge into the branch you are standing on. git switch main first, then git merge feature/greeting.
      explanation_context: When the target branch is an ancestor of the branch being merged, Git just moves the pointer forward. No new commit is needed.
      solution_script: |
        cd ~/work/shop
        git switch main
        git merge feature/greeting
    - id_key: true-merge
      title: Merge diverged work
      points: 20
      is_stateful: true
      description: feature/cart was started before the greeting commit, so history has diverged. Merge it into main with the merge-commit message "Merge feature/cart".
      verification_script: |
        r=/home/labuser/work/shop
        [ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ] &&
        [ "$(git -C $r log -1 --format=%s)" = "Merge feature/cart" ] &&
        [ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
        git -C $r merge-base --is-ancestor feature/cart HEAD &&
        git -C $r merge-base --is-ancestor feature/greeting HEAD &&
        [ -f $r/cart.txt ] && [ -f $r/greeting.txt ]
      hint_context: git merge feature/cart -m "Merge feature/cart" - a three-way merge since both sides have new commits.
      explanation_context: With work on both sides, Git finds the common ancestor and creates a merge commit with two parents. Both lines of history are preserved.
      solution_script: |
        cd ~/work/shop
        git merge --no-edit -m "Merge feature/cart" feature/cart
    - id_key: no-ff-merge
      title: Force a merge commit with --no-ff
      points: 20
      is_stateful: true
      description: Create branch feature/footer from main with one commit "Add footer" (file footer.txt). Switch to main and merge it using --no-ff with the message "Merge feature/footer", even though a fast-forward was possible.
      verification_script: |
        r=/home/labuser/work/shop
        [ "$(git -C $r log -1 --format=%s)" = "Merge feature/footer" ] &&
        [ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
        [ "$(git -C $r log HEAD^2 -1 --format=%s)" = "Add footer" ] &&
        [ "$(git -C $r log HEAD^1 -1 --format=%s)" = "Merge feature/cart" ]
      hint_context: Branch, commit, switch back to main, then git merge --no-ff feature/footer -m "...". HEAD^1 is the main side, HEAD^2 the merged branch.
      explanation_context: --no-ff always records a merge commit, so the history still shows that a group of commits belonged to one feature branch.
      solution_script: |
        cd ~/work/shop
        git switch -c feature/footer
        echo "footer" > footer.txt
        git add footer.txt
        git commit -m "Add footer"
        git switch main
        git merge --no-ff --no-edit -m "Merge feature/footer" feature/footer
    - id_key: delete-merged
      title: Clean up merged branches
      points: 10
      is_stateful: true
      description: Delete the three merged feature branches (feature/greeting, feature/cart, feature/footer) so only main remains. The commits stay in history.
      verification_script: |
        r=/home/labuser/work/shop
        [ "$(git -C $r for-each-ref --format='%(refname:short)' refs/heads)" = main ] &&
        git -C $r log --format=%s | grep -qx "Add footer" &&
        git -C $r log --format=%s | grep -qx "Add cart totals"
      hint_context: git branch -d refuses to delete unmerged branches - that is a safety net. You can pass several names.
      explanation_context: Deleting a branch removes only the pointer. Because the commits are reachable from main they are never lost.
      solution_script: |
        cd ~/work/shop
        git branch -d feature/greeting feature/cart feature/footer
---

## Why this matters

The `~/work/shop` repository has `main` (three commits) and `feature/cart`
(two commits started from `main`). You will create a branch, fast-forward,
make a true merge, force a merge commit with `--no-ff`, and clean up.

Start by looking:

```bash
cd ~/work/shop
git log --oneline --graph --all
```

## Task 1: branch and commit

Create `feature/greeting` from `main`, add `greeting.txt`, commit it as
`Add greeting`. `main` must not move.

[[lab-task:1]]

Expected graph:

```
* 2ab9c40 (HEAD -> feature/greeting) Add greeting
| * 77d1e0a (feature/cart) Add cart totals
| * 0c4f8e2 Add cart file
|/
* 5e13a9b (main) Add checkout
```

## Task 2: fast-forward

Switch to `main` and merge `feature/greeting`. `main` has not moved, so this is
a fast-forward.

[[lab-task:2]]

Expected output contains `Fast-forward`.

## Task 3: a real merge

`feature/cart` started before the greeting commit, so history has diverged.
Merge it into `main` with the message `Merge feature/cart`.

[[lab-task:3]]

Expected graph:

```
*   e5a1d77 (HEAD -> main) Merge feature/cart
|\
| * 77d1e0a (feature/cart) Add cart totals
| * 0c4f8e2 Add cart file
* | 2ab9c40 (feature/greeting) Add greeting
|/
* 5e13a9b Add checkout
```

## Task 4: --no-ff

Create `feature/footer` from `main` with one commit `Add footer`
(`footer.txt`). Merge it into `main` with `--no-ff` and the message
`Merge feature/footer`, even though a fast-forward was possible.

[[lab-task:4]]

Expected `git log --oneline --graph -4`:

```
*   a41c0be (HEAD -> main) Merge feature/footer
|\
| * 3f9d812 (feature/footer) Add footer
|/
*   e5a1d77 Merge feature/cart
```

## Task 5: clean up

Delete the three merged feature branches. Only `main` remains; every commit
stays in history.

[[lab-task:5]]

Expected `git branch`:

```
* main
```

## Remember

- Look at the graph before and after each merge.
- `-d` deletes only merged branches; that is your safety net.
