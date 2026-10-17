---
kind: lesson
id_key: linux/under-the-hood/cgroups
course: linux
section: under-the-hood
section_title: "Chapter 10: Under the Hood - Kernel, Namespaces and cgroups"
section_position: 10
title: "cgroups: Limiting What a Process Can Use"
position: 2
estimated_minutes: 8
source:
  - cgroups(7) manual page; The Linux Kernel documentation, "Control Group v2"
  - systemd.resource-control(5), systemd-cgtop(1), systemd-run(1) manual pages
---

## Why this matters

A memory leak in brewbot should kill brewbot, not the database next to it. A
runaway report should not eat every CPU during the sale. **cgroups** are how
Linux, systemd, Docker and Kubernetes put a fence around each service's
resources.

## Mental model: a fenced paddock with meters

A **control group (cgroup)** is a group of processes with:

- **limits** (fences): at most 512 MiB of memory, at most half a CPU, at most
  100 processes;
- **accounting** (meters): how much memory, CPU and IO the group is using now.

Groups form a tree. Modern systems use **cgroup v2**: one tree, mounted at
`/sys/fs/cgroup`. systemd puts every service in its own group:

```
 /sys/fs/cgroup/
   system.slice/
     nginx.service/        memory.current  memory.max  cpu.max  pids.max
     brewbot.service/
   user.slice/
     user-1000.slice/      your login sessions
```

When a group hits `memory.max`, the kernel's OOM killer kills a process **inside
that group**, not a random one on the machine.

## See it work

```bash
cat /proc/self/cgroup
```

Expected output inside the lab container:

```
0::/
```

`0::` means cgroup v2; the path after it is your group, relative to the tree you
can see (a cgroup namespace makes the container look like the root). Read the
fences and meters:

```bash
cat /sys/fs/cgroup/memory.max     # memory limit ("max" = unlimited)
cat /sys/fs/cgroup/memory.current # bytes in use now
cat /sys/fs/cgroup/cpu.max        # "QUOTA PERIOD": 50000 100000 = half a CPU
cat /sys/fs/cgroup/pids.max       # process limit
```

Example output for a container limited to 512 MiB and half a CPU:

```
536870912
84475904
50000 100000
max
```

### On a systemd server

```bash
systemctl status brewbot          # the CGroup: line shows its group
systemd-cgtop                     # top, per cgroup
systemd-cgls                      # the tree
sudo systemctl set-property brewbot MemoryMax=512M CPUQuota=50%
```

Or in the unit file (chapter 6):

```ini
[Service]
MemoryMax=512M
CPUQuota=50%
TasksMax=200
IOWeight=50
```

Run a one-off command in its own limited group:

```bash
sudo systemd-run --scope -p MemoryMax=200M -p CPUQuota=20% ./import-big-file.sh
```

### Containers are cgroups too

`docker run --memory 512m --cpus 0.5` and Kubernetes `resources.limits` write
exactly these files. A container killed with exit code **137** (SIGKILL) after
hitting its memory limit is the cgroup OOM killer at work; `memory.events` counts
`oom_kill`s.

`nproc` respects the CPUs you are allowed to use (affinity); CPU *quota* limits
show up in `cpu.max`, not in `nproc`.

## Try it

`cat /sys/fs/cgroup/system.slice/brewbot.service/memory.max` prints
`536870912`. Brewbot keeps getting killed with status 137 during the sale. What
is happening, and what are your options?

<details>
<summary>Show answer</summary>

536870912 bytes = 512 MiB. Brewbot reaches its cgroup memory limit and the
kernel OOM-kills it (137 = 128 + SIGKILL). Check `memory.events` for `oom_kill`
and the journal for the OOM message. Then either fix the leak/usage, or raise
`MemoryMax=` deliberately if the server has room.

</details>

## Common mistakes

- **No limits at all.** One leaking service takes the whole machine down.
- **Reading free memory on the host to judge a container.** The container's
  limit is in its cgroup (`memory.max`), not in `free`.
- **Confusing CPU quota with CPU count.** `cpu.max` 50000/100000 is half a CPU
  of time, spread across any cores.
- **Setting limits too tight.** Then the service is OOM-killed under normal
  load. Measure `memory.current` and `memory.peak` first.

## Remember

- cgroups = limits + accounting for groups of processes; v2 lives at
  `/sys/fs/cgroup`.
- Files: `memory.max/current`, `cpu.max`, `pids.max`, `memory.events`.
- systemd: `MemoryMax=`, `CPUQuota=`, `TasksMax=`; `systemd-cgtop`,
  `systemd-run -p`.
- Docker and Kubernetes limits are cgroups; 137 often = cgroup OOM kill.

**Self-check:**

1. Where do you read a container's memory limit from inside it?
2. What does `cpu.max` of `50000 100000` mean?
3. Which systemd setting caps a service's memory?
