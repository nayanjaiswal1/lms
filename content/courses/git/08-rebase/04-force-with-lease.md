---
kind: lesson
id_key: git/rebase/force-with-lease
course: git
section: rebase
section_title: Rebase and Rewriting History
section_position: 8
title: "Pushing Rewritten History Safely: --force-with-lease"
position: 3
estimated_minutes: 7
source:
  - git-push(1) manual page, --force-with-lease and --force-if-includes
  - Pro Git book, ch. 3.6 "The Perils of Rebasing"
---

## Why this matters

You rebased or squashed a branch you had already pushed (your pull request).
Now `git push` is rejected. The tempting fix, `--force`, can silently delete a
reviewer's commit. `--force-with-lease` does the same job with a safety check.

## Mental model: a lease on the branch

Plain `--force` says: "make the server branch equal mine, whatever is there."

`--force-with-lease` says: "make it equal mine, **but only if** it still points
where I last saw it (my `origin/<branch>`)". If someone pushed in between, your
lease is broken and the push is refused.

```
 origin/feature:  A---B---C---D        teammate has D checked out
 you rebase  ->   A---B---C'---D'      (new hashes)
 push --force     origin now has C'D'  -> teammate's D is orphaned, their next pull is a mess
```

## See it work

### The rejection

```bash
git push
```

Expected output after a rebase of an already-pushed branch:

```
 ! [rejected]        feature/profile -> feature/profile (non-fast-forward)
```

Your branch no longer contains the server's commits (they were replaced by
copies), so it is not a fast-forward.

### The safe overwrite

```bash
git push --force-with-lease origin feature/profile
```

Expected output:

```
 + 0b7e5ad...91c0d4e feature/profile -> feature/profile (forced update)
```

The `+` and "forced update" confirm the history was replaced.

If a teammate pushed meanwhile, you get instead:

```
 ! [rejected]        feature/profile -> feature/profile (stale info)
```

Then: `git fetch`, look at their commit, integrate it (rebase again), and retry.

### One more safety net

A plain `git fetch` updates `origin/<branch>`, which silently renews your lease
even if you never looked at the new commits. Add:

```bash
git push --force-with-lease --force-if-includes
```

`--force-if-includes` (Git 2.30+) also checks that the remote tip is somewhere
in your branch's reflog, i.e. that you actually integrated it. Set it once with
`git config --global push.useForceIfIncludes true`.

```knowledge-check
{ "questions": [
  { "id": "git-rebase-lease-q1", "type": "mcq",
    "prompt": "Why is --force-with-lease safer than --force?",
    "options": [
      {"id":"a","text":"It refuses to overwrite the remote branch if it has commits you have not seen"},
      {"id":"b","text":"It is faster"},
      {"id":"c","text":"It also rebases for you"},
      {"id":"d","text":"It deletes the remote branch first"}],
    "correct": "a",
    "explanation": "It checks the remote still points where your remote-tracking ref says before overwriting. It is not faster, does not rebase, and never deletes the branch." },
  { "id": "git-rebase-lease-q2", "type": "mcq",
    "prompt": "Which branch should you NEVER rebase?",
    "options": [
      {"id":"a","text":"A private local branch nobody has pulled"},
      {"id":"b","text":"A shared branch like main that others have pulled"},
      {"id":"c","text":"A branch with one commit"},
      {"id":"d","text":"A branch with no remote"}],
    "correct": "b",
    "explanation": "Rewriting commits others already have forces them to reconcile two versions of history. Private, single-commit or local-only branches are safe to rebase." }
] }
```

### Protect important branches on the server

Hosts let you mark `main` (and release branches) as **protected**: no force
pushes, no deletion, changes only through reviewed pull requests. Turn this on
for every shared repository; it makes the golden rule impossible to break by
accident.

## Try it

You rebased your PR branch and ran `git push --force-with-lease`. It says
`(stale info)`. What happened, and what is the safe sequence now?

<details>
<summary>Show answer</summary>

Someone (maybe a reviewer adding a fixup) pushed to your PR branch after your
last fetch. Safe sequence:

```bash
git fetch
git log --oneline feature/profile..origin/feature/profile   # see their commit
git rebase origin/feature/profile    # or cherry-pick their commit onto yours
git push --force-with-lease
```

</details>

## Common mistakes

- **Using `--force` by habit.** Make an alias instead:
  `git config --global alias.pushf "push --force-with-lease --force-if-includes"`.
- **Force-pushing `main`.** Never; revert instead (Section 9). Protect the
  branch on the host.
- **Running `git fetch` right before force-pushing without looking.** The lease
  then always succeeds; use `--force-if-includes`.

## Remember

- After rewriting a pushed branch, a normal push is rejected (non-fast-forward).
- `--force-with-lease` overwrites only if the server is where you last saw it.
- Add `--force-if-includes` so a blind fetch does not defeat the lease.
- Protect `main` on the server; never force-push shared branches.

**Self-check:**

1. What does "(stale info)" mean?
2. What extra check does `--force-if-includes` add?
3. Which branches should be protected on the host?
