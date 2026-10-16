---
kind: lesson
id_key: linux/hardening/auditing
course: linux
section: hardening
section_title: "Chapter 12: Locking Down Atlas - Security Hardening"
section_position: 12
title: "Auditing a Server: SUID Files, Open Permissions, Accounts and Logins"
position: 2
estimated_minutes: 8
source:
  - find(1), last(1), lastlog(8), auditd(8), auditctl(8), ausearch(8) manual pages; AIDE documentation
---

## Why this matters

Tom left a month ago. Did he leave a SUID backdoor, a world-writable script that
root runs from cron, or an extra UID 0 account? An audit answers "what is on this
box that should not be?" with a handful of `find` and `awk` commands you already
know.

## Mental model: an inventory walk

Walk the shop with a checklist and write down anything unusual:

```
 1. Privileged files      SUID/SGID binaries, file capabilities
 2. Open permissions      world-writable files and directories, secrets readable by all
 3. Accounts              UID 0, empty passwords, unexpected logins, sudo rights
 4. Logins and changes    last/lastb, auth log, package history
 5. Integrity             are system files what the packages installed?
```

## See it work

### 1. Privileged files

```bash
sudo find / -xdev -perm -4000 -type f 2>/dev/null     # SUID
sudo find / -xdev -perm -2000 -type f 2>/dev/null     # SGID
getcap -r / 2>/dev/null                               # file capabilities
```

Compare against a known-good server or the package list: `dpkg -S` on each path
should name a package. A SUID file that no package owns (`dpkg -S` says "no path
found") in `/tmp`, `/home` or `/var` is a red flag.

### 2. Open permissions

```bash
sudo find / -xdev -type f -perm -o+w 2>/dev/null                  # world-writable files
sudo find / -xdev -type d -perm -o+w ! -perm -1000 2>/dev/null     # world-writable dirs without sticky bit
sudo find /etc /opt /srv -name '*.env' -perm /o+r 2>/dev/null      # secrets readable by others
```

`-perm -o+w` means "at least these bits set"; `-perm /o+r` means "any of these
bits set". The worst case: a world-writable script that **root** runs (cron,
systemd). Anyone could add a line and become root.

Fix in bulk, keeping all other bits:

```bash
find /srv/shop -perm -o+w -exec chmod o-w {} +
```

### 3. Accounts

```bash
awk -F: '$3 == 0 {print $1}' /etc/passwd             # only root expected
sudo awk -F: '$2 == "" {print $1}' /etc/shadow        # empty passwords
awk -F: '$7 !~ /nologin|false/ {print $1, $7}' /etc/passwd   # who can log in
getent group sudo                                     # who has full sudo (wheel on RHEL)
sudo ls /etc/sudoers.d/ && sudo grep -r NOPASSWD /etc/sudoers /etc/sudoers.d/
for u in $(cut -d: -f1 /etc/passwd); do sudo crontab -l -u "$u" 2>/dev/null | sed "s/^/$u: /"; done
```

### 4. Logins and changes

```bash
last -n 20            # recent logins and reboots
sudo lastb -n 20      # failed logins
lastlog | grep -v 'Never logged in'
grep -E ' install | upgrade | remove ' /var/log/dpkg.log | tail
```

### 5. Integrity and auditing tools

- `debsums -s` (Debian/Ubuntu) or `rpm -Va` (RHEL) compare installed files with
  the package checksums: changed binaries stand out.
- **AIDE** builds a database of file hashes and reports changes later.
- **auditd** records chosen events in the kernel, for example every change to
  `/etc/passwd`:

```bash
sudo auditctl -w /etc/passwd -p wa -k identity
sudo ausearch -k identity --start today
```

## Try it

You find `-rwsr-xr-x root root /var/tmp/.cache/sh`. Is that normal? What do you
check, and what do you do?

<details>
<summary>Show answer</summary>

Not normal: a SUID-root shell in a temp directory is a classic backdoor (anyone
running it gets root). `dpkg -S /var/tmp/.cache/sh` will find no package. Treat
the server as compromised: preserve evidence (copy the file, note timestamps
with `stat`, check `last`, auth logs and cron), then follow your incident
process. Usually that means rebuilding the server from a clean image and
rotating credentials, not just deleting the file.

</details>

## Common mistakes

- **Running `find /` without `-xdev`.** It wanders into `/proc` and network
  mounts.
- **Deleting suspicious files immediately.** You lose the evidence of how and
  when. Copy and record first.
- **Fixing permissions with `chmod -R 755`.** It changes far more than needed;
  remove only the bad bit (`chmod o-w`).
- **Auditing only once.** Schedule it and diff the results.

## Remember

- SUID/SGID: `find / -xdev -perm -4000`; capabilities: `getcap -r /`.
- World-writable: `find -perm -o+w`; fix with `chmod o-w`.
- Accounts: UID 0, empty passwords, login shells, sudo group, crontabs.
- `last`, `lastb`, logs, package history; `debsums`/`rpm -Va`, AIDE, auditd.

**Self-check:**

1. What is the difference between `-perm -o+w` and `-perm /o+w`?
2. Why is a world-writable script run by root's cron dangerous?
3. Why copy evidence before deleting a suspicious file?
