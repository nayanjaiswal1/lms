---
kind: lesson
id_key: git/undo-recovery/lesson
course: git
section: undo-recovery
section_title: Undo and Recovery
section_position: 8
title: restore, reset, revert, reflog, cherry-pick and stash
position: 0
estimated_minutes: 60
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
    git config --system init.defaultBranch main
    git config --system safe.directory '*'
    git config --system user.name "Lab Student"
    git config --system user.email "student@lab.local"
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

> **"I just deleted my work."** Everyone says it once. After this section you will know which undo to reach for, and that the reflog remembers almost everything.

## restore: discard or unstage

`git restore` fixes the working tree and the index without moving any branch.

```
 BEFORE                                   AFTER
 HEAD   : ledger v1                       HEAD   : ledger v1
 index  : ledger v1                       index  : ledger v1
 working: ledger v1 + GARBAGE             working: ledger v1       git restore ledger.txt

 git restore --staged secret.txt:  index loses the file, working copy untouched
```

```bash
cd ~/work/ledger
git status
git restore ledger.txt
git restore --staged secret.txt
```

[[lab-task:1]]
[[lab-task:2]]

What you should see:

```
$ git status -s
 M ledger.txt
A  secret.txt
(after both restores)
?? secret.txt
```

```knowledge-check
{ "questions": [
  { "id": "git-undo-restore-q1", "type": "mcq",
    "prompt": "Which command removes a file from the staging area without deleting your edits?",
    "options": [
      {"id":"a","text":"git restore --staged <file>"},
      {"id":"b","text":"git restore <file>"},
      {"id":"c","text":"git reset --hard"},
      {"id":"d","text":"git clean -f"}],
    "correct": "a",
    "explanation": "Plain git restore <file> would discard the working-tree edits instead." }
] }
```

## reset: soft, mixed, hard

`reset` moves the current branch to another commit, and then decides how much else to rewind:

```
              moves HEAD    resets INDEX    overwrites WORKING TREE
 --soft           yes            no                 no
 --mixed (default) yes           yes                no
 --hard           yes            yes                yes   (destructive)
```

```
BEFORE: A---B---C  <- main (HEAD)         git reset X HEAD~1

 --soft :  A---B  <- main   index = C's content (staged)   working = C's content
 --mixed:  A---B  <- main   index = B              working = C's content (unstaged)
 --hard :  A---B  <- main   index = B              working = B      (C's changes gone)
           C is now unreachable (but in the reflog)
```

```bash
git reset --soft HEAD~1 && git commit -m "Add March entries"   # fix a commit message
git reset --mixed HEAD~1                                      # unstage and keep edits
git commit -am "Add March entries"
git reset --hard HEAD~2                                       # drop commits AND edits
```

[[lab-task:3]]
[[lab-task:4]]
[[lab-task:5]]
[[lab-task:6]]

What you should see after `git reset --hard HEAD~2`:

```
HEAD is now at 4be2c19 Add February entries
```

```knowledge-check
{ "questions": [
  { "id": "git-undo-reset-q1", "type": "mcq",
    "prompt": "After git reset --soft HEAD~1, where do the undone commit's changes live?",
    "options": [
      {"id":"a","text":"Staged in the index"},
      {"id":"b","text":"Unstaged in the working tree"},
      {"id":"c","text":"Deleted"},
      {"id":"d","text":"In a stash"}],
    "correct": "a",
    "explanation": "--soft leaves index and working tree alone; --mixed unstages; --hard discards." },
  { "id": "git-undo-reset-q2", "type": "mcq",
    "prompt": "Which reset mode can destroy uncommitted work?",
    "options": [
      {"id":"a","text":"--soft"},
      {"id":"b","text":"--mixed"},
      {"id":"c","text":"--hard"},
      {"id":"d","text":"None of them"}],
    "correct": "c",
    "explanation": "--hard overwrites the working tree, and uncommitted edits are not in the reflog." }
] }
```

## reflog: the safety net

`git reflog` records every move of HEAD. After a `reset --hard` the commits are unreachable from
any branch but still reachable via the reflog.

```
 git reflog
 4be2c19 HEAD@{0}: reset: moving to HEAD~2
 a91d6f3 HEAD@{1}: commit: Add April entries      <-- the "lost" commit
 5c07b8e HEAD@{2}: commit: Add March entries

 git reset --hard a91d6f3     main points at April again:  A---B---C---D---E <- main
```

```bash
git reflog
git reset --hard <hash of "commit: Add April entries">
```

[[lab-task:7]]

What you should see:

```
HEAD is now at a91d6f3 Add April entries
```

```knowledge-check
{ "questions": [
  { "id": "git-undo-reflog-q1", "type": "mcq",
    "prompt": "You ran git reset --hard and lost commits. What is your first move?",
    "options": [
      {"id":"a","text":"Re-clone the repo"},
      {"id":"b","text":"git reflog to find the old commit hash, then reset or branch to it"},
      {"id":"c","text":"git gc --prune=now"},
      {"id":"d","text":"Nothing - it is gone"}],
    "correct": "b",
    "explanation": "The reflog keeps the previous positions of HEAD (for 90 days by default for reachable-once commits)." }
] }
```

## revert: undo safely on shared history

`reset` rewrites history; `revert` adds a new commit that undoes an old one.

```
BEFORE                               AFTER git revert C

 A---B---C---D  <- main               A---B---C---D---C'  <- main
                                      C' = inverse of C   (C stays in history)
```

For a merge commit there are two parents, so tell Git which one is the mainline:

```
        M  <- main (merge of feature into main)       git revert -m 1 M
       / \                                             -m 1 = keep parent 1 (main's side),
      B   F  <- feature                                undo everything F brought in
```

```bash
git revert --no-edit <hash of "Add March entries">
git merge --no-ff feature/bonus -m "Merge feature/bonus"
git revert -m 1 --no-edit HEAD
```

[[lab-task:8]]
[[lab-task:9]]
[[lab-task:10]]

What you should see:

```
[main 7ad03ce] Revert "Merge feature/bonus"
 Date: ...
 1 file changed, 1 deletion(-)
 delete mode 100644 bonus.txt
```

```knowledge-check
{ "questions": [
  { "id": "git-undo-revert-q1", "type": "mcq",
    "prompt": "Why is revert preferred over reset on a branch teammates already pulled?",
    "options": [
      {"id":"a","text":"It adds a new commit instead of rewriting history, so nobody's clone diverges"},
      {"id":"b","text":"It is faster"},
      {"id":"c","text":"It deletes the original commit"},
      {"id":"d","text":"It works without a repository"}],
    "correct": "a",
    "explanation": "Rewriting shared history forces everyone else to repair their branches." },
  { "id": "git-undo-revert-q2", "type": "mcq",
    "prompt": "What does git revert -m 1 <merge> keep?",
    "options": [
      {"id":"a","text":"The side of parent 1 (the branch the merge was made on) and undoes what the other parent brought in"},
      {"id":"b","text":"Only the other parent's changes"},
      {"id":"c","text":"Nothing"},
      {"id":"d","text":"Both sides"}],
    "correct": "a",
    "explanation": "-m picks the mainline parent; changes relative to it are inverted." }
] }
```

## cherry-pick: borrow one commit

```
BEFORE                                AFTER  git switch main; git cherry-pick S

 main:    A---B---C                    main:    A---B---C---S'   (S' = copy of S)
 audit:        \                       audit:        \
                L---S                                 L---S   (unchanged)
```

```bash
git log --oneline feature/audit
git cherry-pick <hash of "Add audit summary">
```

[[lab-task:11]]

What you should see:

```
[main 3b9f1a2] Add audit summary
 Author: Priya Auditor <priya@example.com>
 1 file changed, 1 insertion(+)
```

```knowledge-check
{ "questions": [
  { "id": "git-undo-pick-q1", "type": "mcq",
    "prompt": "A cherry-picked commit has the same hash as the original.",
    "options": [
      {"id":"a","text":"True"},
      {"id":"b","text":"False - it is a new commit with a different parent, so a different hash"}],
    "correct": "b",
    "explanation": "The diff and message are copied but the commit identity (parent, date) differs." }
] }
```

## stash: park work in progress

```
 working tree dirty ----git stash push -m "wip total"----> working tree clean
                                     stash@{0} holds the edits
 later: git stash pop  ------------------------------------> edits are back, stash entry dropped
```

```bash
echo "WIP total" >> ledger.txt
git stash push -m "wip total"
git stash list
git stash pop
```

[[lab-task:12]]
[[lab-task:13]]

What you should see from `git stash list`:

```
stash@{0}: On main: wip total
```

```knowledge-check
{ "questions": [
  { "id": "git-undo-stash-q1", "type": "mcq",
    "prompt": "What is the difference between git stash pop and git stash apply?",
    "options": [
      {"id":"a","text":"pop applies and removes the stash entry; apply keeps it"},
      {"id":"b","text":"pop deletes the repo"},
      {"id":"c","text":"apply only works on tags"},
      {"id":"d","text":"There is none"}],
    "correct": "a",
    "explanation": "apply is useful when you want to apply the same stash on several branches." }
] }
```

> **Next:** now the reverse - something is broken on main and nobody knows when it started. Time to be a detective.
