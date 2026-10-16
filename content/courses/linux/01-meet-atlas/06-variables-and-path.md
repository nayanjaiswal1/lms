---
kind: lesson
id_key: linux/meet-atlas/variables-and-path
course: linux
section: meet-atlas
section_title: "Chapter 1: Meet Atlas - the Shell and the Map"
section_position: 1
title: "Variables, the Environment and PATH"
position: 5
estimated_minutes: 8
source:
  - GNU Bash Reference Manual, "Shell Parameters" and "Environment"
  - environ(7) manual page
---

## Why this matters

The runbook says "type `brewctl status`" and bash answers `command not found`,
even though the file exists. The reason is almost always one variable: `PATH`.
Variables also carry settings like `HOME`, `USER` and app configuration into
every program you start.

## Mental model: sticky notes on the barista's desk

A **variable** is a named sticky note: `NAME=atlas`. There are two kinds:

- A **shell variable** stays on the barista's desk. Only this shell sees it.
- An **environment variable** is photocopied and handed to every program the
  shell starts. You create one with `export`.

```
  shell (bash)                     child program (python, brewbot)
  +-----------------+   starts    +-------------------------+
  | NAME=atlas      |  -------->  |  (does not see NAME)    |
  | export ROLE=dev |             |  ROLE=dev   <- copied   |
  +-----------------+             +-------------------------+
```

Copies go **down** only: a child can never change its parent's variables.

## See it work

```bash
NAME=atlas              # shell variable: no spaces around =
echo $NAME
export ROLE=apprentice  # environment variable
env | grep ROLE         # list the environment, keep ROLE
echo $HOME $USER $SHELL
```

What this does: sets two variables and prints them. Expected output:

```
atlas
ROLE=apprentice
/home/labuser labuser /bin/bash
```

`$NAME` means "the value of NAME". `env` prints only exported variables, which is
why `NAME` does not appear in it.

### PATH: where the shell looks for commands

`PATH` is a colon-separated list of directories. When you type `grep`, bash
checks each directory in order and runs the **first** `grep` it finds.

```bash
echo $PATH
```

```
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
     1st            2nd          3rd       4th ...
```

```
 you type: brewctl
 bash checks /usr/local/sbin/brewctl  no
             /usr/local/bin/brewctl   no
             /usr/sbin/brewctl        no
             ...                      no  ->  "brewctl: command not found"
```

To add your own directory for this shell:

```bash
export PATH="$HOME/bin:$PATH"     # prepend: your tools win
```

Notice `$PATH` inside the new value: you **extend** the list, you do not
replace it. The current directory (`.`) is deliberately not in PATH, which is
why you run local scripts as `./script.sh`.

> **Memory hook:** PATH is the **route the barista walks** to find a tool. Put
> your shelf (`~/bin`) first on the route and your tools win.

## Try it

You run `PATH=/home/labuser/bin` (no `$PATH`). What breaks immediately? How do
you get a working shell back?

<details>
<summary>Show answer</summary>

Every normal command (`ls`, `grep`, `cat`) now says `command not found`, because
bash only looks in `/home/labuser/bin`. Builtins like `cd` and `echo` still
work. Fix it by opening a new shell (the change only lived in this one), or type
`export PATH=/usr/local/bin:/usr/bin:/bin`.

</details>

## Common mistakes

- **Spaces around `=`.** `NAME = atlas` runs a command called `NAME`. Write
  `NAME=atlas`.
- **Overwriting PATH instead of extending it.** Always include `$PATH` in the
  new value.
- **Forgetting `export`.** A plain variable is invisible to programs you start,
  so `python app.py` will not see it.
- **Expecting a script to change your shell's variables.** A script runs as a
  child; its variables vanish when it ends. Use `source script.sh` to run it in
  the current shell instead.

## Remember

- `NAME=value` sets, `$NAME` reads, `export` passes it to child programs.
- `env` lists the environment; `echo $PATH` shows the command search route.
- Extend PATH with `export PATH="$HOME/bin:$PATH"`.
- `command not found` = no directory in PATH has that name.

**Self-check:**

1. What is the difference between `X=1` and `export X=1`?
2. In what order does bash search PATH?
3. Why do you type `./deploy.sh` and not just `deploy.sh`?
