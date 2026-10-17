---
kind: quiz
id_key: linux/storeroom/quiz
course: linux
section: storeroom
section_title: "Chapter 7: The Storeroom - Packages, Disks and Backups"
section_position: 7
title: "Quiz: Packages, Disks and Backups"
position: 6
estimated_minutes: 10
pass_percentage: 70
duration_minutes: 12
source:
  - Chapter 7 lessons, plus one review question from chapter 6
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "apt install redis fails with 404 Not Found for a .deb file. What should you run first?"
    options:
      - text: "sudo apt update"
        correct: true
      - text: "sudo apt purge redis"
      - text: "sudo dpkg -i redis"
      - text: "sudo reboot"
    explanation: "Stale package lists point to versions the mirror has removed; apt update refreshes them. Purge removes something not installed, dpkg -i needs a local file, and rebooting does not refresh lists."
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "A strange binary /usr/bin/foo appeared. How do you find which package installed it on Ubuntu?"
    options:
      - text: "dpkg -S /usr/bin/foo"
        correct: true
      - text: "dpkg -L /usr/bin/foo"
      - text: "apt show /usr/bin/foo"
      - text: "rpm -qf /usr/bin/foo"
    explanation: "dpkg -S searches installed packages for a path. dpkg -L lists files of a package name, apt show takes a package name, and rpm -qf is the RHEL equivalent."
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "df -h shows / at 40% but creating files fails with 'No space left on device'. What do you check?"
    options:
      - text: "df -i, because the filesystem may be out of inodes"
        correct: true
      - text: "free -h"
      - text: "lsblk"
      - text: "Nothing; df is wrong"
    explanation: "Every file needs an inode; millions of tiny files can exhaust them while space remains. free shows memory, lsblk shows devices and sizes, and df is accurate."
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why should /etc/fstab refer to a disk by UUID, and what do you run before rebooting?"
    options:
      - text: "Device names can change between boots; test with sudo mount -a"
        correct: true
      - text: "UUIDs are faster; test with df -h"
      - text: "Device names only work for USB; test with lsblk"
      - text: "fstab rejects /dev names; no test needed"
    explanation: "A filesystem UUID never changes while /dev names can be reordered. mount -a applies every fstab line now, so mistakes appear before they can stop the boot."
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You ran sudo lvextend -L +20G /dev/vg_data/lv_srv, but df -h /srv/data shows the old size. Why?"
    options:
      - text: "The filesystem was not grown; use lvextend -r or run resize2fs/xfs_growfs"
        correct: true
      - text: "You must reboot"
      - text: "LVM changes take 24 hours"
      - text: "df caches sizes"
    explanation: "The LV grew but the filesystem inside still has its old size. -r grows both. No reboot or waiting is needed, and df reads live values."
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Which command lists what is inside backup.tar.gz without extracting it?"
    options:
      - text: "tar -tzf backup.tar.gz"
        correct: true
      - text: "tar -xzf backup.tar.gz"
      - text: "tar -czf backup.tar.gz"
      - text: "gzip -d backup.tar.gz"
    explanation: "t = tell (list). x extracts, c creates (and would overwrite the archive), and gzip -d decompresses the file in place."
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "You run rsync -av --delete src /backup/src and find /backup/src/src created. What went wrong?"
    options:
      - text: "Without a trailing slash, rsync copies the directory itself; use src/ to copy its contents"
        correct: true
      - text: "--delete creates extra directories"
      - text: "-a means append a directory"
      - text: "rsync always nests directories"
    explanation: "src/ means the contents, src means the directory. --delete removes extra files, -a is archive mode, and rsync only nests when told to copy the directory."
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Review (chapter 6): your nightly backup timer missed its 02:30 run because atlas was powered off. Which setting makes it run at the next boot?"
    options:
      - text: "Persistent=true in the [Timer] section"
        correct: true
      - text: "Restart=always in the [Service] section"
      - text: "WantedBy=multi-user.target"
      - text: "@reboot in the crontab of the timer"
    explanation: "Persistent=true makes a timer catch up on missed runs. Restart= is about crashing services, WantedBy is how enabling hooks in, and timers do not use crontabs."
---
