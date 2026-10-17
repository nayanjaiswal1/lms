-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-10-16T19:07:57Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Linux: The Atlas Story ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, is_public, estimated_hours)
VALUES ('ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Linux: The Atlas Story', 'linux', 'Learn Linux by living it. You join Orbit Coffee as the new junior sysadmin and inherit "atlas", the server that runs the whole shop. Short, one-idea lessons take you from the shell and the filesystem map through text tools, users and permissions, processes, systemd and logs, packages and storage (including LVM), networking and SSH, and Bash scripting, then under the hood to system calls, namespaces and cgroups, performance triage, and security hardening. Every chapter ends with a hands-on terminal lab and a quiz; the last chapter is Incident Week, a troubleshooting playbook with real outage scenarios to fix, followed by flashcards and a final exam.', '/course-covers/linux.svg', 'beginner', ARRAY['linux','bash','sysadmin','devops','cli'], 'published', true, false, 17.6)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, is_public=EXCLUDED.is_public, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

UPDATE course_sections SET position = position + 100000 WHERE course_id = 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf';
UPDATE course_modules SET position = position + 100000 WHERE course_id = 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf';

-- Section: Chapter 1: Meet Atlas - the Shell and the Map
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('4078896b-224c-5318-8a4a-c389cca4bece', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 1: Meet Atlas - the Shell and the Map', 1, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b6b1f456-2e0a-52f7-8b19-57626f5ccdf3', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '4078896b-224c-5318-8a4a-c389cca4bece', 'Big Picture: What Linux Is and How This Course Works', 'notes', 0, $md$## Why this matters

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
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('76428f04-341c-5a99-a241-aab2f94c6fb1', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '4078896b-224c-5318-8a4a-c389cca4bece', 'Your First Commands: the Prompt and Command Anatomy', 'notes', 1, $md$## Why this matters

Rhea gives you an SSH session on atlas. A blinking cursor, nothing else. Before
you can fix anything you must read the prompt, type a command the right way, and
recover when a command hangs. Every later lesson builds on this.

## Mental model: a sentence with a verb

A command line is a sentence. The first word is the **verb** (the program). The
rest are **options** (how to do it) and **arguments** (what to do it to).

```
  ls      -l -h        /var/log
  |       |            |
  verb    options      argument
 (program) (start with -) (what to act on)
```

- Short options are one letter after one dash: `-l`. You can bundle them: `-lh`
  is the same as `-l -h`.
- Long options use two dashes and a word: `--human-readable`.
- Spaces separate words. That is why file names with spaces cause trouble later.

The **prompt** tells you who and where you are before you type anything:

```
labuser@atlas:~/work$
   |      |     |   |
  user  host  where  $ = normal user   (# = root, the superuser)
```

`~` is short for your home directory (`/home/labuser`). **Root** is the
all-powerful administrator account; a `#` prompt means every command can change
anything.

## See it work

```bash
whoami          # which user am I?
hostname        # which machine am I on?
uname -a        # everything the kernel says about itself
date            # current date and time
```

What this does: four tiny programs, each answering one question. Expected output
(yours will differ):

```
labuser
atlas
Linux atlas 6.8.0-45-generic #45-Ubuntu SMP ... x86_64 GNU/Linux
Wed Oct 14 09:12:44 UTC 2026
```

Now an option and an argument together:

```bash
ls -l /etc/hostname
```

```
-rw-r--r-- 1 root root 6 Oct  1 08:00 /etc/hostname
```

`ls` listed one file (`/etc/hostname`) in long format (`-l`). You will learn to
read every column of that line in chapter 4.

### Keys that save you every day

| Key | What it does |
|---|---|
| **Tab** | complete a command or file name (press twice to see choices) |
| **Up / Down** | walk through previous commands |
| **Ctrl+R** | search your history: type part of an old command |
| **Ctrl+C** | stop (interrupt) the running command |
| **Ctrl+D** | end of input; in an empty prompt it logs you out |
| **Ctrl+L** | clear the screen (same as `clear`) |
| **Ctrl+A / Ctrl+E** | jump to start / end of the line |

```bash
history | tail -3     # your last three commands, numbered
!!                    # run the previous command again
```

`history` prints the list; `!!` repeats the last line. A common use is
`sudo !!` when you forgot `sudo`.

## Try it

You typed `sleep 100` and the prompt disappeared. What happened and how do you
get the prompt back? Then: what is the verb, the option and the argument in
`tail -n 5 /var/log/syslog`?

<details>
<summary>Show answer</summary>

`sleep 100` waits 100 seconds in the foreground, so the shell waits too. Press
**Ctrl+C** to stop it. In `tail -n 5 /var/log/syslog`, `tail` is the verb, `-n 5`
is an option with its own value (5 lines), and `/var/log/syslog` is the argument.

</details>

## Common mistakes

- **Forgetting that Linux is case-sensitive.** `LS`, `Ls` and `ls` are different
  words; only `ls` exists. The same goes for file names: `Notes.txt` and
  `notes.txt` are two files.
- **Typing a long path by hand.** Use Tab. It is faster and it proves the path
  exists: if Tab does not complete, the file is not there.
- **Working as root for everything.** A typo as root can destroy the system. Stay
  a normal user and borrow root only when needed (chapter 4 covers `sudo`).
- **Pasting commands you do not understand.** Read each word first. You now know
  how: verb, options, arguments.

## Remember

- Command anatomy: `program -options arguments`.
- Prompt: `user@host:directory$`; `#` means root.
- Tab completes, Up recalls, Ctrl+R searches, Ctrl+C stops.
- Linux is case-sensitive, everywhere.

**Self-check:**

1. What does a `#` at the end of the prompt mean?
2. Which key stops a command that is still running?
3. How do you repeat the previous command?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('aa12b2c0-47fd-5b45-9e77-b3f8d51102fb', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '4078896b-224c-5318-8a4a-c389cca4bece', 'The Filesystem Map: One Tree from /', 'notes', 2, $md$## Why this matters

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
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ed92d13b-2c45-5056-9163-73173039c990', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '4078896b-224c-5318-8a4a-c389cca4bece', 'Moving Around: pwd, ls, cd and Paths', 'notes', 3, $md$## Why this matters

Tom hid notes in folders all over atlas, some of them hidden. To find them you
need three commands and one idea: the difference between an absolute and a
relative path. Most "No such file or directory" errors come from mixing them up.

## Mental model: you are standing somewhere

The shell always stands in one directory, the **working directory**. Paths are
directions.

- An **absolute path** starts at `/`: a full postal address. It works from
  anywhere.
- A **relative path** starts from where you stand: "two doors down". It only
  works from the right place.

```
 absolute: /home/labuser/work/atlas      always starts with /
 relative: work/atlas                    starts from where you are

 .  = this directory
 .. = the parent (one level up)
 ~  = your home directory
 -  = (with cd) the previous directory
```

## See it work

```bash
pwd                     # print working directory: "where am I?"
```

```
/home/labuser
```

```bash
cd /var/log             # absolute path: jump straight there
pwd
cd ..                   # one level up
pwd
cd                      # no argument: go home
pwd
```

What this does: moves around and confirms each step. Expected output:

```
/var/log
/var
/home/labuser
```

`cd -` returns to the previous directory, handy when you bounce between two
places.

### Listing what is here

```bash
ls              # names only
ls -l           # long: permissions, owner, size, date
ls -a           # all, including hidden dot-files
ls -la          # both
ls -lh          # human sizes (4.0K, 12M)
ls -lt          # newest first
```

A file whose name starts with `.` is **hidden**: `ls` skips it, `ls -a` shows
it. That is only a naming convention, not security. Config files in your home
(`.bashrc`, `.ssh/`) are hidden so they do not clutter listings.

```bash
ls -la ~
```

```
drwxr-x--- 4 labuser labuser 4096 Oct 14 09:00 .
drwxr-xr-x 3 root    root    4096 Oct  1 08:00 ..
-rw-r--r-- 1 labuser labuser 3771 Oct  1 08:00 .bashrc
drwxrwxr-x 3 labuser labuser 4096 Oct 14 09:00 work
```

Every directory contains `.` (itself) and `..` (its parent). The first letter
`d` marks a directory, `-` a regular file.

## Try it

You are in `/home/labuser/work`. Write two different commands that take you to
`/home/labuser/work/atlas/etc`: one with an absolute path, one relative. Then:
which `ls` option would reveal a folder named `.archive`?

<details>
<summary>Show answer</summary>

Absolute: `cd /home/labuser/work/atlas/etc`. Relative: `cd atlas/etc`. Also
valid: `cd ~/work/atlas/etc`. `ls -a` (or `ls -la`) shows names starting with a
dot.

</details>

## Common mistakes

- **Using a relative path from the wrong place.** `cd atlas` fails in `/tmp`
  because there is no `/tmp/atlas`. Run `pwd` when in doubt.
- **Forgetting the leading `/`.** `cd var/log` means "`var/log` below here", not
  the system's `/var/log`.
- **Typing spaces in names without quotes.** `cd my notes` tries to go to `my`.
  Use `cd "my notes"` or Tab completion, which adds `\ ` for you.
- **Believing hidden means protected.** Anyone who can list the folder can run
  `ls -a`. Use permissions (chapter 4) to protect files.

## Remember

- `pwd` where am I, `ls` what is here, `cd` go there.
- Absolute paths start with `/`; relative paths start from the current directory.
- `.` here, `..` up, `~` home, `cd -` back.
- Dot-files are hidden from `ls`; `ls -a` shows them.

**Self-check:**

1. What does `cd` with no arguments do?
2. Is `../logs` absolute or relative?
3. Which option makes `ls` show sizes like `12M`?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('fda98f02-7987-58e5-9ee8-2bd0421ecf2c', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '4078896b-224c-5318-8a4a-c389cca4bece', 'Getting Help Without Google: man, --help, type and which', 'notes', 4, $md$## Why this matters

The server room has no internet, and at 2am nobody answers chat. Linux ships its
own documentation. Knowing how to ask atlas itself is faster than searching the
web, and the answer always matches the version actually installed.

## Mental model: three kinds of help

| Question | Ask |
|---|---|
| "Remind me of the options" | `command --help` (short summary) |
| "Explain it fully" | `man command` (the manual page) |
| "What *is* this word I typed?" | `type word`, `which word` |

Manual pages are split into numbered **sections**. You will use three:

- **1** user commands (`man 1 passwd`: the command)
- **5** file formats (`man 5 passwd`: the `/etc/passwd` file)
- **8** admin commands (`man 8 mount`)

## See it work

```bash
ls --help | head -5
```

What this does: prints the short usage text and keeps the first 5 lines.

```
Usage: ls [OPTION]... [FILE]...
List information about the FILEs (the current directory by default).
Sort entries alphabetically if none of -cftuvSUX nor --sort is specified.
...
```

```bash
man ls
```

This opens the manual in a pager. Keys inside it:

| Key | Action |
|---|---|
| Space / b | page down / up |
| `/word` then Enter | search; `n` next match |
| `q` | quit |

### What kind of command is it?

```bash
type cd
type ls
which grep
command -v grep
```

Expected output:

```
cd is a shell builtin
ls is aliased to `ls --color=auto'
/usr/bin/grep
/usr/bin/grep
```

- A **builtin** lives inside bash itself (`cd`, `export`, `echo`). It has no
  separate man page; use `help cd`.
- An **alias** is a shortcut defined in your shell.
- Everything else is a program file on disk; `which` and `command -v` show
  where.

### Finding a command you do not know

```bash
apropos compress     # search man page descriptions by keyword
whatis tar           # one-line description
```

```
tar (1)              - an archiving utility
```

If `man` says "No manual entry", the docs may not be installed (minimal images
strip them). `--help` usually still works.

## Try it

You want to know the format of the file `/etc/crontab`, not the `crontab`
command. Which man command do you run? And how do you check if `echo` is a
builtin?

<details>
<summary>Show answer</summary>

`man 5 crontab` opens the file-format section. `type echo` prints
`echo is a shell builtin`.

</details>

## Common mistakes

- **Reading `man` top to bottom.** Jump to EXAMPLES with `/EXAMPLES`. Most pages
  have one.
- **Running `man cd`.** Builtins are documented by `help cd` (or in `man bash`).
- **Trusting a blog over the local manual.** Options differ between GNU (Linux)
  and BSD (macOS) tools; the local `man` matches the machine you are on.

## Remember

- `--help` for a quick reminder, `man` for the full story, `q` to quit.
- Sections: 1 commands, 5 file formats, 8 admin commands.
- `type` tells you builtin / alias / file; `which` and `command -v` give the path.
- `apropos keyword` finds commands you do not know yet.

**Self-check:**

1. What is the difference between `man 1 passwd` and `man 5 passwd`?
2. How do you search inside a man page?
3. Why does `which cd` print nothing useful?
$md$, 6, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('d97de623-3798-5d28-b6ee-a253e819bcc1', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '4078896b-224c-5318-8a4a-c389cca4bece', 'Variables, the Environment and PATH', 'notes', 5, $md$## Why this matters

The runbook says "type `brewctl status`" and bash answers `command not found`,
even though the file exists. The reason is almost always one variable: `PATH`.
Variables also carry settings like `HOME`, `USER` and app configuration into
every program you start.

## Mental model: sticky notes on the barista's desk

A **variable** is a named sticky note: `NAME=atlas`. There are two kinds:

- A **shell variable** stays on the barista's desk. Only this shell sees it.
- An **environment variable** is photocopied and handed to every program the
  shell starts. You create one with `export`.

```
  shell (bash)                     child program (python, brewbot)
  +-----------------+   starts    +-------------------------+
  | NAME=atlas      |  -------->  |  (does not see NAME)    |
  | export ROLE=dev |             |  ROLE=dev   <- copied   |
  +-----------------+             +-------------------------+
```

Copies go **down** only: a child can never change its parent's variables.

## See it work

```bash
NAME=atlas              # shell variable: no spaces around =
echo $NAME
export ROLE=apprentice  # environment variable
env | grep ROLE         # list the environment, keep ROLE
echo $HOME $USER $SHELL
```

What this does: sets two variables and prints them. Expected output:

```
atlas
ROLE=apprentice
/home/labuser labuser /bin/bash
```

`$NAME` means "the value of NAME". `env` prints only exported variables, which is
why `NAME` does not appear in it.

### PATH: where the shell looks for commands

`PATH` is a colon-separated list of directories. When you type `grep`, bash
checks each directory in order and runs the **first** `grep` it finds.

```bash
echo $PATH
```

```
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
     1st            2nd          3rd       4th ...
```

```
 you type: brewctl
 bash checks /usr/local/sbin/brewctl  no
             /usr/local/bin/brewctl   no
             /usr/sbin/brewctl        no
             ...                      no  ->  "brewctl: command not found"
```

To add your own directory for this shell:

```bash
export PATH="$HOME/bin:$PATH"     # prepend: your tools win
```

Notice `$PATH` inside the new value: you **extend** the list, you do not
replace it. The current directory (`.`) is deliberately not in PATH, which is
why you run local scripts as `./script.sh`.

> **Memory hook:** PATH is the **route the barista walks** to find a tool. Put
> your shelf (`~/bin`) first on the route and your tools win.

## Try it

You run `PATH=/home/labuser/bin` (no `$PATH`). What breaks immediately? How do
you get a working shell back?

<details>
<summary>Show answer</summary>

Every normal command (`ls`, `grep`, `cat`) now says `command not found`, because
bash only looks in `/home/labuser/bin`. Builtins like `cd` and `echo` still
work. Fix it by opening a new shell (the change only lived in this one), or type
`export PATH=/usr/local/bin:/usr/bin:/bin`.

</details>

## Common mistakes

- **Spaces around `=`.** `NAME = atlas` runs a command called `NAME`. Write
  `NAME=atlas`.
- **Overwriting PATH instead of extending it.** Always include `$PATH` in the
  new value.
- **Forgetting `export`.** A plain variable is invisible to programs you start,
  so `python app.py` will not see it.
- **Expecting a script to change your shell's variables.** A script runs as a
  child; its variables vanish when it ends. Use `source script.sh` to run it in
  the current shell instead.

## Remember

- `NAME=value` sets, `$NAME` reads, `export` passes it to child programs.
- `env` lists the environment; `echo $PATH` shows the command search route.
- Extend PATH with `export PATH="$HOME/bin:$PATH"`.
- `command not found` = no directory in PATH has that name.

**Self-check:**

1. What is the difference between `X=1` and `export X=1`?
2. In what order does bash search PATH?
3. Why do you type `./deploy.sh` and not just `deploy.sh`?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ce77c897-2d26-5f99-8ca6-6dfd33fcdfdc', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '4078896b-224c-5318-8a4a-c389cca4bece', 'Making It Stick: .bashrc, .profile and Aliases', 'notes', 6, $md$## Why this matters

You set `PATH` and an alias, close the terminal, open a new one: everything is
gone. Settings typed at the prompt live only as long as that shell. Startup files
are how you make atlas remember you.

## Mental model: the barista's morning checklist

Every time bash starts, it reads a checklist file and runs each line, as if you
typed them. Which checklist depends on how the shell started:

```
 login shell (SSH login, console login)
   reads: /etc/profile, then ~/.profile (or ~/.bash_profile)
   Ubuntu's ~/.profile then also reads ~/.bashrc

 interactive non-login shell (a new terminal tab, typing `bash`)
   reads: /etc/bash.bashrc, then ~/.bashrc
```

| File | Runs when | Put here |
|---|---|---|
| `~/.bashrc` | every new interactive bash | aliases, prompt, PATH tweaks, umask |
| `~/.profile` / `~/.bash_profile` | login shells (once per login) | environment for the whole session |
| `/etc/profile`, `/etc/profile.d/*.sh` | login shells, every user | system-wide settings |
| `/etc/bash.bashrc` | interactive shells, every user | system-wide aliases |

Simple rule for this course: **put your settings in `~/.bashrc`.**

## See it work

An **alias** is a shortcut: one word that expands to a longer command.

```bash
alias ll='ls -alF'      # define it
ll /tmp                 # use it
alias                   # list all aliases
unalias ll              # remove it
```

To make settings permanent, append them to `~/.bashrc`:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
echo "alias ll='ls -alF'" >> ~/.bashrc
source ~/.bashrc
```

What this does: `>>` appends a line to the end of the file (never use a single
`>` here; it would wipe the file). `source` re-reads the file in the current
shell so you do not need a new terminal. Check it:

```bash
tail -2 ~/.bashrc
type ll
```

```
export PATH="$HOME/bin:$PATH"
alias ll='ls -alF'
ll is aliased to `ls -alF'
```

### Your own commands

Any executable file in a PATH directory is a command. Put scripts in `~/bin`:

```bash
mkdir -p ~/bin
printf '#!/bin/bash\necho "Atlas online"\n' > ~/bin/hello-atlas
chmod +x ~/bin/hello-atlas
cd /tmp && hello-atlas
```

```
Atlas online
```

The first line `#!/bin/bash` (the **shebang**) tells the kernel to run the file
with bash. `chmod +x` makes it executable. Chapter 9 covers scripts properly.

## Try it

You added `alias atlas='cd ~/work/atlas'` to `~/.bashrc`, but in your current
terminal `atlas` says command not found. Why, and what are two ways to fix it?

<details>
<summary>Show answer</summary>

The current shell read `~/.bashrc` when it started, before you added the line.
Either run `source ~/.bashrc` or open a new shell (`bash`, or a new terminal).

</details>

## Common mistakes

- **Using `>` instead of `>>`.** `echo ... > ~/.bashrc` replaces the whole file.
  Keep a backup: `cp ~/.bashrc ~/.bashrc.bak` before editing.
- **Putting settings in the wrong file.** If something works in a new tab but not
  after SSH login (or the reverse), check which startup file each shell reads.
- **Breaking `.bashrc` with a syntax error.** Every new shell prints errors. Fix
  with `nano ~/.bashrc` and test with `bash -n ~/.bashrc` (syntax check only).
- **Aliases in scripts.** Scripts do not expand aliases by default. Use
  functions or full commands in scripts.

## Remember

- Typed settings die with the shell; startup files bring them back.
- `~/.bashrc` runs for every interactive bash; `~/.profile` for logins.
- Append with `>>`, reload with `source ~/.bashrc`.
- An executable file in `~/bin` (on PATH) is your own command.

**Self-check:**

1. Which file holds your aliases?
2. What does `source ~/.bashrc` do?
3. What three things make `hello-atlas` work as a command from any directory?
$md$, 6, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a50e29c4-cd7e-5b52-bfea-bf5cd4825d59', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '4078896b-224c-5318-8a4a-c389cca4bece', 'Lab: Find Tom''s Note and Make Atlas Yours', 'notes', 7, $md$## Why this matters

You have read how the shell, the filesystem map and PATH work. Now use them on a
real machine. Tom left a hidden note on atlas, and by the end of this lab atlas
will know your name and run a command you wrote. Each task is checked
automatically.

## Before you start

Your lab copy of atlas lives under `~/work/atlas`. Look around first:

```bash
cd ~/work/atlas
ls
```

Expected output:

```
etc  home  srv  var
```

The same map as a real server, in miniature.

## Task 1: ask atlas who it is

Create the directory `~/work/answers`, then save the running kernel release into
`answers/kernel.txt`. `uname -r` prints it; `>` sends a command's output into a
file instead of the screen (lesson 1 and chapter 3 cover this).

[[lab-task:1]]

Check yourself: `cat ~/work/answers/kernel.txt` shows one line like
`6.8.0-45-generic`.

## Task 2: find where the shell lives

Commands are files on disk. Save the full path of the `bash` program into
`answers/bash-path.txt`. Lesson 5 showed two commands that print it.

[[lab-task:2]]

## Task 3: find Tom's hidden note

Tom's note is somewhere under `~/work/atlas`. Plain `ls` will not show it: Tom
liked names that start with a dot. Save only the codeword (one word, capital
letters) into `answers/codeword.txt`.

[[lab-task:3]]

What you should see when you find the hidden folder:

```
$ ls -la var/log/old
drwxr-xr-x 3 labuser labuser 4096 ... .
drwxr-xr-x 3 labuser labuser 4096 ... ..
drwxr-xr-x 2 labuser labuser 4096 ... .archive
-rw-r--r-- 1 labuser labuser   25 ... notes.txt
```

## Task 4: make atlas remember you

In `~/.bashrc`, export `ATLAS_ROLE=apprentice` and define an alias `atlas` that
runs `cd /home/labuser/work/atlas`. Use `>>` so you append, then
`source ~/.bashrc` to try it.

[[lab-task:4]]

## Task 5: teach atlas a new command

Create the script `~/bin/hello-atlas` that prints exactly `Atlas online`, make
it executable, and add `~/bin` to your PATH in `~/.bashrc`.

[[lab-task:5]]

What you should see:

```
$ cd /tmp && hello-atlas
Atlas online
```

## Remember

- `uname -r` = kernel release; `command -v` = where a program lives.
- Hidden files start with a dot; `ls -a` and `find` reveal them.
- `~/.bashrc` makes exports, aliases and PATH changes permanent.
- An executable file in a PATH directory is a command.

> **End of day 1.** Tom's note said RISTRETTO, and below it, in small letters:
> "Tomorrow, unpack the boxes."
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('eb18d200-624b-53e4-8ac5-751d4dda5229', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'a50e29c4-cd7e-5b52-bfea-bf5cd4825d59', 'module', 'Lab: Find Tom''s Note and Make Atlas Yours', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
rm -rf $w/atlas $w/answers
mkdir -p $w/atlas/etc/brewbot $w/atlas/var/log/old/.archive $w/atlas/home/tom $w/atlas/srv/brewbot
echo "port = 8080" > $w/atlas/etc/brewbot/brewbot.conf
echo "Welcome to atlas. Look deeper - and look for what is hidden." > $w/atlas/home/tom/README
echo "nothing here, keep going" > $w/atlas/var/log/old/notes.txt
echo "If you found this, the codeword is RISTRETTO" > $w/atlas/var/log/old/.archive/.tom-note
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed' AND id NOT IN ('7f67d19f-8874-5b63-b5b3-69094b1e3f39', '72c12f27-ba4c-52db-8688-8ec19b822c56', 'cda34423-ecc5-57cd-9e5f-6a58c06c841b', '57304ba3-0462-5bfe-83a5-046b0035ad08', 'cb03a349-1803-5ef9-bbda-7b8dfdcd16bc');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed';
DELETE FROM lab_tasks WHERE lab_id = 'eb18d200-624b-53e4-8ac5-751d4dda5229' AND id NOT IN ('e99a9388-6e2f-5e67-8b42-e5ead23e4c27', 'fbf1cc53-b9a5-57e4-8b18-77cadbf1620d', 'fb16e9f8-d8da-5149-a377-cd78f3dd4304', '9c2e5b47-866e-50c0-a07a-34182ef6ef18', 'bcef36e7-8285-5295-8769-312665efb73a');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'eb18d200-624b-53e4-8ac5-751d4dda5229';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('e99a9388-6e2f-5e67-8b42-e5ead23e4c27', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 1, 'Ask atlas who it is', $md$Create the directory /home/labuser/work/answers, then save the running kernel release (the output of uname -r) into answers/kernel.txt.$md$, $script$f=/home/labuser/work/answers/kernel.txt
[ -f $f ] && [ "$(tr -d '[:space:]' < $f)" = "$(uname -r)" ]
$script$, 'uname prints kernel information; -r is the release. Redirect its output with > into the file. mkdir creates the answers directory first.', 'The kernel is the core of Linux. uname -r asks the running kernel for its release string; > redirects a command''s output into a file instead of the screen.', 10, false, true),
('fbf1cc53-b9a5-57e4-8b18-77cadbf1620d', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 2, 'Find where the shell lives', $md$Save the full path of the bash program into answers/bash-path.txt.$md$, $script$p=$(tr -d '[:space:]' < /home/labuser/work/answers/bash-path.txt)
[ -x "$p" ] && [ "$(basename "$p")" = bash ]
$script$, 'command -v bash (or which bash) prints the path of the program bash runs when you type its name.', 'Commands are just programs on disk. The shell searches each directory in PATH and runs the first match; which and command -v show you where that match is.', 10, false, true),
('fb16e9f8-d8da-5149-a377-cd78f3dd4304', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 3, 'Find Tom''s hidden note', $md$The old admin, Tom, hid a note somewhere under /home/labuser/work/atlas. Find it and save only the codeword (one word, capital letters) into answers/codeword.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/codeword.txt)" = RISTRETTO ]
$script$, 'Files and directories whose names start with a dot are hidden from plain ls. Use ls -la in each directory, or find /home/labuser/work/atlas -name ''.*''.', 'A leading dot is the only thing that makes a file hidden in Linux - it is a naming convention, not a permission. ls -a and find show them.', 20, false, true),
('9c2e5b47-866e-50c0-a07a-34182ef6ef18', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 4, 'Make atlas remember you', $md$In ~/.bashrc, export the variable ATLAS_ROLE with the value apprentice, and define an alias called atlas that runs cd /home/labuser/work/atlas. Open a new shell (or run source ~/.bashrc) to try it.$md$, $script$[ "$(bash -ic 'echo $ATLAS_ROLE' 2>/dev/null)" = apprentice ] &&
bash -ic 'alias atlas' 2>/dev/null | grep -q 'cd /home/labuser/work/atlas'
$script$, 'Add two lines to the end of ~/.bashrc - export ATLAS_ROLE=apprentice and alias atlas=''cd /home/labuser/work/atlas''. echo ''line'' >> ~/.bashrc appends without overwriting.', 'Variables set in a terminal vanish when it closes. ~/.bashrc runs at the start of every interactive Bash shell, so exports and aliases placed there come back every time.', 20, false, true),
('bcef36e7-8285-5295-8769-312665efb73a', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 5, 'Teach atlas a new command', $md$Create the script ~/bin/hello-atlas that prints exactly "Atlas online", make it executable, and add ~/bin to your PATH in ~/.bashrc so typing hello-atlas from any directory works.$md$, $script$[ "$(bash -ic 'cd /tmp && hello-atlas' 2>/dev/null)" = "Atlas online" ]
$script$, 'The script needs a first line #!/bin/bash and a line echo "Atlas online". chmod +x makes it runnable. export PATH="$HOME/bin:$PATH" in ~/.bashrc puts the directory on the search path.', 'A command is any executable file in a PATH directory. Prepending ~/bin to PATH makes your own scripts behave exactly like system commands.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 1, $json$[{"id":"e99a9388-6e2f-5e67-8b42-e5ead23e4c27","lab_id":"eb18d200-624b-53e4-8ac5-751d4dda5229","position":1,"title":"Ask atlas who it is","description":"Create the directory /home/labuser/work/answers, then save the running kernel release (the output of uname -r) into answers/kernel.txt.","verification_script":"f=/home/labuser/work/answers/kernel.txt\n[ -f $f ] \u0026\u0026 [ \"$(tr -d '[:space:]' \u003c $f)\" = \"$(uname -r)\" ]\n","hint_context":"uname prints kernel information; -r is the release. Redirect its output with \u003e into the file. mkdir creates the answers directory first.","explanation_context":"The kernel is the core of Linux. uname -r asks the running kernel for its release string; \u003e redirects a command's output into a file instead of the screen.","points":10,"is_optional":false,"is_stateful":true},{"id":"fbf1cc53-b9a5-57e4-8b18-77cadbf1620d","lab_id":"eb18d200-624b-53e4-8ac5-751d4dda5229","position":2,"title":"Find where the shell lives","description":"Save the full path of the bash program into answers/bash-path.txt.","verification_script":"p=$(tr -d '[:space:]' \u003c /home/labuser/work/answers/bash-path.txt)\n[ -x \"$p\" ] \u0026\u0026 [ \"$(basename \"$p\")\" = bash ]\n","hint_context":"command -v bash (or which bash) prints the path of the program bash runs when you type its name.","explanation_context":"Commands are just programs on disk. The shell searches each directory in PATH and runs the first match; which and command -v show you where that match is.","points":10,"is_optional":false,"is_stateful":true},{"id":"fb16e9f8-d8da-5149-a377-cd78f3dd4304","lab_id":"eb18d200-624b-53e4-8ac5-751d4dda5229","position":3,"title":"Find Tom's hidden note","description":"The old admin, Tom, hid a note somewhere under /home/labuser/work/atlas. Find it and save only the codeword (one word, capital letters) into answers/codeword.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/codeword.txt)\" = RISTRETTO ]\n","hint_context":"Files and directories whose names start with a dot are hidden from plain ls. Use ls -la in each directory, or find /home/labuser/work/atlas -name '.*'.","explanation_context":"A leading dot is the only thing that makes a file hidden in Linux - it is a naming convention, not a permission. ls -a and find show them.","points":20,"is_optional":false,"is_stateful":true},{"id":"9c2e5b47-866e-50c0-a07a-34182ef6ef18","lab_id":"eb18d200-624b-53e4-8ac5-751d4dda5229","position":4,"title":"Make atlas remember you","description":"In ~/.bashrc, export the variable ATLAS_ROLE with the value apprentice, and define an alias called atlas that runs cd /home/labuser/work/atlas. Open a new shell (or run source ~/.bashrc) to try it.","verification_script":"[ \"$(bash -ic 'echo $ATLAS_ROLE' 2\u003e/dev/null)\" = apprentice ] \u0026\u0026\nbash -ic 'alias atlas' 2\u003e/dev/null | grep -q 'cd /home/labuser/work/atlas'\n","hint_context":"Add two lines to the end of ~/.bashrc - export ATLAS_ROLE=apprentice and alias atlas='cd /home/labuser/work/atlas'. echo 'line' \u003e\u003e ~/.bashrc appends without overwriting.","explanation_context":"Variables set in a terminal vanish when it closes. ~/.bashrc runs at the start of every interactive Bash shell, so exports and aliases placed there come back every time.","points":20,"is_optional":false,"is_stateful":true},{"id":"bcef36e7-8285-5295-8769-312665efb73a","lab_id":"eb18d200-624b-53e4-8ac5-751d4dda5229","position":5,"title":"Teach atlas a new command","description":"Create the script ~/bin/hello-atlas that prints exactly \"Atlas online\", make it executable, and add ~/bin to your PATH in ~/.bashrc so typing hello-atlas from any directory works.","verification_script":"[ \"$(bash -ic 'cd /tmp \u0026\u0026 hello-atlas' 2\u003e/dev/null)\" = \"Atlas online\" ]\n","hint_context":"The script needs a first line #!/bin/bash and a line echo \"Atlas online\". chmod +x makes it runnable. export PATH=\"$HOME/bin:$PATH\" in ~/.bashrc puts the directory on the search path.","explanation_context":"A command is any executable file in a PATH directory. Prepending ~/bin to PATH makes your own scripts behave exactly like system commands.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('7f67d19f-8874-5b63-b5b3-69094b1e3f39', 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', 'e99a9388-6e2f-5e67-8b42-e5ead23e4c27', 1, 'Ask atlas who it is', $md$Create the directory /home/labuser/work/answers, then save the running kernel release (the output of uname -r) into answers/kernel.txt.$md$, $script$f=/home/labuser/work/answers/kernel.txt
[ -f $f ] && [ "$(tr -d '[:space:]' < $f)" = "$(uname -r)" ]
$script$, 'uname prints kernel information; -r is the release. Redirect its output with > into the file. mkdir creates the answers directory first.', 'The kernel is the core of Linux. uname -r asks the running kernel for its release string; > redirects a command''s output into a file instead of the screen.', 10, false, true),
('72c12f27-ba4c-52db-8688-8ec19b822c56', 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', 'fbf1cc53-b9a5-57e4-8b18-77cadbf1620d', 2, 'Find where the shell lives', $md$Save the full path of the bash program into answers/bash-path.txt.$md$, $script$p=$(tr -d '[:space:]' < /home/labuser/work/answers/bash-path.txt)
[ -x "$p" ] && [ "$(basename "$p")" = bash ]
$script$, 'command -v bash (or which bash) prints the path of the program bash runs when you type its name.', 'Commands are just programs on disk. The shell searches each directory in PATH and runs the first match; which and command -v show you where that match is.', 10, false, true),
('cda34423-ecc5-57cd-9e5f-6a58c06c841b', 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', 'fb16e9f8-d8da-5149-a377-cd78f3dd4304', 3, 'Find Tom''s hidden note', $md$The old admin, Tom, hid a note somewhere under /home/labuser/work/atlas. Find it and save only the codeword (one word, capital letters) into answers/codeword.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/codeword.txt)" = RISTRETTO ]
$script$, 'Files and directories whose names start with a dot are hidden from plain ls. Use ls -la in each directory, or find /home/labuser/work/atlas -name ''.*''.', 'A leading dot is the only thing that makes a file hidden in Linux - it is a naming convention, not a permission. ls -a and find show them.', 20, false, true),
('57304ba3-0462-5bfe-83a5-046b0035ad08', 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', '9c2e5b47-866e-50c0-a07a-34182ef6ef18', 4, 'Make atlas remember you', $md$In ~/.bashrc, export the variable ATLAS_ROLE with the value apprentice, and define an alias called atlas that runs cd /home/labuser/work/atlas. Open a new shell (or run source ~/.bashrc) to try it.$md$, $script$[ "$(bash -ic 'echo $ATLAS_ROLE' 2>/dev/null)" = apprentice ] &&
bash -ic 'alias atlas' 2>/dev/null | grep -q 'cd /home/labuser/work/atlas'
$script$, 'Add two lines to the end of ~/.bashrc - export ATLAS_ROLE=apprentice and alias atlas=''cd /home/labuser/work/atlas''. echo ''line'' >> ~/.bashrc appends without overwriting.', 'Variables set in a terminal vanish when it closes. ~/.bashrc runs at the start of every interactive Bash shell, so exports and aliases placed there come back every time.', 20, false, true),
('cb03a349-1803-5ef9-bbda-7b8dfdcd16bc', 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', 'bcef36e7-8285-5295-8769-312665efb73a', 5, 'Teach atlas a new command', $md$Create the script ~/bin/hello-atlas that prints exactly "Atlas online", make it executable, and add ~/bin to your PATH in ~/.bashrc so typing hello-atlas from any directory works.$md$, $script$[ "$(bash -ic 'cd /tmp && hello-atlas' 2>/dev/null)" = "Atlas online" ]
$script$, 'The script needs a first line #!/bin/bash and a line echo "Atlas online". chmod +x makes it runnable. export PATH="$HOME/bin:$PATH" in ~/.bashrc puts the directory on the search path.', 'A command is any executable file in a PATH directory. Prepending ~/bin to PATH makes your own scripts behave exactly like system commands.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', updated_at = now()
WHERE id = 'eb18d200-624b-53e4-8ac5-751d4dda5229' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('aaddd255-50b2-5b9b-b090-3451a9b4f104', '00000000-0000-0000-0000-000000000001', 'mcq', 'A colleague says ''we upgraded Linux from 22.04 to 24.04''. What did they most ...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7c1aa709-ead0-5a33-b4d6-fc2ed070678d', 'aaddd255-50b2-5b9b-b090-3451a9b4f104', 1, $json${"prompt":"A colleague says 'we upgraded Linux from 22.04 to 24.04'. What did they most likely upgrade?","multiple":false,"options":[{"id":"a","text":"Only the kernel","is_correct":false},{"id":"b","text":"The Ubuntu distribution (which also brought a newer kernel and tools)","is_correct":true},{"id":"c","text":"The shell, from sh to bash","is_correct":false},{"id":"d","text":"The terminal program","is_correct":false}],"explanation":"22.04 and 24.04 are Ubuntu release numbers, so the distribution was upgraded. Kernel versions look like 6.8.0; the shell and the terminal are single programs and have their own versions."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e97345cd-d1cb-54ec-bd95-5bced28a82b5', '00000000-0000-0000-0000-000000000001', 'mcq', 'Brewbot misbehaves. Where do you look first for its configuration and its logs?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f6c4c5af-d944-58d5-823d-c50b1a34ccf4', 'e97345cd-d1cb-54ec-bd95-5bced28a82b5', 1, $json${"prompt":"Brewbot misbehaves. Where do you look first for its configuration and its logs?","multiple":false,"options":[{"id":"a","text":"/usr/brewbot and /tmp","is_correct":false},{"id":"b","text":"/etc/brewbot and /var/log/brewbot","is_correct":true},{"id":"c","text":"/proc/brewbot and /dev/brewbot","is_correct":false},{"id":"d","text":"/root/brewbot and /boot","is_correct":false}],"explanation":"/etc holds configuration, /var/log holds logs. /usr is for package-managed programs, /tmp is scratch space, /proc and /dev are kernel views of processes and devices, /root is the root user's home and /boot holds the kernel."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('dc72920c-d4ec-5858-ac02-25e44f628919', '00000000-0000-0000-0000-000000000001', 'mcq', 'You are in /home/labuser. Which command does NOT take you to /var/log?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5c44ec63-6a1f-5f2a-8955-0a7c123e73aa', 'dc72920c-d4ec-5858-ac02-25e44f628919', 1, $json${"prompt":"You are in /home/labuser. Which command does NOT take you to /var/log?","multiple":false,"options":[{"id":"a","text":"cd /var/log","is_correct":false},{"id":"b","text":"cd ../../var/log","is_correct":false},{"id":"c","text":"cd var/log","is_correct":true},{"id":"d","text":"cd /var; cd log","is_correct":false}],"explanation":"var/log is relative, so from /home/labuser it means /home/labuser/var/log, which does not exist. The absolute path works from anywhere, ../../ climbs to / first, and the two-step cd uses an absolute path then a relative one from /var."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c9f63b74-da83-5a0a-aa58-2771f28ae974', '00000000-0000-0000-0000-000000000001', 'mcq', 'type cd prints ''cd is a shell builtin''. What does that tell you?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('98c3fed6-5012-5a39-b4d7-6eb3368f5ba1', 'c9f63b74-da83-5a0a-aa58-2771f28ae974', 1, $json${"prompt":"type cd prints 'cd is a shell builtin'. What does that tell you?","multiple":false,"options":[{"id":"a","text":"cd is a program in /usr/bin","is_correct":false},{"id":"b","text":"cd is part of bash itself, so help cd documents it rather than a man page","is_correct":true},{"id":"c","text":"cd is an alias you can delete","is_correct":false},{"id":"d","text":"cd only works for root","is_correct":false}],"explanation":"Builtins run inside the shell. That is why which cd finds no file and man cd has no page; help cd does. An alias would print 'is aliased to', and builtins work for every user."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('14ddba9e-f2f3-579f-b335-91d36269b654', '00000000-0000-0000-0000-000000000001', 'mcq', 'You ran PATH=$HOME/bin in your terminal. Now ls says ''command not found''. Why?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5feaea6f-948f-51ca-9029-258d7ef00f6c', '14ddba9e-f2f3-579f-b335-91d36269b654', 1, $json${"prompt":"You ran PATH=$HOME/bin in your terminal. Now ls says 'command not found'. Why?","multiple":false,"options":[{"id":"a","text":"ls was deleted","is_correct":false},{"id":"b","text":"PATH now contains only $HOME/bin, so bash no longer searches /usr/bin where ls lives","is_correct":true},{"id":"c","text":"The kernel blocks ls after PATH changes","is_correct":false},{"id":"d","text":"You need to reboot after editing PATH","is_correct":false}],"explanation":"You replaced the search list instead of extending it. The right form is export PATH=\"$HOME/bin:$PATH\". Nothing was deleted, the kernel is not involved, and a new shell (not a reboot) restores the default."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b4ea2c97-6b10-54e2-a60c-9e343e89aca2', '00000000-0000-0000-0000-000000000001', 'mcq', 'You exported DB_HOST=db1 in one terminal, then started brewbot from a second ...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f01f7871-64b2-590e-a0b0-6f627a5854fc', 'b4ea2c97-6b10-54e2-a60c-9e343e89aca2', 1, $json${"prompt":"You exported DB_HOST=db1 in one terminal, then started brewbot from a second terminal. Brewbot does not see DB_HOST. Why?","multiple":false,"options":[{"id":"a","text":"export only works for root","is_correct":false},{"id":"b","text":"Each shell has its own environment; the second terminal never had DB_HOST","is_correct":true},{"id":"c","text":"Environment variables must be lowercase","is_correct":false},{"id":"d","text":"Brewbot needs to be started with sudo","is_correct":false}],"explanation":"Environment variables are copied from a shell to its children only. The second terminal is a separate shell. Put the export in ~/.bashrc or in the service's own config. Any user can export, and case does not matter."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7bd8cca5-928d-509a-9ff8-9cc386f9e801', '00000000-0000-0000-0000-000000000001', 'mcq', 'Where should you put an alias so it exists in every new interactive bash shell?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('02edf732-693e-504f-9d84-0c6f78e44f19', '7bd8cca5-928d-509a-9ff8-9cc386f9e801', 1, $json${"prompt":"Where should you put an alias so it exists in every new interactive bash shell?","multiple":false,"options":[{"id":"a","text":"~/.bashrc","is_correct":true},{"id":"b","text":"/tmp/aliases","is_correct":false},{"id":"c","text":"/proc/self/aliases","is_correct":false},{"id":"d","text":"/etc/hostname","is_correct":false}],"explanation":"Bash reads ~/.bashrc at the start of every interactive shell. /tmp is scratch space bash never reads, /proc is a kernel view, and /etc/hostname only holds the machine name."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6c9acc6d-825c-52ab-a556-b7c9ae8124ab', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why is a file called .tom-note not shown by ls?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('987af65a-b8be-5034-b7b6-c03330773707', '6c9acc6d-825c-52ab-a556-b7c9ae8124ab', 1, $json${"prompt":"Why is a file called .tom-note not shown by ls?","multiple":false,"options":[{"id":"a","text":"It has secret permissions","is_correct":false},{"id":"b","text":"Names starting with a dot are hidden by convention; ls -a shows them","is_correct":true},{"id":"c","text":"It is encrypted","is_correct":false},{"id":"d","text":"Only root can see dot-files","is_correct":false}],"explanation":"A leading dot is purely a naming convention. Anyone who can list the directory sees it with ls -a. It is not a permission, not encryption, and not limited to root."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('2d8f58e6-e8ce-5601-b99d-7b0eeec793f0', '00000000-0000-0000-0000-000000000001', 'Quiz: the Shell and the Map', 'linux-meet-atlas-quiz', 'Quiz covering Chapter 1: Meet Atlas - the Shell and the Map.', 'mcq', 'published', 'module', '10d6dc16-476c-5e96-ae6b-efa23dae5aca', 10, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '2d8f58e6-e8ce-5601-b99d-7b0eeec793f0' AND question_id NOT IN ('aaddd255-50b2-5b9b-b090-3451a9b4f104', 'e97345cd-d1cb-54ec-bd95-5bced28a82b5', 'dc72920c-d4ec-5858-ac02-25e44f628919', 'c9f63b74-da83-5a0a-aa58-2771f28ae974', '14ddba9e-f2f3-579f-b335-91d36269b654', 'b4ea2c97-6b10-54e2-a60c-9e343e89aca2', '7bd8cca5-928d-509a-9ff8-9cc386f9e801', '6c9acc6d-825c-52ab-a556-b7c9ae8124ab');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('3dbd61ec-7f78-5592-83c6-169501c757f3', '2d8f58e6-e8ce-5601-b99d-7b0eeec793f0', 'aaddd255-50b2-5b9b-b090-3451a9b4f104', '7c1aa709-ead0-5a33-b4d6-fc2ed070678d', 0, 2),
('2a9ae859-eb8a-528c-b9da-b6add581d48c', '2d8f58e6-e8ce-5601-b99d-7b0eeec793f0', 'e97345cd-d1cb-54ec-bd95-5bced28a82b5', 'f6c4c5af-d944-58d5-823d-c50b1a34ccf4', 1, 2),
('31ee4585-cc34-580b-9de8-1110048f9a02', '2d8f58e6-e8ce-5601-b99d-7b0eeec793f0', 'dc72920c-d4ec-5858-ac02-25e44f628919', '5c44ec63-6a1f-5f2a-8955-0a7c123e73aa', 2, 2),
('0bcac327-3942-5f77-80f3-9d86b5ecf50b', '2d8f58e6-e8ce-5601-b99d-7b0eeec793f0', 'c9f63b74-da83-5a0a-aa58-2771f28ae974', '98c3fed6-5012-5a39-b4d7-6eb3368f5ba1', 3, 2),
('bcb7faca-9657-5e6e-a82e-691f90bc532f', '2d8f58e6-e8ce-5601-b99d-7b0eeec793f0', '14ddba9e-f2f3-579f-b335-91d36269b654', '5feaea6f-948f-51ca-9029-258d7ef00f6c', 4, 2),
('4dd88751-51f0-5d9f-a189-658f0fce9757', '2d8f58e6-e8ce-5601-b99d-7b0eeec793f0', 'b4ea2c97-6b10-54e2-a60c-9e343e89aca2', 'f01f7871-64b2-590e-a0b0-6f627a5854fc', 5, 2),
('cf5451f1-f2b1-501f-831e-fd5d70041a47', '2d8f58e6-e8ce-5601-b99d-7b0eeec793f0', '7bd8cca5-928d-509a-9ff8-9cc386f9e801', '02edf732-693e-504f-9d84-0c6f78e44f19', 6, 2),
('3582321a-e63b-5c53-b51e-a7d06f0adc61', '2d8f58e6-e8ce-5601-b99d-7b0eeec793f0', '6c9acc6d-825c-52ab-a556-b7c9ae8124ab', '987af65a-b8be-5034-b7b6-c03330773707', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('10d6dc16-476c-5e96-ae6b-efa23dae5aca', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '4078896b-224c-5318-8a4a-c389cca4bece', 'Quiz: the Shell and the Map', 'assessment', 8, 8, '2d8f58e6-e8ce-5601-b99d-7b0eeec793f0')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 2: Moving In - Working with Files
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('63d08802-94af-5e70-adb6-8cdf39e53b00', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 2: Moving In - Working with Files', 2, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0fd77dab-c5af-5341-97f3-61a343493b95', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '63d08802-94af-5e70-adb6-8cdf39e53b00', 'Creating Files and Directories, and Editing Them', 'notes', 0, $md$## Why this matters

> **Tuesday.** Rhea points at a pile of digital boxes Tom dumped in
> `~/work/moving`: "The shop needs a proper home. Unpack, throw out the junk,
> and don't delete anything we need. There is no recycle bin on Linux."

Building a folder layout and writing small text files is half of daily admin
work: config files, notes, scripts. You need to do it fast and without
accidents.

## Mental model: bulldozer and stapler

Two symbols write text into files, and they behave very differently:

```
 echo "hello" >  file.txt     BULLDOZER: flattens the file, then writes
 echo "more"  >> file.txt     STAPLER:   adds a page at the end
```

> **Memory hook:** `>` is a **bulldozer**, `>>` is a **stapler**.

## See it work

```bash
mkdir shop                            # one directory
mkdir -p shop/config/recipes          # whole path, no error if it exists
mkdir -p shop/{config,logs,backups}   # brace expansion -> three dirs
ls shop
```

What this does: `-p` creates every missing parent and stays quiet if a
directory already exists. `{config,logs,backups}` is **brace expansion**: bash
turns one word into three *before* `mkdir` runs, so `mkdir` receives
`shop/config shop/logs shop/backups`. Expected output:

```
backups  config  logs
```

Check what bash will do with braces using `echo`:

```bash
echo shop/{config,logs,backups}
```

```
shop/config shop/logs shop/backups
```

### Files

```bash
touch notes.txt                 # create an empty file (or update its timestamp)
echo "Espresso 3.00" > menu.txt # create/overwrite with content
echo "Latte 4.50" >> menu.txt   # append a line
cat menu.txt
```

```
Espresso 3.00
Latte 4.50
```

For multi-line content, a **here-document** saves typing:

```bash
cat > hours.txt <<'EOF'
Mon-Fri 07:00-18:00
Sat     08:00-14:00
EOF
```

Everything between the two `EOF` lines goes into the file.

### Removing empty directories

```bash
rmdir emptydir      # only works if the directory is EMPTY
```

`rmdir` refusing a non-empty directory is a safety feature. The next lesson
covers `rm -r`.

### Editing on a server

Servers have no mouse-driven editor. Learn the survival keys of two:

| nano (easy) | vi / vim (always installed) |
|---|---|
| `nano file.txt` | `vi file.txt` |
| type directly | press `i` to start typing (insert mode) |
| `Ctrl+O` Enter = save | `Esc` then `:w` Enter = save |
| `Ctrl+X` = exit | `Esc` then `:q` Enter = quit |
| shortcuts are listed at the bottom | `Esc` then `:wq` = save and quit, `:q!` = quit without saving |

If you get stuck in vi, press `Esc` a few times, type `:q!` and Enter.

## Try it

With one command, create `~/work/cafe/menu`, `~/work/cafe/staff` and
`~/work/cafe/stock`, even though `~/work/cafe` does not exist yet. Then add two
lines to `~/work/cafe/menu/today.txt` without losing the first one.

<details>
<summary>Show answer</summary>

```bash
mkdir -p ~/work/cafe/{menu,staff,stock}
echo "Espresso" > ~/work/cafe/menu/today.txt
echo "Mocha" >> ~/work/cafe/menu/today.txt
```

The second command must use `>>`. Another `>` would replace "Espresso".

</details>

## Common mistakes

- **Spaces inside braces.** `{config, logs}` is not expanded; bash sees two
  separate words. Write `{config,logs}`.
- **`>` when you meant `>>`.** The old content is gone instantly. When editing
  important files, copy first: `cp app.conf app.conf.bak`.
- **Forgetting `-p`.** `mkdir a/b/c` fails if `a/b` does not exist.
- **Panicking in vi.** `Esc`, then `:q!`. Nothing is saved, nothing is broken.

## Remember

- `mkdir -p` makes whole paths; braces make many names at once.
- `touch` creates empty files; `>` overwrites, `>>` appends.
- Here-documents (`<<'EOF'`) write multi-line files.
- nano: `Ctrl+O`, `Ctrl+X`. vi: `i`, `Esc`, `:wq`, `:q!`.

**Self-check:**

1. What does `mkdir -p` do differently from plain `mkdir`?
2. What does `echo x{1,2,3}` print?
3. How do you quit vi without saving?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('faee4b4d-9fb1-5ccd-8229-de8e4915da6d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '63d08802-94af-5e70-adb6-8cdf39e53b00', 'Copy, Move, Rename, Delete - and Wildcards', 'notes', 1, $md$## Why this matters

Unpacking the boxes means copying recipes, moving the menu, and deleting junk.
These are the commands that cause the most damage when typed carelessly: `rm` has
no undo. Learn them with the safety habits built in.

## Mental model: photocopy vs carry

```
 cp:  box/recipes ---photocopy---> shop/config/recipes   (both exist after)
 mv:  box/menu.txt ---carry------> shop/menu.txt          (only one exists after)
 rm:  shredder. No bin, no undo.
```

`mv` within one filesystem does not copy any data. It only changes which
directory lists the name, so moving a 50 GB file is instant.

## See it work

```bash
cp menu.txt menu.bak           # copy a file
cp -r recipes/ backup/recipes  # copy a directory: -r = recursive
cp -a src/ dst/                # archive copy: keep permissions, times, links
mv old.txt new.txt             # rename
mv menu.txt shop/              # move into a directory
rm notes.txt                   # delete a file
rm -r olddir                   # delete a directory and everything inside
rm -i *.log                    # ask before each delete
```

Without `-r`, `cp` refuses directories:

```
$ cp recipes backup
cp: -r not specified; omitting directory 'recipes'
```

Use `-v` (verbose) on `cp`, `mv` and `rm` to see each action:

```bash
mv -v menu.txt shop/
```

```
renamed 'menu.txt' -> 'shop/menu.txt'
```

### Wildcards (globs)

The shell expands **wildcards** into matching file names before the command
runs. The command never sees the `*`.

| Pattern | Matches |
|---|---|
| `*` | anything, including nothing (`*.log`) |
| `?` | exactly one character (`file?.txt`) |
| `[abc]`, `[0-9]` | one character from the set |
| `{a,b}` | not a match: brace expansion always generates both words |

Preview what a pattern matches by giving it to `ls` or `echo` first:

```bash
echo *.bak
```

```
menu-2019.bak prices.bak
```

If nothing matches, bash passes the pattern through literally (`*.bak`), and the
command then complains that no such file exists.

### Safety habits for rm

`rm -rf` with a wrong variable has wiped whole servers. Before any delete:

1. Run `ls` with the exact same pattern first.
2. Use `rm -i` when unsure, or `-v` to see what happened.
3. In scripts, never write `rm -rf "$DIR"/` without checking that `$DIR` is set
   (chapter 9 shows `${DIR:?}`).
4. Prefer moving to a `trash/` folder when cleaning up something you do not fully
   understand.

## Try it

You are in `~/work/moving/box`. Copy the whole `recipes` directory to
`~/work/shop/config/recipes`, then move `menu.txt` into `~/work/shop/`. Which of
the two sources still exists afterwards?

<details>
<summary>Show answer</summary>

```bash
cp -r recipes ~/work/shop/config/recipes
mv menu.txt ~/work/shop/
```

`recipes` still exists (it was copied). `menu.txt` is gone from the box (it was
moved).

</details>

## Common mistakes

- **Trailing-slash and target confusion.** `cp -r recipes dest` creates
  `dest/recipes` if `dest` exists, but creates `dest` itself (a copy named
  `dest`) if it does not. Check with `ls` after.
- **`mv` silently overwrites.** If `shop/menu.txt` exists, `mv menu.txt shop/`
  replaces it. Use `mv -i` or `mv -n` (never overwrite) when it matters.
- **`rm *` in the wrong directory.** Always `pwd` first. A space typo,
  `rm -rf / tmp/x`, deletes from `/`.
- **Expecting a recycle bin.** Deleted from the shell means gone. Backups are the
  only undo.

## Remember

- `cp` copies (`-r` for directories, `-a` to keep attributes); `mv` moves or
  renames; `rm` deletes forever.
- Globs `*`, `?`, `[...]` are expanded by the shell; preview with `echo` or `ls`.
- Add `-i` to ask, `-v` to see what happened.
- `ls` first, `rm` second.

**Self-check:**

1. Which option does `cp` need to copy a directory?
2. Why is `mv` instant for a huge file on the same disk?
3. What does `?` match in a glob?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('06d07063-e592-5091-af65-caa319274ed2', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '63d08802-94af-5e70-adb6-8cdf39e53b00', 'Finding Files with find (and locate)', 'notes', 2, $md$## Why this matters

Tom left `.bak` files in five different folders. Next week a disk fills up and
you need every file over 1 GB. `find` walks a whole directory tree and can act on
what it finds. It is one of the most used admin commands.

## Mental model: WHERE, WHAT, DO

```
 find  /var/log   -name "*.log" -mtime +7   -delete
       \______/   \___________________/    \_____/
        WHERE            WHAT                 DO
   (start here)  (tests, all must match)  (action, default: print)
```

> **Memory hook:** `find WHERE WHAT DO`. Always run it once **without** the DO
> part, read the list, then add the action.

## See it work

```bash
find ~/work/moving -name "*.bak"
```

What this does: walks every directory below `~/work/moving` and prints paths
whose name ends in `.bak`. Expected output (the order may differ; `find` lists
in directory order, not alphabetically):

```
/home/labuser/work/moving/box/old/menu-2019.bak
/home/labuser/work/moving/box/old/prices.bak
/home/labuser/work/moving/box/recipes/mocha.bak
/home/labuser/work/moving/garage/spare.bak
```

Quote the pattern. Without quotes, bash would expand `*.bak` against the current
directory first, and `find` would get the wrong name.

### Common tests

```bash
find . -iname "readme*"          # name, case-insensitive
find . -type f                   # regular files only
find . -type d -name config      # directories named config
find / -size +100M 2>/dev/null   # bigger than 100 MiB (2>/dev/null hides "Permission denied")
find . -mtime -1                 # modified less than 1 day ago
find . -mtime +30                # modified more than 30 days ago
find . -user labuser             # owned by labuser
find . -perm -o+w                # writable by others (chapter 12)
find . -name "*.tmp" -o -name "*.bak"   # OR between tests
```

Size units: `k`, `M`, `G`. `+` means more than, `-` means less than.

### Actions

```bash
find . -name "*.bak" -delete                 # delete each match
find . -name "*.sh" -exec chmod +x {} \;     # run a command per file
find . -name "*.log" -exec gzip {} +         # one command, many files (faster)
```

In `-exec`, `{}` is replaced by the file name. `\;` ends the command (one run
per file); `+` packs many files into one run.

You will also see `find ... | xargs cmd`. `xargs` turns lines of input into
arguments. Use `find ... -print0 | xargs -0 cmd` so names with spaces survive.

### locate: the fast index

```bash
locate nginx.conf       # searches a prebuilt database, instant
sudo updatedb           # refresh the database (runs daily via a timer)
```

`locate` is fast but can be out of date and is not installed everywhere.
`find` always sees the current truth.

## Try it

Write one command that lists all regular files bigger than 1 MiB under
`~/work/moving`. Then turn it into a command that deletes every `.bak` file under
`~/work/moving`, but describe what you run first.

<details>
<summary>Show answer</summary>

```bash
find ~/work/moving -type f -size +1M
find ~/work/moving -name '*.bak'           # preview first
find ~/work/moving -name '*.bak' -delete   # then delete
```

</details>

## Common mistakes

- **Putting `-delete` first.** `find . -delete -name '*.bak'` deletes everything:
  actions run in order, before the name test is applied. Tests first, action
  last.
- **Unquoted patterns.** `find . -name *.log` works only by luck. Quote it.
- **Searching `/` and drowning in errors.** Add `2>/dev/null`, or limit the
  search with `-xdev` (stay on one filesystem).
- **Trusting `locate` for new files.** It only knows what was there at the last
  `updatedb`.

## Remember

- `find WHERE TESTS ACTION`; preview, then act.
- Tests: `-name`, `-iname`, `-type`, `-size`, `-mtime`, `-user`, `-perm`.
- Actions: `-delete`, `-exec cmd {} \;` or `+`.
- `locate` is a fast but possibly stale index.

**Self-check:**

1. What does `-mtime +30` mean?
2. Why should the pattern after `-name` be quoted?
3. What is the difference between `-exec ... \;` and `-exec ... +`?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5d0e0635-a1ba-57a3-bfac-8925114a0c0a', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '63d08802-94af-5e70-adb6-8cdf39e53b00', 'Inodes, Hard Links and Symbolic Links', 'notes', 3, $md$## Why this matters

Nginx enables a site with a symlink. A deleted log can keep a disk full. A
"broken link" error stops a deploy. All three make sense once you know that a
file name is not the file.

## Mental model: rooms, doors and sticky notes

- The **inode** is the room: it holds the file's metadata (size, owner,
  permissions, timestamps, link count) and points to the data blocks on disk.
- A **directory entry** is a door: a name that leads to an inode number. A
  directory is just a list of `name -> inode number`.
- A **hard link** is a second door into the same room.
- A **symbolic link (symlink)** is a sticky note with an address written on it.

```
  directory entries          inode 4211            data blocks
  menu.txt   ---------\     +-------------+       +-----------+
                       >--> | size, owner |-----> | Espresso  |
  backups/menu.hard --/     | links: 2    |       | 3.00 ...  |
                            +-------------+       +-----------+
  current-menu  -> "/home/labuser/work/shop/menu.txt"   (symlink: just a path)
```

> **Memory hook:** a **symlink is a sticky note** with an address; a **hard link
> is a second front door** into the same room.

## See it work

```bash
cd ~/work/shop
ln -s /home/labuser/work/shop/menu.txt current-menu   # symlink
ln menu.txt backups/menu.hard                         # hard link
ls -li menu.txt current-menu backups/menu.hard
```

What this does: `ln -s TARGET NAME` writes a symlink; plain `ln TARGET NAME`
adds a hard link. `ls -i` prints the inode number in the first column. Expected
output (numbers differ):

```
4211 -rw-r--r-- 2 labuser labuser 41 ... menu.txt
4300 lrwxrwxrwx 1 labuser labuser 32 ... current-menu -> /home/labuser/work/shop/menu.txt
4211 -rw-r--r-- 2 labuser labuser 41 ... backups/menu.hard
```

Same inode (4211) and a link count of **2**: one file, two names. The symlink
has its own inode and type `l`.

```bash
readlink -f current-menu   # where does the link finally point?
stat menu.txt              # full inode details
```

### What happens on delete

`rm` removes one name and decrements the link count. The data is freed only
when the count reaches 0 **and** no process still has the file open.

```bash
rm menu.txt
cat backups/menu.hard     # still works: the room has another door
cat current-menu          # fails: the address on the sticky note is gone
```

```
Espresso 3.00 | Latte 4.50 | Mocha 5.00
cat: current-menu: No such file or directory
```

A symlink whose target is gone is called **dangling**.

### Comparison

| | Hard link (`ln`) | Symbolic link (`ln -s`) |
|---|---|---|
| What it is | a second name for the same inode | a tiny file containing a path |
| Original name deleted | data survives | link breaks (dangling) |
| Across filesystems | no | yes |
| For directories | no | yes |
| Typical use | rare; backups, dedup | config switches, versions |

Classic symlink uses:

```bash
ln -s /etc/nginx/sites-available/shop /etc/nginx/sites-enabled/shop
ln -sfn /opt/brewbot/releases/2.4.1 /opt/brewbot/current   # switch versions
```

`-f` replaces an existing link; `-n` treats an existing link to a directory as a
file, so it is replaced rather than entered.

### Inodes can run out

Every file uses one inode, and a filesystem has a fixed number. Millions of tiny
files can exhaust inodes while plenty of space remains. `df -i` shows inode
usage. This returns in Incident Week.

## Try it

You make a hard link `b` to file `a`, then edit `b` with nano. Does `a` change?
Then you delete `a`. Is `b` still readable?

<details>
<summary>Show answer</summary>

Usually yes and yes. `a` and `b` are the same inode, so an edit through one name
shows through the other, and deleting `a` only removes one name; `b` keeps the
data alive. (Some editors save by writing a new file and renaming it, which
gives `b` a new inode and breaks the link. `ls -li` shows whether the inode
numbers still match.)

</details>

## Common mistakes

- **Reversing the arguments.** It is `ln -s TARGET LINKNAME`, the same order as
  `cp SOURCE DEST`.
- **Relative symlinks created from the wrong place.** A relative target is
  resolved from the link's directory, not from where you ran `ln`. Use absolute
  targets until you are comfortable.
- **Thinking `rm` on a symlink deletes the target.** It deletes only the sticky
  note.
- **Expecting a hard link across disks.** Inode numbers are per filesystem, so
  `ln` fails with "Invalid cross-device link". Use a symlink.

## Remember

- A name points to an inode; the inode holds metadata and points to the data.
- Hard link = same inode, another name. Symlink = a file holding a path.
- Data is freed when the link count is 0 and nobody has it open.
- `ls -li`, `stat`, `readlink -f` reveal what is really going on.

**Self-check:**

1. What does the number after the permissions in `ls -l` count?
2. Why can a hard link not point to a file on another disk?
3. What is a dangling symlink?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b235d4e1-d303-58e8-8e4d-abd8d4340caa', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '63d08802-94af-5e70-adb6-8cdf39e53b00', 'How Big Is It, and What Is It? du, ls -S and file', 'notes', 4, $md$## Why this matters

"The disk is almost full" is one of the most common pages a sysadmin gets. You
must find the heavy files in seconds. And because Linux ignores extensions, you
also need a way to ask what a file really contains.

## Mental model: weigh the boxes, then open one

- `du` (**d**isk **u**sage) weighs boxes: how much space a file or directory
  tree uses.
- `ls -lS` lines files up by size inside one directory.
- `file` opens the box and looks inside: what kind of data is this?

Chapter 7 adds `df` (**d**isk **f**ree), which weighs whole disks. Start with
`df` to find the full disk, drill down with `du`.

## See it work

```bash
du -sh ~/work/moving
```

What this does: `-s` gives one summary total, `-h` prints human units. Expected
output:

```
2.1M	/home/labuser/work/moving
```

Rank everything inside, biggest last:

```bash
du -ah ~/work/moving | sort -h | tail -5
```

What this does: `-a` lists files too, not just directories; `sort -h`
understands human sizes like `4.0K` and `2.0M`; `tail -5` keeps the five biggest
(the last lines). Expected output (similar):

```
16K	/home/labuser/work/moving/box/recipes
40K	/home/labuser/work/moving/box
2.0M	/home/labuser/work/moving/garage/beans-inventory.csv
2.1M	/home/labuser/work/moving
2.1M	/home/labuser/work/moving/garage
```

The biggest *file* is the first line that is not a directory total:
`beans-inventory.csv`. You will meet the pipe `|` properly in chapter 3; for now
read it as "and then".

```bash
ls -lhS ~/work/moving/garage      # this directory, sorted by size, biggest first
find ~/work/moving -type f -size +1M   # just the big files
```

### Sizes on disk vs apparent size

`ls -l` shows the **apparent size** (bytes in the file). `du` shows **space
used on disk** (whole blocks, usually 4 KiB each). A 10-byte file shows `10` in
`ls -l` but `4.0K` in `du`. For "what fills my disk", trust `du`.

### What kind of file is it?

```bash
file ~/work/moving/garage/beans-inventory.csv
file /usr/bin/ls
file ~/.bashrc
```

```
.../beans-inventory.csv: data
/usr/bin/ls: ELF 64-bit LSB pie executable, x86-64, ...
/home/labuser/.bashrc: ASCII text
```

The `.csv` file is not text at all: `file` looks at the content and finds raw
binary data. Linux does not care about extensions; they are just part of the
name. (`file` may not be installed on minimal images; `head -c 64 FILE | od -c`
is a fallback.)

## Try it

Write a pipeline that shows the 3 largest items under `/var/log` with human
sizes, hiding "Permission denied" errors.

<details>
<summary>Show answer</summary>

```bash
du -ah /var/log 2>/dev/null | sort -h | tail -3
```

`2>/dev/null` throws away error messages (chapter 3 explains why that works).

</details>

## Common mistakes

- **Using `sort -n` on human sizes.** `-n` thinks `900K` is bigger than `2.0M`.
  Use `sort -h` with `-h` output.
- **Looking only at `ls -l`.** It shows one directory and apparent sizes. Use
  `du` for trees.
- **Trusting extensions.** `report.pdf` might be an executable. Check with
  `file`.

## Remember

- `du -sh DIR` = total; `du -ah DIR | sort -h | tail` = the heaviest items.
- `ls -lhS` sorts one directory by size.
- `find -size +1M` filters by size.
- `file` reports what the content really is; extensions mean nothing to Linux.

**Self-check:**

1. Why does a 10-byte file show 4.0K in `du`?
2. Which `sort` option understands `2.0M`?
3. How do you check whether a `.txt` file is really text?
$md$, 6, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('7aca830d-151a-5ddd-b824-189d87652f8d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '63d08802-94af-5e70-adb6-8cdf39e53b00', 'Lab: Unpack the Boxes', 'notes', 5, $md$## Why this matters

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
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('f88e3d11-37ed-5d49-a2fc-588e50584208', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '7aca830d-151a-5ddd-b824-189d87652f8d', 'module', 'Lab: Unpack the Boxes', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
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
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '4dcf5149-1aba-5323-a07f-9c7061e18ff8' AND id NOT IN ('23449351-d653-5286-9afa-7448431995b4', '408ee77e-ed5e-5281-8b77-eff44b5f19a9', '27393828-6d30-5fed-b91e-a620fc0efb26', 'fc55826c-c5ee-5384-bfa9-f36c046189ca', 'b28d1720-b68a-5f0d-8e1a-ea3fbe02b42a');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '4dcf5149-1aba-5323-a07f-9c7061e18ff8';
DELETE FROM lab_tasks WHERE lab_id = 'f88e3d11-37ed-5d49-a2fc-588e50584208' AND id NOT IN ('6998c437-10ca-5703-a08f-054b11d8caf9', 'cb39898d-640f-51f7-9e9f-54c3e17881b5', '7109941e-a02e-58a9-b567-fcff498603fb', 'e8c3cc24-07d3-5bed-babd-cb22b692cc9c', '32019b28-5296-5165-a93b-76db427f321e');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'f88e3d11-37ed-5d49-a2fc-588e50584208';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('6998c437-10ca-5703-a08f-054b11d8caf9', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 1, 'Build the shop skeleton', $md$Create /home/labuser/work/shop with three subdirectories inside it - config, logs and backups - using a single mkdir command.$md$, $script$s=/home/labuser/work/shop
[ -d $s/config ] && [ -d $s/logs ] && [ -d $s/backups ]
$script$, 'mkdir -p creates parent directories as needed, and brace expansion {config,logs,backups} turns one word into three.', 'mkdir -p never fails if a directory already exists and creates every missing parent. Bash expands shop/{a,b,c} into three separate arguments before mkdir even runs.', 10, false, true),
('cb39898d-640f-51f7-9e9f-54c3e17881b5', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 2, 'Unpack the box', $md$Copy the whole moving/box/recipes directory (with its contents) to shop/config/recipes, and move moving/box/menu.txt to shop/menu.txt so it no longer exists in the box.$md$, $script$w=/home/labuser/work
[ -f $w/shop/config/recipes/espresso.txt ] && [ -f $w/shop/config/recipes/latte.txt ] &&
[ -f $w/moving/box/recipes/espresso.txt ] &&
[ -f $w/shop/menu.txt ] && [ ! -e $w/moving/box/menu.txt ]
$script$, 'cp needs -r to copy a directory. mv both moves and renames; the source disappears.', 'cp -r copies a tree and leaves the original in place. mv only changes where the name points, so within one filesystem it is instant even for huge files.', 15, false, true),
('7109941e-a02e-58a9-b567-fcff498603fb', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 3, 'Throw out the junk', $md$Delete every file ending in .bak anywhere under moving/ (there are several, in different folders) with one find command. Every other file must survive.$md$, $script$w=/home/labuser/work/moving
[ -z "$(find $w -name '*.bak')" ] &&
[ -f $w/garage/tools.txt ] && [ -f $w/box/old/receipts.csv ] && [ -f $w/garage/beans-inventory.csv ]
$script$, 'find DIR -name ''*.bak'' lists matches; run it first to check, then add -delete. Quote the pattern so the shell does not expand it.', 'find walks the whole tree. Always run it without -delete first - rm and -delete have no undo and no recycle bin in Linux.', 20, false, true),
('e8c3cc24-07d3-5bed-babd-cb22b692cc9c', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 4, 'Two kinds of links', $md$Create a symbolic link shop/current-menu pointing to /home/labuser/work/shop/menu.txt, and a hard link shop/backups/menu.hard to the same menu.txt.$md$, $script$s=/home/labuser/work/shop
[ -L $s/current-menu ] && [ "$(readlink -f $s/current-menu)" = $s/menu.txt ] &&
[ ! -L $s/backups/menu.hard ] && [ $s/backups/menu.hard -ef $s/menu.txt ]
$script$, 'ln -s TARGET LINKNAME makes a symlink; ln TARGET LINKNAME (no -s) makes a hard link. ls -li shows inode numbers - hard links share one.', 'A symlink is a small file holding a path, so it breaks if the target moves. A hard link is a second name for the same inode, so the data lives until the last name is removed.', 25, false, true),
('32019b28-5296-5165-a93b-76db427f321e', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 5, 'What is eating the space?', $md$Find the largest file anywhere under moving/ and save its file name (just the name, not the path) into answers/biggest.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/biggest.txt)" = beans-inventory.csv ]
$script$, 'find moving -type f -size +1M lists files bigger than 1 MiB, or ls -lhR / du -ah moving | sort -h shows sizes.', 'find -size filters by size, and du -ah | sort -h ranks everything. This is the first thing you do when a disk fills up.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('4dcf5149-1aba-5323-a07f-9c7061e18ff8', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 1, $json$[{"id":"6998c437-10ca-5703-a08f-054b11d8caf9","lab_id":"f88e3d11-37ed-5d49-a2fc-588e50584208","position":1,"title":"Build the shop skeleton","description":"Create /home/labuser/work/shop with three subdirectories inside it - config, logs and backups - using a single mkdir command.","verification_script":"s=/home/labuser/work/shop\n[ -d $s/config ] \u0026\u0026 [ -d $s/logs ] \u0026\u0026 [ -d $s/backups ]\n","hint_context":"mkdir -p creates parent directories as needed, and brace expansion {config,logs,backups} turns one word into three.","explanation_context":"mkdir -p never fails if a directory already exists and creates every missing parent. Bash expands shop/{a,b,c} into three separate arguments before mkdir even runs.","points":10,"is_optional":false,"is_stateful":true},{"id":"cb39898d-640f-51f7-9e9f-54c3e17881b5","lab_id":"f88e3d11-37ed-5d49-a2fc-588e50584208","position":2,"title":"Unpack the box","description":"Copy the whole moving/box/recipes directory (with its contents) to shop/config/recipes, and move moving/box/menu.txt to shop/menu.txt so it no longer exists in the box.","verification_script":"w=/home/labuser/work\n[ -f $w/shop/config/recipes/espresso.txt ] \u0026\u0026 [ -f $w/shop/config/recipes/latte.txt ] \u0026\u0026\n[ -f $w/moving/box/recipes/espresso.txt ] \u0026\u0026\n[ -f $w/shop/menu.txt ] \u0026\u0026 [ ! -e $w/moving/box/menu.txt ]\n","hint_context":"cp needs -r to copy a directory. mv both moves and renames; the source disappears.","explanation_context":"cp -r copies a tree and leaves the original in place. mv only changes where the name points, so within one filesystem it is instant even for huge files.","points":15,"is_optional":false,"is_stateful":true},{"id":"7109941e-a02e-58a9-b567-fcff498603fb","lab_id":"f88e3d11-37ed-5d49-a2fc-588e50584208","position":3,"title":"Throw out the junk","description":"Delete every file ending in .bak anywhere under moving/ (there are several, in different folders) with one find command. Every other file must survive.","verification_script":"w=/home/labuser/work/moving\n[ -z \"$(find $w -name '*.bak')\" ] \u0026\u0026\n[ -f $w/garage/tools.txt ] \u0026\u0026 [ -f $w/box/old/receipts.csv ] \u0026\u0026 [ -f $w/garage/beans-inventory.csv ]\n","hint_context":"find DIR -name '*.bak' lists matches; run it first to check, then add -delete. Quote the pattern so the shell does not expand it.","explanation_context":"find walks the whole tree. Always run it without -delete first - rm and -delete have no undo and no recycle bin in Linux.","points":20,"is_optional":false,"is_stateful":true},{"id":"e8c3cc24-07d3-5bed-babd-cb22b692cc9c","lab_id":"f88e3d11-37ed-5d49-a2fc-588e50584208","position":4,"title":"Two kinds of links","description":"Create a symbolic link shop/current-menu pointing to /home/labuser/work/shop/menu.txt, and a hard link shop/backups/menu.hard to the same menu.txt.","verification_script":"s=/home/labuser/work/shop\n[ -L $s/current-menu ] \u0026\u0026 [ \"$(readlink -f $s/current-menu)\" = $s/menu.txt ] \u0026\u0026\n[ ! -L $s/backups/menu.hard ] \u0026\u0026 [ $s/backups/menu.hard -ef $s/menu.txt ]\n","hint_context":"ln -s TARGET LINKNAME makes a symlink; ln TARGET LINKNAME (no -s) makes a hard link. ls -li shows inode numbers - hard links share one.","explanation_context":"A symlink is a small file holding a path, so it breaks if the target moves. A hard link is a second name for the same inode, so the data lives until the last name is removed.","points":25,"is_optional":false,"is_stateful":true},{"id":"32019b28-5296-5165-a93b-76db427f321e","lab_id":"f88e3d11-37ed-5d49-a2fc-588e50584208","position":5,"title":"What is eating the space?","description":"Find the largest file anywhere under moving/ and save its file name (just the name, not the path) into answers/biggest.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/biggest.txt)\" = beans-inventory.csv ]\n","hint_context":"find moving -type f -size +1M lists files bigger than 1 MiB, or ls -lhR / du -ah moving | sort -h shows sizes.","explanation_context":"find -size filters by size, and du -ah | sort -h ranks everything. This is the first thing you do when a disk fills up.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('23449351-d653-5286-9afa-7448431995b4', '4dcf5149-1aba-5323-a07f-9c7061e18ff8', '6998c437-10ca-5703-a08f-054b11d8caf9', 1, 'Build the shop skeleton', $md$Create /home/labuser/work/shop with three subdirectories inside it - config, logs and backups - using a single mkdir command.$md$, $script$s=/home/labuser/work/shop
[ -d $s/config ] && [ -d $s/logs ] && [ -d $s/backups ]
$script$, 'mkdir -p creates parent directories as needed, and brace expansion {config,logs,backups} turns one word into three.', 'mkdir -p never fails if a directory already exists and creates every missing parent. Bash expands shop/{a,b,c} into three separate arguments before mkdir even runs.', 10, false, true),
('408ee77e-ed5e-5281-8b77-eff44b5f19a9', '4dcf5149-1aba-5323-a07f-9c7061e18ff8', 'cb39898d-640f-51f7-9e9f-54c3e17881b5', 2, 'Unpack the box', $md$Copy the whole moving/box/recipes directory (with its contents) to shop/config/recipes, and move moving/box/menu.txt to shop/menu.txt so it no longer exists in the box.$md$, $script$w=/home/labuser/work
[ -f $w/shop/config/recipes/espresso.txt ] && [ -f $w/shop/config/recipes/latte.txt ] &&
[ -f $w/moving/box/recipes/espresso.txt ] &&
[ -f $w/shop/menu.txt ] && [ ! -e $w/moving/box/menu.txt ]
$script$, 'cp needs -r to copy a directory. mv both moves and renames; the source disappears.', 'cp -r copies a tree and leaves the original in place. mv only changes where the name points, so within one filesystem it is instant even for huge files.', 15, false, true),
('27393828-6d30-5fed-b91e-a620fc0efb26', '4dcf5149-1aba-5323-a07f-9c7061e18ff8', '7109941e-a02e-58a9-b567-fcff498603fb', 3, 'Throw out the junk', $md$Delete every file ending in .bak anywhere under moving/ (there are several, in different folders) with one find command. Every other file must survive.$md$, $script$w=/home/labuser/work/moving
[ -z "$(find $w -name '*.bak')" ] &&
[ -f $w/garage/tools.txt ] && [ -f $w/box/old/receipts.csv ] && [ -f $w/garage/beans-inventory.csv ]
$script$, 'find DIR -name ''*.bak'' lists matches; run it first to check, then add -delete. Quote the pattern so the shell does not expand it.', 'find walks the whole tree. Always run it without -delete first - rm and -delete have no undo and no recycle bin in Linux.', 20, false, true),
('fc55826c-c5ee-5384-bfa9-f36c046189ca', '4dcf5149-1aba-5323-a07f-9c7061e18ff8', 'e8c3cc24-07d3-5bed-babd-cb22b692cc9c', 4, 'Two kinds of links', $md$Create a symbolic link shop/current-menu pointing to /home/labuser/work/shop/menu.txt, and a hard link shop/backups/menu.hard to the same menu.txt.$md$, $script$s=/home/labuser/work/shop
[ -L $s/current-menu ] && [ "$(readlink -f $s/current-menu)" = $s/menu.txt ] &&
[ ! -L $s/backups/menu.hard ] && [ $s/backups/menu.hard -ef $s/menu.txt ]
$script$, 'ln -s TARGET LINKNAME makes a symlink; ln TARGET LINKNAME (no -s) makes a hard link. ls -li shows inode numbers - hard links share one.', 'A symlink is a small file holding a path, so it breaks if the target moves. A hard link is a second name for the same inode, so the data lives until the last name is removed.', 25, false, true),
('b28d1720-b68a-5f0d-8e1a-ea3fbe02b42a', '4dcf5149-1aba-5323-a07f-9c7061e18ff8', '32019b28-5296-5165-a93b-76db427f321e', 5, 'What is eating the space?', $md$Find the largest file anywhere under moving/ and save its file name (just the name, not the path) into answers/biggest.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/biggest.txt)" = beans-inventory.csv ]
$script$, 'find moving -type f -size +1M lists files bigger than 1 MiB, or ls -lhR / du -ah moving | sort -h shows sizes.', 'find -size filters by size, and du -ah | sort -h ranks everything. This is the first thing you do when a disk fills up.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '4dcf5149-1aba-5323-a07f-9c7061e18ff8', updated_at = now()
WHERE id = 'f88e3d11-37ed-5d49-a2fc-588e50584208' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('44440d58-8bee-583d-8582-e57bfe163823', '00000000-0000-0000-0000-000000000001', 'mcq', 'You run echo ''port = 8080'' > app.conf on a config file that had 40 lines. Wha...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('15441b99-fbd2-568e-9020-33f181852112', '44440d58-8bee-583d-8582-e57bfe163823', 1, $json${"prompt":"You run echo 'port = 8080' \u003e app.conf on a config file that had 40 lines. What is in app.conf now?","multiple":false,"options":[{"id":"a","text":"41 lines: the old 40 plus the new one at the end","is_correct":false},{"id":"b","text":"Only the line port = 8080","is_correct":true},{"id":"c","text":"The new line at the top, followed by the old 40","is_correct":false},{"id":"d","text":"Nothing; \u003e refuses to touch existing files","is_correct":false}],"explanation":"A single \u003e truncates the file and then writes. Appending at the end is \u003e\u003e. Neither operator inserts at the top, and \u003e never refuses (unless the shell option noclobber is set)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0ebfea28-a836-5a52-b53f-981c3d1cfd03', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command creates releases/v1, releases/v2 and releases/v3, even if relea...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('cf45b1c0-27df-5367-b902-e622081b3381', '0ebfea28-a836-5a52-b53f-981c3d1cfd03', 1, $json${"prompt":"Which command creates releases/v1, releases/v2 and releases/v3, even if releases does not exist yet?","multiple":false,"options":[{"id":"a","text":"mkdir releases/{v1,v2,v3}","is_correct":false},{"id":"b","text":"mkdir -p releases/{v1,v2,v3}","is_correct":true},{"id":"c","text":"mkdir -p releases/{v1, v2, v3}","is_correct":false},{"id":"d","text":"touch -p releases/v1 releases/v2 releases/v3","is_correct":false}],"explanation":"-p creates the missing parent, and the braces expand to three paths. Without -p, mkdir fails because releases is missing. Spaces inside braces stop the expansion. touch creates files, not directories, and has no -p."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('36cc3a39-f0ee-56b5-91f3-031edb74bc0b', '00000000-0000-0000-0000-000000000001', 'mcq', 'You want to delete all .tmp files under /srv/cache. What is the safest sequence?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b9458dfe-9eab-5597-ab3a-98ddafdbd5ac', '36cc3a39-f0ee-56b5-91f3-031edb74bc0b', 1, $json${"prompt":"You want to delete all .tmp files under /srv/cache. What is the safest sequence?","multiple":false,"options":[{"id":"a","text":"find /srv/cache -delete -name '*.tmp'","is_correct":false},{"id":"b","text":"rm -rf /srv/cache/*","is_correct":false},{"id":"c","text":"find /srv/cache -name '*.tmp' first, check the list, then find /srv/cache -name '*.tmp' -delete","is_correct":true},{"id":"d","text":"find /srv/cache -name *.tmp -delete","is_correct":false}],"explanation":"Preview, then act. With -delete before -name, find deletes everything it walks. rm -rf removes all files, not only .tmp. An unquoted *.tmp may be expanded by the shell in the current directory and pass the wrong name to find."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('48337ab7-cf0c-51a7-bca4-2951728d59c2', '00000000-0000-0000-0000-000000000001', 'mcq', 'nginx''s sites-enabled/shop is a symlink to sites-available/shop. Someone dele...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('915e4458-3158-5d00-84e0-ca6581c8e4a5', '48337ab7-cf0c-51a7-bca4-2951728d59c2', 1, $json${"prompt":"nginx's sites-enabled/shop is a symlink to sites-available/shop. Someone deletes sites-available/shop. What happens to sites-enabled/shop?","multiple":false,"options":[{"id":"a","text":"It still has the config, because a symlink copies the content","is_correct":false},{"id":"b","text":"It becomes a dangling link: it still exists but points to nothing","is_correct":true},{"id":"c","text":"It is deleted automatically","is_correct":false},{"id":"d","text":"It turns into a hard link","is_correct":false}],"explanation":"A symlink only stores a path. When the target goes, the link remains but leads nowhere, and nginx will fail to read it. Only a hard link would keep the data alive. Links never change type by themselves."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f8738fcb-7e6e-5e4c-a392-02effc84e6b7', '00000000-0000-0000-0000-000000000001', 'mcq', 'ls -li shows two names with the same inode number and a link count of 2. What...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bbdcfa74-49a1-592e-872c-9df2f088d024', 'f8738fcb-7e6e-5e4c-a392-02effc84e6b7', 1, $json${"prompt":"ls -li shows two names with the same inode number and a link count of 2. What does that mean?","multiple":false,"options":[{"id":"a","text":"They are two copies that happen to be identical","is_correct":false},{"id":"b","text":"They are two names for the same file data; editing one changes the other","is_correct":true},{"id":"c","text":"One of them is a symlink","is_correct":false},{"id":"d","text":"The filesystem is corrupted","is_correct":false}],"explanation":"Same inode = same file. A hard link is a second name. Copies would have different inodes, a symlink has its own inode and type l, and shared inodes are completely normal."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3d33bf47-20c3-50ee-a009-e18a1821ef1c', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which pipeline shows the five largest items under /var/log, biggest last?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7c2836db-aff7-509f-aadf-5ed4a45aba17', '3d33bf47-20c3-50ee-a009-e18a1821ef1c', 1, $json${"prompt":"Which pipeline shows the five largest items under /var/log, biggest last?","multiple":false,"options":[{"id":"a","text":"du -ah /var/log | sort -h | tail -5","is_correct":true},{"id":"b","text":"du -ah /var/log | sort -n | head -5","is_correct":false},{"id":"c","text":"ls /var/log | tail -5","is_correct":false},{"id":"d","text":"df -h /var/log | tail -5","is_correct":false}],"explanation":"du -ah prints sizes like 2.0M, sort -h orders them correctly and tail keeps the last (largest) lines. sort -n misorders human sizes and head keeps the smallest. ls prints names without sizes, and df reports whole filesystems, not files."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('52af8a93-9e22-5858-8fe7-bbed0e9e122a', '00000000-0000-0000-0000-000000000001', 'mcq', 'A file is called invoice.pdf. How do you find out what it really contains?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('fd244b1d-041f-50b4-9a8d-dbfe8f510f6d', '52af8a93-9e22-5858-8fe7-bbed0e9e122a', 1, $json${"prompt":"A file is called invoice.pdf. How do you find out what it really contains?","multiple":false,"options":[{"id":"a","text":"Trust the .pdf extension","is_correct":false},{"id":"b","text":"Run file invoice.pdf","is_correct":true},{"id":"c","text":"Run ls -l invoice.pdf","is_correct":false},{"id":"d","text":"Rename it to .txt and cat it","is_correct":false}],"explanation":"file inspects the content. Linux ignores extensions, so the name proves nothing. ls -l shows size and permissions, not content type, and renaming changes nothing about the data."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('84d16779-7d1b-5849-bdc3-b486b4e52c25', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 1): you are in /etc. Which command lists hidden files in your...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1379f930-cc15-5b27-9f27-fbabc02985f2', '84d16779-7d1b-5849-bdc3-b486b4e52c25', 1, $json${"prompt":"Review (chapter 1): you are in /etc. Which command lists hidden files in your home directory?","multiple":false,"options":[{"id":"a","text":"ls -a ~","is_correct":true},{"id":"b","text":"ls ~","is_correct":false},{"id":"c","text":"ls -a","is_correct":false},{"id":"d","text":"ls -l /root","is_correct":false}],"explanation":"~ is your home and -a includes dot-files. Plain ls hides them, ls -a alone lists /etc (where you are), and /root is the root user's home, not yours."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('2994834e-167d-59ca-9cae-bff42ae900ed', '00000000-0000-0000-0000-000000000001', 'Quiz: Working with Files', 'linux-moving-in-quiz', 'Quiz covering Chapter 2: Moving In - Working with Files.', 'mcq', 'published', 'module', '9316f12f-6675-5d94-bb0a-f55dbf0c73f1', 10, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '2994834e-167d-59ca-9cae-bff42ae900ed' AND question_id NOT IN ('44440d58-8bee-583d-8582-e57bfe163823', '0ebfea28-a836-5a52-b53f-981c3d1cfd03', '36cc3a39-f0ee-56b5-91f3-031edb74bc0b', '48337ab7-cf0c-51a7-bca4-2951728d59c2', 'f8738fcb-7e6e-5e4c-a392-02effc84e6b7', '3d33bf47-20c3-50ee-a009-e18a1821ef1c', '52af8a93-9e22-5858-8fe7-bbed0e9e122a', '84d16779-7d1b-5849-bdc3-b486b4e52c25');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('00cc9f91-973e-5375-bd5b-3ccd20dc39c7', '2994834e-167d-59ca-9cae-bff42ae900ed', '44440d58-8bee-583d-8582-e57bfe163823', '15441b99-fbd2-568e-9020-33f181852112', 0, 2),
('2ed60294-f9ad-557e-8c27-7f4ee7f64737', '2994834e-167d-59ca-9cae-bff42ae900ed', '0ebfea28-a836-5a52-b53f-981c3d1cfd03', 'cf45b1c0-27df-5367-b902-e622081b3381', 1, 2),
('e9e27bef-d22d-5ca8-ab40-9f488ff22cb8', '2994834e-167d-59ca-9cae-bff42ae900ed', '36cc3a39-f0ee-56b5-91f3-031edb74bc0b', 'b9458dfe-9eab-5597-ab3a-98ddafdbd5ac', 2, 2),
('cb6cbdb1-eb92-5347-a391-cda1ee7fe877', '2994834e-167d-59ca-9cae-bff42ae900ed', '48337ab7-cf0c-51a7-bca4-2951728d59c2', '915e4458-3158-5d00-84e0-ca6581c8e4a5', 3, 2),
('31ad7bd6-b2a2-5773-8685-3b1f40742979', '2994834e-167d-59ca-9cae-bff42ae900ed', 'f8738fcb-7e6e-5e4c-a392-02effc84e6b7', 'bbdcfa74-49a1-592e-872c-9df2f088d024', 4, 2),
('cd6bbf03-db6d-5018-881e-bc49d11310d5', '2994834e-167d-59ca-9cae-bff42ae900ed', '3d33bf47-20c3-50ee-a009-e18a1821ef1c', '7c2836db-aff7-509f-aadf-5ed4a45aba17', 5, 2),
('bd389236-fe3e-58d6-aebc-95e145d39d1c', '2994834e-167d-59ca-9cae-bff42ae900ed', '52af8a93-9e22-5858-8fe7-bbed0e9e122a', 'fd244b1d-041f-50b4-9a8d-dbfe8f510f6d', 6, 2),
('182f6844-e119-54ee-a6a4-fce69a8216cb', '2994834e-167d-59ca-9cae-bff42ae900ed', '84d16779-7d1b-5849-bdc3-b486b4e52c25', '1379f930-cc15-5b27-9f27-fbabc02985f2', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('9316f12f-6675-5d94-bb0a-f55dbf0c73f1', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '63d08802-94af-5e70-adb6-8cdf39e53b00', 'Quiz: Working with Files', 'assessment', 6, 8, '2994834e-167d-59ca-9cae-bff42ae900ed')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 3: The Logbook - Text Tools and Pipes
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 3: The Logbook - Text Tools and Pipes', 3, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5a5b409f-a43c-5413-8bac-dbbdd8d138d7', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'Looking at Files: cat, less, head, tail and wc', 'notes', 0, $md$## Why this matters

> **Wednesday, 10:14.** Customers say checkout is broken. Rhea: "Tom always said
> *the logs never lie*. Don't guess, read the logbook." In `~/work/logbook` you
> have the web server's `access.log` and the app's `app.log`.

Logs are text, and they are big. Dumping a 2 GB log to the screen helps nobody.
You need to look at the right part: the start, the end, or the live stream.

## Mental model: a queue of customers

A log is a queue. New lines join at the **end**.

```
 first line  ... ... ... ... ... ... ... ... ... ... last line  <- new lines arrive here
 \__ head __/                                   \__ tail __/
                                                tail -f = stand at the end and watch
```

> **Memory hook:** `head` and `tail` are the two ends of the coffee queue.
> `tail -f` is standing at the end **forever**, watching new customers arrive.

## See it work

```bash
cd ~/work/logbook
wc -l app.log access.log
```

What this does: counts lines in each file (always check the size before
opening). Expected output:

```
   80 app.log
  275 access.log
  355 total
```

```bash
head -n 3 app.log      # first 3 lines
tail -n 2 app.log      # last 2 lines
```

```
2026-10-14 10:1:00 INFO order placed order=1
2026-10-14 10:2:00 INFO order placed order=2
2026-10-14 10:3:00 ERROR payment gateway timeout order=3
2026-10-14 10:19:00 INFO order placed order=79
2026-10-14 10:20:00 ERROR payment gateway timeout order=80
```

`-n` sets how many lines (default 10). `tail -n +50` means "from line 50 to the
end".

### Following a live log

```bash
tail -f /var/log/syslog         # print new lines as they arrive; Ctrl+C stops
tail -F app.log                 # same, but survives log rotation
```

`-F` reopens the file if it is renamed and recreated, which is what log rotation
does every night (chapter 6).

### Scrolling with less

```bash
less access.log
```

| Key | Action |
|---|---|
| Space / b | page down / back |
| `g` / `G` | top / bottom |
| `/500` Enter | search forward for "500"; `n` next, `N` previous |
| `F` | follow mode (like `tail -f`); Ctrl+C to stop following |
| `q` | quit |

`less` opens huge files instantly because it reads only what it shows.

### cat and wc

```bash
cat small.txt           # print the whole file (fine for small files)
cat a.txt b.txt         # concatenate: print both, one after another
wc -l file              # lines; -w words, -c bytes
```

`cat` stands for con**cat**enate. On a big log, prefer `less`.

## Try it

Show the last 20 lines of `access.log`, then open it in `less` and jump to the
first line containing `404`.

<details>
<summary>Show answer</summary>

```bash
tail -n 20 access.log
less access.log      # then type /404 and press Enter; n for the next one
```

</details>

## Common mistakes

- **`cat` on a huge file.** Your terminal scrolls for minutes. Use `less`, `head`
  or `tail`.
- **`tail -f` on a rotated log.** After rotation it watches the old, renamed
  file and shows nothing new. Use `tail -F`.
- **Opening a log in an editor.** `vi` or `nano` load the whole file and can
  save changes by accident. `less` is read-only.

## Remember

- `wc -l` to size it up, `head`/`tail` for the ends, `less` to explore.
- `tail -f` (or `-F`) follows a live log.
- In `less`: `/word` search, `G` end, `F` follow, `q` quit.

**Self-check:**

1. What is the difference between `tail -f` and `tail -F`?
2. How do you jump to the end of a file in `less`?
3. Which command counts the lines of a file?
$md$, 6, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ca211df5-0a8e-5362-b113-b41608481009', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'grep: Finding the Needle, with a Little Regex', 'notes', 1, $md$## Why this matters

`app.log` has 80 lines today and will have 8 million next year. The first
question in every incident is "show me only the lines that matter". `grep` does
exactly that, and it is the command you will type most often on a server.

## Mental model: a sieve

`grep PATTERN FILE` pours every line through a sieve. Lines that contain the
pattern fall through to your screen; the rest stay behind.

```
  80 lines  -->  [ grep ERROR ]  -->  16 lines that contain "ERROR"
```

Options change the sieve: count instead of print (`-c`), keep the *non*-matching
lines (`-v`), ignore case (`-i`).

## See it work

```bash
cd ~/work/logbook
grep ERROR app.log | head -3
```

What this does: prints lines containing `ERROR` (only the first 3 here).
Expected output:

```
2026-10-14 10:3:00 ERROR payment gateway timeout order=3
2026-10-14 10:10:00 ERROR payment gateway timeout order=10
2026-10-14 10:13:00 ERROR payment gateway timeout order=13
```

```bash
grep -c ERROR app.log       # count matching lines
grep -c WARN app.log
```

```
16
8
```

### The options you will use daily

```bash
grep -i error app.log           # ignore case: error, Error, ERROR
grep -v INFO app.log            # invert: lines WITHOUT INFO
grep -n timeout app.log         # prefix line numbers
grep -w port app.conf           # whole word: not "export" or "portal"
grep -r "port" /etc/brewbot/    # search every file in a directory tree
grep -l "port" /etc/*.conf      # list only file names that match
grep -E "ERROR|WARN" app.log    # extended regex: either word
grep -A2 -B1 ERROR app.log      # 2 lines After and 1 Before each match
grep -q ERROR app.log && echo found   # quiet: only the exit code (for scripts)
```

Context (`-A`, `-B`, `-C`) is gold in incidents: the line before an error often
says what caused it.

```bash
grep -n -B1 WARN app.log | head -2
```

```
4-2026-10-14 10:4:00 INFO login user=u4 password=s3cret4
5:2026-10-14 10:5:00 WARN slow query 1200ms order=5
```

With `-n`, matching lines use `:` after the number and context lines use `-`.

### Regex survival kit

A **regular expression (regex)** is a pattern language. Six symbols cover most
needs:

| Symbol | Means | Example | Matches |
|---|---|---|---|
| `^` | start of line | `^2026` | lines starting with 2026 |
| `$` | end of line | `order=3$` | lines ending in order=3 |
| `.` | any one character | `10.0` | 10.0, 1000, 10x0 |
| `*` | previous item 0+ times | `ab*c` | ac, abc, abbbc |
| `[...]` | one character from a set | `[0-9]` | one digit |
| `[^...]` | one character NOT in the set | `[^ ]*` | a run of non-spaces |

With `-E` (extended regex) you also get `+` (1 or more), `?` (0 or 1), `|` (or),
`()` (groups) and `{n}` (exactly n times).

```bash
grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3} ' access.log | head -1   # lines starting with an IPv4
grep -c ' 500 ' access.log                                     # status 500, surrounded by spaces
grep -F '[error]' nginx.log                                    # -F: fixed string, no regex at all
```

Always put patterns in **single quotes** so the shell does not touch `*`, `$` or
`|`.

## Try it

From `app.log`, count the lines that are either ERROR or WARN, and then print
every line that is *not* INFO, with line numbers.

<details>
<summary>Show answer</summary>

```bash
grep -cE 'ERROR|WARN' app.log     # 24
grep -nv INFO app.log
```

</details>

## Common mistakes

- **Unquoted patterns.** `grep ERROR|WARN app.log` makes the shell pipe into a
  command called `WARN`. Quote: `grep -E 'ERROR|WARN'`.
- **Forgetting that `.` is special.** `grep 10.0.0.5` also matches `10a0b0c5`.
  Use `grep -F 10.0.0.5` or escape the dots: `10\.0\.0\.5`.
- **`|` without `-E`.** Basic grep treats `|` as a literal character.
- **`cat file | grep x`.** Works, but `grep x file` is shorter and lets grep
  print file names.

## Remember

- `grep PATTERN FILE` prints matching lines; `-c` counts, `-v` inverts, `-i`
  ignores case, `-n` numbers, `-r` recurses.
- `-A/-B/-C` show context around matches.
- Regex basics: `^ $ . * [] [^]`; `-E` adds `+ ? | ()`.
- Single-quote every pattern; use `-F` for plain strings.

**Self-check:**

1. Which option prints the lines that do NOT match?
2. What does `^#` match?
3. Why does `grep 1.2.3.4` sometimes match lines without that IP?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a43a1a91-d60d-5265-9262-a02ee53c971d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'stdin, stdout, stderr and Redirection', 'notes', 2, $md$## Why this matters

A cron job "runs" but its errors vanish. A script writes errors into the data
file it produces. A search over `/` buries the answer under 500 "Permission
denied" lines. All three are fixed by sending each **stream** to the right
place.

## Mental model: one input pipe, two output pipes

Every program starts with three open channels, numbered:

```
            +-----------+
 stdin  0 ->|  program  |-> 1 stdout  (normal output)
            |           |-> 2 stderr  (errors and warnings)
            +-----------+
```

By default all three are connected to your terminal, which is why errors and
output look mixed together. **Redirection** reconnects them to files.

## See it work

```bash
ls ~/work/logbook /no/such/dir
```

```
ls: cannot access '/no/such/dir': No such file or directory
/home/labuser/work/logbook:
access.log
app.log
```

One command, two streams on one screen. Now split them:

```bash
ls ~/work/logbook /no/such/dir > out.txt 2> err.txt
cat err.txt
```

What this does: `>` sends stream 1 to `out.txt`, `2>` sends stream 2 to
`err.txt`. Expected output:

```
ls: cannot access '/no/such/dir': No such file or directory
```

### The redirection table

| Syntax | Meaning |
|---|---|
| `cmd > file` | stdout to file (overwrite) |
| `cmd >> file` | stdout to file (append) |
| `cmd 2> file` | stderr to file |
| `cmd > file 2>&1` | both streams to the same file |
| `cmd &> file` | same, bash shorthand |
| `cmd 2>/dev/null` | throw errors away |
| `cmd < file` | read stdin from a file |
| `cmd \| tee file` | show on screen *and* save to file |

`/dev/null` is the black hole: anything written there disappears.

### Why order matters in `2>&1`

`2>&1` means "point stream 2 wherever stream 1 points **right now**".
Redirections are processed left to right.

```
 cmd > log 2>&1     1 -> log, then 2 -> (where 1 points) = log      both in log
 cmd 2>&1 > log     2 -> terminal (where 1 points now), then 1 -> log
                    errors still on screen
```

So for a cron job, the safe pattern is:

```bash
/opt/brewbot/backup.sh >> /var/log/backup.log 2>&1
```

### Reading input from a file, and tee

```bash
wc -l < app.log           # wc reads stdin; prints just "80" (no file name)
grep ERROR app.log | tee errors.txt | wc -l
```

`tee` is a T-junction in the pipe: it writes a copy to a file and passes
everything on. Expected output of the second line: `16`, and `errors.txt` holds
the 16 lines.

To write to a root-owned file with sudo, `sudo echo x > /etc/file` fails because
your (non-root) shell opens the file. Use `echo x | sudo tee /etc/file` instead
(`tee -a` appends).

## Try it

Run `find / -name "*.conf"` so that the results go into `confs.txt` and every
"Permission denied" message is thrown away.

<details>
<summary>Show answer</summary>

```bash
find / -name "*.conf" > confs.txt 2>/dev/null
```

</details>

## Common mistakes

- **`2>&1 > file` order.** Errors stay on the screen. Put `2>&1` last.
- **Reading and writing the same file.** `sort data.txt > data.txt` empties the
  file before `sort` reads it. Write to a new file, then `mv`.
- **`sudo` with `>`.** The redirection runs as you, not root. Use `| sudo tee`.
- **Hiding all errors with `2>/dev/null` in scripts.** You also hide the one
  error that explains a failure. Hide them only when you know what they are.

## Remember

- 0 stdin, 1 stdout, 2 stderr.
- `>` overwrite, `>>` append, `2>` errors, `> f 2>&1` or `&> f` both.
- `/dev/null` discards; `tee` copies to a file and passes it on.
- Redirections apply left to right.

**Self-check:**

1. What number is stderr?
2. Why does `cmd 2>&1 > log` still show errors on screen?
3. How do you append a line to a root-owned file using sudo?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a7a9a13d-7a23-58b3-b9e6-6a989d6ac7d8', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'Pipes: cut, sort, uniq, tr and the Top-N Pipeline', 'notes', 3, $md$## Why this matters

"Which IP is hammering the shop?" "Which status codes are we returning?"
Answering these in one line, with small tools chained together, is the moment
Linux starts feeling like a superpower.

## Mental model: a coffee filter chain

The pipe `|` connects stdout of one command to stdin of the next. Each stage
takes what drips from the stage above and passes on something smaller.

```
 awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -3
      just the IPs           -> grouped -> counted -> biggest first -> top 3
```

> **Memory hook:** a pipe is a **coffee filter chain**. Small tools, each doing
> one thing, chained together.

## See it work

### cut: slice columns

```bash
cut -d' ' -f1 ~/work/logbook/access.log | head -2   # field 1, space-separated
cut -d: -f1,7 /etc/passwd | tail -2                 # fields 1 and 7, colon-separated
```

```
10.0.0.7
192.168.1.20
postgres:/bin/bash
labuser:/bin/bash
```

`-d` sets the delimiter (one character), `-f` picks fields. `cut -c1-10` takes
characters instead.

### sort and uniq: group and count

```bash
cd ~/work/logbook
awk '{print $1}' access.log | sort | uniq -c | sort -rn
```

What this does: extract the IP (field 1), sort so equal IPs are next to each
other, count each group, sort by count numerically in reverse. Expected output:

```
     95 192.168.1.20
     60 172.16.0.9
     60 10.0.0.7
     60 10.0.0.5
```

`uniq` only merges **adjacent** duplicate lines. That is why `sort` must come
first.

| Command | Does |
|---|---|
| `sort` | alphabetical |
| `sort -n` / `-h` | numeric / human sizes (2K, 1M) |
| `sort -r` | reverse |
| `sort -k2 -t,` | by field 2, comma-separated |
| `sort -u` | sort and drop duplicates |
| `uniq -c` | count adjacent duplicates |
| `uniq -d` | show only duplicated lines |

### tr: translate characters

```bash
echo "orbit coffee" | tr 'a-z' 'A-Z'     # ORBIT COFFEE
tr -d '\r' < win.txt > unix.txt          # remove Windows carriage returns
echo "a  b   c" | tr -s ' '              # squeeze repeated spaces: a b c
```

### xargs: turn lines into arguments

Some commands do not read stdin; they want arguments. `xargs` bridges that.

```bash
find . -name '*.log' -print0 | xargs -0 gzip     # gzip every log found
cut -d' ' -f1 access.log | sort -u | xargs -n1 echo checking
```

`-print0` and `-0` use a NUL byte between names, so names with spaces survive.

### The top-N pattern

Memorise this shape; you will use it for IPs, URLs, users, error types:

```
 <extract one field> | sort | uniq -c | sort -rn | head
```

```bash
awk '{print $9}' access.log | sort | uniq -c | sort -rn    # status code mix
```

```
    243 200
     18 404
     14 500
```

## Try it

Using `cut`, list each distinct IP in `access.log` once, sorted. Then: why does
`uniq -c access.log` without `sort` give wrong counts?

<details>
<summary>Show answer</summary>

```bash
cut -d' ' -f1 access.log | sort -u
```

```
10.0.0.5
10.0.0.7
172.16.0.9
192.168.1.20
```

`uniq` compares each line only with the line right before it. Without `sort`,
the same IP appears in many separate runs and each run is counted separately.

</details>

## Common mistakes

- **`uniq` without `sort`.** Counts are split into many small groups.
- **`sort` on numbers without `-n`.** Alphabetically, `100` comes before `9`.
- **`cut -d' '` on text with multiple spaces.** Each space is a separator, so
  fields shift. Use `awk` (next lesson), which splits on runs of whitespace.
- **Very long pipelines nobody can read.** Build them one stage at a time, and
  check the output of each stage with `| head`.

## Remember

- `|` sends stdout of the left command to stdin of the right one.
- `cut -d -f` slices fields; `tr` translates characters; `xargs` makes
  arguments.
- `sort | uniq -c | sort -rn | head` is the top-N pipeline.
- Build pipelines stage by stage.

**Self-check:**

1. Why must `sort` come before `uniq -c`?
2. Which `sort` options give biggest number first?
3. What problem does `-print0 | xargs -0` solve?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('3b82fcaa-113c-5f02-8280-09784672b7ca', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'awk: Columns Made Easy', 'notes', 4, $md$## Why this matters

Access logs, `ps` output, `df` output: most admin data is columns. "Show the path
of every request that returned 500" means *filter on column 9, print column 7*.
`awk` does that in one short line.

## Mental model: a spreadsheet, one row at a time

`awk` reads a line, splits it into fields on whitespace, and names them `$1`,
`$2`, ... (`$0` is the whole line, `$NF` the last field). Then it runs your rule:

```
  awk ' CONDITION { ACTION } ' file

  for each line:
     if CONDITION is true (or missing) -> do ACTION (default: print the line)
```

An access log line, split:

```
 10.0.0.5 - - [14/Oct/2026:10:24:00 +0000] "GET /api/orders HTTP/1.1" 500 408
   $1     $2 $3        $4            $5    $6      $7         $8     $9  $10
```

> **Memory hook:** **s**ed **s**ubstitutes, **a**wk **a**sks about columns.

## See it work

```bash
cd ~/work/logbook
awk '{print $1, $9}' access.log | head -2      # IP and status
```

```
10.0.0.7 200
192.168.1.20 200
```

A comma in `print` inserts a space between fields.

```bash
awk '$9 == 500' access.log | head -2           # condition only: print matching lines
```

```
10.0.0.5 - - [14/Oct/2026:10:24:00 +0000] "GET /api/orders HTTP/1.1" 500 408
10.0.0.5 - - [14/Oct/2026:10:28:00 +0000] "GET /checkout HTTP/1.1" 500 476
```

```bash
awk '$9 == 500 {print $7}' access.log | sort | uniq -c   # condition + action
```

```
      7 /api/orders
      7 /checkout
```

That is the answer to "which pages are crashing?"

### Separators, sums and line numbers

```bash
awk -F: '{print $1, $7}' /etc/passwd            # -F sets the field separator
awk '{sum += $10} END {print sum}' access.log   # add up bytes sent
awk 'NR <= 3' app.log                           # NR = line number: first 3 lines
awk '{print $NF}' app.log | head -1             # last field of each line
awk '$3 == "ERROR" {n++} END {print n}' app.log # count ERROR lines
```

Expected output of the sum: `509560`. `END { }` runs once after the last line.
Variables like `sum` and `n` start at 0 automatically.

| Piece | Meaning |
|---|---|
| `$1 ... $NF` | fields; `$0` whole line |
| `NR` | current line number |
| `NF` | number of fields on this line |
| `-F:` | split on `:` instead of whitespace |
| `BEGIN {}` / `END {}` | run before the first / after the last line |
| `==`, `!=`, `>`, `~ /re/` | compare; `~` matches a regex |

```bash
awk '$7 ~ /^\/api/ {print $7}' access.log | sort -u   # paths starting with /api
```

## Try it

From `/etc/passwd` print the user name and home directory (fields 1 and 6) of
every user whose shell (field 7) is `/bin/bash`.

<details>
<summary>Show answer</summary>

```bash
awk -F: '$7 == "/bin/bash" {print $1, $6}' /etc/passwd
```

Strings in awk conditions need double quotes; the whole program sits in single
quotes.

</details>

## Common mistakes

- **Double quotes around the program.** `awk "{print $1}"` lets the shell
  replace `$1` first (usually with nothing). Always single-quote awk programs.
- **Forgetting `-F` for non-space data.** `/etc/passwd` and CSV need `-F:` or
  `-F,`.
- **Counting fields by eye.** Print `NF` or `$9` on one line first to check
  which number is which.
- **`=` instead of `==`.** `$9 = 500` assigns 500 to field 9 and is always true.

## Remember

- `awk 'COND {ACTION}' file`; fields are `$1..$NF`.
- Filter on one column and print another in one step.
- `-F` sets the separator; `END {}` prints totals.
- Single-quote the program, double-quote strings inside it.

**Self-check:**

1. What is `$NF`?
2. Write the awk condition for "field 9 is 404".
3. When does an `END` block run?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4c86713a-ebd2-56bd-be0e-5ca781b0c6f8', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'sed: Editing a Stream, and Comparing Files with diff', 'notes', 5, $md$## Why this matters

The app wrote customer passwords into its log. You need a clean copy to share
with the developers, now, without opening an editor. Later you will change one
port number in a config on ten servers. `sed` does both from the command line.

## Mental model: a find-and-replace conveyor belt

`sed` (**s**tream **ed**itor) reads lines one by one, applies an edit, and
prints the result. The original file is untouched unless you ask for `-i`.

```
  app.log --> [ sed 's/password=[^ ]*/password=***/' ] --> stdout (or > new file)
```

The main command is **s**ubstitute:

```
  s / what / with / flags
        regex   text   g = every match on the line (default: first only)
```

## See it work

```bash
cd ~/work/logbook
grep login app.log | head -2
sed 's/password=[^ ]*/password=***/' app.log | grep login | head -2
```

What this does: `[^ ]*` means "any run of non-space characters", so the whole
password value is replaced. Expected output (before, then after):

```
2026-10-14 10:4:00 INFO login user=u4 password=s3cret4
2026-10-14 10:8:00 INFO login user=u8 password=s3cret8
2026-10-14 10:4:00 INFO login user=u4 password=***
2026-10-14 10:8:00 INFO login user=u8 password=***
```

`app.log` itself is unchanged. To keep the result, redirect to a **new** file:

```bash
sed 's/password=[^ ]*/password=***/' app.log > app-clean.log
```

### Other everyday sed commands

```bash
sed 's/old/new/g' file          # replace every match on each line
sed -n '10,12p' app.log         # print only lines 10-12 (-n = no automatic print)
sed '/^#/d' app.conf            # delete comment lines
sed '/^$/d' app.conf            # delete empty lines
sed 's|/var/log|/srv/log|g' f   # any character can be the delimiter: handy with paths
```

### Editing in place

```bash
sed -i.bak 's/^port = .*/port = 8080/' brewbot.conf
```

What this does: `-i` writes the change back into the file; `.bak` keeps the
original as `brewbot.conf.bak`. Always test without `-i` first, then add it.

> **Memory hook:** without `-i`, sed is a **preview**; with `-i`, it is a
> **pen**. Preview first.

### Comparing files: diff

After editing a config, check what really changed:

```bash
diff brewbot.conf.bak brewbot.conf
diff -u brewbot.conf.bak brewbot.conf     # unified format, the one git shows
```

Output of the second command (timestamps trimmed):

```
--- brewbot.conf.bak
+++ brewbot.conf
@@ -1,3 +1,3 @@
 name = brewbot
-port = 80800
+port = 8080
 workers = 4
```

Lines with `-` were removed, `+` added. `diff` exits with 0 when files are the
same, so scripts can use it as a test. For binary files use `cmp a.bin b.bin`.

## Try it

Print `app.log` with every `ERROR` replaced by `FAIL`, but only show lines 1-5
of the result. Do not change the file.

<details>
<summary>Show answer</summary>

```bash
sed 's/ERROR/FAIL/g' app.log | head -5
```

or `sed -n '1,5{s/ERROR/FAIL/g;p}' app.log`. The first is easier to read.

</details>

## Common mistakes

- **`sed -i` on the only copy of evidence.** A wrong regex destroys the log you
  needed. Use `-i.bak` or write to a new file.
- **`sed file > file`.** The shell empties the file before sed reads it. Write
  elsewhere, then `mv`.
- **Forgetting `g`.** Only the first match on each line is replaced.
- **Slashes in the pattern.** `s//var/log//srv/` is broken. Escape them or use
  another delimiter: `s|/var|/srv|`.

## Remember

- `sed 's/what/with/g' file` prints an edited copy.
- `-n 'X,Yp'` prints a range; `/re/d` deletes matching lines.
- `-i.bak` edits in place with a backup; preview first.
- `diff -u old new` shows exactly what changed.

**Self-check:**

1. What does `[^ ]*` match?
2. What does `sed -n '5p'` print?
3. How do you make `sed -i` keep a backup?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('c5763494-4508-5099-965a-3b07d56d84c9', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'Lab: Read the Logbook', 'notes', 6, $md$## Why this matters

Checkout is broken and the logs hold the answer. In this lab you turn hundreds of
log lines into five precise answers, the same way you would during a real
incident. Each task is checked automatically.

## Before you start

```bash
cd ~/work/logbook
wc -l *.log
head -2 access.log app.log
```

What this does: sizes up both logs and shows their format. In `access.log` the
IP is field 1, the path field 7 and the status code field 9.

## Task 1: how bad is it?

Count how many lines in `app.log` contain `ERROR` and save just the number into
`~/work/answers/errors.txt`.

[[lab-task:1]]

## Task 2: who is hammering the shop?

Find the IP address that made the most requests in `access.log` and save only
that IP into `answers/top-ip.txt`. Use the top-N pipeline from lesson 4.

[[lab-task:2]]

What you should see while building it:

```
$ awk '{print $1}' access.log | sort | uniq -c | sort -rn
     95 192.168.1.20
     60 172.16.0.9
     60 10.0.0.7
     60 10.0.0.5
```

## Task 3: which pages are crashing?

Save the distinct request paths that returned status 500 into
`answers/500-paths.txt`, one per line, sorted alphabetically with no duplicates.

[[lab-task:3]]

## Task 4: hide the leaked passwords

Create `logbook/app-clean.log`, a copy of `app.log` where every
`password=VALUE` becomes `password=***`, using `sed`. Leave `app.log`
unchanged: it is evidence.

[[lab-task:4]]

## Task 5: separate the good from the bad

Run `ls /home/labuser/work/logbook /no/such/dir` as one command so that normal
output goes to `answers/out.txt` and the error goes to `answers/err.txt`.

[[lab-task:5]]

What you should see:

```
$ cat answers/err.txt
ls: cannot access '/no/such/dir': No such file or directory
```

## Remember

- `grep -c` counts; `awk 'COND {print $N}'` filters and slices.
- `sort | uniq -c | sort -rn | head` answers every "top N" question.
- `sed 's/x/y/' in > out` makes a clean copy without touching the original.
- `>` and `2>` split stdout and stderr.

> **End of day 3.** The pipeline told the story: `/checkout` and `/api/orders`
> were throwing 500s, and one IP was hammering the cart. You masked the leaked
> passwords before anyone saw them. In the corner of the log you spot Tom's next
> note: "Not everyone should have every key."
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('8fac3d77-167a-50ca-8617-771b36111113', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c5763494-4508-5099-965a-3b07d56d84c9', 'module', 'Lab: Read the Logbook', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
rm -rf $w/logbook $w/answers
mkdir -p $w/logbook $w/answers
a=$w/logbook/access.log
: > $a
for i in $(seq 1 240); do
  case $((i % 4)) in 0) ip=10.0.0.5;; 1) ip=10.0.0.7;; 2) ip=192.168.1.20;; *) ip=172.16.0.9;; esac
  case $((i % 5)) in 0) p=/;; 1) p=/menu;; 2) p=/cart;; 3) p=/checkout;; *) p=/api/orders;; esac
  code=200
  [ $((i % 7)) -eq 0 ] && [ $p = /checkout ] && code=500
  [ $((i % 6)) -eq 0 ] && [ $p = /api/orders ] && code=500
  [ $((i % 13)) -eq 0 ] && code=404
  echo "$ip - - [14/Oct/2026:10:$((i % 60)):00 +0000] \"GET $p HTTP/1.1\" $code $((i * 17))" >> $a
done
for i in $(seq 1 35); do
  echo "192.168.1.20 - - [14/Oct/2026:11:$((i % 60)):00 +0000] \"GET /cart HTTP/1.1\" 200 512" >> $a
done
l=$w/logbook/app.log
: > $l
for i in $(seq 1 80); do
  case $((i % 10)) in
    0|3) echo "2026-10-14 10:$((i % 60)):00 ERROR payment gateway timeout order=$i" >> $l;;
    5) echo "2026-10-14 10:$((i % 60)):00 WARN slow query 1200ms order=$i" >> $l;;
    *) if [ $((i % 4)) -eq 0 ]; then
         echo "2026-10-14 10:$((i % 60)):00 INFO login user=u$i password=s3cret$i" >> $l
       else
         echo "2026-10-14 10:$((i % 60)):00 INFO order placed order=$i" >> $l
       fi;;
  esac
done
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '24fc0e64-cd84-52bf-b66a-43d0926f076d' AND id NOT IN ('77a75381-8db9-5dbd-ad84-0a218fc076ba', 'b6bed250-c2e3-567a-9f29-620e2b2bf5b0', '1f86d9d0-64c3-5211-9d72-34268ffa756d', '8bad94bd-de18-5c12-8309-6efd82054b8e', '4f9aee3b-3265-5e22-84e6-81a9c75e6d53');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '24fc0e64-cd84-52bf-b66a-43d0926f076d';
DELETE FROM lab_tasks WHERE lab_id = '8fac3d77-167a-50ca-8617-771b36111113' AND id NOT IN ('4d64c7a8-54b4-54e6-b58d-d1e668c05651', '3f7db9c2-95ee-5754-a15e-29221780cba2', 'b640ca4c-f2fc-58e3-8fa9-da9e3644d634', '79f69cf3-8ef8-5748-be31-0aab8681c8e8', '029b8920-d1bf-5d12-ae86-b8b14af6a8e4');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '8fac3d77-167a-50ca-8617-771b36111113';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4d64c7a8-54b4-54e6-b58d-d1e668c05651', '8fac3d77-167a-50ca-8617-771b36111113', 1, 'How bad is it?', $md$Count how many lines in logbook/app.log contain the word ERROR and save just the number into answers/errors.txt.$md$, $script$w=/home/labuser/work
[ "$(tr -d '[:space:]' < $w/answers/errors.txt)" = "$(grep -c ERROR $w/logbook/app.log)" ]
$script$, 'grep -c PATTERN FILE prints the number of matching lines instead of the lines themselves.', 'grep -c counts matching lines. grep PATTERN FILE | wc -l gives the same answer by counting the printed lines.', 15, false, true),
('3f7db9c2-95ee-5754-a15e-29221780cba2', '8fac3d77-167a-50ca-8617-771b36111113', 2, 'Who is hammering the shop?', $md$Find the IP address that made the most requests in logbook/access.log (the IP is the first field on each line) and save only that IP into answers/top-ip.txt.$md$, $script$w=/home/labuser/work
want=$(awk '{print $1}' $w/logbook/access.log | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
[ "$(tr -d '[:space:]' < $w/answers/top-ip.txt)" = "$want" ]
$script$, 'Pipe it - awk ''{print $1}'' extracts the IP, sort groups equal lines, uniq -c counts each group, sort -rn puts the biggest count first, head -1 keeps the winner.', 'sort | uniq -c | sort -rn | head is the classic "top N" pipeline. uniq only merges adjacent duplicates, which is why sort must come first.', 25, false, true),
('b640ca4c-f2fc-58e3-8fa9-da9e3644d634', '8fac3d77-167a-50ca-8617-771b36111113', 3, 'Which pages are crashing?', $md$Save the list of distinct request paths that returned status 500 into answers/500-paths.txt, one path per line, sorted alphabetically with no duplicates. In access.log the path is field 7 and the status code is field 9.$md$, $script$w=/home/labuser/work
diff <(awk '$9 == 500 {print $7}' $w/logbook/access.log | sort -u) <(grep -v '^$' $w/answers/500-paths.txt) >/dev/null
$script$, 'awk ''$9 == 500 {print $7}'' filters on one field and prints another. sort -u sorts and removes duplicates.', 'awk splits each line on whitespace into $1, $2 ... so it can filter on one column and print another in one step. sort -u is sort plus uniq.', 20, false, true),
('79f69cf3-8ef8-5748-be31-0aab8681c8e8', '8fac3d77-167a-50ca-8617-771b36111113', 4, 'Hide the leaked passwords', $md$The app wrote passwords into its log. Create logbook/app-clean.log - a copy of app.log where every password=VALUE is replaced with password=*** - using sed. Leave app.log itself unchanged.$md$, $script$w=/home/labuser/work/logbook
[ -f $w/app-clean.log ] &&
[ "$(wc -l < $w/app-clean.log)" = "$(wc -l < $w/app.log)" ] &&
! grep -q 'password=[^*]' $w/app-clean.log &&
[ "$(grep -c 'password=\*\*\*' $w/app-clean.log)" = "$(grep -c 'password=' $w/app.log)" ] &&
grep -q 'password=s3cret' $w/app.log
$script$, 'sed ''s/password=[^ ]*/password=***/'' FILE > NEWFILE - [^ ]* means "everything up to the next space". Without -i sed prints the result and leaves the original alone.', 'sed s/old/new/ edits a stream line by line. Writing to a new file keeps the evidence intact; sed -i edits in place, which is risky on the only copy of a log.', 20, false, true),
('029b8920-d1bf-5d12-ae86-b8b14af6a8e4', '8fac3d77-167a-50ca-8617-771b36111113', 5, 'Separate the good from the bad', $md$Run ls /home/labuser/work/logbook /no/such/dir as one command so that the normal output goes to answers/out.txt and the error message goes to answers/err.txt.$md$, $script$a=/home/labuser/work/answers
grep -q access.log $a/out.txt && grep -q 'No such file' $a/err.txt &&
! grep -q access.log $a/err.txt && ! grep -q 'No such file' $a/out.txt
$script$, 'The > operator redirects stdout (stream 1) and 2> redirects stderr (stream 2). Both can be used on the same command.', 'Every program has three streams - stdin (0), stdout (1), stderr (2). Splitting them lets scripts keep errors in a log while passing clean data down a pipe.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('24fc0e64-cd84-52bf-b66a-43d0926f076d', '8fac3d77-167a-50ca-8617-771b36111113', 1, $json$[{"id":"4d64c7a8-54b4-54e6-b58d-d1e668c05651","lab_id":"8fac3d77-167a-50ca-8617-771b36111113","position":1,"title":"How bad is it?","description":"Count how many lines in logbook/app.log contain the word ERROR and save just the number into answers/errors.txt.","verification_script":"w=/home/labuser/work\n[ \"$(tr -d '[:space:]' \u003c $w/answers/errors.txt)\" = \"$(grep -c ERROR $w/logbook/app.log)\" ]\n","hint_context":"grep -c PATTERN FILE prints the number of matching lines instead of the lines themselves.","explanation_context":"grep -c counts matching lines. grep PATTERN FILE | wc -l gives the same answer by counting the printed lines.","points":15,"is_optional":false,"is_stateful":true},{"id":"3f7db9c2-95ee-5754-a15e-29221780cba2","lab_id":"8fac3d77-167a-50ca-8617-771b36111113","position":2,"title":"Who is hammering the shop?","description":"Find the IP address that made the most requests in logbook/access.log (the IP is the first field on each line) and save only that IP into answers/top-ip.txt.","verification_script":"w=/home/labuser/work\nwant=$(awk '{print $1}' $w/logbook/access.log | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')\n[ \"$(tr -d '[:space:]' \u003c $w/answers/top-ip.txt)\" = \"$want\" ]\n","hint_context":"Pipe it - awk '{print $1}' extracts the IP, sort groups equal lines, uniq -c counts each group, sort -rn puts the biggest count first, head -1 keeps the winner.","explanation_context":"sort | uniq -c | sort -rn | head is the classic \"top N\" pipeline. uniq only merges adjacent duplicates, which is why sort must come first.","points":25,"is_optional":false,"is_stateful":true},{"id":"b640ca4c-f2fc-58e3-8fa9-da9e3644d634","lab_id":"8fac3d77-167a-50ca-8617-771b36111113","position":3,"title":"Which pages are crashing?","description":"Save the list of distinct request paths that returned status 500 into answers/500-paths.txt, one path per line, sorted alphabetically with no duplicates. In access.log the path is field 7 and the status code is field 9.","verification_script":"w=/home/labuser/work\ndiff \u003c(awk '$9 == 500 {print $7}' $w/logbook/access.log | sort -u) \u003c(grep -v '^$' $w/answers/500-paths.txt) \u003e/dev/null\n","hint_context":"awk '$9 == 500 {print $7}' filters on one field and prints another. sort -u sorts and removes duplicates.","explanation_context":"awk splits each line on whitespace into $1, $2 ... so it can filter on one column and print another in one step. sort -u is sort plus uniq.","points":20,"is_optional":false,"is_stateful":true},{"id":"79f69cf3-8ef8-5748-be31-0aab8681c8e8","lab_id":"8fac3d77-167a-50ca-8617-771b36111113","position":4,"title":"Hide the leaked passwords","description":"The app wrote passwords into its log. Create logbook/app-clean.log - a copy of app.log where every password=VALUE is replaced with password=*** - using sed. Leave app.log itself unchanged.","verification_script":"w=/home/labuser/work/logbook\n[ -f $w/app-clean.log ] \u0026\u0026\n[ \"$(wc -l \u003c $w/app-clean.log)\" = \"$(wc -l \u003c $w/app.log)\" ] \u0026\u0026\n! grep -q 'password=[^*]' $w/app-clean.log \u0026\u0026\n[ \"$(grep -c 'password=\\*\\*\\*' $w/app-clean.log)\" = \"$(grep -c 'password=' $w/app.log)\" ] \u0026\u0026\ngrep -q 'password=s3cret' $w/app.log\n","hint_context":"sed 's/password=[^ ]*/password=***/' FILE \u003e NEWFILE - [^ ]* means \"everything up to the next space\". Without -i sed prints the result and leaves the original alone.","explanation_context":"sed s/old/new/ edits a stream line by line. Writing to a new file keeps the evidence intact; sed -i edits in place, which is risky on the only copy of a log.","points":20,"is_optional":false,"is_stateful":true},{"id":"029b8920-d1bf-5d12-ae86-b8b14af6a8e4","lab_id":"8fac3d77-167a-50ca-8617-771b36111113","position":5,"title":"Separate the good from the bad","description":"Run ls /home/labuser/work/logbook /no/such/dir as one command so that the normal output goes to answers/out.txt and the error message goes to answers/err.txt.","verification_script":"a=/home/labuser/work/answers\ngrep -q access.log $a/out.txt \u0026\u0026 grep -q 'No such file' $a/err.txt \u0026\u0026\n! grep -q access.log $a/err.txt \u0026\u0026 ! grep -q 'No such file' $a/out.txt\n","hint_context":"The \u003e operator redirects stdout (stream 1) and 2\u003e redirects stderr (stream 2). Both can be used on the same command.","explanation_context":"Every program has three streams - stdin (0), stdout (1), stderr (2). Splitting them lets scripts keep errors in a log while passing clean data down a pipe.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('77a75381-8db9-5dbd-ad84-0a218fc076ba', '24fc0e64-cd84-52bf-b66a-43d0926f076d', '4d64c7a8-54b4-54e6-b58d-d1e668c05651', 1, 'How bad is it?', $md$Count how many lines in logbook/app.log contain the word ERROR and save just the number into answers/errors.txt.$md$, $script$w=/home/labuser/work
[ "$(tr -d '[:space:]' < $w/answers/errors.txt)" = "$(grep -c ERROR $w/logbook/app.log)" ]
$script$, 'grep -c PATTERN FILE prints the number of matching lines instead of the lines themselves.', 'grep -c counts matching lines. grep PATTERN FILE | wc -l gives the same answer by counting the printed lines.', 15, false, true),
('b6bed250-c2e3-567a-9f29-620e2b2bf5b0', '24fc0e64-cd84-52bf-b66a-43d0926f076d', '3f7db9c2-95ee-5754-a15e-29221780cba2', 2, 'Who is hammering the shop?', $md$Find the IP address that made the most requests in logbook/access.log (the IP is the first field on each line) and save only that IP into answers/top-ip.txt.$md$, $script$w=/home/labuser/work
want=$(awk '{print $1}' $w/logbook/access.log | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
[ "$(tr -d '[:space:]' < $w/answers/top-ip.txt)" = "$want" ]
$script$, 'Pipe it - awk ''{print $1}'' extracts the IP, sort groups equal lines, uniq -c counts each group, sort -rn puts the biggest count first, head -1 keeps the winner.', 'sort | uniq -c | sort -rn | head is the classic "top N" pipeline. uniq only merges adjacent duplicates, which is why sort must come first.', 25, false, true),
('1f86d9d0-64c3-5211-9d72-34268ffa756d', '24fc0e64-cd84-52bf-b66a-43d0926f076d', 'b640ca4c-f2fc-58e3-8fa9-da9e3644d634', 3, 'Which pages are crashing?', $md$Save the list of distinct request paths that returned status 500 into answers/500-paths.txt, one path per line, sorted alphabetically with no duplicates. In access.log the path is field 7 and the status code is field 9.$md$, $script$w=/home/labuser/work
diff <(awk '$9 == 500 {print $7}' $w/logbook/access.log | sort -u) <(grep -v '^$' $w/answers/500-paths.txt) >/dev/null
$script$, 'awk ''$9 == 500 {print $7}'' filters on one field and prints another. sort -u sorts and removes duplicates.', 'awk splits each line on whitespace into $1, $2 ... so it can filter on one column and print another in one step. sort -u is sort plus uniq.', 20, false, true),
('8bad94bd-de18-5c12-8309-6efd82054b8e', '24fc0e64-cd84-52bf-b66a-43d0926f076d', '79f69cf3-8ef8-5748-be31-0aab8681c8e8', 4, 'Hide the leaked passwords', $md$The app wrote passwords into its log. Create logbook/app-clean.log - a copy of app.log where every password=VALUE is replaced with password=*** - using sed. Leave app.log itself unchanged.$md$, $script$w=/home/labuser/work/logbook
[ -f $w/app-clean.log ] &&
[ "$(wc -l < $w/app-clean.log)" = "$(wc -l < $w/app.log)" ] &&
! grep -q 'password=[^*]' $w/app-clean.log &&
[ "$(grep -c 'password=\*\*\*' $w/app-clean.log)" = "$(grep -c 'password=' $w/app.log)" ] &&
grep -q 'password=s3cret' $w/app.log
$script$, 'sed ''s/password=[^ ]*/password=***/'' FILE > NEWFILE - [^ ]* means "everything up to the next space". Without -i sed prints the result and leaves the original alone.', 'sed s/old/new/ edits a stream line by line. Writing to a new file keeps the evidence intact; sed -i edits in place, which is risky on the only copy of a log.', 20, false, true),
('4f9aee3b-3265-5e22-84e6-81a9c75e6d53', '24fc0e64-cd84-52bf-b66a-43d0926f076d', '029b8920-d1bf-5d12-ae86-b8b14af6a8e4', 5, 'Separate the good from the bad', $md$Run ls /home/labuser/work/logbook /no/such/dir as one command so that the normal output goes to answers/out.txt and the error message goes to answers/err.txt.$md$, $script$a=/home/labuser/work/answers
grep -q access.log $a/out.txt && grep -q 'No such file' $a/err.txt &&
! grep -q access.log $a/err.txt && ! grep -q 'No such file' $a/out.txt
$script$, 'The > operator redirects stdout (stream 1) and 2> redirects stderr (stream 2). Both can be used on the same command.', 'Every program has three streams - stdin (0), stdout (1), stderr (2). Splitting them lets scripts keep errors in a log while passing clean data down a pipe.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '24fc0e64-cd84-52bf-b66a-43d0926f076d', updated_at = now()
WHERE id = '8fac3d77-167a-50ca-8617-771b36111113' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e1290c82-3f3d-57a6-a129-23ffaa14daf9', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'Reference: Text Tools Cheat Sheet', 'notes', 7, $md$## How to use this page

This is a reference, not a lesson. Skim it once, then come back when you need a
flag. Everything here was explained in lessons 1-6 of this chapter, except the
few extras marked **new**.

## Viewing

| Command | Does |
|---|---|
| `cat f` / `cat a b` | print / concatenate |
| `less f` | scroll; `/x` search, `n` next, `G` end, `F` follow, `q` quit |
| `head -n N f` / `tail -n N f` | first / last N lines |
| `tail -n +N f` | from line N to the end |
| `tail -f f` / `tail -F f` | follow; `-F` survives rotation |
| `wc -l` / `-w` / `-c` | lines / words / bytes |
| `nl f` (**new**) | print with line numbers |

## grep

| Option | Does |
|---|---|
| `-i` / `-v` / `-c` / `-n` | ignore case / invert / count / line numbers |
| `-w` / `-x` | whole word / whole line |
| `-r` / `-l` | recurse into directories / list file names only |
| `-E` / `-F` | extended regex / fixed string |
| `-A N` / `-B N` / `-C N` | context after / before / around |
| `-o` (**new**) | print only the matched part |
| `-q` | quiet, exit code only |

Regex: `^` start, `$` end, `.` any char, `*` 0+, `[...]` set, `[^...]` not in
set; with `-E`: `+` 1+, `?` 0-1, `|` or, `()` group, `{n,m}` repeat.

## Redirection and pipes

| Syntax | Does |
|---|---|
| `>` / `>>` | stdout to file, overwrite / append |
| `2>` / `2>>` | stderr to file |
| `> f 2>&1` / `&> f` | both streams |
| `2>/dev/null` | discard errors |
| `< f` | stdin from file |
| `<<'EOF' ... EOF` | here-document |
| `a \| b` | stdout of a into stdin of b |
| `\| tee f` / `\| tee -a f` | copy to file and pass on |
| `\| sudo tee f` | write a root-owned file |

## Slicing, sorting, counting

| Command | Does |
|---|---|
| `cut -d: -f1,7` / `cut -c1-10` | fields / characters |
| `sort` `-n` `-h` `-r` `-u` `-k2 -t,` | numeric, human, reverse, unique, by key |
| `uniq` `-c` `-d` | count / duplicates only (input must be sorted) |
| `tr 'a-z' 'A-Z'` / `tr -d '\r'` / `tr -s ' '` | translate / delete / squeeze |
| `xargs` / `xargs -0` / `xargs -n1` | lines to arguments / NUL-separated / one per call |
| `paste a b` (**new**) | join files side by side |
| `column -t` (**new**) | align columns into a table |
| `comm -12 a b` (**new**) | lines common to two sorted files |

Top-N: `<extract> | sort | uniq -c | sort -rn | head`

## awk

| Piece | Does |
|---|---|
| `awk '{print $1, $NF}'` | first and last field |
| `awk '$9 == 500'` | filter rows |
| `awk -F: '...'` | custom separator |
| `awk '{s += $10} END {print s}'` | sum a column |
| `awk 'NR==10'` / `NF` | line 10 / number of fields |
| `awk '$7 ~ /^\/api/'` | regex match on a field |
| `awk '{c[$1]++} END {for (k in c) print c[k], k}'` (**new**) | count per key without sort |

## sed

| Command | Does |
|---|---|
| `sed 's/a/b/'` / `'s/a/b/g'` | replace first / all on each line |
| `sed -n '10,20p'` | print a range |
| `sed '/re/d'` | delete matching lines |
| `sed -i.bak '...' f` | edit in place, keep backup |
| `sed 's\|/a\|/b\|g'` | other delimiter for paths |

## Comparing

| Command | Does |
|---|---|
| `diff a b` / `diff -u a b` | line differences / unified format |
| `cmp a b` | first differing byte (binary) |
| `sha256sum f` (**new**) | checksum: same hash = same content |

## JSON (new)

```bash
curl -s URL | jq .                 # pretty-print
jq -r '.version' status.json       # one field, raw text
jq -r '.items[] | .name' list.json # every name in an array
```

`jq` is to JSON what `awk` is to columns. Chapter 8 uses it with `curl`.
$md$, 5, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a86155b8-b84b-51eb-b15e-a0e54bce5c32', '00000000-0000-0000-0000-000000000001', 'mcq', 'brewbot''s log is 3 GB. You want to watch new lines arrive while you reproduce...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('972689c7-d34c-51db-92aa-02f77d765daa', 'a86155b8-b84b-51eb-b15e-a0e54bce5c32', 1, $json${"prompt":"brewbot's log is 3 GB. You want to watch new lines arrive while you reproduce a bug, and the log is rotated at midnight. Which command?","multiple":false,"options":[{"id":"a","text":"cat brewbot.log","is_correct":false},{"id":"b","text":"tail -F brewbot.log","is_correct":true},{"id":"c","text":"head -f brewbot.log","is_correct":false},{"id":"d","text":"nano brewbot.log","is_correct":false}],"explanation":"tail -F follows new lines and reopens the file after rotation. cat dumps 3 GB to the screen, head has no follow mode, and an editor loads the whole file and can save changes by accident."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ac8bbc88-ad11-53b7-a77a-d69410a33ac4', '00000000-0000-0000-0000-000000000001', 'mcq', 'You run grep ERROR|WARN app.log and get ''WARN: command not found''. What went ...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d66c2449-abd3-5347-a273-5c265b01798d', 'ac8bbc88-ad11-53b7-a77a-d69410a33ac4', 1, $json${"prompt":"You run grep ERROR|WARN app.log and get 'WARN: command not found'. What went wrong?","multiple":false,"options":[{"id":"a","text":"grep cannot search for two words","is_correct":false},{"id":"b","text":"The unquoted | was read by the shell as a pipe; quote the pattern and use -E: grep -E 'ERROR|WARN' app.log","is_correct":true},{"id":"c","text":"WARN must be written in lowercase","is_correct":false},{"id":"d","text":"app.log must come first","is_correct":false}],"explanation":"Unquoted, | splits the line into two commands. Quoting keeps it inside the pattern and -E makes | mean 'or'. Case and argument order are not the problem."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('39be6fd3-41fe-51ff-8441-d5a7640cd346', '00000000-0000-0000-0000-000000000001', 'mcq', 'A cron job runs /opt/backup.sh 2>&1 > /var/log/backup.log. Its error messages...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('72d5a38d-4865-5a04-adf2-bad5c16afe00', '39be6fd3-41fe-51ff-8441-d5a7640cd346', 1, $json${"prompt":"A cron job runs /opt/backup.sh 2\u003e\u00261 \u003e /var/log/backup.log. Its error messages never reach the log. Why?","multiple":false,"options":[{"id":"a","text":"cron discards stderr by design","is_correct":false},{"id":"b","text":"Redirections apply left to right: 2\u003e\u00261 copied stderr to the old stdout before stdout was moved to the file","is_correct":true},{"id":"c","text":"The log file must end in .err","is_correct":false},{"id":"d","text":"2\u003e\u00261 only works with \u003e\u003e","is_correct":false}],"explanation":"Write \u003e /var/log/backup.log 2\u003e\u00261 (or \u003e\u003e for append) so stderr follows stdout into the file. cron does capture output; file names and append mode have nothing to do with it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e31d8ddf-a0ae-5003-832c-f60768990d1c', '00000000-0000-0000-0000-000000000001', 'mcq', 'awk ''{print $1}'' access.log | uniq -c shows the same IP many times with small...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('263e899e-4b39-5ba6-b8ed-7bc8a52d437c', 'e31d8ddf-a0ae-5003-832c-f60768990d1c', 1, $json${"prompt":"awk '{print $1}' access.log | uniq -c shows the same IP many times with small counts. What is missing?","multiple":false,"options":[{"id":"a","text":"sort before uniq -c, because uniq only merges adjacent duplicates","is_correct":true},{"id":"b","text":"The -F option on awk","is_correct":false},{"id":"c","text":"grep -c instead of uniq","is_correct":false},{"id":"d","text":"Nothing; uniq is just inaccurate","is_correct":false}],"explanation":"Equal lines must be next to each other for uniq to merge them; sort groups them. The default whitespace split is correct for this log, grep -c counts lines not groups, and uniq is exact on sorted input."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c0714155-ee0d-5fab-919e-bebd906f1d38', '00000000-0000-0000-0000-000000000001', 'mcq', 'In access.log the path is field 7 and the status is field 9. Which command li...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5dd8ccf5-94f9-50ff-b2a7-514fd786593e', 'c0714155-ee0d-5fab-919e-bebd906f1d38', 1, $json${"prompt":"In access.log the path is field 7 and the status is field 9. Which command lists each path that returned 404, once?","multiple":false,"options":[{"id":"a","text":"awk '$9 == 404 {print $7}' access.log | sort -u","is_correct":true},{"id":"b","text":"grep 404 access.log | sort -u","is_correct":false},{"id":"c","text":"awk '$7 == 404 {print $9}' access.log","is_correct":false},{"id":"d","text":"cut -f7 access.log | grep 404","is_correct":false}],"explanation":"awk filters on field 9 and prints field 7, sort -u removes duplicates. grep 404 also matches 404 inside byte counts or times and prints whole lines; the third option swaps the fields; cut -f uses tabs by default, and the path field never contains the status."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('79fe423d-5212-5b1f-a1ea-f4e8ade5619a', '00000000-0000-0000-0000-000000000001', 'mcq', 'You need a copy of app.log with passwords masked, and app.log must stay uncha...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c1e7b53f-b2a8-52f8-95af-e9482b3b6d4e', '79fe423d-5212-5b1f-a1ea-f4e8ade5619a', 1, $json${"prompt":"You need a copy of app.log with passwords masked, and app.log must stay unchanged as evidence. Which command?","multiple":false,"options":[{"id":"a","text":"sed -i 's/password=[^ ]*/password=***/' app.log","is_correct":false},{"id":"b","text":"sed 's/password=[^ ]*/password=***/' app.log \u003e app-clean.log","is_correct":true},{"id":"c","text":"sed 's/password=[^ ]*/password=***/' app.log \u003e app.log","is_correct":false},{"id":"d","text":"grep -v password app.log \u003e app.log","is_correct":false}],"explanation":"Without -i, sed prints an edited copy, which you redirect into a new file. -i edits the evidence in place. Redirecting into the same file empties it before sed reads it, and the grep version both destroys the original and drops lines instead of masking them."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('19380b19-af65-5fe9-9913-916c9c904ffa', '00000000-0000-0000-0000-000000000001', 'mcq', 'find / -name ''*.conf'' prints hundreds of ''Permission denied'' lines around the...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d94d229c-0632-50bb-bf66-663da8bd0e35', '19380b19-af65-5fe9-9913-916c9c904ffa', 1, $json${"prompt":"find / -name '*.conf' prints hundreds of 'Permission denied' lines around the results. How do you keep only the results on screen?","multiple":false,"options":[{"id":"a","text":"find / -name '*.conf' 2\u003e/dev/null","is_correct":true},{"id":"b","text":"find / -name '*.conf' \u003e/dev/null","is_correct":false},{"id":"c","text":"find / -name '*.conf' | grep -v conf","is_correct":false},{"id":"d","text":"find / -name '*.conf' \u0026\u003e/dev/null","is_correct":false}],"explanation":"The errors are on stderr (2), so 2\u003e/dev/null discards just them. \u003e/dev/null throws away the results instead, \u0026\u003e throws away both, and grep -v conf would remove the results too."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('add236b3-0763-5bed-ba3f-858a0df27f91', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 2): you want to compress every .log file under /srv/app, incl...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bccfe972-df44-56c0-9ca1-3dab83757034', 'add236b3-0763-5bed-ba3f-858a0df27f91', 1, $json${"prompt":"Review (chapter 2): you want to compress every .log file under /srv/app, including subdirectories, even with spaces in names. Which command?","multiple":false,"options":[{"id":"a","text":"gzip /srv/app/*.log","is_correct":false},{"id":"b","text":"find /srv/app -name '*.log' -print0 | xargs -0 gzip","is_correct":true},{"id":"c","text":"ls /srv/app | gzip","is_correct":false},{"id":"d","text":"find /srv/app -name *.log | gzip","is_correct":false}],"explanation":"find walks subdirectories, and -print0 with xargs -0 keeps names with spaces intact. The glob only covers the top directory, ls | gzip compresses the list of names rather than the files, and piping names into gzip compresses the text, not the files (and the pattern is unquoted)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('75defd31-4d20-51ab-8e3e-696aee1f6b5d', '00000000-0000-0000-0000-000000000001', 'Quiz: Text Tools and Pipes', 'linux-the-logbook-quiz', 'Quiz covering Chapter 3: The Logbook - Text Tools and Pipes.', 'mcq', 'published', 'module', 'bf0047a6-c13e-5bf5-9556-59a2f6c47e4c', 12, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '75defd31-4d20-51ab-8e3e-696aee1f6b5d' AND question_id NOT IN ('a86155b8-b84b-51eb-b15e-a0e54bce5c32', 'ac8bbc88-ad11-53b7-a77a-d69410a33ac4', '39be6fd3-41fe-51ff-8441-d5a7640cd346', 'e31d8ddf-a0ae-5003-832c-f60768990d1c', 'c0714155-ee0d-5fab-919e-bebd906f1d38', '79fe423d-5212-5b1f-a1ea-f4e8ade5619a', '19380b19-af65-5fe9-9913-916c9c904ffa', 'add236b3-0763-5bed-ba3f-858a0df27f91');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('0ce1d0d2-6f14-5017-8b75-5726b3544273', '75defd31-4d20-51ab-8e3e-696aee1f6b5d', 'a86155b8-b84b-51eb-b15e-a0e54bce5c32', '972689c7-d34c-51db-92aa-02f77d765daa', 0, 2),
('5074852e-6944-5ddd-b5e2-5a45a7c6002e', '75defd31-4d20-51ab-8e3e-696aee1f6b5d', 'ac8bbc88-ad11-53b7-a77a-d69410a33ac4', 'd66c2449-abd3-5347-a273-5c265b01798d', 1, 2),
('00ec782a-5de1-52d4-9a73-df4f7de1244a', '75defd31-4d20-51ab-8e3e-696aee1f6b5d', '39be6fd3-41fe-51ff-8441-d5a7640cd346', '72d5a38d-4865-5a04-adf2-bad5c16afe00', 2, 2),
('527757a4-1b32-5aca-bcd9-a687082f0b72', '75defd31-4d20-51ab-8e3e-696aee1f6b5d', 'e31d8ddf-a0ae-5003-832c-f60768990d1c', '263e899e-4b39-5ba6-b8ed-7bc8a52d437c', 3, 2),
('96b82ec8-aa56-5ff1-98ea-dcfb7f432993', '75defd31-4d20-51ab-8e3e-696aee1f6b5d', 'c0714155-ee0d-5fab-919e-bebd906f1d38', '5dd8ccf5-94f9-50ff-b2a7-514fd786593e', 4, 2),
('cfd7802f-2697-51cf-b464-2c863c36c3cc', '75defd31-4d20-51ab-8e3e-696aee1f6b5d', '79fe423d-5212-5b1f-a1ea-f4e8ade5619a', 'c1e7b53f-b2a8-52f8-95af-e9482b3b6d4e', 5, 2),
('3040c6f1-b7f0-5f66-8ef2-a7b6c691386a', '75defd31-4d20-51ab-8e3e-696aee1f6b5d', '19380b19-af65-5fe9-9913-916c9c904ffa', 'd94d229c-0632-50bb-bf66-663da8bd0e35', 6, 2),
('d2aafb63-e245-59a0-9484-563d1e39c021', '75defd31-4d20-51ab-8e3e-696aee1f6b5d', 'add236b3-0763-5bed-ba3f-858a0df27f91', 'bccfe972-df44-56c0-9ca1-3dab83757034', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('bf0047a6-c13e-5bf5-9556-59a2f6c47e4c', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'Quiz: Text Tools and Pipes', 'assessment', 8, 10, '75defd31-4d20-51ab-8e3e-696aee1f6b5d')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 4: Keys and Locks - Users and Permissions
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('ace77ee1-65f9-5db8-a581-1431f13b56fc', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 4: Keys and Locks - Users and Permissions', 4, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('49afe0f9-ea78-5800-b816-537f12311cf3', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'Users and Groups: Who Is Who on Atlas', 'notes', 0, $md$## Why this matters

> **Thursday.** Rhea is upset: "Someone read our database password last night.
> Tom's old deploy script was world-readable." Tom's note said *not everyone
> should have every key*.

Before you can lock anything, you must know who the "someones" are. Every
permission decision Linux makes starts with two questions: **which user** is
asking, and **which groups** are they in?

## Mental model: staff badges

- Every person and every service has a **user** account: a badge with a number,
  the **UID** (user ID).
- A **group** is a team badge (GID). A user has one **primary group** and any
  number of **supplementary groups**.
- Every **process** runs with a user's badge, and every **file** is owned by one
  user and one group.

On each file access, the kernel compares the process's badges with the file's
owner and group. That is the whole security model of this chapter.

UID **0** is **root**, the superuser. The kernel skips most permission checks for
UID 0. Its name does not matter; its number does.

## See it work

```bash
whoami        # your user name
id            # your UID, primary group and all groups
```

What this does: shows your badges. Expected output in the lab:

```
labuser
uid=1001(labuser) gid=1001(labuser) groups=1001(labuser)
```

On a real admin account you might see
`groups=1000(rhea),27(sudo),998(docker)`.

### The staff register: three text files

```bash
getent passwd labuser root www-data
```

```
labuser:x:1001:1001::/home/labuser:/bin/bash
root:x:0:0:root:/root:/bin/bash
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
```

`/etc/passwd` has seven colon-separated fields:

```
labuser : x  : 1001 : 1001 : (comment) : /home/labuser : /bin/bash
 name    pw    UID    GID     comment      home          login shell
```

- The `x` means the password hash is in **`/etc/shadow`**, readable only by
  root.
- `/etc/group` lists groups: `baristas:x:2001:labuser,rhea` (name, pw, GID,
  members).

`getent` reads these databases the way programs do, including network
directories like LDAP, so prefer it over `cat /etc/passwd` when it matters.

### System accounts

UIDs below 1000 (on Debian/Ubuntu and RHEL) are usually **system accounts** for
services: `www-data` (web server), `postgres`, `redis`. Their shell is
`/usr/sbin/nologin`, so nobody can log in as them. Running each service as its
own user limits the damage if it is hacked.

```bash
who      # who is logged in right now
w        # same, plus what they are running
last     # recent logins (reads /var/log/wtmp)
```

## Try it

Using `/etc/passwd`, print the UID and login shell of `labuser`, separated by a
space. (Chapter 3's `awk -F:` will do it.)

<details>
<summary>Show answer</summary>

```bash
awk -F: '$1 == "labuser" {print $3, $7}' /etc/passwd
```

```
1001 /bin/bash
```

</details>

## Common mistakes

- **Thinking "root" is special because of its name.** Any account with UID 0 is
  all-powerful. An extra UID 0 account is a classic backdoor; check with
  `awk -F: '$3 == 0' /etc/passwd`.
- **Editing `/etc/passwd` by hand.** One broken line can lock everyone out. Use
  `useradd`, `usermod` and `vipw` (next lesson).
- **Running services as root "to avoid permission errors".** Give each service
  its own user and fix the permissions instead.

## Remember

- Users have UIDs, groups have GIDs; root is UID 0.
- `id` shows your user and groups; `getent passwd NAME` shows an account.
- `/etc/passwd` (accounts), `/etc/shadow` (hashes, root only), `/etc/group`.
- Services run as system users with `nologin` shells.

**Self-check:**

1. Which field of `/etc/passwd` holds the login shell?
2. Where are password hashes stored, and who can read them?
3. Why does `www-data` have `/usr/sbin/nologin` as its shell?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e3fdea25-4723-55cf-9e13-25710487a99d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'Managing Users and Groups: useradd, usermod, passwd', 'notes', 1, $md$## Why this matters

Sam joins the team on Monday and needs an account. A forgotten test account was
how someone read the database password. Creating, changing and removing accounts
correctly, and spotting the ones that should not exist, is basic hygiene.

## Mental model: hiring, transfers, leaving

| Event | Command (needs root) |
|---|---|
| Hire someone | `useradd` (+ `passwd`) |
| Join a team | `usermod -aG team user` |
| Temporary suspension | `usermod -L` / `passwd -l` (lock) |
| Leave | `userdel -r` |
| New team | `groupadd` |

> **Memory hook:** `usermod -aG`: **A**lways **A**ppend. Forget the `-a` and the
> user is *removed* from every group you did not list.

## See it work

These commands change system files, so they need root. On atlas you prefix them
with `sudo` (lesson 8 of this chapter). They will not work in the lab, where you
are a normal user.

```bash
sudo groupadd baristas                          # new group
sudo useradd -m -s /bin/bash -G baristas sam    # create user
sudo passwd sam                                 # set a password (asks twice)
id sam
```

What this does: `-m` creates `/home/sam`, `-s` sets the login shell, `-G` adds
supplementary groups. Expected output of `id sam`:

```
uid=1002(sam) gid=1002(sam) groups=1002(sam),2001(baristas)
```

Each new user gets a private primary group with the same name (the "user
private group" scheme). On Debian/Ubuntu, `adduser sam` is a friendlier
interactive wrapper that asks for the password and details.

### Changing an existing user

```bash
sudo usermod -aG docker sam       # ADD sam to docker, keep other groups
sudo usermod -s /usr/sbin/nologin sam   # disable shell logins
sudo usermod -L sam               # lock the password (adds ! to the hash)
sudo usermod -U sam               # unlock
sudo chage -l sam                 # password ageing info
sudo chage -E 2026-12-31 sam      # account expires on that date
```

Group changes apply at the **next login**. Sam must log out and back in (or run
`newgrp docker` in one shell) before `id` shows the new group.

### Removing

```bash
sudo userdel -r sam      # delete user, home directory and mail spool
sudo groupdel baristas
```

Before deleting, find files the user owns elsewhere:
`sudo find / -xdev -user sam 2>/dev/null`.

### Auditing accounts

```bash
awk -F: '$3 >= 1000 {print $1}' /etc/passwd           # human accounts
awk -F: '$3 == 0 {print $1}' /etc/passwd              # should print only root
sudo awk -F: '$2 == "" {print $1}' /etc/shadow        # accounts with NO password
lastlog | grep -v Never                               # who ever logged in
```

## Try it

Sam is in groups `sam` and `sudo`. You run `sudo usermod -G docker sam`. What
groups does Sam have now, and what should you have typed?

<details>
<summary>Show answer</summary>

Only `sam` (primary) and `docker`. Without `-a`, `-G` replaces the whole list,
so Sam lost `sudo`. The right command is `sudo usermod -aG docker sam`.

</details>

## Common mistakes

- **`usermod -G` without `-a`.** Silently strips other groups, including
  `sudo`.
- **Expecting group changes to apply instantly.** Existing sessions keep their
  old groups until the user logs in again.
- **`userdel` without checking for running processes and cron jobs.** Kill or
  move them first, or the account's jobs fail in odd ways.
- **Shared accounts.** One `deploy` login used by five people means no audit
  trail. Give everyone their own account and use groups and sudo.

## Remember

- `useradd -m -s /bin/bash -G grp NAME`, then `passwd NAME`.
- `usermod -aG grp NAME`: always append.
- Lock with `usermod -L`, expire with `chage -E`, remove with `userdel -r`.
- New group membership needs a new login.

**Self-check:**

1. What does `-m` do in `useradd`?
2. Why does Sam not see the new group right away?
3. Which command lists accounts with UID 0?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0df028e1-6c37-546f-91cb-a92db089afa9', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'Reading Permissions: rwx for Owner, Group and Others', 'notes', 2, $md$## Why this matters

"Permission denied" is the most common error on Linux. You can only fix it if
you can read the ten characters at the start of `ls -l` in one glance and know
which of them applies to you.

## Mental model: three locks on every door

Every file has three sets of locks, for three kinds of people:

```
 -rwxr-x---  1  rhea  baristas  512  Oct 14  deploy.sh
 |\_/\_/\_/     |     |
 | |  |  |      owner group
 | |  |  others: ---  nothing
 | |  group:     r-x  read + execute
 | owner:        rwx  read + write + execute
 type: - file, d directory, l symlink
```

Linux checks **one** class only, the first that fits:

```
 Are you the owner?        -> use the owner bits. Stop.
 Else, in the file's group? -> use the group bits. Stop.
 Else                       -> use the others bits.
```

So if the owner bits are `---`, the owner is denied even if "others" may read.
Root skips these checks (except that it still needs at least one `x` to run a
file).

## What r, w, x mean

The same letter means different things on files and directories:

| | On a file | On a directory |
|---|---|---|
| **r** | read the content | list the names inside (`ls`) |
| **w** | change the content | create, delete, rename entries inside |
| **x** | run it as a program | enter it (`cd`) and reach files inside |

Two consequences surprise everyone:

- **Deleting a file needs `w` on the directory**, not on the file. A read-only
  file in your own directory can still be deleted by you.
- **To reach `/srv/shop/menu.txt` you need `x` on `/`, `/srv` and `/srv/shop`.**
  One locked directory in the path blocks everything below it.

## See it work

```bash
ls -l ~/work/answers/kernel.txt
ls -ld ~/work /tmp
```

What this does: `-d` lists the directory itself instead of its contents.
Expected output (similar):

```
-rw-r--r-- 1 labuser labuser 17 Oct 14 09:20 /home/labuser/work/answers/kernel.txt
drwxr-xr-x 4 labuser labuser 4096 Oct 14 09:00 /home/labuser/work
drwxrwxrwt 1 root    root    4096 Oct 15 11:56 /tmp
```

- `kernel.txt`: owner read/write, everyone else read only.
- `/tmp`: everyone can do everything, plus a `t` at the end (the sticky bit,
  lesson 6).

`stat` shows the same in numbers:

```bash
stat -c '%A %a %U:%G %n' ~/work/answers/kernel.txt
```

```
-rw-r--r-- 644 labuser:labuser /home/labuser/work/answers/kernel.txt
```

`namei -l` shows the permissions of **every directory on the path**, which is
how you find the one locked door:

```bash
namei -l /home/labuser/work/answers/kernel.txt
```

```
f: /home/labuser/work/answers/kernel.txt
drwxr-xr-x root    root    /
drwxr-xr-x root    root    home
drwxr-x--- labuser labuser labuser
drwxr-xr-x labuser labuser work
drwxr-xr-x labuser labuser answers
-rw-r--r-- labuser labuser kernel.txt
```

`/home/labuser` is `drwxr-x---`: other users cannot even enter your home.

## Try it

A file is `-r--rw-rw- rhea baristas notes.txt`. Rhea (in group baristas) tries
to write to it. Allowed? And Sam, who is in baristas but is not Rhea?

<details>
<summary>Show answer</summary>

Rhea: **denied**. She is the owner, so only the owner bits `r--` apply; the
group bits are never checked for her. Sam: **allowed**, he is not the owner but
is in the group, so `rw-` applies.

</details>

## Common mistakes

- **Adding up classes.** Linux does not combine owner + group + others. Only the
  first matching class counts.
- **Checking only the file.** Missing `x` on a parent directory gives
  "Permission denied" for a perfectly readable file. Use `namei -l`.
- **Thinking `r` on a directory lets you open files.** `r` lists names; `x` lets
  you reach the files.

## Remember

- `type owner group others`: `-rwxr-x---`.
- One class applies: owner, else group, else others.
- Directory `w` = create/delete entries; directory `x` = pass through.
- `ls -ld`, `stat`, `namei -l` show what really applies.

**Self-check:**

1. What permission do you need to delete a file?
2. What does `x` mean on a directory?
3. Which command shows permissions of every directory on a path?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2ccfc028-4aa0-5f7e-9a25-27d3fd01017a', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'chmod: Changing the Locks with Numbers and Letters', 'notes', 3, $md$## Why this matters

The deploy script was world-readable, so anyone on atlas could read the database
password inside it. One `chmod` would have prevented the incident. You will set
permissions every week: scripts, keys, secrets, shared folders.

## Mental model: three wizards per class

Each class (owner, group, others) gets a number from adding up three values:

```
 r = 4      w = 2      x = 1

 7 = rwx   6 = rw-   5 = r-x   4 = r--   0 = ---
```

> **Memory hook:** **R**eal **W**izards e**X**ist: **4 - 2 - 1**. Add the
> wizards you want: read + write = 4 + 2 = 6.

Three digits, one per class, in the order owner, group, others:

```
 chmod 740 deploy.sh
       |||
       ||+-- others: 0 = ---
       |+--- group:  4 = r--
       +---- owner:  7 = rwx
```

The five modes you will use 95% of the time:

| Mode | Looks like | Use for |
|---|---|---|
| `755` | `rwxr-xr-x` | programs, scripts, normal directories |
| `644` | `rw-r--r--` | normal files |
| `700` | `rwx------` | private directories (`~/.ssh`) |
| `600` | `rw-------` | private keys, passwords, `.env` files |
| `640` | `rw-r-----` | config readable by a service's group |

## See it work

```bash
mkdir -p ~/work/keys && cd ~/work/keys
echo 'echo deploying' > deploy.sh
chmod 740 deploy.sh
ls -l deploy.sh
```

What this does: owner gets everything, group may read, others nothing. Expected
output:

```
-rwxr----- 1 labuser labuser 15 Oct 14 10:02 deploy.sh
```

### Symbolic mode: small changes

When you only want to change one thing, letters are clearer than numbers:

```bash
chmod u+x deploy.sh          # owner (user): add execute
chmod go-rwx secrets.env     # group and others: remove everything
chmod g=r deploy.sh          # group: exactly read, nothing else
chmod a+r index.html         # all: add read
chmod -R g+w shared/         # recursive: whole tree
```

`u` user/owner, `g` group, `o` others, `a` all; `+` add, `-` remove, `=` set
exactly.

### Recursive changes, carefully

`chmod -R 644 dir` also removes `x` from every **directory**, so nobody can
enter them any more. Use capital `X`, which adds execute only to directories
(and files that already have it):

```bash
chmod -R u=rwX,g=rX,o= /srv/shop      # dirs 750, files 640
```

Or treat files and directories separately with `find`:

```bash
find /srv/shop -type d -exec chmod 755 {} +
find /srv/shop -type f -exec chmod 644 {} +
```

Only the file's **owner** (or root) can change its mode.

## Try it

Create `secrets.env` containing `DB_PASSWORD=espresso` and make it readable and
writable by you only. Give both the numeric and the symbolic command.

<details>
<summary>Show answer</summary>

```bash
echo 'DB_PASSWORD=espresso' > secrets.env
chmod 600 secrets.env          # or: chmod u=rw,go= secrets.env
ls -l secrets.env              # -rw------- ...
```

</details>

## Common mistakes

- **`chmod 777` to "fix" an error.** It lets every user and every hacked service
  change the file. Find who needs access and grant only that.
- **`chmod -R 644` on a directory tree.** Directories lose `x` and become
  unreachable. Use `X` or `find -type`.
- **Making a secret 600 but leaving its directory open.** Others cannot read it,
  but with `w` on the directory they can delete or replace it.
- **Forgetting the leading zero is optional.** `chmod 0640` and `chmod 640` are
  the same. A fourth leading digit sets special bits (lesson 6).

## Remember

- r=4, w=2, x=1; three digits = owner, group, others.
- 755 programs/dirs, 644 files, 700 private dirs, 600 secrets.
- Symbolic: `u/g/o/a` with `+ - =`.
- Recursive: use `X` or separate `find -type d/f` runs. Never 777.

**Self-check:**

1. What number is `r-x`?
2. Write `rw-r-----` as a number.
3. What does capital `X` do in `chmod -R`?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('aa0b609a-d2eb-537a-9efc-3e17ff38e5b4', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'chown and chgrp: Changing Who Owns a File', 'notes', 4, $md$## Why this matters

You copy the shop's website into `/srv/shop` as yourself, and nginx (running as
`www-data`) answers 403 Forbidden. Brewbot cannot read its config because root
owns it with mode 600. Permissions are only half the story; the other half is
**who owns** the file.

## Mental model: the name on the locker

Each file has two name tags: an **owner** (a user) and a **group**. The rwx bits
from the last lesson say what the owner, the group and everyone else may do.
`chown` changes the tags; `chmod` changes the locks.

```
 -rw-r----- root  brewbot  brewbot.conf
            owner group
  root: rw   brewbot group members (the service): r   others: nothing
```

That pattern, **root owns, the service's group reads, mode 640**, is the
standard way to give a service read-only access to its config.

## See it work

These need root on atlas:

```bash
sudo chown rhea deploy.sh                    # new owner
sudo chown rhea:baristas deploy.sh           # owner and group
sudo chown :brewbot /etc/brewbot/brewbot.conf  # group only (same as chgrp)
sudo chown -R www-data:www-data /srv/shop    # whole tree
chgrp baristas notes.txt                     # group only
ls -l deploy.sh
```

Expected output of the last line:

```
-rwxr----- 1 rhea baristas 15 Oct 14 10:02 deploy.sh
```

### Who may change ownership?

- Only **root** can give a file to another user. Otherwise users could dodge
  disk quotas or plant files that look like someone else's.
- The owner may change the **group**, but only to a group they belong to.

In the lab (no root):

```bash
chown root ~/work/keys/deploy.sh
```

```
chown: changing ownership of '/home/labuser/work/keys/deploy.sh': Operation not permitted
```

### Fixing the brewbot config, the right way

```bash
sudo chown root:brewbot /etc/brewbot/brewbot.conf
sudo chmod 640 /etc/brewbot/brewbot.conf
sudo -u brewbot cat /etc/brewbot/brewbot.conf   # test AS the service user
```

`sudo -u brewbot` runs one command as the service's user: the fastest way to
prove the service can read what it needs.

## Try it

Brewbot runs as user `brewbot`. Its config `/etc/brewbot/brewbot.conf` is
`-rw------- root root`. Write the two commands that let brewbot read it without
letting anyone else read it or letting brewbot change it.

<details>
<summary>Show answer</summary>

```bash
sudo chgrp brewbot /etc/brewbot/brewbot.conf
sudo chmod 640 /etc/brewbot/brewbot.conf
```

Root keeps write access, the brewbot group gets read, others nothing. Making
brewbot the owner would also let it modify its own config, which you rarely
want.

</details>

## Common mistakes

- **`chown -R` on the wrong path.** `sudo chown -R www-data /` (from a stray
  space) breaks the whole system. Double-check before Enter.
- **Giving the service ownership when it only needs to read.** Use the group and
  640.
- **Fixing ownership of the file but not the directory.** The service also needs
  `x` on every parent directory (`namei -l`).

## Remember

- `chown user:group file`, `chgrp group file`, `-R` for trees.
- Only root can change the owner.
- Service config pattern: `root:service` with mode 640.
- Test as the service: `sudo -u USER command`.

**Self-check:**

1. Why can't normal users give files away?
2. What does `chown :web file` change?
3. How do you test whether user `brewbot` can read a file?
$md$, 5, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('fa188562-0645-5398-84e4-697ba8f4332e', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'Special Bits: SUID, SGID and the Sticky Bit', 'notes', 5, $md$## Why this matters

How can a normal user change their own password, when the password file is
root-only? Why can't you delete other people's files in `/tmp`, which everyone
can write? Three special bits explain both, and one of them is a favourite target
for attackers.

## Mental model: three special stickers

| Bit | Value | On a file | On a directory | Looks like |
|---|---|---|---|---|
| **SUID** | 4000 | runs as the file's **owner**, not as you | (no effect) | `-rwsr-xr-x` |
| **SGID** | 2000 | runs as the file's **group** | new files inherit the directory's group | `drwxrwsr-x` |
| **Sticky** | 1000 | (no effect) | only a file's owner can delete or rename it | `drwxrwxrwt` |

They appear in the `x` positions of `ls -l`: `s` or `t` when `x` is also set,
capital `S` or `T` when it is not (usually a mistake).

> **Memory hook:** the **sticky** bit is **chewing gum on a locker**: anyone can
> put things in, but only you can take yours out.

## See it work

### SUID: borrowing the owner's badge

```bash
ls -l /usr/bin/passwd
```

```
-rwsr-xr-x 1 root root 64152 May 30  2024 /usr/bin/passwd
```

The `s` means: whoever runs `passwd` runs it **as root**. That is how a normal
user can update the root-only `/etc/shadow`. `passwd` carefully only lets you
change your own entry.

SUID root programs are a favourite attack target: one bug in them is a path to
root. List them all:

```bash
find / -perm -4000 -type f 2>/dev/null
```

Know what is normally there (`passwd`, `su`, `sudo`, `mount`, `ping` on older
systems) and investigate anything new.

### SGID on a directory: shared team folders

```bash
sudo mkdir /srv/roastery
sudo chgrp baristas /srv/roastery
sudo chmod 2775 /srv/roastery
ls -ld /srv/roastery
```

```
drwxrwsr-x 2 root baristas 4096 Oct 14 11:00 /srv/roastery
```

Now every file created inside belongs to group `baristas`, whoever creates it,
so the whole team can work on it.

### Sticky: a shared drop box

```bash
ls -ld /tmp
mkdir -p ~/work/keys/drop && chmod 1777 ~/work/keys/drop
ls -ld ~/work/keys/drop
```

```
drwxrwxrwt 1 root root 4096 Oct 15 11:56 /tmp
drwxrwxrwt 2 labuser labuser 4096 Oct 14 11:05 /home/labuser/work/keys/drop
```

`1777` = sticky (1000) + `rwxrwxrwx` (777). Everyone can create files, but users
can delete only their own.

### Setting them symbolically

```bash
chmod u+s file      # SUID
chmod g+s dir       # SGID
chmod +t dir        # sticky
```

## Try it

You see `-rwSr--r-- labuser labuser report`. What does the capital `S` tell
you, and is it dangerous?

<details>
<summary>Show answer</summary>

SUID is set but the owner has no execute bit, so the file cannot run and the
SUID bit does nothing. It is a harmless mistake; remove it with `chmod u-s
report`.

</details>

## Common mistakes

- **SUID on shell scripts.** Linux ignores SUID on scripts (for good reason). Use
  `sudo` rules instead (lesson 8).
- **World-writable directories without the sticky bit.** Then any user can delete
  everyone's files. Shared write = `1777` or SGID group folders.
- **Leaving unexpected SUID binaries around.** Audit with `find / -perm -4000`.

## Remember

- SUID 4000: run as the file's owner (`passwd`).
- SGID 2000: on a directory, new files inherit its group (team folders).
- Sticky 1000: in a shared directory, only owners delete (`/tmp`, `1777`).
- `s`/`t` in `ls -l`; capital means `x` is missing.

**Self-check:**

1. Why can `passwd` write to `/etc/shadow`?
2. What mode do you give a `/tmp`-like directory?
3. How do you list every SUID file on the system?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6ddf6e30-fb69-5a55-82b6-5557078b415e', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'umask: Safe Defaults for New Files', 'notes', 6, $md$## Why this matters

You can `chmod` every secret file by hand, but you will forget one. The
**umask** decides the permissions of every *new* file automatically. Get the
default right and new files are private without you thinking about it.

## Mental model: a stencil that blocks bits

Programs ask for generous permissions when they create things:

- new **files**: `666` (`rw-rw-rw-`)
- new **directories**: `777` (`rwxrwxrwx`)

The umask is a stencil laid over that request. Every bit set in the umask is
**removed**.

```
  files:  666 - 022 = 644      directories: 777 - 022 = 755    (common default)
  files:  666 - 027 = 640      directories: 777 - 027 = 750    (safer)
  files:  666 - 077 = 600      directories: 777 - 077 = 700    (private)
```

(Strictly it is "remove these bits", not subtraction, but with these common
values the arithmetic gives the same answer.)

## See it work

```bash
umask
cd ~/work && touch before.txt && mkdir before.d
umask 027
touch after.txt && mkdir after.d
ls -ld before.txt before.d after.txt after.d
```

What this does: shows the current umask, creates a file and a directory, tightens
the umask, and creates two more. Expected output:

```
0022
drwxr-xr-x 2 labuser labuser 4096 ... before.d
-rw-r--r-- 1 labuser labuser    0 ... before.txt
drwxr-x--- 2 labuser labuser 4096 ... after.d
-rw-r----- 1 labuser labuser    0 ... after.txt
```

Others lost all access to the new items. Existing files did not change: umask
only affects creation.

### Making it permanent

`umask 027` at the prompt lasts until the shell exits. Put it in `~/.bashrc`
(chapter 1) to keep it:

```bash
echo 'umask 027' >> ~/.bashrc
```

For services, systemd sets it per unit with `UMask=0027` in the `[Service]`
section (chapter 6).

## Try it

With `umask 077`, what permissions does a new file get? A new directory?

<details>
<summary>Show answer</summary>

File `600` (`rw-------`), directory `700` (`rwx------`). Only the owner can do
anything.

</details>

## Common mistakes

- **Expecting umask to change existing files.** It only applies at creation time.
  Use `chmod` for files that already exist.
- **Expecting new files to be executable.** Files start from 666, so a new file
  never gets `x` from the umask. You `chmod +x` scripts yourself.
- **A too-strict umask on shared servers.** With `077`, teammates cannot read
  files you create in a shared folder. Use `027` plus group folders.

## Remember

- New files start at 666, directories at 777; the umask removes bits.
- 022 = 644/755, 027 = 640/750, 077 = 600/700.
- `umask` shows it; put `umask 027` in `~/.bashrc` to keep it.
- Only affects new files.

**Self-check:**

1. What does a umask of 022 do to a new directory?
2. Why does a new file never get the execute bit by default?
3. Where do you set a permanent umask for your shell?
$md$, 5, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2012bf06-6b18-5c0c-a9a0-2807ef547a42', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'sudo: Borrowing Root''s Keys Safely', 'notes', 7, $md$## Why this matters

Installing packages, restarting services and editing `/etc` all need root. Logging
in as root for that is how one typo becomes an outage and how nobody can tell who
did what. `sudo` gives root power one command at a time, with a log entry for
each.

## Mental model: the key cabinet with a sign-out sheet

- Root's keys hang in a cabinet.
- `sudo` lets approved staff borrow a key **for one command**.
- Every borrow is written in a log: who, when, which command.
- The list of who may borrow which key is `/etc/sudoers`.

`su` is the old way: it asks for **root's** password and gives you a whole root
shell. `sudo` asks for **your own** password, can be limited to specific
commands, and logs each one. Prefer `sudo`.

## See it work

```bash
sudo apt update                # run one command as root
sudo -u postgres psql          # run as another user (not root)
sudo -l                        # what am I allowed to run?
sudo -i                        # a full root login shell (use sparingly)
sudo !!                        # rerun the previous command with sudo
```

Expected output of `sudo -l` for an admin on Ubuntu:

```
User rhea may run the following commands on atlas:
    (ALL : ALL) ALL
```

After you type your password once, sudo remembers it for about 15 minutes per
terminal.

### Who may use sudo?

Rules live in `/etc/sudoers` and files in `/etc/sudoers.d/`. On Ubuntu, members
of group **`sudo`** get full access; on RHEL/Fedora the group is **`wheel`**.

A narrow rule lets the baristas restart brewbot and nothing else:

```
# /etc/sudoers.d/baristas
%baristas ALL=(root) /usr/bin/systemctl restart brewbot
#  who    host  as-whom   which command (full path, only this one)
```

`%` marks a group. Always use full paths in rules.

### Edit only with visudo

```bash
sudo visudo                              # edit /etc/sudoers
sudo visudo -f /etc/sudoers.d/baristas   # edit a drop-in file
```

`visudo` locks the file and checks the syntax before saving. A broken sudoers
file can remove **everyone's** sudo access, and then you need recovery mode to
fix it (Incident Week covers that).

### The audit trail

Every sudo use is logged:

```bash
sudo grep sudo /var/log/auth.log | tail -3      # Debian/Ubuntu
sudo journalctl _COMM=sudo --since today        # any systemd distro
```

```
Oct 14 02:13:07 atlas sudo:  test : TTY=pts/1 ; PWD=/home/test ; USER=root ; COMMAND=/usr/bin/cat /etc/brewbot/brewbot.conf
```

That is how Rhea found the culprit: a forgotten `test` account with sudo rights.

### Dangerous rules

Some "harmless" commands give a full root shell: an editor (`vim` can run
`:!bash`), `less`, `find -exec`, `tar`, or any script the user can edit. Granting
`sudo vim /etc/hosts` is effectively granting root. Grant specific, non-interactive
commands, and keep `NOPASSWD` for automation accounts only.

## Try it

The baristas should be able to run `systemctl status brewbot` and
`systemctl restart brewbot` as root, and nothing else. Write the sudoers line and
say how you would install it safely.

<details>
<summary>Show answer</summary>

```
%baristas ALL=(root) /usr/bin/systemctl status brewbot, /usr/bin/systemctl restart brewbot
```

Create it with `sudo visudo -f /etc/sudoers.d/baristas`, then check with
`sudo -l -U sam` that a barista sees exactly those two commands.

</details>

## Common mistakes

- **`sudo su -` as a habit.** You lose the per-command log. Use `sudo CMD`, or
  `sudo -i` only when really needed.
- **Editing sudoers with a normal editor.** One typo locks everyone out. Always
  `visudo`.
- **`sudo` with redirection.** `sudo echo x > /etc/f` fails: the redirection runs
  as you. Use `echo x | sudo tee /etc/f`.
- **Granting editors or shells via sudo.** They can spawn a root shell.

## Remember

- `sudo CMD` = one command as root, logged; `sudo -u USER` = as someone else.
- `sudo -l` shows your rights.
- Rules in `/etc/sudoers` and `/etc/sudoers.d/`; edit with `visudo` only.
- Ubuntu group `sudo`, RHEL group `wheel`; logs in `auth.log` / the journal.

**Self-check:**

1. What is the difference between `su` and `sudo`?
2. Why must you use `visudo`?
3. Why is `sudo vim` effectively full root?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('949b7868-431b-54ca-9fdd-15adc89a0913', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'Beyond rwx: ACLs and File Attributes', 'notes', 8, $md$## Why this matters

Sam, from accounting, needs to read one report in `/srv/roastery`. He is not the
owner, and adding him to the `baristas` group would give him every team file.
Owner/group/others has only three slots. **ACLs** add more slots, one per person
or group.

## Mental model: extra named keys

- Classic permissions: three locks (owner, group, others).
- An **ACL** (access control list) adds named locks: "user sam: read",
  "group auditors: read".
- A `+` at the end of the mode in `ls -l` says "this file has extra locks; look
  closer".

```
 -rw-r-----+ 1 rhea baristas 812 Oct 14 report.csv
           ^ ACL present
```

## See it work

ACL tools come from the `acl` package (`sudo apt install acl`). They are not
installed in the lab image, so try these on your own machine.

```bash
setfacl -m u:sam:r report.csv       # -m modify: give user sam read
getfacl report.csv
```

Expected output:

```
# file: report.csv
# owner: rhea
# group: baristas
user::rw-
user:sam:r--
group::r--
mask::r--
other::---
```

Read it top to bottom: owner `rw-`, named user sam `r--`, owning group `r--`,
others nothing.

### The mask

`mask::` is a ceiling for every named entry and the group. If the mask is `r--`,
even `u:sam:rw` only gets read. `chmod g=...` on a file with an ACL actually
changes the **mask**, which surprises people. Check with `getfacl` after a
`chmod`.

### Default ACLs: inherit on new files

```bash
setfacl -d -m g:auditors:r /srv/roastery/reports   # -d: default for new files
setfacl -x u:sam report.csv                        # remove one entry
setfacl -b report.csv                              # remove all ACLs
```

A **default ACL** on a directory is copied to every new file created inside,
which is how you keep a shared folder readable by a second group.

Copying with `cp` drops ACLs unless you use `cp -a` (or `--preserve=all`), and
`tar` needs `--acls`.

### File attributes: locks even root respects

Attributes are a separate, filesystem-level set of flags (ext4, xfs).

```bash
lsattr notes.txt                    # list attributes
sudo chattr +i /etc/resolv.conf     # immutable: nobody, not even root, can change or delete it
sudo chattr -i /etc/resolv.conf     # remove the flag
sudo chattr +a /var/log/audit.log   # append-only: can add, never rewrite
```

```
--------------e------- notes.txt
```

(`e` just means the file uses extents, normal on ext4.) Setting `+i` or `+a`
needs root. If root gets "Operation not permitted" deleting a file, check
`lsattr` before anything else.

## Try it

Sam must read `report.csv` (owner rhea, group baristas, mode 640) and nobody
else outside the team may. What do you run, and how will `ls -l` look after?

<details>
<summary>Show answer</summary>

```bash
setfacl -m u:sam:r report.csv
getfacl report.csv            # confirm user:sam:r--
```

`ls -l` shows `-rw-r-----+`: the same base mode with a `+` for the ACL.

</details>

## Common mistakes

- **Missing the `+` in `ls -l`.** The visible mode is no longer the full story;
  run `getfacl`.
- **A `chmod` that silently shrinks the mask.** Named users lose access.
- **ACLs where a group would do.** If five people need the same access, make a
  group. ACLs are for exceptions.
- **Forgetting immutable files.** `chattr +i` makes upgrades and edits fail with
  confusing errors.

## Remember

- ACLs add named users/groups: `setfacl -m u:NAME:r file`, read with `getfacl`.
- `+` after the mode = ACL present; `mask` caps named entries.
- `setfacl -d` sets defaults for new files in a directory.
- `chattr +i` (immutable) and `+a` (append-only); check with `lsattr`.

**Self-check:**

1. What does the `+` in `-rw-r-----+` mean?
2. What is the ACL mask for?
3. Root cannot delete a file. Which command do you run first?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a675c34c-0a48-58af-87ad-010cc471a6b6', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'Lab: Lock Up Atlas', 'notes', 9, $md$## Why this matters

Last night someone read the database password because a script was
world-readable. In this lab you read the staff register, lock the deploy script
and the secrets, build a shared drop box, and make new files private by default.
Each task is checked automatically.

## Before you start

```bash
id
umask
ls -ld ~ ~/work /tmp
```

What this does: shows who you are, your current umask, and three directory
modes to compare with later.

## Task 1: read the staff register

Using `/etc/passwd`, save labuser's numeric UID and login shell, separated by
one space, into `~/work/answers/passwd-check.txt` (for example `1234 /bin/sh`).

[[lab-task:1]]

## Task 2: lock the deploy script

Create `~/work/keys/deploy.sh` (any content). The owner may read, write and
execute; the group may only read; others get nothing.

[[lab-task:2]]

## Task 3: hide the secrets

Create `keys/secrets.env` containing the line `DB_PASSWORD=espresso`, readable
and writable by its owner only.

[[lab-task:3]]

What you should see:

```
$ ls -l ~/work/keys
-rwxr----- 1 labuser labuser 15 ... deploy.sh
-rw------- 1 labuser labuser 21 ... secrets.env
```

## Task 4: a shared drop box

Create `keys/drop`, a directory everyone can write into, where users can only
delete their own files: the same behaviour as `/tmp`.

[[lab-task:4]]

## Task 5: safer defaults for new files

Set your umask to `027` permanently in `~/.bashrc`, so new files are never
readable by others.

[[lab-task:5]]

Check yourself: open a new shell with `bash`, run `touch t && ls -l t`, and you
should see `-rw-r-----`.

## Remember

- `/etc/passwd`: name:x:UID:GID:comment:home:shell.
- 740 script, 600 secrets, 1777 shared drop box.
- `umask 027` in `~/.bashrc` makes new files 640.

> **End of day 4.** The deploy script is locked, secrets are 600, and new files
> are private by default. Rhea checks the sudo log and finds the culprit: a
> forgotten test account. Tom's next note was taped under a desk: "Atlas is
> never doing just one thing."
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('598576e4-b7c4-5a9d-9bef-83dfe9c66470', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'a675c34c-0a48-58af-87ad-010cc471a6b6', 'module', 'Lab: Lock Up Atlas', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
rm -rf $w/keys $w/answers
mkdir -p $w/answers
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed' AND id NOT IN ('a7132b41-aeee-5df6-aacb-4fa97efafbbe', '6dd9579d-1a7a-5fb5-9fae-acdff2369637', '7d7443e0-bd97-5db6-bc3f-20181326e47f', '69c98ab3-e74f-5d37-aa50-db876a8bf65c', 'a2de368a-135c-58c7-932e-c1b7312a8af9');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed';
DELETE FROM lab_tasks WHERE lab_id = '598576e4-b7c4-5a9d-9bef-83dfe9c66470' AND id NOT IN ('05829d63-f443-57a2-ac89-e4c9f90e5022', 'ec14c71d-3444-5b1a-9fec-75d48cfe11e9', '3f389c90-9e39-59b5-a462-03670f957f63', '01566597-6b21-56c7-aa75-defae5ae6f5c', 'eb16d62d-851c-5c61-be37-c5e05baa43ff');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '598576e4-b7c4-5a9d-9bef-83dfe9c66470';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('05829d63-f443-57a2-ac89-e4c9f90e5022', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 1, 'Read the staff register', $md$Using /etc/passwd, save labuser's numeric UID and login shell, separated by one space, into answers/passwd-check.txt - for example "1234 /bin/sh".$md$, $script$want="$(id -u labuser) $(getent passwd labuser | cut -d: -f7)"
[ "$(head -1 /home/labuser/work/answers/passwd-check.txt | tr -s ' ' | sed 's/ *$//')" = "$want" ]
$script$, 'grep ''^labuser:'' /etc/passwd shows the line. Field 3 is the UID and field 7 is the shell - awk -F: ''{print $3, $7}'' prints both.', '/etc/passwd has seven colon-separated fields - name:x:UID:GID:comment:home:shell. The x means the password hash lives in the root-only /etc/shadow.', 25, false, true),
('ec14c71d-3444-5b1a-9fec-75d48cfe11e9', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 2, 'Lock the deploy script', $md$Create the directory /home/labuser/work/keys and inside it a file deploy.sh (any content). Give it permissions so the owner can read, write and execute, the group can only read, and others get nothing.$md$, $script$f=/home/labuser/work/keys/deploy.sh
[ -f $f ] && [ "$(stat -c %a $f)" = 740 ] && [ "$(stat -c %U $f)" = labuser ]
$script$, 'Add up r=4 w=2 x=1 for each of owner, group and others. rwx = 7, r-- = 4, --- = 0.', 'chmod 740 sets owner rwx (4+2+1), group r-- (4), others --- (0). ls -l shows it as -rwxr-----.', 20, false, true),
('3f389c90-9e39-59b5-a462-03670f957f63', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 3, 'Hide the secrets', $md$Create keys/secrets.env containing the line DB_PASSWORD=espresso and make it readable and writable by its owner only.$md$, $script$f=/home/labuser/work/keys/secrets.env
grep -qx 'DB_PASSWORD=espresso' $f && [ "$(stat -c %a $f)" = 600 ]
$script$, 'Owner rw- is 6, group and others nothing is 0. chmod 600 or chmod u=rw,go= both work.', 'Credentials files should be 600. SSH, database clients and many tools refuse to use a key or secret file that others can read.', 15, false, true),
('01566597-6b21-56c7-aa75-defae5ae6f5c', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 4, 'A shared drop box', $md$Create the directory keys/drop that everyone can write into, but where users can only delete their own files (the same behaviour as /tmp).$md$, $script$d=/home/labuser/work/keys/drop
[ -d $d ] && [ "$(stat -c %a $d)" = 1777 ]
$script$, 'Compare with ls -ld /tmp - the trailing t is the sticky bit. Its numeric value is 1000, so 777 plus sticky is 1777.', 'On a directory, the sticky bit (t) stops users from deleting or renaming files they do not own, even though the directory is world-writable. That is exactly how /tmp works.', 20, false, true),
('eb16d62d-851c-5c61-be37-c5e05baa43ff', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 5, 'Safer defaults for new files', $md$Set your umask to 027 permanently in ~/.bashrc, so new files are never readable by others.$md$, $script$[ "$(bash -ic umask 2>/dev/null)" = 0027 ]
$script$, 'Append the line umask 027 to ~/.bashrc. The umask lists the bits to REMOVE from the default 666 (files) / 777 (directories).', 'With umask 027, new files become 640 and new directories 750 - the group can read, others get nothing. Putting it in ~/.bashrc applies it to every new shell.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 1, $json$[{"id":"05829d63-f443-57a2-ac89-e4c9f90e5022","lab_id":"598576e4-b7c4-5a9d-9bef-83dfe9c66470","position":1,"title":"Read the staff register","description":"Using /etc/passwd, save labuser's numeric UID and login shell, separated by one space, into answers/passwd-check.txt - for example \"1234 /bin/sh\".","verification_script":"want=\"$(id -u labuser) $(getent passwd labuser | cut -d: -f7)\"\n[ \"$(head -1 /home/labuser/work/answers/passwd-check.txt | tr -s ' ' | sed 's/ *$//')\" = \"$want\" ]\n","hint_context":"grep '^labuser:' /etc/passwd shows the line. Field 3 is the UID and field 7 is the shell - awk -F: '{print $3, $7}' prints both.","explanation_context":"/etc/passwd has seven colon-separated fields - name:x:UID:GID:comment:home:shell. The x means the password hash lives in the root-only /etc/shadow.","points":25,"is_optional":false,"is_stateful":true},{"id":"ec14c71d-3444-5b1a-9fec-75d48cfe11e9","lab_id":"598576e4-b7c4-5a9d-9bef-83dfe9c66470","position":2,"title":"Lock the deploy script","description":"Create the directory /home/labuser/work/keys and inside it a file deploy.sh (any content). Give it permissions so the owner can read, write and execute, the group can only read, and others get nothing.","verification_script":"f=/home/labuser/work/keys/deploy.sh\n[ -f $f ] \u0026\u0026 [ \"$(stat -c %a $f)\" = 740 ] \u0026\u0026 [ \"$(stat -c %U $f)\" = labuser ]\n","hint_context":"Add up r=4 w=2 x=1 for each of owner, group and others. rwx = 7, r-- = 4, --- = 0.","explanation_context":"chmod 740 sets owner rwx (4+2+1), group r-- (4), others --- (0). ls -l shows it as -rwxr-----.","points":20,"is_optional":false,"is_stateful":true},{"id":"3f389c90-9e39-59b5-a462-03670f957f63","lab_id":"598576e4-b7c4-5a9d-9bef-83dfe9c66470","position":3,"title":"Hide the secrets","description":"Create keys/secrets.env containing the line DB_PASSWORD=espresso and make it readable and writable by its owner only.","verification_script":"f=/home/labuser/work/keys/secrets.env\ngrep -qx 'DB_PASSWORD=espresso' $f \u0026\u0026 [ \"$(stat -c %a $f)\" = 600 ]\n","hint_context":"Owner rw- is 6, group and others nothing is 0. chmod 600 or chmod u=rw,go= both work.","explanation_context":"Credentials files should be 600. SSH, database clients and many tools refuse to use a key or secret file that others can read.","points":15,"is_optional":false,"is_stateful":true},{"id":"01566597-6b21-56c7-aa75-defae5ae6f5c","lab_id":"598576e4-b7c4-5a9d-9bef-83dfe9c66470","position":4,"title":"A shared drop box","description":"Create the directory keys/drop that everyone can write into, but where users can only delete their own files (the same behaviour as /tmp).","verification_script":"d=/home/labuser/work/keys/drop\n[ -d $d ] \u0026\u0026 [ \"$(stat -c %a $d)\" = 1777 ]\n","hint_context":"Compare with ls -ld /tmp - the trailing t is the sticky bit. Its numeric value is 1000, so 777 plus sticky is 1777.","explanation_context":"On a directory, the sticky bit (t) stops users from deleting or renaming files they do not own, even though the directory is world-writable. That is exactly how /tmp works.","points":20,"is_optional":false,"is_stateful":true},{"id":"eb16d62d-851c-5c61-be37-c5e05baa43ff","lab_id":"598576e4-b7c4-5a9d-9bef-83dfe9c66470","position":5,"title":"Safer defaults for new files","description":"Set your umask to 027 permanently in ~/.bashrc, so new files are never readable by others.","verification_script":"[ \"$(bash -ic umask 2\u003e/dev/null)\" = 0027 ]\n","hint_context":"Append the line umask 027 to ~/.bashrc. The umask lists the bits to REMOVE from the default 666 (files) / 777 (directories).","explanation_context":"With umask 027, new files become 640 and new directories 750 - the group can read, others get nothing. Putting it in ~/.bashrc applies it to every new shell.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('a7132b41-aeee-5df6-aacb-4fa97efafbbe', 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', '05829d63-f443-57a2-ac89-e4c9f90e5022', 1, 'Read the staff register', $md$Using /etc/passwd, save labuser's numeric UID and login shell, separated by one space, into answers/passwd-check.txt - for example "1234 /bin/sh".$md$, $script$want="$(id -u labuser) $(getent passwd labuser | cut -d: -f7)"
[ "$(head -1 /home/labuser/work/answers/passwd-check.txt | tr -s ' ' | sed 's/ *$//')" = "$want" ]
$script$, 'grep ''^labuser:'' /etc/passwd shows the line. Field 3 is the UID and field 7 is the shell - awk -F: ''{print $3, $7}'' prints both.', '/etc/passwd has seven colon-separated fields - name:x:UID:GID:comment:home:shell. The x means the password hash lives in the root-only /etc/shadow.', 25, false, true),
('6dd9579d-1a7a-5fb5-9fae-acdff2369637', 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', 'ec14c71d-3444-5b1a-9fec-75d48cfe11e9', 2, 'Lock the deploy script', $md$Create the directory /home/labuser/work/keys and inside it a file deploy.sh (any content). Give it permissions so the owner can read, write and execute, the group can only read, and others get nothing.$md$, $script$f=/home/labuser/work/keys/deploy.sh
[ -f $f ] && [ "$(stat -c %a $f)" = 740 ] && [ "$(stat -c %U $f)" = labuser ]
$script$, 'Add up r=4 w=2 x=1 for each of owner, group and others. rwx = 7, r-- = 4, --- = 0.', 'chmod 740 sets owner rwx (4+2+1), group r-- (4), others --- (0). ls -l shows it as -rwxr-----.', 20, false, true),
('7d7443e0-bd97-5db6-bc3f-20181326e47f', 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', '3f389c90-9e39-59b5-a462-03670f957f63', 3, 'Hide the secrets', $md$Create keys/secrets.env containing the line DB_PASSWORD=espresso and make it readable and writable by its owner only.$md$, $script$f=/home/labuser/work/keys/secrets.env
grep -qx 'DB_PASSWORD=espresso' $f && [ "$(stat -c %a $f)" = 600 ]
$script$, 'Owner rw- is 6, group and others nothing is 0. chmod 600 or chmod u=rw,go= both work.', 'Credentials files should be 600. SSH, database clients and many tools refuse to use a key or secret file that others can read.', 15, false, true),
('69c98ab3-e74f-5d37-aa50-db876a8bf65c', 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', '01566597-6b21-56c7-aa75-defae5ae6f5c', 4, 'A shared drop box', $md$Create the directory keys/drop that everyone can write into, but where users can only delete their own files (the same behaviour as /tmp).$md$, $script$d=/home/labuser/work/keys/drop
[ -d $d ] && [ "$(stat -c %a $d)" = 1777 ]
$script$, 'Compare with ls -ld /tmp - the trailing t is the sticky bit. Its numeric value is 1000, so 777 plus sticky is 1777.', 'On a directory, the sticky bit (t) stops users from deleting or renaming files they do not own, even though the directory is world-writable. That is exactly how /tmp works.', 20, false, true),
('a2de368a-135c-58c7-932e-c1b7312a8af9', 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', 'eb16d62d-851c-5c61-be37-c5e05baa43ff', 5, 'Safer defaults for new files', $md$Set your umask to 027 permanently in ~/.bashrc, so new files are never readable by others.$md$, $script$[ "$(bash -ic umask 2>/dev/null)" = 0027 ]
$script$, 'Append the line umask 027 to ~/.bashrc. The umask lists the bits to REMOVE from the default 666 (files) / 777 (directories).', 'With umask 027, new files become 640 and new directories 750 - the group can read, others get nothing. Putting it in ~/.bashrc applies it to every new shell.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', updated_at = now()
WHERE id = '598576e4-b7c4-5a9d-9bef-83dfe9c66470' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('11f5270e-c463-5492-b62c-81f51ce15cdb', '00000000-0000-0000-0000-000000000001', 'mcq', 'notes.txt is -r--rw-rw- owned by rhea, group baristas. Rhea is in baristas. C...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ccfd58e5-562c-5d9d-a16d-0fc4ad859959', '11f5270e-c463-5492-b62c-81f51ce15cdb', 1, $json${"prompt":"notes.txt is -r--rw-rw- owned by rhea, group baristas. Rhea is in baristas. Can Rhea write to it?","multiple":false,"options":[{"id":"a","text":"Yes, because the group bits allow write and she is in the group","is_correct":false},{"id":"b","text":"No: she is the owner, so only the owner bits (r--) are checked","is_correct":true},{"id":"c","text":"Yes, because others may write","is_correct":false},{"id":"d","text":"Only after a reboot","is_correct":false}],"explanation":"Linux picks exactly one class: owner first. Rhea matches owner, so group and others bits are never consulted. Classes do not add up, and reboots have nothing to do with permissions."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('46dc1d98-e3b7-5eab-a929-0b070dea806a', '00000000-0000-0000-0000-000000000001', 'mcq', 'A user gets ''Permission denied'' reading /srv/shop/menu.txt, which is -rw-r--r...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2e541666-a059-566e-abb4-0fdcbbe19332', '46dc1d98-e3b7-5eab-a929-0b070dea806a', 1, $json${"prompt":"A user gets 'Permission denied' reading /srv/shop/menu.txt, which is -rw-r--r--. What is the most likely cause?","multiple":false,"options":[{"id":"a","text":"The file needs the execute bit","is_correct":false},{"id":"b","text":"A directory on the path (/srv or /srv/shop) lacks x for that user; namei -l /srv/shop/menu.txt shows it","is_correct":true},{"id":"c","text":"The file is too large","is_correct":false},{"id":"d","text":"Others can never read files in /srv","is_correct":false}],"explanation":"Reaching a file needs x on every parent directory. Reading a file never needs x on the file itself, size is irrelevant, and /srv has no special rule."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5567ad26-49cf-526b-bbb8-baa56660135c', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which mode is right for a private SSH key or a .env file with passwords?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('3042ed33-90ab-5273-a16f-6f6c70e9b34f', '5567ad26-49cf-526b-bbb8-baa56660135c', 1, $json${"prompt":"Which mode is right for a private SSH key or a .env file with passwords?","multiple":false,"options":[{"id":"a","text":"600","is_correct":true},{"id":"b","text":"644","is_correct":false},{"id":"c","text":"755","is_correct":false},{"id":"d","text":"777","is_correct":false}],"explanation":"600 = rw for the owner only. 644 lets everyone read it, 755 also makes it executable for all, and 777 lets anyone change it. SSH even refuses keys that are readable by others."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('4ba599c2-55d8-5428-ae0d-7e4353db5681', '00000000-0000-0000-0000-000000000001', 'mcq', 'You run chmod -R 644 /srv/shop and suddenly nginx cannot serve anything in su...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('42efad68-ed08-57d6-a1d7-6801f5682947', '4ba599c2-55d8-5428-ae0d-7e4353db5681', 1, $json${"prompt":"You run chmod -R 644 /srv/shop and suddenly nginx cannot serve anything in subdirectories. Why?","multiple":false,"options":[{"id":"a","text":"644 removed the execute bit from the directories, so nobody can enter them","is_correct":true},{"id":"b","text":"nginx needs 777","is_correct":false},{"id":"c","text":"-R changes the owner","is_correct":false},{"id":"d","text":"644 is invalid for files","is_correct":false}],"explanation":"Directories need x to be entered. Use chmod -R u=rwX,g=rX,o=rX or separate find -type d / -type f commands. nginx does not need 777, -R does not touch ownership, and 644 is fine for files."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a1ceeb31-69fc-5a8e-a35b-0653a4c919ff', '00000000-0000-0000-0000-000000000001', 'mcq', 'What lets a normal user change their password even though /etc/shadow is root...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5e9a7196-03f2-534d-a716-de4c7df4e932', 'a1ceeb31-69fc-5a8e-a35b-0653a4c919ff', 1, $json${"prompt":"What lets a normal user change their password even though /etc/shadow is root-only?","multiple":false,"options":[{"id":"a","text":"/usr/bin/passwd has the SUID bit and is owned by root, so it runs as root","is_correct":true},{"id":"b","text":"/etc/shadow has the sticky bit","is_correct":false},{"id":"c","text":"Every user is secretly in the root group","is_correct":false},{"id":"d","text":"The umask allows it","is_correct":false}],"explanation":"SUID makes a program run with its owner's identity. The sticky bit only limits deletion in directories, users are not in the root group, and the umask only affects new files."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('41e24502-3fc5-5d80-b61a-26ab4298ca88', '00000000-0000-0000-0000-000000000001', 'mcq', 'With umask 027, what permissions does a newly created directory get?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('73ee1cbb-896d-5f4c-98fa-913778e62d8a', '41e24502-3fc5-5d80-b61a-26ab4298ca88', 1, $json${"prompt":"With umask 027, what permissions does a newly created directory get?","multiple":false,"options":[{"id":"a","text":"750 (rwxr-x---)","is_correct":true},{"id":"b","text":"640 (rw-r-----)","is_correct":false},{"id":"c","text":"027","is_correct":false},{"id":"d","text":"777","is_correct":false}],"explanation":"Directories start from 777 and the umask removes 027, leaving 750. 640 is what a new file gets. The umask is a filter, not the resulting mode."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('453c7737-a767-52a8-853f-69e248a1e615', '00000000-0000-0000-0000-000000000001', 'mcq', 'Brewbot (user brewbot) must read /etc/brewbot/brewbot.conf but must not modif...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('be6d40e4-7fc5-57bf-be78-6d104d805d49', '453c7737-a767-52a8-853f-69e248a1e615', 1, $json${"prompt":"Brewbot (user brewbot) must read /etc/brewbot/brewbot.conf but must not modify it. Which setup is best?","multiple":false,"options":[{"id":"a","text":"chown brewbot:brewbot and chmod 600","is_correct":false},{"id":"b","text":"chown root:brewbot and chmod 640","is_correct":true},{"id":"c","text":"chmod 666","is_correct":false},{"id":"d","text":"chmod 777 /etc/brewbot","is_correct":false}],"explanation":"Root owns and can write, the brewbot group can read, others get nothing. Making brewbot the owner lets it rewrite its config, and 666/777 let every user tamper with it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b1389867-8ba6-59c2-b43d-047cf520a7a8', '00000000-0000-0000-0000-000000000001', 'mcq', 'You want baristas to run only ''systemctl restart brewbot'' as root. How do you...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('56c94e0e-a83e-5a50-8ea9-63efba0e5979', 'b1389867-8ba6-59c2-b43d-047cf520a7a8', 1, $json${"prompt":"You want baristas to run only 'systemctl restart brewbot' as root. How do you add the rule?","multiple":false,"options":[{"id":"a","text":"Edit /etc/sudoers with nano","is_correct":false},{"id":"b","text":"sudo visudo -f /etc/sudoers.d/baristas with %baristas ALL=(root) /usr/bin/systemctl restart brewbot","is_correct":true},{"id":"c","text":"Add the baristas to the sudo group","is_correct":false},{"id":"d","text":"Give them root's password","is_correct":false}],"explanation":"visudo checks syntax before saving, and the rule grants exactly one command. Editing with nano risks a broken sudoers, the sudo group grants everything, and sharing root's password removes all accountability."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5ff3df8f-99f7-50c0-9077-b3e5f8262f78', '00000000-0000-0000-0000-000000000001', 'mcq', 'ls -l shows -rw-r-----+ on report.csv. What should you run to see who can rea...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d6708068-3375-5dcb-a432-d785edb2bbcd', '5ff3df8f-99f7-50c0-9077-b3e5f8262f78', 1, $json${"prompt":"ls -l shows -rw-r-----+ on report.csv. What should you run to see who can really read it?","multiple":false,"options":[{"id":"a","text":"getfacl report.csv","is_correct":true},{"id":"b","text":"lsattr report.csv","is_correct":false},{"id":"c","text":"stat -c %a report.csv","is_correct":false},{"id":"d","text":"id report.csv","is_correct":false}],"explanation":"The + means an ACL with extra named entries exists; getfacl lists them. lsattr shows filesystem attributes like immutable, stat %a shows only the base mode, and id is about users, not files."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1a732bed-cfa7-5264-82dd-375f2571cf3e', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 3): which command lists the user names of all accounts whose ...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('dfd2c952-923e-5627-b69a-bb28212009b2', '1a732bed-cfa7-5264-82dd-375f2571cf3e', 1, $json${"prompt":"Review (chapter 3): which command lists the user names of all accounts whose shell is /usr/sbin/nologin?","multiple":false,"options":[{"id":"a","text":"awk -F: '$7 == \"/usr/sbin/nologin\" {print $1}' /etc/passwd","is_correct":true},{"id":"b","text":"grep nologin /etc/shadow","is_correct":false},{"id":"c","text":"cut -f1 /etc/passwd | grep nologin","is_correct":false},{"id":"d","text":"awk '{print $7}' /etc/passwd","is_correct":false}],"explanation":"awk with -F: splits on colons, filters on field 7 and prints field 1. /etc/shadow has no shells and is root-only, cut -f1 without -d: uses tabs and drops the shell anyway, and the last awk splits on spaces and prints no names."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('a4618dec-c39b-5d7e-bbf1-04c5b938f3c5', '00000000-0000-0000-0000-000000000001', 'Quiz: Users and Permissions', 'linux-keys-and-locks-quiz', 'Quiz covering Chapter 4: Keys and Locks - Users and Permissions.', 'mcq', 'published', 'module', '8ba2fbe2-8360-5163-af09-ea100c4f9e3f', 12, 70, 5, 20, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5' AND question_id NOT IN ('11f5270e-c463-5492-b62c-81f51ce15cdb', '46dc1d98-e3b7-5eab-a929-0b070dea806a', '5567ad26-49cf-526b-bbb8-baa56660135c', '4ba599c2-55d8-5428-ae0d-7e4353db5681', 'a1ceeb31-69fc-5a8e-a35b-0653a4c919ff', '41e24502-3fc5-5d80-b61a-26ab4298ca88', '453c7737-a767-52a8-853f-69e248a1e615', 'b1389867-8ba6-59c2-b43d-047cf520a7a8', '5ff3df8f-99f7-50c0-9077-b3e5f8262f78', '1a732bed-cfa7-5264-82dd-375f2571cf3e');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('24371a28-f9f5-5993-8321-47e8fe23e4cc', 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5', '11f5270e-c463-5492-b62c-81f51ce15cdb', 'ccfd58e5-562c-5d9d-a16d-0fc4ad859959', 0, 2),
('d37efef7-619a-5f27-b412-cb0d6223bae4', 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5', '46dc1d98-e3b7-5eab-a929-0b070dea806a', '2e541666-a059-566e-abb4-0fdcbbe19332', 1, 2),
('1d6a4739-2e10-5b8d-86f3-a7faa0b82154', 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5', '5567ad26-49cf-526b-bbb8-baa56660135c', '3042ed33-90ab-5273-a16f-6f6c70e9b34f', 2, 2),
('d304a911-b69a-5a58-98f5-71f50399cc82', 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5', '4ba599c2-55d8-5428-ae0d-7e4353db5681', '42efad68-ed08-57d6-a1d7-6801f5682947', 3, 2),
('cd92c43f-f357-50a1-80ea-3a8b9674cdc4', 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5', 'a1ceeb31-69fc-5a8e-a35b-0653a4c919ff', '5e9a7196-03f2-534d-a716-de4c7df4e932', 4, 2),
('97fb8d87-adde-51fb-8e28-0a252ddea375', 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5', '41e24502-3fc5-5d80-b61a-26ab4298ca88', '73ee1cbb-896d-5f4c-98fa-913778e62d8a', 5, 2),
('29cf43b8-36b2-5dec-96fc-d72abfb157cc', 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5', '453c7737-a767-52a8-853f-69e248a1e615', 'be6d40e4-7fc5-57bf-be78-6d104d805d49', 6, 2),
('b88db7b5-56fc-5469-b85c-dce88ffac4fc', 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5', 'b1389867-8ba6-59c2-b43d-047cf520a7a8', '56c94e0e-a83e-5a50-8ea9-63efba0e5979', 7, 2),
('ed42bb2f-1ee9-538c-9544-644df47b755e', 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5', '5ff3df8f-99f7-50c0-9077-b3e5f8262f78', 'd6708068-3375-5dcb-a432-d785edb2bbcd', 8, 2),
('4cc877b5-fccc-51ac-a576-bfdc7d61534d', 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5', '1a732bed-cfa7-5264-82dd-375f2571cf3e', 'dfd2c952-923e-5627-b69a-bb28212009b2', 9, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('8ba2fbe2-8360-5163-af09-ea100c4f9e3f', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'Quiz: Users and Permissions', 'assessment', 10, 10, 'a4618dec-c39b-5d7e-bbf1-04c5b938f3c5')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 5: The Engine Room - Processes
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('ec8f752c-74df-5e68-b66e-b63f6f3212a5', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 5: The Engine Room - Processes', 5, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('fee0d4cf-ff18-5a5e-b150-0ba3e30cf050', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ec8f752c-74df-5e68-b66e-b63f6f3212a5', 'What a Process Is: PIDs, the Process Tree and ps', 'notes', 0, $md$## Why this matters

> **Friday morning.** Atlas feels slow. Rhea: "A server is never doing just one
> thing. Right now it's running hundreds of programs. Find out who is using the
> engine."

Every slow server, hung worker and "port already in use" error is about some
process. You need to list them, find the one you care about, and read its state.

## Mental model: recipe vs coffee being made

- A **program** is a file on disk (`/usr/bin/sleep`): the recipe.
- A **process** is a running copy of it: the coffee being made right now. One
  recipe, many cups, each with its own order number.

Every process has:

- a **PID** (process ID) and a **PPID** (its parent's PID)
- a **user** it runs as
- memory, open files, a current directory, environment variables
- a **state**: `R` running, `S` sleeping (waiting for something), `D`
  uninterruptible sleep (usually waiting on disk), `T` stopped, `Z` zombie

Every process is started by another one, so they form a family tree. At the top
is **PID 1**: on a real server that is **systemd**, the ancestor of everything.

```
systemd (1)
 |-- sshd (812)
 |    `-- sshd (2210) -- bash (2211) -- ps (2300)    <- you
 |-- nginx (901) --+-- nginx worker (902)
 |                 `-- nginx worker (903)
 `-- brewbot (1040)
```

> **Memory hook:** the program is the **recipe**, the process is the **coffee
> being made**: one recipe, many cups, each with its own order number (PID).

## See it work

```bash
ps
```

What this does: lists processes in this terminal. Expected output:

```
    PID TTY          TIME CMD
     12 pts/0    00:00:00 bash
     57 pts/0    00:00:00 ps
```

```bash
ps aux | head -4
```

```
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
labuser        1  0.0  0.0   4324  3456 ?        Ss   09:00   0:00 /bin/bash ...
labuser       12  0.0  0.0   4588  3840 pts/0    Ss   09:01   0:00 bash
labuser       57  0.0  0.0   7888  3968 pts/0    R+   09:02   0:00 ps aux
```

`a` = all users, `u` = user-oriented columns, `x` = include processes without a
terminal (daemons). Key columns: `%CPU`, `%MEM`, `RSS` (real memory in KiB),
`STAT` (state, plus extras: `s` session leader, `+` foreground). In the lab,
PID 1 is not systemd: inside a container, PID 1 is whatever the container
started.

### Finding the one you want

```bash
pgrep -a sleep             # PIDs and command lines matching "sleep"
pidof nginx                # just the PIDs of an exact program name
ps -ef --forest            # full list as a tree
ps -o pid,ppid,stat,ni,cmd -p 12     # chosen columns for one PID
ps aux --sort=-%cpu | head -5        # top CPU users
```

`ps aux | grep sleep` also works, but it finds the `grep` itself too. `pgrep`
does not.

### Live view: top

```bash
top
```

`top` refreshes every few seconds. Inside it: `P` sort by CPU, `M` by memory,
`k` kill, `1` per-CPU view, `q` quit. `htop` is a friendlier version where
installed. Chapter 11 reads `top` in depth.

## Try it

Start `sleep 500 &` (the `&` runs it in the background, lesson 3). Then find its
PID two ways and show its parent PID.

<details>
<summary>Show answer</summary>

```bash
sleep 500 &
pgrep -a sleep
ps -o pid,ppid,cmd -C sleep
```

The PPID is your bash shell's PID (`echo $$` prints it).

</details>

## Common mistakes

- **Confusing program and process.** Deleting the program file does not stop a
  running process.
- **Trusting `ps aux | grep x` counts.** The grep line is in the output. Use
  `pgrep -c x` or `pgrep -a x`.
- **Expecting systemd as PID 1 in containers.** Containers usually run the app
  itself as PID 1.

## Remember

- Program = file; process = running instance with a PID and a parent (PPID).
- States: R running, S sleeping, D disk wait, T stopped, Z zombie.
- `ps aux`, `ps -ef --forest`, `pgrep -a NAME`, `top`.
- PID 1 (systemd on servers) is the ancestor of everything.

**Self-check:**

1. What does state `D` usually mean?
2. Which command lists processes as a tree?
3. Why is `pgrep` better than `ps aux | grep`?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6fd766f9-3650-5a76-921d-ae364b0278e9', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ec8f752c-74df-5e68-b66e-b63f6f3212a5', '/proc: the Live Order Screen', 'notes', 1, $md$## Why this matters

`ps` shows a summary. When you need the full truth about one process (its exact
command line, its open files, its environment, which directory it runs in) you
read `/proc`. It also works when `ps` and `top` are not installed, which happens
in minimal containers.

## Mental model: the order screen in the kitchen

`/proc` is not on any disk. The kernel invents its files the moment you read
them. Every running process gets a directory named after its PID:

```
/proc/
  1/            <- PID 1
    cmdline     full command line (NUL-separated)
    comm        short process name
    status      state, memory, threads, UIDs
    environ     environment variables (owner/root only)
    cwd  ->     current directory (symlink)
    exe  ->     the program file (symlink)
    fd/         open files: 0 stdin, 1 stdout, 2 stderr, 3...
  self/         <- whatever process is reading it
  loadavg  meminfo  cpuinfo  uptime    system-wide numbers
```

Tools like `ps`, `top` and `free` are just reading these files for you.

## See it work

```bash
cat /proc/1/comm
cat /proc/$$/status | head -5
```

What this does: `$$` is the shell's own PID. Expected output (similar):

```
bash
Name:	bash
Umask:	0022
State:	S (sleeping)
Tgid:	12
Ngid:	0
```

```bash
sleep 600 &
p=$!                                 # $! = PID of the last background job
tr '\0' ' ' < /proc/$p/cmdline; echo # full command line
ls -l /proc/$p/cwd /proc/$p/exe      # where it runs, which binary
ls -l /proc/$p/fd                    # its open files
```

```
sleep 600
lrwxrwxrwx 1 labuser labuser 0 ... /proc/80/cwd -> /home/labuser
lrwxrwxrwx 1 labuser labuser 0 ... /proc/80/exe -> /usr/bin/sleep
lr-x------ 1 labuser labuser 64 ... 0 -> /dev/pts/0
l-wx------ 1 labuser labuser 64 ... 1 -> /dev/pts/0
l-wx------ 1 labuser labuser 64 ... 2 -> /dev/pts/0
```

`cmdline` separates arguments with NUL bytes, hence the `tr`.

### Useful tricks

```bash
cat /proc/loadavg                 # load averages, running/total, last PID
grep MemAvailable /proc/meminfo   # memory the system can still hand out
ls -l /proc/*/fd 2>/dev/null | grep deleted   # files deleted but still open
cat /proc/$p/limits               # resource limits (open files, processes)
```

The "deleted but still open" trick returns in Incident Week: it explains a disk
that stays full after you delete a log.

You can only read the private files (`environ`, `fd`) of your own processes,
unless you are root.

## Try it

Save the name of the process with PID 1 into a file, using only `/proc`.

<details>
<summary>Show answer</summary>

```bash
cat /proc/1/comm > pid1.txt
```

On a full server this prints `systemd`; in a container it is the container's
first program.

</details>

## Common mistakes

- **`cat /proc/PID/cmdline` and seeing words glued together.** Arguments are
  NUL-separated; pipe through `tr '\0' ' '`.
- **Thinking `/proc` uses disk space.** It is generated by the kernel; sizes show
  as 0.
- **Keeping a PID for later.** PIDs are reused after a process exits. Re-check
  before you `kill`.

## Remember

- `/proc/PID/` = live details of one process; `/proc/self` = you.
- `cmdline`, `status`, `cwd`, `exe`, `fd/` answer most questions.
- `/proc/loadavg`, `/proc/meminfo`, `/proc/cpuinfo` are system-wide.
- `$$` = this shell's PID, `$!` = last background PID.

**Self-check:**

1. Which file holds a process's full command line?
2. How do you see which files a process has open?
3. Why can PIDs not be trusted forever?
$md$, 6, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6a48b932-03c5-5902-a82b-599fdc4af2ff', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ec8f752c-74df-5e68-b66e-b63f6f3212a5', 'Foreground, Background, nohup and tmux', 'notes', 2, $md$## Why this matters

You start a 2-hour database dump over SSH, your Wi-Fi drops, and the dump dies
with your session. Or a command blocks your prompt and you need it back. Job
control and session tools fix both.

## Mental model: the counter and the back room

- The **foreground** is the counter: one job at a time, and the shell waits for
  it.
- The **background** is the back room: jobs keep working while you take new
  orders.
- When the shop closes (the terminal disconnects), the kernel sends **SIGHUP**
  ("hang up") to the session, and most jobs die. `nohup` and `tmux` keep them
  alive.

```
 sleep 300      foreground, shell waits
   Ctrl+Z  ->   stopped (state T)
   bg      ->   running in background
   fg      ->   back to foreground
 sleep 300 &    start directly in background
```

## See it work

```bash
sleep 300
# press Ctrl+Z
```

```
^Z
[1]+  Stopped                 sleep 300
```

```bash
bg          # resume job 1 in the background
jobs        # list this shell's jobs
fg %1       # bring job 1 back to the foreground (Ctrl+C to stop it)
```

```
[1]+ sleep 300 &
[1]+  Running                 sleep 300 &
sleep 300
```

`%1` means "job 1" in this shell; it is not a PID. `jobs -l` shows PIDs too.

### Surviving logout

```bash
nohup ./backup.sh > backup.out 2>&1 &
```

What this does: `nohup` makes the process ignore SIGHUP, `&` backgrounds it, and
the redirection keeps its output (without it, output goes to `nohup.out`). The
job keeps running after you log out. `disown` does the same for a job you
already started.

### tmux: a session that waits for you

For anything interactive or long on a remote server, use **tmux** (or the older
`screen`):

```bash
tmux new -s dump        # start a named session
# ... run the long command ...
# press Ctrl+B then D to detach; log out if you like
tmux ls                 # later: list sessions
tmux attach -t dump     # reattach, everything still on screen
```

tmux runs on the server, so a dropped SSH connection only detaches you.

### When the job is a service

If something must run all the time and restart after crashes or reboots, it is
not a job at all: make it a **systemd service** (chapter 6). `nohup` is for
one-off tasks.

## Try it

Start `sleep 3001` so that it keeps running even if your terminal is closed, and
confirm it is running.

<details>
<summary>Show answer</summary>

```bash
nohup sleep 3001 >/dev/null 2>&1 &
pgrep -a sleep
```

</details>

## Common mistakes

- **Closing the terminal on a plain `&` job.** It receives SIGHUP and usually
  dies. Use `nohup`, `disown` or tmux.
- **Running a long job interactively over SSH.** Always start tmux first.
- **Using `nohup` for a real service.** No restarts, no logs, gone after reboot.
  Write a unit file.
- **Confusing `%1` and PID 1.** `kill %1` stops your job 1; `kill 1` targets the
  init process (and fails as a normal user).

## Remember

- `&` background, `Ctrl+Z` stop, `bg` resume, `fg` foreground, `jobs` list.
- `nohup CMD > log 2>&1 &` survives logout.
- tmux: `new -s`, `Ctrl+B D` detach, `attach -t`.
- Long-running services belong in systemd.

**Self-check:**

1. Which signal does a process get when its terminal closes?
2. What does `Ctrl+Z` do?
3. How do you reattach to a tmux session named dump?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('66620df3-e85f-56db-87a0-e864f424d086', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ec8f752c-74df-5e68-b66e-b63f6f3212a5', 'Signals: kill, SIGTERM vs SIGKILL, and Zombies', 'notes', 3, $md$## Why this matters

A worker is stuck and orders pile up. Killing it the wrong way can corrupt data
or leave lock files that stop it from starting again. Stopping it the right way
takes three seconds longer and saves an hour.

## Mental model: a tap on the shoulder vs pulling the plug

A **signal** is a tiny numbered message sent to a process by the kernel or by
another process. The process can **catch** most signals and react (save work,
reload config, exit cleanly). Two signals cannot be caught.

| Signal | No. | Meaning | Can be caught? |
|---|---|---|---|
| SIGHUP | 1 | terminal closed / "reload your config" | yes |
| SIGINT | 2 | Ctrl+C | yes |
| SIGKILL | 9 | die now, no cleanup | **no** |
| SIGTERM | 15 | please exit cleanly (default of `kill`) | yes |
| SIGSTOP | 19 | pause | **no** |
| SIGTSTP | 20 | Ctrl+Z, pause politely | yes |
| SIGCONT | 18 | resume | yes |

> **Memory hook:** **15 asks, 9 insists.** "Fifteen is a friend, nine is the
> end."

## See it work

```bash
sleep 3002 &
kill %1          # or: kill PID. Sends SIGTERM (15)
jobs
```

```
[1]+  Terminated              sleep 3002
```

The safe sequence for a stuck process:

```bash
pgrep -a brewbot-worker          # 1. find the PID
kill 4242                        # 2. SIGTERM: ask
sleep 5; pgrep -a brewbot-worker # 3. still there?
kill -9 4242                     # 4. only then SIGKILL
```

SIGKILL gives the program no chance to flush buffers, finish a write, or delete
its lock/PID file. Use it last.

### Other ways to send signals

```bash
kill -HUP 901          # many daemons (nginx, sshd) reload config on SIGHUP
kill -l                # list all signal names and numbers
pkill -f brewbot       # by command line pattern
pkill -u sam           # every process of user sam
killall nginx          # every process with that exact name
```

`pkill -f` matches against the full command line, so test the pattern with
`pgrep -af PATTERN` first.

### Exit codes from signals

When a process dies from a signal, the shell reports exit status **128 + signal
number**:

```bash
sleep 100 & kill -9 $!; wait $!; echo $?
```

```
137
```

137 = 128 + 9 (killed, often by the OOM killer); 143 = 128 + 15 (terminated);
130 = 128 + 2 (Ctrl+C). You will see 137 in container and Kubernetes logs.

### Zombies

A **zombie** (`Z`, shown as `<defunct>`) is a process that has exited but whose
parent has not yet collected its exit status. It uses no CPU or memory, only a
PID slot.

You cannot kill a zombie; it is already dead. Fix or restart the **parent**,
and when the parent exits, PID 1 adopts and reaps the zombies.

## Try it

Stop the process `sleep 3002` with the polite termination signal, and say which
number you sent. Then: a process shows state `Z`. What do you do?

<details>
<summary>Show answer</summary>

```bash
pkill -TERM -f '^sleep 3002$'      # or kill PID; signal 15
```

For a zombie, find its parent (`ps -o ppid= -p ZPID`) and restart or fix the
parent. Killing the zombie itself does nothing.

</details>

## Common mistakes

- **`kill -9` first.** Data loss, stale locks, half-written files. Always 15
  first.
- **Broad `pkill -f` patterns.** `pkill -f python` kills every Python program,
  including other people's. Check with `pgrep -af` first.
- **Trying to kill zombies.** Deal with the parent.
- **Thinking `kill` only kills.** It sends any signal; `kill -HUP` reloads, `kill
  -STOP` pauses.

## Remember

- 15 SIGTERM asks (default), 9 SIGKILL forces, 1 SIGHUP often reloads, 2 = Ctrl+C.
- Order: find, TERM, wait, check, then KILL.
- Exit status 128+N means killed by signal N (137 = SIGKILL).
- Zombies are dead already; fix the parent.

**Self-check:**

1. Which two signals cannot be caught?
2. A container exits with code 143. What happened?
3. Why can SIGKILL leave a service unable to restart?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('61f378d0-ef8b-5471-a452-36ed028f26fa', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ec8f752c-74df-5e68-b66e-b63f6f3212a5', 'Priorities: nice, renice, ionice and taskset', 'notes', 4, $md$## Why this matters

The nightly backup started late and now runs during the morning rush, slowing
the web shop. You do not want to kill it; you want it to step aside. Priorities
let a busy server decide who goes first.

## Mental model: politeness in the queue

The CPU scheduler gives time to runnable processes. **Niceness** is how polite a
process is about waiting:

```
  -20 ......... 0 ......... 19
  greedy     default     polite
```

- Higher niceness = lower priority = waits longer.
- Anyone can make their own processes **nicer** (raise the number).
- Only root can make a process **greedier** (lower the number, below 0).

> **Memory hook:** the **nicer** you are, the **longer** you wait in the queue.
> Root is the only one allowed to cut in line.

Niceness only matters when the CPU is busy. On an idle machine, a nice 19
process runs at full speed.

## See it work

```bash
nohup nice -n 15 sleep 3002 >/dev/null 2>&1 &   # start with niceness 15
nohup sleep 3001 >/dev/null 2>&1 &              # start normally (0)
renice -n 5 -p $(pgrep -f '^sleep 3001$')       # change a running process
ps -o pid,ni,cmd -C sleep
```

What this does: starts one polite job, then makes another one nicer while it
runs. Expected output:

```
3001 (process ID) old priority 0, new priority 5
  PID  NI CMD
  412   5 sleep 3001
  418  15 sleep 3002
```

```bash
sudo renice -n -5 -p 1234      # only root may raise priority
```

### Disk priority: ionice

A backup is usually limited by **disk**, not CPU. `ionice` sets the IO
scheduling class:

```bash
ionice -c3 -p 1234             # idle class: only use the disk when nobody else does
ionice -c2 -n7 tar -czf ...    # best-effort, lowest level
ionice -p 1234                 # show current class
```

### Pinning to CPUs: taskset

```bash
taskset -c 0 ./bench           # run only on CPU 0
taskset -cp 1234               # show which CPUs a process may use
```

Pinning is a specialist tool (benchmarks, latency-sensitive apps). For limiting
a service's share of CPU, systemd's `CPUQuota=` (chapter 10, cgroups) is the
modern answer.

## Try it

Start `sleep 3002` in the background with niceness 15, then try to lower it to
-5 as a normal user. What happens?

<details>
<summary>Show answer</summary>

```bash
nohup nice -n 15 sleep 3002 >/dev/null 2>&1 &
renice -n -5 -p $(pgrep -f '^sleep 3002$')
```

```
renice: failed to set priority for 418 (process ID): Permission denied
```

Normal users can only increase niceness. Lowering it needs root.

</details>

## Common mistakes

- **Expecting `nice` to speed things up.** Without root you can only slow your
  process down relative to others.
- **Renicing an IO-bound job.** If the problem is disk, use `ionice`.
- **Forgetting children.** `renice` on a parent does not change already running
  children; use `renice -g PGID` or set it at start.

## Remember

- Niceness -20 (greedy) to 19 (polite); default 0.
- `nice -n N CMD` at start, `renice -n N -p PID` while running.
- Users can only raise niceness; root can lower it.
- `ionice -c3` for disk-heavy background jobs; `taskset` pins CPUs.

**Self-check:**

1. Which niceness value has the lowest priority?
2. Why might a nice 19 process still use 100% CPU?
3. Which tool lowers a backup's disk priority?
$md$, 6, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('231dac95-528c-5b9c-a5b1-e9236c5325f8', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ec8f752c-74df-5e68-b66e-b63f6f3212a5', 'Lab: Run the Engine Room', 'notes', 5, $md$## Why this matters

A forgotten backup job is hogging atlas and an old worker refuses to leave.
In this lab you find PID 1, start jobs that survive logout, change priorities and
stop a process politely. Each task is checked automatically.

## Before you start

```bash
ps aux
echo $$
```

What this does: lists every process and prints your shell's PID, so you know
which line is you.

## Task 1: who is process number one?

Using `/proc`, save the name of the process with PID 1 into
`~/work/answers/pid1.txt`.

[[lab-task:1]]

## Task 2: a worker that survives logout

Start `sleep 3001` in the background so it keeps running even if your terminal
is closed.

[[lab-task:2]]

## Task 3: run a low-priority job

Start `sleep 3002` in the background with a niceness of 15.

[[lab-task:3]]

## Task 4: change priority on the fly

Without restarting it, change the niceness of the running `sleep 3001` to 5.

[[lab-task:4]]

What you should see:

```
$ ps -o pid,ni,cmd -C sleep
  PID  NI CMD
  412   5 sleep 3001
  418  15 sleep 3002
```

## Task 5: stop a process politely

Stop `sleep 3002` with the polite termination signal (not the forceful one),
then save the number of the signal you sent into `answers/signal.txt`.

[[lab-task:5]]

## Remember

- `/proc/PID/comm` names a process; `pgrep -a` finds one.
- `nohup CMD &` survives logout; `nice -n` / `renice -n` set politeness.
- 15 asks, 9 insists.

> **End of day 5.** You found a forgotten backup job hogging the CPU, reniced
> it, and stopped an old worker politely. Rhea nods: "Good. Tonight you see who
> keeps atlas running while we sleep." Tom's note on the engine room door:
> "Services, logs, and the clock."
$md$, 20, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('f9596c0e-936d-5c50-9933-2993da793da8', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '231dac95-528c-5b9c-a5b1-e9236c5325f8', 'module', 'Lab: Run the Engine Room', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
rm -rf $w/answers
mkdir -p $w/answers
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7' AND id NOT IN ('6d1c21f6-4a8e-5578-987c-e62e31d3d789', 'd0f21ca6-61d6-55d5-9aa3-73977a90a7ad', 'cd501072-5eb2-525f-bdb8-edac90807b7b', '2c7bfa68-d9a4-59ff-a25c-e5a1c0ad63f3', '24b0a1f5-ea00-5816-b072-d591fd8b0441');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7';
DELETE FROM lab_tasks WHERE lab_id = 'f9596c0e-936d-5c50-9933-2993da793da8' AND id NOT IN ('4ec4bba8-6a8e-5dd7-93d9-d1e24855604c', 'd8b404c0-e4a0-5274-8856-f823bca13c8b', 'b51d2b45-4984-5a55-9f5a-1a53f0be9fb5', '7166209d-f6c1-5851-9731-67d8a0bb86e0', '4b7ee0eb-abba-5095-b910-71177f8280ac');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'f9596c0e-936d-5c50-9933-2993da793da8';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4ec4bba8-6a8e-5dd7-93d9-d1e24855604c', 'f9596c0e-936d-5c50-9933-2993da793da8', 1, 'Who is process number one?', $md$Look in /proc and save the name of the process with PID 1 into answers/pid1.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/pid1.txt)" = "$(cat /proc/1/comm)" ]
$script$, 'Every process has a directory /proc/PID. The file comm inside it holds the process name. ps -p 1 -o comm= works too.', 'PID 1 is the first process the kernel starts. On a full server it is systemd; inside a container it is whatever the image''s entrypoint is.', 15, false, true),
('d8b404c0-e4a0-5274-8856-f823bca13c8b', 'f9596c0e-936d-5c50-9933-2993da793da8', 2, 'A worker that survives logout', $md$Start the command sleep 3001 in the background so it keeps running even if your terminal is closed.$md$, $script$pgrep -u labuser -f '^sleep 3001$' >/dev/null
$script$, 'An ampersand at the end runs a command in the background. Prefix it with nohup so it ignores the hangup signal sent when the terminal closes.', 'When a terminal closes, its processes receive SIGHUP and usually die. nohup makes the process ignore SIGHUP and sends its output to nohup.out.', 20, false, true),
('b51d2b45-4984-5a55-9f5a-1a53f0be9fb5', 'f9596c0e-936d-5c50-9933-2993da793da8', 3, 'Run a low-priority job', $md$Start sleep 3002 in the background with a niceness of 15, so it only gets CPU time nobody else wants.$md$, $script$p=$(pgrep -u labuser -f '^sleep 3002$' | head -1)
[ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 15 ]
$script$, 'nice -n 15 COMMAND starts a command with niceness 15. Add an ampersand to background it.', 'Niceness runs from -20 (greedy) to 19 (polite). Higher niceness means lower priority. Normal users can only make processes nicer, never greedier.', 20, false, true),
('7166209d-f6c1-5851-9731-67d8a0bb86e0', 'f9596c0e-936d-5c50-9933-2993da793da8', 4, 'Change priority on the fly', $md$Without restarting it, change the niceness of the running sleep 3001 process to 5.$md$, $script$p=$(pgrep -u labuser -f '^sleep 3001$' | head -1)
[ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 5 ]
$script$, 'Find the PID with pgrep -f ''sleep 3001'' or ps aux | grep sleep, then renice -n 5 -p PID.', 'renice changes the priority of a process that is already running - handy when a backup job starts slowing down the web server.', 20, false, true),
('4b7ee0eb-abba-5095-b910-71177f8280ac', 'f9596c0e-936d-5c50-9933-2993da793da8', 5, 'Stop a process politely', $md$Stop the sleep 3002 process with the polite termination signal (not the forceful one), then save the number of the signal you sent into answers/signal.txt.$md$, $script$! pgrep -u labuser -f '^sleep 3002$' >/dev/null &&
[ "$(tr -d '[:space:]' < /home/labuser/work/answers/signal.txt)" = 15 ]
$script$, 'kill PID sends SIGTERM by default. kill -l lists every signal with its number.', 'SIGTERM (15) asks a process to clean up and exit. SIGKILL (9) cannot be caught - the kernel removes the process immediately, with no chance to save data. Always try 15 first.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', 'f9596c0e-936d-5c50-9933-2993da793da8', 1, $json$[{"id":"4ec4bba8-6a8e-5dd7-93d9-d1e24855604c","lab_id":"f9596c0e-936d-5c50-9933-2993da793da8","position":1,"title":"Who is process number one?","description":"Look in /proc and save the name of the process with PID 1 into answers/pid1.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/pid1.txt)\" = \"$(cat /proc/1/comm)\" ]\n","hint_context":"Every process has a directory /proc/PID. The file comm inside it holds the process name. ps -p 1 -o comm= works too.","explanation_context":"PID 1 is the first process the kernel starts. On a full server it is systemd; inside a container it is whatever the image's entrypoint is.","points":15,"is_optional":false,"is_stateful":true},{"id":"d8b404c0-e4a0-5274-8856-f823bca13c8b","lab_id":"f9596c0e-936d-5c50-9933-2993da793da8","position":2,"title":"A worker that survives logout","description":"Start the command sleep 3001 in the background so it keeps running even if your terminal is closed.","verification_script":"pgrep -u labuser -f '^sleep 3001$' \u003e/dev/null\n","hint_context":"An ampersand at the end runs a command in the background. Prefix it with nohup so it ignores the hangup signal sent when the terminal closes.","explanation_context":"When a terminal closes, its processes receive SIGHUP and usually die. nohup makes the process ignore SIGHUP and sends its output to nohup.out.","points":20,"is_optional":false,"is_stateful":true},{"id":"b51d2b45-4984-5a55-9f5a-1a53f0be9fb5","lab_id":"f9596c0e-936d-5c50-9933-2993da793da8","position":3,"title":"Run a low-priority job","description":"Start sleep 3002 in the background with a niceness of 15, so it only gets CPU time nobody else wants.","verification_script":"p=$(pgrep -u labuser -f '^sleep 3002$' | head -1)\n[ -n \"$p\" ] \u0026\u0026 [ \"$(ps -o ni= -p $p | tr -d ' ')\" = 15 ]\n","hint_context":"nice -n 15 COMMAND starts a command with niceness 15. Add an ampersand to background it.","explanation_context":"Niceness runs from -20 (greedy) to 19 (polite). Higher niceness means lower priority. Normal users can only make processes nicer, never greedier.","points":20,"is_optional":false,"is_stateful":true},{"id":"7166209d-f6c1-5851-9731-67d8a0bb86e0","lab_id":"f9596c0e-936d-5c50-9933-2993da793da8","position":4,"title":"Change priority on the fly","description":"Without restarting it, change the niceness of the running sleep 3001 process to 5.","verification_script":"p=$(pgrep -u labuser -f '^sleep 3001$' | head -1)\n[ -n \"$p\" ] \u0026\u0026 [ \"$(ps -o ni= -p $p | tr -d ' ')\" = 5 ]\n","hint_context":"Find the PID with pgrep -f 'sleep 3001' or ps aux | grep sleep, then renice -n 5 -p PID.","explanation_context":"renice changes the priority of a process that is already running - handy when a backup job starts slowing down the web server.","points":20,"is_optional":false,"is_stateful":true},{"id":"4b7ee0eb-abba-5095-b910-71177f8280ac","lab_id":"f9596c0e-936d-5c50-9933-2993da793da8","position":5,"title":"Stop a process politely","description":"Stop the sleep 3002 process with the polite termination signal (not the forceful one), then save the number of the signal you sent into answers/signal.txt.","verification_script":"! pgrep -u labuser -f '^sleep 3002$' \u003e/dev/null \u0026\u0026\n[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/signal.txt)\" = 15 ]\n","hint_context":"kill PID sends SIGTERM by default. kill -l lists every signal with its number.","explanation_context":"SIGTERM (15) asks a process to clean up and exit. SIGKILL (9) cannot be caught - the kernel removes the process immediately, with no chance to save data. Always try 15 first.","points":25,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('6d1c21f6-4a8e-5578-987c-e62e31d3d789', '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', '4ec4bba8-6a8e-5dd7-93d9-d1e24855604c', 1, 'Who is process number one?', $md$Look in /proc and save the name of the process with PID 1 into answers/pid1.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/pid1.txt)" = "$(cat /proc/1/comm)" ]
$script$, 'Every process has a directory /proc/PID. The file comm inside it holds the process name. ps -p 1 -o comm= works too.', 'PID 1 is the first process the kernel starts. On a full server it is systemd; inside a container it is whatever the image''s entrypoint is.', 15, false, true),
('d0f21ca6-61d6-55d5-9aa3-73977a90a7ad', '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', 'd8b404c0-e4a0-5274-8856-f823bca13c8b', 2, 'A worker that survives logout', $md$Start the command sleep 3001 in the background so it keeps running even if your terminal is closed.$md$, $script$pgrep -u labuser -f '^sleep 3001$' >/dev/null
$script$, 'An ampersand at the end runs a command in the background. Prefix it with nohup so it ignores the hangup signal sent when the terminal closes.', 'When a terminal closes, its processes receive SIGHUP and usually die. nohup makes the process ignore SIGHUP and sends its output to nohup.out.', 20, false, true),
('cd501072-5eb2-525f-bdb8-edac90807b7b', '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', 'b51d2b45-4984-5a55-9f5a-1a53f0be9fb5', 3, 'Run a low-priority job', $md$Start sleep 3002 in the background with a niceness of 15, so it only gets CPU time nobody else wants.$md$, $script$p=$(pgrep -u labuser -f '^sleep 3002$' | head -1)
[ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 15 ]
$script$, 'nice -n 15 COMMAND starts a command with niceness 15. Add an ampersand to background it.', 'Niceness runs from -20 (greedy) to 19 (polite). Higher niceness means lower priority. Normal users can only make processes nicer, never greedier.', 20, false, true),
('2c7bfa68-d9a4-59ff-a25c-e5a1c0ad63f3', '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', '7166209d-f6c1-5851-9731-67d8a0bb86e0', 4, 'Change priority on the fly', $md$Without restarting it, change the niceness of the running sleep 3001 process to 5.$md$, $script$p=$(pgrep -u labuser -f '^sleep 3001$' | head -1)
[ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 5 ]
$script$, 'Find the PID with pgrep -f ''sleep 3001'' or ps aux | grep sleep, then renice -n 5 -p PID.', 'renice changes the priority of a process that is already running - handy when a backup job starts slowing down the web server.', 20, false, true),
('24b0a1f5-ea00-5816-b072-d591fd8b0441', '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', '4b7ee0eb-abba-5095-b910-71177f8280ac', 5, 'Stop a process politely', $md$Stop the sleep 3002 process with the polite termination signal (not the forceful one), then save the number of the signal you sent into answers/signal.txt.$md$, $script$! pgrep -u labuser -f '^sleep 3002$' >/dev/null &&
[ "$(tr -d '[:space:]' < /home/labuser/work/answers/signal.txt)" = 15 ]
$script$, 'kill PID sends SIGTERM by default. kill -l lists every signal with its number.', 'SIGTERM (15) asks a process to clean up and exit. SIGKILL (9) cannot be caught - the kernel removes the process immediately, with no chance to save data. Always try 15 first.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', updated_at = now()
WHERE id = 'f9596c0e-936d-5c50-9933-2993da793da8' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cdd76c72-6ffa-5a60-881e-115137ce4afe', '00000000-0000-0000-0000-000000000001', 'mcq', 'You delete /usr/local/bin/brewbot-worker while it is running. What happens to...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2535f702-a419-5452-a3e8-553b52b7d73f', 'cdd76c72-6ffa-5a60-881e-115137ce4afe', 1, $json${"prompt":"You delete /usr/local/bin/brewbot-worker while it is running. What happens to the running worker?","multiple":false,"options":[{"id":"a","text":"It stops immediately","is_correct":false},{"id":"b","text":"It keeps running; the process already has the program loaded, only the name is gone","is_correct":true},{"id":"c","text":"It restarts","is_correct":false},{"id":"d","text":"It becomes a zombie","is_correct":false}],"explanation":"A process is a running instance; deleting the file removes a name, not the process. Nothing restarts it, and zombies are exited processes waiting for their parent."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('9858abd2-98c0-533b-8f99-a6dc4e0f276a', '00000000-0000-0000-0000-000000000001', 'mcq', 'A worker is stuck. What is the correct sequence?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ef79b199-d096-54d8-bf40-b5e833ce025a', '9858abd2-98c0-533b-8f99-a6dc4e0f276a', 1, $json${"prompt":"A worker is stuck. What is the correct sequence?","multiple":false,"options":[{"id":"a","text":"kill -9 PID immediately","is_correct":false},{"id":"b","text":"kill PID (SIGTERM), wait a few seconds, check, then kill -9 PID only if it is still there","is_correct":true},{"id":"c","text":"kill -HUP PID and wait an hour","is_correct":false},{"id":"d","text":"Reboot the server","is_correct":false}],"explanation":"SIGTERM lets the program clean up. SIGKILL is the last resort because it can leave half-written files and stale locks. SIGHUP usually means reload, and a reboot punishes every other service."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a6376212-9a6c-5df0-bfe4-9e348af18613', '00000000-0000-0000-0000-000000000001', 'mcq', 'A container exits with status 137. What does that tell you?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b43a885e-4b1f-5049-84c3-678736898439', 'a6376212-9a6c-5df0-bfe4-9e348af18613', 1, $json${"prompt":"A container exits with status 137. What does that tell you?","multiple":false,"options":[{"id":"a","text":"It exited normally","is_correct":false},{"id":"b","text":"It was killed by signal 9 (SIGKILL), often from the OOM killer","is_correct":true},{"id":"c","text":"Command not found","is_correct":false},{"id":"d","text":"It received Ctrl+C","is_correct":false}],"explanation":"128 + 9 = 137. Normal exit is 0, command not found is 127, and Ctrl+C (SIGINT 2) gives 130."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f31b6801-cc81-5e7f-9a09-f00d4dd140db', '00000000-0000-0000-0000-000000000001', 'mcq', 'ps shows several <defunct> processes in state Z under the same parent. What d...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('3cd0b713-89a7-5204-a203-b0627d5d593d', 'f31b6801-cc81-5e7f-9a09-f00d4dd140db', 1, $json${"prompt":"ps shows several \u003cdefunct\u003e processes in state Z under the same parent. What do you do?","multiple":false,"options":[{"id":"a","text":"kill -9 each zombie","is_correct":false},{"id":"b","text":"Fix or restart the parent, which is failing to collect its children's exit status","is_correct":true},{"id":"c","text":"Reboot immediately; zombies eat memory","is_correct":false},{"id":"d","text":"Nothing can ever remove them","is_correct":false}],"explanation":"Zombies are already dead, so signals do nothing. They hold only a PID slot, not memory. When the parent reaps them, or exits so PID 1 adopts and reaps them, they vanish."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('dc19738a-1303-58cf-8c77-22984c8ffdca', '00000000-0000-0000-0000-000000000001', 'mcq', 'You must start a 2-hour database dump over SSH from a café with flaky Wi-Fi....', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7f9352ac-0680-51ed-b0ea-066bd73070fc', 'dc19738a-1303-58cf-8c77-22984c8ffdca', 1, $json${"prompt":"You must start a 2-hour database dump over SSH from a café with flaky Wi-Fi. What is the best approach?","multiple":false,"options":[{"id":"a","text":"Run it normally and keep the laptop open","is_correct":false},{"id":"b","text":"Start a tmux session on the server and run the dump inside it","is_correct":true},{"id":"c","text":"Run it with kill -STOP","is_correct":false},{"id":"d","text":"Add \u0026 at the end and close the laptop","is_correct":false}],"explanation":"tmux runs on the server, so a dropped connection only detaches you. A plain foreground or \u0026 job gets SIGHUP when the session dies, and SIGSTOP just pauses it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d107a2f3-3b25-5f83-adcf-b18646095ff3', '00000000-0000-0000-0000-000000000001', 'mcq', 'As a normal user you run renice -n -5 -p 1234 on your own process and get Per...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('3664aa76-d0a4-52ba-8f52-72c1f5b25812', 'd107a2f3-3b25-5f83-adcf-b18646095ff3', 1, $json${"prompt":"As a normal user you run renice -n -5 -p 1234 on your own process and get Permission denied. Why?","multiple":false,"options":[{"id":"a","text":"Only root may lower niceness (raise priority)","is_correct":true},{"id":"b","text":"The PID is wrong","is_correct":false},{"id":"c","text":"renice only works on root's processes","is_correct":false},{"id":"d","text":"Niceness must be between 0 and 10","is_correct":false}],"explanation":"Users may only make their processes nicer. A wrong PID gives 'No such process', renice works on your own processes, and the range is -20 to 19."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2a2b6e7b-accc-5710-b1b3-29771dcaa12d', '00000000-0000-0000-0000-000000000001', 'mcq', 'Where can you see the exact command line of process 4242, even without ps ins...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('41d67fe1-2272-5930-9a02-8bfcee888024', '2a2b6e7b-accc-5710-b1b3-29771dcaa12d', 1, $json${"prompt":"Where can you see the exact command line of process 4242, even without ps installed?","multiple":false,"options":[{"id":"a","text":"/proc/4242/cmdline","is_correct":true},{"id":"b","text":"/var/log/4242","is_correct":false},{"id":"c","text":"/etc/proc/4242","is_correct":false},{"id":"d","text":"/dev/4242","is_correct":false}],"explanation":"The kernel exposes each process under /proc/PID; cmdline holds the arguments separated by NUL bytes. The other paths do not exist."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('caf5a330-93eb-5954-a4e8-95cd57514ebc', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 4): brewbot runs as user brewbot and cannot read /etc/brewbot...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('77edf301-5755-57a0-87a5-cfea87b1ea19', 'caf5a330-93eb-5954-a4e8-95cd57514ebc', 1, $json${"prompt":"Review (chapter 4): brewbot runs as user brewbot and cannot read /etc/brewbot/brewbot.conf (-rw------- root root). What is the safest fix?","multiple":false,"options":[{"id":"a","text":"chmod 644 /etc/brewbot/brewbot.conf","is_correct":false},{"id":"b","text":"chgrp brewbot /etc/brewbot/brewbot.conf and chmod 640","is_correct":true},{"id":"c","text":"Run brewbot as root","is_correct":false},{"id":"d","text":"chmod 777 /etc/brewbot","is_correct":false}],"explanation":"Group read for the service only. 644 exposes the config to every user, running as root removes all protection, and 777 lets anyone replace files."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('c2dafbb0-b2aa-5a09-b9fb-90a9cc9ed587', '00000000-0000-0000-0000-000000000001', 'Quiz: Processes and Signals', 'linux-engine-room-quiz', 'Quiz covering Chapter 5: The Engine Room - Processes.', 'mcq', 'published', 'module', 'adf26bb9-07fe-518a-9fe6-a06e247aa5f1', 10, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'c2dafbb0-b2aa-5a09-b9fb-90a9cc9ed587' AND question_id NOT IN ('cdd76c72-6ffa-5a60-881e-115137ce4afe', '9858abd2-98c0-533b-8f99-a6dc4e0f276a', 'a6376212-9a6c-5df0-bfe4-9e348af18613', 'f31b6801-cc81-5e7f-9a09-f00d4dd140db', 'dc19738a-1303-58cf-8c77-22984c8ffdca', 'd107a2f3-3b25-5f83-adcf-b18646095ff3', '2a2b6e7b-accc-5710-b1b3-29771dcaa12d', 'caf5a330-93eb-5954-a4e8-95cd57514ebc');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('c1809a52-7cbe-5001-98a8-3c82e32558a6', 'c2dafbb0-b2aa-5a09-b9fb-90a9cc9ed587', 'cdd76c72-6ffa-5a60-881e-115137ce4afe', '2535f702-a419-5452-a3e8-553b52b7d73f', 0, 2),
('3f717154-69fe-580c-83c6-8007956a5f19', 'c2dafbb0-b2aa-5a09-b9fb-90a9cc9ed587', '9858abd2-98c0-533b-8f99-a6dc4e0f276a', 'ef79b199-d096-54d8-bf40-b5e833ce025a', 1, 2),
('4649ddbe-4cdc-5cc6-a44b-4613d8747146', 'c2dafbb0-b2aa-5a09-b9fb-90a9cc9ed587', 'a6376212-9a6c-5df0-bfe4-9e348af18613', 'b43a885e-4b1f-5049-84c3-678736898439', 2, 2),
('bf2b34c9-d099-535c-ad80-1770c39b6199', 'c2dafbb0-b2aa-5a09-b9fb-90a9cc9ed587', 'f31b6801-cc81-5e7f-9a09-f00d4dd140db', '3cd0b713-89a7-5204-a203-b0627d5d593d', 3, 2),
('255d158b-3d96-5b30-b0e3-61272d2bf479', 'c2dafbb0-b2aa-5a09-b9fb-90a9cc9ed587', 'dc19738a-1303-58cf-8c77-22984c8ffdca', '7f9352ac-0680-51ed-b0ea-066bd73070fc', 4, 2),
('138939a7-3f4f-5f14-9f41-3d5bef53d3f4', 'c2dafbb0-b2aa-5a09-b9fb-90a9cc9ed587', 'd107a2f3-3b25-5f83-adcf-b18646095ff3', '3664aa76-d0a4-52ba-8f52-72c1f5b25812', 5, 2),
('e70242bf-602b-5df2-ab9f-e823f7001a54', 'c2dafbb0-b2aa-5a09-b9fb-90a9cc9ed587', '2a2b6e7b-accc-5710-b1b3-29771dcaa12d', '41d67fe1-2272-5930-9a02-8bfcee888024', 6, 2),
('cb007d3e-587c-531d-8c70-c64aa998e523', 'c2dafbb0-b2aa-5a09-b9fb-90a9cc9ed587', 'caf5a330-93eb-5954-a4e8-95cd57514ebc', '77edf301-5755-57a0-87a5-cfea87b1ea19', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('adf26bb9-07fe-518a-9fe6-a06e247aa5f1', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ec8f752c-74df-5e68-b66e-b63f6f3212a5', 'Quiz: Processes and Signals', 'assessment', 6, 8, 'c2dafbb0-b2aa-5a09-b9fb-90a9cc9ed587')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 6: The Night Shift - systemd, Logs and Schedules
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('1d2e633e-0589-50da-b212-4e9f881d0b3c', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 6: The Night Shift - systemd, Logs and Schedules', 6, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('fbc23bf0-026c-5d0a-9905-ae647b0dee6b', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '1d2e633e-0589-50da-b212-4e9f881d0b3c', 'How Atlas Boots: Firmware, GRUB, Kernel, systemd', 'notes', 0, $md$## Why this matters

> **Friday night, on call for the first time.** Your phone buzzes at 2:07am:
> *brewbot is down, no orders are coming in.* Tom's note said "services, logs,
> and the clock".

When a server does not come back after a reboot, you need to know which stage
failed: firmware, bootloader, kernel or services. Each stage has its own tools
and its own error messages.

## Mental model: four runners in a relay

```
 power on
   |
 [1] BIOS / UEFI        firmware checks hardware, finds a boot disk
   |
 [2] GRUB (bootloader)  menu; loads the kernel + initramfs from /boot
   |
 [3] Kernel             detects hardware, uses the initramfs to find
   |                    and mount the real root filesystem
 [4] systemd (PID 1)    starts every service in dependency order
   |
 [5] target reached     multi-user.target (server) or graphical.target (desktop)
   |
 login prompt
```

> **Memory hook:** "**B**ig **G**reen **K**ettles **S**team": **B**IOS,
> **G**RUB, **K**ernel, **S**ystemd.

- The **initramfs** is a tiny temporary root filesystem in RAM. It holds the
  drivers needed to reach the real disk (RAID, LVM, encryption).
- A **target** is a named group of units that represents a system state.
  `multi-user.target` = networking and services, no desktop. Older systems
  called these **runlevels** (3 = multi-user, 5 = graphical).

## See it work

```bash
systemctl get-default          # which target we boot into
systemd-analyze                # how long boot took
systemd-analyze blame | head   # slowest units first
```

Expected output (similar):

```
multi-user.target
Startup finished in 3.1s (kernel) + 9.8s (userspace) = 12.9s
multi-user.target reached after 9.6s in userspace.
          5.104s cloud-init.service
          2.012s postgresql@16-main.service
```

### Kernel messages

```bash
sudo dmesg -T | tail             # kernel ring buffer, human timestamps
journalctl -k -b                 # same, from the journal, this boot
journalctl --list-boots          # every boot the journal remembers
journalctl -b -1 -p err          # errors from the PREVIOUS boot
```

`dmesg` is where disk errors, out-of-memory kills, driver problems and hardware
faults show up. `-b -1` (previous boot) is how you investigate a crash after
the machine has rebooted.

### Rescue paths

- Pick an older kernel in the **GRUB menu** if a new kernel fails.
- Boot a **rescue** target (`systemd.unit=rescue.target` on the kernel command
  line) for a root shell with minimal services.
- On cloud servers, use the provider's **serial console**: it shows the boot
  messages even when SSH is down.

`cat /proc/cmdline` shows the kernel command line the machine booted with.

## Try it

Atlas rebooted at 3am after a crash and is fine now. Which command shows the
errors logged just before the crash?

<details>
<summary>Show answer</summary>

```bash
journalctl -b -1 -p err
```

`-b -1` selects the previous boot, `-p err` keeps error priority and worse.
This needs a persistent journal (lesson 4).

</details>

## Common mistakes

- **Rebooting to "see if it helps" before reading logs.** Without a persistent
  journal, the evidence disappears with the reboot.
- **Confusing the kernel and the distro version.** A failed boot after an update
  is often a new kernel; the old one is still in the GRUB menu.
- **Ignoring `dmesg`.** Disk and memory problems are logged by the kernel, not by
  your application.

## Remember

- Firmware, GRUB, kernel (+ initramfs), systemd, target.
- `systemd-analyze blame` = slow boot; `systemctl get-default` = target.
- `dmesg -T` / `journalctl -k` = kernel messages; `journalctl -b -1` = last
  boot.
- Rescue: older kernel in GRUB, `rescue.target`, serial console.

**Self-check:**

1. What is the initramfs for?
2. Which target does a server normally boot into?
3. Where do you look for disk errors?
$md$, 6, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b47e2e9d-c0c7-5861-bd16-0e2b79970b05', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '1d2e633e-0589-50da-b212-4e9f881d0b3c', 'systemd and systemctl: Starting, Stopping, Enabling', 'notes', 1, $md$## Why this matters

Brewbot is down. The first two commands of nearly every Linux incident are
`systemctl status` and `journalctl -u`. You also need to know why a service that
"worked yesterday" did not come back after a reboot.

## Mental model: the night manager

**systemd** is PID 1 and the manager of **units**. A unit is anything systemd
looks after:

| Type | Example | What it is |
|---|---|---|
| `.service` | `nginx.service` | a program to keep running |
| `.timer` | `logrotate.timer` | a schedule (modern cron) |
| `.target` | `multi-user.target` | a group of units = a system state |
| `.socket` | `ssh.socket` | start a service when a connection arrives |
| `.mount`, `.path` | | mount a filesystem, react to file changes |

Two separate questions about every unit:

```
 is it running NOW?          start / stop / restart       (active / inactive / failed)
 will it start at BOOT?      enable / disable             (enabled / disabled)
```

> **Memory hook:** **start** is *today*, **enable** is *every day*. A service
> can be started but not enabled (gone after reboot) or enabled but not started
> (runs from the next boot).

## See it work

```bash
systemctl status nginx
```

Expected output (abridged):

```
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Wed 2026-10-14 09:00:03 UTC; 2h ago
   Main PID: 901 (nginx)
     Memory: 6.1M
     CGroup: /system.slice/nginx.service
             ├─901 "nginx: master process /usr/sbin/nginx"
             └─902 "nginx: worker process"

Oct 14 09:00:03 atlas systemd[1]: Started nginx.service - A high performance web server...
```

Read it top to bottom: where the unit file is and whether it is **enabled**;
whether it is **active** and since when; the main PID; the processes; and the
last log lines.

### The everyday commands

```bash
sudo systemctl start brewbot        # start now
sudo systemctl stop brewbot         # stop now
sudo systemctl restart brewbot      # stop + start
sudo systemctl reload nginx         # re-read config, keep connections (if supported)
sudo systemctl enable brewbot       # start at every boot
sudo systemctl enable --now brewbot # enable AND start
sudo systemctl disable brewbot      # do not start at boot
systemctl is-active brewbot         # active / inactive / failed (good in scripts)
systemctl is-enabled brewbot        # enabled / disabled
systemctl --failed                  # what is broken right now?
systemctl list-units --type=service # everything loaded
systemctl cat nginx                 # print the unit file(s) in use
sudo systemctl daemon-reload        # after editing any unit file
sudo systemctl mask brewbot         # make it impossible to start (even by hand)
```

`mask` links the unit to `/dev/null`; `unmask` undoes it. Use it to make sure
something never runs (an old service that conflicts with a new one).

### When systemd gives up

If a service crashes repeatedly, systemd stops restarting it:
`Start request repeated too quickly`. After fixing the cause, clear the counter:

```bash
sudo systemctl reset-failed brewbot
sudo systemctl start brewbot
```

## Try it

You installed brewbot, ran `sudo systemctl start brewbot`, and it works. After
Saturday's reboot it is not running. What did you forget, and which single
command would have done both steps?

<details>
<summary>Show answer</summary>

You never enabled it. `sudo systemctl enable --now brewbot` enables it for
every boot and starts it now.

</details>

## Common mistakes

- **Editing a unit file and forgetting `daemon-reload`.** systemd keeps using the
  old version and warns "unit file changed on disk".
- **`restart` when `reload` would do.** Restarting nginx drops connections;
  reload does not. Check `nginx -t` first either way.
- **Assuming "enabled" means "running".** Check both `is-enabled` and
  `is-active`.
- **Looking for the service with `ps` only.** `systemctl status` also shows why
  it stopped.

## Remember

- systemd (PID 1) manages units: services, timers, targets, sockets.
- `start/stop/restart/reload` = now; `enable/disable` = at boot; `--now` = both.
- `systemctl status`, `--failed`, `cat`, `is-active`.
- After editing units: `daemon-reload`. After crash loops: `reset-failed`.

**Self-check:**

1. What is the difference between `start` and `enable`?
2. Which command lists all failed units?
3. What does `mask` do?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8d5f801e-52c4-56f7-9636-ebfce847344a', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '1d2e633e-0589-50da-b212-4e9f881d0b3c', 'Writing a Unit File, and Overriding One Safely', 'notes', 2, $md$## Why this matters

Brewbot was started by Tom with `nohup` from his shell. It did not restart after
a crash, did not start after reboot, and its logs went nowhere. A ten-line unit
file fixes all three.

## Mental model: a recipe card for the night manager

A unit file is a small INI file with three sections:

```
 [Unit]     WHAT is it and WHEN does it start (order, dependencies)
 [Service]  HOW to run it (command, user, restart policy, environment)
 [Install]  WHERE it hooks in when you run `systemctl enable`
```

Where unit files live:

| Path | Who writes it |
|---|---|
| `/usr/lib/systemd/system/` (also `/lib/systemd/system/`) | packages; do not edit |
| `/etc/systemd/system/` | you; wins over the package version |
| `/etc/systemd/system/NAME.service.d/*.conf` | drop-in overrides |

## See it work

```ini
# /etc/systemd/system/brewbot.service
[Unit]
Description=Orbit Coffee order bot
# start after networking is up
After=network.target

[Service]
ExecStart=/opt/brewbot/bin/brewbot
# never run apps as root
User=brewbot
# come back if it crashes
Restart=on-failure
RestartSec=5
Environment=PORT=8080

[Install]
# "enable" hooks it into normal boot
WantedBy=multi-user.target
```

Line by line:

- `After=network.target`: start after networking. `After` only orders; add
  `Wants=` or `Requires=` to also pull another unit in.
- `ExecStart=`: the command, with a **full path**. systemd does not use your
  shell's PATH or `.bashrc`.
- `User=`: run as a dedicated, unprivileged user.
- `Restart=on-failure`: restart when it crashes (non-zero exit or signal), wait
  `RestartSec` seconds first.
- `WantedBy=multi-user.target`: `systemctl enable` creates a link so the normal
  boot target pulls brewbot in.

Comments must be on their own line: systemd would treat
`After=network.target # comment` as part of the value.

Activate it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now brewbot
systemctl status brewbot
```

### Overriding a package's unit: drop-ins

Never edit files under `/usr/lib/systemd/system/`; the next package update
overwrites them. Add a **drop-in** instead:

```bash
sudo systemctl edit nginx
```

This opens an editor for `/etc/systemd/system/nginx.service.d/override.conf`.
Only write what you change:

```ini
[Service]
LimitNOFILE=65536
Restart=always
```

`systemctl edit` runs `daemon-reload` for you. `systemctl cat nginx` shows the
original plus every drop-in. To **replace** a list setting such as `ExecStart`,
clear it first with an empty `ExecStart=` line, then set the new value.

### A few production settings worth knowing

```ini
[Service]
EnvironmentFile=/etc/brewbot/env     # KEY=value lines, keeps secrets out of the unit
WorkingDirectory=/opt/brewbot
UMask=0027
MemoryMax=512M                       # cgroup limit (chapter 10)
NoNewPrivileges=yes                  # chapter 12: basic sandboxing
ProtectSystem=strict
```

`systemd-analyze security brewbot` scores how locked down a service is.

## Try it

Write the `[Service]` section that runs `/opt/brewbot/bin/brewbot` as user
`brewbot` and restarts it only when it fails. Which section and line makes
`enable` work?

<details>
<summary>Show answer</summary>

```ini
[Service]
ExecStart=/opt/brewbot/bin/brewbot
User=brewbot
Restart=on-failure
```

`enable` needs `[Install]` with `WantedBy=multi-user.target`. Without an
`[Install]` section, `systemctl enable` refuses.

</details>

## Common mistakes

- **Relative paths or shell syntax in `ExecStart`.** No PATH, no pipes, no `&&`.
  Use a full path, or `ExecStart=/bin/bash -c '...'` if you truly need a shell.
- **Backgrounding the program.** `ExecStart=/opt/app &` or a program that
  daemonizes itself confuses systemd. Run it in the foreground (or set
  `Type=forking` for old-style daemons).
- **Editing the vendor unit in `/usr/lib`.** Lost on the next update. Use
  `systemctl edit`.
- **Forgetting `daemon-reload` after editing by hand.**

## Remember

- `[Unit]` what/when, `[Service]` how, `[Install]` where enable hooks in.
- Your units go in `/etc/systemd/system/`; overrides via `systemctl edit`.
- Key lines: `ExecStart` (full path), `User`, `Restart=on-failure`,
  `WantedBy=multi-user.target`.
- `systemctl cat` shows the effective unit.

**Self-check:**

1. Why must `ExecStart` use a full path?
2. Where does `systemctl edit nginx` write its file?
3. What does `After=` do, and what does it not do?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('390b5685-7889-5f90-87f7-36a775b9c571', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '1d2e633e-0589-50da-b212-4e9f881d0b3c', 'Logs: journalctl, journald and /var/log', 'notes', 3, $md$## Why this matters

`systemctl status brewbot` says `failed`. *Why* it failed is in the logs, almost
always in the last 20 lines. You need to filter the right service, the right
time and the right severity in seconds.

## Mental model: one diary, many authors

- **journald** (`systemd-journald`) collects the output of every service, the
  kernel and syslog messages into one structured, indexed **journal**.
- `journalctl` reads it, with filters.
- Many systems also run **rsyslog**, which writes classic text files in
  `/var/log`. Both exist side by side.

```
 brewbot stdout/stderr --\
 kernel messages ---------+--> journald --> journal (binary, indexed) --> journalctl
 syslog() calls ---------/                \--> rsyslog --> /var/log/syslog, auth.log ...
```

> **Memory hook:** when a service is down, run the **two S's**:
> `systemctl status` (what state?) then `journalctl -u` (what did it say?).

## See it work

```bash
journalctl -u brewbot -n 20 --no-pager
```

What this does: last 20 lines from one unit, printed directly. Expected output:

```
Oct 14 02:00:03 atlas systemd[1]: Starting brewbot.service - Orbit Coffee order bot...
Oct 14 02:00:03 atlas brewbot[1040]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:03 atlas systemd[1]: brewbot.service: Main process exited, code=exited, status=1/FAILURE
Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Start request repeated too quickly.
```

The line from brewbot itself holds the cause: Permission denied on its config.

### Filters you will use

```bash
journalctl -u brewbot -f                    # follow live
journalctl -u brewbot --since "1 hour ago"  # or --since "2026-10-14 02:00" --until "02:30"
journalctl -p err -b                        # priority err and worse, this boot
journalctl -b -1                            # the previous boot
journalctl -k                               # kernel only (like dmesg)
journalctl _PID=1040                        # one process
journalctl -u nginx -o json-pretty -n 1     # every structured field
journalctl --disk-usage                     # journal size
sudo journalctl --vacuum-size=500M          # shrink it
```

Priorities from worst to mildest: `emerg, alert, crit, err, warning, notice,
info, debug` (0-7). `-p warning` means warning and everything worse.

### Make the journal survive reboots

Some distros keep the journal only in RAM (`/run/log/journal`). To keep it on
disk, create the directory (or set `Storage=persistent`):

```bash
sudo mkdir -p /var/log/journal
sudo systemctl restart systemd-journald
```

Limit its size in `/etc/systemd/journald.conf` with `SystemMaxUse=1G`.

### Classic files in /var/log

| File | Contains |
|---|---|
| `/var/log/syslog` (Debian/Ubuntu) or `/var/log/messages` (RHEL) | general system log |
| `/var/log/auth.log` or `/var/log/secure` | logins, sudo, SSH |
| `/var/log/kern.log` | kernel |
| `/var/log/nginx/`, `/var/log/apache2/` | web servers (their own files) |
| `/var/log/dpkg.log`, `/var/log/apt/` | package installs |
| `/var/log/wtmp`, `btmp` | logins / failed logins (read with `last`, `lastb`) |

Apps that write their own files (nginx, databases) do not appear in the journal
unless configured to; check both places.

## Try it

Brewbot failed at about 2am. Write one command that shows only error-level
messages from brewbot between 01:55 and 02:30 today.

<details>
<summary>Show answer</summary>

```bash
journalctl -u brewbot -p err --since "01:55" --until "02:30"
```

</details>

## Common mistakes

- **Reading only systemd's lines.** "Failed with result exit-code" is the
  symptom; the app's own line just above it is the cause.
- **Volatile journal.** After a crash and reboot, `-b -1` is empty. Make it
  persistent.
- **Deleting journal files by hand.** Use `--vacuum-size` or `--vacuum-time`.
- **Forgetting app log files.** nginx and PostgreSQL usually log to
  `/var/log/<app>/`.

## Remember

- `systemctl status X` then `journalctl -u X -n 50`.
- Filters: `-u`, `-p`, `-b`, `--since/--until`, `-f`, `-k`.
- Priorities: emerg alert crit err warning notice info debug.
- `/var/log/journal` = persistent journal; classic files live in `/var/log`.

**Self-check:**

1. Which option shows the previous boot?
2. What does `-p err` include?
3. Where do SSH and sudo logins go on Ubuntu?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('bf821ab5-9fd6-5101-b33d-cce4cfecfac2', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '1d2e633e-0589-50da-b212-4e9f881d0b3c', 'Chores on a Schedule: cron and systemd Timers', 'notes', 4, $md$## Why this matters

Backups at 02:30, health checks every 15 minutes, a report on the 1st of the
month: atlas does chores while everyone sleeps. Get the schedule wrong and the
backup you rely on never ran.

## Mental model: five dials on a clock

A **crontab** line has five time fields, then the command:

```
 .---------------- minute       (0-59)
 |  .------------- hour         (0-23)
 |  |  .---------- day of month (1-31)
 |  |  |  .------- month        (1-12)
 |  |  |  |  .---- day of week  (0-7, 0 and 7 = Sunday)
 |  |  |  |  |
 30 2  *  *  *   /opt/brewbot/backup.sh       every day at 02:30
 */15 * * * 1-5  /opt/brewbot/health.sh       every 15 min, Mon-Fri
 0  9  1  *  *   /opt/report.sh               9am on the 1st of each month
 0  3  *  *  0   /opt/brewbot/weekly.sh       03:00 every Sunday
 @reboot         /opt/brewbot/warmup.sh       once at boot
```

`*` = every value, `*/15` = every 15th, `1-5` = range, `1,15` = list.

> **Memory hook:** "**M**y **H**amster **D**rinks **M**ilk **W**eekly":
> **M**inute, **H**our, **D**ay, **M**onth, **W**eekday.

## See it work

```bash
crontab -e      # edit YOUR crontab (opens an editor)
crontab -l      # list it
```

Example content:

```
PATH=/usr/local/bin:/usr/bin:/bin
30 2 * * * /opt/brewbot/backup.sh >> /var/log/brewbot/backup.log 2>&1
```

System-wide jobs live in `/etc/crontab` and `/etc/cron.d/` (these have an extra
**user** field after the time), plus drop-in folders `/etc/cron.daily/`,
`/etc/cron.weekly/`, `/etc/cron.monthly/` for plain scripts.

### The four cron traps

1. **Tiny environment.** Cron runs with a minimal PATH (`/usr/bin:/bin`) and no
   `.bashrc`. Use full paths or set `PATH=` at the top.
2. **Lost output.** Output is mailed (often to nowhere). Redirect it:
   `>> /var/log/job.log 2>&1`.
3. **`%` is special.** In a crontab, `%` means newline. Escape it:
   `date +\%F`.
4. **Did it run?** `grep CRON /var/log/syslog` or
   `journalctl -u cron --since today`.

`at 23:00` runs a one-off job later (`atq` lists, `atrm` removes).

### systemd timers: the modern alternative

A timer is a unit that starts a service on a schedule. Two files:

```ini
# /etc/systemd/system/brewbot-backup.service
[Unit]
Description=Brewbot nightly backup

[Service]
Type=oneshot
ExecStart=/opt/brewbot/backup.sh
```

```ini
# /etc/systemd/system/brewbot-backup.timer
[Unit]
Description=Run brewbot backup nightly

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now brewbot-backup.timer
systemctl list-timers              # next and last run of every timer
systemd-analyze calendar "Mon..Fri *:0/15"   # check a schedule expression
```

Why timers: output goes to the journal automatically (`journalctl -u
brewbot-backup`), `Persistent=true` catches up on runs missed while the machine
was off, and the job gets all unit settings (user, limits, sandboxing).

| | cron | systemd timer |
|---|---|---|
| Setup | one line | two small files |
| Logs | redirect yourself | journal, automatic |
| Missed runs (machine off) | skipped | `Persistent=true` catches up |
| Overlap protection | none (`flock` yourself) | a running service is not started twice |

## Try it

Write a crontab line that runs `/opt/brewbot/health.sh` every 15 minutes, Monday
to Friday only, and keeps its output in `/var/log/brewbot/health.log`.

<details>
<summary>Show answer</summary>

```
*/15 * * * 1-5 /opt/brewbot/health.sh >> /var/log/brewbot/health.log 2>&1
```

</details>

## Common mistakes

- **Commands that work in your shell but not in cron.** PATH and environment
  differ. Use full paths.
- **`0 3 * * *` vs `* 3 * * *`.** The second runs 60 times, every minute of hour
  3.
- **Both day-of-month and day-of-week set.** Cron runs when *either* matches,
  not both.
- **Overlapping runs.** A slow job started every 5 minutes piles up. Wrap it:
  `flock -n /tmp/job.lock /opt/job.sh`.

## Remember

- minute hour day-of-month month day-of-week, then the command.
- `crontab -e` / `-l`; system jobs in `/etc/cron.d/`.
- Full paths, redirect output, escape `%`, check `grep CRON`.
- Timers: `.service` + `.timer` with `OnCalendar=`, `systemctl list-timers`.

**Self-check:**

1. What does `0 3 * * 0` mean?
2. Why do scripts that work by hand fail in cron?
3. What does `Persistent=true` do in a timer?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('bed22685-6d92-557d-ad29-f2c0b7395b93', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '1d2e633e-0589-50da-b212-4e9f881d0b3c', 'Log Rotation: Stop Logs from Eating the Disk', 'notes', 5, $md$## Why this matters

"Disk full" is one of the most common outages there is, and the usual culprit is
a log that grew for months. Log rotation trims logs automatically. Ten lines of
config prevent a 3am page.

## Mental model: a shelf of dated notebooks

Every day logrotate takes the current notebook off the desk, labels it, puts it
on a shelf, and starts a fresh one. When the shelf is full, the oldest notebook
is thrown away.

```
 day 1:  app.log
 day 2:  app.log   app.log.1
 day 3:  app.log   app.log.1   app.log.2.gz
 ...
 day 9:  app.log   app.log.1   app.log.2.gz ... app.log.7.gz    (oldest deleted)
```

logrotate runs daily from a systemd timer (`logrotate.timer`) or from
`/etc/cron.daily/logrotate`.

## See it work

```
/var/log/brewbot/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 brewbot adm
    postrotate
        systemctl reload brewbot > /dev/null 2>&1 || true
    endscript
}
```

| Directive | Meaning |
|---|---|
| `daily` | rotate every day (or `weekly`, `monthly`, `size 100M`) |
| `rotate 7` | keep 7 old copies |
| `compress` | gzip old copies |
| `delaycompress` | leave the newest old copy uncompressed (apps may still write to it) |
| `missingok` | no error if the log does not exist |
| `notifempty` | do not rotate an empty log |
| `create MODE USER GROUP` | create the new empty log with these permissions |
| `postrotate ... endscript` | run a command after rotating (tell the app to reopen its log) |
| `copytruncate` | copy, then empty the live file in place (for apps that cannot reopen logs) |

Configs live in `/etc/logrotate.d/`, one file per app. Test before trusting:

```bash
sudo logrotate -d /etc/logrotate.d/brewbot     # dry run: shows what it would do
sudo logrotate -f /etc/logrotate.d/brewbot     # force a rotation now
```

### Why the app must be told

After `app.log` is renamed to `app.log.1`, a running app still has the **old
file open** and keeps writing into `app.log.1`. Either:

- signal it to reopen its logs (`postrotate` with a reload or `kill -HUP`), or
- use `copytruncate` (simple, but lines written during the copy can be lost).

Services that log to the journal do not need logrotate; journald limits its own
size (`SystemMaxUse=`).

## Try it

Write a logrotate block for `/var/log/brewbot/*.log` that rotates daily, keeps 7
copies, compresses them, does not complain if the log is missing, and skips
empty logs.

<details>
<summary>Show answer</summary>

```
/var/log/brewbot/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

</details>

## Common mistakes

- **No `postrotate` and no `copytruncate`.** The app writes into the rotated file
  forever and the "new" log stays empty.
- **Deleting a big log with `rm` while the app runs.** The space is not freed
  (Incident Week). Truncate or rotate instead.
- **Never testing.** A syntax error means logrotate silently skips the file.
  Use `-d`.

## Remember

- logrotate renames, compresses and deletes old logs on a schedule.
- Core directives: `daily`, `rotate N`, `compress`, `missingok`, `notifempty`.
- Tell the app: `postrotate` reload, or `copytruncate`.
- Configs in `/etc/logrotate.d/`; test with `logrotate -d`.

**Self-check:**

1. What does `rotate 7` mean?
2. Why does an app keep writing to `app.log.1` after rotation?
3. How do you test a logrotate config without changing anything?
$md$, 6, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e969cf2f-c441-5630-9036-2f68365cdbb8', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '1d2e633e-0589-50da-b212-4e9f881d0b3c', 'Lab: The 2am Page', 'notes', 6, $md$## Why this matters

It is 2:07am and brewbot is down. In this lab you write brewbot's unit file,
read last night's journal to find what crashed, schedule the nightly chores with
cron and a systemd timer, and stop logs from filling the disk. The lab machine
has no systemd of its own, so you write the files and read a saved journal; the
checks look at your files. Each task is checked automatically.

## Before you start

```bash
cd ~/work
ls night
wc -l night/journal.txt
```

What this does: `night/journal.txt` is a copy of last night's
`journalctl` output, about 20 lines.

## Task 1: write brewbot's unit file

Create `~/work/units/brewbot.service`. `[Unit]`: any `Description`, ordered
after `network.target`. `[Service]`: run `/opt/brewbot/bin/brewbot` as user
`brewbot`, restart only on failure. `[Install]`: start in the normal multi-user
boot target.

[[lab-task:1]]

## Task 2: what crashed at 2am?

Save the name of the unit that failed to start into
`answers/failed-unit.txt`, and the highest restart counter systemd reached into
`answers/restarts.txt`.

[[lab-task:2]]

What you should see:

```
$ grep -E 'FATAL|counter|too quickly' night/journal.txt | tail -3
Oct 14 02:00:18 atlas brewbot[1071]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:18 atlas systemd[1]: brewbot.service: Scheduled restart job ...
Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Start request repeated too quickly.
```

On the real atlas, the fix at 2:15am was
`sudo chgrp brewbot /etc/brewbot/brewbot.conf && sudo chmod 640 /etc/brewbot/brewbot.conf`,
then `sudo systemctl reset-failed brewbot && sudo systemctl start brewbot`.

## Task 3: schedule the nightly backup

Create `~/work/cron/brewbot.cron` with a crontab line that runs
`/opt/brewbot/backup.sh` every day at 02:30.

[[lab-task:3]]

## Task 4: health check on weekdays

Add a second line to `cron/brewbot.cron` that runs `/opt/brewbot/health.sh`
every 15 minutes, Monday to Friday only. Append; keep the backup line.

[[lab-task:4]]

## Task 5: stop the logs from eating the disk

Create `~/work/logrotate/brewbot`: a logrotate config for
`/var/log/brewbot/*.log` that rotates daily, keeps 7 copies, compresses them,
does not complain if the log is missing, and skips empty logs.

[[lab-task:5]]

## Task 6: the modern way, a timer

Create `~/work/units/brewbot-backup.timer` that runs every day at 02:30
(`OnCalendar`), catches up on missed runs, and is hooked into `timers.target`.

[[lab-task:6]]

## Remember

- Unit file: `[Unit]` After, `[Service]` ExecStart/User/Restart,
  `[Install]` WantedBy.
- The app's own log line holds the cause; systemd's lines are the symptom.
- Cron: minute hour dom month dow; timers: `OnCalendar=` + `Persistent=true`.
- logrotate keeps logs from filling the disk.

> **End of day 6.** Brewbot runs again and its logs will never fill the disk.
> Rhea, half asleep on the phone: "Nice work. Monday we're getting new disks,
> and we need some software installed." Tom's next note: "Know your storeroom."
$md$, 30, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('bf5b7a41-b247-574c-bc5b-499280eecbd8', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'e969cf2f-c441-5630-9036-2f68365cdbb8', 'module', 'Lab: The 2am Page', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$mkdir -p /home/labuser/work
mkdir -p /home/labuser/work/night && chmod 777 /home/labuser/work/night
cat > /home/labuser/work/night/journal.txt <<'MFEOF'
Oct 14 02:00:01 atlas systemd[1]: Started cron.service - Regular background program processing daemon.
Oct 14 02:00:02 atlas systemd[1]: Started nginx.service - A high performance web server.
Oct 14 02:00:03 atlas systemd[1]: Starting brewbot.service - Orbit Coffee order bot...
Oct 14 02:00:03 atlas brewbot[1040]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:03 atlas systemd[1]: brewbot.service: Main process exited, code=exited, status=1/FAILURE
Oct 14 02:00:03 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
Oct 14 02:00:08 atlas systemd[1]: brewbot.service: Scheduled restart job, restart counter is at 1.
Oct 14 02:00:08 atlas brewbot[1051]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:08 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
Oct 14 02:00:13 atlas systemd[1]: brewbot.service: Scheduled restart job, restart counter is at 2.
Oct 14 02:00:13 atlas brewbot[1060]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:13 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
Oct 14 02:00:18 atlas systemd[1]: brewbot.service: Scheduled restart job, restart counter is at 3.
Oct 14 02:00:18 atlas brewbot[1071]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:18 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Start request repeated too quickly.
Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
Oct 14 02:00:19 atlas systemd[1]: Failed to start brewbot.service - Orbit Coffee order bot.
Oct 14 02:05:00 atlas CRON[1102]: (root) CMD (/usr/local/bin/sync-prices.sh)
Oct 14 02:30:00 atlas sshd[1120]: Accepted publickey for rhea from 10.0.0.7 port 51522 ssh2

MFEOF
chmod 666 /home/labuser/work/night/journal.txt
w=/home/labuser/work
rm -rf $w/units $w/cron $w/logrotate $w/answers
mkdir -p $w/answers
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570' AND id NOT IN ('11690a1d-d6e4-564b-80bf-75bc0dd102c4', '5d802c56-4119-5e53-8d5c-ab82dba75a18', 'b2cf88fd-35a0-55e7-a3da-386886e35869', 'd7074474-e5ad-5350-8df9-e963be0be9fa', '96fa4ea5-1b1b-5fbc-9e6f-9c3717575ed8', '30f6d2d6-ea91-5e52-9975-6bccb6b0dce2');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570';
DELETE FROM lab_tasks WHERE lab_id = 'bf5b7a41-b247-574c-bc5b-499280eecbd8' AND id NOT IN ('4ea6e642-9cef-54b9-b472-34a884112377', '2a2bb681-8f25-5500-9806-588a57d96e8f', '15558316-5268-5690-bc10-94f2fbf741fe', 'b8bfe9e0-1dae-5ae3-876a-1e5ab4354317', 'e8aa0414-7f50-587b-a650-56e983fa7b04', '09a4b9ae-ffc1-5882-bec2-6b0462a246a8');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'bf5b7a41-b247-574c-bc5b-499280eecbd8';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4ea6e642-9cef-54b9-b472-34a884112377', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 1, 'Write brewbot''s unit file', $md$Create /home/labuser/work/units/brewbot.service. In a [Unit] section give it any Description and order it after network.target. In a [Service] section run /opt/brewbot/bin/brewbot as the user brewbot and restart it only when it fails. In an [Install] section make it start in the normal multi-user boot target.$md$, $script$f=/home/labuser/work/units/brewbot.service
grep -q '^\[Unit\]' $f && grep -q '^Description=..*' $f && grep -q '^After=.*network.target' $f &&
grep -q '^\[Service\]' $f && grep -q '^ExecStart=/opt/brewbot/bin/brewbot' $f &&
grep -q '^User=brewbot$' $f && grep -q '^Restart=on-failure$' $f &&
grep -q '^\[Install\]' $f && grep -q '^WantedBy=multi-user.target$' $f
$script$, 'Copy the unit file example from the lesson and adjust it. Keys are Description, After, ExecStart, User, Restart and WantedBy - one per line, no spaces around the equals sign.', 'After= orders startup, ExecStart= is the command, Restart=on-failure brings the service back when it crashes, and WantedBy=multi-user.target is what systemctl enable hooks into.', 25, false, true),
('2a2bb681-8f25-5500-9806-588a57d96e8f', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 2, 'What crashed at 2am?', $md$night/journal.txt is last night's journal. Save the name of the unit that failed to start (for example nginx.service) into answers/failed-unit.txt, and the highest restart counter systemd reached into answers/restarts.txt.$md$, $script$a=/home/labuser/work/answers
[ "$(tr -d '[:space:]' < $a/failed-unit.txt)" = brewbot.service ] &&
[ "$(tr -d '[:space:]' < $a/restarts.txt)" = 3 ]
$script$, 'grep -i fail night/journal.txt shows the failing unit. grep ''restart counter'' shows each restart; the last one has the highest number.', 'systemd restarted brewbot three times, then hit its start rate limit ("Start request repeated too quickly") and gave up. The real cause is on the brewbot line - Permission denied on its config file.', 25, false, true),
('15558316-5268-5690-bc10-94f2fbf741fe', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 3, 'Schedule the nightly backup', $md$Create /home/labuser/work/cron/brewbot.cron containing a crontab line that runs /opt/brewbot/backup.sh every day at 02:30.$md$, $script$awk '$6 == "/opt/brewbot/backup.sh" && $1 == "30" && ($2 == "2" || $2 == "02") && $3 == "*" && $4 == "*" && $5 == "*" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron
$script$, 'The five time fields are minute, hour, day of month, month, day of week. A star means every.', '30 2 * * * means minute 30 of hour 2, on every day of every month, any weekday.', 15, false, true),
('b8bfe9e0-1dae-5ae3-876a-1e5ab4354317', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 4, 'Health check on weekdays', $md$Add a second line to cron/brewbot.cron that runs /opt/brewbot/health.sh every 15 minutes, Monday to Friday only.$md$, $script$awk '$6 == "/opt/brewbot/health.sh" && $1 == "*/15" && $2 == "*" && $3 == "*" && $4 == "*" && $5 == "1-5" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron &&
grep -q backup.sh /home/labuser/work/cron/brewbot.cron
$script$, 'A step value */15 in the minute field means every 15 minutes. Day of week 1-5 is Monday to Friday (0 or 7 is Sunday). Use >> to append so the backup line stays.', '*/15 * * * 1-5 fires at :00, :15, :30 and :45 of every hour, only on weekdays.', 15, false, true),
('e8aa0414-7f50-587b-a650-56e983fa7b04', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 5, 'Stop the logs from eating the disk', $md$Create /home/labuser/work/logrotate/brewbot - a logrotate config for /var/log/brewbot/*.log that rotates daily, keeps 7 old copies, compresses them, does not complain if the log is missing, and skips empty logs.$md$, $script$f=/home/labuser/work/logrotate/brewbot
grep -q '^/var/log/brewbot/\*\.log *{' $f && grep -qw daily $f && grep -Eq '^\s*rotate\s+7\s*$' $f &&
grep -Eq '^\s*compress\s*$' $f && grep -qw missingok $f && grep -qw notifempty $f && grep -q '^}' $f
$script$, 'Use the logrotate example from the lesson - the path, then a block in braces with one directive per line - daily, rotate 7, compress, missingok, notifempty.', 'logrotate runs daily from cron or a systemd timer. Without it, a chatty log grows until the disk is full - one of the most common outages there is.', 20, false, true),
('09a4b9ae-ffc1-5882-bec2-6b0462a246a8', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 6, 'Turn the backup into a systemd timer', $md$Create /home/labuser/work/units/brewbot-backup.timer. In a [Timer] section schedule it every day at 02:30 with OnCalendar and make it catch up on missed runs. In an [Install] section hook it into timers.target.$md$, $script$f=/home/labuser/work/units/brewbot-backup.timer
grep -q '^\[Timer\]' $f && grep -Eq '^OnCalendar=(\*-\*-\* )?0?2:30(:00)?$' $f &&
grep -Eiq '^Persistent=(true|yes)$' $f &&
grep -q '^\[Install\]' $f && grep -q '^WantedBy=timers.target$' $f
$script$, 'Copy the timer example from the cron and timers lesson. OnCalendar=*-*-* 02:30:00, Persistent=true and WantedBy=timers.target, one per line.', 'A timer starts the service with the same name (brewbot-backup.service). Persistent=true runs a missed job at the next boot, and its output lands in the journal without any redirection.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('d8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 1, $json$[{"id":"4ea6e642-9cef-54b9-b472-34a884112377","lab_id":"bf5b7a41-b247-574c-bc5b-499280eecbd8","position":1,"title":"Write brewbot's unit file","description":"Create /home/labuser/work/units/brewbot.service. In a [Unit] section give it any Description and order it after network.target. In a [Service] section run /opt/brewbot/bin/brewbot as the user brewbot and restart it only when it fails. In an [Install] section make it start in the normal multi-user boot target.","verification_script":"f=/home/labuser/work/units/brewbot.service\ngrep -q '^\\[Unit\\]' $f \u0026\u0026 grep -q '^Description=..*' $f \u0026\u0026 grep -q '^After=.*network.target' $f \u0026\u0026\ngrep -q '^\\[Service\\]' $f \u0026\u0026 grep -q '^ExecStart=/opt/brewbot/bin/brewbot' $f \u0026\u0026\ngrep -q '^User=brewbot$' $f \u0026\u0026 grep -q '^Restart=on-failure$' $f \u0026\u0026\ngrep -q '^\\[Install\\]' $f \u0026\u0026 grep -q '^WantedBy=multi-user.target$' $f\n","hint_context":"Copy the unit file example from the lesson and adjust it. Keys are Description, After, ExecStart, User, Restart and WantedBy - one per line, no spaces around the equals sign.","explanation_context":"After= orders startup, ExecStart= is the command, Restart=on-failure brings the service back when it crashes, and WantedBy=multi-user.target is what systemctl enable hooks into.","points":25,"is_optional":false,"is_stateful":true},{"id":"2a2bb681-8f25-5500-9806-588a57d96e8f","lab_id":"bf5b7a41-b247-574c-bc5b-499280eecbd8","position":2,"title":"What crashed at 2am?","description":"night/journal.txt is last night's journal. Save the name of the unit that failed to start (for example nginx.service) into answers/failed-unit.txt, and the highest restart counter systemd reached into answers/restarts.txt.","verification_script":"a=/home/labuser/work/answers\n[ \"$(tr -d '[:space:]' \u003c $a/failed-unit.txt)\" = brewbot.service ] \u0026\u0026\n[ \"$(tr -d '[:space:]' \u003c $a/restarts.txt)\" = 3 ]\n","hint_context":"grep -i fail night/journal.txt shows the failing unit. grep 'restart counter' shows each restart; the last one has the highest number.","explanation_context":"systemd restarted brewbot three times, then hit its start rate limit (\"Start request repeated too quickly\") and gave up. The real cause is on the brewbot line - Permission denied on its config file.","points":25,"is_optional":false,"is_stateful":true},{"id":"15558316-5268-5690-bc10-94f2fbf741fe","lab_id":"bf5b7a41-b247-574c-bc5b-499280eecbd8","position":3,"title":"Schedule the nightly backup","description":"Create /home/labuser/work/cron/brewbot.cron containing a crontab line that runs /opt/brewbot/backup.sh every day at 02:30.","verification_script":"awk '$6 == \"/opt/brewbot/backup.sh\" \u0026\u0026 $1 == \"30\" \u0026\u0026 ($2 == \"2\" || $2 == \"02\") \u0026\u0026 $3 == \"*\" \u0026\u0026 $4 == \"*\" \u0026\u0026 $5 == \"*\" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron\n","hint_context":"The five time fields are minute, hour, day of month, month, day of week. A star means every.","explanation_context":"30 2 * * * means minute 30 of hour 2, on every day of every month, any weekday.","points":15,"is_optional":false,"is_stateful":true},{"id":"b8bfe9e0-1dae-5ae3-876a-1e5ab4354317","lab_id":"bf5b7a41-b247-574c-bc5b-499280eecbd8","position":4,"title":"Health check on weekdays","description":"Add a second line to cron/brewbot.cron that runs /opt/brewbot/health.sh every 15 minutes, Monday to Friday only.","verification_script":"awk '$6 == \"/opt/brewbot/health.sh\" \u0026\u0026 $1 == \"*/15\" \u0026\u0026 $2 == \"*\" \u0026\u0026 $3 == \"*\" \u0026\u0026 $4 == \"*\" \u0026\u0026 $5 == \"1-5\" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron \u0026\u0026\ngrep -q backup.sh /home/labuser/work/cron/brewbot.cron\n","hint_context":"A step value */15 in the minute field means every 15 minutes. Day of week 1-5 is Monday to Friday (0 or 7 is Sunday). Use \u003e\u003e to append so the backup line stays.","explanation_context":"*/15 * * * 1-5 fires at :00, :15, :30 and :45 of every hour, only on weekdays.","points":15,"is_optional":false,"is_stateful":true},{"id":"e8aa0414-7f50-587b-a650-56e983fa7b04","lab_id":"bf5b7a41-b247-574c-bc5b-499280eecbd8","position":5,"title":"Stop the logs from eating the disk","description":"Create /home/labuser/work/logrotate/brewbot - a logrotate config for /var/log/brewbot/*.log that rotates daily, keeps 7 old copies, compresses them, does not complain if the log is missing, and skips empty logs.","verification_script":"f=/home/labuser/work/logrotate/brewbot\ngrep -q '^/var/log/brewbot/\\*\\.log *{' $f \u0026\u0026 grep -qw daily $f \u0026\u0026 grep -Eq '^\\s*rotate\\s+7\\s*$' $f \u0026\u0026\ngrep -Eq '^\\s*compress\\s*$' $f \u0026\u0026 grep -qw missingok $f \u0026\u0026 grep -qw notifempty $f \u0026\u0026 grep -q '^}' $f\n","hint_context":"Use the logrotate example from the lesson - the path, then a block in braces with one directive per line - daily, rotate 7, compress, missingok, notifempty.","explanation_context":"logrotate runs daily from cron or a systemd timer. Without it, a chatty log grows until the disk is full - one of the most common outages there is.","points":20,"is_optional":false,"is_stateful":true},{"id":"09a4b9ae-ffc1-5882-bec2-6b0462a246a8","lab_id":"bf5b7a41-b247-574c-bc5b-499280eecbd8","position":6,"title":"Turn the backup into a systemd timer","description":"Create /home/labuser/work/units/brewbot-backup.timer. In a [Timer] section schedule it every day at 02:30 with OnCalendar and make it catch up on missed runs. In an [Install] section hook it into timers.target.","verification_script":"f=/home/labuser/work/units/brewbot-backup.timer\ngrep -q '^\\[Timer\\]' $f \u0026\u0026 grep -Eq '^OnCalendar=(\\*-\\*-\\* )?0?2:30(:00)?$' $f \u0026\u0026\ngrep -Eiq '^Persistent=(true|yes)$' $f \u0026\u0026\ngrep -q '^\\[Install\\]' $f \u0026\u0026 grep -q '^WantedBy=timers.target$' $f\n","hint_context":"Copy the timer example from the cron and timers lesson. OnCalendar=*-*-* 02:30:00, Persistent=true and WantedBy=timers.target, one per line.","explanation_context":"A timer starts the service with the same name (brewbot-backup.service). Persistent=true runs a missed job at the next boot, and its output lands in the journal without any redirection.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('11690a1d-d6e4-564b-80bf-75bc0dd102c4', 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', '4ea6e642-9cef-54b9-b472-34a884112377', 1, 'Write brewbot''s unit file', $md$Create /home/labuser/work/units/brewbot.service. In a [Unit] section give it any Description and order it after network.target. In a [Service] section run /opt/brewbot/bin/brewbot as the user brewbot and restart it only when it fails. In an [Install] section make it start in the normal multi-user boot target.$md$, $script$f=/home/labuser/work/units/brewbot.service
grep -q '^\[Unit\]' $f && grep -q '^Description=..*' $f && grep -q '^After=.*network.target' $f &&
grep -q '^\[Service\]' $f && grep -q '^ExecStart=/opt/brewbot/bin/brewbot' $f &&
grep -q '^User=brewbot$' $f && grep -q '^Restart=on-failure$' $f &&
grep -q '^\[Install\]' $f && grep -q '^WantedBy=multi-user.target$' $f
$script$, 'Copy the unit file example from the lesson and adjust it. Keys are Description, After, ExecStart, User, Restart and WantedBy - one per line, no spaces around the equals sign.', 'After= orders startup, ExecStart= is the command, Restart=on-failure brings the service back when it crashes, and WantedBy=multi-user.target is what systemctl enable hooks into.', 25, false, true),
('5d802c56-4119-5e53-8d5c-ab82dba75a18', 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', '2a2bb681-8f25-5500-9806-588a57d96e8f', 2, 'What crashed at 2am?', $md$night/journal.txt is last night's journal. Save the name of the unit that failed to start (for example nginx.service) into answers/failed-unit.txt, and the highest restart counter systemd reached into answers/restarts.txt.$md$, $script$a=/home/labuser/work/answers
[ "$(tr -d '[:space:]' < $a/failed-unit.txt)" = brewbot.service ] &&
[ "$(tr -d '[:space:]' < $a/restarts.txt)" = 3 ]
$script$, 'grep -i fail night/journal.txt shows the failing unit. grep ''restart counter'' shows each restart; the last one has the highest number.', 'systemd restarted brewbot three times, then hit its start rate limit ("Start request repeated too quickly") and gave up. The real cause is on the brewbot line - Permission denied on its config file.', 25, false, true),
('b2cf88fd-35a0-55e7-a3da-386886e35869', 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', '15558316-5268-5690-bc10-94f2fbf741fe', 3, 'Schedule the nightly backup', $md$Create /home/labuser/work/cron/brewbot.cron containing a crontab line that runs /opt/brewbot/backup.sh every day at 02:30.$md$, $script$awk '$6 == "/opt/brewbot/backup.sh" && $1 == "30" && ($2 == "2" || $2 == "02") && $3 == "*" && $4 == "*" && $5 == "*" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron
$script$, 'The five time fields are minute, hour, day of month, month, day of week. A star means every.', '30 2 * * * means minute 30 of hour 2, on every day of every month, any weekday.', 15, false, true),
('d7074474-e5ad-5350-8df9-e963be0be9fa', 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', 'b8bfe9e0-1dae-5ae3-876a-1e5ab4354317', 4, 'Health check on weekdays', $md$Add a second line to cron/brewbot.cron that runs /opt/brewbot/health.sh every 15 minutes, Monday to Friday only.$md$, $script$awk '$6 == "/opt/brewbot/health.sh" && $1 == "*/15" && $2 == "*" && $3 == "*" && $4 == "*" && $5 == "1-5" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron &&
grep -q backup.sh /home/labuser/work/cron/brewbot.cron
$script$, 'A step value */15 in the minute field means every 15 minutes. Day of week 1-5 is Monday to Friday (0 or 7 is Sunday). Use >> to append so the backup line stays.', '*/15 * * * 1-5 fires at :00, :15, :30 and :45 of every hour, only on weekdays.', 15, false, true),
('96fa4ea5-1b1b-5fbc-9e6f-9c3717575ed8', 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', 'e8aa0414-7f50-587b-a650-56e983fa7b04', 5, 'Stop the logs from eating the disk', $md$Create /home/labuser/work/logrotate/brewbot - a logrotate config for /var/log/brewbot/*.log that rotates daily, keeps 7 old copies, compresses them, does not complain if the log is missing, and skips empty logs.$md$, $script$f=/home/labuser/work/logrotate/brewbot
grep -q '^/var/log/brewbot/\*\.log *{' $f && grep -qw daily $f && grep -Eq '^\s*rotate\s+7\s*$' $f &&
grep -Eq '^\s*compress\s*$' $f && grep -qw missingok $f && grep -qw notifempty $f && grep -q '^}' $f
$script$, 'Use the logrotate example from the lesson - the path, then a block in braces with one directive per line - daily, rotate 7, compress, missingok, notifempty.', 'logrotate runs daily from cron or a systemd timer. Without it, a chatty log grows until the disk is full - one of the most common outages there is.', 20, false, true),
('30f6d2d6-ea91-5e52-9975-6bccb6b0dce2', 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', '09a4b9ae-ffc1-5882-bec2-6b0462a246a8', 6, 'Turn the backup into a systemd timer', $md$Create /home/labuser/work/units/brewbot-backup.timer. In a [Timer] section schedule it every day at 02:30 with OnCalendar and make it catch up on missed runs. In an [Install] section hook it into timers.target.$md$, $script$f=/home/labuser/work/units/brewbot-backup.timer
grep -q '^\[Timer\]' $f && grep -Eq '^OnCalendar=(\*-\*-\* )?0?2:30(:00)?$' $f &&
grep -Eiq '^Persistent=(true|yes)$' $f &&
grep -q '^\[Install\]' $f && grep -q '^WantedBy=timers.target$' $f
$script$, 'Copy the timer example from the cron and timers lesson. OnCalendar=*-*-* 02:30:00, Persistent=true and WantedBy=timers.target, one per line.', 'A timer starts the service with the same name (brewbot-backup.service). Persistent=true runs a missed job at the next boot, and its output lands in the journal without any redirection.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', updated_at = now()
WHERE id = 'bf5b7a41-b247-574c-bc5b-499280eecbd8' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('80ba4d7c-7bff-511f-a036-9bb99029c411', '00000000-0000-0000-0000-000000000001', 'mcq', 'brewbot runs fine after systemctl start, but is gone after every reboot. Whic...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e392f21c-4069-58b1-9803-a0f85e790743', '80ba4d7c-7bff-511f-a036-9bb99029c411', 1, $json${"prompt":"brewbot runs fine after systemctl start, but is gone after every reboot. Which command fixes it for good?","multiple":false,"options":[{"id":"a","text":"sudo systemctl enable brewbot","is_correct":true},{"id":"b","text":"sudo systemctl reload brewbot","is_correct":false},{"id":"c","text":"sudo systemctl daemon-reload","is_correct":false},{"id":"d","text":"sudo systemctl restart brewbot","is_correct":false}],"explanation":"enable hooks the unit into the boot target. reload re-reads the app's config, daemon-reload re-reads unit files, and restart only affects the current boot."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7956d1b0-5b66-53d4-978c-0a69b63ac317', '00000000-0000-0000-0000-000000000001', 'mcq', 'You changed ExecStart in /etc/systemd/system/brewbot.service and restarted, b...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2625b2cd-3dff-55b8-ba11-d5f5c243c4d2', '7956d1b0-5b66-53d4-978c-0a69b63ac317', 1, $json${"prompt":"You changed ExecStart in /etc/systemd/system/brewbot.service and restarted, but the old command still runs. What did you skip?","multiple":false,"options":[{"id":"a","text":"sudo systemctl daemon-reload","is_correct":true},{"id":"b","text":"sudo systemctl enable brewbot","is_correct":false},{"id":"c","text":"A reboot","is_correct":false},{"id":"d","text":"chmod +x on the unit file","is_correct":false}],"explanation":"systemd caches unit files; daemon-reload makes it read your edit. Enabling changes boot behaviour only, a reboot is overkill, and unit files are not executed so they need no x bit."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5b435ee1-d7ac-59ba-afa6-c6c096d29bfd', '00000000-0000-0000-0000-000000000001', 'mcq', 'You need nginx to allow more open files. Where should the change go?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b4b916dc-8f5e-5266-b7da-13368ad9ef64', '5b435ee1-d7ac-59ba-afa6-c6c096d29bfd', 1, $json${"prompt":"You need nginx to allow more open files. Where should the change go?","multiple":false,"options":[{"id":"a","text":"Edit /usr/lib/systemd/system/nginx.service directly","is_correct":false},{"id":"b","text":"sudo systemctl edit nginx and add LimitNOFILE under [Service]","is_correct":true},{"id":"c","text":"Add it to ~/.bashrc","is_correct":false},{"id":"d","text":"Put it in /etc/crontab","is_correct":false}],"explanation":"systemctl edit creates a drop-in in /etc/systemd/system/nginx.service.d/ that survives package updates. Vendor files in /usr/lib are overwritten on update, and shell or cron files do not affect a service's limits."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('bf54d93c-9b80-5270-9316-bb16ed38dcb2', '00000000-0000-0000-0000-000000000001', 'mcq', 'systemctl status brewbot says ''Start request repeated too quickly''. You fixed...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f561cc9d-da5a-5fb4-85e1-1ca1420d11c6', 'bf54d93c-9b80-5270-9316-bb16ed38dcb2', 1, $json${"prompt":"systemctl status brewbot says 'Start request repeated too quickly'. You fixed the config. What next?","multiple":false,"options":[{"id":"a","text":"systemctl reset-failed brewbot, then systemctl start brewbot","is_correct":true},{"id":"b","text":"Wait 24 hours","is_correct":false},{"id":"c","text":"Reinstall systemd","is_correct":false},{"id":"d","text":"kill -9 1","is_correct":false}],"explanation":"systemd stopped retrying after hitting its start rate limit; reset-failed clears that state. Nothing resets on its own soon, reinstalling is pointless, and killing PID 1 would crash the system."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b9b4196a-4a9a-5e29-a482-d343a01a8f79', '00000000-0000-0000-0000-000000000001', 'mcq', 'atlas crashed at 3am and rebooted. Which command shows error messages from be...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('21ba4403-2fb4-5cf3-9761-a4c2a9a6ae14', 'b9b4196a-4a9a-5e29-a482-d343a01a8f79', 1, $json${"prompt":"atlas crashed at 3am and rebooted. Which command shows error messages from before the crash?","multiple":false,"options":[{"id":"a","text":"journalctl -b -1 -p err (with a persistent journal)","is_correct":true},{"id":"b","text":"journalctl -b -p err","is_correct":false},{"id":"c","text":"dmesg -T","is_correct":false},{"id":"d","text":"systemctl --failed","is_correct":false}],"explanation":"-b -1 selects the previous boot. -b alone is the current boot, dmesg shows the current boot's kernel buffer, and --failed lists units failing now."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('337d8872-02c7-56c4-9821-ca835e64dec8', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does the crontab line */15 * * * 1-5 /opt/check.sh do?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('026a8c4b-7599-5da2-a9de-0eb189d3c712', '337d8872-02c7-56c4-9821-ca835e64dec8', 1, $json${"prompt":"What does the crontab line */15 * * * 1-5 /opt/check.sh do?","multiple":false,"options":[{"id":"a","text":"Runs every 15 minutes, Monday to Friday","is_correct":true},{"id":"b","text":"Runs at 15:00 on the first five days of the month","is_correct":false},{"id":"c","text":"Runs 15 times a day on weekends","is_correct":false},{"id":"d","text":"Runs every 15 hours","is_correct":false}],"explanation":"Field 1 (minute) */15 = every 15 minutes, field 5 (day of week) 1-5 = Monday-Friday. Hour 15 would be in field 2, and day of month is field 3."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e45b4a69-c08e-54f8-8e1d-b138d5bf9f08', '00000000-0000-0000-0000-000000000001', 'mcq', 'backup.sh works when you run it by hand, but the cron job fails with ''pg_dump...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f64dd7f5-8312-55a1-8484-25a9b144894d', 'e45b4a69-c08e-54f8-8e1d-b138d5bf9f08', 1, $json${"prompt":"backup.sh works when you run it by hand, but the cron job fails with 'pg_dump: command not found'. Why?","multiple":false,"options":[{"id":"a","text":"Cron runs with a minimal PATH and no .bashrc; use full paths or set PATH in the crontab","is_correct":true},{"id":"b","text":"Cron cannot run shell scripts","is_correct":false},{"id":"c","text":"pg_dump only works interactively","is_correct":false},{"id":"d","text":"The crontab must be owned by root","is_correct":false}],"explanation":"Cron's environment is tiny. Scripts run fine from cron when commands are reachable, pg_dump is non-interactive, and user crontabs are owned by the user."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6b79c2ea-e4e8-5db1-87f5-441962a4b491', '00000000-0000-0000-0000-000000000001', 'mcq', 'After logrotate ran, app.log is empty but app.log.1 keeps growing. What is mi...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('dda68e12-b420-5a8e-9c74-d2521fa674f8', '6b79c2ea-e4e8-5db1-87f5-441962a4b491', 1, $json${"prompt":"After logrotate ran, app.log is empty but app.log.1 keeps growing. What is missing from the config?","multiple":false,"options":[{"id":"a","text":"A postrotate step that tells the app to reopen its log (or copytruncate)","is_correct":true},{"id":"b","text":"compress","is_correct":false},{"id":"c","text":"missingok","is_correct":false},{"id":"d","text":"rotate 30","is_correct":false}],"explanation":"The app still holds the renamed file open. Signal it to reopen, or use copytruncate. compress, missingok and the number of kept copies do not change which file the app writes to."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3d7cdf46-cb49-5b1c-80a3-fff806f41982', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why might you choose a systemd timer over a cron line for the nightly backup?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9dd557d2-840b-58ac-8989-c3630415043b', '3d7cdf46-cb49-5b1c-80a3-fff806f41982', 1, $json${"prompt":"Why might you choose a systemd timer over a cron line for the nightly backup?","multiple":false,"options":[{"id":"a","text":"Its output goes to the journal automatically and Persistent=true catches up on runs missed while the server was off","is_correct":true},{"id":"b","text":"Timers run faster","is_correct":false},{"id":"c","text":"Cron is removed from modern Linux","is_correct":false},{"id":"d","text":"Timers do not need a service unit","is_correct":false}],"explanation":"Timers bring logging, catch-up and all service settings. Speed is the same, cron is still widely available, and a timer always triggers a service unit."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('01d0a09b-8258-5c4f-a829-500b301858ab', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 5): a nightly job started by hand with & died when you logged...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5e980f88-56f4-5092-9436-722f9b278bb5', '01d0a09b-8258-5c4f-a829-500b301858ab', 1, $json${"prompt":"Review (chapter 5): a nightly job started by hand with \u0026 died when you logged out. What would have kept it running?","multiple":false,"options":[{"id":"a","text":"nohup (or tmux), because logout sends SIGHUP to the session's jobs","is_correct":true},{"id":"b","text":"nice -n 19","is_correct":false},{"id":"c","text":"kill -CONT","is_correct":false},{"id":"d","text":"Running it with sudo","is_correct":false}],"explanation":"nohup makes it ignore SIGHUP; tmux keeps the session alive. Niceness changes priority, SIGCONT resumes stopped jobs, and sudo does not protect from SIGHUP."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('60e74f37-31b2-5856-bdf0-e67af4cd3ab9', '00000000-0000-0000-0000-000000000001', 'Quiz: systemd, Logs and Schedules', 'linux-night-shift-quiz', 'Quiz covering Chapter 6: The Night Shift - systemd, Logs and Schedules.', 'mcq', 'published', 'module', '2548efc3-bdc8-595c-ad95-418a1ba2fc70', 12, 70, 5, 20, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '60e74f37-31b2-5856-bdf0-e67af4cd3ab9' AND question_id NOT IN ('80ba4d7c-7bff-511f-a036-9bb99029c411', '7956d1b0-5b66-53d4-978c-0a69b63ac317', '5b435ee1-d7ac-59ba-afa6-c6c096d29bfd', 'bf54d93c-9b80-5270-9316-bb16ed38dcb2', 'b9b4196a-4a9a-5e29-a482-d343a01a8f79', '337d8872-02c7-56c4-9821-ca835e64dec8', 'e45b4a69-c08e-54f8-8e1d-b138d5bf9f08', '6b79c2ea-e4e8-5db1-87f5-441962a4b491', '3d7cdf46-cb49-5b1c-80a3-fff806f41982', '01d0a09b-8258-5c4f-a829-500b301858ab');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('f0fa21e5-3bda-5b64-8e56-5de5918dfc34', '60e74f37-31b2-5856-bdf0-e67af4cd3ab9', '80ba4d7c-7bff-511f-a036-9bb99029c411', 'e392f21c-4069-58b1-9803-a0f85e790743', 0, 2),
('80a69539-ec2d-58ec-b7e8-41f011984e74', '60e74f37-31b2-5856-bdf0-e67af4cd3ab9', '7956d1b0-5b66-53d4-978c-0a69b63ac317', '2625b2cd-3dff-55b8-ba11-d5f5c243c4d2', 1, 2),
('391aeff3-f761-5d80-a4c1-ccfd289b5c70', '60e74f37-31b2-5856-bdf0-e67af4cd3ab9', '5b435ee1-d7ac-59ba-afa6-c6c096d29bfd', 'b4b916dc-8f5e-5266-b7da-13368ad9ef64', 2, 2),
('587d7458-1df3-5e8a-bed1-436d265757dc', '60e74f37-31b2-5856-bdf0-e67af4cd3ab9', 'bf54d93c-9b80-5270-9316-bb16ed38dcb2', 'f561cc9d-da5a-5fb4-85e1-1ca1420d11c6', 3, 2),
('59040bd5-a6f3-54aa-9185-da91212eeba9', '60e74f37-31b2-5856-bdf0-e67af4cd3ab9', 'b9b4196a-4a9a-5e29-a482-d343a01a8f79', '21ba4403-2fb4-5cf3-9761-a4c2a9a6ae14', 4, 2),
('173c4700-7828-500a-8063-06e38ae5018e', '60e74f37-31b2-5856-bdf0-e67af4cd3ab9', '337d8872-02c7-56c4-9821-ca835e64dec8', '026a8c4b-7599-5da2-a9de-0eb189d3c712', 5, 2),
('1c0d0cc0-4236-58a7-bf09-a2beff9b0101', '60e74f37-31b2-5856-bdf0-e67af4cd3ab9', 'e45b4a69-c08e-54f8-8e1d-b138d5bf9f08', 'f64dd7f5-8312-55a1-8484-25a9b144894d', 6, 2),
('b45aa880-6bfb-5544-ab99-5e27057e9895', '60e74f37-31b2-5856-bdf0-e67af4cd3ab9', '6b79c2ea-e4e8-5db1-87f5-441962a4b491', 'dda68e12-b420-5a8e-9c74-d2521fa674f8', 7, 2),
('cf43f495-0148-51b8-bc2a-d1d96bab3212', '60e74f37-31b2-5856-bdf0-e67af4cd3ab9', '3d7cdf46-cb49-5b1c-80a3-fff806f41982', '9dd557d2-840b-58ac-8989-c3630415043b', 8, 2),
('287eddae-9408-59f0-91ee-4383812bfb40', '60e74f37-31b2-5856-bdf0-e67af4cd3ab9', '01d0a09b-8258-5c4f-a829-500b301858ab', '5e980f88-56f4-5092-9436-722f9b278bb5', 9, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('2548efc3-bdc8-595c-ad95-418a1ba2fc70', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '1d2e633e-0589-50da-b212-4e9f881d0b3c', 'Quiz: systemd, Logs and Schedules', 'assessment', 7, 10, '60e74f37-31b2-5856-bdf0-e67af4cd3ab9')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 7: The Storeroom - Packages, Disks and Backups
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 7: The Storeroom - Packages, Disks and Backups', 7, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ca50f395-ddab-592d-9cf5-1e3a6dc32c7d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', 'Installing Software: apt, dpkg, dnf and rpm', 'notes', 0, $md$## Why this matters

> **Monday, week 2.** A delivery of new disks arrives, and the dev team wants
> software installed. Rhea: "Before you install anything, know what's already in
> the storeroom. And never let a disk fill up silently."

On Linux you rarely download installers from websites. The package manager
installs signed software from trusted repositories, resolves dependencies, and
patches security holes. Knowing it also answers "which version do we run?" and
"where did this file come from?"

## Mental model: the menu and the order

- A **package** is an archive of files plus metadata: name, version,
  dependencies, install scripts.
- A **repository** is a signed online catalogue of packages.
- The **high-level tool** (`apt`, `dnf`) downloads from repositories and solves
  dependencies. The **low-level tool** (`dpkg`, `rpm`) installs a single package
  file and keeps the database of what is installed.

| | Debian / Ubuntu | RHEL / Fedora / Rocky | Alpine |
|---|---|---|---|
| Package format | `.deb` | `.rpm` | `.apk` |
| High-level tool | `apt` | `dnf` (older: `yum`) | `apk` |
| Low-level tool | `dpkg` | `rpm` | - |

> **Memory hook:** `apt update` reads the **menu**, `apt upgrade` **orders** the
> new dishes. Always update before you install.

## See it work

```bash
sudo apt update                  # refresh the package lists (the menu)
sudo apt install nginx           # install, with dependencies
sudo apt upgrade                 # upgrade everything installed
sudo apt remove nginx            # remove, keep config files
sudo apt purge nginx             # remove including config
sudo apt autoremove              # remove dependencies nobody needs anymore
apt search redis                 # find packages
apt show nginx                   # details: version, size, dependencies
apt list --upgradable            # what would upgrade
```

### Asking dpkg what is installed

These work without root, so try them in the lab:

```bash
dpkg -l bash                          # is it installed? which version?
dpkg-query -W -f='${Version}\n' bash  # just the version
dpkg -L jq | head -3                  # files installed by a package
dpkg -S /usr/bin/jq                   # which package owns this file?
```

Expected output (versions differ):

```
ii  bash           5.2.21-2ubuntu4 amd64        GNU Bourne Again SHell
5.2.21-2ubuntu4
/.
/usr
/usr/bin
jq: /usr/bin/jq
```

`ii` means desired = install, status = installed. The RHEL equivalents are
`rpm -q bash`, `rpm -ql PACKAGE`, `rpm -qf FILE`, and `dnf provides FILE` for
packages that are not installed yet.

### Repositories and keys

Repositories are listed in `/etc/apt/sources.list.d/` (Ubuntu 24.04 uses the
`ubuntu.sources` file). Third-party repos come with a signing key; the key is
what makes a download trustworthy.

### Keeping a server patched

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades   # enable automatic security updates
apt-mark hold postgresql-16                       # freeze one package's version
cat /var/run/reboot-required 2>/dev/null          # does an update need a reboot?
```

`/var/log/apt/history.log` and `/var/log/dpkg.log` record every install: the
first place to look when "it broke after the update".

### Other ways software arrives

`snap` and `flatpak` (self-contained apps), language package managers (`pip`,
`npm`), container images, and building from source
(`./configure && make && sudo make install`, into `/usr/local`). On servers,
prefer the distro package when one exists: it gets security updates.

## Try it

Which package installed `/usr/bin/jq`, and which version of `bash` is installed?
Answer both with dpkg tools.

<details>
<summary>Show answer</summary>

```bash
dpkg -S /usr/bin/jq | cut -d: -f1      # jq
dpkg-query -W -f='${Version}\n' bash   # 5.2.21-2ubuntu4 (yours may differ)
```

</details>

## Common mistakes

- **`apt install` without `apt update` first.** Old lists point to package
  versions the mirror deleted: 404 errors.
- **`apt upgrade` on production at peak time.** Services restart. Schedule it,
  and read what will change first.
- **Mixing `pip install` (as root) with distro Python packages.** It can break
  system tools. Use virtual environments.
- **Adding random third-party repositories.** Each one can push any code as root.

## Remember

- `apt update` then `apt install`; `remove` keeps config, `purge` removes it.
- `dpkg -l` / `-L` / `-S` answer installed? / which files? / which package?
- RHEL: `dnf install`, `rpm -q`, `rpm -ql`, `rpm -qf`.
- Enable unattended security upgrades; check `/var/log/apt/history.log` after
  changes.

**Self-check:**

1. What is the difference between `apt update` and `apt upgrade`?
2. Which command tells you which package owns a file?
3. What is the difference between `remove` and `purge`?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2c79ee2f-d567-5228-bbe7-d75be3009813', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', 'Disks, Partitions and Filesystems: lsblk, df and du', 'notes', 1, $md$## Why this matters

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
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('27fd54a6-41f3-5e54-8be6-6d750add8e1d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', 'Adding a Disk: Partition, mkfs, mount, fstab and Swap', 'notes', 2, $md$## Why this matters

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
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ea13445f-9b90-57e2-af6e-4e12dd200fcf', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', 'LVM: Flexible Storage You Can Grow Later', 'notes', 3, $md$## Why this matters

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
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('411b7382-5fde-533f-8918-72e6a7d58c57', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', 'Archives and Backups: tar, gzip and rsync', 'notes', 4, $md$## Why this matters

Backups, deliveries from suppliers, release bundles and log archives are all
`.tar.gz` files. You need to create them with clean paths, look inside before
unpacking a stranger's archive, and copy large directories efficiently.

## Mental model: box, then shrink-wrap

- **tar** (tape archive) packs many files and directories into **one** file,
  keeping paths, permissions and timestamps. It does not compress.
- **gzip / xz / zstd** shrink one file.
- `.tar.gz` (or `.tgz`) = a tar box, shrink-wrapped with gzip.

> **Memory hook:** tar flags read like a sentence: **c**reate **z**ipped
> **f**ile, e**x**tract **z**ipped **f**ile, **t**ell me what is in the
> **z**ipped **f**ile.

## See it work

```bash
cd ~/work
tar -czf backups/storeroom.tar.gz storeroom    # create, gzip, file name
tar -tzf backups/storeroom.tar.gz | head -3    # list without extracting
```

What this does: `c` create, `z` gzip, `f` the archive's file name (must come
right before it). Expected output of the listing:

```
storeroom/
storeroom/beans/
storeroom/beans/arabica.bin
```

Paths are relative (`storeroom/...`) because you ran tar from `~/work`. Archive
from the parent directory, or use `-C`:

```bash
tar -czf /tmp/sr.tar.gz -C /home/labuser/work storeroom   # -C: change dir first
```

### Extracting

```bash
tar -tzf delivery.tar.gz              # ALWAYS look first
mkdir -p unpacked
tar -xzf delivery.tar.gz -C unpacked  # extract into a directory
```

```
delivery/
delivery/manifest.txt
delivery/invoice.txt
```

Listing first protects you from archives that spill hundreds of files into the
current directory, or contain absolute or `../` paths. GNU tar strips a leading
`/` by default, but still: look first.

### Compression choices

| Flag | Tool | Extension | Notes |
|---|---|---|---|
| `-z` | gzip | `.tar.gz` | everywhere, fast |
| `-J` | xz | `.tar.xz` | smaller, slower |
| `--zstd` | zstd | `.tar.zst` | modern: fast and small |
| `-a` | from the extension | any | `tar -caf x.tar.xz dir` |

```bash
gzip big.log          # -> big.log.gz (replaces the original)
gunzip big.log.gz
zcat big.log.gz | grep ERROR   # read without unpacking (also zgrep, zless)
zip -r site.zip site/ && unzip -l site.zip
```

### rsync: copy only what changed

```bash
rsync -av src/ /backup/src/              # archive mode, verbose
rsync -av --delete src/ /backup/src/     # also delete files removed from src
rsync -av --dry-run src/ dst/            # show what would happen
rsync -avz src/ deploy@atlas:/backup/src/   # over SSH, compressed
```

`-a` keeps permissions, times, links (like `cp -a`). The second run only sends
differences, so it is fast. The **trailing slash matters**: `src/` means "the
contents of src", `src` means "the directory src itself" (you get `dst/src/`).

### A backup is not a backup until you have restored it

The 3-2-1 rule: **3** copies, on **2** kinds of storage, **1** off-site. And test
restores regularly; an archive that has never been extracted is a hope, not a
backup.

## Try it

Extract `~/work/delivery.tar.gz` into `~/work/unpacked`, so that
`unpacked/delivery/manifest.txt` exists. What do you run first?

<details>
<summary>Show answer</summary>

```bash
tar -tzf ~/work/delivery.tar.gz          # look first
mkdir -p ~/work/unpacked
tar -xzf ~/work/delivery.tar.gz -C ~/work/unpacked
```

</details>

## Common mistakes

- **`tar -czf dir backup.tar.gz`.** `f` takes the next word as the archive name,
  so this tries to create an archive called `dir`. Archive name first.
- **Absolute paths in archives.** `tar -czf b.tgz /home/labuser/work/storeroom`
  stores `home/labuser/...`. Use `-C` for short paths.
- **`rsync --delete` with the slashes wrong.** It can delete the wrong tree. Run
  `--dry-run` first.
- **Never testing restores.**

## Remember

- `tar -czf OUT.tar.gz DIR`, `tar -tzf` to list, `tar -xzf ... -C DIR` to extract.
- `-z` gzip, `-J` xz, `--zstd`; `zcat`/`zgrep` read compressed logs.
- `rsync -av [--delete] src/ dst/`; trailing slash = contents.
- 3-2-1, and test restores.

**Self-check:**

1. What does `t` do in `tar -tzf`?
2. What does `-C` do?
3. What is the difference between `rsync src/ dst` and `rsync src dst`?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('11b28bd9-4431-59fb-b0c4-9e422068f6cc', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', 'Lab: Take Stock of the Storeroom', 'notes', 5, $md$## Why this matters

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
$md$, 20, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('50515b20-5794-5c5f-83ed-c0d96f5353b1', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '11b28bd9-4431-59fb-b0c4-9e422068f6cc', 'module', 'Lab: Take Stock of the Storeroom', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
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
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '66ce2671-166b-51c5-9017-75b87e77f60e' AND id NOT IN ('b70801f1-c42e-5e7f-a27c-99564232c1c1', '4706ec9a-fc23-576b-b422-ec8c1ba46e00', '55ff6aa1-6f38-5beb-8363-d08e513fe2fb', '316e0a15-515a-5404-990e-dfb5ce9039e5', 'd8c63b7e-2443-5b3d-8b5a-a4bf5d94e724');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '66ce2671-166b-51c5-9017-75b87e77f60e';
DELETE FROM lab_tasks WHERE lab_id = '50515b20-5794-5c5f-83ed-c0d96f5353b1' AND id NOT IN ('7acb13d9-2540-590b-a259-a8a1fec74c29', '3bcb7d63-2da2-57d1-8a38-c43668065aa3', '6e44b33b-1608-5cef-97f9-904682b036c5', '4ba88926-3372-5910-b83e-af606d3d0ec3', '73cac90e-b532-5266-86ae-af99b62a29a2');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '50515b20-5794-5c5f-83ed-c0d96f5353b1';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('7acb13d9-2540-590b-a259-a8a1fec74c29', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 1, 'Which bash do we have?', $md$Use the Debian package tools to save the installed version of the bash package into answers/bash-version.txt (the version string only, for example 5.0-6ubuntu1).$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/bash-version.txt)" = "$(dpkg-query -W -f='${Version}' bash)" ]
$script$, 'dpkg -l bash shows it in a table; dpkg-query -W -f=''${Version}'' bash prints only the version.', 'dpkg is the low-level tool that knows every installed .deb package; apt sits on top of it and adds downloading and dependency resolution.', 15, false, true),
('3bcb7d63-2da2-57d1-8a38-c43668065aa3', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 2, 'Who installed this file?', $md$Find which package installed the file /usr/bin/jq and save just the package name into answers/jq-owner.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/jq-owner.txt)" = "$(dpkg -S /usr/bin/jq | cut -d: -f1)" ]
$script$, 'dpkg -S PATH searches installed packages for a file and prints package-name - path.', 'dpkg -S (search) maps a file back to its package, and dpkg -L PACKAGE does the reverse. On RHEL the same questions are rpm -qf FILE and rpm -ql PACKAGE.', 15, false, true),
('6e44b33b-1608-5cef-97f9-904682b036c5', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 3, 'Which shelf is heaviest?', $md$Save the name of the largest subdirectory of /home/labuser/work/storeroom (just the name, like cups) into answers/biggest-dir.txt.$md$, $script$want=$(du -s /home/labuser/work/storeroom/*/ | sort -n | tail -1 | awk '{print $2}' | xargs basename)
[ "$(tr -d '[:space:]' < /home/labuser/work/answers/biggest-dir.txt)" = "$want" ]
$script$, 'du -sh storeroom/* shows one total per subdirectory; pipe through sort -h to rank them.', 'du measures what files actually use on disk, df measures whole filesystems. When df says a disk is full, du -sh /* | sort -h is how you walk down to the culprit.', 20, false, true),
('4ba88926-3372-5910-b83e-af606d3d0ec3', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 4, 'Back up the storeroom', $md$Create the compressed archive /home/labuser/work/backups/storeroom.tar.gz containing the storeroom directory. Paths inside the archive must start with storeroom/ (not /home/...).$md$, $script$a=/home/labuser/work/backups/storeroom.tar.gz
gzip -t $a && tar -tzf $a | grep -q '^storeroom/beans/arabica.bin$' && ! tar -tzf $a | grep -q '^/\|^home/'
$script$, 'Run tar from inside /home/labuser/work so the paths are relative - tar -czf backups/storeroom.tar.gz storeroom. c create, z gzip, f file name.', 'tar stores paths exactly as you give them. Archiving a relative path means it can be extracted anywhere; tar -tzf lists the contents without extracting.', 25, false, true),
('73cac90e-b532-5266-86ae-af99b62a29a2', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 5, 'Unpack the delivery', $md$Extract /home/labuser/work/delivery.tar.gz into the directory /home/labuser/work/unpacked, so that unpacked/delivery/manifest.txt exists.$md$, $script$grep -q arabica /home/labuser/work/unpacked/delivery/manifest.txt
$script$, 'tar -xzf ARCHIVE -C DIR extracts into DIR (which must exist - mkdir it first). List first with tar -tzf to see what is inside.', 'x extracts, -C changes into a directory first. Always list an archive from a stranger before extracting it - it could contain absolute paths or overwrite your files.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('66ce2671-166b-51c5-9017-75b87e77f60e', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 1, $json$[{"id":"7acb13d9-2540-590b-a259-a8a1fec74c29","lab_id":"50515b20-5794-5c5f-83ed-c0d96f5353b1","position":1,"title":"Which bash do we have?","description":"Use the Debian package tools to save the installed version of the bash package into answers/bash-version.txt (the version string only, for example 5.0-6ubuntu1).","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/bash-version.txt)\" = \"$(dpkg-query -W -f='${Version}' bash)\" ]\n","hint_context":"dpkg -l bash shows it in a table; dpkg-query -W -f='${Version}' bash prints only the version.","explanation_context":"dpkg is the low-level tool that knows every installed .deb package; apt sits on top of it and adds downloading and dependency resolution.","points":15,"is_optional":false,"is_stateful":true},{"id":"3bcb7d63-2da2-57d1-8a38-c43668065aa3","lab_id":"50515b20-5794-5c5f-83ed-c0d96f5353b1","position":2,"title":"Who installed this file?","description":"Find which package installed the file /usr/bin/jq and save just the package name into answers/jq-owner.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/jq-owner.txt)\" = \"$(dpkg -S /usr/bin/jq | cut -d: -f1)\" ]\n","hint_context":"dpkg -S PATH searches installed packages for a file and prints package-name - path.","explanation_context":"dpkg -S (search) maps a file back to its package, and dpkg -L PACKAGE does the reverse. On RHEL the same questions are rpm -qf FILE and rpm -ql PACKAGE.","points":15,"is_optional":false,"is_stateful":true},{"id":"6e44b33b-1608-5cef-97f9-904682b036c5","lab_id":"50515b20-5794-5c5f-83ed-c0d96f5353b1","position":3,"title":"Which shelf is heaviest?","description":"Save the name of the largest subdirectory of /home/labuser/work/storeroom (just the name, like cups) into answers/biggest-dir.txt.","verification_script":"want=$(du -s /home/labuser/work/storeroom/*/ | sort -n | tail -1 | awk '{print $2}' | xargs basename)\n[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/biggest-dir.txt)\" = \"$want\" ]\n","hint_context":"du -sh storeroom/* shows one total per subdirectory; pipe through sort -h to rank them.","explanation_context":"du measures what files actually use on disk, df measures whole filesystems. When df says a disk is full, du -sh /* | sort -h is how you walk down to the culprit.","points":20,"is_optional":false,"is_stateful":true},{"id":"4ba88926-3372-5910-b83e-af606d3d0ec3","lab_id":"50515b20-5794-5c5f-83ed-c0d96f5353b1","position":4,"title":"Back up the storeroom","description":"Create the compressed archive /home/labuser/work/backups/storeroom.tar.gz containing the storeroom directory. Paths inside the archive must start with storeroom/ (not /home/...).","verification_script":"a=/home/labuser/work/backups/storeroom.tar.gz\ngzip -t $a \u0026\u0026 tar -tzf $a | grep -q '^storeroom/beans/arabica.bin$' \u0026\u0026 ! tar -tzf $a | grep -q '^/\\|^home/'\n","hint_context":"Run tar from inside /home/labuser/work so the paths are relative - tar -czf backups/storeroom.tar.gz storeroom. c create, z gzip, f file name.","explanation_context":"tar stores paths exactly as you give them. Archiving a relative path means it can be extracted anywhere; tar -tzf lists the contents without extracting.","points":25,"is_optional":false,"is_stateful":true},{"id":"73cac90e-b532-5266-86ae-af99b62a29a2","lab_id":"50515b20-5794-5c5f-83ed-c0d96f5353b1","position":5,"title":"Unpack the delivery","description":"Extract /home/labuser/work/delivery.tar.gz into the directory /home/labuser/work/unpacked, so that unpacked/delivery/manifest.txt exists.","verification_script":"grep -q arabica /home/labuser/work/unpacked/delivery/manifest.txt\n","hint_context":"tar -xzf ARCHIVE -C DIR extracts into DIR (which must exist - mkdir it first). List first with tar -tzf to see what is inside.","explanation_context":"x extracts, -C changes into a directory first. Always list an archive from a stranger before extracting it - it could contain absolute paths or overwrite your files.","points":25,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('b70801f1-c42e-5e7f-a27c-99564232c1c1', '66ce2671-166b-51c5-9017-75b87e77f60e', '7acb13d9-2540-590b-a259-a8a1fec74c29', 1, 'Which bash do we have?', $md$Use the Debian package tools to save the installed version of the bash package into answers/bash-version.txt (the version string only, for example 5.0-6ubuntu1).$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/bash-version.txt)" = "$(dpkg-query -W -f='${Version}' bash)" ]
$script$, 'dpkg -l bash shows it in a table; dpkg-query -W -f=''${Version}'' bash prints only the version.', 'dpkg is the low-level tool that knows every installed .deb package; apt sits on top of it and adds downloading and dependency resolution.', 15, false, true),
('4706ec9a-fc23-576b-b422-ec8c1ba46e00', '66ce2671-166b-51c5-9017-75b87e77f60e', '3bcb7d63-2da2-57d1-8a38-c43668065aa3', 2, 'Who installed this file?', $md$Find which package installed the file /usr/bin/jq and save just the package name into answers/jq-owner.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/jq-owner.txt)" = "$(dpkg -S /usr/bin/jq | cut -d: -f1)" ]
$script$, 'dpkg -S PATH searches installed packages for a file and prints package-name - path.', 'dpkg -S (search) maps a file back to its package, and dpkg -L PACKAGE does the reverse. On RHEL the same questions are rpm -qf FILE and rpm -ql PACKAGE.', 15, false, true),
('55ff6aa1-6f38-5beb-8363-d08e513fe2fb', '66ce2671-166b-51c5-9017-75b87e77f60e', '6e44b33b-1608-5cef-97f9-904682b036c5', 3, 'Which shelf is heaviest?', $md$Save the name of the largest subdirectory of /home/labuser/work/storeroom (just the name, like cups) into answers/biggest-dir.txt.$md$, $script$want=$(du -s /home/labuser/work/storeroom/*/ | sort -n | tail -1 | awk '{print $2}' | xargs basename)
[ "$(tr -d '[:space:]' < /home/labuser/work/answers/biggest-dir.txt)" = "$want" ]
$script$, 'du -sh storeroom/* shows one total per subdirectory; pipe through sort -h to rank them.', 'du measures what files actually use on disk, df measures whole filesystems. When df says a disk is full, du -sh /* | sort -h is how you walk down to the culprit.', 20, false, true),
('316e0a15-515a-5404-990e-dfb5ce9039e5', '66ce2671-166b-51c5-9017-75b87e77f60e', '4ba88926-3372-5910-b83e-af606d3d0ec3', 4, 'Back up the storeroom', $md$Create the compressed archive /home/labuser/work/backups/storeroom.tar.gz containing the storeroom directory. Paths inside the archive must start with storeroom/ (not /home/...).$md$, $script$a=/home/labuser/work/backups/storeroom.tar.gz
gzip -t $a && tar -tzf $a | grep -q '^storeroom/beans/arabica.bin$' && ! tar -tzf $a | grep -q '^/\|^home/'
$script$, 'Run tar from inside /home/labuser/work so the paths are relative - tar -czf backups/storeroom.tar.gz storeroom. c create, z gzip, f file name.', 'tar stores paths exactly as you give them. Archiving a relative path means it can be extracted anywhere; tar -tzf lists the contents without extracting.', 25, false, true),
('d8c63b7e-2443-5b3d-8b5a-a4bf5d94e724', '66ce2671-166b-51c5-9017-75b87e77f60e', '73cac90e-b532-5266-86ae-af99b62a29a2', 5, 'Unpack the delivery', $md$Extract /home/labuser/work/delivery.tar.gz into the directory /home/labuser/work/unpacked, so that unpacked/delivery/manifest.txt exists.$md$, $script$grep -q arabica /home/labuser/work/unpacked/delivery/manifest.txt
$script$, 'tar -xzf ARCHIVE -C DIR extracts into DIR (which must exist - mkdir it first). List first with tar -tzf to see what is inside.', 'x extracts, -C changes into a directory first. Always list an archive from a stranger before extracting it - it could contain absolute paths or overwrite your files.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '66ce2671-166b-51c5-9017-75b87e77f60e', updated_at = now()
WHERE id = '50515b20-5794-5c5f-83ed-c0d96f5353b1' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2ea86632-24aa-5064-9822-9744733340de', '00000000-0000-0000-0000-000000000001', 'mcq', 'apt install redis fails with 404 Not Found for a .deb file. What should you r...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('437cc6ba-c225-5157-8f4b-6dff7d58761a', '2ea86632-24aa-5064-9822-9744733340de', 1, $json${"prompt":"apt install redis fails with 404 Not Found for a .deb file. What should you run first?","multiple":false,"options":[{"id":"a","text":"sudo apt update","is_correct":true},{"id":"b","text":"sudo apt purge redis","is_correct":false},{"id":"c","text":"sudo dpkg -i redis","is_correct":false},{"id":"d","text":"sudo reboot","is_correct":false}],"explanation":"Stale package lists point to versions the mirror has removed; apt update refreshes them. Purge removes something not installed, dpkg -i needs a local file, and rebooting does not refresh lists."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a51bd6fd-8267-5c77-9ddc-700f46e2b598', '00000000-0000-0000-0000-000000000001', 'mcq', 'A strange binary /usr/bin/foo appeared. How do you find which package install...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('027df9f6-edf4-5f7a-b370-37e7f73a93c4', 'a51bd6fd-8267-5c77-9ddc-700f46e2b598', 1, $json${"prompt":"A strange binary /usr/bin/foo appeared. How do you find which package installed it on Ubuntu?","multiple":false,"options":[{"id":"a","text":"dpkg -S /usr/bin/foo","is_correct":true},{"id":"b","text":"dpkg -L /usr/bin/foo","is_correct":false},{"id":"c","text":"apt show /usr/bin/foo","is_correct":false},{"id":"d","text":"rpm -qf /usr/bin/foo","is_correct":false}],"explanation":"dpkg -S searches installed packages for a path. dpkg -L lists files of a package name, apt show takes a package name, and rpm -qf is the RHEL equivalent."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('694082bb-6c8e-50a2-be2e-25c2aaa05d63', '00000000-0000-0000-0000-000000000001', 'mcq', 'df -h shows / at 40% but creating files fails with ''No space left on device''....', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f09f1c12-6e3f-5769-8d34-9fbc7ec5ce63', '694082bb-6c8e-50a2-be2e-25c2aaa05d63', 1, $json${"prompt":"df -h shows / at 40% but creating files fails with 'No space left on device'. What do you check?","multiple":false,"options":[{"id":"a","text":"df -i, because the filesystem may be out of inodes","is_correct":true},{"id":"b","text":"free -h","is_correct":false},{"id":"c","text":"lsblk","is_correct":false},{"id":"d","text":"Nothing; df is wrong","is_correct":false}],"explanation":"Every file needs an inode; millions of tiny files can exhaust them while space remains. free shows memory, lsblk shows devices and sizes, and df is accurate."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('10ca2c07-6b64-52a8-a0aa-a328dfd035ea', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why should /etc/fstab refer to a disk by UUID, and what do you run before reb...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('56bca73a-db41-516e-b385-d13106b0cb76', '10ca2c07-6b64-52a8-a0aa-a328dfd035ea', 1, $json${"prompt":"Why should /etc/fstab refer to a disk by UUID, and what do you run before rebooting?","multiple":false,"options":[{"id":"a","text":"Device names can change between boots; test with sudo mount -a","is_correct":true},{"id":"b","text":"UUIDs are faster; test with df -h","is_correct":false},{"id":"c","text":"Device names only work for USB; test with lsblk","is_correct":false},{"id":"d","text":"fstab rejects /dev names; no test needed","is_correct":false}],"explanation":"A filesystem UUID never changes while /dev names can be reordered. mount -a applies every fstab line now, so mistakes appear before they can stop the boot."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('894b06d9-d953-52fc-b4c5-412a9a64f6a3', '00000000-0000-0000-0000-000000000001', 'mcq', 'You ran sudo lvextend -L +20G /dev/vg_data/lv_srv, but df -h /srv/data shows ...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('17c5716d-c1b0-5172-9fc8-684e5e97cde3', '894b06d9-d953-52fc-b4c5-412a9a64f6a3', 1, $json${"prompt":"You ran sudo lvextend -L +20G /dev/vg_data/lv_srv, but df -h /srv/data shows the old size. Why?","multiple":false,"options":[{"id":"a","text":"The filesystem was not grown; use lvextend -r or run resize2fs/xfs_growfs","is_correct":true},{"id":"b","text":"You must reboot","is_correct":false},{"id":"c","text":"LVM changes take 24 hours","is_correct":false},{"id":"d","text":"df caches sizes","is_correct":false}],"explanation":"The LV grew but the filesystem inside still has its old size. -r grows both. No reboot or waiting is needed, and df reads live values."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('39834288-b44b-509b-84a6-136c37dba8db', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command lists what is inside backup.tar.gz without extracting it?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('10ce7b01-a828-5c39-bb83-0be6d1981eb5', '39834288-b44b-509b-84a6-136c37dba8db', 1, $json${"prompt":"Which command lists what is inside backup.tar.gz without extracting it?","multiple":false,"options":[{"id":"a","text":"tar -tzf backup.tar.gz","is_correct":true},{"id":"b","text":"tar -xzf backup.tar.gz","is_correct":false},{"id":"c","text":"tar -czf backup.tar.gz","is_correct":false},{"id":"d","text":"gzip -d backup.tar.gz","is_correct":false}],"explanation":"t = tell (list). x extracts, c creates (and would overwrite the archive), and gzip -d decompresses the file in place."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('38883d40-6636-5e68-84e2-be84b426a31f', '00000000-0000-0000-0000-000000000001', 'mcq', 'You run rsync -av --delete src /backup/src and find /backup/src/src created. ...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b5f5e95e-a12c-5d6e-9133-8244b98e4ef4', '38883d40-6636-5e68-84e2-be84b426a31f', 1, $json${"prompt":"You run rsync -av --delete src /backup/src and find /backup/src/src created. What went wrong?","multiple":false,"options":[{"id":"a","text":"Without a trailing slash, rsync copies the directory itself; use src/ to copy its contents","is_correct":true},{"id":"b","text":"--delete creates extra directories","is_correct":false},{"id":"c","text":"-a means append a directory","is_correct":false},{"id":"d","text":"rsync always nests directories","is_correct":false}],"explanation":"src/ means the contents, src means the directory. --delete removes extra files, -a is archive mode, and rsync only nests when told to copy the directory."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('85c80d58-0548-5571-90b4-e59b43796d44', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 6): your nightly backup timer missed its 02:30 run because at...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('6171ea91-c335-5bc7-9d3d-602314f9af60', '85c80d58-0548-5571-90b4-e59b43796d44', 1, $json${"prompt":"Review (chapter 6): your nightly backup timer missed its 02:30 run because atlas was powered off. Which setting makes it run at the next boot?","multiple":false,"options":[{"id":"a","text":"Persistent=true in the [Timer] section","is_correct":true},{"id":"b","text":"Restart=always in the [Service] section","is_correct":false},{"id":"c","text":"WantedBy=multi-user.target","is_correct":false},{"id":"d","text":"@reboot in the crontab of the timer","is_correct":false}],"explanation":"Persistent=true makes a timer catch up on missed runs. Restart= is about crashing services, WantedBy is how enabling hooks in, and timers do not use crontabs."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('4f67294f-50d6-51f2-a4e2-6105708132fc', '00000000-0000-0000-0000-000000000001', 'Quiz: Packages, Disks and Backups', 'linux-storeroom-quiz', 'Quiz covering Chapter 7: The Storeroom - Packages, Disks and Backups.', 'mcq', 'published', 'module', '07329dd3-5b0b-569f-bc30-70db38b74151', 12, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '4f67294f-50d6-51f2-a4e2-6105708132fc' AND question_id NOT IN ('2ea86632-24aa-5064-9822-9744733340de', 'a51bd6fd-8267-5c77-9ddc-700f46e2b598', '694082bb-6c8e-50a2-be2e-25c2aaa05d63', '10ca2c07-6b64-52a8-a0aa-a328dfd035ea', '894b06d9-d953-52fc-b4c5-412a9a64f6a3', '39834288-b44b-509b-84a6-136c37dba8db', '38883d40-6636-5e68-84e2-be84b426a31f', '85c80d58-0548-5571-90b4-e59b43796d44');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('1cca7b8a-082c-527a-9de1-bcbcade5a725', '4f67294f-50d6-51f2-a4e2-6105708132fc', '2ea86632-24aa-5064-9822-9744733340de', '437cc6ba-c225-5157-8f4b-6dff7d58761a', 0, 2),
('f5613d57-1cd2-5e62-8bfd-2925a551b29d', '4f67294f-50d6-51f2-a4e2-6105708132fc', 'a51bd6fd-8267-5c77-9ddc-700f46e2b598', '027df9f6-edf4-5f7a-b370-37e7f73a93c4', 1, 2),
('851e485d-644b-56bf-846d-f8d32610b290', '4f67294f-50d6-51f2-a4e2-6105708132fc', '694082bb-6c8e-50a2-be2e-25c2aaa05d63', 'f09f1c12-6e3f-5769-8d34-9fbc7ec5ce63', 2, 2),
('08f01cdf-58e4-5845-81bd-6d038785d4d3', '4f67294f-50d6-51f2-a4e2-6105708132fc', '10ca2c07-6b64-52a8-a0aa-a328dfd035ea', '56bca73a-db41-516e-b385-d13106b0cb76', 3, 2),
('dfce1eb4-2826-5904-9313-1aa096621143', '4f67294f-50d6-51f2-a4e2-6105708132fc', '894b06d9-d953-52fc-b4c5-412a9a64f6a3', '17c5716d-c1b0-5172-9fc8-684e5e97cde3', 4, 2),
('cdb1e30a-109f-5255-b605-e903953fb200', '4f67294f-50d6-51f2-a4e2-6105708132fc', '39834288-b44b-509b-84a6-136c37dba8db', '10ce7b01-a828-5c39-bb83-0be6d1981eb5', 5, 2),
('2b83f197-a609-5723-a051-5c88370c1a08', '4f67294f-50d6-51f2-a4e2-6105708132fc', '38883d40-6636-5e68-84e2-be84b426a31f', 'b5f5e95e-a12c-5d6e-9133-8244b98e4ef4', 6, 2),
('e8816948-b81c-5440-800a-6f1c176e9ae6', '4f67294f-50d6-51f2-a4e2-6105708132fc', '85c80d58-0548-5571-90b4-e59b43796d44', '6171ea91-c335-5bc7-9d3d-602314f9af60', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('07329dd3-5b0b-569f-bc30-70db38b74151', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', 'Quiz: Packages, Disks and Backups', 'assessment', 6, 10, '4f67294f-50d6-51f2-a4e2-6105708132fc')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 8: Talking to the World - Networking
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 8: Talking to the World - Networking', 8, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ed72dd0b-9dd2-5d1c-a2fa-69f7fc9db327', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'IP Addresses, Subnets and Ports', 'notes', 0, $md$## Why this matters

> **Tuesday, week 2.** The payment provider emails: *we can't reach your
> server*. Rhea: "Before you blame them, prove atlas is listening. Every service
> has an address and a door number."

Every network problem is described in addresses and ports. Without these words
you cannot even read the error message.

## Mental model: street address and door number

```
   IP address = the building           port = the door
   10.0.0.42                            :443  (HTTPS)

   client 203.0.113.5:51522  ------>  atlas 10.0.0.42:443  (nginx)
          (random high port)                (well-known port)
```

- An **IP address** identifies a network interface (a machine's connection).
- A **port** (0-65535) identifies one service on that machine.
- A **connection** is the pair of both ends: client IP:port to server IP:port.
- **TCP** is a reliable conversation (web, SSH, databases). **UDP** is send and
  forget (DNS lookups, video, metrics).

> **Memory hook:** the IP is the **street address of the café**, the port is
> **which door**: front door 80 for walk-ins, the locked side door 22 for staff.

## Special addresses

| Address | Meaning |
|---|---|
| `127.0.0.1` / `::1` | **localhost**: this machine; traffic never leaves it |
| `10.x.x.x`, `172.16-31.x.x`, `192.168.x.x` | private networks (offices, clouds, home) |
| `0.0.0.0` (in "listening on") | every interface on this machine |
| `169.254.x.x` | link-local: no DHCP answer was received |
| `2001:db8::/32`, `fe80::/10` | IPv6 documentation / link-local |

Private addresses are not reachable from the internet directly; a router or load
balancer translates (NAT) or forwards.

## Subnets in one picture

`10.0.0.0/24` is **CIDR** notation: the first 24 bits name the network, the rest
name hosts.

```
 10.0.0.0/24   network bits: 10.0.0     hosts: .0 - .255    256 addresses
 10.0.0.0/16   network bits: 10.0       hosts: 0.0 - 255.255  65,536 addresses
 10.0.0.42/32  exactly one address
```

Machines in the same subnet talk directly. To reach anything else they send
packets to the **default gateway** (the router).

## Well-known ports

| Port | Service | Port | Service |
|---|---|---|---|
| 22 | SSH | 443 | HTTPS |
| 25 | SMTP (mail) | 3306 | MySQL |
| 53 | DNS | 5432 | PostgreSQL |
| 80 | HTTP | 6379 | Redis |
| 123 | NTP (time) | 8080 | common app port |

`/etc/services` maps names to numbers on every machine.

Ports below 1024 are **privileged**: only root (or a process with the
`CAP_NET_BIND_SERVICE` capability) can listen on them. That is why apps often
listen on 8080 behind nginx on 80/443.

## See it work

```bash
grep -wE '^(ssh|https|postgresql)' /etc/services
```

What this does: looks up three service names. Expected output:

```
ssh		22/tcp				# SSH Remote Login Protocol
https		443/tcp				# http protocol over TLS/SSL
https		443/udp				# HTTP/3
postgresql	5432/tcp	postgres	# PostgreSQL Database
```

## Try it

Brewbot listens on `127.0.0.1:8080`. Can the payment provider at
`203.0.113.5` connect to it directly? And how many addresses does
`192.168.1.0/24` contain?

<details>
<summary>Show answer</summary>

No. `127.0.0.1` is localhost; only programs on atlas itself can connect. A
`/24` holds 256 addresses (usually 254 usable hosts).

</details>

## Common mistakes

- **Thinking `127.0.0.1` means "my server's address".** It means "whatever
  machine you are on". On your laptop, it is your laptop.
- **Binding an app to `127.0.0.1` and expecting outside access.** Bind
  `0.0.0.0` (or the specific interface), or put a proxy in front.
- **Running an app as root just to use port 80.** Use a reverse proxy or a
  capability instead.

## Remember

- IP = which machine, port = which service; TCP reliable, UDP send-and-forget.
- localhost `127.0.0.1`; listen `0.0.0.0` = all interfaces.
- `/24` = 256 addresses; other subnets go through the default gateway.
- 22 SSH, 53 DNS, 80 HTTP, 443 HTTPS, 5432 PostgreSQL; below 1024 = privileged.

**Self-check:**

1. What does listening on `0.0.0.0:8080` mean?
2. Which ranges are private IPv4 networks?
3. Why do apps often use port 8080 instead of 80?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5bf81568-4aa0-57ea-a68e-7d55082e4ec4', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'Inspecting the Network: ip, ss, ping and traceroute', 'notes', 1, $md$## Why this matters

"Is atlas even on the network? Is brewbot listening? On which address? Can we
reach the gateway?" Four commands answer these in under a minute, and `ss` is
the single most useful networking command on a server.

## Mental model: check the building from the inside out

```
 1. Do I have an address?        ip a
 2. Do I know the way out?       ip r
 3. What is listening here?      ss -tulpn
 4. Can I reach the other side?  ping / traceroute / curl
```

Work in that order. Each step assumes the previous one is fine.

## See it work

### Interfaces and addresses

```bash
ip a            # short for: ip address show
```

Expected output (abridged):

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
    inet 127.0.0.1/8 scope host lo
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
    inet 10.0.0.42/24 brd 10.0.0.255 scope global eth0
```

`lo` is loopback (localhost). `eth0` is the real interface with
`10.0.0.42` in a `/24`. `UP` means the link is active. (`ifconfig` is the old,
deprecated tool for the same thing.)

### Routes

```bash
ip r            # ip route show
```

```
default via 10.0.0.1 dev eth0
10.0.0.0/24 dev eth0 proto kernel scope link src 10.0.0.42
```

`default via 10.0.0.1` is the **gateway**: everything not in `10.0.0.0/24` goes
there. No default route = no internet.

### What is listening: ss

```bash
ss -tulpn
```

```
Netid State  Local Address:Port  Peer Address:Port Process
tcp   LISTEN 0.0.0.0:22          0.0.0.0:*         users:(("sshd",pid=812,fd=3))
tcp   LISTEN 127.0.0.1:8080      0.0.0.0:*         users:(("brewbot",pid=1040,fd=6))
tcp   LISTEN 0.0.0.0:443         0.0.0.0:*         users:(("nginx",pid=901,fd=7))
```

Flags: `t` TCP, `u` UDP, `l` listening only, `p` owning process (needs root to
see other users' processes), `n` numeric (no name lookups).

Note `127.0.0.1:8080`: brewbot only listens on localhost, so nobody outside can
reach it directly. That is fine behind nginx, but it is also the number one
reason for "the app runs but I can't connect".

```bash
ss -tn                       # current TCP connections
ss -tn state established '( dport = :5432 )'   # connections to PostgreSQL
ss -s                        # summary counts
```

(`netstat -tulpn` is the old equivalent.)

### Reachability

```bash
ping -c 3 10.0.0.1           # is the host answering? (ICMP, may be blocked)
tracepath example.com        # every hop on the way (or traceroute, mtr)
mtr -rwc 10 example.com      # ping + traceroute report: where does loss start?
```

A failed `ping` does not prove a host is down: many firewalls drop ICMP. Test
the real port with `curl` or `nc` (lessons 3 and 7).

```bash
hostname -I                  # this machine's IP addresses, one line
ip -br a                     # brief: one line per interface
```

## Try it

On atlas, the payment provider cannot connect to brewbot on port 8080. Which
command shows whether brewbot listens, and on which address? What in the output
would explain the problem?

<details>
<summary>Show answer</summary>

```bash
ss -tulpn | grep 8080
```

If the local address is `127.0.0.1:8080`, brewbot only accepts connections from
atlas itself. It needs to listen on `0.0.0.0:8080` (or be reached through nginx).

</details>

## Common mistakes

- **Trusting ping.** ICMP is often blocked. Test the actual TCP port.
- **`ss -tulpn` without root.** Other users' process names are hidden; use
  `sudo`.
- **Forgetting `-n`.** Without it, ss resolves names and ports, which can be slow
  and hides the numbers you need.

## Remember

- Inside out: `ip a`, `ip r`, `ss -tulpn`, then ping/traceroute/curl.
- `default via X` is the gateway.
- `ss -tulpn`: who listens on which address and port.
- `127.0.0.1:PORT` = local only; `0.0.0.0:PORT` = all interfaces.

**Self-check:**

1. Which command shows the default gateway?
2. What do the letters in `ss -tulpn` stand for?
3. Why is a failed ping not proof that a server is down?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2d5afd41-c59f-54d6-b0f7-5682eb472299', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'Talking HTTP with curl (and jq)', 'notes', 2, $md$## Why this matters

Browsers hide everything that matters for debugging: status codes, headers,
redirects, TLS errors, timings. `curl` shows all of it from a terminal, works
over SSH, and fits in scripts. It is how you prove "the API is up" in one line.

## Mental model: a waiter who reports everything

You give curl a URL; it walks to the server, orders, and reports back exactly
what happened.

```
 curl -v https://orbit.coffee/api/status
   * resolve name (DNS)  -> * connect TCP :443 -> * TLS handshake
   > GET /api/status HTTP/2        (request: method, path, headers)
   < HTTP/2 200                    (response: status code, headers)
   < content-type: application/json
   {"healthy": true}               (body)
```

Status codes in one breath: **2xx** success, **3xx** redirect, **4xx** your
request is wrong (404 not found, 401/403 not allowed), **5xx** the server failed
(500 error, 502 bad gateway, 503 unavailable, 504 timeout).

## See it work

In the lab, start a tiny web server first (it serves `~/work/site`):

```bash
nohup python3 -m http.server 8080 --directory ~/work/site >/dev/null 2>&1 &
curl http://localhost:8080/
```

What this does: Python's built-in server listens on port 8080; `curl` fetches
the page and prints the body:

```
<!doctype html>
<title>Orbit Coffee</title>
<h1>Orbit Coffee - fresh beans, roasted on atlas</h1>
```

### Headers only

```bash
curl -I http://localhost:8080/
```

```
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.12.3
Date: Wed, 14 Oct 2026 10:30:00 GMT
Content-type: text/html
Content-Length: 87
Last-Modified: Wed, 14 Oct 2026 09:00:00 GMT
```

`-I` sends a HEAD request: "is it up, and what is answering?"

### The options you need

```bash
curl -v https://orbit.coffee            # verbose: DNS, TLS, request, response
curl -s URL | jq .                      # -s silent (no progress bar) + pretty JSON
curl -sf URL || echo "DOWN"             # -f: exit non-zero on HTTP errors (scripts!)
curl -L URL                             # follow redirects
curl -o file.tar.gz URL                 # save to a file (or: wget URL)
curl -X POST -H 'Content-Type: application/json' -d '{"qty":2}' URL
curl -m 5 URL                           # give up after 5 seconds
curl -o /dev/null -s -w '%{http_code} %{time_total}\n' URL   # status and timing only
curl --resolve orbit.coffee:443:10.0.0.42 https://orbit.coffee/   # test a server before DNS points to it
```

### JSON with jq

```bash
curl -s http://localhost:8080/status.json | jq -r .version
```

```
2.4.1
```

`jq .` pretty-prints; `.version` picks one field; `-r` prints raw text without
quotes. `jq '.items[] | .name'` walks arrays.

## Try it

Write one command that prints only the HTTP status code of
`http://localhost:8080/missing`, and say which family it belongs to.

<details>
<summary>Show answer</summary>

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/missing
```

It prints `404`: a 4xx, client-side error (the page does not exist).

</details>

## Common mistakes

- **Using curl without `-f` in scripts.** A 500 page still exits 0, so the
  script thinks all is well.
- **Ignoring redirects.** A `301` with an empty body is not "down"; add `-L` or
  read the `Location` header.
- **`-k` (skip TLS checks) in production scripts.** It hides expired or wrong
  certificates. Fix the certificate instead.
- **Forgetting quotes around URLs with `&` or `?`.** The shell treats `&` as
  "run in background".

## Remember

- `curl URL` body, `-I` headers, `-v` everything, `-s` quiet, `-f` fail on
  errors, `-L` follow.
- `-w '%{http_code} %{time_total}'` = status and timing.
- 2xx ok, 3xx redirect, 4xx client error, 5xx server error.
- `jq -r .field` extracts JSON values.

**Self-check:**

1. What does a 502 from nginx tell you?
2. Why use `-f` in health-check scripts?
3. How do you show only the response headers?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('914dcaa1-93db-55c5-9bb3-d537764eba2a', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'DNS: Turning Names into Addresses', 'notes', 3, $md$## Why this matters

`curl https://api.payments.example` fails, but `curl https://203.0.113.10`
works. The network is fine; the name lookup is broken. "It's always DNS" is a
sysadmin joke because it is so often true.

## Mental model: the phone book chain

Programs ask the system to resolve a name. The system checks, in order:

```
 program --> /etc/nsswitch.conf ("hosts: files dns")
               |
               |-- 1. files: /etc/hosts        local overrides, checked FIRST
               |-- 2. dns:   the resolver in /etc/resolv.conf
                                 (on Ubuntu: systemd-resolved at 127.0.0.53)
                                     |
                                     v
                             DNS servers --> answer: 203.0.113.10 (cached for TTL seconds)
```

Record types you will meet:

| Type | Maps | Example |
|---|---|---|
| `A` / `AAAA` | name to IPv4 / IPv6 | `orbit.coffee -> 203.0.113.10` |
| `CNAME` | alias to another name | `www -> orbit.coffee` |
| `MX` | mail servers for a domain | `10 mail.orbit.coffee` |
| `TXT` | text (SPF, verification) | `"v=spf1 ..."` |
| `NS` | which servers are authoritative | `ns1.example.net` |

**TTL** (time to live) is how long an answer may be cached. After you change a
record, old answers live on until their TTL expires.

## See it work

```bash
getent hosts localhost
cat /etc/hosts
cat /etc/resolv.conf
```

What this does: resolves a name the way programs do (including `/etc/hosts`),
then shows the two config files. Expected output on Ubuntu (similar; inside a
container `resolv.conf` is written by the container runtime instead):

```
::1             localhost ip6-localhost ip6-loopback
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
nameserver 127.0.0.53
options edns0 trust-ad
```

### Asking DNS directly

`dig` (package `dnsutils` / `bind-utils`) talks to DNS servers and shows the raw
answer:

```bash
dig orbit.coffee +short          # just the address
dig MX orbit.coffee +short       # mail servers
dig @1.1.1.1 orbit.coffee        # ask a specific server
dig +trace orbit.coffee          # follow the chain from the root servers
resolvectl status                # systemd-resolved: which DNS server per interface
```

`dig` bypasses `/etc/hosts`; `getent hosts` does not. When they disagree, a
stale `/etc/hosts` line is the usual reason.

### /etc/hosts: local overrides

```
127.0.0.1   localhost
10.0.0.42   atlas atlas.internal
```

Pin a name to an IP on one machine, for example to test a new server before
switching DNS. Remove the line afterwards: forgotten entries cause confusing
outages months later.

> **Memory hook:** "**It's always DNS.**" When a name fails but the IP works,
> the problem is name resolution, not the network.

## Try it

`curl https://api.payments.example` fails with "Could not resolve host", but the
IP works. List three things you check, in order.

<details>
<summary>Show answer</summary>

1. `getent hosts api.payments.example` and `grep payments /etc/hosts`: is there a
   stale local override?
2. `cat /etc/resolv.conf` / `resolvectl status`: which DNS server is used, and is
   it reachable?
3. `dig api.payments.example` and `dig @1.1.1.1 api.payments.example`: does
   another resolver answer? If yes, your resolver is the problem.

</details>

## Common mistakes

- **Testing with `ping` or `dig` only.** `dig` ignores `/etc/hosts`; use
  `getent hosts` to see what programs see.
- **Changing a record and expecting instant effect.** Old answers stay cached
  until the TTL expires. Lower the TTL a day before a migration.
- **Editing `/etc/resolv.conf` by hand on Ubuntu.** It is managed by
  systemd-resolved; configure netplan or `resolved.conf` instead.

## Remember

- Lookup order: `/etc/hosts`, then DNS from `/etc/resolv.conf`.
- `getent hosts NAME` = what programs see; `dig NAME` = what DNS says.
- A/AAAA address, CNAME alias, MX mail, TXT text; TTL = cache time.
- Name fails but IP works: it's DNS.

**Self-check:**

1. Which file is checked before DNS?
2. Why can `dig` and `getent` give different answers?
3. What is a TTL?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1a802dd5-66ee-575e-9a29-585477a8fca7', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'SSH: Keys, Config, Copying and Tunnels', 'notes', 4, $md$## Why this matters

SSH is the staff door to every server. You will use it dozens of times a day.
Keys instead of passwords, a config file instead of long commands, and tunnels
for reaching private databases make you faster and safer.

## Mental model: lock and key

- You generate a **key pair**: a **private key** (stays on your laptop, never
  shared) and a **public key** (safe to hand out).
- The public key goes into the server's `~/.ssh/authorized_keys`: you are
  installing your lock on that door.
- When you connect, the server challenges you; only the matching private key can
  answer.

> **Memory hook:** the public key is the **lock** you can fit to every door; the
> private key is the **only key**: never copy it, never share it.

```
 laptop                                  atlas
 ~/.ssh/id_ed25519      (private)        ~/.ssh/authorized_keys
 ~/.ssh/id_ed25519.pub  ---copy once--->   ssh-ed25519 AAAA... you@orbit
```

## See it work

These need the OpenSSH client and a server to talk to (not in the lab image).

```bash
ssh-keygen -t ed25519 -C "you@orbit"   # make a key pair; set a passphrase
ssh-copy-id deploy@10.0.0.42           # install your public key on the server
ssh deploy@10.0.0.42                   # log in, no password needed now
ssh -p 2222 deploy@10.0.0.42           # non-standard port
ssh deploy@atlas 'df -h /'             # run one command remotely
```

`ed25519` is the modern default key type: short, fast and strong.

### The config file saves typing

```
# ~/.ssh/config
Host atlas
    HostName 10.0.0.42
    User deploy
    Port 2222
    IdentityFile ~/.ssh/atlas_ed25519
```

Now `ssh atlas`, `scp file atlas:/tmp/` and `rsync ... atlas:` just work. One
`Host` block per server; `Host *` sets defaults for all.

### Permissions SSH insists on

SSH silently ignores keys and configs that others could read or change:

| Path | Mode |
|---|---|
| `~/.ssh` | `700` |
| private key, `config`, `authorized_keys` | `600` |
| your home directory | not group- or world-writable |

### Copying files

```bash
scp backup.tar.gz atlas:/tmp/          # copy to the server
scp atlas:/var/log/syslog .            # copy from it
rsync -avz site/ atlas:/srv/site/      # better for directories (only changes)
```

### Tunnels and jumps

```bash
ssh -L 5432:localhost:5432 atlas       # local port 5432 -> atlas's localhost:5432
ssh -J bastion deploy@10.0.0.42        # hop through a bastion host
```

With the `-L` tunnel open, your laptop's `psql -h localhost` reaches atlas's
database, which only listens on atlas's localhost. Nothing extra is exposed.

### Agent: type the passphrase once

```bash
eval "$(ssh-agent)" && ssh-add ~/.ssh/atlas_ed25519
```

The agent holds the unlocked key in memory for your session. Avoid
`ForwardAgent yes` to servers you do not fully trust: root there could use your
agent.

## Try it

Write a `~/.ssh/config` entry named `atlas` for address `10.0.0.42`, user
`deploy`, port `2222`, key `~/.ssh/atlas_ed25519`, and set the right
permissions.

<details>
<summary>Show answer</summary>

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat >> ~/.ssh/config <<'EOF'
Host atlas
    HostName 10.0.0.42
    User deploy
    Port 2222
    IdentityFile ~/.ssh/atlas_ed25519
EOF
chmod 600 ~/.ssh/config
```

</details>

## Common mistakes

- **Copying the private key to servers.** Only the `.pub` file ever leaves your
  laptop.
- **Too-open permissions.** `Permission denied (publickey)` is often a `~/.ssh`
  or home directory that others can write.
- **No passphrase on a laptop key.** A stolen laptop becomes access to every
  server. Use a passphrase plus the agent.
- **Testing sshd changes in your only session.** Keep a second session open
  (chapter 12).

## Remember

- `ssh-keygen -t ed25519`, `ssh-copy-id`, then `ssh user@host`.
- `~/.ssh/config` Host blocks: `HostName`, `User`, `Port`, `IdentityFile`.
- `~/.ssh` 700, keys and config 600.
- `scp`/`rsync` copy; `-L` tunnels; `-J` jumps through a bastion.

**Self-check:**

1. Which key goes into `authorized_keys`?
2. What does `ssh -L 5432:localhost:5432 atlas` do?
3. Why might SSH ignore a perfectly good key?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('82e9b27a-f5da-53a1-b629-7a360b89b0a0', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'Firewalls: ufw, firewalld and nftables', 'notes', 5, $md$## Why this matters

A firewall decides which packets may reach which port. Too open, and your
database is on the internet. Too closed, and the payment provider times out. And
one wrong rule over SSH can lock you out of your own server.

## Mental model: the bouncer at each door

```
 internet --> [ cloud security group ] --> [ host firewall (nftables) ] --> service
                 outside the machine            inside the kernel
```

- The kernel's packet filter is **netfilter**. You configure it with
  **nftables** (`nft`), the modern replacement for **iptables**.
- Friendly front ends write those rules for you: **ufw** on Ubuntu,
  **firewalld** (`firewall-cmd`) on RHEL/Fedora.
- In the cloud there is often a second firewall outside the machine (security
  groups). Both must allow the traffic.

Default policy for a server: **deny incoming, allow outgoing**, then open only
what you serve.

## See it work

These need root (not available in the lab).

```bash
sudo ufw status verbose
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp            # ALWAYS allow SSH before enabling!
sudo ufw allow 443/tcp
sudo ufw allow from 10.0.0.0/24 to any port 5432 proto tcp   # DB only from the office
sudo ufw enable
sudo ufw status numbered
sudo ufw delete 3                # remove rule number 3
```

Expected output of `ufw status`:

```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
5432/tcp                   ALLOW       10.0.0.0/24
```

### firewalld (RHEL family)

```bash
sudo firewall-cmd --list-all
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.0.0.0/24 port port=5432 protocol=tcp accept'
sudo firewall-cmd --reload
```

`--permanent` writes the config; `--reload` applies it. Without `--permanent`,
the rule is lost at the next reload or reboot.

### Looking underneath

```bash
sudo nft list ruleset            # what the kernel actually enforces
sudo iptables -L -n -v           # legacy view (often backed by nftables now)
```

### Reading the symptoms

> **Memory hook:** **refused = nobody home** (you reached the machine, but
> nothing listens on that port). **timed out = the gate is locked** (a firewall
> silently dropped the packets, or routing is broken).

| Error | Usual cause |
|---|---|
| `Connection refused` | service down, wrong port, or bound to 127.0.0.1 |
| `Connection timed out` | firewall / security group drop, or no route |
| `No route to host` | host down or a firewall actively rejecting |

## Try it

You are about to enable ufw on atlas over SSH. Which rule must exist first, and
how do you then let only the office network (`10.0.0.0/24`) reach PostgreSQL?

<details>
<summary>Show answer</summary>

```bash
sudo ufw allow 22/tcp
sudo ufw allow from 10.0.0.0/24 to any port 5432 proto tcp
sudo ufw enable
```

Without the SSH rule, enabling ufw cuts your own session.

</details>

## Common mistakes

- **Enabling the firewall before allowing SSH.** Instant lockout; you need the
  cloud console to recover.
- **Opening the database to `Anywhere`.** Limit by source network.
- **Fixing only the host firewall.** The cloud security group must allow it too.
- **firewalld rules without `--permanent`.** Gone after reload.

## Remember

- Default deny incoming, allow outgoing; open only what you serve.
- ufw: `allow 22/tcp` first, then `enable`; `status numbered`, `delete N`.
- firewalld: `--permanent` + `--reload`; nftables underneath (`nft list ruleset`).
- Refused = nothing listening; timed out = something dropping.

**Self-check:**

1. What is the difference between "connection refused" and "timed out"?
2. Why allow port 22 before `ufw enable`?
3. What does `--permanent` do in firewalld?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('58612421-3b63-54ae-acd4-4fd18e2cc748', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'The Network Debugging Toolbox: nc, tcpdump and openssl', 'notes', 6, $md$## Why this matters

Sometimes `curl` is not enough: the service is not HTTP, you need to know if
packets arrive at all, or the TLS certificate is the problem. Three tools cover
those cases, and a fallback works even on minimal images.

## Mental model: three levels of looking

```
 Can I open the door?          nc -vz host port         (TCP connect test)
 What crosses the wire?        tcpdump                  (watch the packets)
 Is the TLS lock right?        openssl s_client         (certificate, dates, chain)
```

## See it work

### nc (netcat): any TCP port

```bash
nc -vz 10.0.0.42 5432       # can I connect to PostgreSQL?
nc -vz -w 3 10.0.0.42 6379  # give up after 3 seconds
```

```
Connection to 10.0.0.42 5432 port [tcp/postgresql] succeeded!
```

If `nc` is missing, bash itself can test a port:

```bash
timeout 3 bash -c '</dev/tcp/127.0.0.1/8080' && echo open || echo closed
```

`/dev/tcp/HOST/PORT` is a bash feature: opening it makes a TCP connection.

`nc -l 9000` listens on a port, which helps prove a firewall rule works before
the real service exists.

### tcpdump: watch the packets

```bash
sudo tcpdump -ni eth0 port 443                 # all traffic on 443
sudo tcpdump -ni any host 203.0.113.5          # one remote host
sudo tcpdump -ni eth0 'tcp[tcpflags] & tcp-syn != 0' -c 20   # new connection attempts
sudo tcpdump -ni eth0 port 8080 -w cap.pcap    # save for Wireshark
```

`-n` = no name lookups, `-i` = interface (`any` for all), `-c` = stop after N
packets. The killer question it answers: **do the packets even arrive?** If SYN
packets arrive and nothing answers, the service or host firewall is the issue. If
nothing arrives, look upstream (security group, routing).

### openssl: inspect TLS

```bash
echo | openssl s_client -connect orbit.coffee:443 -servername orbit.coffee 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

Expected output (similar):

```
subject=CN = orbit.coffee
issuer=C = US, O = Let's Encrypt, CN = R11
notBefore=Sep 20 00:00:00 2026 GMT
notAfter=Dec 19 23:59:59 2026 GMT
```

`notAfter` in the past = expired certificate. `-servername` sends SNI, needed
when one IP hosts many sites.

### Putting it together

```
 1. ss -tulpn on the server     is it listening, and where?
 2. curl / nc from the server   does it answer locally?
 3. nc from outside             does it answer remotely?
 4. tcpdump on the server       do packets arrive at all?
 5. openssl s_client            for TLS errors
```

## Try it

A Redis server at `10.0.0.50:6379` "does not work" from atlas. `nc` is not
installed. How do you check if the port is reachable?

<details>
<summary>Show answer</summary>

```bash
timeout 3 bash -c '</dev/tcp/10.0.0.50/6379' && echo open || echo closed
```

`open` means TCP connects (look at Redis auth/config next). `closed` quickly
means refused; `closed` after 3 seconds means timeout, so suspect a firewall.

</details>

## Common mistakes

- **tcpdump without `-n`.** It does DNS lookups for every packet, which is slow
  and adds its own traffic.
- **Capturing on the wrong interface.** Use `-i any` when unsure.
- **Forgetting `-servername`.** You may get the default certificate, not the
  site's.

## Remember

- `nc -vz host port` (or bash `/dev/tcp`) tests a TCP port.
- `tcpdump -ni IFACE port N` shows whether packets arrive.
- `openssl s_client ... | openssl x509 -noout -dates` checks certificates.
- Debug in layers: listen, local, remote, wire, TLS.

**Self-check:**

1. What does it mean if SYN packets arrive but nothing answers?
2. How do you test a port without `nc` or `curl`?
3. Which field shows when a certificate expires?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('05b5b666-8186-5ee0-86e5-aefff70dd17b', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'Lab: Prove Atlas Is Listening', 'notes', 7, $md$## Why this matters

The payment provider says they cannot reach atlas. Before blaming them, you
prove what is listening, what it answers, and how you would reach it over SSH.
Each task is checked automatically.

## Before you start

```bash
ls ~/work/site
ss -tln
```

What this does: shows the two files you will serve, and confirms nothing listens
on 8080 yet.

## Task 1: open the shop's front door

Serve `~/work/site` over HTTP on port 8080 with Python's built-in web server,
in the background so you keep your prompt.

[[lab-task:1]]

Check yourself: `ss -tln | grep 8080` shows a listener.

## Task 2: read the response headers

Save only the HTTP response headers of `http://localhost:8080/` into
`~/work/answers/headers.txt`.

[[lab-task:2]]

What you should see:

```
$ curl -I http://localhost:8080/
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.12.3
Content-type: text/html
...
```

## Task 3: ask the API a question

Fetch `http://localhost:8080/status.json` with curl and extract only the
`version` field with jq. Save that value (no quotes) into
`answers/api-version.txt`.

[[lab-task:3]]

## Task 4: a shortcut for SSH

Create `~/.ssh/config` with a host entry `atlas` for address `10.0.0.42`, user
`deploy`, port `2222`, key `~/.ssh/atlas_ed25519`. `~/.ssh` must be 700 and
the config 600. (There is no server to connect to; the check reads your file.)

[[lab-task:4]]

## Task 5: which doors are open?

Test which of the ports 8080, 8081 and 9090 on `127.0.0.1` accept a TCP
connection, and save the open ones, one per line, into
`answers/open-ports.txt`. `nc` is not installed; lesson 7 showed the bash
`/dev/tcp` trick.

[[lab-task:5]]

## Remember

- A server is a process listening on a port; `ss -tln` proves it.
- `curl -I` headers, `curl -s | jq -r .field` JSON.
- `~/.ssh/config` with 700/600 permissions.
- `bash -c '</dev/tcp/HOST/PORT'` tests a port anywhere.

> **End of day 8.** `ss -tulpn` showed brewbot listening on 127.0.0.1 only, and
> nginx's config had the wrong upstream port. One fix and the payment provider
> is happy. Rhea: "You're doing a lot of things by hand. Tomorrow, teach atlas
> to do them itself." Tom's note: "Lazy admins write scripts."
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('c6764360-64ae-5f00-b5c1-1284857edd59', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '05b5b666-8186-5ee0-86e5-aefff70dd17b', 'module', 'Lab: Prove Atlas Is Listening', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$mkdir -p /home/labuser/work
mkdir -p /home/labuser/work/site && chmod 777 /home/labuser/work/site
cat > /home/labuser/work/site/index.html <<'MFEOF'
<!doctype html>
<title>Orbit Coffee</title>
<h1>Orbit Coffee - fresh beans, roasted on atlas</h1>

MFEOF
chmod 666 /home/labuser/work/site/index.html
cat > /home/labuser/work/site/status.json <<'MFEOF'
{"service": "brewbot", "version": "2.4.1", "healthy": true, "orders_today": 128}

MFEOF
chmod 666 /home/labuser/work/site/status.json
w=/home/labuser/work
rm -rf $w/answers
mkdir -p $w/answers
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'a47bb5ca-ad33-5ed0-8073-791e40bc8528' AND id NOT IN ('01d41da1-b906-5a2a-9611-506ec83b7bc8', 'e781e94d-6f3e-5352-8ee4-942d46a25a8e', '6dab314a-0893-58b4-b906-1de5f8d99f06', '9ab214e9-e05b-5081-94ef-1c3b1831f85f', '51cac47c-06d0-54cf-bee7-5b566d35e589');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'a47bb5ca-ad33-5ed0-8073-791e40bc8528';
DELETE FROM lab_tasks WHERE lab_id = 'c6764360-64ae-5f00-b5c1-1284857edd59' AND id NOT IN ('65c3b575-649a-51e1-9a03-c5aef17b7d51', '0302c7ee-54c2-5b9e-ad11-e55a6d467c33', '7767e693-9768-5ff4-9515-7da35cfa1ef6', 'cce6963a-26ee-5b63-a41d-d3170d60b899', 'e26cd570-2169-5cf0-97de-ed00ef6f8760');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'c6764360-64ae-5f00-b5c1-1284857edd59';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('65c3b575-649a-51e1-9a03-c5aef17b7d51', 'c6764360-64ae-5f00-b5c1-1284857edd59', 1, 'Open the shop''s front door', $md$Serve the /home/labuser/work/site directory over HTTP on port 8080 using Python's built-in web server, running in the background so you keep your prompt.$md$, $script$curl -sf --max-time 3 http://localhost:8080/ | grep -q 'Orbit Coffee'
$script$, 'python3 -m http.server 8080 --directory /home/labuser/work/site serves a folder. Put nohup in front and an ampersand at the end to background it.', 'A server is just a process that listens on a port. localhost (127.0.0.1) is the loopback address - traffic that never leaves the machine.', 25, false, true),
('0302c7ee-54c2-5b9e-ad11-e55a6d467c33', 'c6764360-64ae-5f00-b5c1-1284857edd59', 2, 'Read the response headers', $md$Save only the HTTP response headers of http://localhost:8080/ into answers/headers.txt.$md$, $script$f=/home/labuser/work/answers/headers.txt
grep -q 'HTTP/1.[01] 200' $f && grep -qi '^Server: SimpleHTTP' $f && ! grep -q '<h1>' $f
$script$, 'curl -I sends a HEAD request and prints only the headers. Redirect the output with >.', 'Headers carry the status code, content type and server name. curl -I is the fastest way to ask "is it up, and what is answering?"', 20, false, true),
('7767e693-9768-5ff4-9515-7da35cfa1ef6', 'c6764360-64ae-5f00-b5c1-1284857edd59', 3, 'Ask the API a question', $md$Fetch http://localhost:8080/status.json with curl and use jq to extract only the version field. Save that value (no quotes) into answers/api-version.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/api-version.txt)" = 2.4.1 ]
$script$, 'curl -s URL | jq -r .version - the -s hides curl''s progress bar and jq -r prints raw text without quotes.', 'curl talks HTTP, jq slices JSON. Together they replace a browser for checking any API from a terminal.', 25, false, true),
('cce6963a-26ee-5b63-a41d-d3170d60b899', 'c6764360-64ae-5f00-b5c1-1284857edd59', 4, 'A shortcut for SSH', $md$Create ~/.ssh/config with a host entry named atlas that connects to the address 10.0.0.42 as the user deploy on port 2222, using the key file ~/.ssh/atlas_ed25519. The ~/.ssh directory must be accessible only by you (700) and the config file readable and writable only by you (600).$md$, $script$c=$HOME/.ssh/config
[ "$(stat -c %a $HOME/.ssh)" = 700 ] && [ "$(stat -c %a $c)" = 600 ] &&
grep -Eq '^\s*Host\s+atlas\s*$' $c && grep -Eiq '^\s*HostName\s+10\.0\.0\.42\s*$' $c &&
grep -Eiq '^\s*User\s+deploy\s*$' $c && grep -Eiq '^\s*Port\s+2222\s*$' $c &&
grep -Eiq '^\s*IdentityFile\s+~/\.ssh/atlas_ed25519\s*$' $c
$script$, 'One line Host atlas, then indented lines HostName, User, Port and IdentityFile. mkdir -p ~/.ssh, chmod 700 ~/.ssh, chmod 600 ~/.ssh/config.', 'With this entry, ssh atlas expands to ssh -i ~/.ssh/atlas_ed25519 -p 2222 deploy@10.0.0.42. SSH refuses keys and configs that other users can read or write.', 30, false, true),
('e26cd570-2169-5cf0-97de-ed00ef6f8760', 'c6764360-64ae-5f00-b5c1-1284857edd59', 5, 'Which doors are open?', $md$Test which of the ports 8080, 8081 and 9090 on 127.0.0.1 accept a TCP connection right now, and save the open port numbers, one per line, into /home/labuser/work/answers/open-ports.txt. nc is not installed, so use curl or bash's /dev/tcp.$md$, $script$f=/home/labuser/work/answers/open-ports.txt
[ -f $f ] || exit 1
want=$(for p in 8080 8081 9090; do timeout 2 bash -c "</dev/tcp/127.0.0.1/$p" 2>/dev/null && echo $p; done)
[ -n "$want" ] && [ "$(grep -o '[0-9]\+' $f | sort -n | tr '\n' ' ')" = "$(echo $want | tr ' ' '\n' | sort -n | tr '\n' ' ')" ]
$script$, 'for p in 8080 8081 9090; do timeout 2 bash -c "</dev/tcp/127.0.0.1/$p" 2>/dev/null && echo $p; done > answers/open-ports.txt - the web server from task 1 must still be running.', 'Opening /dev/tcp/HOST/PORT makes bash attempt a TCP connection, so it doubles as a port tester on minimal machines. A refused connection fails at once; a firewalled one would hang until the timeout.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('a47bb5ca-ad33-5ed0-8073-791e40bc8528', 'c6764360-64ae-5f00-b5c1-1284857edd59', 1, $json$[{"id":"65c3b575-649a-51e1-9a03-c5aef17b7d51","lab_id":"c6764360-64ae-5f00-b5c1-1284857edd59","position":1,"title":"Open the shop's front door","description":"Serve the /home/labuser/work/site directory over HTTP on port 8080 using Python's built-in web server, running in the background so you keep your prompt.","verification_script":"curl -sf --max-time 3 http://localhost:8080/ | grep -q 'Orbit Coffee'\n","hint_context":"python3 -m http.server 8080 --directory /home/labuser/work/site serves a folder. Put nohup in front and an ampersand at the end to background it.","explanation_context":"A server is just a process that listens on a port. localhost (127.0.0.1) is the loopback address - traffic that never leaves the machine.","points":25,"is_optional":false,"is_stateful":true},{"id":"0302c7ee-54c2-5b9e-ad11-e55a6d467c33","lab_id":"c6764360-64ae-5f00-b5c1-1284857edd59","position":2,"title":"Read the response headers","description":"Save only the HTTP response headers of http://localhost:8080/ into answers/headers.txt.","verification_script":"f=/home/labuser/work/answers/headers.txt\ngrep -q 'HTTP/1.[01] 200' $f \u0026\u0026 grep -qi '^Server: SimpleHTTP' $f \u0026\u0026 ! grep -q '\u003ch1\u003e' $f\n","hint_context":"curl -I sends a HEAD request and prints only the headers. Redirect the output with \u003e.","explanation_context":"Headers carry the status code, content type and server name. curl -I is the fastest way to ask \"is it up, and what is answering?\"","points":20,"is_optional":false,"is_stateful":true},{"id":"7767e693-9768-5ff4-9515-7da35cfa1ef6","lab_id":"c6764360-64ae-5f00-b5c1-1284857edd59","position":3,"title":"Ask the API a question","description":"Fetch http://localhost:8080/status.json with curl and use jq to extract only the version field. Save that value (no quotes) into answers/api-version.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/api-version.txt)\" = 2.4.1 ]\n","hint_context":"curl -s URL | jq -r .version - the -s hides curl's progress bar and jq -r prints raw text without quotes.","explanation_context":"curl talks HTTP, jq slices JSON. Together they replace a browser for checking any API from a terminal.","points":25,"is_optional":false,"is_stateful":true},{"id":"cce6963a-26ee-5b63-a41d-d3170d60b899","lab_id":"c6764360-64ae-5f00-b5c1-1284857edd59","position":4,"title":"A shortcut for SSH","description":"Create ~/.ssh/config with a host entry named atlas that connects to the address 10.0.0.42 as the user deploy on port 2222, using the key file ~/.ssh/atlas_ed25519. The ~/.ssh directory must be accessible only by you (700) and the config file readable and writable only by you (600).","verification_script":"c=$HOME/.ssh/config\n[ \"$(stat -c %a $HOME/.ssh)\" = 700 ] \u0026\u0026 [ \"$(stat -c %a $c)\" = 600 ] \u0026\u0026\ngrep -Eq '^\\s*Host\\s+atlas\\s*$' $c \u0026\u0026 grep -Eiq '^\\s*HostName\\s+10\\.0\\.0\\.42\\s*$' $c \u0026\u0026\ngrep -Eiq '^\\s*User\\s+deploy\\s*$' $c \u0026\u0026 grep -Eiq '^\\s*Port\\s+2222\\s*$' $c \u0026\u0026\ngrep -Eiq '^\\s*IdentityFile\\s+~/\\.ssh/atlas_ed25519\\s*$' $c\n","hint_context":"One line Host atlas, then indented lines HostName, User, Port and IdentityFile. mkdir -p ~/.ssh, chmod 700 ~/.ssh, chmod 600 ~/.ssh/config.","explanation_context":"With this entry, ssh atlas expands to ssh -i ~/.ssh/atlas_ed25519 -p 2222 deploy@10.0.0.42. SSH refuses keys and configs that other users can read or write.","points":30,"is_optional":false,"is_stateful":true},{"id":"e26cd570-2169-5cf0-97de-ed00ef6f8760","lab_id":"c6764360-64ae-5f00-b5c1-1284857edd59","position":5,"title":"Which doors are open?","description":"Test which of the ports 8080, 8081 and 9090 on 127.0.0.1 accept a TCP connection right now, and save the open port numbers, one per line, into /home/labuser/work/answers/open-ports.txt. nc is not installed, so use curl or bash's /dev/tcp.","verification_script":"f=/home/labuser/work/answers/open-ports.txt\n[ -f $f ] || exit 1\nwant=$(for p in 8080 8081 9090; do timeout 2 bash -c \"\u003c/dev/tcp/127.0.0.1/$p\" 2\u003e/dev/null \u0026\u0026 echo $p; done)\n[ -n \"$want\" ] \u0026\u0026 [ \"$(grep -o '[0-9]\\+' $f | sort -n | tr '\\n' ' ')\" = \"$(echo $want | tr ' ' '\\n' | sort -n | tr '\\n' ' ')\" ]\n","hint_context":"for p in 8080 8081 9090; do timeout 2 bash -c \"\u003c/dev/tcp/127.0.0.1/$p\" 2\u003e/dev/null \u0026\u0026 echo $p; done \u003e answers/open-ports.txt - the web server from task 1 must still be running.","explanation_context":"Opening /dev/tcp/HOST/PORT makes bash attempt a TCP connection, so it doubles as a port tester on minimal machines. A refused connection fails at once; a firewalled one would hang until the timeout.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('01d41da1-b906-5a2a-9611-506ec83b7bc8', 'a47bb5ca-ad33-5ed0-8073-791e40bc8528', '65c3b575-649a-51e1-9a03-c5aef17b7d51', 1, 'Open the shop''s front door', $md$Serve the /home/labuser/work/site directory over HTTP on port 8080 using Python's built-in web server, running in the background so you keep your prompt.$md$, $script$curl -sf --max-time 3 http://localhost:8080/ | grep -q 'Orbit Coffee'
$script$, 'python3 -m http.server 8080 --directory /home/labuser/work/site serves a folder. Put nohup in front and an ampersand at the end to background it.', 'A server is just a process that listens on a port. localhost (127.0.0.1) is the loopback address - traffic that never leaves the machine.', 25, false, true),
('e781e94d-6f3e-5352-8ee4-942d46a25a8e', 'a47bb5ca-ad33-5ed0-8073-791e40bc8528', '0302c7ee-54c2-5b9e-ad11-e55a6d467c33', 2, 'Read the response headers', $md$Save only the HTTP response headers of http://localhost:8080/ into answers/headers.txt.$md$, $script$f=/home/labuser/work/answers/headers.txt
grep -q 'HTTP/1.[01] 200' $f && grep -qi '^Server: SimpleHTTP' $f && ! grep -q '<h1>' $f
$script$, 'curl -I sends a HEAD request and prints only the headers. Redirect the output with >.', 'Headers carry the status code, content type and server name. curl -I is the fastest way to ask "is it up, and what is answering?"', 20, false, true),
('6dab314a-0893-58b4-b906-1de5f8d99f06', 'a47bb5ca-ad33-5ed0-8073-791e40bc8528', '7767e693-9768-5ff4-9515-7da35cfa1ef6', 3, 'Ask the API a question', $md$Fetch http://localhost:8080/status.json with curl and use jq to extract only the version field. Save that value (no quotes) into answers/api-version.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/api-version.txt)" = 2.4.1 ]
$script$, 'curl -s URL | jq -r .version - the -s hides curl''s progress bar and jq -r prints raw text without quotes.', 'curl talks HTTP, jq slices JSON. Together they replace a browser for checking any API from a terminal.', 25, false, true),
('9ab214e9-e05b-5081-94ef-1c3b1831f85f', 'a47bb5ca-ad33-5ed0-8073-791e40bc8528', 'cce6963a-26ee-5b63-a41d-d3170d60b899', 4, 'A shortcut for SSH', $md$Create ~/.ssh/config with a host entry named atlas that connects to the address 10.0.0.42 as the user deploy on port 2222, using the key file ~/.ssh/atlas_ed25519. The ~/.ssh directory must be accessible only by you (700) and the config file readable and writable only by you (600).$md$, $script$c=$HOME/.ssh/config
[ "$(stat -c %a $HOME/.ssh)" = 700 ] && [ "$(stat -c %a $c)" = 600 ] &&
grep -Eq '^\s*Host\s+atlas\s*$' $c && grep -Eiq '^\s*HostName\s+10\.0\.0\.42\s*$' $c &&
grep -Eiq '^\s*User\s+deploy\s*$' $c && grep -Eiq '^\s*Port\s+2222\s*$' $c &&
grep -Eiq '^\s*IdentityFile\s+~/\.ssh/atlas_ed25519\s*$' $c
$script$, 'One line Host atlas, then indented lines HostName, User, Port and IdentityFile. mkdir -p ~/.ssh, chmod 700 ~/.ssh, chmod 600 ~/.ssh/config.', 'With this entry, ssh atlas expands to ssh -i ~/.ssh/atlas_ed25519 -p 2222 deploy@10.0.0.42. SSH refuses keys and configs that other users can read or write.', 30, false, true),
('51cac47c-06d0-54cf-bee7-5b566d35e589', 'a47bb5ca-ad33-5ed0-8073-791e40bc8528', 'e26cd570-2169-5cf0-97de-ed00ef6f8760', 5, 'Which doors are open?', $md$Test which of the ports 8080, 8081 and 9090 on 127.0.0.1 accept a TCP connection right now, and save the open port numbers, one per line, into /home/labuser/work/answers/open-ports.txt. nc is not installed, so use curl or bash's /dev/tcp.$md$, $script$f=/home/labuser/work/answers/open-ports.txt
[ -f $f ] || exit 1
want=$(for p in 8080 8081 9090; do timeout 2 bash -c "</dev/tcp/127.0.0.1/$p" 2>/dev/null && echo $p; done)
[ -n "$want" ] && [ "$(grep -o '[0-9]\+' $f | sort -n | tr '\n' ' ')" = "$(echo $want | tr ' ' '\n' | sort -n | tr '\n' ' ')" ]
$script$, 'for p in 8080 8081 9090; do timeout 2 bash -c "</dev/tcp/127.0.0.1/$p" 2>/dev/null && echo $p; done > answers/open-ports.txt - the web server from task 1 must still be running.', 'Opening /dev/tcp/HOST/PORT makes bash attempt a TCP connection, so it doubles as a port tester on minimal machines. A refused connection fails at once; a firewalled one would hang until the timeout.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'a47bb5ca-ad33-5ed0-8073-791e40bc8528', updated_at = now()
WHERE id = 'c6764360-64ae-5f00-b5c1-1284857edd59' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d35afc86-c217-5c41-ab9a-8a0e6bc81e54', '00000000-0000-0000-0000-000000000001', 'mcq', 'From your laptop, curl atlas:8080 says ''Connection refused''. On atlas, ss -tu...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4449b28b-d3c8-5180-aa7e-8d4e68a584d8', 'd35afc86-c217-5c41-ab9a-8a0e6bc81e54', 1, $json${"prompt":"From your laptop, curl atlas:8080 says 'Connection refused'. On atlas, ss -tulpn shows brewbot on 127.0.0.1:8080. What is wrong?","multiple":false,"options":[{"id":"a","text":"brewbot listens only on localhost, so outside connections reach no listener","is_correct":true},{"id":"b","text":"A firewall is dropping the packets","is_correct":false},{"id":"c","text":"DNS resolves the wrong name","is_correct":false},{"id":"d","text":"The server is out of memory","is_correct":false}],"explanation":"Refused means nothing listens on that address and port. Bound to 127.0.0.1, brewbot only accepts local connections. A firewall drop shows as a timeout, a DNS problem fails before connecting, and memory is unrelated."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8164cda7-a7b0-5f23-ade1-cef4f75ed276', '00000000-0000-0000-0000-000000000001', 'mcq', 'curl to the database port hangs for a minute and then reports ''Connection tim...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('463bb52d-8a09-5744-9d86-a19914d9239e', '8164cda7-a7b0-5f23-ade1-cef4f75ed276', 1, $json${"prompt":"curl to the database port hangs for a minute and then reports 'Connection timed out'. What is the most likely cause?","multiple":false,"options":[{"id":"a","text":"A firewall or security group silently drops the packets","is_correct":true},{"id":"b","text":"The database process is stopped","is_correct":false},{"id":"c","text":"The database password is wrong","is_correct":false},{"id":"d","text":"The port number is below 1024","is_correct":false}],"explanation":"Timeouts mean no answer at all, typical of a drop. A stopped service on a reachable host answers with refused immediately, passwords are checked after connecting, and port numbers do not cause timeouts."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7923b54a-da56-5c82-8211-63a7c6ba93a9', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command shows which process is listening on which port?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('55317c85-360f-5102-9c79-e71b9ff08665', '7923b54a-da56-5c82-8211-63a7c6ba93a9', 1, $json${"prompt":"Which command shows which process is listening on which port?","multiple":false,"options":[{"id":"a","text":"sudo ss -tulpn","is_correct":true},{"id":"b","text":"ip r","is_correct":false},{"id":"c","text":"ping localhost","is_correct":false},{"id":"d","text":"dig localhost","is_correct":false}],"explanation":"ss -tulpn lists TCP/UDP listeners with process names. ip r shows routes, ping tests ICMP reachability, and dig queries DNS."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('46447b34-140e-54c0-ba6d-795a03cb6662', '00000000-0000-0000-0000-000000000001', 'mcq', 'curl https://api.payments.example fails with ''Could not resolve host'', but cu...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ac86c037-b054-58f8-af7f-aa5e7d0972a3', '46447b34-140e-54c0-ba6d-795a03cb6662', 1, $json${"prompt":"curl https://api.payments.example fails with 'Could not resolve host', but curl to its IP works. Where do you look?","multiple":false,"options":[{"id":"a","text":"Name resolution: getent hosts, /etc/hosts, /etc/resolv.conf, dig","is_correct":true},{"id":"b","text":"The firewall","is_correct":false},{"id":"c","text":"The TLS certificate","is_correct":false},{"id":"d","text":"The routing table","is_correct":false}],"explanation":"The IP works, so network, routing and firewall are fine. The failure happens before any connection, at the name lookup. TLS would fail after connecting."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b27febee-4f43-5dcd-9180-5c25f60eaa0f', '00000000-0000-0000-0000-000000000001', 'mcq', 'dig api.internal returns 10.0.0.9, but curl goes to 10.0.0.5. What is the mos...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ca64600f-9de9-54ef-87ae-5b7379865939', 'b27febee-4f43-5dcd-9180-5c25f60eaa0f', 1, $json${"prompt":"dig api.internal returns 10.0.0.9, but curl goes to 10.0.0.5. What is the most likely reason?","multiple":false,"options":[{"id":"a","text":"A stale line in /etc/hosts, which programs check before DNS but dig ignores","is_correct":true},{"id":"b","text":"dig is broken","is_correct":false},{"id":"c","text":"curl uses a different port","is_correct":false},{"id":"d","text":"The TTL is negative","is_correct":false}],"explanation":"nsswitch checks files (/etc/hosts) before DNS. getent hosts api.internal shows what programs actually use. dig asks DNS directly, ports do not affect name resolution, and TTLs are never negative."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3413d2f1-a5b4-583a-9ed3-c2326abb5c07', '00000000-0000-0000-0000-000000000001', 'mcq', 'SSH ignores your key and asks for a password. The server''s ~/.ssh is 777 and ...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c868ec73-968e-552f-b25a-74105ecf37ac', '3413d2f1-a5b4-583a-9ed3-c2326abb5c07', 1, $json${"prompt":"SSH ignores your key and asks for a password. The server's ~/.ssh is 777 and authorized_keys is 666. What should they be?","multiple":false,"options":[{"id":"a","text":"~/.ssh 700 and authorized_keys 600","is_correct":true},{"id":"b","text":"~/.ssh 755 and authorized_keys 777","is_correct":false},{"id":"c","text":"Both 644","is_correct":false},{"id":"d","text":"Permissions do not matter to SSH","is_correct":false}],"explanation":"sshd refuses keys that other users could modify. Lock .ssh to 700 and the key files to 600; anything group- or world-writable is rejected."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('eb0db474-cfd2-50e6-bdca-76a9a2fcd50a', '00000000-0000-0000-0000-000000000001', 'mcq', 'PostgreSQL on atlas listens only on 127.0.0.1:5432. How can you use psql from...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b4c1c602-4d83-582a-964e-78870ba1fc0b', 'eb0db474-cfd2-50e6-bdca-76a9a2fcd50a', 1, $json${"prompt":"PostgreSQL on atlas listens only on 127.0.0.1:5432. How can you use psql from your laptop without opening the port to the network?","multiple":false,"options":[{"id":"a","text":"ssh -L 5432:localhost:5432 atlas, then connect to localhost:5432 on the laptop","is_correct":true},{"id":"b","text":"ufw allow 5432 from anywhere","is_correct":false},{"id":"c","text":"Change PostgreSQL to listen on 0.0.0.0","is_correct":false},{"id":"d","text":"scp the database to the laptop","is_correct":false}],"explanation":"An SSH tunnel forwards a local port through the encrypted connection to atlas's localhost. The other options expose the database or copy data around instead."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5557d706-e867-5423-bc2f-b0881228a0c0', '00000000-0000-0000-0000-000000000001', 'mcq', 'You are about to run sudo ufw enable on a remote server. What must you do first?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('72654afb-0e49-5c40-b0e9-a2f12e0a2091', '5557d706-e867-5423-bc2f-b0881228a0c0', 1, $json${"prompt":"You are about to run sudo ufw enable on a remote server. What must you do first?","multiple":false,"options":[{"id":"a","text":"sudo ufw allow 22/tcp (or OpenSSH)","is_correct":true},{"id":"b","text":"Reboot","is_correct":false},{"id":"c","text":"Stop sshd","is_correct":false},{"id":"d","text":"Nothing; ufw never blocks SSH","is_correct":false}],"explanation":"With a default-deny policy, enabling ufw without an SSH rule drops your own session. Rebooting or stopping sshd makes things worse, and ufw does block SSH unless allowed."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('071518c8-63b7-595c-a221-43f9ff6dddbf', '00000000-0000-0000-0000-000000000001', 'mcq', 'A health-check script runs curl http://localhost:8080/health && echo OK. It p...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('3f6ee4ed-1845-5297-9723-9cc8aa2834b7', '071518c8-63b7-595c-a221-43f9ff6dddbf', 1, $json${"prompt":"A health-check script runs curl http://localhost:8080/health \u0026\u0026 echo OK. It prints OK even when the app returns HTTP 500. Why?","multiple":false,"options":[{"id":"a","text":"curl exits 0 for any HTTP response unless -f is given","is_correct":true},{"id":"b","text":"\u0026\u0026 ignores exit codes","is_correct":false},{"id":"c","text":"500 is a success code","is_correct":false},{"id":"d","text":"localhost always returns OK","is_correct":false}],"explanation":"curl only fails on transport errors by default. -f (or checking %{http_code}) makes HTTP 4xx/5xx exit non-zero. \u0026\u0026 does check exit codes, and 5xx means server error."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('89bb073e-f1a6-5cdf-93c7-94a4c8623be9', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 7): you must copy /srv/site to a backup server every night, s...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('977424c8-59d8-51fb-9235-117aaef7ea3c', '89bb073e-f1a6-5cdf-93c7-94a4c8623be9', 1, $json${"prompt":"Review (chapter 7): you must copy /srv/site to a backup server every night, sending only changed files. Which command fits?","multiple":false,"options":[{"id":"a","text":"rsync -az /srv/site/ backup:/backups/site/","is_correct":true},{"id":"b","text":"scp -r /srv/site backup:/backups/","is_correct":false},{"id":"c","text":"tar -czf site.tar.gz /srv/site","is_correct":false},{"id":"d","text":"cp -a /srv/site backup:/backups/","is_correct":false}],"explanation":"rsync over SSH sends only differences. scp copies everything every time, tar only creates a local archive, and cp cannot copy to another host."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('49504522-441d-551b-98dc-947d213e0b60', '00000000-0000-0000-0000-000000000001', 'Quiz: Networking', 'linux-talking-to-the-world-quiz', 'Quiz covering Chapter 8: Talking to the World - Networking.', 'mcq', 'published', 'module', 'b21cb753-609a-5a14-84c8-04c291868caa', 12, 70, 5, 20, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '49504522-441d-551b-98dc-947d213e0b60' AND question_id NOT IN ('d35afc86-c217-5c41-ab9a-8a0e6bc81e54', '8164cda7-a7b0-5f23-ade1-cef4f75ed276', '7923b54a-da56-5c82-8211-63a7c6ba93a9', '46447b34-140e-54c0-ba6d-795a03cb6662', 'b27febee-4f43-5dcd-9180-5c25f60eaa0f', '3413d2f1-a5b4-583a-9ed3-c2326abb5c07', 'eb0db474-cfd2-50e6-bdca-76a9a2fcd50a', '5557d706-e867-5423-bc2f-b0881228a0c0', '071518c8-63b7-595c-a221-43f9ff6dddbf', '89bb073e-f1a6-5cdf-93c7-94a4c8623be9');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('ddfe8b5c-c292-5577-a64a-f694b09901dd', '49504522-441d-551b-98dc-947d213e0b60', 'd35afc86-c217-5c41-ab9a-8a0e6bc81e54', '4449b28b-d3c8-5180-aa7e-8d4e68a584d8', 0, 2),
('75a8c933-a2fc-588a-9d09-dbcd19014242', '49504522-441d-551b-98dc-947d213e0b60', '8164cda7-a7b0-5f23-ade1-cef4f75ed276', '463bb52d-8a09-5744-9d86-a19914d9239e', 1, 2),
('97134f3c-39d0-597b-ab28-55e4c2ea4f68', '49504522-441d-551b-98dc-947d213e0b60', '7923b54a-da56-5c82-8211-63a7c6ba93a9', '55317c85-360f-5102-9c79-e71b9ff08665', 2, 2),
('3ddab149-9f9c-5b0f-9198-9392cc89ef56', '49504522-441d-551b-98dc-947d213e0b60', '46447b34-140e-54c0-ba6d-795a03cb6662', 'ac86c037-b054-58f8-af7f-aa5e7d0972a3', 3, 2),
('b9a0c146-3223-59b5-8581-9f38c2260d64', '49504522-441d-551b-98dc-947d213e0b60', 'b27febee-4f43-5dcd-9180-5c25f60eaa0f', 'ca64600f-9de9-54ef-87ae-5b7379865939', 4, 2),
('60f2f000-d976-5b86-84f7-e58f0e6fb34a', '49504522-441d-551b-98dc-947d213e0b60', '3413d2f1-a5b4-583a-9ed3-c2326abb5c07', 'c868ec73-968e-552f-b25a-74105ecf37ac', 5, 2),
('808c586b-f709-507c-9bf9-7162c4b89bae', '49504522-441d-551b-98dc-947d213e0b60', 'eb0db474-cfd2-50e6-bdca-76a9a2fcd50a', 'b4c1c602-4d83-582a-964e-78870ba1fc0b', 6, 2),
('308131b0-4b17-57bf-adf3-bd06ff2a138d', '49504522-441d-551b-98dc-947d213e0b60', '5557d706-e867-5423-bc2f-b0881228a0c0', '72654afb-0e49-5c40-b0e9-a2f12e0a2091', 7, 2),
('5f3410a4-7377-52dc-b715-c93ab898a676', '49504522-441d-551b-98dc-947d213e0b60', '071518c8-63b7-595c-a221-43f9ff6dddbf', '3f6ee4ed-1845-5297-9723-9cc8aa2834b7', 8, 2),
('14ee45fa-f37e-5eb5-9a13-cacf7595069d', '49504522-441d-551b-98dc-947d213e0b60', '89bb073e-f1a6-5cdf-93c7-94a4c8623be9', '977424c8-59d8-51fb-9235-117aaef7ea3c', 9, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('b21cb753-609a-5a14-84c8-04c291868caa', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'Quiz: Networking', 'assessment', 8, 10, '49504522-441d-551b-98dc-947d213e0b60')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 9: Teaching Atlas Tricks - Bash Scripting
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 9: Teaching Atlas Tricks - Bash Scripting', 9, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b6fb83b0-7196-5683-a122-746fe27d3539', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'Anatomy of a Script: Shebang, set -euo pipefail, Running It', 'notes', 0, $md$## Why this matters

> **Wednesday, week 2.** Rhea counts on her fingers: "You checked services by
> hand, made backups by hand, read logs by hand. Tom wrote on the whiteboard:
> *lazy admins write scripts*."

A script is just the commands you already know, saved in a file, plus a little
logic. Written carefully, it does a 10-minute chore in one second, the same way
every time, at 3am, without you.

## Mental model: a recipe card with a safety belt

```bash
#!/bin/bash                 # 1. shebang: which interpreter runs this file
# greet.sh - say hello      # 2. comment: what and why
set -euo pipefail           # 3. safety belt: stop on errors

name="$1"                   # 4. the work: the commands you already know
echo "Hello, $name!"
```

- **Shebang** `#!/bin/bash`: the first line tells the kernel which program
  interprets the file. `#!/usr/bin/env bash` finds bash via PATH, useful when it
  lives elsewhere (macOS, NixOS).
- **`set -euo pipefail`**: without it, bash carries on after errors, which is how
  a failed `cd` turns into `rm -rf` in the wrong directory.
  - `-e` exit on the first failing command
  - `-u` treat unset variables as an error (catches typos)
  - `-o pipefail` a pipeline fails if *any* part fails, not only the last

> **Memory hook:** "**E**very **U**nsafe **O**ption, **P**lease **F**ail": put
> `set -euo pipefail` at the top of every script.

## See it work

```bash
mkdir -p ~/work/scripts && cd ~/work/scripts
cat > greet.sh <<'EOF'
#!/bin/bash
set -euo pipefail
echo "Hello, $1!"
EOF
chmod +x greet.sh
./greet.sh Rhea
```

What this does: writes the script with a here-document, makes it executable, and
runs it. Expected output:

```
Hello, Rhea!
```

Three ways to run a script:

```bash
./greet.sh Rhea          # needs the x bit; ./ because . is not in PATH
bash greet.sh Rhea       # bash reads the file; no x bit needed
source greet.sh Rhea     # runs in YOUR shell: its variables and cd stick
```

Use `./` or `bash` normally; `source` only for files meant to change your
current shell (like `~/.bashrc`).

### See what the script does: -x

```bash
bash -x greet.sh Rhea
```

```
+ set -euo pipefail
+ echo 'Hello, Rhea!'
Hello, Rhea!
```

Every command is printed with `+` before it runs, with variables already
expanded. This is the first debugging tool for any script. `set -x` inside a
script turns it on from that line.

### What -u catches

```bash
./greet.sh
```

```
./greet.sh: line 3: $1: unbound variable
```

Without `-u`, the script would print `Hello, !` and "succeed". Failing loudly is
better than succeeding wrongly.

## Try it

Write `~/work/scripts/today.sh` that prints `Today is` followed by the date in
`YYYY-MM-DD` format (`date +%F`), make it executable and run it.

<details>
<summary>Show answer</summary>

```bash
cat > ~/work/scripts/today.sh <<'EOF'
#!/bin/bash
set -euo pipefail
echo "Today is $(date +%F)"
EOF
chmod +x ~/work/scripts/today.sh
~/work/scripts/today.sh
```

`$(...)` runs a command and inserts its output (next lesson).

</details>

## Common mistakes

- **No shebang.** The file may run with `sh` instead of bash, and bash features
  fail in odd ways.
- **Windows line endings.** `bad interpreter: /bin/bash^M` means the file has
  `\r\n`. Fix with `sed -i 's/\r$//' script.sh`.
- **Forgetting `chmod +x`.** `./script.sh: Permission denied`.
- **Leaving out `set -euo pipefail`.** Errors are silently ignored and the
  script continues on bad data.

## Remember

- Line 1: `#!/bin/bash`; line 2-3: `set -euo pipefail`.
- `chmod +x` then `./script.sh`; or `bash script.sh`.
- `bash -x` shows every command as it runs.
- Fail loudly: `-e` errors, `-u` unset variables, `pipefail` pipelines.

**Self-check:**

1. What does the shebang line do?
2. What does `-o pipefail` change?
3. How do you trace a script's commands as they run?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b3e204d1-7053-5c45-a3d4-60a5c03fafb3', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'Variables, Quoting, Arguments and Command Substitution', 'notes', 1, $md$## Why this matters

The most common bug in shell scripts is a missing pair of quotes. It works on
your test file and deletes the wrong thing on the file called `my notes.txt`.
Quoting is the one rule that turns fragile scripts into safe ones.

## Mental model: the shell splits words, quotes glue them

Before running a command, bash **expands** variables and then **splits** the
result on spaces. Double quotes stop the splitting.

```
 file="my notes.txt"

 rm $file      ->  rm  my  notes.txt     two arguments: deletes "my" and "notes.txt"
 rm "$file"    ->  rm  "my notes.txt"    one argument: deletes the right file
```

> **Rule:** always write `"$var"`. Leave the quotes off only when you know
> exactly why.

## See it work

```bash
shop="Orbit Coffee"          # no spaces around =
echo "$shop"                 # Orbit Coffee
echo "${shop}-backup"        # braces separate the name from text
echo '$shop'                 # single quotes: NO expansion, prints $shop
today=$(date +%Y-%m-%d)      # command substitution: capture output
count=$((3 + 4))             # arithmetic
echo "$today $count"
```

Expected output (date differs):

```
Orbit Coffee
Orbit Coffee-backup
$shop
2026-10-14 7
```

| Quotes | `$var` and `$(...)` expanded? | Use for |
|---|---|---|
| `"double"` | yes | almost everything |
| `'single'` | no | literal text, awk/sed programs |
| none | yes, then split and globbed | only when you want splitting |

### Arguments and special variables

| Variable | Meaning |
|---|---|
| `$0` | script name |
| `$1`, `$2` ... | arguments |
| `$#` | number of arguments |
| `"$@"` | all arguments, each safely quoted |
| `$?` | exit status of the last command |
| `$$` | this script's PID |

```bash
cat > args.sh <<'EOF'
#!/bin/bash
set -euo pipefail
echo "script=$0 count=$# first=${1:-none}"
for a in "$@"; do echo "arg: $a"; done
EOF
chmod +x args.sh && ./args.sh "dark roast" decaf
```

```
script=./args.sh count=2 first=dark roast
arg: dark roast
arg: decaf
```

`"$@"` kept `dark roast` as one argument. `$*` or unquoted `$@` would split it.

### Defaults and required values

```bash
port=${PORT:-8080}            # use PORT, or 8080 if unset/empty
dest=${2:?usage: backup.sh SRC DEST}   # stop with this message if $2 is missing
rm -rf "${BUILD_DIR:?}/"      # never becomes rm -rf / when BUILD_DIR is empty
```

`${var:-default}` and `${var:?message}` also keep `set -u` happy when an
argument is optional.

### Small string tricks

```bash
f=/var/log/brewbot/app.log
echo "${f##*/}"     # app.log          (like basename)
echo "${f%/*}"      # /var/log/brewbot (like dirname)
echo "${f%.log}.gz" # /var/log/brewbot/app.gz
echo "${#f}"        # 24               (length)
```

## Try it

`file="Q3 report.csv"`. Which command copies it to `/tmp` correctly:
`cp $file /tmp` or `cp "$file" /tmp`? What does the wrong one try to do?

<details>
<summary>Show answer</summary>

`cp "$file" /tmp`. The unquoted version becomes `cp Q3 report.csv /tmp`: it
tries to copy two files named `Q3` and `report.csv`.

</details>

## Common mistakes

- **Unquoted variables.** Spaces split them, `*` in values expands to file
  names.
- **Spaces around `=`.** `name = x` runs a command called `name`.
- **Single quotes when you need the value.** `echo '$HOME'` prints `$HOME`.
- **`$*` instead of `"$@"`.** Arguments with spaces get split.

## Remember

- Always `"$var"` and `"$@"`.
- `$(cmd)` captures output; `$((...))` does arithmetic.
- `$1..$9`, `$#`, `$?`, `$0`, `$$`.
- `${var:-default}`, `${var:?msg}`, `${f##*/}`, `${f%/*}`.

**Self-check:**

1. What is the difference between `'$x'` and `"$x"`?
2. Why is `"$@"` better than `$*`?
3. What does `${PORT:-8080}` do?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('c7f0b046-fe8c-55fa-87cf-259deae74fdd', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'Exit Codes, if, test and && / ||', 'notes', 2, $md$## Why this matters

Scripts make decisions: is the service up, does the directory exist, did the
copy work? Every one of those decisions is based on one number every command
returns. Get it wrong and your script reports success on a failed backup.

## Mental model: zero is a hero

Every command ends with an **exit status** (0-255):

```
 0          = success
 1-255      = some kind of failure (the program decides which number means what)
```

`if`, `&&`, `||` and `set -e` all look at that number, not at the output.

> **Memory hook:** in the shell, **zero is a hero**: 0 means success, the
> opposite of most programming languages where 0 is false.

Common conventions: `1` general error, `2` misuse (bad arguments), `126` not
executable, `127` command not found, `128+N` killed by signal N.

## See it work

```bash
ls /etc/hostname; echo "status=$?"
ls /nope 2>/dev/null; echo "status=$?"
```

```
/etc/hostname
status=0
status=2
```

### if

```bash
if grep -q ERROR app.log; then
  echo "errors found"
elif [ -f app.log ]; then
  echo "clean log"
else
  echo "no log at all" >&2
  exit 1
fi
```

`if` runs the command after it and checks its status. `grep -q` prints nothing
and just returns 0 (found) or 1 (not found). `>&2` sends the message to stderr.

### Tests: [ ] and [[ ]]

`[` is a command (`test`) that checks a condition and returns 0 or 1. Spaces
inside the brackets are required.

| Test | True when |
|---|---|
| `-f path` / `-d path` / `-e path` | file / directory / anything exists |
| `-x path` / `-r path` / `-w path` | executable / readable / writable |
| `-s path` | file exists and is not empty |
| `-z "$s"` / `-n "$s"` | string empty / not empty |
| `"$a" = "$b"` / `!=` | strings equal / differ |
| `$a -eq $b`, `-ne`, `-lt`, `-gt`, `-le`, `-ge` | number comparisons |
| `! test` | negation |

`[[ ]]` is bash's improved test: safer with empty variables, supports `&&`,
`||`, patterns and regex:

```bash
[[ $file == *.log ]] && echo "a log file"
[[ $port =~ ^[0-9]+$ ]] || { echo "port must be a number" >&2; exit 2; }
(( count > 3 )) && echo "more than three"      # arithmetic test
```

### && and ||: short decisions

```bash
mkdir -p backups && echo "ready"     # && runs only on success
cd /srv/shop || exit 1               # || runs only on failure
```

`cd dir || exit 1` is the classic guard: never continue in the wrong directory.

### Setting your own exit code

```bash
if [ $# -lt 1 ]; then
  echo "Usage: greet.sh NAME" >&2
  exit 1
fi
```

Errors go to **stderr** and a **non-zero exit**, so cron, CI and other scripts
can tell success from failure.

## Try it

Write the start of a script that exits with status 2 and an error on stderr if
its first argument is not an existing directory.

<details>
<summary>Show answer</summary>

```bash
#!/bin/bash
set -euo pipefail
src=${1:-}
if [ ! -d "$src" ]; then
  echo "error: '$src' is not a directory" >&2
  exit 2
fi
```

`${1:-}` avoids the `-u` "unbound variable" error when no argument is given.

</details>

## Common mistakes

- **No spaces in tests.** `[ -f$x ]` or `[-f "$x"]` are syntax errors. Write
  `[ -f "$x" ]`.
- **`=` vs `-eq`.** `=` compares strings, `-eq` compares numbers. `[ 010 -eq 10 ]`
  is true, `[ 010 = 10 ]` is false.
- **Testing the output instead of the status.** `if [ "$(grep x f)" ]` works,
  but `if grep -q x f` is clearer and faster.
- **Checking `$?` too late.** Any command (even `echo`) overwrites it. Save it
  first: `rc=$?`.

## Remember

- 0 = success; `$?` holds the last status.
- `if CMD; then ...; elif ...; else ...; fi` checks a command's status.
- `[ -f f ]`, `[ -z "$s" ]`, `[ $a -lt $b ]`; prefer `[[ ]]` in bash.
- `&&` on success, `||` on failure; errors to stderr with `exit N`.

**Self-check:**

1. What exit status means "command not found"?
2. What is the difference between `=` and `-eq` in a test?
3. What does `cd /srv/shop || exit 1` protect against?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('c71c9048-4936-5e5b-aaf4-1a59f4b7c847', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'Loops: for, while read and Ranges', 'notes', 3, $md$## Why this matters

Five reports, thirty log files, ten servers, every line of a service list: the
moment you do something more than twice, a loop does it for you, the same way
each time.

## Mental model: a conveyor belt

A loop takes items off a belt one at a time, puts each in a variable, and runs
the same block of commands on it.

```
 for item in A B C          while read -r line
   do ... "$item" ... done     do ... "$line" ... done < file
   (a list you give it)        (one line at a time from a file or pipe)
```

## See it work

### for over a list

```bash
for n in 1 2 3; do echo "$n"; done
for n in {1..5}; do echo "Report $n" > "report-$n.txt"; done
ls report-*
```

What this does: `{1..5}` is brace expansion that generates `1 2 3 4 5` before
the loop runs. Expected output:

```
1
2
3
report-1.txt  report-2.txt  report-3.txt  report-4.txt  report-5.txt
```

```bash
for f in *.log; do gzip "$f"; done           # every matching file
for host in web1 web2 db1; do ssh "$host" uptime; done
for ((i = 0; i < 3; i++)); do echo "$i"; done # C-style counter
```

If no file matches `*.log`, the loop runs once with the literal text `*.log`.
Guard with `[ -e "$f" ] || continue`, or set `shopt -s nullglob`.

### while read: one line at a time

```bash
cat > services.txt <<'EOF'
nginx running
brewbot stopped
EOF
while read -r name status; do
  echo "$name is $status"
done < services.txt
```

```
nginx is running
brewbot is stopped
```

`read -r name status` splits each line on whitespace: the first word into
`name`, the rest into `status`. `-r` keeps backslashes literal. Always use `-r`.

Read lines from a command's output with process substitution:

```bash
while read -r pid cmd; do
  echo "PID $pid runs $cmd"
done < <(ps -eo pid=,comm= | head -3)
```

### Controlling the loop

```bash
for f in *.conf; do
  [ -s "$f" ] || continue     # skip empty files
  grep -q DEBUG "$f" && break # stop at the first file with DEBUG
done

count=0
while [ $count -lt 3 ]; do count=$((count + 1)); done
until curl -sf localhost:8080 >/dev/null; do sleep 2; done   # wait for a service
```

`continue` skips to the next item; `break` leaves the loop; `until` loops while
the command fails.

## Try it

Using a loop at the prompt, create `~/work/scripts/reports/report-1.txt` to
`report-5.txt`, each holding one line `Report N`.

<details>
<summary>Show answer</summary>

```bash
mkdir -p ~/work/scripts/reports
for n in {1..5}; do echo "Report $n" > ~/work/scripts/reports/report-$n.txt; done
cat ~/work/scripts/reports/report-3.txt     # Report 3
```

</details>

## Common mistakes

- **`for line in $(cat file)`.** Splits on every space, not on lines. Use
  `while read -r`.
- **`cat file | while read ...; do count=...; done`.** The pipe runs the loop in
  a subshell, so variables set inside vanish. Use `done < file`.
- **Unquoted `$f` in the body.** File names with spaces break. Quote.
- **Endless `until` loops.** Add a limit: count attempts and give up.

## Remember

- `for x in LIST; do ...; done`; `{1..5}` makes ranges.
- `while read -r a b; do ...; done < file` for lines.
- `continue` skips, `break` exits, `until` waits for success.
- Quote `"$x"` inside loops; avoid `for line in $(cat f)`.

**Self-check:**

1. Why does `for line in $(cat f)` not loop over lines?
2. What does `-r` do in `read -r`?
3. Why can a variable set inside `cmd | while read` be lost?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('44516a7d-9932-5572-a6d8-6d2e7646aee2', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'Functions, case and Arrays', 'notes', 4, $md$## Why this matters

A 200-line script with the same `curl` check copied six times is hard to read
and easy to break. Functions give a name to a block you reuse. `case` turns a
pile of `if`s into a clear menu: `brewctl start|stop|status`.

## Mental model: named mini-scripts

A **function** is a small script inside your script: it has its own arguments
(`$1`, `$2`...) and returns an exit status, just like a command.

```
 is_up 8080          ->   function is_up() { curl -sf ... "localhost:$1" ... }
   $1 = 8080                returns 0 (up) or non-zero (down)
```

## See it work

### Functions

```bash
log() {
  echo "$(date +%T) $*" >&2
}

is_up() {
  local port=$1
  curl -sf --max-time 2 "http://localhost:$port/" >/dev/null
}

if is_up 8080; then log "brewbot ok"; else log "brewbot DOWN"; fi
```

What this does: `log` prints a timestamped message to stderr; `is_up`'s exit
status is curl's exit status, so it works directly in `if`. Expected output when
nothing listens on 8080:

```
10:42:07 brewbot DOWN
```

- `local port=$1` keeps the variable inside the function.
- `$*` in `log` joins all its arguments into one string.
- `return N` sets a function's status; `exit N` would end the whole script.
- Functions must be defined before they are called.

### case: a clean menu

```bash
case "${1:-}" in
  start)        echo "starting" ;;
  stop)         echo "stopping" ;;
  status|st)    echo "brewbot: OK" ;;
  *.conf)       echo "checking config $1" ;;
  *)            echo "Usage: $0 {start|stop|status}" >&2; exit 1 ;;
esac
```

Each branch is a pattern (`|` means or, `*` is a glob) ending with `)`, and
each block ends with `;;`. `*)` catches everything else, perfect for a usage
message.

### Arrays

```bash
services=(nginx brewbot postgres)
echo "${services[0]}"          # nginx
echo "${#services[@]}"         # 3
for s in "${services[@]}"; do echo "check $s"; done
services+=(redis)              # append
```

`"${arr[@]}"` expands to every element, each kept intact (like `"$@"`).
Associative arrays map names to values: `declare -A port=([web]=80 [api]=8080);
echo "${port[api]}"`.

### Options with getopts

```bash
verbose=0
while getopts "vd:" opt; do
  case $opt in
    v) verbose=1 ;;
    d) dest=$OPTARG ;;
    *) echo "Usage: $0 [-v] [-d DIR]" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))          # what remains in "$@" are the normal arguments
```

`"vd:"` means: `-v` takes no value, `-d` needs one (the colon).

## Try it

Write a function `need` that takes a command name and exits the script with
status 127 and a message on stderr if that command is not installed. Use it for
`jq`.

<details>
<summary>Show answer</summary>

```bash
need() {
  command -v "$1" >/dev/null || { echo "missing command: $1" >&2; exit 127; }
}
need jq
```

</details>

## Common mistakes

- **Forgetting `local`.** Function variables overwrite globals with the same
  name.
- **`exit` inside a function meant to report failure.** It ends the whole script.
  Use `return 1` when the caller should decide.
- **Missing `;;` in case.** Syntax error, or execution falls into the wrong
  branch (`;&`).
- **`${arr[@]}` without quotes.** Elements with spaces split apart.

## Remember

- `name() { ...; }`; arguments `$1...`; `local` vars; `return N`.
- A function's exit status works directly in `if`.
- `case "$1" in a) ...;; b|c) ...;; *) usage;; esac`.
- Arrays: `arr=(a b)`, `"${arr[@]}"`, `${#arr[@]}`; options with `getopts`.

**Self-check:**

1. How does a function return success or failure?
2. What does `*)` do in a `case`?
3. Why quote `"${arr[@]}"`?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4a821c00-a7e1-5030-baf7-3d9825652bb8', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'Making Scripts Robust: trap, mktemp, flock and shellcheck', 'notes', 5, $md$## Why this matters

A script that works when you run it is not done. It must also behave when it is
interrupted, run twice at once, run from cron with no PATH, or meet a file name
with spaces. Five habits cover most of that.

## Mental model: leave the kitchen clean, whatever happens

A good script is like a good cook: it gets its ingredients ready (checks inputs),
works in its own space (temp directory), cleans up even if interrupted (trap),
never cooks the same order twice at the same time (lock), and reports clearly
what happened (exit codes and logs).

## See it work

### Clean up with trap

```bash
#!/bin/bash
set -euo pipefail
tmp=$(mktemp -d)                    # private, unique temp directory
trap 'rm -rf "$tmp"' EXIT           # runs however the script ends
cp /etc/hostname "$tmp/"
ls "$tmp"
```

`mktemp -d` creates something like `/tmp/tmp.k3J9x2`, readable only by you.
`trap '...' EXIT` runs when the script exits, whether normally, by `exit 1`,
by an error under `set -e`, or by Ctrl+C. No more stale temp files.

### Validate inputs first

```bash
src=${1:?usage: backup.sh SRC_DIR DEST_DIR}
dest=${2:?usage: backup.sh SRC_DIR DEST_DIR}
[ -d "$src" ] || { echo "no such dir: $src" >&2; exit 2; }
command -v tar >/dev/null || { echo "tar not installed" >&2; exit 127; }
```

Check everything before changing anything.

### Never run twice at once

A cron job every 5 minutes that sometimes takes 7 will overlap and corrupt its
own output. A lock prevents that:

```bash
exec 9>/tmp/backup.lock
flock -n 9 || { echo "already running" >&2; exit 0; }
```

Or from cron directly: `flock -n /tmp/backup.lock /opt/backup.sh`.

### Be idempotent

**Idempotent** = running it twice is as safe as running it once.

```bash
mkdir -p "$dest"                 # not mkdir
ln -sfn "$release" current       # replace the link, do not fail
grep -qx 'umask 027' ~/.bashrc || echo 'umask 027' >> ~/.bashrc   # add once
```

### Log usefully

```bash
log() { echo "$(date -Is) $*" >&2; }
log "backup of $src started"
logger -t backup "finished OK"     # write to syslog/the journal
```

### Run shellcheck

```bash
shellcheck backup.sh
```

```
In backup.sh line 7:
cp $src $dest
   ^--^ SC2086 (info): Double quote to prevent globbing and word splitting.
```

`shellcheck` finds unquoted variables, useless `cat`s, wrong tests and many
classic bugs. Run it on every script (`apt install shellcheck`).

### For cron and systemd

- Use **full paths** or set `PATH` at the top.
- Keep output: `>> /var/log/job.log 2>&1`, or let systemd collect it.
- Return **meaningful exit codes** so monitoring can alert.

## Try it

Your script creates `/tmp/report.csv` and sometimes crashes halfway, leaving a
half-written file that tomorrow's run mistakes for a finished one. Name two
changes that fix it.

<details>
<summary>Show answer</summary>

Write into `tmp=$(mktemp)` with `trap 'rm -f "$tmp"' EXIT`, and only
`mv "$tmp" /tmp/report.csv` at the very end. `mv` within one filesystem is
atomic: readers see the old file or the complete new one, never half of one.

</details>

## Common mistakes

- **Fixed temp names like `/tmp/data`.** Two runs collide, and other users can
  pre-create the file. Use `mktemp`.
- **Cleanup only at the end of the script.** A failure skips it. Use `trap`.
- **Writing results in place.** Readers see half-written files. Write to temp,
  then `mv`.
- **Ignoring shellcheck warnings.** They are almost always real bugs.

## Remember

- `mktemp -d` + `trap 'rm -rf "$tmp"' EXIT`.
- Validate inputs and dependencies before doing anything.
- `flock -n` against overlapping runs; idempotent commands (`mkdir -p`, `ln -sfn`).
- Write to temp then `mv`; run `shellcheck`.

**Self-check:**

1. When does a `trap ... EXIT` run?
2. What does idempotent mean?
3. Why write to a temp file and then `mv`?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('64a3a363-df99-5bae-aeba-0d274cc5bcd0', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'Lab: Teach Atlas Its Chores', 'notes', 6, $md$## Why this matters

Time to make atlas do your chores. You write a loop, a script with proper
arguments and exit codes, a service watchdog and the backup script Rhea asked
for. The checks run your scripts with different inputs, including bad ones, so
error handling matters. Each task is checked automatically.

## Before you start

```bash
cd ~/work/scripts
cat services.txt
```

Expected output:

```
nginx running
brewbot stopped
postgres running
redis failed
cron running
```

## Task 1: five reports with one loop

Using a `for` loop at the prompt, create `~/work/scripts/reports/` with
`report-1.txt` to `report-5.txt`, each holding one line `Report N`.

[[lab-task:1]]

## Task 2: your first real script

Write the executable script `~/work/scripts/greet.sh`. It starts with a bash
shebang and has `set -euo pipefail` in its first lines. `greet.sh Rhea` prints
exactly `Hello, Rhea! Welcome to Atlas.`. With no argument it prints a message
containing `Usage` to stderr and exits with status 1.

[[lab-task:2]]

## Task 3: a service watchdog

Write the executable script `~/work/scripts/check-services.sh`. It takes a file
name; each line is `NAME STATUS`. For every service not `running` it prints
`ALERT: NAME is STATUS`, in file order. Its exit status is the number of
services that are not running (0 when all are fine).

[[lab-task:3]]

What you should see:

```
$ ./check-services.sh services.txt; echo "exit=$?"
ALERT: brewbot is stopped
ALERT: redis is failed
exit=2
```

## Task 4: the backup script Rhea asked for

Write the executable script `~/work/scripts/backup.sh SRC_DIR DEST_DIR`. It
creates `DEST_DIR` if needed and writes `DEST_DIR/NAME-YYYYMMDD.tar.gz`, where
`NAME` is the last part of `SRC_DIR` and `YYYYMMDD` is today's date. If
`SRC_DIR` is not an existing directory it prints an error to stderr and exits
with status 2.

[[lab-task:4]]

What you should see:

```
$ ./backup.sh /home/labuser/work/scripts /tmp/backups
/tmp/backups/scripts-20261014.tar.gz
```

## Remember

- Shebang, `set -euo pipefail`, `chmod +x`.
- Check `$#` and directories first; errors to `>&2` with a non-zero `exit`.
- `while read -r a b; do ...; done < "$1"` processes a file.
- `$(basename "$1")`, `$(date +%Y%m%d)` and quotes everywhere.

> **End of day 9.** Atlas now checks its own services and backs itself up every
> night. Rhea: "Before Black Friday I want you to understand what is really
> going on inside atlas, how to find what is slow, and how to lock it down."
> Tom's note: "Look under the hood."
$md$, 35, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '64a3a363-df99-5bae-aeba-0d274cc5bcd0', 'module', 'Lab: Teach Atlas Its Chores', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$mkdir -p /home/labuser/work
mkdir -p /home/labuser/work/scripts && chmod 777 /home/labuser/work/scripts
cat > /home/labuser/work/scripts/services.txt <<'MFEOF'
nginx running
brewbot stopped
postgres running
redis failed
cron running

MFEOF
chmod 666 /home/labuser/work/scripts/services.txt
rm -rf /home/labuser/work/scripts/reports /tmp/vb-src /tmp/vb-dest
$script$, NULL, 60, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '52bb484d-fd27-5861-861c-e0f1a4c6d641' AND id NOT IN ('851854b4-5edb-5760-86e5-a078f5f4672d', '20187e3c-bc71-5d45-b38c-e3acd611d333', 'f0e37c21-973f-507e-9e43-3ed1e59b2fb6', '9340dc4e-7314-5d54-b3ed-fa1bfdab3ec2');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '52bb484d-fd27-5861-861c-e0f1a4c6d641';
DELETE FROM lab_tasks WHERE lab_id = '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334' AND id NOT IN ('c5474ddd-1078-58de-bac2-b0a41d39c5f9', '9bc18c52-4bb1-57e0-b895-de397eeeaf8c', '448d095d-099e-5f3e-9b6d-dd9a03d44ed4', 'b389305a-d6a0-5c43-aba7-2ac0aac31735');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('c5474ddd-1078-58de-bac2-b0a41d39c5f9', '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', 1, 'Five reports with one loop', $md$Using a for loop at the prompt, create the directory /home/labuser/work/scripts/reports containing report-1.txt to report-5.txt, where each file holds one line "Report N" (Report 1, Report 2, ...).$md$, $script$d=/home/labuser/work/scripts/reports
for n in 1 2 3 4 5; do [ "$(cat $d/report-$n.txt)" = "Report $n" ] || exit 1; done
$script$, 'mkdir -p the directory, then: for n in 1 2 3 4 5; do echo "Report $n" > DIR/report-$n.txt; done - or use {1..5} instead of listing the numbers.', 'A for loop repeats a command for each word in a list. {1..5} is brace expansion that generates 1 2 3 4 5 before the loop even runs.', 15, false, true),
('9bc18c52-4bb1-57e0-b895-de397eeeaf8c', '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', 2, 'Your first real script', $md$Write the executable script /home/labuser/work/scripts/greet.sh. It must start with a bash shebang and have set -euo pipefail in its first lines. greet.sh Rhea prints exactly "Hello, Rhea! Welcome to Atlas.". Run with no argument, it prints a message containing the word Usage to stderr and exits with status 1.$md$, $script$s=/home/labuser/work/scripts/greet.sh
[ -x $s ] && head -1 $s | grep -q '^#!.*bash' && head -5 $s | grep -q 'set -euo pipefail' &&
[ "$($s Rhea)" = "Hello, Rhea! Welcome to Atlas." ] &&
[ -z "$($s 2>/dev/null)" ] && $s 2>&1 >/dev/null | grep -q Usage || exit 1
$s >/dev/null 2>&1; [ $? -eq 1 ]
$script$, 'Check the argument count with if [ $# -lt 1 ]. echo "..." >&2 writes to stderr, and exit 1 sets the status. Do not forget chmod +x.', '$# is the argument count and $1 the first argument. Errors go to stderr and a non-zero exit status, so callers and pipelines can tell success from failure.', 25, false, true),
('448d095d-099e-5f3e-9b6d-dd9a03d44ed4', '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', 3, 'A service watchdog', $md$Write the executable script /home/labuser/work/scripts/check-services.sh. It takes a file name as its argument, where each line is "NAME STATUS" (see scripts/services.txt). For every service whose status is not running it prints "ALERT: NAME is STATUS", in file order. Its exit status is the number of services that are not running (0 when everything is fine).$md$, $script$s=/home/labuser/work/scripts/check-services.sh
[ -x $s ] || exit 1
out=$($s /home/labuser/work/scripts/services.txt); rc=$?
[ $rc -eq 2 ] && [ "$out" = "$(printf 'ALERT: brewbot is stopped\nALERT: redis is failed')" ] || exit 1
printf 'a running\nb running\n' > /tmp/vb-ok.txt
out=$($s /tmp/vb-ok.txt); rc=$?
rm -f /tmp/vb-ok.txt
[ $rc -eq 0 ] && [ -z "$out" ]
$script$, 'while read -r name status; do ... done < "$1" reads the file line by line into two variables. Keep a counter with down=$((down + 1)) and finish with exit $down.', 'while read is the standard way to process a file line by line. Using the exit status as a count lets other tools (cron, monitoring) react without parsing the output.', 30, false, true),
('b389305a-d6a0-5c43-aba7-2ac0aac31735', '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', 4, 'The backup script Rhea asked for', $md$Write the executable script /home/labuser/work/scripts/backup.sh taking SRC_DIR and DEST_DIR. It creates DEST_DIR if needed and writes DEST_DIR/NAME-YYYYMMDD.tar.gz, where NAME is the last part of SRC_DIR and YYYYMMDD is today's date. If SRC_DIR is not an existing directory it prints an error to stderr and exits with status 2.$md$, $script$s=/home/labuser/work/scripts/backup.sh
[ -x $s ] || exit 1
rm -rf /tmp/vb-src /tmp/vb-dest && mkdir -p /tmp/vb-src && echo beans > /tmp/vb-src/a.txt
$s /tmp/vb-src /tmp/vb-dest >/dev/null 2>&1 || exit 1
f=/tmp/vb-dest/vb-src-$(date +%Y%m%d).tar.gz
[ -f $f ] && tar -tzf $f | grep -q 'a.txt' || exit 1
$s /tmp/no-such-dir /tmp/vb-dest >/dev/null 2>&1; rc=$?
rm -rf /tmp/vb-src /tmp/vb-dest
[ $rc -eq 2 ]
$script$, 'name=$(basename "$1") and today=$(date +%Y%m%d) build the file name. Test the source with if [ ! -d "$1" ]. tar -czf "$out" -C "$(dirname "$1")" "$name" keeps the paths short.', 'Command substitution $(...) captures a command''s output into a variable. Quoting every "$variable" keeps the script working when paths contain spaces.', 30, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('52bb484d-fd27-5861-861c-e0f1a4c6d641', '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', 1, $json$[{"id":"c5474ddd-1078-58de-bac2-b0a41d39c5f9","lab_id":"85eb0f03-4f8b-50fe-8f6c-e3e2cd227334","position":1,"title":"Five reports with one loop","description":"Using a for loop at the prompt, create the directory /home/labuser/work/scripts/reports containing report-1.txt to report-5.txt, where each file holds one line \"Report N\" (Report 1, Report 2, ...).","verification_script":"d=/home/labuser/work/scripts/reports\nfor n in 1 2 3 4 5; do [ \"$(cat $d/report-$n.txt)\" = \"Report $n\" ] || exit 1; done\n","hint_context":"mkdir -p the directory, then: for n in 1 2 3 4 5; do echo \"Report $n\" \u003e DIR/report-$n.txt; done - or use {1..5} instead of listing the numbers.","explanation_context":"A for loop repeats a command for each word in a list. {1..5} is brace expansion that generates 1 2 3 4 5 before the loop even runs.","points":15,"is_optional":false,"is_stateful":true},{"id":"9bc18c52-4bb1-57e0-b895-de397eeeaf8c","lab_id":"85eb0f03-4f8b-50fe-8f6c-e3e2cd227334","position":2,"title":"Your first real script","description":"Write the executable script /home/labuser/work/scripts/greet.sh. It must start with a bash shebang and have set -euo pipefail in its first lines. greet.sh Rhea prints exactly \"Hello, Rhea! Welcome to Atlas.\". Run with no argument, it prints a message containing the word Usage to stderr and exits with status 1.","verification_script":"s=/home/labuser/work/scripts/greet.sh\n[ -x $s ] \u0026\u0026 head -1 $s | grep -q '^#!.*bash' \u0026\u0026 head -5 $s | grep -q 'set -euo pipefail' \u0026\u0026\n[ \"$($s Rhea)\" = \"Hello, Rhea! Welcome to Atlas.\" ] \u0026\u0026\n[ -z \"$($s 2\u003e/dev/null)\" ] \u0026\u0026 $s 2\u003e\u00261 \u003e/dev/null | grep -q Usage || exit 1\n$s \u003e/dev/null 2\u003e\u00261; [ $? -eq 1 ]\n","hint_context":"Check the argument count with if [ $# -lt 1 ]. echo \"...\" \u003e\u00262 writes to stderr, and exit 1 sets the status. Do not forget chmod +x.","explanation_context":"$# is the argument count and $1 the first argument. Errors go to stderr and a non-zero exit status, so callers and pipelines can tell success from failure.","points":25,"is_optional":false,"is_stateful":true},{"id":"448d095d-099e-5f3e-9b6d-dd9a03d44ed4","lab_id":"85eb0f03-4f8b-50fe-8f6c-e3e2cd227334","position":3,"title":"A service watchdog","description":"Write the executable script /home/labuser/work/scripts/check-services.sh. It takes a file name as its argument, where each line is \"NAME STATUS\" (see scripts/services.txt). For every service whose status is not running it prints \"ALERT: NAME is STATUS\", in file order. Its exit status is the number of services that are not running (0 when everything is fine).","verification_script":"s=/home/labuser/work/scripts/check-services.sh\n[ -x $s ] || exit 1\nout=$($s /home/labuser/work/scripts/services.txt); rc=$?\n[ $rc -eq 2 ] \u0026\u0026 [ \"$out\" = \"$(printf 'ALERT: brewbot is stopped\\nALERT: redis is failed')\" ] || exit 1\nprintf 'a running\\nb running\\n' \u003e /tmp/vb-ok.txt\nout=$($s /tmp/vb-ok.txt); rc=$?\nrm -f /tmp/vb-ok.txt\n[ $rc -eq 0 ] \u0026\u0026 [ -z \"$out\" ]\n","hint_context":"while read -r name status; do ... done \u003c \"$1\" reads the file line by line into two variables. Keep a counter with down=$((down + 1)) and finish with exit $down.","explanation_context":"while read is the standard way to process a file line by line. Using the exit status as a count lets other tools (cron, monitoring) react without parsing the output.","points":30,"is_optional":false,"is_stateful":true},{"id":"b389305a-d6a0-5c43-aba7-2ac0aac31735","lab_id":"85eb0f03-4f8b-50fe-8f6c-e3e2cd227334","position":4,"title":"The backup script Rhea asked for","description":"Write the executable script /home/labuser/work/scripts/backup.sh taking SRC_DIR and DEST_DIR. It creates DEST_DIR if needed and writes DEST_DIR/NAME-YYYYMMDD.tar.gz, where NAME is the last part of SRC_DIR and YYYYMMDD is today's date. If SRC_DIR is not an existing directory it prints an error to stderr and exits with status 2.","verification_script":"s=/home/labuser/work/scripts/backup.sh\n[ -x $s ] || exit 1\nrm -rf /tmp/vb-src /tmp/vb-dest \u0026\u0026 mkdir -p /tmp/vb-src \u0026\u0026 echo beans \u003e /tmp/vb-src/a.txt\n$s /tmp/vb-src /tmp/vb-dest \u003e/dev/null 2\u003e\u00261 || exit 1\nf=/tmp/vb-dest/vb-src-$(date +%Y%m%d).tar.gz\n[ -f $f ] \u0026\u0026 tar -tzf $f | grep -q 'a.txt' || exit 1\n$s /tmp/no-such-dir /tmp/vb-dest \u003e/dev/null 2\u003e\u00261; rc=$?\nrm -rf /tmp/vb-src /tmp/vb-dest\n[ $rc -eq 2 ]\n","hint_context":"name=$(basename \"$1\") and today=$(date +%Y%m%d) build the file name. Test the source with if [ ! -d \"$1\" ]. tar -czf \"$out\" -C \"$(dirname \"$1\")\" \"$name\" keeps the paths short.","explanation_context":"Command substitution $(...) captures a command's output into a variable. Quoting every \"$variable\" keeps the script working when paths contain spaces.","points":30,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('851854b4-5edb-5760-86e5-a078f5f4672d', '52bb484d-fd27-5861-861c-e0f1a4c6d641', 'c5474ddd-1078-58de-bac2-b0a41d39c5f9', 1, 'Five reports with one loop', $md$Using a for loop at the prompt, create the directory /home/labuser/work/scripts/reports containing report-1.txt to report-5.txt, where each file holds one line "Report N" (Report 1, Report 2, ...).$md$, $script$d=/home/labuser/work/scripts/reports
for n in 1 2 3 4 5; do [ "$(cat $d/report-$n.txt)" = "Report $n" ] || exit 1; done
$script$, 'mkdir -p the directory, then: for n in 1 2 3 4 5; do echo "Report $n" > DIR/report-$n.txt; done - or use {1..5} instead of listing the numbers.', 'A for loop repeats a command for each word in a list. {1..5} is brace expansion that generates 1 2 3 4 5 before the loop even runs.', 15, false, true),
('20187e3c-bc71-5d45-b38c-e3acd611d333', '52bb484d-fd27-5861-861c-e0f1a4c6d641', '9bc18c52-4bb1-57e0-b895-de397eeeaf8c', 2, 'Your first real script', $md$Write the executable script /home/labuser/work/scripts/greet.sh. It must start with a bash shebang and have set -euo pipefail in its first lines. greet.sh Rhea prints exactly "Hello, Rhea! Welcome to Atlas.". Run with no argument, it prints a message containing the word Usage to stderr and exits with status 1.$md$, $script$s=/home/labuser/work/scripts/greet.sh
[ -x $s ] && head -1 $s | grep -q '^#!.*bash' && head -5 $s | grep -q 'set -euo pipefail' &&
[ "$($s Rhea)" = "Hello, Rhea! Welcome to Atlas." ] &&
[ -z "$($s 2>/dev/null)" ] && $s 2>&1 >/dev/null | grep -q Usage || exit 1
$s >/dev/null 2>&1; [ $? -eq 1 ]
$script$, 'Check the argument count with if [ $# -lt 1 ]. echo "..." >&2 writes to stderr, and exit 1 sets the status. Do not forget chmod +x.', '$# is the argument count and $1 the first argument. Errors go to stderr and a non-zero exit status, so callers and pipelines can tell success from failure.', 25, false, true),
('f0e37c21-973f-507e-9e43-3ed1e59b2fb6', '52bb484d-fd27-5861-861c-e0f1a4c6d641', '448d095d-099e-5f3e-9b6d-dd9a03d44ed4', 3, 'A service watchdog', $md$Write the executable script /home/labuser/work/scripts/check-services.sh. It takes a file name as its argument, where each line is "NAME STATUS" (see scripts/services.txt). For every service whose status is not running it prints "ALERT: NAME is STATUS", in file order. Its exit status is the number of services that are not running (0 when everything is fine).$md$, $script$s=/home/labuser/work/scripts/check-services.sh
[ -x $s ] || exit 1
out=$($s /home/labuser/work/scripts/services.txt); rc=$?
[ $rc -eq 2 ] && [ "$out" = "$(printf 'ALERT: brewbot is stopped\nALERT: redis is failed')" ] || exit 1
printf 'a running\nb running\n' > /tmp/vb-ok.txt
out=$($s /tmp/vb-ok.txt); rc=$?
rm -f /tmp/vb-ok.txt
[ $rc -eq 0 ] && [ -z "$out" ]
$script$, 'while read -r name status; do ... done < "$1" reads the file line by line into two variables. Keep a counter with down=$((down + 1)) and finish with exit $down.', 'while read is the standard way to process a file line by line. Using the exit status as a count lets other tools (cron, monitoring) react without parsing the output.', 30, false, true),
('9340dc4e-7314-5d54-b3ed-fa1bfdab3ec2', '52bb484d-fd27-5861-861c-e0f1a4c6d641', 'b389305a-d6a0-5c43-aba7-2ac0aac31735', 4, 'The backup script Rhea asked for', $md$Write the executable script /home/labuser/work/scripts/backup.sh taking SRC_DIR and DEST_DIR. It creates DEST_DIR if needed and writes DEST_DIR/NAME-YYYYMMDD.tar.gz, where NAME is the last part of SRC_DIR and YYYYMMDD is today's date. If SRC_DIR is not an existing directory it prints an error to stderr and exits with status 2.$md$, $script$s=/home/labuser/work/scripts/backup.sh
[ -x $s ] || exit 1
rm -rf /tmp/vb-src /tmp/vb-dest && mkdir -p /tmp/vb-src && echo beans > /tmp/vb-src/a.txt
$s /tmp/vb-src /tmp/vb-dest >/dev/null 2>&1 || exit 1
f=/tmp/vb-dest/vb-src-$(date +%Y%m%d).tar.gz
[ -f $f ] && tar -tzf $f | grep -q 'a.txt' || exit 1
$s /tmp/no-such-dir /tmp/vb-dest >/dev/null 2>&1; rc=$?
rm -rf /tmp/vb-src /tmp/vb-dest
[ $rc -eq 2 ]
$script$, 'name=$(basename "$1") and today=$(date +%Y%m%d) build the file name. Test the source with if [ ! -d "$1" ]. tar -czf "$out" -C "$(dirname "$1")" "$name" keeps the paths short.', 'Command substitution $(...) captures a command''s output into a variable. Quoting every "$variable" keeps the script working when paths contain spaces.', 30, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '52bb484d-fd27-5861-861c-e0f1a4c6d641', updated_at = now()
WHERE id = '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('caeec16b-d5c7-599c-a28b-2348b83e1641', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'Reference: Bash Scripting Cheat Sheet', 'notes', 7, $md$## How to use this page

A reference for writing scripts. Everything here was explained in lessons 1-6 of
this chapter. Keep it open while you write; do not memorise it.

## Script template

```bash
#!/bin/bash
# name.sh - one line saying what this does
set -euo pipefail

usage() { echo "Usage: $0 SRC DEST" >&2; exit 2; }
log()   { echo "$(date -Is) $*" >&2; }

[ $# -eq 2 ] || usage
src=$1 dest=$2
[ -d "$src" ] || { log "no such dir: $src"; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

log "start"
# ... work in "$tmp", then mv results into place ...
log "done"
```

## Variables and expansion

| Syntax | Meaning |
|---|---|
| `x=1` / `"$x"` / `"${x}y"` | set / use / use next to text |
| `$(cmd)` / `$((a + b))` | command output / arithmetic |
| `${x:-def}` / `${x:=def}` | default / default and assign |
| `${x:?msg}` | stop with msg if unset or empty |
| `${#x}` | length |
| `${f##*/}` / `${f%/*}` | basename / dirname |
| `${f%.log}` / `${f#prefix}` | strip suffix / prefix |
| `${x/old/new}` / `${x//old/new}` | replace first / all |
| `${x^^}` / `${x,,}` | upper / lower case |

## Special parameters

`$0` script, `$1..$9` args, `$#` count, `"$@"` all args, `$?` last status,
`$$` PID, `$!` last background PID, `shift` drops `$1`.

## Tests

| Test | True when |
|---|---|
| `-e` `-f` `-d` `-L` | exists / file / directory / symlink |
| `-r` `-w` `-x` `-s` | readable / writable / executable / non-empty |
| `-z "$s"` / `-n "$s"` | empty / not empty |
| `=` `!=` | string equal / different |
| `-eq -ne -lt -le -gt -ge` | numeric |
| `[[ $s == *.log ]]` / `[[ $s =~ ^[0-9]+$ ]]` | glob / regex match |
| `(( n > 3 ))` | arithmetic |

## Control flow

```bash
if cmd; then ...; elif [ ... ]; then ...; else ...; fi
case "$1" in start) ... ;; stop|halt) ... ;; *) usage ;; esac
for x in a b c; do ...; done
for n in {1..10}; do ...; done
for ((i = 0; i < 5; i++)); do ...; done
while read -r a b; do ...; done < file
while read -r line; do ...; done < <(cmd)
until cmd; do sleep 2; done
cmd1 && cmd2 || cmd3
```

## Functions and arrays

```bash
f() { local a=$1; ...; return 0; }
arr=(a b c); "${arr[@]}"; ${#arr[@]}; arr+=(d)
declare -A m=([web]=80); "${m[web]}"
while getopts "vd:" o; do case $o in v) v=1;; d) d=$OPTARG;; esac; done; shift $((OPTIND-1))
```

## Exit codes

`0` ok, `1` general error, `2` usage, `126` not executable, `127` not found,
`128+N` killed by signal N (`130` Ctrl+C, `137` SIGKILL, `143` SIGTERM).

## Debugging and quality

| Tool | Use |
|---|---|
| `bash -n script` | syntax check only |
| `bash -x script` / `set -x` | trace every command |
| `shellcheck script` | lint for classic bugs |
| `PS4='+ ${LINENO}: '` | show line numbers in traces |

## Robustness checklist

- `set -euo pipefail`; quote every expansion.
- Validate arguments and required commands first.
- `mktemp` + `trap ... EXIT` for temporary files.
- Write to temp, then `mv` into place.
- `flock -n` for jobs that must not overlap.
- Full paths for cron; errors to stderr; meaningful exit codes.
$md$, 5, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d4c0e3b4-1c43-5ec0-94df-96eddca4a8b3', '00000000-0000-0000-0000-000000000001', 'mcq', 'A cleanup script runs cd /srv/build; rm -rf ./*. One night /srv/build does no...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ce0b440e-584a-56d1-a275-7f9de2461fa5', 'd4c0e3b4-1c43-5ec0-94df-96eddca4a8b3', 1, $json${"prompt":"A cleanup script runs cd /srv/build; rm -rf ./*. One night /srv/build does not exist. Without set -e, what happens?","multiple":false,"options":[{"id":"a","text":"cd fails, the script continues, and rm -rf ./* deletes the contents of whatever directory it was started in","is_correct":true},{"id":"b","text":"rm refuses because cd failed","is_correct":false},{"id":"c","text":"bash stops automatically on any error","is_correct":false},{"id":"d","text":"Nothing, ./* is empty","is_correct":false}],"explanation":"Without set -e (or cd ... || exit 1), bash runs the next line anyway in the old directory. rm does not know cd failed, and bash does not stop by default."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b5bb4e8a-8179-50b5-acae-8fbca06a2f03', '00000000-0000-0000-0000-000000000001', 'mcq', 'file=''Q3 report.csv''. Which command copies it correctly?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('de8c11c6-4037-5296-af10-88e317a848ee', 'b5bb4e8a-8179-50b5-acae-8fbca06a2f03', 1, $json${"prompt":"file='Q3 report.csv'. Which command copies it correctly?","multiple":false,"options":[{"id":"a","text":"cp \"$file\" /backup/","is_correct":true},{"id":"b","text":"cp $file /backup/","is_correct":false},{"id":"c","text":"cp '$file' /backup/","is_correct":false},{"id":"d","text":"cp ${file} /backup/","is_correct":false}],"explanation":"Double quotes keep the value as one argument. Unquoted (with or without braces) it splits into Q3 and report.csv, and single quotes pass the literal text $file."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5f76a47c-d1ce-566d-934e-55facaada697', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does set -o pipefail change in: curl -s URL | jq .version?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5a425f54-9f0d-50fa-b932-c3f678d632a9', '5f76a47c-d1ce-566d-934e-55facaada697', 1, $json${"prompt":"What does set -o pipefail change in: curl -s URL | jq .version?","multiple":false,"options":[{"id":"a","text":"If curl fails, the pipeline's status is non-zero even though jq succeeded","is_correct":true},{"id":"b","text":"It makes curl retry","is_correct":false},{"id":"c","text":"It hides jq errors","is_correct":false},{"id":"d","text":"Nothing; pipelines always report the first command","is_correct":false}],"explanation":"Without pipefail a pipeline returns the last command's status, hiding earlier failures. pipefail returns the status of the last failing stage. It does not retry or hide anything."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f2a90355-7680-593f-a32c-693b8fee33b6', '00000000-0000-0000-0000-000000000001', 'mcq', 'In Bash, what exit status means a command succeeded?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('fb3b1fe3-c854-55ef-9e54-dcc96af25821', 'f2a90355-7680-593f-a32c-693b8fee33b6', 1, $json${"prompt":"In Bash, what exit status means a command succeeded?","multiple":false,"options":[{"id":"a","text":"0","is_correct":true},{"id":"b","text":"1","is_correct":false},{"id":"c","text":"-1","is_correct":false},{"id":"d","text":"255","is_correct":false}],"explanation":"Zero is a hero: 0 is success, any other number is a failure code. if, \u0026\u0026 and || all check it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7cb40c53-e416-5008-92bb-76dd13820a9d', '00000000-0000-0000-0000-000000000001', 'mcq', 'This loop prints count=0 at the end even though the file has lines: count=0; ...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('43be2dae-895f-5faa-a689-f570bef5d4fc', '7cb40c53-e416-5008-92bb-76dd13820a9d', 1, $json${"prompt":"This loop prints count=0 at the end even though the file has lines: count=0; cat f | while read -r l; do count=$((count+1)); done; echo count=$count. Why?","multiple":false,"options":[{"id":"a","text":"The pipe runs the while loop in a subshell, so its count is lost; use done \u003c f instead","is_correct":true},{"id":"b","text":"read -r skips every line","is_correct":false},{"id":"c","text":"Arithmetic does not work in loops","is_correct":false},{"id":"d","text":"count must be exported","is_correct":false}],"explanation":"Each side of a pipe runs in a child process; changes inside vanish when it ends. Redirecting the file into the loop keeps it in the current shell. read works, arithmetic works, and export only passes copies to children."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('57b8a6b1-e006-5265-8c62-7d4329912166', '00000000-0000-0000-0000-000000000001', 'mcq', 'A script creates temporary files and is sometimes stopped with Ctrl+C, leavin...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c4fe25dc-18ff-59cd-be67-a97d8d717d05', '57b8a6b1-e006-5265-8c62-7d4329912166', 1, $json${"prompt":"A script creates temporary files and is sometimes stopped with Ctrl+C, leaving junk behind. What is the cleanest fix?","multiple":false,"options":[{"id":"a","text":"tmp=$(mktemp -d); trap 'rm -rf \"$tmp\"' EXIT","is_correct":true},{"id":"b","text":"Add rm -rf /tmp/* at the end of the script","is_correct":false},{"id":"c","text":"Tell users not to press Ctrl+C","is_correct":false},{"id":"d","text":"Run the script with nohup","is_correct":false}],"explanation":"The EXIT trap runs however the script ends. A final rm never runs after an interrupt and would delete other people's files, and nohup is about hang-ups, not cleanup."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('49f94ab8-9a02-51bb-ac84-9ac9c9be577f', '00000000-0000-0000-0000-000000000001', 'mcq', 'Inside a function you write exit 1 when a check fails, and the whole deploy s...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2981964b-3563-5a58-b513-39347c63f8d6', '49f94ab8-9a02-51bb-ac84-9ac9c9be577f', 1, $json${"prompt":"Inside a function you write exit 1 when a check fails, and the whole deploy script stops. What did you probably want?","multiple":false,"options":[{"id":"a","text":"return 1, so the caller can decide what to do","is_correct":true},{"id":"b","text":"break 1","is_correct":false},{"id":"c","text":"continue","is_correct":false},{"id":"d","text":"exit 0","is_correct":false}],"explanation":"return sets the function's status; exit ends the entire script. break and continue are for loops, and exit 0 would still end the script, reporting success."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e9b45515-b1e1-5359-877d-ab70ae8c6944', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does set -euo pipefail at the top of a Bash script do?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('436ca426-c94f-5eb1-90ff-0349d4cb6112', 'e9b45515-b1e1-5359-877d-ab70ae8c6944', 1, $json${"prompt":"What does set -euo pipefail at the top of a Bash script do?","multiple":false,"options":[{"id":"a","text":"Stops on the first failing command, errors on unset variables, and fails a pipeline if any part fails","is_correct":true},{"id":"b","text":"Runs the script as root","is_correct":false},{"id":"c","text":"Enables colour output and Unicode","is_correct":false},{"id":"d","text":"Makes the script run in the background","is_correct":false}],"explanation":"-e exit on error, -u treat unset variables as errors, -o pipefail make a pipeline's status reflect any failing stage. It does not change users, colours or job control."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('fbe33f9d-7860-5404-bf2c-df72e19935fe', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 8): your watchdog script should treat brewbot as down when it...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5355820c-5079-502e-9071-4e3daf2b6a4f', 'fbe33f9d-7860-5404-bf2c-df72e19935fe', 1, $json${"prompt":"Review (chapter 8): your watchdog script should treat brewbot as down when it returns HTTP 500. Which check is right?","multiple":false,"options":[{"id":"a","text":"if curl -sf --max-time 3 http://localhost:8080/health \u003e/dev/null; then ok; else alert; fi","is_correct":true},{"id":"b","text":"if curl -s http://localhost:8080/health; then ok; fi","is_correct":false},{"id":"c","text":"if ping -c1 localhost; then ok; fi","is_correct":false},{"id":"d","text":"if ss -tln | grep -q 8080; then ok; fi","is_correct":false}],"explanation":"-f turns HTTP errors into a non-zero exit, and --max-time stops it hanging. Without -f a 500 still counts as success; ping and ss only prove the host or port exists, not that the app is healthy."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('3107011d-f53e-5a68-8d18-ab73502437fe', '00000000-0000-0000-0000-000000000001', 'Quiz: Bash Scripting', 'linux-teaching-atlas-tricks-quiz', 'Quiz covering Chapter 9: Teaching Atlas Tricks - Bash Scripting.', 'mcq', 'published', 'module', '55c6c650-559a-5777-b18e-471216cab061', 12, 70, 5, 18, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '3107011d-f53e-5a68-8d18-ab73502437fe' AND question_id NOT IN ('d4c0e3b4-1c43-5ec0-94df-96eddca4a8b3', 'b5bb4e8a-8179-50b5-acae-8fbca06a2f03', '5f76a47c-d1ce-566d-934e-55facaada697', 'f2a90355-7680-593f-a32c-693b8fee33b6', '7cb40c53-e416-5008-92bb-76dd13820a9d', '57b8a6b1-e006-5265-8c62-7d4329912166', '49f94ab8-9a02-51bb-ac84-9ac9c9be577f', 'e9b45515-b1e1-5359-877d-ab70ae8c6944', 'fbe33f9d-7860-5404-bf2c-df72e19935fe');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('b1b9867e-1b72-5c23-9573-76818d94e366', '3107011d-f53e-5a68-8d18-ab73502437fe', 'd4c0e3b4-1c43-5ec0-94df-96eddca4a8b3', 'ce0b440e-584a-56d1-a275-7f9de2461fa5', 0, 2),
('dae0a43d-98d5-521a-bfa8-f6dc44d000b9', '3107011d-f53e-5a68-8d18-ab73502437fe', 'b5bb4e8a-8179-50b5-acae-8fbca06a2f03', 'de8c11c6-4037-5296-af10-88e317a848ee', 1, 2),
('fb1a1585-c2d2-5c8c-88fa-4b9e05b50355', '3107011d-f53e-5a68-8d18-ab73502437fe', '5f76a47c-d1ce-566d-934e-55facaada697', '5a425f54-9f0d-50fa-b932-c3f678d632a9', 2, 2),
('2e5188ed-8695-5857-b2ed-bb43095840c1', '3107011d-f53e-5a68-8d18-ab73502437fe', 'f2a90355-7680-593f-a32c-693b8fee33b6', 'fb3b1fe3-c854-55ef-9e54-dcc96af25821', 3, 2),
('bfd4984d-4504-5f5f-bec9-44d8c5732499', '3107011d-f53e-5a68-8d18-ab73502437fe', '7cb40c53-e416-5008-92bb-76dd13820a9d', '43be2dae-895f-5faa-a689-f570bef5d4fc', 4, 2),
('5b23cf38-0723-5942-b314-67b3337465d8', '3107011d-f53e-5a68-8d18-ab73502437fe', '57b8a6b1-e006-5265-8c62-7d4329912166', 'c4fe25dc-18ff-59cd-be67-a97d8d717d05', 5, 2),
('5e89a266-0fd8-5846-b819-3334dc515b1d', '3107011d-f53e-5a68-8d18-ab73502437fe', '49f94ab8-9a02-51bb-ac84-9ac9c9be577f', '2981964b-3563-5a58-b513-39347c63f8d6', 6, 2),
('51a8c3ce-9c76-50f1-b4ed-52ebe2263198', '3107011d-f53e-5a68-8d18-ab73502437fe', 'e9b45515-b1e1-5359-877d-ab70ae8c6944', '436ca426-c94f-5eb1-90ff-0349d4cb6112', 7, 2),
('8c38220f-2877-53e4-a0b7-b99aa0d68051', '3107011d-f53e-5a68-8d18-ab73502437fe', 'fbe33f9d-7860-5404-bf2c-df72e19935fe', '5355820c-5079-502e-9071-4e3daf2b6a4f', 8, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('55c6c650-559a-5777-b18e-471216cab061', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'Quiz: Bash Scripting', 'assessment', 8, 10, '3107011d-f53e-5a68-8d18-ab73502437fe')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 10: Under the Hood - Kernel, Namespaces and cgroups
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('5db992b5-3341-59db-beb3-e76a644469d4', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 10: Under the Hood - Kernel, Namespaces and cgroups', 10, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('9958f366-25a0-5d32-8c62-dc48d5c2b7c2', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '5db992b5-3341-59db-beb3-e76a644469d4', 'User Space, Kernel Space, System Calls and sysctl', 'notes', 0, $md$## Why this matters

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
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b2f85ef8-d84e-5d7a-b11a-d8e4fe0bde1b', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '5db992b5-3341-59db-beb3-e76a644469d4', 'Namespaces: How Containers See Their Own World', 'notes', 1, $md$## Why this matters

Inside a container, `ps` shows three processes, PID 1 is your app, and the
hostname is a random string. On the host, the same app is PID 48213. Knowing why
lets you debug containers from the outside, and understand what isolation they
do and do not give.

## Mental model: tinted glasses

A **namespace** is a pair of tinted glasses the kernel puts on a process. With
them on, the process sees only its own slice of one kind of resource. Nothing is
virtualised; it is the same kernel, just filtered views.

| Namespace | The process sees its own... |
|---|---|
| `pid` | process numbers (it can be PID 1) |
| `mnt` | mount points and filesystem tree |
| `net` | network interfaces, IPs, ports, routes |
| `uts` | hostname |
| `ipc` | shared memory and message queues |
| `user` | user IDs (root inside can be nobody outside) |
| `cgroup` | view of the cgroup tree |
| `time` | some clocks |

```
 HOST view:  systemd(1) ... containerd ... brewbot(48213)
                                             |
 CONTAINER view (pid namespace):          brewbot(1)
```

> **Memory hook:** **namespaces = what you can SEE; cgroups = how much you can
> USE** (next lesson). A container is a process with both, plus a filesystem.

## See it work

Every process's namespaces are links in `/proc/PID/ns`. Two processes share a
namespace when the numbers match.

```bash
ls -l /proc/self/ns
```

Expected output (abridged, numbers differ):

```
lrwxrwxrwx 1 labuser labuser 0 ... mnt -> mnt:[4026532564]
lrwxrwxrwx 1 labuser labuser 0 ... net -> net:[4026533025]
lrwxrwxrwx 1 labuser labuser 0 ... pid -> pid:[4026533023]
lrwxrwxrwx 1 labuser labuser 0 ... uts -> uts:[4026532565]
```

```bash
readlink /proc/$$/ns/pid       # just one
lsns                           # all namespaces you can see, with a process in each
```

The lab itself runs in a container, so `ps aux` shows only a few processes and
`hostname` prints a random ID: you are wearing the glasses right now.

### Making namespaces (on your own Linux machine)

```bash
sudo unshare --uts --pid --fork --mount-proc bash
hostname sandbox      # changes the hostname only inside
ps aux                # only bash and ps: PID 1 is your bash
exit
```

`unshare` starts a program in new namespaces. Rootless containers use the
`user` namespace so an unprivileged user can be "root" inside
(`unshare -r` maps you to UID 0 there). This needs the kernel and host to allow
it, so it fails in many locked-down environments, including this lab.

### Stepping into a container from the host

```bash
pid=$(docker inspect -f '{{.State.Pid}}' web)    # the container's PID on the host
sudo nsenter -t "$pid" -n ss -tlnp                # run ss inside its network namespace
```

`nsenter` borrows another process's glasses. With `-n` you get the container's
network view while still using the host's tools: handy for minimal images that
have no `ss` or `curl`.

### What namespaces do not do

- They do not limit CPU or memory (that is cgroups).
- All containers share **one kernel**. A kernel bug can break out; that is why
  untrusted workloads use extra layers (seccomp, AppArmor/SELinux, gVisor,
  micro-VMs).

## Try it

Process A shows `net:[4026533025]` and process B shows `net:[4026531840]`. What
does that tell you about `ss -tln` run as each of them?

<details>
<summary>Show answer</summary>

They are in different network namespaces, so each sees its own interfaces and
listening ports. A service listening in B's namespace does not appear in A's
`ss` output, and `localhost` means something different for each.

</details>

## Common mistakes

- **Thinking a container is a small VM.** It is a process on the host kernel with
  filtered views.
- **Debugging container networking from the host's view.** Use `nsenter -n` or
  `docker exec` to see the container's own interfaces.
- **Assuming root in a container is harmless.** Without a user namespace, UID 0
  inside is UID 0 on the host, held back only by dropped capabilities and other
  layers.

## Remember

- Namespaces filter what a process sees: pid, mnt, net, uts, ipc, user, cgroup,
  time.
- `/proc/PID/ns/*` and `lsns` show them; same number = shared.
- `unshare` creates them, `nsenter` enters them.
- See (namespaces) vs Use (cgroups); one shared kernel.

**Self-check:**

1. Which namespace lets a container have its own PID 1?
2. How can you tell if two processes share a network namespace?
3. What does `nsenter -t PID -n` give you?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b0fcae15-7a36-5f87-8ee6-cea618c6ea6a', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '5db992b5-3341-59db-beb3-e76a644469d4', 'cgroups: Limiting What a Process Can Use', 'notes', 2, $md$## Why this matters

A memory leak in brewbot should kill brewbot, not the database next to it. A
runaway report should not eat every CPU during the sale. **cgroups** are how
Linux, systemd, Docker and Kubernetes put a fence around each service's
resources.

## Mental model: a fenced paddock with meters

A **control group (cgroup)** is a group of processes with:

- **limits** (fences): at most 512 MiB of memory, at most half a CPU, at most
  100 processes;
- **accounting** (meters): how much memory, CPU and IO the group is using now.

Groups form a tree. Modern systems use **cgroup v2**: one tree, mounted at
`/sys/fs/cgroup`. systemd puts every service in its own group:

```
 /sys/fs/cgroup/
   system.slice/
     nginx.service/        memory.current  memory.max  cpu.max  pids.max
     brewbot.service/
   user.slice/
     user-1000.slice/      your login sessions
```

When a group hits `memory.max`, the kernel's OOM killer kills a process **inside
that group**, not a random one on the machine.

## See it work

```bash
cat /proc/self/cgroup
```

Expected output inside the lab container:

```
0::/
```

`0::` means cgroup v2; the path after it is your group, relative to the tree you
can see (a cgroup namespace makes the container look like the root). Read the
fences and meters:

```bash
cat /sys/fs/cgroup/memory.max     # memory limit ("max" = unlimited)
cat /sys/fs/cgroup/memory.current # bytes in use now
cat /sys/fs/cgroup/cpu.max        # "QUOTA PERIOD": 50000 100000 = half a CPU
cat /sys/fs/cgroup/pids.max       # process limit
```

Example output for a container limited to 512 MiB and half a CPU:

```
536870912
84475904
50000 100000
max
```

### On a systemd server

```bash
systemctl status brewbot          # the CGroup: line shows its group
systemd-cgtop                     # top, per cgroup
systemd-cgls                      # the tree
sudo systemctl set-property brewbot MemoryMax=512M CPUQuota=50%
```

Or in the unit file (chapter 6):

```ini
[Service]
MemoryMax=512M
CPUQuota=50%
TasksMax=200
IOWeight=50
```

Run a one-off command in its own limited group:

```bash
sudo systemd-run --scope -p MemoryMax=200M -p CPUQuota=20% ./import-big-file.sh
```

### Containers are cgroups too

`docker run --memory 512m --cpus 0.5` and Kubernetes `resources.limits` write
exactly these files. A container killed with exit code **137** (SIGKILL) after
hitting its memory limit is the cgroup OOM killer at work; `memory.events` counts
`oom_kill`s.

`nproc` respects the CPUs you are allowed to use (affinity); CPU *quota* limits
show up in `cpu.max`, not in `nproc`.

## Try it

`cat /sys/fs/cgroup/system.slice/brewbot.service/memory.max` prints
`536870912`. Brewbot keeps getting killed with status 137 during the sale. What
is happening, and what are your options?

<details>
<summary>Show answer</summary>

536870912 bytes = 512 MiB. Brewbot reaches its cgroup memory limit and the
kernel OOM-kills it (137 = 128 + SIGKILL). Check `memory.events` for `oom_kill`
and the journal for the OOM message. Then either fix the leak/usage, or raise
`MemoryMax=` deliberately if the server has room.

</details>

## Common mistakes

- **No limits at all.** One leaking service takes the whole machine down.
- **Reading free memory on the host to judge a container.** The container's
  limit is in its cgroup (`memory.max`), not in `free`.
- **Confusing CPU quota with CPU count.** `cpu.max` 50000/100000 is half a CPU
  of time, spread across any cores.
- **Setting limits too tight.** Then the service is OOM-killed under normal
  load. Measure `memory.current` and `memory.peak` first.

## Remember

- cgroups = limits + accounting for groups of processes; v2 lives at
  `/sys/fs/cgroup`.
- Files: `memory.max/current`, `cpu.max`, `pids.max`, `memory.events`.
- systemd: `MemoryMax=`, `CPUQuota=`, `TasksMax=`; `systemd-cgtop`,
  `systemd-run -p`.
- Docker and Kubernetes limits are cgroups; 137 often = cgroup OOM kill.

**Self-check:**

1. Where do you read a container's memory limit from inside it?
2. What does `cpu.max` of `50000 100000` mean?
3. Which systemd setting caps a service's memory?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4ec6da49-ce7c-5503-bae2-95c23b81662d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '5db992b5-3341-59db-beb3-e76a644469d4', 'Lab: Look Under Atlas''s Hood', 'notes', 3, $md$## Why this matters

You have read about system calls, namespaces and cgroups. Now find them on a
real machine. This lab runs inside a container, so you are looking at exactly
the fences and glasses a container gets. Each task is checked automatically.

## Before you start

```bash
cat /proc/self/cgroup
ls -l /proc/self/ns
hostname
```

What this does: shows your cgroup, your namespaces, and a hostname that is
clearly not "atlas": the uts namespace at work.

## Task 1: which PID namespace am I in?

Save the inode number of your shell's PID namespace (only the digits) into
`~/work/answers/pidns.txt`.

[[lab-task:1]]

## Task 2: what is my memory fence?

Find your cgroup and save the contents of its `memory.max` into
`answers/memory-max.txt`.

[[lab-task:2]]

## Task 3: read a kernel tunable

Save the value of `kernel.pid_max` into `answers/pid-max.txt`.

[[lab-task:3]]

## Task 4: how many CPUs may I use?

Save the number of CPUs available to your shell into `answers/cpus.txt`.

[[lab-task:4]]

## Task 5: pin a worker to CPU 0

Start `sleep 4001` in the background, surviving logout, allowed to run only on
CPU 0.

[[lab-task:5]]

Check yourself:

```
$ taskset -cp $(pgrep -f '^sleep 4001$')
pid 87's current affinity list: 0
```

## Remember

- `/proc/self/ns/*` = your namespaces; `/proc/self/cgroup` = your group.
- `/sys/fs/cgroup/.../memory.max`, `cpu.max`, `pids.max` = your fences.
- `/proc/sys` and `sysctl` = kernel tunables.
- `taskset -c` pins CPUs; `nproc` respects it.
$md$, 20, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('61e84cb3-8615-5680-8429-8ad478d636f8', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '4ec6da49-ce7c-5503-bae2-95c23b81662d', 'module', 'Lab: Look Under Atlas''s Hood', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
rm -rf $w/answers
mkdir -p $w/answers
$script$, NULL, 30, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'a53034fc-7c2c-5061-8668-ba2cd3584d15' AND id NOT IN ('04380e78-b274-5f8f-b6cd-80f3a19f64f7', 'a0348d9a-a34b-5ea3-bc61-a444857a470c', '4de42612-1ddf-5080-b160-3f6183359afb', '636f6747-ce88-59ee-8d7e-4e96564f98b9', '8777fa10-424e-597a-91ce-a96d4d92d2f4');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'a53034fc-7c2c-5061-8668-ba2cd3584d15';
DELETE FROM lab_tasks WHERE lab_id = '61e84cb3-8615-5680-8429-8ad478d636f8' AND id NOT IN ('168832e5-6850-5291-a66a-f359607e1ec3', '5def65a9-4502-58d3-8f95-6786568d0fbf', '370097ac-de12-591c-921e-d4479c361891', '15c6330b-32e7-5f68-b907-22d47d26add2', '4dc6fb55-02b2-5c13-89d4-c393f80a89b6');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '61e84cb3-8615-5680-8429-8ad478d636f8';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('168832e5-6850-5291-a66a-f359607e1ec3', '61e84cb3-8615-5680-8429-8ad478d636f8', 1, 'Which PID namespace am I in?', $md$Save the inode number of your shell's PID namespace (only the digits inside pid:[...]) into /home/labuser/work/answers/pidns.txt.$md$, $script$want=$(readlink /proc/self/ns/pid | tr -dc '0-9')
[ -n "$want" ] && [ "$(tr -d '[:space:]' < /home/labuser/work/answers/pidns.txt)" = "$want" ]
$script$, 'readlink /proc/$$/ns/pid prints pid:[NUMBER]. tr -dc ''0-9'' keeps only the digits.', 'Every namespace has an inode number. Processes that show the same number share that namespace and therefore see the same process list.', 20, false, true),
('5def65a9-4502-58d3-8f95-6786568d0fbf', '61e84cb3-8615-5680-8429-8ad478d636f8', 2, 'What is my memory fence?', $md$Find your cgroup (from /proc/self/cgroup) and save the contents of its memory.max file under /sys/fs/cgroup into answers/memory-max.txt (a number of bytes, or the word max if unlimited).$md$, $script$cg=$(cut -d: -f3 /proc/self/cgroup | head -1)
want=$(cat "/sys/fs/cgroup${cg%/}/memory.max" 2>/dev/null || echo none)
[ "$(tr -d '[:space:]' < /home/labuser/work/answers/memory-max.txt)" = "$want" ]
$script$, 'cat /proc/self/cgroup shows 0::PATH. With PATH = / the file is /sys/fs/cgroup/memory.max.', 'cgroup v2 exposes each group as a directory. memory.max is the limit the OOM killer enforces for the group; max means no limit at this level.', 20, false, true),
('370097ac-de12-591c-921e-d4479c361891', '61e84cb3-8615-5680-8429-8ad478d636f8', 3, 'Read a kernel tunable', $md$Save the current value of the kernel setting kernel.pid_max (the highest PID number the kernel will hand out) into answers/pid-max.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/pid-max.txt)" = "$(cat /proc/sys/kernel/pid_max)" ]
$script$, 'sysctl -n kernel.pid_max, or cat /proc/sys/kernel/pid_max - dots in the name become slashes in the path.', '/proc/sys exposes kernel tunables as files. sysctl is a friendlier front end; writing needs root, reading does not.', 20, false, true),
('15c6330b-32e7-5f68-b907-22d47d26add2', '61e84cb3-8615-5680-8429-8ad478d636f8', 4, 'How many CPUs may I use?', $md$Save the number of CPUs available to your shell into answers/cpus.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/cpus.txt)" = "$(nproc)" ]
$script$, 'nproc prints the number of CPUs this process may run on.', 'nproc respects CPU affinity, so inside a pinned container it can be smaller than the host''s CPU count. CPU time quotas live in cpu.max instead.', 15, false, true),
('4dc6fb55-02b2-5c13-89d4-c393f80a89b6', '61e84cb3-8615-5680-8429-8ad478d636f8', 5, 'Pin a worker to CPU 0', $md$Start sleep 4001 in the background, surviving logout, allowed to run only on CPU 0.$md$, $script$p=$(pgrep -u labuser -f '^sleep 4001$' | head -1)
[ -n "$p" ] && [ "$(taskset -cp $p | awk -F': ' '{print $2}' | tr -d ' ')" = 0 ]
$script$, 'taskset -c 0 COMMAND starts a command on CPU 0. Combine with nohup and an ampersand.', 'CPU affinity is a per-process mask the scheduler respects. cgroups (cpuset) can enforce the same for a whole group, which is how container runtimes pin workloads.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('a53034fc-7c2c-5061-8668-ba2cd3584d15', '61e84cb3-8615-5680-8429-8ad478d636f8', 1, $json$[{"id":"168832e5-6850-5291-a66a-f359607e1ec3","lab_id":"61e84cb3-8615-5680-8429-8ad478d636f8","position":1,"title":"Which PID namespace am I in?","description":"Save the inode number of your shell's PID namespace (only the digits inside pid:[...]) into /home/labuser/work/answers/pidns.txt.","verification_script":"want=$(readlink /proc/self/ns/pid | tr -dc '0-9')\n[ -n \"$want\" ] \u0026\u0026 [ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/pidns.txt)\" = \"$want\" ]\n","hint_context":"readlink /proc/$$/ns/pid prints pid:[NUMBER]. tr -dc '0-9' keeps only the digits.","explanation_context":"Every namespace has an inode number. Processes that show the same number share that namespace and therefore see the same process list.","points":20,"is_optional":false,"is_stateful":true},{"id":"5def65a9-4502-58d3-8f95-6786568d0fbf","lab_id":"61e84cb3-8615-5680-8429-8ad478d636f8","position":2,"title":"What is my memory fence?","description":"Find your cgroup (from /proc/self/cgroup) and save the contents of its memory.max file under /sys/fs/cgroup into answers/memory-max.txt (a number of bytes, or the word max if unlimited).","verification_script":"cg=$(cut -d: -f3 /proc/self/cgroup | head -1)\nwant=$(cat \"/sys/fs/cgroup${cg%/}/memory.max\" 2\u003e/dev/null || echo none)\n[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/memory-max.txt)\" = \"$want\" ]\n","hint_context":"cat /proc/self/cgroup shows 0::PATH. With PATH = / the file is /sys/fs/cgroup/memory.max.","explanation_context":"cgroup v2 exposes each group as a directory. memory.max is the limit the OOM killer enforces for the group; max means no limit at this level.","points":20,"is_optional":false,"is_stateful":true},{"id":"370097ac-de12-591c-921e-d4479c361891","lab_id":"61e84cb3-8615-5680-8429-8ad478d636f8","position":3,"title":"Read a kernel tunable","description":"Save the current value of the kernel setting kernel.pid_max (the highest PID number the kernel will hand out) into answers/pid-max.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/pid-max.txt)\" = \"$(cat /proc/sys/kernel/pid_max)\" ]\n","hint_context":"sysctl -n kernel.pid_max, or cat /proc/sys/kernel/pid_max - dots in the name become slashes in the path.","explanation_context":"/proc/sys exposes kernel tunables as files. sysctl is a friendlier front end; writing needs root, reading does not.","points":20,"is_optional":false,"is_stateful":true},{"id":"15c6330b-32e7-5f68-b907-22d47d26add2","lab_id":"61e84cb3-8615-5680-8429-8ad478d636f8","position":4,"title":"How many CPUs may I use?","description":"Save the number of CPUs available to your shell into answers/cpus.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/cpus.txt)\" = \"$(nproc)\" ]\n","hint_context":"nproc prints the number of CPUs this process may run on.","explanation_context":"nproc respects CPU affinity, so inside a pinned container it can be smaller than the host's CPU count. CPU time quotas live in cpu.max instead.","points":15,"is_optional":false,"is_stateful":true},{"id":"4dc6fb55-02b2-5c13-89d4-c393f80a89b6","lab_id":"61e84cb3-8615-5680-8429-8ad478d636f8","position":5,"title":"Pin a worker to CPU 0","description":"Start sleep 4001 in the background, surviving logout, allowed to run only on CPU 0.","verification_script":"p=$(pgrep -u labuser -f '^sleep 4001$' | head -1)\n[ -n \"$p\" ] \u0026\u0026 [ \"$(taskset -cp $p | awk -F': ' '{print $2}' | tr -d ' ')\" = 0 ]\n","hint_context":"taskset -c 0 COMMAND starts a command on CPU 0. Combine with nohup and an ampersand.","explanation_context":"CPU affinity is a per-process mask the scheduler respects. cgroups (cpuset) can enforce the same for a whole group, which is how container runtimes pin workloads.","points":25,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('04380e78-b274-5f8f-b6cd-80f3a19f64f7', 'a53034fc-7c2c-5061-8668-ba2cd3584d15', '168832e5-6850-5291-a66a-f359607e1ec3', 1, 'Which PID namespace am I in?', $md$Save the inode number of your shell's PID namespace (only the digits inside pid:[...]) into /home/labuser/work/answers/pidns.txt.$md$, $script$want=$(readlink /proc/self/ns/pid | tr -dc '0-9')
[ -n "$want" ] && [ "$(tr -d '[:space:]' < /home/labuser/work/answers/pidns.txt)" = "$want" ]
$script$, 'readlink /proc/$$/ns/pid prints pid:[NUMBER]. tr -dc ''0-9'' keeps only the digits.', 'Every namespace has an inode number. Processes that show the same number share that namespace and therefore see the same process list.', 20, false, true),
('a0348d9a-a34b-5ea3-bc61-a444857a470c', 'a53034fc-7c2c-5061-8668-ba2cd3584d15', '5def65a9-4502-58d3-8f95-6786568d0fbf', 2, 'What is my memory fence?', $md$Find your cgroup (from /proc/self/cgroup) and save the contents of its memory.max file under /sys/fs/cgroup into answers/memory-max.txt (a number of bytes, or the word max if unlimited).$md$, $script$cg=$(cut -d: -f3 /proc/self/cgroup | head -1)
want=$(cat "/sys/fs/cgroup${cg%/}/memory.max" 2>/dev/null || echo none)
[ "$(tr -d '[:space:]' < /home/labuser/work/answers/memory-max.txt)" = "$want" ]
$script$, 'cat /proc/self/cgroup shows 0::PATH. With PATH = / the file is /sys/fs/cgroup/memory.max.', 'cgroup v2 exposes each group as a directory. memory.max is the limit the OOM killer enforces for the group; max means no limit at this level.', 20, false, true),
('4de42612-1ddf-5080-b160-3f6183359afb', 'a53034fc-7c2c-5061-8668-ba2cd3584d15', '370097ac-de12-591c-921e-d4479c361891', 3, 'Read a kernel tunable', $md$Save the current value of the kernel setting kernel.pid_max (the highest PID number the kernel will hand out) into answers/pid-max.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/pid-max.txt)" = "$(cat /proc/sys/kernel/pid_max)" ]
$script$, 'sysctl -n kernel.pid_max, or cat /proc/sys/kernel/pid_max - dots in the name become slashes in the path.', '/proc/sys exposes kernel tunables as files. sysctl is a friendlier front end; writing needs root, reading does not.', 20, false, true),
('636f6747-ce88-59ee-8d7e-4e96564f98b9', 'a53034fc-7c2c-5061-8668-ba2cd3584d15', '15c6330b-32e7-5f68-b907-22d47d26add2', 4, 'How many CPUs may I use?', $md$Save the number of CPUs available to your shell into answers/cpus.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/cpus.txt)" = "$(nproc)" ]
$script$, 'nproc prints the number of CPUs this process may run on.', 'nproc respects CPU affinity, so inside a pinned container it can be smaller than the host''s CPU count. CPU time quotas live in cpu.max instead.', 15, false, true),
('8777fa10-424e-597a-91ce-a96d4d92d2f4', 'a53034fc-7c2c-5061-8668-ba2cd3584d15', '4dc6fb55-02b2-5c13-89d4-c393f80a89b6', 5, 'Pin a worker to CPU 0', $md$Start sleep 4001 in the background, surviving logout, allowed to run only on CPU 0.$md$, $script$p=$(pgrep -u labuser -f '^sleep 4001$' | head -1)
[ -n "$p" ] && [ "$(taskset -cp $p | awk -F': ' '{print $2}' | tr -d ' ')" = 0 ]
$script$, 'taskset -c 0 COMMAND starts a command on CPU 0. Combine with nohup and an ampersand.', 'CPU affinity is a per-process mask the scheduler respects. cgroups (cpuset) can enforce the same for a whole group, which is how container runtimes pin workloads.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'a53034fc-7c2c-5061-8668-ba2cd3584d15', updated_at = now()
WHERE id = '61e84cb3-8615-5680-8429-8ad478d636f8' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5054644b-1e2e-529d-996a-bb0672a788af', '00000000-0000-0000-0000-000000000001', 'mcq', 'brewbot exits with only ''startup failed''. Which tool shows the exact file it ...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4a19ea76-56e3-598b-8909-9cce96261b5d', '5054644b-1e2e-529d-996a-bb0672a788af', 1, $json${"prompt":"brewbot exits with only 'startup failed'. Which tool shows the exact file it tried to open and the error the kernel returned?","multiple":false,"options":[{"id":"a","text":"strace -f -e trace=file /opt/brewbot/bin/brewbot","is_correct":true},{"id":"b","text":"top","is_correct":false},{"id":"c","text":"lsblk","is_correct":false},{"id":"d","text":"sysctl -a","is_correct":false}],"explanation":"strace prints each system call with its result, such as openat(...) = -1 EACCES. top shows resource use, lsblk shows disks and sysctl lists kernel tunables."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('9f43d8a4-738b-59a2-8b03-7faab9484bbe', '00000000-0000-0000-0000-000000000001', 'mcq', 'You ran sudo sysctl -w net.core.somaxconn=4096 and it helped, but after a reb...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d9049aa4-7bbe-5ad0-8e13-504c3b1b4dc2', '9f43d8a4-738b-59a2-8b03-7faab9484bbe', 1, $json${"prompt":"You ran sudo sysctl -w net.core.somaxconn=4096 and it helped, but after a reboot the old value is back. What was missing?","multiple":false,"options":[{"id":"a","text":"A file in /etc/sysctl.d/ with the setting","is_correct":true},{"id":"b","text":"systemctl daemon-reload","is_correct":false},{"id":"c","text":"A reboot right after the change","is_correct":false},{"id":"d","text":"chmod on /proc/sys","is_correct":false}],"explanation":"sysctl -w changes the running kernel only. Files in /etc/sysctl.d/ are applied at every boot. daemon-reload is for unit files, and /proc/sys permissions are not the issue."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('318065d9-5ac9-562a-acf2-7d42a61f00e7', '00000000-0000-0000-0000-000000000001', 'mcq', 'Inside a container, ps shows your app as PID 1, but on the host it is PID 482...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a36545d0-8a5e-50a1-840a-25eb6e041b71', '318065d9-5ac9-562a-acf2-7d42a61f00e7', 1, $json${"prompt":"Inside a container, ps shows your app as PID 1, but on the host it is PID 48213. Which kernel feature causes this?","multiple":false,"options":[{"id":"a","text":"A PID namespace","is_correct":true},{"id":"b","text":"A cgroup memory limit","is_correct":false},{"id":"c","text":"A virtual machine","is_correct":false},{"id":"d","text":"The sticky bit","is_correct":false}],"explanation":"A PID namespace gives the container its own process numbering. cgroups limit resources, a container is not a VM, and the sticky bit is a directory permission."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5ff889ab-15bf-5867-a1cf-f7982a2822cb', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which statement about containers is correct?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('6c19908c-5bff-5957-bd6a-2914fd83b107', '5ff889ab-15bf-5867-a1cf-f7982a2822cb', 1, $json${"prompt":"Which statement about containers is correct?","multiple":false,"options":[{"id":"a","text":"Containers share the host's kernel; namespaces limit what they see and cgroups limit what they use","is_correct":true},{"id":"b","text":"Each container runs its own kernel","is_correct":false},{"id":"c","text":"Namespaces limit CPU and memory","is_correct":false},{"id":"d","text":"cgroups hide other processes","is_correct":false}],"explanation":"See = namespaces, Use = cgroups, one shared kernel. Separate kernels are what VMs provide, and the two features' roles are the other way round in the wrong options."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('014df0e9-d4db-57db-84d9-4161ba6fb311', '00000000-0000-0000-0000-000000000001', 'mcq', 'A container with a 512 MiB limit keeps dying with exit code 137 while the hos...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('323abc5f-74fd-5c75-ae8e-3da68c476992', '014df0e9-d4db-57db-84d9-4161ba6fb311', 1, $json${"prompt":"A container with a 512 MiB limit keeps dying with exit code 137 while the host has 20 GB free. What is happening?","multiple":false,"options":[{"id":"a","text":"It reaches its cgroup memory.max and the kernel OOM-kills it inside that group","is_correct":true},{"id":"b","text":"The host is out of memory","is_correct":false},{"id":"c","text":"Exit 137 means a normal shutdown","is_correct":false},{"id":"d","text":"The container's disk is full","is_correct":false}],"explanation":"Limits apply per cgroup, regardless of free host memory. 137 = 128 + SIGKILL. A disk-full error would appear as write failures, not SIGKILL."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('9fc0fc7e-51f8-5185-9eda-477dfb163f7a', '00000000-0000-0000-0000-000000000001', 'mcq', 'You want a nightly import job to never use more than 20% of a CPU or 200 MB o...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ae416801-2dec-5ac5-8f03-d5797f6862e5', '9fc0fc7e-51f8-5185-9eda-477dfb163f7a', 1, $json${"prompt":"You want a nightly import job to never use more than 20% of a CPU or 200 MB of RAM. What is the simplest systemd way to run it once?","multiple":false,"options":[{"id":"a","text":"sudo systemd-run --scope -p CPUQuota=20% -p MemoryMax=200M ./import.sh","is_correct":true},{"id":"b","text":"nice -n 19 ./import.sh","is_correct":false},{"id":"c","text":"ulimit -v 200 ./import.sh","is_correct":false},{"id":"d","text":"taskset -c 0 ./import.sh","is_correct":false}],"explanation":"systemd-run puts the command in its own cgroup with hard limits. nice only changes priority, ulimit -v limits virtual address space in KiB and is not a CPU limit, and taskset picks CPUs but not a share of them."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('db20eba0-6692-5ce5-b31d-ac42ee658cf7', '00000000-0000-0000-0000-000000000001', 'mcq', 'A minimal container image has no ss or curl. How can you list its listening p...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('523d4131-99bb-5bc2-abbc-f7b424d5801c', 'db20eba0-6692-5ce5-b31d-ac42ee658cf7', 1, $json${"prompt":"A minimal container image has no ss or curl. How can you list its listening ports from the host?","multiple":false,"options":[{"id":"a","text":"sudo nsenter -t \u003ccontainer PID\u003e -n ss -tlnp","is_correct":true},{"id":"b","text":"ss -tlnp on the host","is_correct":false},{"id":"c","text":"lsns -t net","is_correct":false},{"id":"d","text":"cat /sys/fs/cgroup/cpu.max","is_correct":false}],"explanation":"nsenter -n enters the container's network namespace while using the host's ss. The host's own ss shows a different namespace, lsns only lists namespaces, and cpu.max is a CPU limit."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2389980e-730c-5461-ac61-e7757cc8bd5a', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 9): a script must not run twice at the same time from cron. W...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5a38c3a6-7292-5fe9-b1ca-aeb03879f763', '2389980e-730c-5461-ac61-e7757cc8bd5a', 1, $json${"prompt":"Review (chapter 9): a script must not run twice at the same time from cron. Which line protects it?","multiple":false,"options":[{"id":"a","text":"flock -n /tmp/import.lock /opt/import.sh in the crontab","is_correct":true},{"id":"b","text":"set -euo pipefail","is_correct":false},{"id":"c","text":"trap 'rm -f /tmp/x' EXIT","is_correct":false},{"id":"d","text":"nohup /opt/import.sh \u0026","is_correct":false}],"explanation":"flock -n takes a lock or gives up immediately if another run holds it. set -euo pipefail handles errors, trap handles cleanup, and nohup only survives logout."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('95ae7120-56f0-5884-96cb-f54b8ddc525f', '00000000-0000-0000-0000-000000000001', 'Quiz: Kernel, Namespaces and cgroups', 'linux-under-the-hood-quiz', 'Quiz covering Chapter 10: Under the Hood - Kernel, Namespaces and cgroups.', 'mcq', 'published', 'module', 'd16ae943-dbf4-5cb8-9c60-dd0304d81e15', 10, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '95ae7120-56f0-5884-96cb-f54b8ddc525f' AND question_id NOT IN ('5054644b-1e2e-529d-996a-bb0672a788af', '9f43d8a4-738b-59a2-8b03-7faab9484bbe', '318065d9-5ac9-562a-acf2-7d42a61f00e7', '5ff889ab-15bf-5867-a1cf-f7982a2822cb', '014df0e9-d4db-57db-84d9-4161ba6fb311', '9fc0fc7e-51f8-5185-9eda-477dfb163f7a', 'db20eba0-6692-5ce5-b31d-ac42ee658cf7', '2389980e-730c-5461-ac61-e7757cc8bd5a');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('6530d026-ffde-506d-9af2-ba109b044907', '95ae7120-56f0-5884-96cb-f54b8ddc525f', '5054644b-1e2e-529d-996a-bb0672a788af', '4a19ea76-56e3-598b-8909-9cce96261b5d', 0, 2),
('c1a7be79-8010-54b9-8de3-9027347f2624', '95ae7120-56f0-5884-96cb-f54b8ddc525f', '9f43d8a4-738b-59a2-8b03-7faab9484bbe', 'd9049aa4-7bbe-5ad0-8e13-504c3b1b4dc2', 1, 2),
('bc696785-20c2-5190-b77e-02ee208673d0', '95ae7120-56f0-5884-96cb-f54b8ddc525f', '318065d9-5ac9-562a-acf2-7d42a61f00e7', 'a36545d0-8a5e-50a1-840a-25eb6e041b71', 2, 2),
('a5f54a65-5fa3-5e63-8c48-c01e914014d8', '95ae7120-56f0-5884-96cb-f54b8ddc525f', '5ff889ab-15bf-5867-a1cf-f7982a2822cb', '6c19908c-5bff-5957-bd6a-2914fd83b107', 3, 2),
('7481b17d-4e28-5c9b-ba56-af7de524c722', '95ae7120-56f0-5884-96cb-f54b8ddc525f', '014df0e9-d4db-57db-84d9-4161ba6fb311', '323abc5f-74fd-5c75-ae8e-3da68c476992', 4, 2),
('f6f3087c-8ce2-59d3-ad30-5fda661ca27e', '95ae7120-56f0-5884-96cb-f54b8ddc525f', '9fc0fc7e-51f8-5185-9eda-477dfb163f7a', 'ae416801-2dec-5ac5-8f03-d5797f6862e5', 5, 2),
('c9e6f705-c741-59f0-9e1c-cfdd51a7ffb4', '95ae7120-56f0-5884-96cb-f54b8ddc525f', 'db20eba0-6692-5ce5-b31d-ac42ee658cf7', '523d4131-99bb-5bc2-abbc-f7b424d5801c', 6, 2),
('421b5c62-6233-5e5b-81be-d33c7d103a71', '95ae7120-56f0-5884-96cb-f54b8ddc525f', '2389980e-730c-5461-ac61-e7757cc8bd5a', '5a38c3a6-7292-5fe9-b1ca-aeb03879f763', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('d16ae943-dbf4-5cb8-9c60-dd0304d81e15', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '5db992b5-3341-59db-beb3-e76a644469d4', 'Quiz: Kernel, Namespaces and cgroups', 'assessment', 4, 8, '95ae7120-56f0-5884-96cb-f54b8ddc525f')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 11: Performance Triage
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('c5860956-2151-5bdf-bf27-28e5acab5aad', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 11: Performance Triage', 11, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0adf72de-87a1-5cd3-857e-0bdfbac9fe1b', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c5860956-2151-5bdf-bf27-28e5acab5aad', 'The USE Method and the First 60 Seconds', 'notes', 0, $md$## Why this matters

> **Friday, week 2.** Rhea: "During last year's sale atlas got slow and nobody
> knew why. People restarted things at random." Tom's note: *measure, don't
> guess*.

"The server is slow" is the vaguest page you will get. Without a method you poke
at random. With one, you check every resource in a fixed order and find the
bottleneck in minutes.

## Mental model: USE, for every resource

For each resource (CPU, memory, disk, network), ask three questions:

| Letter | Question | Example signal |
|---|---|---|
| **U**tilization | How busy is it? | CPU 95%, disk %util 100 |
| **S**aturation | Is work queuing for it? | load > CPUs, swap in/out, disk queue |
| **E**rrors | Is it failing? | `dmesg` IO errors, dropped packets, OOM kills |

```
            Utilization   Saturation        Errors
 CPU        top us+sy     load vs nproc     dmesg (MCE)
 Memory     free used     si/so (swapping)  OOM kills
 Disk       iostat %util  iostat aqu-sz     dmesg IO errors
 Network    sar -n DEV    drops, retrans    ip -s link errors
```

Saturation is usually what users *feel*: things waiting in a queue.

> **Memory hook:** **U-S-E**: "**U**sed? **S**tuck in a queue? **E**rroring?"
> for every resource, before you change anything.

## See it work: the first 60 seconds

Run these in order on any slow server. Each takes a second; together they
cover most causes.

```bash
uptime                      # 1. load averages: rising or falling?
dmesg -T | tail             # 2. kernel errors: OOM kills, disk errors
vmstat 1 5                  # 3. run queue (r), blocked (b), swap (si/so), CPU split
free -h                     # 4. memory: look at "available"
top                         # 5. who uses CPU (P) and memory (M)?
iostat -xz 1 3              # 6. disk utilisation and queues (sysstat package)
ss -s; ip -s link           # 7. connections, network errors and drops
journalctl -p err -b        # 8. errors from services since boot
```

Example `vmstat 1` reading:

```
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 9  0      0 812344  60412 2201000    0    0     2    40 2100 3900 92  6  2  0  0
```

`r 9` (nine runnable) on a 4-CPU box, `us 92` (user CPU), `id 2` (idle), no
swap, no `wa`: **CPU saturation**. The next step is `top` to find who.

`vmstat` columns to know: `r` runnable, `b` blocked on IO, `si`/`so` swap in/out,
`us` user, `sy` kernel, `id` idle, `wa` IO wait, `st` stolen by the hypervisor.

### Then: change one thing, measure again

Performance work is a loop: measure, form one hypothesis, change one thing,
measure again. Restarting a service "to see" destroys the evidence.

## Try it

`vmstat 1` shows `r 1`, `b 6`, `us 5`, `id 20`, `wa 75`. Which resource does
USE point to, and which tool comes next?

<details>
<summary>Show answer</summary>

Disk. Six processes are blocked on IO (`b 6`) and the CPU spends 75% of its
time waiting for IO (`wa`). Next: `iostat -xz 1` for the busy device, and
`iotop` or `ps` (state `D`) for the process causing it.

</details>

## Common mistakes

- **Starting with the application code.** Check the machine first; a full disk
  or a noisy neighbour looks like a slow app.
- **Looking only at utilization.** A disk at 60% with a long queue can still be
  the bottleneck. Check saturation.
- **Restarting before measuring.** The problem goes away for an hour and you
  learned nothing.
- **Ignoring `st` on cloud VMs.** High steal time means the hypervisor is giving
  your CPU to someone else.

## Remember

- USE: Utilization, Saturation, Errors, for CPU, memory, disk, network.
- First 60 s: `uptime`, `dmesg -T | tail`, `vmstat 1`, `free -h`, `top`,
  `iostat -xz 1`, `ss -s`, `journalctl -p err -b`.
- `vmstat`: `r`, `b`, `si/so`, `us sy id wa st`.
- Measure, change one thing, measure again.

**Self-check:**

1. What does the S in USE mean, and why does it matter most to users?
2. In `vmstat`, what do `r` and `b` count?
3. What does high `st` tell you?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8a509708-8aee-541f-a44c-5f23acd47e44', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c5860956-2151-5bdf-bf27-28e5acab5aad', 'CPU and Load Average: Reading uptime and top', 'notes', 1, $md$## Why this matters

`uptime` says load 8. Is that bad? It depends on the number of CPUs and on
*what* the load is made of. Misreading load average sends people chasing CPU
problems that are really disk problems.

## Mental model: the queue at the espresso machines

Load average = the average number of processes **running or waiting** over the
last 1, 5 and 15 minutes. On Linux it also counts processes waiting on disk
(state `D`).

```
 4 espresso machines (CPUs)

 load 2   ##..        half busy, no queue
 load 4   ####        fully busy, no queue
 load 8   ####|####   fully busy, 4 customers waiting
```

Compare load with `nproc`: **load / CPUs > 1** means a queue is forming.

## See it work

```bash
uptime
nproc
```

```
 10:42:01 up 12 days,  3 users,  load average: 3.90, 2.10, 1.05
4
```

Read left to right: 1 min, 5 min, 15 min. 3.90 on 4 CPUs is busy but not
queued. Rising numbers from right to left (1.05 -> 2.10 -> 3.90) mean it is
**getting worse**. The same numbers are in `/proc/loadavg`.

### The top header

```bash
top
```

```
top - 10:42:05 up 12 days,  3 users,  load average: 3.90, 2.10, 1.05
Tasks: 212 total,   5 running, 207 sleeping,   0 stopped,   0 zombie
%Cpu(s): 88.1 us,  6.2 sy,  0.0 ni,  5.1 id,  0.3 wa,  0.0 hi,  0.2 si,  0.1 st
MiB Mem :   7940.0 total,    512.3 free,   4810.2 used,   2617.5 buff/cache
MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.   2890.4 avail Mem

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
   2231 brewbot   20   0 1830444 402112  21000 R 296.0   4.9  41:12.08 report-builder
```

| Field | Meaning | If high |
|---|---|---|
| `us` | user code (apps) | an app is busy: find it in the list |
| `sy` | kernel code | many syscalls, context switches, networking |
| `wa` | idle, waiting for IO | disk bottleneck (next lessons) |
| `st` | stolen by hypervisor | noisy neighbour / undersized VM |
| `ni` | niced processes | background jobs; usually fine |

`%CPU` per process is per core: 296% = about three cores. Keys: `P` sort by
CPU, `M` by memory, `1` per-CPU view, `H` threads, `k` kill, `r` renice.

### Per-process and per-CPU views

```bash
ps aux --sort=-%cpu | head -5    # snapshot of the top CPU users
pidstat 1 5                      # per-process CPU each second (sysstat)
mpstat -P ALL 1 3                # per-CPU: one core at 100% = single-threaded bottleneck
```

`ps` `%CPU` is the average over the process's lifetime; `top` and `pidstat`
show *now*.

### What to do about it

- A runaway or stuck process: signal it (chapter 5).
- A legitimate batch job at the wrong time: `renice -n 19`, move it off-peak, or
  cap it with `CPUQuota=` (chapter 10).
- Real demand: optimise the code, add CPUs, or add servers.

## Try it

`uptime` shows `load average: 12.0, 11.5, 10.8` on an 8-CPU machine, and `top`
shows `wa 0.0`, `us 95`. Healthy? What do you look at next?

<details>
<summary>Show answer</summary>

No: 12 runnable on 8 CPUs means about 4 processes are always waiting, and it has
been like that for 15 minutes. With `wa` at 0 and `us` at 95, it is real CPU
demand. Press `P` in `top` (or `pidstat 1`) to find which processes use the CPU.

</details>

## Common mistakes

- **Judging load without `nproc`.** Load 4 is idle on 32 CPUs and overloaded on
  2.
- **Assuming high load = CPU.** Linux load includes processes in `D` state. High
  load with idle CPU is a disk (or NFS) problem.
- **Reading `ps` `%CPU` as current usage.** It is a lifetime average.
- **Missing a single-threaded bottleneck.** Total CPU 25% on 4 cores can be one
  core at 100%. Check `mpstat -P ALL` or `top` then `1`.

## Remember

- Load = running + waiting (incl. disk wait); compare with `nproc`.
- 1/5/15 minutes: compare to see the trend.
- `top`: `us` apps, `sy` kernel, `wa` IO wait, `st` steal; `P`, `M`, `1`.
- `%CPU` 200% = two cores.

**Self-check:**

1. Load 6 on 4 CPUs: what does it mean?
2. Which `top` field rises when the disk is the bottleneck?
3. Why can load be high while the CPU is idle?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('02603888-41d8-554a-8dc2-4d895a51b6cc', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c5860956-2151-5bdf-bf27-28e5acab5aad', 'Memory: free, available, cache, swap and the OOM Killer', 'notes', 2, $md$## Why this matters

`free` says 200 MB free on an 8 GB server and someone wants to buy RAM. Usually
the machine is fine. Other times a process silently vanishes and nobody knows it
was killed. Reading memory correctly saves money and finds real leaks.

## Mental model: free memory is wasted memory

Linux uses spare RAM as **page cache**: copies of recently read files. That
makes the next read instant. When a program needs memory, the kernel drops cache
and hands the RAM over.

```
 [ apps (used) | cache & buffers (reclaimable) | free ]
               \______________ available ______________/
```

So look at **available**, not free.

## See it work

```bash
free -h
```

```
               total        used        free      shared  buff/cache   available
Mem:           7.8Gi       4.7Gi       512Mi        64Mi       2.6Gi       2.8Gi
Swap:          2.0Gi          0B       2.0Gi
```

- `free` 512 MiB looks scary; `available` 2.8 GiB says there is plenty.
- Swap `used 0B`: no memory pressure.

```bash
grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree' /proc/meminfo
```

### Who uses the memory?

```bash
ps aux --sort=-rss | head -5
```

```
USER       PID %CPU %MEM    VSZ   RSS TTY  STAT START   TIME COMMAND
postgres   880  1.2 25.1 2310440 2041332 ?  Ss   Oct02  80:01 postgres: ...
brewbot   1040  3.4 12.0 1830444  976112 ?  Sl   09:00  41:12 brewbot
```

- **RSS** (resident set size): RAM really used now, in KiB. Sort by this.
- **VSZ**: virtual size, everything mapped; often huge and mostly meaningless.
- In `top`, press `M`; the `RES` column is RSS.

A process whose RSS only ever grows across hours is the classic **memory leak**.

### Swapping: the saturation signal

```bash
vmstat 1 5
```

Watch `si` and `so` (pages swapped in/out per second). Swap *used* that sits
still is fine (idle memory moved out of the way). Constant non-zero `si`/`so`
means the machine is short of RAM right now: everything slows down.

Newer kernels also report **pressure**: how much time tasks were stalled
waiting for memory.

```bash
cat /proc/pressure/memory
```

```
some avg10=0.00 avg60=0.00 avg300=0.00 total=0
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
```

Non-zero `avg10` = tasks are waiting for memory right now.

### The OOM killer

When memory and swap run out, the kernel's **OOM (out of memory) killer** picks
a process (usually the biggest, adjusted by `oom_score_adj`) and kills it with
SIGKILL. The victim's own log shows nothing: it just vanished.

```bash
dmesg -T | grep -iE 'killed process|out of memory'
journalctl -k | grep -i oom
```

```
[Fri Nov 27 09:14:02 2026] Out of memory: Killed process 1040 (brewbot) total-vm:1830444kB, anon-rss:976112kB ...
```

**Fixes:** find the leak, add RAM or swap, and set `MemoryMax=` on services
(chapter 10) so a leaking app dies alone instead of taking the database with it.
`OOMScoreAdjust=-500` in a unit protects a critical service.

## Try it

`free -h` shows `free 150Mi`, `available 3.1Gi`, swap used `0B`, and `vmstat`
shows `si 0 so 0`. Does atlas need more RAM?

<details>
<summary>Show answer</summary>

No. 3.1 GiB is available (mostly reclaimable cache) and there is no swapping. Low
`free` alone means Linux is using spare RAM as cache, which is good.

</details>

## Common mistakes

- **Reading `free` instead of `available`.**
- **Sorting by VSZ.** Sort by RSS to find real memory users.
- **"Swap used = problem".** Only active swapping (`si`/`so` > 0 over time) is a
  problem.
- **Missing OOM kills.** A process that "crashed with no log" was often killed;
  check `dmesg`.

## Remember

- available = free + reclaimable cache; that is the number that matters.
- RSS = real memory per process; `ps aux --sort=-rss`, `top` then `M`.
- Saturation: `vmstat` `si`/`so`, `/proc/pressure/memory`.
- OOM kills: `dmesg -T | grep -i 'killed process'`; limit services with
  `MemoryMax=`.

**Self-check:**

1. Why is low "free" memory usually fine?
2. Which column shows the RAM a process really uses?
3. Where do you find evidence of an OOM kill?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ce244c27-606e-5adc-975a-5aff24d69587', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c5860956-2151-5bdf-bf27-28e5acab5aad', 'Disk IO: iostat, iotop and Processes Stuck in D State', 'notes', 3, $md$## Why this matters

Load 12 on 4 CPUs, yet `top` shows the CPUs mostly idle. Web requests take 5
seconds. Nothing is "using" CPU. This is the most misread pattern in Linux
performance: the processes are queued for the **disk**.

## Mental model: one narrow door to the storeroom

Every read and write that misses the cache goes through the disk's door. When
too many requests arrive, they queue, and every process waiting is stuck in
**state `D`** (uninterruptible sleep). Those processes count toward load average
but use no CPU, so the CPU shows as `wa` (idle, waiting for IO).

```
 high load + high wa + processes in D  =  disk bottleneck
```

## See it work

### Spot it

```bash
top                                   # %Cpu(s): ...  5.0 us, 2.0 sy, 18.0 id, 75.0 wa
vmstat 1 5                            # "b" column = processes blocked on IO
ps -eo state,pid,cmd | grep '^D'      # who is stuck right now?
```

### Which disk, how busy, how queued: iostat

`iostat` comes from the `sysstat` package.

```bash
iostat -xz 1 3
```

```
Device   r/s    w/s   rkB/s   wkB/s  r_await w_await aqu-sz  %util
vda     12.0  840.0   96.0  98000.0     1.2    45.8   38.4   99.6
```

| Column | Meaning | Worry when |
|---|---|---|
| `r/s`, `w/s` | reads / writes per second | compare with the disk's rating |
| `r_await`, `w_await` | average ms per request, including queueing | far above a few ms on SSD |
| `aqu-sz` | average queue length | well above 1 |
| `%util` | time the device was busy | near 100% (less meaningful for NVMe/RAID, which serve requests in parallel) |

Here: heavy writes, 46 ms per write and a queue of 38. The disk is saturated.

### Which process?

```bash
sudo iotop -oPa          # only processes doing IO, accumulated (iotop package)
pidstat -d 1             # per-process read/write kB/s (sysstat)
cat /proc/PID/io         # bytes a process has read/written
```

### Common causes and fixes

| Cause | Fix |
|---|---|
| backup or `tar` during peak hours | schedule off-peak; `ionice -c3`; `nice` |
| database without enough RAM for cache | more RAM, tune the cache, fix slow queries |
| chatty debug logging | lower the log level; logrotate |
| swapping (check `si`/`so`) | it is a memory problem first |
| failing disk (`dmesg` IO errors, slow `await`) | replace it; check SMART with `smartctl -a` |
| noisy neighbour / burst credits on cloud disks | provision IOPS, check provider metrics |

## Try it

`uptime` shows load 12 on 4 CPUs, `top` shows `id 20` and `wa 75`, and `ps`
shows six `tar` processes in state `D`. What is going on, and what is a quick,
safe mitigation?

<details>
<summary>Show answer</summary>

The disk is the bottleneck: the `tar` processes are waiting for IO, which pushes
load up while the CPU sits idle. Quick fix: lower their IO priority
(`ionice -c3 -p PID` for each) or pause/reschedule the backup to off-peak hours.
Then confirm with `iostat -xz 1` that `await` and `aqu-sz` drop.

</details>

## Common mistakes

- **Treating every high load as CPU.** Check `wa` and `D` state first.
- **Killing `D` processes.** They cannot be interrupted until the IO completes;
  `kill -9` often does nothing. Fix the IO.
- **Trusting `%util` alone on SSD/NVMe.** Look at `await` and queue size too.
- **Forgetting memory.** Heavy swapping looks like a disk problem.

## Remember

- Disk bottleneck = high load + high `wa` + processes in `D` + `vmstat b`.
- `iostat -xz 1`: `await` (latency), `aqu-sz` (queue), `%util`.
- `iotop -oPa`, `pidstat -d` find the process.
- Fix: reschedule, `ionice -c3`, more cache, replace failing disks.

**Self-check:**

1. Why can load be 12 while the CPU is 75% idle?
2. Which `iostat` column shows latency per request?
3. Why does `kill -9` often not remove a `D` process?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f1f33db1-7c4b-5ac8-8188-addabd6b6f4a', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c5860956-2151-5bdf-bf27-28e5acab5aad', 'Lab: Why Is Atlas Slow?', 'notes', 4, $md$## Why this matters

The pager says atlas is slow. Instead of restarting things at random, you will
measure, find the CPU hog and the memory hog, and deal with each the right way.
Each task is checked automatically.

## Before you start

Take a baseline first, so you can compare:

```bash
uptime
free -h
```

## Task 1: the pager goes off

Run `bash ~/work/start-load.sh` once.

[[lab-task:1]]

Now run the first-60-seconds commands again:

```bash
uptime
vmstat 1 3
free -h
```

The 1-minute load starts rising; `vmstat` shows a runnable process (`r`) and
high `us`.

## Task 2: who is eating the CPU?

Find the program using the most CPU and save its name into
`~/work/answers/cpu-hog.txt`.

[[lab-task:2]]

What you should see (abridged):

```
$ ps aux --sort=-%cpu | head -2
USER   PID %CPU %MEM ... COMMAND
labuser 41 99.6  0.0 ... bash /home/labuser/work/perf/bin/report-builder
```

## Task 3: make it step aside

Give `report-builder` niceness 19 without killing it.

[[lab-task:3]]

## Task 4: who is holding the memory?

Find the process with the largest RSS and save its PID into
`answers/mem-hog-pid.txt`.

[[lab-task:4]]

## Task 5: stop the memory hog politely

Stop `cache-warmer` with SIGTERM and confirm it is gone. Run `free -h` again:
`available` should be about 120 MiB higher.

[[lab-task:5]]

## Remember

- Baseline first: `uptime`, `free -h`, `vmstat 1`.
- CPU: `top` + `P` or `ps --sort=-%cpu`; tame with `renice -n 19`.
- Memory: `top` + `M` or `ps --sort=-rss`; RSS, not VSZ.
- 15 before 9, and measure again after every change.

> **End of week 2.** You found the report job and the cache warmer, calmed one
> and stopped the other, and atlas is fast again. Rhea: "Last thing before Black
> Friday: lock atlas down." Tom's note: "Every open door is a risk."
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('b02929e7-4264-5bbd-943a-3364c43eb66a', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'f1f33db1-7c4b-5ac8-8188-addabd6b6f4a', 'module', 'Lab: Why Is Atlas Slow?', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/start-load.sh <<'MFEOF'
#!/bin/bash
# Starts the slow-atlas scenario. Run once: bash ~/work/start-load.sh
set -euo pipefail
w=/home/labuser/work/perf
mkdir -p $w/bin
cat > $w/bin/report-builder <<'EOF'
#!/bin/bash
# a report job stuck in a busy loop
end=$((SECONDS + 1800))
while [ $SECONDS -lt $end ]; do :; done
EOF
cat > $w/bin/cache-warmer.py <<'EOF'
import time
cache = bytearray(120 * 1024 * 1024)   # holds 120 MiB
for i in range(0, len(cache), 4096):
    cache[i] = 1
time.sleep(1800)
EOF
chmod 755 $w/bin/report-builder
nohup bash $w/bin/report-builder >/dev/null 2>&1 &
nohup python3 $w/bin/cache-warmer.py >/dev/null 2>&1 &
nohup sleep 1800 >/dev/null 2>&1 &
sleep 2
touch $w/.load-started
echo "PAGER: atlas is slow. Find out why."

MFEOF
chmod 666 /home/labuser/work/start-load.sh
pkill -u labuser -f '[p]erf/bin/' || true
rm -rf /home/labuser/work/perf /home/labuser/work/answers
mkdir -p /home/labuser/work/answers
$script$, NULL, 40, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '95a129b2-54dc-58dc-b35f-e1d8b1956ca6' AND id NOT IN ('25c781d3-d365-5df4-a344-ed1e98d99494', 'b7b6fbcf-7dfa-552c-88a6-fedcfb9b1ef2', '37686f7b-c592-5e85-a37d-7f872fdc322e', 'f4be141a-9a00-5bc5-b314-0e12f5d77bc2', '51ab51c8-92ca-5bdf-9821-5dd21c673845');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '95a129b2-54dc-58dc-b35f-e1d8b1956ca6';
DELETE FROM lab_tasks WHERE lab_id = 'b02929e7-4264-5bbd-943a-3364c43eb66a' AND id NOT IN ('e13824d3-6611-5a32-80b1-66ea4878a504', '853ff238-1bf0-5e45-8e84-d87dcc9dd938', '49f6412c-232a-58db-aeeb-e706c3c9b40a', 'ebfb6b1b-8987-5a05-80d1-a2825d177f70', 'd16d648c-d2d4-5418-b571-ffb364308603');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'b02929e7-4264-5bbd-943a-3364c43eb66a';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('e13824d3-6611-5a32-80b1-66ea4878a504', 'b02929e7-4264-5bbd-943a-3364c43eb66a', 1, 'The pager goes off', $md$Run bash /home/labuser/work/start-load.sh once to start the scenario.$md$, $script$[ -f /home/labuser/work/perf/.load-started ] &&
pgrep -u labuser -f '^bash /home/labuser/work/perf/bin/report-builder$' >/dev/null &&
pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' >/dev/null
$script$, 'Type exactly bash /home/labuser/work/start-load.sh and press Enter.', 'The script starts a CPU-hungry report job, a memory-hungry cache warmer and one idle process, so you can practise finding each with the right tool.', 10, false, true),
('853ff238-1bf0-5e45-8e84-d87dcc9dd938', 'b02929e7-4264-5bbd-943a-3364c43eb66a', 2, 'Who is eating the CPU?', $md$Find the program using the most CPU and save its program name (the file name of the script, for example backup-runner) into /home/labuser/work/answers/cpu-hog.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/cpu-hog.txt)" = report-builder ]
$script$, 'top then P, or ps aux --sort=-%cpu | head -3. The COMMAND column shows bash followed by the script path; you want the script''s name.', 'The %CPU column near 100 means one full core. A bash process at 100% running a script is the script''s loop, so the script is the program to name.', 20, false, true),
('49f6412c-232a-58db-aeeb-e706c3c9b40a', 'b02929e7-4264-5bbd-943a-3364c43eb66a', 3, 'Make it step aside', $md$Without killing it, give the report-builder process the lowest possible CPU priority (niceness 19).$md$, $script$p=$(pgrep -u labuser -f '^bash /home/labuser/work/perf/bin/report-builder$' | head -1)
[ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 19 ]
$script$, 'renice -n 19 -p PID. pgrep -f report-builder prints the PID.', 'A niced process still runs, but only on CPU time other processes do not want, so the web shop gets served first. Killing a report job may lose work; renicing buys time.', 20, false, true),
('ebfb6b1b-8987-5a05-80d1-a2825d177f70', 'b02929e7-4264-5bbd-943a-3364c43eb66a', 4, 'Who is holding the memory?', $md$Find the process with the largest resident memory (RSS) and save its PID into answers/mem-hog-pid.txt.$md$, $script$want=$(pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' | head -1)
[ -n "$want" ] && [ "$(tr -d '[:space:]' < /home/labuser/work/answers/mem-hog-pid.txt)" = "$want" ]
$script$, 'ps aux --sort=-rss | head -3, or top then M. RSS (RES in top) is real memory in use; ignore VSZ.', 'RSS is the RAM a process really holds. Sorting by it finds memory users quickly; VSZ includes mapped but unused address space.', 25, false, true),
('d16d648c-d2d4-5418-b571-ffb364308603', 'b02929e7-4264-5bbd-943a-3364c43eb66a', 5, 'Stop the memory hog politely', $md$Stop the cache-warmer process with SIGTERM (not SIGKILL) and confirm it is gone.$md$, $script$[ -f /home/labuser/work/perf/.load-started ] &&
! pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' >/dev/null
$script$, 'kill PID (the PID you saved in the previous task) sends SIGTERM. pgrep -f cache-warmer should then print nothing.', 'SIGTERM lets the program exit cleanly and the kernel frees its memory at once. Check free -h before and after - available memory goes up by about 120 MiB.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('95a129b2-54dc-58dc-b35f-e1d8b1956ca6', 'b02929e7-4264-5bbd-943a-3364c43eb66a', 1, $json$[{"id":"e13824d3-6611-5a32-80b1-66ea4878a504","lab_id":"b02929e7-4264-5bbd-943a-3364c43eb66a","position":1,"title":"The pager goes off","description":"Run bash /home/labuser/work/start-load.sh once to start the scenario.","verification_script":"[ -f /home/labuser/work/perf/.load-started ] \u0026\u0026\npgrep -u labuser -f '^bash /home/labuser/work/perf/bin/report-builder$' \u003e/dev/null \u0026\u0026\npgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' \u003e/dev/null\n","hint_context":"Type exactly bash /home/labuser/work/start-load.sh and press Enter.","explanation_context":"The script starts a CPU-hungry report job, a memory-hungry cache warmer and one idle process, so you can practise finding each with the right tool.","points":10,"is_optional":false,"is_stateful":true},{"id":"853ff238-1bf0-5e45-8e84-d87dcc9dd938","lab_id":"b02929e7-4264-5bbd-943a-3364c43eb66a","position":2,"title":"Who is eating the CPU?","description":"Find the program using the most CPU and save its program name (the file name of the script, for example backup-runner) into /home/labuser/work/answers/cpu-hog.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/cpu-hog.txt)\" = report-builder ]\n","hint_context":"top then P, or ps aux --sort=-%cpu | head -3. The COMMAND column shows bash followed by the script path; you want the script's name.","explanation_context":"The %CPU column near 100 means one full core. A bash process at 100% running a script is the script's loop, so the script is the program to name.","points":20,"is_optional":false,"is_stateful":true},{"id":"49f6412c-232a-58db-aeeb-e706c3c9b40a","lab_id":"b02929e7-4264-5bbd-943a-3364c43eb66a","position":3,"title":"Make it step aside","description":"Without killing it, give the report-builder process the lowest possible CPU priority (niceness 19).","verification_script":"p=$(pgrep -u labuser -f '^bash /home/labuser/work/perf/bin/report-builder$' | head -1)\n[ -n \"$p\" ] \u0026\u0026 [ \"$(ps -o ni= -p $p | tr -d ' ')\" = 19 ]\n","hint_context":"renice -n 19 -p PID. pgrep -f report-builder prints the PID.","explanation_context":"A niced process still runs, but only on CPU time other processes do not want, so the web shop gets served first. Killing a report job may lose work; renicing buys time.","points":20,"is_optional":false,"is_stateful":true},{"id":"ebfb6b1b-8987-5a05-80d1-a2825d177f70","lab_id":"b02929e7-4264-5bbd-943a-3364c43eb66a","position":4,"title":"Who is holding the memory?","description":"Find the process with the largest resident memory (RSS) and save its PID into answers/mem-hog-pid.txt.","verification_script":"want=$(pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' | head -1)\n[ -n \"$want\" ] \u0026\u0026 [ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/mem-hog-pid.txt)\" = \"$want\" ]\n","hint_context":"ps aux --sort=-rss | head -3, or top then M. RSS (RES in top) is real memory in use; ignore VSZ.","explanation_context":"RSS is the RAM a process really holds. Sorting by it finds memory users quickly; VSZ includes mapped but unused address space.","points":25,"is_optional":false,"is_stateful":true},{"id":"d16d648c-d2d4-5418-b571-ffb364308603","lab_id":"b02929e7-4264-5bbd-943a-3364c43eb66a","position":5,"title":"Stop the memory hog politely","description":"Stop the cache-warmer process with SIGTERM (not SIGKILL) and confirm it is gone.","verification_script":"[ -f /home/labuser/work/perf/.load-started ] \u0026\u0026\n! pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' \u003e/dev/null\n","hint_context":"kill PID (the PID you saved in the previous task) sends SIGTERM. pgrep -f cache-warmer should then print nothing.","explanation_context":"SIGTERM lets the program exit cleanly and the kernel frees its memory at once. Check free -h before and after - available memory goes up by about 120 MiB.","points":25,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('25c781d3-d365-5df4-a344-ed1e98d99494', '95a129b2-54dc-58dc-b35f-e1d8b1956ca6', 'e13824d3-6611-5a32-80b1-66ea4878a504', 1, 'The pager goes off', $md$Run bash /home/labuser/work/start-load.sh once to start the scenario.$md$, $script$[ -f /home/labuser/work/perf/.load-started ] &&
pgrep -u labuser -f '^bash /home/labuser/work/perf/bin/report-builder$' >/dev/null &&
pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' >/dev/null
$script$, 'Type exactly bash /home/labuser/work/start-load.sh and press Enter.', 'The script starts a CPU-hungry report job, a memory-hungry cache warmer and one idle process, so you can practise finding each with the right tool.', 10, false, true),
('b7b6fbcf-7dfa-552c-88a6-fedcfb9b1ef2', '95a129b2-54dc-58dc-b35f-e1d8b1956ca6', '853ff238-1bf0-5e45-8e84-d87dcc9dd938', 2, 'Who is eating the CPU?', $md$Find the program using the most CPU and save its program name (the file name of the script, for example backup-runner) into /home/labuser/work/answers/cpu-hog.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/cpu-hog.txt)" = report-builder ]
$script$, 'top then P, or ps aux --sort=-%cpu | head -3. The COMMAND column shows bash followed by the script path; you want the script''s name.', 'The %CPU column near 100 means one full core. A bash process at 100% running a script is the script''s loop, so the script is the program to name.', 20, false, true),
('37686f7b-c592-5e85-a37d-7f872fdc322e', '95a129b2-54dc-58dc-b35f-e1d8b1956ca6', '49f6412c-232a-58db-aeeb-e706c3c9b40a', 3, 'Make it step aside', $md$Without killing it, give the report-builder process the lowest possible CPU priority (niceness 19).$md$, $script$p=$(pgrep -u labuser -f '^bash /home/labuser/work/perf/bin/report-builder$' | head -1)
[ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 19 ]
$script$, 'renice -n 19 -p PID. pgrep -f report-builder prints the PID.', 'A niced process still runs, but only on CPU time other processes do not want, so the web shop gets served first. Killing a report job may lose work; renicing buys time.', 20, false, true),
('f4be141a-9a00-5bc5-b314-0e12f5d77bc2', '95a129b2-54dc-58dc-b35f-e1d8b1956ca6', 'ebfb6b1b-8987-5a05-80d1-a2825d177f70', 4, 'Who is holding the memory?', $md$Find the process with the largest resident memory (RSS) and save its PID into answers/mem-hog-pid.txt.$md$, $script$want=$(pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' | head -1)
[ -n "$want" ] && [ "$(tr -d '[:space:]' < /home/labuser/work/answers/mem-hog-pid.txt)" = "$want" ]
$script$, 'ps aux --sort=-rss | head -3, or top then M. RSS (RES in top) is real memory in use; ignore VSZ.', 'RSS is the RAM a process really holds. Sorting by it finds memory users quickly; VSZ includes mapped but unused address space.', 25, false, true),
('51ab51c8-92ca-5bdf-9821-5dd21c673845', '95a129b2-54dc-58dc-b35f-e1d8b1956ca6', 'd16d648c-d2d4-5418-b571-ffb364308603', 5, 'Stop the memory hog politely', $md$Stop the cache-warmer process with SIGTERM (not SIGKILL) and confirm it is gone.$md$, $script$[ -f /home/labuser/work/perf/.load-started ] &&
! pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' >/dev/null
$script$, 'kill PID (the PID you saved in the previous task) sends SIGTERM. pgrep -f cache-warmer should then print nothing.', 'SIGTERM lets the program exit cleanly and the kernel frees its memory at once. Check free -h before and after - available memory goes up by about 120 MiB.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '95a129b2-54dc-58dc-b35f-e1d8b1956ca6', updated_at = now()
WHERE id = 'b02929e7-4264-5bbd-943a-3364c43eb66a' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('12b3cbe1-7fde-5623-a70e-9489ae85e8c5', '00000000-0000-0000-0000-000000000001', 'mcq', 'uptime shows a load average of 12 on a 4-CPU server, but top shows the CPUs m...', 'advanced', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bb7e42d0-f816-596e-9184-5f6ac3537e60', '12b3cbe1-7fde-5623-a70e-9489ae85e8c5', 1, $json${"prompt":"uptime shows a load average of 12 on a 4-CPU server, but top shows the CPUs mostly idle with a high wa value. What is going on?","multiple":false,"options":[{"id":"a","text":"Processes are blocked waiting on disk IO, which counts toward load","is_correct":true},{"id":"b","text":"The load average is broken and should be ignored","is_correct":false},{"id":"c","text":"The server has too much free memory","is_correct":false},{"id":"d","text":"Twelve users are logged in","is_correct":false}],"explanation":"Linux load counts processes running or waiting, including uninterruptible (D state) disk waits. High wa means the disk, not the CPU, is the bottleneck. Load is not broken, free memory does not raise load, and users are not counted."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('182bb008-827a-5d26-a615-cf53abae6fd7', '00000000-0000-0000-0000-000000000001', 'mcq', 'free -h shows free 180Mi and available 3.2Gi, and vmstat shows si 0 so 0. Wha...', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('aecd118a-97a0-5dba-9b9c-73582bc9e1a1', '182bb008-827a-5d26-a615-cf53abae6fd7', 1, $json${"prompt":"free -h shows free 180Mi and available 3.2Gi, and vmstat shows si 0 so 0. What do you conclude?","multiple":false,"options":[{"id":"a","text":"Memory is fine; the kernel is using spare RAM as cache it can reclaim","is_correct":true},{"id":"b","text":"The server is about to run out of memory","is_correct":false},{"id":"c","text":"Swap is broken","is_correct":false},{"id":"d","text":"You must drop caches every hour","is_correct":false}],"explanation":"available counts reclaimable cache, and no swapping means no pressure. Low free alone is normal, swap is idle not broken, and dropping caches only makes reads slower."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('13a3202c-6d06-5aad-a888-7a942bb08aca', '00000000-0000-0000-0000-000000000001', 'mcq', 'A worker disappeared overnight with nothing in its own log. What do you check...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('725bfd7a-cab7-53cb-ab8f-d73f9fabad30', '13a3202c-6d06-5aad-a888-7a942bb08aca', 1, $json${"prompt":"A worker disappeared overnight with nothing in its own log. What do you check first?","multiple":false,"options":[{"id":"a","text":"dmesg -T | grep -i 'killed process' (the OOM killer)","is_correct":true},{"id":"b","text":"The crontab","is_correct":false},{"id":"c","text":"iostat","is_correct":false},{"id":"d","text":"/etc/hosts","is_correct":false}],"explanation":"The OOM killer sends SIGKILL, so the victim cannot log anything; the kernel logs it instead. Cron, disk statistics and name resolution do not explain a silent kill."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('44f5261c-8456-5467-b0f6-831f46cea3b9', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which column do you sort by to find the process really using the most RAM?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('45174063-e195-5a51-80d5-c435a7978b3e', '44f5261c-8456-5467-b0f6-831f46cea3b9', 1, $json${"prompt":"Which column do you sort by to find the process really using the most RAM?","multiple":false,"options":[{"id":"a","text":"RSS (RES in top)","is_correct":true},{"id":"b","text":"VSZ","is_correct":false},{"id":"c","text":"TIME","is_correct":false},{"id":"d","text":"PID","is_correct":false}],"explanation":"RSS is resident memory in use. VSZ includes mapped but unused address space, TIME is CPU time, and PID is just an ID."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5b0428eb-715e-550a-8421-f2e4fa052946', '00000000-0000-0000-0000-000000000001', 'mcq', 'top shows total CPU at 25% on a 4-core server, yet one request type is very s...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('47aa0537-f898-54e9-8b5e-c9718a548c4a', '5b0428eb-715e-550a-8421-f2e4fa052946', 1, $json${"prompt":"top shows total CPU at 25% on a 4-core server, yet one request type is very slow and its process shows %CPU 100. What is likely?","multiple":false,"options":[{"id":"a","text":"A single-threaded bottleneck: one core is saturated while the others idle","is_correct":true},{"id":"b","text":"The CPU is underused, so it cannot be CPU-related","is_correct":false},{"id":"c","text":"The disk is full","is_correct":false},{"id":"d","text":"Swap is too small","is_correct":false}],"explanation":"100% in top is one full core; on 4 cores that is 25% total. mpstat -P ALL shows it clearly. Disk and swap would show up as wa or si/so instead."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('05677ff6-7dc4-5da0-9992-829fccb658ff', '00000000-0000-0000-0000-000000000001', 'mcq', 'iostat -xz 1 shows the data disk with w_await 60 ms, aqu-sz 30 and %util 99 d...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5d364cbd-57bc-5255-a876-1a4665b225f2', '05677ff6-7dc4-5da0-9992-829fccb658ff', 1, $json${"prompt":"iostat -xz 1 shows the data disk with w_await 60 ms, aqu-sz 30 and %util 99 during a backup at noon. Best quick mitigation?","multiple":false,"options":[{"id":"a","text":"Lower the backup's IO priority with ionice -c3 (and move it off-peak)","is_correct":true},{"id":"b","text":"renice -n -20 the backup","is_correct":false},{"id":"c","text":"kill -9 every process in D state","is_correct":false},{"id":"d","text":"Add more CPUs","is_correct":false}],"explanation":"The disk is saturated; idle IO class lets the shop's IO go first. Raising the backup's priority makes it worse, D-state processes do not die from SIGKILL until IO completes, and CPUs are not the bottleneck."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('61a38c71-11bc-5edb-9a37-7379813f1f90', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the USE method, what does Saturation mean?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('73bb851a-4416-5ace-b297-6e5810e35b66', '61a38c71-11bc-5edb-9a37-7379813f1f90', 1, $json${"prompt":"In the USE method, what does Saturation mean?","multiple":false,"options":[{"id":"a","text":"Work is queuing for the resource (e.g. run queue above CPU count, swapping, disk queue)","is_correct":true},{"id":"b","text":"The resource is 100% utilised","is_correct":false},{"id":"c","text":"The resource is returning errors","is_correct":false},{"id":"d","text":"The resource is unused","is_correct":false}],"explanation":"Saturation is waiting work, which is what users feel as slowness. Utilization is how busy it is and Errors are failures; a resource can be 100% utilised without a queue."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b867c166-9021-556d-948e-08b8767ca175', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 10): brewbot should never use more than 1 GiB of RAM, so a le...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2905b582-7cda-5c8c-bdb4-43073a109ed0', 'b867c166-9021-556d-948e-08b8767ca175', 1, $json${"prompt":"Review (chapter 10): brewbot should never use more than 1 GiB of RAM, so a leak kills brewbot rather than the database. What do you add to its unit?","multiple":false,"options":[{"id":"a","text":"MemoryMax=1G in [Service]","is_correct":true},{"id":"b","text":"Nice=19","is_correct":false},{"id":"c","text":"Restart=no","is_correct":false},{"id":"d","text":"After=postgresql.service","is_correct":false}],"explanation":"MemoryMax sets the cgroup limit, so the OOM killer acts inside brewbot's group. Nice changes CPU priority, Restart controls restarts, and After only orders startup."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('ea2121cf-cc32-5db0-b54f-f9484e8b00e5', '00000000-0000-0000-0000-000000000001', 'Quiz: Performance Triage', 'linux-performance-quiz', 'Quiz covering Chapter 11: Performance Triage.', 'mcq', 'published', 'module', '2f33a0a9-0fde-5271-b17c-f54f0a296c1c', 10, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'ea2121cf-cc32-5db0-b54f-f9484e8b00e5' AND question_id NOT IN ('12b3cbe1-7fde-5623-a70e-9489ae85e8c5', '182bb008-827a-5d26-a615-cf53abae6fd7', '13a3202c-6d06-5aad-a888-7a942bb08aca', '44f5261c-8456-5467-b0f6-831f46cea3b9', '5b0428eb-715e-550a-8421-f2e4fa052946', '05677ff6-7dc4-5da0-9992-829fccb658ff', '61a38c71-11bc-5edb-9a37-7379813f1f90', 'b867c166-9021-556d-948e-08b8767ca175');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('f0666baa-5e7b-5bb0-af9b-4d57d73f2450', 'ea2121cf-cc32-5db0-b54f-f9484e8b00e5', '12b3cbe1-7fde-5623-a70e-9489ae85e8c5', 'bb7e42d0-f816-596e-9184-5f6ac3537e60', 0, 2),
('05b6154d-5922-55c7-bd55-a77db1479bdc', 'ea2121cf-cc32-5db0-b54f-f9484e8b00e5', '182bb008-827a-5d26-a615-cf53abae6fd7', 'aecd118a-97a0-5dba-9b9c-73582bc9e1a1', 1, 2),
('c4519c1d-6e2e-5709-acf2-f6fb6124eccd', 'ea2121cf-cc32-5db0-b54f-f9484e8b00e5', '13a3202c-6d06-5aad-a888-7a942bb08aca', '725bfd7a-cab7-53cb-ab8f-d73f9fabad30', 2, 2),
('6af8f8d5-7c3c-55e2-93ab-3ace090b5fb1', 'ea2121cf-cc32-5db0-b54f-f9484e8b00e5', '44f5261c-8456-5467-b0f6-831f46cea3b9', '45174063-e195-5a51-80d5-c435a7978b3e', 3, 2),
('92188973-a7fd-5171-8c98-3d70755ee748', 'ea2121cf-cc32-5db0-b54f-f9484e8b00e5', '5b0428eb-715e-550a-8421-f2e4fa052946', '47aa0537-f898-54e9-8b5e-c9718a548c4a', 4, 2),
('42fa3c79-d75f-521e-9010-e8c749bece6c', 'ea2121cf-cc32-5db0-b54f-f9484e8b00e5', '05677ff6-7dc4-5da0-9992-829fccb658ff', '5d364cbd-57bc-5255-a876-1a4665b225f2', 5, 2),
('78f204cd-8014-5c29-9f79-1e4fe357c6da', 'ea2121cf-cc32-5db0-b54f-f9484e8b00e5', '61a38c71-11bc-5edb-9a37-7379813f1f90', '73bb851a-4416-5ace-b297-6e5810e35b66', 6, 2),
('f50a024d-3612-505a-9bed-797902dc081b', 'ea2121cf-cc32-5db0-b54f-f9484e8b00e5', 'b867c166-9021-556d-948e-08b8767ca175', '2905b582-7cda-5c8c-bdb4-43073a109ed0', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('2f33a0a9-0fde-5271-b17c-f54f0a296c1c', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c5860956-2151-5bdf-bf27-28e5acab5aad', 'Quiz: Performance Triage', 'assessment', 5, 8, 'ea2121cf-cc32-5db0-b54f-f9484e8b00e5')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 12: Locking Down Atlas - Security Hardening
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('303569e7-7bba-5e6f-a8bb-47557bde7da4', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 12: Locking Down Atlas - Security Hardening', 12, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('7a74603b-08dc-5e6d-b8d7-07935be12863', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '303569e7-7bba-5e6f-a8bb-47557bde7da4', 'Hardening Principles: Least Privilege and a Small Attack Surface', 'notes', 0, $md$## Why this matters

> **Monday, week 3.** Rhea: "Black Friday makes us a target. Bots will hammer
> SSH, scan every port and try every old bug. Lock atlas down." Tom's note:
> *every open door is a risk*.

Most break-ins are not clever. They use a password that was guessed, a service
nobody remembered was running, or a bug fixed months ago but never patched.
Hardening is a short, boring checklist done every time.

## Mental model: a shop at closing time

Before leaving, you walk through the shop:

1. **Close doors you do not use** (attack surface).
2. **Give each key to as few people as possible** (least privilege).
3. **Fix broken locks quickly** (patching).
4. **Check the cameras** (logging and auditing, next lessons).
5. **Put a second lock on valuables** (defence in depth: firewall + auth +
   permissions + sandboxing).

## See it work: the baseline checklist

### 1. Patch

```bash
sudo apt update && apt list --upgradable
sudo apt install unattended-upgrades          # automatic security updates
cat /var/run/reboot-required 2>/dev/null      # kernel/libc updates need a reboot
```

### 2. Shrink the attack surface

```bash
sudo ss -tulpn                                # every listening port
systemctl list-units --type=service --state=running
sudo systemctl disable --now cups avahi-daemon   # stop what you do not need
sudo apt purge telnetd rsh-server             # remove what you never need
```

For every listener ask: do we need it, and does it need to listen on
`0.0.0.0`? Databases and caches should listen on `127.0.0.1` or a private
network only.

### 3. Firewall: default deny

```bash
sudo ufw default deny incoming
sudo ufw allow 22/tcp && sudo ufw allow 443/tcp
sudo ufw enable
```

(Chapter 8.) Only the ports you serve, and admin ports from known networks.

### 4. Least privilege for people and services

- Personal accounts plus `sudo`; no shared logins; no direct root login.
- Narrow sudo rules for teams (chapter 4).
- Every service runs as its own unprivileged user.
- Secrets in files with mode `600`/`640`, never world-readable, never in Git.
- Remove accounts of people who left; lock unused ones (`usermod -L`).

### 5. Sane file permissions

```bash
umask 027                                     # in /etc/profile or per service (UMask=)
sudo chmod 600 /etc/brewbot/env
sudo find / -xdev -type f -perm -o+w 2>/dev/null   # world-writable files: why?
```

Lesson 3 turns these into a full audit.

### 6. Keep the evidence

Persistent journal (chapter 6), `auth.log` shipped off the box (if attackers get
root, they edit local logs), time synced with NTP so timestamps line up.

### Automated checkers

```bash
sudo apt install lynis && sudo lynis audit system   # hardening report with suggestions
```

**Lynis** and the **CIS Benchmarks** are long checklists. Use them as guides,
apply what fits, and record what you skipped and why.

## Try it

`ss -tulpn` on atlas shows `0.0.0.0:6379 redis-server` and
`0.0.0.0:5432 postgres`. Only brewbot, on the same machine, uses them. What do
you change?

<details>
<summary>Show answer</summary>

Make both listen on `127.0.0.1` only (`bind 127.0.0.1` in `redis.conf`,
`listen_addresses = 'localhost'` in `postgresql.conf`), restart them, and check
`ss -tulpn` again. Also ensure the firewall does not allow 6379/5432 from
outside. Defence in depth: both fixes, not one.

</details>

## Common mistakes

- **Hardening once.** New packages and services appear; repeat the checklist
  (and automate it).
- **Relying on one layer.** A firewall rule removed by mistake should not expose
  an unauthenticated database.
- **Disabling updates "for stability".** Unpatched servers are the most common
  way in. Test, then patch.
- **Breaking your own access.** Keep a second session or the cloud console
  while changing SSH and firewall settings.

## Remember

- Patch, shrink the surface, default-deny firewall, least privilege, keep logs.
- `ss -tulpn` and `systemctl list-units` = your attack surface.
- Internal services listen on `127.0.0.1` or a private network.
- Lynis / CIS = checklists; defence in depth beats any single control.

**Self-check:**

1. What does "attack surface" mean on a server?
2. Why should Redis listen on `127.0.0.1` when only local apps use it?
3. Why ship logs off the machine?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('74f56cd2-7563-5379-983a-96ff369dcd16', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '303569e7-7bba-5e6f-a8bb-47557bde7da4', 'Hardening SSH: Keys Only, No Root, fail2ban', 'notes', 1, $md$## Why this matters

Within minutes of getting a public IP, atlas sees thousands of SSH password
guesses from bots. If one account has a weak password, they get in. SSH
hardening takes five lines and closes the most attacked door on the internet.

## Mental model: the staff door

- **Keys only**: no password can be guessed if passwords are not accepted.
- **No root at the door**: staff log in as themselves, then use `sudo` (which is
  logged).
- **Only staff**: name who may log in.
- **A bouncer for repeat offenders**: fail2ban bans IPs after failed attempts.

## See it work

Ubuntu reads drop-in files from `/etc/ssh/sshd_config.d/`. Put your changes in
one file instead of editing the main config:

```
# /etc/ssh/sshd_config.d/10-hardening.conf
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 20
AllowGroups ssh-users
X11Forwarding no
```

| Setting | Effect |
|---|---|
| `PasswordAuthentication no` | keys only; no password guessing |
| `KbdInteractiveAuthentication no` | closes the other password-prompt path |
| `PermitRootLogin no` | log in as yourself, then `sudo` |
| `MaxAuthTries 3` | disconnect after 3 failed attempts |
| `AllowGroups ssh-users` | only members of this group may log in |
| `X11Forwarding no` | turn off features you do not use |

### Apply it without locking yourself out

```bash
sudo sshd -t                        # 1. syntax check: silent means OK
sudo sshd -T | grep -Ei 'passwordauth|permitroot|maxauth'   # 2. effective settings
sudo systemctl reload ssh           # 3. reload (existing sessions stay open)
# 4. in a NEW terminal: ssh atlas   -> must still work before you close the old one
```

Expected output of step 2:

```
maxauthtries 3
permitrootlogin no
passwordauthentication no
```

The first matching value wins in `sshd_config`, and drop-ins are read where the
main file has its `Include` line (at the top on Ubuntu), so a drop-in beats
later lines in the main file. `sshd -T` shows what is really in effect.

### fail2ban: ban repeat offenders

```bash
sudo apt install fail2ban
sudo tee /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled  = true
maxretry = 5
findtime = 10m
bantime  = 1h
EOF
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

fail2ban reads the auth log (or journal), counts failures per IP and adds a
firewall rule to block offenders.

### See the attacks

```bash
sudo grep 'Failed password' /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head
sudo journalctl -u ssh --since today | grep -c 'Invalid user'
sudo lastb | head                     # failed logins (from /var/log/btmp)
```

The first line is chapter 3's top-N pipeline: the field four from the end is the
source IP in OpenSSH's "Failed password ... from IP port N ssh2" line.

Moving SSH to another port reduces log noise but is not security; bots find it.
Restrict by source network in the firewall where possible, or use a VPN or
bastion host.

## Try it

You set `PasswordAuthentication no` in `/etc/ssh/sshd_config.d/10-hardening.conf`,
but `sshd -T` still shows `passwordauthentication yes`. What could cause it?

<details>
<summary>Show answer</summary>

Another file sets it first. The first value sshd reads wins, so a drop-in that
sorts earlier (for example `01-legacy.conf`) or a line placed before the
`Include` in the main file overrides yours. Search: `sudo grep -ri passwordauthentication /etc/ssh/`. Rename yours to
sort first or remove the conflicting line, then `sshd -t` and reload.

</details>

## Common mistakes

- **Disabling passwords before your key works.** Test key login first.
- **Closing your only session after reloading.** Always test from a second
  terminal.
- **Forgetting `sshd -t`.** A typo stops sshd from starting at the next restart.
- **Trusting a non-standard port as protection.** It only reduces noise.

## Remember

- Drop-in `/etc/ssh/sshd_config.d/10-hardening.conf`: keys only, no root,
  `MaxAuthTries`, `AllowGroups`.
- `sshd -t` (syntax), `sshd -T` (effective config), reload, test in a new
  session.
- fail2ban bans IPs after repeated failures.
- Count attackers with grep + awk + `sort | uniq -c`.

**Self-check:**

1. Why disable both `PasswordAuthentication` and `KbdInteractiveAuthentication`?
2. Which command shows the settings sshd will really use?
3. What does fail2ban do?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('32749896-8ec8-5cc1-8030-1f065f7e2c52', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '303569e7-7bba-5e6f-a8bb-47557bde7da4', 'Auditing a Server: SUID Files, Open Permissions, Accounts and Logins', 'notes', 2, $md$## Why this matters

Tom left a month ago. Did he leave a SUID backdoor, a world-writable script that
root runs from cron, or an extra UID 0 account? An audit answers "what is on this
box that should not be?" with a handful of `find` and `awk` commands you already
know.

## Mental model: an inventory walk

Walk the shop with a checklist and write down anything unusual:

```
 1. Privileged files      SUID/SGID binaries, file capabilities
 2. Open permissions      world-writable files and directories, secrets readable by all
 3. Accounts              UID 0, empty passwords, unexpected logins, sudo rights
 4. Logins and changes    last/lastb, auth log, package history
 5. Integrity             are system files what the packages installed?
```

## See it work

### 1. Privileged files

```bash
sudo find / -xdev -perm -4000 -type f 2>/dev/null     # SUID
sudo find / -xdev -perm -2000 -type f 2>/dev/null     # SGID
getcap -r / 2>/dev/null                               # file capabilities
```

Compare against a known-good server or the package list: `dpkg -S` on each path
should name a package. A SUID file that no package owns (`dpkg -S` says "no path
found") in `/tmp`, `/home` or `/var` is a red flag.

### 2. Open permissions

```bash
sudo find / -xdev -type f -perm -o+w 2>/dev/null                  # world-writable files
sudo find / -xdev -type d -perm -o+w ! -perm -1000 2>/dev/null     # world-writable dirs without sticky bit
sudo find /etc /opt /srv -name '*.env' -perm /o+r 2>/dev/null      # secrets readable by others
```

`-perm -o+w` means "at least these bits set"; `-perm /o+r` means "any of these
bits set". The worst case: a world-writable script that **root** runs (cron,
systemd). Anyone could add a line and become root.

Fix in bulk, keeping all other bits:

```bash
find /srv/shop -perm -o+w -exec chmod o-w {} +
```

### 3. Accounts

```bash
awk -F: '$3 == 0 {print $1}' /etc/passwd             # only root expected
sudo awk -F: '$2 == "" {print $1}' /etc/shadow        # empty passwords
awk -F: '$7 !~ /nologin|false/ {print $1, $7}' /etc/passwd   # who can log in
getent group sudo                                     # who has full sudo (wheel on RHEL)
sudo ls /etc/sudoers.d/ && sudo grep -r NOPASSWD /etc/sudoers /etc/sudoers.d/
for u in $(cut -d: -f1 /etc/passwd); do sudo crontab -l -u "$u" 2>/dev/null | sed "s/^/$u: /"; done
```

### 4. Logins and changes

```bash
last -n 20            # recent logins and reboots
sudo lastb -n 20      # failed logins
lastlog | grep -v 'Never logged in'
grep -E ' install | upgrade | remove ' /var/log/dpkg.log | tail
```

### 5. Integrity and auditing tools

- `debsums -s` (Debian/Ubuntu) or `rpm -Va` (RHEL) compare installed files with
  the package checksums: changed binaries stand out.
- **AIDE** builds a database of file hashes and reports changes later.
- **auditd** records chosen events in the kernel, for example every change to
  `/etc/passwd`:

```bash
sudo auditctl -w /etc/passwd -p wa -k identity
sudo ausearch -k identity --start today
```

## Try it

You find `-rwsr-xr-x root root /var/tmp/.cache/sh`. Is that normal? What do you
check, and what do you do?

<details>
<summary>Show answer</summary>

Not normal: a SUID-root shell in a temp directory is a classic backdoor (anyone
running it gets root). `dpkg -S /var/tmp/.cache/sh` will find no package. Treat
the server as compromised: preserve evidence (copy the file, note timestamps
with `stat`, check `last`, auth logs and cron), then follow your incident
process. Usually that means rebuilding the server from a clean image and
rotating credentials, not just deleting the file.

</details>

## Common mistakes

- **Running `find /` without `-xdev`.** It wanders into `/proc` and network
  mounts.
- **Deleting suspicious files immediately.** You lose the evidence of how and
  when. Copy and record first.
- **Fixing permissions with `chmod -R 755`.** It changes far more than needed;
  remove only the bad bit (`chmod o-w`).
- **Auditing only once.** Schedule it and diff the results.

## Remember

- SUID/SGID: `find / -xdev -perm -4000`; capabilities: `getcap -r /`.
- World-writable: `find -perm -o+w`; fix with `chmod o-w`.
- Accounts: UID 0, empty passwords, login shells, sudo group, crontabs.
- `last`, `lastb`, logs, package history; `debsums`/`rpm -Va`, AIDE, auditd.

**Self-check:**

1. What is the difference between `-perm -o+w` and `-perm /o+w`?
2. Why is a world-writable script run by root's cron dangerous?
3. Why copy evidence before deleting a suspicious file?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b36783aa-e3cf-5870-b0cb-b98a0029f958', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '303569e7-7bba-5e6f-a8bb-47557bde7da4', 'Beyond Permissions: AppArmor, SELinux and systemd Sandboxing', 'notes', 3, $md$## Why this matters

File permissions say what a **user** may do. If nginx (user `www-data`) is
hacked, the attacker can do everything `www-data` can, including reading every
file that user can read. **Mandatory access control** and **sandboxing** limit
what a specific **program** may do, even when the permissions would allow it.

## Mental model: a job description on top of the key ring

- **DAC** (discretionary access control) = classic rwx and ACLs. The owner
  decides. Chapter 4.
- **MAC** (mandatory access control) = a policy written by the admin that the
  program cannot change: "nginx may read `/srv/www` and `/etc/nginx`, write
  `/var/log/nginx`, and nothing else". Both checks must pass.

```
 request from nginx to read /home/rhea/notes.txt
   DAC (rwx):      others may read     -> allowed
   MAC (AppArmor): not in nginx profile -> DENIED
```

Two MAC systems:

| | AppArmor | SELinux |
|---|---|---|
| Default on | Ubuntu, Debian, SUSE | RHEL, Fedora, Rocky, Alma |
| Policy based on | file **paths** per program (profiles) | **labels** on every file and process |
| Status | `sudo aa-status` | `getenforce`, `sestatus` |
| Modes | enforce / complain | enforcing / permissive / disabled |

## See it work

### AppArmor (Ubuntu)

```bash
sudo aa-status | head
```

```
apparmor module is loaded.
48 profiles are loaded.
46 profiles are in enforce mode.
   /usr/sbin/cupsd
   /usr/sbin/mysqld
...
```

Denials appear in the kernel log:

```bash
sudo journalctl -k | grep -i 'apparmor="DENIED"'
```

Profiles live in `/etc/apparmor.d/`. `sudo aa-complain /usr/sbin/mysqld` logs
instead of blocking while you fix a profile; `aa-enforce` turns it back on.

### SELinux (RHEL family)

```bash
getenforce                        # Enforcing / Permissive / Disabled
ls -Z /var/www/html/index.html    # the file's label
sudo ausearch -m avc -ts recent   # denials
sudo restorecon -Rv /var/www/html # reset labels to the policy default
```

The classic SELinux bug: you `mv` files from your home into `/var/www/html`;
they keep the home-directory label, and the web server gets "Permission denied"
although rwx looks fine. `restorecon` fixes it. Do **not** fix it with
`setenforce 0`; that switches off protection for the whole machine.

### systemd sandboxing: cheap and per service

Many sandbox options are one line each in a unit file:

```ini
[Service]
User=brewbot
NoNewPrivileges=yes          # cannot gain privileges via SUID binaries
ProtectSystem=strict         # / is read-only for this service...
ReadWritePaths=/var/lib/brewbot /var/log/brewbot   # ...except these
ProtectHome=yes              # /home, /root invisible
PrivateTmp=yes               # its own /tmp
CapabilityBoundingSet=       # no capabilities at all
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
```

```bash
systemd-analyze security brewbot
```

```
→ Overall exposure level for brewbot.service: 3.1 OK
```

The score drops from around 9.6 ("UNSAFE") as you add options. Add them one at a
time and check the service still works.

## Try it

On a RHEL server, nginx returns 403 for a page you just moved from your home
directory. `ls -l` shows `-rw-r--r-- nginx nginx`. What is the likely cause and
fix?

<details>
<summary>Show answer</summary>

SELinux labels: the moved file kept its `user_home_t` label, which nginx may not
read. Check with `ls -Z` and `ausearch -m avc -ts recent`, then fix with
`sudo restorecon -Rv /usr/share/nginx/html` (or the site's directory). Leave
SELinux enforcing.

</details>

## Common mistakes

- **Disabling SELinux/AppArmor at the first denial.** Read the denial and fix the
  label or the profile.
- **`mv` vs `cp` on SELinux systems.** `mv` keeps old labels; run `restorecon`.
- **Adding every sandbox option at once.** The service breaks and you do not
  know which line did it.

## Remember

- DAC = rwx/ACLs (user-based); MAC = admin policy per program; both must allow.
- AppArmor (Ubuntu): profiles by path, `aa-status`, denials in the kernel log.
- SELinux (RHEL): labels, `getenforce`, `ls -Z`, `restorecon`, `ausearch -m avc`.
- systemd sandboxing: `NoNewPrivileges`, `ProtectSystem`, `ProtectHome`,
  `PrivateTmp`; score with `systemd-analyze security`.

**Self-check:**

1. What does MAC add on top of normal permissions?
2. Which command fixes wrong SELinux labels?
3. What does `ProtectSystem=strict` do?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('98e8fdd8-e24e-5db1-b803-395897fc53f0', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '303569e7-7bba-5e6f-a8bb-47557bde7da4', 'Lab: Audit and Harden Tom''s Leftovers', 'notes', 4, $md$## Why this matters

Tom's leftovers are in `~/work/audit`: a small copy of a web root, an app, some
tools and an auth log. Somewhere in there is a backdoor, a leaked secret and
files anyone can change. Audit it, fix it, and harden SSH. Each task is checked
automatically.

## Before you start

```bash
cd ~/work/audit
ls -laR
```

What this does: lists everything, including hidden files, with permissions. Look
for `s` in the owner execute position and `w` in the last triplet.

## Task 1: find the SUID files

List every SUID file under `~/work/audit`, one full path per line, into
`~/work/answers/suid.txt`.

[[lab-task:1]]

## Task 2: defuse the backdoor

`tools/.helper` is a script that runs `bash -p`: with SUID, a privileged shell.
Remove its SUID bit; leave `brewstat` alone.

[[lab-task:2]]

## Task 3: close the world-writable files and directories

Remove write permission for others from everything under `~/work/audit`,
changing no other bits.

[[lab-task:3]]

What you should see afterwards:

```
$ find ~/work/audit -perm -o+w
$
```

## Task 4: lock the secret

Make `app/.env` readable and writable by its owner only.

[[lab-task:4]]

## Task 5: write the SSH hardening drop-in

Create `audit/sshd_config.d/10-hardening.conf`: no password authentication, no
root login, at most 3 authentication attempts.

[[lab-task:5]]

## Task 6: who is attacking?

From `audit/auth.log`, save the IP with the most `Failed password` lines into
`answers/attacker.txt`.

[[lab-task:6]]

## Remember

- `find -perm -4000` for SUID, `-perm -o+w` for world-writable.
- Fix only the bad bit: `chmod u-s`, `chmod o-w`.
- Secrets 600; SSH: keys only, no root, few attempts.
- Logs plus the top-N pipeline show who is attacking.

> **End of week 3.** Atlas is patched, locked down and audited. Rhea reads your
> report and nods: "Black Friday is next week. You're on call." Tom's last note,
> stuck to the server rack: "When it breaks, stay calm and follow the method."
$md$, 25, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('3d5814c7-4ab9-5d2a-a071-4b5f85734600', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '98e8fdd8-e24e-5db1-b803-395897fc53f0', 'module', 'Lab: Audit and Harden Tom''s Leftovers', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$mkdir -p /home/labuser/work
mkdir -p /home/labuser/work/audit && chmod 777 /home/labuser/work/audit
cat > /home/labuser/work/audit/auth.log <<'MFEOF'
Nov 23 03:11:02 atlas sshd[2101]: Failed password for root from 198.51.100.23 port 40122 ssh2
Nov 23 03:11:05 atlas sshd[2101]: Failed password for root from 198.51.100.23 port 40122 ssh2
Nov 23 03:11:09 atlas sshd[2104]: Failed password for invalid user admin from 203.0.113.77 port 51811 ssh2
Nov 23 03:12:41 atlas sshd[2110]: Accepted publickey for rhea from 10.0.0.7 port 51522 ssh2
Nov 23 03:13:00 atlas sshd[2115]: Failed password for invalid user test from 198.51.100.23 port 40188 ssh2
Nov 23 03:13:04 atlas sshd[2115]: Failed password for invalid user oracle from 198.51.100.23 port 40188 ssh2
Nov 23 03:14:22 atlas sshd[2120]: Failed password for root from 192.0.2.150 port 33001 ssh2
Nov 23 03:14:25 atlas sshd[2120]: Failed password for root from 192.0.2.150 port 33001 ssh2
Nov 23 03:15:10 atlas sshd[2131]: Failed password for invalid user deploy from 203.0.113.77 port 51990 ssh2
Nov 23 03:16:45 atlas sshd[2140]: Failed password for root from 198.51.100.23 port 40301 ssh2
Nov 23 03:17:02 atlas sudo:     rhea : TTY=pts/0 ; PWD=/home/rhea ; USER=root ; COMMAND=/usr/bin/apt update
Nov 23 03:18:30 atlas sshd[2150]: Failed password for invalid user pi from 192.0.2.150 port 33100 ssh2

MFEOF
chmod 666 /home/labuser/work/audit/auth.log
a=/home/labuser/work/audit
rm -rf $a/srv $a/app $a/tools $a/sshd_config.d /home/labuser/work/answers
mkdir -p $a/srv/www $a/srv/uploads $a/app $a/tools /home/labuser/work/answers
echo '<h1>Orbit Coffee</h1>' > $a/srv/www/index.html
echo 'echo checking' > $a/tools/check.sh
echo 'echo rotating' > $a/tools/rotate.sh
printf '#!/bin/bash\nexec /bin/bash -p\n' > $a/tools/.helper
printf '#!/bin/bash\necho status\n' > $a/tools/brewstat
echo 'DB_PASSWORD=espresso' > $a/app/.env
echo 'name = brewbot' > $a/app/brewbot.conf
chmod 755 $a/srv $a/srv/www $a/app $a/tools
chmod 777 $a/srv/uploads
chmod 666 $a/srv/www/index.html
chmod 777 $a/tools/check.sh
chmod 755 $a/tools/rotate.sh
chmod 4755 $a/tools/.helper
chmod 4755 $a/tools/brewstat
chmod 644 $a/app/.env
chmod 644 $a/app/brewbot.conf
$script$, NULL, 40, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'e51d093a-4eb0-533a-bd1c-4ce65c49db1a' AND id NOT IN ('eb5630da-3521-504d-bbbd-5f63bce6f2fb', 'eb596b1b-4e50-588f-bfa0-fbe6e276a87a', '85a5b571-acf6-519c-968a-0639a6d305bc', '7edc8910-aef4-580c-943f-862f1bd8bf49', '076f9352-7bb2-5212-9a9f-c2e445b0b3d8', 'dbe7fa3a-96a3-50cd-a9f2-ad02f3a36027');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'e51d093a-4eb0-533a-bd1c-4ce65c49db1a';
DELETE FROM lab_tasks WHERE lab_id = '3d5814c7-4ab9-5d2a-a071-4b5f85734600' AND id NOT IN ('89a8fb73-e2f2-59af-8005-93b2b03bb6f2', '505e36f4-c0ed-5278-bdb8-8ab8f31961e1', 'e5b193ad-bcdf-5c65-ad87-7cea5d3c1469', '58e09ac1-554f-5601-a355-bcc7f6146424', 'f35c05ad-4013-5641-8693-965c12984466', '28506e59-5789-5f3c-9fd3-931e35fb3f3f');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '3d5814c7-4ab9-5d2a-a071-4b5f85734600';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('89a8fb73-e2f2-59af-8005-93b2b03bb6f2', '3d5814c7-4ab9-5d2a-a071-4b5f85734600', 1, 'Find the SUID files', $md$List every file under /home/labuser/work/audit that has the SUID bit set, one full path per line, into /home/labuser/work/answers/suid.txt.$md$, $script$a=/home/labuser/work/audit
diff <(find $a -type f -perm -4000 | sort) <(grep -v '^$' /home/labuser/work/answers/suid.txt | sort) >/dev/null
$script$, 'find /home/labuser/work/audit -type f -perm -4000 lists them. Hidden files count too - find shows them, ls does not.', 'SUID makes a program run as its owner. A SUID file that execs bash -p is a classic backdoor - whoever runs it keeps the owner''s privileges. Audit these regularly.', 20, false, true),
('505e36f4-c0ed-5278-bdb8-8ab8f31961e1', '3d5814c7-4ab9-5d2a-a071-4b5f85734600', 2, 'Defuse the backdoor', $md$Remove the SUID bit from the hidden helper script tools/.helper (keep its other permissions as they are). Leave brewstat alone.$md$, $script$a=/home/labuser/work/audit/tools
[ "$(stat -c %a $a/.helper)" = 755 ] && [ "$(stat -c %a $a/brewstat)" = 4755 ]
$script$, 'chmod u-s removes only the SUID bit.', 'chmod u-s clears SUID and leaves rwx untouched. On a real server you would first copy the file and record stat output as evidence, then investigate how it got there.', 15, false, true),
('e5b193ad-bcdf-5c65-ad87-7cea5d3c1469', '3d5814c7-4ab9-5d2a-a071-4b5f85734600', 3, 'Close the world-writable files and directories', $md$Remove write permission for others from every file and directory under /home/labuser/work/audit, without changing any other permission bits.$md$, $script$a=/home/labuser/work/audit
[ -z "$(find $a -perm -o+w)" ] &&
[ "$(stat -c %a $a/tools/check.sh)" = 775 ] &&
[ "$(stat -c %a $a/srv/uploads)" = 775 ] &&
[ "$(stat -c %a $a/srv/www/index.html)" = 664 ] &&
[ "$(stat -c %a $a/tools/rotate.sh)" = 755 ]
$script$, 'find /home/labuser/work/audit -perm -o+w lists them; add -exec chmod o-w {} + to fix all at once.', 'chmod o-w removes only the others-write bit, so owners and groups keep their access. A chmod -R 755 would also have changed files that were fine.', 25, false, true),
('58e09ac1-554f-5601-a355-bcc7f6146424', '3d5814c7-4ab9-5d2a-a071-4b5f85734600', 4, 'Lock the secret', $md$Make app/.env readable and writable by its owner only.$md$, $script$[ "$(stat -c %a /home/labuser/work/audit/app/.env)" = 600 ]
$script$, 'chmod 600 /home/labuser/work/audit/app/.env', 'Secrets files must be 600 (or 640 with a service group). Anyone who can read .env can log into the database.', 15, false, true),
('f35c05ad-4013-5641-8693-965c12984466', '3d5814c7-4ab9-5d2a-a071-4b5f85734600', 5, 'Write the SSH hardening drop-in', $md$Create /home/labuser/work/audit/sshd_config.d/10-hardening.conf that disables password authentication, forbids root login and allows at most 3 authentication attempts per connection.$md$, $script$f=/home/labuser/work/audit/sshd_config.d/10-hardening.conf
grep -Eiq '^\s*PasswordAuthentication\s+no\s*$' $f &&
grep -Eiq '^\s*PermitRootLogin\s+no\s*$' $f &&
grep -Eiq '^\s*MaxAuthTries\s+3\s*$' $f
$script$, 'One setting per line - PasswordAuthentication no, PermitRootLogin no, MaxAuthTries 3.', 'On a real server this file goes in /etc/ssh/sshd_config.d/, followed by sshd -t, sshd -T to confirm, a reload, and a test login from a second terminal.', 15, false, true),
('28506e59-5789-5f3c-9fd3-931e35fb3f3f', '3d5814c7-4ab9-5d2a-a071-4b5f85734600', 6, 'Who is attacking?', $md$From audit/auth.log, find the IP address with the most "Failed password" lines and save only that IP into answers/attacker.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/attacker.txt)" = 198.51.100.23 ]
$script$, 'grep ''Failed password'' auth.log | awk ''{print $(NF-3)}'' | sort | uniq -c | sort -rn | head -1', 'The IP is the fourth field from the end of each OpenSSH failure line. The top-N pipeline from chapter 3 turns a log into a ranking in one line; fail2ban automates the same idea.', 10, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('e51d093a-4eb0-533a-bd1c-4ce65c49db1a', '3d5814c7-4ab9-5d2a-a071-4b5f85734600', 1, $json$[{"id":"89a8fb73-e2f2-59af-8005-93b2b03bb6f2","lab_id":"3d5814c7-4ab9-5d2a-a071-4b5f85734600","position":1,"title":"Find the SUID files","description":"List every file under /home/labuser/work/audit that has the SUID bit set, one full path per line, into /home/labuser/work/answers/suid.txt.","verification_script":"a=/home/labuser/work/audit\ndiff \u003c(find $a -type f -perm -4000 | sort) \u003c(grep -v '^$' /home/labuser/work/answers/suid.txt | sort) \u003e/dev/null\n","hint_context":"find /home/labuser/work/audit -type f -perm -4000 lists them. Hidden files count too - find shows them, ls does not.","explanation_context":"SUID makes a program run as its owner. A SUID file that execs bash -p is a classic backdoor - whoever runs it keeps the owner's privileges. Audit these regularly.","points":20,"is_optional":false,"is_stateful":true},{"id":"505e36f4-c0ed-5278-bdb8-8ab8f31961e1","lab_id":"3d5814c7-4ab9-5d2a-a071-4b5f85734600","position":2,"title":"Defuse the backdoor","description":"Remove the SUID bit from the hidden helper script tools/.helper (keep its other permissions as they are). Leave brewstat alone.","verification_script":"a=/home/labuser/work/audit/tools\n[ \"$(stat -c %a $a/.helper)\" = 755 ] \u0026\u0026 [ \"$(stat -c %a $a/brewstat)\" = 4755 ]\n","hint_context":"chmod u-s removes only the SUID bit.","explanation_context":"chmod u-s clears SUID and leaves rwx untouched. On a real server you would first copy the file and record stat output as evidence, then investigate how it got there.","points":15,"is_optional":false,"is_stateful":true},{"id":"e5b193ad-bcdf-5c65-ad87-7cea5d3c1469","lab_id":"3d5814c7-4ab9-5d2a-a071-4b5f85734600","position":3,"title":"Close the world-writable files and directories","description":"Remove write permission for others from every file and directory under /home/labuser/work/audit, without changing any other permission bits.","verification_script":"a=/home/labuser/work/audit\n[ -z \"$(find $a -perm -o+w)\" ] \u0026\u0026\n[ \"$(stat -c %a $a/tools/check.sh)\" = 775 ] \u0026\u0026\n[ \"$(stat -c %a $a/srv/uploads)\" = 775 ] \u0026\u0026\n[ \"$(stat -c %a $a/srv/www/index.html)\" = 664 ] \u0026\u0026\n[ \"$(stat -c %a $a/tools/rotate.sh)\" = 755 ]\n","hint_context":"find /home/labuser/work/audit -perm -o+w lists them; add -exec chmod o-w {} + to fix all at once.","explanation_context":"chmod o-w removes only the others-write bit, so owners and groups keep their access. A chmod -R 755 would also have changed files that were fine.","points":25,"is_optional":false,"is_stateful":true},{"id":"58e09ac1-554f-5601-a355-bcc7f6146424","lab_id":"3d5814c7-4ab9-5d2a-a071-4b5f85734600","position":4,"title":"Lock the secret","description":"Make app/.env readable and writable by its owner only.","verification_script":"[ \"$(stat -c %a /home/labuser/work/audit/app/.env)\" = 600 ]\n","hint_context":"chmod 600 /home/labuser/work/audit/app/.env","explanation_context":"Secrets files must be 600 (or 640 with a service group). Anyone who can read .env can log into the database.","points":15,"is_optional":false,"is_stateful":true},{"id":"f35c05ad-4013-5641-8693-965c12984466","lab_id":"3d5814c7-4ab9-5d2a-a071-4b5f85734600","position":5,"title":"Write the SSH hardening drop-in","description":"Create /home/labuser/work/audit/sshd_config.d/10-hardening.conf that disables password authentication, forbids root login and allows at most 3 authentication attempts per connection.","verification_script":"f=/home/labuser/work/audit/sshd_config.d/10-hardening.conf\ngrep -Eiq '^\\s*PasswordAuthentication\\s+no\\s*$' $f \u0026\u0026\ngrep -Eiq '^\\s*PermitRootLogin\\s+no\\s*$' $f \u0026\u0026\ngrep -Eiq '^\\s*MaxAuthTries\\s+3\\s*$' $f\n","hint_context":"One setting per line - PasswordAuthentication no, PermitRootLogin no, MaxAuthTries 3.","explanation_context":"On a real server this file goes in /etc/ssh/sshd_config.d/, followed by sshd -t, sshd -T to confirm, a reload, and a test login from a second terminal.","points":15,"is_optional":false,"is_stateful":true},{"id":"28506e59-5789-5f3c-9fd3-931e35fb3f3f","lab_id":"3d5814c7-4ab9-5d2a-a071-4b5f85734600","position":6,"title":"Who is attacking?","description":"From audit/auth.log, find the IP address with the most \"Failed password\" lines and save only that IP into answers/attacker.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/attacker.txt)\" = 198.51.100.23 ]\n","hint_context":"grep 'Failed password' auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -1","explanation_context":"The IP is the fourth field from the end of each OpenSSH failure line. The top-N pipeline from chapter 3 turns a log into a ranking in one line; fail2ban automates the same idea.","points":10,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('eb5630da-3521-504d-bbbd-5f63bce6f2fb', 'e51d093a-4eb0-533a-bd1c-4ce65c49db1a', '89a8fb73-e2f2-59af-8005-93b2b03bb6f2', 1, 'Find the SUID files', $md$List every file under /home/labuser/work/audit that has the SUID bit set, one full path per line, into /home/labuser/work/answers/suid.txt.$md$, $script$a=/home/labuser/work/audit
diff <(find $a -type f -perm -4000 | sort) <(grep -v '^$' /home/labuser/work/answers/suid.txt | sort) >/dev/null
$script$, 'find /home/labuser/work/audit -type f -perm -4000 lists them. Hidden files count too - find shows them, ls does not.', 'SUID makes a program run as its owner. A SUID file that execs bash -p is a classic backdoor - whoever runs it keeps the owner''s privileges. Audit these regularly.', 20, false, true),
('eb596b1b-4e50-588f-bfa0-fbe6e276a87a', 'e51d093a-4eb0-533a-bd1c-4ce65c49db1a', '505e36f4-c0ed-5278-bdb8-8ab8f31961e1', 2, 'Defuse the backdoor', $md$Remove the SUID bit from the hidden helper script tools/.helper (keep its other permissions as they are). Leave brewstat alone.$md$, $script$a=/home/labuser/work/audit/tools
[ "$(stat -c %a $a/.helper)" = 755 ] && [ "$(stat -c %a $a/brewstat)" = 4755 ]
$script$, 'chmod u-s removes only the SUID bit.', 'chmod u-s clears SUID and leaves rwx untouched. On a real server you would first copy the file and record stat output as evidence, then investigate how it got there.', 15, false, true),
('85a5b571-acf6-519c-968a-0639a6d305bc', 'e51d093a-4eb0-533a-bd1c-4ce65c49db1a', 'e5b193ad-bcdf-5c65-ad87-7cea5d3c1469', 3, 'Close the world-writable files and directories', $md$Remove write permission for others from every file and directory under /home/labuser/work/audit, without changing any other permission bits.$md$, $script$a=/home/labuser/work/audit
[ -z "$(find $a -perm -o+w)" ] &&
[ "$(stat -c %a $a/tools/check.sh)" = 775 ] &&
[ "$(stat -c %a $a/srv/uploads)" = 775 ] &&
[ "$(stat -c %a $a/srv/www/index.html)" = 664 ] &&
[ "$(stat -c %a $a/tools/rotate.sh)" = 755 ]
$script$, 'find /home/labuser/work/audit -perm -o+w lists them; add -exec chmod o-w {} + to fix all at once.', 'chmod o-w removes only the others-write bit, so owners and groups keep their access. A chmod -R 755 would also have changed files that were fine.', 25, false, true),
('7edc8910-aef4-580c-943f-862f1bd8bf49', 'e51d093a-4eb0-533a-bd1c-4ce65c49db1a', '58e09ac1-554f-5601-a355-bcc7f6146424', 4, 'Lock the secret', $md$Make app/.env readable and writable by its owner only.$md$, $script$[ "$(stat -c %a /home/labuser/work/audit/app/.env)" = 600 ]
$script$, 'chmod 600 /home/labuser/work/audit/app/.env', 'Secrets files must be 600 (or 640 with a service group). Anyone who can read .env can log into the database.', 15, false, true),
('076f9352-7bb2-5212-9a9f-c2e445b0b3d8', 'e51d093a-4eb0-533a-bd1c-4ce65c49db1a', 'f35c05ad-4013-5641-8693-965c12984466', 5, 'Write the SSH hardening drop-in', $md$Create /home/labuser/work/audit/sshd_config.d/10-hardening.conf that disables password authentication, forbids root login and allows at most 3 authentication attempts per connection.$md$, $script$f=/home/labuser/work/audit/sshd_config.d/10-hardening.conf
grep -Eiq '^\s*PasswordAuthentication\s+no\s*$' $f &&
grep -Eiq '^\s*PermitRootLogin\s+no\s*$' $f &&
grep -Eiq '^\s*MaxAuthTries\s+3\s*$' $f
$script$, 'One setting per line - PasswordAuthentication no, PermitRootLogin no, MaxAuthTries 3.', 'On a real server this file goes in /etc/ssh/sshd_config.d/, followed by sshd -t, sshd -T to confirm, a reload, and a test login from a second terminal.', 15, false, true),
('dbe7fa3a-96a3-50cd-a9f2-ad02f3a36027', 'e51d093a-4eb0-533a-bd1c-4ce65c49db1a', '28506e59-5789-5f3c-9fd3-931e35fb3f3f', 6, 'Who is attacking?', $md$From audit/auth.log, find the IP address with the most "Failed password" lines and save only that IP into answers/attacker.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/attacker.txt)" = 198.51.100.23 ]
$script$, 'grep ''Failed password'' auth.log | awk ''{print $(NF-3)}'' | sort | uniq -c | sort -rn | head -1', 'The IP is the fourth field from the end of each OpenSSH failure line. The top-N pipeline from chapter 3 turns a log into a ranking in one line; fail2ban automates the same idea.', 10, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'e51d093a-4eb0-533a-bd1c-4ce65c49db1a', updated_at = now()
WHERE id = '3d5814c7-4ab9-5d2a-a071-4b5f85734600' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ed4f530f-03ac-5ef4-a394-ad7f68d7a84d', '00000000-0000-0000-0000-000000000001', 'mcq', 'ss -tulpn shows redis-server on 0.0.0.0:6379. Only brewbot on the same machin...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5ca2c02c-3055-5aaf-98a4-e4d96712a382', 'ed4f530f-03ac-5ef4-a394-ad7f68d7a84d', 1, $json${"prompt":"ss -tulpn shows redis-server on 0.0.0.0:6379. Only brewbot on the same machine uses Redis. What is the best fix?","multiple":false,"options":[{"id":"a","text":"Bind Redis to 127.0.0.1 and also make sure the firewall does not allow 6379 from outside","is_correct":true},{"id":"b","text":"Move Redis to port 6380","is_correct":false},{"id":"c","text":"Run Redis as root","is_correct":false},{"id":"d","text":"Nothing; Redis has no security issues","is_correct":false}],"explanation":"Listen only where clients are, and keep the firewall as a second layer (defence in depth). A different port only hides it, root makes a compromise worse, and exposed Redis instances are a common way in."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6d7cadd9-a487-5b71-a32c-2168c3b195e1', '00000000-0000-0000-0000-000000000001', 'mcq', 'You added PasswordAuthentication no in a drop-in and want to apply it safely....', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('39218478-fbe4-5510-b919-e6b2cf4c0ba4', '6d7cadd9-a487-5b71-a32c-2168c3b195e1', 1, $json${"prompt":"You added PasswordAuthentication no in a drop-in and want to apply it safely. What is the right order?","multiple":false,"options":[{"id":"a","text":"sshd -t, sshd -T to confirm the value, reload ssh, then test a login from a NEW terminal before closing the old one","is_correct":true},{"id":"b","text":"Reboot the server and hope","is_correct":false},{"id":"c","text":"Restart ssh and log out immediately","is_correct":false},{"id":"d","text":"Delete authorized_keys first","is_correct":false}],"explanation":"Check syntax, confirm the effective value, reload (existing sessions survive), and prove you can still get in. The other options risk locking you out."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ad0f8711-a858-572e-b067-88978874cc23', '00000000-0000-0000-0000-000000000001', 'mcq', 'An audit finds -rwsr-xr-x root root /var/tmp/.x/sh that no package owns. What...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ffae97dd-1568-545e-af33-4ba38c254157', 'ad0f8711-a858-572e-b067-88978874cc23', 1, $json${"prompt":"An audit finds -rwsr-xr-x root root /var/tmp/.x/sh that no package owns. What is the right response?","multiple":false,"options":[{"id":"a","text":"Treat it as a likely compromise: preserve evidence, investigate logins and cron, and plan a rebuild and credential rotation","is_correct":true},{"id":"b","text":"chmod u-s and move on","is_correct":false},{"id":"c","text":"Delete it and reboot","is_correct":false},{"id":"d","text":"Ignore it; /var/tmp is temporary","is_correct":false}],"explanation":"A SUID-root shell in a temp directory is a backdoor; something put it there with root access. Removing the bit or the file alone leaves whatever else the attacker changed, and deleting first destroys evidence."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ca0c75e4-f474-5701-a695-c4faff74bbb1', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command removes write access for others from everything under /srv/shop...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('869135fe-9ba7-5843-a4b6-f3ccd4b03289', 'ca0c75e4-f474-5701-a695-c4faff74bbb1', 1, $json${"prompt":"Which command removes write access for others from everything under /srv/shop while keeping all other bits?","multiple":false,"options":[{"id":"a","text":"find /srv/shop -perm -o+w -exec chmod o-w {} +","is_correct":true},{"id":"b","text":"chmod -R 755 /srv/shop","is_correct":false},{"id":"c","text":"chmod -R 000 /srv/shop","is_correct":false},{"id":"d","text":"chown -R root /srv/shop","is_correct":false}],"explanation":"chmod o-w clears only that bit on exactly the files that have it. 755 changes every file (making them executable), 000 breaks everything, and chown changes ownership, not the others-write bit."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('afaa5642-1975-517c-902e-0089cc849608', '00000000-0000-0000-0000-000000000001', 'mcq', 'On a RHEL server nginx returns 403 for files you moved from your home into th...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('68c223e9-b4c9-5e42-a0dc-6fafcf8f0e06', 'afaa5642-1975-517c-902e-0089cc849608', 1, $json${"prompt":"On a RHEL server nginx returns 403 for files you moved from your home into the web root. ls -l looks fine. What is likely, and what is the right fix?","multiple":false,"options":[{"id":"a","text":"Wrong SELinux labels from mv; run restorecon -Rv on the web root","is_correct":true},{"id":"b","text":"Run setenforce 0 permanently","is_correct":false},{"id":"c","text":"chmod 777 the files","is_correct":false},{"id":"d","text":"Reinstall nginx","is_correct":false}],"explanation":"mv keeps the home-directory label, which nginx may not read; restorecon resets labels to the policy. Disabling SELinux removes protection everywhere, 777 does not change labels, and nginx itself is fine."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('9070e329-ca60-5be6-9a62-865a03ffbd79', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does fail2ban do for SSH?', 'beginner', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d32dc4e9-2b2e-5ea6-a928-d50e855fc4d2', '9070e329-ca60-5be6-9a62-865a03ffbd79', 1, $json${"prompt":"What does fail2ban do for SSH?","multiple":false,"options":[{"id":"a","text":"Watches the auth log and temporarily blocks IPs with too many failed logins","is_correct":true},{"id":"b","text":"Encrypts SSH traffic","is_correct":false},{"id":"c","text":"Replaces passwords with keys","is_correct":false},{"id":"d","text":"Moves SSH to a random port","is_correct":false}],"explanation":"fail2ban counts failures per IP and adds firewall bans. SSH already encrypts, keys are configured in sshd, and port changes are unrelated."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('4199b3ff-f918-5a21-9ddc-1246c9116053', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which unit-file line stops a service from ever gaining privileges through SUI...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c32703ae-db9f-53a4-88d3-162fd2eeafe4', '4199b3ff-f918-5a21-9ddc-1246c9116053', 1, $json${"prompt":"Which unit-file line stops a service from ever gaining privileges through SUID binaries?","multiple":false,"options":[{"id":"a","text":"NoNewPrivileges=yes","is_correct":true},{"id":"b","text":"PrivateTmp=yes","is_correct":false},{"id":"c","text":"Restart=on-failure","is_correct":false},{"id":"d","text":"User=root","is_correct":false}],"explanation":"NoNewPrivileges blocks privilege gain via SUID/SGID and file capabilities. PrivateTmp isolates /tmp, Restart is about crashes, and User=root does the opposite of hardening."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ba31e1d7-f064-5f7d-b764-709fd9002012', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 11): during a brute-force attack sshd uses lots of CPU. top s...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ded8987a-640c-5e54-92f7-54a757c963a5', 'ba31e1d7-f064-5f7d-b764-709fd9002012', 1, $json${"prompt":"Review (chapter 11): during a brute-force attack sshd uses lots of CPU. top shows sy high and many short-lived sshd processes. Which USE category and fix fit best?","multiple":false,"options":[{"id":"a","text":"CPU saturation from unwanted work; reduce the work with fail2ban and firewall rules limiting SSH to known networks","is_correct":true},{"id":"b","text":"Disk saturation; add a faster disk","is_correct":false},{"id":"c","text":"Memory errors; add RAM","is_correct":false},{"id":"d","text":"Nothing; this is normal load","is_correct":false}],"explanation":"The CPU is busy handling attack connections. Removing the attack traffic is the fix. Disk and memory are not involved, and sustained attack load is not normal."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('68a99a3a-3ddd-5da5-a289-e445c56f10a1', '00000000-0000-0000-0000-000000000001', 'Quiz: Security Hardening', 'linux-hardening-quiz', 'Quiz covering Chapter 12: Locking Down Atlas - Security Hardening.', 'mcq', 'published', 'module', '2a490cae-71e4-59a9-a587-b59b8f867764', 10, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '68a99a3a-3ddd-5da5-a289-e445c56f10a1' AND question_id NOT IN ('ed4f530f-03ac-5ef4-a394-ad7f68d7a84d', '6d7cadd9-a487-5b71-a32c-2168c3b195e1', 'ad0f8711-a858-572e-b067-88978874cc23', 'ca0c75e4-f474-5701-a695-c4faff74bbb1', 'afaa5642-1975-517c-902e-0089cc849608', '9070e329-ca60-5be6-9a62-865a03ffbd79', '4199b3ff-f918-5a21-9ddc-1246c9116053', 'ba31e1d7-f064-5f7d-b764-709fd9002012');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('1c368c18-de2b-5cc8-be4b-a7f15ba08d5c', '68a99a3a-3ddd-5da5-a289-e445c56f10a1', 'ed4f530f-03ac-5ef4-a394-ad7f68d7a84d', '5ca2c02c-3055-5aaf-98a4-e4d96712a382', 0, 2),
('bbbd6c61-9959-5841-887a-d6ec37066c29', '68a99a3a-3ddd-5da5-a289-e445c56f10a1', '6d7cadd9-a487-5b71-a32c-2168c3b195e1', '39218478-fbe4-5510-b919-e6b2cf4c0ba4', 1, 2),
('98adfc0d-406c-5817-9c8d-532348952a72', '68a99a3a-3ddd-5da5-a289-e445c56f10a1', 'ad0f8711-a858-572e-b067-88978874cc23', 'ffae97dd-1568-545e-af33-4ba38c254157', 2, 2),
('88a0ee63-86f9-5617-9ec4-bf0069ceffc2', '68a99a3a-3ddd-5da5-a289-e445c56f10a1', 'ca0c75e4-f474-5701-a695-c4faff74bbb1', '869135fe-9ba7-5843-a4b6-f3ccd4b03289', 3, 2),
('daeec6ea-354e-5555-90ac-9d789f4c8879', '68a99a3a-3ddd-5da5-a289-e445c56f10a1', 'afaa5642-1975-517c-902e-0089cc849608', '68c223e9-b4c9-5e42-a0dc-6fafcf8f0e06', 4, 2),
('e1ad02cb-27e6-59d3-a9c9-ee98b3a1eb86', '68a99a3a-3ddd-5da5-a289-e445c56f10a1', '9070e329-ca60-5be6-9a62-865a03ffbd79', 'd32dc4e9-2b2e-5ea6-a928-d50e855fc4d2', 5, 2),
('64fe50fa-ce06-58e6-89dd-edc7ef798a55', '68a99a3a-3ddd-5da5-a289-e445c56f10a1', '4199b3ff-f918-5a21-9ddc-1246c9116053', 'c32703ae-db9f-53a4-88d3-162fd2eeafe4', 6, 2),
('026f6537-7544-5f3c-acc5-f01a5f221d6a', '68a99a3a-3ddd-5da5-a289-e445c56f10a1', 'ba31e1d7-f064-5f7d-b764-709fd9002012', 'ded8987a-640c-5e54-92f7-54a757c963a5', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('2a490cae-71e4-59a9-a587-b59b8f867764', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '303569e7-7bba-5e6f-a8bb-47557bde7da4', 'Quiz: Security Hardening', 'assessment', 5, 8, '68a99a3a-3ddd-5da5-a289-e445c56f10a1')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Chapter 13: Incident Week - Troubleshooting Playbook
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('716c0129-f420-5354-9147-1d8b681dd59a', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 13: Incident Week - Troubleshooting Playbook', 13, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('fc864796-19d3-5045-99ff-39d6b618c77f', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '716c0129-f420-5354-9147-1d8b681dd59a', 'The Method: Stay Calm and Check E-R-L-P-C', 'notes', 0, $md$## Why this matters

> **Black Friday, 9:02am.** The sale went live two minutes ago and your pager is
> screaming: *disk 99% full, brewbot erroring, deploy failing.* Rhea is on a
> plane. Tom's last note: **"When it breaks, stay calm and follow the method."**

Under pressure, people try random fixes, and random fixes make outages longer
and destroy evidence. A fixed sequence of checks keeps you calm and finds the
cause faster. Everything from chapters 1-12 gets used here.

## Mental model: a doctor's checklist

A doctor does not guess. They check vital signs in a fixed order, then form one
hypothesis, test it, and treat. Do the same:

```
 1. ERROR       read the exact error message - all of it
 2. RESOURCES   disk (df -h, df -i), memory (free -h), CPU/load (uptime, top)
 3. LOGS        systemctl status X, journalctl -u X, /var/log/*, dmesg
 4. PERMISSIONS ls -l, namei -l, id, who owns it, can this user reach it?
 5. CHANGES     what changed recently? deploys, config edits, updates, certs
```

> **Memory hook:** "**E**very **R**eal **L**inux **P**ro **C**hecks": **E**rror,
> **R**esources, **L**ogs, **P**ermissions, **C**hanges.

Most incidents are found at step 1 (the error says it) or step 5 (someone changed
something).

## See it work: the first 60 seconds on any sick server

```bash
uptime                 # load average - is it busy? getting worse?
dmesg -T | tail        # kernel errors: OOM kills, disk errors
df -h; df -i           # space and inodes
free -h                # memory and swap
top                    # who is using CPU (P) and memory (M)?
systemctl --failed     # what is broken?
journalctl -p err -b   # errors since boot
ss -tulpn              # what is listening?
```

Then look at what changed:

```bash
last -n 5                                       # who logged in
grep -E ' install | upgrade ' /var/log/dpkg.log | tail   # package changes
journalctl --since "1 hour ago" | grep -iE 'deploy|reload|started'
ls -lt /etc | head                              # recently changed config
```

## How to work during an incident

1. **Stabilise first, fix later.** Freeing disk space or rolling back a deploy
   restores service; the root cause can wait an hour.
2. **Change one thing at a time,** and note what you changed and when (a
   timeline in a text file or the incident channel).
3. **Prefer reversible actions.** `mv` config aside instead of deleting;
   truncate instead of `rm` for open logs; `renice` before `kill`.
4. **Keep evidence.** Copy the failing config, save `journalctl` output, before
   restarting.
5. **Communicate.** A one-line status every 15 minutes ("disk freed, brewbot
   restarting, checkout still failing") stops people interrupting you.

## Try it

Brewbot will not start, right after a teammate edited its config. Using the
method, what do you do first, and which step probably holds the answer?

<details>
<summary>Show answer</summary>

Step 1: read the error (`systemctl status brewbot`, then `journalctl -u brewbot
-n 50`). Step 5 (Changes) is the likely cause: diff the config against the
backup or Git, validate it with the program's own checker, fix one line, restart.

</details>

## Common mistakes

- **Rebooting first.** It may "fix" it for an hour and wipes the evidence
  (unless the journal is persistent).
- **Changing several things at once.** You never learn which one helped.
- **Ignoring the exact error text.** "Permission denied", "No space left" and
  "Address already in use" each point straight at one scenario.
- **Fixing alone in silence.** Tell people what you are doing.

## Remember

- E-R-L-P-C: Error, Resources, Logs, Permissions, Changes.
- First 60 s: `uptime`, `dmesg`, `df -h/-i`, `free`, `top`, `systemctl
  --failed`, `journalctl -p err -b`, `ss -tulpn`.
- Stabilise, one change at a time, reversible, keep evidence, communicate.

**Self-check:**

1. What do the letters E-R-L-P-C stand for?
2. Why is rebooting first a bad habit?
3. Name two reversible alternatives to deleting something during an incident.
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a8b8174b-e741-5507-ae90-29cd8d9556b4', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '716c0129-f420-5354-9147-1d8b681dd59a', 'Disk Scenarios: Full, Deleted-but-Open, Inodes, Read-Only', 'notes', 1, $md$## Why this matters

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
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f70cdaac-4587-5fa1-8521-59ab720723bd', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '716c0129-f420-5354-9147-1d8b681dd59a', 'Process Scenarios: Runaway, Hung, OOM-Killed, IO-Bound', 'notes', 2, $md$## Why this matters

The server is slow, a worker stopped doing anything, or a process vanished.
These three symptoms have four common causes. Chapters 5 and 11 gave you the
tools; this lesson is the playbook for using them under pressure.

## Mental model: what is the process doing?

```
 using CPU nonstop           -> runaway (loop, heavy job)          top: high %CPU, state R
 alive but doing nothing     -> hung (waiting on lock, network)    state S or D, no progress
 gone, no error in its log   -> killed (OOM killer, someone else)  dmesg, journal
 slow, CPU idle, load high   -> waiting on disk                    wa high, state D
```

## Scenario 1: a runaway or hung process

**Symptom:** server slow with one process at 100% CPU, or a worker that stopped
processing.

```bash
top                            # press P (CPU) or M (memory)
ps aux --sort=-%cpu | head
pgrep -af brewbot-worker
cat /proc/PID/wchan; echo      # kernel function it is waiting in (if sleeping)
kill PID; sleep 5; kill -9 PID # 15 first, 9 only if needed
```

`strace -p PID` (chapter 10) shows what a hung process is waiting for: a
`futex` (a lock), a `read` on a socket (a slow remote service), `poll`.

**Prevent:** `Restart=on-failure` in the unit file, timeouts in the code,
`CPUQuota=` for batch jobs, a watchdog health check.

## Scenario 2: the OOM killer

**Symptom:** a process vanished with no error in its own log; exit code 137.

```bash
dmesg -T | grep -iE 'killed process|out of memory'
journalctl -k | grep -i oom
free -h
systemctl status brewbot      # "status=9/KILL" or "oom-kill"
```

When memory runs out, the kernel's **OOM killer** kills the process with the
highest score (usually the biggest). **Fix:** find the leak (RSS growing over
time), add RAM or swap, and set `MemoryMax=` on the service so it dies instead of
the database (chapter 10).

## Scenario 3: high load, idle CPU - waiting on disk

`uptime` shows load 12 on 4 CPUs but `top` shows the CPU mostly idle. Look at
`wa` (IO wait) in top's CPU line, and processes in state **`D`**.

```bash
top                       # %Cpu(s): ... 85.0 wa
vmstat 1                  # the "wa" and "b" (blocked) columns
iostat -x 1               # disk %util and await (sysstat package)
ps -eo state,pid,cmd | grep '^D'
```

Load counts processes **waiting**, not just computing. **Fix:** find the
IO-heavy process (`iotop`), a slow or failing disk (`dmesg`), or a backup running
at peak time (`renice` it, `ionice -c3`).

## Scenario 4: too many processes or open files

```bash
ps -eLf | wc -l                       # threads in total
cat /proc/sys/kernel/pid_max
grep 'open files' /proc/PID/limits    # per-process limit
ls /proc/PID/fd | wc -l               # how many it has open
```

"Too many open files" (`EMFILE`) usually means a leak of connections or file
handles. Raise `LimitNOFILE=` only after checking it is real demand, not a leak.

## Try it

`systemctl status brewbot` shows `Main process exited, code=killed,
status=9/KILL` at 09:14, and brewbot's log just stops. What do you check, and
what setting limits the blast radius next time?

<details>
<summary>Show answer</summary>

SIGKILL with no log line suggests the OOM killer: `dmesg -T | grep -i 'killed
process'` around 09:14. Check memory growth (RSS) for a leak. `MemoryMax=` in
the unit confines the damage to brewbot's own cgroup; `OOMScoreAdjust=` can
protect critical services like the database.

</details>

## Common mistakes

- **`kill -9` first.** Loses data and leaves locks; 15 first.
- **Restarting a hung process without looking.** Grab `wchan`, `strace -p` or a
  thread dump first, or the hang returns and you know nothing.
- **Calling every high load "CPU".** Check `wa` and `D` state.

## Remember

- Runaway: `top`/`ps --sort=-%cpu`, TERM then KILL, then prevent.
- Hung: state, `wchan`, `strace -p`; usually a lock or a slow dependency.
- Vanished: `dmesg | grep -i 'killed process'`; `MemoryMax=`.
- Load high + CPU idle + `D` state = disk.

**Self-check:**

1. A process exits with 137 and no log. First command?
2. How can you tell what a hung process is waiting for?
3. Which signals, in which order, stop a stuck worker?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6de74a5b-c7fa-561d-abaf-4a194a2053e7', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '716c0129-f420-5354-9147-1d8b681dd59a', 'Service Scenarios: Permission Denied, Won''t Start, Port in Use, Not Found, Cron', 'notes', 3, $md$## Why this matters

These five errors are the daily bread of operations. Each has a short, fixed
checklist. Knowing it turns a 40-minute hunt into a 4-minute fix.

## Mental model: the error text is the map

```
 "Permission denied"           -> who am I, who owns it, every directory on the path
 "failed" / "exit-code"        -> the service's own log line, then validate config
 "Address already in use"      -> who already has the port
 "command not found"           -> PATH, or the package is missing
 "the cron job didn't run"     -> did cron try? environment? output?
```

## Scenario 1: "Permission denied"

```bash
ls -l deploy.sh               # is the x bit set? who owns it?
namei -l /srv/shop/deploy.sh  # permissions of EVERY directory on the path
id                            # which user and groups am I?
findmnt -no OPTIONS /srv      # mounted noexec?
```

**Fix:** `chmod u+x`, `chown` to the right user, add the user to the group
(`usermod -aG`, then log in again), or run as the right user
(`sudo -u www-data`). On SELinux/AppArmor systems check denials (chapter 12).
**Never** fix it with `chmod 777`.

## Scenario 2: the service will not start

```bash
systemctl status brewbot              # state + last log lines
journalctl -u brewbot -n 50 --no-pager
sudo nginx -t                         # many programs validate their own config
sudo sshd -t
```

Usual causes: a typo in the config, a missing file, wrong permissions on a
config or key, the port already in use, or a dependency (database) not up yet.
**Fix one thing, validate, then restart.** If systemd gave up ("start request
repeated too quickly"), run `systemctl reset-failed brewbot` first.

## Scenario 3: "Address already in use"

```bash
sudo ss -tulpn | grep ':8080'         # who has the port?
sudo lsof -i :8080
```

Usually an old copy of the app is still running, or two services were configured
with the same port. Stop the stray process or change one port.

## Scenario 4: "command not found"

```bash
echo "$PATH"
type brewctl; command -v brewctl
ls -l /opt/brewbot/bin/
apt-file search bin/dig           # which package provides it? (or: dnf provides '*/dig')
```

**Fix:** use the full path, add the directory to PATH in `~/.bashrc` (or
`/etc/profile.d/` for everyone), or install the package. Under `sudo`, PATH is
reset to `secure_path`, another common surprise. Exit status **127** = not
found; **126** = found but not executable.

## Scenario 5: the cron job didn't run

```bash
grep CRON /var/log/syslog | tail      # did cron even try?   (or: journalctl -u cron)
crontab -l                            # is the line there, for the right user?
systemctl list-timers                 # if it is a systemd timer
```

Cron runs with a minimal environment: use **full paths**, make the script
**executable**, escape `%` (it means newline in crontab), and redirect output to
a log (`>> /var/log/job.log 2>&1`) so failures are visible.

## Try it

`./deploy.sh` says `Permission denied`. `ls -l` shows `-rw-r--r-- labuser
labuser deploy.sh` and you are labuser. What is the cause and the right fix?
What is the wrong fix?

<details>
<summary>Show answer</summary>

There is no execute bit, so the kernel refuses to run it. Right fix:
`chmod u+x deploy.sh`, then `./deploy.sh`. Wrong fixes: `chmod 777` (lets
everyone change your deploy script) or habitually working around it with
`bash deploy.sh` without fixing the file.

</details>

## Common mistakes

- **Restarting a service in a loop without reading its log.**
- **Killing whatever holds a port without checking what it is.** It might be the
  new version you just started.
- **Assuming cron has your PATH.** It does not.
- **`chmod 777` for permission errors.** It creates a security hole and usually
  does not fix the real cause (a parent directory, the wrong user, SELinux).

## Remember

- Permission denied: `ls -l`, `namei -l`, `id`, mount options, MAC.
- Won't start: `status`, `journalctl -u`, validate config, `reset-failed`.
- Port in use: `ss -tulpn | grep :PORT`, `lsof -i :PORT`.
- Not found: PATH, full path, package; 127 vs 126.
- Cron: did it try, full paths, `%`, redirect output.

**Self-check:**

1. Which command shows the permissions of every directory on a path?
2. What do exit codes 126 and 127 mean?
3. Why might a script work by hand but fail in cron?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f3d8d904-d373-57e6-b6fd-c3193f0210dc', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '716c0129-f420-5354-9147-1d8b681dd59a', 'Network Scenarios: Can''t Connect, DNS, SSH Refused, TLS and Clocks', 'notes', 4, $md$## Why this matters

"It works on the server but customers can't reach it", "the API name doesn't
resolve", "SSH says publickey", "TLS certificate is not yet valid". Network
incidents feel mysterious, but each one is solved by checking layers from the
bottom up.

## Mental model: bottom-up, one layer at a time

```
 1. is it running?          systemctl status brewbot
 2. is it listening?        ss -tulpn | grep 8080     (on 127.0.0.1 or 0.0.0.0?)
 3. works locally?          curl -v http://localhost:8080/
 4. reachable from outside? curl from another machine
 5. firewall?               sudo ufw status / cloud security group
```

Stop at the first layer that fails; that is where the problem is.

## Scenario 1: cannot connect to a service

- **Connection refused**: nothing is listening there (service down, wrong port,
  or bound to 127.0.0.1).
- **Connection timed out**: packets are dropped: firewall, security group, or
  routing.
- **502 Bad Gateway** from nginx: nginx is fine, the app behind it is not (down,
  wrong upstream port).
- **504 Gateway Timeout**: the app is too slow to answer.

Time the request to separate "slow" from "down":

```bash
curl -o /dev/null -s -w "%{http_code} %{time_total}\n" http://localhost:8080/
```

An app inside a Docker container behaves the same way: if it binds `127.0.0.1`
*inside* the container, the published port cannot reach it. Bind `0.0.0.0` in
the container, then check `docker ps` for the port mapping.

## Scenario 2: name resolution fails

`curl https://api.payments.example` fails, but `curl https://203.0.113.10` works.

```bash
dig api.payments.example +short
cat /etc/resolv.conf
getent hosts api.payments.example   # includes /etc/hosts
grep payments /etc/hosts            # a stale override?
```

**Fix:** correct the resolver, remove the stale `/etc/hosts` line, or wait out a
DNS change (TTL). "It's always DNS."

## Scenario 3: SSH key refused

`Permission denied (publickey)`:

```bash
ssh -v deploy@atlas                     # client side: which keys were offered?
sudo journalctl -u ssh -n 20            # server side: why it refused (or /var/log/auth.log)
ls -ld ~ ~/.ssh ~/.ssh/authorized_keys  # home not group-writable, .ssh 700, keys 600
```

The usual causes: permissions too open on the server's `~/.ssh` or home
directory, the public key in the wrong user's `authorized_keys`, or
`AllowGroups`/`PermitRootLogin` in sshd_config excluding you.

## Scenario 4: TLS errors and wrong times

`certificate is not yet valid`, failing `apt update`, or confusing log timestamps:
the clock is off.

```bash
timedatectl                        # "System clock synchronized: yes"?
sudo timedatectl set-ntp true      # turn on NTP sync (systemd-timesyncd / chrony)
```

Also check that a certificate really has not expired:

```bash
echo | openssl s_client -connect orbit.coffee:443 -servername orbit.coffee 2>/dev/null \
  | openssl x509 -noout -dates
```

`notAfter` in the past = renew it (and automate renewal, for example certbot's
timer).

## Try it

Customers get `Connection refused` on port 8088. On atlas, `curl
localhost:8088` works and `ss -tln` shows `127.0.0.1:8088`. Which layer failed,
and what is the fix?

<details>
<summary>Show answer</summary>

Layer 2: it listens only on localhost. Change the bind address to `0.0.0.0` (or
the public interface) in the config, **restart** the process (config changes do
nothing until then), and confirm `ss -tln` shows `0.0.0.0:8088`. Then check the
firewall allows 8088.

</details>

## Common mistakes

- **Starting at the firewall.** Check the service and the listener first.
- **Editing the config and not restarting.** The running process still uses the
  old bind address.
- **Blaming DNS when the IP also fails** (or the network when only the name
  fails). Test both.
- **Ignoring the clock.** TLS, Kerberos, TOTP and log correlation all depend on
  it.

## Remember

- Bottom-up: running, listening (where?), local, remote, firewall.
- Refused = no listener; timeout = dropped; 502 = app behind proxy down.
- DNS: `getent hosts`, `/etc/hosts`, `resolv.conf`, `dig`.
- SSH: `ssh -v`, server logs, `~/.ssh` permissions. Clock: `timedatectl`.

**Self-check:**

1. What does a 502 from nginx tell you?
2. Why can `curl localhost` work while customers get refused?
3. Which command shows whether the clock is synced?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0827d60b-62f1-5079-a788-314cbad71256', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '716c0129-f420-5354-9147-1d8b681dd59a', 'Locked Out, Recovery Mode, and the Post-Mortem', 'notes', 5, $md$## Why this matters

Sometimes you break your own access: a bad sudoers file, a firewall rule, an
fstab typo that stops the boot. And when the fire is out, the most valuable
step is the one most teams skip: writing down what happened so it never
happens again.

## Mental model: the spare key and the logbook

- Every server needs a **spare key**: a way in that does not depend on SSH, sudo
  or the network (console, recovery mode).
- Every incident ends with a **logbook entry**: the post-mortem.

## Scenario: locked out of sudo

You broke `/etc/sudoers` or removed yourself from the `sudo` group.

- Never edit sudoers without `visudo`: it refuses to save a broken file. Keep
  rules in small `/etc/sudoers.d/` files, edited with `visudo -f`.
- If it happens anyway: use another admin account, `pkexec visudo` on desktops,
  or boot into **recovery mode** (or the cloud provider's serial console) to fix
  it as root.

## Scenario: the server does not boot

```
 GRUB menu  -> pick an older kernel (Advanced options)
            -> or edit the kernel line (press e) and append:
                 systemd.unit=rescue.target      root shell, basic system
                 systemd.unit=emergency.target   root shell, root mounted read-only
```

From emergency mode, fix the cause (often a bad `/etc/fstab` line):

```bash
mount -o remount,rw /
nano /etc/fstab          # comment out the broken line, or add nofail
mount -a                 # test
systemctl reboot
```

On cloud servers, the **serial console** shows the boot messages and gives you
this shell; for some providers you instead attach the disk to a rescue VM.

## Scenario: locked out by the firewall or SSH config

Use the cloud console or out-of-band access, undo the last change
(`ufw disable`, restore the sshd drop-in), and next time keep a second session
open and test from a new one before closing the old one (chapter 12).

## The post-mortem

When the fire is out, write down:

| Section | Content |
|---|---|
| Summary | one paragraph: what broke, impact, duration |
| Timeline | timestamps: detection, actions, recovery |
| Root cause | the real cause, not the trigger ("no log rotation", not "disk filled") |
| What went well / badly | detection speed, tooling, communication |
| Action items | owner + date: a logrotate rule, an alert, a script, a doc |

**No blame.** Systems fail and people learn. Ask "how did our system allow
this?" rather than "who did it?", or people will hide mistakes next time.

> **Memory hook:** a post-mortem without action items is a story, not a fix.

## Try it

After Black Friday's full-disk outage, which is the better root cause:
"brewbot's debug log filled the disk" or "debug logging was enabled in
production and the brewbot log had no rotation or size alert"? Name two action
items.

<details>
<summary>Show answer</summary>

The second: it names the conditions that allowed the trigger. Action items, each
with an owner and a date: add a logrotate rule (or journald limits) for brewbot;
alert at 80% disk; turn off debug logging in production config; add a CI check
for the log level.

</details>

## Common mistakes

- **No out-of-band access tested before you need it.** Check the cloud console
  works today.
- **Editing sudoers, sshd and firewall in one go.** Change one, test, then the
  next.
- **Post-mortems that blame a person.** You lose the honest timeline.
- **Action items without owners.** They never happen.

## Remember

- Sudoers only via `visudo`; recovery mode, serial console as spare keys.
- Boot problems: older kernel in GRUB, `rescue.target`, `emergency.target`; fix
  fstab with `nofail` and `mount -a`.
- Post-mortem: summary, timeline, root cause, lessons, action items with owners.
- Blameless.

**Self-check:**

1. Why use `visudo` instead of a normal editor?
2. Which kernel argument boots into a minimal root shell?
3. What makes a root cause better than a trigger?
$md$, 6, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('99908f22-2062-52f6-88ad-daa4d7d1135f', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '716c0129-f420-5354-9147-1d8b681dd59a', 'Lab: Black Friday Incident Week', 'notes', 6, $md$## Why this matters

Black Friday is live and six things are broken at once. Everything from the
course gets used: disk, processes, permissions, config, PATH and networking.
Work through them with the method: read the error, check resources, logs,
permissions, changes. Each task is checked automatically.

## Before you start

```bash
cat ~/work/start-incident.sh | head -20
```

What this does: lets you read what the incident script will do. On a real
server you never get this luxury, but reading scripts before running them is a
good habit.

## Task 1: the pager goes off

Run `bash ~/work/start-incident.sh` once to open the incidents.

[[lab-task:1]]

Expected output:

```
PAGER: atlas disk 99% full, brewbot errors, deploy failing. Good luck.
```

## Task 2: scenario 1, the disk is full

Something under `~/work/incident` is eating the disk. Find the largest file and
empty it to 0 bytes **without deleting it** (pretend brewbot still has it
open). Leave the other logs alone.

[[lab-task:2]]

## Task 3: scenario 2, a hung worker

A stuck `brewbot-worker` process is running. Find it and stop it, politely
first.

[[lab-task:3]]

## Task 4: scenario 3, Permission denied

Running `~/work/incident/deploy.sh` fails with `Permission denied`. Fix the
cause (do not work around it with `bash deploy.sh`), then run `./deploy.sh`
successfully.

[[lab-task:4]]

## Task 5: scenario 4, the service will not start

Run `~/work/incident/bin/brewbot-check`, read the error, and fix
`incident/etc/brewbot.conf` so brewbot listens on port 8080 and the check
passes. Keep every other line.

[[lab-task:5]]

## Task 6: scenario 5, command not found

The runbook says `brewctl status`, but bash says `command not found`. The tool is
in `~/work/incident/bin`. Fix your PATH permanently in `~/.bashrc`.

[[lab-task:6]]

What you should see:

```
$ cd /tmp && brewctl status
brewbot: OK
```

## Task 7: scenario 6, the app runs but nobody can reach it

The storefront on port 8088 is unreachable from outside, yet the process runs.
The config is `incident/etc/brewbot-web.conf`, the launcher
`incident/bin/brewbot-web`. Make it listen on every interface and leave a working
listener running.

[[lab-task:7]]

Check yourself:

```
$ ss -tln | grep 8088
LISTEN 0      5            0.0.0.0:8088       0.0.0.0:*
```

## Remember

- Disk: `du -ah | sort -h`, then `truncate -s 0`, not `rm`.
- Processes: `pgrep -af`, TERM before KILL.
- Permission denied: `ls -l`, then `chmod u+x`; never 777.
- Config: read the checker's error, fix one line, validate.
- PATH in `~/.bashrc`; listeners: `ss -tln`, bind `0.0.0.0`, restart.

> **The end of Black Friday.** By 9:40am the disk was clear, the hung worker
> gone, the deploy shipped, brewbot back on port 8080, the storefront reachable
> and the runbook command fixed. Orders hit a record. Rhea lands, reads your
> post-mortem, and pins Tom's notes to the wall, next to your name. You are
> atlas's admin now.
$md$, 40, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('02027500-659a-5c5f-b7dc-746a394f9083', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '99908f22-2062-52f6-88ad-daa4d7d1135f', 'module', 'Lab: Black Friday Incident Week', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/start-incident.sh <<'MFEOF'
#!/bin/bash
# Opens Black Friday's incidents on atlas. Run once: bash ~/work/start-incident.sh
set -euo pipefail
w=/home/labuser/work/incident
mkdir -p $w/var/log/brewbot $w/bin $w/etc $w/app
head -c 31457280 /dev/zero > $w/var/log/brewbot/debug.log
printf '2026-11-27 09:00:01 INFO brewbot started\n2026-11-27 09:00:02 INFO accepting orders\n' > $w/var/log/brewbot/app.log
cat > $w/bin/brewbot-worker <<'EOF'
#!/bin/bash
while true; do sleep 60; done
EOF
cat > $w/deploy.sh <<'EOF'
#!/bin/bash
mkdir -p /home/labuser/work/incident/app
echo deployed > /home/labuser/work/incident/app/deployed.ok
echo "Deploy complete"
EOF
chmod 644 $w/deploy.sh
printf 'name = brewbot\nport = 80800\nworkers = 4\n' > $w/etc/brewbot.conf
cat > $w/bin/brewbot-check <<'EOF'
#!/bin/bash
conf=/home/labuser/work/incident/etc/brewbot.conf
p=$(awk -F' = ' '$1 == "port" {print $2}' $conf)
if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]; then
  echo "config OK"
else
  echo "ERROR: port '$p' out of range (1-65535) in $conf" >&2
  exit 1
fi
EOF
cat > $w/bin/brewctl <<'EOF'
#!/bin/bash
if [ "${1:-}" = status ]; then echo "brewbot: OK"; else echo "usage: brewctl status" >&2; exit 1; fi
EOF
chmod 755 $w/bin/brewbot-check $w/bin/brewctl $w/bin/brewbot-worker
mkdir -p $w/www
echo "brewbot storefront" > $w/www/index.html
printf 'name = brewbot-web\nbind = 127.0.0.1\nport = 8088\n' > $w/etc/brewbot-web.conf
cat > $w/bin/brewbot-web <<'EOF'
#!/bin/bash
w=/home/labuser/work/incident
bind=$(awk -F' = ' '$1 == "bind" {print $2}' $w/etc/brewbot-web.conf)
port=$(awk -F' = ' '$1 == "port" {print $2}' $w/etc/brewbot-web.conf)
cd $w/www && exec python3 -m http.server "$port" --bind "$bind"
EOF
chmod 755 $w/bin/brewbot-web
nohup bash $w/bin/brewbot-worker >/dev/null 2>&1 &
nohup $w/bin/brewbot-web >/dev/null 2>&1 &
touch $w/.incident-started
echo "PAGER: atlas disk 99% full, brewbot errors, deploy failing. Good luck."

MFEOF
chmod 666 /home/labuser/work/start-incident.sh
rm -rf /home/labuser/work/incident
$script$, NULL, 60, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '56fb8e99-6956-5184-941f-adca04839713' AND id NOT IN ('dd08f133-0057-5083-82e1-ce8b14f268ce', '7b440eb1-f1a2-5472-831e-fc75ccd6eaed', '656aa777-0dda-5b18-88b0-61a5c1baeef7', '4c2e41b7-c3d4-51f9-9cc5-82e172de974f', 'e9afd486-df8c-5904-8beb-65ebcd4882be', '7bc01984-42fc-53f5-9b65-6f820f6b467a', '61ca6c31-f89c-5fc0-809a-ebf875c49259');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '56fb8e99-6956-5184-941f-adca04839713';
DELETE FROM lab_tasks WHERE lab_id = '02027500-659a-5c5f-b7dc-746a394f9083' AND id NOT IN ('59d51559-b1c1-50b0-9c88-f107aa9ec3fe', '43921609-0e08-5541-81aa-fe6f0cfb9507', '2ae1e983-c29c-5e51-9c9d-3a645a5705a4', '8c913c34-26c0-534e-bc33-bf2ce52cf97d', '282c2039-0d42-5d80-862a-3699e38f165d', 'c584f42a-3760-5804-8293-80cf4b975feb', 'ba17fa69-87d0-5010-9ad0-b6601043582c');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '02027500-659a-5c5f-b7dc-746a394f9083';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('59d51559-b1c1-50b0-9c88-f107aa9ec3fe', '02027500-659a-5c5f-b7dc-746a394f9083', 1, 'The pager goes off', $md$Black Friday has started. Run bash /home/labuser/work/start-incident.sh once to open the incidents.$md$, $script$[ -f /home/labuser/work/incident/.incident-started ] &&
pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' >/dev/null
$script$, 'Type exactly bash /home/labuser/work/start-incident.sh and press Enter.', 'The script creates a full disk, a hung worker, a broken deploy, a bad config, a missing command and an unreachable web listener under ~/work/incident - one for each scenario that follows.', 10, false, true),
('43921609-0e08-5541-81aa-fe6f0cfb9507', '02027500-659a-5c5f-b7dc-746a394f9083', 2, 'Scenario 1 - the disk is full', $md$Something under /home/labuser/work/incident is eating the disk. Find the largest file and empty it to 0 bytes WITHOUT deleting it (pretend brewbot still has it open). Leave the other logs alone.$md$, $script$l=/home/labuser/work/incident/var/log/brewbot
[ -f $l/debug.log ] && [ ! -s $l/debug.log ] && [ -s $l/app.log ]
$script$, 'du -ah /home/labuser/work/incident | sort -h | tail finds the culprit. truncate -s 0 FILE or : > FILE empties it in place.', 'Deleting a log that a process still holds open frees nothing - the process keeps writing into the invisible inode. Truncating keeps the same inode and releases the space immediately.', 20, false, true),
('2ae1e983-c29c-5e51-9c9d-3a645a5705a4', '02027500-659a-5c5f-b7dc-746a394f9083', 3, 'Scenario 2 - a hung worker', $md$A stuck brewbot-worker process is running. Find it and stop it - politely first.$md$, $script$[ -f /home/labuser/work/incident/.incident-started ] &&
! pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' >/dev/null
$script$, 'ps aux | grep brewbot-worker or pgrep -af brewbot-worker shows the PID. kill PID sends SIGTERM; use kill -9 only if it refuses to die.', 'Find (ps, pgrep), ask politely (SIGTERM 15), confirm it is gone, and only then force (SIGKILL 9). On a real server you would then check why systemd did not restart it, or why it hung.', 20, false, true),
('8c913c34-26c0-534e-bc33-bf2ce52cf97d', '02027500-659a-5c5f-b7dc-746a394f9083', 4, 'Scenario 3 - Permission denied', $md$Running /home/labuser/work/incident/deploy.sh fails with Permission denied. Fix the cause (do not work around it with bash deploy.sh), then run ./deploy.sh successfully.$md$, $script$w=/home/labuser/work/incident
[ -x $w/deploy.sh ] && [ -f $w/app/deployed.ok ]
$script$, 'ls -l deploy.sh - is there an x anywhere in the permissions? chmod u+x adds it.', 'To run a file directly, the kernel needs the execute bit. "Permission denied" always means check ls -l on the file - and on every directory in its path (namei -l shows them all).', 15, false, true),
('282c2039-0d42-5d80-862a-3699e38f165d', '02027500-659a-5c5f-b7dc-746a394f9083', 5, 'Scenario 4 - the service will not start', $md$brewbot refuses to start. Run /home/labuser/work/incident/bin/brewbot-check, read the error, and fix incident/etc/brewbot.conf so brewbot listens on port 8080 and the check passes.$md$, $script$w=/home/labuser/work/incident
$w/bin/brewbot-check >/dev/null 2>&1 && grep -qx 'port = 8080' $w/etc/brewbot.conf && grep -qx 'workers = 4' $w/etc/brewbot.conf
$script$, 'The checker names the bad line. Edit it with nano, or sed -i ''s/^port = .*/port = 8080/'' FILE. Keep every other line.', 'Most "service won''t start" incidents are a bad config change. Read the error, fix one line, validate with the program''s own checker (nginx -t, sshd -t, brewbot-check) before restarting.', 15, false, true),
('c584f42a-3760-5804-8293-80cf4b975feb', '02027500-659a-5c5f-b7dc-746a394f9083', 6, 'Scenario 5 - command not found', $md$The runbook says to type brewctl status, but bash answers command not found. The tool exists in /home/labuser/work/incident/bin. Fix your PATH permanently in ~/.bashrc so brewctl status works from any directory.$md$, $script$[ "$(bash -ic 'cd /tmp && brewctl status' 2>/dev/null)" = "brewbot: OK" ]
$script$, 'Append export PATH="$PATH:/home/labuser/work/incident/bin" to ~/.bashrc, then open a new shell or source it.', 'command not found means no directory in PATH contains that name. Check with echo $PATH and which; the fix is either the full path, a PATH change, or installing the missing package.', 20, false, true),
('ba17fa69-87d0-5010-9ad0-b6601043582c', '02027500-659a-5c5f-b7dc-746a394f9083', 7, 'Scenario 6 - the app runs but nobody can reach it', $md$Customers report the brewbot storefront (port 8088) is unreachable from outside, yet the process is running. Find out why and fix it so the site listens on every interface. The config is incident/etc/brewbot-web.conf and the launcher is incident/bin/brewbot-web. Leave a working listener running.$md$, $script$w=/home/labuser/work/incident
grep -qx 'bind = 0.0.0.0' $w/etc/brewbot-web.conf &&
grep -qx 'port = 8088' $w/etc/brewbot-web.conf &&
ss -tln | awk '{print $4}' | grep -qx '0.0.0.0:8088' &&
[ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8088/)" = 200 ]
$script$, 'ss -tulpn | grep 8088 shows the address it is bound to. 127.0.0.1 means local only. Change bind in the config to 0.0.0.0, stop the old listener (pkill -f "http.server 8088"), then start brewbot-web again in the background with &.', 'A service bound to 127.0.0.1 answers only on the same machine, so curl localhost works while everyone else gets connection refused. Editing the config does nothing until the process restarts. This is the classic "works on the server, unreachable from outside" bug, and the same cause behind a container app that is not reachable through a published port.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('56fb8e99-6956-5184-941f-adca04839713', '02027500-659a-5c5f-b7dc-746a394f9083', 1, $json$[{"id":"59d51559-b1c1-50b0-9c88-f107aa9ec3fe","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":1,"title":"The pager goes off","description":"Black Friday has started. Run bash /home/labuser/work/start-incident.sh once to open the incidents.","verification_script":"[ -f /home/labuser/work/incident/.incident-started ] \u0026\u0026\npgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' \u003e/dev/null\n","hint_context":"Type exactly bash /home/labuser/work/start-incident.sh and press Enter.","explanation_context":"The script creates a full disk, a hung worker, a broken deploy, a bad config, a missing command and an unreachable web listener under ~/work/incident - one for each scenario that follows.","points":10,"is_optional":false,"is_stateful":true},{"id":"43921609-0e08-5541-81aa-fe6f0cfb9507","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":2,"title":"Scenario 1 - the disk is full","description":"Something under /home/labuser/work/incident is eating the disk. Find the largest file and empty it to 0 bytes WITHOUT deleting it (pretend brewbot still has it open). Leave the other logs alone.","verification_script":"l=/home/labuser/work/incident/var/log/brewbot\n[ -f $l/debug.log ] \u0026\u0026 [ ! -s $l/debug.log ] \u0026\u0026 [ -s $l/app.log ]\n","hint_context":"du -ah /home/labuser/work/incident | sort -h | tail finds the culprit. truncate -s 0 FILE or : \u003e FILE empties it in place.","explanation_context":"Deleting a log that a process still holds open frees nothing - the process keeps writing into the invisible inode. Truncating keeps the same inode and releases the space immediately.","points":20,"is_optional":false,"is_stateful":true},{"id":"2ae1e983-c29c-5e51-9c9d-3a645a5705a4","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":3,"title":"Scenario 2 - a hung worker","description":"A stuck brewbot-worker process is running. Find it and stop it - politely first.","verification_script":"[ -f /home/labuser/work/incident/.incident-started ] \u0026\u0026\n! pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' \u003e/dev/null\n","hint_context":"ps aux | grep brewbot-worker or pgrep -af brewbot-worker shows the PID. kill PID sends SIGTERM; use kill -9 only if it refuses to die.","explanation_context":"Find (ps, pgrep), ask politely (SIGTERM 15), confirm it is gone, and only then force (SIGKILL 9). On a real server you would then check why systemd did not restart it, or why it hung.","points":20,"is_optional":false,"is_stateful":true},{"id":"8c913c34-26c0-534e-bc33-bf2ce52cf97d","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":4,"title":"Scenario 3 - Permission denied","description":"Running /home/labuser/work/incident/deploy.sh fails with Permission denied. Fix the cause (do not work around it with bash deploy.sh), then run ./deploy.sh successfully.","verification_script":"w=/home/labuser/work/incident\n[ -x $w/deploy.sh ] \u0026\u0026 [ -f $w/app/deployed.ok ]\n","hint_context":"ls -l deploy.sh - is there an x anywhere in the permissions? chmod u+x adds it.","explanation_context":"To run a file directly, the kernel needs the execute bit. \"Permission denied\" always means check ls -l on the file - and on every directory in its path (namei -l shows them all).","points":15,"is_optional":false,"is_stateful":true},{"id":"282c2039-0d42-5d80-862a-3699e38f165d","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":5,"title":"Scenario 4 - the service will not start","description":"brewbot refuses to start. Run /home/labuser/work/incident/bin/brewbot-check, read the error, and fix incident/etc/brewbot.conf so brewbot listens on port 8080 and the check passes.","verification_script":"w=/home/labuser/work/incident\n$w/bin/brewbot-check \u003e/dev/null 2\u003e\u00261 \u0026\u0026 grep -qx 'port = 8080' $w/etc/brewbot.conf \u0026\u0026 grep -qx 'workers = 4' $w/etc/brewbot.conf\n","hint_context":"The checker names the bad line. Edit it with nano, or sed -i 's/^port = .*/port = 8080/' FILE. Keep every other line.","explanation_context":"Most \"service won't start\" incidents are a bad config change. Read the error, fix one line, validate with the program's own checker (nginx -t, sshd -t, brewbot-check) before restarting.","points":15,"is_optional":false,"is_stateful":true},{"id":"c584f42a-3760-5804-8293-80cf4b975feb","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":6,"title":"Scenario 5 - command not found","description":"The runbook says to type brewctl status, but bash answers command not found. The tool exists in /home/labuser/work/incident/bin. Fix your PATH permanently in ~/.bashrc so brewctl status works from any directory.","verification_script":"[ \"$(bash -ic 'cd /tmp \u0026\u0026 brewctl status' 2\u003e/dev/null)\" = \"brewbot: OK\" ]\n","hint_context":"Append export PATH=\"$PATH:/home/labuser/work/incident/bin\" to ~/.bashrc, then open a new shell or source it.","explanation_context":"command not found means no directory in PATH contains that name. Check with echo $PATH and which; the fix is either the full path, a PATH change, or installing the missing package.","points":20,"is_optional":false,"is_stateful":true},{"id":"ba17fa69-87d0-5010-9ad0-b6601043582c","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":7,"title":"Scenario 6 - the app runs but nobody can reach it","description":"Customers report the brewbot storefront (port 8088) is unreachable from outside, yet the process is running. Find out why and fix it so the site listens on every interface. The config is incident/etc/brewbot-web.conf and the launcher is incident/bin/brewbot-web. Leave a working listener running.","verification_script":"w=/home/labuser/work/incident\ngrep -qx 'bind = 0.0.0.0' $w/etc/brewbot-web.conf \u0026\u0026\ngrep -qx 'port = 8088' $w/etc/brewbot-web.conf \u0026\u0026\nss -tln | awk '{print $4}' | grep -qx '0.0.0.0:8088' \u0026\u0026\n[ \"$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8088/)\" = 200 ]\n","hint_context":"ss -tulpn | grep 8088 shows the address it is bound to. 127.0.0.1 means local only. Change bind in the config to 0.0.0.0, stop the old listener (pkill -f \"http.server 8088\"), then start brewbot-web again in the background with \u0026.","explanation_context":"A service bound to 127.0.0.1 answers only on the same machine, so curl localhost works while everyone else gets connection refused. Editing the config does nothing until the process restarts. This is the classic \"works on the server, unreachable from outside\" bug, and the same cause behind a container app that is not reachable through a published port.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('dd08f133-0057-5083-82e1-ce8b14f268ce', '56fb8e99-6956-5184-941f-adca04839713', '59d51559-b1c1-50b0-9c88-f107aa9ec3fe', 1, 'The pager goes off', $md$Black Friday has started. Run bash /home/labuser/work/start-incident.sh once to open the incidents.$md$, $script$[ -f /home/labuser/work/incident/.incident-started ] &&
pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' >/dev/null
$script$, 'Type exactly bash /home/labuser/work/start-incident.sh and press Enter.', 'The script creates a full disk, a hung worker, a broken deploy, a bad config, a missing command and an unreachable web listener under ~/work/incident - one for each scenario that follows.', 10, false, true),
('7b440eb1-f1a2-5472-831e-fc75ccd6eaed', '56fb8e99-6956-5184-941f-adca04839713', '43921609-0e08-5541-81aa-fe6f0cfb9507', 2, 'Scenario 1 - the disk is full', $md$Something under /home/labuser/work/incident is eating the disk. Find the largest file and empty it to 0 bytes WITHOUT deleting it (pretend brewbot still has it open). Leave the other logs alone.$md$, $script$l=/home/labuser/work/incident/var/log/brewbot
[ -f $l/debug.log ] && [ ! -s $l/debug.log ] && [ -s $l/app.log ]
$script$, 'du -ah /home/labuser/work/incident | sort -h | tail finds the culprit. truncate -s 0 FILE or : > FILE empties it in place.', 'Deleting a log that a process still holds open frees nothing - the process keeps writing into the invisible inode. Truncating keeps the same inode and releases the space immediately.', 20, false, true),
('656aa777-0dda-5b18-88b0-61a5c1baeef7', '56fb8e99-6956-5184-941f-adca04839713', '2ae1e983-c29c-5e51-9c9d-3a645a5705a4', 3, 'Scenario 2 - a hung worker', $md$A stuck brewbot-worker process is running. Find it and stop it - politely first.$md$, $script$[ -f /home/labuser/work/incident/.incident-started ] &&
! pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' >/dev/null
$script$, 'ps aux | grep brewbot-worker or pgrep -af brewbot-worker shows the PID. kill PID sends SIGTERM; use kill -9 only if it refuses to die.', 'Find (ps, pgrep), ask politely (SIGTERM 15), confirm it is gone, and only then force (SIGKILL 9). On a real server you would then check why systemd did not restart it, or why it hung.', 20, false, true),
('4c2e41b7-c3d4-51f9-9cc5-82e172de974f', '56fb8e99-6956-5184-941f-adca04839713', '8c913c34-26c0-534e-bc33-bf2ce52cf97d', 4, 'Scenario 3 - Permission denied', $md$Running /home/labuser/work/incident/deploy.sh fails with Permission denied. Fix the cause (do not work around it with bash deploy.sh), then run ./deploy.sh successfully.$md$, $script$w=/home/labuser/work/incident
[ -x $w/deploy.sh ] && [ -f $w/app/deployed.ok ]
$script$, 'ls -l deploy.sh - is there an x anywhere in the permissions? chmod u+x adds it.', 'To run a file directly, the kernel needs the execute bit. "Permission denied" always means check ls -l on the file - and on every directory in its path (namei -l shows them all).', 15, false, true),
('e9afd486-df8c-5904-8beb-65ebcd4882be', '56fb8e99-6956-5184-941f-adca04839713', '282c2039-0d42-5d80-862a-3699e38f165d', 5, 'Scenario 4 - the service will not start', $md$brewbot refuses to start. Run /home/labuser/work/incident/bin/brewbot-check, read the error, and fix incident/etc/brewbot.conf so brewbot listens on port 8080 and the check passes.$md$, $script$w=/home/labuser/work/incident
$w/bin/brewbot-check >/dev/null 2>&1 && grep -qx 'port = 8080' $w/etc/brewbot.conf && grep -qx 'workers = 4' $w/etc/brewbot.conf
$script$, 'The checker names the bad line. Edit it with nano, or sed -i ''s/^port = .*/port = 8080/'' FILE. Keep every other line.', 'Most "service won''t start" incidents are a bad config change. Read the error, fix one line, validate with the program''s own checker (nginx -t, sshd -t, brewbot-check) before restarting.', 15, false, true),
('7bc01984-42fc-53f5-9b65-6f820f6b467a', '56fb8e99-6956-5184-941f-adca04839713', 'c584f42a-3760-5804-8293-80cf4b975feb', 6, 'Scenario 5 - command not found', $md$The runbook says to type brewctl status, but bash answers command not found. The tool exists in /home/labuser/work/incident/bin. Fix your PATH permanently in ~/.bashrc so brewctl status works from any directory.$md$, $script$[ "$(bash -ic 'cd /tmp && brewctl status' 2>/dev/null)" = "brewbot: OK" ]
$script$, 'Append export PATH="$PATH:/home/labuser/work/incident/bin" to ~/.bashrc, then open a new shell or source it.', 'command not found means no directory in PATH contains that name. Check with echo $PATH and which; the fix is either the full path, a PATH change, or installing the missing package.', 20, false, true),
('61ca6c31-f89c-5fc0-809a-ebf875c49259', '56fb8e99-6956-5184-941f-adca04839713', 'ba17fa69-87d0-5010-9ad0-b6601043582c', 7, 'Scenario 6 - the app runs but nobody can reach it', $md$Customers report the brewbot storefront (port 8088) is unreachable from outside, yet the process is running. Find out why and fix it so the site listens on every interface. The config is incident/etc/brewbot-web.conf and the launcher is incident/bin/brewbot-web. Leave a working listener running.$md$, $script$w=/home/labuser/work/incident
grep -qx 'bind = 0.0.0.0' $w/etc/brewbot-web.conf &&
grep -qx 'port = 8088' $w/etc/brewbot-web.conf &&
ss -tln | awk '{print $4}' | grep -qx '0.0.0.0:8088' &&
[ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8088/)" = 200 ]
$script$, 'ss -tulpn | grep 8088 shows the address it is bound to. 127.0.0.1 means local only. Change bind in the config to 0.0.0.0, stop the old listener (pkill -f "http.server 8088"), then start brewbot-web again in the background with &.', 'A service bound to 127.0.0.1 answers only on the same machine, so curl localhost works while everyone else gets connection refused. Editing the config does nothing until the process restarts. This is the classic "works on the server, unreachable from outside" bug, and the same cause behind a container app that is not reachable through a published port.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '56fb8e99-6956-5184-941f-adca04839713', updated_at = now()
WHERE id = '02027500-659a-5c5f-b7dc-746a394f9083' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('92e328bd-e388-5832-ac26-28744ebfc928', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '716c0129-f420-5354-9147-1d8b681dd59a', 'Reference: Symptom to First Command', 'notes', 7, $md$## How to use this page

Print it, pin it, open it at 3am. Find the symptom, run the first command, then
go to the lesson that covers it. The method above all: **E**rror,
**R**esources, **L**ogs, **P**ermissions, **C**hanges.

## First 60 seconds

```bash
uptime; dmesg -T | tail; df -h; df -i; free -h
top                      # P = CPU, M = memory
systemctl --failed; journalctl -p err -b
ss -tulpn
```

## Symptom table

| Symptom | First command | Then |
|---|---|---|
| No space left | `df -h`, then `du -xh / \| sort -h` | `truncate -s 0` big logs, vacuum journal |
| Full but nothing big | `lsof +L1` | restart the holder or `: > /proc/PID/fd/N` |
| No space, df shows free | `df -i` | delete tiny junk files, fix the app |
| Read-only file system | `dmesg -T \| grep -i error` | disk health, fsck, restore |
| Slow server | `uptime`, `vmstat 1` | `top` (CPU), `free` (memory), `iostat -x` (disk) |
| High load, idle CPU | `ps -eo state,pid,cmd \| grep '^D'` | `iostat -x 1`, `iotop`, `ionice -c3` |
| Process vanished, exit 137 | `dmesg -T \| grep -i 'killed process'` | find the leak, `MemoryMax=` |
| Worker hung | `pgrep -af NAME`, `cat /proc/PID/wchan` | `strace -p PID`, TERM then KILL |
| Permission denied | `ls -l FILE`, `namei -l PATH`, `id` | `chmod`/`chown`/group, MAC denials |
| Service down | `systemctl status X`, `journalctl -u X -n 50` | validate config, `reset-failed`, start |
| Address already in use | `ss -tulpn \| grep :PORT` | stop the stray process or change port |
| command not found | `echo $PATH`, `command -v X` | full path, PATH in `~/.bashrc`, install |
| Cron job didn't run | `grep CRON /var/log/syslog` | full paths, `%`, redirect output |
| Connection refused | `ss -tulpn` on the server | start it / bind `0.0.0.0` / right port |
| Connection timed out | firewall: `ufw status`, security group | `tcpdump -ni any port N` |
| 502 from nginx | `journalctl -u APP`, `curl localhost:APPPORT` | app down or wrong upstream |
| Name doesn't resolve | `getent hosts NAME`, `dig NAME` | `/etc/hosts`, `/etc/resolv.conf` |
| SSH publickey refused | `ssh -v`, server `journalctl -u ssh` | `~/.ssh` 700, keys 600, right user |
| TLS not yet valid / expired | `timedatectl`, `openssl s_client ... \| openssl x509 -noout -dates` | NTP on, renew certificate |
| Locked out of sudo | another admin, console | recovery mode, `visudo` |
| Server won't boot | serial console | older kernel, `emergency.target`, fix fstab |

## Exit codes

`0` ok · `1` error · `2` usage · `126` not executable · `127` not found ·
`130` Ctrl+C · `137` SIGKILL (often OOM) · `143` SIGTERM.

## After the incident

Timeline, root cause (not the trigger), what went well/badly, action items with
owners. Blameless.
$md$, 5, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cf235b21-f7ea-517f-ac5a-0e457c939c2a', '00000000-0000-0000-0000-000000000001', 'mcq', 'You deleted a 20 GB log with rm, but df still shows the disk full. What is th...', 'advanced', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e8dcc723-8b41-5138-bc49-421462962f43', 'cf235b21-f7ea-517f-ac5a-0e457c939c2a', 1, $json${"prompt":"You deleted a 20 GB log with rm, but df still shows the disk full. What is the most likely reason?","multiple":false,"options":[{"id":"a","text":"A running process still has the deleted file open, so its space is not released","is_correct":true},{"id":"b","text":"rm only moves files to a hidden trash folder","is_correct":false},{"id":"c","text":"df caches results for 24 hours","is_correct":false},{"id":"d","text":"The filesystem needs to be reformatted","is_correct":false}],"explanation":"The inode lives until the last open handle closes. lsof +L1 finds it; restart the process or truncate via /proc/PID/fd. Linux has no trash for rm, df reads live values, and reformatting is never needed for this."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ac025799-c81b-5f69-85ae-9e6162fe7635', '00000000-0000-0000-0000-000000000001', 'mcq', 'The 1-minute load is 9 on a 4-CPU server and climbing, top shows us 90 and wa...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('513f996f-d2d4-5d04-b54d-496d5ce62d5c', 'ac025799-c81b-5f69-85ae-9e6162fe7635', 1, $json${"prompt":"The 1-minute load is 9 on a 4-CPU server and climbing, top shows us 90 and wa 0. Which process do you look for first?","multiple":false,"options":[{"id":"a","text":"The top CPU users (top then P, or ps aux --sort=-%cpu)","is_correct":true},{"id":"b","text":"Processes in D state","is_correct":false},{"id":"c","text":"The biggest RSS","is_correct":false},{"id":"d","text":"Zombies","is_correct":false}],"explanation":"High user CPU with no IO wait is CPU demand; find who uses it. D state is for disk waits (wa would be high), RSS is memory, and zombies use no CPU."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f17b03d1-a423-5152-bc2b-ae1ff8af3712', '00000000-0000-0000-0000-000000000001', 'mcq', 'brewbot fails to start with ''bind: Address already in use'' on port 8080. What...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ae3ed155-5c14-5ad2-be68-b1036290b754', 'f17b03d1-a423-5152-bc2b-ae1ff8af3712', 1, $json${"prompt":"brewbot fails to start with 'bind: Address already in use' on port 8080. What is the first command?","multiple":false,"options":[{"id":"a","text":"sudo ss -tulpn | grep :8080","is_correct":true},{"id":"b","text":"sudo systemctl daemon-reload","is_correct":false},{"id":"c","text":"sudo ufw allow 8080","is_correct":false},{"id":"d","text":"chmod 777 /opt/brewbot","is_correct":false}],"explanation":"Find out who already holds the port (often an old copy of brewbot). daemon-reload re-reads units, the firewall is not involved in binding, and permissions do not cause this error."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e612bffc-507f-57f5-857d-77450f848851', '00000000-0000-0000-0000-000000000001', 'mcq', 'Customers get 502 Bad Gateway from nginx. What does that tell you?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4f7ea6c7-deed-5779-bdc4-90a7260ffec4', 'e612bffc-507f-57f5-857d-77450f848851', 1, $json${"prompt":"Customers get 502 Bad Gateway from nginx. What does that tell you?","multiple":false,"options":[{"id":"a","text":"nginx is running, but the application behind it is down or unreachable on its upstream address","is_correct":true},{"id":"b","text":"nginx itself is down","is_correct":false},{"id":"c","text":"DNS for the site is broken","is_correct":false},{"id":"d","text":"The customers' browsers are broken","is_correct":false}],"explanation":"nginx answered with an error, so it is up; it failed talking to the upstream. If nginx were down there would be no HTTP response, and DNS failures stop before any connection."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('dd5d161a-a700-59d4-918c-3cb7cdea4cbc', '00000000-0000-0000-0000-000000000001', 'mcq', 'After an fstab edit, the server boots into emergency mode. What is the right ...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('38684b75-18f8-55dc-9af1-1fe314f50c08', 'dd5d161a-a700-59d4-918c-3cb7cdea4cbc', 1, $json${"prompt":"After an fstab edit, the server boots into emergency mode. What is the right recovery path?","multiple":false,"options":[{"id":"a","text":"From the console: mount -o remount,rw /, fix or comment the bad fstab line (or add nofail), mount -a, reboot","is_correct":true},{"id":"b","text":"Reinstall the OS","is_correct":false},{"id":"c","text":"Press Ctrl+C until it boots","is_correct":false},{"id":"d","text":"Delete /etc/fstab completely","is_correct":false}],"explanation":"Emergency mode gives a root shell with / read-only; remount, fix the line and test with mount -a. Reinstalling is overkill, Ctrl+C does nothing useful, and deleting fstab breaks all other mounts."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8d52cffa-5334-5c1e-ac1b-f0b33897e253', '00000000-0000-0000-0000-000000000001', 'mcq', 'Brewbot will not start right after a teammate edited its config. Following th...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('de1fce33-7732-5560-a1a3-87bbdbf3909e', '8d52cffa-5334-5c1e-ac1b-f0b33897e253', 1, $json${"prompt":"Brewbot will not start right after a teammate edited its config. Following the incident method, what do you do first?","multiple":false,"options":[{"id":"a","text":"Read the error with systemctl status and journalctl -u brewbot, then validate the changed config","is_correct":true},{"id":"b","text":"Reboot the server and hope it comes back","is_correct":false},{"id":"c","text":"chmod -R 777 /etc/brewbot so permissions cannot be the problem","is_correct":false},{"id":"d","text":"Reinstall the operating system","is_correct":false}],"explanation":"Every Real Linux Pro Checks: Error, Resources, Logs, Permissions, Changes. A recent config change plus a startup failure points straight at the config: read the logs, fix one thing, validate, restart."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('11c20753-13b8-5c62-8f39-40c144c56ee6', '00000000-0000-0000-0000-000000000001', 'mcq', 'apt update fails with ''Release file is not valid yet'' and TLS errors appear e...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('cbc8af60-cb2d-5942-9d9f-59f17e690196', '11c20753-13b8-5c62-8f39-40c144c56ee6', 1, $json${"prompt":"apt update fails with 'Release file is not valid yet' and TLS errors appear everywhere. What do you check?","multiple":false,"options":[{"id":"a","text":"The system clock: timedatectl, and enable NTP","is_correct":true},{"id":"b","text":"The disk space","is_correct":false},{"id":"c","text":"The sudoers file","is_correct":false},{"id":"d","text":"The swap size","is_correct":false}],"explanation":"'Not valid yet' means the machine thinks it is earlier than the certificate's start date. Disk, sudo and swap do not affect certificate validity."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('4f2dd388-92f5-531f-b28d-af92a1ecfb15', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which root cause statement leads to the most useful post-mortem action items?', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('da44e9c7-452e-56df-8bfe-27455bd41b39', '4f2dd388-92f5-531f-b28d-af92a1ecfb15', 1, $json${"prompt":"Which root cause statement leads to the most useful post-mortem action items?","multiple":false,"options":[{"id":"a","text":"Debug logging was enabled in production and the log had no rotation or disk alert","is_correct":true},{"id":"b","text":"The disk filled up","is_correct":false},{"id":"c","text":"Sam made a mistake","is_correct":false},{"id":"d","text":"Bad luck on a busy day","is_correct":false}],"explanation":"Naming the conditions that allowed the failure points to fixes (logrotate, alerts, config checks). 'Disk filled' is the trigger, blaming a person hides the system problem, and luck is not actionable."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('bbe46169-3410-5ad0-a305-952129a9b8c0', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (chapter 12): during the incident you are tempted to chmod 777 a direc...', 'intermediate', 2, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ea105501-3fa0-5daf-9e70-21b4aa0d2604', 'bbe46169-3410-5ad0-a305-952129a9b8c0', 1, $json${"prompt":"Review (chapter 12): during the incident you are tempted to chmod 777 a directory to make a 'Permission denied' go away. Why not?","multiple":false,"options":[{"id":"a","text":"It lets every user and every compromised service modify the files; find the real cause (owner, group, parent directory, MAC) instead","is_correct":true},{"id":"b","text":"chmod 777 is not a valid mode","is_correct":false},{"id":"c","text":"It requires a reboot to take effect","is_correct":false},{"id":"d","text":"It would make the files read-only","is_correct":false}],"explanation":"777 is valid and takes effect at once, which is exactly why it is dangerous: it removes all write protection. The real fix is the specific missing permission."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('c26f3363-7321-59bd-833c-4939af04c321', '00000000-0000-0000-0000-000000000001', 'Quiz: Troubleshooting Scenarios', 'linux-incident-week-quiz', 'Quiz covering Chapter 13: Incident Week - Troubleshooting Playbook.', 'mcq', 'published', 'module', '10e4a330-31e0-5017-b0f7-bc227acf23e9', 12, 70, 5, 18, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'c26f3363-7321-59bd-833c-4939af04c321' AND question_id NOT IN ('cf235b21-f7ea-517f-ac5a-0e457c939c2a', 'ac025799-c81b-5f69-85ae-9e6162fe7635', 'f17b03d1-a423-5152-bc2b-ae1ff8af3712', 'e612bffc-507f-57f5-857d-77450f848851', 'dd5d161a-a700-59d4-918c-3cb7cdea4cbc', '8d52cffa-5334-5c1e-ac1b-f0b33897e253', '11c20753-13b8-5c62-8f39-40c144c56ee6', '4f2dd388-92f5-531f-b28d-af92a1ecfb15', 'bbe46169-3410-5ad0-a305-952129a9b8c0');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('135efda7-69ea-59ef-b375-0389090d61a5', 'c26f3363-7321-59bd-833c-4939af04c321', 'cf235b21-f7ea-517f-ac5a-0e457c939c2a', 'e8dcc723-8b41-5138-bc49-421462962f43', 0, 2),
('6fa2c17a-5665-561a-ab18-0c592bb13d6a', 'c26f3363-7321-59bd-833c-4939af04c321', 'ac025799-c81b-5f69-85ae-9e6162fe7635', '513f996f-d2d4-5d04-b54d-496d5ce62d5c', 1, 2),
('0a01c098-dd7f-5517-89b2-6799add17ee3', 'c26f3363-7321-59bd-833c-4939af04c321', 'f17b03d1-a423-5152-bc2b-ae1ff8af3712', 'ae3ed155-5c14-5ad2-be68-b1036290b754', 2, 2),
('c8f205ec-c46e-525d-aa21-9eccb554a631', 'c26f3363-7321-59bd-833c-4939af04c321', 'e612bffc-507f-57f5-857d-77450f848851', '4f7ea6c7-deed-5779-bdc4-90a7260ffec4', 3, 2),
('d2d95d52-5a9a-591b-b254-55d3382c9315', 'c26f3363-7321-59bd-833c-4939af04c321', 'dd5d161a-a700-59d4-918c-3cb7cdea4cbc', '38684b75-18f8-55dc-9af1-1fe314f50c08', 4, 2),
('7523e8af-1447-5757-a8b2-a6299558c20e', 'c26f3363-7321-59bd-833c-4939af04c321', '8d52cffa-5334-5c1e-ac1b-f0b33897e253', 'de1fce33-7732-5560-a1a3-87bbdbf3909e', 5, 2),
('b760dbea-b3aa-5f7f-b691-cfb5ebbe454a', 'c26f3363-7321-59bd-833c-4939af04c321', '11c20753-13b8-5c62-8f39-40c144c56ee6', 'cbc8af60-cb2d-5942-9d9f-59f17e690196', 6, 2),
('2bfc4162-69e1-5bfb-b306-3ef398e85eb8', 'c26f3363-7321-59bd-833c-4939af04c321', '4f2dd388-92f5-531f-b28d-af92a1ecfb15', 'da44e9c7-452e-56df-8bfe-27455bd41b39', 7, 2),
('15944b50-e2c2-5e07-a37f-098a146c2142', 'c26f3363-7321-59bd-833c-4939af04c321', 'bbe46169-3410-5ad0-a305-952129a9b8c0', 'ea105501-3fa0-5daf-9e70-21b4aa0d2604', 8, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('10e4a330-31e0-5017-b0f7-bc227acf23e9', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '716c0129-f420-5354-9147-1d8b681dd59a', 'Quiz: Troubleshooting Scenarios', 'assessment', 8, 10, 'c26f3363-7321-59bd-833c-4939af04c321')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Final Exam: Atlas Certified
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('8b26cec3-ded3-5a1a-92dd-bb42562680dc', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Final Exam: Atlas Certified', 14, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f9aca5c5-1fc3-504c-98bd-addeb9db74ea', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '8b26cec3-ded3-5a1a-92dd-bb42562680dc', 'Course Review: Flashcards for Spaced Recall', 'notes', 0, $md$## How to use this page

Cover the right column and answer each prompt out loud, then check. Mark the ones
you missed and come back to them tomorrow, in three days and in a week. Spaced,
effortful recall beats re-reading. Then take the final exam.

## Shell and filesystem (chapters 1-2)

| Prompt | Answer |
|---|---|
| Kernel vs distro vs shell | core program / kernel + tools + package manager / command interpreter (bash) |
| Config, logs, user files live in... | `/etc`, `/var/log`, `/home` |
| Absolute vs relative path | starts at `/` / starts where you are |
| Make PATH change permanent | `export PATH="$HOME/bin:$PATH"` in `~/.bashrc` |
| `>` vs `>>` | overwrite / append |
| Copy a directory | `cp -r` (or `cp -a` to keep attributes) |
| find, safely | `find DIR -name '*.bak'` first, then add `-delete` |
| Hard link vs symlink | second name for the same inode / small file holding a path |

## Text tools (chapter 3)

| Prompt | Answer |
|---|---|
| Count matching lines | `grep -c PATTERN file` |
| stderr to a file | `2> file`; both: `> file 2>&1` |
| Top-N pipeline | `... \| sort \| uniq -c \| sort -rn \| head` |
| Filter column 9, print column 7 | `awk '$9 == 500 {print $7}'` |
| Replace safely into a new file | `sed 's/a/b/g' in > out` |

## Users and permissions (chapter 4)

| Prompt | Answer |
|---|---|
| r, w, x values | 4, 2, 1 |
| 640 means | owner rw, group r, others nothing |
| Which class applies? | owner, else group, else others (only one) |
| Delete a file needs | `w` on the directory |
| Add user to a group | `usermod -aG group user` (always `-a`) |
| SUID / SGID dir / sticky | run as owner / inherit group / only owner deletes |
| umask 027 gives | files 640, directories 750 |
| Edit sudoers | `visudo` only |
| Extra named permissions | ACLs: `setfacl -m u:sam:r f`, `getfacl` |

## Processes and systemd (chapters 5-6)

| Prompt | Answer |
|---|---|
| Polite vs forced kill | SIGTERM 15 / SIGKILL 9 |
| Exit 137 | 128 + 9: killed by SIGKILL (often OOM) |
| Survive logout | `nohup CMD &` or tmux |
| start vs enable | now / at every boot (`enable --now` both) |
| After editing a unit | `systemctl daemon-reload` |
| Override a vendor unit | `systemctl edit NAME` (drop-in) |
| One unit's logs, previous boot | `journalctl -u NAME -b -1` |
| Cron fields | minute hour day-of-month month day-of-week |
| Timer catches up missed runs | `Persistent=true` |

## Storage and network (chapters 7-8)

| Prompt | Answer |
|---|---|
| Which package owns a file? | `dpkg -S FILE` (`rpm -qf FILE`) |
| Space vs inodes | `df -h` / `df -i` |
| fstab: identify disks by | UUID; test with `mount -a` |
| Grow an LVM volume online | `lvextend -r -L +20G /dev/VG/LV` |
| List a tarball | `tar -tzf file.tar.gz` |
| Who listens on which port? | `ss -tulpn` |
| Refused vs timed out | nothing listening / dropped by firewall |
| What programs resolve | `getent hosts NAME` (includes `/etc/hosts`) |
| SSH permissions | `~/.ssh` 700, keys and config 600 |

## Scripting (chapter 9)

| Prompt | Answer |
|---|---|
| Script safety line | `set -euo pipefail` |
| Always quote | `"$var"`, `"$@"` |
| Success exit status | 0 |
| Read a file line by line | `while read -r a b; do ...; done < file` |
| Cleanup on any exit | `trap 'rm -rf "$tmp"' EXIT` |

## Under the hood, performance, security (chapters 10-12)

| Prompt | Answer |
|---|---|
| Namespaces vs cgroups | what a process can see / how much it can use |
| Cap a service's memory | `MemoryMax=` in the unit |
| Watch a program's system calls | `strace -f -e trace=file CMD` |
| USE method | Utilization, Saturation, Errors per resource |
| High load, idle CPU, high wa | disk bottleneck (processes in `D`) |
| Memory number that matters | `available` in `free -h` |
| SSH hardening basics | keys only, `PermitRootLogin no`, `sshd -t`, test in a new session |
| Find SUID files | `find / -xdev -perm -4000 -type f` |
| MAC on Ubuntu / RHEL | AppArmor / SELinux |

## Troubleshooting (chapter 13)

| Prompt | Answer |
|---|---|
| The method | Error, Resources, Logs, Permissions, Changes |
| df full but du is not | `lsof +L1` (deleted but open) |
| Empty an open log | `truncate -s 0 FILE` |
| 502 from nginx | the app behind it is down |
| Post-mortem must have | root cause + action items with owners, blameless |
$md$, 12, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('631e7621-1f2d-5c5b-b31b-98d95922c155', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the coffee shop picture of Linux, which part is the kitchen that manages C...', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('459aedd2-1910-5155-bb1f-0abd5c8834ba', '631e7621-1f2d-5c5b-b31b-98d95922c155', 1, $json${"prompt":"In the coffee shop picture of Linux, which part is the kitchen that manages CPU, memory, disks and processes?","multiple":false,"options":[{"id":"a","text":"The kernel","is_correct":true},{"id":"b","text":"The shell (bash)","is_correct":false},{"id":"c","text":"The terminal","is_correct":false},{"id":"d","text":"The distribution","is_correct":false}],"explanation":"The kernel is the core that shares hardware between programs. The shell is the barista that takes your commands and asks the kernel to run them."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cbca87c0-7c74-5564-85b0-d371ee7545d8', '00000000-0000-0000-0000-000000000001', 'mcq', 'Brewbot''s configuration file and its log files most likely live in which two ...', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('df795f74-ef30-58a1-9d6c-6cdd687b95b8', 'cbca87c0-7c74-5564-85b0-d371ee7545d8', 1, $json${"prompt":"Brewbot's configuration file and its log files most likely live in which two directories?","multiple":false,"options":[{"id":"a","text":"/etc for the config, /var/log for the logs","is_correct":true},{"id":"b","text":"/usr for the config, /tmp for the logs","is_correct":false},{"id":"c","text":"/home for the config, /proc for the logs","is_correct":false},{"id":"d","text":"/bin for the config, /dev for the logs","is_correct":false}],"explanation":"/etc holds editable text configuration and /var holds data that varies, including logs under /var/log."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b3136879-d0a0-5050-acdf-624e579250ae', '00000000-0000-0000-0000-000000000001', 'mcq', 'You put an executable script called deploy in ~/bin, but typing deploy says c...', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9fe9dd4c-15d8-533a-b4de-fd718c1682d3', 'b3136879-d0a0-5050-acdf-624e579250ae', 1, $json${"prompt":"You put an executable script called deploy in ~/bin, but typing deploy says command not found. What is the most likely cause?","multiple":false,"options":[{"id":"a","text":"~/bin is not listed in the PATH variable","is_correct":true},{"id":"b","text":"Scripts can only run from /usr/bin","is_correct":false},{"id":"c","text":"The file name needs a .sh extension","is_correct":false},{"id":"d","text":"The kernel needs a reboot to see new commands","is_correct":false}],"explanation":"The shell only searches directories listed in PATH. Add export PATH=\"$HOME/bin:$PATH\" to ~/.bashrc."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('822b1374-8977-586e-8902-ae16c680cf65', '00000000-0000-0000-0000-000000000001', 'mcq', 'You create a symlink and a hard link to menu.txt, then delete menu.txt. What ...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c6a7ee6c-307b-5e0f-a97e-734eb225d55a', '822b1374-8977-586e-8902-ae16c680cf65', 1, $json${"prompt":"You create a symlink and a hard link to menu.txt, then delete menu.txt. What happens?","multiple":false,"options":[{"id":"a","text":"The hard link still shows the content; the symlink is now broken","is_correct":true},{"id":"b","text":"Both links still show the content","is_correct":false},{"id":"c","text":"Both links are broken","is_correct":false},{"id":"d","text":"The symlink still works; the hard link is broken","is_correct":false}],"explanation":"A hard link is another name for the same inode, so the data survives. A symlink only stores the path, which no longer exists."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7eb1b543-6d29-5109-b181-c2854b6ed8d1', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the safe habit before running find /srv -name ''*.tmp'' -delete?', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0f53e9b9-614d-586f-95fb-5d42f3c2b52b', '7eb1b543-6d29-5109-b181-c2854b6ed8d1', 1, $json${"prompt":"What is the safe habit before running find /srv -name '*.tmp' -delete?","multiple":false,"options":[{"id":"a","text":"Run the same find without -delete first and check the list","is_correct":true},{"id":"b","text":"Run it twice to make sure it worked","is_correct":false},{"id":"c","text":"Add sudo so it cannot fail","is_correct":false},{"id":"d","text":"Nothing - deleted files go to the trash and can be restored","is_correct":false}],"explanation":"Linux has no recycle bin. Always preview what find matches before adding -delete."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c3226f2b-9da0-5196-bb2c-c4286daf17be', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why does the top-IP pipeline need sort before uniq -c?', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5fb598ed-0cd9-5d4e-9289-0958df0d1e21', 'c3226f2b-9da0-5196-bb2c-c4286daf17be', 1, $json${"prompt":"Why does the top-IP pipeline need sort before uniq -c?","multiple":false,"options":[{"id":"a","text":"uniq only merges duplicate lines that are next to each other","is_correct":true},{"id":"b","text":"uniq cannot read from a pipe","is_correct":false},{"id":"c","text":"sort removes the timestamps from each line","is_correct":false},{"id":"d","text":"uniq -c only works on numbers","is_correct":false}],"explanation":"uniq compares each line only with the line before it, so equal lines must first be grouped together by sort."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d5c8c230-1e0b-542b-8a98-772cfb3e07f1', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command sends both normal output and errors of backup.sh to backup.log,...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ab234ad2-1b2c-517a-aa2f-1feb2bbf54ba', 'd5c8c230-1e0b-542b-8a98-772cfb3e07f1', 1, $json${"prompt":"Which command sends both normal output and errors of backup.sh to backup.log, appending to the file?","multiple":false,"options":[{"id":"a","text":"./backup.sh \u003e\u003e backup.log 2\u003e\u00261","is_correct":true},{"id":"b","text":"./backup.sh 2\u003e\u00261 \u003e backup.log","is_correct":false},{"id":"c","text":"./backup.sh | backup.log","is_correct":false},{"id":"d","text":"./backup.sh \u003e backup.log 2\u003e/dev/null","is_correct":false}],"explanation":"\u003e\u003e appends stdout to the file, then 2\u003e\u00261 points stderr at the same place. Order matters - redirections are processed left to right."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0aa4e899-21cc-55e5-a071-ba279d0dd815', '00000000-0000-0000-0000-000000000001', 'mcq', 'deploy.sh should be readable, writable and executable by its owner, readable ...', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('69a9b803-4fdf-5dac-81c3-08e626bfb6d7', '0aa4e899-21cc-55e5-a071-ba279d0dd815', 1, $json${"prompt":"deploy.sh should be readable, writable and executable by its owner, readable by the group, and nothing for others. Which command is correct?","multiple":false,"options":[{"id":"a","text":"chmod 740 deploy.sh","is_correct":true},{"id":"b","text":"chmod 750 deploy.sh","is_correct":false},{"id":"c","text":"chmod 704 deploy.sh","is_correct":false},{"id":"d","text":"chmod 777 deploy.sh","is_correct":false}],"explanation":"r=4 w=2 x=1. Owner rwx = 7, group r-- = 4, others --- = 0."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e77dc2e0-717f-5379-ad81-64e15eb75919', '00000000-0000-0000-0000-000000000001', 'mcq', 'You run sudo usermod -G docker sam and suddenly sam can no longer use sudo. Why?', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0186e08e-7ef3-5a64-b7c2-b05ef2b22f1a', 'e77dc2e0-717f-5379-ad81-64e15eb75919', 1, $json${"prompt":"You run sudo usermod -G docker sam and suddenly sam can no longer use sudo. Why?","multiple":false,"options":[{"id":"a","text":"Without -a, -G replaces all of sam's supplementary groups, removing sam from the sudo group","is_correct":true},{"id":"b","text":"The docker group blocks sudo","is_correct":false},{"id":"c","text":"usermod always resets the password","is_correct":false},{"id":"d","text":"Sam needs to reboot the server","is_correct":false}],"explanation":"Always use usermod -aG (append). -G alone sets the group list to exactly what you give."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1ffbf11f-71f8-5be6-b594-5cf47ceb3a07', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why can''t users delete each other''s files in /tmp, even though /tmp is writab...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d9018b26-dda6-541b-99f6-823633accfd4', '1ffbf11f-71f8-5be6-b594-5cf47ceb3a07', 1, $json${"prompt":"Why can't users delete each other's files in /tmp, even though /tmp is writable by everyone?","multiple":false,"options":[{"id":"a","text":"/tmp has the sticky bit, so only a file's owner (or root) can delete it","is_correct":true},{"id":"b","text":"/tmp is mounted read-only","is_correct":false},{"id":"c","text":"Every file in /tmp is SUID root","is_correct":false},{"id":"d","text":"The umask prevents deletion","is_correct":false}],"explanation":"drwxrwxrwt - the t is the sticky bit. On a directory it limits deleting and renaming to the file's owner."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1c221771-6eea-5155-a761-10ed3bbcfec9', '00000000-0000-0000-0000-000000000001', 'mcq', 'A worker process is stuck. What is the right order of signals to send?', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a28ad616-fc67-563f-ad67-6d852c4084f4', '1c221771-6eea-5155-a761-10ed3bbcfec9', 1, $json${"prompt":"A worker process is stuck. What is the right order of signals to send?","multiple":false,"options":[{"id":"a","text":"SIGTERM (15) first, and SIGKILL (9) only if it refuses to exit","is_correct":true},{"id":"b","text":"SIGKILL (9) first, it is faster","is_correct":false},{"id":"c","text":"SIGHUP (1) only, it always stops processes","is_correct":false},{"id":"d","text":"SIGSTOP (19), then wait for it to exit by itself","is_correct":false}],"explanation":"15 asks, 9 insists. SIGTERM lets the program clean up; SIGKILL cannot be caught and can leave half-written files."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c0651b5a-bde0-576f-a4e3-3b4a64709bf9', '00000000-0000-0000-0000-000000000001', 'mcq', 'uptime shows a load average of 12 on a 4-CPU server, but top shows the CPUs m...', 'advanced', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('374ff15c-0ad0-562e-9147-d2fde9758c2e', 'c0651b5a-bde0-576f-a4e3-3b4a64709bf9', 1, $json${"prompt":"uptime shows a load average of 12 on a 4-CPU server, but top shows the CPUs mostly idle with a high wa value. What is going on?","multiple":false,"options":[{"id":"a","text":"Processes are blocked waiting on disk IO, which counts toward load","is_correct":true},{"id":"b","text":"The load average is broken and should be ignored","is_correct":false},{"id":"c","text":"The server has too much free memory","is_correct":false},{"id":"d","text":"Twelve users are logged in","is_correct":false}],"explanation":"Linux load counts processes running or waiting, including uninterruptible (D state) disk waits. High wa means the disk, not the CPU, is the bottleneck."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f75565b6-a546-59a4-8df9-f6e57f693341', '00000000-0000-0000-0000-000000000001', 'mcq', 'You ran sudo systemctl start brewbot and it works, but after a reboot brewbot...', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2bac7394-b3ad-5e1c-b1ff-94a5ab2dff96', 'f75565b6-a546-59a4-8df9-f6e57f693341', 1, $json${"prompt":"You ran sudo systemctl start brewbot and it works, but after a reboot brewbot is not running. What did you forget?","multiple":false,"options":[{"id":"a","text":"sudo systemctl enable brewbot","is_correct":true},{"id":"b","text":"sudo systemctl reload brewbot","is_correct":false},{"id":"c","text":"sudo systemctl daemon-reload","is_correct":false},{"id":"d","text":"sudo systemctl status brewbot","is_correct":false}],"explanation":"start runs it now; enable hooks it into the boot target so it starts every time. enable --now does both."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a344c221-b459-59b5-a35a-42ab657b6baa', '00000000-0000-0000-0000-000000000001', 'mcq', 'Brewbot shows as failed. Which command shows what brewbot itself logged?', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b34b63c0-0b30-50ed-9cc8-1e6f8f294ba0', 'a344c221-b459-59b5-a35a-42ab657b6baa', 1, $json${"prompt":"Brewbot shows as failed. Which command shows what brewbot itself logged?","multiple":false,"options":[{"id":"a","text":"journalctl -u brewbot","is_correct":true},{"id":"b","text":"dmesg -u brewbot","is_correct":false},{"id":"c","text":"cat /proc/brewbot/log","is_correct":false},{"id":"d","text":"systemctl enable brewbot","is_correct":false}],"explanation":"journalctl -u UNIT filters the journal to one unit. Pair it with systemctl status for the current state."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('68d1413f-05cd-5cf0-926f-814a2a019766', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does the crontab line 0 3 * * 0 /opt/brewbot/backup.sh do?', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d8493143-7c82-5e4a-81e2-b0658fac67fc', '68d1413f-05cd-5cf0-926f-814a2a019766', 1, $json${"prompt":"What does the crontab line 0 3 * * 0 /opt/brewbot/backup.sh do?","multiple":false,"options":[{"id":"a","text":"Runs the backup at 03:00 every Sunday","is_correct":true},{"id":"b","text":"Runs the backup every 3 minutes","is_correct":false},{"id":"c","text":"Runs the backup at midnight on the 3rd of every month","is_correct":false},{"id":"d","text":"Runs the backup at 03:00 every day","is_correct":false}],"explanation":"Fields are minute, hour, day of month, month, day of week: minute 0, hour 3, any day, any month, weekday 0 = Sunday."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('28daf639-9558-5108-a769-1ae1caf9a159', '00000000-0000-0000-0000-000000000001', 'mcq', 'df -h says / is only 40% used, yet creating new files fails, and df -i shows ...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e778851b-9f7d-5b1a-b0d0-cff268894a95', '28daf639-9558-5108-a769-1ae1caf9a159', 1, $json${"prompt":"df -h says / is only 40% used, yet creating new files fails, and df -i shows 100%. What has run out?","multiple":false,"options":[{"id":"a","text":"Inodes - too many small files","is_correct":true},{"id":"b","text":"Swap space","is_correct":false},{"id":"c","text":"RAM","is_correct":false},{"id":"d","text":"File descriptors","is_correct":false}],"explanation":"Every file needs an inode. Millions of tiny files can exhaust inodes long before the blocks run out; df -i shows it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1c725e5b-4f0b-5b16-9425-9d61643ad8af', '00000000-0000-0000-0000-000000000001', 'mcq', 'You deleted a 20 GB log with rm, but df still shows the disk full. What is th...', 'advanced', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a23c2956-176d-596d-bbdc-0bd289f2d0f9', '1c725e5b-4f0b-5b16-9425-9d61643ad8af', 1, $json${"prompt":"You deleted a 20 GB log with rm, but df still shows the disk full. What is the most likely reason?","multiple":false,"options":[{"id":"a","text":"A running process still has the deleted file open, so its space is not released","is_correct":true},{"id":"b","text":"rm only moves files to a hidden trash folder","is_correct":false},{"id":"c","text":"df caches results for 24 hours","is_correct":false},{"id":"d","text":"The file system needs to be reformatted","is_correct":false}],"explanation":"The inode lives until the last open handle closes. lsof +L1 finds it; restart the process or truncate via /proc/PID/fd. Truncating instead of rm avoids this."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d5e96e4d-de21-59e9-93b7-ac1a3192f9ce', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why should /etc/fstab refer to a new disk by UUID instead of /dev/sdb1, and w...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bc381a35-6996-52b8-a5ee-e372b3457671', 'd5e96e4d-de21-59e9-93b7-ac1a3192f9ce', 1, $json${"prompt":"Why should /etc/fstab refer to a new disk by UUID instead of /dev/sdb1, and what do you run before rebooting?","multiple":false,"options":[{"id":"a","text":"Device names can change between boots; test the file with sudo mount -a","is_correct":true},{"id":"b","text":"UUIDs are faster to read; test with df -h","is_correct":false},{"id":"c","text":"/dev names are only for USB sticks; test with lsblk","is_correct":false},{"id":"d","text":"fstab does not accept /dev names; no test is needed","is_correct":false}],"explanation":"Disk order can change, but a filesystem UUID does not. mount -a mounts every fstab entry now, catching mistakes that could otherwise stop the boot."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c31f420a-c600-5581-b56d-ed27124868b3', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command lists what is inside backup.tar.gz without extracting it?', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('fa028a69-12bb-58ea-b65d-70df66ab8bd8', 'c31f420a-c600-5581-b56d-ed27124868b3', 1, $json${"prompt":"Which command lists what is inside backup.tar.gz without extracting it?","multiple":false,"options":[{"id":"a","text":"tar -tzf backup.tar.gz","is_correct":true},{"id":"b","text":"tar -xzf backup.tar.gz","is_correct":false},{"id":"c","text":"tar -czf backup.tar.gz","is_correct":false},{"id":"d","text":"gzip -l backup.tar.gz | tar","is_correct":false}],"explanation":"t = tell (list), z = gzip, f = file. x extracts and c creates."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c5da0533-ca52-5278-838a-ba1494e962f8', '00000000-0000-0000-0000-000000000001', 'mcq', 'From your laptop, curl to atlas:8080 says Connection refused. On atlas, ss -t...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4126ccb0-4fa0-5a95-9921-2d3b9256b993', 'c5da0533-ca52-5278-838a-ba1494e962f8', 1, $json${"prompt":"From your laptop, curl to atlas:8080 says Connection refused. On atlas, ss -tulpn shows brewbot on 127.0.0.1:8080. What is wrong?","multiple":false,"options":[{"id":"a","text":"Brewbot listens only on localhost, so outside connections reach no listener","is_correct":true},{"id":"b","text":"A firewall is dropping the packets","is_correct":false},{"id":"c","text":"DNS is resolving the wrong name","is_correct":false},{"id":"d","text":"The server is out of memory","is_correct":false}],"explanation":"Refused means nothing listens on that address and port. Bound to 127.0.0.1, brewbot only accepts local connections; a firewall drop would show as a timeout instead."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c82a64c4-af32-576d-9df6-829b84d82177', '00000000-0000-0000-0000-000000000001', 'mcq', 'SSH ignores your key and asks for a password. The server''s ~/.ssh is 777 and ...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c5c1e943-e446-5cb4-8fe3-24065eda3c56', 'c82a64c4-af32-576d-9df6-829b84d82177', 1, $json${"prompt":"SSH ignores your key and asks for a password. The server's ~/.ssh is 777 and authorized_keys is 666. What should they be?","multiple":false,"options":[{"id":"a","text":"~/.ssh 700 and authorized_keys 600","is_correct":true},{"id":"b","text":"~/.ssh 755 and authorized_keys 777","is_correct":false},{"id":"c","text":"Both 644","is_correct":false},{"id":"d","text":"Permissions do not matter to SSH","is_correct":false}],"explanation":"sshd refuses keys that other users could modify. Lock .ssh to 700 and the key files to 600."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('54692db7-3207-596f-a55d-d0a84e1f83d1', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does set -euo pipefail at the top of a Bash script do?', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('69eac406-ecc3-5e84-bb64-7532a797d6cd', '54692db7-3207-596f-a55d-d0a84e1f83d1', 1, $json${"prompt":"What does set -euo pipefail at the top of a Bash script do?","multiple":false,"options":[{"id":"a","text":"Stops on the first failing command, errors on unset variables, and fails a pipeline if any part fails","is_correct":true},{"id":"b","text":"Runs the script as root","is_correct":false},{"id":"c","text":"Enables colour output and Unicode","is_correct":false},{"id":"d","text":"Makes the script run in the background","is_correct":false}],"explanation":"-e exit on error, -u treat unset variables as errors, -o pipefail make a pipeline's status reflect any failing stage."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('25c90928-7c7a-5bad-88d3-aa2023584c78', '00000000-0000-0000-0000-000000000001', 'mcq', 'In Bash, what exit status means a command succeeded?', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4f316929-42fc-5b0e-9c34-9396f6c9148e', '25c90928-7c7a-5bad-88d3-aa2023584c78', 1, $json${"prompt":"In Bash, what exit status means a command succeeded?","multiple":false,"options":[{"id":"a","text":"0","is_correct":true},{"id":"b","text":"1","is_correct":false},{"id":"c","text":"-1","is_correct":false},{"id":"d","text":"255","is_correct":false}],"explanation":"Zero is a hero: 0 is success, any other number is a failure code. if, \u0026\u0026 and || all check it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f01018b8-54f3-5fbc-b2b6-412ecdd3c857', '00000000-0000-0000-0000-000000000001', 'mcq', 'Brewbot will not start right after a teammate edited its config. Following th...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b8502b94-50bf-5b39-80e5-9ea68d0eeaef', 'f01018b8-54f3-5fbc-b2b6-412ecdd3c857', 1, $json${"prompt":"Brewbot will not start right after a teammate edited its config. Following the incident method, what do you do first?","multiple":false,"options":[{"id":"a","text":"Read the error with systemctl status and journalctl -u brewbot, then validate the changed config","is_correct":true},{"id":"b","text":"Reboot the server and hope it comes back","is_correct":false},{"id":"c","text":"chmod -R 777 /etc/brewbot so permissions cannot be the problem","is_correct":false},{"id":"d","text":"Reinstall the operating system","is_correct":false}],"explanation":"Every Real Linux Pro Checks: Error, Resources, Logs, Permissions, Changes. A recent config change plus a startup failure points straight at the config - read the logs, fix one thing, validate, restart."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('34aaf3a6-587c-5a02-a6b5-62bac5db4ba9', '00000000-0000-0000-0000-000000000001', 'mcq', 'A program fails with a vague error and no useful log. Which tool shows the ex...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7ce58d1b-28ca-502b-ae7f-d046ad6b22a4', '34aaf3a6-587c-5a02-a6b5-62bac5db4ba9', 1, $json${"prompt":"A program fails with a vague error and no useful log. Which tool shows the exact file it tried to open and the error the kernel returned?","multiple":false,"options":[{"id":"a","text":"strace","is_correct":true},{"id":"b","text":"lsblk","is_correct":false},{"id":"c","text":"uptime","is_correct":false},{"id":"d","text":"crontab -l","is_correct":false}],"explanation":"strace prints each system call and its result, for example openat(...) = -1 ENOENT. The others show disks, load and scheduled jobs."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('60c00966-3202-5997-8b11-536342bd9802', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which pair of kernel features makes a container?', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('49e1b8df-51a5-59e0-96ca-61ffac432711', '60c00966-3202-5997-8b11-536342bd9802', 1, $json${"prompt":"Which pair of kernel features makes a container?","multiple":false,"options":[{"id":"a","text":"Namespaces (what it can see) and cgroups (how much it can use)","is_correct":true},{"id":"b","text":"SUID and the sticky bit","is_correct":false},{"id":"c","text":"cron and systemd timers","is_correct":false},{"id":"d","text":"LVM and fstab","is_correct":false}],"explanation":"Namespaces isolate views of PIDs, mounts, network and hostname; cgroups limit CPU, memory and processes. All containers share the host kernel."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a195597c-12b0-5126-8254-eb4183de8f2b', '00000000-0000-0000-0000-000000000001', 'mcq', 'A memory leak in brewbot should kill brewbot, not the database next to it. Wh...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b352f71f-90cc-522d-bb2e-80b4254b5bff', 'a195597c-12b0-5126-8254-eb4183de8f2b', 1, $json${"prompt":"A memory leak in brewbot should kill brewbot, not the database next to it. What do you set?","multiple":false,"options":[{"id":"a","text":"MemoryMax= in brewbot's unit file (a cgroup limit)","is_correct":true},{"id":"b","text":"nice -n 19 brewbot","is_correct":false},{"id":"c","text":"A bigger swap file","is_correct":false},{"id":"d","text":"Restart=no","is_correct":false}],"explanation":"MemoryMax confines the OOM kill to brewbot's cgroup. Niceness affects CPU, more swap only delays the problem, and Restart controls restarts."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c1905cf8-12f2-56b6-9c94-d01d2651618e', '00000000-0000-0000-0000-000000000001', 'mcq', 'free -h shows free 200Mi and available 3.0Gi with no swapping. What is the ri...', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('74f60cc9-97b0-5f10-861c-e763834d7574', 'c1905cf8-12f2-56b6-9c94-d01d2651618e', 1, $json${"prompt":"free -h shows free 200Mi and available 3.0Gi with no swapping. What is the right conclusion?","multiple":false,"options":[{"id":"a","text":"Memory is fine; Linux uses spare RAM as reclaimable cache","is_correct":true},{"id":"b","text":"The server is nearly out of memory","is_correct":false},{"id":"c","text":"Swap is broken","is_correct":false},{"id":"d","text":"Reboot to free memory","is_correct":false}],"explanation":"available includes cache the kernel hands back on demand. Low free memory alone is normal and healthy."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('95ba3a34-f789-5eb4-958f-047c7dc23cb6', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the USE method, which signal shows CPU saturation?', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d18668b1-67fa-590d-83ff-5f68ab0418f5', '95ba3a34-f789-5eb4-958f-047c7dc23cb6', 1, $json${"prompt":"In the USE method, which signal shows CPU saturation?","multiple":false,"options":[{"id":"a","text":"A run queue (vmstat r, or load) consistently above the number of CPUs","is_correct":true},{"id":"b","text":"High %util in iostat","is_correct":false},{"id":"c","text":"A large RSS","is_correct":false},{"id":"d","text":"Many open SSH sessions","is_correct":false}],"explanation":"Saturation means waiting work. For CPU that is runnable processes beyond the CPU count. iostat %util is disk utilisation and RSS is memory."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3b8edbf2-f608-5549-bc6c-47f21bb0f145', '00000000-0000-0000-0000-000000000001', 'mcq', '/srv/data is an ext4 LVM volume and nearly full; the volume group has free sp...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2ac030bd-8a21-5aec-819d-403f2e9d0f77', '3b8edbf2-f608-5549-bc6c-47f21bb0f145', 1, $json${"prompt":"/srv/data is an ext4 LVM volume and nearly full; the volume group has free space. Which command grows it online?","multiple":false,"options":[{"id":"a","text":"sudo lvextend -r -L +20G /dev/vg_data/lv_srv","is_correct":true},{"id":"b","text":"sudo mkfs.ext4 /dev/vg_data/lv_srv","is_correct":false},{"id":"c","text":"sudo fdisk /dev/vg_data/lv_srv","is_correct":false},{"id":"d","text":"sudo mount -a","is_correct":false}],"explanation":"lvextend -r grows the logical volume and the filesystem together. mkfs erases it, fdisk partitions disks, and mount -a only mounts fstab entries."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a17f66a7-c8ba-5d6b-9bfe-ebc0034f3893', '00000000-0000-0000-0000-000000000001', 'mcq', 'You disabled SSH password logins in a drop-in. What do you do before closing ...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('372c340f-552f-534d-ac90-6c4cde100b50', 'a17f66a7-c8ba-5d6b-9bfe-ebc0034f3893', 1, $json${"prompt":"You disabled SSH password logins in a drop-in. What do you do before closing your current session?","multiple":false,"options":[{"id":"a","text":"Run sshd -t, reload ssh, and confirm a new session can log in with your key","is_correct":true},{"id":"b","text":"Reboot immediately","is_correct":false},{"id":"c","text":"Nothing; sshd validates changes itself","is_correct":false},{"id":"d","text":"Delete your authorized_keys","is_correct":false}],"explanation":"Check syntax, reload (existing sessions stay), and prove access still works from a new terminal. Otherwise one mistake locks you out."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b1d0f602-15d2-50cd-aff9-f90f9edb099d', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command lists SUID files, a common place for backdoors?', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1ee31683-a7a7-5702-a58d-7f160bf7e4ad', 'b1d0f602-15d2-50cd-aff9-f90f9edb099d', 1, $json${"prompt":"Which command lists SUID files, a common place for backdoors?","multiple":false,"options":[{"id":"a","text":"find / -xdev -perm -4000 -type f 2\u003e/dev/null","is_correct":true},{"id":"b","text":"find / -perm 777","is_correct":false},{"id":"c","text":"ls -la /","is_correct":false},{"id":"d","text":"df -i","is_correct":false}],"explanation":"-perm -4000 matches the SUID bit. 777 is a different (world-writable) problem, ls / shows one directory, and df -i shows inode usage."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7ddd7f27-bf6c-53d8-ba0a-e0be6c5a4a75', '00000000-0000-0000-0000-000000000001', 'mcq', 'Atlas crashed overnight and rebooted. Which command shows error messages from...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5c0fa1ce-e84b-52af-8348-8f628f98f714', '7ddd7f27-bf6c-53d8-ba0a-e0be6c5a4a75', 1, $json${"prompt":"Atlas crashed overnight and rebooted. Which command shows error messages from before the crash (with a persistent journal)?","multiple":false,"options":[{"id":"a","text":"journalctl -b -1 -p err","is_correct":true},{"id":"b","text":"journalctl -b -p err","is_correct":false},{"id":"c","text":"systemctl --failed","is_correct":false},{"id":"d","text":"dmesg -T","is_correct":false}],"explanation":"-b -1 selects the previous boot. The other commands show the current boot or the current state."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('7938e6a1-f9a9-568b-91e9-a09d6b757114', '00000000-0000-0000-0000-000000000001', 'Final Exam: Linux on Atlas', 'linux-final-exam', 'Quiz covering Final Exam: Atlas Certified.', 'mcq', 'published', 'module', 'c09b6d0f-f9b8-5c55-9a5c-e59ac936ee3d', 40, 70, 5, 165, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '7938e6a1-f9a9-568b-91e9-a09d6b757114' AND question_id NOT IN ('631e7621-1f2d-5c5b-b31b-98d95922c155', 'cbca87c0-7c74-5564-85b0-d371ee7545d8', 'b3136879-d0a0-5050-acdf-624e579250ae', '822b1374-8977-586e-8902-ae16c680cf65', '7eb1b543-6d29-5109-b181-c2854b6ed8d1', 'c3226f2b-9da0-5196-bb2c-c4286daf17be', 'd5c8c230-1e0b-542b-8a98-772cfb3e07f1', '0aa4e899-21cc-55e5-a071-ba279d0dd815', 'e77dc2e0-717f-5379-ad81-64e15eb75919', '1ffbf11f-71f8-5be6-b594-5cf47ceb3a07', '1c221771-6eea-5155-a761-10ed3bbcfec9', 'c0651b5a-bde0-576f-a4e3-3b4a64709bf9', 'f75565b6-a546-59a4-8df9-f6e57f693341', 'a344c221-b459-59b5-a35a-42ab657b6baa', '68d1413f-05cd-5cf0-926f-814a2a019766', '28daf639-9558-5108-a769-1ae1caf9a159', '1c725e5b-4f0b-5b16-9425-9d61643ad8af', 'd5e96e4d-de21-59e9-93b7-ac1a3192f9ce', 'c31f420a-c600-5581-b56d-ed27124868b3', 'c5da0533-ca52-5278-838a-ba1494e962f8', 'c82a64c4-af32-576d-9df6-829b84d82177', '54692db7-3207-596f-a55d-d0a84e1f83d1', '25c90928-7c7a-5bad-88d3-aa2023584c78', 'f01018b8-54f3-5fbc-b2b6-412ecdd3c857', '34aaf3a6-587c-5a02-a6b5-62bac5db4ba9', '60c00966-3202-5997-8b11-536342bd9802', 'a195597c-12b0-5126-8254-eb4183de8f2b', 'c1905cf8-12f2-56b6-9c94-d01d2651618e', '95ba3a34-f789-5eb4-958f-047c7dc23cb6', '3b8edbf2-f608-5549-bc6c-47f21bb0f145', 'a17f66a7-c8ba-5d6b-9bfe-ebc0034f3893', 'b1d0f602-15d2-50cd-aff9-f90f9edb099d', '7ddd7f27-bf6c-53d8-ba0a-e0be6c5a4a75');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('53503d6f-3573-5600-aa96-47a1a602b6fc', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '631e7621-1f2d-5c5b-b31b-98d95922c155', '459aedd2-1910-5155-bb1f-0abd5c8834ba', 0, 5),
('7fe1f11c-075b-5225-878d-c9e69723860d', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'cbca87c0-7c74-5564-85b0-d371ee7545d8', 'df795f74-ef30-58a1-9d6c-6cdd687b95b8', 1, 5),
('2ecc2ec1-cb59-55ce-8be1-3780f5520034', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'b3136879-d0a0-5050-acdf-624e579250ae', '9fe9dd4c-15d8-533a-b4de-fd718c1682d3', 2, 5),
('cb4a900f-29da-5c25-92dc-82f6f52afcb5', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '822b1374-8977-586e-8902-ae16c680cf65', 'c6a7ee6c-307b-5e0f-a97e-734eb225d55a', 3, 5),
('167d265e-e87c-5a02-ab94-90c572986970', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '7eb1b543-6d29-5109-b181-c2854b6ed8d1', '0f53e9b9-614d-586f-95fb-5d42f3c2b52b', 4, 5),
('9b319f2a-89ac-5cd8-8ccb-5677440dea27', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'c3226f2b-9da0-5196-bb2c-c4286daf17be', '5fb598ed-0cd9-5d4e-9289-0958df0d1e21', 5, 5),
('9469bc36-7c16-50da-a174-d5e95a097c26', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'd5c8c230-1e0b-542b-8a98-772cfb3e07f1', 'ab234ad2-1b2c-517a-aa2f-1feb2bbf54ba', 6, 5),
('09ea92c6-d063-5683-a90d-08314637e973', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '0aa4e899-21cc-55e5-a071-ba279d0dd815', '69a9b803-4fdf-5dac-81c3-08e626bfb6d7', 7, 5),
('2735dc4d-967c-5e8d-bc74-f34bbb15fe22', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'e77dc2e0-717f-5379-ad81-64e15eb75919', '0186e08e-7ef3-5a64-b7c2-b05ef2b22f1a', 8, 5),
('ac4b094f-c2c3-581e-9910-157fe270ab72', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '1ffbf11f-71f8-5be6-b594-5cf47ceb3a07', 'd9018b26-dda6-541b-99f6-823633accfd4', 9, 5),
('23ec00e5-7ed0-5f50-bd76-0deed3621cba', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '1c221771-6eea-5155-a761-10ed3bbcfec9', 'a28ad616-fc67-563f-ad67-6d852c4084f4', 10, 5),
('3c6e8644-7557-593b-9b59-99ea49029ba8', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'c0651b5a-bde0-576f-a4e3-3b4a64709bf9', '374ff15c-0ad0-562e-9147-d2fde9758c2e', 11, 5),
('6b7adbdb-1082-545b-8cc8-772c7b3a4e09', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'f75565b6-a546-59a4-8df9-f6e57f693341', '2bac7394-b3ad-5e1c-b1ff-94a5ab2dff96', 12, 5),
('534b4685-0e72-5d8d-8dcc-26a59babe202', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'a344c221-b459-59b5-a35a-42ab657b6baa', 'b34b63c0-0b30-50ed-9cc8-1e6f8f294ba0', 13, 5),
('0c1025b1-e589-5f46-ac80-8a872ad322ab', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '68d1413f-05cd-5cf0-926f-814a2a019766', 'd8493143-7c82-5e4a-81e2-b0658fac67fc', 14, 5),
('089191f0-634e-529d-8df3-fca7206c0635', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '28daf639-9558-5108-a769-1ae1caf9a159', 'e778851b-9f7d-5b1a-b0d0-cff268894a95', 15, 5),
('1dd01d3e-3327-5714-bf9d-ef550edbf08a', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '1c725e5b-4f0b-5b16-9425-9d61643ad8af', 'a23c2956-176d-596d-bbdc-0bd289f2d0f9', 16, 5),
('51bd00d7-894c-5835-a169-644f381d1d44', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'd5e96e4d-de21-59e9-93b7-ac1a3192f9ce', 'bc381a35-6996-52b8-a5ee-e372b3457671', 17, 5),
('eb09df5b-2520-5be9-94c9-df4c7759f9c3', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'c31f420a-c600-5581-b56d-ed27124868b3', 'fa028a69-12bb-58ea-b65d-70df66ab8bd8', 18, 5),
('a2b7f82b-9689-562a-9141-3204515b228d', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'c5da0533-ca52-5278-838a-ba1494e962f8', '4126ccb0-4fa0-5a95-9921-2d3b9256b993', 19, 5),
('db239f63-11d0-5936-bbef-a0c022234edb', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'c82a64c4-af32-576d-9df6-829b84d82177', 'c5c1e943-e446-5cb4-8fe3-24065eda3c56', 20, 5),
('05c6c3e8-08be-56b9-9a2d-66f15f1d61f5', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '54692db7-3207-596f-a55d-d0a84e1f83d1', '69eac406-ecc3-5e84-bb64-7532a797d6cd', 21, 5),
('dc3ee37f-7f66-556e-bd62-b3fd58a0fa9c', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '25c90928-7c7a-5bad-88d3-aa2023584c78', '4f316929-42fc-5b0e-9c34-9396f6c9148e', 22, 5),
('f166fdd9-82a4-54a2-9c8a-7670474dcdbd', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'f01018b8-54f3-5fbc-b2b6-412ecdd3c857', 'b8502b94-50bf-5b39-80e5-9ea68d0eeaef', 23, 5),
('bd1d9f3f-2037-5a85-b05a-7e07f0e1c547', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '34aaf3a6-587c-5a02-a6b5-62bac5db4ba9', '7ce58d1b-28ca-502b-ae7f-d046ad6b22a4', 24, 5),
('8c446164-5032-595b-a3a3-3a9c9d249f56', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '60c00966-3202-5997-8b11-536342bd9802', '49e1b8df-51a5-59e0-96ca-61ffac432711', 25, 5),
('889f881f-6b54-57ec-95c4-9c0be1123347', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'a195597c-12b0-5126-8254-eb4183de8f2b', 'b352f71f-90cc-522d-bb2e-80b4254b5bff', 26, 5),
('3a411e36-16da-54d9-92d3-bd01c8fb882c', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'c1905cf8-12f2-56b6-9c94-d01d2651618e', '74f60cc9-97b0-5f10-861c-e763834d7574', 27, 5),
('51bbe5cd-69da-5d13-9836-f36a9e10c078', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '95ba3a34-f789-5eb4-958f-047c7dc23cb6', 'd18668b1-67fa-590d-83ff-5f68ab0418f5', 28, 5),
('da923344-0a0c-5a7c-b027-3ab8552b1155', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '3b8edbf2-f608-5549-bc6c-47f21bb0f145', '2ac030bd-8a21-5aec-819d-403f2e9d0f77', 29, 5),
('20737690-c6a4-5ffe-9eff-f3ca9ca39c2e', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'a17f66a7-c8ba-5d6b-9bfe-ebc0034f3893', '372c340f-552f-534d-ac90-6c4cde100b50', 30, 5),
('b9645d78-f881-557b-9100-da5a0b88b864', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'b1d0f602-15d2-50cd-aff9-f90f9edb099d', '1ee31683-a7a7-5702-a58d-7f160bf7e4ad', 31, 5),
('f842e479-2507-5dc7-9bf7-90a5c74b2f93', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '7ddd7f27-bf6c-53d8-ba0a-e0be6c5a4a75', '5c0fa1ce-e84b-52af-8348-8f628f98f714', 32, 5)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('c09b6d0f-f9b8-5c55-9a5c-e59ac936ee3d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '8b26cec3-ded3-5a1a-92dd-bb42562680dc', 'Final Exam: Linux on Atlas', 'assessment', 1, 40, '7938e6a1-f9a9-568b-91e9-a09d6b757114')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('846f1551-d0eb-56ef-829d-5275cbdcfd21', '00000000-0000-0000-0000-000000000014', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

DELETE FROM course_modules WHERE course_id = 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf' AND id NOT IN ('b6b1f456-2e0a-52f7-8b19-57626f5ccdf3', '76428f04-341c-5a99-a241-aab2f94c6fb1', 'aa12b2c0-47fd-5b45-9e77-b3f8d51102fb', 'ed92d13b-2c45-5056-9163-73173039c990', 'fda98f02-7987-58e5-9ee8-2bd0421ecf2c', 'd97de623-3798-5d28-b6ee-a253e819bcc1', 'ce77c897-2d26-5f99-8ca6-6dfd33fcdfdc', 'a50e29c4-cd7e-5b52-bfea-bf5cd4825d59', '10d6dc16-476c-5e96-ae6b-efa23dae5aca', '0fd77dab-c5af-5341-97f3-61a343493b95', 'faee4b4d-9fb1-5ccd-8229-de8e4915da6d', '06d07063-e592-5091-af65-caa319274ed2', '5d0e0635-a1ba-57a3-bfac-8925114a0c0a', 'b235d4e1-d303-58e8-8e4d-abd8d4340caa', '7aca830d-151a-5ddd-b824-189d87652f8d', '9316f12f-6675-5d94-bb0a-f55dbf0c73f1', '5a5b409f-a43c-5413-8bac-dbbdd8d138d7', 'ca211df5-0a8e-5362-b113-b41608481009', 'a43a1a91-d60d-5265-9262-a02ee53c971d', 'a7a9a13d-7a23-58b3-b9e6-6a989d6ac7d8', '3b82fcaa-113c-5f02-8280-09784672b7ca', '4c86713a-ebd2-56bd-be0e-5ca781b0c6f8', 'c5763494-4508-5099-965a-3b07d56d84c9', 'e1290c82-3f3d-57a6-a129-23ffaa14daf9', 'bf0047a6-c13e-5bf5-9556-59a2f6c47e4c', '49afe0f9-ea78-5800-b816-537f12311cf3', 'e3fdea25-4723-55cf-9e13-25710487a99d', '0df028e1-6c37-546f-91cb-a92db089afa9', '2ccfc028-4aa0-5f7e-9a25-27d3fd01017a', 'aa0b609a-d2eb-537a-9efc-3e17ff38e5b4', 'fa188562-0645-5398-84e4-697ba8f4332e', '6ddf6e30-fb69-5a55-82b6-5557078b415e', '2012bf06-6b18-5c0c-a9a0-2807ef547a42', '949b7868-431b-54ca-9fdd-15adc89a0913', 'a675c34c-0a48-58af-87ad-010cc471a6b6', '8ba2fbe2-8360-5163-af09-ea100c4f9e3f', 'fee0d4cf-ff18-5a5e-b150-0ba3e30cf050', '6fd766f9-3650-5a76-921d-ae364b0278e9', '6a48b932-03c5-5902-a82b-599fdc4af2ff', '66620df3-e85f-56db-87a0-e864f424d086', '61f378d0-ef8b-5471-a452-36ed028f26fa', '231dac95-528c-5b9c-a5b1-e9236c5325f8', 'adf26bb9-07fe-518a-9fe6-a06e247aa5f1', 'fbc23bf0-026c-5d0a-9905-ae647b0dee6b', 'b47e2e9d-c0c7-5861-bd16-0e2b79970b05', '8d5f801e-52c4-56f7-9636-ebfce847344a', '390b5685-7889-5f90-87f7-36a775b9c571', 'bf821ab5-9fd6-5101-b33d-cce4cfecfac2', 'bed22685-6d92-557d-ad29-f2c0b7395b93', 'e969cf2f-c441-5630-9036-2f68365cdbb8', '2548efc3-bdc8-595c-ad95-418a1ba2fc70', 'ca50f395-ddab-592d-9cf5-1e3a6dc32c7d', '2c79ee2f-d567-5228-bbe7-d75be3009813', '27fd54a6-41f3-5e54-8be6-6d750add8e1d', 'ea13445f-9b90-57e2-af6e-4e12dd200fcf', '411b7382-5fde-533f-8918-72e6a7d58c57', '11b28bd9-4431-59fb-b0c4-9e422068f6cc', '07329dd3-5b0b-569f-bc30-70db38b74151', 'ed72dd0b-9dd2-5d1c-a2fa-69f7fc9db327', '5bf81568-4aa0-57ea-a68e-7d55082e4ec4', '2d5afd41-c59f-54d6-b0f7-5682eb472299', '914dcaa1-93db-55c5-9bb3-d537764eba2a', '1a802dd5-66ee-575e-9a29-585477a8fca7', '82e9b27a-f5da-53a1-b629-7a360b89b0a0', '58612421-3b63-54ae-acd4-4fd18e2cc748', '05b5b666-8186-5ee0-86e5-aefff70dd17b', 'b21cb753-609a-5a14-84c8-04c291868caa', 'b6fb83b0-7196-5683-a122-746fe27d3539', 'b3e204d1-7053-5c45-a3d4-60a5c03fafb3', 'c7f0b046-fe8c-55fa-87cf-259deae74fdd', 'c71c9048-4936-5e5b-aaf4-1a59f4b7c847', '44516a7d-9932-5572-a6d8-6d2e7646aee2', '4a821c00-a7e1-5030-baf7-3d9825652bb8', '64a3a363-df99-5bae-aeba-0d274cc5bcd0', 'caeec16b-d5c7-599c-a28b-2348b83e1641', '55c6c650-559a-5777-b18e-471216cab061', '9958f366-25a0-5d32-8c62-dc48d5c2b7c2', 'b2f85ef8-d84e-5d7a-b11a-d8e4fe0bde1b', 'b0fcae15-7a36-5f87-8ee6-cea618c6ea6a', '4ec6da49-ce7c-5503-bae2-95c23b81662d', 'd16ae943-dbf4-5cb8-9c60-dd0304d81e15', '0adf72de-87a1-5cd3-857e-0bdfbac9fe1b', '8a509708-8aee-541f-a44c-5f23acd47e44', '02603888-41d8-554a-8dc2-4d895a51b6cc', 'ce244c27-606e-5adc-975a-5aff24d69587', 'f1f33db1-7c4b-5ac8-8188-addabd6b6f4a', '2f33a0a9-0fde-5271-b17c-f54f0a296c1c', '7a74603b-08dc-5e6d-b8d7-07935be12863', '74f56cd2-7563-5379-983a-96ff369dcd16', '32749896-8ec8-5cc1-8030-1f065f7e2c52', 'b36783aa-e3cf-5870-b0cb-b98a0029f958', '98e8fdd8-e24e-5db1-b803-395897fc53f0', '2a490cae-71e4-59a9-a587-b59b8f867764', 'fc864796-19d3-5045-99ff-39d6b618c77f', 'a8b8174b-e741-5507-ae90-29cd8d9556b4', 'f70cdaac-4587-5fa1-8521-59ab720723bd', '6de74a5b-c7fa-561d-abaf-4a194a2053e7', 'f3d8d904-d373-57e6-b6fd-c3193f0210dc', '0827d60b-62f1-5079-a788-314cbad71256', '99908f22-2062-52f6-88ad-daa4d7d1135f', '92e328bd-e388-5832-ac26-28744ebfc928', '10e4a330-31e0-5017-b0f7-bc227acf23e9', 'f9aca5c5-1fc3-504c-98bd-addeb9db74ea', 'c09b6d0f-f9b8-5c55-9a5c-e59ac936ee3d');
DELETE FROM course_sections WHERE course_id = 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf' AND id NOT IN ('4078896b-224c-5318-8a4a-c389cca4bece', '63d08802-94af-5e70-adb6-8cdf39e53b00', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'ec8f752c-74df-5e68-b66e-b63f6f3212a5', '1d2e633e-0589-50da-b212-4e9f881d0b3c', 'e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', '5db992b5-3341-59db-beb3-e76a644469d4', 'c5860956-2151-5bdf-bf27-28e5acab5aad', '303569e7-7bba-5e6f-a8bb-47557bde7da4', '716c0129-f420-5354-9147-1d8b681dd59a', '8b26cec3-ded3-5a1a-92dd-bb42562680dc');

