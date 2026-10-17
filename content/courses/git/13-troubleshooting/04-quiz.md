---
kind: quiz
id_key: git/troubleshooting/quiz
course: git
section: troubleshooting
section_title: "Troubleshooting Playbook"
section_position: 13
title: "Quiz: Troubleshooting"
position: 3
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Pro Git book, ch. 7 and 10.7; git-filter-repo documentation
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You pushed a commit containing a live cloud access key to a private repo 10 minutes ago. What is the FIRST thing to do?"
    options:
      - text: "Run git filter-repo to remove it from history"
      - text: "Revoke/rotate the key with the cloud provider"
        correct: true
      - text: "Delete the file in a new commit"
      - text: "Make the repository private again"
    explanation: "Assume the key is compromised the moment it left your machine. Rotation is the only real fix; cleaning history and deleting the file only reduce future exposure, and the repo is already private."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You made three commits on local main that should be on a feature branch. Nothing is pushed. Which sequence is correct?"
    options:
      - text: "git branch feature/x; git reset --hard origin/main; git switch feature/x"
        correct: true
      - text: "git reset --hard origin/main; git branch feature/x"
      - text: "git push --force; git switch -c feature/x"
      - text: "git revert HEAD~3..HEAD; git switch -c feature/x"
    explanation: "Label the commits first, then move main back. Resetting first would leave the commits unlabelled (recoverable only via reflog), force-pushing publishes the mistake, and revert adds inverse commits to main instead of moving the work."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Every Git command fails with \"Unable to create '.git/index.lock': File exists\". No other Git process is running. What do you do?"
    options:
      - text: "Delete the repository and re-clone"
      - text: "Remove the stale .git/index.lock file"
        correct: true
      - text: "Run git gc --prune=now"
      - text: "Run git reset --hard"
    explanation: "A crashed Git process left its lock file. Once you have confirmed nothing is running, deleting it is safe. Re-cloning throws away local branches and reflogs, gc and reset do not remove the lock (and reset would fail on it)."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A teammate on Windows commits and suddenly every line of every file shows as changed. What is the lasting team-wide fix?"
    options:
      - text: "Ask everyone to use the same editor"
      - text: "Add a .gitattributes with text=auto (and eol rules), then git add --renormalize . and commit"
        correct: true
      - text: "Disable git diff"
      - text: "Use git blame -w"
    explanation: "Line-ending normalisation belongs in .gitattributes, which is committed and applies to everyone. Editors vary, disabling diff hides the problem, and blame -w only affects blame output."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You dropped a stash yesterday by mistake. How can you find it?"
    options:
      - text: "git reflog shows dropped stashes"
      - text: "git fsck --no-reflogs --unreachable lists dangling commits; the stash commit has a subject like 'On main: ...'"
        correct: true
      - text: "git stash list --all"
      - text: "It cannot be recovered"
    explanation: "Stash commits are not in HEAD's reflog and leave refs/stash when dropped, but the objects remain until gc prunes them. stash list has no --all to show dropped entries."
  - id_key: q6
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "After rewriting history with git filter-repo and force-pushing, why must teammates re-clone instead of just pulling?"
    options:
      - text: "Pulling is disabled after a force push"
      - text: "Their clones still hold the old commits containing the secret; merging would bring them back, and every rewritten commit has a new hash"
        correct: true
      - text: "filter-repo changes the remote URL"
      - text: "Re-cloning is faster than pulling"
    explanation: "A pull would merge the old history (with the secret) into the new one. Pulling still works technically, the URL is unchanged, and speed is not the point."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (Section 12): a new teammate's clone has an empty vendor/ui-lib folder and the build fails. What should they run?"
    options:
      - text: "git submodule update --init --recursive"
        correct: true
      - text: "git pull --rebase"
      - text: "git worktree add vendor/ui-lib"
      - text: "git lfs pull"
    explanation: "A plain clone does not fetch submodule contents. pull updates the parent only, worktree creates a checkout of the same repo, and LFS handles large files, not submodules."
---
