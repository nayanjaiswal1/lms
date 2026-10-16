---
kind: lesson
id_key: linux/keys-and-locks/lesson
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks - Users and Permissions"
section_position: 4
title: "Lab: Lock Up Atlas"
position: 9
estimated_minutes: 25
source:
  - chmod(1), chown(1), umask(2), passwd(5), group(5), shadow(5), sudoers(5) manual pages
  - useradd(8), usermod(8), setfacl(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 45
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    w=/home/labuser/work
    rm -rf $w/keys $w/answers
    mkdir -p $w/answers
  tasks:
    - id_key: read-passwd
      title: Read the staff register
      points: 25
      is_stateful: true
      description: Using /etc/passwd, save labuser's numeric UID and login shell, separated by one space, into answers/passwd-check.txt - for example "1234 /bin/sh".
      verification_script: |
        want="$(id -u labuser) $(getent passwd labuser | cut -d: -f7)"
        [ "$(head -1 /home/labuser/work/answers/passwd-check.txt | tr -s ' ' | sed 's/ *$//')" = "$want" ]
      hint_context: >-
        grep '^labuser:' /etc/passwd shows the line. Field 3 is the UID and field 7 is the shell - awk -F: '{print $3, $7}' prints both.
      explanation_context: /etc/passwd has seven colon-separated fields - name:x:UID:GID:comment:home:shell. The x means the password hash lives in the root-only /etc/shadow.
      solution_script: |
        awk -F: '$1 == "labuser" {print $3, $7}' /etc/passwd > /home/labuser/work/answers/passwd-check.txt
    - id_key: lock-deploy
      title: Lock the deploy script
      points: 20
      is_stateful: true
      description: Create the directory /home/labuser/work/keys and inside it a file deploy.sh (any content). Give it permissions so the owner can read, write and execute, the group can only read, and others get nothing.
      verification_script: |
        f=/home/labuser/work/keys/deploy.sh
        [ -f $f ] && [ "$(stat -c %a $f)" = 740 ] && [ "$(stat -c %U $f)" = labuser ]
      hint_context: Add up r=4 w=2 x=1 for each of owner, group and others. rwx = 7, r-- = 4, --- = 0.
      explanation_context: chmod 740 sets owner rwx (4+2+1), group r-- (4), others --- (0). ls -l shows it as -rwxr-----.
      solution_script: |
        mkdir -p /home/labuser/work/keys
        echo 'echo deploying' > /home/labuser/work/keys/deploy.sh
        chmod 740 /home/labuser/work/keys/deploy.sh
    - id_key: lock-secrets
      title: Hide the secrets
      points: 15
      is_stateful: true
      description: Create keys/secrets.env containing the line DB_PASSWORD=espresso and make it readable and writable by its owner only.
      verification_script: |
        f=/home/labuser/work/keys/secrets.env
        grep -qx 'DB_PASSWORD=espresso' $f && [ "$(stat -c %a $f)" = 600 ]
      hint_context: Owner rw- is 6, group and others nothing is 0. chmod 600 or chmod u=rw,go= both work.
      explanation_context: Credentials files should be 600. SSH, database clients and many tools refuse to use a key or secret file that others can read.
      solution_script: |
        echo 'DB_PASSWORD=espresso' > /home/labuser/work/keys/secrets.env
        chmod 600 /home/labuser/work/keys/secrets.env
    - id_key: sticky-drop
      title: A shared drop box
      points: 20
      is_stateful: true
      description: Create the directory keys/drop that everyone can write into, but where users can only delete their own files (the same behaviour as /tmp).
      verification_script: |
        d=/home/labuser/work/keys/drop
        [ -d $d ] && [ "$(stat -c %a $d)" = 1777 ]
      hint_context: Compare with ls -ld /tmp - the trailing t is the sticky bit. Its numeric value is 1000, so 777 plus sticky is 1777.
      explanation_context: On a directory, the sticky bit (t) stops users from deleting or renaming files they do not own, even though the directory is world-writable. That is exactly how /tmp works.
      solution_script: |
        mkdir -p /home/labuser/work/keys/drop
        chmod 1777 /home/labuser/work/keys/drop
    - id_key: safe-umask
      title: Safer defaults for new files
      points: 20
      is_stateful: true
      description: Set your umask to 027 permanently in ~/.bashrc, so new files are never readable by others.
      verification_script: |
        [ "$(bash -ic umask 2>/dev/null)" = 0027 ]
      hint_context: Append the line umask 027 to ~/.bashrc. The umask lists the bits to REMOVE from the default 666 (files) / 777 (directories).
      explanation_context: With umask 027, new files become 640 and new directories 750 - the group can read, others get nothing. Putting it in ~/.bashrc applies it to every new shell.
      solution_script: |
        echo 'umask 027' >> ~/.bashrc
---

## Why this matters

Last night someone read the database password because a script was
world-readable. In this lab you read the staff register, lock the deploy script
and the secrets, build a shared drop box, and make new files private by default.
Each task is checked automatically.

## Before you start

```bash
id
umask
ls -ld ~ ~/work /tmp
```

What this does: shows who you are, your current umask, and three directory
modes to compare with later.

## Task 1: read the staff register

Using `/etc/passwd`, save labuser's numeric UID and login shell, separated by
one space, into `~/work/answers/passwd-check.txt` (for example `1234 /bin/sh`).

[[lab-task:1]]

## Task 2: lock the deploy script

Create `~/work/keys/deploy.sh` (any content). The owner may read, write and
execute; the group may only read; others get nothing.

[[lab-task:2]]

## Task 3: hide the secrets

Create `keys/secrets.env` containing the line `DB_PASSWORD=espresso`, readable
and writable by its owner only.

[[lab-task:3]]

What you should see:

```
$ ls -l ~/work/keys
-rwxr----- 1 labuser labuser 15 ... deploy.sh
-rw------- 1 labuser labuser 21 ... secrets.env
```

## Task 4: a shared drop box

Create `keys/drop`, a directory everyone can write into, where users can only
delete their own files: the same behaviour as `/tmp`.

[[lab-task:4]]

## Task 5: safer defaults for new files

Set your umask to `027` permanently in `~/.bashrc`, so new files are never
readable by others.

[[lab-task:5]]

Check yourself: open a new shell with `bash`, run `touch t && ls -l t`, and you
should see `-rw-r-----`.

## Remember

- `/etc/passwd`: name:x:UID:GID:comment:home:shell.
- 740 script, 600 secrets, 1777 shared drop box.
- `umask 027` in `~/.bashrc` makes new files 640.

> **End of day 4.** The deploy script is locked, secrets are 600, and new files
> are private by default. Rhea checks the sudo log and finds the culprit: a
> forgotten test account. Tom's next note was taped under a desk: "Atlas is
> never doing just one thing."
