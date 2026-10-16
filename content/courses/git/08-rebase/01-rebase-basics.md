---
kind: lesson
id_key: git/rebase/basics
course: git
section: rebase
section_title: "Rebase and Rewriting History"
section_position: 8
title: "Rebase: Replay Your Commits on a New Base"
position: 0
estimated_minutes: 9
source:
  - Pro Git book, ch. 3.6 "Rebasing"
  - git-rebase(1) manual page
---

## Why this matters

Review day. Maya asks: "Put your branch on top of the latest main so the review
shows only your changes." Merging main into your branch works but adds noisy
merge commits. **Rebase** moves your commits so they start from main's tip,
giving a straight, easy-to-read history.

## Mental model: re-applying your edits to a fresh printout

You wrote edits on a printout of a document. Meanwhile the original was updated.
Rebase takes a fresh printout and re-applies your edits, one by one, in order.
The edits are the same ideas, but they are now on new paper. In Git terms:
**new commits with new hashes**.

```
BEFORE                                AFTER  git switch feature; git rebase main

 A---B---C---D  <- main                A---B---C---D  <- main
      \                                              \
       E---F  <- feature                              E'---F'  <- feature
                                       (E and F are replaced by copies E' and F')
```

What Git does internally:

1. Find the commits on `feature` that are not on `main` (E, F).
2. Move `feature` to `main`'s tip (D).
3. Re-apply E's changes as a new commit E', then F's as F'.

The old E and F still exist (reachable from the reflog), just no longer on the
branch. Remember from Section 7: objects never change; rebase makes new ones and
moves a ref.

## See it work

```bash
cd ~/work/blog
git switch feature/comments
git rebase main
git log --oneline --graph --all
```

Expected output:

```
* 7c3a2e9 (HEAD -> feature/comments) Add comment form
* 0f6b18d Add comments page
* b1e47a0 (main) Rename title to Dev Blog
* 5d9c30f Add footer
* 2a8f6c1 Add about page
* e0d31b7 Initial blog
```

A straight line. If `main` is merged with `feature/comments` now, it is a
fast-forward.

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
    "explanation": "Each commit has a new parent, so a new hash. The old commits remain in the reflog, nothing is deleted, and plain rebase keeps them as separate commits." }
] }
```

### Conflicts during a rebase

Rebase applies commits one at a time, so a conflict stops it **on the commit
that cannot apply**. You have three choices:

```
 git rebase main  --> CONFLICT while applying E
      |
      +-- fix files, git add, git rebase --continue   (carry on with next commit)
      +-- git rebase --skip                           (drop this commit)
      +-- git rebase --abort                          (go back to before the rebase)
```

Expected output when it stops:

```
Auto-merging index.md
CONFLICT (content): Merge conflict in index.md
error: could not apply 3e5f1aa... Rename blog title
hint: Resolve all conflicts manually, mark them as resolved with
hint: "git add/rm <conflicted_files>", then run "git rebase --continue".
```

```bash
# edit index.md, then
git add index.md
GIT_EDITOR=true git rebase --continue    # GIT_EDITOR=true keeps the message without opening an editor
```

Expected: `Successfully rebased and updated refs/heads/feature/title.`

**The labels flip.** During a rebase, "ours" (HEAD) is the branch you are
rebasing **onto** (main plus already-replayed commits), and "theirs" is **your**
commit being replayed. The opposite of a merge. So `git checkout --theirs file`
during a rebase keeps *your* version.

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
    "explanation": "--skip would drop the commit being applied; --abort undoes the whole rebase. --continue carries on, and reset --hard origin/main would throw your branch's work away." }
] }
```

## Try it

Your branch has 5 commits. While rebasing onto main, commit 3 conflicts. After
you resolve it and run `--continue`, can commits 4 and 5 conflict too?

<details>
<summary>Show answer</summary>

Yes. Each commit is replayed separately, so each can stop with its own conflict.
That is why long-lived branches with many commits are painful to rebase, and
why squashing first (lesson 3) or enabling rerere helps.

</details>

## Common mistakes

- **Running `git commit` in the middle of a rebase.** Use `git rebase --continue`;
  it creates the commit for you.
- **Forgetting you are mid-rebase.** `git status` says
  `interactive rebase in progress; onto b1e47a0`. Finish or abort before doing
  anything else.
- **Mixing up ours/theirs.** Rebase flips them. Read the file, not the label.
- **Rebasing a branch others use.** Lesson 4 explains why that hurts.

## Remember

- Rebase = replay your commits on a new base; they get new hashes.
- Conflicts stop on one commit: fix, `git add`, `git rebase --continue`.
- `--abort` returns to exactly where you started; `--skip` drops the current commit.
- In a rebase, ours = the new base, theirs = your commit.

**Self-check:**

1. Why do rebased commits get new hashes?
2. What are the three ways out of a rebase conflict?
3. In a rebase, what does `--theirs` refer to?
