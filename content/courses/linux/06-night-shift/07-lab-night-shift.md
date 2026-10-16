---
kind: lesson
id_key: linux/night-shift/lesson
course: linux
section: night-shift
section_title: "Chapter 6: The Night Shift"
section_position: 6
title: Boot, systemd Services, Logs, cron and Log Rotation
position: 0
estimated_minutes: 50
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
---

> **Friday night, on call for the first time.** Your phone buzzes at 2:07am: *brewbot is down, no orders are coming in.* Tom's note said "services, logs, and the clock". Tonight you learn who starts programs on atlas, where they write their diary, and how atlas does chores on a schedule.

## How atlas boots

```
 power on
   |
 [1] BIOS / UEFI        checks hardware, finds a boot disk
   |
 [2] GRUB (bootloader)  menu, loads the kernel + initramfs from /boot
   |
 [3] Kernel             detects hardware, mounts the root filesystem
   |
 [4] systemd (PID 1)    starts every service in dependency order
   |
 [5] target reached     multi-user.target (server) or graphical.target (desktop)
   |
 login prompt
```

> **Memory hook:** "**B**ig **G**reen **K**ettles **S**team" - **B**IOS, **G**RUB, **K**ernel, **S**ystemd.

`dmesg` shows kernel messages from boot (hardware, drivers, disk errors). `systemd-analyze blame` shows which services slowed boot.

## systemd and systemctl

systemd is PID 1 and the manager of **units**. The most common unit types:

| Type | Example | What it is |
|---|---|---|
| `.service` | `nginx.service` | a program to keep running |
| `.timer` | `logrotate.timer` | a schedule (modern cron) |
| `.target` | `multi-user.target` | a group of units = a "boot state" |
| `.socket`, `.mount`, `.path` | | start on connection / mount / file change |

```bash
systemctl status brewbot          # running? last log lines? PID?
sudo systemctl start brewbot      # start now
sudo systemctl stop brewbot       # stop now
sudo systemctl restart brewbot    # stop + start
sudo systemctl reload nginx       # re-read config without dropping connections
sudo systemctl enable brewbot     # start at every boot
sudo systemctl enable --now brewbot   # enable AND start
sudo systemctl disable brewbot    # don't start at boot
systemctl is-active brewbot       # active / inactive / failed
systemctl list-units --failed     # what is broken right now?
sudo systemctl daemon-reload      # after editing a unit file
```

> **Memory hook:** **start** is *today*, **enable** is *every day*. A service can be started but not enabled (dies at reboot) or enabled but not started (runs from the next boot).

A unit file is a small INI file. Your own go in `/etc/systemd/system/`; package-provided ones live in `/lib/systemd/system/`.

```ini
# /etc/systemd/system/brewbot.service
[Unit]
Description=Orbit Coffee order bot
# start after networking is up
After=network.target

[Service]
ExecStart=/opt/brewbot/bin/brewbot
# never run apps as root
User=brewbot
# come back if it crashes
Restart=on-failure
Environment=PORT=8080

[Install]
# "enable" hooks it into normal boot
WantedBy=multi-user.target
```

Comments in unit files must be on their own line - systemd would treat `After=network.target # comment` as part of the value.

[[lab-task:1]]

## Logs: journalctl and /var/log

systemd's **journal** collects output from every service:

```bash
journalctl -u brewbot             # one unit's logs
journalctl -u brewbot -f          # follow live
journalctl -u brewbot --since "1 hour ago"
journalctl -p err -b              # errors (and worse) since this boot
journalctl -b -1                  # the previous boot (after a crash/reboot)
journalctl --disk-usage           # how big is the journal?
```

Classic text logs still live in `/var/log`:

| File | Contains |
|---|---|
| `/var/log/syslog` (Debian/Ubuntu) or `/var/log/messages` (RHEL) | general system log |
| `/var/log/auth.log` or `/var/log/secure` | logins, sudo, SSH |
| `/var/log/kern.log` | kernel |
| `/var/log/nginx/`, `/var/log/apache2/` | web servers |
| `/var/log/dpkg.log`, `/var/log/apt/` | package installs |

Log **priorities** from worst to mildest: `emerg, alert, crit, err, warning, notice, info, debug`.

> **Memory hook:** when a service is down, run the **two S's**: `systemctl status` (what state?) then `journalctl -u` (what did it say?). The answer is almost always in the last 20 lines.

[[lab-task:2]]

What you should see:

```
$ grep -E 'FATAL|counter|too quickly' night/journal.txt | tail -3
Oct 14 02:00:18 atlas brewbot[1071]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:18 atlas systemd[1]: brewbot.service: Scheduled restart job ...
Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Start request repeated too quickly.
```

At 2:15am you run `sudo chmod 640 /etc/brewbot/brewbot.conf && sudo chgrp brewbot /etc/brewbot/brewbot.conf`, then `sudo systemctl reset-failed brewbot && sudo systemctl start brewbot`. Orders flow again.

## cron: chores on a schedule

Each user has a crontab (`crontab -e` edits it, `crontab -l` lists it). System-wide jobs go in `/etc/crontab` and `/etc/cron.d/`, plus drop-in folders `/etc/cron.daily/`, `/etc/cron.weekly/`.

```
 .---------------- minute       (0-59)
 |  .------------- hour         (0-23)
 |  |  .---------- day of month (1-31)
 |  |  |  .------- month        (1-12)
 |  |  |  |  .---- day of week  (0-7, 0 and 7 = Sunday)
 |  |  |  |  |
 30 2  *  *  *   /opt/brewbot/backup.sh       every day at 02:30
 */15 * * * 1-5  /opt/brewbot/health.sh       every 15 min, Mon-Fri
 0  9  1  *  *   /opt/report.sh               9am on the 1st of each month
 @reboot         /opt/brewbot/warmup.sh       once at boot
```

> **Memory hook:** "**M**y **H**amster **D**rinks **M**ilk **W**eekly" - **M**inute, **H**our, **D**ay, **M**onth, **W**eekday.

Cron traps: jobs run with a **tiny PATH** (`/usr/bin:/bin`) and no `.bashrc`, so use full paths. Output is mailed or lost - redirect it: `... >> /var/log/backup.log 2>&1`. Check `grep CRON /var/log/syslog` to see if a job ran. `at 23:00` runs a one-off job; systemd **timers** are the modern alternative with logs in the journal.

[[lab-task:3]]

[[lab-task:4]]

## Log rotation

Logs grow forever unless something trims them. **logrotate** (run daily) renames `app.log` to `app.log.1`, compresses old ones, and deletes the oldest:

```
/var/log/brewbot/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

| Directive | Meaning |
|---|---|
| `daily` | rotate every day (or `weekly`, `monthly`, `size 100M`) |
| `rotate 7` | keep 7 old copies |
| `compress` | gzip old copies |
| `missingok` | no error if the log doesn't exist |
| `notifempty` | don't rotate an empty log |
| `copytruncate` | copy then empty the live file, for apps that can't reopen logs |

Configs live in `/etc/logrotate.d/`. Test one with `sudo logrotate -d /etc/logrotate.d/brewbot` (dry run).

[[lab-task:5]]

> **End of day 6.** Brewbot runs again and its logs will never fill the disk. Rhea, half asleep on the phone: "Nice work. Monday we're getting new disks - and we need some software installed." Tom's next note: "Know your storeroom."
