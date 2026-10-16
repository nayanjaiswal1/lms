---
kind: lesson
id_key: git/rebase/interactive
course: git
section: rebase
section_title: "Rebase and Rewriting History"
section_position: 8
title: "Interactive Rebase: Squash, Reorder, Reword, Drop"
position: 2
estimated_minutes: 9
source:
  - Pro Git book, ch. 7.6 "Rewriting History"
  - git-rebase(1) manual page, INTERACTIVE MODE and --autosquash
---

## Why this matters

While working you commit "wip", "fix typo", "really fix it". Reviewers and
future readers (and `git bisect`) want a short story of clean, meaningful
commits. Interactive rebase lets you edit your branch's history like a to-do
list before anyone else sees it.

## Mental model: editing a playlist

`git rebase -i main` shows your branch's commits as a playlist, **oldest at the
top**. You edit the list (reorder lines, change the verb in front of each), save,
and Git replays the playlist exactly as written.

```
 pick   1111 wip: profile skeleton        pick   1111 wip: profile skeleton
 pick   2222 wip: add avatar        -->   fixup  3333 fix typo in profile
 pick   3333 fix typo in profile          fixup  4444 wip: bio
 pick   4444 wip: bio                     pick   2222 wip: add avatar
```

```
BEFORE (4 commits)                  AFTER (2 commits)

 main---P1---P2---P3---P4            main---P1'---P2'
        skel avatar typo bio              skel+typo+bio  avatar
```

## See it work

### The verbs

| Verb | Short | Effect |
|---|---|---|
| `pick` | `p` | Keep the commit as is |
| `reword` | `r` | Keep content, edit the message |
| `edit` | `e` | Stop after applying, so you can amend or split it |
| `squash` | `s` | Meld into the commit above; combine both messages |
| `fixup` | `f` | Meld into the commit above; discard this message |
| `drop` | `d` | Delete the commit (or just delete the line) |
| `exec` | `x` | Run a shell command, e.g. `x npm test`; stop if it fails |

Reordering lines reorders commits. Commits touching different files reorder
without conflicts.

### Run it

```bash
git switch feature/profile
git rebase -i main
```

Git opens your editor with the list. Edit, save, close. Expected result:

```
* 91c0d4e (HEAD -> feature/profile) Add profile avatar
* 6a2fb85 Add profile page
* b1e47a0 (main) Rename title to Dev Blog
```

Prefer `git rebase -i main` (or `origin/main`) over `HEAD~N`: it always picks
exactly the commits on your branch.

```knowledge-check
{ "questions": [
  { "id": "git-rebase-interactive-q1", "type": "mcq",
    "prompt": "What is the difference between squash and fixup in an interactive rebase?",
    "options": [
      {"id":"a","text":"squash keeps and combines the commit message, fixup discards it"},
      {"id":"b","text":"fixup deletes the file"},
      {"id":"c","text":"They are identical"},
      {"id":"d","text":"squash pushes to the remote"}],
    "correct": "a",
    "explanation": "Both meld the commit into the previous one; only squash lets you keep its message. Neither deletes files or pushes." }
] }
```

### Plan fixups as you go: --fixup and --autosquash

```bash
git commit --fixup=6a2fb85          # creates "fixup! Add profile page"
git rebase -i --autosquash main     # Git pre-moves and marks it as fixup
```

Set `git config --global rebase.autoSquash true` to make this the default.

### Scripting it

The todo list editor is `GIT_SEQUENCE_EDITOR`; the message editor is
`GIT_EDITOR`. Useful in labs and scripts:

```bash
GIT_SEQUENCE_EDITOR="sed -i '2,\$s/^pick/fixup/'" git rebase -i main   # squash all into the first
```

### Move a branch to a different base: --onto

You started `feature/b` from `feature/a`, but `feature/a` was dropped. Move only
B's own commits onto main:

```bash
git rebase --onto main feature/a feature/b
```

Read it as: "take commits after `feature/a` up to `feature/b`, replay them onto
`main`".

## Try it

Your branch has commits (oldest first): `Add search`, `Debug prints`,
`Fix search for empty query`. You want one commit `Add search` (including the
fix) and no debug prints. Write the todo list.

<details>
<summary>Show answer</summary>

```
pick  aaa Add search
fixup ccc Fix search for empty query
drop  bbb Debug prints
```

`fixup` must sit directly under the commit it melds into; `drop` (or deleting
the line) removes the debug commit. If the fix touches the same lines as the
debug prints, expect a conflict.

</details>

## Common mistakes

- **Reading the list bottom-up.** Oldest is at the top, unlike `git log`.
- **Putting `fixup` on the first line.** There is nothing above it to meld
  into; Git refuses.
- **Rewriting commits already on main or pushed to a shared branch.** Only
  clean up your own unshared work.
- **Losing work with `drop`.** Recoverable: `git reflog`, then
  `git reset --hard <pre-rebase hash>` (or use `ORIG_HEAD` right after).

## Remember

- `git rebase -i <base>`: oldest commit first; edit verbs, save, Git replays.
- `fixup` melds and drops the message; `squash` melds and keeps it.
- `commit --fixup` + `rebase --autosquash` automates cleanup.
- `rebase --onto new old branch` moves only a branch's own commits.

**Self-check:**

1. Which verb lets you split a commit?
2. Why is `git rebase -i main` safer than `git rebase -i HEAD~5`?
3. How do you undo a bad interactive rebase?
