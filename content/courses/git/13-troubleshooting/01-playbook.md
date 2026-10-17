---
kind: lesson
id_key: git/troubleshooting/playbook
course: git
section: troubleshooting
section_title: "Troubleshooting Playbook"
section_position: 13
title: "The Git Emergency Playbook: 12 Common Problems"
position: 0
estimated_minutes: 11
source:
  - Pro Git book, ch. 7.7 and 10.7; git-scm.com/docs
  - git-status(1), git-config(1) safe.directory, core.autocrlf, gitattributes(5)
---

## Why this matters

Most Git emergencies are the same dozen situations. Each has a calm,
two-command fix, and most of them reuse what you already learned: refs move,
objects stay, the reflog remembers. This lesson is a lookup table to come back
to.

## Mental model: three questions before any fix

1. **Is it pushed?** Pushed to a shared branch -> only add commits (revert).
   Local only -> you may rewrite (reset, rebase, amend).
2. **Is anything uncommitted?** Commit or stash it first, so a fix cannot
   destroy it.
3. **What does `git status` say?** It names the state (mid-merge, mid-rebase,
   detached) and usually the command to get out.

Mnemonic: **P-U-S** - Pushed? Uncommitted? Status?

## See it work: the playbook

### 1. "I committed on main, it should be on a branch" (not pushed)

```bash
git switch -c feature/report      # new branch keeps the commits
git switch main
git reset --hard origin/main      # main back to the server state
```

```
 before: main: A---B---X---Y  (origin/main = B)
 after : main: A---B           feature/report: A---B---X---Y
```

### 2. "I committed to the wrong branch" (it belongs on an existing one)

```bash
git switch right-branch
git cherry-pick wrong-branch~1 wrong-branch   # or a range
git switch wrong-branch && git reset --hard HEAD~2
```

### 3. "I'm in detached HEAD"

`git status` says `HEAD detached at ...`. Just looking? `git switch main`. Made
commits? `git switch -c keep-them` first. Already left? `git reflog` (Section 7).

### 4. "I deleted a branch I needed"

```bash
git reflog | grep feature/export     # or look for its last commit message
git branch feature/export <hash>
```

`git branch -D` also prints the hash it deleted: `Deleted branch x (was 1a2b3c4).`

### 5. "I dropped a stash"

Stashes are commits but not in the reflog once dropped. Find dangling ones:

```bash
git fsck --no-reflogs --unreachable | grep commit
git stash apply <hash>          # check each candidate with git show first
```

### 6. "Your branch and 'origin/main' have diverged"

Both sides have new commits. Decide how to integrate:

```bash
git pull --rebase      # your unpushed commits on top (linear)
# or
git pull --no-rebase   # merge commit
```

Never answer it with `push --force` on a shared branch.

### 7. "fatal: refusing to merge unrelated histories"

The two branches share no root commit, usually because the remote was created
with a README and you `git init`-ed locally. If you really mean to combine them:
`git pull origin main --allow-unrelated-histories`. Otherwise you have the
wrong remote URL.

### 8. "Unable to create '.../.git/index.lock': File exists"

Another Git process is running (editor integration, a hung command), or one
crashed. Check nothing is running (`ps aux | grep git`), then:

```bash
rm .git/index.lock
```

### 9. "fatal: detected dubious ownership in repository"

The repo folder belongs to another user (shared drives, containers, `sudo`).
Git refuses for security. If you trust it:

```bash
git config --global --add safe.directory /path/to/repo
```

### 10. Every line shows as changed (line endings / file mode)

Windows (CRLF) and Linux/macOS (LF) line endings, or executable bits flipping.
Fix it for everyone in the repo with `.gitattributes`:

```
* text=auto eol=lf
*.bat text eol=crlf
*.png binary
```

Then `git add --renormalize .` and commit. A mode-only diff
(`old mode 100644 / new mode 100755`) can be silenced with
`git config core.fileMode false` on filesystems that do not support it.

### 11. Push rejected: file too large

Hosts refuse files over a limit (GitHub: 100 MB). Removing the file in a new
commit is **not enough**; it is still in the unpushed history. If the commit is
local, `git reset --soft origin/main`, unstage the file, ignore it or track it
with LFS, and recommit. If it is deeper, rewrite with `git filter-repo`
(next lesson).

### 12. "I committed a secret"

Rotate it **first**. Then clean history (next lesson).

## Try it

You made two commits on local `main` that belong on a new branch
`feature/export`, and nothing is pushed. Write the three commands.

<details>
<summary>Show answer</summary>

```bash
git branch feature/export          # label the current commit
git reset --hard origin/main       # move main back (uncommitted work? stash first)
git switch feature/export
```

</details>

## Common mistakes

- **Fixing before reading `git status`.** It often names the exact way out.
- **Reaching for `--force` or `rm -rf .git`.** Almost every situation has a
  non-destructive fix.
- **Re-cloning to "start fresh".** You lose local branches, stashes and the
  reflog: the very tools that would have saved you.

## Remember

- P-U-S: Pushed? Uncommitted? Status?
- Misplaced commits: label them with a branch, then reset the wrong branch.
- Lost things: reflog for commits and branches, `fsck --unreachable` for stashes.
- Lock files, dubious ownership, line endings: read the message, apply the one-line fix.

**Self-check:**

1. What are the three P-U-S questions?
2. How do you recover a dropped stash?
3. Why is removing a big file in a new commit not enough before pushing?
