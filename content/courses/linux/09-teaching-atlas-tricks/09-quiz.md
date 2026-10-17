---
kind: quiz
id_key: linux/teaching-atlas-tricks/quiz
course: linux
section: teaching-atlas-tricks
section_title: "Chapter 9: Teaching Atlas Tricks - Bash Scripting"
section_position: 9
title: "Quiz: Bash Scripting"
position: 8
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Chapter 9 lessons, plus one review question from chapter 8
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A cleanup script runs cd /srv/build; rm -rf ./*. One night /srv/build does not exist. Without set -e, what happens?"
    options:
      - text: "cd fails, the script continues, and rm -rf ./* deletes the contents of whatever directory it was started in"
        correct: true
      - text: "rm refuses because cd failed"
      - text: "bash stops automatically on any error"
      - text: "Nothing, ./* is empty"
    explanation: "Without set -e (or cd ... || exit 1), bash runs the next line anyway in the old directory. rm does not know cd failed, and bash does not stop by default."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "file='Q3 report.csv'. Which command copies it correctly?"
    options:
      - text: "cp \"$file\" /backup/"
        correct: true
      - text: "cp $file /backup/"
      - text: "cp '$file' /backup/"
      - text: "cp ${file} /backup/"
    explanation: "Double quotes keep the value as one argument. Unquoted (with or without braces) it splits into Q3 and report.csv, and single quotes pass the literal text $file."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What does set -o pipefail change in: curl -s URL | jq .version?"
    options:
      - text: "If curl fails, the pipeline's status is non-zero even though jq succeeded"
        correct: true
      - text: "It makes curl retry"
      - text: "It hides jq errors"
      - text: "Nothing; pipelines always report the first command"
    explanation: "Without pipefail a pipeline returns the last command's status, hiding earlier failures. pipefail returns the status of the last failing stage. It does not retry or hide anything."
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "In Bash, what exit status means a command succeeded?"
    options:
      - text: "0"
        correct: true
      - text: "1"
      - text: "-1"
      - text: "255"
    explanation: "Zero is a hero: 0 is success, any other number is a failure code. if, && and || all check it."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "This loop prints count=0 at the end even though the file has lines: count=0; cat f | while read -r l; do count=$((count+1)); done; echo count=$count. Why?"
    options:
      - text: "The pipe runs the while loop in a subshell, so its count is lost; use done < f instead"
        correct: true
      - text: "read -r skips every line"
      - text: "Arithmetic does not work in loops"
      - text: "count must be exported"
    explanation: "Each side of a pipe runs in a child process; changes inside vanish when it ends. Redirecting the file into the loop keeps it in the current shell. read works, arithmetic works, and export only passes copies to children."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A script creates temporary files and is sometimes stopped with Ctrl+C, leaving junk behind. What is the cleanest fix?"
    options:
      - text: "tmp=$(mktemp -d); trap 'rm -rf \"$tmp\"' EXIT"
        correct: true
      - text: "Add rm -rf /tmp/* at the end of the script"
      - text: "Tell users not to press Ctrl+C"
      - text: "Run the script with nohup"
    explanation: "The EXIT trap runs however the script ends. A final rm never runs after an interrupt and would delete other people's files, and nohup is about hang-ups, not cleanup."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Inside a function you write exit 1 when a check fails, and the whole deploy script stops. What did you probably want?"
    options:
      - text: "return 1, so the caller can decide what to do"
        correct: true
      - text: "break 1"
      - text: "continue"
      - text: "exit 0"
    explanation: "return sets the function's status; exit ends the entire script. break and continue are for loops, and exit 0 would still end the script, reporting success."
  - id_key: q8
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "What does set -euo pipefail at the top of a Bash script do?"
    options:
      - text: "Stops on the first failing command, errors on unset variables, and fails a pipeline if any part fails"
        correct: true
      - text: "Runs the script as root"
      - text: "Enables colour output and Unicode"
      - text: "Makes the script run in the background"
    explanation: "-e exit on error, -u treat unset variables as errors, -o pipefail make a pipeline's status reflect any failing stage. It does not change users, colours or job control."
  - id_key: q9
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (chapter 8): your watchdog script should treat brewbot as down when it returns HTTP 500. Which check is right?"
    options:
      - text: "if curl -sf --max-time 3 http://localhost:8080/health >/dev/null; then ok; else alert; fi"
        correct: true
      - text: "if curl -s http://localhost:8080/health; then ok; fi"
      - text: "if ping -c1 localhost; then ok; fi"
      - text: "if ss -tln | grep -q 8080; then ok; fi"
    explanation: "-f turns HTTP errors into a non-zero exit, and --max-time stops it hanging. Without -f a 500 still counts as success; ping and ss only prove the host or port exists, not that the app is healthy."
---
