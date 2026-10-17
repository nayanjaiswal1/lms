---
kind: lesson
id_key: linux/keys-and-locks/umask
course: linux
section: keys-and-locks
section_title: "Chapter 4: Keys and Locks - Users and Permissions"
section_position: 4
title: "umask: Safe Defaults for New Files"
position: 6
estimated_minutes: 5
source:
  - umask(2) manual page; GNU Bash Reference Manual, "umask" builtin
---

## Why this matters

You can `chmod` every secret file by hand, but you will forget one. The
**umask** decides the permissions of every *new* file automatically. Get the
default right and new files are private without you thinking about it.

## Mental model: a stencil that blocks bits

Programs ask for generous permissions when they create things:

- new **files**: `666` (`rw-rw-rw-`)
- new **directories**: `777` (`rwxrwxrwx`)

The umask is a stencil laid over that request. Every bit set in the umask is
**removed**.

```
  files:  666 - 022 = 644      directories: 777 - 022 = 755    (common default)
  files:  666 - 027 = 640      directories: 777 - 027 = 750    (safer)
  files:  666 - 077 = 600      directories: 777 - 077 = 700    (private)
```

(Strictly it is "remove these bits", not subtraction, but with these common
values the arithmetic gives the same answer.)

## See it work

```bash
umask
cd ~/work && touch before.txt && mkdir before.d
umask 027
touch after.txt && mkdir after.d
ls -ld before.txt before.d after.txt after.d
```

What this does: shows the current umask, creates a file and a directory, tightens
the umask, and creates two more. Expected output:

```
0022
drwxr-xr-x 2 labuser labuser 4096 ... before.d
-rw-r--r-- 1 labuser labuser    0 ... before.txt
drwxr-x--- 2 labuser labuser 4096 ... after.d
-rw-r----- 1 labuser labuser    0 ... after.txt
```

Others lost all access to the new items. Existing files did not change: umask
only affects creation.

### Making it permanent

`umask 027` at the prompt lasts until the shell exits. Put it in `~/.bashrc`
(chapter 1) to keep it:

```bash
echo 'umask 027' >> ~/.bashrc
```

For services, systemd sets it per unit with `UMask=0027` in the `[Service]`
section (chapter 6).

## Try it

With `umask 077`, what permissions does a new file get? A new directory?

<details>
<summary>Show answer</summary>

File `600` (`rw-------`), directory `700` (`rwx------`). Only the owner can do
anything.

</details>

## Common mistakes

- **Expecting umask to change existing files.** It only applies at creation time.
  Use `chmod` for files that already exist.
- **Expecting new files to be executable.** Files start from 666, so a new file
  never gets `x` from the umask. You `chmod +x` scripts yourself.
- **A too-strict umask on shared servers.** With `077`, teammates cannot read
  files you create in a shared folder. Use `027` plus group folders.

## Remember

- New files start at 666, directories at 777; the umask removes bits.
- 022 = 644/755, 027 = 640/750, 077 = 600/700.
- `umask` shows it; put `umask 027` in `~/.bashrc` to keep it.
- Only affects new files.

**Self-check:**

1. What does a umask of 022 do to a new directory?
2. Why does a new file never get the execute bit by default?
3. Where do you set a permanent umask for your shell?
