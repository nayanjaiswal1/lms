---
kind: lesson
id_key: linux/performance/cpu-and-load
course: linux
section: performance
section_title: "Chapter 11: Performance Triage"
section_position: 11
title: "CPU and Load Average: Reading uptime and top"
position: 1
estimated_minutes: 8
source:
  - uptime(1), top(1), mpstat(1), pidstat(1) manual pages; proc(5) "/proc/loadavg"
  - "Brendan Gregg, Linux Load Averages - Solving the Mystery (brendangregg.com)"
---

## Why this matters

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
