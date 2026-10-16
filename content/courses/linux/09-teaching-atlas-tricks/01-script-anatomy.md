---
kind: lesson
id_key: linux/teaching-atlas-tricks/script-anatomy
course: linux
section: teaching-atlas-tricks
section_title: "Chapter 9: Teaching Atlas Tricks - Bash Scripting"
section_position: 9
title: "Anatomy of a Script: Shebang, set -euo pipefail, Running It"
position: 0
estimated_minutes: 7
source:
  - GNU Bash Reference Manual, "Shell Scripts" and "The Set Builtin"
  - execve(2) manual page ("interpreter scripts")
---

## Why this matters

> **Wednesday, week 2.** Rhea counts on her fingers: "You checked services by
> hand, made backups by hand, read logs by hand. Tom wrote on the whiteboard:
> *lazy admins write scripts*."

A script is just the commands you already know, saved in a file, plus a little
logic. Written carefully, it does a 10-minute chore in one second, the same way
every time, at 3am, without you.

## Mental model: a recipe card with a safety belt

```bash
#!/bin/bash                 # 1. shebang: which interpreter runs this file
# greet.sh - say hello      # 2. comment: what and why
set -euo pipefail           # 3. safety belt: stop on errors

name="$1"                   # 4. the work: the commands you already know
echo "Hello, $name!"
```

- **Shebang** `#!/bin/bash`: the first line tells the kernel which program
  interprets the file. `#!/usr/bin/env bash` finds bash via PATH, useful when it
  lives elsewhere (macOS, NixOS).
- **`set -euo pipefail`**: without it, bash carries on after errors, which is how
  a failed `cd` turns into `rm -rf` in the wrong directory.
  - `-e` exit on the first failing command
  - `-u` treat unset variables as an error (catches typos)
  - `-o pipefail` a pipeline fails if *any* part fails, not only the last

> **Memory hook:** "**E**very **U**nsafe **O**ption, **P**lease **F**ail": put
> `set -euo pipefail` at the top of every script.

## See it work

```bash
mkdir -p ~/work/scripts && cd ~/work/scripts
cat > greet.sh <<'EOF'
#!/bin/bash
set -euo pipefail
echo "Hello, $1!"
EOF
chmod +x greet.sh
./greet.sh Rhea
```

What this does: writes the script with a here-document, makes it executable, and
runs it. Expected output:

```
Hello, Rhea!
```

Three ways to run a script:

```bash
./greet.sh Rhea          # needs the x bit; ./ because . is not in PATH
bash greet.sh Rhea       # bash reads the file; no x bit needed
source greet.sh Rhea     # runs in YOUR shell: its variables and cd stick
```

Use `./` or `bash` normally; `source` only for files meant to change your
current shell (like `~/.bashrc`).

### See what the script does: -x

```bash
bash -x greet.sh Rhea
```

```
+ set -euo pipefail
+ echo 'Hello, Rhea!'
Hello, Rhea!
```

Every command is printed with `+` before it runs, with variables already
expanded. This is the first debugging tool for any script. `set -x` inside a
script turns it on from that line.

### What -u catches

```bash
./greet.sh
```

```
./greet.sh: line 3: $1: unbound variable
```

Without `-u`, the script would print `Hello, !` and "succeed". Failing loudly is
better than succeeding wrongly.

## Try it

Write `~/work/scripts/today.sh` that prints `Today is` followed by the date in
`YYYY-MM-DD` format (`date +%F`), make it executable and run it.

<details>
<summary>Show answer</summary>

```bash
cat > ~/work/scripts/today.sh <<'EOF'
#!/bin/bash
set -euo pipefail
echo "Today is $(date +%F)"
EOF
chmod +x ~/work/scripts/today.sh
~/work/scripts/today.sh
```

`$(...)` runs a command and inserts its output (next lesson).

</details>

## Common mistakes

- **No shebang.** The file may run with `sh` instead of bash, and bash features
  fail in odd ways.
- **Windows line endings.** `bad interpreter: /bin/bash^M` means the file has
  `\r\n`. Fix with `sed -i 's/\r$//' script.sh`.
- **Forgetting `chmod +x`.** `./script.sh: Permission denied`.
- **Leaving out `set -euo pipefail`.** Errors are silently ignored and the
  script continues on bad data.

## Remember

- Line 1: `#!/bin/bash`; line 2-3: `set -euo pipefail`.
- `chmod +x` then `./script.sh`; or `bash script.sh`.
- `bash -x` shows every command as it runs.
- Fail loudly: `-e` errors, `-u` unset variables, `pipefail` pipelines.

**Self-check:**

1. What does the shebang line do?
2. What does `-o pipefail` change?
3. How do you trace a script's commands as they run?
