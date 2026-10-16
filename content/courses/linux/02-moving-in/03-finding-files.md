---
kind: lesson
id_key: linux/moving-in/finding-files
course: linux
section: moving-in
section_title: "Chapter 2: Moving In - Working with Files"
section_position: 2
title: "Finding Files with find (and locate)"
position: 2
estimated_minutes: 8
source:
  - find(1), locate(1), updatedb(8), xargs(1) manual pages
---

## Why this matters

Tom left `.bak` files in five different folders. Next week a disk fills up and
you need every file over 1 GB. `find` walks a whole directory tree and can act on
what it finds. It is one of the most used admin commands.

## Mental model: WHERE, WHAT, DO

```
 find  /var/log   -name "*.log" -mtime +7   -delete
       \______/   \___________________/    \_____/
        WHERE            WHAT                 DO
   (start here)  (tests, all must match)  (action, default: print)
```

> **Memory hook:** `find WHERE WHAT DO`. Always run it once **without** the DO
> part, read the list, then add the action.

## See it work

```bash
find ~/work/moving -name "*.bak"
```

What this does: walks every directory below `~/work/moving` and prints paths
whose name ends in `.bak`. Expected output (the order may differ; `find` lists
in directory order, not alphabetically):

```
/home/labuser/work/moving/box/old/menu-2019.bak
/home/labuser/work/moving/box/old/prices.bak
/home/labuser/work/moving/box/recipes/mocha.bak
/home/labuser/work/moving/garage/spare.bak
```

Quote the pattern. Without quotes, bash would expand `*.bak` against the current
directory first, and `find` would get the wrong name.

### Common tests

```bash
find . -iname "readme*"          # name, case-insensitive
find . -type f                   # regular files only
find . -type d -name config      # directories named config
find / -size +100M 2>/dev/null   # bigger than 100 MiB (2>/dev/null hides "Permission denied")
find . -mtime -1                 # modified less than 1 day ago
find . -mtime +30                # modified more than 30 days ago
find . -user labuser             # owned by labuser
find . -perm -o+w                # writable by others (chapter 12)
find . -name "*.tmp" -o -name "*.bak"   # OR between tests
```

Size units: `k`, `M`, `G`. `+` means more than, `-` means less than.

### Actions

```bash
find . -name "*.bak" -delete                 # delete each match
find . -name "*.sh" -exec chmod +x {} \;     # run a command per file
find . -name "*.log" -exec gzip {} +         # one command, many files (faster)
```

In `-exec`, `{}` is replaced by the file name. `\;` ends the command (one run
per file); `+` packs many files into one run.

You will also see `find ... | xargs cmd`. `xargs` turns lines of input into
arguments. Use `find ... -print0 | xargs -0 cmd` so names with spaces survive.

### locate: the fast index

```bash
locate nginx.conf       # searches a prebuilt database, instant
sudo updatedb           # refresh the database (runs daily via a timer)
```

`locate` is fast but can be out of date and is not installed everywhere.
`find` always sees the current truth.

## Try it

Write one command that lists all regular files bigger than 1 MiB under
`~/work/moving`. Then turn it into a command that deletes every `.bak` file under
`~/work/moving`, but describe what you run first.

<details>
<summary>Show answer</summary>

```bash
find ~/work/moving -type f -size +1M
find ~/work/moving -name '*.bak'           # preview first
find ~/work/moving -name '*.bak' -delete   # then delete
```

</details>

## Common mistakes

- **Putting `-delete` first.** `find . -delete -name '*.bak'` deletes everything:
  actions run in order, before the name test is applied. Tests first, action
  last.
- **Unquoted patterns.** `find . -name *.log` works only by luck. Quote it.
- **Searching `/` and drowning in errors.** Add `2>/dev/null`, or limit the
  search with `-xdev` (stay on one filesystem).
- **Trusting `locate` for new files.** It only knows what was there at the last
  `updatedb`.

## Remember

- `find WHERE TESTS ACTION`; preview, then act.
- Tests: `-name`, `-iname`, `-type`, `-size`, `-mtime`, `-user`, `-perm`.
- Actions: `-delete`, `-exec cmd {} \;` or `+`.
- `locate` is a fast but possibly stale index.

**Self-check:**

1. What does `-mtime +30` mean?
2. Why should the pattern after `-name` be quoted?
3. What is the difference between `-exec ... \;` and `-exec ... +`?
