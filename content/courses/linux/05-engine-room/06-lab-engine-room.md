---
kind: lesson
id_key: linux/engine-room/lesson
course: linux
section: engine-room
section_title: "Chapter 5: The Engine Room - Processes"
section_position: 5
title: "Lab: Run the Engine Room"
position: 5
estimated_minutes: 20
source:
  - ps(1), top(1), kill(1), signal(7), nice(1), renice(1), proc(5), free(1) manual pages
  - GNU Bash Reference Manual, "Job Control"
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 45
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    w=/home/labuser/work
    rm -rf $w/answers
    mkdir -p $w/answers
  tasks:
    - id_key: pid-one
      title: Who is process number one?
      points: 15
      is_stateful: true
      description: Look in /proc and save the name of the process with PID 1 into answers/pid1.txt.
      verification_script: |
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/pid1.txt)" = "$(cat /proc/1/comm)" ]
      hint_context: Every process has a directory /proc/PID. The file comm inside it holds the process name. ps -p 1 -o comm= works too.
      explanation_context: PID 1 is the first process the kernel starts. On a full server it is systemd; inside a container it is whatever the image's entrypoint is.
      solution_script: |
        cat /proc/1/comm > /home/labuser/work/answers/pid1.txt
    - id_key: survive-logout
      title: A worker that survives logout
      points: 20
      is_stateful: true
      description: Start the command sleep 3001 in the background so it keeps running even if your terminal is closed.
      verification_script: |
        pgrep -u labuser -f '^sleep 3001$' >/dev/null
      hint_context: An ampersand at the end runs a command in the background. Prefix it with nohup so it ignores the hangup signal sent when the terminal closes.
      explanation_context: When a terminal closes, its processes receive SIGHUP and usually die. nohup makes the process ignore SIGHUP and sends its output to nohup.out.
      solution_script: |
        nohup sleep 3001 >/dev/null 2>&1 &
    - id_key: low-priority
      title: Run a low-priority job
      points: 20
      is_stateful: true
      description: Start sleep 3002 in the background with a niceness of 15, so it only gets CPU time nobody else wants.
      verification_script: |
        p=$(pgrep -u labuser -f '^sleep 3002$' | head -1)
        [ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 15 ]
      hint_context: nice -n 15 COMMAND starts a command with niceness 15. Add an ampersand to background it.
      explanation_context: Niceness runs from -20 (greedy) to 19 (polite). Higher niceness means lower priority. Normal users can only make processes nicer, never greedier.
      solution_script: |
        nohup nice -n 15 sleep 3002 >/dev/null 2>&1 &
    - id_key: renice-it
      title: Change priority on the fly
      points: 20
      is_stateful: true
      description: Without restarting it, change the niceness of the running sleep 3001 process to 5.
      verification_script: |
        p=$(pgrep -u labuser -f '^sleep 3001$' | head -1)
        [ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 5 ]
      hint_context: Find the PID with pgrep -f 'sleep 3001' or ps aux | grep sleep, then renice -n 5 -p PID.
      explanation_context: renice changes the priority of a process that is already running - handy when a backup job starts slowing down the web server.
      solution_script: |
        renice -n 5 -p $(pgrep -u labuser -f '^sleep 3001$' | head -1)
    - id_key: polite-kill
      title: Stop a process politely
      points: 25
      is_stateful: true
      description: Stop the sleep 3002 process with the polite termination signal (not the forceful one), then save the number of the signal you sent into answers/signal.txt.
      verification_script: |
        ! pgrep -u labuser -f '^sleep 3002$' >/dev/null &&
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/signal.txt)" = 15 ]
      hint_context: kill PID sends SIGTERM by default. kill -l lists every signal with its number.
      explanation_context: SIGTERM (15) asks a process to clean up and exit. SIGKILL (9) cannot be caught - the kernel removes the process immediately, with no chance to save data. Always try 15 first.
      solution_script: |
        pkill -TERM -u labuser -f '^sleep 3002$'
        echo 15 > /home/labuser/work/answers/signal.txt
---

## Why this matters

A forgotten backup job is hogging atlas and an old worker refuses to leave.
In this lab you find PID 1, start jobs that survive logout, change priorities and
stop a process politely. Each task is checked automatically.

## Before you start

```bash
ps aux
echo $$
```

What this does: lists every process and prints your shell's PID, so you know
which line is you.

## Task 1: who is process number one?

Using `/proc`, save the name of the process with PID 1 into
`~/work/answers/pid1.txt`.

[[lab-task:1]]

## Task 2: a worker that survives logout

Start `sleep 3001` in the background so it keeps running even if your terminal
is closed.

[[lab-task:2]]

## Task 3: run a low-priority job

Start `sleep 3002` in the background with a niceness of 15.

[[lab-task:3]]

## Task 4: change priority on the fly

Without restarting it, change the niceness of the running `sleep 3001` to 5.

[[lab-task:4]]

What you should see:

```
$ ps -o pid,ni,cmd -C sleep
  PID  NI CMD
  412   5 sleep 3001
  418  15 sleep 3002
```

## Task 5: stop a process politely

Stop `sleep 3002` with the polite termination signal (not the forceful one),
then save the number of the signal you sent into `answers/signal.txt`.

[[lab-task:5]]

## Remember

- `/proc/PID/comm` names a process; `pgrep -a` finds one.
- `nohup CMD &` survives logout; `nice -n` / `renice -n` set politeness.
- 15 asks, 9 insists.

> **End of day 5.** You found a forgotten backup job hogging the CPU, reniced
> it, and stopped an old worker politely. Rhea nods: "Good. Tonight you see who
> keeps atlas running while we sleep." Tom's note on the engine room door:
> "Services, logs, and the clock."
