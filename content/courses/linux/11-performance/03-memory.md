---
kind: lesson
id_key: linux/performance/memory
course: linux
section: performance
section_title: "Chapter 11: Performance Triage"
section_position: 11
title: "Memory: free, available, cache, swap and the OOM Killer"
position: 2
estimated_minutes: 8
source:
  - free(1), vmstat(8), proc(5) "/proc/meminfo" and "/proc/pressure", ps(1) manual pages
  - The Linux Kernel documentation, "Out Of Memory handling" and "PSI - Pressure Stall Information"
---

## Why this matters

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
