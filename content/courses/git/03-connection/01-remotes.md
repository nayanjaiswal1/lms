---
kind: lesson
id_key: git/connection/remotes
course: git
section: connection
section_title: Connecting to the Team
section_position: 3
title: "Remotes: Names for Other Copies"
position: 0
estimated_minutes: 7
source:
  - Pro Git book, ch. 2.5 "Working with Remotes"
  - git-remote(1) manual page
---

## Why this matters

Day 2. Your history lives only on your laptop. Maya says: "Join the team repo so
I can see your work." To share work you connect your repository to another copy
of it, called a **remote**. Most "push does not work" problems are simply a
wrong remote URL.

## Mental model: contacts in your phone

A remote is a contact entry: a short **name** (like "Mum") saved for a long
**number**. `origin` is just the name Git gives by default to the place you
cloned from. It is not special and you can rename it.

```
 your repo                         remotes (name -> URL)
 +-----------+   origin  ---->  git@github.com:brightside/shop.git
 | .git      |   backup  ---->  /srv/git/backup.git
 +-----------+   upstream ---->  https://github.com/original/shop.git
```

> **One-sentence definition:** a **remote** is a saved name for the URL of
> another copy of the repository.

### URL forms you will meet

| Form | Example | Auth |
|---|---|---|
| SSH | `git@github.com:brightside/shop.git` | SSH key |
| HTTPS | `https://github.com/brightside/shop.git` | Username + token |
| Local path | `/srv/git/team.git` | File permissions |
| File URL | `file:///srv/git/team.git` | File permissions |

Servers usually store **bare** repositories (created with `git init --bare`):
just the `.git` contents, no working tree, because nobody edits files on the
server.

## See it work

### List, add, change, remove

```bash
git remote -v
```

What this does: lists each remote with its fetch and push URL. Expected output:

```
origin  /srv/git/team.git (fetch)
origin  /srv/git/team.git (push)
```

```bash
git remote add backup /srv/git/backup.git       # add a second remote
git remote set-url origin /srv/git/team.git      # fix a wrong URL
git remote rename backup mirror                  # rename
git remote remove mirror                         # delete the entry (not the server repo)
git remote show origin                           # details: branches, tracking
```

### Test the connection without changing anything

```bash
git ls-remote origin
```

What this does: asks the remote for its list of branches and tags. If it
prints refs, the URL and access are fine. If it fails, the message tells you
why:

```
fatal: '/srv/git/tean.git' does not appear to be a git repository
fatal: Could not read from remote repository.
```

That `tean` is a typo. Fix it with `git remote set-url`.

### First push

```
 before push                     after git push origin main
 you   : A---B---C               you   : A---B---C
 origin: A---B                   origin: A---B---C
```

```bash
git push origin main
```

A commit exists only on your machine until you push it.

## Try it

You forked a project on GitHub, cloned your fork, and now want to receive
updates from the original project too. What do you add?

<details>
<summary>Show answer</summary>

A second remote, by convention called `upstream`:

```bash
git remote add upstream https://github.com/original/shop.git
git fetch upstream
```

`origin` stays your fork (where you push); `upstream` is where you pull
updates from.

</details>

## Common mistakes

- **Thinking `git remote remove` deletes the server repo.** It only deletes the
  name from your local config.
- **Pushing to the wrong remote.** With several remotes, always name it:
  `git push origin main`, not just `git push`, until upstreams are set.
- **Typos in the URL.** "Repository not found" or "does not appear to be a git
  repository" is often just that. Check `git remote -v` first.

## Remember

- A remote = name -> URL. `origin` is only the default name.
- `git remote -v` to see, `add` / `set-url` / `remove` to change.
- `git ls-remote origin` tests access without changing anything.
- Commits stay local until you `git push`.

**Self-check:**

1. What is `origin`?
2. Which command fixes a remote's URL?
3. Why do servers use bare repositories?
