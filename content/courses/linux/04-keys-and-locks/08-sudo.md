---
kind: lesson
id_key: linux/keys-and-locks/sudo
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks - Users and Permissions"
section_position: 4
title: "sudo: Borrowing Root's Keys Safely"
position: 7
estimated_minutes: 7
source:
  - sudo(8), sudoers(5), visudo(8), su(1) manual pages
---

## Why this matters

Installing packages, restarting services and editing `/etc` all need root. Logging
in as root for that is how one typo becomes an outage and how nobody can tell who
did what. `sudo` gives root power one command at a time, with a log entry for
each.

## Mental model: the key cabinet with a sign-out sheet

- Root's keys hang in a cabinet.
- `sudo` lets approved staff borrow a key **for one command**.
- Every borrow is written in a log: who, when, which command.
- The list of who may borrow which key is `/etc/sudoers`.

`su` is the old way: it asks for **root's** password and gives you a whole root
shell. `sudo` asks for **your own** password, can be limited to specific
commands, and logs each one. Prefer `sudo`.

## See it work

```bash
sudo apt update                # run one command as root
sudo -u postgres psql          # run as another user (not root)
sudo -l                        # what am I allowed to run?
sudo -i                        # a full root login shell (use sparingly)
sudo !!                        # rerun the previous command with sudo
```

Expected output of `sudo -l` for an admin on Ubuntu:

```
User rhea may run the following commands on atlas:
    (ALL : ALL) ALL
```

After you type your password once, sudo remembers it for about 15 minutes per
terminal.

### Who may use sudo?

Rules live in `/etc/sudoers` and files in `/etc/sudoers.d/`. On Ubuntu, members
of group **`sudo`** get full access; on RHEL/Fedora the group is **`wheel`**.

A narrow rule lets the baristas restart brewbot and nothing else:

```
# /etc/sudoers.d/baristas
%baristas ALL=(root) /usr/bin/systemctl restart brewbot
#  who    host  as-whom   which command (full path, only this one)
```

`%` marks a group. Always use full paths in rules.

### Edit only with visudo

```bash
sudo visudo                              # edit /etc/sudoers
sudo visudo -f /etc/sudoers.d/baristas   # edit a drop-in file
```

`visudo` locks the file and checks the syntax before saving. A broken sudoers
file can remove **everyone's** sudo access, and then you need recovery mode to
fix it (Incident Week covers that).

### The audit trail

Every sudo use is logged:

```bash
sudo grep sudo /var/log/auth.log | tail -3      # Debian/Ubuntu
sudo journalctl _COMM=sudo --since today        # any systemd distro
```

```
Oct 14 02:13:07 atlas sudo:  test : TTY=pts/1 ; PWD=/home/test ; USER=root ; COMMAND=/usr/bin/cat /etc/brewbot/brewbot.conf
```

That is how Rhea found the culprit: a forgotten `test` account with sudo rights.

### Dangerous rules

Some "harmless" commands give a full root shell: an editor (`vim` can run
`:!bash`), `less`, `find -exec`, `tar`, or any script the user can edit. Granting
`sudo vim /etc/hosts` is effectively granting root. Grant specific, non-interactive
commands, and keep `NOPASSWD` for automation accounts only.

## Try it

The baristas should be able to run `systemctl status brewbot` and
`systemctl restart brewbot` as root, and nothing else. Write the sudoers line and
say how you would install it safely.

<details>
<summary>Show answer</summary>

```
%baristas ALL=(root) /usr/bin/systemctl status brewbot, /usr/bin/systemctl restart brewbot
```

Create it with `sudo visudo -f /etc/sudoers.d/baristas`, then check with
`sudo -l -U sam` that a barista sees exactly those two commands.

</details>

## Common mistakes

- **`sudo su -` as a habit.** You lose the per-command log. Use `sudo CMD`, or
  `sudo -i` only when really needed.
- **Editing sudoers with a normal editor.** One typo locks everyone out. Always
  `visudo`.
- **`sudo` with redirection.** `sudo echo x > /etc/f` fails: the redirection runs
  as you. Use `echo x | sudo tee /etc/f`.
- **Granting editors or shells via sudo.** They can spawn a root shell.

## Remember

- `sudo CMD` = one command as root, logged; `sudo -u USER` = as someone else.
- `sudo -l` shows your rights.
- Rules in `/etc/sudoers` and `/etc/sudoers.d/`; edit with `visudo` only.
- Ubuntu group `sudo`, RHEL group `wheel`; logs in `auth.log` / the journal.

**Self-check:**

1. What is the difference between `su` and `sudo`?
2. Why must you use `visudo`?
3. Why is `sudo vim` effectively full root?
