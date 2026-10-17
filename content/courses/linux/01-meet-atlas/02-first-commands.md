---
kind: lesson
id_key: linux/meet-atlas/first-commands
course: linux
section: meet-atlas
section_title: "Chapter 1: Meet Atlas - the Shell and the Map"
section_position: 1
title: "Your First Commands: the Prompt and Command Anatomy"
position: 1
estimated_minutes: 8
source:
  - GNU Bash Reference Manual, "Shell Syntax" and "Bash History Facilities"
  - uname(1), whoami(1), hostname(1) manual pages
---

## Why this matters

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
