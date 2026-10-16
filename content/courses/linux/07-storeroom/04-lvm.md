---
kind: lesson
id_key: linux/storeroom/lvm
course: linux
section: storeroom
section_title: "Chapter 7: The Storeroom - Packages, Disks and Backups"
section_position: 7
title: "LVM: Flexible Storage You Can Grow Later"
position: 3
estimated_minutes: 8
source:
  - lvm(8), pvcreate(8), vgcreate(8), lvcreate(8), lvextend(8), resize2fs(8), xfs_growfs(8) manual pages
  - Red Hat Enterprise Linux documentation, "Configuring and managing logical volumes"
---

## Why this matters

`/srv/data` is full six months later. With a plain partition, growing it means
downtime and risky repartitioning. With **LVM** you add a disk and grow the
filesystem while it is mounted, in two commands. Most enterprise servers (and
the Ubuntu server installer by default) use LVM.

## Mental model: a water tank with taps

```
  disks / partitions       PV  PV  PV         physical volumes: raw capacity
                             \  |  /
  pool                         VG              volume group: one big tank
                             /  |  \
  carved volumes            LV  LV  LV         logical volumes: act like partitions
                            |    |    |
  filesystems             ext4 xfs  swap       mounted as usual
```

- **PV (physical volume)**: a disk or partition handed to LVM.
- **VG (volume group)**: all PVs pooled together.
- **LV (logical volume)**: a slice of the pool. It looks like a partition:
  `/dev/vg_data/lv_srv` (also `/dev/mapper/vg_data-lv_srv`).

You can add PVs to a VG and grow LVs at any time.

## See it work

These need root and spare disks (a VM is perfect).

```bash
sudo pvcreate /dev/vdb /dev/vdc              # 1. hand disks to LVM
sudo vgcreate vg_data /dev/vdb /dev/vdc      # 2. pool them
sudo lvcreate -n lv_srv -L 50G vg_data       # 3. carve 50 GB
sudo mkfs.ext4 /dev/vg_data/lv_srv           # 4. format and mount as usual
sudo mount /dev/vg_data/lv_srv /srv/data
```

Inspect:

```bash
sudo pvs; sudo vgs; sudo lvs
```

```
  PV         VG      Fmt  Attr PSize    PFree
  /dev/vdb   vg_data lvm2 a--  <100.00g <50.00g
  /dev/vdc   vg_data lvm2 a--  <100.00g <100.00g
  VG      #PV #LV #SN Attr   VSize   VFree
  vg_data   2   1   0 wz--n- 199.99g 149.99g
  LV     VG      Attr       LSize  ...
  lv_srv vg_data -wi-ao---- 50.00g
```

`VFree` is unallocated space in the pool.

### Growing a volume (online)

```bash
sudo lvextend -r -L +20G /dev/vg_data/lv_srv    # grow LV and filesystem
df -h /srv/data
```

`-r` (`--resizefs`) also grows the filesystem (it calls `resize2fs` for ext4 or
`xfs_growfs` for xfs). Without `-r`, the LV is bigger but `df` shows the old
size until you grow the filesystem yourself.

When the pool is empty, add a disk first:

```bash
sudo pvcreate /dev/vdd
sudo vgextend vg_data /dev/vdd
```

Shrinking is riskier: ext4 must be unmounted to shrink, and **xfs cannot shrink
at all**. Plan sizes so you only ever grow.

### Snapshots

```bash
sudo lvcreate -s -n srv_snap -L 5G /dev/vg_data/lv_srv
```

A snapshot freezes the LV's state at that instant (copy-on-write). Use it to take
a consistent backup, or before a risky upgrade; remove it after (`lvremove`),
because a full snapshot becomes invalid.

## Try it

`df -h` shows `/srv/data` (an ext4 LV in `vg_data`) at 98%, and `vgs` shows
`VFree 0`. You have a new disk `/dev/vde`. List the commands to give
`/srv/data` 50 GB more without unmounting.

<details>
<summary>Show answer</summary>

```bash
sudo pvcreate /dev/vde
sudo vgextend vg_data /dev/vde
sudo lvextend -r -L +50G /dev/vg_data/lv_srv
df -h /srv/data
```

</details>

## Common mistakes

- **`lvextend` without `-r`.** The filesystem does not grow; `df` looks
  unchanged.
- **Planning to shrink xfs.** Not possible; back up, recreate, restore.
- **Thinking LVM is a backup.** Spanning a VG over two disks means losing
  *either* disk can lose data. Use RAID for redundancy and real backups for
  safety.
- **Leaving snapshots around.** They slow writes and break when full.

## Remember

- PV (disks) -> VG (pool) -> LV (volumes) -> filesystem.
- `pvs`, `vgs`, `lvs` show each layer.
- Grow online: `vgextend` if needed, then `lvextend -r -L +SIZE`.
- Snapshots: `lvcreate -s` for consistent backups; remove afterwards.

**Self-check:**

1. What does `-r` do in `lvextend`?
2. Which filesystem cannot be shrunk?
3. Name the three LVM layers in order.
