---
kind: lesson
id_key: git/investigation/searching
course: git
section: investigation
section_title: Investigating History
section_position: 10
title: "Searching History: log -S, -G, -L and --follow"
position: 2
estimated_minutes: 8
source:
  - Pro Git book, ch. 7.5 "Searching"
  - git-log(1) manual page (-S, -G, -L, --follow), git-grep(1)
---

## Why this matters

Blame works for code that still exists. But what about a constant that was
**deleted**, a value that changed months ago, or a file that was renamed?
Git can search inside every diff ever made. These "pickaxe" searches answer
"when did this string appear or disappear?".

## Mental model: two different metal detectors

- `-S 'text'` beeps when the **number of occurrences** of the text changes in a
  commit, i.e. it was added or removed.
- `-G 'regex'` beeps when any **added or removed line** matches, which also
  catches edits where the text stays but the line changes.

```
 -S 'text'   commits where the COUNT of 'text' changed (added / removed)
 -G 'regex'  commits whose diff has a +/- line matching regex (also catches edits)
 --follow f  history of one file across renames

 config.sh:   Misc changes  (+timeout=30 +LEGACY_FLAG=1)
              Bump timeout  (-timeout=30 +timeout=45)   found by -G, NOT by -S 'timeout='
              Tidy up       (-LEGACY_FLAG=1)             found by -S LEGACY_FLAG
```

## See it work

### When was it added, when removed?

```bash
git log -S LEGACY_FLAG --oneline
```

Expected output:

```
9e1b3d0 Tidy up
c3a77f4 Misc changes
```

Newest first: removed in "Tidy up", added in "Misc changes". Add `-p` to see
the diffs.

### When did the value change?

```bash
git log -G 'timeout=' --oneline
```

Expected output:

```
5f0e2c8 Bump timeout
c3a77f4 Misc changes
```

`-S 'timeout='` would show only "Misc changes": in "Bump timeout" one
`timeout=` line was removed and one added, so the count did not change.

```knowledge-check
{ "questions": [
  { "id": "git-inv-search-q1", "type": "mcq",
    "prompt": "A value changed from timeout=30 to timeout=45. Which search finds that commit?",
    "options": [
      {"id":"a","text":"git log -S 'timeout='"},
      {"id":"b","text":"git log -G 'timeout='"},
      {"id":"c","text":"git log --follow"},
      {"id":"d","text":"git blame -C"}],
    "correct": "b",
    "explanation": "-S only fires when the number of occurrences changes; -G matches any changed line. --follow tracks renames, and blame -C follows moved code but does not search history for a value change." }
] }
```

### Across renames: --follow

```bash
git log --follow --oneline -- pricing.sh
```

Expected output (last line = creation under the old name `price.sh`):

```
a71e3c9 Rename price helper
4c0d8b2 Add price helper
```

Git does not store renames; it detects them by content similarity. `--follow`
works for a single file only.

### The history of a function or line range: -L

```bash
git log -L :tax:tax.sh          # every change to function "tax" in tax.sh
git log -L 1,3:config.sh        # every change to lines 1-3
```

Each entry shows the commit and just the diff for that range. Often faster than
repeated blame.

### Search the current code (or any version)

```bash
git grep -n "LEGACY_FLAG"            # tracked files in the working tree
git grep -n "LEGACY_FLAG" v1.0       # files as they were at v1.0
```

`git grep` is fast and respects `.gitignore` (skips `node_modules`, builds).

## Try it

An API key string `sk_live_` was committed and later deleted. You need every
commit that ever added or removed it, with the diffs.

<details>
<summary>Show answer</summary>

```bash
git log -S 'sk_live_' -p --all
```

`--all` includes every branch. Then rotate the key (Section 13): deleting it
from the latest commit never removed it from history.

</details>

## Common mistakes

- **Using `-S` for value changes.** Use `-G` when the line changes but the
  text count does not.
- **Forgetting `--all`.** The commit may be on another branch.
- **`--follow` with several paths or a directory.** It only works on one file.

## Remember

- `-S text` = added or removed; `-G regex` = any changed line matching.
- `--follow -- file` walks history past renames.
- `git log -L` tracks a function or line range over time.
- `git grep` searches files now or at any revision.

**Self-check:**

1. Why can `-S` miss an edit?
2. What is the limitation of `--follow`?
3. How do you see every change to one function?
