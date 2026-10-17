---
kind: lesson
id_key: linux/incident-week/disk-scenarios
course: linux
section: incident-week
section_title: "Chapter 13: Incident Week - Troubleshooting Playbook"
section_position: 13
title: "Disk Scenarios: Full, Deleted-but-Open, Inodes, Read-Only"
position: 1
estimated_minutes: 8
source:
  - df(1), du(1), lsof(8), truncate(1), fsck(8), journalctl(1) manual pages
---

## Why this matters

"No space left on device" breaks databases, logs, deploys and logins all at
once. It is the most common outage there is, and it has four different causes
that look alike. Telling them apart takes four commands.

## Mental model: four ways a shelf is "full"

```
 1. Really full          df -h 100%                  -> find the big stuff (du)
 2. Full, nothing big    df -h 100%, du adds up less  -> deleted file still open (lsof +L1)
 3. Space but no slots   df -h 40%, df -i 100%        -> millions of tiny files (inodes)
 4. Can't write at all   "Read-only file system"      -> kernel protected a damaged FS
```

## Scenario 1: "No space left on device"

**Symptom:** writes fail, services crash, `No space left on device` in logs.

```bash
df -h                                             # which filesystem is full?
sudo du -xh / 2>/dev/null | sort -h | tail -20    # -x stays on that filesystem
sudo find / -xdev -type f -size +500M 2>/dev/null
sudo journalctl --vacuum-size=200M                # shrink the journal
sudo apt clean                                    # drop downloaded package files
```

**Fix:** empty or compress the giant log with `truncate -s 0 FILE` (not `rm` if a
process has it open), delete old rotated logs and backups. **Prevent:**
logrotate, a disk alert at 80%, a separate `/var` partition or LVM headroom.

`truncate -s 0 FILE` and `: > FILE` both empty a file **in place**: same inode,
so a process writing to it keeps working and the space is freed immediately.

## Scenario 2: df says full, du says not

You deleted a 20 GB log but `df` still says 100%. A process still has the
deleted file **open**, so its inode and blocks live on (chapter 2: data is freed
only when no name and no open handle remain).

```bash
sudo lsof +L1                    # open files with zero links (deleted)
sudo lsof | grep '(deleted)'
ls -l /proc/*/fd 2>/dev/null | grep deleted    # without lsof
```

```
COMMAND  PID    USER  FD  TYPE DEVICE    SIZE/OFF NLINK  NODE NAME
brewbot 1040 brewbot   4w  REG  252,1 21474836480     0 13107 /var/log/brewbot/debug.log (deleted)
```

**Fix:** restart the process that holds it (`systemctl restart brewbot`), or
truncate it through `/proc`: `: > /proc/1040/fd/4`. **Lesson:** truncate logs,
do not `rm` them while in use.

## Scenario 3: space left but writes fail (inodes)

`df -h` shows 40% used, yet files cannot be created. `df -i` shows 100%
`IUse%`: millions of tiny files (sessions, cache, mail queue) used every inode.

```bash
df -i
sudo find /var -xdev -type f | cut -d/ -f2-4 | sort | uniq -c | sort -rn | head
```

**Fix:** delete the junk files (for example
`find /var/lib/php/sessions -mtime +2 -delete`) and fix the app that creates
them.

## Scenario 4: "Read-only file system"

The kernel remounts a filesystem read-only when it detects errors, to protect
your data.

```bash
dmesg -T | grep -iE 'ext4|xfs|i/o error|remount'
findmnt -no OPTIONS /            # ro,... ?
```

**Fix:** check the disk's health (`smartctl -a`, cloud provider status),
schedule `fsck` on the unmounted filesystem (or from recovery mode for `/`), and
restore from backup if the disk is failing. Do not just force a remount
read-write.

## Try it

`df -h /` says 100%. `sudo du -xsh /` says 31G of a 40G disk. What explains the
missing 9 GB, and which command proves it?

<details>
<summary>Show answer</summary>

Space held by deleted files that a process still has open: `du` cannot see them
(no name), but `df` counts them. `sudo lsof +L1` lists them with the owning
process. Restart that process or truncate via `/proc/PID/fd/N`.

</details>

## Common mistakes

- **`rm` on an open log.** Frees nothing; use `truncate -s 0`.
- **Forgetting `df -i`.** "No space" with free space is inodes.
- **`du /` without `-x`.** Counts `/proc` and other mounts and takes forever.
- **Remounting a failing disk read-write.** You may destroy what is left.

## Remember

- Full: `df -h`, then `du -xh | sort -h`, truncate big logs.
- df full, du not: `lsof +L1`; restart the holder or truncate via `/proc`.
- Inodes: `df -i`, find directories with millions of files.
- Read-only: `dmesg`, then fsck and disk health; never force rw.

**Self-check:**

1. Why does `truncate -s 0` free space when `rm` did not?
2. Which command lists deleted-but-open files?
3. What does a sudden read-only root filesystem usually mean?
