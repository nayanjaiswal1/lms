---
kind: lesson
id_key: linux/storeroom/lesson
course: linux
section: storeroom
section_title: "Chapter 7: The Storeroom - Packages, Disks and Backups"
section_position: 7
title: "Lab: Take Stock of the Storeroom"
position: 5
estimated_minutes: 20
source:
  - apt(8), dpkg(1), dpkg-query(1), dnf(8) manual pages
  - df(1), du(1), lsblk(8), mount(8), fstab(5), mkfs(8), tar(1), rsync(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 45
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    w=/home/labuser/work
    rm -rf $w/storeroom $w/backups $w/unpacked $w/answers $w/delivery.tar.gz
    mkdir -p $w/storeroom/beans $w/storeroom/cups $w/storeroom/syrups $w/answers
    head -c 3145728 /dev/urandom > $w/storeroom/beans/arabica.bin
    head -c 204800 /dev/urandom > $w/storeroom/cups/paper.bin
    head -c 1048576 /dev/urandom > $w/storeroom/syrups/vanilla.bin
    t=$(mktemp -d)
    mkdir -p $t/delivery
    echo "20 bags arabica, 5 boxes cups, 3 bottles vanilla" > $t/delivery/manifest.txt
    echo "paid" > $t/delivery/invoice.txt
    tar -czf $w/delivery.tar.gz -C $t delivery
    rm -rf $t
  tasks:
    - id_key: package-version
      title: Which bash do we have?
      points: 15
      is_stateful: true
      description: Use the Debian package tools to save the installed version of the bash package into answers/bash-version.txt (the version string only, for example 5.0-6ubuntu1).
      verification_script: |
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/bash-version.txt)" = "$(dpkg-query -W -f='${Version}' bash)" ]
      hint_context: dpkg -l bash shows it in a table; dpkg-query -W -f='${Version}' bash prints only the version.
      explanation_context: dpkg is the low-level tool that knows every installed .deb package; apt sits on top of it and adds downloading and dependency resolution.
      solution_script: |
        dpkg-query -W -f='${Version}' bash > /home/labuser/work/answers/bash-version.txt
    - id_key: package-owner
      title: Who installed this file?
      points: 15
      is_stateful: true
      description: Find which package installed the file /usr/bin/jq and save just the package name into answers/jq-owner.txt.
      verification_script: |
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/jq-owner.txt)" = "$(dpkg -S /usr/bin/jq | cut -d: -f1)" ]
      hint_context: dpkg -S PATH searches installed packages for a file and prints package-name - path.
      explanation_context: dpkg -S (search) maps a file back to its package, and dpkg -L PACKAGE does the reverse. On RHEL the same questions are rpm -qf FILE and rpm -ql PACKAGE.
      solution_script: |
        dpkg -S /usr/bin/jq | cut -d: -f1 > /home/labuser/work/answers/jq-owner.txt
    - id_key: biggest-dir
      title: Which shelf is heaviest?
      points: 20
      is_stateful: true
      description: Save the name of the largest subdirectory of /home/labuser/work/storeroom (just the name, like cups) into answers/biggest-dir.txt.
      verification_script: |
        want=$(du -s /home/labuser/work/storeroom/*/ | sort -n | tail -1 | awk '{print $2}' | xargs basename)
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/biggest-dir.txt)" = "$want" ]
      hint_context: du -sh storeroom/* shows one total per subdirectory; pipe through sort -h to rank them.
      explanation_context: du measures what files actually use on disk, df measures whole filesystems. When df says a disk is full, du -sh /* | sort -h is how you walk down to the culprit.
      solution_script: |
        echo beans > /home/labuser/work/answers/biggest-dir.txt
    - id_key: make-archive
      title: Back up the storeroom
      points: 25
      is_stateful: true
      description: Create the compressed archive /home/labuser/work/backups/storeroom.tar.gz containing the storeroom directory. Paths inside the archive must start with storeroom/ (not /home/...).
      verification_script: |
        a=/home/labuser/work/backups/storeroom.tar.gz
        gzip -t $a && tar -tzf $a | grep -q '^storeroom/beans/arabica.bin$' && ! tar -tzf $a | grep -q '^/\|^home/'
      hint_context: Run tar from inside /home/labuser/work so the paths are relative - tar -czf backups/storeroom.tar.gz storeroom. c create, z gzip, f file name.
      explanation_context: tar stores paths exactly as you give them. Archiving a relative path means it can be extracted anywhere; tar -tzf lists the contents without extracting.
      solution_script: |
        cd /home/labuser/work && mkdir -p backups && tar -czf backups/storeroom.tar.gz storeroom
    - id_key: extract-archive
      title: Unpack the delivery
      points: 25
      is_stateful: true
      description: Extract /home/labuser/work/delivery.tar.gz into the directory /home/labuser/work/unpacked, so that unpacked/delivery/manifest.txt exists.
      verification_script: |
        grep -q arabica /home/labuser/work/unpacked/delivery/manifest.txt
      hint_context: tar -xzf ARCHIVE -C DIR extracts into DIR (which must exist - mkdir it first). List first with tar -tzf to see what is inside.
      explanation_context: x extracts, -C changes into a directory first. Always list an archive from a stranger before extracting it - it could contain absolute paths or overwrite your files.
      solution_script: |
        mkdir -p /home/labuser/work/unpacked && tar -xzf /home/labuser/work/delivery.tar.gz -C /home/labuser/work/unpacked
---

## Why this matters

Before you install anything new, Rhea wants an inventory: which versions are
installed, where files came from, what fills the shelves, and a backup of the
storeroom. Partitioning and LVM need root and spare disks, so this lab focuses on
the parts you can do as a normal user. Each task is checked automatically.

## Before you start

```bash
cd ~/work
ls storeroom
ls -l delivery.tar.gz
```

What this does: shows the three shelves (`beans`, `cups`, `syrups`) and the
delivery archive.

## Task 1: which bash do we have?

Using the Debian package tools, save the installed version of the `bash`
package (the version string only) into `answers/bash-version.txt`.

[[lab-task:1]]

## Task 2: who installed this file?

Find which package installed `/usr/bin/jq` and save just the package name into
`answers/jq-owner.txt`.

[[lab-task:2]]

## Task 3: which shelf is heaviest?

Save the name of the largest subdirectory of `~/work/storeroom` (just the name,
like `cups`) into `answers/biggest-dir.txt`.

[[lab-task:3]]

## Task 4: back up the storeroom

Create `~/work/backups/storeroom.tar.gz` containing the `storeroom` directory.
Paths inside must start with `storeroom/`, not `/home/...`.

[[lab-task:4]]

## Task 5: unpack the delivery

Extract `~/work/delivery.tar.gz` into `~/work/unpacked`, so that
`unpacked/delivery/manifest.txt` exists. List it first.

[[lab-task:5]]

What you should see:

```
$ tar -tzf delivery.tar.gz
delivery/
delivery/manifest.txt
delivery/invoice.txt
```

## Remember

- `dpkg-query -W`, `dpkg -S` answer "which version" and "which package".
- `du -sh DIR/* | sort -h` ranks directories.
- `tar -czf` from the parent directory keeps paths short; `tar -tzf` before
  `-x`.

> **End of day 7.** The new disk is mounted by UUID on an LVM volume you can
> grow, the storeroom is backed up, and the delivery is unpacked. Rhea:
> "Tomorrow the payment provider needs to reach brewbot. Learn how atlas talks
> to the world." Tom's note: "Every door has a number."
