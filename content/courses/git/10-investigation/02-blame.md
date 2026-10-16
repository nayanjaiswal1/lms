---
kind: lesson
id_key: git/investigation/blame
course: git
section: investigation
section_title: Investigating History
section_position: 10
title: "blame: Who Last Changed This Line, Really?"
position: 1
estimated_minutes: 8
source:
  - Pro Git book, ch. 7.10 "Debugging with Git - File Annotation"
  - git-blame(1) manual page
---

## Why this matters

You find a strange line: `rate=15`. Before changing it you want the commit that
introduced it and the reason in its message. `git blame` finds that commit in
seconds. But reformatting and moved code fool it, so you also need the flags
that see through refactors.

(Despite the name, blame is about context, not fault. Many tools call it
"annotate".)

## Mental model: a sticky note on every line

Blame puts a sticky note on each line: "last changed by commit X, author Y, on
date Z". It shows only the **last** change. To go further back you then run
`git log` or blame the parent commit.

```
 commit history of tax.sh                 git blame -L1,1 tax.sh
 c1 Alice: rate=10                        ^
 c7 Dave : rate=15   <- last change  --->  7a3f9c1 (Dave Hotfix 2024-06-07 1) rate=15
```

## See it work

### Basic blame on a line range

```bash
cd ~/work/inventory
git blame -L1,1 tax.sh
```

What this does: annotates only line 1. Expected output (hash differs):

```
7a3f9c1 (Dave Hotfix 2024-06-07 10:00:00 +0000 1) rate=15
```

Then read the why: `git show 7a3f9c1`.

`-L` also accepts a function: `git blame -L :tax tax.sh` (by funcname regex).

```knowledge-check
{ "questions": [
  { "id": "git-inv-blame-q1", "type": "mcq",
    "prompt": "What does git blame show for a line?",
    "options": [
      {"id":"a","text":"The commit and author that most recently changed that line"},
      {"id":"b","text":"The person who reviewed it"},
      {"id":"c","text":"Every commit that ever touched the file"},
      {"id":"d","text":"The branch it lives on"}],
    "correct": "a",
    "explanation": "Blame is about the last change to each line, which is the starting point for digging deeper with git log. Git does not know reviewers, does not list every commit, and does not track branches per line." }
] }
```

### Seeing through refactors

Reformatting and moving code make plain blame name the wrong person.

```
 c4 Carol writes  "  echo $(( $1 * 10 / 100 ))"
 c9 Eve re-indents "\techo ..."           plain blame -> Eve      blame -w -> Carol

 c6 Gina writes shipping.sh
 c10 Frank moves the lines to util.sh    plain blame -> Frank    blame -C -> Gina
```

```bash
git blame -L2,2 discount.sh        # Eve
git blame -w -L2,2 discount.sh     # Carol
git blame util.sh | sed -n 4p      # Frank
git blame -C util.sh | sed -n 4p   # Gina (run it on the whole file, not with -L)
```

Expected output of the first two:

```
d41e0b7 (Eve Formatter 2024-06-09 10:00:00 +0000 2) 	echo $(( $1 * 10 / 100 ))
b09c7a2 (Carol Pricing 2024-06-04 10:00:00 +0000 2) 	echo $(( $1 * 10 / 100 ))
```

| Flag | Ignores / follows |
|---|---|
| `-w` | Whitespace-only changes |
| `-M` | Lines moved **within** the file |
| `-C` | Lines moved/copied from other files changed in the same commit |
| `-C -C` / `-C -C -C` | Also the commit that created the file / any commit (slower) |

```knowledge-check
{ "questions": [
  { "id": "git-inv-blamewc-q1", "type": "mcq",
    "prompt": "A formatter re-indented a file and now blame names the formatter. Which flag finds the real author?",
    "options": [
      {"id":"a","text":"-w to ignore whitespace changes"},
      {"id":"b","text":"-q"},
      {"id":"c","text":"--first-parent"},
      {"id":"d","text":"-v"}],
    "correct": "a",
    "explanation": "-w ignores whitespace when attributing lines. The other flags do not change how whitespace edits are attributed." },
  { "id": "git-inv-blamewc-q2", "type": "mcq",
    "prompt": "Code was moved from one file to another in a single commit. Which flag lets blame follow it?",
    "options": [
      {"id":"a","text":"-C"},
      {"id":"b","text":"-w"},
      {"id":"c","text":"-L"},
      {"id":"d","text":"-s"}],
    "correct": "a",
    "explanation": "-C detects lines moved or copied between files; repeat it for deeper searches. -w handles whitespace, -L limits lines, and -s hides author names." }
] }
```

### Ignore known bulk-formatting commits for everyone

List the hashes of "reformat the whole codebase" commits in a file and tell
blame to skip them:

```bash
echo d41e0b7... >> .git-blame-ignore-revs
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

GitHub and GitLab read `.git-blame-ignore-revs` automatically in their blame
views.

## Try it

`git blame` says line 40 of `api.py` was last changed by commit `abc123`
"Rename variables". You want the commit before that which wrote the logic. What
do you run?

<details>
<summary>Show answer</summary>

Blame the parent of that commit:

```bash
git blame -L40,40 abc123^ -- api.py
```

(The line number may shift slightly in older versions; adjust or use `-L :func`.)
Or follow the line's whole history with `git log -L40,40:api.py`.

</details>

## Common mistakes

- **Stopping at the first answer.** The last change is often a rename or
  reformat. Use `-w`, `-C`, or blame the parent.
- **Using blame to point fingers.** Use it to find the commit message and the
  pull request that explain *why*.
- **`-C` with `-L` on a narrow range.** Detection can miss moves; blame the
  whole file and pick the line.

## Remember

- `git blame -L a,b file` = last commit per line in a range.
- `-w` sees through re-indents; `-C` follows code moved between files.
- `.git-blame-ignore-revs` hides formatting commits for the whole team.
- After blame, `git show <hash>` to read the reason.

**Self-check:**

1. What does blame show: the first or the last change to a line?
2. Which flag handles a reformat, and which handles moved code?
3. How do you look further back than the last change?
