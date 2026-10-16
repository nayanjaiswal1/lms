---
kind: quiz
id_key: linux/final-exam
course: linux
section: final-exam
section_title: "Final Exam: Atlas Certified"
section_position: 14
title: "Final Exam: Linux on Atlas"
position: 1
estimated_minutes: 40
pass_percentage: 70
duration_minutes: 40
source:
  - content/courses/linux chapters 1-13
questions:
  - id_key: linux/final-exam/kernel-vs-shell
    type: mcq
    difficulty: beginner
    points: 5
    prompt: "In the coffee shop picture of Linux, which part is the kitchen that manages CPU, memory, disks and processes?"
    options:
      - text: "The kernel"
        correct: true
      - text: "The shell (bash)"
      - text: "The terminal"
      - text: "The distribution"
    explanation: "The kernel is the core that shares hardware between programs. The shell is the barista that takes your commands and asks the kernel to run them."

  - id_key: linux/final-exam/fhs
    type: mcq
    difficulty: beginner
    points: 5
    prompt: "Brewbot's configuration file and its log files most likely live in which two directories?"
    options:
      - text: "/etc for the config, /var/log for the logs"
        correct: true
      - text: "/usr for the config, /tmp for the logs"
      - text: "/home for the config, /proc for the logs"
      - text: "/bin for the config, /dev for the logs"
    explanation: "/etc holds editable text configuration and /var holds data that varies, including logs under /var/log."

  - id_key: linux/final-exam/path
    type: mcq
    difficulty: beginner
    points: 5
    prompt: "You put an executable script called deploy in ~/bin, but typing deploy says command not found. What is the most likely cause?"
    options:
      - text: "~/bin is not listed in the PATH variable"
        correct: true
      - text: "Scripts can only run from /usr/bin"
      - text: "The file name needs a .sh extension"
      - text: "The kernel needs a reboot to see new commands"
    explanation: "The shell only searches directories listed in PATH. Add export PATH=\"$HOME/bin:$PATH\" to ~/.bashrc."

  - id_key: linux/final-exam/hard-vs-soft
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "You create a symlink and a hard link to menu.txt, then delete menu.txt. What happens?"
    options:
      - text: "The hard link still shows the content; the symlink is now broken"
        correct: true
      - text: "Both links still show the content"
      - text: "Both links are broken"
      - text: "The symlink still works; the hard link is broken"
    explanation: "A hard link is another name for the same inode, so the data survives. A symlink only stores the path, which no longer exists."

  - id_key: linux/final-exam/find-delete
    type: mcq
    difficulty: beginner
    points: 5
    prompt: "What is the safe habit before running find /srv -name '*.tmp' -delete?"
    options:
      - text: "Run the same find without -delete first and check the list"
        correct: true
      - text: "Run it twice to make sure it worked"
      - text: "Add sudo so it cannot fail"
      - text: "Nothing - deleted files go to the trash and can be restored"
    explanation: "Linux has no recycle bin. Always preview what find matches before adding -delete."

  - id_key: linux/final-exam/pipeline
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "Why does the top-IP pipeline need sort before uniq -c?"
    options:
      - text: "uniq only merges duplicate lines that are next to each other"
        correct: true
      - text: "uniq cannot read from a pipe"
      - text: "sort removes the timestamps from each line"
      - text: "uniq -c only works on numbers"
    explanation: "uniq compares each line only with the line before it, so equal lines must first be grouped together by sort."

  - id_key: linux/final-exam/redirect
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "Which command sends both normal output and errors of backup.sh to backup.log, appending to the file?"
    options:
      - text: "./backup.sh >> backup.log 2>&1"
        correct: true
      - text: "./backup.sh 2>&1 > backup.log"
      - text: "./backup.sh | backup.log"
      - text: "./backup.sh > backup.log 2>/dev/null"
    explanation: ">> appends stdout to the file, then 2>&1 points stderr at the same place. Order matters - redirections are processed left to right."

  - id_key: linux/final-exam/chmod-numeric
    type: mcq
    difficulty: beginner
    points: 5
    prompt: "deploy.sh should be readable, writable and executable by its owner, readable by the group, and nothing for others. Which command is correct?"
    options:
      - text: "chmod 740 deploy.sh"
        correct: true
      - text: "chmod 750 deploy.sh"
      - text: "chmod 704 deploy.sh"
      - text: "chmod 777 deploy.sh"
    explanation: "r=4 w=2 x=1. Owner rwx = 7, group r-- = 4, others --- = 0."

  - id_key: linux/final-exam/usermod
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "You run sudo usermod -G docker sam and suddenly sam can no longer use sudo. Why?"
    options:
      - text: "Without -a, -G replaces all of sam's supplementary groups, removing sam from the sudo group"
        correct: true
      - text: "The docker group blocks sudo"
      - text: "usermod always resets the password"
      - text: "Sam needs to reboot the server"
    explanation: "Always use usermod -aG (append). -G alone sets the group list to exactly what you give."

  - id_key: linux/final-exam/sticky
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "Why can't users delete each other's files in /tmp, even though /tmp is writable by everyone?"
    options:
      - text: "/tmp has the sticky bit, so only a file's owner (or root) can delete it"
        correct: true
      - text: "/tmp is mounted read-only"
      - text: "Every file in /tmp is SUID root"
      - text: "The umask prevents deletion"
    explanation: "drwxrwxrwt - the t is the sticky bit. On a directory it limits deleting and renaming to the file's owner."

  - id_key: linux/final-exam/signals
    type: mcq
    difficulty: beginner
    points: 5
    prompt: "A worker process is stuck. What is the right order of signals to send?"
    options:
      - text: "SIGTERM (15) first, and SIGKILL (9) only if it refuses to exit"
        correct: true
      - text: "SIGKILL (9) first, it is faster"
      - text: "SIGHUP (1) only, it always stops processes"
      - text: "SIGSTOP (19), then wait for it to exit by itself"
    explanation: "15 asks, 9 insists. SIGTERM lets the program clean up; SIGKILL cannot be caught and can leave half-written files."

  - id_key: linux/final-exam/load
    type: mcq
    difficulty: advanced
    points: 5
    prompt: "uptime shows a load average of 12 on a 4-CPU server, but top shows the CPUs mostly idle with a high wa value. What is going on?"
    options:
      - text: "Processes are blocked waiting on disk IO, which counts toward load"
        correct: true
      - text: "The load average is broken and should be ignored"
      - text: "The server has too much free memory"
      - text: "Twelve users are logged in"
    explanation: "Linux load counts processes running or waiting, including uninterruptible (D state) disk waits. High wa means the disk, not the CPU, is the bottleneck."

  - id_key: linux/final-exam/start-vs-enable
    type: mcq
    difficulty: beginner
    points: 5
    prompt: "You ran sudo systemctl start brewbot and it works, but after a reboot brewbot is not running. What did you forget?"
    options:
      - text: "sudo systemctl enable brewbot"
        correct: true
      - text: "sudo systemctl reload brewbot"
      - text: "sudo systemctl daemon-reload"
      - text: "sudo systemctl status brewbot"
    explanation: "start runs it now; enable hooks it into the boot target so it starts every time. enable --now does both."

  - id_key: linux/final-exam/journalctl
    type: mcq
    difficulty: beginner
    points: 5
    prompt: "Brewbot shows as failed. Which command shows what brewbot itself logged?"
    options:
      - text: "journalctl -u brewbot"
        correct: true
      - text: "dmesg -u brewbot"
      - text: "cat /proc/brewbot/log"
      - text: "systemctl enable brewbot"
    explanation: "journalctl -u UNIT filters the journal to one unit. Pair it with systemctl status for the current state."

  - id_key: linux/final-exam/cron
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "What does the crontab line 0 3 * * 0 /opt/brewbot/backup.sh do?"
    options:
      - text: "Runs the backup at 03:00 every Sunday"
        correct: true
      - text: "Runs the backup every 3 minutes"
      - text: "Runs the backup at midnight on the 3rd of every month"
      - text: "Runs the backup at 03:00 every day"
    explanation: "Fields are minute, hour, day of month, month, day of week: minute 0, hour 3, any day, any month, weekday 0 = Sunday."

  - id_key: linux/final-exam/df-du
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "df -h says / is only 40% used, yet creating new files fails, and df -i shows 100%. What has run out?"
    options:
      - text: "Inodes - too many small files"
        correct: true
      - text: "Swap space"
      - text: "RAM"
      - text: "File descriptors"
    explanation: "Every file needs an inode. Millions of tiny files can exhaust inodes long before the blocks run out; df -i shows it."

  - id_key: linux/final-exam/deleted-open
    type: mcq
    difficulty: advanced
    points: 5
    prompt: "You deleted a 20 GB log with rm, but df still shows the disk full. What is the most likely reason?"
    options:
      - text: "A running process still has the deleted file open, so its space is not released"
        correct: true
      - text: "rm only moves files to a hidden trash folder"
      - text: "df caches results for 24 hours"
      - text: "The file system needs to be reformatted"
    explanation: "The inode lives until the last open handle closes. lsof +L1 finds it; restart the process or truncate via /proc/PID/fd. Truncating instead of rm avoids this."

  - id_key: linux/final-exam/fstab
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "Why should /etc/fstab refer to a new disk by UUID instead of /dev/sdb1, and what do you run before rebooting?"
    options:
      - text: "Device names can change between boots; test the file with sudo mount -a"
        correct: true
      - text: "UUIDs are faster to read; test with df -h"
      - text: "/dev names are only for USB sticks; test with lsblk"
      - text: "fstab does not accept /dev names; no test is needed"
    explanation: "Disk order can change, but a filesystem UUID does not. mount -a mounts every fstab entry now, catching mistakes that could otherwise stop the boot."

  - id_key: linux/final-exam/tar
    type: mcq
    difficulty: beginner
    points: 5
    prompt: "Which command lists what is inside backup.tar.gz without extracting it?"
    options:
      - text: "tar -tzf backup.tar.gz"
        correct: true
      - text: "tar -xzf backup.tar.gz"
      - text: "tar -czf backup.tar.gz"
      - text: "gzip -l backup.tar.gz | tar"
    explanation: "t = tell (list), z = gzip, f = file. x extracts and c creates."

  - id_key: linux/final-exam/refused-timeout
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "From your laptop, curl to atlas:8080 says Connection refused. On atlas, ss -tulpn shows brewbot on 127.0.0.1:8080. What is wrong?"
    options:
      - text: "Brewbot listens only on localhost, so outside connections reach no listener"
        correct: true
      - text: "A firewall is dropping the packets"
      - text: "DNS is resolving the wrong name"
      - text: "The server is out of memory"
    explanation: "Refused means nothing listens on that address and port. Bound to 127.0.0.1, brewbot only accepts local connections; a firewall drop would show as a timeout instead."

  - id_key: linux/final-exam/ssh-perms
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "SSH ignores your key and asks for a password. The server's ~/.ssh is 777 and authorized_keys is 666. What should they be?"
    options:
      - text: "~/.ssh 700 and authorized_keys 600"
        correct: true
      - text: "~/.ssh 755 and authorized_keys 777"
      - text: "Both 644"
      - text: "Permissions do not matter to SSH"
    explanation: "sshd refuses keys that other users could modify. Lock .ssh to 700 and the key files to 600."

  - id_key: linux/final-exam/set-e
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "What does set -euo pipefail at the top of a Bash script do?"
    options:
      - text: "Stops on the first failing command, errors on unset variables, and fails a pipeline if any part fails"
        correct: true
      - text: "Runs the script as root"
      - text: "Enables colour output and Unicode"
      - text: "Makes the script run in the background"
    explanation: "-e exit on error, -u treat unset variables as errors, -o pipefail make a pipeline's status reflect any failing stage."

  - id_key: linux/final-exam/exit-code
    type: mcq
    difficulty: beginner
    points: 5
    prompt: "In Bash, what exit status means a command succeeded?"
    options:
      - text: "0"
        correct: true
      - text: "1"
      - text: "-1"
      - text: "255"
    explanation: "Zero is a hero: 0 is success, any other number is a failure code. if, && and || all check it."

  - id_key: linux/final-exam/method
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "Brewbot will not start right after a teammate edited its config. Following the incident method, what do you do first?"
    options:
      - text: "Read the error with systemctl status and journalctl -u brewbot, then validate the changed config"
        correct: true
      - text: "Reboot the server and hope it comes back"
      - text: "chmod -R 777 /etc/brewbot so permissions cannot be the problem"
      - text: "Reinstall the operating system"
    explanation: "Every Real Linux Pro Checks: Error, Resources, Logs, Permissions, Changes. A recent config change plus a startup failure points straight at the config - read the logs, fix one thing, validate, restart."

  - id_key: linux/final-exam/strace
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "A program fails with a vague error and no useful log. Which tool shows the exact file it tried to open and the error the kernel returned?"
    options:
      - text: "strace"
        correct: true
      - text: "lsblk"
      - text: "uptime"
      - text: "crontab -l"
    explanation: "strace prints each system call and its result, for example openat(...) = -1 ENOENT. The others show disks, load and scheduled jobs."

  - id_key: linux/final-exam/namespaces-cgroups
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "Which pair of kernel features makes a container?"
    options:
      - text: "Namespaces (what it can see) and cgroups (how much it can use)"
        correct: true
      - text: "SUID and the sticky bit"
      - text: "cron and systemd timers"
      - text: "LVM and fstab"
    explanation: "Namespaces isolate views of PIDs, mounts, network and hostname; cgroups limit CPU, memory and processes. All containers share the host kernel."

  - id_key: linux/final-exam/memory-max
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "A memory leak in brewbot should kill brewbot, not the database next to it. What do you set?"
    options:
      - text: "MemoryMax= in brewbot's unit file (a cgroup limit)"
        correct: true
      - text: "nice -n 19 brewbot"
      - text: "A bigger swap file"
      - text: "Restart=no"
    explanation: "MemoryMax confines the OOM kill to brewbot's cgroup. Niceness affects CPU, more swap only delays the problem, and Restart controls restarts."

  - id_key: linux/final-exam/available-memory
    type: mcq
    difficulty: beginner
    points: 5
    prompt: "free -h shows free 200Mi and available 3.0Gi with no swapping. What is the right conclusion?"
    options:
      - text: "Memory is fine; Linux uses spare RAM as reclaimable cache"
        correct: true
      - text: "The server is nearly out of memory"
      - text: "Swap is broken"
      - text: "Reboot to free memory"
    explanation: "available includes cache the kernel hands back on demand. Low free memory alone is normal and healthy."

  - id_key: linux/final-exam/use-method
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "In the USE method, which signal shows CPU saturation?"
    options:
      - text: "A run queue (vmstat r, or load) consistently above the number of CPUs"
        correct: true
      - text: "High %util in iostat"
      - text: "A large RSS"
      - text: "Many open SSH sessions"
    explanation: "Saturation means waiting work. For CPU that is runnable processes beyond the CPU count. iostat %util is disk utilisation and RSS is memory."

  - id_key: linux/final-exam/lvm-grow
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "/srv/data is an ext4 LVM volume and nearly full; the volume group has free space. Which command grows it online?"
    options:
      - text: "sudo lvextend -r -L +20G /dev/vg_data/lv_srv"
        correct: true
      - text: "sudo mkfs.ext4 /dev/vg_data/lv_srv"
      - text: "sudo fdisk /dev/vg_data/lv_srv"
      - text: "sudo mount -a"
    explanation: "lvextend -r grows the logical volume and the filesystem together. mkfs erases it, fdisk partitions disks, and mount -a only mounts fstab entries."

  - id_key: linux/final-exam/ssh-hardening
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "You disabled SSH password logins in a drop-in. What do you do before closing your current session?"
    options:
      - text: "Run sshd -t, reload ssh, and confirm a new session can log in with your key"
        correct: true
      - text: "Reboot immediately"
      - text: "Nothing; sshd validates changes itself"
      - text: "Delete your authorized_keys"
    explanation: "Check syntax, reload (existing sessions stay), and prove access still works from a new terminal. Otherwise one mistake locks you out."

  - id_key: linux/final-exam/suid-audit
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "Which command lists SUID files, a common place for backdoors?"
    options:
      - text: "find / -xdev -perm -4000 -type f 2>/dev/null"
        correct: true
      - text: "find / -perm 777"
      - text: "ls -la /"
      - text: "df -i"
    explanation: "-perm -4000 matches the SUID bit. 777 is a different (world-writable) problem, ls / shows one directory, and df -i shows inode usage."

  - id_key: linux/final-exam/journal-previous-boot
    type: mcq
    difficulty: intermediate
    points: 5
    prompt: "Atlas crashed overnight and rebooted. Which command shows error messages from before the crash (with a persistent journal)?"
    options:
      - text: "journalctl -b -1 -p err"
        correct: true
      - text: "journalctl -b -p err"
      - text: "systemctl --failed"
      - text: "dmesg -T"
    explanation: "-b -1 selects the previous boot. The other commands show the current boot or the current state."
---
