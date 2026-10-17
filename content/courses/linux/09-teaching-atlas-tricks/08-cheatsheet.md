---
kind: lesson
id_key: linux/teaching-atlas-tricks/cheatsheet
course: linux
section: teaching-atlas-tricks
section_title: "Chapter 9: Teaching Atlas Tricks - Bash Scripting"
section_position: 9
title: "Reference: Bash Scripting Cheat Sheet"
position: 7
estimated_minutes: 5
source:
  - GNU Bash Reference Manual (gnu.org/software/bash/manual)
---

## How to use this page

A reference for writing scripts. Everything here was explained in lessons 1-6 of
this chapter. Keep it open while you write; do not memorise it.

## Script template

```bash
#!/bin/bash
# name.sh - one line saying what this does
set -euo pipefail

usage() { echo "Usage: $0 SRC DEST" >&2; exit 2; }
log()   { echo "$(date -Is) $*" >&2; }

[ $# -eq 2 ] || usage
src=$1 dest=$2
[ -d "$src" ] || { log "no such dir: $src"; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

log "start"
# ... work in "$tmp", then mv results into place ...
log "done"
```

## Variables and expansion

| Syntax | Meaning |
|---|---|
| `x=1` / `"$x"` / `"${x}y"` | set / use / use next to text |
| `$(cmd)` / `$((a + b))` | command output / arithmetic |
| `${x:-def}` / `${x:=def}` | default / default and assign |
| `${x:?msg}` | stop with msg if unset or empty |
| `${#x}` | length |
| `${f##*/}` / `${f%/*}` | basename / dirname |
| `${f%.log}` / `${f#prefix}` | strip suffix / prefix |
| `${x/old/new}` / `${x//old/new}` | replace first / all |
| `${x^^}` / `${x,,}` | upper / lower case |

## Special parameters

`$0` script, `$1..$9` args, `$#` count, `"$@"` all args, `$?` last status,
`$$` PID, `$!` last background PID, `shift` drops `$1`.

## Tests

| Test | True when |
|---|---|
| `-e` `-f` `-d` `-L` | exists / file / directory / symlink |
| `-r` `-w` `-x` `-s` | readable / writable / executable / non-empty |
| `-z "$s"` / `-n "$s"` | empty / not empty |
| `=` `!=` | string equal / different |
| `-eq -ne -lt -le -gt -ge` | numeric |
| `[[ $s == *.log ]]` / `[[ $s =~ ^[0-9]+$ ]]` | glob / regex match |
| `(( n > 3 ))` | arithmetic |

## Control flow

```bash
if cmd; then ...; elif [ ... ]; then ...; else ...; fi
case "$1" in start) ... ;; stop|halt) ... ;; *) usage ;; esac
for x in a b c; do ...; done
for n in {1..10}; do ...; done
for ((i = 0; i < 5; i++)); do ...; done
while read -r a b; do ...; done < file
while read -r line; do ...; done < <(cmd)
until cmd; do sleep 2; done
cmd1 && cmd2 || cmd3
```

## Functions and arrays

```bash
f() { local a=$1; ...; return 0; }
arr=(a b c); "${arr[@]}"; ${#arr[@]}; arr+=(d)
declare -A m=([web]=80); "${m[web]}"
while getopts "vd:" o; do case $o in v) v=1;; d) d=$OPTARG;; esac; done; shift $((OPTIND-1))
```

## Exit codes

`0` ok, `1` general error, `2` usage, `126` not executable, `127` not found,
`128+N` killed by signal N (`130` Ctrl+C, `137` SIGKILL, `143` SIGTERM).

## Debugging and quality

| Tool | Use |
|---|---|
| `bash -n script` | syntax check only |
| `bash -x script` / `set -x` | trace every command |
| `shellcheck script` | lint for classic bugs |
| `PS4='+ ${LINENO}: '` | show line numbers in traces |

## Robustness checklist

- `set -euo pipefail`; quote every expansion.
- Validate arguments and required commands first.
- `mktemp` + `trap ... EXIT` for temporary files.
- Write to temp, then `mv` into place.
- `flock -n` for jobs that must not overlap.
- Full paths for cron; errors to stderr; meaningful exit codes.
