---
kind: lesson
id_key: linux/performance/disk-io
course: linux
section: performance
section_title: "Chapter 11: Performance Triage"
section_position: 11
title: "Disk IO: iostat, iotop and Processes Stuck in D State"
position: 3
estimated_minutes: 7
source:
  - iostat(1), iotop(8), vmstat(8), ionice(1), ps(1) manual pages
---

## Why this matters

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
