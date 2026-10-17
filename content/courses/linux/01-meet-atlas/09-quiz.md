---
kind: quiz
id_key: linux/meet-atlas/quiz
course: linux
section: meet-atlas
section_title: "Chapter 1: Meet Atlas - the Shell and the Map"
section_position: 1
title: "Quiz: the Shell and the Map"
position: 8
estimated_minutes: 8
pass_percentage: 70
duration_minutes: 10
source:
  - Chapter 1 lessons
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "A colleague says 'we upgraded Linux from 22.04 to 24.04'. What did they most likely upgrade?"
    options:
      - text: "Only the kernel"
      - text: "The Ubuntu distribution (which also brought a newer kernel and tools)"
        correct: true
      - text: "The shell, from sh to bash"
      - text: "The terminal program"
    explanation: "22.04 and 24.04 are Ubuntu release numbers, so the distribution was upgraded. Kernel versions look like 6.8.0; the shell and the terminal are single programs and have their own versions."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Brewbot misbehaves. Where do you look first for its configuration and its logs?"
    options:
      - text: "/usr/brewbot and /tmp"
      - text: "/etc/brewbot and /var/log/brewbot"
        correct: true
      - text: "/proc/brewbot and /dev/brewbot"
      - text: "/root/brewbot and /boot"
    explanation: "/etc holds configuration, /var/log holds logs. /usr is for package-managed programs, /tmp is scratch space, /proc and /dev are kernel views of processes and devices, /root is the root user's home and /boot holds the kernel."
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You are in /home/labuser. Which command does NOT take you to /var/log?"
    options:
      - text: "cd /var/log"
      - text: "cd ../../var/log"
      - text: "cd var/log"
        correct: true
      - text: "cd /var; cd log"
    explanation: "var/log is relative, so from /home/labuser it means /home/labuser/var/log, which does not exist. The absolute path works from anywhere, ../../ climbs to / first, and the two-step cd uses an absolute path then a relative one from /var."
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "type cd prints 'cd is a shell builtin'. What does that tell you?"
    options:
      - text: "cd is a program in /usr/bin"
      - text: "cd is part of bash itself, so help cd documents it rather than a man page"
        correct: true
      - text: "cd is an alias you can delete"
      - text: "cd only works for root"
    explanation: "Builtins run inside the shell. That is why which cd finds no file and man cd has no page; help cd does. An alias would print 'is aliased to', and builtins work for every user."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You ran PATH=$HOME/bin in your terminal. Now ls says 'command not found'. Why?"
    options:
      - text: "ls was deleted"
      - text: "PATH now contains only $HOME/bin, so bash no longer searches /usr/bin where ls lives"
        correct: true
      - text: "The kernel blocks ls after PATH changes"
      - text: "You need to reboot after editing PATH"
    explanation: "You replaced the search list instead of extending it. The right form is export PATH=\"$HOME/bin:$PATH\". Nothing was deleted, the kernel is not involved, and a new shell (not a reboot) restores the default."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You exported DB_HOST=db1 in one terminal, then started brewbot from a second terminal. Brewbot does not see DB_HOST. Why?"
    options:
      - text: "export only works for root"
      - text: "Each shell has its own environment; the second terminal never had DB_HOST"
        correct: true
      - text: "Environment variables must be lowercase"
      - text: "Brewbot needs to be started with sudo"
    explanation: "Environment variables are copied from a shell to its children only. The second terminal is a separate shell. Put the export in ~/.bashrc or in the service's own config. Any user can export, and case does not matter."
  - id_key: q7
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Where should you put an alias so it exists in every new interactive bash shell?"
    options:
      - text: "~/.bashrc"
        correct: true
      - text: "/tmp/aliases"
      - text: "/proc/self/aliases"
      - text: "/etc/hostname"
    explanation: "Bash reads ~/.bashrc at the start of every interactive shell. /tmp is scratch space bash never reads, /proc is a kernel view, and /etc/hostname only holds the machine name."
  - id_key: q8
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Why is a file called .tom-note not shown by ls?"
    options:
      - text: "It has secret permissions"
      - text: "Names starting with a dot are hidden by convention; ls -a shows them"
        correct: true
      - text: "It is encrypted"
      - text: "Only root can see dot-files"
    explanation: "A leading dot is purely a naming convention. Anyone who can list the directory sees it with ls -a. It is not a permission, not encryption, and not limited to root."
---
