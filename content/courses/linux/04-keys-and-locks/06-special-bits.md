---
kind: lesson
id_key: linux/keys-and-locks/special-bits
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks - Users and Permissions"
section_position: 4
title: "Special Bits: SUID, SGID and the Sticky Bit"
position: 5
estimated_minutes: 7
source:
  - chmod(1), inode(7), passwd(1) manual pages
---

## Why this matters

How can a normal user change their own password, when the password file is
root-only? Why can't you delete other people's files in `/tmp`, which everyone
can write? Three special bits explain both, and one of them is a favourite target
for attackers.

## Mental model: three special stickers

| Bit | Value | On a file | On a directory | Looks like |
|---|---|---|---|---|
| **SUID** | 4000 | runs as the file's **owner**, not as you | (no effect) | `-rwsr-xr-x` |
| **SGID** | 2000 | runs as the file's **group** | new files inherit the directory's group | `drwxrwsr-x` |
| **Sticky** | 1000 | (no effect) | only a file's owner can delete or rename it | `drwxrwxrwt` |

They appear in the `x` positions of `ls -l`: `s` or `t` when `x` is also set,
capital `S` or `T` when it is not (usually a mistake).

> **Memory hook:** the **sticky** bit is **chewing gum on a locker**: anyone can
> put things in, but only you can take yours out.

## See it work

### SUID: borrowing the owner's badge

```bash
ls -l /usr/bin/passwd
```

```
-rwsr-xr-x 1 root root 64152 May 30  2024 /usr/bin/passwd
```

The `s` means: whoever runs `passwd` runs it **as root**. That is how a normal
user can update the root-only `/etc/shadow`. `passwd` carefully only lets you
change your own entry.

SUID root programs are a favourite attack target: one bug in them is a path to
root. List them all:

```bash
find / -perm -4000 -type f 2>/dev/null
```

Know what is normally there (`passwd`, `su`, `sudo`, `mount`, `ping` on older
systems) and investigate anything new.

### SGID on a directory: shared team folders

```bash
sudo mkdir /srv/roastery
sudo chgrp baristas /srv/roastery
sudo chmod 2775 /srv/roastery
ls -ld /srv/roastery
```

```
drwxrwsr-x 2 root baristas 4096 Oct 14 11:00 /srv/roastery
```

Now every file created inside belongs to group `baristas`, whoever creates it,
so the whole team can work on it.

### Sticky: a shared drop box

```bash
ls -ld /tmp
mkdir -p ~/work/keys/drop && chmod 1777 ~/work/keys/drop
ls -ld ~/work/keys/drop
```

```
drwxrwxrwt 1 root root 4096 Oct 15 11:56 /tmp
drwxrwxrwt 2 labuser labuser 4096 Oct 14 11:05 /home/labuser/work/keys/drop
```

`1777` = sticky (1000) + `rwxrwxrwx` (777). Everyone can create files, but users
can delete only their own.

### Setting them symbolically

```bash
chmod u+s file      # SUID
chmod g+s dir       # SGID
chmod +t dir        # sticky
```

## Try it

You see `-rwSr--r-- labuser labuser report`. What does the capital `S` tell
you, and is it dangerous?

<details>
<summary>Show answer</summary>

SUID is set but the owner has no execute bit, so the file cannot run and the
SUID bit does nothing. It is a harmless mistake; remove it with `chmod u-s
report`.

</details>

## Common mistakes

- **SUID on shell scripts.** Linux ignores SUID on scripts (for good reason). Use
  `sudo` rules instead (lesson 8).
- **World-writable directories without the sticky bit.** Then any user can delete
  everyone's files. Shared write = `1777` or SGID group folders.
- **Leaving unexpected SUID binaries around.** Audit with `find / -perm -4000`.

## Remember

- SUID 4000: run as the file's owner (`passwd`).
- SGID 2000: on a directory, new files inherit its group (team folders).
- Sticky 1000: in a shared directory, only owners delete (`/tmp`, `1777`).
- `s`/`t` in `ls -l`; capital means `x` is missing.

**Self-check:**

1. Why can `passwd` write to `/etc/shadow`?
2. What mode do you give a `/tmp`-like directory?
3. How do you list every SUID file on the system?
