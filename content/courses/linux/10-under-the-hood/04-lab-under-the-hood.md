---
kind: lesson
id_key: linux/under-the-hood/lab-inspect
course: linux
section: under-the-hood
section_title: "Chapter 10: Under the Hood - Kernel, Namespaces and cgroups"
section_position: 10
title: "Lab: Look Under Atlas's Hood"
position: 3
estimated_minutes: 20
source:
  - proc(5), namespaces(7), cgroups(7), sysctl(8), taskset(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 30
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    w=/home/labuser/work
    rm -rf $w/answers
    mkdir -p $w/answers
  tasks:
    - id_key: pid-namespace
      title: Which PID namespace am I in?
      points: 20
      is_stateful: true
      description: Save the inode number of your shell's PID namespace (only the digits inside pid:[...]) into /home/labuser/work/answers/pidns.txt.
      verification_script: |
        want=$(readlink /proc/self/ns/pid | tr -dc '0-9')
        [ -n "$want" ] && [ "$(tr -d '[:space:]' < /home/labuser/work/answers/pidns.txt)" = "$want" ]
      hint_context: readlink /proc/$$/ns/pid prints pid:[NUMBER]. tr -dc '0-9' keeps only the digits.
      explanation_context: Every namespace has an inode number. Processes that show the same number share that namespace and therefore see the same process list.
      solution_script: |
        readlink /proc/self/ns/pid | tr -dc '0-9' > /home/labuser/work/answers/pidns.txt
    - id_key: cgroup-memory
      title: What is my memory fence?
      points: 20
      is_stateful: true
      description: Find your cgroup (from /proc/self/cgroup) and save the contents of its memory.max file under /sys/fs/cgroup into answers/memory-max.txt (a number of bytes, or the word max if unlimited).
      verification_script: |
        cg=$(cut -d: -f3 /proc/self/cgroup | head -1)
        want=$(cat "/sys/fs/cgroup${cg%/}/memory.max" 2>/dev/null || echo none)
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/memory-max.txt)" = "$want" ]
      hint_context: cat /proc/self/cgroup shows 0::PATH. With PATH = / the file is /sys/fs/cgroup/memory.max.
      explanation_context: cgroup v2 exposes each group as a directory. memory.max is the limit the OOM killer enforces for the group; max means no limit at this level.
      solution_script: |
        cg=$(cut -d: -f3 /proc/self/cgroup | head -1)
        cat "/sys/fs/cgroup${cg%/}/memory.max" > /home/labuser/work/answers/memory-max.txt
    - id_key: read-sysctl
      title: Read a kernel tunable
      points: 20
      is_stateful: true
      description: Save the current value of the kernel setting kernel.pid_max (the highest PID number the kernel will hand out) into answers/pid-max.txt.
      verification_script: |
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/pid-max.txt)" = "$(cat /proc/sys/kernel/pid_max)" ]
      hint_context: sysctl -n kernel.pid_max, or cat /proc/sys/kernel/pid_max - dots in the name become slashes in the path.
      explanation_context: /proc/sys exposes kernel tunables as files. sysctl is a friendlier front end; writing needs root, reading does not.
      solution_script: |
        cat /proc/sys/kernel/pid_max > /home/labuser/work/answers/pid-max.txt
    - id_key: cpu-count
      title: How many CPUs may I use?
      points: 15
      is_stateful: true
      description: Save the number of CPUs available to your shell into answers/cpus.txt.
      verification_script: |
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/cpus.txt)" = "$(nproc)" ]
      hint_context: nproc prints the number of CPUs this process may run on.
      explanation_context: nproc respects CPU affinity, so inside a pinned container it can be smaller than the host's CPU count. CPU time quotas live in cpu.max instead.
      solution_script: |
        nproc > /home/labuser/work/answers/cpus.txt
    - id_key: pinned-worker
      title: Pin a worker to CPU 0
      points: 25
      is_stateful: true
      description: Start sleep 4001 in the background, surviving logout, allowed to run only on CPU 0.
      verification_script: |
        p=$(pgrep -u labuser -f '^sleep 4001$' | head -1)
        [ -n "$p" ] && [ "$(taskset -cp $p | awk -F': ' '{print $2}' | tr -d ' ')" = 0 ]
      hint_context: taskset -c 0 COMMAND starts a command on CPU 0. Combine with nohup and an ampersand.
      explanation_context: CPU affinity is a per-process mask the scheduler respects. cgroups (cpuset) can enforce the same for a whole group, which is how container runtimes pin workloads.
      solution_script: |
        nohup taskset -c 0 sleep 4001 >/dev/null 2>&1 &
        sleep 1
---

## Why this matters

You have read about system calls, namespaces and cgroups. Now find them on a
real machine. This lab runs inside a container, so you are looking at exactly
the fences and glasses a container gets. Each task is checked automatically.

## Before you start

```bash
cat /proc/self/cgroup
ls -l /proc/self/ns
hostname
```

What this does: shows your cgroup, your namespaces, and a hostname that is
clearly not "atlas": the uts namespace at work.

## Task 1: which PID namespace am I in?

Save the inode number of your shell's PID namespace (only the digits) into
`~/work/answers/pidns.txt`.

[[lab-task:1]]

## Task 2: what is my memory fence?

Find your cgroup and save the contents of its `memory.max` into
`answers/memory-max.txt`.

[[lab-task:2]]

## Task 3: read a kernel tunable

Save the value of `kernel.pid_max` into `answers/pid-max.txt`.

[[lab-task:3]]

## Task 4: how many CPUs may I use?

Save the number of CPUs available to your shell into `answers/cpus.txt`.

[[lab-task:4]]

## Task 5: pin a worker to CPU 0

Start `sleep 4001` in the background, surviving logout, allowed to run only on
CPU 0.

[[lab-task:5]]

Check yourself:

```
$ taskset -cp $(pgrep -f '^sleep 4001$')
pid 87's current affinity list: 0
```

## Remember

- `/proc/self/ns/*` = your namespaces; `/proc/self/cgroup` = your group.
- `/sys/fs/cgroup/.../memory.max`, `cpu.max`, `pids.max` = your fences.
- `/proc/sys` and `sysctl` = kernel tunables.
- `taskset -c` pins CPUs; `nproc` respects it.
