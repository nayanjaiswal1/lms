---
kind: lesson
id_key: git/internals/index-storage
course: git
section: internals
section_title: "Under the Hood: Objects, Refs and the Index"
section_position: 7
title: "The Index, Packfiles and Garbage Collection"
position: 2
estimated_minutes: 8
source:
  - Pro Git book, ch. 10.4 "Packfiles" and ch. 10.7 "Maintenance and Data Recovery"
  - git-ls-files(1), git-gc(1), git-count-objects(1), git-fsck(1) manual pages
---

## Why this matters

Two final pieces complete the picture. The **index** is a real file that
explains staging and conflicts. **Reachability and garbage collection** explain
why "deleted" commits can be recovered, and for how long. Together they tell
you when Git can truly lose data and when it cannot.

## Mental model: the order form and the cleaner

- The **index** (`.git/index`) is an order form listing every path that will go
  into the next commit, with the blob hash for each. `git add` writes the blob
  and updates the line on the form.
- **Garbage collection** is a cleaner who throws out boxes that no sticky note
  (ref) or recent reflog entry leads to, but only after a grace period.

## See it work

### Look at the index

```bash
git ls-files -s
```

Expected output:

```
100644 fec56017dc1b1ac87ad6e54e3cb3a20bb8dcc5ab 0	README.md
100644 8b2fe5434fec16870a71cd8b272c7fcf6d352536 0	src/app.sh
```

Each line: mode, blob hash, **stage number**, path. Stage `0` is normal. During
a conflict a path has three entries instead:

| Stage | Holds |
|---|---|
| 1 | Common ancestor (merge base) version |
| 2 | "Ours" (HEAD) version |
| 3 | "Theirs" version |

That is what "unmerged" means, and why `git add` resolves a conflict: it
collapses stages 1-3 into one stage-0 entry. You can view each with
`git show :2:app.conf`.

`git add` already stores the blob in `.git/objects`. So even an edit that was
only staged (never committed) can sometimes be dug out later with `git fsck`.

### Loose objects and packfiles

```bash
git count-objects -v
```

Expected output in a fresh repo:

```
count: 5
size: 20
in-pack: 0
packs: 0
...
```

New objects start as individual **loose** files, zlib-compressed, under
`.git/objects/ab/cdef...` (first two hex characters = folder). Periodically
(`git gc`, or automatically) Git packs them into **packfiles** that store
similar objects as deltas. That is why a repo with a long history is still
small, and why "snapshots" do not waste space.

### Reachability: what can be lost

An object is **reachable** if you can walk to it from any ref (branches, tags,
remote-tracking refs, stash) or any reflog entry.

```
 refs ---> commits ---> trees ---> blobs        reachable: safe forever
 reflog -> old commits (after reset/rebase)      safe until the reflog entry expires
 nothing -> dangling objects                     removed by gc after a grace period
```

Default timers:

| Setting | Default | Meaning |
|---|---|---|
| `gc.reflogExpire` | 90 days | Reflog entries still reachable from the branch |
| `gc.reflogExpireUnreachable` | 30 days | Reflog entries for commits no longer on the branch (e.g. after `reset --hard`) |
| `gc.pruneExpire` | 2 weeks | Unreachable loose objects older than this can be deleted |

Find dangling objects (for example a dropped stash) with:

```bash
git fsck --lost-found       # lists dangling commits/blobs, copies them to .git/lost-found
```

What can **really** be lost: changes that were never staged or committed. Git
never saw them.

## Try it

You staged a file with `git add secret-draft.md`, then ran
`git reset --hard` before committing. Is the content recoverable?

<details>
<summary>Show answer</summary>

Probably yes, for about two weeks. `git add` wrote a blob. It is now dangling:

```bash
git fsck --lost-found
git show <dangling-blob-hash>
```

If you had never run `git add`, it would be gone.

</details>

## Common mistakes

- **Running `git gc --prune=now` in a panic.** It deletes exactly the
  unreachable objects you might need. Recover first, clean later.
- **Believing deleted branches are gone instantly.** Their commits stay in the
  reflog for weeks.
- **Committing huge binaries "just once".** Every version stays in history and
  every clone downloads it (Section 12 covers Git LFS).

## Remember

- The index lists path -> blob for the next commit; `git ls-files -s` shows it.
- Conflicts = stages 1 (base), 2 (ours), 3 (theirs) in the index.
- Loose objects get packed into delta-compressed packfiles.
- Reachable objects are safe; unreachable ones survive weeks via reflog/grace periods.
- Never-staged edits are the only thing Git truly cannot recover.

**Self-check:**

1. What does stage 2 hold during a conflict?
2. What makes an object reachable?
3. Which work can Git never recover?
