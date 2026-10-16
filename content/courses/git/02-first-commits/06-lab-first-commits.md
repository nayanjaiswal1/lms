---
kind: lesson
id_key: git/first-commits/lesson
course: git
section: first-commits
section_title: Setup and First Commits
section_position: 2
title: "Lab: Your First Clean History"
position: 5
estimated_minutes: 35
source:
  - Pro Git book, ch. 2 "Git Basics" (git-scm.com/book)
  - git-commit(1), git-config(1), gitignore(5) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 45
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    git config --system init.defaultBranch main
    git config --system safe.directory '*'
    rm -rf /home/labuser/work/hello
  tasks:
    - id_key: init-repo
      title: Create a repository
      points: 10
      is_stateful: true
      description: Create a new directory called hello inside your work directory and turn it into a Git repository whose first branch is named main.
      verification_script: |
        r=/home/labuser/work/hello
        [ "$(git -C $r rev-parse --is-inside-work-tree)" = true ] &&
        [ "$(git -C $r symbolic-ref HEAD)" = refs/heads/main ]
      hint_context: git init creates the hidden .git directory. The default branch name is already main in this lab; check it with git status.
      explanation_context: git init writes the .git directory (objects, refs, HEAD). Nothing is committed yet, so HEAD points at a branch (main) that does not exist until the first commit.
      solution_script: |
        mkdir -p ~/work/hello && cd ~/work/hello && git init
    - id_key: set-identity
      title: Tell Git who you are
      points: 10
      is_stateful: true
      description: Set your global identity to the name "Ada Student" and the email "ada@example.com".
      verification_script: |
        [ "$(git config --global --get user.name)" = "Ada Student" ] &&
        [ "$(git config --global --get user.email)" = "ada@example.com" ]
      hint_context: git config --global writes to ~/.gitconfig and applies to every repository you use.
      explanation_context: Every commit records an author name and email. They come from user.name and user.email; --global stores them once for all repos.
      solution_script: |
        git config --global user.name "Ada Student"
        git config --global user.email "ada@example.com"
    - id_key: first-commit
      title: Make your first commit
      points: 15
      is_stateful: true
      description: Inside hello, create README.md containing the single line "# Hello", stage it and commit it with the message "Add README".
      verification_script: |
        r=/home/labuser/work/hello
        [ "$(git -C $r rev-list --count HEAD)" = 1 ] &&
        [ "$(git -C $r log -1 --format=%s)" = "Add README" ] &&
        [ "$(git -C $r log -1 --format=%an)" = "Ada Student" ] &&
        [ "$(git -C $r show HEAD:README.md)" = "# Hello" ] &&
        [ -z "$(git -C $r status --porcelain)" ]
      hint_context: Three steps - create the file, git add it, git commit -m with the message. git status before and after shows the difference.
      explanation_context: A commit snapshots the staging area (index), not the working tree. git add moves the file into the index; git commit turns the index into a permanent commit.
      solution_script: |
        cd ~/work/hello
        echo "# Hello" > README.md
        git add README.md
        git commit -m "Add README"
    - id_key: ignore-files
      title: Ignore generated files
      points: 15
      is_stateful: true
      description: Create main.sh (any content), a .gitignore that ignores *.log files and the build/ directory, plus an app.log file and a build/out.txt file. Commit main.sh and .gitignore with the message "Add main script and gitignore" while app.log and build/ stay on disk but untracked.
      verification_script: |
        r=/home/labuser/work/hello
        [ "$(git -C $r log -1 --format=%s)" = "Add main script and gitignore" ] &&
        git -C $r ls-files --error-unmatch main.sh .gitignore >/dev/null &&
        [ -f $r/app.log ] && [ -f $r/build/out.txt ] &&
        git -C $r check-ignore -q app.log && git -C $r check-ignore -q build/out.txt &&
        [ -z "$(git -C $r ls-files | grep -E 'app.log|build/')" ] &&
        [ -z "$(git -C $r status --porcelain)" ]
      hint_context: A .gitignore line like *.log matches any log file, and build/ matches a directory. git status should NOT list app.log or build/ once the rules exist.
      explanation_context: .gitignore only affects untracked files. Because app.log and build/ never entered the index, Git silently skips them; git check-ignore -v shows which rule matched.
      solution_script: |
        cd ~/work/hello
        printf '#!/bin/sh\necho hello\n' > main.sh
        printf '*.log\nbuild/\n' > .gitignore
        echo noise > app.log
        mkdir -p build && echo out > build/out.txt
        git add main.sh .gitignore
        git commit -m "Add main script and gitignore"
    - id_key: stage-vs-unstaged
      title: Split staged and unstaged changes
      points: 15
      is_stateful: true
      description: Append the line "Learning git" to README.md and stage it. Then append the line "echo done" to main.sh but do NOT stage it. Use git diff and git diff --staged to see the two views.
      verification_script: |
        r=/home/labuser/work/hello
        [ "$(git -C $r diff --cached --name-only)" = README.md ] &&
        [ "$(git -C $r diff --name-only)" = main.sh ] &&
        git -C $r diff --cached | grep -q '^+Learning git$' &&
        git -C $r diff | grep -q '^+echo done$'
      hint_context: git add README.md stages only that file. git diff compares working tree to the index; git diff --staged compares the index to HEAD.
      explanation_context: Git has three areas - working tree, index, HEAD. git diff shows working vs index, git diff --staged shows index vs HEAD, so the same file can appear in either or both.
      solution_script: |
        cd ~/work/hello
        echo "Learning git" >> README.md
        git add README.md
        echo "echo done" >> main.sh
    - id_key: amend-commit
      title: Commit and then amend
      points: 20
      is_stateful: true
      description: Commit the staged README change with the message "Update readme". Then realise main.sh belongs in the same commit, stage it, and amend so there is one commit with the message "Update README and script" that contains both files. History should have exactly three commits.
      verification_script: |
        r=/home/labuser/work/hello
        [ "$(git -C $r rev-list --count HEAD)" = 3 ] &&
        [ "$(git -C $r log -1 --format=%s)" = "Update README and script" ] &&
        git -C $r show --name-only --format= HEAD | grep -qx README.md &&
        git -C $r show --name-only --format= HEAD | grep -qx main.sh &&
        [ -z "$(git -C $r status --porcelain)" ]
      hint_context: git commit --amend -m "new message" after staging the extra file replaces the last commit instead of adding a new one.
      explanation_context: --amend does not edit a commit, it builds a replacement from the current index and moves the branch to it; the old commit becomes unreachable (but is still in the reflog). Never amend commits you already pushed.
      solution_script: |
        cd ~/work/hello
        git commit -m "Update readme"
        git add main.sh
        git commit --amend -m "Update README and script"
---

## Why this matters

Maya wants a tidy three-commit history in a new `hello` project. This lab uses
everything from the last five lessons: the three areas, identity, commits,
`.gitignore`, status and diff, and amend. Each task is checked automatically.

## Task 1: create the repository

Make `~/work/hello` and turn it into a repository. The first branch is already
configured to be `main` in this lab.

[[lab-task:1]]

Expected output of `git init` and `git status`:

```
Initialized empty Git repository in /home/labuser/work/hello/.git/
On branch main

No commits yet

nothing to commit (create/copy files and use "git add" to track)
```

## Task 2: tell Git who you are

Set the global name `Ada Student` and email `ada@example.com`.

[[lab-task:2]]

Check: `git config --list --show-origin | grep user`.

## Task 3: first commit

Create `README.md` with the single line `# Hello`, stage it and commit it as
`Add README`.

[[lab-task:3]]

Expected `git log --oneline` (hash differs):

```
3f1c9ab (HEAD -> main) Add README
```

## Task 4: ignore generated files

Create `main.sh`, a `.gitignore` that ignores `*.log` and `build/`, and the
noise files `app.log` and `build/out.txt`. Commit only `main.sh` and
`.gitignore` as `Add main script and gitignore`.

[[lab-task:4]]

Expected `git status` afterwards (the ignored files stay on disk, unlisted):

```
On branch main
nothing to commit, working tree clean
```

Confirm a rule with `git check-ignore -v app.log`.

## Task 5: one staged, one not

Append `Learning git` to `README.md` and stage it. Append `echo done` to
`main.sh` and do **not** stage it. Compare `git diff` and `git diff --staged`.

[[lab-task:5]]

Expected `git status -s`:

```
M  README.md
 M main.sh
```

## Task 6: commit, then amend

Commit the staged change as `Update readme`. Then stage `main.sh` and amend so
one commit named `Update README and script` holds both files.

[[lab-task:6]]

Expected `git log --oneline`:

```
b94e2d1 (HEAD -> main) Update README and script
7a03c55 Add main script and gitignore
3f1c9ab Add README
```

## Remember

- Look at `git status` before and after every command while you learn.
- Commit only what is staged; review it with `git diff --staged`.
- Amend replaces the last commit; do it before you push.
