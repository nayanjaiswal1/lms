---
kind: lesson
id_key: docker/production/resource-limits
course: docker
section: production
section_title: Production-Ready Containers
section_position: 7
title: "Resource Limits: Memory, CPU and PIDs"
position: 2
estimated_minutes: 8
source:
  - Docker Command Cheat Sheet.pdf
---

## Why this matters

By default a container may use **all** of the host's memory and CPU. One memory
leak or runaway loop can freeze every other container on the machine. Limits
turn "the whole server died" into "one container restarted".

## Mental model: a hotel room's electricity fuse

Each room (container) gets a fuse. Plug in too much and **that room's** fuse
trips; the rest of the hotel keeps its lights on. These fuses are Linux
**cgroups** (Section 1): the kernel counts and caps what each container consumes.

Two kinds of limits behave very differently:

| Resource | What happens at the limit | Why |
|---|---|---|
| **Memory** | The kernel **kills** the process (OOM kill, exit code **137**) | Memory cannot be "slowed down" |
| **CPU** | The process is **throttled** (runs slower) | CPU time can be shared out |

## See it work

### Memory

```bash
docker run -d --name capped --memory 64m nginx:1.27-alpine
docker stats --no-stream capped
```

Expected output (values vary):

```
NAME     CPU %   MEM USAGE / LIMIT   MEM %
capped   0.00%   3.9MiB / 64MiB      6.09%
```

Watch an OOM kill happen:

```bash
docker run --name hog --memory 32m python:3.12-alpine \
  python3 -c "x = bytearray(100 * 1024 * 1024)"
docker inspect -f '{{.State.ExitCode}} {{.State.OOMKilled}}' hog
```

Expected output:

```
137 true
```

Memory flags:

- `--memory 512m`: hard limit.
- `--memory-swap 512m`: memory + swap total; equal to `--memory` means no swap.
- `--memory-reservation 256m`: a soft target the kernel enforces when the host is under pressure.

### CPU

```bash
docker run -d --name cpu-half --cpus 0.5 nginx:1.27-alpine
```

- `--cpus 1.5`: at most one and a half CPU cores' worth of time.
- `--cpu-shares 512`: relative weight (default 1024) that only matters when CPUs are busy.
- `--cpuset-cpus 0,1`: pin to specific cores.

### Process count

```bash
docker run --rm --pids-limit 100 alpine:3.20 sh -c 'echo limited'
```

`--pids-limit` stops fork bombs and thread leaks from exhausting the host's process table.

### Change limits on a running container

```bash
docker update --memory 128m --memory-swap 128m --cpus 1 capped
docker inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' capped
```

Output: `134217728 1000000000` (bytes, and billionths of a CPU).

### In Compose

```yaml
services:
  api:
    image: myorg/api:1.0
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          memory: 256M
    pids_limit: 200
```

`docker compose up` applies `deploy.resources.limits` to normal (non-Swarm) containers too.

### Runtimes must know their limit

Language runtimes size their heaps from "available memory". Modern JVMs (Java
10+), Node and Go read the cgroup limit, but you often still tune them:
`-XX:MaxRAMPercentage=75` for Java, `--max-old-space-size` for Node. Leave
headroom: the limit covers the whole process, not just the heap.

## Try it

A Java service restarts every few hours with exit code 137, and `OOMKilled` is
`true`. The limit is `--memory 1g` and the JVM uses `-Xmx1g`. What is wrong?

<details>
<summary>Show answer</summary>

The heap alone is allowed to use the entire 1 GB limit, but the JVM also needs
memory for metaspace, threads, buffers and the JIT. The total crosses 1 GB and
the kernel kills it. Lower the heap (`-XX:MaxRAMPercentage=75` or
`-Xmx700m`) or raise the limit.

</details>

## Common mistakes

- **No limits in production.** One leak takes the host down.
- **Reading exit 137 as "Docker bug".** Check `OOMKilled`; it is usually the memory limit.
- **Setting `--cpus` and expecting a crash.** CPU limits throttle; look for high
  latency, not restarts.
- **Heap = limit.** Leave room for non-heap memory.

## Remember

- No limits by default. Limits are cgroups.
- Memory over limit → OOM kill, exit **137**, `OOMKilled=true`.
- CPU over limit → throttled (slower), never killed.
- Flags: `--memory`, `--memory-swap`, `--cpus`, `--cpu-shares`, `--pids-limit`; `docker update` changes them live.
- `docker stats` shows usage against limits.

**Self-check:**

1. What happens when a container exceeds its memory limit? Its CPU limit?
2. Which `inspect` field confirms an OOM kill?
3. What does `--pids-limit` protect against?
