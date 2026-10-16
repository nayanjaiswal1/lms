---
kind: quiz
id_key: linux/the-logbook/quiz
course: linux
section: the-logbook
section_title: "Chapter 3: The Logbook - Text Tools and Pipes"
section_position: 3
title: "Quiz: Text Tools and Pipes"
position: 8
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Chapter 3 lessons, plus one review question from chapter 2
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "brewbot's log is 3 GB. You want to watch new lines arrive while you reproduce a bug, and the log is rotated at midnight. Which command?"
    options:
      - text: "cat brewbot.log"
      - text: "tail -F brewbot.log"
        correct: true
      - text: "head -f brewbot.log"
      - text: "nano brewbot.log"
    explanation: "tail -F follows new lines and reopens the file after rotation. cat dumps 3 GB to the screen, head has no follow mode, and an editor loads the whole file and can save changes by accident."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You run grep ERROR|WARN app.log and get 'WARN: command not found'. What went wrong?"
    options:
      - text: "grep cannot search for two words"
      - text: "The unquoted | was read by the shell as a pipe; quote the pattern and use -E: grep -E 'ERROR|WARN' app.log"
        correct: true
      - text: "WARN must be written in lowercase"
      - text: "app.log must come first"
    explanation: "Unquoted, | splits the line into two commands. Quoting keeps it inside the pattern and -E makes | mean 'or'. Case and argument order are not the problem."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A cron job runs /opt/backup.sh 2>&1 > /var/log/backup.log. Its error messages never reach the log. Why?"
    options:
      - text: "cron discards stderr by design"
      - text: "Redirections apply left to right: 2>&1 copied stderr to the old stdout before stdout was moved to the file"
        correct: true
      - text: "The log file must end in .err"
      - text: "2>&1 only works with >>"
    explanation: "Write > /var/log/backup.log 2>&1 (or >> for append) so stderr follows stdout into the file. cron does capture output; file names and append mode have nothing to do with it."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "awk '{print $1}' access.log | uniq -c shows the same IP many times with small counts. What is missing?"
    options:
      - text: "sort before uniq -c, because uniq only merges adjacent duplicates"
        correct: true
      - text: "The -F option on awk"
      - text: "grep -c instead of uniq"
      - text: "Nothing; uniq is just inaccurate"
    explanation: "Equal lines must be next to each other for uniq to merge them; sort groups them. The default whitespace split is correct for this log, grep -c counts lines not groups, and uniq is exact on sorted input."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "In access.log the path is field 7 and the status is field 9. Which command lists each path that returned 404, once?"
    options:
      - text: "awk '$9 == 404 {print $7}' access.log | sort -u"
        correct: true
      - text: "grep 404 access.log | sort -u"
      - text: "awk '$7 == 404 {print $9}' access.log"
      - text: "cut -f7 access.log | grep 404"
    explanation: "awk filters on field 9 and prints field 7, sort -u removes duplicates. grep 404 also matches 404 inside byte counts or times and prints whole lines; the third option swaps the fields; cut -f uses tabs by default, and the path field never contains the status."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You need a copy of app.log with passwords masked, and app.log must stay unchanged as evidence. Which command?"
    options:
      - text: "sed -i 's/password=[^ ]*/password=***/' app.log"
      - text: "sed 's/password=[^ ]*/password=***/' app.log > app-clean.log"
        correct: true
      - text: "sed 's/password=[^ ]*/password=***/' app.log > app.log"
      - text: "grep -v password app.log > app.log"
    explanation: "Without -i, sed prints an edited copy, which you redirect into a new file. -i edits the evidence in place. Redirecting into the same file empties it before sed reads it, and the grep version both destroys the original and drops lines instead of masking them."
  - id_key: q7
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "find / -name '*.conf' prints hundreds of 'Permission denied' lines around the results. How do you keep only the results on screen?"
    options:
      - text: "find / -name '*.conf' 2>/dev/null"
        correct: true
      - text: "find / -name '*.conf' >/dev/null"
      - text: "find / -name '*.conf' | grep -v conf"
      - text: "find / -name '*.conf' &>/dev/null"
    explanation: "The errors are on stderr (2), so 2>/dev/null discards just them. >/dev/null throws away the results instead, &> throws away both, and grep -v conf would remove the results too."
  - id_key: q8
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Review (chapter 2): you want to compress every .log file under /srv/app, including subdirectories, even with spaces in names. Which command?"
    options:
      - text: "gzip /srv/app/*.log"
      - text: "find /srv/app -name '*.log' -print0 | xargs -0 gzip"
        correct: true
      - text: "ls /srv/app | gzip"
      - text: "find /srv/app -name *.log | gzip"
    explanation: "find walks subdirectories, and -print0 with xargs -0 keeps names with spaces intact. The glob only covers the top directory, ls | gzip compresses the list of names rather than the files, and piping names into gzip compresses the text, not the files (and the pattern is unquoted)."
---
