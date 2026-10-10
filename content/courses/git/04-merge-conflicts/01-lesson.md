---
kind: lesson
id_key: git/merge-conflicts/lesson
course: git
section: merge-conflicts
section_title: Merge Conflicts
section_position: 4
title: Reading, Resolving, Aborting and Remembering Conflicts
position: 0
estimated_minutes: 40
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
    git config --system init.defaultBranch main
    git config --system safe.directory '*'
    git config --system user.name "Lab Student"
    git config --system user.email "student@lab.local"
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

## Why conflicts happen

Git merges by comparing each branch to their common ancestor. If only one side changed a line, that
change wins. If both sides changed the same lines differently, Git stops and asks you.

```
 ancestor:  timeout=30
 main    :  timeout=60        both changed the same line
 feature :  timeout=45        ->  CONFLICT
```

```knowledge-check
{ "questions": [
  { "id": "git-conflict-why-q1", "type": "mcq",
    "prompt": "When does Git report a merge conflict?",
    "options": [
      {"id":"a","text":"Whenever two branches exist"},
      {"id":"b","text":"When both branches changed the same lines in different ways since the common ancestor"},
      {"id":"c","text":"When a branch is older than a week"},
      {"id":"d","text":"When a file is larger than 1 MB"}],
    "correct": "b",
    "explanation": "If only one side changed a region, Git takes that change automatically." }
] }
```

## Reading the markers

```bash
git switch main
git merge feature/timeout
git status
cat app.conf
```

[[lab-task:1]]

What you should see:

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

Above `=======` is your side (HEAD, the branch you are on). Below it is the incoming branch.

```
 DURING the merge
   A---B---C  <- main <- HEAD         .git/MERGE_HEAD -> feature/timeout tip
        \
         D  <- feature/timeout
   index holds 3 versions of app.conf (ancestor / ours / theirs) = "unmerged"
```

```knowledge-check
{ "questions": [
  { "id": "git-conflict-markers-q1", "type": "mcq",
    "prompt": "In a conflict block, what sits between <<<<<<< HEAD and =======?",
    "options": [
      {"id":"a","text":"The incoming branch's version"},
      {"id":"b","text":"The version from the branch you are currently on"},
      {"id":"c","text":"The common ancestor"},
      {"id":"d","text":"A summary written by Git"}],
    "correct": "b",
    "explanation": "HEAD is your current branch (ours); below ======= is theirs." }
] }
```

## Resolving and completing the merge

Resolving = edit the file to the final text, then tell Git with `git add`. Finish with `git commit`.

```
 resolve         git add app.conf      git commit
 (edit file) --> (conflict cleared) --> merge commit M (parents: main tip, feature tip)

   A---B---C---M  <- main
        \     /
         D---+   <- feature/timeout
```

```bash
# edit app.conf: keep timeout=60 and retries=3, delete the markers
git add app.conf
git commit
git log --oneline --graph
```

[[lab-task:2]]
[[lab-task:3]]

What you should see:

```
*   6be1f20 (HEAD -> main) Merge branch 'feature/timeout'
|\
| * c2a9d41 (feature/timeout) Raise timeout to 45 and add retries
* | 14e8b07 Raise timeout to 60
|/
* a70d3e5 Initial config
```

```knowledge-check
{ "questions": [
  { "id": "git-conflict-resolve-q1", "type": "mcq",
    "prompt": "After editing a conflicted file you must:",
    "options": [
      {"id":"a","text":"git add it, then git commit to complete the merge"},
      {"id":"b","text":"Delete the .git directory"},
      {"id":"c","text":"git push immediately"},
      {"id":"d","text":"Run git clone"}],
    "correct": "a",
    "explanation": "git add marks the path resolved; git commit records the merge commit." },
  { "id": "git-conflict-resolve-q2", "type": "mcq",
    "prompt": "What is the safest way to check no markers were left in the repository?",
    "options": [
      {"id":"a","text":"git grep -nE '^(<<<<<<<|>>>>>>>)'"},
      {"id":"b","text":"git gc"},
      {"id":"c","text":"git remote -v"},
      {"id":"d","text":"git tag"}],
    "correct": "a",
    "explanation": "Markers are plain text, so Git will happily commit them if you stage a file without cleaning it." }
] }
```

## Aborting a merge

If you start a merge and it is not the right time, back out cleanly:

```
 DURING conflict                     AFTER git merge --abort
 main + half-resolved files    -->   exactly the pre-merge state of main
```

```bash
git merge feature/log-level      # conflict
git merge --abort
git status
```

[[lab-task:4]]
[[lab-task:5]]

What you should see:

```
On branch main
nothing to commit, working tree clean
```

```knowledge-check
{ "questions": [
  { "id": "git-conflict-abort-q1", "type": "mcq",
    "prompt": "What does git merge --abort do?",
    "options": [
      {"id":"a","text":"Deletes the other branch"},
      {"id":"b","text":"Restores the repository to its state before the merge started"},
      {"id":"c","text":"Commits the conflict markers"},
      {"id":"d","text":"Pushes to origin"}],
    "correct": "b",
    "explanation": "It is only available while a merge is in progress; afterwards use reset or revert instead." }
] }
```

## rerere: reuse recorded resolution

Turn on `rerere` and Git remembers how you resolved each conflict. When the same conflict
appears again (re-merge, rebase, cherry-pick), it replays your answer.

```
 conflict #1:  preimage ---you resolve---> postimage      saved in .git/rr-cache/<hash>/
 conflict #2 (same hunk) -> "Resolved 'logging.conf' using previous resolution."
```

```bash
git config rerere.enabled true
git merge feature/log-level      # conflict, recorded
# resolve to level=warn
git add logging.conf && git commit --no-edit
ls .git/rr-cache/*/
```

[[lab-task:6]]

What you should see:

```
Recorded preimage for 'logging.conf'
...
Recorded resolution for 'logging.conf'.
postimage  preimage
```

```knowledge-check
{ "questions": [
  { "id": "git-conflict-rerere-q1", "type": "mcq",
    "prompt": "When is rerere most useful?",
    "options": [
      {"id":"a","text":"When you repeat the same merge or rebase many times, such as a long-lived branch rebased daily"},
      {"id":"b","text":"For encrypting commits"},
      {"id":"c","text":"For speeding up git clone"},
      {"id":"d","text":"For deleting old branches"}],
    "correct": "a",
    "explanation": "Each repeat of an identical conflict is resolved automatically from the recorded postimage." }
] }
```
