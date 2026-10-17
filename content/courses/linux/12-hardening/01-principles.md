---
kind: lesson
id_key: linux/hardening/principles
course: linux
section: hardening
section_title: "Chapter 12: Locking Down Atlas - Security Hardening"
section_position: 12
title: "Hardening Principles: Least Privilege and a Small Attack Surface"
position: 0
estimated_minutes: 7
source:
  - CIS Benchmarks for Ubuntu Linux (cisecurity.org)
  - Ubuntu Server documentation, "Security"; systemctl(1), ss(8), unattended-upgrades documentation
---

## Why this matters

> **Monday, week 3.** Rhea: "Black Friday makes us a target. Bots will hammer
> SSH, scan every port and try every old bug. Lock atlas down." Tom's note:
> *every open door is a risk*.

Most break-ins are not clever. They use a password that was guessed, a service
nobody remembered was running, or a bug fixed months ago but never patched.
Hardening is a short, boring checklist done every time.

## Mental model: a shop at closing time

Before leaving, you walk through the shop:

1. **Close doors you do not use** (attack surface).
2. **Give each key to as few people as possible** (least privilege).
3. **Fix broken locks quickly** (patching).
4. **Check the cameras** (logging and auditing, next lessons).
5. **Put a second lock on valuables** (defence in depth: firewall + auth +
   permissions + sandboxing).

## See it work: the baseline checklist

### 1. Patch

```bash
sudo apt update && apt list --upgradable
sudo apt install unattended-upgrades          # automatic security updates
cat /var/run/reboot-required 2>/dev/null      # kernel/libc updates need a reboot
```

### 2. Shrink the attack surface

```bash
sudo ss -tulpn                                # every listening port
systemctl list-units --type=service --state=running
sudo systemctl disable --now cups avahi-daemon   # stop what you do not need
sudo apt purge telnetd rsh-server             # remove what you never need
```

For every listener ask: do we need it, and does it need to listen on
`0.0.0.0`? Databases and caches should listen on `127.0.0.1` or a private
network only.

### 3. Firewall: default deny

```bash
sudo ufw default deny incoming
sudo ufw allow 22/tcp && sudo ufw allow 443/tcp
sudo ufw enable
```

(Chapter 8.) Only the ports you serve, and admin ports from known networks.

### 4. Least privilege for people and services

- Personal accounts plus `sudo`; no shared logins; no direct root login.
- Narrow sudo rules for teams (chapter 4).
- Every service runs as its own unprivileged user.
- Secrets in files with mode `600`/`640`, never world-readable, never in Git.
- Remove accounts of people who left; lock unused ones (`usermod -L`).

### 5. Sane file permissions

```bash
umask 027                                     # in /etc/profile or per service (UMask=)
sudo chmod 600 /etc/brewbot/env
sudo find / -xdev -type f -perm -o+w 2>/dev/null   # world-writable files: why?
```

Lesson 3 turns these into a full audit.

### 6. Keep the evidence

Persistent journal (chapter 6), `auth.log` shipped off the box (if attackers get
root, they edit local logs), time synced with NTP so timestamps line up.

### Automated checkers

```bash
sudo apt install lynis && sudo lynis audit system   # hardening report with suggestions
```

**Lynis** and the **CIS Benchmarks** are long checklists. Use them as guides,
apply what fits, and record what you skipped and why.

## Try it

`ss -tulpn` on atlas shows `0.0.0.0:6379 redis-server` and
`0.0.0.0:5432 postgres`. Only brewbot, on the same machine, uses them. What do
you change?

<details>
<summary>Show answer</summary>

Make both listen on `127.0.0.1` only (`bind 127.0.0.1` in `redis.conf`,
`listen_addresses = 'localhost'` in `postgresql.conf`), restart them, and check
`ss -tulpn` again. Also ensure the firewall does not allow 6379/5432 from
outside. Defence in depth: both fixes, not one.

</details>

## Common mistakes

- **Hardening once.** New packages and services appear; repeat the checklist
  (and automate it).
- **Relying on one layer.** A firewall rule removed by mistake should not expose
  an unauthenticated database.
- **Disabling updates "for stability".** Unpatched servers are the most common
  way in. Test, then patch.
- **Breaking your own access.** Keep a second session or the cloud console
  while changing SSH and firewall settings.

## Remember

- Patch, shrink the surface, default-deny firewall, least privilege, keep logs.
- `ss -tulpn` and `systemctl list-units` = your attack surface.
- Internal services listen on `127.0.0.1` or a private network.
- Lynis / CIS = checklists; defence in depth beats any single control.

**Self-check:**

1. What does "attack surface" mean on a server?
2. Why should Redis listen on `127.0.0.1` when only local apps use it?
3. Why ship logs off the machine?
