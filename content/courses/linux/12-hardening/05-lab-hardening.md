---
kind: lesson
id_key: linux/hardening/lab-audit
course: linux
section: hardening
section_title: "Chapter 12: Locking Down Atlas - Security Hardening"
section_position: 12
title: "Lab: Audit and Harden Tom's Leftovers"
position: 4
estimated_minutes: 25
source:
  - find(1), chmod(1), sshd_config(5) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 40
  max_resets: 3
  is_required: false
  workspace_layout: console
  files:
    - path: audit/auth.log
      content: |
        Nov 23 03:11:02 atlas sshd[2101]: Failed password for root from 198.51.100.23 port 40122 ssh2
        Nov 23 03:11:05 atlas sshd[2101]: Failed password for root from 198.51.100.23 port 40122 ssh2
        Nov 23 03:11:09 atlas sshd[2104]: Failed password for invalid user admin from 203.0.113.77 port 51811 ssh2
        Nov 23 03:12:41 atlas sshd[2110]: Accepted publickey for rhea from 10.0.0.7 port 51522 ssh2
        Nov 23 03:13:00 atlas sshd[2115]: Failed password for invalid user test from 198.51.100.23 port 40188 ssh2
        Nov 23 03:13:04 atlas sshd[2115]: Failed password for invalid user oracle from 198.51.100.23 port 40188 ssh2
        Nov 23 03:14:22 atlas sshd[2120]: Failed password for root from 192.0.2.150 port 33001 ssh2
        Nov 23 03:14:25 atlas sshd[2120]: Failed password for root from 192.0.2.150 port 33001 ssh2
        Nov 23 03:15:10 atlas sshd[2131]: Failed password for invalid user deploy from 203.0.113.77 port 51990 ssh2
        Nov 23 03:16:45 atlas sshd[2140]: Failed password for root from 198.51.100.23 port 40301 ssh2
        Nov 23 03:17:02 atlas sudo:     rhea : TTY=pts/0 ; PWD=/home/rhea ; USER=root ; COMMAND=/usr/bin/apt update
        Nov 23 03:18:30 atlas sshd[2150]: Failed password for invalid user pi from 192.0.2.150 port 33100 ssh2
  setup_script: |
    a=/home/labuser/work/audit
    rm -rf $a/srv $a/app $a/tools $a/sshd_config.d /home/labuser/work/answers
    mkdir -p $a/srv/www $a/srv/uploads $a/app $a/tools /home/labuser/work/answers
    echo '<h1>Orbit Coffee</h1>' > $a/srv/www/index.html
    echo 'echo checking' > $a/tools/check.sh
    echo 'echo rotating' > $a/tools/rotate.sh
    printf '#!/bin/bash\nexec /bin/bash -p\n' > $a/tools/.helper
    printf '#!/bin/bash\necho status\n' > $a/tools/brewstat
    echo 'DB_PASSWORD=espresso' > $a/app/.env
    echo 'name = brewbot' > $a/app/brewbot.conf
    chmod 755 $a/srv $a/srv/www $a/app $a/tools
    chmod 777 $a/srv/uploads
    chmod 666 $a/srv/www/index.html
    chmod 777 $a/tools/check.sh
    chmod 755 $a/tools/rotate.sh
    chmod 4755 $a/tools/.helper
    chmod 4755 $a/tools/brewstat
    chmod 644 $a/app/.env
    chmod 644 $a/app/brewbot.conf
  tasks:
    - id_key: find-suid
      title: Find the SUID files
      points: 20
      is_stateful: true
      description: List every file under /home/labuser/work/audit that has the SUID bit set, one full path per line, into /home/labuser/work/answers/suid.txt.
      verification_script: |
        a=/home/labuser/work/audit
        diff <(find $a -type f -perm -4000 | sort) <(grep -v '^$' /home/labuser/work/answers/suid.txt | sort) >/dev/null
      hint_context: find /home/labuser/work/audit -type f -perm -4000 lists them. Hidden files count too - find shows them, ls does not.
      explanation_context: SUID makes a program run as its owner. A SUID file that execs bash -p is a classic backdoor - whoever runs it keeps the owner's privileges. Audit these regularly.
      solution_script: |
        find /home/labuser/work/audit -type f -perm -4000 > /home/labuser/work/answers/suid.txt
    - id_key: remove-suid
      title: Defuse the backdoor
      points: 15
      is_stateful: true
      description: Remove the SUID bit from the hidden helper script tools/.helper (keep its other permissions as they are). Leave brewstat alone.
      verification_script: |
        a=/home/labuser/work/audit/tools
        [ "$(stat -c %a $a/.helper)" = 755 ] && [ "$(stat -c %a $a/brewstat)" = 4755 ]
      hint_context: chmod u-s removes only the SUID bit.
      explanation_context: chmod u-s clears SUID and leaves rwx untouched. On a real server you would first copy the file and record stat output as evidence, then investigate how it got there.
      solution_script: |
        chmod u-s /home/labuser/work/audit/tools/.helper
    - id_key: fix-world-writable
      title: Close the world-writable files and directories
      points: 25
      is_stateful: true
      description: Remove write permission for others from every file and directory under /home/labuser/work/audit, without changing any other permission bits.
      verification_script: |
        a=/home/labuser/work/audit
        [ -z "$(find $a -perm -o+w)" ] &&
        [ "$(stat -c %a $a/tools/check.sh)" = 775 ] &&
        [ "$(stat -c %a $a/srv/uploads)" = 775 ] &&
        [ "$(stat -c %a $a/srv/www/index.html)" = 664 ] &&
        [ "$(stat -c %a $a/tools/rotate.sh)" = 755 ]
      hint_context: find /home/labuser/work/audit -perm -o+w lists them; add -exec chmod o-w {} + to fix all at once.
      explanation_context: chmod o-w removes only the others-write bit, so owners and groups keep their access. A chmod -R 755 would also have changed files that were fine.
      solution_script: |
        find /home/labuser/work/audit -perm -o+w -exec chmod o-w {} +
    - id_key: protect-secret
      title: Lock the secret
      points: 15
      is_stateful: true
      description: Make app/.env readable and writable by its owner only.
      verification_script: |
        [ "$(stat -c %a /home/labuser/work/audit/app/.env)" = 600 ]
      hint_context: chmod 600 /home/labuser/work/audit/app/.env
      explanation_context: Secrets files must be 600 (or 640 with a service group). Anyone who can read .env can log into the database.
      solution_script: |
        chmod 600 /home/labuser/work/audit/app/.env
    - id_key: sshd-dropin
      title: Write the SSH hardening drop-in
      points: 15
      is_stateful: true
      description: >-
        Create /home/labuser/work/audit/sshd_config.d/10-hardening.conf that disables
        password authentication, forbids root login and allows at most 3
        authentication attempts per connection.
      verification_script: |
        f=/home/labuser/work/audit/sshd_config.d/10-hardening.conf
        grep -Eiq '^\s*PasswordAuthentication\s+no\s*$' $f &&
        grep -Eiq '^\s*PermitRootLogin\s+no\s*$' $f &&
        grep -Eiq '^\s*MaxAuthTries\s+3\s*$' $f
      hint_context: One setting per line - PasswordAuthentication no, PermitRootLogin no, MaxAuthTries 3.
      explanation_context: On a real server this file goes in /etc/ssh/sshd_config.d/, followed by sshd -t, sshd -T to confirm, a reload, and a test login from a second terminal.
      solution_script: |
        mkdir -p /home/labuser/work/audit/sshd_config.d
        printf 'PasswordAuthentication no\nPermitRootLogin no\nMaxAuthTries 3\n' > /home/labuser/work/audit/sshd_config.d/10-hardening.conf
    - id_key: top-attacker
      title: Who is attacking?
      points: 10
      is_stateful: true
      description: From audit/auth.log, find the IP address with the most "Failed password" lines and save only that IP into answers/attacker.txt.
      verification_script: |
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/attacker.txt)" = 198.51.100.23 ]
      hint_context: grep 'Failed password' auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -1
      explanation_context: The IP is the fourth field from the end of each OpenSSH failure line. The top-N pipeline from chapter 3 turns a log into a ranking in one line; fail2ban automates the same idea.
      solution_script: |
        grep 'Failed password' /home/labuser/work/audit/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}' > /home/labuser/work/answers/attacker.txt
---

## Why this matters

Tom's leftovers are in `~/work/audit`: a small copy of a web root, an app, some
tools and an auth log. Somewhere in there is a backdoor, a leaked secret and
files anyone can change. Audit it, fix it, and harden SSH. Each task is checked
automatically.

## Before you start

```bash
cd ~/work/audit
ls -laR
```

What this does: lists everything, including hidden files, with permissions. Look
for `s` in the owner execute position and `w` in the last triplet.

## Task 1: find the SUID files

List every SUID file under `~/work/audit`, one full path per line, into
`~/work/answers/suid.txt`.

[[lab-task:1]]

## Task 2: defuse the backdoor

`tools/.helper` is a script that runs `bash -p`: with SUID, a privileged shell.
Remove its SUID bit; leave `brewstat` alone.

[[lab-task:2]]

## Task 3: close the world-writable files and directories

Remove write permission for others from everything under `~/work/audit`,
changing no other bits.

[[lab-task:3]]

What you should see afterwards:

```
$ find ~/work/audit -perm -o+w
$
```

## Task 4: lock the secret

Make `app/.env` readable and writable by its owner only.

[[lab-task:4]]

## Task 5: write the SSH hardening drop-in

Create `audit/sshd_config.d/10-hardening.conf`: no password authentication, no
root login, at most 3 authentication attempts.

[[lab-task:5]]

## Task 6: who is attacking?

From `audit/auth.log`, save the IP with the most `Failed password` lines into
`answers/attacker.txt`.

[[lab-task:6]]

## Remember

- `find -perm -4000` for SUID, `-perm -o+w` for world-writable.
- Fix only the bad bit: `chmod u-s`, `chmod o-w`.
- Secrets 600; SSH: keys only, no root, few attempts.
- Logs plus the top-N pipeline show who is attacking.

> **End of week 3.** Atlas is patched, locked down and audited. Rhea reads your
> report and nods: "Black Friday is next week. You're on call." Tom's last note,
> stuck to the server rack: "When it breaks, stay calm and follow the method."
