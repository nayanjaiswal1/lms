---
kind: quiz
id_key: git/power-tools/quiz
course: git
section: power-tools
section_title: "Power Tools: Worktrees, Submodules and Large Repos"
section_position: 12
title: "Quiz: Worktrees, Submodules and Large Repos"
position: 4
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - git-worktree(1), git-submodule(1), git-clone(1), Git LFS docs
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You are mid-feature with a running dev server and uncommitted edits. A production fix must ship now. What is the least disruptive approach?"
    options:
      - text: "git stash, switch to main, fix, switch back, git stash pop"
      - text: "git worktree add ../hotfix -b hotfix/x main and fix it in that folder"
        correct: true
      - text: "Commit your half-finished work to main"
      - text: "Clone the repository again from the server"
    explanation: "A worktree gives a second checkout sharing the same repository, so your feature folder, files and server stay untouched. Stashing works but disrupts the running setup, committing WIP to main is wrong, and a second clone wastes disk and does not share commits."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "`git worktree add ../review main` fails with \"'main' is already used by worktree\". Why?"
    options:
      - text: "Worktrees cannot use main at all"
      - text: "A branch can be checked out in only one worktree at a time, and main is checked out in your primary folder"
        correct: true
      - text: "The folder ../review already exists"
      - text: "You must fetch first"
    explanation: "Git prevents two working trees from moving the same branch. Use another branch or --detach. main is allowed in a worktree if no other worktree has it; the folder and fetch state are not the issue here."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What does a parent repository store for a submodule at vendor/ui-lib?"
    options:
      - text: "A full copy of the library's files and history"
      - text: "The library's URL in .gitmodules and a gitlink: the exact commit hash of the library to use"
        correct: true
      - text: "Only the URL; the latest commit is always used"
      - text: "A symlink to another folder"
    explanation: "Submodules pin an exact commit (tree entry mode 160000). Files and history live in the library's own repository, nothing floats to 'latest' automatically, and no symlink is involved."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "`git submodule add /srv/libs/ui.git vendor/ui` fails with \"fatal: transport 'file' not allowed\". What is going on?"
    options:
      - text: "The path is wrong"
      - text: "Since Git 2.38.1, submodules from local or file:// URLs are blocked by default for security; allow it for a trusted repo with -c protocol.file.allow=always"
        correct: true
      - text: "Submodules require SSH"
      - text: "You need to run git init in vendor/ui first"
    explanation: "A security fix disabled the file transport for submodules by default. A wrong path gives a different 'not a git repository' error, HTTPS and SSH both work, and git init in the target is not needed."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Developers on a 15 GB monorepo want fast clones but still need full `git log` and `git blame`. Which option fits best?"
    options:
      - text: "git clone --depth 1"
      - text: "git clone --filter=blob:none (partial clone)"
        correct: true
      - text: "Download a zip of the repository"
      - text: "git clone --bare"
    explanation: "Partial clone downloads all commits and trees, fetching file contents on demand, so history commands still work. A shallow clone cuts history (log/blame/bisect break), a zip has no history at all, and --bare has no working tree to develop in."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "A designer wants to commit 300 MB Photoshop files that change weekly. What should the team do first?"
    options:
      - text: "Commit them normally; Git compresses everything"
      - text: "Set up Git LFS (git lfs track '*.psd') before the first commit of those files"
        correct: true
      - text: "Put them in .gitignore and email them"
      - text: "Use a shallow clone"
    explanation: "Every version of a committed binary stays in history and every clone downloads it; binaries also compress poorly. LFS stores pointers in Git and the files on an LFS server. Emailing loses versioning, and shallow clones do not stop the history from growing."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (Section 11): you want everyone's commits checked for a ticket key in the message, including people who use --no-verify. Where must the check live?"
    options:
      - text: "In CI and/or a server-side hook (e.g. pre-receive), backed by branch protection"
        correct: true
      - text: "Only in .git/hooks/commit-msg"
      - text: "In .gitignore"
      - text: "In each developer's ~/.gitconfig"
    explanation: "Client hooks can be skipped and are not cloned. Only checks on the server or in required CI apply to everyone. .gitignore and personal config cannot enforce anything."
---
