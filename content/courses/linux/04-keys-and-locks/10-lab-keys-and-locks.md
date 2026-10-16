---
kind: lesson
id_key: linux/keys-and-locks/lesson
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks"
section_position: 4
title: Users, Groups, Permissions and sudo
position: 0
estimated_minutes: 50
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

> **Thursday.** Rhea is upset: "Someone read our database password last night. Tom's old deploy script was world-readable." Tom's note said *not everyone should have every key*. Today you learn who can open what on atlas.

## Users and groups

Every process runs as a **user**, and every file belongs to a **user** and a **group**. Linux checks those two facts on every single file access.

```bash
whoami              # your user name
id                  # uid=1001(labuser) gid=1001(labuser) groups=...
groups              # just the groups
who / w             # who is logged in right now
```

The staff register lives in three text files:

```
/etc/passwd   labuser:x:1001:1001:Lab User:/home/labuser:/bin/bash
               name  pw UID  GID  comment  home          shell
/etc/shadow   labuser:$y$j9T$...:19800:0:99999:7:::     (password hashes, root only)
/etc/group    baristas:x:2001:labuser,rhea              (group:pw:GID:members)
```

UID **0** is **root** - the superuser who bypasses permission checks. UIDs below 1000 are usually system accounts for services (`www-data`, `postgres`), which often have the shell `/usr/sbin/nologin` so nobody can log in as them.

Managing users (needs root):

```bash
sudo useradd -m -s /bin/bash -G baristas sam   # create user with home + group
sudo passwd sam                                # set password
sudo usermod -aG docker sam                    # ADD to a group (-a matters!)
sudo groupadd roasters                         # new group
sudo userdel -r sam                            # delete user and home
sudo chage -l sam                              # password ageing info
```

> **Memory hook:** `usermod -aG` - **a**ppend to **G**roups. Forget the `-a` and the user is *removed* from every other group. "**A**lways **a**ppend."

[[lab-task:1]]

## Reading permissions

```
 -rwxr-x---  1  rhea  baristas  512  Oct 14  deploy.sh
 |\_/\_/\_/     |     |
 | |  |  |      owner group
 | |  |  others: ---  nothing
 | |  group:     r-x  read + execute
 | owner:        rwx  read + write + execute
 type: - file, d directory, l symlink
```

| | On a file | On a directory |
|---|---|---|
| **r** | read the content | list the names inside (`ls`) |
| **w** | change the content | create, delete, rename entries |
| **x** | run it as a program | enter it (`cd`) and reach files inside |

Linux checks **one** class only: if you are the owner, owner bits apply; else if you are in the group, group bits; else others.

## chmod: changing the locks

Numbers: each class is a sum of **r=4, w=2, x=1**.

```
 7 = rwx   6 = rw-   5 = r-x   4 = r--   0 = ---

 chmod 755 script.sh     rwxr-xr-x   programs, directories
 chmod 644 notes.txt     rw-r--r--   normal files
 chmod 600 secret.key    rw-------   private keys, passwords
 chmod 700 ~/.ssh        rwx------   private directories
```

> **Memory hook:** **R**eal **W**izards e**X**ist: **4 - 2 - 1**. Add the wizards you want: read+write = 4+2 = 6.

Symbols are handy for small changes:

```bash
chmod u+x deploy.sh          # owner: add execute
chmod go-rwx secrets.env     # group & others: remove everything
chmod g=r deploy.sh          # group: exactly read
chmod -R g+w shared/         # recursive
```

`u` user/owner, `g` group, `o` others, `a` all.

[[lab-task:2]]

[[lab-task:3]]

What you should see:

```
$ ls -l keys
-rwxr----- 1 labuser labuser 15 ... deploy.sh
-rw------- 1 labuser labuser 21 ... secrets.env
```

## chown and chgrp: changing the owner

```bash
sudo chown rhea deploy.sh             # new owner
sudo chown rhea:baristas deploy.sh    # owner and group
sudo chown -R www-data:www-data /srv/shop   # whole tree, e.g. for the web server
chgrp baristas notes.txt              # group only (you must be in that group)
```

Only root can give a file away to another user - otherwise you could dodge disk quotas by "gifting" files.

## Special bits: SUID, SGID, sticky

| Bit | Value | On a file | On a directory | Looks like |
|---|---|---|---|---|
| SUID | 4000 | runs as the file's **owner** | - | `-rwsr-xr-x` |
| SGID | 2000 | runs as the file's group | new files inherit the dir's group | `drwxrwsr-x` |
| Sticky | 1000 | - | only the owner can delete their files | `drwxrwxrwt` |

`/usr/bin/passwd` is SUID root - that is how a normal user can update the root-only `/etc/shadow`. SUID binaries are a favourite attack target: `find / -perm -4000 2>/dev/null` lists them all.

> **Memory hook:** the **sticky** bit is **chewing gum on a locker** - anyone can put things in, but only you can take yours out. `/tmp` is the classic sticky directory.

[[lab-task:4]]

## umask: default permissions

New files start at `666`, new directories at `777`, then the **umask** removes bits:

```
  files:  666 - 022 = 644      directories: 777 - 022 = 755    (common default)
  files:  666 - 027 = 640      directories: 777 - 027 = 750    (safer)
  files:  666 - 077 = 600      directories: 777 - 077 = 700    (private)
```

```bash
umask           # show current (0022)
umask 027       # set for this shell; put it in ~/.bashrc to keep it
```

[[lab-task:5]]

## sudo: borrowing root's keys

Never log in as root for daily work. Use `sudo` for the one command that needs it:

```bash
sudo apt update              # run one command as root
sudo -i                      # root shell (be careful)
sudo -u postgres psql        # run as another user
sudo -l                      # what am I allowed to run?
sudo visudo                  # edit /etc/sudoers SAFELY (syntax-checked)
```

Who may use sudo is decided by `/etc/sudoers` and `/etc/sudoers.d/`. On Ubuntu, members of the `sudo` group get full access (`wheel` on RHEL/Fedora). Every sudo use is logged (`/var/log/auth.log`) - that is how Rhea will find out who read the password.

```
# /etc/sudoers.d/baristas
%baristas ALL=(ALL) /usr/bin/systemctl restart brewbot
#  who    host  as-whom   which command (only this one!)
```

**ACLs** go beyond owner/group/others when one extra person needs access:

```bash
setfacl -m u:sam:r secrets.env    # give sam read, nobody else changes
getfacl secrets.env               # a + at the end of ls -l means an ACL exists
```

> **End of day 4.** The deploy script is locked, secrets are 600, and new files are private by default. Rhea checks `/var/log/auth.log` and finds the culprit: a forgotten test account. Tom's next note was taped under a desk: "Atlas is never doing just one thing."
