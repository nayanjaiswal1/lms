---
kind: lesson
id_key: linux/meet-atlas/filesystem-map
course: linux
section: meet-atlas
section_title: "Chapter 1: Meet Atlas - the Shell and the Map"
section_position: 1
title: "The Filesystem Map: One Tree from /"
position: 2
estimated_minutes: 8
source:
  - Filesystem Hierarchy Standard 3.0 (refspecs.linuxfoundation.org/fhs.shtml)
  - hier(7), file-hierarchy(7) manual pages
---

## Why this matters

Tom's first note on the wall said: *learn the map before you touch anything.*
When brewbot breaks at 2am you must know, without searching, that its config is
in `/etc` and its logs are in `/var/log`. Every Linux machine uses the same map.

## Mental model: one tree, no drive letters

Linux has **one** directory tree. It starts at `/`, called **root** (not to be
confused with the root user). There is no `C:` or `D:`. A second disk is
**mounted**: attached as a folder somewhere inside the tree.

```
/                       the root of everything
|-- bin  -> usr/bin     essential commands (ls, cp, bash)
|-- sbin -> usr/sbin    system admin commands (fdisk, reboot)
|-- etc                 configuration files (plain text!)
|-- home                users' personal folders  (/home/labuser)
|-- root                the root user's home
|-- var                 data that changes: logs, caches, mail, databases
|   `-- log             <- you will live here during incidents
|-- tmp                 temporary files, may be wiped on reboot
|-- usr                 installed programs, libraries, docs
|-- opt                 optional third-party software
|-- srv                 data this machine serves (websites, repos)
|-- dev                 devices as files (disks: /dev/sda, /dev/nvme0n1)
|-- proc                live view of processes and the kernel
|-- sys                 live view of hardware and drivers
|-- run                 runtime data since boot (PID files, sockets)
|-- mnt, media          mount points for extra disks / USB sticks
`-- boot                kernel and bootloader files
```

> **Memory hook, the coffee shop map:** `/etc` = the recipe binder (config) ·
> `/var` = the till receipts, they **var**y (logs) · `/home` = staff lockers ·
> `/tmp` = the counter, wiped every night · `/usr` = the equipment ·
> `/proc` = the live order screen · `/dev` = the machines themselves.

On modern distros (Ubuntu, Fedora, Debian 12+) `/bin`, `/sbin` and `/lib` are
just **symlinks** (shortcuts) into `/usr`. This is called "merged /usr".

## Everything is a file

The Linux motto: if it exists, it shows up as a file somewhere.

- Your disk is the file `/dev/sda` (or `/dev/nvme0n1`).
- A running process is the folder `/proc/<number>`.
- Configuration is plain text in `/etc`, readable with any text tool.

That is why the same few tools (`cat`, `ls`, `grep`) work on config, logs,
hardware info and processes.

## See it work

```bash
ls /
```

What this does: lists the top of the tree. Expected output (similar):

```
bin   dev  home  lib64  mnt  proc  run   srv  tmp  var
boot  etc  lib   media  opt  root  sbin  sys  usr
```

```bash
ls -l /bin
```

```
lrwxrwxrwx 1 root root 7 Apr 22  2024 /bin -> usr/bin
```

The `l` at the start and the arrow show `/bin` is a symlink into `/usr/bin`.

```bash
head -5 /proc/cpuinfo     # the kernel shows CPU details as a "file"
ls /var/log               # where the logs live
```

`/proc/cpuinfo` is not on any disk. The kernel generates its content the moment
you read it.

## Where things go: a quick decision table

| You are looking for... | Look in |
|---|---|
| a service's config | `/etc/<service>/` or `/etc/<service>.conf` |
| a service's logs | `/var/log/` (or the journal, chapter 6) |
| a program's binary | `/usr/bin`, `/usr/sbin`, `/usr/local/bin`, `/opt/<app>/bin` |
| software you installed by hand | `/usr/local/` or `/opt/` (never inside `/usr` directly) |
| a user's files | `/home/<user>/` |
| website or data files served | `/srv/` or `/var/www/` |
| disk devices | `/dev/` |

## Try it

A colleague asks where three things would live on atlas: brewbot's config file,
brewbot's log file, and the binary of a tool you compiled yourself. Answer with
paths.

<details>
<summary>Show answer</summary>

Config: `/etc/brewbot/brewbot.conf` (or `/etc/brewbot.conf`). Logs:
`/var/log/brewbot/`. Your own compiled tool: `/usr/local/bin/` (or
`/opt/brewbot/bin/` if it is a self-contained application). Package-managed
programs live in `/usr/bin`; keep hand-installed ones out of there so the package
manager never overwrites them.

</details>

## Common mistakes

- **Saving important data in `/tmp`.** It is for scratch files and may be emptied
  at every boot.
- **Hunting for config in `/usr`.** Config belongs in `/etc`. `/usr` should be
  treated as read-only, owned by the package manager.
- **Confusing `/` (the root directory) with `/root` (root user's home).** Same
  word, different things.
- **Thinking `/proc` uses disk space.** It is virtual; `du` on it is meaningless.

## Remember

- One tree from `/`; extra disks are mounted inside it.
- `/etc` config, `/var/log` logs, `/home` users, `/tmp` scratch, `/usr` programs.
- `/proc` and `/sys` are live kernel views; `/dev` holds devices.
- Everything is a file, so text tools work everywhere.

**Self-check:**

1. Where are configuration files kept?
2. What is the difference between `/` and `/root`?
3. Why can you `cat /proc/cpuinfo` even though no such file is on disk?
