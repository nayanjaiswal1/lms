---
kind: lesson
id_key: git/clone-remotes/fetch-pull
course: git
section: clone-remotes
section_title: "Clone, Fetch, Pull and Push"
section_position: 4
title: "fetch vs pull: Look Before You Merge"
position: 1
estimated_minutes: 8
source:
  - Pro Git book, ch. 3.5 "Remote Branches"
  - git-fetch(1), git-pull(1) manual pages
---

## Why this matters

`git pull` is the command beginners use most and understand least. It is
really two commands glued together. Knowing the two halves lets you check what
a teammate changed **before** it lands in your branch, and explains the pull
error modern Git shows when histories have diverged.

## Mental model: check the mailbox, then open the letters

- `git fetch` = check the mailbox. New letters arrive in `origin/*`. Nothing on
  your desk changes.
- `git merge origin/main` (or `git rebase origin/main`) = open the letters and
  file them into your own branch.
- `git pull` = both, in one step.

```
 pull = fetch + integrate

 git fetch:       origin/* updated        your branches: untouched
 git merge:       your branch absorbs origin/main
```

## See it work

### fetch is always safe

```bash
git fetch
git log --oneline --graph --all
```

What this does: downloads new commits and moves `origin/main`; never touches
your branches or files. Expected graph when you and a teammate both committed:

```
* 9d4b0c2 (origin/main) Teammate: add changelog
| * 41ae6f8 (HEAD -> main) Add notes.txt
|/
* 8c1f7b3 Add license
```

Now you can inspect before integrating:

```bash
git log main..origin/main --oneline     # commits on the server you do not have
git diff main...origin/main             # what they changed since you split
```

```knowledge-check
{ "questions": [
  { "id": "git-clone-fetch-q1", "type": "mcq",
    "prompt": "After git fetch, which of these has changed?",
    "options": [
      {"id":"a","text":"Your local main branch and working tree"},
      {"id":"b","text":"Only the remote-tracking branches such as origin/main"},
      {"id":"c","text":"Nothing, fetch only prints a message"},
      {"id":"d","text":"The server's branches"}],
    "correct": "b",
    "explanation": "fetch is safe: it never changes your branches or files, and it only reads from the server. It does change something: your origin/* notes." }
] }
```

### pull: fetch and integrate

```
 before pull               after git pull (merge)          after git push
 N <- main                 M <- main  (merge commit)       server main = M
 T <- origin/main           / \                            (fast-forward)
                           N   T <- origin/main
```

```bash
git pull --no-rebase      # fetch + merge
git log --oneline --graph
```

Expected output:

```
*   c7e21d0 (HEAD -> main) Merge branch 'main' of /srv/git/origin
|\
| * 9d4b0c2 (origin/main) Teammate: add changelog
* | 41ae6f8 Add notes.txt
|/
* 8c1f7b3 Add license
```

```knowledge-check
{ "questions": [
  { "id": "git-clone-pull-q1", "type": "mcq",
    "prompt": "git pull is equivalent to:",
    "options": [
      {"id":"a","text":"git fetch followed by git merge (or rebase) of the upstream branch"},
      {"id":"b","text":"git push in the other direction"},
      {"id":"c","text":"git clone again"},
      {"id":"d","text":"git fetch only"}],
    "correct": "a",
    "explanation": "pull = fetch + integrate. Knowing the two halves lets you inspect before integrating. It is not a reverse push, not a re-clone, and it does more than fetch." }
] }
```

### The "divergent branches" message

When both sides have new commits and you have not said how to integrate, modern
Git (2.33+) stops:

```
hint: You have divergent branches and need to specify how to reconcile them.
...
fatal: Need to specify how to reconcile divergent branches.
```

Pick a default once:

| Setting | What pull does when histories diverged |
|---|---|
| `git config --global pull.rebase false` | Merge (creates a merge commit) |
| `git config --global pull.rebase true` | Rebase your commits on top (linear history; Section 8) |
| `git config --global pull.ff only` | Refuse; you decide manually |

Per command: `git pull --no-rebase`, `git pull --rebase`, `git pull --ff-only`.

## Try it

You are about to leave for the weekend and just want to see what the team
pushed today, without touching your half-finished branch. Which commands?

<details>
<summary>Show answer</summary>

```bash
git fetch
git log --oneline HEAD..origin/main
```

`fetch` updates only `origin/*`; the log lists the commits you do not have yet.
Your branch and working tree are untouched.

</details>

## Common mistakes

- **Pulling with uncommitted changes.** If the incoming commits touch the same
  files, Git refuses. Commit or stash (Section 9) first.
- **Thinking fetch "did nothing".** It updated `origin/*`. Look with
  `git log --all --graph`.
- **Accidental merge commits from habitual `git pull`.** Many teams set
  `pull.rebase true` or `pull.ff only` to avoid noise.

## Remember

- `fetch` downloads into `origin/*` and changes nothing else. Always safe.
- `pull` = `fetch` + merge (or rebase).
- `git log main..origin/main` = what you have not integrated yet.
- Set `pull.rebase` (or `pull.ff only`) once to avoid the divergent-branches error.

**Self-check:**

1. Which command updates `origin/main` without touching `main`?
2. What are the two halves of `git pull`?
3. What does `git log main..origin/main` list?
