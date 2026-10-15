---
kind: lesson
id_key: linux/engine-room/lesson
course: linux
section: engine-room
section_title: "Chapter 5: The Engine Room"
section_position: 5
title: Processes, Jobs, Signals and Resources
position: 0
estimated_minutes: 45
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

> **Friday morning.** Atlas feels slow. Rhea: "A server is never doing just one thing - right now it's running hundreds of programs. Find out who is using the engine." Welcome to the engine room.

## What a process is

A **program** is a file on disk (`/usr/bin/sleep`). A **process** is a running copy of it, with:

- a **PID** (process ID) and a **PPID** (its parent's PID)
- an owner (the user it runs as)
- memory, open files, a current directory, environment variables
- a **state**: `R` running, `S` sleeping (waiting), `D` uninterruptible (usually waiting on disk), `T` stopped, `Z` zombie

Every process is started by another one, forming a family tree. At the top is **PID 1** - on a real server that is **systemd**, the ancestor of everything.

```
systemd (1)
 |-- sshd (812)
 |    `-- sshd (2210) -- bash (2211) -- ps (2300)    <- you
 |-- nginx (901) --+-- nginx worker (902)
 |                 `-- nginx worker (903)
 `-- brewbot (1040)
```

```bash
ps                  # processes in this terminal
ps aux              # every process: USER PID %CPU %MEM ... COMMAND
ps -ef --forest     # tree view
pstree -p           # family tree with PIDs (if installed)
pgrep -a nginx      # find processes by name
pidof nginx         # just the PIDs
```

> **Memory hook:** the program is the **recipe**, the process is the **coffee being made** right now. One recipe, many cups - each with its own order number (PID).

[[lab-task:1]]

## Watching resources

```bash
top                 # live view: q quit, P sort by CPU, M by memory, k kill
htop                # friendlier top, if installed
uptime              # load average over 1, 5 and 15 minutes
free -h             # memory: total, used, free, available
vmstat 1            # CPU, memory, IO every second
nproc               # number of CPUs
```

Reading `uptime`:

```
 10:42:01 up 12 days,  3 users,  load average: 3.90, 2.10, 1.05
                                                1 min  5 min  15 min
```

The load average is the number of processes running or waiting. Compare it with `nproc`: **load 4 on 4 CPUs = fully busy**; load 8 on 4 CPUs = a queue is forming. Rising left-to-right numbers (1.05 -> 3.90) mean it is getting worse.

In `free -h`, look at **available**, not free - Linux uses spare memory as disk cache and gives it back when needed. "Free memory is wasted memory."

## Foreground, background and jobs

```bash
sleep 300           # foreground: the shell waits
Ctrl+Z              # suspend it (state T)
bg                  # resume it in the background
jobs                # list this shell's jobs: [1]+ Running sleep 300 &
fg %1               # bring job 1 back to the foreground
sleep 300 &         # start directly in the background
nohup ./backup.sh &         # survive terminal close (ignores SIGHUP)
```

For long work on remote servers use `tmux` or `screen`: they keep a whole session alive when your SSH connection drops.

[[lab-task:2]]

## Priorities: nice and renice

```
  -20 ......... 0 ......... 19
  greedy     default     polite
```

```bash
nice -n 10 ./backup.sh          # start with lower priority
renice -n 5 -p 1234             # change a running process
sudo renice -n -5 -p 1234       # only root may raise priority
```

> **Memory hook:** the **nicer** you are, the **longer** you wait in the queue. Root is the only one allowed to cut in line (negative nice).

[[lab-task:3]]

[[lab-task:4]]

What you should see:

```
$ ps -o pid,ni,cmd -C sleep
  PID  NI CMD
  412   5 sleep 3001
  418  15 sleep 3002
```

## Signals: talking to processes

A signal is a tiny message from the kernel or another process.

| Signal | Number | Meaning | Can be caught? |
|---|---|---|---|
| SIGHUP | 1 | terminal closed / "reload your config" | yes |
| SIGINT | 2 | Ctrl+C | yes |
| SIGKILL | 9 | die now | **no** |
| SIGTERM | 15 | please exit cleanly (default for `kill`) | yes |
| SIGSTOP | 19 | pause (Ctrl+Z sends SIGTSTP, 20) | no |
| SIGCONT | 18 | resume | yes |

```bash
kill 1234           # SIGTERM - polite
kill -9 1234        # SIGKILL - last resort, no cleanup
kill -HUP 1234      # many daemons (nginx) reload config on HUP
pkill -f brewbot    # by name / command line
killall nginx       # every process with that name
kill -l             # list all signals
```

> **Memory hook:** **15 asks, 9 insists.** "Fifteen is a friend, nine is the end." Always send 15, wait a few seconds, and use 9 only if the process ignores you - SIGKILL can leave half-written files and stale lock files behind.

**Zombies** (`Z`) are processes that have exited but whose parent never collected their exit status. They use no CPU or memory, only a PID slot. You cannot kill a zombie - it is already dead. Fix or restart the **parent**.

[[lab-task:5]]

## /proc: the live order screen

Every process is a directory in `/proc`:

```bash
ls /proc/1234/
cat /proc/1234/cmdline | tr '\0' ' '   # full command line
cat /proc/1234/status                  # state, memory, threads
ls -l /proc/1234/fd                    # open files
ls -l /proc/1234/cwd                   # current directory
cat /proc/loadavg /proc/meminfo        # system-wide numbers
```

Tools like `ps`, `top` and `free` are just reading these files for you.

> **End of day 5.** You found a forgotten backup job hogging the CPU, reniced it, and stopped an old worker politely. Rhea nods: "Good. Tonight you see who keeps atlas running while we sleep." Tom's note on the engine room door: "Services, logs, and the clock."
