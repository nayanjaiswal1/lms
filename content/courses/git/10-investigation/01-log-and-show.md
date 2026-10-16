---
kind: lesson
id_key: git/investigation/log-show
course: git
section: investigation
section_title: Investigating History
section_position: 10
title: "Reading History with log and show"
position: 0
estimated_minutes: 8
source:
  - Pro Git book, ch. 2.3 "Viewing the Commit History"
  - git-log(1), git-show(1) manual pages
---

## Why this matters

Production is broken. A test that passed last week now fails. Who changed what,
when and why? History answers that, but `git log` on a real project prints
thousands of commits. You need filters that cut it to the five commits that
matter.

## Mental model: a searchable logbook

`git log` is a ship's logbook. You rarely read it front to back; you ask
questions: "entries by Dave", "entries touching tax.sh", "entries last week",
"entries on this branch but not on main". Each question is a flag.

## See it work

### Shapes of output

```bash
git log --oneline -5                     # last 5, one line each
git log --oneline --graph --all          # every branch as a graph
git log --stat -3                        # which files each commit changed
git log -p -1                            # full patch of the latest commit
git log --format='%h %an %ad %s' --date=short -3
```

What the last one prints (format placeholders: `%h` short hash, `%an` author,
`%ad` date, `%s` subject):

```
a71e3c9 Heidi Renamer 2024-06-13 Rename price helper
9e1b3d0 Bob Docs 2024-06-12 Tidy up
5f0e2c8 Alice Dev 2024-06-11 Bump timeout
```

### Filters

| Question | Command |
|---|---|
| By author | `git log --author="Dave"` |
| By message text | `git log --grep="tax" -i` |
| By date | `git log --since="2 weeks ago" --until=yesterday` |
| Touching a file or folder | `git log -- tax.sh` |
| On feature, not on main | `git log main..feature` |
| Only merges / no merges | `--merges` / `--no-merges` |
| Main line only (one entry per merged PR) | `git log --first-parent main` |

Combine freely: `git log --author=Dave --since=1.week -- src/`.

The `--` separates options and revisions from **paths**. Use it whenever a file
name could look like a branch name.

### show: one object in detail

```bash
git show 7a3f9c1                 # metadata + patch of one commit
git show -s --format='%an <%ae>' 7a3f9c1   # just the author line
git show v1.0:tax.sh             # a file as it was at a tag
git show v1.0                    # tag info + the commit
```

Expected output of the second command:

```
Dave Hotfix <dave@example.com>
```

### Who did how much

```bash
git shortlog -sn          # commit counts per author
```

## Try it

Write one command that lists, one line each, the commits from the last 30 days
that touched anything under `src/payments/`, excluding merges.

<details>
<summary>Show answer</summary>

```bash
git log --oneline --since="30 days ago" --no-merges -- src/payments/
```

</details>

## Common mistakes

- **Reading `git log` without `--oneline` or a limit.** You drown. Start narrow.
- **Forgetting `--all`.** Without it, `log` shows only commits reachable from
  HEAD, so other branches look missing.
- **Author vs committer.** After rebase or cherry-pick they can differ;
  `%an` is who wrote it, `%cn` who applied it.

## Remember

- `--oneline --graph --all` for shape; `--stat` / `-p` for detail.
- Filter by `--author`, `--grep`, `--since`, `-- <path>`, `A..B`.
- `git show <rev>` for one commit; `git show <rev>:<path>` for an old file.
- `--first-parent` reads a merge-based main branch as one entry per feature.

**Self-check:**

1. How do you list commits on `feature` that are not on `main`?
2. What does `--` do in `git log -- tax.sh`?
3. How do you print an old version of a file without checking it out?
