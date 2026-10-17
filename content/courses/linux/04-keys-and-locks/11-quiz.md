---
kind: quiz
id_key: linux/keys-and-locks/quiz
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks - Users and Permissions"
section_position: 4
title: "Quiz: Users and Permissions"
position: 10
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Chapter 4 lessons, plus one review question from chapter 3
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "notes.txt is -r--rw-rw- owned by rhea, group baristas. Rhea is in baristas. Can Rhea write to it?"
    options:
      - text: "Yes, because the group bits allow write and she is in the group"
      - text: "No: she is the owner, so only the owner bits (r--) are checked"
        correct: true
      - text: "Yes, because others may write"
      - text: "Only after a reboot"
    explanation: "Linux picks exactly one class: owner first. Rhea matches owner, so group and others bits are never consulted. Classes do not add up, and reboots have nothing to do with permissions."
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "A user gets 'Permission denied' reading /srv/shop/menu.txt, which is -rw-r--r--. What is the most likely cause?"
    options:
      - text: "The file needs the execute bit"
      - text: "A directory on the path (/srv or /srv/shop) lacks x for that user; namei -l /srv/shop/menu.txt shows it"
        correct: true
      - text: "The file is too large"
      - text: "Others can never read files in /srv"
    explanation: "Reaching a file needs x on every parent directory. Reading a file never needs x on the file itself, size is irrelevant, and /srv has no special rule."
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which mode is right for a private SSH key or a .env file with passwords?"
    options:
      - text: "600"
        correct: true
      - text: "644"
      - text: "755"
      - text: "777"
    explanation: "600 = rw for the owner only. 644 lets everyone read it, 755 also makes it executable for all, and 777 lets anyone change it. SSH even refuses keys that are readable by others."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You run chmod -R 644 /srv/shop and suddenly nginx cannot serve anything in subdirectories. Why?"
    options:
      - text: "644 removed the execute bit from the directories, so nobody can enter them"
        correct: true
      - text: "nginx needs 777"
      - text: "-R changes the owner"
      - text: "644 is invalid for files"
    explanation: "Directories need x to be entered. Use chmod -R u=rwX,g=rX,o=rX or separate find -type d / -type f commands. nginx does not need 777, -R does not touch ownership, and 644 is fine for files."
  - id_key: q5
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "What lets a normal user change their password even though /etc/shadow is root-only?"
    options:
      - text: "/usr/bin/passwd has the SUID bit and is owned by root, so it runs as root"
        correct: true
      - text: "/etc/shadow has the sticky bit"
      - text: "Every user is secretly in the root group"
      - text: "The umask allows it"
    explanation: "SUID makes a program run with its owner's identity. The sticky bit only limits deletion in directories, users are not in the root group, and the umask only affects new files."
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "With umask 027, what permissions does a newly created directory get?"
    options:
      - text: "750 (rwxr-x---)"
        correct: true
      - text: "640 (rw-r-----)"
      - text: "027"
      - text: "777"
    explanation: "Directories start from 777 and the umask removes 027, leaving 750. 640 is what a new file gets. The umask is a filter, not the resulting mode."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Brewbot (user brewbot) must read /etc/brewbot/brewbot.conf but must not modify it. Which setup is best?"
    options:
      - text: "chown brewbot:brewbot and chmod 600"
      - text: "chown root:brewbot and chmod 640"
        correct: true
      - text: "chmod 666"
      - text: "chmod 777 /etc/brewbot"
    explanation: "Root owns and can write, the brewbot group can read, others get nothing. Making brewbot the owner lets it rewrite its config, and 666/777 let every user tamper with it."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You want baristas to run only 'systemctl restart brewbot' as root. How do you add the rule?"
    options:
      - text: "Edit /etc/sudoers with nano"
      - text: "sudo visudo -f /etc/sudoers.d/baristas with %baristas ALL=(root) /usr/bin/systemctl restart brewbot"
        correct: true
      - text: "Add the baristas to the sudo group"
      - text: "Give them root's password"
    explanation: "visudo checks syntax before saving, and the rule grants exactly one command. Editing with nano risks a broken sudoers, the sudo group grants everything, and sharing root's password removes all accountability."
  - id_key: q9
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "ls -l shows -rw-r-----+ on report.csv. What should you run to see who can really read it?"
    options:
      - text: "getfacl report.csv"
        correct: true
      - text: "lsattr report.csv"
      - text: "stat -c %a report.csv"
      - text: "id report.csv"
    explanation: "The + means an ACL with extra named entries exists; getfacl lists them. lsattr shows filesystem attributes like immutable, stat %a shows only the base mode, and id is about users, not files."
  - id_key: q10
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Review (chapter 3): which command lists the user names of all accounts whose shell is /usr/sbin/nologin?"
    options:
      - text: "awk -F: '$7 == \"/usr/sbin/nologin\" {print $1}' /etc/passwd"
        correct: true
      - text: "grep nologin /etc/shadow"
      - text: "cut -f1 /etc/passwd | grep nologin"
      - text: "awk '{print $7}' /etc/passwd"
    explanation: "awk with -F: splits on colons, filters on field 7 and prints field 1. /etc/shadow has no shells and is root-only, cut -f1 without -d: uses tabs and drops the shell anyway, and the last awk splits on spaces and prints no names."
---
