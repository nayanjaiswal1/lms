---
kind: lesson
id_key: linux/the-logbook/cheatsheet
course: linux
section: the-logbook
section_title: "Chapter 3: The Logbook - Text Tools and Pipes"
section_position: 3
title: "Reference: Text Tools Cheat Sheet"
position: 7
estimated_minutes: 5
source:
  - grep(1), sed(1), awk(1), sort(1), uniq(1), cut(1), tr(1), xargs(1), diff(1), comm(1), column(1), jq(1) manual pages
---

## How to use this page

This is a reference, not a lesson. Skim it once, then come back when you need a
flag. Everything here was explained in lessons 1-6 of this chapter, except the
few extras marked **new**.

## Viewing

| Command | Does |
|---|---|
| `cat f` / `cat a b` | print / concatenate |
| `less f` | scroll; `/x` search, `n` next, `G` end, `F` follow, `q` quit |
| `head -n N f` / `tail -n N f` | first / last N lines |
| `tail -n +N f` | from line N to the end |
| `tail -f f` / `tail -F f` | follow; `-F` survives rotation |
| `wc -l` / `-w` / `-c` | lines / words / bytes |
| `nl f` (**new**) | print with line numbers |

## grep

| Option | Does |
|---|---|
| `-i` / `-v` / `-c` / `-n` | ignore case / invert / count / line numbers |
| `-w` / `-x` | whole word / whole line |
| `-r` / `-l` | recurse into directories / list file names only |
| `-E` / `-F` | extended regex / fixed string |
| `-A N` / `-B N` / `-C N` | context after / before / around |
| `-o` (**new**) | print only the matched part |
| `-q` | quiet, exit code only |

Regex: `^` start, `$` end, `.` any char, `*` 0+, `[...]` set, `[^...]` not in
set; with `-E`: `+` 1+, `?` 0-1, `|` or, `()` group, `{n,m}` repeat.

## Redirection and pipes

| Syntax | Does |
|---|---|
| `>` / `>>` | stdout to file, overwrite / append |
| `2>` / `2>>` | stderr to file |
| `> f 2>&1` / `&> f` | both streams |
| `2>/dev/null` | discard errors |
| `< f` | stdin from file |
| `<<'EOF' ... EOF` | here-document |
| `a \| b` | stdout of a into stdin of b |
| `\| tee f` / `\| tee -a f` | copy to file and pass on |
| `\| sudo tee f` | write a root-owned file |

## Slicing, sorting, counting

| Command | Does |
|---|---|
| `cut -d: -f1,7` / `cut -c1-10` | fields / characters |
| `sort` `-n` `-h` `-r` `-u` `-k2 -t,` | numeric, human, reverse, unique, by key |
| `uniq` `-c` `-d` | count / duplicates only (input must be sorted) |
| `tr 'a-z' 'A-Z'` / `tr -d '\r'` / `tr -s ' '` | translate / delete / squeeze |
| `xargs` / `xargs -0` / `xargs -n1` | lines to arguments / NUL-separated / one per call |
| `paste a b` (**new**) | join files side by side |
| `column -t` (**new**) | align columns into a table |
| `comm -12 a b` (**new**) | lines common to two sorted files |

Top-N: `<extract> | sort | uniq -c | sort -rn | head`

## awk

| Piece | Does |
|---|---|
| `awk '{print $1, $NF}'` | first and last field |
| `awk '$9 == 500'` | filter rows |
| `awk -F: '...'` | custom separator |
| `awk '{s += $10} END {print s}'` | sum a column |
| `awk 'NR==10'` / `NF` | line 10 / number of fields |
| `awk '$7 ~ /^\/api/'` | regex match on a field |
| `awk '{c[$1]++} END {for (k in c) print c[k], k}'` (**new**) | count per key without sort |

## sed

| Command | Does |
|---|---|
| `sed 's/a/b/'` / `'s/a/b/g'` | replace first / all on each line |
| `sed -n '10,20p'` | print a range |
| `sed '/re/d'` | delete matching lines |
| `sed -i.bak '...' f` | edit in place, keep backup |
| `sed 's\|/a\|/b\|g'` | other delimiter for paths |

## Comparing

| Command | Does |
|---|---|
| `diff a b` / `diff -u a b` | line differences / unified format |
| `cmp a b` | first differing byte (binary) |
| `sha256sum f` (**new**) | checksum: same hash = same content |

## JSON (new)

```bash
curl -s URL | jq .                 # pretty-print
jq -r '.version' status.json       # one field, raw text
jq -r '.items[] | .name' list.json # every name in an array
```

`jq` is to JSON what `awk` is to columns. Chapter 8 uses it with `curl`.
