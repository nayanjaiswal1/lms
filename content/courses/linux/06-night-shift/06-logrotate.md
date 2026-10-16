---
kind: lesson
id_key: linux/night-shift/logrotate
course: linux
section: night-shift
section_title: "Chapter 6: The Night Shift - systemd, Logs and Schedules"
section_position: 6
title: "Log Rotation: Stop Logs from Eating the Disk"
position: 5
estimated_minutes: 6
source:
  - logrotate(8) manual page
---

## Why this matters

"Disk full" is one of the most common outages there is, and the usual culprit is
a log that grew for months. Log rotation trims logs automatically. Ten lines of
config prevent a 3am page.

## Mental model: a shelf of dated notebooks

Every day logrotate takes the current notebook off the desk, labels it, puts it
on a shelf, and starts a fresh one. When the shelf is full, the oldest notebook
is thrown away.

```
 day 1:  app.log
 day 2:  app.log   app.log.1
 day 3:  app.log   app.log.1   app.log.2.gz
 ...
 day 9:  app.log   app.log.1   app.log.2.gz ... app.log.7.gz    (oldest deleted)
```

logrotate runs daily from a systemd timer (`logrotate.timer`) or from
`/etc/cron.daily/logrotate`.

## See it work

```
/var/log/brewbot/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 brewbot adm
    postrotate
        systemctl reload brewbot > /dev/null 2>&1 || true
    endscript
}
```

| Directive | Meaning |
|---|---|
| `daily` | rotate every day (or `weekly`, `monthly`, `size 100M`) |
| `rotate 7` | keep 7 old copies |
| `compress` | gzip old copies |
| `delaycompress` | leave the newest old copy uncompressed (apps may still write to it) |
| `missingok` | no error if the log does not exist |
| `notifempty` | do not rotate an empty log |
| `create MODE USER GROUP` | create the new empty log with these permissions |
| `postrotate ... endscript` | run a command after rotating (tell the app to reopen its log) |
| `copytruncate` | copy, then empty the live file in place (for apps that cannot reopen logs) |

Configs live in `/etc/logrotate.d/`, one file per app. Test before trusting:

```bash
sudo logrotate -d /etc/logrotate.d/brewbot     # dry run: shows what it would do
sudo logrotate -f /etc/logrotate.d/brewbot     # force a rotation now
```

### Why the app must be told

After `app.log` is renamed to `app.log.1`, a running app still has the **old
file open** and keeps writing into `app.log.1`. Either:

- signal it to reopen its logs (`postrotate` with a reload or `kill -HUP`), or
- use `copytruncate` (simple, but lines written during the copy can be lost).

Services that log to the journal do not need logrotate; journald limits its own
size (`SystemMaxUse=`).

## Try it

Write a logrotate block for `/var/log/brewbot/*.log` that rotates daily, keeps 7
copies, compresses them, does not complain if the log is missing, and skips
empty logs.

<details>
<summary>Show answer</summary>

```
/var/log/brewbot/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

</details>

## Common mistakes

- **No `postrotate` and no `copytruncate`.** The app writes into the rotated file
  forever and the "new" log stays empty.
- **Deleting a big log with `rm` while the app runs.** The space is not freed
  (Incident Week). Truncate or rotate instead.
- **Never testing.** A syntax error means logrotate silently skips the file.
  Use `-d`.

## Remember

- logrotate renames, compresses and deletes old logs on a schedule.
- Core directives: `daily`, `rotate N`, `compress`, `missingok`, `notifempty`.
- Tell the app: `postrotate` reload, or `copytruncate`.
- Configs in `/etc/logrotate.d/`; test with `logrotate -d`.

**Self-check:**

1. What does `rotate 7` mean?
2. Why does an app keep writing to `app.log.1` after rotation?
3. How do you test a logrotate config without changing anything?
