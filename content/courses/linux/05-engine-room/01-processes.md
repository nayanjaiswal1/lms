---
kind: lesson
id_key: linux/engine-room/processes
course: linux
section: engine-room
section_title: "Chapter 5: The Engine Room - Processes"
section_position: 5
title: "What a Process Is: PIDs, the Process Tree and ps"
position: 0
estimated_minutes: 8
source:
  - ps(1), pstree(1), pgrep(1), top(1) manual pages; proc(5)
---

## Why this matters

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
