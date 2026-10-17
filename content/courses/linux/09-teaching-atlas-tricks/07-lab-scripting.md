---
kind: lesson
id_key: linux/teaching-atlas-tricks/lesson
course: linux
section: teaching-atlas-tricks
section_title: "Chapter 9: Teaching Atlas Tricks - Bash Scripting"
section_position: 9
title: "Lab: Teach Atlas Its Chores"
position: 6
estimated_minutes: 35
source:
  - GNU Bash Reference Manual (gnu.org/software/bash/manual)
  - bash(1), test(1), date(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 60
  max_resets: 3
  is_required: false
  workspace_layout: console
  files:
    - path: scripts/services.txt
      content: |
        nginx running
        brewbot stopped
        postgres running
        redis failed
        cron running
  setup_script: |
    rm -rf /home/labuser/work/scripts/reports /tmp/vb-src /tmp/vb-dest
  tasks:
    - id_key: reports-loop
      title: Five reports with one loop
      points: 15
      is_stateful: true
      description: Using a for loop at the prompt, create the directory /home/labuser/work/scripts/reports containing report-1.txt to report-5.txt, where each file holds one line "Report N" (Report 1, Report 2, ...).
      verification_script: |
        d=/home/labuser/work/scripts/reports
        for n in 1 2 3 4 5; do [ "$(cat $d/report-$n.txt)" = "Report $n" ] || exit 1; done
      hint_context: "mkdir -p the directory, then: for n in 1 2 3 4 5; do echo \"Report $n\" > DIR/report-$n.txt; done - or use {1..5} instead of listing the numbers."
      explanation_context: A for loop repeats a command for each word in a list. {1..5} is brace expansion that generates 1 2 3 4 5 before the loop even runs.
      solution_script: |
        mkdir -p /home/labuser/work/scripts/reports
        for n in {1..5}; do echo "Report $n" > /home/labuser/work/scripts/reports/report-$n.txt; done
    - id_key: greet-script
      title: Your first real script
      points: 25
      is_stateful: true
      description: >-
        Write the executable script /home/labuser/work/scripts/greet.sh. It must
        start with a bash shebang and have set -euo pipefail in its first lines.
        greet.sh Rhea prints exactly "Hello, Rhea! Welcome to Atlas.". Run with no
        argument, it prints a message containing the word Usage to stderr and exits
        with status 1.
      verification_script: |
        s=/home/labuser/work/scripts/greet.sh
        [ -x $s ] && head -1 $s | grep -q '^#!.*bash' && head -5 $s | grep -q 'set -euo pipefail' &&
        [ "$($s Rhea)" = "Hello, Rhea! Welcome to Atlas." ] &&
        [ -z "$($s 2>/dev/null)" ] && $s 2>&1 >/dev/null | grep -q Usage || exit 1
        $s >/dev/null 2>&1; [ $? -eq 1 ]
      hint_context: Check the argument count with if [ $# -lt 1 ]. echo "..." >&2 writes to stderr, and exit 1 sets the status. Do not forget chmod +x.
      explanation_context: $# is the argument count and $1 the first argument. Errors go to stderr and a non-zero exit status, so callers and pipelines can tell success from failure.
      solution_script: |
        cat > /home/labuser/work/scripts/greet.sh <<'EOF'
        #!/bin/bash
        set -euo pipefail
        if [ $# -lt 1 ]; then
          echo "Usage: greet.sh NAME" >&2
          exit 1
        fi
        echo "Hello, $1! Welcome to Atlas."
        EOF
        chmod +x /home/labuser/work/scripts/greet.sh
    - id_key: check-services
      title: A service watchdog
      points: 30
      is_stateful: true
      description: >-
        Write the executable script /home/labuser/work/scripts/check-services.sh. It
        takes a file name as its argument, where each line is "NAME STATUS" (see
        scripts/services.txt). For every service whose status is not running it
        prints "ALERT: NAME is STATUS", in file order. Its exit status is the number
        of services that are not running (0 when everything is fine).
      verification_script: |
        s=/home/labuser/work/scripts/check-services.sh
        [ -x $s ] || exit 1
        out=$($s /home/labuser/work/scripts/services.txt); rc=$?
        [ $rc -eq 2 ] && [ "$out" = "$(printf 'ALERT: brewbot is stopped\nALERT: redis is failed')" ] || exit 1
        printf 'a running\nb running\n' > /tmp/vb-ok.txt
        out=$($s /tmp/vb-ok.txt); rc=$?
        rm -f /tmp/vb-ok.txt
        [ $rc -eq 0 ] && [ -z "$out" ]
      hint_context: "while read -r name status; do ... done < \"$1\" reads the file line by line into two variables. Keep a counter with down=$((down + 1)) and finish with exit $down."
      explanation_context: while read is the standard way to process a file line by line. Using the exit status as a count lets other tools (cron, monitoring) react without parsing the output.
      solution_script: |
        cat > /home/labuser/work/scripts/check-services.sh <<'EOF'
        #!/bin/bash
        set -euo pipefail
        down=0
        while read -r name status; do
          [ -z "$name" ] && continue
          if [ "$status" != running ]; then
            echo "ALERT: $name is $status"
            down=$((down + 1))
          fi
        done < "$1"
        exit $down
        EOF
        chmod +x /home/labuser/work/scripts/check-services.sh
    - id_key: backup-script
      title: The backup script Rhea asked for
      points: 30
      is_stateful: true
      description: >-
        Write the executable script /home/labuser/work/scripts/backup.sh taking
        SRC_DIR and DEST_DIR. It creates DEST_DIR if needed and writes
        DEST_DIR/NAME-YYYYMMDD.tar.gz, where NAME is the last part of SRC_DIR and
        YYYYMMDD is today's date. If SRC_DIR is not an existing directory it prints
        an error to stderr and exits with status 2.
      verification_script: |
        s=/home/labuser/work/scripts/backup.sh
        [ -x $s ] || exit 1
        rm -rf /tmp/vb-src /tmp/vb-dest && mkdir -p /tmp/vb-src && echo beans > /tmp/vb-src/a.txt
        $s /tmp/vb-src /tmp/vb-dest >/dev/null 2>&1 || exit 1
        f=/tmp/vb-dest/vb-src-$(date +%Y%m%d).tar.gz
        [ -f $f ] && tar -tzf $f | grep -q 'a.txt' || exit 1
        $s /tmp/no-such-dir /tmp/vb-dest >/dev/null 2>&1; rc=$?
        rm -rf /tmp/vb-src /tmp/vb-dest
        [ $rc -eq 2 ]
      hint_context: name=$(basename "$1") and today=$(date +%Y%m%d) build the file name. Test the source with if [ ! -d "$1" ]. tar -czf "$out" -C "$(dirname "$1")" "$name" keeps the paths short.
      explanation_context: Command substitution $(...) captures a command's output into a variable. Quoting every "$variable" keeps the script working when paths contain spaces.
      solution_script: |
        cat > /home/labuser/work/scripts/backup.sh <<'EOF'
        #!/bin/bash
        set -euo pipefail
        src=${1:-}
        dest=${2:-}
        if [ ! -d "$src" ] || [ -z "$dest" ]; then
          echo "Usage: backup.sh SRC_DIR DEST_DIR (SRC_DIR must exist)" >&2
          exit 2
        fi
        mkdir -p "$dest"
        name=$(basename "$src")
        out="$dest/$name-$(date +%Y%m%d).tar.gz"
        tar -czf "$out" -C "$(dirname "$src")" "$name"
        echo "$out"
        EOF
        chmod +x /home/labuser/work/scripts/backup.sh
---

## Why this matters

Time to make atlas do your chores. You write a loop, a script with proper
arguments and exit codes, a service watchdog and the backup script Rhea asked
for. The checks run your scripts with different inputs, including bad ones, so
error handling matters. Each task is checked automatically.

## Before you start

```bash
cd ~/work/scripts
cat services.txt
```

Expected output:

```
nginx running
brewbot stopped
postgres running
redis failed
cron running
```

## Task 1: five reports with one loop

Using a `for` loop at the prompt, create `~/work/scripts/reports/` with
`report-1.txt` to `report-5.txt`, each holding one line `Report N`.

[[lab-task:1]]

## Task 2: your first real script

Write the executable script `~/work/scripts/greet.sh`. It starts with a bash
shebang and has `set -euo pipefail` in its first lines. `greet.sh Rhea` prints
exactly `Hello, Rhea! Welcome to Atlas.`. With no argument it prints a message
containing `Usage` to stderr and exits with status 1.

[[lab-task:2]]

## Task 3: a service watchdog

Write the executable script `~/work/scripts/check-services.sh`. It takes a file
name; each line is `NAME STATUS`. For every service not `running` it prints
`ALERT: NAME is STATUS`, in file order. Its exit status is the number of
services that are not running (0 when all are fine).

[[lab-task:3]]

What you should see:

```
$ ./check-services.sh services.txt; echo "exit=$?"
ALERT: brewbot is stopped
ALERT: redis is failed
exit=2
```

## Task 4: the backup script Rhea asked for

Write the executable script `~/work/scripts/backup.sh SRC_DIR DEST_DIR`. It
creates `DEST_DIR` if needed and writes `DEST_DIR/NAME-YYYYMMDD.tar.gz`, where
`NAME` is the last part of `SRC_DIR` and `YYYYMMDD` is today's date. If
`SRC_DIR` is not an existing directory it prints an error to stderr and exits
with status 2.

[[lab-task:4]]

What you should see:

```
$ ./backup.sh /home/labuser/work/scripts /tmp/backups
/tmp/backups/scripts-20261014.tar.gz
```

## Remember

- Shebang, `set -euo pipefail`, `chmod +x`.
- Check `$#` and directories first; errors to `>&2` with a non-zero `exit`.
- `while read -r a b; do ...; done < "$1"` processes a file.
- `$(basename "$1")`, `$(date +%Y%m%d)` and quotes everywhere.

> **End of day 9.** Atlas now checks its own services and backs itself up every
> night. Rhea: "Before Black Friday I want you to understand what is really
> going on inside atlas, how to find what is slow, and how to lock it down."
> Tom's note: "Look under the hood."
