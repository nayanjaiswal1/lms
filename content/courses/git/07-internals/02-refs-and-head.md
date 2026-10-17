---
kind: lesson
id_key: git/internals/refs-head
course: git
section: internals
section_title: "Under the Hood: Objects, Refs and the Index"
section_position: 7
title: "Refs, HEAD, Detached HEAD and Revision Syntax"
position: 1
estimated_minutes: 9
source:
  - Pro Git book, ch. 10.3 "Git References" and ch. 7.1 "Revision Selection"
  - gitrevisions(7), git-rev-parse(1), git-update-ref(1) manual pages
---

## Why this matters

Objects are immutable and named by hashes nobody wants to type. **Refs** give
them human names and are the only thing that moves when you commit, reset or
rebase. Understanding refs and `HEAD` explains detached HEAD, "lost" commits,
and the `~` / `^` syntax you see in every tutorial.

## Mental model: sticky notes on boxes

The commit DAG (boxes linked to their parents) never changes. Refs are sticky
notes stuck on boxes. Committing = add a box, move the note.

> **DAG** = directed acyclic graph: each commit points to its parent(s), arrows
> only go backwards in time, and there are no loops.

```
 refs/heads/main  ----------------------.
 refs/tags/v1.0 ------------.            v
                     A <--- B <--- C <--- D
                                    ^
 refs/heads/fix --------------------'
 HEAD --> "ref: refs/heads/main"      (HEAD points to a branch, which points to a commit)
```

| Ref | Lives in | Moves when |
|---|---|---|
| `refs/heads/<branch>` | `.git/refs/heads/` | You commit, merge, reset on that branch |
| `refs/remotes/origin/<b>` | `.git/refs/remotes/` | fetch, pull, push |
| `refs/tags/<tag>` | `.git/refs/tags/` | Never (by convention) |
| `HEAD` | `.git/HEAD` | You switch branches |
| `refs/stash` | `.git/refs/stash` | You stash |

Many refs may also be packed into one file, `.git/packed-refs`, for speed.
Always use commands like `git show-ref` instead of reading files directly.

## See it work

### HEAD is (usually) a pointer to a pointer

```bash
cat .git/HEAD
git rev-parse HEAD
git show-ref
```

Expected output:

```
ref: refs/heads/main
e5fda59241d1283c91fa2b05a24226a7ab85f105
e5fda59241d1283c91fa2b05a24226a7ab85f105 refs/heads/main
812bd18cfdc59a9c25eecda7f0bf7df972a94a40 refs/tags/v1
```

`HEAD` is a **symbolic ref**: it names a branch. When you commit, Git writes the
new commit, then updates the branch HEAD names.

### Detached HEAD

```bash
git switch --detach v1
cat .git/HEAD
git status
```

```
e5fda59241d1283c91fa2b05a24226a7ab85f105
HEAD detached at e5fda59
nothing to commit, working tree clean
```

Now `HEAD` holds a hash directly. Commits you make here are attached to no
branch:

```
 main --> D
          \
           X---Y   <- HEAD only. Switch away and nothing points at Y.
```

Save them before leaving: `git switch -c keep-this`. Already left? The reflog
remembers (Section 9): `git reflog`, find Y, `git branch keep-this <hash>`.

### Moving a ref by hand

```bash
git update-ref refs/heads/manual HEAD~1     # create/move branch "manual"
git branch manual2 HEAD~1                   # same effect, friendlier
```

Both just write a hash into a ref. This is all a branch is.

### Revision syntax cheat sheet

| Syntax | Means |
|---|---|
| `HEAD~1`, `HEAD~3` | 1st / 3rd generation back, following **first** parents |
| `HEAD^` = `HEAD^1` | First parent |
| `HEAD^2` | **Second** parent (only merges have one) |
| `main@{upstream}`, `@{u}` | The branch's upstream, e.g. `origin/main` |
| `main@{2}` | Where main pointed 2 moves ago (reflog) |
| `v1^{commit}`, `HEAD^{tree}` | Peel a tag to its commit / a commit to its tree |
| `HEAD:src/app.sh` | The blob for that path in that commit |
| `A..B` | Commits reachable from B but not from A |
| `A...B` | Commits reachable from either but not both |
| `:/fix typo` | Youngest commit whose message matches |

`git rev-parse <anything>` turns any of these into a hash, perfect for
checking your understanding.

## Try it

`M` is a merge commit on `main`. What is the difference between `M~2` and
`M^2`?

<details>
<summary>Show answer</summary>

`M~2` = grandparent along the first-parent line (two steps back on `main`).
`M^2` = the **second parent** of M, i.e. the tip of the branch that was merged
in. `~` counts generations; `^` picks which parent.

</details>

## Common mistakes

- **Panicking at "detached HEAD".** It is a normal state for looking at old
  commits. Just do not leave new commits there without a branch.
- **Editing `.git/refs` files by hand.** Refs may be packed or use the newer
  `reftable` format; use `git update-ref` / `git branch`.
- **Confusing `..` and `...`.** For `git log`, `main..feature` = what feature
  has that main does not. For `git diff`, `main...feature` = changes on feature
  since it split from main.

## Remember

- Refs are names for commits; only refs move, objects never change.
- `HEAD` normally points to a branch; detached HEAD points to a commit.
- Commits made on a detached HEAD need a branch, or they become unreachable.
- `~n` = n generations back (first parent); `^n` = nth parent.

**Self-check:**

1. What does `.git/HEAD` contain on a normal branch?
2. How do you keep commits made on a detached HEAD?
3. What does `git log main..feature` show?
