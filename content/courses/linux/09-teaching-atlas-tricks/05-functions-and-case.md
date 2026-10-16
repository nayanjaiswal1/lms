---
kind: lesson
id_key: linux/teaching-atlas-tricks/functions-and-case
course: linux
section: teaching-atlas-tricks
section_title: "Chapter 9: Teaching Atlas Tricks - Bash Scripting"
section_position: 9
title: "Functions, case and Arrays"
position: 4
estimated_minutes: 7
source:
  - GNU Bash Reference Manual, "Shell Functions", "Conditional Constructs" (case), "Arrays"; getopts builtin
---

## Why this matters

A 200-line script with the same `curl` check copied six times is hard to read
and easy to break. Functions give a name to a block you reuse. `case` turns a
pile of `if`s into a clear menu: `brewctl start|stop|status`.

## Mental model: named mini-scripts

A **function** is a small script inside your script: it has its own arguments
(`$1`, `$2`...) and returns an exit status, just like a command.

```
 is_up 8080          ->   function is_up() { curl -sf ... "localhost:$1" ... }
   $1 = 8080                returns 0 (up) or non-zero (down)
```

## See it work

### Functions

```bash
log() {
  echo "$(date +%T) $*" >&2
}

is_up() {
  local port=$1
  curl -sf --max-time 2 "http://localhost:$port/" >/dev/null
}

if is_up 8080; then log "brewbot ok"; else log "brewbot DOWN"; fi
```

What this does: `log` prints a timestamped message to stderr; `is_up`'s exit
status is curl's exit status, so it works directly in `if`. Expected output when
nothing listens on 8080:

```
10:42:07 brewbot DOWN
```

- `local port=$1` keeps the variable inside the function.
- `$*` in `log` joins all its arguments into one string.
- `return N` sets a function's status; `exit N` would end the whole script.
- Functions must be defined before they are called.

### case: a clean menu

```bash
case "${1:-}" in
  start)        echo "starting" ;;
  stop)         echo "stopping" ;;
  status|st)    echo "brewbot: OK" ;;
  *.conf)       echo "checking config $1" ;;
  *)            echo "Usage: $0 {start|stop|status}" >&2; exit 1 ;;
esac
```

Each branch is a pattern (`|` means or, `*` is a glob) ending with `)`, and
each block ends with `;;`. `*)` catches everything else, perfect for a usage
message.

### Arrays

```bash
services=(nginx brewbot postgres)
echo "${services[0]}"          # nginx
echo "${#services[@]}"         # 3
for s in "${services[@]}"; do echo "check $s"; done
services+=(redis)              # append
```

`"${arr[@]}"` expands to every element, each kept intact (like `"$@"`).
Associative arrays map names to values: `declare -A port=([web]=80 [api]=8080);
echo "${port[api]}"`.

### Options with getopts

```bash
verbose=0
while getopts "vd:" opt; do
  case $opt in
    v) verbose=1 ;;
    d) dest=$OPTARG ;;
    *) echo "Usage: $0 [-v] [-d DIR]" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))          # what remains in "$@" are the normal arguments
```

`"vd:"` means: `-v` takes no value, `-d` needs one (the colon).

## Try it

Write a function `need` that takes a command name and exits the script with
status 127 and a message on stderr if that command is not installed. Use it for
`jq`.

<details>
<summary>Show answer</summary>

```bash
need() {
  command -v "$1" >/dev/null || { echo "missing command: $1" >&2; exit 127; }
}
need jq
```

</details>

## Common mistakes

- **Forgetting `local`.** Function variables overwrite globals with the same
  name.
- **`exit` inside a function meant to report failure.** It ends the whole script.
  Use `return 1` when the caller should decide.
- **Missing `;;` in case.** Syntax error, or execution falls into the wrong
  branch (`;&`).
- **`${arr[@]}` without quotes.** Elements with spaces split apart.

## Remember

- `name() { ...; }`; arguments `$1...`; `local` vars; `return N`.
- A function's exit status works directly in `if`.
- `case "$1" in a) ...;; b|c) ...;; *) usage;; esac`.
- Arrays: `arr=(a b)`, `"${arr[@]}"`, `${#arr[@]}`; options with `getopts`.

**Self-check:**

1. How does a function return success or failure?
2. What does `*)` do in a `case`?
3. Why quote `"${arr[@]}"`?
