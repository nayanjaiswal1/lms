---
kind: quiz
id_key: git/investigation/quiz
course: git
section: investigation
section_title: Investigating History
section_position: 10
title: "Quiz: Investigating History"
position: 5
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Pro Git book, ch. 7.5 and 7.10
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A function `legacyAuth()` no longer exists anywhere in the code. You need to know when it was deleted. What do you run?"
    options:
      - text: "git blame on the file"
      - text: "git log -S 'legacyAuth(' --oneline"
        correct: true
      - text: "git grep legacyAuth"
      - text: "git bisect start"
    explanation: "-S lists commits where the count of the string changed; the newest one removed it. blame and git grep only see code that still exists, and bisect needs a good/bad test."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A company-wide formatter commit touched every file last month. Blame now names it for nearly every line. What is the team-wide fix?"
    options:
      - text: "Revert the formatter commit"
      - text: "Add its hash to .git-blame-ignore-revs and set blame.ignoreRevsFile"
        correct: true
      - text: "Use git log --follow"
      - text: "Use git blame -C on every file"
    explanation: "The ignore-revs file makes blame (and GitHub/GitLab blame views) skip that commit. Reverting undoes the formatting, --follow is for renames, and -C is for moved code, not formatting."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Your bisect script must build the project first, and some old commits fail to build. What should the script return for those?"
    options:
      - text: "0"
      - text: "1"
      - text: "125"
        correct: true
      - text: "255"
    explanation: "125 tells bisect to skip an untestable commit. 0 would mark it good and 1 bad, both wrong guesses; 128 and above abort the whole bisect."
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Between a known-good tag and HEAD there are about 2000 commits. Roughly how many tests will bisect need?"
    options:
      - text: "About 11"
        correct: true
      - text: "About 100"
      - text: "About 1000"
      - text: "2000"
    explanation: "log2(2000) is about 11. Binary search halves the range every step; 1000 or 2000 would be a linear search."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You want the commits on your branch feature/report that are not yet on main, newest first, one line each. Which command?"
    options:
      - text: "git log --oneline main..feature/report"
        correct: true
      - text: "git log --oneline feature/report..main"
      - text: "git log --oneline --all"
      - text: "git diff main feature/report"
    explanation: "A..B means 'reachable from B but not from A'. The reversed range lists main's commits that feature lacks, --all lists everything, and diff shows file changes rather than commits."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A config value changed from retries=3 to retries=5. Which search finds that commit?"
    options:
      - text: "git log -S 'retries='"
      - text: "git log -G 'retries='"
        correct: true
      - text: "git log --follow"
      - text: "git shortlog -sn"
    explanation: "One retries= line was removed and one added, so the count is unchanged and -S misses it. -G matches any changed line. --follow handles renames and shortlog summarises authors."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (Section 9): bisect found that commit X on shared main broke checkout. Several good commits came after it. How do you fix main?"
    options:
      - text: "git revert X and push"
        correct: true
      - text: "git reset --hard X~1 and force-push"
      - text: "git rebase -i to drop X and force-push"
      - text: "git cherry-pick X"
    explanation: "Revert removes X's effect with a new commit, keeping shared history intact and the later good commits in place. Reset and rebase rewrite shared history (and reset also drops the good commits); cherry-pick would apply X again."
---
