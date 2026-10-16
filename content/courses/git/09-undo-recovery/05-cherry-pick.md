---
kind: lesson
id_key: git/undo-recovery/cherry-pick
course: git
section: undo-recovery
section_title: Undo and Recovery
section_position: 9
title: "cherry-pick: Copy One Commit to Another Branch"
position: 4
estimated_minutes: 7
source:
  - Pro Git book, ch. 5.3 "Rebasing and Cherry-Picking Workflows"
  - git-cherry-pick(1) manual page
---

## Why this matters

A bug fix landed on `main`, but the release branch `release/1.4` needs it too,
without the other 30 commits on main. Or you committed to the wrong branch.
`git cherry-pick` copies exactly the commits you choose.

## Mental model: photocopy a single page

Cherry-pick takes one commit's **changes** (its diff against its parent) and
applies them on top of your current branch as a **new commit**. Same message,
same author, but a new parent, so a new hash.

```
BEFORE                                AFTER  git switch main; git cherry-pick S

 main:    A---B---C                    main:    A---B---C---S'   (S' = copy of S)
 audit:        \                       audit:        \
                L---S                                 L---S   (unchanged)
```

## See it work

### Pick one commit

```bash
git log --oneline feature/audit
git switch main
git cherry-pick <hash of "Add audit summary">
```

Expected output:

```
[main 3b9f1a2] Add audit summary
 Author: Priya Auditor <priya@example.com>
 Date: Tue May 7 10:00:00 2024 +0000
 1 file changed, 1 insertion(+)
 create mode 100644 summary.txt
```

The author is preserved (Priya); you become the **committer**.

```knowledge-check
{ "questions": [
  { "id": "git-undo-pick-q1", "type": "mcq",
    "prompt": "A cherry-picked commit has the same hash as the original.",
    "options": [
      {"id":"a","text":"True"},
      {"id":"b","text":"False - it is a new commit with a different parent, so a different hash"}],
    "correct": "b",
    "explanation": "The diff and message are copied but the commit identity (parent, committer, date) differs, so the hash differs." }
] }
```

### Useful options

| Command | Effect |
|---|---|
| `git cherry-pick A B C` | Copy several commits in order |
| `git cherry-pick A..B` | Copy the range after A up to B |
| `git cherry-pick -x <hash>` | Add "(cherry picked from commit ...)" to the message; recommended for backports |
| `git cherry-pick -n <hash>` | Apply changes without committing |
| `git cherry-pick -m 1 <merge>` | Pick a merge commit (relative to parent 1) |
| `--continue` / `--skip` / `--abort` | After a conflict, like rebase |

### Backport a fix to a release branch

```bash
git switch release/1.4
git cherry-pick -x 9f2c1e7      # the fix from main
git push
```

`-x` lets anyone trace the backport to the original commit.

### When not to cherry-pick

Cherry-picking many commits between long-lived branches creates duplicates
(same change, different hashes). Later merges may conflict or show the change
twice. If you need most of a branch, merge or rebase it instead.

## Try it

You committed `Fix login redirect` on `main` by mistake; it belongs on
`feature/login`. Nothing is pushed. Move it.

<details>
<summary>Show answer</summary>

```bash
git switch feature/login
git cherry-pick main          # main's tip = the misplaced commit
git switch main
git reset --hard HEAD~1       # remove it from main (local, unpushed only)
```

Section 13 shows the same fix for several commits.

</details>

## Common mistakes

- **Expecting the same hash.** It is a copy; tools that compare hashes see two
  different commits.
- **Cherry-picking without `-x` on backports.** Later nobody knows where the
  change came from.
- **Using it as a substitute for merging.** Many picks between branches cause
  duplicate commits and confusing conflicts.

## Remember

- Cherry-pick copies a commit's changes as a new commit on the current branch.
- Author is kept; hash is new.
- `-x` records the source; ranges and multiple hashes work.
- Conflicts: fix, `git add`, `git cherry-pick --continue`.

**Self-check:**

1. What does cherry-pick actually copy: the snapshot or the diff?
2. Why add `-x` to a backport?
3. When is merging better than cherry-picking?
