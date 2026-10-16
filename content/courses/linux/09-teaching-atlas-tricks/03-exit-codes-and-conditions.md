---
kind: lesson
id_key: linux/teaching-atlas-tricks/exit-codes-and-conditions
course: linux
section: teaching-atlas-tricks
section_title: "Chapter 9: Teaching Atlas Tricks - Bash Scripting"
section_position: 9
title: "Exit Codes, if, test and && / ||"
position: 2
estimated_minutes: 8
source:
  - GNU Bash Reference Manual, "Exit Status", "Conditional Constructs", "Bash Conditional Expressions"; test(1)
---

## Why this matters

Scripts make decisions: is the service up, does the directory exist, did the
copy work? Every one of those decisions is based on one number every command
returns. Get it wrong and your script reports success on a failed backup.

## Mental model: zero is a hero

Every command ends with an **exit status** (0-255):

```
 0          = success
 1-255      = some kind of failure (the program decides which number means what)
```

`if`, `&&`, `||` and `set -e` all look at that number, not at the output.

> **Memory hook:** in the shell, **zero is a hero**: 0 means success, the
> opposite of most programming languages where 0 is false.

Common conventions: `1` general error, `2` misuse (bad arguments), `126` not
executable, `127` command not found, `128+N` killed by signal N.

## See it work

```bash
ls /etc/hostname; echo "status=$?"
ls /nope 2>/dev/null; echo "status=$?"
```

```
/etc/hostname
status=0
status=2
```

### if

```bash
if grep -q ERROR app.log; then
  echo "errors found"
elif [ -f app.log ]; then
  echo "clean log"
else
  echo "no log at all" >&2
  exit 1
fi
```

`if` runs the command after it and checks its status. `grep -q` prints nothing
and just returns 0 (found) or 1 (not found). `>&2` sends the message to stderr.

### Tests: [ ] and [[ ]]

`[` is a command (`test`) that checks a condition and returns 0 or 1. Spaces
inside the brackets are required.

| Test | True when |
|---|---|
| `-f path` / `-d path` / `-e path` | file / directory / anything exists |
| `-x path` / `-r path` / `-w path` | executable / readable / writable |
| `-s path` | file exists and is not empty |
| `-z "$s"` / `-n "$s"` | string empty / not empty |
| `"$a" = "$b"` / `!=` | strings equal / differ |
| `$a -eq $b`, `-ne`, `-lt`, `-gt`, `-le`, `-ge` | number comparisons |
| `! test` | negation |

`[[ ]]` is bash's improved test: safer with empty variables, supports `&&`,
`||`, patterns and regex:

```bash
[[ $file == *.log ]] && echo "a log file"
[[ $port =~ ^[0-9]+$ ]] || { echo "port must be a number" >&2; exit 2; }
(( count > 3 )) && echo "more than three"      # arithmetic test
```

### && and ||: short decisions

```bash
mkdir -p backups && echo "ready"     # && runs only on success
cd /srv/shop || exit 1               # || runs only on failure
```

`cd dir || exit 1` is the classic guard: never continue in the wrong directory.

### Setting your own exit code

```bash
if [ $# -lt 1 ]; then
  echo "Usage: greet.sh NAME" >&2
  exit 1
fi
```

Errors go to **stderr** and a **non-zero exit**, so cron, CI and other scripts
can tell success from failure.

## Try it

Write the start of a script that exits with status 2 and an error on stderr if
its first argument is not an existing directory.

<details>
<summary>Show answer</summary>

```bash
#!/bin/bash
set -euo pipefail
src=${1:-}
if [ ! -d "$src" ]; then
  echo "error: '$src' is not a directory" >&2
  exit 2
fi
```

`${1:-}` avoids the `-u` "unbound variable" error when no argument is given.

</details>

## Common mistakes

- **No spaces in tests.** `[ -f$x ]` or `[-f "$x"]` are syntax errors. Write
  `[ -f "$x" ]`.
- **`=` vs `-eq`.** `=` compares strings, `-eq` compares numbers. `[ 010 -eq 10 ]`
  is true, `[ 010 = 10 ]` is false.
- **Testing the output instead of the status.** `if [ "$(grep x f)" ]` works,
  but `if grep -q x f` is clearer and faster.
- **Checking `$?` too late.** Any command (even `echo`) overwrites it. Save it
  first: `rc=$?`.

## Remember

- 0 = success; `$?` holds the last status.
- `if CMD; then ...; elif ...; else ...; fi` checks a command's status.
- `[ -f f ]`, `[ -z "$s" ]`, `[ $a -lt $b ]`; prefer `[[ ]]` in bash.
- `&&` on success, `||` on failure; errors to stderr with `exit N`.

**Self-check:**

1. What exit status means "command not found"?
2. What is the difference between `=` and `-eq` in a test?
3. What does `cd /srv/shop || exit 1` protect against?
