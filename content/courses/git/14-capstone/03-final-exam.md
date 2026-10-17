---
kind: quiz
id_key: git/capstone/final-exam
course: git
section: capstone
section_title: "Capstone: Team Workflow"
section_position: 14
title: "Final Exam: Git"
position: 2
estimated_minutes: 25
pass_percentage: 70
duration_minutes: 30
source:
  - All sections of this course
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You edited three files and ran `git add a.py`. You then run `git commit -m 'Update'`. What is in the commit?"
    options:
      - text: "All three files"
      - text: "Only the change to a.py, as it was when you staged it"
        correct: true
      - text: "Nothing; you must use -a"
      - text: "a.py and any new files"
    explanation: "A commit snapshots the index. Unstaged edits stay in the working tree. -a is optional and only adds tracked modified files; new files are never added implicitly."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You rename README.md to README.txt without changing content and commit. How many NEW blob objects does Git store?"
    options:
      - text: "Zero; the content is identical, so the existing blob is reused"
        correct: true
      - text: "One, for the new name"
      - text: "Two, old and new"
      - text: "It depends on the file size"
    explanation: "Blobs are named by content. Names live in trees, so only a new tree and a new commit are created."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "`git status` says 'Your branch and origin/main have diverged, and have 2 and 3 different commits each'. Your 2 commits are unpushed. Which command gives a linear history safely?"
    options:
      - text: "git push --force"
      - text: "git pull --rebase"
        correct: true
      - text: "git reset --hard origin/main"
      - text: "git merge --squash origin/main"
    explanation: "pull --rebase replays your unpushed commits on top of the 3 remote ones. Force-push deletes the teammates' commits, reset --hard throws away yours, and a squash merge creates an odd unlinked commit."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "During `git rebase main`, a conflict in pricing.py stops the rebase. You want YOUR feature commit's version of that file. Which command?"
    options:
      - text: "git checkout --ours pricing.py"
      - text: "git checkout --theirs pricing.py"
        correct: true
      - text: "git rebase --skip"
      - text: "git merge --abort"
    explanation: "In a rebase, theirs is the commit being replayed (yours) and ours is the base. --skip drops your entire commit and merge --abort does not apply to rebases."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A feature merged into main last week (merge commit M) must be removed from production. main is shared. What do you do?"
    options:
      - text: "git reset --hard M^1 and force-push"
      - text: "git revert -m 1 M and push"
        correct: true
      - text: "git revert M (no options)"
      - text: "git branch -D feature"
    explanation: "-m 1 keeps main's side and undoes what the feature brought in, as a new commit. Reset + force rewrites shared history, revert without -m is refused for merges, and deleting the branch leaves the merged code in main."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You ran `git reset --hard HEAD~4` on your local branch and immediately regret it. What is the fastest recovery?"
    options:
      - text: "git reset --hard ORIG_HEAD (or the hash from git reflog)"
        correct: true
      - text: "git revert HEAD~4"
      - text: "git fetch"
      - text: "Re-clone from the server"
    explanation: "reset records ORIG_HEAD and the reflog has the old tip. revert adds inverse commits, fetch only updates remote-tracking refs, and the server lacks your unpushed commits."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A config value changed from max_conn=10 to max_conn=50 at some point last year. Which command finds the commit?"
    options:
      - text: "git log -S 'max_conn='"
      - text: "git log -G 'max_conn='"
        correct: true
      - text: "git blame -C config.ini"
      - text: "git log --follow config.ini"
    explanation: "The number of 'max_conn=' occurrences did not change, so -S misses it; -G matches changed lines. blame shows only the latest change and --follow is about renames (though it lists all commits touching the file, it does not search content)."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "There are 500 commits between a good tag and the broken HEAD. You have a test script. What gets you to the culprit fastest?"
    options:
      - text: "git bisect start HEAD v2.0 && git bisect run ./test.sh"
        correct: true
      - text: "git log -p and read every diff"
      - text: "git blame on every file"
      - text: "git revert each commit until the test passes"
    explanation: "bisect run needs about 9 test runs (log2 500). Reading diffs or blaming is slow and unreliable, and reverting commits one by one is destructive and linear."
  - id_key: q9
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You rebased your already-pushed PR branch. A reviewer pushed a fixup commit to it 5 minutes ago that you have not fetched. What happens with `git push --force-with-lease`?"
    options:
      - text: "The reviewer's commit is overwritten"
      - text: "The push is rejected as stale, protecting the reviewer's commit"
        correct: true
      - text: "Git merges the two automatically"
      - text: "The push succeeds and keeps both"
    explanation: "The lease checks the server still points where your origin/<branch> says. It does not, so the push is refused. Plain --force would overwrite; Git never merges during push."
  - id_key: q10
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You created an annotated tag v3.0.0 and ran `git push`. Teammates cannot see the tag. Why?"
    options:
      - text: "Annotated tags are local only"
      - text: "Plain git push does not push tags; run git push origin v3.0.0 (or use --follow-tags)"
        correct: true
      - text: "Tags need a separate remote"
      - text: "Teammates must run git tag --sync"
    explanation: "Tags are pushed explicitly. Annotated tags can be pushed like any ref, no separate remote is needed, and --sync does not exist."
  - id_key: q11
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Your team wants the commit-message rule enforced for every contributor, even those who use --no-verify. Where must it be enforced?"
    options:
      - text: "In a committed .githooks/commit-msg only"
      - text: "In CI or a server-side check, with branch protection requiring it"
        correct: true
      - text: "In each developer's global config"
      - text: "In .gitattributes"
    explanation: "Client hooks are skippable and opt-in. Only server-side or required CI checks apply to everyone; config and attributes cannot enforce message rules."
  - id_key: q12
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You need to fix a production bug while your feature branch has uncommitted work and a running dev server. Which tool keeps your current folder untouched?"
    options:
      - text: "git worktree add ../hotfix -b hotfix/bug main"
        correct: true
      - text: "git switch main"
      - text: "git clone --depth 1"
      - text: "git submodule add"
    explanation: "A worktree is a second checkout of the same repository in another folder. Switching changes your current files, a shallow clone is a separate repo without your local branches, and submodules embed other repositories."
  - id_key: q13
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Your CI clone of a 20 GB repository takes 10 minutes; the build needs only the latest files of two folders. What helps most?"
    options:
      - text: "git clone --depth 1 --filter=blob:none --sparse, then git sparse-checkout set <two folders>"
        correct: true
      - text: "git gc --aggressive on the server every night"
      - text: "git clone --mirror"
      - text: "Moving to Git LFS for all files"
    explanation: "Shallow + partial + sparse downloads and checks out only what the build needs. gc helps size slightly, --mirror downloads everything, and LFS is for large binaries, not general source."
  - id_key: q14
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A database password was pushed in a commit an hour ago. Put these in the right order: (A) git filter-repo and force-push, (B) rotate the password, (C) enable secret scanning/push protection."
    options:
      - text: "A, B, C"
      - text: "B, A, C"
        correct: true
      - text: "C, A, B"
      - text: "A, C, B"
    explanation: "Rotate first: the secret must be assumed compromised. Then clean history to limit future exposure, then prevent the next leak."
  - id_key: q15
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You committed two commits on local main that belong on feature/x, nothing pushed. Which sequence fixes it?"
    options:
      - text: "git branch feature/x; git reset --hard origin/main"
        correct: true
      - text: "git revert HEAD~2..HEAD; git switch -c feature/x"
      - text: "git push; git switch -c feature/x"
      - text: "git stash; git switch -c feature/x; git stash pop"
    explanation: "Label the commits with a branch, then move main back. revert adds inverse commits to main, pushing publishes the mistake, and stash only handles uncommitted changes."
---
