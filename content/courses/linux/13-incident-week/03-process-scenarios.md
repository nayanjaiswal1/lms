---
kind: lesson
id_key: linux/incident-week/process-scenarios
course: linux
section: incident-week
section_title: "Chapter 13: Incident Week - Troubleshooting Playbook"
section_position: 13
title: "Process Scenarios: Runaway, Hung, OOM-Killed, IO-Bound"
position: 2
estimated_minutes: 7
source:
  - ps(1), top(1), kill(1), dmesg(1), vmstat(8), iostat(1), systemd.resource-control(5) manual pages
---

## Why this matters

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
