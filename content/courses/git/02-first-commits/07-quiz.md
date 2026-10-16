---
kind: quiz
id_key: git/first-commits/quiz
course: git
section: first-commits
section_title: Setup and First Commits
section_position: 2
title: "Quiz: Setup and First Commits"
position: 6
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Pro Git book, ch. 2 "Git Basics"
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You edit config.py and utils.py, run `git add config.py`, then `git commit -m 'Fix config'`. A teammate pulls your commit. Does it contain the utils.py change?"
    options:
      - text: "Yes, commit saves every modified file"
      - text: "No, only what was in the index is committed; utils.py is still an unstaged change on your machine"
        correct: true
      - text: "Yes, but only if utils.py is tracked"
      - text: "No, and the utils.py change is now lost"
    explanation: "A commit snapshots the index. utils.py was never added, so it is not in the commit, even though it is tracked. The change is not lost: it is still in your working tree, listed under 'Changes not staged for commit'."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "`git status -s` shows `MM report.md`. What does it mean?"
    options:
      - text: "The file has a merge conflict"
      - text: "The file was modified twice in two commits"
      - text: "The file has staged changes AND further unstaged changes made after `git add`"
        correct: true
      - text: "The file is modified on two branches"
    explanation: "Left column = index vs HEAD (staged), right column = working tree vs index (not staged). Both show M. A conflict shows UU, and short status never looks at other commits or branches."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Your project .gitignore contains `*.log`, but `git status` still lists `server.log` as modified. Why?"
    options:
      - text: "The pattern needs to be `**/*.log`"
      - text: "server.log was committed before the rule existed, and .gitignore never affects tracked files"
        correct: true
      - text: ".gitignore only works after a push"
      - text: "Git caches ignore rules for 24 hours"
    explanation: "Ignore rules only stop untracked files. Use `git rm --cached server.log` and commit to stop tracking it. `*.log` already matches at any depth, and there is no push requirement or cache delay."
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which command shows exactly what your next commit will contain?"
    options:
      - text: "git diff"
      - text: "git diff --staged"
        correct: true
      - text: "git log -p"
      - text: "git status --ignored"
    explanation: "--staged compares the index with HEAD, which is the next commit's content. Plain git diff shows changes NOT staged, git log -p shows past commits, and --ignored lists ignored files."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Your global email is personal, but in one work repository you must commit as ada@company.com. What is the cleanest fix?"
    options:
      - text: "Change the global email every time you switch projects"
      - text: "Run `git config user.email ada@company.com` inside the work repository"
        correct: true
      - text: "Edit each commit after making it"
      - text: "Set it with --system"
    explanation: "Without a flag, git config writes the local .git/config, which overrides global only for that repo. Switching global settings is error-prone, editing every commit is wasteful, and --system would affect every repo and user on the machine."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You committed and pushed to the shared main branch, then noticed a typo in the message. What should you do?"
    options:
      - text: "git commit --amend and git push --force"
      - text: "Leave it, or fix it with a follow-up commit; do not rewrite a pushed commit on a shared branch"
        correct: true
      - text: "Delete the repository and push again"
      - text: "git commit --amend; amend never changes hashes"
    explanation: "Amend creates a new commit with a new hash, so force-pushing it rewrites history teammates may already have. A message typo is not worth that. Amend always changes the hash, and deleting the repo is absurd."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A .env file with an API key was committed two weeks ago. You add .env to .gitignore and run `git rm --cached .env`. What is still required?"
    options:
      - text: "Nothing; the key is now gone"
      - text: "Rotate (revoke and replace) the API key, because it is still readable in old commits"
        correct: true
      - text: "Run git gc to delete the key from history"
      - text: "Rename the file to .env.old"
    explanation: "Old commits still contain the key; anyone with the repo can read it. Rotate it first. git gc does not remove objects that are still reachable from history, and renaming does nothing to old commits."
  - id_key: q8
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Review (Section 1): what does `git restore notes.txt` do?"
    options:
      - text: "Copies the version of notes.txt from the index back over your working copy, discarding unstaged edits"
        correct: true
      - text: "Undoes the last commit"
      - text: "Downloads notes.txt from the server"
      - text: "Stages notes.txt"
    explanation: "restore replaces the working-tree file with the staged/committed version. It does not move commits, never talks to a server, and staging is git add."
---
