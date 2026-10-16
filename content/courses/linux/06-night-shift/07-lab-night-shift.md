---
kind: lesson
id_key: linux/night-shift/lesson
course: linux
section: night-shift
section_title: "Chapter 6: The Night Shift - systemd, Logs and Schedules"
section_position: 6
title: "Lab: The 2am Page"
position: 6
estimated_minutes: 30
source:
  - systemd.unit(5), systemd.service(5), systemctl(1), journalctl(1) manual pages
  - crontab(5), logrotate(8) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 45
  max_resets: 3
  is_required: false
  workspace_layout: console
  files:
    - path: night/journal.txt
      content: |
        Oct 14 02:00:01 atlas systemd[1]: Started cron.service - Regular background program processing daemon.
        Oct 14 02:00:02 atlas systemd[1]: Started nginx.service - A high performance web server.
        Oct 14 02:00:03 atlas systemd[1]: Starting brewbot.service - Orbit Coffee order bot...
        Oct 14 02:00:03 atlas brewbot[1040]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
        Oct 14 02:00:03 atlas systemd[1]: brewbot.service: Main process exited, code=exited, status=1/FAILURE
        Oct 14 02:00:03 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
        Oct 14 02:00:08 atlas systemd[1]: brewbot.service: Scheduled restart job, restart counter is at 1.
        Oct 14 02:00:08 atlas brewbot[1051]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
        Oct 14 02:00:08 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
        Oct 14 02:00:13 atlas systemd[1]: brewbot.service: Scheduled restart job, restart counter is at 2.
        Oct 14 02:00:13 atlas brewbot[1060]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
        Oct 14 02:00:13 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
        Oct 14 02:00:18 atlas systemd[1]: brewbot.service: Scheduled restart job, restart counter is at 3.
        Oct 14 02:00:18 atlas brewbot[1071]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
        Oct 14 02:00:18 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
        Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Start request repeated too quickly.
        Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
        Oct 14 02:00:19 atlas systemd[1]: Failed to start brewbot.service - Orbit Coffee order bot.
        Oct 14 02:05:00 atlas CRON[1102]: (root) CMD (/usr/local/bin/sync-prices.sh)
        Oct 14 02:30:00 atlas sshd[1120]: Accepted publickey for rhea from 10.0.0.7 port 51522 ssh2
  setup_script: |
    w=/home/labuser/work
    rm -rf $w/units $w/cron $w/logrotate $w/answers
    mkdir -p $w/answers
  tasks:
    - id_key: unit-file
      title: Write brewbot's unit file
      points: 25
      is_stateful: true
      description: >-
        Create /home/labuser/work/units/brewbot.service. In a [Unit] section give it any
        Description and order it after network.target. In a [Service] section run
        /opt/brewbot/bin/brewbot as the user brewbot and restart it only when it fails.
        In an [Install] section make it start in the normal multi-user boot target.
      verification_script: |
        f=/home/labuser/work/units/brewbot.service
        grep -q '^\[Unit\]' $f && grep -q '^Description=..*' $f && grep -q '^After=.*network.target' $f &&
        grep -q '^\[Service\]' $f && grep -q '^ExecStart=/opt/brewbot/bin/brewbot' $f &&
        grep -q '^User=brewbot$' $f && grep -q '^Restart=on-failure$' $f &&
        grep -q '^\[Install\]' $f && grep -q '^WantedBy=multi-user.target$' $f
      hint_context: Copy the unit file example from the lesson and adjust it. Keys are Description, After, ExecStart, User, Restart and WantedBy - one per line, no spaces around the equals sign.
      explanation_context: After= orders startup, ExecStart= is the command, Restart=on-failure brings the service back when it crashes, and WantedBy=multi-user.target is what systemctl enable hooks into.
      solution_script: |
        mkdir -p /home/labuser/work/units
        printf '[Unit]\nDescription=Orbit Coffee order bot\nAfter=network.target\n\n[Service]\nExecStart=/opt/brewbot/bin/brewbot\nUser=brewbot\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target\n' > /home/labuser/work/units/brewbot.service
    - id_key: read-journal
      title: What crashed at 2am?
      points: 25
      is_stateful: true
      description: night/journal.txt is last night's journal. Save the name of the unit that failed to start (for example nginx.service) into answers/failed-unit.txt, and the highest restart counter systemd reached into answers/restarts.txt.
      verification_script: |
        a=/home/labuser/work/answers
        [ "$(tr -d '[:space:]' < $a/failed-unit.txt)" = brewbot.service ] &&
        [ "$(tr -d '[:space:]' < $a/restarts.txt)" = 3 ]
      hint_context: grep -i fail night/journal.txt shows the failing unit. grep 'restart counter' shows each restart; the last one has the highest number.
      explanation_context: systemd restarted brewbot three times, then hit its start rate limit ("Start request repeated too quickly") and gave up. The real cause is on the brewbot line - Permission denied on its config file.
      solution_script: |
        echo brewbot.service > /home/labuser/work/answers/failed-unit.txt
        echo 3 > /home/labuser/work/answers/restarts.txt
    - id_key: cron-backup
      title: Schedule the nightly backup
      points: 15
      is_stateful: true
      description: Create /home/labuser/work/cron/brewbot.cron containing a crontab line that runs /opt/brewbot/backup.sh every day at 02:30.
      verification_script: |
        awk '$6 == "/opt/brewbot/backup.sh" && $1 == "30" && ($2 == "2" || $2 == "02") && $3 == "*" && $4 == "*" && $5 == "*" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron
      hint_context: The five time fields are minute, hour, day of month, month, day of week. A star means every.
      explanation_context: 30 2 * * * means minute 30 of hour 2, on every day of every month, any weekday.
      solution_script: |
        mkdir -p /home/labuser/work/cron
        echo '30 2 * * * /opt/brewbot/backup.sh' > /home/labuser/work/cron/brewbot.cron
    - id_key: cron-health
      title: Health check on weekdays
      points: 15
      is_stateful: true
      description: Add a second line to cron/brewbot.cron that runs /opt/brewbot/health.sh every 15 minutes, Monday to Friday only.
      verification_script: |
        awk '$6 == "/opt/brewbot/health.sh" && $1 == "*/15" && $2 == "*" && $3 == "*" && $4 == "*" && $5 == "1-5" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron &&
        grep -q backup.sh /home/labuser/work/cron/brewbot.cron
      hint_context: A step value */15 in the minute field means every 15 minutes. Day of week 1-5 is Monday to Friday (0 or 7 is Sunday). Use >> to append so the backup line stays.
      explanation_context: "*/15 * * * 1-5 fires at :00, :15, :30 and :45 of every hour, only on weekdays."
      solution_script: |
        echo '*/15 * * * 1-5 /opt/brewbot/health.sh' >> /home/labuser/work/cron/brewbot.cron
    - id_key: logrotate
      title: Stop the logs from eating the disk
      points: 20
      is_stateful: true
      description: Create /home/labuser/work/logrotate/brewbot - a logrotate config for /var/log/brewbot/*.log that rotates daily, keeps 7 old copies, compresses them, does not complain if the log is missing, and skips empty logs.
      verification_script: |
        f=/home/labuser/work/logrotate/brewbot
        grep -q '^/var/log/brewbot/\*\.log *{' $f && grep -qw daily $f && grep -Eq '^\s*rotate\s+7\s*$' $f &&
        grep -Eq '^\s*compress\s*$' $f && grep -qw missingok $f && grep -qw notifempty $f && grep -q '^}' $f
      hint_context: Use the logrotate example from the lesson - the path, then a block in braces with one directive per line - daily, rotate 7, compress, missingok, notifempty.
      explanation_context: logrotate runs daily from cron or a systemd timer. Without it, a chatty log grows until the disk is full - one of the most common outages there is.
      solution_script: |
        mkdir -p /home/labuser/work/logrotate
        printf '/var/log/brewbot/*.log {\n    daily\n    rotate 7\n    compress\n    missingok\n    notifempty\n}\n' > /home/labuser/work/logrotate/brewbot
    - id_key: timer-unit
      title: Turn the backup into a systemd timer
      points: 20
      is_stateful: true
      description: >-
        Create /home/labuser/work/units/brewbot-backup.timer. In a [Timer] section
        schedule it every day at 02:30 with OnCalendar and make it catch up on missed
        runs. In an [Install] section hook it into timers.target.
      verification_script: |
        f=/home/labuser/work/units/brewbot-backup.timer
        grep -q '^\[Timer\]' $f && grep -Eq '^OnCalendar=(\*-\*-\* )?0?2:30(:00)?$' $f &&
        grep -Eiq '^Persistent=(true|yes)$' $f &&
        grep -q '^\[Install\]' $f && grep -q '^WantedBy=timers.target$' $f
      hint_context: Copy the timer example from the cron and timers lesson. OnCalendar=*-*-* 02:30:00, Persistent=true and WantedBy=timers.target, one per line.
      explanation_context: A timer starts the service with the same name (brewbot-backup.service). Persistent=true runs a missed job at the next boot, and its output lands in the journal without any redirection.
      solution_script: |
        mkdir -p /home/labuser/work/units
        printf '[Unit]\nDescription=Run brewbot backup nightly\n\n[Timer]\nOnCalendar=*-*-* 02:30:00\nPersistent=true\n\n[Install]\nWantedBy=timers.target\n' > /home/labuser/work/units/brewbot-backup.timer
---

## Why this matters

It is 2:07am and brewbot is down. In this lab you write brewbot's unit file,
read last night's journal to find what crashed, schedule the nightly chores with
cron and a systemd timer, and stop logs from filling the disk. The lab machine
has no systemd of its own, so you write the files and read a saved journal; the
checks look at your files. Each task is checked automatically.

## Before you start

```bash
cd ~/work
ls night
wc -l night/journal.txt
```

What this does: `night/journal.txt` is a copy of last night's
`journalctl` output, about 20 lines.

## Task 1: write brewbot's unit file

Create `~/work/units/brewbot.service`. `[Unit]`: any `Description`, ordered
after `network.target`. `[Service]`: run `/opt/brewbot/bin/brewbot` as user
`brewbot`, restart only on failure. `[Install]`: start in the normal multi-user
boot target.

[[lab-task:1]]

## Task 2: what crashed at 2am?

Save the name of the unit that failed to start into
`answers/failed-unit.txt`, and the highest restart counter systemd reached into
`answers/restarts.txt`.

[[lab-task:2]]

What you should see:

```
$ grep -E 'FATAL|counter|too quickly' night/journal.txt | tail -3
Oct 14 02:00:18 atlas brewbot[1071]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:18 atlas systemd[1]: brewbot.service: Scheduled restart job ...
Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Start request repeated too quickly.
```

On the real atlas, the fix at 2:15am was
`sudo chgrp brewbot /etc/brewbot/brewbot.conf && sudo chmod 640 /etc/brewbot/brewbot.conf`,
then `sudo systemctl reset-failed brewbot && sudo systemctl start brewbot`.

## Task 3: schedule the nightly backup

Create `~/work/cron/brewbot.cron` with a crontab line that runs
`/opt/brewbot/backup.sh` every day at 02:30.

[[lab-task:3]]

## Task 4: health check on weekdays

Add a second line to `cron/brewbot.cron` that runs `/opt/brewbot/health.sh`
every 15 minutes, Monday to Friday only. Append; keep the backup line.

[[lab-task:4]]

## Task 5: stop the logs from eating the disk

Create `~/work/logrotate/brewbot`: a logrotate config for
`/var/log/brewbot/*.log` that rotates daily, keeps 7 copies, compresses them,
does not complain if the log is missing, and skips empty logs.

[[lab-task:5]]

## Task 6: the modern way, a timer

Create `~/work/units/brewbot-backup.timer` that runs every day at 02:30
(`OnCalendar`), catches up on missed runs, and is hooked into `timers.target`.

[[lab-task:6]]

## Remember

- Unit file: `[Unit]` After, `[Service]` ExecStart/User/Restart,
  `[Install]` WantedBy.
- The app's own log line holds the cause; systemd's lines are the symptom.
- Cron: minute hour dom month dow; timers: `OnCalendar=` + `Persistent=true`.
- logrotate keeps logs from filling the disk.

> **End of day 6.** Brewbot runs again and its logs will never fill the disk.
> Rhea, half asleep on the phone: "Nice work. Monday we're getting new disks,
> and we need some software installed." Tom's next note: "Know your storeroom."
