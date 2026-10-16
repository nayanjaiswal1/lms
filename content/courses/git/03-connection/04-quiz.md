---
kind: quiz
id_key: git/connection/quiz
course: git
section: connection
section_title: "Connecting to the Team"
section_position: 3
title: "Quiz: Connecting to the Team"
position: 3
estimated_minutes: 8
pass_percentage: 70
duration_minutes: 10
source:
  - Pro Git book, ch. 2.5 and ch. 4
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "`git fetch` fails with 'ERROR: Repository not found.' `git remote -v` shows origin as git@github.com:brightsde/shop.git, and you do have access to brightside/shop. What do you do?"
    options:
      - text: "Generate a new SSH key"
      - text: "Fix the typo with `git remote set-url origin git@github.com:brightside/shop.git`"
        correct: true
      - text: "Delete and re-clone the repository"
      - text: "Run git init"
    explanation: "The URL says brightsde, a typo. set-url fixes it in one command. A key problem would say 'Permission denied (publickey)', re-cloning is unnecessary, and git init creates a new empty repository."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which file do you paste into GitHub's 'SSH keys' settings page?"
    options:
      - text: "~/.ssh/id_ed25519"
      - text: "~/.ssh/id_ed25519.pub"
        correct: true
      - text: "~/.gitconfig"
      - text: "~/.git-credentials"
    explanation: "The .pub file is the public key and is safe to share. The file without .pub is the private key and must never leave your machine. .gitconfig holds settings and .git-credentials holds stored passwords/tokens."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You forked a project and cloned your fork. You want to receive new commits from the original project. What is the usual setup?"
    options:
      - text: "Change origin to the original project's URL"
      - text: "Add a second remote called upstream pointing to the original, and fetch from it"
        correct: true
      - text: "Clone the original project into a subfolder"
      - text: "Ask the maintainers to push to your fork"
    explanation: "origin stays your fork (you push there; you usually cannot push to the original), upstream is the read source. Changing origin would break your pushes, a nested clone is a separate repo, and maintainers do not push to forks."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A teammate stored their token with `git config --global credential.helper store` on a shared lab machine. What is the risk?"
    options:
      - text: "None; the token is encrypted"
      - text: "The token is saved in plain text in ~/.git-credentials where others with access to the account or backups can read it"
        correct: true
      - text: "The token expires immediately"
      - text: "Git will stop asking for SSH keys"
    explanation: "The store helper writes credentials unencrypted. Prefer cache (memory) or an OS keychain/Credential Manager. Storage does not change the token's expiry, and the helper does not affect SSH."
  - id_key: q5
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "What does `git remote remove backup` do?"
    options:
      - text: "Deletes the backup repository on the server"
      - text: "Removes only the local name 'backup' and its remote-tracking branches from your repository config"
        correct: true
      - text: "Deletes all branches that were pushed to backup"
      - text: "Removes the last commit pushed to backup"
    explanation: "Remotes are local bookmarks. Removing one never touches the server or any commits."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Review (Section 2): you ran `git add app.py`, then edited app.py again, then committed. Which version is in the commit?"
    options:
      - text: "The version from the moment you ran git add"
        correct: true
      - text: "The latest version on disk"
      - text: "Both versions, as two commits"
      - text: "Neither; the commit fails"
    explanation: "The index holds the content as it was when you staged it. The later edit is still unstaged. Git never splits it into two commits by itself, and the commit succeeds."
---
