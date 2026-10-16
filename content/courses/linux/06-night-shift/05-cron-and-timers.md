---
kind: lesson
id_key: linux/night-shift/cron-and-timers
course: linux
section: night-shift
section_title: "Chapter 6: The Night Shift - systemd, Logs and Schedules"
section_position: 6
title: "Chores on a Schedule: cron and systemd Timers"
position: 4
estimated_minutes: 8
source:
  - crontab(5), crontab(1), cron(8), systemd.timer(5), systemd.time(7) manual pages
---

## Why this matters

Backups at 02:30, health checks every 15 minutes, a report on the 1st of the
month: atlas does chores while everyone sleeps. Get the schedule wrong and the
backup you rely on never ran.

## Mental model: five dials on a clock

A **crontab** line has five time fields, then the command:

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
 0  3  *  *  0   /opt/brewbot/weekly.sh       03:00 every Sunday
 @reboot         /opt/brewbot/warmup.sh       once at boot
```

`*` = every value, `*/15` = every 15th, `1-5` = range, `1,15` = list.

> **Memory hook:** "**M**y **H**amster **D**rinks **M**ilk **W**eekly":
> **M**inute, **H**our, **D**ay, **M**onth, **W**eekday.

## See it work

```bash
crontab -e      # edit YOUR crontab (opens an editor)
crontab -l      # list it
```

Example content:

```
PATH=/usr/local/bin:/usr/bin:/bin
30 2 * * * /opt/brewbot/backup.sh >> /var/log/brewbot/backup.log 2>&1
```

System-wide jobs live in `/etc/crontab` and `/etc/cron.d/` (these have an extra
**user** field after the time), plus drop-in folders `/etc/cron.daily/`,
`/etc/cron.weekly/`, `/etc/cron.monthly/` for plain scripts.

### The four cron traps

1. **Tiny environment.** Cron runs with a minimal PATH (`/usr/bin:/bin`) and no
   `.bashrc`. Use full paths or set `PATH=` at the top.
2. **Lost output.** Output is mailed (often to nowhere). Redirect it:
   `>> /var/log/job.log 2>&1`.
3. **`%` is special.** In a crontab, `%` means newline. Escape it:
   `date +\%F`.
4. **Did it run?** `grep CRON /var/log/syslog` or
   `journalctl -u cron --since today`.

`at 23:00` runs a one-off job later (`atq` lists, `atrm` removes).

### systemd timers: the modern alternative

A timer is a unit that starts a service on a schedule. Two files:

```ini
# /etc/systemd/system/brewbot-backup.service
[Unit]
Description=Brewbot nightly backup

[Service]
Type=oneshot
ExecStart=/opt/brewbot/backup.sh
```

```ini
# /etc/systemd/system/brewbot-backup.timer
[Unit]
Description=Run brewbot backup nightly

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now brewbot-backup.timer
systemctl list-timers              # next and last run of every timer
systemd-analyze calendar "Mon..Fri *:0/15"   # check a schedule expression
```

Why timers: output goes to the journal automatically (`journalctl -u
brewbot-backup`), `Persistent=true` catches up on runs missed while the machine
was off, and the job gets all unit settings (user, limits, sandboxing).

| | cron | systemd timer |
|---|---|---|
| Setup | one line | two small files |
| Logs | redirect yourself | journal, automatic |
| Missed runs (machine off) | skipped | `Persistent=true` catches up |
| Overlap protection | none (`flock` yourself) | a running service is not started twice |

## Try it

Write a crontab line that runs `/opt/brewbot/health.sh` every 15 minutes, Monday
to Friday only, and keeps its output in `/var/log/brewbot/health.log`.

<details>
<summary>Show answer</summary>

```
*/15 * * * 1-5 /opt/brewbot/health.sh >> /var/log/brewbot/health.log 2>&1
```

</details>

## Common mistakes

- **Commands that work in your shell but not in cron.** PATH and environment
  differ. Use full paths.
- **`0 3 * * *` vs `* 3 * * *`.** The second runs 60 times, every minute of hour
  3.
- **Both day-of-month and day-of-week set.** Cron runs when *either* matches,
  not both.
- **Overlapping runs.** A slow job started every 5 minutes piles up. Wrap it:
  `flock -n /tmp/job.lock /opt/job.sh`.

## Remember

- minute hour day-of-month month day-of-week, then the command.
- `crontab -e` / `-l`; system jobs in `/etc/cron.d/`.
- Full paths, redirect output, escape `%`, check `grep CRON`.
- Timers: `.service` + `.timer` with `OnCalendar=`, `systemctl list-timers`.

**Self-check:**

1. What does `0 3 * * 0` mean?
2. Why do scripts that work by hand fail in cron?
3. What does `Persistent=true` do in a timer?
