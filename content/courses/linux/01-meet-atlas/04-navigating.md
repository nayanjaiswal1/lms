---
kind: lesson
id_key: linux/meet-atlas/navigating
course: linux
section: meet-atlas
section_title: "Chapter 1: Meet Atlas - the Shell and the Map"
section_position: 1
title: "Moving Around: pwd, ls, cd and Paths"
position: 3
estimated_minutes: 7
source:
  - pwd(1), ls(1) manual pages; GNU Bash Reference Manual, "cd" builtin and "Tilde Expansion"
---

## Why this matters

Tom hid notes in folders all over atlas, some of them hidden. To find them you
need three commands and one idea: the difference between an absolute and a
relative path. Most "No such file or directory" errors come from mixing them up.

## Mental model: you are standing somewhere

The shell always stands in one directory, the **working directory**. Paths are
directions.

- An **absolute path** starts at `/`: a full postal address. It works from
  anywhere.
- A **relative path** starts from where you stand: "two doors down". It only
  works from the right place.

```
 absolute: /home/labuser/work/atlas      always starts with /
 relative: work/atlas                    starts from where you are

 .  = this directory
 .. = the parent (one level up)
 ~  = your home directory
 -  = (with cd) the previous directory
```

## See it work

```bash
pwd                     # print working directory: "where am I?"
```

```
/home/labuser
```

```bash
cd /var/log             # absolute path: jump straight there
pwd
cd ..                   # one level up
pwd
cd                      # no argument: go home
pwd
```

What this does: moves around and confirms each step. Expected output:

```
/var/log
/var
/home/labuser
```

`cd -` returns to the previous directory, handy when you bounce between two
places.

### Listing what is here

```bash
ls              # names only
ls -l           # long: permissions, owner, size, date
ls -a           # all, including hidden dot-files
ls -la          # both
ls -lh          # human sizes (4.0K, 12M)
ls -lt          # newest first
```

A file whose name starts with `.` is **hidden**: `ls` skips it, `ls -a` shows
it. That is only a naming convention, not security. Config files in your home
(`.bashrc`, `.ssh/`) are hidden so they do not clutter listings.

```bash
ls -la ~
```

```
drwxr-x--- 4 labuser labuser 4096 Oct 14 09:00 .
drwxr-xr-x 3 root    root    4096 Oct  1 08:00 ..
-rw-r--r-- 1 labuser labuser 3771 Oct  1 08:00 .bashrc
drwxrwxr-x 3 labuser labuser 4096 Oct 14 09:00 work
```

Every directory contains `.` (itself) and `..` (its parent). The first letter
`d` marks a directory, `-` a regular file.

## Try it

You are in `/home/labuser/work`. Write two different commands that take you to
`/home/labuser/work/atlas/etc`: one with an absolute path, one relative. Then:
which `ls` option would reveal a folder named `.archive`?

<details>
<summary>Show answer</summary>

Absolute: `cd /home/labuser/work/atlas/etc`. Relative: `cd atlas/etc`. Also
valid: `cd ~/work/atlas/etc`. `ls -a` (or `ls -la`) shows names starting with a
dot.

</details>

## Common mistakes

- **Using a relative path from the wrong place.** `cd atlas` fails in `/tmp`
  because there is no `/tmp/atlas`. Run `pwd` when in doubt.
- **Forgetting the leading `/`.** `cd var/log` means "`var/log` below here", not
  the system's `/var/log`.
- **Typing spaces in names without quotes.** `cd my notes` tries to go to `my`.
  Use `cd "my notes"` or Tab completion, which adds `\ ` for you.
- **Believing hidden means protected.** Anyone who can list the folder can run
  `ls -a`. Use permissions (chapter 4) to protect files.

## Remember

- `pwd` where am I, `ls` what is here, `cd` go there.
- Absolute paths start with `/`; relative paths start from the current directory.
- `.` here, `..` up, `~` home, `cd -` back.
- Dot-files are hidden from `ls`; `ls -a` shows them.

**Self-check:**

1. What does `cd` with no arguments do?
2. Is `../logs` absolute or relative?
3. Which option makes `ls` show sizes like `12M`?
