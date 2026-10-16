---
kind: lesson
id_key: linux/incident-week/the-method
course: linux
section: incident-week
section_title: "Chapter 13: Incident Week - Troubleshooting Playbook"
section_position: 13
title: "The Method: Stay Calm and Check E-R-L-P-C"
position: 0
estimated_minutes: 7
source:
  - Brendan Gregg, "Linux Performance Analysis in 60,000 Milliseconds" (brendangregg.com)
  - Google SRE Book, chapter 12 "Effective Troubleshooting" (sre.google)
---

## Why this matters

> **Black Friday, 9:02am.** The sale went live two minutes ago and your pager is
> screaming: *disk 99% full, brewbot erroring, deploy failing.* Rhea is on a
> plane. Tom's last note: **"When it breaks, stay calm and follow the method."**

Under pressure, people try random fixes, and random fixes make outages longer
and destroy evidence. A fixed sequence of checks keeps you calm and finds the
cause faster. Everything from chapters 1-12 gets used here.

## Mental model: a doctor's checklist

A doctor does not guess. They check vital signs in a fixed order, then form one
hypothesis, test it, and treat. Do the same:

```
 1. ERROR       read the exact error message - all of it
 2. RESOURCES   disk (df -h, df -i), memory (free -h), CPU/load (uptime, top)
 3. LOGS        systemctl status X, journalctl -u X, /var/log/*, dmesg
 4. PERMISSIONS ls -l, namei -l, id, who owns it, can this user reach it?
 5. CHANGES     what changed recently? deploys, config edits, updates, certs
```

> **Memory hook:** "**E**very **R**eal **L**inux **P**ro **C**hecks": **E**rror,
> **R**esources, **L**ogs, **P**ermissions, **C**hanges.

Most incidents are found at step 1 (the error says it) or step 5 (someone changed
something).

## See it work: the first 60 seconds on any sick server

```bash
uptime                 # load average - is it busy? getting worse?
dmesg -T | tail        # kernel errors: OOM kills, disk errors
df -h; df -i           # space and inodes
free -h                # memory and swap
top                    # who is using CPU (P) and memory (M)?
systemctl --failed     # what is broken?
journalctl -p err -b   # errors since boot
ss -tulpn              # what is listening?
```

Then look at what changed:

```bash
last -n 5                                       # who logged in
grep -E ' install | upgrade ' /var/log/dpkg.log | tail   # package changes
journalctl --since "1 hour ago" | grep -iE 'deploy|reload|started'
ls -lt /etc | head                              # recently changed config
```

## How to work during an incident

1. **Stabilise first, fix later.** Freeing disk space or rolling back a deploy
   restores service; the root cause can wait an hour.
2. **Change one thing at a time,** and note what you changed and when (a
   timeline in a text file or the incident channel).
3. **Prefer reversible actions.** `mv` config aside instead of deleting;
   truncate instead of `rm` for open logs; `renice` before `kill`.
4. **Keep evidence.** Copy the failing config, save `journalctl` output, before
   restarting.
5. **Communicate.** A one-line status every 15 minutes ("disk freed, brewbot
   restarting, checkout still failing") stops people interrupting you.

## Try it

Brewbot will not start, right after a teammate edited its config. Using the
method, what do you do first, and which step probably holds the answer?

<details>
<summary>Show answer</summary>

Step 1: read the error (`systemctl status brewbot`, then `journalctl -u brewbot
-n 50`). Step 5 (Changes) is the likely cause: diff the config against the
backup or Git, validate it with the program's own checker, fix one line, restart.

</details>

## Common mistakes

- **Rebooting first.** It may "fix" it for an hour and wipes the evidence
  (unless the journal is persistent).
- **Changing several things at once.** You never learn which one helped.
- **Ignoring the exact error text.** "Permission denied", "No space left" and
  "Address already in use" each point straight at one scenario.
- **Fixing alone in silence.** Tell people what you are doing.

## Remember

- E-R-L-P-C: Error, Resources, Logs, Permissions, Changes.
- First 60 s: `uptime`, `dmesg`, `df -h/-i`, `free`, `top`, `systemctl
  --failed`, `journalctl -p err -b`, `ss -tulpn`.
- Stabilise, one change at a time, reversible, keep evidence, communicate.

**Self-check:**

1. What do the letters E-R-L-P-C stand for?
2. Why is rebooting first a bad habit?
3. Name two reversible alternatives to deleting something during an incident.
