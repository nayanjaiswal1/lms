---
kind: quiz
id_key: linux/under-the-hood/quiz
course: linux
section: under-the-hood
section_title: "Chapter 10: Under the Hood - Kernel, Namespaces and cgroups"
section_position: 10
title: "Quiz: Kernel, Namespaces and cgroups"
position: 4
estimated_minutes: 8
pass_percentage: 70
duration_minutes: 10
source:
  - Chapter 10 lessons, plus one review question from chapter 9
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "brewbot exits with only 'startup failed'. Which tool shows the exact file it tried to open and the error the kernel returned?"
    options:
      - text: "strace -f -e trace=file /opt/brewbot/bin/brewbot"
        correct: true
      - text: "top"
      - text: "lsblk"
      - text: "sysctl -a"
    explanation: "strace prints each system call with its result, such as openat(...) = -1 EACCES. top shows resource use, lsblk shows disks and sysctl lists kernel tunables."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You ran sudo sysctl -w net.core.somaxconn=4096 and it helped, but after a reboot the old value is back. What was missing?"
    options:
      - text: "A file in /etc/sysctl.d/ with the setting"
        correct: true
      - text: "systemctl daemon-reload"
      - text: "A reboot right after the change"
      - text: "chmod on /proc/sys"
    explanation: "sysctl -w changes the running kernel only. Files in /etc/sysctl.d/ are applied at every boot. daemon-reload is for unit files, and /proc/sys permissions are not the issue."
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Inside a container, ps shows your app as PID 1, but on the host it is PID 48213. Which kernel feature causes this?"
    options:
      - text: "A PID namespace"
        correct: true
      - text: "A cgroup memory limit"
      - text: "A virtual machine"
      - text: "The sticky bit"
    explanation: "A PID namespace gives the container its own process numbering. cgroups limit resources, a container is not a VM, and the sticky bit is a directory permission."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which statement about containers is correct?"
    options:
      - text: "Containers share the host's kernel; namespaces limit what they see and cgroups limit what they use"
        correct: true
      - text: "Each container runs its own kernel"
      - text: "Namespaces limit CPU and memory"
      - text: "cgroups hide other processes"
    explanation: "See = namespaces, Use = cgroups, one shared kernel. Separate kernels are what VMs provide, and the two features' roles are the other way round in the wrong options."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A container with a 512 MiB limit keeps dying with exit code 137 while the host has 20 GB free. What is happening?"
    options:
      - text: "It reaches its cgroup memory.max and the kernel OOM-kills it inside that group"
        correct: true
      - text: "The host is out of memory"
      - text: "Exit 137 means a normal shutdown"
      - text: "The container's disk is full"
    explanation: "Limits apply per cgroup, regardless of free host memory. 137 = 128 + SIGKILL. A disk-full error would appear as write failures, not SIGKILL."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You want a nightly import job to never use more than 20% of a CPU or 200 MB of RAM. What is the simplest systemd way to run it once?"
    options:
      - text: "sudo systemd-run --scope -p CPUQuota=20% -p MemoryMax=200M ./import.sh"
        correct: true
      - text: "nice -n 19 ./import.sh"
      - text: "ulimit -v 200 ./import.sh"
      - text: "taskset -c 0 ./import.sh"
    explanation: "systemd-run puts the command in its own cgroup with hard limits. nice only changes priority, ulimit -v limits virtual address space in KiB and is not a CPU limit, and taskset picks CPUs but not a share of them."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A minimal container image has no ss or curl. How can you list its listening ports from the host?"
    options:
      - text: "sudo nsenter -t <container PID> -n ss -tlnp"
        correct: true
      - text: "ss -tlnp on the host"
      - text: "lsns -t net"
      - text: "cat /sys/fs/cgroup/cpu.max"
    explanation: "nsenter -n enters the container's network namespace while using the host's ss. The host's own ss shows a different namespace, lsns only lists namespaces, and cpu.max is a CPU limit."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (chapter 9): a script must not run twice at the same time from cron. Which line protects it?"
    options:
      - text: "flock -n /tmp/import.lock /opt/import.sh in the crontab"
        correct: true
      - text: "set -euo pipefail"
      - text: "trap 'rm -f /tmp/x' EXIT"
      - text: "nohup /opt/import.sh &"
    explanation: "flock -n takes a lock or gives up immediately if another run holds it. set -euo pipefail handles errors, trap handles cleanup, and nohup only survives logout."
---
