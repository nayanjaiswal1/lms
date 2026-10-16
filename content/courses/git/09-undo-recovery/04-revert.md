---
kind: lesson
id_key: git/undo-recovery/revert
course: git
section: undo-recovery
section_title: "Undo and Recovery"
section_position: 9
title: "revert: Undo Safely on Shared History"
position: 3
estimated_minutes: 8
source:
  - Pro Git book, ch. 7.8 "Reverse the commit"
  - git-revert(1) manual page
---

## Why this matters

A bad commit is already on `main`, and teammates and CI have pulled it. You
cannot rewrite that history without breaking everyone's clones. `git revert`
undoes the change by **adding** a new commit, so history only grows and every
clone stays consistent.

## Mental model: a correction notice

A newspaper cannot un-print yesterday's paper. It prints a **correction** in
today's paper. Revert is the correction: a new commit whose changes are the
exact inverse of the bad one.

```
BEFORE                               AFTER git revert C

 A---B---C---D  <- main               A---B---C---D---C'  <- main
                                      C' = inverse of C   (C stays in history)
```

| | reset | revert |
|---|---|---|
| What it does | Moves the branch back | Adds an inverse commit |
| History | Rewritten | Append-only |
| Safe after push | No | **Yes** |

## See it work

### Revert one commit

```bash
git log --oneline
git revert --no-edit 5c07b8e        # hash of "Add March entries"
```

Expected output:

```
[main 2e81c4d] Revert "Add March entries"
 1 file changed, 1 deletion(-)
```

`--no-edit` keeps the default message `Revert "<original subject>"`, whose
body says `This reverts commit 5c07b8e...`. Without it, Git opens the editor
so you can explain **why** you reverted. Good practice on shared branches.

Revert can conflict if later commits changed the same lines; resolve as usual,
then `git revert --continue` (or `--abort`).

```knowledge-check
{ "questions": [
  { "id": "git-undo-revert-q1", "type": "mcq",
    "prompt": "Why is revert preferred over reset on a branch teammates already pulled?",
    "options": [
      {"id":"a","text":"It adds a new commit instead of rewriting history, so nobody's clone diverges"},
      {"id":"b","text":"It is faster"},
      {"id":"c","text":"It deletes the original commit"},
      {"id":"d","text":"It works without a repository"}],
    "correct": "a",
    "explanation": "Rewriting shared history forces everyone else to repair their branches. Revert is not faster, it keeps the original commit, and it needs a repository like any command." }
] }
```

### Revert a merge commit

A merge has two parents, so Git needs to know which side is the "mainline" to
keep:

```
        M  <- main (merge of feature into main)       git revert -m 1 M
       / \                                             -m 1 = keep parent 1 (main's side),
      B   F  <- feature                                undo everything F brought in
```

```bash
git revert -m 1 --no-edit HEAD
```

Expected:

```
[main 7ad03ce] Revert "Merge feature/bonus"
 1 file changed, 1 deletion(-)
 delete mode 100644 bonus.txt
```

Without `-m`, Git refuses: `error: commit ... is a merge but no -m option was
given.`

**Gotcha:** Git still considers `feature/bonus` merged. If you fix the feature
and merge it again later, only the **new** commits come in. To bring the whole
feature back, first revert the revert (`git revert <revert-commit>`).

```knowledge-check
{ "questions": [
  { "id": "git-undo-revert-q2", "type": "mcq",
    "prompt": "What does git revert -m 1 <merge> keep?",
    "options": [
      {"id":"a","text":"The side of parent 1 (the branch the merge was made on) and undoes what the other parent brought in"},
      {"id":"b","text":"Only the other parent's changes"},
      {"id":"c","text":"Nothing"},
      {"id":"d","text":"Both sides"}],
    "correct": "a",
    "explanation": "-m picks the mainline parent; changes relative to it are inverted. It does not keep only the other side, nor both, nor nothing." }
] }
```

### Revert several commits

```bash
git revert --no-commit HEAD~3..HEAD   # stage the inverse of the last 3 commits
git commit -m "Revert checkout redesign (breaks Safari)"
```

## Try it

Commit `X` on shared `main` broke the build. Two good commits came after it.
Undo only `X` and publish the fix.

<details>
<summary>Show answer</summary>

```bash
git pull
git revert X          # explain why in the message
git push
```

The good commits stay; `X` stays in history; a new commit removes its effect.

</details>

## Common mistakes

- **Using reset + force-push on `main`.** Breaks every clone and CI. Revert.
- **Forgetting `-m 1` on merges.** Git refuses without it.
- **Re-merging a reverted branch and wondering why changes are missing.**
  Revert the revert first.

## Remember

- Revert = new commit with the inverse changes; history stays append-only.
- Use it for anything already pushed to a shared branch.
- Merge commits need `-m 1` (keep the mainline side).
- After reverting a merge, re-merging needs the revert reverted.

**Self-check:**

1. Does revert delete the original commit?
2. Why does reverting a merge need `-m`?
3. How do you bring back a feature whose merge you reverted?
