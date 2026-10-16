---
kind: quiz
id_key: git/foundation/quiz
course: git
section: foundation
section_title: "Big Picture: Why Git"
section_position: 1
title: "Quiz: Big Picture"
position: 3
estimated_minutes: 6
pass_percentage: 70
duration_minutes: 8
source:
  - Pro Git book, ch. 1 and ch. 3.1
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You are on a plane with no Wi-Fi. Which of these can you still do in your clone of a Git repository?"
    options:
      - text: "Nothing; Git needs the server for every command"
      - text: "Commit, create branches and read the full history"
        correct: true
      - text: "Only read files; commits wait until you are online"
      - text: "Push to GitHub, which queues the upload"
    explanation: "A clone is a complete repository, so committing, branching and reading history are all local. Only talking to another copy (push, pull, fetch) needs a network. Git has no offline push queue: push simply fails until you are online."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "A teammate says: 'I changed the message of a commit from last month and nobody noticed.' Why should that sound suspicious?"
    options:
      - text: "Commit messages cannot be edited by any command"
      - text: "Each commit's hash includes its parent's hash, so changing an old commit changes every later hash, which shows up for everyone who has the old history"
        correct: true
      - text: "Git emails the whole team when a message changes"
      - text: "Only the repository owner can edit messages"
    explanation: "History is a hash chain. Editing an old commit creates a new commit with a new hash, and every commit after it also gets a new hash. Other clones still have the old hashes, so the histories diverge visibly. Messages can be rewritten (rebase), but not silently; Git sends no emails and has no owner-only edit rule."
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Your history is A---B---C with main on C. You create a branch `idea` and commit D while on it. Where do the labels point now?"
    options:
      - text: "main on D, idea on C"
      - text: "main on C, idea on D"
        correct: true
      - text: "Both on D"
      - text: "Both on C; labels only move when you push"
    explanation: "Only the branch you are on (the one HEAD points to) moves when you commit. You were on idea, so idea moves to D and main stays on C. Labels move locally on every commit; pushing is not involved."
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Why is creating a branch in Git instant, even in a huge project?"
    options:
      - text: "Git copies files in the background"
      - text: "A branch is a small file holding one commit hash; no project files are copied"
        correct: true
      - text: "Branches are stored on the server, not on disk"
      - text: "Git compresses the copy"
    explanation: "A branch is a pointer to a commit. There is no copy, background or compressed, and branches live locally in .git, not only on a server."
  - id_key: q5
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "What is the relationship between Git and GitHub?"
    options:
      - text: "They are two names for the same program"
      - text: "GitHub is a hosting service for Git repositories that adds features like pull requests; Git is the version control program itself"
        correct: true
      - text: "Git is the website, GitHub is the command-line tool"
      - text: "GitHub is required for Git to work"
    explanation: "Git runs on your machine and works without any server. GitHub, GitLab and Bitbucket host shared copies and add review, CI and access control. Git does not depend on them."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You overwrote report.txt with junk. It was committed yesterday. Which command brings back yesterday's version of the file?"
    options:
      - text: "git restore report.txt"
        correct: true
      - text: "git commit report.txt"
      - text: "git init"
      - text: "git log report.txt"
    explanation: "git restore copies the committed version over the working copy. git commit would save the junk as a new snapshot, git init creates a new repository, and git log only lists history."
---
