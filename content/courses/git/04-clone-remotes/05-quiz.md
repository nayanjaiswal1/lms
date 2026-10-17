---
kind: quiz
id_key: git/clone-remotes/quiz
course: git
section: clone-remotes
section_title: "Clone, Fetch, Pull and Push"
section_position: 4
title: "Quiz: Clone, Fetch, Pull and Push"
position: 4
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Pro Git book, ch. 3.5 "Remote Branches"
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "`git status` says 'Your branch is up to date with origin/main', yet a teammate says they pushed an hour ago. Who is right?"
    options:
      - text: "Git; status always checks the server"
      - text: "Possibly both: status compares with origin/main as of your last fetch, so you may simply not have fetched"
        correct: true
      - text: "The teammate; status is broken"
      - text: "Neither; pushes take a day to appear"
    explanation: "status never contacts the server. Run git fetch and status will show 'behind'. Nothing is broken, and pushes are visible immediately to anyone who fetches."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You want to review a teammate's new commits on main before they touch your branch. Which sequence fits?"
    options:
      - text: "git pull, then git log"
      - text: "git fetch, then git log main..origin/main and git diff main...origin/main"
        correct: true
      - text: "git push, then git log"
      - text: "git clone into a new folder every time"
    explanation: "fetch only updates origin/main, so you can inspect first. pull would integrate before you looked, push sends your work instead, and re-cloning is slow and unnecessary."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "`git push` prints '! [rejected] main -> main (fetch first)'. A colleague suggests `git push --force`. What happens if you do?"
    options:
      - text: "The server keeps both your commits and theirs"
      - text: "The server's main is replaced by yours and the teammate's commit disappears from it"
        correct: true
      - text: "Git merges automatically on the server"
      - text: "The push is still rejected; force only works on tags"
    explanation: "Force overwrites the server branch, dropping commits you did not have. Servers never merge for you, and force works on branches (unless the server protects them). Integrate and push normally instead."
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You created feature/cart locally. What is the command to publish it AND make later plain `git push` work?"
    options:
      - text: "git push"
      - text: "git push -u origin feature/cart"
        correct: true
      - text: "git fetch -u origin feature/cart"
      - text: "git remote add feature/cart"
    explanation: "-u sets the upstream while pushing. Plain git push fails for a branch with no upstream (unless push.autoSetupRemote is set), fetch downloads instead of uploading, and remote add creates a remote, not a branch."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "`git pull` fails with 'fatal: Need to specify how to reconcile divergent branches.' What does it mean?"
    options:
      - text: "The remote is unreachable"
      - text: "Both your branch and the remote branch have new commits, and no pull strategy (merge, rebase or ff-only) is configured"
        correct: true
      - text: "You have a merge conflict"
      - text: "Your branch has no upstream"
    explanation: "Set pull.rebase true/false or pull.ff only, or pass --rebase/--no-rebase. An unreachable remote gives a connection error, a conflict only happens after integration starts, and a missing upstream gives a different message."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Branches deleted on the server still appear in `git branch -r`. How do you clean them up?"
    options:
      - text: "git branch -D origin/old-branch"
      - text: "git fetch --prune"
        correct: true
      - text: "git push --prune"
      - text: "git remote remove origin"
    explanation: "fetch --prune removes remote-tracking branches whose server branch is gone. branch -D works on local branches, push --prune deletes on the server (dangerous), and removing origin breaks your setup."
  - id_key: q7
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Review (Section 3): you get 'Permission denied (publickey)' on push. Which is the most likely cause?"
    options:
      - text: "Your public key is not registered with the host or not loaded in ssh-agent"
        correct: true
      - text: "You have not fetched recently"
      - text: "The branch has no upstream"
      - text: "The commit message is too long"
    explanation: "publickey errors are SSH authentication problems. Fetch state, upstreams and messages do not affect authentication."
---
