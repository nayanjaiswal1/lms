---
kind: lesson
id_key: linux/meet-atlas/roadmap
course: linux
section: meet-atlas
section_title: "Chapter 1: Meet Atlas - the Shell and the Map"
section_position: 1
title: "Big Picture: What Linux Is and How This Course Works"
position: 0
estimated_minutes: 7
source:
  - The Linux Kernel documentation, "The Linux kernel user's and administrator's guide" (docs.kernel.org)
  - bash(1), hier(7) manual pages
---

## Why this matters

> **Monday, 9:00.** You are the new junior sysadmin at **Orbit Coffee**, a small
> roastery that sells beans online. Rhea, the ops lead, slides a laptop across the
> desk: "Everything we sell runs on one Linux server called **atlas**. Our old
> admin, Tom, left last month. He hid notes all over the box. Learn atlas, and by
> the end of the month you are on call."

Most servers, containers, cloud machines and phones run Linux. If you can read a
Linux box calmly, you can debug almost anything that runs on it. This lesson
gives you the map before the details.

## Mental model: a coffee shop with layers

Think of atlas as a coffee shop. You never walk into the kitchen. You ask the
barista, and the barista asks the kitchen.

```
 +------------------------------------------------+
 |  YOU (customers)        type commands          |
 +------------------------------------------------+
 |  SHELL (the barista)    bash reads & runs them |
 +------------------------------------------------+
 |  PROGRAMS (the tools)   ls, grep, nginx, ...   |
 +------------------------------------------------+
 |  KERNEL (the kitchen)   CPU, memory, disks,    |
 |                         network, processes     |
 +------------------------------------------------+
 |  HARDWARE (the building)                       |
 +------------------------------------------------+
```

Four words you will hear every day:

- **Kernel**: the core program. It shares the CPU between programs, hands out
  memory, and talks to disks and the network. Strictly, "Linux" is only this
  kernel.
- **Distribution (distro)**: the kernel plus tools plus a package manager, bundled
  and tested together. Examples: Ubuntu, Debian, Fedora, RHEL, Rocky, Alpine,
  Arch. Atlas runs **Ubuntu**.
- **Shell**: the program that reads what you type and asks the kernel to run it.
  On most systems that is **bash**.
- **Terminal**: the window the shell lives in. Over the network you reach it with
  SSH.

> **One-sentence definition:** Linux is a kernel; a distribution is that kernel
> plus everything you need to use it; the shell is how you talk to both.

> **Memory hook:** *Kernel = kitchen, Shell = barista.*

## See it work

Ask atlas who it is. Each line is one command; the text after `#` is a comment
the shell ignores.

```bash
uname -r              # kernel release
cat /etc/os-release   # which distribution
```

What this does: `uname -r` asks the running kernel for its version. The file
`/etc/os-release` describes the distro. Expected output (your numbers will
differ):

```
6.8.0-45-generic
PRETTY_NAME="Ubuntu 24.04.1 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
...
```

The kernel version and the distro version are different things. Ubuntu 24.04 can
run many kernel versions over its life.

## The road ahead

The course follows your first weeks on atlas. Each chapter is one skill area,
split into short lessons, then a hands-on lab on a real Linux machine and a quiz.

| Chapter | You learn to... |
|---|---|
| 1 Meet Atlas | use the shell, read the filesystem map, get help, set your PATH |
| 2 Moving In | create, copy, move, delete, find and link files |
| 3 The Logbook | read text, grep, pipes, redirection, sort/uniq, awk, sed |
| 4 Keys and Locks | users, groups, permissions, special bits, umask, sudo, ACLs |
| 5 The Engine Room | processes, /proc, jobs, signals, priorities |
| 6 The Night Shift | boot, systemd, unit files, journald, cron and timers, logrotate |
| 7 The Storeroom | packages, disks, mounts, LVM, swap, archives, rsync |
| 8 Talking to the World | IP, ports, ss, curl, DNS, SSH, firewalls |
| 9 Teaching Atlas Tricks | Bash scripting |
| 10 Under the Hood | system calls, kernel tuning, namespaces, cgroups |
| 11 Performance Triage | the USE method, CPU, memory, disk IO |
| 12 Locking Down Atlas | security hardening and auditing |
| 13 Incident Week | a troubleshooting playbook and a live incident lab |

Every lesson has the same shape: **Why this matters, Mental model, See it work,
Try it, Common mistakes, Remember**. The labs check your work automatically.

## How to study this course

- **Type every command yourself.** Reading `ls -la` is not the same as seeing its
  output scroll by.
- **Answer the self-check questions out loud** before you look anything up.
  Effortful recall is what makes things stick.
- **Come back.** The final chapter has a flashcard page. Use it tomorrow, in three
  days and in a week.

## Try it

Without scrolling up: which layer decides which program gets the CPU next, the
shell or the kernel? And which one would you replace if you switched from bash to
zsh?

<details>
<summary>Show answer</summary>

The kernel schedules the CPU. The shell is just one program among many; switching
from bash to zsh replaces the shell and leaves the kernel untouched.

</details>

## Common mistakes

- **Treating "Linux" and "Ubuntu" as the same thing.** Ubuntu is one distro built
  on the Linux kernel. Commands like `apt` are Ubuntu/Debian, not "Linux".
- **Thinking the terminal is the shell.** The terminal is the window; bash is the
  program inside it. You can run a different shell in the same window.
- **Expecting a server to have a desktop.** Servers usually have no graphical
  interface at all. The shell is the interface.

## Remember

- Layers: hardware, kernel, programs, shell, you.
- Kernel = core that shares hardware; distro = kernel + tools; shell = command
  interpreter (bash).
- `uname -r` shows the kernel; `/etc/os-release` shows the distro.
- Study by typing, recalling and revisiting.

**Self-check:**

1. What is the difference between a kernel and a distribution?
2. Which file tells you the distro name and version?
3. Name the six parts of the lesson skeleton used in this course.
