---
kind: lesson
id_key: linux/performance/use-method
course: linux
section: performance
section_title: "Chapter 11: Performance Triage"
section_position: 11
title: "The USE Method and the First 60 Seconds"
position: 0
estimated_minutes: 7
source:
  - Brendan Gregg, "The USE Method" and "Linux Performance Analysis in 60,000 Milliseconds" (brendangregg.com)
---

## Why this matters

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
