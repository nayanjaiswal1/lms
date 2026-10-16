---
kind: lesson
id_key: git/workflows/tags-releases
course: git
section: workflows
section_title: "Team Workflows, Releases, Hooks and Signing"
section_position: 11
title: "Tags, Semantic Versioning and Releases"
position: 1
estimated_minutes: 8
source:
  - Pro Git book, ch. 2.6 "Tagging"
  - git-tag(1), git-describe(1) manual pages; semver.org
---

## Why this matters

"Which code is running in production?" "What changed since 2.3.0?" Tags answer
both. A tag gives a permanent name to the exact commit you released, so you can
rebuild it, compare against it, or branch a hotfix from it years later.

## Mental model: a branch that never moves

A branch label moves with every commit. A **tag** is a label glued to one
commit forever. Two kinds:

| | Lightweight | Annotated |
|---|---|---|
| Create | `git tag v1.2.0` | `git tag -a v1.2.0 -m "Release 1.2.0"` |
| Stored as | Just a ref | A tag **object** (tagger, date, message) + ref |
| Can be signed | No | Yes (`-s`) |
| Use for | Private bookmarks | **Releases** |

`git describe` and many tools ignore lightweight tags by default, another
reason to use annotated tags for releases.

## See it work

### Tag a release

```bash
git tag -a v1.1.0 -m "Release 1.1.0"        # tags HEAD
git tag -a v1.0.1 -m "Hotfix" 4f7a1d9       # tag an older commit
git tag -n1                                  # list with first message line
git show v1.1.0                              # tag info + the commit
```

Expected `git tag -n1`:

```
v1.0.1          Hotfix
v1.1.0          Release 1.1.0
```

### Tags are not pushed by default

```bash
git push origin v1.1.0          # one tag
git push --follow-tags          # pushes annotated tags reachable from pushed commits
git ls-remote --tags origin
```

Expected `ls-remote` output:

```
a14c7be...	refs/tags/v1.1.0
5be0a93...	refs/tags/v1.1.0^{}
```

The `^{}` line is the commit the annotated tag points to ("peeled").

```knowledge-check
{ "questions": [
  { "id": "git-cap-tag-q1", "type": "mcq",
    "prompt": "Does a plain git push publish tags?",
    "options": [
      {"id":"a","text":"No - push them explicitly (git push origin <tag> or --tags)"},
      {"id":"b","text":"Yes, always"},
      {"id":"c","text":"Only annotated tags"},
      {"id":"d","text":"Only on the main branch"}],
    "correct": "a",
    "explanation": "Tags are references of their own and must be pushed on request (or with --follow-tags / push.followTags). Plain push sends no tags of either kind, on any branch." }
] }
```

Set `git config --global push.followTags true` to push annotated tags with
their commits automatically.

### Semantic versioning

`MAJOR.MINOR.PATCH`, e.g. `v2.4.1`:

- **MAJOR** - breaking change for users (2.x -> 3.0.0)
- **MINOR** - new feature, backwards compatible (2.4 -> 2.5.0)
- **PATCH** - bug fix only (2.4.0 -> 2.4.1)
- Pre-releases: `v3.0.0-rc.1`

### Find your place relative to tags

```bash
git describe
```

Expected output a few commits after `v1.0`:

```
v1.0-3-g9d4b0c2
```

Read it as: nearest annotated tag `v1.0`, 3 commits later, at commit `9d4b0c2`
(`g` = git). Builds often embed this as their version string.

```bash
git log --oneline v1.0..v1.1.0      # what went into 1.1.0 (release notes)
git switch -c hotfix/1.0.1 v1.0     # branch a fix from an old release
```

### Delete or move a tag

```bash
git tag -d v1.1.0                    # local
git push origin --delete v1.1.0      # remote
```

Never move a published release tag; people and caches already trust it. Make a
new version instead (`v1.1.1`).

### Hosting "releases"

GitHub/GitLab Releases are a page attached to a tag: notes plus downloadable
build artifacts. The tag is the Git part; the rest is the host.

## Try it

You released `v2.0.0`, then found a typo in the tag message. It is already
pushed and users downloaded it. What do you do?

<details>
<summary>Show answer</summary>

Leave the tag alone. Moving a published tag breaks trust and caches, and other
clones will not update their copy automatically. A message typo is not worth
it; if the code was wrong, release `v2.0.1`.

</details>

## Common mistakes

- **Lightweight tags for releases.** No author, date or message, and ignored by
  `describe`.
- **Forgetting to push tags.** CI that builds on tags never triggers.
- **Re-tagging a release.** Users who fetched the old tag keep it.

## Remember

- Annotated tag (`-a`) for releases; lightweight for private bookmarks.
- Push tags explicitly (`git push origin v1.2.0`) or set `push.followTags`.
- SemVer: MAJOR breaking, MINOR features, PATCH fixes.
- `git describe` = nearest tag + distance; never move published tags.

**Self-check:**

1. What does an annotated tag store that a lightweight one does not?
2. What does `v1.0-3-g9d4b0c2` mean?
3. Which version part changes for a breaking API change?
