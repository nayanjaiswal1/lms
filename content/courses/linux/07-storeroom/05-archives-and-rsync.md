---
kind: lesson
id_key: linux/storeroom/archives-and-rsync
course: linux
section: storeroom
section_title: "Chapter 7: The Storeroom - Packages, Disks and Backups"
section_position: 7
title: "Archives and Backups: tar, gzip and rsync"
position: 4
estimated_minutes: 8
source:
  - tar(1), gzip(1), xz(1), zstd(1), zip(1), rsync(1) manual pages
---

## Why this matters

Backups, deliveries from suppliers, release bundles and log archives are all
`.tar.gz` files. You need to create them with clean paths, look inside before
unpacking a stranger's archive, and copy large directories efficiently.

## Mental model: box, then shrink-wrap

- **tar** (tape archive) packs many files and directories into **one** file,
  keeping paths, permissions and timestamps. It does not compress.
- **gzip / xz / zstd** shrink one file.
- `.tar.gz` (or `.tgz`) = a tar box, shrink-wrapped with gzip.

> **Memory hook:** tar flags read like a sentence: **c**reate **z**ipped
> **f**ile, e**x**tract **z**ipped **f**ile, **t**ell me what is in the
> **z**ipped **f**ile.

## See it work

```bash
cd ~/work
tar -czf backups/storeroom.tar.gz storeroom    # create, gzip, file name
tar -tzf backups/storeroom.tar.gz | head -3    # list without extracting
```

What this does: `c` create, `z` gzip, `f` the archive's file name (must come
right before it). Expected output of the listing:

```
storeroom/
storeroom/beans/
storeroom/beans/arabica.bin
```

Paths are relative (`storeroom/...`) because you ran tar from `~/work`. Archive
from the parent directory, or use `-C`:

```bash
tar -czf /tmp/sr.tar.gz -C /home/labuser/work storeroom   # -C: change dir first
```

### Extracting

```bash
tar -tzf delivery.tar.gz              # ALWAYS look first
mkdir -p unpacked
tar -xzf delivery.tar.gz -C unpacked  # extract into a directory
```

```
delivery/
delivery/manifest.txt
delivery/invoice.txt
```

Listing first protects you from archives that spill hundreds of files into the
current directory, or contain absolute or `../` paths. GNU tar strips a leading
`/` by default, but still: look first.

### Compression choices

| Flag | Tool | Extension | Notes |
|---|---|---|---|
| `-z` | gzip | `.tar.gz` | everywhere, fast |
| `-J` | xz | `.tar.xz` | smaller, slower |
| `--zstd` | zstd | `.tar.zst` | modern: fast and small |
| `-a` | from the extension | any | `tar -caf x.tar.xz dir` |

```bash
gzip big.log          # -> big.log.gz (replaces the original)
gunzip big.log.gz
zcat big.log.gz | grep ERROR   # read without unpacking (also zgrep, zless)
zip -r site.zip site/ && unzip -l site.zip
```

### rsync: copy only what changed

```bash
rsync -av src/ /backup/src/              # archive mode, verbose
rsync -av --delete src/ /backup/src/     # also delete files removed from src
rsync -av --dry-run src/ dst/            # show what would happen
rsync -avz src/ deploy@atlas:/backup/src/   # over SSH, compressed
```

`-a` keeps permissions, times, links (like `cp -a`). The second run only sends
differences, so it is fast. The **trailing slash matters**: `src/` means "the
contents of src", `src` means "the directory src itself" (you get `dst/src/`).

### A backup is not a backup until you have restored it

The 3-2-1 rule: **3** copies, on **2** kinds of storage, **1** off-site. And test
restores regularly; an archive that has never been extracted is a hope, not a
backup.

## Try it

Extract `~/work/delivery.tar.gz` into `~/work/unpacked`, so that
`unpacked/delivery/manifest.txt` exists. What do you run first?

<details>
<summary>Show answer</summary>

```bash
tar -tzf ~/work/delivery.tar.gz          # look first
mkdir -p ~/work/unpacked
tar -xzf ~/work/delivery.tar.gz -C ~/work/unpacked
```

</details>

## Common mistakes

- **`tar -czf dir backup.tar.gz`.** `f` takes the next word as the archive name,
  so this tries to create an archive called `dir`. Archive name first.
- **Absolute paths in archives.** `tar -czf b.tgz /home/labuser/work/storeroom`
  stores `home/labuser/...`. Use `-C` for short paths.
- **`rsync --delete` with the slashes wrong.** It can delete the wrong tree. Run
  `--dry-run` first.
- **Never testing restores.**

## Remember

- `tar -czf OUT.tar.gz DIR`, `tar -tzf` to list, `tar -xzf ... -C DIR` to extract.
- `-z` gzip, `-J` xz, `--zstd`; `zcat`/`zgrep` read compressed logs.
- `rsync -av [--delete] src/ dst/`; trailing slash = contents.
- 3-2-1, and test restores.

**Self-check:**

1. What does `t` do in `tar -tzf`?
2. What does `-C` do?
3. What is the difference between `rsync src/ dst` and `rsync src dst`?
