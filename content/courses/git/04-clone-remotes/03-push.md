---
kind: lesson
id_key: git/clone-remotes/push
course: git
section: clone-remotes
section_title: "Clone, Fetch, Pull and Push"
section_position: 4
title: "push: Publishing Branches and Handling Rejections"
position: 2
estimated_minutes: 8
source:
  - Pro Git book, ch. 3.5 "Remote Branches"
  - git-push(1) manual page
---

## Why this matters

Your first rejected push feels like an error. It is actually Git protecting a
teammate's work. Learn what the rejection means, how to publish a new branch
with one command, and how to clean up branches on the server.

## Mental model: the server only accepts "forward"

A normal push may only move a server branch **forward**: your branch must
already contain everything the server branch has. This is called a
**fast-forward**.

```
You commit locally, a teammate pushes first:

            origin/main (server)           your clone
 before:    A---B---C---T                  A---B---C---N   <- main

 git push  -> REJECTED: server has T that you do not have (non-fast-forward)
```

If the server accepted your push, `T` would be thrown away. So it refuses.

## See it work

### A rejected push and the fix

```bash
git push
```

Expected output:

```
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to '/srv/git/origin.git'
hint: Updates were rejected because the remote contains work that you do not
hint: have locally. ...
```

The fix is always: **integrate first, then push.**

```bash
git pull --no-rebase    # or: git pull --rebase
git push
```

Now your branch contains `T`, so the push is a fast-forward for the server.

```knowledge-check
{ "questions": [
  { "id": "git-clone-fetch-q2", "type": "mcq",
    "prompt": "A push is rejected with 'fetch first'. What is the usual fix?",
    "options": [
      {"id":"a","text":"git push --force"},
      {"id":"b","text":"Delete the remote"},
      {"id":"c","text":"Integrate the remote work (pull, or fetch + merge/rebase) and push again"},
      {"id":"d","text":"Re-clone the repository"}],
    "correct": "c",
    "explanation": "Force pushing would erase the teammate's commit. Deleting the remote or re-cloning loses your local work or setup. Integrate first, then push a fast-forward." }
] }
```

### Publish a new branch

```
 before:  feature/search            (local only)
 after :  feature/search -> origin/feature/search     git push -u origin feature/search
```

```bash
git switch -c feature/search
echo search > search.txt && git add search.txt && git commit -m "Add search stub"
git push -u origin feature/search
```

What `-u` (`--set-upstream`) does: pushes **and** records
`origin/feature/search` as the upstream, so later a bare `git push` or
`git pull` knows where to go. Expected last line:

```
branch 'feature/search' set up to track 'origin/feature/search'.
```

Tip: `git config --global push.autoSetupRemote true` makes the first plain
`git push` of a new branch do this automatically.

```knowledge-check
{ "questions": [
  { "id": "git-clone-publish-q1", "type": "mcq",
    "prompt": "What does the -u in git push -u origin feature/search do?",
    "options": [
      {"id":"a","text":"Updates all submodules"},
      {"id":"b","text":"Records origin/feature/search as the upstream so later bare git pull/push work"},
      {"id":"c","text":"Uploads untracked files"},
      {"id":"d","text":"Forces the push"}],
    "correct": "b",
    "explanation": "-u is short for --set-upstream and writes the tracking configuration. It has nothing to do with submodules, untracked files are never pushed, and it does not force anything." }
] }
```

### See what is on the server

```bash
git ls-remote origin
```

Expected output (hashes differ):

```
c7e21d0...	HEAD
c7e21d0...	refs/heads/main
5d2e9a1...	refs/heads/feature/login
e0b64f9...	refs/heads/feature/search
```

### Delete and prune remote branches

```bash
git push origin --delete feature/search   # delete the branch on the server
git fetch --prune                         # drop origin/* notes for branches deleted on the server
```

Set `git config --global fetch.prune true` to prune on every fetch.

## Try it

You ran `git push` on a new branch and got: `fatal: The current branch
feature/x has no upstream branch.` What one command fixes it?

<details>
<summary>Show answer</summary>

```bash
git push -u origin feature/x
```

After that, plain `git push` works for this branch.

</details>

## Common mistakes

- **Answering a rejection with `--force`.** That deletes your teammate's
  commits from the server. Integrate instead.
- **Pushing to the wrong branch.** `git push origin main` while on a feature
  branch pushes your **local main**, not the feature. Read the command carefully.
- **Expecting tags to go up with a plain push.** They do not (Section 11).
- **Stale `origin/*` branches piling up.** Use `fetch --prune`.

## Remember

- Push only fast-forwards the server branch. Rejected = integrate, then push.
- `git push -u origin <branch>` publishes and sets the upstream.
- `git ls-remote origin` shows what the server really has.
- `git push origin --delete <branch>` + `git fetch --prune` clean up.

**Self-check:**

1. Why does Git reject a non-fast-forward push?
2. What does `-u` record?
3. Which command removes stale `origin/*` branches?
