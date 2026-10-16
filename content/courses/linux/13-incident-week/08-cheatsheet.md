---
kind: lesson
id_key: linux/incident-week/cheatsheet
course: linux
section: incident-week
section_title: "Chapter 13: Incident Week - Troubleshooting Playbook"
section_position: 13
title: "Reference: Symptom to First Command"
position: 7
estimated_minutes: 5
source:
  - Chapter 13 lessons
---

## How to use this page

Print it, pin it, open it at 3am. Find the symptom, run the first command, then
go to the lesson that covers it. The method above all: **E**rror,
**R**esources, **L**ogs, **P**ermissions, **C**hanges.

## First 60 seconds

```bash
uptime; dmesg -T | tail; df -h; df -i; free -h
top                      # P = CPU, M = memory
systemctl --failed; journalctl -p err -b
ss -tulpn
```

## Symptom table

| Symptom | First command | Then |
|---|---|---|
| No space left | `df -h`, then `du -xh / \| sort -h` | `truncate -s 0` big logs, vacuum journal |
| Full but nothing big | `lsof +L1` | restart the holder or `: > /proc/PID/fd/N` |
| No space, df shows free | `df -i` | delete tiny junk files, fix the app |
| Read-only file system | `dmesg -T \| grep -i error` | disk health, fsck, restore |
| Slow server | `uptime`, `vmstat 1` | `top` (CPU), `free` (memory), `iostat -x` (disk) |
| High load, idle CPU | `ps -eo state,pid,cmd \| grep '^D'` | `iostat -x 1`, `iotop`, `ionice -c3` |
| Process vanished, exit 137 | `dmesg -T \| grep -i 'killed process'` | find the leak, `MemoryMax=` |
| Worker hung | `pgrep -af NAME`, `cat /proc/PID/wchan` | `strace -p PID`, TERM then KILL |
| Permission denied | `ls -l FILE`, `namei -l PATH`, `id` | `chmod`/`chown`/group, MAC denials |
| Service down | `systemctl status X`, `journalctl -u X -n 50` | validate config, `reset-failed`, start |
| Address already in use | `ss -tulpn \| grep :PORT` | stop the stray process or change port |
| command not found | `echo $PATH`, `command -v X` | full path, PATH in `~/.bashrc`, install |
| Cron job didn't run | `grep CRON /var/log/syslog` | full paths, `%`, redirect output |
| Connection refused | `ss -tulpn` on the server | start it / bind `0.0.0.0` / right port |
| Connection timed out | firewall: `ufw status`, security group | `tcpdump -ni any port N` |
| 502 from nginx | `journalctl -u APP`, `curl localhost:APPPORT` | app down or wrong upstream |
| Name doesn't resolve | `getent hosts NAME`, `dig NAME` | `/etc/hosts`, `/etc/resolv.conf` |
| SSH publickey refused | `ssh -v`, server `journalctl -u ssh` | `~/.ssh` 700, keys 600, right user |
| TLS not yet valid / expired | `timedatectl`, `openssl s_client ... \| openssl x509 -noout -dates` | NTP on, renew certificate |
| Locked out of sudo | another admin, console | recovery mode, `visudo` |
| Server won't boot | serial console | older kernel, `emergency.target`, fix fstab |

## Exit codes

`0` ok · `1` error · `2` usage · `126` not executable · `127` not found ·
`130` Ctrl+C · `137` SIGKILL (often OOM) · `143` SIGTERM.

## After the incident

Timeline, root cause (not the trigger), what went well/badly, action items with
owners. Blameless.
