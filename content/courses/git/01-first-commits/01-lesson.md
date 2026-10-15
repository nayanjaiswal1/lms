---
kind: lesson
id_key: git/first-commits/lesson
course: git
section: first-commits
section_title: Setup and First Commits
section_position: 2
title: Init, Stage, Commit, Amend, Ignore
position: 0
estimated_minutes: 40
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

> **Day 1 at Brightside.** Maya, your tech lead, hands you an empty folder: "Start the hello tool. Commit as you go - the whole team will read this history, so keep it clean." By the end of this section you will have a tidy three-commit history you are not embarrassed to show.

## The three areas

Git tracks your work in three places. Files move between them with explicit commands:

```
 WORKING TREE            INDEX (staging)             REPOSITORY (.git)
 files you edit   --->   next commit's snapshot --->  permanent history
                 git add                    git commit
       <---------------- git restore -----------------
```

`git init` creates the repository, `git status` tells you what sits in each area, and `git diff`
compares two of them.

```knowledge-check
{ "questions": [
  { "id": "git-first-areas-q1", "type": "mcq",
    "prompt": "Which area does git commit actually snapshot?",
    "options": [
      {"id":"a","text":"The working tree"},
      {"id":"b","text":"The index (staging area)"},
      {"id":"c","text":"The remote repository"},
      {"id":"d","text":"Only files modified in the last hour"}],
    "correct": "b",
    "explanation": "A commit is built from the index. Edits you did not git add are not part of it." }
] }
```

[[lab-task:1]]

What you should see after `git init hello` and `git status`:

```
Initialized empty Git repository in /home/labuser/work/hello/.git/
On branch main

No commits yet

nothing to commit (create/copy files and use "git add" to track)
```

## Identity and your first commit

Every commit stores an author. Configure it once:

```bash
git config --global user.name  "Ada Student"
git config --global user.email "ada@example.com"
git config --list --show-origin | grep user
```

[[lab-task:2]]

Then create and commit a file. Before and after:

```
BEFORE (after git add)            AFTER (git commit -m "Add README")

 working: README.md                working: README.md
 index  : README.md                index  : README.md
 HEAD   : (none)                   HEAD   : A  <- main
                                          A = "Add README"
```

```bash
echo "# Hello" > README.md
git add README.md
git commit -m "Add README"
git log --oneline
```

[[lab-task:3]]

What you should see (the hash will differ):

```
3f1c9ab (HEAD -> main) Add README
```

```knowledge-check
{ "questions": [
  { "id": "git-first-commit-q1", "type": "mcq",
    "prompt": "Where does Git get the author name stored in a commit?",
    "options": [
      {"id":"a","text":"The operating system login name, always"},
      {"id":"b","text":"user.name and user.email from git config"},
      {"id":"c","text":"The remote repository owner"},
      {"id":"d","text":"The file's last modified time"}],
    "correct": "b",
    "explanation": "user.name and user.email are read from config at commit time and baked into the commit object." }
] }
```

## Ignoring files with .gitignore

Logs, build output and secrets should never be committed. List patterns in `.gitignore`:

```
*.log
build/
```

Ignore rules only apply to files Git is not already tracking. Verify a rule with
`git check-ignore -v app.log`.

[[lab-task:4]]

What you should see from `git status` once the rules exist and everything is committed:

```
On branch main
nothing to commit, working tree clean
```

```knowledge-check
{ "questions": [
  { "id": "git-first-ignore-q1", "type": "mcq",
    "prompt": "You add app.log to .gitignore AFTER committing it. What happens to the already-tracked app.log?",
    "options": [
      {"id":"a","text":"It is deleted from history"},
      {"id":"b","text":"It stays tracked until you git rm --cached it"},
      {"id":"c","text":"It is removed from disk"},
      {"id":"d","text":"Git refuses further commits"}],
    "correct": "b",
    "explanation": ".gitignore only affects untracked files. A tracked file keeps being tracked until you remove it from the index with git rm --cached." }
] }
```

## status and diff: reading the three areas

```
 working tree --git diff--> index --git diff --staged--> HEAD

 README.md  (edited, added)       -> shows under "Changes to be committed"
 main.sh    (edited, not added)   -> shows under "Changes not staged"
```

```bash
echo "Learning git" >> README.md && git add README.md
echo "echo done" >> main.sh
git status -s
git diff            # main.sh only (unstaged)
git diff --staged   # README.md only (staged)
```

[[lab-task:5]]

What you should see from `git status -s`:

```
M  README.md
 M main.sh
```

The left column is the index versus HEAD, the right column is working tree versus index.

```knowledge-check
{ "questions": [
  { "id": "git-first-diff-q1", "type": "mcq",
    "prompt": "git diff prints nothing but git status shows a file under 'Changes to be committed'. Why?",
    "options": [
      {"id":"a","text":"The change is already staged, and plain git diff only compares working tree to index"},
      {"id":"b","text":"The file was ignored"},
      {"id":"c","text":"Git diff only works on binary files"},
      {"id":"d","text":"The repository is corrupt"}],
    "correct": "a",
    "explanation": "Use git diff --staged to see index versus HEAD." }
] }
```

## Fixing the last commit with --amend

```
BEFORE amend                         AFTER git commit --amend

 A---B---C  <- main                   A---B---C'  <- main
                                           \
                                            C (orphaned, still in reflog)
```

```bash
git commit -m "Update readme"
git add main.sh
git commit --amend -m "Update README and script"
git log --oneline
```

[[lab-task:6]]

What you should see:

```
b94e2d1 (HEAD -> main) Update README and script
7a03c55 Add main script and gitignore
3f1c9ab Add README
```

```knowledge-check
{ "questions": [
  { "id": "git-first-amend-q1", "type": "mcq",
    "prompt": "Why should you not amend a commit you already pushed?",
    "options": [
      {"id":"a","text":"Amend creates a new commit with a new hash, so the pushed one diverges from your local branch"},
      {"id":"b","text":"Amend deletes the remote repository"},
      {"id":"c","text":"Amend only works on the first commit"},
      {"id":"d","text":"Amend is not a real command"}],
    "correct": "a",
    "explanation": "The amended commit is a different object. Anyone who already has the old one now has diverging history." }
] }
```

> **Next:** your history is only on your laptop. Maya needs it on the team server - time to connect.
