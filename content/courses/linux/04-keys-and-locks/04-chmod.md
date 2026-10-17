---
kind: lesson
id_key: linux/keys-and-locks/chmod
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks - Users and Permissions"
section_position: 4
title: "chmod: Changing the Locks with Numbers and Letters"
position: 3
estimated_minutes: 7
source:
  - chmod(1) manual page; GNU Coreutils manual, "File permissions"
---

## Why this matters

The deploy script was world-readable, so anyone on atlas could read the database
password inside it. One `chmod` would have prevented the incident. You will set
permissions every week: scripts, keys, secrets, shared folders.

## Mental model: three wizards per class

Each class (owner, group, others) gets a number from adding up three values:

```
 r = 4      w = 2      x = 1

 7 = rwx   6 = rw-   5 = r-x   4 = r--   0 = ---
```

> **Memory hook:** **R**eal **W**izards e**X**ist: **4 - 2 - 1**. Add the
> wizards you want: read + write = 4 + 2 = 6.

Three digits, one per class, in the order owner, group, others:

```
 chmod 740 deploy.sh
       |||
       ||+-- others: 0 = ---
       |+--- group:  4 = r--
       +---- owner:  7 = rwx
```

The five modes you will use 95% of the time:

| Mode | Looks like | Use for |
|---|---|---|
| `755` | `rwxr-xr-x` | programs, scripts, normal directories |
| `644` | `rw-r--r--` | normal files |
| `700` | `rwx------` | private directories (`~/.ssh`) |
| `600` | `rw-------` | private keys, passwords, `.env` files |
| `640` | `rw-r-----` | config readable by a service's group |

## See it work

```bash
mkdir -p ~/work/keys && cd ~/work/keys
echo 'echo deploying' > deploy.sh
chmod 740 deploy.sh
ls -l deploy.sh
```

What this does: owner gets everything, group may read, others nothing. Expected
output:

```
-rwxr----- 1 labuser labuser 15 Oct 14 10:02 deploy.sh
```

### Symbolic mode: small changes

When you only want to change one thing, letters are clearer than numbers:

```bash
chmod u+x deploy.sh          # owner (user): add execute
chmod go-rwx secrets.env     # group and others: remove everything
chmod g=r deploy.sh          # group: exactly read, nothing else
chmod a+r index.html         # all: add read
chmod -R g+w shared/         # recursive: whole tree
```

`u` user/owner, `g` group, `o` others, `a` all; `+` add, `-` remove, `=` set
exactly.

### Recursive changes, carefully

`chmod -R 644 dir` also removes `x` from every **directory**, so nobody can
enter them any more. Use capital `X`, which adds execute only to directories
(and files that already have it):

```bash
chmod -R u=rwX,g=rX,o= /srv/shop      # dirs 750, files 640
```

Or treat files and directories separately with `find`:

```bash
find /srv/shop -type d -exec chmod 755 {} +
find /srv/shop -type f -exec chmod 644 {} +
```

Only the file's **owner** (or root) can change its mode.

## Try it

Create `secrets.env` containing `DB_PASSWORD=espresso` and make it readable and
writable by you only. Give both the numeric and the symbolic command.

<details>
<summary>Show answer</summary>

```bash
echo 'DB_PASSWORD=espresso' > secrets.env
chmod 600 secrets.env          # or: chmod u=rw,go= secrets.env
ls -l secrets.env              # -rw------- ...
```

</details>

## Common mistakes

- **`chmod 777` to "fix" an error.** It lets every user and every hacked service
  change the file. Find who needs access and grant only that.
- **`chmod -R 644` on a directory tree.** Directories lose `x` and become
  unreachable. Use `X` or `find -type`.
- **Making a secret 600 but leaving its directory open.** Others cannot read it,
  but with `w` on the directory they can delete or replace it.
- **Forgetting the leading zero is optional.** `chmod 0640` and `chmod 640` are
  the same. A fourth leading digit sets special bits (lesson 6).

## Remember

- r=4, w=2, x=1; three digits = owner, group, others.
- 755 programs/dirs, 644 files, 700 private dirs, 600 secrets.
- Symbolic: `u/g/o/a` with `+ - =`.
- Recursive: use `X` or separate `find -type d/f` runs. Never 777.

**Self-check:**

1. What number is `r-x`?
2. Write `rw-r-----` as a number.
3. What does capital `X` do in `chmod -R`?
