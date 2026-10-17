---
kind: lesson
id_key: linux/moving-in/sizes-and-types
course: linux
section: moving-in
section_title: "Chapter 2: Moving In - Working with Files"
section_position: 2
title: "How Big Is It, and What Is It? du, ls -S and file"
position: 4
estimated_minutes: 6
source:
  - du(1), ls(1), file(1), stat(1) manual pages
---

## Why this matters

"The disk is almost full" is one of the most common pages a sysadmin gets. You
must find the heavy files in seconds. And because Linux ignores extensions, you
also need a way to ask what a file really contains.

## Mental model: weigh the boxes, then open one

- `du` (**d**isk **u**sage) weighs boxes: how much space a file or directory
  tree uses.
- `ls -lS` lines files up by size inside one directory.
- `file` opens the box and looks inside: what kind of data is this?

Chapter 7 adds `df` (**d**isk **f**ree), which weighs whole disks. Start with
`df` to find the full disk, drill down with `du`.

## See it work

```bash
du -sh ~/work/moving
```

What this does: `-s` gives one summary total, `-h` prints human units. Expected
output:

```
2.1M	/home/labuser/work/moving
```

Rank everything inside, biggest last:

```bash
du -ah ~/work/moving | sort -h | tail -5
```

What this does: `-a` lists files too, not just directories; `sort -h`
understands human sizes like `4.0K` and `2.0M`; `tail -5` keeps the five biggest
(the last lines). Expected output (similar):

```
16K	/home/labuser/work/moving/box/recipes
40K	/home/labuser/work/moving/box
2.0M	/home/labuser/work/moving/garage/beans-inventory.csv
2.1M	/home/labuser/work/moving
2.1M	/home/labuser/work/moving/garage
```

The biggest *file* is the first line that is not a directory total:
`beans-inventory.csv`. You will meet the pipe `|` properly in chapter 3; for now
read it as "and then".

```bash
ls -lhS ~/work/moving/garage      # this directory, sorted by size, biggest first
find ~/work/moving -type f -size +1M   # just the big files
```

### Sizes on disk vs apparent size

`ls -l` shows the **apparent size** (bytes in the file). `du` shows **space
used on disk** (whole blocks, usually 4 KiB each). A 10-byte file shows `10` in
`ls -l` but `4.0K` in `du`. For "what fills my disk", trust `du`.

### What kind of file is it?

```bash
file ~/work/moving/garage/beans-inventory.csv
file /usr/bin/ls
file ~/.bashrc
```

```
.../beans-inventory.csv: data
/usr/bin/ls: ELF 64-bit LSB pie executable, x86-64, ...
/home/labuser/.bashrc: ASCII text
```

The `.csv` file is not text at all: `file` looks at the content and finds raw
binary data. Linux does not care about extensions; they are just part of the
name. (`file` may not be installed on minimal images; `head -c 64 FILE | od -c`
is a fallback.)

## Try it

Write a pipeline that shows the 3 largest items under `/var/log` with human
sizes, hiding "Permission denied" errors.

<details>
<summary>Show answer</summary>

```bash
du -ah /var/log 2>/dev/null | sort -h | tail -3
```

`2>/dev/null` throws away error messages (chapter 3 explains why that works).

</details>

## Common mistakes

- **Using `sort -n` on human sizes.** `-n` thinks `900K` is bigger than `2.0M`.
  Use `sort -h` with `-h` output.
- **Looking only at `ls -l`.** It shows one directory and apparent sizes. Use
  `du` for trees.
- **Trusting extensions.** `report.pdf` might be an executable. Check with
  `file`.

## Remember

- `du -sh DIR` = total; `du -ah DIR | sort -h | tail` = the heaviest items.
- `ls -lhS` sorts one directory by size.
- `find -size +1M` filters by size.
- `file` reports what the content really is; extensions mean nothing to Linux.

**Self-check:**

1. Why does a 10-byte file show 4.0K in `du`?
2. Which `sort` option understands `2.0M`?
3. How do you check whether a `.txt` file is really text?
