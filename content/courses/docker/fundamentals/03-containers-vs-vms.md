---
kind: lesson
id_key: docker/fundamentals/containers-vs-vms
course: docker
section: fundamentals
section_title: Big Picture & Fundamentals
section_position: 1
title: "Under the Hood: Namespaces, cgroups and Containers vs VMs"
position: 2
estimated_minutes: 9
source:
  - Docker Command Cheat Sheet.pdf
---

## Why this matters

Interviewers love "how is a container different from a VM?". More importantly,
the answer explains real behaviour you will hit: why a container starts in
milliseconds, why it can see only its own processes, and why one container can
starve the host of memory if you do not set limits.

## Mental model: an apartment building

A **virtual machine** is a separate house. It has its own foundation, plumbing
and power plant (its own **kernel**, the core of the operating system).

A **container** is an apartment in one building. Every apartment shares the same
foundation and plumbing (the **host kernel**), but each has its own locked door,
its own mailbox and a fixed share of electricity.

```
     Virtual machines                     Containers
+----------+ +----------+        +----------+ +----------+
|  App A   | |  App B   |        |  App A   | |  App B   |
| libs     | | libs     |        | libs     | | libs     |
| Guest OS | | Guest OS |        +----------+ +----------+
| (kernel) | | (kernel) |        |  container runtime     |
+----------+ +----------+        +------------------------+
|      Hypervisor        |       |  Host OS (ONE kernel)  |
+------------------------+       +------------------------+
|       Hardware         |       |       Hardware         |
+------------------------+       +------------------------+
```

Linux builds the "apartment walls" from two kernel features:

| Feature | Plain-words job | Analogy |
|---|---|---|
| **Namespaces** | Control what a process can **see** (its own process list, network, hostname, mounts, users) | The locked door and private mailbox |
| **cgroups** (control groups) | Control how much a process can **use** (CPU, memory, number of processes, disk I/O) | The fixed share of electricity |

Mnemonic: **Namespaces = what you See. cgroups = what you Consume.**

The main namespaces Docker uses:

- **pid**: the container sees its own process tree; its main process is PID 1.
- **net**: its own network interfaces, IP address and ports.
- **mnt**: its own filesystem view (built from the image).
- **uts**: its own hostname.
- **ipc**: its own shared-memory area.
- **user**: maps users inside to different users outside (used by rootless mode).

## See it work

```bash
# Inside a container, the process list contains only the container's processes
docker run --rm alpine:3.20 ps
```

Expected output:

```
PID   USER     TIME  COMMAND
    1 root      0:00 ps
```

The `ps` command is PID 1 and sees nothing else. That is the **pid namespace**.

```bash
# The container has its own hostname (the uts namespace)
docker run --rm alpine:3.20 hostname
```

Expected output: a random 12-character ID such as `5c1f0e2a9d3b` (the container ID).

```bash
# But the kernel is the host's own kernel: same version inside and outside
uname -r
docker run --rm alpine:3.20 uname -r
```

Both lines print the **same** kernel version. That is the "shared foundation".

On Linux you can even see the container from the host: run a long sleep and look for it.

```bash
docker run -d --name sleeper alpine:3.20 sleep 300
ps aux | grep "sleep 300"     # visible on the host as an ordinary process
docker rm -f sleeper
```

(On macOS and Windows, Docker Desktop runs a small Linux VM behind the scenes, so
you would see it inside that VM, not on your Mac.)

## Containers vs VMs at a glance

| | Container | Virtual machine |
|---|---|---|
| Kernel | Shares host kernel | Own guest kernel |
| Start time | Milliseconds to seconds | Tens of seconds to minutes |
| Size | MBs (just app + libs) | GBs (whole OS) |
| Isolation | Process-level; weaker | Hardware-level; stronger |
| Runs a different OS kernel? | No (Linux images need a Linux kernel) | Yes |

They are not rivals. In the cloud, containers usually run **inside** VMs.

## Try it

Your teammate says: "I set up a container with 2 GB of memory and it can only
see its own processes." Which kernel feature does each half of that sentence use?

<details>
<summary>Show answer</summary>

- "2 GB of memory" is a limit on consumption: **cgroups**.
- "only see its own processes" is a visibility rule: the **pid namespace**.

</details>

## Common mistakes

- **Assuming containers are as isolated as VMs.** A kernel bug affects every
  container on the host. That is why you run as non-root and drop privileges
  (Section 7).
- **Forgetting cgroup limits.** By default a container has **no** memory or CPU
  limit. One leaky container can slow down the whole host.
- **Expecting a Windows or macOS kernel inside a Linux container.** The image's
  userland (Alpine, Debian) changes, the kernel does not.

## Remember

- A container is a host process wrapped in **namespaces** (what it sees) and
  **cgroups** (what it uses).
- Containers share the host kernel; VMs bring their own.
- That is why containers are small and fast, and also why their isolation is weaker.
- No limits are set by default. You add them (Section 7).

**Self-check:**

1. Which kernel feature makes PID 1 inside a container?
2. Why does `uname -r` print the same value inside and outside a container?
3. Give one advantage of a VM over a container.
