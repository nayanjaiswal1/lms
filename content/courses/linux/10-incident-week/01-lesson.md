---
kind: lesson
id_key: linux/incident-week/lesson
course: linux
section: incident-week
section_title: "Chapter 10: Incident Week"
section_position: 10
title: Troubleshooting Real-World Scenarios
position: 0
estimated_minutes: 60
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
        nohup bash $w/bin/brewbot-worker >/dev/null 2>&1 &
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
      explanation_context: The script creates a full disk, a hung worker, a broken deploy, a bad config and a missing command under ~/work/incident - one for each scenario that follows.
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
---

> **Black Friday.** 9:02am. The sale went live two minutes ago and your pager is screaming: *disk 99% full, brewbot erroring, deploy failing.* Rhea is on a plane. Tom's last note is taped to the rack: **"When it breaks, stay calm and follow the method."** Everything you learned in chapters 1-9 now gets used at once.

## The method

Panicking and trying random fixes makes outages longer. Follow the same five steps every time:

```
 1. ERROR       read the exact error message - all of it
 2. RESOURCES   disk (df -h, df -i), memory (free -h), CPU/load (uptime, top)
 3. LOGS        systemctl status X, journalctl -u X, /var/log/*, dmesg
 4. PERMISSIONS ls -l, namei -l, id, who owns it, can this user reach it?
 5. CHANGES     what changed recently? deploys, config edits, updates, certs
```

> **Memory hook:** "**E**very **R**eal **L**inux **P**ro **C**hecks" - **E**rror, **R**esources, **L**ogs, **P**ermissions, **C**hanges.

And the first 60 seconds on any sick server:

```bash
uptime                 # load average - is it busy?
dmesg -T | tail        # kernel errors: OOM kills, disk errors
df -h; df -i           # space and inodes
free -h                # memory and swap
top                    # who is using CPU and memory?
systemctl --failed     # what is broken?
journalctl -p err -b   # errors since boot
ss -tulpn              # what is listening?
```

[[lab-task:1]]

## Scenario 1: "No space left on device"

**Symptom:** writes fail, services crash, `No space left on device` in logs.

```bash
df -h                                   # which filesystem is full?
sudo du -xh / 2>/dev/null | sort -h | tail -20   # -x stays on one filesystem
sudo find / -xdev -type f -size +500M 2>/dev/null
sudo journalctl --vacuum-size=200M      # shrink the journal
sudo apt clean                          # drop downloaded package files
```

**Fix:** empty or compress the giant log with `truncate -s 0 file` (not `rm` if a process has it open), delete old rotated logs and backups. **Prevent:** logrotate, monitoring alerts at 80%, separate `/var` partition.

[[lab-task:2]]

## Scenario 2: df says full, du says not

You deleted a 20 GB log but `df` still says 100%. A process still has the deleted file **open**, so the inode and its blocks live on.

```bash
sudo lsof +L1                  # open files with zero links (deleted)
sudo lsof | grep deleted
```

**Fix:** restart the process that holds it (`systemctl restart brewbot`), or truncate through `/proc`: `: > /proc/PID/fd/N`. **Lesson:** truncate logs, don't `rm` them while in use.

## Scenario 3: disk has space but writes fail - inodes

`df -h` shows 40% used, yet files cannot be created. **`df -i`** shows 100% IUse - millions of tiny files (sessions, cache, mail queue) used every inode.

```bash
df -i
sudo find /var -xdev -type f | cut -d/ -f2-3 | sort | uniq -c | sort -rn | head
```

**Fix:** delete the junk files (e.g. `find /var/lib/php/sessions -mtime +2 -delete`), fix the app that creates them.

## Scenario 4: a runaway or hung process

**Symptom:** server slow, one process at 100% CPU, or a worker that stopped doing anything.

```bash
top                            # press P (CPU) or M (memory)
ps aux --sort=-%cpu | head
pgrep -af brewbot-worker
kill PID; sleep 5; kill -9 PID # 15 first, 9 only if needed
```

**Prevent:** `Restart=on-failure` in the unit file, CPU limits (`CPUQuota=` in systemd), timeouts in the code.

[[lab-task:3]]

## Scenario 5: the OOM killer

**Symptom:** a process vanished with no error in its own log.

```bash
dmesg -T | grep -i -E 'killed process|out of memory'
journalctl -k | grep -i oom
free -h
```

When memory runs out the kernel's **OOM killer** kills the process with the highest score (usually the biggest). **Fix:** find the memory leak, add RAM or swap, set `MemoryMax=` on the service so it dies instead of the database.

## Scenario 6: high load, idle CPU - waiting on disk

`uptime` shows load 12 on 4 CPUs but `top` shows the CPU mostly idle. Look at `wa` (IO wait) in top's CPU line, and processes in state **`D`**.

```bash
top                       # %Cpu(s): ... 85.0 wa
vmstat 1                  # the "wa" and "b" (blocked) columns
iostat -x 1               # disk %util (sysstat package)
ps -eo state,pid,cmd | grep '^D'
```

Load counts processes **waiting**, not just computing. **Fix:** find the IO-heavy process (`iotop`), a slow or failing disk (`dmesg`), or a backup running at peak time (renice it, `ionice -c3`).

## Scenario 7: "Permission denied"

```bash
ls -l deploy.sh               # is the x bit set? who owns it?
namei -l /srv/shop/deploy.sh  # permissions of EVERY directory on the path
id                            # which user and groups am I?
mount | grep noexec           # is the filesystem mounted noexec?
```

**Fix:** `chmod u+x`, `chown` to the right user, add the user to the group (`usermod -aG`, then log in again), or run as the right user (`sudo -u www-data`). **Never** fix it with `chmod 777`.

[[lab-task:4]]

## Scenario 8: the service will not start

```bash
systemctl status brewbot            # state + last log lines
journalctl -u brewbot -n 50 --no-pager
sudo nginx -t                       # many programs validate their own config
sudo sshd -t
```

Usual causes: a typo in the config, a missing file, wrong permissions on a config or key, the port already in use, or a dependency (database) not up yet. **Fix one thing, validate, then restart.** If systemd gave up ("start request repeated too quickly"), run `systemctl reset-failed brewbot` first.

[[lab-task:5]]

## Scenario 9: "Address already in use"

```bash
sudo ss -tulpn | grep ':8080'       # who has the port?
sudo lsof -i :8080
```

Usually an old copy of the app is still running, or two services were configured with the same port. Stop the stray process or change one port.

## Scenario 10: "command not found"

```bash
echo $PATH
which brewctl ; type brewctl
ls -l /opt/brewbot/bin/
apt-file search bin/dig             # which package provides it? (or: dnf provides)
```

**Fix:** use the full path, add the directory to PATH in `~/.bashrc` (or `/etc/profile.d/` for everyone), or install the package. Under `sudo`, PATH is reset to `secure_path` - another common surprise.

[[lab-task:6]]

What you should see:

```
$ cd /tmp && brewctl status
brewbot: OK
```

## Scenario 11: cannot connect to a service

Work from the bottom up:

```
 1. is it running?          systemctl status brewbot
 2. is it listening?        ss -tulpn | grep 8080     (on 127.0.0.1 or 0.0.0.0?)
 3. works locally?          curl -v http://localhost:8080/
 4. reachable from outside? curl from another machine
 5. firewall?               sudo ufw status / cloud security group
```

- **Connection refused** - nothing is listening there (service down, wrong port, or bound to 127.0.0.1).
- **Connection timed out** - packets are dropped: firewall, security group, or routing.
- **502 Bad Gateway** from nginx - nginx is fine, the app behind it is not.

## Scenario 12: name resolution fails

`curl https://api.payments.example` fails, but `curl https://203.0.113.10` works.

```bash
dig api.payments.example +short
cat /etc/resolv.conf
getent hosts api.payments.example   # includes /etc/hosts
grep payments /etc/hosts            # a stale override?
```

**Fix:** correct the resolver, remove the stale `/etc/hosts` line, or wait out a DNS change (TTL). "It's always DNS."

## Scenario 13: SSH key refused

`Permission denied (publickey)`:

```bash
ssh -v deploy@atlas                     # client side: which keys were offered?
sudo tail -f /var/log/auth.log          # server side: why it refused
ls -ld ~ ~/.ssh ~/.ssh/authorized_keys  # home not group-writable, .ssh 700, keys 600
```

The usual cause is permissions that are too open on the server's `~/.ssh` or home directory, or the public key pasted into the wrong user's `authorized_keys`.

## Scenario 14: the cron job didn't run

```bash
grep CRON /var/log/syslog          # did cron even try?
crontab -l                         # is the line there, for the right user?
```

Cron runs with a minimal environment: use **full paths**, make the script **executable**, escape `%` (it means newline in crontab), and redirect output to a log (`>> /var/log/job.log 2>&1`) so failures are visible.

## Scenario 15: "Read-only file system"

The kernel remounts a filesystem read-only when it detects errors, to protect your data.

```bash
dmesg -T | grep -i -E 'ext4|i/o error|remount'
mount | grep ' / '                 # (ro, ...)
```

**Fix:** check the disk's health, schedule `fsck` on the unmounted filesystem (or from recovery mode for `/`), and restore from backup if the disk is failing. Do not just force a remount read-write.

## Scenario 16: TLS errors and wrong times

`certificate is not yet valid`, failing `apt update`, or confusing log timestamps - the clock is off.

```bash
timedatectl                        # is "System clock synchronized: yes"?
sudo timedatectl set-ntp true      # turn on NTP sync (systemd-timesyncd / chrony)
```

Also check that a certificate really has not expired: `echo | openssl s_client -connect orbit.coffee:443 2>/dev/null | openssl x509 -noout -dates`.

## Scenario 17: locked out of sudo

You broke `/etc/sudoers` or removed yourself from the sudo group. Never edit sudoers without `visudo` - it refuses to save a broken file. If it happens anyway: use another admin account, `pkexec visudo` on desktops, or boot into **recovery mode** (or the cloud provider's serial console) to fix it as root.

## Cheat sheet: symptom to first command

| Symptom | First command |
|---|---|
| No space left | `df -h`, then `du -xh / \| sort -h` |
| Full but nothing big | `lsof +L1` (deleted-open files), `df -i` (inodes) |
| Slow server | `uptime`, `top`, `vmstat 1` |
| Process vanished | `dmesg -T \| grep -i oom` |
| Permission denied | `ls -l`, `namei -l path`, `id` |
| Service down | `systemctl status X`, `journalctl -u X` |
| Port in use | `ss -tulpn \| grep :PORT` |
| Can't connect | `ss -tulpn`, `curl -v localhost`, firewall |
| Name doesn't resolve | `dig name`, `/etc/resolv.conf`, `/etc/hosts` |
| SSH refused | `ssh -v`, `/var/log/auth.log`, `~/.ssh` permissions |
| Cron didn't run | `grep CRON /var/log/syslog`, full paths |
| Read-only FS | `dmesg -T`, then fsck |
| command not found | `echo $PATH`, `which`, install package |

## The post-mortem

When the fire is out, write down: what happened, the timeline, the root cause, how it was fixed, and **what will stop it happening again** (a logrotate rule, an alert, a script). No blame - systems fail, people learn.

> **The end of Black Friday.** By 9:40am the disk was clear, the hung worker gone, the deploy shipped, brewbot back on port 8080, and the runbook command fixed. Orders hit a record. Rhea lands, reads your post-mortem, and pins Tom's notes to the wall - next to your name. You are atlas's admin now.
