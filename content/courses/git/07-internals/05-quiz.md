---
kind: quiz
id_key: git/internals/quiz
course: git
section: internals
section_title: "Under the Hood: Objects, Refs and the Index"
section_position: 7
title: "Quiz: Under the Hood"
position: 4
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Pro Git book, ch. 10 "Git Internals"
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You rename src/util.py to src/helpers.py without changing its content and commit. Which new objects does Git create?"
    options:
      - text: "A new blob for the file, a new tree and a new commit"
      - text: "New trees (src and root) and a new commit; the blob is reused because the content is identical"
        correct: true
      - text: "Only a new commit"
      - text: "Nothing; renames are stored in the index only"
    explanation: "Blobs hold content only, so the same content keeps the same blob. Names live in trees, so the src tree and the root tree change, and a new commit points at the new root tree."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which object type stores the commit message and the parent hashes?"
    options:
      - text: "blob"
      - text: "tree"
      - text: "commit"
        correct: true
      - text: "ref"
    explanation: "A commit object contains tree, parent(s), author, committer and message. Blobs hold file bytes, trees hold names, and refs are not objects at all, just names pointing at objects."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You checked out an old commit by hash, made two commits, then ran `git switch main`. Git warns you are leaving 2 commits behind. How do you keep them?"
    options:
      - text: "They are already on main"
      - text: "Find them in `git reflog` and run `git branch keep <hash>`"
        correct: true
      - text: "Run git gc so they are saved"
      - text: "They are lost permanently"
    explanation: "Commits on a detached HEAD belong to no branch, but the HEAD reflog remembers them. A branch makes them reachable again. gc does the opposite (prunes), and they are not on main."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "M is a merge commit. What does `git show M^2` show?"
    options:
      - text: "The commit two generations before M on the first-parent line"
      - text: "The second parent of M, i.e. the tip of the branch that was merged in"
        correct: true
      - text: "The second file changed in M"
      - text: "Nothing; ^2 is invalid"
    explanation: "^n picks the nth parent; ~n walks n generations back along first parents. M~2 would be the grandparent on the main line."
  - id_key: q5
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "During a merge conflict, `git ls-files -s app.conf` prints three lines with stage numbers 1, 2 and 3. What is stage 3?"
    options:
      - text: "The common ancestor version"
      - text: "Your version (HEAD)"
      - text: "The incoming branch's version (theirs)"
        correct: true
      - text: "The working-tree version"
    explanation: "Stage 1 = merge base, 2 = ours, 3 = theirs. The working tree file is not in the index at all; it is what you edit."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A teammate ran `git reset --hard HEAD~3` an hour ago and now needs those commits. Which statement is correct?"
    options:
      - text: "They are gone; reset --hard deletes commits immediately"
      - text: "They are still in the object database and listed in the reflog; recover with git reflog and git reset --hard <hash>"
        correct: true
      - text: "Only a remote can restore them"
      - text: "git gc --prune=now will restore them"
    explanation: "reset only moves a ref. The commits stay reachable from the reflog (30 days by default for unreachable entries). gc --prune=now would remove unreachable objects, the opposite of what you want."
  - id_key: q7
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which kind of work can Git NOT recover?"
    options:
      - text: "A commit removed by reset --hard"
      - text: "A deleted branch's commits"
      - text: "Edits you never staged or committed, discarded by git restore or reset --hard"
        correct: true
      - text: "A commit dropped during interactive rebase"
    explanation: "Git only knows about content it stored. Never-staged edits were never written as objects. All the others are still reachable via the reflog for weeks."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (Section 6): during a MERGE conflict, what does `git checkout --ours file` keep?"
    options:
      - text: "The version from the branch you are on (HEAD)"
        correct: true
      - text: "The version from the branch being merged in"
      - text: "The merge base version"
      - text: "The version with conflict markers"
    explanation: "In a merge, ours = HEAD = the current branch. (In a rebase it flips, which the next section covers.)"
---
