---
kind: lesson
id_key: git/clone-remotes/clone-tracking
course: git
section: clone-remotes
section_title: "Clone, Fetch, Pull and Push"
section_position: 4
title: "Clone, Remote-Tracking Branches and Upstreams"
position: 0
estimated_minutes: 8
source:
  - Pro Git book, ch. 2.1 "Cloning an Existing Repository" and ch. 3.5 "Remote Branches"
  - git-clone(1), git-branch(1) manual pages
---

## Why this matters

Maya says: "Pull my latest, add your change, push it back." Before you can do
that you need a clone and you need to read three kinds of branch names:
`main`, `origin/main` and the link between them. Confusing them is the root of
most "but I pulled!" surprises.

## Mental model: your branch, your notes about theirs, and the link

```
        origin  (/home/labuser/srv/git/origin.git)
        A---B---C  <- main
                 \
                  D  <- feature/login
   ============================================
        your clone
        A---B---C  <- main, origin/main
                 \
                  D  <- origin/feature/login
```

- `main` - **your** local branch. Moves when you commit.
- `origin/main` - a **remote-tracking branch**: your last-known note of where
  the server's `main` was. It is read-only and moves only when you `fetch`,
  `pull` or `push`.
- **Upstream** - the setting that links `main` to `origin/main`, so `git status`,
  `git pull` and `git push` know what to compare with.

> **One-sentence definition:** `origin/main` is a snapshot of the server's branch
> as of your last contact, not a live view.

## See it work

### Clone

```bash
git clone /home/labuser/srv/git/origin.git app
cd app
git remote -v
git branch -a
```

What this does: copies the full history, creates remote `origin`, creates
`origin/*` tracking branches, and checks out `main` linked to `origin/main`.
Expected output of `git branch -a`:

```
* main
  remotes/origin/HEAD -> origin/main
  remotes/origin/feature/login
  remotes/origin/main
```

Only `main` is a local branch. The others are your notes about the server.

```knowledge-check
{ "questions": [
  { "id": "git-clone-remote-q1", "type": "mcq",
    "prompt": "What is origin/main in your clone?",
    "options": [
      {"id":"a","text":"A live view of the server's main branch"},
      {"id":"b","text":"A local snapshot of where the server's main was at your last fetch"},
      {"id":"c","text":"A second copy of your own main branch"},
      {"id":"d","text":"A tag"}],
    "correct": "b",
    "explanation": "Remote-tracking branches are only updated when you talk to the remote (fetch, pull, push). They are not live, not a copy of your branch, and not tags." }
] }
```

### Start working on a remote branch

```bash
git switch feature/login
git branch -vv
```

What this does: no local `feature/login` exists, but `origin/feature/login`
does, so `git switch` creates a local branch from it and sets the upstream.
Expected output:

```
* feature/login 5d2e9a1 [origin/feature/login] Add login form
  main          8c1f7b3 [origin/main] Add license
```

The square brackets show the upstream. After you commit locally it becomes
`[origin/main: ahead 1]`; after a fetch brings new server commits it can show
`[origin/main: ahead 1, behind 2]`.

```knowledge-check
{ "questions": [
  { "id": "git-clone-track-q1", "type": "mcq",
    "prompt": "What does git branch -vv show in square brackets?",
    "options": [
      {"id":"a","text":"The upstream (tracked) branch of each local branch"},
      {"id":"b","text":"The author of the last commit"},
      {"id":"c","text":"Files with conflicts"},
      {"id":"d","text":"Stashed changes"}],
    "correct": "a",
    "explanation": "The upstream is what status, pull and push compare against. Authors, conflicts and stashes are shown by other commands." }
] }
```

### Useful clone options

| Option | Effect |
|---|---|
| `git clone <url> mydir` | Clone into a folder named `mydir` |
| `--branch dev` | Check out `dev` instead of the default branch |
| `--depth 1` | Shallow clone: only the latest commit (fast CI checkouts) |
| `--filter=blob:none` | Partial clone: download file contents only when needed |

The last two matter for huge repositories (Section 12).

## Try it

`git status` says: `Your branch is up to date with 'origin/main'.` A teammate
pushed 5 minutes ago. Is your `main` really up to date with the server?

<details>
<summary>Show answer</summary>

Not necessarily. Status compares with `origin/main`, your **last-known** note.
Until you run `git fetch`, Git does not know about the teammate's push.
"Up to date" means "up to date with what I last saw".

</details>

## Common mistakes

- **Committing on `origin/main`.** You cannot; switching to it gives a
  detached HEAD. Work on a local branch.
- **Trusting "up to date" without fetching.** Run `git fetch` first.
- **Cloning inside another repository.** You get a nested repo that the outer
  one sees as a strange folder. Clone into a clean directory.

## Remember

- Clone = full history + remote `origin` + `origin/*` notes + local `main`.
- `origin/main` moves only on fetch, pull or push.
- Upstream links a local branch to its remote branch; see it with `git branch -vv`.
- `git switch <name>` creates a tracking branch from `origin/<name>`.

**Self-check:**

1. What is the difference between `main` and `origin/main`?
2. What does "ahead 1, behind 2" mean?
3. Why can "up to date" be wrong?
