---
kind: quiz
id_key: git/merge-conflicts/quiz
course: git
section: merge-conflicts
section_title: "Merge Conflicts"
section_position: 6
title: "Quiz: Merge Conflicts"
position: 4
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Pro Git book, ch. 3.2 and ch. 7.8-7.9
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Since the merge base, main changed line 10 of api.py and feature changed line 80 of the same file. You merge feature into main. What happens?"
    options:
      - text: "Conflict, because both branches changed api.py"
      - text: "Clean merge: each region was changed on only one side, so Git takes both changes"
        correct: true
      - text: "Git keeps main's version of the whole file"
      - text: "Git asks you to choose one version of the file"
    explanation: "Conflicts are per region (hunk), not per file. Different, non-adjacent regions merge automatically. Git never keeps one side of a whole file unless told to."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You are on main merging `feature/pay`. The block shows `<<<<<<< HEAD` / `fee=2` / `=======` / `fee=3` / `>>>>>>> feature/pay`. Which statement is true?"
    options:
      - text: "fee=2 is from feature/pay"
      - text: "fee=2 is from main (ours); fee=3 is from feature/pay (theirs)"
        correct: true
      - text: "fee=2 is the original value from the merge base"
      - text: "Both values come from main"
    explanation: "In a merge, HEAD is the branch you are on. The ancestor value only appears with diff3/zdiff3 style, between ||||||| and =======."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You fixed both conflicted files and ran `git add` on them. What does `git status` say, and what is the next command?"
    options:
      - text: "'All conflicts fixed but you are still merging'; run git commit"
        correct: true
      - text: "'nothing to commit'; run git push"
      - text: "'You have unmerged paths'; run git merge --continue only"
      - text: "'detached HEAD'; run git switch main"
    explanation: "After staging all resolutions you are still mid-merge until you commit (git merge --continue also works and runs commit). 'Unmerged paths' would mean a file is still unresolved, and you are not detached."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "In a big merge, package-lock.json conflicts in 40 places. You know the incoming branch's lock file is correct. What is the quickest correct move?"
    options:
      - text: "Edit all 40 blocks by hand"
      - text: "git checkout --theirs package-lock.json, then git add it"
        correct: true
      - text: "git merge --abort and delete the file"
      - text: "git add package-lock.json with the markers"
    explanation: "--theirs takes the merged-in branch's whole file. Hand-editing is slow and risky, aborting loses the merge, and staging markers commits a broken file."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A merge resolved without any conflict, but the app no longer starts: main renamed `get_user()` to `fetch_user()` while feature added a new call to `get_user()`. What does this show?"
    options:
      - text: "Git has a bug"
      - text: "A textually clean merge can still be semantically broken; always run tests after merging"
        correct: true
      - text: "rerere applied a wrong resolution"
      - text: "The merge base was wrong"
    explanation: "Git merges text, not meaning. The edits touched different lines, so there was no conflict. Nothing is buggy, rerere only acts on recorded conflicts, and the merge base was correct."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You rebase a long-lived branch onto main every morning and resolve the same conflict each time. What helps most?"
    options:
      - text: "git config rerere.enabled true"
        correct: true
      - text: "git config merge.ff false"
      - text: "git gc --aggressive"
      - text: "git merge -X theirs every time"
    explanation: "rerere replays recorded resolutions of identical conflicts. merge.ff changes history shape, gc compresses storage, and -X theirs blindly discards your side of every conflict."
  - id_key: q7
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Review (Section 5): you merge feature into main and Git prints 'Fast-forward'. How many new commits were created?"
    options:
      - text: "Zero; main's label just moved forward"
        correct: true
      - text: "One merge commit"
      - text: "One per feature commit"
      - text: "Two"
    explanation: "A fast-forward creates no commit at all. A merge commit appears only when histories diverged or with --no-ff."
---
