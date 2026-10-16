---
kind: lesson
id_key: linux/the-logbook/sed
course: linux
section: the-logbook
section_title: "Chapter 3: The Logbook - Text Tools and Pipes"
section_position: 3
title: "sed: Editing a Stream, and Comparing Files with diff"
position: 5
estimated_minutes: 7
source:
  - sed(1), diff(1), cmp(1) manual pages; GNU sed manual (gnu.org/software/sed/manual)
---

## Why this matters

The app wrote customer passwords into its log. You need a clean copy to share
with the developers, now, without opening an editor. Later you will change one
port number in a config on ten servers. `sed` does both from the command line.

## Mental model: a find-and-replace conveyor belt

`sed` (**s**tream **ed**itor) reads lines one by one, applies an edit, and
prints the result. The original file is untouched unless you ask for `-i`.

```
  app.log --> [ sed 's/password=[^ ]*/password=***/' ] --> stdout (or > new file)
```

The main command is **s**ubstitute:

```
  s / what / with / flags
        regex   text   g = every match on the line (default: first only)
```

## See it work

```bash
cd ~/work/logbook
grep login app.log | head -2
sed 's/password=[^ ]*/password=***/' app.log | grep login | head -2
```

What this does: `[^ ]*` means "any run of non-space characters", so the whole
password value is replaced. Expected output (before, then after):

```
2026-10-14 10:4:00 INFO login user=u4 password=s3cret4
2026-10-14 10:8:00 INFO login user=u8 password=s3cret8
2026-10-14 10:4:00 INFO login user=u4 password=***
2026-10-14 10:8:00 INFO login user=u8 password=***
```

`app.log` itself is unchanged. To keep the result, redirect to a **new** file:

```bash
sed 's/password=[^ ]*/password=***/' app.log > app-clean.log
```

### Other everyday sed commands

```bash
sed 's/old/new/g' file          # replace every match on each line
sed -n '10,12p' app.log         # print only lines 10-12 (-n = no automatic print)
sed '/^#/d' app.conf            # delete comment lines
sed '/^$/d' app.conf            # delete empty lines
sed 's|/var/log|/srv/log|g' f   # any character can be the delimiter: handy with paths
```

### Editing in place

```bash
sed -i.bak 's/^port = .*/port = 8080/' brewbot.conf
```

What this does: `-i` writes the change back into the file; `.bak` keeps the
original as `brewbot.conf.bak`. Always test without `-i` first, then add it.

> **Memory hook:** without `-i`, sed is a **preview**; with `-i`, it is a
> **pen**. Preview first.

### Comparing files: diff

After editing a config, check what really changed:

```bash
diff brewbot.conf.bak brewbot.conf
diff -u brewbot.conf.bak brewbot.conf     # unified format, the one git shows
```

Output of the second command (timestamps trimmed):

```
--- brewbot.conf.bak
+++ brewbot.conf
@@ -1,3 +1,3 @@
 name = brewbot
-port = 80800
+port = 8080
 workers = 4
```

Lines with `-` were removed, `+` added. `diff` exits with 0 when files are the
same, so scripts can use it as a test. For binary files use `cmp a.bin b.bin`.

## Try it

Print `app.log` with every `ERROR` replaced by `FAIL`, but only show lines 1-5
of the result. Do not change the file.

<details>
<summary>Show answer</summary>

```bash
sed 's/ERROR/FAIL/g' app.log | head -5
```

or `sed -n '1,5{s/ERROR/FAIL/g;p}' app.log`. The first is easier to read.

</details>

## Common mistakes

- **`sed -i` on the only copy of evidence.** A wrong regex destroys the log you
  needed. Use `-i.bak` or write to a new file.
- **`sed file > file`.** The shell empties the file before sed reads it. Write
  elsewhere, then `mv`.
- **Forgetting `g`.** Only the first match on each line is replaced.
- **Slashes in the pattern.** `s//var/log//srv/` is broken. Escape them or use
  another delimiter: `s|/var|/srv|`.

## Remember

- `sed 's/what/with/g' file` prints an edited copy.
- `-n 'X,Yp'` prints a range; `/re/d` deletes matching lines.
- `-i.bak` edits in place with a backup; preview first.
- `diff -u old new` shows exactly what changed.

**Self-check:**

1. What does `[^ ]*` match?
2. What does `sed -n '5p'` print?
3. How do you make `sed -i` keep a backup?
