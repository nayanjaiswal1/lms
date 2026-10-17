---
kind: lesson
id_key: git/merge-conflicts/resolving
course: git
section: merge-conflicts
section_title: "Merge Conflicts"
section_position: 6
title: "Resolving, Completing and Aborting a Merge"
position: 1
estimated_minutes: 9
source:
  - Pro Git book, ch. 3.2 "Basic Merge Conflicts" and ch. 7.8 "Advanced Merging"
  - git-merge(1), git-checkout(1), git-mergetool(1) manual pages
---

## Why this matters

Reading a conflict is half the job. Now answer it: decide the final text, tell
Git you are done, and finish the merge. Equally important: know how to back out
cleanly when the merge is not worth doing right now.

## Mental model: fill in the form, stamp it, file it

1. **Edit** - make the file look exactly how it should end up. Delete all
   markers.
2. **Stamp** - `git add <file>` marks that file resolved.
3. **File** - `git commit` creates the merge commit.

```
 resolve         git add app.conf      git commit
 (edit file) --> (conflict cleared) --> merge commit M (parents: main tip, feature tip)

   A---B---C---M  <- main
        \     /
         D---+   <- feature/timeout
```

Resolution is **your decision**, not picking a side by habit. Often the right
answer combines both (keep main's `timeout=60` *and* feature's `retries=3`).

## See it work

### Resolve by editing

```bash
nano app.conf          # make it: name=app / timeout=60 / log=info / retries=3
git add app.conf
git status
```

Expected status:

```
On branch main
All conflicts fixed but you are still merging.
  (use "git commit" to conclude merge)
```

```bash
git commit --no-edit      # keep the default "Merge branch 'feature/timeout'" message
git log --oneline --graph
```

Expected output:

```
*   6be1f20 (HEAD -> main) Merge branch 'feature/timeout'
|\
| * c2a9d41 (feature/timeout) Raise timeout to 45 and add retries
* | 14e8b07 Raise timeout to 60
|/
* a70d3e5 Initial config
```

Without `--no-edit`, Git opens the editor with that message pre-filled; save
and close.

### Before committing: no markers left

```bash
git diff --check                        # warns about leftover markers in unstaged changes
git grep -nE '^(<<<<<<<|=======|>>>>>>>)'   # search tracked files for markers
```

Both print nothing when you are clean. Markers are plain text: Git will happily
commit them if you stage a file without cleaning it.

```knowledge-check
{ "questions": [
  { "id": "git-conflict-resolve-q1", "type": "mcq",
    "prompt": "After editing a conflicted file you must:",
    "options": [
      {"id":"a","text":"git add it, then git commit to complete the merge"},
      {"id":"b","text":"Delete the .git directory"},
      {"id":"c","text":"git push immediately"},
      {"id":"d","text":"Run git clone"}],
    "correct": "a",
    "explanation": "git add marks the path resolved; git commit records the merge commit. Deleting .git destroys the repository, pushing before committing sends nothing new, and cloning is unrelated." },
  { "id": "git-conflict-resolve-q2", "type": "mcq",
    "prompt": "What is the safest way to check no markers were left in the repository?",
    "options": [
      {"id":"a","text":"git grep -nE '^(<<<<<<<|>>>>>>>)'"},
      {"id":"b","text":"git gc"},
      {"id":"c","text":"git remote -v"},
      {"id":"d","text":"git tag"}],
    "correct": "a",
    "explanation": "Markers are plain text, so Git will happily commit them if you stage a file without cleaning it. gc, remote and tag do not look at file contents." }
] }
```

### Take one whole side for a file

When you know one side is simply right for a file:

```bash
git checkout --ours   config/settings.yml    # keep my branch's version
git checkout --theirs package-lock.json      # take the incoming version
git add config/settings.yml package-lock.json
```

For a whole merge: `git merge -X ours feature` resolves **conflicting hunks**
in favour of your side (non-conflicting changes from feature still come in).

### Visual tools

`git mergetool` opens a configured 3-way tool (vimdiff, meld, VS Code, ...).
Set one with `git config --global merge.tool vscode` plus the tool's command.
Editors like VS Code also show "Accept Current / Incoming / Both" buttons right
above the markers.

### Abort: back out cleanly

```
 DURING conflict                     AFTER git merge --abort
 main + half-resolved files    -->   exactly the pre-merge state of main
```

```bash
git merge feature/log-level      # conflict
git merge --abort
git status
```

Expected output:

```
On branch main
nothing to commit, working tree clean
```

```knowledge-check
{ "questions": [
  { "id": "git-conflict-abort-q1", "type": "mcq",
    "prompt": "What does git merge --abort do?",
    "options": [
      {"id":"a","text":"Deletes the other branch"},
      {"id":"b","text":"Restores the repository to its state before the merge started"},
      {"id":"c","text":"Commits the conflict markers"},
      {"id":"d","text":"Pushes to origin"}],
    "correct": "b",
    "explanation": "It is only available while a merge is in progress; afterwards use reset or revert instead. It deletes no branch, commits nothing and never pushes." }
] }
```

Start every merge with a clean working tree. Then `--abort` can always restore
it exactly.

## Try it

You resolved `app.conf`, ran `git add app.conf`, but `git commit` says
`error: Committing is not possible because you have unmerged files.` What is
going on?

<details>
<summary>Show answer</summary>

Another file still has a conflict. Run `git status` and look under
"Unmerged paths". Resolve and `git add` that file too, then commit.

</details>

## Common mistakes

- **Picking "ours" for everything to make it go away.** You silently throw away
  a teammate's work. Read each block.
- **Forgetting to run the tests after resolving.** A merge can be textually
  clean and still broken (for example, one side renamed a function the other
  side calls).
- **Using `--abort` after committing.** Too late; the merge is done. Use
  `git reset --hard ORIG_HEAD` (local only) or `git revert -m 1` (shared).

## Remember

- Resolve = edit to the final text, `git add`, `git commit`.
- `git diff --check` / `git grep` for markers before committing.
- `git checkout --ours|--theirs <file>` takes one side for a whole file.
- `git merge --abort` returns to the pre-merge state while still merging.

**Self-check:**

1. What does `git add` mean during a conflict?
2. How do you take the incoming version of one file?
3. When does `git merge --abort` stop working?
