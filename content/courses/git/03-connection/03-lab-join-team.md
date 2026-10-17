---
kind: lesson
id_key: git/connection/lesson
course: git
section: connection
section_title: "Connecting to the Team"
section_position: 3
title: "Lab: Fix a Remote and Push to the Team"
position: 2
estimated_minutes: 20
source:
  - Pro Git book, ch. 2.5 "Working with Remotes" and ch. 4 "Git on the Server"
  - git-remote(1), ssh-keygen(1), git-credential(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 30
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    umask 000
    git config --global init.defaultBranch main
    git config --global safe.directory '*'
    git config --global user.name "Lab Student"
    git config --global user.email "student@lab.local"
    rm -rf /home/labuser/srv/git /home/labuser/work/onboarding /tmp/seed
    mkdir -p /home/labuser/srv/git
    git init -q --bare /home/labuser/srv/git/team.git
    git init -q --bare /home/labuser/srv/git/backup.git
    git clone -q /home/labuser/srv/git/team.git /tmp/seed 2>/dev/null
    cd /tmp/seed
    export GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com
    echo "# Brightside Shop" > README.md; git add -A
    GIT_AUTHOR_DATE="2024-01-01T10:00:00+0000" GIT_COMMITTER_DATE="2024-01-01T10:00:00+0000" git commit -q -m "Initial commit"
    git push -q origin main
    cd /; rm -rf /tmp/seed
    git --git-dir=/home/labuser/srv/git/team.git symbolic-ref HEAD refs/heads/main
    git --git-dir=/home/labuser/srv/git/backup.git symbolic-ref HEAD refs/heads/main
    git clone -q /home/labuser/srv/git/team.git /home/labuser/work/onboarding 2>/dev/null
    git -C /home/labuser/work/onboarding remote set-url origin /home/labuser/srv/git/tean.git
    chmod -R a+rwX /home/labuser/srv/git /home/labuser/work/onboarding
  tasks:
    - id_key: fix-remote-url
      title: Fix the broken remote
      points: 10
      is_stateful: true
      description: Maya set up your onboarding repository in your work directory, but git fetch fails - the origin URL has a typo. Point origin at the real team repository, /home/labuser/srv/git/team.git.
      verification_script: |
        r=/home/labuser/work/onboarding
        [ "$(git -C $r remote get-url origin)" = /home/labuser/srv/git/team.git ] &&
        git -C $r ls-remote origin >/dev/null 2>&1
      hint_context: git remote -v shows the current URL, git remote set-url origin <url> changes it. Run git fetch afterwards to confirm it works.
      explanation_context: A remote is only a name for a URL. When fetch says repository not found, check the URL first - a typo is the most common cause.
      solution_script: |
        cd ~/work/onboarding && git remote set-url origin /home/labuser/srv/git/team.git
    - id_key: first-push
      title: Say hello to the team
      points: 15
      is_stateful: true
      description: In onboarding, create welcome.txt containing the line "Hello from the new developer", commit it with the message "Add welcome note", and push it to origin main.
      verification_script: |
        r=/home/labuser/work/onboarding
        [ "$(git --git-dir=/home/labuser/srv/git/team.git show main:welcome.txt)" = "Hello from the new developer" ] &&
        [ "$(git --git-dir=/home/labuser/srv/git/team.git log -1 --format=%s main)" = "Add welcome note" ] &&
        [ "$(git -C $r rev-parse HEAD)" = "$(git --git-dir=/home/labuser/srv/git/team.git rev-parse main)" ]
      hint_context: Create the file, git add, git commit -m, then git push origin main.
      explanation_context: A commit exists only locally until you push. After the push, the team repository's main points at your commit, so Maya can pull it.
      solution_script: |
        cd ~/work/onboarding
        echo "Hello from the new developer" > welcome.txt
        git add welcome.txt
        git commit -m "Add welcome note"
        git push origin main
    - id_key: add-backup-remote
      title: Add a second remote
      points: 15
      is_stateful: true
      description: A repository can have several remotes. Add a remote called backup that points to /home/labuser/srv/git/backup.git and push main to it.
      verification_script: |
        r=/home/labuser/work/onboarding
        [ "$(git -C $r remote get-url backup)" = /home/labuser/srv/git/backup.git ] &&
        [ "$(git --git-dir=/home/labuser/srv/git/backup.git rev-parse main)" = "$(git -C $r rev-parse main)" ]
      hint_context: git remote add <name> <url>, then git push backup main.
      explanation_context: origin is just the default name. Any number of remotes can exist, each a different URL, and you choose which one each push goes to.
      solution_script: |
        cd ~/work/onboarding
        git remote add backup /home/labuser/srv/git/backup.git
        git push backup main
---

## Why this matters

Maya cloned an onboarding repository for you, but `git fetch` fails. Fix the
remote, push your first commit to the team, and add a backup remote. In this
sandbox the "server" repositories are bare repos on disk under `/home/labuser/srv/git`, so no
keys or tokens are needed; the commands are the same as with GitHub.

## Task 1: fix the broken remote

```bash
cd ~/work/onboarding
git remote -v
git fetch          # fails - read the message
```

Expected error:

```
fatal: '/home/labuser/srv/git/tean.git' does not appear to be a git repository
fatal: Could not read from remote repository.
```

Point `origin` at the real repository, `/home/labuser/srv/git/team.git`.

[[lab-task:1]]

What you should see once the URL is right:

```
$ git remote -v
origin  /home/labuser/srv/git/team.git (fetch)
origin  /home/labuser/srv/git/team.git (push)
```

## Task 2: say hello to the team

Create `welcome.txt` containing `Hello from the new developer`, commit it as
`Add welcome note`, and push to `origin main`.

```
 before push                     after git push origin main
 you   : A---B                   you   : A---B
 origin: A                       origin: A---B
```

[[lab-task:2]]

Check: `git ls-remote origin main` prints the same hash as `git rev-parse HEAD`.

## Task 3: add a second remote

Add a remote named `backup` pointing at `/home/labuser/srv/git/backup.git`, then push `main`
to it.

[[lab-task:3]]

Expected `git remote -v`:

```
backup  /home/labuser/srv/git/backup.git (fetch)
backup  /home/labuser/srv/git/backup.git (push)
origin  /home/labuser/srv/git/team.git (fetch)
origin  /home/labuser/srv/git/team.git (push)
```

## Remember

- When fetch or push fails, check `git remote -v` before anything else.
- `git push <remote> <branch>` names exactly where your commits go.
- One repository can have many remotes.
