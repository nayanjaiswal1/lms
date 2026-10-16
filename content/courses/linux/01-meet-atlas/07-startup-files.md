---
kind: lesson
id_key: linux/meet-atlas/startup-files
course: linux
section: meet-atlas
section_title: "Chapter 1: Meet Atlas - the Shell and the Map"
section_position: 1
title: "Making It Stick: .bashrc, .profile and Aliases"
position: 6
estimated_minutes: 6
source:
  - GNU Bash Reference Manual, "Bash Startup Files" and "Aliases"
---

## Why this matters

You set `PATH` and an alias, close the terminal, open a new one: everything is
gone. Settings typed at the prompt live only as long as that shell. Startup files
are how you make atlas remember you.

## Mental model: the barista's morning checklist

Every time bash starts, it reads a checklist file and runs each line, as if you
typed them. Which checklist depends on how the shell started:

```
 login shell (SSH login, console login)
   reads: /etc/profile, then ~/.profile (or ~/.bash_profile)
   Ubuntu's ~/.profile then also reads ~/.bashrc

 interactive non-login shell (a new terminal tab, typing `bash`)
   reads: /etc/bash.bashrc, then ~/.bashrc
```

| File | Runs when | Put here |
|---|---|---|
| `~/.bashrc` | every new interactive bash | aliases, prompt, PATH tweaks, umask |
| `~/.profile` / `~/.bash_profile` | login shells (once per login) | environment for the whole session |
| `/etc/profile`, `/etc/profile.d/*.sh` | login shells, every user | system-wide settings |
| `/etc/bash.bashrc` | interactive shells, every user | system-wide aliases |

Simple rule for this course: **put your settings in `~/.bashrc`.**

## See it work

An **alias** is a shortcut: one word that expands to a longer command.

```bash
alias ll='ls -alF'      # define it
ll /tmp                 # use it
alias                   # list all aliases
unalias ll              # remove it
```

To make settings permanent, append them to `~/.bashrc`:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
echo "alias ll='ls -alF'" >> ~/.bashrc
source ~/.bashrc
```

What this does: `>>` appends a line to the end of the file (never use a single
`>` here; it would wipe the file). `source` re-reads the file in the current
shell so you do not need a new terminal. Check it:

```bash
tail -2 ~/.bashrc
type ll
```

```
export PATH="$HOME/bin:$PATH"
alias ll='ls -alF'
ll is aliased to `ls -alF'
```

### Your own commands

Any executable file in a PATH directory is a command. Put scripts in `~/bin`:

```bash
mkdir -p ~/bin
printf '#!/bin/bash\necho "Atlas online"\n' > ~/bin/hello-atlas
chmod +x ~/bin/hello-atlas
cd /tmp && hello-atlas
```

```
Atlas online
```

The first line `#!/bin/bash` (the **shebang**) tells the kernel to run the file
with bash. `chmod +x` makes it executable. Chapter 9 covers scripts properly.

## Try it

You added `alias atlas='cd ~/work/atlas'` to `~/.bashrc`, but in your current
terminal `atlas` says command not found. Why, and what are two ways to fix it?

<details>
<summary>Show answer</summary>

The current shell read `~/.bashrc` when it started, before you added the line.
Either run `source ~/.bashrc` or open a new shell (`bash`, or a new terminal).

</details>

## Common mistakes

- **Using `>` instead of `>>`.** `echo ... > ~/.bashrc` replaces the whole file.
  Keep a backup: `cp ~/.bashrc ~/.bashrc.bak` before editing.
- **Putting settings in the wrong file.** If something works in a new tab but not
  after SSH login (or the reverse), check which startup file each shell reads.
- **Breaking `.bashrc` with a syntax error.** Every new shell prints errors. Fix
  with `nano ~/.bashrc` and test with `bash -n ~/.bashrc` (syntax check only).
- **Aliases in scripts.** Scripts do not expand aliases by default. Use
  functions or full commands in scripts.

## Remember

- Typed settings die with the shell; startup files bring them back.
- `~/.bashrc` runs for every interactive bash; `~/.profile` for logins.
- Append with `>>`, reload with `source ~/.bashrc`.
- An executable file in `~/bin` (on PATH) is your own command.

**Self-check:**

1. Which file holds your aliases?
2. What does `source ~/.bashrc` do?
3. What three things make `hello-atlas` work as a command from any directory?
