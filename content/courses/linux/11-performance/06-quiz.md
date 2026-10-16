---
kind: quiz
id_key: linux/performance/quiz
course: linux
section: performance
section_title: "Chapter 11: Performance Triage"
section_position: 11
title: "Quiz: Performance Triage"
position: 5
estimated_minutes: 8
pass_percentage: 70
duration_minutes: 10
source:
  - Chapter 11 lessons, plus one review question from chapter 10
questions:
  - id_key: q1
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "uptime shows a load average of 12 on a 4-CPU server, but top shows the CPUs mostly idle with a high wa value. What is going on?"
    options:
      - text: "Processes are blocked waiting on disk IO, which counts toward load"
        correct: true
      - text: "The load average is broken and should be ignored"
      - text: "The server has too much free memory"
      - text: "Twelve users are logged in"
    explanation: "Linux load counts processes running or waiting, including uninterruptible (D state) disk waits. High wa means the disk, not the CPU, is the bottleneck. Load is not broken, free memory does not raise load, and users are not counted."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "free -h shows free 180Mi and available 3.2Gi, and vmstat shows si 0 so 0. What do you conclude?"
    options:
      - text: "Memory is fine; the kernel is using spare RAM as cache it can reclaim"
        correct: true
      - text: "The server is about to run out of memory"
      - text: "Swap is broken"
      - text: "You must drop caches every hour"
    explanation: "available counts reclaimable cache, and no swapping means no pressure. Low free alone is normal, swap is idle not broken, and dropping caches only makes reads slower."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A worker disappeared overnight with nothing in its own log. What do you check first?"
    options:
      - text: "dmesg -T | grep -i 'killed process' (the OOM killer)"
        correct: true
      - text: "The crontab"
      - text: "iostat"
      - text: "/etc/hosts"
    explanation: "The OOM killer sends SIGKILL, so the victim cannot log anything; the kernel logs it instead. Cron, disk statistics and name resolution do not explain a silent kill."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which column do you sort by to find the process really using the most RAM?"
    options:
      - text: "RSS (RES in top)"
        correct: true
      - text: "VSZ"
      - text: "TIME"
      - text: "PID"
    explanation: "RSS is resident memory in use. VSZ includes mapped but unused address space, TIME is CPU time, and PID is just an ID."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "top shows total CPU at 25% on a 4-core server, yet one request type is very slow and its process shows %CPU 100. What is likely?"
    options:
      - text: "A single-threaded bottleneck: one core is saturated while the others idle"
        correct: true
      - text: "The CPU is underused, so it cannot be CPU-related"
      - text: "The disk is full"
      - text: "Swap is too small"
    explanation: "100% in top is one full core; on 4 cores that is 25% total. mpstat -P ALL shows it clearly. Disk and swap would show up as wa or si/so instead."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "iostat -xz 1 shows the data disk with w_await 60 ms, aqu-sz 30 and %util 99 during a backup at noon. Best quick mitigation?"
    options:
      - text: "Lower the backup's IO priority with ionice -c3 (and move it off-peak)"
        correct: true
      - text: "renice -n -20 the backup"
      - text: "kill -9 every process in D state"
      - text: "Add more CPUs"
    explanation: "The disk is saturated; idle IO class lets the shop's IO go first. Raising the backup's priority makes it worse, D-state processes do not die from SIGKILL until IO completes, and CPUs are not the bottleneck."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "In the USE method, what does Saturation mean?"
    options:
      - text: "Work is queuing for the resource (e.g. run queue above CPU count, swapping, disk queue)"
        correct: true
      - text: "The resource is 100% utilised"
      - text: "The resource is returning errors"
      - text: "The resource is unused"
    explanation: "Saturation is waiting work, which is what users feel as slowness. Utilization is how busy it is and Errors are failures; a resource can be 100% utilised without a queue."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (chapter 10): brewbot should never use more than 1 GiB of RAM, so a leak kills brewbot rather than the database. What do you add to its unit?"
    options:
      - text: "MemoryMax=1G in [Service]"
        correct: true
      - text: "Nice=19"
      - text: "Restart=no"
      - text: "After=postgresql.service"
    explanation: "MemoryMax sets the cgroup limit, so the OOM killer acts inside brewbot's group. Nice changes CPU priority, Restart controls restarts, and After only orders startup."
---
