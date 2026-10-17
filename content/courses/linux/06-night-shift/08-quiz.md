---
kind: quiz
id_key: linux/night-shift/quiz
course: linux
section: night-shift
section_title: "Chapter 6: The Night Shift - systemd, Logs and Schedules"
section_position: 6
title: "Quiz: systemd, Logs and Schedules"
position: 7
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Chapter 6 lessons, plus one review question from chapter 5
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "brewbot runs fine after systemctl start, but is gone after every reboot. Which command fixes it for good?"
    options:
      - text: "sudo systemctl enable brewbot"
        correct: true
      - text: "sudo systemctl reload brewbot"
      - text: "sudo systemctl daemon-reload"
      - text: "sudo systemctl restart brewbot"
    explanation: "enable hooks the unit into the boot target. reload re-reads the app's config, daemon-reload re-reads unit files, and restart only affects the current boot."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You changed ExecStart in /etc/systemd/system/brewbot.service and restarted, but the old command still runs. What did you skip?"
    options:
      - text: "sudo systemctl daemon-reload"
        correct: true
      - text: "sudo systemctl enable brewbot"
      - text: "A reboot"
      - text: "chmod +x on the unit file"
    explanation: "systemd caches unit files; daemon-reload makes it read your edit. Enabling changes boot behaviour only, a reboot is overkill, and unit files are not executed so they need no x bit."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You need nginx to allow more open files. Where should the change go?"
    options:
      - text: "Edit /usr/lib/systemd/system/nginx.service directly"
      - text: "sudo systemctl edit nginx and add LimitNOFILE under [Service]"
        correct: true
      - text: "Add it to ~/.bashrc"
      - text: "Put it in /etc/crontab"
    explanation: "systemctl edit creates a drop-in in /etc/systemd/system/nginx.service.d/ that survives package updates. Vendor files in /usr/lib are overwritten on update, and shell or cron files do not affect a service's limits."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "systemctl status brewbot says 'Start request repeated too quickly'. You fixed the config. What next?"
    options:
      - text: "systemctl reset-failed brewbot, then systemctl start brewbot"
        correct: true
      - text: "Wait 24 hours"
      - text: "Reinstall systemd"
      - text: "kill -9 1"
    explanation: "systemd stopped retrying after hitting its start rate limit; reset-failed clears that state. Nothing resets on its own soon, reinstalling is pointless, and killing PID 1 would crash the system."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "atlas crashed at 3am and rebooted. Which command shows error messages from before the crash?"
    options:
      - text: "journalctl -b -1 -p err (with a persistent journal)"
        correct: true
      - text: "journalctl -b -p err"
      - text: "dmesg -T"
      - text: "systemctl --failed"
    explanation: "-b -1 selects the previous boot. -b alone is the current boot, dmesg shows the current boot's kernel buffer, and --failed lists units failing now."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "What does the crontab line */15 * * * 1-5 /opt/check.sh do?"
    options:
      - text: "Runs every 15 minutes, Monday to Friday"
        correct: true
      - text: "Runs at 15:00 on the first five days of the month"
      - text: "Runs 15 times a day on weekends"
      - text: "Runs every 15 hours"
    explanation: "Field 1 (minute) */15 = every 15 minutes, field 5 (day of week) 1-5 = Monday-Friday. Hour 15 would be in field 2, and day of month is field 3."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "backup.sh works when you run it by hand, but the cron job fails with 'pg_dump: command not found'. Why?"
    options:
      - text: "Cron runs with a minimal PATH and no .bashrc; use full paths or set PATH in the crontab"
        correct: true
      - text: "Cron cannot run shell scripts"
      - text: "pg_dump only works interactively"
      - text: "The crontab must be owned by root"
    explanation: "Cron's environment is tiny. Scripts run fine from cron when commands are reachable, pg_dump is non-interactive, and user crontabs are owned by the user."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "After logrotate ran, app.log is empty but app.log.1 keeps growing. What is missing from the config?"
    options:
      - text: "A postrotate step that tells the app to reopen its log (or copytruncate)"
        correct: true
      - text: "compress"
      - text: "missingok"
      - text: "rotate 30"
    explanation: "The app still holds the renamed file open. Signal it to reopen, or use copytruncate. compress, missingok and the number of kept copies do not change which file the app writes to."
  - id_key: q9
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why might you choose a systemd timer over a cron line for the nightly backup?"
    options:
      - text: "Its output goes to the journal automatically and Persistent=true catches up on runs missed while the server was off"
        correct: true
      - text: "Timers run faster"
      - text: "Cron is removed from modern Linux"
      - text: "Timers do not need a service unit"
    explanation: "Timers bring logging, catch-up and all service settings. Speed is the same, cron is still widely available, and a timer always triggers a service unit."
  - id_key: q10
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (chapter 5): a nightly job started by hand with & died when you logged out. What would have kept it running?"
    options:
      - text: "nohup (or tmux), because logout sends SIGHUP to the session's jobs"
        correct: true
      - text: "nice -n 19"
      - text: "kill -CONT"
      - text: "Running it with sudo"
    explanation: "nohup makes it ignore SIGHUP; tmux keeps the session alive. Niceness changes priority, SIGCONT resumes stopped jobs, and sudo does not protect from SIGHUP."
---
