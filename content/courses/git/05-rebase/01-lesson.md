---
kind: lesson
id_key: git/rebase/lesson
course: git
section: rebase
section_title: Rebase
section_position: 5
title: Rebase, Interactive Rebase and force-with-lease
position: 0
estimated_minutes: 55
source:
  - Pro Git book, ch. 3.6 "Rebasing" and ch. 7.6 "Rewriting History"
  - git-rebase(1), git-push(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 55
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    umask 000
    git config --system init.defaultBranch main
    git config --system safe.directory '*'
    git config --system user.name "Lab Student"
    git config --system user.email "student@lab.local"
    rm -rf /home/labuser/work/blog /srv/git
    mkdir -p /srv/git /home/labuser/work/blog && cd /home/labuser/work/blog
    git init -q
    M() { git add -A; GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
    printf '# My Blog\nWelcome\n' > index.md
    echo 'body{}' > style.css
    M 2024-04-01 "Initial blog"
    echo about > about.md; M 2024-04-02 "Add about page"
    git switch -q -c feature/comments
    echo comments > comments.md; M 2024-04-03 "Add comments page"
    echo form >> comments.md; M 2024-04-04 "Add comment form"
    git switch -q main
    git switch -q -c feature/title
    printf '# The Blog\nWelcome\n' > index.md; M 2024-04-05 "Rename blog title"
    git switch -q main
    echo footer > footer.md; M 2024-04-06 "Add footer"
    printf '# Dev Blog\nWelcome\n' > index.md; M 2024-04-07 "Rename title to Dev Blog"
    git switch -q -c feature/profile
    printf '# Proflie\nname: TBD\n' > profile.md; M 2024-04-08 "wip: profile skeleton"
    echo avatar.png > avatar.md; M 2024-04-09 "wip: add avatar"
    printf '# Profile\nname: TBD\n' > profile.md; M 2024-04-10 "fix typo in profile"
    echo 'bio: hello' >> profile.md; M 2024-04-11 "wip: bio"
    git switch -q main
    git init -q --bare /srv/git/blog.git
    git remote add origin /srv/git/blog.git
    git push -q origin main feature/profile
    git branch -q --set-upstream-to=origin/main main
    git branch -q --set-upstream-to=origin/feature/profile feature/profile
    chmod -R a+rwX /home/labuser/work/blog /srv/git
  tasks:
    - id_key: rebase-onto-main
      title: Rebase a feature branch onto main
      points: 15
      is_stateful: true
      description: In ~/work/blog, feature/comments was started before main gained two commits. Rebase feature/comments onto main so its two commits sit on top of main's tip with no merge commit.
      verification_script: |
        r=/home/labuser/work/blog
        git -C $r merge-base --is-ancestor main feature/comments &&
        [ "$(git -C $r rev-list --count main..feature/comments)" = 2 ] &&
        [ "$(git -C $r rev-list --merges --count main..feature/comments)" = 0 ] &&
        [ "$(git -C $r log feature/comments -1 --format=%s)" = "Add comment form" ] &&
        [ ! -d $r/.git/rebase-merge ]
      hint_context: git switch feature/comments, then git rebase main. Check the result with git log --oneline --graph --all.
      explanation_context: Rebase replays each of your commits on top of a new base, creating new commits with new hashes. The result is a straight line instead of a merge.
      solution_script: |
        cd ~/work/blog
        git switch feature/comments
        git rebase main
    - id_key: rebase-conflict-start
      title: Hit a conflict mid-rebase
      points: 10
      is_stateful: true
      description: feature/title renames the heading to "# The Blog" but main already renamed it to "# Dev Blog". Rebase feature/title onto main and stop at the conflict.
      verification_script: |
        r=/home/labuser/work/blog
        [ -d $r/.git/rebase-merge ] &&
        git -C $r ls-files -u | grep -q index.md
      hint_context: git switch feature/title && git rebase main. Git pauses and prints which commit it was applying.
      explanation_context: Rebase replays commits one at a time; a conflict stops it with the branch in a detached state until you continue or abort.
      solution_script: |
        cd ~/work/blog
        git switch feature/title
        git rebase main || true
    - id_key: rebase-abort
      title: Abort the rebase
      points: 10
      is_stateful: true
      description: Change your mind - abort the rebase so feature/title is exactly as it was before.
      verification_script: |
        r=/home/labuser/work/blog
        [ ! -d $r/.git/rebase-merge ] &&
        [ "$(git -C $r rev-parse --abbrev-ref HEAD)" = feature/title ] &&
        ! git -C $r merge-base --is-ancestor main feature/title &&
        [ -z "$(git -C $r status --porcelain)" ]
      hint_context: git rebase --abort.
      explanation_context: --abort returns the branch to its pre-rebase tip. Your original commits were never modified, so nothing is lost.
      solution_script: |
        cd ~/work/blog
        git rebase --abort
    - id_key: rebase-resolve-continue
      title: Resolve and continue the rebase
      points: 20
      is_stateful: true
      description: Rebase feature/title onto main again. This time resolve index.md so its first line is "# The Dev Blog" (second line "Welcome"), git add it and run git rebase --continue.
      verification_script: |
        r=/home/labuser/work/blog
        [ ! -d $r/.git/rebase-merge ] &&
        git -C $r merge-base --is-ancestor main feature/title &&
        [ "$(git -C $r rev-list --count main..feature/title)" = 1 ] &&
        [ "$(git -C $r log feature/title -1 --format=%s)" = "Rename blog title" ] &&
        [ "$(git -C $r show feature/title:index.md | head -1)" = "# The Dev Blog" ] &&
        [ -z "$(git -C $r grep -nE '^(<<<<<<<|=======|>>>>>>>)' feature/title)" ]
      hint_context: After editing, git add index.md then git rebase --continue (set GIT_EDITOR=true to skip the message editor).
      explanation_context: In a rebase "ours" is the branch you are rebasing onto and "theirs" is your commit being replayed - the reverse of a merge. The continue step creates the rewritten commit.
      solution_script: |
        cd ~/work/blog
        git switch feature/title
        git rebase main || true
        printf '# The Dev Blog\nWelcome\n' > index.md
        git add index.md
        GIT_EDITOR=true git rebase --continue
    - id_key: interactive-squash
      title: Squash and reorder with interactive rebase
      points: 20
      is_stateful: true
      description: 'feature/profile has four messy commits ("wip: profile skeleton", "wip: add avatar", "fix typo in profile", "wip: bio"). Use git rebase -i main to fold the typo fix and bio into the skeleton commit and keep the avatar commit last, leaving exactly two commits.'
      verification_script: |
        r=/home/labuser/work/blog
        [ ! -d $r/.git/rebase-merge ] &&
        [ "$(git -C $r rev-list --count main..feature/profile)" = 2 ] &&
        [ "$(git -C $r show --name-only --format= feature/profile)" = avatar.md ] &&
        git -C $r show feature/profile~1:profile.md | grep -qx '# Profile' &&
        git -C $r show feature/profile~1:profile.md | grep -qx 'bio: hello'
      hint_context: In the todo list move the "fix typo" and "bio" lines directly under the skeleton line and change pick to fixup (f). Leave the avatar line last. In this lab terminal the editor is nano or vim.
      explanation_context: fixup melds a commit into the one above it and discards its message; reordering lines reorders history. Commits that touch different files reorder without conflicts.
      solution_script: |
        cd ~/work/blog
        git switch feature/profile
        h() { git log --format=%h --grep="$1" main..feature/profile; }
        printf 'pick %s\nfixup %s\nfixup %s\npick %s\n' "$(h 'wip: profile skeleton')" "$(h 'fix typo')" "$(h 'wip: bio')" "$(h 'wip: add avatar')" > /tmp/todo
        GIT_SEQUENCE_EDITOR='cp /tmp/todo' git rebase -i main
    - id_key: interactive-reword
      title: Reword the commits
      points: 15
      is_stateful: true
      description: Reword the two remaining commits (oldest first) to "Add profile page" and "Add profile avatar" using interactive rebase.
      verification_script: |
        r=/home/labuser/work/blog
        [ ! -d $r/.git/rebase-merge ] &&
        [ "$(git -C $r log --reverse --format=%s main..feature/profile)" = "$(printf 'Add profile page\nAdd profile avatar')" ]
      hint_context: Change pick to reword (r) on both lines; Git opens the editor once per commit.
      explanation_context: reword keeps the content and rewrites only the message. Since every following commit has a new parent, the hashes of later commits change too.
      solution_script: |
        cd ~/work/blog
        git switch feature/profile
        printf '#!/bin/sh\nif grep -q avatar "$1"; then echo "Add profile avatar" > "$1"; else echo "Add profile page" > "$1"; fi\n' > /tmp/msg.sh
        chmod +x /tmp/msg.sh
        set -- $(git rev-list --reverse main..feature/profile)
        printf 'reword %s\nreword %s\n' "$1" "$2" > /tmp/todo
        GIT_SEQUENCE_EDITOR='cp /tmp/todo' GIT_EDITOR=/tmp/msg.sh git rebase -i main
    - id_key: force-with-lease
      title: Update the shared branch safely
      points: 20
      is_stateful: true
      description: origin still holds the old, un-squashed feature/profile. A plain git push is rejected because history was rewritten. Push the rewritten branch with --force-with-lease (never plain --force). origin's main must stay untouched.
      verification_script: |
        r=/home/labuser/work/blog
        [ "$(git -C $r ls-remote origin refs/heads/feature/profile | cut -f1)" = "$(git -C $r rev-parse feature/profile)" ] &&
        [ "$(git -C $r ls-remote origin refs/heads/main | cut -f1)" = "$(git -C $r rev-parse main)" ] &&
        [ "$(git -C $r rev-list --count origin/feature/profile)" = "$(git -C $r rev-list --count feature/profile)" ]
      hint_context: git push --force-with-lease origin feature/profile. It refuses if someone else pushed to the branch since your last fetch.
      explanation_context: --force-with-lease overwrites the remote branch only if it still points where you last saw it, protecting a teammate's newer commits that a blind --force would destroy.
      solution_script: |
        cd ~/work/blog
        git switch feature/profile
        git push || true
        git push --force-with-lease origin feature/profile
---

## Rebase: move a branch onto a new base

Merge joins two histories; rebase **replays** your commits on top of another branch. The result
is a straight line, but your commits get new hashes.

```
BEFORE                                AFTER  git switch feature; git rebase main

 A---B---C---D  <- main                A---B---C---D  <- main
      \                                              \
       E---F  <- feature                              E'---F'  <- feature
                                       (E and F are replaced by copies E' and F')
```

```bash
cd ~/work/blog
git switch feature/comments
git rebase main
git log --oneline --graph --all
```

[[lab-task:1]]

What you should see:

```
* 7c3a2e9 (HEAD -> feature/comments) Add comment form
* 0f6b18d Add comments page
* b1e47a0 (main) Rename title to Dev Blog
* 5d9c30f Add footer
* 2a8f6c1 Add about page
* e0d31b7 Initial blog
```

```knowledge-check
{ "questions": [
  { "id": "git-rebase-basic-q1", "type": "mcq",
    "prompt": "After git rebase main, the commits of your feature branch...",
    "options": [
      {"id":"a","text":"Keep exactly the same hashes"},
      {"id":"b","text":"Are replaced by new commits with new hashes on top of main"},
      {"id":"c","text":"Are deleted"},
      {"id":"d","text":"Are merged into one commit"}],
    "correct": "b",
    "explanation": "Each commit has a new parent, so a new hash. The old commits remain in the reflog." }
] }
```

## Conflicts during a rebase

A conflict stops the replay on the commit that cannot apply. You have three choices:

```
 git rebase main  --> CONFLICT while applying E
      |
      +-- fix files, git add, git rebase --continue   (carry on with next commit)
      +-- git rebase --skip                           (drop this commit)
      +-- git rebase --abort                          (go back to before the rebase)
```

In a rebase the labels flip: "ours" (HEAD) is the branch you are rebasing **onto**, "theirs" is the
commit being replayed.

```bash
git switch feature/title
git rebase main          # CONFLICT in index.md
git rebase --abort       # back to the start
git rebase main          # conflict again
# edit index.md, then
git add index.md
GIT_EDITOR=true git rebase --continue
```

[[lab-task:2]]
[[lab-task:3]]
[[lab-task:4]]

What you should see while stopped:

```
Auto-merging index.md
CONFLICT (content): Merge conflict in index.md
error: could not apply 3e5f1aa... Rename blog title
hint: Resolve all conflicts manually, mark them as resolved with
hint: "git add/rm <conflicted_files>", then run "git rebase --continue".

$ git status
interactive rebase in progress; onto b1e47a0
```

And afterwards:

```
Successfully rebased and updated refs/heads/feature/title.
```

```knowledge-check
{ "questions": [
  { "id": "git-rebase-conflict-q1", "type": "mcq",
    "prompt": "During a rebase conflict, which command gives up and restores the branch to its pre-rebase state?",
    "options": [
      {"id":"a","text":"git rebase --continue"},
      {"id":"b","text":"git rebase --abort"},
      {"id":"c","text":"git reset --hard origin/main"},
      {"id":"d","text":"git rebase --skip"}],
    "correct": "b",
    "explanation": "--skip would drop the commit being applied; --abort undoes the whole rebase." }
] }
```

## Interactive rebase: squash, reorder, reword

`git rebase -i main` opens a todo list, oldest commit first. Edit the verbs, save, and Git replays:

```
 pick   1111 wip: profile skeleton        pick   1111 wip: profile skeleton
 pick   2222 wip: add avatar        -->   fixup  3333 fix typo in profile
 pick   3333 fix typo in profile          fixup  4444 wip: bio
 pick   4444 wip: bio                     pick   2222 wip: add avatar
```

```
BEFORE (4 commits)                  AFTER (2 commits)

 main---P1---P2---P3---P4            main---P1'---P2'
        skel avatar typo bio              skel+typo+bio  avatar
```

Verbs: `pick` keep, `reword` keep and edit message, `squash` meld and combine messages, `fixup`
meld and discard message, `drop` delete, and reordering lines reorders commits.

Scripts can drive it with `GIT_SEQUENCE_EDITOR` (the todo editor) and `GIT_EDITOR` (the message
editor), e.g. `GIT_SEQUENCE_EDITOR='sed -i s/^pick/reword/' git rebase -i main`.

```bash
git switch feature/profile
git rebase -i main
```

[[lab-task:5]]
[[lab-task:6]]

What you should see afterwards:

```
* 91c0d4e (HEAD -> feature/profile) Add profile avatar
* 6a2fb85 Add profile page
* b1e47a0 (main) Rename title to Dev Blog
```

```knowledge-check
{ "questions": [
  { "id": "git-rebase-interactive-q1", "type": "mcq",
    "prompt": "What is the difference between squash and fixup in an interactive rebase?",
    "options": [
      {"id":"a","text":"squash keeps and combines the commit message, fixup discards it"},
      {"id":"b","text":"fixup deletes the file"},
      {"id":"c","text":"They are identical"},
      {"id":"d","text":"squash pushes to the remote"}],
    "correct": "a",
    "explanation": "Both meld the commit into the previous one; only squash lets you keep its message." }
] }
```

## Never rebase shared history; use force-with-lease

Rebasing rewrites commits. If teammates already built on the old ones, their history and yours
no longer match:

```
 origin/feature:  A---B---C---D        teammate has D checked out
 you rebase  ->   A---B---C'---D'      (new hashes)
 push --force     origin now has C'D'  -> teammate's D is orphaned, their next pull is a mess
```

Rule: rebase only commits nobody else has based work on (your own unpublished branch, or a
branch you own). When you must update a branch you already pushed, use
`--force-with-lease`; it refuses if the remote moved since you last fetched.

```bash
git push                                  # rejected: non-fast-forward
git push --force-with-lease origin feature/profile
```

[[lab-task:7]]

What you should see:

```
 ! [rejected]        feature/profile -> feature/profile (non-fast-forward)
...
 + 0b7e5ad...91c0d4e feature/profile -> feature/profile (forced update)
```

```knowledge-check
{ "questions": [
  { "id": "git-rebase-lease-q1", "type": "mcq",
    "prompt": "Why is --force-with-lease safer than --force?",
    "options": [
      {"id":"a","text":"It refuses to overwrite the remote branch if it has commits you have not seen"},
      {"id":"b","text":"It is faster"},
      {"id":"c","text":"It also rebases for you"},
      {"id":"d","text":"It deletes the remote branch first"}],
    "correct": "a",
    "explanation": "It checks the remote still points where your remote-tracking ref says before overwriting." },
  { "id": "git-rebase-lease-q2", "type": "mcq",
    "prompt": "Which branch should you NEVER rebase?",
    "options": [
      {"id":"a","text":"A private local branch nobody has pulled"},
      {"id":"b","text":"A shared branch like main that others have pulled"},
      {"id":"c","text":"A branch with one commit"},
      {"id":"d","text":"A branch with no remote"}],
    "correct": "b",
    "explanation": "Rewriting commits others already have forces them to reconcile two versions of history." }
] }
```
