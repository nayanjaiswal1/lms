---
kind: lesson
id_key: linux/engine-room/jobs
course: linux
section: engine-room
section_title: "Chapter 5: The Engine Room - Processes"
section_position: 5
title: "Foreground, Background, nohup and tmux"
position: 2
estimated_minutes: 7
source:
  - GNU Bash Reference Manual, "Job Control"; nohup(1), tmux(1) manual pages
---

## Why this matters

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
