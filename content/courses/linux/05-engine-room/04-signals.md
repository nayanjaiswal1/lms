---
kind: lesson
id_key: linux/engine-room/signals
course: linux
section: engine-room
section_title: "Chapter 5: The Engine Room - Processes"
section_position: 5
title: "Signals: kill, SIGTERM vs SIGKILL, and Zombies"
position: 3
estimated_minutes: 8
source:
  - signal(7), kill(1), pkill(1), killall(1), wait(2) manual pages
---

## Why this matters

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
