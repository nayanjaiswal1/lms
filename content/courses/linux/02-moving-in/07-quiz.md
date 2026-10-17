---
kind: quiz
id_key: linux/moving-in/quiz
course: linux
section: moving-in
section_title: "Chapter 2: Moving In - Working with Files"
section_position: 2
title: "Quiz: Working with Files"
position: 6
estimated_minutes: 8
pass_percentage: 70
duration_minutes: 10
source:
  - Chapter 2 lessons, plus one review question from chapter 1
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "You run echo 'port = 8080' > app.conf on a config file that had 40 lines. What is in app.conf now?"
    options:
      - text: "41 lines: the old 40 plus the new one at the end"
      - text: "Only the line port = 8080"
        correct: true
      - text: "The new line at the top, followed by the old 40"
      - text: "Nothing; > refuses to touch existing files"
    explanation: "A single > truncates the file and then writes. Appending at the end is >>. Neither operator inserts at the top, and > never refuses (unless the shell option noclobber is set)."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which command creates releases/v1, releases/v2 and releases/v3, even if releases does not exist yet?"
    options:
      - text: "mkdir releases/{v1,v2,v3}"
      - text: "mkdir -p releases/{v1,v2,v3}"
        correct: true
      - text: "mkdir -p releases/{v1, v2, v3}"
      - text: "touch -p releases/v1 releases/v2 releases/v3"
    explanation: "-p creates the missing parent, and the braces expand to three paths. Without -p, mkdir fails because releases is missing. Spaces inside braces stop the expansion. touch creates files, not directories, and has no -p."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You want to delete all .tmp files under /srv/cache. What is the safest sequence?"
    options:
      - text: "find /srv/cache -delete -name '*.tmp'"
      - text: "rm -rf /srv/cache/*"
      - text: "find /srv/cache -name '*.tmp' first, check the list, then find /srv/cache -name '*.tmp' -delete"
        correct: true
      - text: "find /srv/cache -name *.tmp -delete"
    explanation: "Preview, then act. With -delete before -name, find deletes everything it walks. rm -rf removes all files, not only .tmp. An unquoted *.tmp may be expanded by the shell in the current directory and pass the wrong name to find."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "nginx's sites-enabled/shop is a symlink to sites-available/shop. Someone deletes sites-available/shop. What happens to sites-enabled/shop?"
    options:
      - text: "It still has the config, because a symlink copies the content"
      - text: "It becomes a dangling link: it still exists but points to nothing"
        correct: true
      - text: "It is deleted automatically"
      - text: "It turns into a hard link"
    explanation: "A symlink only stores a path. When the target goes, the link remains but leads nowhere, and nginx will fail to read it. Only a hard link would keep the data alive. Links never change type by themselves."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "ls -li shows two names with the same inode number and a link count of 2. What does that mean?"
    options:
      - text: "They are two copies that happen to be identical"
      - text: "They are two names for the same file data; editing one changes the other"
        correct: true
      - text: "One of them is a symlink"
      - text: "The filesystem is corrupted"
    explanation: "Same inode = same file. A hard link is a second name. Copies would have different inodes, a symlink has its own inode and type l, and shared inodes are completely normal."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which pipeline shows the five largest items under /var/log, biggest last?"
    options:
      - text: "du -ah /var/log | sort -h | tail -5"
        correct: true
      - text: "du -ah /var/log | sort -n | head -5"
      - text: "ls /var/log | tail -5"
      - text: "df -h /var/log | tail -5"
    explanation: "du -ah prints sizes like 2.0M, sort -h orders them correctly and tail keeps the last (largest) lines. sort -n misorders human sizes and head keeps the smallest. ls prints names without sizes, and df reports whole filesystems, not files."
  - id_key: q7
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "A file is called invoice.pdf. How do you find out what it really contains?"
    options:
      - text: "Trust the .pdf extension"
      - text: "Run file invoice.pdf"
        correct: true
      - text: "Run ls -l invoice.pdf"
      - text: "Rename it to .txt and cat it"
    explanation: "file inspects the content. Linux ignores extensions, so the name proves nothing. ls -l shows size and permissions, not content type, and renaming changes nothing about the data."
  - id_key: q8
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Review (chapter 1): you are in /etc. Which command lists hidden files in your home directory?"
    options:
      - text: "ls -a ~"
        correct: true
      - text: "ls ~"
      - text: "ls -a"
      - text: "ls -l /root"
    explanation: "~ is your home and -a includes dot-files. Plain ls hides them, ls -a alone lists /etc (where you are), and /root is the root user's home, not yours."
---
