---
kind: quiz
id_key: git/workflows/quiz
course: git
section: workflows
section_title: "Team Workflows, Releases, Hooks and Signing"
section_position: 11
title: "Quiz: Team Workflows, Releases, Hooks and Signing"
position: 5
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Pro Git book, ch. 2.6, 3.4, 7.4, 8.3
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A SaaS team deploys main to production many times a day. Which branching strategy fits best?"
    options:
      - text: "Git flow with develop, release and hotfix branches"
      - text: "Trunk-based development or GitHub flow with short-lived branches and protected main"
        correct: true
      - text: "One long-lived branch per developer, merged monthly"
      - text: "No branches; everyone pushes directly with --force"
    explanation: "Continuous deployment wants small, frequent integration into one always-deployable main. Git flow adds release ceremony meant for versioned products, monthly merges create huge conflicts, and force-pushing main destroys work."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "CI builds a release whenever a tag v* is pushed. You ran `git tag -a v1.4.0 -m 'Release 1.4.0'` and `git push`. CI did not start. Why?"
    options:
      - text: "Annotated tags cannot trigger CI"
      - text: "A plain git push does not send tags; run git push origin v1.4.0"
        correct: true
      - text: "Tags must be lightweight"
      - text: "The tag needs to be on a branch called release"
    explanation: "Tags are only pushed explicitly or with --follow-tags/push.followTags. Annotated tags are exactly what release tooling expects, and tags can point at any commit."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Your library's public function signature changed in a way that breaks callers. Current version is 2.7.3. What is the next SemVer version?"
    options:
      - text: "2.7.4"
      - text: "2.8.0"
      - text: "3.0.0"
        correct: true
      - text: "2.7.3-breaking"
    explanation: "Breaking changes bump MAJOR and reset the others. PATCH is for fixes, MINOR for compatible features, and a suffix marks pre-releases, not breaking changes."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You added an executable .git/hooks/commit-msg to enforce ticket keys. A teammate clones the repo and their commits are not checked. Why?"
    options:
      - text: "Hooks only run on the server"
      - text: ".git/hooks is not part of the repository content and is never cloned; share hooks via a committed folder plus core.hooksPath or a hook manager"
        correct: true
      - text: "commit-msg hooks only run with --verify"
      - text: "The teammate uses a different branch"
    explanation: "Each clone has its own .git/hooks with only sample files. Client hooks do run locally (that is the point), run by default, and do not depend on branches."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Management wants a guarantee that no commit with a failing linter ever reaches main. Is a pre-commit hook enough?"
    options:
      - text: "Yes; hooks cannot be skipped"
      - text: "No; `git commit --no-verify` skips client hooks, so also require the lint check in CI and protect main"
        correct: true
      - text: "Yes, if it is also a pre-push hook"
      - text: "No; hooks only work for commit messages"
    explanation: "Client hooks are a convenience. Enforcement belongs in CI and server-side branch protection. pre-push can also be skipped with --no-verify, and pre-commit can run any check, not only messages."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why does a signed commit prove more than the author field?"
    options:
      - text: "Anyone can set user.name and user.email to any value, but only the holder of the private key can produce a signature that verifies against the public key"
        correct: true
      - text: "Signing encrypts the commit so others cannot read it"
      - text: "Signed commits cannot be reverted"
      - text: "The host checks the author's password at commit time"
    explanation: "The author line is plain text. Signing does not encrypt, does not prevent reverts, and hosts never see commits until push, so they cannot check passwords at commit time."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "`git describe` prints v3.1.0-12-g4e5f6a7. What does it mean?"
    options:
      - text: "The nearest annotated tag is v3.1.0; HEAD is 12 commits after it, at commit 4e5f6a7"
        correct: true
      - text: "Version 3.1.0, build 12, generation 4e5f6a7"
      - text: "Twelve tags exist after v3.1.0"
      - text: "HEAD is 12 commits before v3.1.0"
    explanation: "Format: <tag>-<commits since tag>-g<short hash>. It counts commits, not tags or builds, and always looks backwards from HEAD."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (Section 10): which command shows every commit on any branch that added or removed the string 'API_KEY', with diffs?"
    options:
      - text: "git log -S API_KEY -p --all"
        correct: true
      - text: "git grep API_KEY"
      - text: "git blame -C"
      - text: "git log --follow API_KEY"
    explanation: "-S finds additions/removals, -p shows diffs, --all covers every branch. git grep searches current files only, blame annotates existing lines, and --follow tracks a file's renames."
---
