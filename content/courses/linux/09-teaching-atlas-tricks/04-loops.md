---
kind: lesson
id_key: linux/teaching-atlas-tricks/loops
course: linux
section: teaching-atlas-tricks
section_title: "Chapter 9: Teaching Atlas Tricks - Bash Scripting"
section_position: 9
title: "Loops: for, while read and Ranges"
position: 3
estimated_minutes: 7
source:
  - GNU Bash Reference Manual, "Looping Constructs" and "Brace Expansion"; read builtin
---

## Why this matters

Five reports, thirty log files, ten servers, every line of a service list: the
moment you do something more than twice, a loop does it for you, the same way
each time.

## Mental model: a conveyor belt

A loop takes items off a belt one at a time, puts each in a variable, and runs
the same block of commands on it.

```
 for item in A B C          while read -r line
   do ... "$item" ... done     do ... "$line" ... done < file
   (a list you give it)        (one line at a time from a file or pipe)
```

## See it work

### for over a list

```bash
for n in 1 2 3; do echo "$n"; done
for n in {1..5}; do echo "Report $n" > "report-$n.txt"; done
ls report-*
```

What this does: `{1..5}` is brace expansion that generates `1 2 3 4 5` before
the loop runs. Expected output:

```
1
2
3
report-1.txt  report-2.txt  report-3.txt  report-4.txt  report-5.txt
```

```bash
for f in *.log; do gzip "$f"; done           # every matching file
for host in web1 web2 db1; do ssh "$host" uptime; done
for ((i = 0; i < 3; i++)); do echo "$i"; done # C-style counter
```

If no file matches `*.log`, the loop runs once with the literal text `*.log`.
Guard with `[ -e "$f" ] || continue`, or set `shopt -s nullglob`.

### while read: one line at a time

```bash
cat > services.txt <<'EOF'
nginx running
brewbot stopped
EOF
while read -r name status; do
  echo "$name is $status"
done < services.txt
```

```
nginx is running
brewbot is stopped
```

`read -r name status` splits each line on whitespace: the first word into
`name`, the rest into `status`. `-r` keeps backslashes literal. Always use `-r`.

Read lines from a command's output with process substitution:

```bash
while read -r pid cmd; do
  echo "PID $pid runs $cmd"
done < <(ps -eo pid=,comm= | head -3)
```

### Controlling the loop

```bash
for f in *.conf; do
  [ -s "$f" ] || continue     # skip empty files
  grep -q DEBUG "$f" && break # stop at the first file with DEBUG
done

count=0
while [ $count -lt 3 ]; do count=$((count + 1)); done
until curl -sf localhost:8080 >/dev/null; do sleep 2; done   # wait for a service
```

`continue` skips to the next item; `break` leaves the loop; `until` loops while
the command fails.

## Try it

Using a loop at the prompt, create `~/work/scripts/reports/report-1.txt` to
`report-5.txt`, each holding one line `Report N`.

<details>
<summary>Show answer</summary>

```bash
mkdir -p ~/work/scripts/reports
for n in {1..5}; do echo "Report $n" > ~/work/scripts/reports/report-$n.txt; done
cat ~/work/scripts/reports/report-3.txt     # Report 3
```

</details>

## Common mistakes

- **`for line in $(cat file)`.** Splits on every space, not on lines. Use
  `while read -r`.
- **`cat file | while read ...; do count=...; done`.** The pipe runs the loop in
  a subshell, so variables set inside vanish. Use `done < file`.
- **Unquoted `$f` in the body.** File names with spaces break. Quote.
- **Endless `until` loops.** Add a limit: count attempts and give up.

## Remember

- `for x in LIST; do ...; done`; `{1..5}` makes ranges.
- `while read -r a b; do ...; done < file` for lines.
- `continue` skips, `break` exits, `until` waits for success.
- Quote `"$x"` inside loops; avoid `for line in $(cat f)`.

**Self-check:**

1. Why does `for line in $(cat f)` not loop over lines?
2. What does `-r` do in `read -r`?
3. Why can a variable set inside `cmd | while read` be lost?
