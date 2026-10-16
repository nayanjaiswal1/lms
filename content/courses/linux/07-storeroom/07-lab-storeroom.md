---
kind: lesson
id_key: linux/storeroom/lesson
course: linux
section: storeroom
section_title: "Chapter 7: The Storeroom"
section_position: 7
title: Packages, Disks, Filesystems, Mounts and Archives
position: 0
estimated_minutes: 50
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

> **Monday, week 2.** A delivery of new disks arrives, and the dev team wants software installed. Rhea: "Before you install anything, know what's already in the storeroom - and never let a disk fill up silently." Tom's note: *know your storeroom*.

## Packages: installing software the right way

On Linux you rarely download installers from websites. You use the distro's **package manager**, which fetches signed packages from trusted repositories and handles dependencies.

| | Debian / Ubuntu | RHEL / Fedora / Rocky | Alpine |
|---|---|---|---|
| Package format | `.deb` | `.rpm` | `.apk` |
| High-level tool | `apt` | `dnf` (older: `yum`) | `apk` |
| Low-level tool | `dpkg` | `rpm` | - |

```bash
sudo apt update                  # refresh the list of available packages
sudo apt upgrade                 # upgrade everything installed
sudo apt install nginx           # install (+ dependencies)
sudo apt remove nginx            # remove, keep config files
sudo apt purge nginx             # remove including config
sudo apt autoremove              # remove dependencies nobody needs anymore
apt search redis                 # find packages
apt show nginx                   # details
dpkg -l | grep nginx             # is it installed? which version?
dpkg -L nginx                    # which files did it install?
dpkg -S /usr/sbin/nginx          # which package owns this file?
```

> **Memory hook:** `apt update` reads the **menu**, `apt upgrade` **orders** the new dishes. Always update before you install.

Repositories are listed in `/etc/apt/sources.list` and `/etc/apt/sources.list.d/`. Other ways software arrives: `snap`/`flatpak` (self-contained apps), language package managers (`pip`, `npm`), and compiling from source (`./configure && make && sudo make install`) - avoid that last one on servers when a package exists.

[[lab-task:1]]

[[lab-task:2]]

## Disks, partitions and filesystems

```
  /dev/sda            the whole first disk (SATA/SCSI/virtual)
  |-- /dev/sda1       partition 1  -> ext4  mounted at /boot
  `-- /dev/sda2       partition 2  -> ext4  mounted at /
  /dev/nvme0n1p1      NVMe disk 0, partition 1
  /dev/sdb            the new disk - not partitioned yet
```

```bash
lsblk               # disk and partition tree with mount points
lsblk -f            # plus filesystem types and UUIDs
df -h               # space used on each mounted filesystem
df -i               # INODES used - a disk can be "full" with space left!
du -sh /var/log     # size of one directory
du -sh /* 2>/dev/null | sort -h    # find the heavy top-level directories
free -h             # memory and swap
```

A filesystem organises a partition into files and directories: **ext4** (the Linux default), **xfs** (RHEL default, big files), **btrfs** (snapshots), **vfat** (USB sticks, EFI), **tmpfs** (in RAM).

> **Memory hook:** **df** = **d**isk **f**ree (how full is the whole shelf?). **du** = **d**isk **u**sage (how much does this box weigh?). Start with df, drill down with du.

[[lab-task:3]]

## Adding a new disk, step by step

```bash
sudo fdisk /dev/sdb                  # or parted: create partition sdb1
sudo mkfs.ext4 /dev/sdb1             # put a filesystem on it (ERASES it!)
sudo mkdir -p /srv/data
sudo mount /dev/sdb1 /srv/data       # attach it into the tree
df -h /srv/data
sudo umount /srv/data                # detach (nobody may be using it)
```

A `mount` is forgotten at reboot. To make it permanent, add a line to **/etc/fstab**:

```
# device                                    mountpoint  type  options   dump pass
UUID=3f2a9c1e-...                           /srv/data   ext4  defaults  0    2
```

Use the **UUID** (from `lsblk -f` or `blkid`), not `/dev/sdb1` - device names can change between boots. Test with `sudo mount -a` **before** rebooting: a broken fstab line can stop the server from booting.

**LVM** (Logical Volume Manager) adds a flexible layer: disks become *physical volumes*, pooled into a *volume group*, carved into *logical volumes* that can grow later (`lvextend -r`). **Swap** is disk space used as overflow memory (`swapon --show`).

## Archives and compression

```bash
tar -czf backup.tar.gz dir/       # create, gzip
tar -cJf backup.tar.xz dir/       # create, xz (smaller, slower)
tar -tzf backup.tar.gz            # list contents
tar -xzf backup.tar.gz            # extract here
tar -xzf backup.tar.gz -C /tmp    # extract somewhere else
gzip big.log  /  gunzip big.log.gz      # compress a single file
zip -r site.zip site/  /  unzip site.zip
```

> **Memory hook:** tar flags read like a sentence: **c**reate **z**ipped **f**ile, e**x**tract **z**ipped **f**ile, **t**ell me what is in the **z**ipped **f**ile.

[[lab-task:4]]

[[lab-task:5]]

What you should see:

```
$ tar -tzf delivery.tar.gz
delivery/
delivery/manifest.txt
delivery/invoice.txt
```

## Copying between places: rsync

```bash
rsync -av src/ /backup/src/             # copy only what changed
rsync -av --delete src/ /backup/src/    # also delete files removed from src
rsync -avz src/ user@host:/backup/src/  # over SSH, compressed
rsync -av --dry-run src/ dst/           # show what would happen
```

The trailing slash matters: `src/` means "the contents of src", `src` means "the directory src itself".

> **End of day 7.** The new disk is mounted by UUID, the storeroom is backed up, and the delivery is unpacked. Rhea: "Tomorrow the payment provider needs to reach brewbot. Learn how atlas talks to the world." Tom's note: "Every door has a number."
