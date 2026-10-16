---
kind: lesson
id_key: git/merge-conflicts/lesson
course: git
section: merge-conflicts
section_title: Merge Conflicts
section_position: 6
title: "Lab: Resolve, Abort and Remember Conflicts"
position: 3
estimated_minutes: 30
source:
  - Pro Git book, ch. 3.2 "Basic Merging" and ch. 7.8 "Rerere"
  - git-merge(1), git-rerere(1) manual pages
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
    rm -rf /home/labuser/work/config-app
    mkdir /home/labuser/work/config-app && cd /home/labuser/work/config-app
    git init -q
    M() { git add -A; GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
    printf 'name=app\ntimeout=30\nlog=info\n' > app.conf
    printf 'level=info\n' > logging.conf
    M 2024-03-01 "Initial config"
    git switch -q -c feature/timeout
    printf 'name=app\ntimeout=45\nlog=info\nretries=3\n' > app.conf
    M 2024-03-02 "Raise timeout to 45 and add retries"
    git switch -q main
    git switch -q -c feature/log-level
    printf 'level=debug\n' > logging.conf
    M 2024-03-03 "Enable debug logging"
    git switch -q main
    printf 'name=app\ntimeout=60\nlog=info\n' > app.conf
    M 2024-03-04 "Raise timeout to 60"
    printf 'level=warn\n' > logging.conf
    M 2024-03-05 "Quiet logging"
    chmod -R a+rwX /home/labuser/work/config-app
  tasks:
    - id_key: start-conflicting-merge
      title: Trigger a merge conflict
      points: 10
      is_stateful: true
      description: In ~/work/config-app, merge branch feature/timeout into main. Both branches changed the timeout line, so Git must stop with a conflict in app.conf. Leave the merge unfinished.
      verification_script: |
        r=/home/labuser/work/config-app
        git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
        [ "$(git -C $r rev-parse MERGE_HEAD)" = "$(git -C $r rev-parse feature/timeout)" ] &&
        git -C $r ls-files -u | grep -q app.conf &&
        grep -q '^<<<<<<<' $r/app.conf
      hint_context: git merge feature/timeout. When it says CONFLICT, run git status and open app.conf to see the markers.
      explanation_context: Both sides changed the same line relative to the common ancestor, so Git cannot choose. It writes both versions between <<<<<<<, ======= and >>>>>>> and records MERGE_HEAD so you can finish or abort.
      solution_script: |
        cd ~/work/config-app
        git merge feature/timeout || true
    - id_key: resolve-conflict
      title: Resolve the conflict
      points: 20
      is_stateful: true
      description: Edit app.conf so it keeps the larger timeout from main (timeout=60) AND the new retries=3 line from the feature branch. Remove all conflict markers and stage the file. Do not commit yet.
      verification_script: |
        r=/home/labuser/work/config-app
        git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
        [ -z "$(git -C $r ls-files -u)" ] &&
        ! grep -qE '^(<<<<<<<|=======|>>>>>>>)' $r/app.conf &&
        git -C $r show :app.conf | grep -qx 'timeout=60' &&
        git -C $r show :app.conf | grep -qx 'retries=3' &&
        ! git -C $r show :app.conf | grep -q 'timeout=45'
      hint_context: Delete the three marker lines and the line you do not want, keep timeout=60 and retries=3, then git add app.conf. git diff --staged confirms.
      explanation_context: Conflict markers are just text; resolving means producing the final content yourself. git add tells Git the conflict for that path is resolved and moves it out of the unmerged state.
      solution_script: |
        cd ~/work/config-app
        printf 'name=app\ntimeout=60\nlog=info\nretries=3\n' > app.conf
        git add app.conf
    - id_key: complete-merge
      title: Complete the merge
      points: 10
      is_stateful: true
      description: Finish the merge with git commit (accept the default message). Afterwards the working tree must be clean and contain no conflict markers anywhere.
      verification_script: |
        r=/home/labuser/work/config-app
        ! git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
        [ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
        git -C $r log -1 --format=%s | grep -q '^Merge' &&
        git -C $r merge-base --is-ancestor feature/timeout HEAD &&
        [ -z "$(git -C $r grep -nE '^(<<<<<<<|>>>>>>>)' HEAD)" ] &&
        git -C $r show HEAD:app.conf | grep -qx 'timeout=60' &&
        [ -z "$(git -C $r status --porcelain)" ]
      hint_context: git commit with no -m opens the editor with a pre-filled merge message; save and quit. Or use git commit --no-edit.
      explanation_context: The merge commit is created from the resolved index and has two parents, so both lines of history stay linked.
      solution_script: |
        cd ~/work/config-app
        git commit --no-edit
    - id_key: second-conflict
      title: Start a second conflicting merge
      points: 10
      is_stateful: true
      description: Now merge feature/log-level into main. logging.conf conflicts (debug vs warn). Stop at the conflict.
      verification_script: |
        r=/home/labuser/work/config-app
        git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
        [ "$(git -C $r rev-parse MERGE_HEAD)" = "$(git -C $r rev-parse feature/log-level)" ] &&
        git -C $r ls-files -u | grep -q logging.conf
      hint_context: git merge feature/log-level, then read git status - it lists logging.conf as "both modified".
      explanation_context: Same mechanics as before; this time you will back out instead of resolving.
      solution_script: |
        cd ~/work/config-app
        git merge feature/log-level || true
    - id_key: abort-merge
      title: Abort the merge
      points: 15
      is_stateful: true
      description: Decide this merge is not worth doing right now and abort it so the repository returns exactly to its state before you started.
      verification_script: |
        r=/home/labuser/work/config-app
        ! git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
        [ -z "$(git -C $r status --porcelain)" ] &&
        ! git -C $r merge-base --is-ancestor feature/log-level HEAD &&
        [ "$(cat $r/logging.conf)" = "level=warn" ]
      hint_context: git merge --abort restores the pre-merge state. It only works while the merge is still in progress.
      explanation_context: --abort resets the index and working tree to the commit you were on before the merge, discarding half-resolved edits. Nothing is lost from committed history.
      solution_script: |
        cd ~/work/config-app
        git merge --abort
    - id_key: rerere
      title: Let rerere remember the resolution
      points: 20
      is_stateful: true
      description: Enable rerere for this repository (git config rerere.enabled true), merge feature/log-level again, resolve logging.conf as level=warn, and commit the merge. Git then records your resolution so the same conflict can be replayed automatically later.
      verification_script: |
        r=/home/labuser/work/config-app
        [ "$(git -C $r config --get rerere.enabled)" = true ] &&
        ls $r/.git/rr-cache/*/postimage >/dev/null 2>&1 &&
        [ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
        git -C $r merge-base --is-ancestor feature/log-level HEAD &&
        [ "$(git -C $r show HEAD:logging.conf)" = "level=warn" ] &&
        [ -z "$(git -C $r status --porcelain)" ]
      hint_context: Enable rerere BEFORE the merge so the conflict is recorded. After resolving, git add and git commit; the postimage appears under .git/rr-cache.
      explanation_context: rerere (reuse recorded resolution) stores the conflicted preimage and your resolved postimage keyed by the conflict's hash. If the same conflict reappears (rebase, re-merge) Git applies your earlier fix automatically.
      solution_script: |
        cd ~/work/config-app
        git config rerere.enabled true
        git merge feature/log-level || true
        printf 'level=warn\n' > logging.conf
        git add logging.conf
        git commit --no-edit
---

## Why this matters

In `~/work/config-app`, `main` and two feature branches all edited the same
config lines. You will trigger a conflict, resolve it by combining both sides,
finish the merge, abort a second one, and finally let rerere record a
resolution.

```bash
cd ~/work/config-app
git log --oneline --graph --all
```

## Task 1: trigger the conflict

Merge `feature/timeout` into `main` and stop at the conflict. Do not resolve
yet.

[[lab-task:1]]

Expected output and file:

```
Auto-merging app.conf
CONFLICT (content): Merge conflict in app.conf
Automatic merge failed; fix conflicts and then commit the result.

name=app
<<<<<<< HEAD
timeout=60
=======
timeout=45
>>>>>>> feature/timeout
log=info
retries=3
```

## Task 2: resolve by combining

Make `app.conf` keep `timeout=60` from `main` **and** `retries=3` from the
feature branch. Remove every marker and stage the file. Do not commit yet.

[[lab-task:2]]

Check: `git status` says `All conflicts fixed but you are still merging.`

## Task 3: complete the merge

Commit with the default message.

[[lab-task:3]]

Expected graph:

```
*   6be1f20 (HEAD -> main) Merge branch 'feature/timeout'
|\
| * c2a9d41 (feature/timeout) Raise timeout to 45 and add retries
* | 14e8b07 Raise timeout to 60
|/
* a70d3e5 Initial config
```

## Task 4: a second conflict

Merge `feature/log-level`. `logging.conf` conflicts (debug vs warn). Stop there.

[[lab-task:4]]

## Task 5: abort

Decide it is not the right time. Abort so the repository is exactly as before.

[[lab-task:5]]

Expected `git status`:

```
On branch main
nothing to commit, working tree clean
```

## Task 6: record a resolution with rerere

Enable rerere for this repository, merge `feature/log-level` again, resolve
`logging.conf` as `level=warn`, and commit.

[[lab-task:6]]

Expected messages along the way:

```
Recorded preimage for 'logging.conf'
...
Recorded resolution for 'logging.conf'.
```

and `ls .git/rr-cache/*/` shows `postimage  preimage`.

## Remember

- Read `git status` at every step of a conflict.
- Combine both sides when both are right.
- `--abort` is your undo button while the merge is in progress.
