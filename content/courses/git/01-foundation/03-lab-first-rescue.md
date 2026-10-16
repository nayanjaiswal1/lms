---
kind: lesson
id_key: git/foundation/why-git
course: git
section: foundation
section_title: Foundation - Why Git
section_position: 1
title: "Lab: Rescue a File, Find the First Commit, Branch Safely"
position: 2
estimated_minutes: 20
source:
  - Pro Git book, ch. 1 "Getting Started" and ch. 10.2 "Git Objects"
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
    rm -rf /home/labuser/work/notes /home/labuser/work/first.txt
    mkdir -p /home/labuser/work/notes && cd /home/labuser/work/notes
    git init -q
    export GIT_AUTHOR_DATE="2024-01-01T10:00:00+0000" GIT_COMMITTER_DATE="2024-01-01T10:00:00+0000"
    echo "Quarterly report: revenue up 12 percent" > report.txt
    git add -A; git commit -q -m "Add quarterly report"
    export GIT_AUTHOR_DATE="2024-01-02T10:00:00+0000" GIT_COMMITTER_DATE="2024-01-02T10:00:00+0000"
    echo "TODO: write summary" > summary.txt
    git add -A; git commit -q -m "Add summary stub"
    echo "oops, pasted the wrong thing" > report.txt
    chmod -R a+rwX /home/labuser/work/notes
  tasks:
    - id_key: rescue-file
      title: Rescue the overwritten report
      points: 10
      is_stateful: true
      description: In the notes repository inside your work directory, report.txt was just overwritten by accident and the real report is gone from disk. Bring it back exactly as it was in the last commit.
      verification_script: |
        r=/home/labuser/work/notes
        [ "$(cat $r/report.txt)" = "Quarterly report: revenue up 12 percent" ] &&
        [ -z "$(git -C $r status --porcelain)" ]
      hint_context: git status will tell you which command restores a file from the last commit.
      explanation_context: Git keeps every committed snapshot, so an overwritten file is one command from being back. git restore copies the committed version over the working copy.
      solution_script: |
        cd ~/work/notes && git restore report.txt
    - id_key: find-first-commit
      title: Find where the story began
      points: 10
      is_stateful: true
      description: Find the full hash of the very first commit in the notes repository and write it, alone on one line, into a file called first.txt inside your work directory.
      verification_script: |
        r=/home/labuser/work/notes
        [ "$(tr -d '[:space:]' < /home/labuser/work/first.txt)" = "$(git -C $r rev-list --max-parents=0 HEAD)" ]
      hint_context: git log --oneline shows short hashes. git log --format=%H prints full ones, and the first commit is the last line.
      explanation_context: Every commit has a unique hash computed from its content and its parent. The first commit has no parent, so it is the root of the history.
      solution_script: |
        cd ~/work/notes && git rev-list --max-parents=0 HEAD > ~/work/first.txt
    - id_key: safe-experiment
      title: Experiment without fear
      points: 15
      is_stateful: true
      description: Create a branch called experiment, and on it make one commit with the message "Try a bold rewrite" that changes summary.txt. Branch main must stay exactly as it was.
      verification_script: |
        r=/home/labuser/work/notes
        [ "$(git -C $r rev-list --count main)" = 2 ] &&
        [ "$(git -C $r rev-list --count experiment)" = 3 ] &&
        [ "$(git -C $r log -1 --format=%s experiment)" = "Try a bold rewrite" ] &&
        [ "$(git -C $r show main:summary.txt)" = "TODO: write summary" ]
      hint_context: git switch -c experiment creates and moves to the branch. Edit summary.txt, then add and commit.
      explanation_context: A branch is just a pointer to a commit, so creating one is instant and free. Your experiment lives on its own line of history and main is untouched.
      solution_script: |
        cd ~/work/notes
        git switch -c experiment
        echo "Bold new summary" > summary.txt
        git add summary.txt
        git commit -m "Try a bold rewrite"
---

## Why this matters

You have read what Git protects you from. Now feel it: rescue an overwritten
file, find where a history began, and try a risky idea on a branch without
touching `main`. Each task is checked automatically in a real terminal.

## Before you start

The lab already contains a repository at `~/work/notes` with two commits. Someone
just pasted the wrong text over `report.txt`. Move into it first:

```bash
cd ~/work/notes
git status
```

Expected output:

```
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   report.txt
```

Read the hint lines. Git usually tells you the next command.

## Task 1: rescue the report

The committed snapshot still holds the real report. Copy it back over the
broken file (lesson 2 showed the command).

[[lab-task:1]]

What you should see after the fix:

```
$ git status
On branch main
nothing to commit, working tree clean
```

## Task 2: find the first commit

Every history starts at a root commit (a commit with no parent). Print full
hashes with `git log --format=%H`; the oldest commit is the last line. Save just
that hash into `~/work/first.txt`.

[[lab-task:2]]

Check yourself: `cat ~/work/first.txt` shows a single 40-character hash.

## Task 3: experiment on a branch

Create a branch named `experiment`, change `summary.txt` on it and commit with
the message `Try a bold rewrite`. `main` must stay exactly as it was.

```
 main        A---B
                  \
 experiment        C   "Try a bold rewrite"
```

[[lab-task:3]]

Check yourself:

```bash
git log --oneline --all --graph
git show main:summary.txt     # still prints: TODO: write summary
```

## Remember

- `git status` reads the situation and suggests the next command.
- `git restore <file>` brings back the committed version.
- A branch lets you experiment while `main` stays safe.
