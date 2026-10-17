---
kind: lesson
id_key: git/undo-recovery/lesson
course: git
section: undo-recovery
section_title: "Undo and Recovery"
section_position: 9
title: "Lab: Undo Anything"
position: 6
estimated_minutes: 50
source:
  - Pro Git book, ch. 7.3 "Stashing and Cleaning", ch. 7.7 "Reset Demystified"
  - git-restore(1), git-reset(1), git-revert(1), git-reflog(1), git-cherry-pick(1), git-stash(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 60
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    umask 000
    git config --global init.defaultBranch main
    git config --global safe.directory '*'
    git config --global user.name "Lab Student"
    git config --global user.email "student@lab.local"
    rm -rf /home/labuser/work/ledger
    mkdir /home/labuser/work/ledger && cd /home/labuser/work/ledger
    git init -q
    A() { git add -A; GIT_AUTHOR_NAME="$3" GIT_AUTHOR_EMAIL="$4" GIT_COMMITTER_NAME="$3" GIT_COMMITTER_EMAIL="$4" GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
    M() { A "$1" "$2" "Maya Lead" maya@example.com; }
    echo "# Ledger" > ledger.txt;   M 2024-05-01 "Create ledger"
    echo "Jan: 100" >> ledger.txt;  M 2024-05-02 "Add January entries"
    echo "Feb: 120" >> ledger.txt;  M 2024-05-03 "Add February entries"
    echo "Mar: 90" >> ledger.txt;   M 2024-05-04 "Add Marsh entries"
    git switch -q -c feature/bonus
    echo "bonus: 10" > bonus.txt;   M 2024-05-05 "Add bonus file"
    git switch -q main
    git switch -q -c feature/audit
    echo "audit log" > auditlog.txt;  A 2024-05-06 "Add audit log" "Priya Auditor" priya@example.com
    echo "audit summary" > summary.txt; A 2024-05-07 "Add audit summary" "Priya Auditor" priya@example.com
    git switch -q main
    echo "GARBAGE" >> ledger.txt
    echo "api-key=abc" > secret.txt
    git add secret.txt
    chmod -R a+rwX /home/labuser/work/ledger
  tasks:
    - id_key: restore-file
      title: Discard an unwanted edit
      points: 10
      is_stateful: true
      description: In ~/work/ledger someone left a junk line (GARBAGE) in ledger.txt. Throw that uncommitted edit away so ledger.txt matches the last commit again.
      verification_script: |
        r=/home/labuser/work/ledger
        git -C $r diff --quiet -- ledger.txt && ! grep -q GARBAGE $r/ledger.txt
      hint_context: git restore <file> copies the file from the index back into the working tree. It discards the edit permanently, so read git diff first.
      explanation_context: git restore (the modern replacement for git checkout -- file) overwrites the working-tree file from the index. Uncommitted edits are not in any commit, so this cannot be undone.
      solution_script: |
        cd ~/work/ledger
        git restore ledger.txt
    - id_key: unstage-file
      title: Unstage a file you must not commit
      points: 10
      is_stateful: true
      description: secret.txt was staged by accident. Remove it from the staging area but keep the file on disk, untracked.
      verification_script: |
        r=/home/labuser/work/ledger
        git -C $r diff --cached --quiet &&
        [ -f $r/secret.txt ] &&
        git -C $r ls-files --others --exclude-standard | grep -qx secret.txt
      hint_context: git restore --staged <file> undoes git add without touching the file itself.
      explanation_context: restore --staged copies HEAD's version of the path into the index, so the file drops out of the next commit while your working copy stays intact.
      solution_script: |
        cd ~/work/ledger
        git restore --staged secret.txt
    - id_key: reset-soft
      title: Re-do the last commit with reset --soft
      points: 15
      is_stateful: true
      description: The last commit message "Add Marsh entries" has a typo. Move the branch back one commit while keeping the changes staged (reset --soft), then commit again with the message "Add March entries". There must still be exactly four commits on main.
      verification_script: |
        r=/home/labuser/work/ledger
        [ "$(git -C $r log -1 --format=%s)" = "Add March entries" ] &&
        [ "$(git -C $r rev-list --count HEAD)" = 4 ] &&
        git -C $r diff --quiet HEAD &&
        git -C $r reflog | grep -q 'reset: moving to'
      hint_context: git reset --soft HEAD~1 moves only the branch pointer; the old commit's changes stay staged, ready for git commit -m.
      explanation_context: --soft moves HEAD (and the branch) but leaves the index and working tree alone, so everything the undone commit contained is still staged.
      solution_script: |
        cd ~/work/ledger
        git reset --soft HEAD~1
        git commit -m "Add March entries"
    - id_key: reset-mixed
      title: Unstage everything with reset --mixed
      points: 15
      is_stateful: true
      description: Step main back to "Add February entries" with a mixed reset, so the March line remains in ledger.txt as an unstaged working-tree change. Nothing may be staged.
      verification_script: |
        r=/home/labuser/work/ledger
        [ "$(git -C $r log -1 --format=%s)" = "Add February entries" ] &&
        git -C $r diff --cached --quiet &&
        ! git -C $r diff --quiet -- ledger.txt &&
        grep -qx 'Mar: 90' $r/ledger.txt &&
        [ "$(git -C $r reflog | grep -c 'reset: moving to')" -ge 2 ]
      hint_context: git reset (default is --mixed) HEAD~1. git status then lists ledger.txt under "Changes not staged for commit".
      explanation_context: --mixed moves HEAD and resets the index to match, but keeps the working tree. Your edits survive as plain unstaged modifications.
      solution_script: |
        cd ~/work/ledger
        git reset --mixed HEAD~1
    - id_key: recommit-and-april
      title: Recommit March and add April
      points: 10
      is_stateful: true
      description: 'Commit the March change again with the message "Add March entries", then create april.txt containing "Apr: 200" and commit it as "Add April entries".'
      verification_script: |
        r=/home/labuser/work/ledger
        [ "$(git -C $r log --format=%s -3 | paste -sd,)" = "Add April entries,Add March entries,Add February entries" ] &&
        [ "$(git -C $r rev-list --count HEAD)" = 5 ] &&
        git -C $r diff --quiet HEAD
      hint_context: git commit -am commits tracked-file changes. april.txt is new, so git add it first.
      explanation_context: This sets up a history with two commits you are about to throw away, so you can practise recovering them.
      solution_script: |
        cd ~/work/ledger
        git commit -am "Add March entries"
        echo "Apr: 200" > april.txt
        git add april.txt
        git commit -m "Add April entries"
    - id_key: reset-hard
      title: Throw work away with reset --hard
      points: 10
      is_stateful: true
      description: 'Discard the last two commits AND their changes: reset --hard so main is back at "Add February entries" with no March line and no april.txt.'
      verification_script: |
        r=/home/labuser/work/ledger
        [ "$(git -C $r log -1 --format=%s)" = "Add February entries" ] &&
        git -C $r diff --quiet HEAD &&
        [ ! -f $r/april.txt ] &&
        ! grep -q 'Mar: 90' $r/ledger.txt
      hint_context: git reset --hard HEAD~2 rewinds the branch two commits and overwrites the working tree.
      explanation_context: --hard moves HEAD, resets the index and overwrites the working tree. The commits are no longer on any branch, but Git still remembers them in the reflog for a while.
      solution_script: |
        cd ~/work/ledger
        git reset --hard HEAD~2
    - id_key: reflog-recover
      title: Recover the lost commits from the reflog
      points: 20
      is_stateful: true
      description: Oops - you needed April after all. Use git reflog to find the commit "Add April entries" and move main back to it so both the March and April commits are restored.
      verification_script: |
        r=/home/labuser/work/ledger
        [ "$(git -C $r log -1 --format=%s)" = "Add April entries" ] &&
        [ -f $r/april.txt ] &&
        git -C $r log --format=%s | grep -qx "Add March entries" &&
        git -C $r diff --quiet HEAD
      hint_context: git reflog lists every position HEAD has been at. Find the line "commit - Add April entries" and git reset --hard <that hash>.
      explanation_context: The reflog is a private diary of where your refs pointed. Commits unreachable from any branch survive until garbage collection (90 days by default), so a bad reset is recoverable.
      solution_script: |
        cd ~/work/ledger
        sha=$(git reflog --format='%h %gs' | grep 'commit: Add April entries' | head -1 | cut -d' ' -f1)
        git reset --hard "$sha"
    - id_key: revert-commit
      title: Revert a published commit
      points: 15
      is_stateful: true
      description: The March entries were wrong, but history is already shared so you must not rewrite it. Revert the commit "Add March entries" with git revert (default message), keeping April.
      verification_script: |
        r=/home/labuser/work/ledger
        [ "$(git -C $r log -1 --format=%s)" = 'Revert "Add March entries"' ] &&
        ! grep -q 'Mar: 90' $r/ledger.txt &&
        [ -f $r/april.txt ] &&
        git -C $r log --format=%s | grep -qx "Add March entries"
      hint_context: git revert <hash-of-March-commit> --no-edit. Find the hash with git log --oneline.
      explanation_context: revert creates a NEW commit that applies the inverse patch. The original commit stays in history, so it is safe on shared branches, unlike reset.
      solution_script: |
        cd ~/work/ledger
        git revert --no-edit "$(git log --format=%h --grep='^Add March entries$' -1)"
    - id_key: merge-bonus
      title: Merge a feature branch
      points: 10
      is_stateful: true
      description: Merge feature/bonus into main with --no-ff and the message "Merge feature/bonus".
      verification_script: |
        r=/home/labuser/work/ledger
        [ "$(git -C $r log -1 --format=%s)" = "Merge feature/bonus" ] &&
        [ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
        [ -f $r/bonus.txt ]
      hint_context: git merge --no-ff feature/bonus -m "Merge feature/bonus".
      explanation_context: This creates a merge commit with two parents, which is what makes reverting a merge special in the next task.
      solution_script: |
        cd ~/work/ledger
        git merge --no-ff --no-edit -m "Merge feature/bonus" feature/bonus
    - id_key: revert-merge
      title: Revert a merge commit with -m 1
      points: 20
      is_stateful: true
      description: The bonus feature must come out. Revert the merge commit itself. A merge has two parents so Git needs to know which side to keep - use mainline parent 1 (the main side).
      verification_script: |
        r=/home/labuser/work/ledger
        [ "$(git -C $r log -1 --format=%s)" = 'Revert "Merge feature/bonus"' ] &&
        [ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 2 ] &&
        [ ! -f $r/bonus.txt ] &&
        git -C $r merge-base --is-ancestor feature/bonus HEAD
      hint_context: git revert -m 1 HEAD --no-edit. Without -m Git refuses because it cannot tell which parent is the mainline.
      explanation_context: -m 1 says "undo the changes relative to parent 1", i.e. everything the merge brought in from the other branch. Note that Git now considers that branch already merged, so re-merging it later needs the revert reverted first.
      solution_script: |
        cd ~/work/ledger
        git revert -m 1 --no-edit HEAD
    - id_key: cherry-pick-one
      title: Cherry-pick a single commit
      points: 15
      is_stateful: true
      description: feature/audit has two commits. Bring only "Add audit summary" onto main with cherry-pick, leaving auditlog.txt behind. The original author must be preserved.
      verification_script: |
        r=/home/labuser/work/ledger
        [ "$(git -C $r log -1 --format=%s)" = "Add audit summary" ] &&
        [ "$(git -C $r log -1 --format=%an)" = "Priya Auditor" ] &&
        [ -f $r/summary.txt ] && [ ! -f $r/auditlog.txt ] &&
        [ "$(git -C $r rev-parse HEAD)" != "$(git -C $r rev-parse feature/audit)" ]
      hint_context: Find the hash with git log --oneline feature/audit, then git cherry-pick <hash> while on main.
      explanation_context: cherry-pick re-applies one commit's diff on top of the current branch as a brand-new commit (new hash), keeping the original author and message.
      solution_script: |
        cd ~/work/ledger
        git cherry-pick "$(git log --format=%h --grep='^Add audit summary$' -1 feature/audit)"
    - id_key: stash-save
      title: Stash work in progress
      points: 10
      is_stateful: true
      description: Append the line "WIP total" to ledger.txt, then stash it with the message "wip total" so the working tree is clean again.
      verification_script: |
        r=/home/labuser/work/ledger
        git -C $r stash list | grep -q 'wip total' &&
        git -C $r diff --quiet HEAD &&
        ! grep -q 'WIP total' $r/ledger.txt
      hint_context: git stash push -m "wip total" saves tracked changes and restores a clean tree.
      explanation_context: A stash is a commit stored outside your branches. It lets you switch context quickly and come back later.
      solution_script: |
        cd ~/work/ledger
        echo "WIP total" >> ledger.txt
        git stash push -m "wip total"
    - id_key: stash-pop
      title: Bring the stash back
      points: 10
      is_stateful: true
      description: Re-apply the stashed change and drop it from the stash list in one step.
      verification_script: |
        r=/home/labuser/work/ledger
        [ -z "$(git -C $r stash list)" ] &&
        grep -qx 'WIP total' $r/ledger.txt
      hint_context: git stash pop applies the newest stash and removes it; git stash apply would keep it.
      explanation_context: pop = apply + drop. If applying hits a conflict, the stash is kept so you do not lose it.
      solution_script: |
        cd ~/work/ledger
        git stash pop
---

## Why this matters

`~/work/ledger` is a small accounting repo in a messy state: a junk line in
`ledger.txt`, a secret file staged by accident, a typo in a commit message, and
two feature branches. You will use every undo from this section, in the order
you would meet them on the job.

```bash
cd ~/work/ledger
git status
git log --oneline --graph --all
```

## Part 1: uncommitted changes

**Task 1.** Throw away the uncommitted `GARBAGE` line in `ledger.txt`.

[[lab-task:1]]

**Task 2.** Unstage `secret.txt` but keep it on disk.

[[lab-task:2]]

Expected `git status -s` afterwards:

```
?? secret.txt
```

## Part 2: reset

**Task 3.** The last commit says `Add Marsh entries`. Use `reset --soft` and
recommit as `Add March entries` (still four commits).

[[lab-task:3]]

**Task 4.** Step back to `Add February entries` with a **mixed** reset so the
March line stays as an unstaged edit.

[[lab-task:4]]

Expected `git status -s`:

```
 M ledger.txt
```

**Task 5.** Commit March again (`Add March entries`), then add `april.txt`
containing `Apr: 200` as `Add April entries`.

[[lab-task:5]]

**Task 6.** Throw away both commits and their changes with `reset --hard`.

[[lab-task:6]]

Expected: `HEAD is now at 4be2c19 Add February entries`.

## Part 3: recover

**Task 7.** You needed April after all. Find it in the reflog and move `main`
back to it.

[[lab-task:7]]

Expected `git reflog` top lines:

```
4be2c19 HEAD@{0}: reset: moving to HEAD~2
a91d6f3 HEAD@{1}: commit: Add April entries
```

## Part 4: shared-history undo

Pretend `main` is already pushed from here on, so no more resets.

**Task 8.** Revert `Add March entries` (keep April).

[[lab-task:8]]

**Task 9.** Merge `feature/bonus` with `--no-ff` and the message
`Merge feature/bonus`.

[[lab-task:9]]

**Task 10.** The bonus feature must come out: revert the merge commit, keeping
the main side (`-m 1`).

[[lab-task:10]]

Expected:

```
[main 7ad03ce] Revert "Merge feature/bonus"
 1 file changed, 1 deletion(-)
 delete mode 100644 bonus.txt
```

## Part 5: copy and park

**Task 11.** Bring only `Add audit summary` from `feature/audit` onto `main`.

[[lab-task:11]]

Check: `git log -1 --format='%an'` prints `Priya Auditor`.

**Task 12.** Append `WIP total` to `ledger.txt` and stash it with the message
`wip total`.

[[lab-task:12]]

Expected `git stash list`:

```
stash@{0}: On main: wip total
```

**Task 13.** Bring the stash back and drop it in one step.

[[lab-task:13]]

## Remember

| Situation | Command |
|---|---|
| Discard an uncommitted edit | `git restore <file>` |
| Unstage | `git restore --staged <file>` |
| Redo local commits | `git reset --soft` / `--mixed` |
| Drop local commits | `git reset --hard` (then reflog if wrong) |
| Undo a pushed commit | `git revert` (`-m 1` for merges) |
| Copy one commit | `git cherry-pick` |
| Park unfinished work | `git stash push -m` / `pop` |
