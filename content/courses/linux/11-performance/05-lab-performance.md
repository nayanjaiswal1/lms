---
kind: lesson
id_key: linux/performance/lab-triage
course: linux
section: performance
section_title: "Chapter 11: Performance Triage"
section_position: 11
title: "Lab: Why Is Atlas Slow?"
position: 4
estimated_minutes: 25
source:
  - top(1), ps(1), vmstat(8), free(1), renice(1), kill(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 40
  max_resets: 3
  is_required: false
  workspace_layout: console
  files:
    - path: start-load.sh
      content: |
        #!/bin/bash
        # Starts the slow-atlas scenario. Run once: bash ~/work/start-load.sh
        set -euo pipefail
        w=/home/labuser/work/perf
        mkdir -p $w/bin
        cat > $w/bin/report-builder <<'EOF'
        #!/bin/bash
        # a report job stuck in a busy loop
        end=$((SECONDS + 1800))
        while [ $SECONDS -lt $end ]; do :; done
        EOF
        cat > $w/bin/cache-warmer.py <<'EOF'
        import time
        cache = bytearray(120 * 1024 * 1024)   # holds 120 MiB
        for i in range(0, len(cache), 4096):
            cache[i] = 1
        time.sleep(1800)
        EOF
        chmod 755 $w/bin/report-builder
        nohup bash $w/bin/report-builder >/dev/null 2>&1 &
        nohup python3 $w/bin/cache-warmer.py >/dev/null 2>&1 &
        nohup sleep 1800 >/dev/null 2>&1 &
        sleep 2
        touch $w/.load-started
        echo "PAGER: atlas is slow. Find out why."
  setup_script: |
    pkill -u labuser -f '[p]erf/bin/' || true
    rm -rf /home/labuser/work/perf /home/labuser/work/answers
    mkdir -p /home/labuser/work/answers
  tasks:
    - id_key: start-load
      title: The pager goes off
      points: 10
      is_stateful: true
      description: Run bash /home/labuser/work/start-load.sh once to start the scenario.
      verification_script: |
        [ -f /home/labuser/work/perf/.load-started ] &&
        pgrep -u labuser -f '^bash /home/labuser/work/perf/bin/report-builder$' >/dev/null &&
        pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' >/dev/null
      hint_context: Type exactly bash /home/labuser/work/start-load.sh and press Enter.
      explanation_context: The script starts a CPU-hungry report job, a memory-hungry cache warmer and one idle process, so you can practise finding each with the right tool.
      solution_script: |
        bash /home/labuser/work/start-load.sh
    - id_key: cpu-hog
      title: Who is eating the CPU?
      points: 20
      is_stateful: true
      description: Find the program using the most CPU and save its program name (the file name of the script, for example backup-runner) into /home/labuser/work/answers/cpu-hog.txt.
      verification_script: |
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/cpu-hog.txt)" = report-builder ]
      hint_context: top then P, or ps aux --sort=-%cpu | head -3. The COMMAND column shows bash followed by the script path; you want the script's name.
      explanation_context: The %CPU column near 100 means one full core. A bash process at 100% running a script is the script's loop, so the script is the program to name.
      solution_script: |
        echo report-builder > /home/labuser/work/answers/cpu-hog.txt
    - id_key: calm-cpu
      title: Make it step aside
      points: 20
      is_stateful: true
      description: Without killing it, give the report-builder process the lowest possible CPU priority (niceness 19).
      verification_script: |
        p=$(pgrep -u labuser -f '^bash /home/labuser/work/perf/bin/report-builder$' | head -1)
        [ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 19 ]
      hint_context: renice -n 19 -p PID. pgrep -f report-builder prints the PID.
      explanation_context: A niced process still runs, but only on CPU time other processes do not want, so the web shop gets served first. Killing a report job may lose work; renicing buys time.
      solution_script: |
        renice -n 19 -p $(pgrep -u labuser -f '^bash /home/labuser/work/perf/bin/report-builder$')
    - id_key: mem-hog
      title: Who is holding the memory?
      points: 25
      is_stateful: true
      description: Find the process with the largest resident memory (RSS) and save its PID into answers/mem-hog-pid.txt.
      verification_script: |
        want=$(pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' | head -1)
        [ -n "$want" ] && [ "$(tr -d '[:space:]' < /home/labuser/work/answers/mem-hog-pid.txt)" = "$want" ]
      hint_context: ps aux --sort=-rss | head -3, or top then M. RSS (RES in top) is real memory in use; ignore VSZ.
      explanation_context: RSS is the RAM a process really holds. Sorting by it finds memory users quickly; VSZ includes mapped but unused address space.
      solution_script: |
        ps -u labuser -o pid=,rss= --sort=-rss | head -1 | awk '{print $1}' > /home/labuser/work/answers/mem-hog-pid.txt
    - id_key: stop-mem-hog
      title: Stop the memory hog politely
      points: 25
      is_stateful: true
      description: Stop the cache-warmer process with SIGTERM (not SIGKILL) and confirm it is gone.
      verification_script: |
        [ -f /home/labuser/work/perf/.load-started ] &&
        ! pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$' >/dev/null
      hint_context: kill PID (the PID you saved in the previous task) sends SIGTERM. pgrep -f cache-warmer should then print nothing.
      explanation_context: SIGTERM lets the program exit cleanly and the kernel frees its memory at once. Check free -h before and after - available memory goes up by about 120 MiB.
      solution_script: |
        kill $(pgrep -u labuser -f '^python3 /home/labuser/work/perf/bin/cache-warmer.py$')
        sleep 1
---

## Why this matters

The pager says atlas is slow. Instead of restarting things at random, you will
measure, find the CPU hog and the memory hog, and deal with each the right way.
Each task is checked automatically.

## Before you start

Take a baseline first, so you can compare:

```bash
uptime
free -h
```

## Task 1: the pager goes off

Run `bash ~/work/start-load.sh` once.

[[lab-task:1]]

Now run the first-60-seconds commands again:

```bash
uptime
vmstat 1 3
free -h
```

The 1-minute load starts rising; `vmstat` shows a runnable process (`r`) and
high `us`.

## Task 2: who is eating the CPU?

Find the program using the most CPU and save its name into
`~/work/answers/cpu-hog.txt`.

[[lab-task:2]]

What you should see (abridged):

```
$ ps aux --sort=-%cpu | head -2
USER   PID %CPU %MEM ... COMMAND
labuser 41 99.6  0.0 ... bash /home/labuser/work/perf/bin/report-builder
```

## Task 3: make it step aside

Give `report-builder` niceness 19 without killing it.

[[lab-task:3]]

## Task 4: who is holding the memory?

Find the process with the largest RSS and save its PID into
`answers/mem-hog-pid.txt`.

[[lab-task:4]]

## Task 5: stop the memory hog politely

Stop `cache-warmer` with SIGTERM and confirm it is gone. Run `free -h` again:
`available` should be about 120 MiB higher.

[[lab-task:5]]

## Remember

- Baseline first: `uptime`, `free -h`, `vmstat 1`.
- CPU: `top` + `P` or `ps --sort=-%cpu`; tame with `renice -n 19`.
- Memory: `top` + `M` or `ps --sort=-rss`; RSS, not VSZ.
- 15 before 9, and measure again after every change.

> **End of week 2.** You found the report job and the cache warmer, calmed one
> and stopped the other, and atlas is fast again. Rhea: "Last thing before Black
> Friday: lock atlas down." Tom's note: "Every open door is a risk."
