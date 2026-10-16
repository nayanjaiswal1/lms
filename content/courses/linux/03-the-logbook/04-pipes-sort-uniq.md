---
kind: lesson
id_key: linux/the-logbook/pipes-sort-uniq
course: linux
section: the-logbook
section_title: "Chapter 3: The Logbook - Text Tools and Pipes"
section_position: 3
title: "Pipes: cut, sort, uniq, tr and the Top-N Pipeline"
position: 3
estimated_minutes: 8
source:
  - GNU Bash Reference Manual, "Pipelines"
  - cut(1), sort(1), uniq(1), tr(1), xargs(1) manual pages
---

## Why this matters

"Which IP is hammering the shop?" "Which status codes are we returning?"
Answering these in one line, with small tools chained together, is the moment
Linux starts feeling like a superpower.

## Mental model: a coffee filter chain

The pipe `|` connects stdout of one command to stdin of the next. Each stage
takes what drips from the stage above and passes on something smaller.

```
 awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -3
      just the IPs           -> grouped -> counted -> biggest first -> top 3
```

> **Memory hook:** a pipe is a **coffee filter chain**. Small tools, each doing
> one thing, chained together.

## See it work

### cut: slice columns

```bash
cut -d' ' -f1 ~/work/logbook/access.log | head -2   # field 1, space-separated
cut -d: -f1,7 /etc/passwd | tail -2                 # fields 1 and 7, colon-separated
```

```
10.0.0.7
192.168.1.20
postgres:/bin/bash
labuser:/bin/bash
```

`-d` sets the delimiter (one character), `-f` picks fields. `cut -c1-10` takes
characters instead.

### sort and uniq: group and count

```bash
cd ~/work/logbook
awk '{print $1}' access.log | sort | uniq -c | sort -rn
```

What this does: extract the IP (field 1), sort so equal IPs are next to each
other, count each group, sort by count numerically in reverse. Expected output:

```
     95 192.168.1.20
     60 172.16.0.9
     60 10.0.0.7
     60 10.0.0.5
```

`uniq` only merges **adjacent** duplicate lines. That is why `sort` must come
first.

| Command | Does |
|---|---|
| `sort` | alphabetical |
| `sort -n` / `-h` | numeric / human sizes (2K, 1M) |
| `sort -r` | reverse |
| `sort -k2 -t,` | by field 2, comma-separated |
| `sort -u` | sort and drop duplicates |
| `uniq -c` | count adjacent duplicates |
| `uniq -d` | show only duplicated lines |

### tr: translate characters

```bash
echo "orbit coffee" | tr 'a-z' 'A-Z'     # ORBIT COFFEE
tr -d '\r' < win.txt > unix.txt          # remove Windows carriage returns
echo "a  b   c" | tr -s ' '              # squeeze repeated spaces: a b c
```

### xargs: turn lines into arguments

Some commands do not read stdin; they want arguments. `xargs` bridges that.

```bash
find . -name '*.log' -print0 | xargs -0 gzip     # gzip every log found
cut -d' ' -f1 access.log | sort -u | xargs -n1 echo checking
```

`-print0` and `-0` use a NUL byte between names, so names with spaces survive.

### The top-N pattern

Memorise this shape; you will use it for IPs, URLs, users, error types:

```
 <extract one field> | sort | uniq -c | sort -rn | head
```

```bash
awk '{print $9}' access.log | sort | uniq -c | sort -rn    # status code mix
```

```
    243 200
     18 404
     14 500
```

## Try it

Using `cut`, list each distinct IP in `access.log` once, sorted. Then: why does
`uniq -c access.log` without `sort` give wrong counts?

<details>
<summary>Show answer</summary>

```bash
cut -d' ' -f1 access.log | sort -u
```

```
10.0.0.5
10.0.0.7
172.16.0.9
192.168.1.20
```

`uniq` compares each line only with the line right before it. Without `sort`,
the same IP appears in many separate runs and each run is counted separately.

</details>

## Common mistakes

- **`uniq` without `sort`.** Counts are split into many small groups.
- **`sort` on numbers without `-n`.** Alphabetically, `100` comes before `9`.
- **`cut -d' '` on text with multiple spaces.** Each space is a separator, so
  fields shift. Use `awk` (next lesson), which splits on runs of whitespace.
- **Very long pipelines nobody can read.** Build them one stage at a time, and
  check the output of each stage with `| head`.

## Remember

- `|` sends stdout of the left command to stdin of the right one.
- `cut -d -f` slices fields; `tr` translates characters; `xargs` makes
  arguments.
- `sort | uniq -c | sort -rn | head` is the top-N pipeline.
- Build pipelines stage by stage.

**Self-check:**

1. Why must `sort` come before `uniq -c`?
2. Which `sort` options give biggest number first?
3. What problem does `-print0 | xargs -0` solve?
