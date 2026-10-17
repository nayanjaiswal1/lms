---
kind: lesson
id_key: linux/moving-in/lesson
course: linux
section: moving-in
section_title: "Chapter 2: Moving In - Working with Files"
section_position: 2
title: "Lab: Unpack the Boxes"
position: 5
estimated_minutes: 25
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

## Why this matters

Time to unpack Tom's boxes for real: build the shop's folders, copy and move
files, throw out the junk without losing anything, link the menu, and find what
is eating the space. Each task is checked automatically.

## Before you start

```bash
cd ~/work/moving
find . -type f
```

What this does: lists every file in the boxes so you know what you are working
with (about ten files, in `box/` and `garage/`).

## Task 1: build the shop skeleton

Create `~/work/shop` with three subdirectories inside it, `config`, `logs` and
`backups`, using a single `mkdir` command (lesson 1: `-p` and braces).

[[lab-task:1]]

## Task 2: unpack the box

Copy the whole `moving/box/recipes` directory to `shop/config/recipes`, and move
`moving/box/menu.txt` to `shop/menu.txt`. The recipes stay in the box too; the
menu must leave it.

[[lab-task:2]]

## Task 3: throw out the junk

Delete every file ending in `.bak` anywhere under `moving/`, with one `find`
command. Every other file must survive. Run it without `-delete` first.

[[lab-task:3]]

## Task 4: two kinds of links

Create a symbolic link `shop/current-menu` pointing to
`/home/labuser/work/shop/menu.txt`, and a hard link `shop/backups/menu.hard` to
the same `menu.txt`.

[[lab-task:4]]

What you should see from `ls -li shop shop/backups`:

```
4211 -rw-r--r-- 2 labuser labuser 41 ... menu.txt
4300 lrwxrwxrwx 1 labuser labuser 32 ... current-menu -> /home/labuser/work/shop/menu.txt
4211 -rw-r--r-- 2 labuser labuser 41 ... menu.hard
```

Same inode and a link count of 2: one file, two names.

## Task 5: what is eating the space?

Find the largest file anywhere under `moving/` and save just its file name (not
the path) into `~/work/answers/biggest.txt`. Create `answers` if needed.

[[lab-task:5]]

## Remember

- `mkdir -p dir/{a,b,c}` builds a layout in one go.
- `cp -r` copies trees, `mv` moves; `find ... -delete` only after a preview.
- `ln -s` = sticky note, `ln` = second door.
- `du -ah | sort -h | tail` finds the heavy stuff.

> **End of day 2.** The shop has a home, the junk is gone, and you noticed
> `beans-inventory.csv` was hogging space. Inside the box you find Tom's next
> note: "The logs never lie. Read them."
