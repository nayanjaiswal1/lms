---
kind: lesson
id_key: git/rebase/rebase-vs-merge
course: git
section: rebase
section_title: "Rebase and Rewriting History"
section_position: 8
title: "Rebase vs Merge: When to Use Which"
position: 1
estimated_minutes: 8
source:
  - Pro Git book, ch. 3.6 "Rebasing" (Rebase vs. Merge, The Perils of Rebasing)
  - git-pull(1) manual page, --rebase
---

## Why this matters

"Should we rebase or merge?" starts arguments on every team and comes up in
interviews. Both integrate work; they differ in what history they leave
behind and in who they can hurt. The real answer is a simple rule plus a team
convention.

## Mental model: diary vs edited book

- **Merge** keeps the **diary**: exactly what happened, including that two
  people worked in parallel. Honest, but messy to read.
- **Rebase** produces an **edited book**: the story retold in a clean order, as
  if you started from the latest main. Easy to read, but rewritten.

```
 merge:   A---B---D---M          rebase:   A---B---D---C'---E'
           \       /                       (C, E replaced by copies)
            C-----E
```

## Side by side

| | Merge | Rebase |
|---|---|---|
| History shape | Branches and merge commits | Straight line |
| Existing commits | Untouched | Replaced by copies (new hashes) |
| Safe on shared branches | Yes | **No** (rewrites what others have) |
| Conflicts | Resolved once, in the merge commit | Possibly once per replayed commit |
| `git bisect` / `git log` | Works, graph is busier | Easy, linear |
| Shows "when work happened in parallel" | Yes | No |

### The golden rule

> **Never rebase commits that other people have already based work on.**

Rebasing your own local or personal feature branch: fine. Rebasing `main`, or a
branch your teammate has pulled and committed on: they now have the old
commits, you have the new copies, and their next pull duplicates or conflicts
everything.

## See it work

### The common team convention

1. Work on a feature branch.
2. Keep it current with **rebase** onto `origin/main` (your private branch, so
   rewriting is fine).
3. Integrate into `main` with a **merge** (or the host's "squash" / "rebase and
   merge" button). `main` itself is never rewritten.

```bash
git fetch
git rebase origin/main            # update my feature branch
git push --force-with-lease       # update my PR branch (lesson 4)
```

### pull --rebase for small local changes

You made one commit on `main` while a teammate pushed. Instead of a merge
commit "Merge branch 'main' of ...":

```bash
git pull --rebase
```

What this does: fetch, then replay **your unpushed** commits on top of
`origin/main`. Your commits were never shared, so rewriting them is safe.

```
 before:  origin/main A---B---T      your main A---B---N
 after :  your main   A---B---T---N'   (no merge commit)
```

Make it the default with `git config --global pull.rebase true`. Add
`git config --global rebase.autoStash true` so Git stashes uncommitted edits
around the rebase automatically.

### When to prefer merge

- Integrating a long-lived branch with many authors.
- When you need an exact record (regulated environments, release branches).
- When the branch is already shared and you are not its only user.

## Try it

You and Priya both commit on `feature/report`, which you both push to. You want
the latest `main` in it. Rebase or merge?

<details>
<summary>Show answer</summary>

**Merge** `main` into `feature/report` (or agree with Priya first). The branch
is shared, so rebasing would rewrite commits Priya already has. If you really
want a rebase, coordinate: she pushes everything, you rebase and
force-with-lease, she resets her copy to the new branch.

</details>

## Common mistakes

- **"Rebase is always better."** It is cleaner, not safer. On shared branches it
  causes real damage.
- **"Merge commits are bad."** A merge commit per feature is a useful,
  revertable unit. What teams dislike is the noise of accidental
  "Merge branch 'main' of ..." commits from habitual pulls.
- **Rebasing a branch that contains merges.** Plain rebase flattens them. Use
  `git rebase --rebase-merges` if you must keep them.

## Remember

- Merge preserves history; rebase rewrites it into a line.
- Golden rule: never rebase commits others have built on.
- Typical flow: rebase your feature branch, merge into main.
- `pull.rebase true` (+ `rebase.autoStash true`) avoids noisy pull merges.

**Self-check:**

1. State the golden rule of rebasing.
2. Name one advantage of each approach.
3. Why is `git pull --rebase` safe for unpushed commits?
