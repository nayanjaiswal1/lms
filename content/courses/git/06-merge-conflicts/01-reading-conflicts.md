---
kind: lesson
id_key: git/merge-conflicts/reading
course: git
section: merge-conflicts
section_title: "Merge Conflicts"
section_position: 6
title: "Why Conflicts Happen and How to Read Them"
position: 0
estimated_minutes: 8
source:
  - Pro Git book, ch. 3.2 "Basic Merge Conflicts" and ch. 7.8 "Advanced Merging"
  - git-merge(1) manual page, "HOW CONFLICTS ARE PRESENTED"
---

## Why this matters

Git stops and prints `CONFLICT`. Most beginners panic here. A conflict is not an
error and nothing is broken: it is Git asking a question it cannot answer
alone. Once you can read the markers, answering takes a minute.

## Mental model: two editors, one sentence

Git merges by comparing each side with their **common ancestor** (the merge
base):

- Only one side changed a line? Take that change. No question.
- Both sides changed the **same lines** differently? Git cannot know which one
  you want, so it asks.

```
 ancestor:  timeout=30
 main    :  timeout=60        both changed the same line
 feature :  timeout=45        ->  CONFLICT
```

Like two editors rewriting the same sentence of a book: the publisher has to
pick, or write a third version.

```knowledge-check
{ "questions": [
  { "id": "git-conflict-why-q1", "type": "mcq",
    "prompt": "When does Git report a merge conflict?",
    "options": [
      {"id":"a","text":"Whenever two branches exist"},
      {"id":"b","text":"When both branches changed the same lines in different ways since the common ancestor"},
      {"id":"c","text":"When a branch is older than a week"},
      {"id":"d","text":"When a file is larger than 1 MB"}],
    "correct": "b",
    "explanation": "If only one side changed a region, Git takes that change automatically. Branch count, age and file size do not cause conflicts." }
] }
```

## See it work

### Trigger and inspect

```bash
git switch main
git merge feature/timeout
```

Expected output:

```
Auto-merging app.conf
CONFLICT (content): Merge conflict in app.conf
Automatic merge failed; fix conflicts and then commit the result.
```

```bash
git status
```

```
On branch main
You have unmerged paths.
  (fix conflicts and run "git commit")
  (use "git merge --abort" to abort the merge)

Unmerged paths:
  (use "git add <file>..." to mark resolution)
	both modified:   app.conf
```

Status tells you you are **in the middle of a merge** and lists the files to fix.

### Read the markers

```bash
cat app.conf
```

```
name=app
<<<<<<< HEAD
timeout=60
=======
timeout=45
>>>>>>> feature/timeout
log=info
retries=3
```

| Marker | Meaning |
|---|---|
| `<<<<<<< HEAD` | Start of **your** side (the branch you are on, "ours") |
| `=======` | Divider |
| `>>>>>>> feature/timeout` | End of **their** side (the branch being merged, "theirs") |

Notice `retries=3` sits outside the markers. Only the feature branch added it,
so Git took it automatically. Only the truly contested lines are marked.

```
 DURING the merge
   A---B---C  <- main <- HEAD         .git/MERGE_HEAD -> feature/timeout tip
        \
         D  <- feature/timeout
   index holds 3 versions of app.conf (ancestor / ours / theirs) = "unmerged"
```

```knowledge-check
{ "questions": [
  { "id": "git-conflict-markers-q1", "type": "mcq",
    "prompt": "In a conflict block, what sits between <<<<<<< HEAD and =======?",
    "options": [
      {"id":"a","text":"The incoming branch's version"},
      {"id":"b","text":"The version from the branch you are currently on"},
      {"id":"c","text":"The common ancestor"},
      {"id":"d","text":"A summary written by Git"}],
    "correct": "b",
    "explanation": "HEAD is your current branch (ours); below ======= is theirs. The ancestor is only shown with the diff3/zdiff3 style, and Git writes no summary." }
] }
```

### See the ancestor too (recommended setting)

```bash
git config --global merge.conflictStyle zdiff3
```

Now conflicts also show the original text between `|||||||` and `=======`:

```
<<<<<<< HEAD
timeout=60
||||||| 8c1f7b3
timeout=30
=======
timeout=45
>>>>>>> feature/timeout
```

Knowing it **was** 30 tells you both sides raised it, which helps you decide.
`zdiff3` needs Git 2.35+; older versions have `diff3`.

## Try it

A conflict block shows `<<<<<<< HEAD`, then `color=blue`, then `=======`, then
`color=green`, then `>>>>>>> redesign`. You are on `main`. Which branch wanted
green?

<details>
<summary>Show answer</summary>

`redesign`. The bottom half (after `=======`) is the branch named after
`>>>>>>>`, the one you are merging in. `main` (HEAD) wanted blue.

</details>

## Common mistakes

- **Thinking the whole file conflicted.** Only marked blocks need you; the rest
  merged automatically.
- **Mixing up ours and theirs.** In a merge, ours = HEAD = the branch you are
  on. (During a rebase it flips; Section 8.)
- **Committing with markers still in the file.** Git does not stop you if you
  `git add` a file with markers. Search for them first.

## Remember

- Conflict = both sides changed the same lines since the merge base.
- `git status` lists "both modified" files and says you are mid-merge.
- Above `=======` = ours (HEAD). Below = theirs (the merged branch).
- Set `merge.conflictStyle zdiff3` to also see the ancestor.

**Self-check:**

1. Which three versions does Git compare during a merge?
2. What does "both modified" mean in status?
3. What extra information does `zdiff3` show?
