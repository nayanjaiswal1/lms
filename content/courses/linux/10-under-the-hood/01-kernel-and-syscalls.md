---
kind: lesson
id_key: linux/under-the-hood/kernel-and-syscalls
course: linux
section: under-the-hood
section_title: "Chapter 10: Under the Hood - Kernel, Namespaces and cgroups"
section_position: 10
title: "User Space, Kernel Space, System Calls and sysctl"
position: 0
estimated_minutes: 8
source:
  - syscalls(2), strace(1), sysctl(8), sysctl.d(5), capabilities(7), modprobe(8) manual pages
  - The Linux Kernel documentation, "Documentation for /proc/sys"
---

## Why this matters

> **Thursday, week 2.** Rhea: "Before Black Friday I want you to understand what
> is really going on inside atlas." Tom's note: *look under the hood*.

When logs say nothing, the boundary between programs and the kernel still tells
the truth: which file a program tried to open, which call failed, which kernel
limit was hit. And containers, the most common way software ships in 2026, are
built from kernel features you will meet in this chapter.

## Mental model: the customer counter

Programs (user space) are customers. They cannot touch the kitchen (hardware,
other programs' memory). They place orders at a counter: **system calls**.

```
 USER SPACE      bash, nginx, python, brewbot      (restricted)
 ----------------------- system call boundary -----------------------
                 open() read() write() fork() execve() connect() kill() ...
 KERNEL SPACE    scheduler, memory, filesystems, network stack, drivers
 ----------------------------------------------------------------------
 HARDWARE
```

- Every file read, network packet, new process and signal is a system call.
- When a call fails, the kernel returns an error code (`ENOENT` no such file,
  `EACCES` permission denied, `ENOSPC` no space). Those are the messages you see
  in logs.

## See it work

### strace: watch the orders

`strace` (install it with `apt install strace`; not in the lab image) shows each
system call a program makes:

```bash
strace -e trace=openat cat /etc/hostname
```

Expected output (abridged):

```
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/etc/hostname", O_RDONLY) = 3
atlas
```

The killer use: a program fails with a vague error. `strace -f -e trace=file
./brewbot` shows exactly which path it tried and got `ENOENT` or `EACCES` for.
`strace -p PID` attaches to a running process (what is that hung worker waiting
for?). `-c` prints a summary of calls and time.

### sysctl: kernel settings at runtime

Kernel tunables live under `/proc/sys`. `sysctl` reads and writes them with dots
instead of slashes:

```bash
cat /proc/sys/kernel/pid_max
sysctl kernel.pid_max vm.swappiness
```

Expected output (values vary):

```
4194304
kernel.pid_max = 4194304
vm.swappiness = 60
```

Changing them needs root:

```bash
sudo sysctl -w net.core.somaxconn=4096              # now, until reboot
echo 'net.core.somaxconn = 4096' | sudo tee /etc/sysctl.d/90-brewbot.conf
sudo sysctl --system                                # reload all files
```

Common ones: `vm.swappiness` (how eagerly to swap), `fs.file-max` (system-wide
open files), `net.ipv4.ip_forward` (route packets, needed by containers and
VPNs), `net.core.somaxconn` (listen queue length).

### Kernel modules

Drivers and features load as **modules**:

```bash
lsmod | head            # loaded modules
sudo modprobe br_netfilter   # load one (with its dependencies)
modinfo ext4            # details
```

### Capabilities: root split into pieces

Root's power is split into about 40 **capabilities**, such as
`CAP_NET_BIND_SERVICE` (ports below 1024) or `CAP_SYS_ADMIN` (almost
everything). A program can get just one:

```bash
sudo setcap cap_net_bind_service=+ep /opt/brewbot/bin/brewbot
getcap /opt/brewbot/bin/brewbot
grep Cap /proc/$$/status      # your shell's capability sets (hex)
```

Containers drop most capabilities by default; that is part of why they are safer
than plain root.

## Try it

Brewbot logs only "failed to start". Which tool shows the exact file it tried to
open, and what error code would mean "permission denied"?

<details>
<summary>Show answer</summary>

`strace -f -e trace=file /opt/brewbot/bin/brewbot` (or `-e trace=openat`). Look
for a line ending in `= -1 EACCES (Permission denied)`; `ENOENT` would mean the
file does not exist.

</details>

## Common mistakes

- **`sysctl -w` without a file in `/etc/sysctl.d/`.** The change is gone after
  reboot.
- **Tuning kernel knobs from blog posts.** Measure first; most defaults are good.
- **`strace` on production at full speed.** It slows the traced program a lot.
  Trace briefly, or filter with `-e`.
- **Running a service as root just for port 80.** Grant one capability instead.

## Remember

- Programs ask the kernel for everything through system calls.
- `strace -e trace=file CMD` / `strace -p PID` show calls and errors
  (`ENOENT`, `EACCES`, `ENOSPC`).
- `/proc/sys` = live tunables; `sysctl` reads/writes; persist in
  `/etc/sysctl.d/`.
- Capabilities split root's power; `setcap`, `getcap`.

**Self-check:**

1. What is a system call?
2. How do you make a sysctl change survive a reboot?
3. Which capability lets a program bind port 80 without root?
