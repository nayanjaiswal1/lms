---
kind: lesson
id_key: git/undo-recovery/stash
course: git
section: undo-recovery
section_title: Undo and Recovery
section_position: 9
title: "stash: Park Work in Progress"
position: 5
estimated_minutes: 7
source:
  - Pro Git book, ch. 7.3 "Stashing and Cleaning"
  - git-stash(1) manual page
---

## Why this matters

You are halfway through a change when Maya says: "Production is down, switch to
main now." Your edits are not ready to commit, and Git will not let you switch
if they clash. `git stash` puts them aside in one command and brings them back
later.

## Mental model: a drawer for unfinished work

Stash sweeps your uncommitted changes into a drawer and leaves your desk clean
(working tree matches HEAD). The drawer is a stack: the newest item is
`stash@{0}`.

```
 working tree dirty ----git stash push -m "wip total"----> working tree clean
                                     stash@{0} holds the edits
 later: git stash pop  ------------------------------------> edits are back, stash entry dropped
```

Internally each stash is a commit (plus one for the index) stored under
`refs/stash`, not on any branch.

## See it work

### Stash and list

```bash
echo "WIP total" >> ledger.txt
git stash push -m "wip total"
git stash list
git status -s
```

Expected output:

```
Saved working directory and index state On main: wip total
stash@{0}: On main: wip total
```

`git status -s` prints nothing: the tree is clean.

### Bring it back

```bash
git stash pop          # apply stash@{0} and drop it
```

```knowledge-check
{ "questions": [
  { "id": "git-undo-stash-q1", "type": "mcq",
    "prompt": "What is the difference between git stash pop and git stash apply?",
    "options": [
      {"id":"a","text":"pop applies and removes the stash entry; apply keeps it"},
      {"id":"b","text":"pop deletes the repo"},
      {"id":"c","text":"apply only works on tags"},
      {"id":"d","text":"There is none"}],
    "correct": "a",
    "explanation": "apply is useful when you want to apply the same stash on several branches. pop never touches the repo itself, and both work on any branch." }
] }
```

If `pop` hits a conflict, the stash is **kept** so nothing is lost. Resolve,
then `git stash drop` yourself.

### The useful options

| Command | Effect |
|---|---|
| `git stash push -u` | Also stash **untracked** files (default: tracked only) |
| `git stash push -p` | Choose hunks interactively |
| `git stash push -- path/` | Stash only some paths |
| `git stash push --staged` | Stash only what is staged (Git 2.35+) |
| `git stash show -p stash@{1}` | See a stash's diff |
| `git stash apply stash@{1}` | Apply an older stash, keep it |
| `git stash drop stash@{1}` / `clear` | Delete one / all (careful) |
| `git stash branch new-branch` | Create a branch from where you stashed and apply it there |

`git stash branch` is the cleanest fix when a stash no longer applies because
the code moved on.

### Stash or commit?

Stashes have no good names, are easy to forget, and are local only. For
anything longer than a quick context switch, a **WIP commit on a branch** is
safer: `git switch -c wip/report && git commit -am "WIP"`, and amend or squash it
later.

## Try it

You need to switch branches but have edits to `app.sh` **and** a new file
`notes.md` you have not added. Plain `git stash` leaves `notes.md` behind. What
do you run?

<details>
<summary>Show answer</summary>

```bash
git stash push -u -m "wip app and notes"
```

`-u` includes untracked files. Restore later with `git stash pop`.

</details>

## Common mistakes

- **Forgetting untracked files.** Use `-u`.
- **Piling up ten anonymous stashes.** Always add `-m "message"`, and clean up
  with `git stash list` regularly.
- **`git stash clear` by accident.** Dropped stashes can sometimes be found
  with `git fsck --unreachable` (Section 13), but do not rely on it.

## Remember

- `git stash push -m "msg"` parks changes; `git stash pop` brings them back.
- `pop` = apply + drop; `apply` keeps the entry.
- `-u` includes untracked files; `stash branch` rescues stale stashes.
- For longer pauses, prefer a WIP commit on a branch.

**Self-check:**

1. What does plain `git stash` leave behind?
2. What happens to the stash entry if `pop` conflicts?
3. When is a WIP commit better than a stash?
