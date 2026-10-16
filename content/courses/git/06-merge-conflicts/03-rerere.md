---
kind: lesson
id_key: git/merge-conflicts/rerere
course: git
section: merge-conflicts
section_title: Merge Conflicts
section_position: 6
title: "rerere: Let Git Remember Your Resolutions"
position: 2
estimated_minutes: 6
source:
  - Pro Git book, ch. 7.9 "Rerere"
  - git-rerere(1) manual page
---

## Why this matters

On a long-lived branch you can hit the **same** conflict again and again: every
time you re-merge, rebase onto a new main, or retry an aborted merge. Resolving
it by hand each time is boring and error-prone. `rerere` ("reuse recorded
resolution") records your answer once and replays it automatically.

## Mental model: a sticky note on the question

The first time a conflict appears, Git photographs the conflicted text (the
**preimage**). When you resolve it, Git photographs your answer (the
**postimage**). Next time the identical conflict appears, Git finds the photo
and applies the same answer.

```
 conflict #1:  preimage ---you resolve---> postimage      saved in .git/rr-cache/<hash>/
 conflict #2 (same hunk) -> "Resolved 'logging.conf' using previous resolution."
```

It matches on the conflicting text, not on branch names, so it works across
merge, rebase, cherry-pick and revert.

## See it work

### Turn it on

```bash
git config rerere.enabled true          # this repo; use --global for all repos
```

Enable it **before** the merge, or the first conflict is not recorded.

### Record a resolution

```bash
git merge feature/log-level      # conflict in logging.conf
```

Expected output now includes a new line:

```
Auto-merging logging.conf
CONFLICT (content): Merge conflict in logging.conf
Recorded preimage for 'logging.conf'
Automatic merge failed; fix conflicts and then commit the result.
```

Resolve and commit as usual:

```bash
printf 'level=warn\n' > logging.conf
git add logging.conf
git commit --no-edit
ls .git/rr-cache/*/
```

Expected output:

```
Recorded resolution for 'logging.conf'.
[main 4d2f9b1] Merge branch 'feature/log-level'
postimage  preimage
```

### Replay

If the same conflict comes back (say you undo the merge and do it again later),
Git prints:

```
Resolved 'logging.conf' using previous resolution.
```

The file already contains your answer. rerere does **not** stage it for you by
default: check it, then `git add` and continue. (`rerere.autoUpdate true` stages
automatically.)

### Manage it

```bash
git rerere status       # files whose resolution rerere is tracking right now
git rerere diff         # what rerere would apply
git rerere forget logging.conf   # drop a wrong recorded resolution
```

```knowledge-check
{ "questions": [
  { "id": "git-conflict-rerere-q1", "type": "mcq",
    "prompt": "When is rerere most useful?",
    "options": [
      {"id":"a","text":"When you repeat the same merge or rebase many times, such as a long-lived branch rebased daily"},
      {"id":"b","text":"For encrypting commits"},
      {"id":"c","text":"For speeding up git clone"},
      {"id":"d","text":"For deleting old branches"}],
    "correct": "a",
    "explanation": "Each repeat of an identical conflict is resolved automatically from the recorded postimage. rerere has nothing to do with encryption, clone speed or branch cleanup." }
] }
```

## Try it

You enabled rerere, resolved a conflict badly, committed, and then undid the
merge. Next time you merge, Git re-applies your bad resolution. How do you stop
that?

<details>
<summary>Show answer</summary>

While the conflict is in progress, run:

```bash
git rerere forget <file>
```

Git drops the recorded resolution, puts the conflict markers back, and you can
resolve it correctly (which records the new answer).

</details>

## Common mistakes

- **Enabling it after the conflict.** The preimage is recorded only when the
  conflict first appears with rerere on.
- **Trusting replays blindly.** A replayed resolution can be wrong in a new
  context. Always review and run tests.
- **Expecting it to be shared.** `.git/rr-cache` is local; teammates do not get
  your recorded resolutions.

## Remember

- `git config rerere.enabled true` (or `--global`).
- First conflict: preimage recorded; your fix: postimage recorded.
- Same conflict later: "Resolved ... using previous resolution."
- `git rerere forget <file>` drops a bad recording.

**Self-check:**

1. What do preimage and postimage contain?
2. Does rerere stage the replayed file for you by default?
3. Where are recordings stored?
