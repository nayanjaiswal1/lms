---
kind: lesson
id_key: git/power-tools/large-repos
course: git
section: power-tools
section_title: "Power Tools: Worktrees, Submodules and Large Repos"
section_position: 12
title: "Working with Huge Repositories and Large Files"
position: 2
estimated_minutes: 9
source:
  - git-clone(1) --depth/--filter, git-sparse-checkout(1), git-maintenance(1), scalar(1) manual pages
  - Git LFS documentation (git-lfs.com)
---

## Why this matters

A monorepo with 10 years of history, 300,000 files and some 200 MB design
assets can take an hour to clone and seconds for every `git status`. CI clones
it hundreds of times a day. A few built-in features make huge repositories
fast, and one extension (Git LFS) keeps big binaries out of history.

## Mental model: download less, look at less, keep it tidy

| Problem | Fix | Idea |
|---|---|---|
| Too much **history** | Shallow clone | Only the last N commits |
| Too many **file versions** | Partial clone | Fetch file contents on demand |
| Too many **files on disk** | Sparse checkout | Only the folders you work on |
| Slow commands over time | Background maintenance | Keep packs and indexes fresh |
| Big **binaries** | Git LFS | Store pointers in Git, files elsewhere |

## See it work

### Shallow clone (CI favourite)

```bash
git clone --depth 1 https://example.com/big.git
git rev-parse --is-shallow-repository      # true
```

Fast, but `log`, `blame` and `bisect` only see what you downloaded. Get more
later with `git fetch --deepen=100` or `git fetch --unshallow`.

Gotcha: from a **local path** `--depth` is ignored:

```
warning: --depth is ignored in local clones; use file:// instead.
```

Use `git clone --depth 1 file:///srv/big.git` instead.

### Partial clone (best for developers)

```bash
git clone --filter=blob:none https://example.com/big.git
```

What this does: downloads all commits and trees but **no file contents**
except those needed for the checkout; older versions are fetched on demand when
you look at them. Full history for `log`, much smaller download. Use
`--filter=tree:0` for CI that needs only the current files plus commits.

### Sparse checkout

```bash
git sparse-checkout set services/payments libs/common
git sparse-checkout list
git sparse-checkout disable          # back to everything
```

What this does: only those folders (plus files at the root) appear in your
working tree. `git status` and builds get faster because there are fewer files.
Combine with partial clone:
`git clone --filter=blob:none --sparse <url>`.

### Keep it fast

```bash
git maintenance start        # schedules background tasks: prefetch, commit-graph, loose objects, incremental repack
git config core.fsmonitor true   # (where supported) a daemon watches files so status need not scan everything
```

`scalar clone <url>` (shipped with Git since 2.38) sets up partial clone,
sparse checkout and maintenance in one command for very large repos.

### Large binary files: Git LFS

Every version of every committed file stays in history forever. Ten versions of
a 200 MB video = 2 GB that **every** clone downloads.

```bash
git lfs install                    # once per machine
git lfs track "*.psd" "*.mp4"      # writes rules into .gitattributes
git add .gitattributes design.psd
git commit -m "Track design files with LFS"
```

Git stores a tiny pointer file; the real file lives on the LFS server and is
downloaded only for the version you check out. Hosts often reject plain-Git
files over 100 MB, so set LFS up **before** the first big file is committed.

Moving existing big files into LFS rewrites history (`git lfs migrate import`),
with the same team coordination as any rewrite.

## Try it

CI takes 9 minutes just to clone the monorepo, and the build only needs the
latest files. Which two clone options would you try?

<details>
<summary>Show answer</summary>

`--depth 1` (shallow: only the latest commit) and, if the build touches only
some folders, `--filter=blob:none --sparse` plus `git sparse-checkout set
<folders>`. Many CI systems expose these as "fetch depth" and "sparse checkout"
settings.

</details>

## Common mistakes

- **Shallow clones for developers.** Blame, log and bisect break in confusing
  ways. Prefer partial clone (`--filter=blob:none`).
- **Adding LFS after the fact.** The big files are already in history; only a
  rewrite removes them.
- **Committing generated files** (builds, `node_modules`, datasets). Ignore and
  regenerate them instead.

## Remember

- Shallow (`--depth`) = less history; partial (`--filter=blob:none`) = contents on demand.
- `git sparse-checkout set <dirs>` = fewer files on disk.
- `git maintenance start` / `scalar` keep huge repos fast.
- Big binaries go in Git LFS from day one.

**Self-check:**

1. What does a partial clone skip downloading?
2. Why should developers prefer partial over shallow clones?
3. What does Git store in the repo for an LFS-tracked file?
