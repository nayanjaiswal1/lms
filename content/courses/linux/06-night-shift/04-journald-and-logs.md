---
kind: lesson
id_key: linux/night-shift/journald-and-logs
course: linux
section: night-shift
section_title: "Chapter 6: The Night Shift - systemd, Logs and Schedules"
section_position: 6
title: "Logs: journalctl, journald and /var/log"
position: 3
estimated_minutes: 8
source:
  - journalctl(1), journald.conf(5), systemd-journald.service(8), rsyslogd(8) manual pages
---

## Why this matters

`systemctl status brewbot` says `failed`. *Why* it failed is in the logs, almost
always in the last 20 lines. You need to filter the right service, the right
time and the right severity in seconds.

## Mental model: one diary, many authors

- **journald** (`systemd-journald`) collects the output of every service, the
  kernel and syslog messages into one structured, indexed **journal**.
- `journalctl` reads it, with filters.
- Many systems also run **rsyslog**, which writes classic text files in
  `/var/log`. Both exist side by side.

```
 brewbot stdout/stderr --\
 kernel messages ---------+--> journald --> journal (binary, indexed) --> journalctl
 syslog() calls ---------/                \--> rsyslog --> /var/log/syslog, auth.log ...
```

> **Memory hook:** when a service is down, run the **two S's**:
> `systemctl status` (what state?) then `journalctl -u` (what did it say?).

## See it work

```bash
journalctl -u brewbot -n 20 --no-pager
```

What this does: last 20 lines from one unit, printed directly. Expected output:

```
Oct 14 02:00:03 atlas systemd[1]: Starting brewbot.service - Orbit Coffee order bot...
Oct 14 02:00:03 atlas brewbot[1040]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:03 atlas systemd[1]: brewbot.service: Main process exited, code=exited, status=1/FAILURE
Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Start request repeated too quickly.
```

The line from brewbot itself holds the cause: Permission denied on its config.

### Filters you will use

```bash
journalctl -u brewbot -f                    # follow live
journalctl -u brewbot --since "1 hour ago"  # or --since "2026-10-14 02:00" --until "02:30"
journalctl -p err -b                        # priority err and worse, this boot
journalctl -b -1                            # the previous boot
journalctl -k                               # kernel only (like dmesg)
journalctl _PID=1040                        # one process
journalctl -u nginx -o json-pretty -n 1     # every structured field
journalctl --disk-usage                     # journal size
sudo journalctl --vacuum-size=500M          # shrink it
```

Priorities from worst to mildest: `emerg, alert, crit, err, warning, notice,
info, debug` (0-7). `-p warning` means warning and everything worse.

### Make the journal survive reboots

Some distros keep the journal only in RAM (`/run/log/journal`). To keep it on
disk, create the directory (or set `Storage=persistent`):

```bash
sudo mkdir -p /var/log/journal
sudo systemctl restart systemd-journald
```

Limit its size in `/etc/systemd/journald.conf` with `SystemMaxUse=1G`.

### Classic files in /var/log

| File | Contains |
|---|---|
| `/var/log/syslog` (Debian/Ubuntu) or `/var/log/messages` (RHEL) | general system log |
| `/var/log/auth.log` or `/var/log/secure` | logins, sudo, SSH |
| `/var/log/kern.log` | kernel |
| `/var/log/nginx/`, `/var/log/apache2/` | web servers (their own files) |
| `/var/log/dpkg.log`, `/var/log/apt/` | package installs |
| `/var/log/wtmp`, `btmp` | logins / failed logins (read with `last`, `lastb`) |

Apps that write their own files (nginx, databases) do not appear in the journal
unless configured to; check both places.

## Try it

Brewbot failed at about 2am. Write one command that shows only error-level
messages from brewbot between 01:55 and 02:30 today.

<details>
<summary>Show answer</summary>

```bash
journalctl -u brewbot -p err --since "01:55" --until "02:30"
```

</details>

## Common mistakes

- **Reading only systemd's lines.** "Failed with result exit-code" is the
  symptom; the app's own line just above it is the cause.
- **Volatile journal.** After a crash and reboot, `-b -1` is empty. Make it
  persistent.
- **Deleting journal files by hand.** Use `--vacuum-size` or `--vacuum-time`.
- **Forgetting app log files.** nginx and PostgreSQL usually log to
  `/var/log/<app>/`.

## Remember

- `systemctl status X` then `journalctl -u X -n 50`.
- Filters: `-u`, `-p`, `-b`, `--since/--until`, `-f`, `-k`.
- Priorities: emerg alert crit err warning notice info debug.
- `/var/log/journal` = persistent journal; classic files live in `/var/log`.

**Self-check:**

1. Which option shows the previous boot?
2. What does `-p err` include?
3. Where do SSH and sudo logins go on Ubuntu?
