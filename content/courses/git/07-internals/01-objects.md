---
kind: lesson
id_key: git/internals/objects
course: git
section: internals
section_title: "Under the Hood: Objects, Refs and the Index"
section_position: 7
title: "The Object Database: Blobs, Trees, Commits and Tags"
position: 0
estimated_minutes: 9
source:
  - Pro Git book, ch. 10.2 "Git Objects"
  - git-cat-file(1), git-hash-object(1) manual pages
---

## Why this matters

So far you have used Git through its friendly commands. Under them sits a tiny,
elegant database with only four kinds of object. Once you can see it, rebase,
reset, cherry-pick and the reflog all become obvious: they just create objects
and move labels. It is also a classic interview topic.

## Mental model: a warehouse of labelled boxes

Git's `.git/objects` folder is a warehouse. Every box is sealed and labelled
with a fingerprint (hash) **computed from its contents**. Same contents = same
label, so nothing is ever stored twice. Boxes are never opened and changed;
you only add new ones.

> **One-sentence definition:** Git is a **content-addressable** store: you give
> it data, it gives you back a hash, and that hash is the data's permanent name.

The four object types:

| Object | Holds | Analogy |
|---|---|---|
| **blob** | The bytes of one file (no name!) | A page |
| **tree** | A list of names -> blobs and subtrees, with modes | A folder listing |
| **commit** | One root tree + parent(s) + author, committer, message | A dated cover letter |
| **tag** (annotated) | A pointer to an object + tagger + message | A signed label |

```
 commit e5fda59 ----> tree 5889598 (root)
  "Add README and app"   |-- README.md -> blob fec5601   "# Hello"
                         '-- src/      -> tree 13803ae
                                           '-- app.sh -> blob 8b2fe54  "echo hi"
```

## See it work

### Ask Git to hash some content

```bash
echo "# Hello" | git hash-object --stdin
```

What this does: computes the blob hash for that content without storing it.
Expected output, identical on every machine in the world:

```
fec56017dc1b1ac87ad6e54e3cb3a20bb8dcc5ab
```

Add `-w` to also write the blob into the database.

### Walk from a commit down to a file

```bash
git cat-file -t HEAD          # type of the object
git cat-file -p HEAD          # pretty-print it
```

Expected output:

```
commit
tree 58895983f0bc0369f144effc936e853a95f9083b
author Ada Student <ada@example.com> 1704103200 +0000
committer Ada Student <ada@example.com> 1704103200 +0000

Add README and app
```

That is the whole commit: a tree, author and committer (name, email, Unix
time, timezone), and the message. A non-root commit also has `parent <hash>`
lines (two for a merge).

```bash
git cat-file -p 'HEAD^{tree}'
```

```
100644 blob fec56017dc1b1ac87ad6e54e3cb3a20bb8dcc5ab	README.md
040000 tree 13803ae2f49ec21cb219869c5558aef862f47410	src
```

The tree stores the **file names** and modes (`100644` normal file, `100755`
executable, `040000` directory, `120000` symlink, `160000` submodule). The blob
stores only content. That is why renaming a file creates a new tree but reuses
the same blob.

### Annotated tags are objects too

```bash
git tag -a v1 -m "Release 1"
git cat-file -p v1
```

```
object e5fda59241d1283c91fa2b05a24226a7ab85f105
type commit
tag v1
tagger Ada Student <ada@example.com> 1792164929 +0000

Release 1
```

A **lightweight** tag (`git tag v1` without `-a`) creates no object; it is just
a label, like a branch that never moves.

### About the hash

Git hashes `"<type> <size>\0<content>"` with SHA-1 by default (a hardened
variant that detects known collision attacks). Repositories can also use
SHA-256 (`git init --object-format=sha256`), which the Git project plans to make
the default in the future. You can type any unique prefix, usually 7+
characters.

## Try it

Two files in different folders, `docs/LICENSE` and `vendor/LICENSE`, have
identical content. How many blobs does Git store for them?

<details>
<summary>Show answer</summary>

One. The blob hash depends only on content, so both tree entries point to the
same blob. Names live in the trees.

</details>

## Common mistakes

- **Thinking commits store diffs.** A commit points to a full tree. Diffs are
  computed by comparing two trees.
- **Thinking a blob knows its filename.** It does not; trees hold names.
- **Thinking objects can be edited.** Any change makes a new object with a new
  hash. "Rewriting history" means creating new objects and moving labels.

## Remember

- Four objects: blob (content), tree (names), commit (snapshot + parents + meta), tag.
- Hash = name derived from content; identical content is stored once.
- `git cat-file -t` (type) and `-p` (print) let you walk the graph.
- Objects are immutable; history changes are new objects plus moved labels.

**Self-check:**

1. Which object stores file names?
2. What does a commit object contain?
3. Why does renaming a file not duplicate its content?
