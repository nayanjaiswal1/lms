---
kind: lesson
id_key: git/clone-remotes/lesson
course: git
section: clone-remotes
section_title: Clone and Remotes
section_position: 4
title: "Lab: Clone, Track, Fetch, Pull and Push"
position: 3
estimated_minutes: 35
source:
  - Pro Git book, ch. 2.5 "Working with Remotes" and ch. 3.5 "Remote Branches"
  - git-clone(1), git-fetch(1), git-pull(1), git-push(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 45
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    umask 000
    git config --system init.defaultBranch main
    git config --system safe.directory '*'
    git config --system pull.rebase false
    git config --system user.name "Lab Student"
    git config --system user.email "student@lab.local"
    rm -rf /srv/git /home/labuser/work/app /tmp/seed
    mkdir -p /srv/git
    git init -q --bare /srv/git/origin.git
    git clone -q /srv/git/origin.git /tmp/seed 2>/dev/null
    cd /tmp/seed
    export GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com
    c() { GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
    echo "# Shop" > README.md; git add -A; c 2024-01-01 "Initial commit"
    echo 'echo shop' > app.sh; git add -A; c 2024-01-02 "Add app script"
    echo MIT > LICENSE; git add -A; c 2024-01-03 "Add license"
    git push -q origin main
    git switch -q -c feature/login
    echo "login form" > login.txt; git add -A; c 2024-01-04 "Add login form"
    git push -q origin feature/login
    cd /; rm -rf /tmp/seed
    git --git-dir=/srv/git/origin.git symbolic-ref HEAD refs/heads/main
    cat > /usr/local/bin/teammate-push <<'SCRIPT'
    #!/bin/bash
    # Simulates a teammate pushing a commit to origin/main.
    set -e
    t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
    git clone -q /srv/git/origin.git "$t/w" 2>/dev/null; cd "$t/w"
    if git log --format=%s | grep -qx "Teammate: add changelog"; then echo "teammate already pushed"; exit 0; fi
    echo "# Changelog" > CHANGELOG.md; git add -A
    GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com \
    GIT_AUTHOR_DATE="2024-01-10T10:00:00+0000" GIT_COMMITTER_DATE="2024-01-10T10:00:00+0000" git commit -q -m "Teammate: add changelog"
    git push -q origin main
    echo "teammate pushed to origin/main"
    SCRIPT
    chmod 755 /usr/local/bin/teammate-push
    chmod -R a+rwX /srv/git
  tasks:
    - id_key: clone-origin
      title: Clone the shared repository
      points: 10
      is_stateful: true
      description: The team repository lives at /srv/git/origin.git (a bare repository acting as "the server"). Clone it into a directory called app inside your work directory.
      verification_script: |
        r=/home/labuser/work/app
        [ "$(git -C $r remote get-url origin)" = /srv/git/origin.git ] &&
        [ "$(git -C $r symbolic-ref HEAD)" = refs/heads/main ] &&
        [ "$(git -C $r rev-list --count HEAD)" = 3 ]
      hint_context: git clone <url> <directory>. A local path works as a URL. Afterwards run git remote -v to see where origin points.
      explanation_context: Clone copies all history, creates the remote named origin, remote-tracking refs (origin/main ...) and checks out main with main tracking origin/main.
      solution_script: |
        cd ~/work && git clone /srv/git/origin.git app
    - id_key: track-branch
      title: Check out a remote branch
      points: 10
      is_stateful: true
      description: origin also has a branch feature/login. Create a local branch feature/login that tracks origin/feature/login (git switch can do this for you).
      verification_script: |
        r=/home/labuser/work/app
        [ "$(git -C $r config branch.feature/login.remote)" = origin ] &&
        [ "$(git -C $r config branch.feature/login.merge)" = refs/heads/feature/login ] &&
        git -C $r log feature/login --format=%s | grep -qx "Add login form"
      hint_context: git branch -a lists remote-tracking branches. git switch feature/login creates a tracking branch when only origin/feature/login exists.
      explanation_context: A tracking branch remembers its upstream, so git status can say "ahead 1, behind 2" and plain git pull / git push know where to go.
      solution_script: |
        cd ~/work/app && git switch feature/login
    - id_key: local-commit
      title: Commit locally on main
      points: 10
      is_stateful: true
      description: Switch back to main and commit a new file notes.txt (any content) with the message "Add notes.txt". Do not push yet.
      verification_script: |
        r=/home/labuser/work/app
        [ "$(git -C $r rev-list --count origin/main..main)" = 1 ] &&
        [ "$(git -C $r log main -1 --format=%s)" = "Add notes.txt" ] &&
        [ "$(git -C $r rev-list --count main..origin/main)" = 0 ]
      hint_context: git switch main, then create, add and commit the file. git status should now say "ahead of origin/main by 1 commit".
      explanation_context: Commits are local until pushed. origin/main is only your last known copy of the remote branch, so main being ahead is normal.
      solution_script: |
        cd ~/work/app
        git switch main
        echo "my notes" > notes.txt
        git add notes.txt
        git commit -m "Add notes.txt"
    - id_key: fetch-diverged
      title: Fetch a teammate's work without merging
      points: 20
      is_stateful: true
      description: Run the helper command teammate-push (it simulates a colleague pushing to origin/main). Then try git push - it will be rejected. Run git fetch (not pull) so origin/main updates while your own main stays untouched.
      verification_script: |
        r=/home/labuser/work/app
        o=$(git -C $r ls-remote origin refs/heads/main | cut -f1)
        [ "$(git -C $r rev-parse origin/main)" = "$o" ] &&
        [ "$(git -C $r rev-parse main)" != "$o" ] &&
        git -C $r log origin/main --format=%s | grep -qx "Teammate: add changelog" &&
        [ "$(git -C $r log main -1 --format=%s)" = "Add notes.txt" ]
      hint_context: teammate-push is already on your PATH. After git push is rejected, git fetch updates origin/main but never touches your branches. Compare with git log --oneline --graph --all.
      explanation_context: Push is rejected (non-fast-forward) because origin/main has a commit you lack. fetch downloads it into the remote-tracking branch only; pull would also merge it into your branch.
      solution_script: |
        teammate-push
        cd ~/work/app
        git push || true
        git fetch
    - id_key: pull-and-push
      title: Integrate and push
      points: 20
      is_stateful: true
      description: Bring the teammate's commit into main with git pull (merge strategy) and push main so origin has both the changelog commit and your notes commit.
      verification_script: |
        r=/home/labuser/work/app
        o=$(git -C $r ls-remote origin refs/heads/main | cut -f1)
        [ "$(git -C $r rev-parse main)" = "$o" ] &&
        git -C $r log origin/main --format=%s | grep -qx "Add notes.txt" &&
        git -C $r log origin/main --format=%s | grep -qx "Teammate: add changelog" &&
        [ -z "$(git -C $r status --porcelain)" ]
      hint_context: git pull = git fetch + git merge. The system default is merge (pull.rebase=false). Afterwards git push publishes the merge.
      explanation_context: Your main and origin/main had diverged, so pull creates a merge commit joining them; the follow-up push is then a fast-forward for the server.
      solution_script: |
        cd ~/work/app
        git pull --no-rebase --no-edit
        git push
    - id_key: push-new-branch
      title: Publish a new branch with upstream tracking
      points: 15
      is_stateful: true
      description: Create a branch feature/search with one commit "Add search stub" (add a file search.txt) and push it to origin, setting the upstream so a bare git push works later.
      verification_script: |
        r=/home/labuser/work/app
        o=$(git -C $r ls-remote origin refs/heads/feature/search | cut -f1)
        [ -n "$o" ] &&
        [ "$(git -C $r rev-parse feature/search)" = "$o" ] &&
        [ "$(git -C $r rev-parse feature/search@{upstream})" = "$o" ] &&
        [ "$(git -C $r log feature/search -1 --format=%s)" = "Add search stub" ]
      hint_context: git push -u origin <branch> pushes and records the upstream in one step.
      explanation_context: -u (--set-upstream) writes branch.<name>.remote and .merge, which is what makes git status and bare git pull/push work for that branch.
      solution_script: |
        cd ~/work/app
        git switch -c feature/search
        echo "search" > search.txt
        git add search.txt
        git commit -m "Add search stub"
        git push -u origin feature/search
---

## Why this matters

This is the loop you will run every working day: clone, track a branch, commit,
get rejected because a teammate pushed first, fetch, integrate, push, and
publish a new branch. The "server" is the bare repository `/srv/git/origin.git`.
A helper command, `teammate-push`, plays Maya pushing to `main`.

## Task 1: clone

Clone `/srv/git/origin.git` into `~/work/app`.

[[lab-task:1]]

Expected `git remote -v` inside `app`:

```
origin  /srv/git/origin.git (fetch)
origin  /srv/git/origin.git (push)
```

## Task 2: track a remote branch

`origin/feature/login` exists, but you have no local `feature/login`. Create one
that tracks it.

[[lab-task:2]]

Expected `git branch -vv`:

```
* feature/login 5d2e9a1 [origin/feature/login] Add login form
  main          8c1f7b3 [origin/main] Add license
```

## Task 3: commit locally

Back on `main`, commit a new file `notes.txt` as `Add notes.txt`. Do not push.
`git status` should now say `ahead of 'origin/main' by 1 commit`.

[[lab-task:3]]

## Task 4: get rejected, then fetch

Run `teammate-push`, then try `git push` and read the rejection. Then `git fetch`
(not pull) so only `origin/main` moves.

```
 after teammate-push and git fetch:

 * 9d4b0c2 (origin/main) Teammate: add changelog
 | * 41ae6f8 (HEAD -> main) Add notes.txt
 |/
 * 8c1f7b3 Add license
```

[[lab-task:4]]

Expected rejection:

```
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to '/srv/git/origin.git'
```

## Task 5: integrate and push

Merge the teammate's commit with `git pull` (merge strategy is the default in
this lab), then push.

[[lab-task:5]]

Expected `git log --oneline --graph`:

```
*   c7e21d0 (HEAD -> main, origin/main) Merge branch 'main' of /srv/git/origin
|\
| * 9d4b0c2 Teammate: add changelog
* | 41ae6f8 Add notes.txt
|/
* 8c1f7b3 Add license
```

## Task 6: publish a new branch

Create `feature/search` with one commit `Add search stub` (file `search.txt`)
and push it with upstream tracking.

[[lab-task:6]]

Check: `git ls-remote origin` lists `refs/heads/feature/search`, and
`git status` on the branch says `up to date with 'origin/feature/search'`.

## Remember

- Rejected push = someone pushed first. Fetch, integrate, push.
- `fetch` is safe to run any time.
- `push -u` once per new branch.
