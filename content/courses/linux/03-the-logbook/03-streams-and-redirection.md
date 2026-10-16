---
kind: lesson
id_key: linux/the-logbook/streams-and-redirection
course: linux
section: the-logbook
section_title: "Chapter 3: The Logbook - Text Tools and Pipes"
section_position: 3
title: "stdin, stdout, stderr and Redirection"
position: 2
estimated_minutes: 8
source:
  - GNU Bash Reference Manual, "Redirections"; stdin(3), null(4), tee(1) manual pages
---

## Why this matters

A cron job "runs" but its errors vanish. A script writes errors into the data
file it produces. A search over `/` buries the answer under 500 "Permission
denied" lines. All three are fixed by sending each **stream** to the right
place.

## Mental model: one input pipe, two output pipes

Every program starts with three open channels, numbered:

```
            +-----------+
 stdin  0 ->|  program  |-> 1 stdout  (normal output)
            |           |-> 2 stderr  (errors and warnings)
            +-----------+
```

By default all three are connected to your terminal, which is why errors and
output look mixed together. **Redirection** reconnects them to files.

## See it work

```bash
ls ~/work/logbook /no/such/dir
```

```
ls: cannot access '/no/such/dir': No such file or directory
/home/labuser/work/logbook:
access.log
app.log
```

One command, two streams on one screen. Now split them:

```bash
ls ~/work/logbook /no/such/dir > out.txt 2> err.txt
cat err.txt
```

What this does: `>` sends stream 1 to `out.txt`, `2>` sends stream 2 to
`err.txt`. Expected output:

```
ls: cannot access '/no/such/dir': No such file or directory
```

### The redirection table

| Syntax | Meaning |
|---|---|
| `cmd > file` | stdout to file (overwrite) |
| `cmd >> file` | stdout to file (append) |
| `cmd 2> file` | stderr to file |
| `cmd > file 2>&1` | both streams to the same file |
| `cmd &> file` | same, bash shorthand |
| `cmd 2>/dev/null` | throw errors away |
| `cmd < file` | read stdin from a file |
| `cmd \| tee file` | show on screen *and* save to file |

`/dev/null` is the black hole: anything written there disappears.

### Why order matters in `2>&1`

`2>&1` means "point stream 2 wherever stream 1 points **right now**".
Redirections are processed left to right.

```
 cmd > log 2>&1     1 -> log, then 2 -> (where 1 points) = log      both in log
 cmd 2>&1 > log     2 -> terminal (where 1 points now), then 1 -> log
                    errors still on screen
```

So for a cron job, the safe pattern is:

```bash
/opt/brewbot/backup.sh >> /var/log/backup.log 2>&1
```

### Reading input from a file, and tee

```bash
wc -l < app.log           # wc reads stdin; prints just "80" (no file name)
grep ERROR app.log | tee errors.txt | wc -l
```

`tee` is a T-junction in the pipe: it writes a copy to a file and passes
everything on. Expected output of the second line: `16`, and `errors.txt` holds
the 16 lines.

To write to a root-owned file with sudo, `sudo echo x > /etc/file` fails because
your (non-root) shell opens the file. Use `echo x | sudo tee /etc/file` instead
(`tee -a` appends).

## Try it

Run `find / -name "*.conf"` so that the results go into `confs.txt` and every
"Permission denied" message is thrown away.

<details>
<summary>Show answer</summary>

```bash
find / -name "*.conf" > confs.txt 2>/dev/null
```

</details>

## Common mistakes

- **`2>&1 > file` order.** Errors stay on the screen. Put `2>&1` last.
- **Reading and writing the same file.** `sort data.txt > data.txt` empties the
  file before `sort` reads it. Write to a new file, then `mv`.
- **`sudo` with `>`.** The redirection runs as you, not root. Use `| sudo tee`.
- **Hiding all errors with `2>/dev/null` in scripts.** You also hide the one
  error that explains a failure. Hide them only when you know what they are.

## Remember

- 0 stdin, 1 stdout, 2 stderr.
- `>` overwrite, `>>` append, `2>` errors, `> f 2>&1` or `&> f` both.
- `/dev/null` discards; `tee` copies to a file and passes it on.
- Redirections apply left to right.

**Self-check:**

1. What number is stderr?
2. Why does `cmd 2>&1 > log` still show errors on screen?
3. How do you append a line to a root-owned file using sudo?
