---
kind: quiz
id_key: linux/engine-room/quiz
course: linux
section: engine-room
section_title: "Chapter 5: The Engine Room - Processes"
section_position: 5
title: "Quiz: Processes and Signals"
position: 6
estimated_minutes: 8
pass_percentage: 70
duration_minutes: 10
source:
  - Chapter 5 lessons, plus one review question from chapter 4
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You delete /usr/local/bin/brewbot-worker while it is running. What happens to the running worker?"
    options:
      - text: "It stops immediately"
      - text: "It keeps running; the process already has the program loaded, only the name is gone"
        correct: true
      - text: "It restarts"
      - text: "It becomes a zombie"
    explanation: "A process is a running instance; deleting the file removes a name, not the process. Nothing restarts it, and zombies are exited processes waiting for their parent."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A worker is stuck. What is the correct sequence?"
    options:
      - text: "kill -9 PID immediately"
      - text: "kill PID (SIGTERM), wait a few seconds, check, then kill -9 PID only if it is still there"
        correct: true
      - text: "kill -HUP PID and wait an hour"
      - text: "Reboot the server"
    explanation: "SIGTERM lets the program clean up. SIGKILL is the last resort because it can leave half-written files and stale locks. SIGHUP usually means reload, and a reboot punishes every other service."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A container exits with status 137. What does that tell you?"
    options:
      - text: "It exited normally"
      - text: "It was killed by signal 9 (SIGKILL), often from the OOM killer"
        correct: true
      - text: "Command not found"
      - text: "It received Ctrl+C"
    explanation: "128 + 9 = 137. Normal exit is 0, command not found is 127, and Ctrl+C (SIGINT 2) gives 130."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "ps shows several <defunct> processes in state Z under the same parent. What do you do?"
    options:
      - text: "kill -9 each zombie"
      - text: "Fix or restart the parent, which is failing to collect its children's exit status"
        correct: true
      - text: "Reboot immediately; zombies eat memory"
      - text: "Nothing can ever remove them"
    explanation: "Zombies are already dead, so signals do nothing. They hold only a PID slot, not memory. When the parent reaps them, or exits so PID 1 adopts and reaps them, they vanish."
  - id_key: q5
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You must start a 2-hour database dump over SSH from a café with flaky Wi-Fi. What is the best approach?"
    options:
      - text: "Run it normally and keep the laptop open"
      - text: "Start a tmux session on the server and run the dump inside it"
        correct: true
      - text: "Run it with kill -STOP"
      - text: "Add & at the end and close the laptop"
    explanation: "tmux runs on the server, so a dropped connection only detaches you. A plain foreground or & job gets SIGHUP when the session dies, and SIGSTOP just pauses it."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "As a normal user you run renice -n -5 -p 1234 on your own process and get Permission denied. Why?"
    options:
      - text: "Only root may lower niceness (raise priority)"
        correct: true
      - text: "The PID is wrong"
      - text: "renice only works on root's processes"
      - text: "Niceness must be between 0 and 10"
    explanation: "Users may only make their processes nicer. A wrong PID gives 'No such process', renice works on your own processes, and the range is -20 to 19."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Where can you see the exact command line of process 4242, even without ps installed?"
    options:
      - text: "/proc/4242/cmdline"
        correct: true
      - text: "/var/log/4242"
      - text: "/etc/proc/4242"
      - text: "/dev/4242"
    explanation: "The kernel exposes each process under /proc/PID; cmdline holds the arguments separated by NUL bytes. The other paths do not exist."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (chapter 4): brewbot runs as user brewbot and cannot read /etc/brewbot/brewbot.conf (-rw------- root root). What is the safest fix?"
    options:
      - text: "chmod 644 /etc/brewbot/brewbot.conf"
      - text: "chgrp brewbot /etc/brewbot/brewbot.conf and chmod 640"
        correct: true
      - text: "Run brewbot as root"
      - text: "chmod 777 /etc/brewbot"
    explanation: "Group read for the service only. 644 exposes the config to every user, running as root removes all protection, and 777 lets anyone replace files."
---
