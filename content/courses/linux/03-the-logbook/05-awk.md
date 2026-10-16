---
kind: lesson
id_key: linux/the-logbook/awk
course: linux
section: the-logbook
section_title: "Chapter 3: The Logbook - Text Tools and Pipes"
section_position: 3
title: "awk: Columns Made Easy"
position: 4
estimated_minutes: 7
source:
  - awk(1) manual page; The GNU Awk User's Guide (gnu.org/software/gawk/manual)
---

## Why this matters

Access logs, `ps` output, `df` output: most admin data is columns. "Show the path
of every request that returned 500" means *filter on column 9, print column 7*.
`awk` does that in one short line.

## Mental model: a spreadsheet, one row at a time

`awk` reads a line, splits it into fields on whitespace, and names them `$1`,
`$2`, ... (`$0` is the whole line, `$NF` the last field). Then it runs your rule:

```
  awk ' CONDITION { ACTION } ' file

  for each line:
     if CONDITION is true (or missing) -> do ACTION (default: print the line)
```

An access log line, split:

```
 10.0.0.5 - - [14/Oct/2026:10:24:00 +0000] "GET /api/orders HTTP/1.1" 500 408
   $1     $2 $3        $4            $5    $6      $7         $8     $9  $10
```

> **Memory hook:** **s**ed **s**ubstitutes, **a**wk **a**sks about columns.

## See it work

```bash
cd ~/work/logbook
awk '{print $1, $9}' access.log | head -2      # IP and status
```

```
10.0.0.7 200
192.168.1.20 200
```

A comma in `print` inserts a space between fields.

```bash
awk '$9 == 500' access.log | head -2           # condition only: print matching lines
```

```
10.0.0.5 - - [14/Oct/2026:10:24:00 +0000] "GET /api/orders HTTP/1.1" 500 408
10.0.0.5 - - [14/Oct/2026:10:28:00 +0000] "GET /checkout HTTP/1.1" 500 476
```

```bash
awk '$9 == 500 {print $7}' access.log | sort | uniq -c   # condition + action
```

```
      7 /api/orders
      7 /checkout
```

That is the answer to "which pages are crashing?"

### Separators, sums and line numbers

```bash
awk -F: '{print $1, $7}' /etc/passwd            # -F sets the field separator
awk '{sum += $10} END {print sum}' access.log   # add up bytes sent
awk 'NR <= 3' app.log                           # NR = line number: first 3 lines
awk '{print $NF}' app.log | head -1             # last field of each line
awk '$3 == "ERROR" {n++} END {print n}' app.log # count ERROR lines
```

Expected output of the sum: `509560`. `END { }` runs once after the last line.
Variables like `sum` and `n` start at 0 automatically.

| Piece | Meaning |
|---|---|
| `$1 ... $NF` | fields; `$0` whole line |
| `NR` | current line number |
| `NF` | number of fields on this line |
| `-F:` | split on `:` instead of whitespace |
| `BEGIN {}` / `END {}` | run before the first / after the last line |
| `==`, `!=`, `>`, `~ /re/` | compare; `~` matches a regex |

```bash
awk '$7 ~ /^\/api/ {print $7}' access.log | sort -u   # paths starting with /api
```

## Try it

From `/etc/passwd` print the user name and home directory (fields 1 and 6) of
every user whose shell (field 7) is `/bin/bash`.

<details>
<summary>Show answer</summary>

```bash
awk -F: '$7 == "/bin/bash" {print $1, $6}' /etc/passwd
```

Strings in awk conditions need double quotes; the whole program sits in single
quotes.

</details>

## Common mistakes

- **Double quotes around the program.** `awk "{print $1}"` lets the shell
  replace `$1` first (usually with nothing). Always single-quote awk programs.
- **Forgetting `-F` for non-space data.** `/etc/passwd` and CSV need `-F:` or
  `-F,`.
- **Counting fields by eye.** Print `NF` or `$9` on one line first to check
  which number is which.
- **`=` instead of `==`.** `$9 = 500` assigns 500 to field 9 and is always true.

## Remember

- `awk 'COND {ACTION}' file`; fields are `$1..$NF`.
- Filter on one column and print another in one step.
- `-F` sets the separator; `END {}` prints totals.
- Single-quote the program, double-quote strings inside it.

**Self-check:**

1. What is `$NF`?
2. Write the awk condition for "field 9 is 404".
3. When does an `END` block run?
