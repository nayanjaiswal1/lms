---
kind: lesson
id_key: linux/final-exam/course-review
course: linux
section: final-exam
section_title: "Final Exam: Atlas Certified"
section_position: 14
title: "Course Review: Flashcards for Spaced Recall"
position: 0
estimated_minutes: 12
source:
  - All chapters of this course
---

## How to use this page

Cover the right column and answer each prompt out loud, then check. Mark the ones
you missed and come back to them tomorrow, in three days and in a week. Spaced,
effortful recall beats re-reading. Then take the final exam.

## Shell and filesystem (chapters 1-2)

| Prompt | Answer |
|---|---|
| Kernel vs distro vs shell | core program / kernel + tools + package manager / command interpreter (bash) |
| Config, logs, user files live in... | `/etc`, `/var/log`, `/home` |
| Absolute vs relative path | starts at `/` / starts where you are |
| Make PATH change permanent | `export PATH="$HOME/bin:$PATH"` in `~/.bashrc` |
| `>` vs `>>` | overwrite / append |
| Copy a directory | `cp -r` (or `cp -a` to keep attributes) |
| find, safely | `find DIR -name '*.bak'` first, then add `-delete` |
| Hard link vs symlink | second name for the same inode / small file holding a path |

## Text tools (chapter 3)

| Prompt | Answer |
|---|---|
| Count matching lines | `grep -c PATTERN file` |
| stderr to a file | `2> file`; both: `> file 2>&1` |
| Top-N pipeline | `... \| sort \| uniq -c \| sort -rn \| head` |
| Filter column 9, print column 7 | `awk '$9 == 500 {print $7}'` |
| Replace safely into a new file | `sed 's/a/b/g' in > out` |

## Users and permissions (chapter 4)

| Prompt | Answer |
|---|---|
| r, w, x values | 4, 2, 1 |
| 640 means | owner rw, group r, others nothing |
| Which class applies? | owner, else group, else others (only one) |
| Delete a file needs | `w` on the directory |
| Add user to a group | `usermod -aG group user` (always `-a`) |
| SUID / SGID dir / sticky | run as owner / inherit group / only owner deletes |
| umask 027 gives | files 640, directories 750 |
| Edit sudoers | `visudo` only |
| Extra named permissions | ACLs: `setfacl -m u:sam:r f`, `getfacl` |

## Processes and systemd (chapters 5-6)

| Prompt | Answer |
|---|---|
| Polite vs forced kill | SIGTERM 15 / SIGKILL 9 |
| Exit 137 | 128 + 9: killed by SIGKILL (often OOM) |
| Survive logout | `nohup CMD &` or tmux |
| start vs enable | now / at every boot (`enable --now` both) |
| After editing a unit | `systemctl daemon-reload` |
| Override a vendor unit | `systemctl edit NAME` (drop-in) |
| One unit's logs, previous boot | `journalctl -u NAME -b -1` |
| Cron fields | minute hour day-of-month month day-of-week |
| Timer catches up missed runs | `Persistent=true` |

## Storage and network (chapters 7-8)

| Prompt | Answer |
|---|---|
| Which package owns a file? | `dpkg -S FILE` (`rpm -qf FILE`) |
| Space vs inodes | `df -h` / `df -i` |
| fstab: identify disks by | UUID; test with `mount -a` |
| Grow an LVM volume online | `lvextend -r -L +20G /dev/VG/LV` |
| List a tarball | `tar -tzf file.tar.gz` |
| Who listens on which port? | `ss -tulpn` |
| Refused vs timed out | nothing listening / dropped by firewall |
| What programs resolve | `getent hosts NAME` (includes `/etc/hosts`) |
| SSH permissions | `~/.ssh` 700, keys and config 600 |

## Scripting (chapter 9)

| Prompt | Answer |
|---|---|
| Script safety line | `set -euo pipefail` |
| Always quote | `"$var"`, `"$@"` |
| Success exit status | 0 |
| Read a file line by line | `while read -r a b; do ...; done < file` |
| Cleanup on any exit | `trap 'rm -rf "$tmp"' EXIT` |

## Under the hood, performance, security (chapters 10-12)

| Prompt | Answer |
|---|---|
| Namespaces vs cgroups | what a process can see / how much it can use |
| Cap a service's memory | `MemoryMax=` in the unit |
| Watch a program's system calls | `strace -f -e trace=file CMD` |
| USE method | Utilization, Saturation, Errors per resource |
| High load, idle CPU, high wa | disk bottleneck (processes in `D`) |
| Memory number that matters | `available` in `free -h` |
| SSH hardening basics | keys only, `PermitRootLogin no`, `sshd -t`, test in a new session |
| Find SUID files | `find / -xdev -perm -4000 -type f` |
| MAC on Ubuntu / RHEL | AppArmor / SELinux |

## Troubleshooting (chapter 13)

| Prompt | Answer |
|---|---|
| The method | Error, Resources, Logs, Permissions, Changes |
| df full but du is not | `lsof +L1` (deleted but open) |
| Empty an open log | `truncate -s 0 FILE` |
| 502 from nginx | the app behind it is down |
| Post-mortem must have | root cause + action items with owners, blameless |
