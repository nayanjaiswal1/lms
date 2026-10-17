---
kind: lesson
id_key: linux/keys-and-locks/managing-users
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks - Users and Permissions"
section_position: 4
title: "Managing Users and Groups: useradd, usermod, passwd"
position: 1
estimated_minutes: 7
source:
  - useradd(8), usermod(8), userdel(8), groupadd(8), passwd(1), chage(1), adduser(8) manual pages
---

## Why this matters

Sam joins the team on Monday and needs an account. A forgotten test account was
how someone read the database password. Creating, changing and removing accounts
correctly, and spotting the ones that should not exist, is basic hygiene.

## Mental model: hiring, transfers, leaving

| Event | Command (needs root) |
|---|---|
| Hire someone | `useradd` (+ `passwd`) |
| Join a team | `usermod -aG team user` |
| Temporary suspension | `usermod -L` / `passwd -l` (lock) |
| Leave | `userdel -r` |
| New team | `groupadd` |

> **Memory hook:** `usermod -aG`: **A**lways **A**ppend. Forget the `-a` and the
> user is *removed* from every group you did not list.

## See it work

These commands change system files, so they need root. On atlas you prefix them
with `sudo` (lesson 8 of this chapter). They will not work in the lab, where you
are a normal user.

```bash
sudo groupadd baristas                          # new group
sudo useradd -m -s /bin/bash -G baristas sam    # create user
sudo passwd sam                                 # set a password (asks twice)
id sam
```

What this does: `-m` creates `/home/sam`, `-s` sets the login shell, `-G` adds
supplementary groups. Expected output of `id sam`:

```
uid=1002(sam) gid=1002(sam) groups=1002(sam),2001(baristas)
```

Each new user gets a private primary group with the same name (the "user
private group" scheme). On Debian/Ubuntu, `adduser sam` is a friendlier
interactive wrapper that asks for the password and details.

### Changing an existing user

```bash
sudo usermod -aG docker sam       # ADD sam to docker, keep other groups
sudo usermod -s /usr/sbin/nologin sam   # disable shell logins
sudo usermod -L sam               # lock the password (adds ! to the hash)
sudo usermod -U sam               # unlock
sudo chage -l sam                 # password ageing info
sudo chage -E 2026-12-31 sam      # account expires on that date
```

Group changes apply at the **next login**. Sam must log out and back in (or run
`newgrp docker` in one shell) before `id` shows the new group.

### Removing

```bash
sudo userdel -r sam      # delete user, home directory and mail spool
sudo groupdel baristas
```

Before deleting, find files the user owns elsewhere:
`sudo find / -xdev -user sam 2>/dev/null`.

### Auditing accounts

```bash
awk -F: '$3 >= 1000 {print $1}' /etc/passwd           # human accounts
awk -F: '$3 == 0 {print $1}' /etc/passwd              # should print only root
sudo awk -F: '$2 == "" {print $1}' /etc/shadow        # accounts with NO password
lastlog | grep -v Never                               # who ever logged in
```

## Try it

Sam is in groups `sam` and `sudo`. You run `sudo usermod -G docker sam`. What
groups does Sam have now, and what should you have typed?

<details>
<summary>Show answer</summary>

Only `sam` (primary) and `docker`. Without `-a`, `-G` replaces the whole list,
so Sam lost `sudo`. The right command is `sudo usermod -aG docker sam`.

</details>

## Common mistakes

- **`usermod -G` without `-a`.** Silently strips other groups, including
  `sudo`.
- **Expecting group changes to apply instantly.** Existing sessions keep their
  old groups until the user logs in again.
- **`userdel` without checking for running processes and cron jobs.** Kill or
  move them first, or the account's jobs fail in odd ways.
- **Shared accounts.** One `deploy` login used by five people means no audit
  trail. Give everyone their own account and use groups and sudo.

## Remember

- `useradd -m -s /bin/bash -G grp NAME`, then `passwd NAME`.
- `usermod -aG grp NAME`: always append.
- Lock with `usermod -L`, expire with `chage -E`, remove with `userdel -r`.
- New group membership needs a new login.

**Self-check:**

1. What does `-m` do in `useradd`?
2. Why does Sam not see the new group right away?
3. Which command lists accounts with UID 0?
