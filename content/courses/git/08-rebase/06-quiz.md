---
kind: quiz
id_key: git/rebase/quiz
course: git
section: rebase
section_title: "Rebase and Rewriting History"
section_position: 8
title: "Quiz: Rebase and Rewriting History"
position: 5
estimated_minutes: 12
pass_percentage: 70
duration_minutes: 14
source:
  - Pro Git book, ch. 3.6 and ch. 7.6
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You rebase your private branch feature/x onto main. A colleague asks why the commit hashes in your PR all changed. What is the correct explanation?"
    options:
      - text: "Rebase re-applies each commit on a new parent, and a commit's hash includes its parent, so every replayed commit is new"
        correct: true
      - text: "Git randomises hashes on every push"
      - text: "Rebase compresses commits, which changes hashes"
      - text: "The hashes did not change; only the dates did"
    explanation: "New parent -> new commit object -> new hash. Hashes are deterministic, not random; rebase does not compress; and the hashes do change."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Mid-rebase, a conflict appears in config.yml. You want to keep YOUR branch's version of the file. Which command?"
    options:
      - text: "git checkout --ours config.yml"
      - text: "git checkout --theirs config.yml"
        correct: true
      - text: "git merge --abort"
      - text: "git rebase --skip"
    explanation: "In a rebase the labels flip: ours = the base being rebased onto, theirs = your commit being replayed. --ours would take main's version, merge --abort does not apply to a rebase, and --skip would drop your whole commit."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Two developers push to the shared branch release/2.1. One of them wants to rebase it onto main to 'tidy it up'. What is the best advice?"
    options:
      - text: "Go ahead and push --force"
      - text: "Do not rebase a shared branch; merge main into it, or coordinate so nobody has unpushed work and everyone resets afterwards"
        correct: true
      - text: "Rebase is fine as long as you use --force-with-lease"
      - text: "Delete the branch and recreate it"
    explanation: "The golden rule: never rebase commits others have built on. --force-with-lease protects against overwriting unseen commits, but teammates still hold the old history and must repair their clones. Deleting and recreating is the same rewrite."
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "In the interactive rebase todo list, where is the oldest commit?"
    options:
      - text: "At the top"
        correct: true
      - text: "At the bottom"
      - text: "Sorted by author"
      - text: "It is not shown"
    explanation: "The todo list is the order commits will be replayed, oldest first. git log shows newest first, which is why people often read the list upside down."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You want to fold a 'fix typo' commit into the commit above it and throw away the 'fix typo' message. Which verb?"
    options:
      - text: "squash"
      - text: "fixup"
        correct: true
      - text: "edit"
      - text: "drop"
    explanation: "fixup melds and discards the message. squash melds but opens the editor to combine messages, edit stops for amending, and drop removes the change entirely."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "After rebasing your PR branch, `git push --force-with-lease` is rejected with '(stale info)'. What happened?"
    options:
      - text: "Your network is slow"
      - text: "Someone pushed to the branch after your last fetch, so the server no longer matches your origin/<branch>"
        correct: true
      - text: "Force-with-lease only works on main"
      - text: "Your branch has a merge conflict"
    explanation: "The lease protects that unseen commit. Fetch, integrate it, and push again. It is not a network or conflict problem, and the option works on any branch."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You made one unpushed commit on main; a teammate pushed one too. You want to avoid a 'Merge branch main of ...' commit. Which command?"
    options:
      - text: "git pull --rebase"
        correct: true
      - text: "git push --force"
      - text: "git merge --no-ff origin/main"
      - text: "git rebase -i HEAD~10"
    explanation: "pull --rebase replays your unpushed commit on top of origin/main. Safe because nobody else has it. Force-push would delete the teammate's commit, --no-ff creates exactly the merge commit you wanted to avoid, and rebase -i HEAD~10 rewrites shared commits."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (Section 7): you dropped the wrong commit during an interactive rebase that finished a minute ago. How do you get back the pre-rebase branch?"
    options:
      - text: "git reset --hard ORIG_HEAD, or find the pre-rebase hash in git reflog and reset to it"
        correct: true
      - text: "git rebase --abort"
      - text: "It is lost"
      - text: "git revert HEAD"
    explanation: "Rebase records ORIG_HEAD and the reflog keeps the old tip. --abort only works while the rebase is still running, nothing is lost, and revert would add an inverse of the last commit, not restore the dropped one."
---
