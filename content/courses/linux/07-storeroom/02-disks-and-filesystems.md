---
kind: lesson
id_key: linux/storeroom/disks-and-filesystems
course: linux
section: storeroom
section_title: "Chapter 7: The Storeroom - Packages, Disks and Backups"
section_position: 7
title: "Disks, Partitions and Filesystems: lsblk, df and du"
position: 1
estimated_minutes: 7
source:
  - lsblk(8), df(1), du(1), blkid(8), ext4(5), xfs(5) manual pages
---

## Why this matters

"Disk 95% full" is a page you will get. You must answer three questions fast:
*which* disk, *what* is filling it, and is it space or inodes? You also need to
know what the new disk in the delivery box is before you can use it.

## Mental model: shelves, boxes, labels

```
  /dev/sda            the whole first disk (SATA/SCSI/virtual)
  |-- /dev/sda1       partition 1  -> ext4  mounted at /boot
  `-- /dev/sda2       partition 2  -> ext4  mounted at /
  /dev/nvme0n1p1      NVMe disk 0, partition 1
  /dev/vdb            the new (virtual) disk - not partitioned yet
```

- A **disk** (block device) is the raw shelf.
- A **partition** divides it into sections.
- A **filesystem** organises a partition into files, directories and inodes.
- **Mounting** attaches a filesystem to a directory in the one tree (next
  lesson).

Common filesystems: **ext4** (Linux default), **xfs** (RHEL default, large
files), **btrfs** (snapshots, checksums), **vfat** (USB sticks, the EFI
partition), **tmpfs** (in RAM), **overlay** (container layers).

> **Memory hook:** **df** = **d**isk **f**ree, how full is the whole shelf?
> **du** = **d**isk **u**sage, how much does this box weigh? Start with df,
> drill down with du.

## See it work

```bash
lsblk
lsblk -f            # add filesystem type, label, UUID
```

Expected output on a typical VM (abridged):

```
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda     252:0    0   40G  0 disk
├─vda1  252:1    0   39G  0 part /
├─vda15 252:15   0  106M  0 part /boot/efi
vdb     252:16   0  100G  0 disk
```

`vdb` has no partitions and no mount point: that is the new disk.

```bash
df -h
```

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1        38G   31G  6.6G  83% /
/dev/vda15      105M  6.1M   99M   6% /boot/efi
tmpfs           2.0G     0  2.0G   0% /dev/shm
```

`-h` = human sizes. Read the `Use%` and `Mounted on` columns first. In the lab
container you will see `overlay` on `/`: a container filesystem.

### Inodes can run out too

```bash
df -i /
```

```
Filesystem      Inodes   IUsed   IFree IUse% Mounted on
/dev/vda1      2523136 2523136       0  100% /
```

100% `IUse%` with free space left means millions of tiny files used every inode.
New files fail with "No space left on device" even though `df -h` shows space.

### Drilling down

```bash
sudo du -xh --max-depth=1 / 2>/dev/null | sort -h | tail
```

What this does: one total per top-level directory, `-x` stays on this
filesystem (skips `/proc` and other mounts), sorted with the biggest last.
Repeat on the biggest directory until you find the culprit.

## Try it

Under `~/work/storeroom` there are three shelves. Which command tells you which
one is heaviest?

<details>
<summary>Show answer</summary>

```bash
du -sh ~/work/storeroom/* | sort -h
```

The last line is the heaviest.

</details>

## Common mistakes

- **Starting with `du /`.** Slow and noisy. `df -h` first to find the full
  filesystem, then `du -x` on it.
- **Forgetting `df -i`.** "No space left" with free space = inodes.
- **Confusing partitions with mount points.** `/dev/vda1` is the device, `/` is
  where it appears.
- **Running `du` across mounts.** Without `-x`, you also count other disks and
  network shares.

## Remember

- Disk, partition, filesystem, mount point.
- `lsblk -f` = what devices exist and what is on them.
- `df -h` = how full each filesystem is; `df -i` = inodes.
- `du -xh --max-depth=1 DIR | sort -h` = what is heavy.

**Self-check:**

1. What does `df -i` show?
2. Why add `-x` to `du`?
3. How do you spot a new, unused disk in `lsblk`?
