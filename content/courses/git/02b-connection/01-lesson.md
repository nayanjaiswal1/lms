---
kind: lesson
id_key: git/connection/lesson
course: git
section: connection
section_title: Connecting to the Team
section_position: 3
title: Join the Team Repository - Remotes, SSH and Tokens
position: 0
estimated_minutes: 25
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
    git config --system init.defaultBranch main
    git config --system safe.directory '*'
    git config --system user.name "Lab Student"
    git config --system user.email "student@lab.local"
    rm -rf /srv/git /home/labuser/work/onboarding /tmp/seed
    mkdir -p /srv/git
    git init -q --bare /srv/git/team.git
    git init -q --bare /srv/git/backup.git
    git clone -q /srv/git/team.git /tmp/seed 2>/dev/null
    cd /tmp/seed
    export GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com
    echo "# Brightside Shop" > README.md; git add -A
    GIT_AUTHOR_DATE="2024-01-01T10:00:00+0000" GIT_COMMITTER_DATE="2024-01-01T10:00:00+0000" git commit -q -m "Initial commit"
    git push -q origin main
    cd /; rm -rf /tmp/seed
    git --git-dir=/srv/git/team.git symbolic-ref HEAD refs/heads/main
    git --git-dir=/srv/git/backup.git symbolic-ref HEAD refs/heads/main
    git clone -q /srv/git/team.git /home/labuser/work/onboarding 2>/dev/null
    git -C /home/labuser/work/onboarding remote set-url origin /srv/git/tean.git
    chmod -R a+rwX /srv/git /home/labuser/work/onboarding
  tasks:
    - id_key: fix-remote-url
      title: Fix the broken remote
      points: 10
      is_stateful: true
      description: Maya set up your onboarding repository in your work directory, but git fetch fails - the origin URL has a typo. Point origin at the real team repository, /srv/git/team.git.
      verification_script: |
        r=/home/labuser/work/onboarding
        [ "$(git -C $r remote get-url origin)" = /srv/git/team.git ] &&
        git -C $r ls-remote origin >/dev/null 2>&1
      hint_context: git remote -v shows the current URL, git remote set-url origin <url> changes it. Run git fetch afterwards to confirm it works.
      explanation_context: A remote is only a name for a URL. When fetch says repository not found, check the URL first - a typo is the most common cause.
      solution_script: |
        cd ~/work/onboarding && git remote set-url origin /srv/git/team.git
    - id_key: first-push
      title: Say hello to the team
      points: 15
      is_stateful: true
      description: In onboarding, create welcome.txt containing the line "Hello from the new developer", commit it with the message "Add welcome note", and push it to origin main.
      verification_script: |
        r=/home/labuser/work/onboarding
        [ "$(git --git-dir=/srv/git/team.git show main:welcome.txt)" = "Hello from the new developer" ] &&
        [ "$(git --git-dir=/srv/git/team.git log -1 --format=%s main)" = "Add welcome note" ] &&
        [ "$(git -C $r rev-parse HEAD)" = "$(git --git-dir=/srv/git/team.git rev-parse main)" ]
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
      description: A repository can have several remotes. Add a remote called backup that points to /srv/git/backup.git and push main to it.
      verification_script: |
        r=/home/labuser/work/onboarding
        [ "$(git -C $r remote get-url backup)" = /srv/git/backup.git ] &&
        [ "$(git --git-dir=/srv/git/backup.git rev-parse main)" = "$(git -C $r rev-parse main)" ]
      hint_context: git remote add <name> <url>, then git push backup main.
      explanation_context: origin is just the default name. Any number of remotes can exist, each a different URL, and you choose which one each push goes to.
      solution_script: |
        cd ~/work/onboarding
        git remote add backup /srv/git/backup.git
        git push backup main
---

> **Day 2.** You have a clean local history, but it lives only on your laptop. Maya says: "Join the team repo so I can see your work." That means one thing: connecting to a remote. On a real host (GitHub, GitLab) this is where most beginners get stuck, so this section covers both the commands and the errors you will meet.

## A remote is a name for a URL

`origin` is the default name for wherever you cloned from. It is nothing special.

```bash
git remote -v
git remote add backup <url>
git remote set-url origin <url>
```

[[lab-task:1]]

What you should see once the URL is right:

```
$ git remote -v
origin  /srv/git/team.git (fetch)
origin  /srv/git/team.git (push)
```

## Proving who you are

On a real host there are two ways to authenticate:

```
 HTTPS  https://host/you/project.git     username + personal access token
                                         (account passwords are not accepted)
 SSH    git@host:you/project.git         a key pair: the private key stays on
                                         your machine, the public key goes to the host
```

Setting up SSH takes four commands:

```bash
ssh-keygen -t ed25519 -C "you@example.com"   # creates id_ed25519 and id_ed25519.pub
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub                     # paste into the host's SSH keys page
ssh -T git@github.com                         # should greet you by name
```

Never share or commit the private key (the file without `.pub`). For HTTPS, create a personal access token on the host and use it as the password; `git config --global credential.helper store` remembers it.

## When it fails, read the error

```
 Permission denied (publickey)   public key not added to the host, or key not loaded in ssh-agent
 Authentication failed           expired/wrong token, or the account password was used
 Repository not found            URL typo, or no access to a private repo
```

```knowledge-check
{ "questions": [
  { "id": "git-connection-q1", "type": "mcq",
    "prompt": "You get 'Permission denied (publickey)' when pushing over SSH. What do you check first?",
    "options": [
      {"id":"a","text":"That the public key is uploaded to the host and the key is loaded in ssh-agent"},
      {"id":"b","text":"That the branch is called main"},
      {"id":"c","text":"That the commit message is short"},
      {"id":"d","text":"That the repository has a README"}],
    "correct": "a",
    "explanation": "The host must know your public key, and your machine must offer the matching private key." },
  { "id": "git-connection-q2", "type": "mcq",
    "prompt": "git push over HTTPS says 'Authentication failed' although your account password is correct. Most likely cause?",
    "options": [
      {"id":"a","text":"Hosts require a personal access token, not the account password"},
      {"id":"b","text":"The branch is named main"},
      {"id":"c","text":"Your commits are too large"},
      {"id":"d","text":"SSH is also enabled"}],
    "correct": "a",
    "explanation": "GitHub and GitLab no longer accept account passwords for Git over HTTPS." }
] }
```

## Your first push

```
 before push                     after git push origin main
 you   : A---B---C               you   : A---B---C
 origin: A---B                   origin: A---B---C
```

[[lab-task:2]]

## More than one remote

[[lab-task:3]]

> **Next:** you are connected and your first commit is on the team server. Now learn the daily loop: clone, fetch, pull and push.
