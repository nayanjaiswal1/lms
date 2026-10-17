---
kind: quiz
id_key: linux/incident-week/quiz
course: linux
section: incident-week
section_title: "Chapter 13: Incident Week - Troubleshooting Playbook"
section_position: 13
title: "Quiz: Troubleshooting Scenarios"
position: 8
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Chapter 13 lessons, interleaved with earlier chapters
questions:
  - id_key: q1
    type: mcq
    difficulty: advanced
    points: 2
    prompt: "You deleted a 20 GB log with rm, but df still shows the disk full. What is the most likely reason?"
    options:
      - text: "A running process still has the deleted file open, so its space is not released"
        correct: true
      - text: "rm only moves files to a hidden trash folder"
      - text: "df caches results for 24 hours"
      - text: "The filesystem needs to be reformatted"
    explanation: "The inode lives until the last open handle closes. lsof +L1 finds it; restart the process or truncate via /proc/PID/fd. Linux has no trash for rm, df reads live values, and reformatting is never needed for this."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "The 1-minute load is 9 on a 4-CPU server and climbing, top shows us 90 and wa 0. Which process do you look for first?"
    options:
      - text: "The top CPU users (top then P, or ps aux --sort=-%cpu)"
        correct: true
      - text: "Processes in D state"
      - text: "The biggest RSS"
      - text: "Zombies"
    explanation: "High user CPU with no IO wait is CPU demand; find who uses it. D state is for disk waits (wa would be high), RSS is memory, and zombies use no CPU."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "brewbot fails to start with 'bind: Address already in use' on port 8080. What is the first command?"
    options:
      - text: "sudo ss -tulpn | grep :8080"
        correct: true
      - text: "sudo systemctl daemon-reload"
      - text: "sudo ufw allow 8080"
      - text: "chmod 777 /opt/brewbot"
    explanation: "Find out who already holds the port (often an old copy of brewbot). daemon-reload re-reads units, the firewall is not involved in binding, and permissions do not cause this error."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Customers get 502 Bad Gateway from nginx. What does that tell you?"
    options:
      - text: "nginx is running, but the application behind it is down or unreachable on its upstream address"
        correct: true
      - text: "nginx itself is down"
      - text: "DNS for the site is broken"
      - text: "The customers' browsers are broken"
    explanation: "nginx answered with an error, so it is up; it failed talking to the upstream. If nginx were down there would be no HTTP response, and DNS failures stop before any connection."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "After an fstab edit, the server boots into emergency mode. What is the right recovery path?"
    options:
      - text: "From the console: mount -o remount,rw /, fix or comment the bad fstab line (or add nofail), mount -a, reboot"
        correct: true
      - text: "Reinstall the OS"
      - text: "Press Ctrl+C until it boots"
      - text: "Delete /etc/fstab completely"
    explanation: "Emergency mode gives a root shell with / read-only; remount, fix the line and test with mount -a. Reinstalling is overkill, Ctrl+C does nothing useful, and deleting fstab breaks all other mounts."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Brewbot will not start right after a teammate edited its config. Following the incident method, what do you do first?"
    options:
      - text: "Read the error with systemctl status and journalctl -u brewbot, then validate the changed config"
        correct: true
      - text: "Reboot the server and hope it comes back"
      - text: "chmod -R 777 /etc/brewbot so permissions cannot be the problem"
      - text: "Reinstall the operating system"
    explanation: "Every Real Linux Pro Checks: Error, Resources, Logs, Permissions, Changes. A recent config change plus a startup failure points straight at the config: read the logs, fix one thing, validate, restart."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "apt update fails with 'Release file is not valid yet' and TLS errors appear everywhere. What do you check?"
    options:
      - text: "The system clock: timedatectl, and enable NTP"
        correct: true
      - text: "The disk space"
      - text: "The sudoers file"
      - text: "The swap size"
    explanation: "'Not valid yet' means the machine thinks it is earlier than the certificate's start date. Disk, sudo and swap do not affect certificate validity."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which root cause statement leads to the most useful post-mortem action items?"
    options:
      - text: "Debug logging was enabled in production and the log had no rotation or disk alert"
        correct: true
      - text: "The disk filled up"
      - text: "Sam made a mistake"
      - text: "Bad luck on a busy day"
    explanation: "Naming the conditions that allowed the failure points to fixes (logrotate, alerts, config checks). 'Disk filled' is the trigger, blaming a person hides the system problem, and luck is not actionable."
  - id_key: q9
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (chapter 12): during the incident you are tempted to chmod 777 a directory to make a 'Permission denied' go away. Why not?"
    options:
      - text: "It lets every user and every compromised service modify the files; find the real cause (owner, group, parent directory, MAC) instead"
        correct: true
      - text: "chmod 777 is not a valid mode"
      - text: "It requires a reboot to take effect"
      - text: "It would make the files read-only"
    explanation: "777 is valid and takes effect at once, which is exactly why it is dangerous: it removes all write protection. The real fix is the specific missing permission."
---
