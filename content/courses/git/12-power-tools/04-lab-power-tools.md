---
kind: lesson
id_key: git/power-tools/lab-worktrees-submodules
course: git
section: power-tools
section_title: "Power Tools: Worktrees, Submodules and Large Repos"
section_position: 12
title: "Lab: Hotfix in a Worktree, Add a Submodule, Shallow-Clone"
position: 3
estimated_minutes: 30
source:
  - git-worktree(1), git-submodule(1), git-clone(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 40
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    umask 000
    git config --global init.defaultBranch main
    git config --global safe.directory '*'
    git config --global user.name "Lab Student"
    git config --global user.email "student@lab.local"
    w=/home/labuser/work; s=/home/labuser/srv/git
    rm -rf $w/shop $w/shop-hotfix $w/big-shallow $s/ui-lib.git $s/big.git /tmp/seed
    mkdir -p $s
    M() { git add -A; GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
    git init -q /tmp/seed && cd /tmp/seed
    echo "button v1" > button.css; M 2024-10-01 "UI lib v1"
    echo "button v2" > button.css; M 2024-10-02 "UI lib v2"
    git init -q --bare $s/ui-lib.git && git push -q $s/ui-lib.git main
    git --git-dir=$s/ui-lib.git symbolic-ref HEAD refs/heads/main
    cd / && rm -rf /tmp/seed && git init -q /tmp/seed && cd /tmp/seed
    for i in 1 2 3 4 5; do echo "data $i" > data.txt; M 2024-10-0$i "Big repo commit $i"; done
    git init -q --bare $s/big.git && git push -q $s/big.git main
    git --git-dir=$s/big.git symbolic-ref HEAD refs/heads/main
    cd / && rm -rf /tmp/seed
    mkdir -p $w/shop && cd $w/shop && git init -q
    echo "# Shop" > README.md; echo "price=9.9" > price.txt; M 2024-10-01 "Initial shop"
    echo "checkout" > checkout.txt; M 2024-10-02 "Add checkout"
    git switch -q -c feature/coupons
    echo "coupons draft" > coupons.txt; M 2024-10-03 "Start coupons"
    echo "half-finished coupon rules" >> coupons.txt
  tasks:
    - id_key: add-worktree
      title: Open a hotfix worktree
      points: 15
      is_stateful: true
      description: You are on feature/coupons in ~/work/shop with uncommitted work. Without touching it, add a worktree at ~/work/shop-hotfix with a new branch hotfix/price created from main.
      verification_script: |
        r=/home/labuser/work/shop
        l=$(git -C $r worktree list --porcelain)
        echo "$l" | grep -qx 'worktree /home/labuser/work/shop-hotfix' &&
        echo "$l" | grep -qx 'branch refs/heads/hotfix/price' &&
        [ "$(git -C /home/labuser/work/shop-hotfix rev-parse HEAD)" = "$(git -C $r rev-parse main)" ] &&
        ! git -C $r diff --quiet -- coupons.txt
      hint_context: From inside ~/work/shop run git worktree add ../shop-hotfix -b hotfix/price main. Your half-finished coupons.txt edit stays where it is.
      explanation_context: A linked worktree is a second working directory that shares the same .git database, with its own branch, index and files.
      solution_script: |
        cd ~/work/shop && git worktree add ../shop-hotfix -b hotfix/price main
    - id_key: hotfix-commit
      title: Commit the hotfix in the worktree
      points: 15
      is_stateful: true
      description: In ~/work/shop-hotfix change price.txt to the single line "price=9.99" and commit it with the message "Fix price rounding". Your feature work in ~/work/shop must stay uncommitted and untouched.
      verification_script: |
        r=/home/labuser/work/shop
        [ "$(git -C $r log -1 --format=%s hotfix/price)" = "Fix price rounding" ] &&
        [ "$(git -C $r show hotfix/price:price.txt)" = "price=9.99" ] &&
        [ "$(git -C $r rev-parse --abbrev-ref HEAD)" = feature/coupons ] &&
        grep -qx 'half-finished coupon rules' $r/coupons.txt
      hint_context: cd ~/work/shop-hotfix, edit the file, git commit -am "Fix price rounding". Then git log --oneline hotfix/price from ~/work/shop shows the same commit.
      explanation_context: Both folders share one object database and one set of refs, so the hotfix commit is instantly visible from the main worktree.
      solution_script: |
        cd ~/work/shop-hotfix
        echo "price=9.99" > price.txt
        git commit -am "Fix price rounding"
    - id_key: remove-worktree
      title: Remove the worktree, keep the branch
      points: 10
      is_stateful: true
      description: The hotfix is committed. Remove the ~/work/shop-hotfix worktree with git worktree remove. The branch hotfix/price must still exist.
      verification_script: |
        r=/home/labuser/work/shop
        [ ! -d /home/labuser/work/shop-hotfix ] &&
        [ "$(git -C $r worktree list --porcelain | grep -c '^worktree ')" = 1 ] &&
        git -C $r rev-parse -q --verify hotfix/price >/dev/null
      hint_context: Run git worktree remove ../shop-hotfix from ~/work/shop (not from inside the folder you are removing).
      explanation_context: remove deletes the folder and Git's bookkeeping for it. Branches and commits live in the shared repository and are not affected.
      solution_script: |
        cd ~/work/shop && git worktree remove ../shop-hotfix
    - id_key: add-submodule
      title: Add a submodule
      points: 20
      is_stateful: true
      description: 'In ~/work/shop add the UI library /home/labuser/srv/git/ui-lib.git as a submodule at vendor/ui-lib, and commit only the submodule (.gitmodules and vendor/ui-lib) with the message "Add ui-lib submodule". Local-path submodules are blocked by default; allow the file transport for that one command.'
      verification_script: |
        r=/home/labuser/work/shop
        [ "$(git -C $r log -1 --format=%s)" = "Add ui-lib submodule" ] &&
        [ "$(git -C $r ls-tree HEAD vendor/ui-lib | cut -d' ' -f1-2)" = "160000 commit" ] &&
        [ "$(git -C $r ls-tree HEAD vendor/ui-lib | cut -f1 | cut -d' ' -f3)" = "$(git --git-dir=/home/labuser/srv/git/ui-lib.git rev-parse main)" ] &&
        git -C $r show HEAD:.gitmodules | grep -q 'url = /home/labuser/srv/git/ui-lib.git'
      hint_context: 'git -c protocol.file.allow=always submodule add /home/labuser/srv/git/ui-lib.git vendor/ui-lib stages both paths; then git commit -m "Add ui-lib submodule" (do not git add -A, or your half-finished coupons edit goes in too).'
      explanation_context: The parent repo stores .gitmodules (path and URL) and a gitlink (mode 160000) pinning one exact commit of the library. Since Git 2.38.1 the file transport is disabled for submodules unless explicitly allowed.
      solution_script: |
        cd ~/work/shop
        git -c protocol.file.allow=always submodule add /home/labuser/srv/git/ui-lib.git vendor/ui-lib
        git commit -m "Add ui-lib submodule"
    - id_key: shallow-clone
      title: Make a shallow clone
      points: 15
      is_stateful: true
      description: Clone /home/labuser/srv/git/big.git into ~/work/big-shallow with only the latest commit (depth 1). Note that --depth is ignored for plain local paths.
      verification_script: |
        r=/home/labuser/work/big-shallow
        [ "$(git -C $r rev-parse --is-shallow-repository 2>/dev/null)" = true ] &&
        [ "$(git -C $r rev-list --count HEAD)" = 1 ] &&
        [ "$(git -C $r log -1 --format=%s)" = "Big repo commit 5" ]
      hint_context: 'git clone --depth 1 /home/labuser/srv/git/big.git prints "warning: --depth is ignored in local clones". Use a file:// URL: git clone --depth 1 file:///home/labuser/srv/git/big.git ~/work/big-shallow.'
      explanation_context: Shallow clones download only the newest commits. For a local path Git normally hard-links the whole object store instead of transferring, so it ignores --depth; the file:// URL forces a real transfer that honours it.
      solution_script: |
        git clone --depth 1 file:///home/labuser/srv/git/big.git ~/work/big-shallow
---

## Why this matters

These three tools solve problems you will meet on bigger teams: an urgent fix
while your work is half done (worktree), a shared library pinned to a version
(submodule), and a slow clone (shallow). The repositories are ready under
`~/work/shop` and `~/srv/git`.

```bash
cd ~/work/shop
git status -s
```

Expected:

```
 M coupons.txt
```

That is your half-finished work. Leave it alone throughout this lab.

## Task 1: open a hotfix worktree

Add `~/work/shop-hotfix` with a new branch `hotfix/price` from `main`.

[[lab-task:1]]

Expected `git worktree list`:

```
/home/labuser/work/shop         1b2c3d4 [feature/coupons]
/home/labuser/work/shop-hotfix  5e6f7a8 [hotfix/price]
```

## Task 2: fix the price there

In `~/work/shop-hotfix`, set `price.txt` to `price=9.99` and commit
`Fix price rounding`.

[[lab-task:2]]

Check from the main folder: `git log --oneline -1 hotfix/price`.

## Task 3: remove the worktree

[[lab-task:3]]

## Task 4: add the UI library as a submodule

Add `/home/labuser/srv/git/ui-lib.git` at `vendor/ui-lib` and commit only the
submodule. Try it first without the `-c` option to see the security error:

```
fatal: transport 'file' not allowed
```

[[lab-task:4]]

Check: `git ls-tree HEAD vendor/ui-lib` shows mode `160000` and type `commit`.

## Task 5: shallow clone

Clone `big.git` into `~/work/big-shallow` with depth 1. Try a plain path first
and read the warning.

[[lab-task:5]]

Expected: `git -C ~/work/big-shallow log --oneline` prints a single commit.

## Remember

- Worktrees: parallel checkouts sharing one repository.
- Submodules pin another repo's exact commit; local paths need `protocol.file.allow`.
- Shallow clones need a real transfer (`file://` locally, or a server URL).
