---
kind: lesson
id_key: linux/moving-in/inodes-and-links
course: linux
section: moving-in
section_title: "Chapter 2: Moving In - Working with Files"
section_position: 2
title: "Inodes, Hard Links and Symbolic Links"
position: 3
estimated_minutes: 8
source:
  - ln(1), stat(1), readlink(1) manual pages; inode(7), symlink(7)
---

## Why this matters

Nginx enables a site with a symlink. A deleted log can keep a disk full. A
"broken link" error stops a deploy. All three make sense once you know that a
file name is not the file.

## Mental model: rooms, doors and sticky notes

- The **inode** is the room: it holds the file's metadata (size, owner,
  permissions, timestamps, link count) and points to the data blocks on disk.
- A **directory entry** is a door: a name that leads to an inode number. A
  directory is just a list of `name -> inode number`.
- A **hard link** is a second door into the same room.
- A **symbolic link (symlink)** is a sticky note with an address written on it.

```
  directory entries          inode 4211            data blocks
  menu.txt   ---------\     +-------------+       +-----------+
                       >--> | size, owner |-----> | Espresso  |
  backups/menu.hard --/     | links: 2    |       | 3.00 ...  |
                            +-------------+       +-----------+
  current-menu  -> "/home/labuser/work/shop/menu.txt"   (symlink: just a path)
```

> **Memory hook:** a **symlink is a sticky note** with an address; a **hard link
> is a second front door** into the same room.

## See it work

```bash
cd ~/work/shop
ln -s /home/labuser/work/shop/menu.txt current-menu   # symlink
ln menu.txt backups/menu.hard                         # hard link
ls -li menu.txt current-menu backups/menu.hard
```

What this does: `ln -s TARGET NAME` writes a symlink; plain `ln TARGET NAME`
adds a hard link. `ls -i` prints the inode number in the first column. Expected
output (numbers differ):

```
4211 -rw-r--r-- 2 labuser labuser 41 ... menu.txt
4300 lrwxrwxrwx 1 labuser labuser 32 ... current-menu -> /home/labuser/work/shop/menu.txt
4211 -rw-r--r-- 2 labuser labuser 41 ... backups/menu.hard
```

Same inode (4211) and a link count of **2**: one file, two names. The symlink
has its own inode and type `l`.

```bash
readlink -f current-menu   # where does the link finally point?
stat menu.txt              # full inode details
```

### What happens on delete

`rm` removes one name and decrements the link count. The data is freed only
when the count reaches 0 **and** no process still has the file open.

```bash
rm menu.txt
cat backups/menu.hard     # still works: the room has another door
cat current-menu          # fails: the address on the sticky note is gone
```

```
Espresso 3.00 | Latte 4.50 | Mocha 5.00
cat: current-menu: No such file or directory
```

A symlink whose target is gone is called **dangling**.

### Comparison

| | Hard link (`ln`) | Symbolic link (`ln -s`) |
|---|---|---|
| What it is | a second name for the same inode | a tiny file containing a path |
| Original name deleted | data survives | link breaks (dangling) |
| Across filesystems | no | yes |
| For directories | no | yes |
| Typical use | rare; backups, dedup | config switches, versions |

Classic symlink uses:

```bash
ln -s /etc/nginx/sites-available/shop /etc/nginx/sites-enabled/shop
ln -sfn /opt/brewbot/releases/2.4.1 /opt/brewbot/current   # switch versions
```

`-f` replaces an existing link; `-n` treats an existing link to a directory as a
file, so it is replaced rather than entered.

### Inodes can run out

Every file uses one inode, and a filesystem has a fixed number. Millions of tiny
files can exhaust inodes while plenty of space remains. `df -i` shows inode
usage. This returns in Incident Week.

## Try it

You make a hard link `b` to file `a`, then edit `b` with nano. Does `a` change?
Then you delete `a`. Is `b` still readable?

<details>
<summary>Show answer</summary>

Usually yes and yes. `a` and `b` are the same inode, so an edit through one name
shows through the other, and deleting `a` only removes one name; `b` keeps the
data alive. (Some editors save by writing a new file and renaming it, which
gives `b` a new inode and breaks the link. `ls -li` shows whether the inode
numbers still match.)

</details>

## Common mistakes

- **Reversing the arguments.** It is `ln -s TARGET LINKNAME`, the same order as
  `cp SOURCE DEST`.
- **Relative symlinks created from the wrong place.** A relative target is
  resolved from the link's directory, not from where you ran `ln`. Use absolute
  targets until you are comfortable.
- **Thinking `rm` on a symlink deletes the target.** It deletes only the sticky
  note.
- **Expecting a hard link across disks.** Inode numbers are per filesystem, so
  `ln` fails with "Invalid cross-device link". Use a symlink.

## Remember

- A name points to an inode; the inode holds metadata and points to the data.
- Hard link = same inode, another name. Symlink = a file holding a path.
- Data is freed when the link count is 0 and nobody has it open.
- `ls -li`, `stat`, `readlink -f` reveal what is really going on.

**Self-check:**

1. What does the number after the permissions in `ls -l` count?
2. Why can a hard link not point to a file on another disk?
3. What is a dangling symlink?
