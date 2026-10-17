---
kind: lesson
id_key: linux/teaching-atlas-tricks/variables-and-quoting
course: linux
section: teaching-atlas-tricks
section_title: "Chapter 9: Teaching Atlas Tricks - Bash Scripting"
section_position: 9
title: "Variables, Quoting, Arguments and Command Substitution"
position: 1
estimated_minutes: 8
source:
  - GNU Bash Reference Manual, "Quoting", "Shell Parameter Expansion", "Command Substitution", "Special Parameters"
---

## Why this matters

The most common bug in shell scripts is a missing pair of quotes. It works on
your test file and deletes the wrong thing on the file called `my notes.txt`.
Quoting is the one rule that turns fragile scripts into safe ones.

## Mental model: the shell splits words, quotes glue them

Before running a command, bash **expands** variables and then **splits** the
result on spaces. Double quotes stop the splitting.

```
 file="my notes.txt"

 rm $file      ->  rm  my  notes.txt     two arguments: deletes "my" and "notes.txt"
 rm "$file"    ->  rm  "my notes.txt"    one argument: deletes the right file
```

> **Rule:** always write `"$var"`. Leave the quotes off only when you know
> exactly why.

## See it work

```bash
shop="Orbit Coffee"          # no spaces around =
echo "$shop"                 # Orbit Coffee
echo "${shop}-backup"        # braces separate the name from text
echo '$shop'                 # single quotes: NO expansion, prints $shop
today=$(date +%Y-%m-%d)      # command substitution: capture output
count=$((3 + 4))             # arithmetic
echo "$today $count"
```

Expected output (date differs):

```
Orbit Coffee
Orbit Coffee-backup
$shop
2026-10-14 7
```

| Quotes | `$var` and `$(...)` expanded? | Use for |
|---|---|---|
| `"double"` | yes | almost everything |
| `'single'` | no | literal text, awk/sed programs |
| none | yes, then split and globbed | only when you want splitting |

### Arguments and special variables

| Variable | Meaning |
|---|---|
| `$0` | script name |
| `$1`, `$2` ... | arguments |
| `$#` | number of arguments |
| `"$@"` | all arguments, each safely quoted |
| `$?` | exit status of the last command |
| `$$` | this script's PID |

```bash
cat > args.sh <<'EOF'
#!/bin/bash
set -euo pipefail
echo "script=$0 count=$# first=${1:-none}"
for a in "$@"; do echo "arg: $a"; done
EOF
chmod +x args.sh && ./args.sh "dark roast" decaf
```

```
script=./args.sh count=2 first=dark roast
arg: dark roast
arg: decaf
```

`"$@"` kept `dark roast` as one argument. `$*` or unquoted `$@` would split it.

### Defaults and required values

```bash
port=${PORT:-8080}            # use PORT, or 8080 if unset/empty
dest=${2:?usage: backup.sh SRC DEST}   # stop with this message if $2 is missing
rm -rf "${BUILD_DIR:?}/"      # never becomes rm -rf / when BUILD_DIR is empty
```

`${var:-default}` and `${var:?message}` also keep `set -u` happy when an
argument is optional.

### Small string tricks

```bash
f=/var/log/brewbot/app.log
echo "${f##*/}"     # app.log          (like basename)
echo "${f%/*}"      # /var/log/brewbot (like dirname)
echo "${f%.log}.gz" # /var/log/brewbot/app.gz
echo "${#f}"        # 24               (length)
```

## Try it

`file="Q3 report.csv"`. Which command copies it to `/tmp` correctly:
`cp $file /tmp` or `cp "$file" /tmp`? What does the wrong one try to do?

<details>
<summary>Show answer</summary>

`cp "$file" /tmp`. The unquoted version becomes `cp Q3 report.csv /tmp`: it
tries to copy two files named `Q3` and `report.csv`.

</details>

## Common mistakes

- **Unquoted variables.** Spaces split them, `*` in values expands to file
  names.
- **Spaces around `=`.** `name = x` runs a command called `name`.
- **Single quotes when you need the value.** `echo '$HOME'` prints `$HOME`.
- **`$*` instead of `"$@"`.** Arguments with spaces get split.

## Remember

- Always `"$var"` and `"$@"`.
- `$(cmd)` captures output; `$((...))` does arithmetic.
- `$1..$9`, `$#`, `$?`, `$0`, `$$`.
- `${var:-default}`, `${var:?msg}`, `${f##*/}`, `${f%/*}`.

**Self-check:**

1. What is the difference between `'$x'` and `"$x"`?
2. Why is `"$@"` better than `$*`?
3. What does `${PORT:-8080}` do?
