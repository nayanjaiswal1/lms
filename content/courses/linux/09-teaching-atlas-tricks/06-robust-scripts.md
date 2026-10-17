---
kind: lesson
id_key: linux/teaching-atlas-tricks/robust-scripts
course: linux
section: teaching-atlas-tricks
section_title: "Chapter 9: Teaching Atlas Tricks - Bash Scripting"
section_position: 9
title: "Making Scripts Robust: trap, mktemp, flock and shellcheck"
position: 5
estimated_minutes: 7
source:
  - GNU Bash Reference Manual, "trap" builtin; mktemp(1), flock(1), logger(1) manual pages; ShellCheck wiki (shellcheck.net)
---

## Why this matters

A script that works when you run it is not done. It must also behave when it is
interrupted, run twice at once, run from cron with no PATH, or meet a file name
with spaces. Five habits cover most of that.

## Mental model: leave the kitchen clean, whatever happens

A good script is like a good cook: it gets its ingredients ready (checks inputs),
works in its own space (temp directory), cleans up even if interrupted (trap),
never cooks the same order twice at the same time (lock), and reports clearly
what happened (exit codes and logs).

## See it work

### Clean up with trap

```bash
#!/bin/bash
set -euo pipefail
tmp=$(mktemp -d)                    # private, unique temp directory
trap 'rm -rf "$tmp"' EXIT           # runs however the script ends
cp /etc/hostname "$tmp/"
ls "$tmp"
```

`mktemp -d` creates something like `/tmp/tmp.k3J9x2`, readable only by you.
`trap '...' EXIT` runs when the script exits, whether normally, by `exit 1`,
by an error under `set -e`, or by Ctrl+C. No more stale temp files.

### Validate inputs first

```bash
src=${1:?usage: backup.sh SRC_DIR DEST_DIR}
dest=${2:?usage: backup.sh SRC_DIR DEST_DIR}
[ -d "$src" ] || { echo "no such dir: $src" >&2; exit 2; }
command -v tar >/dev/null || { echo "tar not installed" >&2; exit 127; }
```

Check everything before changing anything.

### Never run twice at once

A cron job every 5 minutes that sometimes takes 7 will overlap and corrupt its
own output. A lock prevents that:

```bash
exec 9>/tmp/backup.lock
flock -n 9 || { echo "already running" >&2; exit 0; }
```

Or from cron directly: `flock -n /tmp/backup.lock /opt/backup.sh`.

### Be idempotent

**Idempotent** = running it twice is as safe as running it once.

```bash
mkdir -p "$dest"                 # not mkdir
ln -sfn "$release" current       # replace the link, do not fail
grep -qx 'umask 027' ~/.bashrc || echo 'umask 027' >> ~/.bashrc   # add once
```

### Log usefully

```bash
log() { echo "$(date -Is) $*" >&2; }
log "backup of $src started"
logger -t backup "finished OK"     # write to syslog/the journal
```

### Run shellcheck

```bash
shellcheck backup.sh
```

```
In backup.sh line 7:
cp $src $dest
   ^--^ SC2086 (info): Double quote to prevent globbing and word splitting.
```

`shellcheck` finds unquoted variables, useless `cat`s, wrong tests and many
classic bugs. Run it on every script (`apt install shellcheck`).

### For cron and systemd

- Use **full paths** or set `PATH` at the top.
- Keep output: `>> /var/log/job.log 2>&1`, or let systemd collect it.
- Return **meaningful exit codes** so monitoring can alert.

## Try it

Your script creates `/tmp/report.csv` and sometimes crashes halfway, leaving a
half-written file that tomorrow's run mistakes for a finished one. Name two
changes that fix it.

<details>
<summary>Show answer</summary>

Write into `tmp=$(mktemp)` with `trap 'rm -f "$tmp"' EXIT`, and only
`mv "$tmp" /tmp/report.csv` at the very end. `mv` within one filesystem is
atomic: readers see the old file or the complete new one, never half of one.

</details>

## Common mistakes

- **Fixed temp names like `/tmp/data`.** Two runs collide, and other users can
  pre-create the file. Use `mktemp`.
- **Cleanup only at the end of the script.** A failure skips it. Use `trap`.
- **Writing results in place.** Readers see half-written files. Write to temp,
  then `mv`.
- **Ignoring shellcheck warnings.** They are almost always real bugs.

## Remember

- `mktemp -d` + `trap 'rm -rf "$tmp"' EXIT`.
- Validate inputs and dependencies before doing anything.
- `flock -n` against overlapping runs; idempotent commands (`mkdir -p`, `ln -sfn`).
- Write to temp then `mv`; run `shellcheck`.

**Self-check:**

1. When does a `trap ... EXIT` run?
2. What does idempotent mean?
3. Why write to a temp file and then `mv`?
