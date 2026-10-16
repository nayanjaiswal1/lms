---
kind: lesson
id_key: linux/under-the-hood/namespaces
course: linux
section: under-the-hood
section_title: "Chapter 10: Under the Hood - Kernel, Namespaces and cgroups"
section_position: 10
title: "Namespaces: How Containers See Their Own World"
position: 1
estimated_minutes: 8
source:
  - namespaces(7), pid_namespaces(7), user_namespaces(7), unshare(1), nsenter(1), lsns(8) manual pages
---

## Why this matters

Inside a container, `ps` shows three processes, PID 1 is your app, and the
hostname is a random string. On the host, the same app is PID 48213. Knowing why
lets you debug containers from the outside, and understand what isolation they
do and do not give.

## Mental model: tinted glasses

A **namespace** is a pair of tinted glasses the kernel puts on a process. With
them on, the process sees only its own slice of one kind of resource. Nothing is
virtualised; it is the same kernel, just filtered views.

| Namespace | The process sees its own... |
|---|---|
| `pid` | process numbers (it can be PID 1) |
| `mnt` | mount points and filesystem tree |
| `net` | network interfaces, IPs, ports, routes |
| `uts` | hostname |
| `ipc` | shared memory and message queues |
| `user` | user IDs (root inside can be nobody outside) |
| `cgroup` | view of the cgroup tree |
| `time` | some clocks |

```
 HOST view:  systemd(1) ... containerd ... brewbot(48213)
                                             |
 CONTAINER view (pid namespace):          brewbot(1)
```

> **Memory hook:** **namespaces = what you can SEE; cgroups = how much you can
> USE** (next lesson). A container is a process with both, plus a filesystem.

## See it work

Every process's namespaces are links in `/proc/PID/ns`. Two processes share a
namespace when the numbers match.

```bash
ls -l /proc/self/ns
```

Expected output (abridged, numbers differ):

```
lrwxrwxrwx 1 labuser labuser 0 ... mnt -> mnt:[4026532564]
lrwxrwxrwx 1 labuser labuser 0 ... net -> net:[4026533025]
lrwxrwxrwx 1 labuser labuser 0 ... pid -> pid:[4026533023]
lrwxrwxrwx 1 labuser labuser 0 ... uts -> uts:[4026532565]
```

```bash
readlink /proc/$$/ns/pid       # just one
lsns                           # all namespaces you can see, with a process in each
```

The lab itself runs in a container, so `ps aux` shows only a few processes and
`hostname` prints a random ID: you are wearing the glasses right now.

### Making namespaces (on your own Linux machine)

```bash
sudo unshare --uts --pid --fork --mount-proc bash
hostname sandbox      # changes the hostname only inside
ps aux                # only bash and ps: PID 1 is your bash
exit
```

`unshare` starts a program in new namespaces. Rootless containers use the
`user` namespace so an unprivileged user can be "root" inside
(`unshare -r` maps you to UID 0 there). This needs the kernel and host to allow
it, so it fails in many locked-down environments, including this lab.

### Stepping into a container from the host

```bash
pid=$(docker inspect -f '{{.State.Pid}}' web)    # the container's PID on the host
sudo nsenter -t "$pid" -n ss -tlnp                # run ss inside its network namespace
```

`nsenter` borrows another process's glasses. With `-n` you get the container's
network view while still using the host's tools: handy for minimal images that
have no `ss` or `curl`.

### What namespaces do not do

- They do not limit CPU or memory (that is cgroups).
- All containers share **one kernel**. A kernel bug can break out; that is why
  untrusted workloads use extra layers (seccomp, AppArmor/SELinux, gVisor,
  micro-VMs).

## Try it

Process A shows `net:[4026533025]` and process B shows `net:[4026531840]`. What
does that tell you about `ss -tln` run as each of them?

<details>
<summary>Show answer</summary>

They are in different network namespaces, so each sees its own interfaces and
listening ports. A service listening in B's namespace does not appear in A's
`ss` output, and `localhost` means something different for each.

</details>

## Common mistakes

- **Thinking a container is a small VM.** It is a process on the host kernel with
  filtered views.
- **Debugging container networking from the host's view.** Use `nsenter -n` or
  `docker exec` to see the container's own interfaces.
- **Assuming root in a container is harmless.** Without a user namespace, UID 0
  inside is UID 0 on the host, held back only by dropped capabilities and other
  layers.

## Remember

- Namespaces filter what a process sees: pid, mnt, net, uts, ipc, user, cgroup,
  time.
- `/proc/PID/ns/*` and `lsns` show them; same number = shared.
- `unshare` creates them, `nsenter` enters them.
- See (namespaces) vs Use (cgroups); one shared kernel.

**Self-check:**

1. Which namespace lets a container have its own PID 1?
2. How can you tell if two processes share a network namespace?
3. What does `nsenter -t PID -n` give you?
