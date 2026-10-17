---
kind: lesson
id_key: git/first-commits/gitignore
course: git
section: first-commits
section_title: "Setup and First Commits"
section_position: 2
title: "Ignoring Files with .gitignore"
position: 2
estimated_minutes: 7
source:
  - gitignore(5) manual page
  - Pro Git book, ch. 2.2 "Ignoring Files"
---

## Why this matters

Logs, build output, dependency folders and secrets must never be committed.
Logs bloat history, build output causes pointless conflicts, and a committed
password stays in history even after you delete the file. `.gitignore` keeps
them out from the start.

## Mental model: a bouncer for untracked files

`.gitignore` is a bouncer at the door of the index. It stops **new** (untracked)
files from walking in when you run `git add .`. It does nothing to files that
are already inside (tracked).

```
 untracked file --> [ .gitignore bouncer ] --x  blocked: not shown in status, not added
 tracked file   --> already inside; the bouncer ignores it
```

## See it work

### Write the rules

```bash
printf '*.log\nbuild/\n.env\n' > .gitignore
cat .gitignore
```

What this does: creates a `.gitignore` with three patterns. Expected output:

```
*.log
build/
.env
```

| Pattern | Matches |
|---|---|
| `*.log` | any file ending in `.log`, in any folder |
| `build/` | a directory named `build`, anywhere |
| `/build/` | only `build` at the repository root |
| `.env` | a file named `.env` anywhere |
| `!keep.log` | an exception: do NOT ignore `keep.log` |
| `docs/**/*.tmp` | `.tmp` files at any depth under `docs` |
| `# note` | a comment |

Commit `.gitignore` itself so the whole team shares the rules.

### Check that a rule works

```bash
echo noise > app.log
git status -s                 # app.log is NOT listed
git check-ignore -v app.log
```

Expected output of the last command:

```
.gitignore:1:*.log	app.log
```

It tells you the file, line number and pattern that matched. Use it whenever
you wonder "why is this file ignored?".

### Where else ignore rules can live

| File | Shared with team? | Use for |
|---|---|---|
| `.gitignore` (committed) | Yes | Project build output, logs, `.env` |
| `.git/info/exclude` | No | Your personal scratch files in one repo |
| `core.excludesFile` (e.g. `~/.config/git/ignore`) | No | Editor and OS junk (`.DS_Store`, `.idea/`) everywhere |

### Stopping tracking of a file that is already committed

```bash
git rm --cached app.log      # remove from the index, keep the file on disk
echo "*.log" >> .gitignore
git commit -m "Stop tracking app.log"
```

`--cached` means "only the index". Without it, `git rm` also deletes the file
from your disk.

```knowledge-check
{ "questions": [
  { "id": "git-first-ignore-q1", "type": "mcq",
    "prompt": "You add app.log to .gitignore AFTER committing it. What happens to the already-tracked app.log?",
    "options": [
      {"id":"a","text":"It is deleted from history"},
      {"id":"b","text":"It stays tracked until you git rm --cached it"},
      {"id":"c","text":"It is removed from disk"},
      {"id":"d","text":"Git refuses further commits"}],
    "correct": "b",
    "explanation": ".gitignore only affects untracked files. A tracked file keeps being tracked until you remove it from the index with git rm --cached. Nothing is deleted from history or disk, and commits keep working." }
] }
```

## Try it

You committed `.env` containing a database password last week. You now add
`.env` to `.gitignore` and run `git rm --cached .env` and commit. Is the
password safe?

<details>
<summary>Show answer</summary>

No. The password is still inside last week's commit, and anyone with the repo
can read it with `git show <old-commit>:.env`. Treat it as leaked: **rotate the
password first**, then optionally rewrite history (Section 13 covers
`git filter-repo`).

</details>

## Common mistakes

- **Expecting `.gitignore` to untrack committed files.** It never does. Use
  `git rm --cached`.
- **Ignoring the folder but adding a file inside it by name.** `git add -f`
  forces an ignored file in; avoid unless you mean it.
- **Putting personal editor junk in the project `.gitignore`.** Use your global
  excludes file so every repo benefits and teammates are not bothered.
- **Ignoring `.env` but committing `.env.example` with real values.** The example
  file must contain placeholders only.

## Remember

- `.gitignore` stops **untracked** files from being added. It never touches tracked ones.
- `git check-ignore -v <file>` shows which rule matched.
- `git rm --cached <file>` untracks a file but keeps it on disk.
- A secret that was ever committed is leaked: rotate it.

**Self-check:**

1. What does a trailing `/` in a pattern mean?
2. Which command explains why a file is ignored?
3. What is the difference between `git rm` and `git rm --cached`?
