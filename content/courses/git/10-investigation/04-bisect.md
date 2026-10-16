---
kind: lesson
id_key: git/investigation/bisect
course: git
section: investigation
section_title: Investigating History
section_position: 10
title: "bisect: Binary Search for the Commit That Broke It"
position: 3
estimated_minutes: 8
source:
  - Pro Git book, ch. 7.10 "Binary Search"
  - git-bisect(1) manual page
---

## Why this matters

"It worked at v1.0, it is broken now, and there are 400 commits in between."
Reading them all would take days. `git bisect` finds the first bad commit in
about 9 tests, and if you have a script that detects the bug, Git runs it for
you.

## Mental model: guess the number

"I am thinking of a number between 1 and 1000." Ask "higher or lower?" and you
need about 10 guesses. Bisect plays that game with commits: test the middle
commit, throw away the half that cannot contain the culprit, repeat.

```
 v1.0 (good)                                              HEAD (bad)
  c5   c6   c7   c8   c9   c10  c11  c12  c13
  good  ?    ?    ?    ?    ?    ?    ?   bad
              test c9 -> bad    [c5 .. c9]
              test c7 -> bad    [c5 .. c7]
              test c6 -> good   first bad = c7  "Speed up tax calc"
```

Tests needed ~ log2(number of commits): 1000 commits -> about 10.

## See it work

### Manual bisect

```bash
git bisect start
git bisect bad              # current commit is broken
git bisect good v1.0        # this one worked
# Git checks out a middle commit. Test it, then say:
git bisect good             # or: git bisect bad
# ...repeat until Git prints "<hash> is the first bad commit"
git bisect reset            # go back to where you started
```

Use `git bisect skip` when a commit cannot be tested (it does not build). Use
`git bisect log` to see your answers so far.

### Automatic bisect with a script

```bash
git bisect start HEAD v1.0
git bisect run sh check.sh
```

What this does: Git checks out each middle commit and runs `sh check.sh`.
The **exit code** is the answer:

| Exit code | Meaning |
|---|---|
| `0` | good |
| `1`-`127` except `125` | bad |
| `125` | skip (cannot test this commit) |
| `128`+ | stop bisecting (something is badly wrong) |

Expected output (trimmed):

```
running 'sh' 'check.sh'
FAIL
7a3f9c1e... is the first bad commit
commit 7a3f9c1e...
Author: Dave Hotfix <dave@example.com>
    Speed up tax calc
bisect found first bad commit
```

Save the answer, then always reset:

```bash
git rev-parse refs/bisect/bad > ~/work/culprit.txt
git bisect reset
git show -s --format='%an <%ae>' "$(cat ~/work/culprit.txt)"
```

```knowledge-check
{ "questions": [
  { "id": "git-inv-bisect-q1", "type": "mcq",
    "prompt": "About how many test runs does git bisect need for 1000 commits?",
    "options": [
      {"id":"a","text":"About 10 (binary search)"},
      {"id":"b","text":"About 500"},
      {"id":"c","text":"1000"},
      {"id":"d","text":"It depends on the file sizes"}],
    "correct": "a",
    "explanation": "Each test halves the remaining range: log2(1000) is roughly 10. 500 or 1000 would be a linear search, and file sizes do not matter." },
  { "id": "git-inv-bisect-q2", "type": "mcq",
    "prompt": "What does a script given to git bisect run return for a good commit?",
    "options": [
      {"id":"a","text":"Exit status 0"},
      {"id":"b","text":"Exit status 1"},
      {"id":"c","text":"Any output"},
      {"id":"d","text":"The word good"}],
    "correct": "a",
    "explanation": "0 means good, 1 to 127 (except 125 = skip) means bad. Output text is ignored; only the exit status counts." }
] }
```

### Tips for good bisects

- Write the test **outside** the repo (or untracked) so it exists in every
  checked-out commit.
- Bisect a history of small commits: a giant "big refactor" commit is a huge
  haystack even after bisect finds it. Another reason to squash *thoughtfully*.
- With merge-heavy history, `git bisect start --first-parent` (Git 2.29+) tests
  only the main line, i.e. one step per merged pull request.
- Words other than good/bad: `git bisect start --term-old=fast --term-new=slow`
  for "when did it get slow?".

## Try it

Your test needs a build step, and some old commits do not compile at all. How
should your bisect script handle those commits?

<details>
<summary>Show answer</summary>

Exit with **125** when the build fails, so Git skips that commit instead of
calling it bad:

```bash
#!/bin/sh
make >/dev/null 2>&1 || exit 125
./run-test
```

</details>

## Common mistakes

- **Forgetting `git bisect reset`.** You stay on a detached HEAD in the middle of
  history and wonder where your branch went.
- **Answering by gut feeling.** One wrong good/bad sends the search to the wrong
  half. Use a script when you can.
- **A test that is itself in history.** If the test file did not exist in old
  commits, every old commit looks "bad". Keep the script outside the tree.

## Remember

- Bisect = binary search: about log2(N) tests.
- `start`, mark one `bad` and one `good`, answer, then `reset`.
- `git bisect run <cmd>`: exit 0 good, 1-127 bad, 125 skip.
- Small commits make the culprit easy to understand.

**Self-check:**

1. Which exit code tells bisect to skip a commit?
2. Why keep the test script outside the repository?
3. What command must you always run at the end?
