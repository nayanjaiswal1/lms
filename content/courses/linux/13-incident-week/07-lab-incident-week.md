---
kind: lesson
id_key: linux/incident-week/lesson
course: linux
section: incident-week
section_title: "Chapter 13: Incident Week - Troubleshooting Playbook"
section_position: 13
title: "Lab: Black Friday Incident Week"
position: 6
estimated_minutes: 40
source:
  - Brendan Gregg, "Linux Performance Analysis in 60,000 Milliseconds" and the USE method (brendangregg.com)
  - lsof(8), dmesg(1), namei(1), timedatectl(1), fsck(8) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 60
  max_resets: 3
  is_required: false
  workspace_layout: console
  files:
    - path: start-incident.sh
      content: |
        #!/bin/bash
        # Opens Black Friday's incidents on atlas. Run once: bash ~/work/start-incident.sh
        set -euo pipefail
        w=/home/labuser/work/incident
        mkdir -p $w/var/log/brewbot $w/bin $w/etc $w/app
        head -c 31457280 /dev/zero > $w/var/log/brewbot/debug.log
        printf '2026-11-27 09:00:01 INFO brewbot started\n2026-11-27 09:00:02 INFO accepting orders\n' > $w/var/log/brewbot/app.log
        cat > $w/bin/brewbot-worker <<'EOF'
        #!/bin/bash
        while true; do sleep 60; done
        EOF
        cat > $w/deploy.sh <<'EOF'
        #!/bin/bash
        mkdir -p /home/labuser/work/incident/app
        echo deployed > /home/labuser/work/incident/app/deployed.ok
        echo "Deploy complete"
        EOF
        chmod 644 $w/deploy.sh
        printf 'name = brewbot\nport = 80800\nworkers = 4\n' > $w/etc/brewbot.conf
        cat > $w/bin/brewbot-check <<'EOF'
        #!/bin/bash
        conf=/home/labuser/work/incident/etc/brewbot.conf
        p=$(awk -F' = ' '$1 == "port" {print $2}' $conf)
        if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]; then
          echo "config OK"
        else
          echo "ERROR: port '$p' out of range (1-65535) in $conf" >&2
          exit 1
        fi
        EOF
        cat > $w/bin/brewctl <<'EOF'
        #!/bin/bash
        if [ "${1:-}" = status ]; then echo "brewbot: OK"; else echo "usage: brewctl status" >&2; exit 1; fi
        EOF
        chmod 755 $w/bin/brewbot-check $w/bin/brewctl $w/bin/brewbot-worker
        mkdir -p $w/www
        echo "brewbot storefront" > $w/www/index.html
        printf 'name = brewbot-web\nbind = 127.0.0.1\nport = 8088\n' > $w/etc/brewbot-web.conf
        cat > $w/bin/brewbot-web <<'EOF'
        #!/bin/bash
        w=/home/labuser/work/incident
        bind=$(awk -F' = ' '$1 == "bind" {print $2}' $w/etc/brewbot-web.conf)
        port=$(awk -F' = ' '$1 == "port" {print $2}' $w/etc/brewbot-web.conf)
        cd $w/www && exec python3 -m http.server "$port" --bind "$bind"
        EOF
        chmod 755 $w/bin/brewbot-web
        nohup bash $w/bin/brewbot-worker >/dev/null 2>&1 &
        nohup $w/bin/brewbot-web >/dev/null 2>&1 &
        touch $w/.incident-started
        echo "PAGER: atlas disk 99% full, brewbot errors, deploy failing. Good luck."
  setup_script: |
    rm -rf /home/labuser/work/incident
  tasks:
    - id_key: open-incident
      title: The pager goes off
      points: 10
      is_stateful: true
      description: Black Friday has started. Run bash /home/labuser/work/start-incident.sh once to open the incidents.
      verification_script: |
        [ -f /home/labuser/work/incident/.incident-started ] &&
        pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' >/dev/null
      hint_context: Type exactly bash /home/labuser/work/start-incident.sh and press Enter.
      explanation_context: The script creates a full disk, a hung worker, a broken deploy, a bad config, a missing command and an unreachable web listener under ~/work/incident - one for each scenario that follows.
      solution_script: |
        bash /home/labuser/work/start-incident.sh
    - id_key: disk-full
      title: "Scenario 1 - the disk is full"
      points: 20
      is_stateful: true
      description: Something under /home/labuser/work/incident is eating the disk. Find the largest file and empty it to 0 bytes WITHOUT deleting it (pretend brewbot still has it open). Leave the other logs alone.
      verification_script: |
        l=/home/labuser/work/incident/var/log/brewbot
        [ -f $l/debug.log ] && [ ! -s $l/debug.log ] && [ -s $l/app.log ]
      hint_context: >-
        du -ah /home/labuser/work/incident | sort -h | tail finds the culprit. truncate -s 0 FILE or : > FILE empties it in place.
      explanation_context: Deleting a log that a process still holds open frees nothing - the process keeps writing into the invisible inode. Truncating keeps the same inode and releases the space immediately.
      solution_script: |
        truncate -s 0 /home/labuser/work/incident/var/log/brewbot/debug.log
    - id_key: hung-worker
      title: "Scenario 2 - a hung worker"
      points: 20
      is_stateful: true
      description: A stuck brewbot-worker process is running. Find it and stop it - politely first.
      verification_script: |
        [ -f /home/labuser/work/incident/.incident-started ] &&
        ! pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' >/dev/null
      hint_context: ps aux | grep brewbot-worker or pgrep -af brewbot-worker shows the PID. kill PID sends SIGTERM; use kill -9 only if it refuses to die.
      explanation_context: Find (ps, pgrep), ask politely (SIGTERM 15), confirm it is gone, and only then force (SIGKILL 9). On a real server you would then check why systemd did not restart it, or why it hung.
      solution_script: |
        pkill -TERM -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$'
        sleep 1
    - id_key: permission-denied
      title: "Scenario 3 - Permission denied"
      points: 15
      is_stateful: true
      description: Running /home/labuser/work/incident/deploy.sh fails with Permission denied. Fix the cause (do not work around it with bash deploy.sh), then run ./deploy.sh successfully.
      verification_script: |
        w=/home/labuser/work/incident
        [ -x $w/deploy.sh ] && [ -f $w/app/deployed.ok ]
      hint_context: ls -l deploy.sh - is there an x anywhere in the permissions? chmod u+x adds it.
      explanation_context: To run a file directly, the kernel needs the execute bit. "Permission denied" always means check ls -l on the file - and on every directory in its path (namei -l shows them all).
      solution_script: |
        cd /home/labuser/work/incident && chmod u+x deploy.sh && ./deploy.sh
    - id_key: bad-config
      title: "Scenario 4 - the service will not start"
      points: 15
      is_stateful: true
      description: brewbot refuses to start. Run /home/labuser/work/incident/bin/brewbot-check, read the error, and fix incident/etc/brewbot.conf so brewbot listens on port 8080 and the check passes.
      verification_script: |
        w=/home/labuser/work/incident
        $w/bin/brewbot-check >/dev/null 2>&1 && grep -qx 'port = 8080' $w/etc/brewbot.conf && grep -qx 'workers = 4' $w/etc/brewbot.conf
      hint_context: The checker names the bad line. Edit it with nano, or sed -i 's/^port = .*/port = 8080/' FILE. Keep every other line.
      explanation_context: Most "service won't start" incidents are a bad config change. Read the error, fix one line, validate with the program's own checker (nginx -t, sshd -t, brewbot-check) before restarting.
      solution_script: |
        sed -i 's/^port = .*/port = 8080/' /home/labuser/work/incident/etc/brewbot.conf
    - id_key: command-not-found
      title: "Scenario 5 - command not found"
      points: 20
      is_stateful: true
      description: The runbook says to type brewctl status, but bash answers command not found. The tool exists in /home/labuser/work/incident/bin. Fix your PATH permanently in ~/.bashrc so brewctl status works from any directory.
      verification_script: |
        [ "$(bash -ic 'cd /tmp && brewctl status' 2>/dev/null)" = "brewbot: OK" ]
      hint_context: Append export PATH="$PATH:/home/labuser/work/incident/bin" to ~/.bashrc, then open a new shell or source it.
      explanation_context: command not found means no directory in PATH contains that name. Check with echo $PATH and which; the fix is either the full path, a PATH change, or installing the missing package.
      solution_script: |
        echo 'export PATH="$PATH:/home/labuser/work/incident/bin"' >> ~/.bashrc
    - id_key: unreachable-port
      title: "Scenario 6 - the app runs but nobody can reach it"
      points: 20
      is_stateful: true
      description: Customers report the brewbot storefront (port 8088) is unreachable from outside, yet the process is running. Find out why and fix it so the site listens on every interface. The config is incident/etc/brewbot-web.conf and the launcher is incident/bin/brewbot-web. Leave a working listener running.
      verification_script: |
        w=/home/labuser/work/incident
        grep -qx 'bind = 0.0.0.0' $w/etc/brewbot-web.conf &&
        grep -qx 'port = 8088' $w/etc/brewbot-web.conf &&
        ss -tln | awk '{print $4}' | grep -qx '0.0.0.0:8088' &&
        [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8088/)" = 200 ]
      hint_context: ss -tulpn | grep 8088 shows the address it is bound to. 127.0.0.1 means local only. Change bind in the config to 0.0.0.0, stop the old listener (pkill -f "http.server 8088"), then start brewbot-web again in the background with &.
      explanation_context: A service bound to 127.0.0.1 answers only on the same machine, so curl localhost works while everyone else gets connection refused. Editing the config does nothing until the process restarts. This is the classic "works on the server, unreachable from outside" bug, and the same cause behind a container app that is not reachable through a published port.
      solution_script: |
        w=/home/labuser/work/incident
        sed -i 's/^bind = .*/bind = 0.0.0.0/' $w/etc/brewbot-web.conf
        pkill -u labuser -f '^python3 -m http.server 8088' || true
        sleep 1
        nohup $w/bin/brewbot-web >/dev/null 2>&1 &
        sleep 1
---

## Why this matters

Black Friday is live and six things are broken at once. Everything from the
course gets used: disk, processes, permissions, config, PATH and networking.
Work through them with the method: read the error, check resources, logs,
permissions, changes. Each task is checked automatically.

## Before you start

```bash
cat ~/work/start-incident.sh | head -20
```

What this does: lets you read what the incident script will do. On a real
server you never get this luxury, but reading scripts before running them is a
good habit.

## Task 1: the pager goes off

Run `bash ~/work/start-incident.sh` once to open the incidents.

[[lab-task:1]]

Expected output:

```
PAGER: atlas disk 99% full, brewbot errors, deploy failing. Good luck.
```

## Task 2: scenario 1, the disk is full

Something under `~/work/incident` is eating the disk. Find the largest file and
empty it to 0 bytes **without deleting it** (pretend brewbot still has it
open). Leave the other logs alone.

[[lab-task:2]]

## Task 3: scenario 2, a hung worker

A stuck `brewbot-worker` process is running. Find it and stop it, politely
first.

[[lab-task:3]]

## Task 4: scenario 3, Permission denied

Running `~/work/incident/deploy.sh` fails with `Permission denied`. Fix the
cause (do not work around it with `bash deploy.sh`), then run `./deploy.sh`
successfully.

[[lab-task:4]]

## Task 5: scenario 4, the service will not start

Run `~/work/incident/bin/brewbot-check`, read the error, and fix
`incident/etc/brewbot.conf` so brewbot listens on port 8080 and the check
passes. Keep every other line.

[[lab-task:5]]

## Task 6: scenario 5, command not found

The runbook says `brewctl status`, but bash says `command not found`. The tool is
in `~/work/incident/bin`. Fix your PATH permanently in `~/.bashrc`.

[[lab-task:6]]

What you should see:

```
$ cd /tmp && brewctl status
brewbot: OK
```

## Task 7: scenario 6, the app runs but nobody can reach it

The storefront on port 8088 is unreachable from outside, yet the process runs.
The config is `incident/etc/brewbot-web.conf`, the launcher
`incident/bin/brewbot-web`. Make it listen on every interface and leave a working
listener running.

[[lab-task:7]]

Check yourself:

```
$ ss -tln | grep 8088
LISTEN 0      5            0.0.0.0:8088       0.0.0.0:*
```

## Remember

- Disk: `du -ah | sort -h`, then `truncate -s 0`, not `rm`.
- Processes: `pgrep -af`, TERM before KILL.
- Permission denied: `ls -l`, then `chmod u+x`; never 777.
- Config: read the checker's error, fix one line, validate.
- PATH in `~/.bashrc`; listeners: `ss -tln`, bind `0.0.0.0`, restart.

> **The end of Black Friday.** By 9:40am the disk was clear, the hung worker
> gone, the deploy shipped, brewbot back on port 8080, the storefront reachable
> and the runbook command fixed. Orders hit a record. Rhea lands, reads your
> post-mortem, and pins Tom's notes to the wall, next to your name. You are
> atlas's admin now.
