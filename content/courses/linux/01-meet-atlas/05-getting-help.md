---
kind: lesson
id_key: linux/meet-atlas/getting-help
course: linux
section: meet-atlas
section_title: "Chapter 1: Meet Atlas - the Shell and the Map"
section_position: 1
title: "Getting Help Without Google: man, --help, type and which"
position: 4
estimated_minutes: 6
source:
  - man(1), man-pages(7), apropos(1), whatis(1), which(1) manual pages
  - GNU Bash Reference Manual, "type" and "help" builtins
---

## Why this matters

The server room has no internet, and at 2am nobody answers chat. Linux ships its
own documentation. Knowing how to ask atlas itself is faster than searching the
web, and the answer always matches the version actually installed.

## Mental model: three kinds of help

| Question | Ask |
|---|---|
| "Remind me of the options" | `command --help` (short summary) |
| "Explain it fully" | `man command` (the manual page) |
| "What *is* this word I typed?" | `type word`, `which word` |

Manual pages are split into numbered **sections**. You will use three:

- **1** user commands (`man 1 passwd`: the command)
- **5** file formats (`man 5 passwd`: the `/etc/passwd` file)
- **8** admin commands (`man 8 mount`)

## See it work

```bash
ls --help | head -5
```

What this does: prints the short usage text and keeps the first 5 lines.

```
Usage: ls [OPTION]... [FILE]...
List information about the FILEs (the current directory by default).
Sort entries alphabetically if none of -cftuvSUX nor --sort is specified.
...
```

```bash
man ls
```

This opens the manual in a pager. Keys inside it:

| Key | Action |
|---|---|
| Space / b | page down / up |
| `/word` then Enter | search; `n` next match |
| `q` | quit |

### What kind of command is it?

```bash
type cd
type ls
which grep
command -v grep
```

Expected output:

```
cd is a shell builtin
ls is aliased to `ls --color=auto'
/usr/bin/grep
/usr/bin/grep
```

- A **builtin** lives inside bash itself (`cd`, `export`, `echo`). It has no
  separate man page; use `help cd`.
- An **alias** is a shortcut defined in your shell.
- Everything else is a program file on disk; `which` and `command -v` show
  where.

### Finding a command you do not know

```bash
apropos compress     # search man page descriptions by keyword
whatis tar           # one-line description
```

```
tar (1)              - an archiving utility
```

If `man` says "No manual entry", the docs may not be installed (minimal images
strip them). `--help` usually still works.

## Try it

You want to know the format of the file `/etc/crontab`, not the `crontab`
command. Which man command do you run? And how do you check if `echo` is a
builtin?

<details>
<summary>Show answer</summary>

`man 5 crontab` opens the file-format section. `type echo` prints
`echo is a shell builtin`.

</details>

## Common mistakes

- **Reading `man` top to bottom.** Jump to EXAMPLES with `/EXAMPLES`. Most pages
  have one.
- **Running `man cd`.** Builtins are documented by `help cd` (or in `man bash`).
- **Trusting a blog over the local manual.** Options differ between GNU (Linux)
  and BSD (macOS) tools; the local `man` matches the machine you are on.

## Remember

- `--help` for a quick reminder, `man` for the full story, `q` to quit.
- Sections: 1 commands, 5 file formats, 8 admin commands.
- `type` tells you builtin / alias / file; `which` and `command -v` give the path.
- `apropos keyword` finds commands you do not know yet.

**Self-check:**

1. What is the difference between `man 1 passwd` and `man 5 passwd`?
2. How do you search inside a man page?
3. Why does `which cd` print nothing useful?
