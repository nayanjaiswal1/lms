---
kind: lesson
id_key: git/troubleshooting/lab-fix-it
course: git
section: troubleshooting
section_title: "Troubleshooting Playbook"
section_position: 13
title: "Lab: Four Git Emergencies"
position: 2
estimated_minutes: 30
source:
  - git-reset(1), git-rm(1), git-reflog(1), git-fsck(1), git-stash(1) manual pages
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
    w=/home/labuser/work/fixit; s=/home/labuser/srv/git
    rm -rf $w $s/fixit.git
    mkdir -p $s $w && git init -q --bare $s/fixit.git
    git --git-dir=$s/fixit.git symbolic-ref HEAD refs/heads/main
    cd $w && git init -q
    M() { git add -A; GIT_AUTHOR_NAME="Lab Student" GIT_AUTHOR_EMAIL=student@lab.local GIT_COMMITTER_NAME="Lab Student" GIT_COMMITTER_EMAIL=student@lab.local GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
    echo "# Fixit" > README.md; echo "notes" > notes.txt; M 2024-11-01 "Initial app"
    echo "port=8080" > settings.txt; echo "API_KEY=abc123" > .env; M 2024-11-02 "Add settings"
    git remote add origin $s/fixit.git && git push -q -u origin main 2>/dev/null
    git switch -q -c feature/export
    echo "id,total" > export.csv; M 2024-11-03 "Add CSV export"
    git switch -q main
    git branch -q -D feature/export
    echo "Report" > report.txt; M 2024-11-04 "Add report header"
    echo "Total: 42" >> report.txt; M 2024-11-05 "Add report totals"
    echo "half-finished idea" >> notes.txt
    git stash push -q -m "idea"
    git stash drop -q
  tasks:
    - id_key: move-to-branch
      title: Move commits made on main to a feature branch
      points: 20
      is_stateful: true
      description: In ~/work/fixit the last two commits on main ("Add report header", "Add report totals") were never pushed and belong on a new branch feature/report. Create that branch with both commits and put main back where origin/main is.
      verification_script: |
        r=/home/labuser/work/fixit
        [ "$(git -C $r log --format=%s -2 feature/report 2>/dev/null | paste -sd,)" = "Add report totals,Add report header" ] &&
        [ "$(git -C $r rev-parse main)" = "$(git -C $r rev-parse origin/main)" ] &&
        [ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ] &&
        [ ! -f $r/report.txt ]
      hint_context: git branch feature/report labels the current commit. Then git reset --hard origin/main moves main back. The commits stay on feature/report.
      explanation_context: A branch is only a label, so you label the misplaced commits first, then move main. Nothing was pushed, so resetting main rewrites nothing anyone else has.
      solution_script: |
        cd ~/work/fixit
        git branch feature/report
        git reset --hard origin/main
    - id_key: untrack-env
      title: Stop tracking a committed .env file
      points: 15
      is_stateful: true
      description: '.env with an API key was committed and pushed in "Add settings" (the key has already been rotated). Stop tracking .env while keeping the file on disk, ignore it, and commit both changes on main with the message "Stop tracking .env".'
      verification_script: |
        r=/home/labuser/work/fixit
        [ "$(git -C $r log -1 --format=%s main)" = "Stop tracking .env" ] &&
        ! git -C $r cat-file -e main:.env 2>/dev/null &&
        git -C $r show main:.gitignore | grep -qx '.env' &&
        [ -f $r/.env ] && git -C $r check-ignore -q .env
      hint_context: git rm --cached .env removes it from the index only. echo .env >> .gitignore, git add .gitignore, then commit.
      explanation_context: Untracking stops future commits from containing .env, but the old commit still has it. That is why rotation came first; rewriting history (git filter-repo) is the optional extra step.
      solution_script: |
        cd ~/work/fixit
        git rm -q --cached .env
        echo ".env" >> .gitignore
        git add .gitignore
        git commit -m "Stop tracking .env"
    - id_key: restore-deleted-branch
      title: Restore a deleted branch
      points: 20
      is_stateful: true
      description: Someone force-deleted the branch feature/export, whose only new commit was "Add CSV export". Recreate feature/export pointing at that commit.
      verification_script: |
        r=/home/labuser/work/fixit
        [ "$(git -C $r log -1 --format=%s feature/export 2>/dev/null)" = "Add CSV export" ] &&
        [ "$(git -C $r show feature/export:export.csv | head -1)" = "id,total" ]
      hint_context: 'git reflog shows "commit: Add CSV export" from when the branch was checked out. git branch feature/export <that hash>.'
      explanation_context: Deleting a branch removes only the ref. The commit stays in the object database and in HEAD's reflog, so a new ref brings it back.
      solution_script: |
        cd ~/work/fixit
        git branch feature/export "$(git reflog --format='%h %gs' | grep 'commit: Add CSV export' | head -1 | cut -d' ' -f1)"
    - id_key: recover-dropped-stash
      title: Recover a dropped stash
      points: 25
      is_stateful: true
      description: A stash named "idea" (an extra line "half-finished idea" in notes.txt) was dropped by mistake. Find the dangling stash commit and apply it so notes.txt contains that line again.
      verification_script: |
        grep -qx 'half-finished idea' /home/labuser/work/fixit/notes.txt
      hint_context: 'git fsck --no-reflogs --unreachable lists dangling commits. Check each with git show -s <hash>; the stash has the subject "On main: idea". Then git stash apply <hash>.'
      explanation_context: A stash is a commit stored under refs/stash. Dropping it removes the ref, and stash entries are not in HEAD's reflog, but the commit object lives on until garbage collection, so fsck can still find it.
      solution_script: |
        cd ~/work/fixit
        h=$(git fsck --no-reflogs --unreachable 2>/dev/null | awk '/commit/ {print $3}' | while read c; do [ "$(git log -1 --format=%s "$c")" = "On main: idea" ] && echo "$c"; done | head -1)
        git stash apply "$h"
---

## Why this matters

These are the emergencies people actually post in team chat. The repository
`~/work/fixit` has all four. Before each fix, run the P-U-S check from the
playbook: **P**ushed? **U**ncommitted? **S**tatus?

```bash
cd ~/work/fixit
git status
git log --oneline --graph --all
```

Expected:

```
* 9c1d2e3 (HEAD -> main) Add report totals
* 4b5a6f7 Add report header
* 2e3f4a5 (origin/main) Add settings
* 1a2b3c4 Initial app
```

## Task 1: commits on the wrong branch

The two report commits are not pushed and belong on `feature/report`.

```
 before: main: ...---S---R1---R2   (origin/main = S)
 after : main: ...---S             feature/report: ...---S---R1---R2
```

[[lab-task:1]]

## Task 2: a committed .env

`.env` was pushed in `Add settings` (assume the key has been rotated). Untrack
it, keep the file, ignore it, commit `Stop tracking .env`.

[[lab-task:2]]

Check: `git status` no longer mentions `.env`, and `cat .env` still works.

## Task 3: a deleted branch

`feature/export` was force-deleted. Find its commit in the reflog and recreate
the branch.

[[lab-task:3]]

Expected reflog line to look for:

```
5d6e7f8 HEAD@{6}: commit: Add CSV export
```

## Task 4: a dropped stash

A stash named `idea` was dropped. Stashes are not in HEAD's reflog, so search
for dangling commits:

```bash
git fsck --no-reflogs --unreachable
git show -s <hash>          # look for "On main: idea"
git stash apply <hash>
```

[[lab-task:4]]

Check: `tail -1 notes.txt` prints `half-finished idea`.

## Remember

- Label first (`git branch`), then move (`reset`).
- Untracking does not remove history; rotation does the real fix.
- Reflog for branches and commits; `fsck --unreachable` for stashes.
