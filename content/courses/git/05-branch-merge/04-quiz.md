---
kind: quiz
id_key: git/branch-merge/quiz
course: git
section: branch-merge
section_title: "Branching and Merging"
section_position: 5
title: "Quiz: Branching and Merging"
position: 3
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Pro Git book, ch. 3 "Git Branching"
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You are on main. You run `git merge feature`. main has had no new commits since feature was created. What happens?"
    options:
      - text: "A merge commit with two parents is created"
      - text: "main's label slides forward to feature's tip (fast-forward); no new commit"
        correct: true
      - text: "feature is moved to main"
      - text: "Git refuses because nothing diverged"
    explanation: "main is an ancestor of feature, so Git fast-forwards. A merge commit appears only with --no-ff or when both sides moved. The branch you merge from never moves, and Git does not refuse a fast-forward."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Your team wants every pull request to show up as one revertable unit in main, while keeping the individual commits. Which merge style fits?"
    options:
      - text: "git merge --ff-only"
      - text: "git merge --no-ff"
        correct: true
      - text: "git merge --squash"
      - text: "Rebase and fast-forward"
    explanation: "--no-ff always records a merge commit grouping the branch's commits; revert that one commit to undo the feature. --ff-only and rebase+ff leave no grouping commit, and --squash keeps the unit but throws away the individual commits."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "After `git merge --squash feature && git commit`, `git branch -d feature` refuses. Why?"
    options:
      - text: "Squash merges are not real merges: the new commit has one parent, so Git does not see feature's commits as merged"
        correct: true
      - text: "You must push first"
      - text: "-d only works on remote branches"
      - text: "The squash failed silently"
    explanation: "Squash copies the changes into a single ordinary commit. feature's commits are not ancestors of main, so -d's safety check fails. Use -D once you are sure. Pushing is irrelevant, -d is for local branches, and the squash worked."
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You try to switch branches and get 'Your local changes to the following files would be overwritten'. What is the safe next step?"
    options:
      - text: "git switch --force"
      - text: "Commit or stash your changes, then switch"
        correct: true
      - text: "Delete the other branch"
      - text: "git reset --hard"
    explanation: "Git refuses to destroy uncommitted edits. Commit or stash keeps them. --force and reset --hard throw your edits away, and deleting the branch loses its commits' label."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "M is a merge commit made on main from feature. What are M^1 and M^2?"
    options:
      - text: "M^1 is the previous main tip; M^2 is the feature tip"
        correct: true
      - text: "M^1 is the feature tip; M^2 is the previous main tip"
      - text: "M^1 and M^2 are the two commits before M on main"
      - text: "They are the same commit"
    explanation: "The first parent is the branch you were on when merging; the second parent is the branch you merged in. Two commits back on main would be M~2."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You delete a merged feature branch with git branch -d. What happens to its commits?"
    options:
      - text: "They are deleted"
      - text: "Nothing; they are still reachable from main because they were merged"
        correct: true
      - text: "They are moved into main as new commits"
      - text: "They become a tag"
    explanation: "A branch is only a label. Merged commits are part of main's history, so deleting the label loses nothing. Nothing is copied or turned into a tag."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (Section 4): you want to update local main from origin/main and be sure no merge commit is ever created by accident. Which command?"
    options:
      - text: "git pull --ff-only"
        correct: true
      - text: "git pull --no-rebase"
      - text: "git fetch --all"
      - text: "git push --force"
    explanation: "--ff-only refuses if a fast-forward is not possible. pull --no-rebase may create a merge commit, fetch alone does not update main, and push --force sends your branch the wrong way."
---
