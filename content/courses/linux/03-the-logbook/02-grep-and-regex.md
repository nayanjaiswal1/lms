---
kind: lesson
id_key: linux/the-logbook/grep-and-regex
course: linux
section: the-logbook
section_title: "Chapter 3: The Logbook - Text Tools and Pipes"
section_position: 3
title: "grep: Finding the Needle, with a Little Regex"
position: 1
estimated_minutes: 8
source:
  - grep(1), regex(7) manual pages; GNU grep manual (gnu.org/software/grep/manual)
---

## Why this matters

`app.log` has 80 lines today and will have 8 million next year. The first
question in every incident is "show me only the lines that matter". `grep` does
exactly that, and it is the command you will type most often on a server.

## Mental model: a sieve

`grep PATTERN FILE` pours every line through a sieve. Lines that contain the
pattern fall through to your screen; the rest stay behind.

```
  80 lines  -->  [ grep ERROR ]  -->  16 lines that contain "ERROR"
```

Options change the sieve: count instead of print (`-c`), keep the *non*-matching
lines (`-v`), ignore case (`-i`).

## See it work

```bash
cd ~/work/logbook
grep ERROR app.log | head -3
```

What this does: prints lines containing `ERROR` (only the first 3 here).
Expected output:

```
2026-10-14 10:3:00 ERROR payment gateway timeout order=3
2026-10-14 10:10:00 ERROR payment gateway timeout order=10
2026-10-14 10:13:00 ERROR payment gateway timeout order=13
```

```bash
grep -c ERROR app.log       # count matching lines
grep -c WARN app.log
```

```
16
8
```

### The options you will use daily

```bash
grep -i error app.log           # ignore case: error, Error, ERROR
grep -v INFO app.log            # invert: lines WITHOUT INFO
grep -n timeout app.log         # prefix line numbers
grep -w port app.conf           # whole word: not "export" or "portal"
grep -r "port" /etc/brewbot/    # search every file in a directory tree
grep -l "port" /etc/*.conf      # list only file names that match
grep -E "ERROR|WARN" app.log    # extended regex: either word
grep -A2 -B1 ERROR app.log      # 2 lines After and 1 Before each match
grep -q ERROR app.log && echo found   # quiet: only the exit code (for scripts)
```

Context (`-A`, `-B`, `-C`) is gold in incidents: the line before an error often
says what caused it.

```bash
grep -n -B1 WARN app.log | head -2
```

```
4-2026-10-14 10:4:00 INFO login user=u4 password=s3cret4
5:2026-10-14 10:5:00 WARN slow query 1200ms order=5
```

With `-n`, matching lines use `:` after the number and context lines use `-`.

### Regex survival kit

A **regular expression (regex)** is a pattern language. Six symbols cover most
needs:

| Symbol | Means | Example | Matches |
|---|---|---|---|
| `^` | start of line | `^2026` | lines starting with 2026 |
| `$` | end of line | `order=3$` | lines ending in order=3 |
| `.` | any one character | `10.0` | 10.0, 1000, 10x0 |
| `*` | previous item 0+ times | `ab*c` | ac, abc, abbbc |
| `[...]` | one character from a set | `[0-9]` | one digit |
| `[^...]` | one character NOT in the set | `[^ ]*` | a run of non-spaces |

With `-E` (extended regex) you also get `+` (1 or more), `?` (0 or 1), `|` (or),
`()` (groups) and `{n}` (exactly n times).

```bash
grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3} ' access.log | head -1   # lines starting with an IPv4
grep -c ' 500 ' access.log                                     # status 500, surrounded by spaces
grep -F '[error]' nginx.log                                    # -F: fixed string, no regex at all
```

Always put patterns in **single quotes** so the shell does not touch `*`, `$` or
`|`.

## Try it

From `app.log`, count the lines that are either ERROR or WARN, and then print
every line that is *not* INFO, with line numbers.

<details>
<summary>Show answer</summary>

```bash
grep -cE 'ERROR|WARN' app.log     # 24
grep -nv INFO app.log
```

</details>

## Common mistakes

- **Unquoted patterns.** `grep ERROR|WARN app.log` makes the shell pipe into a
  command called `WARN`. Quote: `grep -E 'ERROR|WARN'`.
- **Forgetting that `.` is special.** `grep 10.0.0.5` also matches `10a0b0c5`.
  Use `grep -F 10.0.0.5` or escape the dots: `10\.0\.0\.5`.
- **`|` without `-E`.** Basic grep treats `|` as a literal character.
- **`cat file | grep x`.** Works, but `grep x file` is shorter and lets grep
  print file names.

## Remember

- `grep PATTERN FILE` prints matching lines; `-c` counts, `-v` inverts, `-i`
  ignores case, `-n` numbers, `-r` recurses.
- `-A/-B/-C` show context around matches.
- Regex basics: `^ $ . * [] [^]`; `-E` adds `+ ? | ()`.
- Single-quote every pattern; use `-F` for plain strings.

**Self-check:**

1. Which option prints the lines that do NOT match?
2. What does `^#` match?
3. Why does `grep 1.2.3.4` sometimes match lines without that IP?
