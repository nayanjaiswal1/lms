---
kind: quiz
id_key: linux/hardening/quiz
course: linux
section: hardening
section_title: "Chapter 12: Locking Down Atlas - Security Hardening"
section_position: 12
title: "Quiz: Security Hardening"
position: 5
estimated_minutes: 8
pass_percentage: 70
duration_minutes: 10
source:
  - Chapter 12 lessons, plus one review question from chapter 11
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "ss -tulpn shows redis-server on 0.0.0.0:6379. Only brewbot on the same machine uses Redis. What is the best fix?"
    options:
      - text: "Bind Redis to 127.0.0.1 and also make sure the firewall does not allow 6379 from outside"
        correct: true
      - text: "Move Redis to port 6380"
      - text: "Run Redis as root"
      - text: "Nothing; Redis has no security issues"
    explanation: "Listen only where clients are, and keep the firewall as a second layer (defence in depth). A different port only hides it, root makes a compromise worse, and exposed Redis instances are a common way in."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You added PasswordAuthentication no in a drop-in and want to apply it safely. What is the right order?"
    options:
      - text: "sshd -t, sshd -T to confirm the value, reload ssh, then test a login from a NEW terminal before closing the old one"
        correct: true
      - text: "Reboot the server and hope"
      - text: "Restart ssh and log out immediately"
      - text: "Delete authorized_keys first"
    explanation: "Check syntax, confirm the effective value, reload (existing sessions survive), and prove you can still get in. The other options risk locking you out."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "An audit finds -rwsr-xr-x root root /var/tmp/.x/sh that no package owns. What is the right response?"
    options:
      - text: "Treat it as a likely compromise: preserve evidence, investigate logins and cron, and plan a rebuild and credential rotation"
        correct: true
      - text: "chmod u-s and move on"
      - text: "Delete it and reboot"
      - text: "Ignore it; /var/tmp is temporary"
    explanation: "A SUID-root shell in a temp directory is a backdoor; something put it there with root access. Removing the bit or the file alone leaves whatever else the attacker changed, and deleting first destroys evidence."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which command removes write access for others from everything under /srv/shop while keeping all other bits?"
    options:
      - text: "find /srv/shop -perm -o+w -exec chmod o-w {} +"
        correct: true
      - text: "chmod -R 755 /srv/shop"
      - text: "chmod -R 000 /srv/shop"
      - text: "chown -R root /srv/shop"
    explanation: "chmod o-w clears only that bit on exactly the files that have it. 755 changes every file (making them executable), 000 breaks everything, and chown changes ownership, not the others-write bit."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "On a RHEL server nginx returns 403 for files you moved from your home into the web root. ls -l looks fine. What is likely, and what is the right fix?"
    options:
      - text: "Wrong SELinux labels from mv; run restorecon -Rv on the web root"
        correct: true
      - text: "Run setenforce 0 permanently"
      - text: "chmod 777 the files"
      - text: "Reinstall nginx"
    explanation: "mv keeps the home-directory label, which nginx may not read; restorecon resets labels to the policy. Disabling SELinux removes protection everywhere, 777 does not change labels, and nginx itself is fine."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "What does fail2ban do for SSH?"
    options:
      - text: "Watches the auth log and temporarily blocks IPs with too many failed logins"
        correct: true
      - text: "Encrypts SSH traffic"
      - text: "Replaces passwords with keys"
      - text: "Moves SSH to a random port"
    explanation: "fail2ban counts failures per IP and adds firewall bans. SSH already encrypts, keys are configured in sshd, and port changes are unrelated."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which unit-file line stops a service from ever gaining privileges through SUID binaries?"
    options:
      - text: "NoNewPrivileges=yes"
        correct: true
      - text: "PrivateTmp=yes"
      - text: "Restart=on-failure"
      - text: "User=root"
    explanation: "NoNewPrivileges blocks privilege gain via SUID/SGID and file capabilities. PrivateTmp isolates /tmp, Restart is about crashes, and User=root does the opposite of hardening."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (chapter 11): during a brute-force attack sshd uses lots of CPU. top shows sy high and many short-lived sshd processes. Which USE category and fix fit best?"
    options:
      - text: "CPU saturation from unwanted work; reduce the work with fail2ban and firewall rules limiting SSH to known networks"
        correct: true
      - text: "Disk saturation; add a faster disk"
      - text: "Memory errors; add RAM"
      - text: "Nothing; this is normal load"
    explanation: "The CPU is busy handling attack connections. Removing the attack traffic is the fix. Disk and memory are not involved, and sustained attack load is not normal."
---
