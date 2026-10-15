---
kind: lesson
id_key: linux/moving-in/lesson
course: linux
section: moving-in
section_title: "Chapter 2: Moving In"
section_position: 2
title: Files, Directories, Links and Finding Things
position: 0
estimated_minutes: 45
source:
  - cp(1), mv(1), rm(1), ln(1), find(1), stat(1) manual pages
  - GNU Coreutils manual (gnu.org/software/coreutils/manual)
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 45
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    w=/home/labuser/work
    rm -rf $w/moving $w/shop $w/answers
    mkdir -p $w/moving/box/recipes $w/moving/box/old $w/moving/garage $w/answers
    echo "Espresso 3.00 | Latte 4.50 | Mocha 5.00" > $w/moving/box/menu.txt
    echo "18g in, 36g out, 28 seconds" > $w/moving/box/recipes/espresso.txt
    echo "1 espresso + 200ml steamed milk" > $w/moving/box/recipes/latte.txt
    echo "old menu" > $w/moving/box/old/menu-2019.bak
    echo "old prices" > $w/moving/box/old/prices.bak
    echo "draft" > $w/moving/box/recipes/mocha.bak
    echo "tools list" > $w/moving/garage/tools.txt
    echo "spare" > $w/moving/garage/spare.bak
    head -c 2097152 /dev/urandom > $w/moving/garage/beans-inventory.csv
    head -c 4096 /dev/urandom > $w/moving/box/old/receipts.csv
  tasks:
    - id_key: make-shop
      title: Build the shop skeleton
      points: 10
      is_stateful: true
      description: Create /home/labuser/work/shop with three subdirectories inside it - config, logs and backups - using a single mkdir command.
      verification_script: |
        s=/home/labuser/work/shop
        [ -d $s/config ] && [ -d $s/logs ] && [ -d $s/backups ]
      hint_context: mkdir -p creates parent directories as needed, and brace expansion {config,logs,backups} turns one word into three.
      explanation_context: mkdir -p never fails if a directory already exists and creates every missing parent. Bash expands shop/{a,b,c} into three separate arguments before mkdir even runs.
      solution_script: |
        mkdir -p /home/labuser/work/shop/{config,logs,backups}
    - id_key: copy-move
      title: Unpack the box
      points: 15
      is_stateful: true
      description: Copy the whole moving/box/recipes directory (with its contents) to shop/config/recipes, and move moving/box/menu.txt to shop/menu.txt so it no longer exists in the box.
      verification_script: |
        w=/home/labuser/work
        [ -f $w/shop/config/recipes/espresso.txt ] && [ -f $w/shop/config/recipes/latte.txt ] &&
        [ -f $w/moving/box/recipes/espresso.txt ] &&
        [ -f $w/shop/menu.txt ] && [ ! -e $w/moving/box/menu.txt ]
      hint_context: cp needs -r to copy a directory. mv both moves and renames; the source disappears.
      explanation_context: cp -r copies a tree and leaves the original in place. mv only changes where the name points, so within one filesystem it is instant even for huge files.
      solution_script: |
        cp -r /home/labuser/work/moving/box/recipes /home/labuser/work/shop/config/recipes
        mv /home/labuser/work/moving/box/menu.txt /home/labuser/work/shop/menu.txt
    - id_key: clean-bak
      title: Throw out the junk
      points: 20
      is_stateful: true
      description: Delete every file ending in .bak anywhere under moving/ (there are several, in different folders) with one find command. Every other file must survive.
      verification_script: |
        w=/home/labuser/work/moving
        [ -z "$(find $w -name '*.bak')" ] &&
        [ -f $w/garage/tools.txt ] && [ -f $w/box/old/receipts.csv ] && [ -f $w/garage/beans-inventory.csv ]
      hint_context: find DIR -name '*.bak' lists matches; run it first to check, then add -delete. Quote the pattern so the shell does not expand it.
      explanation_context: find walks the whole tree. Always run it without -delete first - rm and -delete have no undo and no recycle bin in Linux.
      solution_script: |
        find /home/labuser/work/moving -name '*.bak' -delete
    - id_key: links
      title: Two kinds of links
      points: 25
      is_stateful: true
      description: Create a symbolic link shop/current-menu pointing to /home/labuser/work/shop/menu.txt, and a hard link shop/backups/menu.hard to the same menu.txt.
      verification_script: |
        s=/home/labuser/work/shop
        [ -L $s/current-menu ] && [ "$(readlink -f $s/current-menu)" = $s/menu.txt ] &&
        [ ! -L $s/backups/menu.hard ] && [ $s/backups/menu.hard -ef $s/menu.txt ]
      hint_context: ln -s TARGET LINKNAME makes a symlink; ln TARGET LINKNAME (no -s) makes a hard link. ls -li shows inode numbers - hard links share one.
      explanation_context: A symlink is a small file holding a path, so it breaks if the target moves. A hard link is a second name for the same inode, so the data lives until the last name is removed.
      solution_script: |
        ln -s /home/labuser/work/shop/menu.txt /home/labuser/work/shop/current-menu
        ln /home/labuser/work/shop/menu.txt /home/labuser/work/shop/backups/menu.hard
    - id_key: biggest-file
      title: What is eating the space?
      points: 20
      is_stateful: true
      description: Find the largest file anywhere under moving/ and save its file name (just the name, not the path) into answers/biggest.txt.
      verification_script: |
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/biggest.txt)" = beans-inventory.csv ]
      hint_context: find moving -type f -size +1M lists files bigger than 1 MiB, or ls -lhR / du -ah moving | sort -h shows sizes.
      explanation_context: find -size filters by size, and du -ah | sort -h ranks everything. This is the first thing you do when a disk fills up.
      solution_script: |
        echo beans-inventory.csv > /home/labuser/work/answers/biggest.txt
---

> **Tuesday.** Rhea points at a pile of digital boxes Tom dumped in `~/work/moving`: "The shop needs a proper home. Unpack, throw out the junk, and don't delete anything we need - there is no recycle bin on Linux."

## Creating files and directories

```bash
mkdir shop                       # one directory
mkdir -p shop/config/recipes     # whole path, no error if it exists
mkdir -p shop/{config,logs,backups}   # brace expansion -> three dirs
touch notes.txt                  # create empty file (or update its timestamp)
echo "hello" > file.txt          # create/overwrite with content
echo "more"  >> file.txt         # append
rmdir emptydir                   # remove an EMPTY directory
```

Editors on a server: `nano file.txt` (easy, shortcuts at the bottom: `Ctrl+O` save, `Ctrl+X` exit) or `vi file.txt` (always installed). Survival `vi`: `i` to type, `Esc` to stop, `:wq` save and quit, `:q!` quit without saving.

> **Memory hook:** `>` is a **bulldozer** (flattens the file), `>>` is a **stapler** (adds a page).

[[lab-task:1]]

## Copy, move, rename, delete

```bash
cp a.txt b.txt              # copy file
cp -r dir1 dir2             # copy directory (recursive)
cp -a src dst               # archive copy: keep permissions, times, links
mv old.txt new.txt          # rename
mv file.txt dir/            # move
rm file.txt                 # delete file
rm -r dir                   # delete directory and everything inside
rm -i *.log                 # ask before each delete
```

```
 cp:  box/recipes ---copy---> shop/config/recipes     (both exist after)
 mv:  box/menu.txt --move---> shop/menu.txt           (only one exists after)
```

There is **no undo**. `rm -rf /` with a typo in a variable has ended careers. Habits that save you: run `ls` with the same pattern first, use `rm -i` when unsure, never run `rm -rf $DIR/` without checking `$DIR` is set.

**Wildcards (globs)** are expanded by the shell before the command runs:

| Pattern | Matches |
|---|---|
| `*` | anything (`*.log`) |
| `?` | exactly one character (`file?.txt`) |
| `[abc]` / `[0-9]` | one character from the set |
| `{a,b}` | brace expansion - not a match, it generates both words |

[[lab-task:2]]

## Finding things

```bash
find /var/log -name "*.log"            # by name (quote the pattern!)
find . -iname "readme*"                # case-insensitive
find . -type d -name config            # directories only (f = files)
find / -size +100M 2>/dev/null         # bigger than 100 MiB
find . -mtime -1                       # modified in the last 24h
find . -user labuser                   # by owner
find . -name "*.bak" -delete           # find and delete
find . -name "*.sh" -exec chmod +x {} \;   # run a command on each match
locate nginx.conf                      # fast, uses a prebuilt index (updatedb)
```

> **Memory hook:** `find WHERE WHAT DO` - *where* to look, *what* to match, what to *do* with it. Always run it once **without** the DO part.

[[lab-task:3]]

## Inodes and links

A file name is not the file. The data lives in an **inode** (metadata: size, owner, permissions, where the blocks are). A directory is just a list of `name -> inode number`.

```
  directory entries          inode 4211            data blocks
  menu.txt   ---------\     +-------------+       +-----------+
                       >--> | size, owner |-----> | Espresso  |
  backups/menu.hard --/     | links: 2    |       | 3.00 ...  |
                            +-------------+       +-----------+
  current-menu  -> "/home/labuser/work/shop/menu.txt"   (symlink: just a path)
```

| | Hard link (`ln`) | Symbolic link (`ln -s`) |
|---|---|---|
| What it is | a second name for the same inode | a tiny file containing a path |
| Original deleted | data survives | link breaks (dangling) |
| Across filesystems | no | yes |
| For directories | no | yes |

```bash
ln -s /etc/nginx/sites-available/shop /etc/nginx/sites-enabled/shop   # classic symlink use
ls -li                  # first column = inode number
stat menu.txt           # full inode details
readlink -f current-menu    # where does the link really point?
```

> **Memory hook:** a **symlink is a sticky note** with an address on it; a **hard link is a second front door** into the same room.

[[lab-task:4]]

What you should see from `ls -li shop shop/backups`:

```
4211 -rw-r--r-- 2 labuser labuser 41 ... menu.txt
4300 lrwxrwxrwx 1 labuser labuser 32 ... current-menu -> /home/labuser/work/shop/menu.txt
4211 -rw-r--r-- 2 labuser labuser 41 ... menu.hard
```

Same inode (4211) and a link count of 2 - one file, two names.

## Sizes and file types

```bash
du -sh shop             # total size of a directory
du -ah moving | sort -h | tail -5    # the five biggest things
ls -lhS                 # list sorted by size
file beans-inventory.csv    # what kind of data is this, really?
```

Linux does not care about extensions - `file` looks at the content.

[[lab-task:5]]

> **End of day 2.** The shop has a home, the junk is gone, and you noticed `beans-inventory.csv` was hogging space. Inside the box you find Tom's next note: "The logs never lie. Read them."
