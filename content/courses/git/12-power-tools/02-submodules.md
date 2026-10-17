---
kind: lesson
id_key: git/power-tools/submodules
course: git
section: power-tools
section_title: "Power Tools: Worktrees, Submodules and Large Repos"
section_position: 12
title: "Submodules (and Subtrees): Repositories Inside Repositories"
position: 1
estimated_minutes: 9
source:
  - Pro Git book, ch. 7.11 "Submodules"
  - git-submodule(1), gitmodules(5) manual pages
---

## Why this matters

Your app uses a shared UI library that lives in its own repository and is
versioned separately. You want a **specific version** of it inside your
project. Submodules do that, and they confuse almost everyone the first time
("why is the folder empty?"). Know how they work, and when to avoid them.

## Mental model: a bookmark to an exact page of another book

A submodule does not copy the other repo's files into your history. Your repo
stores only:

1. `.gitmodules` - where to get the other repo (path -> URL).
2. A **gitlink** in your tree - the exact commit hash of the other repo to use
   (mode `160000`).

```
 app repo tree
 |-- src/...
 |-- .gitmodules          path = vendor/ui-lib, url = .../ui-lib.git
 '-- vendor/ui-lib  ->  gitlink 9357447   (a commit in ANOTHER repository)
```

Updating the library in your app = committing a new gitlink hash. Nothing moves
automatically.

## See it work

### Add a submodule

```bash
git submodule add https://example.com/ui-lib.git vendor/ui-lib
git status -s
git commit -m "Add ui-lib submodule"
```

Expected `git status -s` before the commit:

```
A  .gitmodules
A  vendor/ui-lib
```

`git ls-files -s vendor/ui-lib` shows the gitlink:

```
160000 9357447dd34cbf4e244315e5209746b122367380 0	vendor/ui-lib
```

**Local-path gotcha (Git 2.38.1+):** submodules from local paths or `file://`
URLs are blocked by default for security:

```
fatal: transport 'file' not allowed
```

For a trusted local repo, allow it for that one command:
`git -c protocol.file.allow=always submodule add /path/to/lib.git vendor/ui-lib`.

### Clone a project that has submodules

```bash
git clone --recurse-submodules <url>
# already cloned without it? the folder is empty, so:
git submodule update --init --recursive
```

### Update the library version

```bash
cd vendor/ui-lib
git fetch && git switch --detach v2.3.0     # pick the version you want
cd ../..
git add vendor/ui-lib                       # record the new gitlink
git commit -m "Bump ui-lib to v2.3.0"
```

Or `git submodule update --remote vendor/ui-lib` to move to the latest commit of
the branch configured in `.gitmodules`, then commit.

After teammates pull your bump they run `git submodule update` (or set
`git config --global submodule.recurse true` so pull/switch do it).

### Remove a submodule

```bash
git rm vendor/ui-lib          # removes gitlink, folder and .gitmodules entry
git commit -m "Remove ui-lib submodule"
```

### Alternatives

| Need | Consider |
|---|---|
| Vendored code you rarely update, want plain files in history | `git subtree` (copies the code into your repo) |
| Language libraries | The package manager (npm, pip, Go modules, Maven) |
| Many related projects, atomic changes across them | One monorepo |

## Try it

A new teammate cloned the app and `vendor/ui-lib` is an empty folder; the build
fails. What happened and what is the fix?

<details>
<summary>Show answer</summary>

A plain clone does not fetch submodule contents. Run:

```bash
git submodule update --init --recursive
```

Next time: `git clone --recurse-submodules`.

</details>

## Common mistakes

- **Committing inside the submodule and forgetting to commit the gitlink in the
  parent.** Teammates never get your library change.
- **Pushing the parent before the submodule's commit.** Others get a gitlink to
  a commit that does not exist on the server. Push the submodule first (or
  `git push --recurse-submodules=check`).
- **Being surprised by detached HEAD inside the submodule.** That is normal: the
  parent pins a commit, not a branch.

## Remember

- A submodule = `.gitmodules` URL + a gitlink commit hash (mode 160000).
- Clone with `--recurse-submodules` or run `git submodule update --init --recursive`.
- Bump a version: change the submodule's checkout, `git add` it in the parent, commit.
- Local/file URLs need `protocol.file.allow=always` on modern Git.

**Self-check:**

1. What does the parent repo actually store for a submodule?
2. Why is a freshly cloned submodule folder empty?
3. What must be pushed first: the submodule commit or the parent?
