---
kind: lesson
id_key: linux/incident-week/service-scenarios
course: linux
section: incident-week
section_title: "Chapter 13: Incident Week - Troubleshooting Playbook"
section_position: 13
title: "Service Scenarios: Permission Denied, Won't Start, Port in Use, Not Found, Cron"
position: 3
estimated_minutes: 8
source:
  - namei(1), systemctl(1), journalctl(1), ss(8), lsof(8), crontab(5) manual pages
---

## Why this matters

These five errors are the daily bread of operations. Each has a short, fixed
checklist. Knowing it turns a 40-minute hunt into a 4-minute fix.

## Mental model: the error text is the map

```
 "Permission denied"           -> who am I, who owns it, every directory on the path
 "failed" / "exit-code"        -> the service's own log line, then validate config
 "Address already in use"      -> who already has the port
 "command not found"           -> PATH, or the package is missing
 "the cron job didn't run"     -> did cron try? environment? output?
```

## Scenario 1: "Permission denied"

```bash
ls -l deploy.sh               # is the x bit set? who owns it?
namei -l /srv/shop/deploy.sh  # permissions of EVERY directory on the path
id                            # which user and groups am I?
findmnt -no OPTIONS /srv      # mounted noexec?
```

**Fix:** `chmod u+x`, `chown` to the right user, add the user to the group
(`usermod -aG`, then log in again), or run as the right user
(`sudo -u www-data`). On SELinux/AppArmor systems check denials (chapter 12).
**Never** fix it with `chmod 777`.

## Scenario 2: the service will not start

```bash
systemctl status brewbot              # state + last log lines
journalctl -u brewbot -n 50 --no-pager
sudo nginx -t                         # many programs validate their own config
sudo sshd -t
```

Usual causes: a typo in the config, a missing file, wrong permissions on a
config or key, the port already in use, or a dependency (database) not up yet.
**Fix one thing, validate, then restart.** If systemd gave up ("start request
repeated too quickly"), run `systemctl reset-failed brewbot` first.

## Scenario 3: "Address already in use"

```bash
sudo ss -tulpn | grep ':8080'         # who has the port?
sudo lsof -i :8080
```

Usually an old copy of the app is still running, or two services were configured
with the same port. Stop the stray process or change one port.

## Scenario 4: "command not found"

```bash
echo "$PATH"
type brewctl; command -v brewctl
ls -l /opt/brewbot/bin/
apt-file search bin/dig           # which package provides it? (or: dnf provides '*/dig')
```

**Fix:** use the full path, add the directory to PATH in `~/.bashrc` (or
`/etc/profile.d/` for everyone), or install the package. Under `sudo`, PATH is
reset to `secure_path`, another common surprise. Exit status **127** = not
found; **126** = found but not executable.

## Scenario 5: the cron job didn't run

```bash
grep CRON /var/log/syslog | tail      # did cron even try?   (or: journalctl -u cron)
crontab -l                            # is the line there, for the right user?
systemctl list-timers                 # if it is a systemd timer
```

Cron runs with a minimal environment: use **full paths**, make the script
**executable**, escape `%` (it means newline in crontab), and redirect output to
a log (`>> /var/log/job.log 2>&1`) so failures are visible.

## Try it

`./deploy.sh` says `Permission denied`. `ls -l` shows `-rw-r--r-- labuser
labuser deploy.sh` and you are labuser. What is the cause and the right fix?
What is the wrong fix?

<details>
<summary>Show answer</summary>

There is no execute bit, so the kernel refuses to run it. Right fix:
`chmod u+x deploy.sh`, then `./deploy.sh`. Wrong fixes: `chmod 777` (lets
everyone change your deploy script) or habitually working around it with
`bash deploy.sh` without fixing the file.

</details>

## Common mistakes

- **Restarting a service in a loop without reading its log.**
- **Killing whatever holds a port without checking what it is.** It might be the
  new version you just started.
- **Assuming cron has your PATH.** It does not.
- **`chmod 777` for permission errors.** It creates a security hole and usually
  does not fix the real cause (a parent directory, the wrong user, SELinux).

## Remember

- Permission denied: `ls -l`, `namei -l`, `id`, mount options, MAC.
- Won't start: `status`, `journalctl -u`, validate config, `reset-failed`.
- Port in use: `ss -tulpn | grep :PORT`, `lsof -i :PORT`.
- Not found: PATH, full path, package; 127 vs 126.
- Cron: did it try, full paths, `%`, redirect output.

**Self-check:**

1. Which command shows the permissions of every directory on a path?
2. What do exit codes 126 and 127 mean?
3. Why might a script work by hand but fail in cron?
