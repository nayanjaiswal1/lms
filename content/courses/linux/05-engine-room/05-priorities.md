---
kind: lesson
id_key: linux/engine-room/priorities
course: linux
section: engine-room
section_title: "Chapter 5: The Engine Room - Processes"
section_position: 5
title: "Priorities: nice, renice, ionice and taskset"
position: 4
estimated_minutes: 6
source:
  - nice(1), renice(1), ionice(1), taskset(1), sched(7) manual pages
---

## Why this matters

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
