---
kind: lesson
id_key: linux/keys-and-locks/users-and-groups
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks - Users and Permissions"
section_position: 4
title: "Users and Groups: Who Is Who on Atlas"
position: 0
estimated_minutes: 7
source:
  - passwd(5), group(5), shadow(5), id(1), getent(1) manual pages
---

## Why this matters

> **Thursday.** Rhea is upset: "Someone read our database password last night.
> Tom's old deploy script was world-readable." Tom's note said *not everyone
> should have every key*.

Before you can lock anything, you must know who the "someones" are. Every
permission decision Linux makes starts with two questions: **which user** is
asking, and **which groups** are they in?

## Mental model: staff badges

- Every person and every service has a **user** account: a badge with a number,
  the **UID** (user ID).
- A **group** is a team badge (GID). A user has one **primary group** and any
  number of **supplementary groups**.
- Every **process** runs with a user's badge, and every **file** is owned by one
  user and one group.

On each file access, the kernel compares the process's badges with the file's
owner and group. That is the whole security model of this chapter.

UID **0** is **root**, the superuser. The kernel skips most permission checks for
UID 0. Its name does not matter; its number does.

## See it work

```bash
whoami        # your user name
id            # your UID, primary group and all groups
```

What this does: shows your badges. Expected output in the lab:

```
labuser
uid=1001(labuser) gid=1001(labuser) groups=1001(labuser)
```

On a real admin account you might see
`groups=1000(rhea),27(sudo),998(docker)`.

### The staff register: three text files

```bash
getent passwd labuser root www-data
```

```
labuser:x:1001:1001::/home/labuser:/bin/bash
root:x:0:0:root:/root:/bin/bash
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
```

`/etc/passwd` has seven colon-separated fields:

```
labuser : x  : 1001 : 1001 : (comment) : /home/labuser : /bin/bash
 name    pw    UID    GID     comment      home          login shell
```

- The `x` means the password hash is in **`/etc/shadow`**, readable only by
  root.
- `/etc/group` lists groups: `baristas:x:2001:labuser,rhea` (name, pw, GID,
  members).

`getent` reads these databases the way programs do, including network
directories like LDAP, so prefer it over `cat /etc/passwd` when it matters.

### System accounts

UIDs below 1000 (on Debian/Ubuntu and RHEL) are usually **system accounts** for
services: `www-data` (web server), `postgres`, `redis`. Their shell is
`/usr/sbin/nologin`, so nobody can log in as them. Running each service as its
own user limits the damage if it is hacked.

```bash
who      # who is logged in right now
w        # same, plus what they are running
last     # recent logins (reads /var/log/wtmp)
```

## Try it

Using `/etc/passwd`, print the UID and login shell of `labuser`, separated by a
space. (Chapter 3's `awk -F:` will do it.)

<details>
<summary>Show answer</summary>

```bash
awk -F: '$1 == "labuser" {print $3, $7}' /etc/passwd
```

```
1001 /bin/bash
```

</details>

## Common mistakes

- **Thinking "root" is special because of its name.** Any account with UID 0 is
  all-powerful. An extra UID 0 account is a classic backdoor; check with
  `awk -F: '$3 == 0' /etc/passwd`.
- **Editing `/etc/passwd` by hand.** One broken line can lock everyone out. Use
  `useradd`, `usermod` and `vipw` (next lesson).
- **Running services as root "to avoid permission errors".** Give each service
  its own user and fix the permissions instead.

## Remember

- Users have UIDs, groups have GIDs; root is UID 0.
- `id` shows your user and groups; `getent passwd NAME` shows an account.
- `/etc/passwd` (accounts), `/etc/shadow` (hashes, root only), `/etc/group`.
- Services run as system users with `nologin` shells.

**Self-check:**

1. Which field of `/etc/passwd` holds the login shell?
2. Where are password hashes stored, and who can read them?
3. Why does `www-data` have `/usr/sbin/nologin` as its shell?
