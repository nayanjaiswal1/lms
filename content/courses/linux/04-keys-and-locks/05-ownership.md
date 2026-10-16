---
kind: lesson
id_key: linux/keys-and-locks/ownership
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks - Users and Permissions"
section_position: 4
title: "chown and chgrp: Changing Who Owns a File"
position: 4
estimated_minutes: 5
source:
  - chown(1), chgrp(1) manual pages
---

## Why this matters

You copy the shop's website into `/srv/shop` as yourself, and nginx (running as
`www-data`) answers 403 Forbidden. Brewbot cannot read its config because root
owns it with mode 600. Permissions are only half the story; the other half is
**who owns** the file.

## Mental model: the name on the locker

Each file has two name tags: an **owner** (a user) and a **group**. The rwx bits
from the last lesson say what the owner, the group and everyone else may do.
`chown` changes the tags; `chmod` changes the locks.

```
 -rw-r----- root  brewbot  brewbot.conf
            owner group
  root: rw   brewbot group members (the service): r   others: nothing
```

That pattern, **root owns, the service's group reads, mode 640**, is the
standard way to give a service read-only access to its config.

## See it work

These need root on atlas:

```bash
sudo chown rhea deploy.sh                    # new owner
sudo chown rhea:baristas deploy.sh           # owner and group
sudo chown :brewbot /etc/brewbot/brewbot.conf  # group only (same as chgrp)
sudo chown -R www-data:www-data /srv/shop    # whole tree
chgrp baristas notes.txt                     # group only
ls -l deploy.sh
```

Expected output of the last line:

```
-rwxr----- 1 rhea baristas 15 Oct 14 10:02 deploy.sh
```

### Who may change ownership?

- Only **root** can give a file to another user. Otherwise users could dodge
  disk quotas or plant files that look like someone else's.
- The owner may change the **group**, but only to a group they belong to.

In the lab (no root):

```bash
chown root ~/work/keys/deploy.sh
```

```
chown: changing ownership of '/home/labuser/work/keys/deploy.sh': Operation not permitted
```

### Fixing the brewbot config, the right way

```bash
sudo chown root:brewbot /etc/brewbot/brewbot.conf
sudo chmod 640 /etc/brewbot/brewbot.conf
sudo -u brewbot cat /etc/brewbot/brewbot.conf   # test AS the service user
```

`sudo -u brewbot` runs one command as the service's user: the fastest way to
prove the service can read what it needs.

## Try it

Brewbot runs as user `brewbot`. Its config `/etc/brewbot/brewbot.conf` is
`-rw------- root root`. Write the two commands that let brewbot read it without
letting anyone else read it or letting brewbot change it.

<details>
<summary>Show answer</summary>

```bash
sudo chgrp brewbot /etc/brewbot/brewbot.conf
sudo chmod 640 /etc/brewbot/brewbot.conf
```

Root keeps write access, the brewbot group gets read, others nothing. Making
brewbot the owner would also let it modify its own config, which you rarely
want.

</details>

## Common mistakes

- **`chown -R` on the wrong path.** `sudo chown -R www-data /` (from a stray
  space) breaks the whole system. Double-check before Enter.
- **Giving the service ownership when it only needs to read.** Use the group and
  640.
- **Fixing ownership of the file but not the directory.** The service also needs
  `x` on every parent directory (`namei -l`).

## Remember

- `chown user:group file`, `chgrp group file`, `-R` for trees.
- Only root can change the owner.
- Service config pattern: `root:service` with mode 640.
- Test as the service: `sudo -u USER command`.

**Self-check:**

1. Why can't normal users give files away?
2. What does `chown :web file` change?
3. How do you test whether user `brewbot` can read a file?
