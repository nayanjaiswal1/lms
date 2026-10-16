---
kind: lesson
id_key: linux/night-shift/systemctl
course: linux
section: night-shift
section_title: "Chapter 6: The Night Shift - systemd, Logs and Schedules"
section_position: 6
title: "systemd and systemctl: Starting, Stopping, Enabling"
position: 1
estimated_minutes: 8
source:
  - systemd(1), systemctl(1), systemd.unit(5) manual pages
---

## Why this matters

Brewbot is down. The first two commands of nearly every Linux incident are
`systemctl status` and `journalctl -u`. You also need to know why a service that
"worked yesterday" did not come back after a reboot.

## Mental model: the night manager

**systemd** is PID 1 and the manager of **units**. A unit is anything systemd
looks after:

| Type | Example | What it is |
|---|---|---|
| `.service` | `nginx.service` | a program to keep running |
| `.timer` | `logrotate.timer` | a schedule (modern cron) |
| `.target` | `multi-user.target` | a group of units = a system state |
| `.socket` | `ssh.socket` | start a service when a connection arrives |
| `.mount`, `.path` | | mount a filesystem, react to file changes |

Two separate questions about every unit:

```
 is it running NOW?          start / stop / restart       (active / inactive / failed)
 will it start at BOOT?      enable / disable             (enabled / disabled)
```

> **Memory hook:** **start** is *today*, **enable** is *every day*. A service
> can be started but not enabled (gone after reboot) or enabled but not started
> (runs from the next boot).

## See it work

```bash
systemctl status nginx
```

Expected output (abridged):

```
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Wed 2026-10-14 09:00:03 UTC; 2h ago
   Main PID: 901 (nginx)
     Memory: 6.1M
     CGroup: /system.slice/nginx.service
             ├─901 "nginx: master process /usr/sbin/nginx"
             └─902 "nginx: worker process"

Oct 14 09:00:03 atlas systemd[1]: Started nginx.service - A high performance web server...
```

Read it top to bottom: where the unit file is and whether it is **enabled**;
whether it is **active** and since when; the main PID; the processes; and the
last log lines.

### The everyday commands

```bash
sudo systemctl start brewbot        # start now
sudo systemctl stop brewbot         # stop now
sudo systemctl restart brewbot      # stop + start
sudo systemctl reload nginx         # re-read config, keep connections (if supported)
sudo systemctl enable brewbot       # start at every boot
sudo systemctl enable --now brewbot # enable AND start
sudo systemctl disable brewbot      # do not start at boot
systemctl is-active brewbot         # active / inactive / failed (good in scripts)
systemctl is-enabled brewbot        # enabled / disabled
systemctl --failed                  # what is broken right now?
systemctl list-units --type=service # everything loaded
systemctl cat nginx                 # print the unit file(s) in use
sudo systemctl daemon-reload        # after editing any unit file
sudo systemctl mask brewbot         # make it impossible to start (even by hand)
```

`mask` links the unit to `/dev/null`; `unmask` undoes it. Use it to make sure
something never runs (an old service that conflicts with a new one).

### When systemd gives up

If a service crashes repeatedly, systemd stops restarting it:
`Start request repeated too quickly`. After fixing the cause, clear the counter:

```bash
sudo systemctl reset-failed brewbot
sudo systemctl start brewbot
```

## Try it

You installed brewbot, ran `sudo systemctl start brewbot`, and it works. After
Saturday's reboot it is not running. What did you forget, and which single
command would have done both steps?

<details>
<summary>Show answer</summary>

You never enabled it. `sudo systemctl enable --now brewbot` enables it for
every boot and starts it now.

</details>

## Common mistakes

- **Editing a unit file and forgetting `daemon-reload`.** systemd keeps using the
  old version and warns "unit file changed on disk".
- **`restart` when `reload` would do.** Restarting nginx drops connections;
  reload does not. Check `nginx -t` first either way.
- **Assuming "enabled" means "running".** Check both `is-enabled` and
  `is-active`.
- **Looking for the service with `ps` only.** `systemctl status` also shows why
  it stopped.

## Remember

- systemd (PID 1) manages units: services, timers, targets, sockets.
- `start/stop/restart/reload` = now; `enable/disable` = at boot; `--now` = both.
- `systemctl status`, `--failed`, `cat`, `is-active`.
- After editing units: `daemon-reload`. After crash loops: `reset-failed`.

**Self-check:**

1. What is the difference between `start` and `enable`?
2. Which command lists all failed units?
3. What does `mask` do?
