---
kind: lesson
id_key: git/internals/lab-objects-refs
course: git
section: internals
section_title: "Under the Hood: Objects, Refs and the Index"
section_position: 7
title: "Lab: Explore Objects and Refs by Hand"
position: 3
estimated_minutes: 30
source:
  - Pro Git book, ch. 10 "Git Internals"
  - git-cat-file(1), git-hash-object(1), git-update-ref(1), gitrevisions(7) manual pages
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
    rm -rf /home/labuser/work/vault /home/labuser/work/tree.txt /home/labuser/work/blob.txt
    mkdir -p /home/labuser/work/vault && cd /home/labuser/work/vault
    git init -q
    M() { git add -A; GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
    echo "# Vault" > README.md; echo "mode=dev" > config.txt; M 2024-08-01 "Initial vault"
    echo "mode=staging" > config.txt; M 2024-08-02 "Switch to staging"
    GIT_COMMITTER_DATE="2024-08-02T12:00:00+0000" git tag -a v1 -m "Release 1"
    echo "mode=prod" > config.txt; M 2024-08-03 "Go to production"
    echo "keys" > keys.txt; M 2024-08-04 "Add key list"
    git switch -q --detach HEAD~1
    echo "experiment" > experiment.txt; M 2024-08-05 "Detached experiment"
    git switch -q main 2>/dev/null
    chmod -R a+rwX /home/labuser/work/vault
  tasks:
    - id_key: store-blob
      title: Store a blob by hand
      points: 10
      is_stateful: true
      description: In ~/work/vault, write a blob whose content is the line "hello objects" (with a trailing newline, as echo produces) straight into the object database, without creating any file or commit.
      verification_script: |
        r=/home/labuser/work/vault
        h=$(printf 'hello objects\n' | git -C $r hash-object --stdin)
        git -C $r cat-file -e "$h" 2>/dev/null &&
        [ "$(git -C $r cat-file -t "$h")" = blob ]
      hint_context: git hash-object --stdin only prints the hash; add -w to write the object. Pipe the content in with echo.
      explanation_context: hash-object -w stores content as a loose blob under .git/objects and prints its hash. Nothing references it yet, so it is a dangling object that gc may eventually prune.
      solution_script: |
        cd ~/work/vault && echo "hello objects" | git hash-object -w --stdin
    - id_key: root-tree
      title: Find the root tree of HEAD
      points: 10
      is_stateful: true
      description: Write the full hash of the root tree object of the current HEAD commit, alone on one line, into ~/work/tree.txt.
      verification_script: |
        r=/home/labuser/work/vault
        [ "$(tr -d '[:space:]' < /home/labuser/work/tree.txt)" = "$(git -C $r rev-parse 'HEAD^{tree}')" ]
      hint_context: git cat-file -p HEAD prints the commit; its first line is "tree <hash>". git rev-parse 'HEAD^{tree}' gives the same hash directly.
      explanation_context: Every commit points to exactly one root tree, the snapshot of the whole project. The tree lists names and points to blobs and subtrees.
      solution_script: |
        cd ~/work/vault && git rev-parse 'HEAD^{tree}' > ~/work/tree.txt
    - id_key: blob-at-tag
      title: Find a file's blob in an older release
      points: 15
      is_stateful: true
      description: The annotated tag v1 marks an older release. Write the full blob hash of config.txt as it was at v1, alone on one line, into ~/work/blob.txt.
      verification_script: |
        r=/home/labuser/work/vault
        [ "$(tr -d '[:space:]' < /home/labuser/work/blob.txt)" = "$(git -C $r rev-parse v1:config.txt)" ]
      hint_context: The <rev>:<path> syntax names the blob for a path in a commit. git rev-parse v1:config.txt prints its hash; git cat-file -p v1:config.txt shows its content (mode=staging).
      explanation_context: v1 is a tag object; Git peels it to the commit, then to the root tree, then looks up config.txt in that tree. Different content means a different blob than today's config.txt.
      solution_script: |
        cd ~/work/vault && git rev-parse v1:config.txt > ~/work/blob.txt
    - id_key: manual-branch
      title: Create a branch with update-ref
      points: 10
      is_stateful: true
      description: Create a branch named manual that points at the commit one before main's tip (main~1). Use git update-ref to see that a branch is only a ref holding a hash.
      verification_script: |
        r=/home/labuser/work/vault
        [ "$(git -C $r rev-parse --verify -q refs/heads/manual)" = "$(git -C $r rev-parse main~1)" ]
      hint_context: git update-ref refs/heads/manual main~1. Then git log --oneline --all --graph shows the new label.
      explanation_context: update-ref writes a hash into a ref (and records it in the reflog). git branch manual main~1 does the same thing with a friendlier interface.
      solution_script: |
        cd ~/work/vault && git update-ref refs/heads/manual main~1
    - id_key: rescue-detached
      title: Rescue a commit made on a detached HEAD
      points: 20
      is_stateful: true
      description: Someone made a commit "Detached experiment" on a detached HEAD and then switched back to main, so no branch points at it. Create a branch named rescued that points at that commit.
      verification_script: |
        r=/home/labuser/work/vault
        [ "$(git -C $r log -1 --format=%s rescued 2>/dev/null)" = "Detached experiment" ] &&
        git -C $r show rescued:experiment.txt | grep -qx experiment
      hint_context: 'git reflog lists every position HEAD has had, including the line "commit: Detached experiment". Copy that hash and run git branch rescued <hash>.'
      explanation_context: The commit was never lost, only unreferenced. The HEAD reflog still points to it, and a new branch makes it reachable again so garbage collection will never remove it.
      solution_script: |
        cd ~/work/vault
        git branch rescued "$(git reflog --format='%h %gs' | grep 'commit: Detached experiment' | head -1 | cut -d' ' -f1)"
---

## Why this matters

Reading about objects and refs is abstract. In this lab you create a blob by
hand, walk from a commit to its tree and to an old file version, make a branch
by writing a ref, and rescue a commit that no branch points at. After this,
"rebase made new commits" and "reset moved the branch" will feel concrete.

```bash
cd ~/work/vault
git log --oneline --graph --all
```

Expected (hashes differ):

```
* 6c1d2e0 (HEAD -> main) Add key list
* 3b7a9f4 Go to production
* 91e0c55 (tag: v1) Switch to staging
* 0f2d8aa Initial vault
```

The "Detached experiment" commit does not appear: nothing points at it.

## Task 1: store a blob

Ask Git to hash the line `hello objects` **and write it** into the database.

[[lab-task:1]]

Check: `echo "hello objects" | git hash-object --stdin` prints a hash, and
`git cat-file -p <that hash>` prints `hello objects`.

## Task 2: find the root tree

Every commit points to one root tree. Save HEAD's tree hash into
`~/work/tree.txt`.

[[lab-task:2]]

Look inside it with `git cat-file -p 'HEAD^{tree}'`:

```
100644 blob ...	README.md
100644 blob ...	config.txt
100644 blob ...	keys.txt
```

## Task 3: a file in an old release

Use the `<rev>:<path>` syntax to get the blob of `config.txt` at tag `v1`, and
save its hash into `~/work/blob.txt`.

[[lab-task:3]]

Check: `git cat-file -p v1:config.txt` prints `mode=staging`, while
`cat config.txt` prints `mode=prod`.

## Task 4: a branch is just a ref

Create the branch `manual` at `main~1` with `git update-ref`.

[[lab-task:4]]

Check: `git show-ref` now lists `refs/heads/manual`.

## Task 5: rescue the lost commit

Find "Detached experiment" in the reflog and give it a branch named `rescued`.

[[lab-task:5]]

Expected snippet of `git reflog`:

```
6c1d2e0 HEAD@{0}: checkout: moving from 7a0e413... to main
7a0e413 HEAD@{1}: commit: Detached experiment
3b7a9f4 HEAD@{2}: checkout: moving from main to HEAD~1
```

## Remember

- `hash-object -w`, `cat-file -t/-p` and `rev-parse` let you inspect anything.
- `<rev>:<path>` names a file version; `<rev>^{tree}` names a snapshot.
- Branches are refs; the reflog keeps commits findable after refs move away.
