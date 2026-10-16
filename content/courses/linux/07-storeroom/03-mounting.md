---
kind: lesson
id_key: linux/storeroom/mounting
course: linux
section: storeroom
section_title: "Chapter 7: The Storeroom - Packages, Disks and Backups"
section_position: 7
title: "Adding a Disk: Partition, mkfs, mount, fstab and Swap"
position: 2
estimated_minutes: 8
source:
  - fdisk(8), parted(8), mkfs(8), mount(8), umount(8), fstab(5), findmnt(8), swapon(8), mkswap(8) manual pages
---

## Why this matters

The new 100 GB disk must hold the shop's data at `/srv/data` and still be there
after a reboot. One wrong line in `/etc/fstab` can stop the server from booting.
These steps need root, so practise them on a spare VM.

## Mental model: shelf, labels, and the floor plan

```
 /dev/vdb  --(parted/fdisk)-->  /dev/vdb1  --(mkfs.ext4)-->  filesystem
                                                                |
                                         mount /dev/vdb1 /srv/data
                                                                v
                                     /srv/data now shows the new disk
 /etc/fstab = the floor plan: which filesystem goes where at every boot
```

## See it work

### 1. Partition and format

```bash
sudo parted /dev/vdb --script mklabel gpt mkpart data ext4 0% 100%
sudo mkfs.ext4 -L data /dev/vdb1      # ERASES everything on vdb1
lsblk -f /dev/vdb
```

Expected output:

```
NAME   FSTYPE LABEL UUID                                 MOUNTPOINTS
vdb
└─vdb1 ext4   data  3f2a9c1e-5b1d-4c8e-9a77-0d5e2f1c9b10
```

`fdisk /dev/vdb` is the interactive alternative to `parted`. Triple-check the
device name: `mkfs` on the wrong disk destroys it.

### 2. Mount it

```bash
sudo mkdir -p /srv/data
sudo mount /dev/vdb1 /srv/data
df -h /srv/data
findmnt /srv/data          # where is it mounted, with which options?
sudo umount /srv/data      # detach (fails with "target is busy" if in use)
```

A mount point is just an empty directory. Anything that was in it is hidden
(not deleted) while something is mounted on top.

### 3. Make it permanent: /etc/fstab

`mount` is forgotten at reboot. Add a line to **`/etc/fstab`**:

```
# device                                    mountpoint  type  options          dump pass
UUID=3f2a9c1e-5b1d-4c8e-9a77-0d5e2f1c9b10   /srv/data   ext4  defaults,nofail  0    2
```

- Use the **UUID** (from `lsblk -f` or `blkid`), not `/dev/vdb1`: device names
  can change between boots.
- `nofail`: boot continues if this disk is missing (good for data disks).
- `pass 2`: check this filesystem with `fsck` after the root (which uses 1).

Test **before** rebooting:

```bash
sudo umount /srv/data
sudo mount -a              # mounts everything in fstab; errors show NOW
findmnt --verify           # checks fstab syntax
```

A broken fstab line found by `mount -a` is a 10-second fix. Found at boot, it can
drop the server into emergency mode.

Useful mount options: `ro` (read-only), `noexec` (no programs run from here),
`nosuid`, `nodev` (good for `/tmp` and upload directories).

### Swap

**Swap** is disk space used as overflow when RAM is full. It is slow, but it
lets the kernel move idle memory out of the way instead of killing processes.

```bash
swapon --show                       # current swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Try it

You added a line to `/etc/fstab` for `/srv/data`. Before you reboot, which
command proves the line works, and why use a UUID instead of `/dev/vdb1`?

<details>
<summary>Show answer</summary>

`sudo mount -a` (after `umount`) mounts every fstab entry now and shows errors
immediately; `findmnt --verify` checks syntax. UUIDs belong to the filesystem
and never change, while device names like `vdb` can be reordered when disks are
added or removed.

</details>

## Common mistakes

- **`mkfs` on the wrong device.** Check `lsblk` twice; data disks rarely have
  partitions mounted on `/`.
- **Rebooting without `mount -a`.** A typo in fstab can prevent boot.
- **`/dev/sdX` in fstab.** Use `UUID=` or `LABEL=`.
- **"target is busy" on umount.** Someone is inside: `cd` out, or find them with
  `sudo lsof +D /srv/data` / `fuser -vm /srv/data`.

## Remember

- Partition (`parted`/`fdisk`), format (`mkfs.ext4`), mount, then fstab.
- fstab: `UUID=... /mnt ext4 defaults,nofail 0 2`.
- Always `sudo mount -a` before rebooting.
- Swap = slow overflow memory; `swapon --show`.

**Self-check:**

1. What happens to files already inside a directory when you mount on it?
2. What does `nofail` do?
3. Which command shows the UUID of a filesystem?
