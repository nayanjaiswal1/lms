---
kind: quiz
id_key: git/undo-recovery/quiz
course: git
section: undo-recovery
section_title: "Undo and Recovery"
section_position: 9
title: "Quiz: Undo and Recovery"
position: 7
estimated_minutes: 12
pass_percentage: 70
duration_minutes: 15
source:
  - Pro Git book, ch. 2.4, 7.3, 7.7
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A commit with a broken migration was pushed to main an hour ago; CI and two teammates have pulled it. What is the right undo?"
    options:
      - text: "git reset --hard HEAD~1 and git push --force"
      - text: "git revert <hash> and git push"
        correct: true
      - text: "git restore --source=HEAD~1 . and commit nothing"
      - text: "git commit --amend and push"
    explanation: "Shared history must only grow, so add an inverse commit. reset + force and amend + push both rewrite commits others have; restoring files without committing changes nothing for anyone else."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You made 4 local commits that should be one. You want all their changes staged so you can commit once. Which command?"
    options:
      - text: "git reset --soft HEAD~4"
        correct: true
      - text: "git reset --hard HEAD~4"
      - text: "git revert HEAD~4"
      - text: "git restore --staged ."
    explanation: "--soft moves the branch back but leaves everything staged. --hard would discard the changes, revert adds an inverse commit, and restore --staged unstages instead of un-committing."
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which of these can permanently lose work that Git cannot recover?"
    options:
      - text: "git reset --hard HEAD~2 on committed work"
      - text: "git branch -D feature after committing on it"
      - text: "git restore app.py on edits that were never staged or committed"
        correct: true
      - text: "Dropping a commit in interactive rebase"
    explanation: "Never-staged edits were never stored, so nothing can bring them back. The other three lose only refs; the commits are still in the reflog."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You reverted a merge of feature/search last week. The team fixed the bug on feature/search and merged it again, but most of the search code is still missing on main. Why?"
    options:
      - text: "Git considers the old feature commits already merged, and the revert still undoes them; revert the revert first"
        correct: true
      - text: "Merges never bring back deleted files"
      - text: "The second merge needed --no-ff"
      - text: "rerere replayed an old resolution"
    explanation: "Reverting a merge undoes the changes but not the fact that the commits are ancestors of main. Only the new fix commits come in on re-merge. --no-ff and rerere do not matter here, and merges can restore files."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A security fix is on main as commit 9f2c1e7. Release branch release/1.4 needs only that fix. What do you run on release/1.4?"
    options:
      - text: "git merge main"
      - text: "git cherry-pick -x 9f2c1e7"
        correct: true
      - text: "git rebase main"
      - text: "git revert 9f2c1e7"
    explanation: "cherry-pick copies just that commit; -x records the source. Merging or rebasing would bring every other main commit into the release, and revert would undo the fix."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You need to switch branches urgently. You have edits to two tracked files and one new untracked file. Which command parks all three?"
    options:
      - text: "git stash"
      - text: "git stash push -u"
        correct: true
      - text: "git stash apply"
      - text: "git restore ."
    explanation: "-u includes untracked files; plain stash would leave the new file behind. apply restores a stash rather than creating one, and restore discards edits."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "After `git reset --hard HEAD~3` you realise you needed those commits. `git reflog` shows `HEAD@{0}: reset: moving to HEAD~3` and `HEAD@{1}: commit: Add export`. What restores the branch?"
    options:
      - text: "git reset --hard HEAD@{1}"
        correct: true
      - text: "git reset --hard HEAD@{0}"
      - text: "git revert HEAD@{1}"
      - text: "git stash pop"
    explanation: "Each reflog line is the state after an action; HEAD@{1} is the state just before the reset. HEAD@{0} is the current (bad) state, revert would add an inverse commit, and stash is unrelated."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (Section 8): you rebased your already-pushed PR branch. What is the correct push?"
    options:
      - text: "git push --force-with-lease"
        correct: true
      - text: "git push"
      - text: "git push --force on main"
      - text: "git push --tags"
    explanation: "History was rewritten, so a plain push is rejected; the lease protects any commits you have not seen. Force-pushing main is never right, and --tags pushes tags only."
---
