---
kind: lesson
id_key: git/foundation/why-git
course: git
section: foundation
section_title: Foundation - Why Git
section_position: 1
title: The Day You Lose Your Work (and Git Saves It)
position: 0
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

> **Start with the pain.** You have a report due. You paste the wrong text over it, save, close the editor. The real report is gone. Without version control, that is a bad afternoon. With Git, it is one command - you will do it in the first lab, in under three minutes.

## Why Git exists

Before version control, history lived in file names like `report_final_v2_REAL.docx`. Git records every change, who made it and why, and lets you go back or work on several ideas at once.

```
 Centralized (SVN)              Distributed (Git)
 one server holds history       every clone holds ALL history
 no server = no work            work offline, sync when ready
```

Your clone is a complete repository, so commits, branches and history work with no network. A server such as GitHub is just another copy the team agrees to share.

[[lab-task:1]]

What you should see after the fix:

```
$ git status
On branch main
nothing to commit, working tree clean
```

```knowledge-check
{ "questions": [
  { "id": "git-foundation-q1", "type": "mcq",
    "prompt": "You overwrote a tracked file by accident and had committed it earlier. Is the old content lost?",
    "options": [
      {"id":"a","text":"Yes, the file is gone for good"},
      {"id":"b","text":"No, Git still has the committed snapshot and can restore it"},
      {"id":"c","text":"Only if you have a remote"},
      {"id":"d","text":"Only if you saved a backup copy"}],
    "correct": "b",
    "explanation": "Committed snapshots stay in the repository. git restore brings the file back." }
] }
```

## Snapshots with a name

Each commit is a snapshot of the whole project, named by a hash of its content and its parent. That chain of parents is the history, and it is why history cannot be changed silently.

```
 A <-- B <-- C      each arrow points to the parent
 first        latest
```

[[lab-task:2]]

## Branches are cheap

```
 main        A---B
                  \
 experiment        C     <- your risky idea, isolated
```

A branch is only a pointer to a commit. Try bold ideas on a branch; if they fail, delete it and nothing is lost.

[[lab-task:3]]

```knowledge-check
{ "questions": [
  { "id": "git-foundation-q2", "type": "mcq",
    "prompt": "What is a Git branch?",
    "options": [
      {"id":"a","text":"A full copy of all project files"},
      {"id":"b","text":"A movable pointer to a commit"},
      {"id":"c","text":"A separate repository"},
      {"id":"d","text":"A list of changed lines"}],
    "correct": "b",
    "explanation": "A branch is a tiny pointer, which is why creating one is instant." }
] }
```

> **Next:** you have seen what Git protects you from. Now start for real - on your first day at Brightside, with an empty folder.
