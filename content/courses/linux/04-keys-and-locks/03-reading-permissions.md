---
kind: lesson
id_key: linux/keys-and-locks/reading-permissions
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks - Users and Permissions"
section_position: 4
title: "Reading Permissions: rwx for Owner, Group and Others"
position: 2
estimated_minutes: 7
source:
  - ls(1), stat(1), path_resolution(7) manual pages
---

## Why this matters

"Permission denied" is the most common error on Linux. You can only fix it if
you can read the ten characters at the start of `ls -l` in one glance and know
which of them applies to you.

## Mental model: three locks on every door

Every file has three sets of locks, for three kinds of people:

```
 -rwxr-x---  1  rhea  baristas  512  Oct 14  deploy.sh
 |\_/\_/\_/     |     |
 | |  |  |      owner group
 | |  |  others: ---  nothing
 | |  group:     r-x  read + execute
 | owner:        rwx  read + write + execute
 type: - file, d directory, l symlink
```

Linux checks **one** class only, the first that fits:

```
 Are you the owner?        -> use the owner bits. Stop.
 Else, in the file's group? -> use the group bits. Stop.
 Else                       -> use the others bits.
```

So if the owner bits are `---`, the owner is denied even if "others" may read.
Root skips these checks (except that it still needs at least one `x` to run a
file).

## What r, w, x mean

The same letter means different things on files and directories:

| | On a file | On a directory |
|---|---|---|
| **r** | read the content | list the names inside (`ls`) |
| **w** | change the content | create, delete, rename entries inside |
| **x** | run it as a program | enter it (`cd`) and reach files inside |

Two consequences surprise everyone:

- **Deleting a file needs `w` on the directory**, not on the file. A read-only
  file in your own directory can still be deleted by you.
- **To reach `/srv/shop/menu.txt` you need `x` on `/`, `/srv` and `/srv/shop`.**
  One locked directory in the path blocks everything below it.

## See it work

```bash
ls -l ~/work/answers/kernel.txt
ls -ld ~/work /tmp
```

What this does: `-d` lists the directory itself instead of its contents.
Expected output (similar):

```
-rw-r--r-- 1 labuser labuser 17 Oct 14 09:20 /home/labuser/work/answers/kernel.txt
drwxr-xr-x 4 labuser labuser 4096 Oct 14 09:00 /home/labuser/work
drwxrwxrwt 1 root    root    4096 Oct 15 11:56 /tmp
```

- `kernel.txt`: owner read/write, everyone else read only.
- `/tmp`: everyone can do everything, plus a `t` at the end (the sticky bit,
  lesson 6).

`stat` shows the same in numbers:

```bash
stat -c '%A %a %U:%G %n' ~/work/answers/kernel.txt
```

```
-rw-r--r-- 644 labuser:labuser /home/labuser/work/answers/kernel.txt
```

`namei -l` shows the permissions of **every directory on the path**, which is
how you find the one locked door:

```bash
namei -l /home/labuser/work/answers/kernel.txt
```

```
f: /home/labuser/work/answers/kernel.txt
drwxr-xr-x root    root    /
drwxr-xr-x root    root    home
drwxr-x--- labuser labuser labuser
drwxr-xr-x labuser labuser work
drwxr-xr-x labuser labuser answers
-rw-r--r-- labuser labuser kernel.txt
```

`/home/labuser` is `drwxr-x---`: other users cannot even enter your home.

## Try it

A file is `-r--rw-rw- rhea baristas notes.txt`. Rhea (in group baristas) tries
to write to it. Allowed? And Sam, who is in baristas but is not Rhea?

<details>
<summary>Show answer</summary>

Rhea: **denied**. She is the owner, so only the owner bits `r--` apply; the
group bits are never checked for her. Sam: **allowed**, he is not the owner but
is in the group, so `rw-` applies.

</details>

## Common mistakes

- **Adding up classes.** Linux does not combine owner + group + others. Only the
  first matching class counts.
- **Checking only the file.** Missing `x` on a parent directory gives
  "Permission denied" for a perfectly readable file. Use `namei -l`.
- **Thinking `r` on a directory lets you open files.** `r` lists names; `x` lets
  you reach the files.

## Remember

- `type owner group others`: `-rwxr-x---`.
- One class applies: owner, else group, else others.
- Directory `w` = create/delete entries; directory `x` = pass through.
- `ls -ld`, `stat`, `namei -l` show what really applies.

**Self-check:**

1. What permission do you need to delete a file?
2. What does `x` mean on a directory?
3. Which command shows permissions of every directory on a path?
