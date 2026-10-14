---
kind: lesson
id_key: linux/meet-atlas/lesson
course: linux
section: meet-atlas
section_title: "Chapter 1: Meet Atlas"
section_position: 1
title: Linux, the Shell and the Filesystem Map
position: 0
estimated_minutes: 45
source:
  - Filesystem Hierarchy Standard 3.0 (refspecs.linuxfoundation.org/fhs.shtml)
  - bash(1), man(1), hier(7) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 45
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    w=/home/labuser/work
    rm -rf $w/atlas $w/answers
    mkdir -p $w/atlas/etc/brewbot $w/atlas/var/log/old/.archive $w/atlas/home/tom $w/atlas/srv/brewbot
    echo "port = 8080" > $w/atlas/etc/brewbot/brewbot.conf
    echo "Welcome to atlas. Look deeper - and look for what is hidden." > $w/atlas/home/tom/README
    echo "nothing here, keep going" > $w/atlas/var/log/old/notes.txt
    echo "If you found this, the codeword is RISTRETTO" > $w/atlas/var/log/old/.archive/.tom-note
  tasks:
    - id_key: kernel-version
      title: Ask atlas who it is
      points: 10
      is_stateful: true
      description: Create the directory /home/labuser/work/answers, then save the running kernel release (the output of uname -r) into answers/kernel.txt.
      verification_script: |
        f=/home/labuser/work/answers/kernel.txt
        [ -f $f ] && [ "$(tr -d '[:space:]' < $f)" = "$(uname -r)" ]
      hint_context: uname prints kernel information; -r is the release. Redirect its output with > into the file. mkdir creates the answers directory first.
      explanation_context: The kernel is the core of Linux. uname -r asks the running kernel for its release string; > redirects a command's output into a file instead of the screen.
      solution_script: |
        mkdir -p /home/labuser/work/answers
        uname -r > /home/labuser/work/answers/kernel.txt
    - id_key: find-bash
      title: Find where the shell lives
      points: 10
      is_stateful: true
      description: Save the full path of the bash program into answers/bash-path.txt.
      verification_script: |
        p=$(tr -d '[:space:]' < /home/labuser/work/answers/bash-path.txt)
        [ -x "$p" ] && [ "$(basename "$p")" = bash ]
      hint_context: command -v bash (or which bash) prints the path of the program bash runs when you type its name.
      explanation_context: Commands are just programs on disk. The shell searches each directory in PATH and runs the first match; which and command -v show you where that match is.
      solution_script: |
        command -v bash > /home/labuser/work/answers/bash-path.txt
    - id_key: hidden-note
      title: Find Tom's hidden note
      points: 20
      is_stateful: true
      description: The old admin, Tom, hid a note somewhere under /home/labuser/work/atlas. Find it and save only the codeword (one word, capital letters) into answers/codeword.txt.
      verification_script: |
        [ "$(tr -d '[:space:]' < /home/labuser/work/answers/codeword.txt)" = RISTRETTO ]
      hint_context: Files and directories whose names start with a dot are hidden from plain ls. Use ls -la in each directory, or find /home/labuser/work/atlas -name '.*'.
      explanation_context: A leading dot is the only thing that makes a file hidden in Linux - it is a naming convention, not a permission. ls -a and find show them.
      solution_script: |
        echo RISTRETTO > /home/labuser/work/answers/codeword.txt
    - id_key: env-and-alias
      title: Make atlas remember you
      points: 20
      is_stateful: true
      description: In ~/.bashrc, export the variable ATLAS_ROLE with the value apprentice, and define an alias called atlas that runs cd /home/labuser/work/atlas. Open a new shell (or run source ~/.bashrc) to try it.
      verification_script: |
        [ "$(bash -ic 'echo $ATLAS_ROLE' 2>/dev/null)" = apprentice ] &&
        bash -ic 'alias atlas' 2>/dev/null | grep -q 'cd /home/labuser/work/atlas'
      hint_context: Add two lines to the end of ~/.bashrc - export ATLAS_ROLE=apprentice and alias atlas='cd /home/labuser/work/atlas'. echo 'line' >> ~/.bashrc appends without overwriting.
      explanation_context: Variables set in a terminal vanish when it closes. ~/.bashrc runs at the start of every interactive Bash shell, so exports and aliases placed there come back every time.
      solution_script: |
        echo 'export ATLAS_ROLE=apprentice' >> ~/.bashrc
        echo "alias atlas='cd /home/labuser/work/atlas'" >> ~/.bashrc
    - id_key: own-command
      title: Teach atlas a new command
      points: 20
      is_stateful: true
      description: Create the script ~/bin/hello-atlas that prints exactly "Atlas online", make it executable, and add ~/bin to your PATH in ~/.bashrc so typing hello-atlas from any directory works.
      verification_script: |
        [ "$(bash -ic 'cd /tmp && hello-atlas' 2>/dev/null)" = "Atlas online" ]
      hint_context: >-
        The script needs a first line #!/bin/bash and a line echo "Atlas online". chmod +x makes it runnable.
        export PATH="$HOME/bin:$PATH" in ~/.bashrc puts the directory on the search path.
      explanation_context: A command is any executable file in a PATH directory. Prepending ~/bin to PATH makes your own scripts behave exactly like system commands.
      solution_script: |
        mkdir -p ~/bin
        printf '#!/bin/bash\necho "Atlas online"\n' > ~/bin/hello-atlas
        chmod +x ~/bin/hello-atlas
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
---

> **Monday, 9:00.** You are the new junior sysadmin at **Orbit Coffee**, a small roastery that sells beans online. Rhea, the ops lead, slides a laptop across the desk: "Everything we sell runs on one Linux server called **atlas**. Our old admin, Tom, left last month. He hid notes all over the box. Find them, learn atlas, and by Friday you're on call." This course follows your first weeks on atlas - every chapter is one day of the story, and every lab happens on a real Linux machine.

## What Linux actually is

Think of atlas as a coffee shop:

```
 +------------------------------------------------+
 |  YOU (customers)        type commands          |
 +------------------------------------------------+
 |  SHELL (the barista)    bash reads & runs them |
 +------------------------------------------------+
 |  PROGRAMS (the tools)   ls, grep, nginx, ...   |
 +------------------------------------------------+
 |  KERNEL (the kitchen)   CPU, memory, disks,    |
 |                         network, processes     |
 +------------------------------------------------+
 |  HARDWARE (the building)                       |
 +------------------------------------------------+
```

- **Kernel** - the core. It shares the CPU between programs, hands out memory, talks to disks and the network. "Linux" strictly means this kernel.
- **Distribution (distro)** - kernel + tools + package manager, bundled: Ubuntu, Debian, Fedora, RHEL, Alpine, Arch. Atlas runs Ubuntu.
- **Shell** - the program that reads what you type and asks the kernel to run it. On most systems that is **bash**.
- **Terminal** - the window the shell lives in.

The prompt tells you who and where you are:

```
labuser@atlas:~/work$
   |      |     |   |
  user  host  where  $ = normal user   (# = root, the superuser)
```

> **Memory hook:** *Kernel = kitchen, Shell = barista.* You never walk into the kitchen; you ask the barista.

```bash
uname -r        # kernel release
uname -a        # everything about the kernel
cat /etc/os-release   # which distro
whoami          # which user you are
hostname        # machine name
```

[[lab-task:1]]

## The filesystem map

Linux has **one tree**, starting at `/` (root). There are no drive letters - a second disk is just *mounted* somewhere inside the tree. Tom's first note on the wall said "learn the map before you touch anything":

```
/                       the root of everything
|-- bin  -> usr/bin     essential commands (ls, cp, bash)
|-- sbin -> usr/sbin    system admin commands (fdisk, reboot)
|-- etc                 configuration files (text!)
|-- home                users' personal folders  (/home/labuser)
|-- root                the root user's home
|-- var                 data that changes: logs, caches, mail, DBs
|   `-- log             <- you will live here during incidents
|-- tmp                 temporary files, wiped on reboot
|-- usr                 installed programs and libraries
|-- opt                 optional third-party software
|-- srv                 data served by this machine (websites)
|-- dev                 devices as files (disks: /dev/sda)
|-- proc                live view of processes and the kernel
|-- sys                 live view of hardware/drivers
|-- mnt, media          mount points for extra disks / USB
`-- boot                kernel and bootloader files
```

> **Memory hook - the coffee shop map:**
> `/etc` = the **E**ditable **T**ext **C**onfig (the recipe binder) · `/var` = **VAR**ies (the till receipts - logs) · `/home` = staff lockers · `/tmp` = the counter, wiped every night · `/usr` = the equipment · `/proc` = the live order screen · `/dev` = the machines themselves.

"**Everything is a file**" is the Linux motto: your disk is `/dev/sda`, a running process is a folder in `/proc`, and config is plain text in `/etc`.

```bash
ls /             # see the map
cat /proc/cpuinfo | head     # the kernel shows CPU info as a "file"
ls /var/log      # where logs live
```

[[lab-task:2]]

## Moving around: pwd, ls, cd

```bash
pwd                     # print working directory - "where am I?"
ls                      # list
ls -l                   # long: permissions, owner, size, date
ls -la                  # long + all, including hidden dot-files
ls -lh                  # human sizes (4.0K, 12M)
cd /var/log             # absolute path: starts at /
cd ../..                # relative path: .. is the parent
cd ~   (or just cd)     # home
cd -                    # back to the previous directory
```

```
 absolute: /home/labuser/work/atlas      always starts with /
 relative: work/atlas                    starts from where you are
 .  = this directory      .. = parent      ~ = your home
```

A file whose name starts with `.` is **hidden** - `ls` skips it, `ls -a` shows it. That is just a naming convention, not security. Tom loved hiding things this way.

Press **Tab** to autocomplete names, and **Up arrow** for previous commands. `history` lists them; `Ctrl+R` searches them; `Ctrl+C` stops a running command; `Ctrl+L` clears the screen.

[[lab-task:3]]

What you should see when you find the hidden folder:

```
$ ls -la var/log/old
drwxr-xr-x 3 labuser labuser 4096 ... .
drwxr-xr-x 3 labuser labuser 4096 ... ..
drwxr-xr-x 2 labuser labuser 4096 ... .archive
-rw-r--r-- 1 labuser labuser   25 ... notes.txt
```

## Getting help without Google

Atlas has no internet in the server room, so learn to ask atlas itself:

| Command | Answers |
|---|---|
| `man ls` | The full manual page (`q` quits, `/word` searches) |
| `ls --help` | Short usage summary |
| `type cd` | Is it a builtin, alias, or program? |
| `which grep` / `command -v grep` | Where the program is on disk |
| `whatis tar` | One-line description |
| `apropos copy` | Find commands by keyword |

Manual sections worth knowing: **1** user commands, **5** file formats (`man 5 passwd`), **8** admin commands.

## The shell's memory: variables, PATH, aliases

```bash
NAME=atlas              # shell variable (no spaces around =)
echo $NAME
export ROLE=apprentice  # environment variable: inherited by programs you start
env | grep ROLE         # list environment variables
echo $HOME $USER $SHELL
echo $PATH              # where the shell looks for commands
```

`PATH` is a colon-separated list of directories. When you type `grep`, bash checks each directory in order and runs the first `grep` it finds:

```
PATH=/home/labuser/bin:/usr/local/bin:/usr/bin:/bin
         1st                2nd          3rd     4th
```

Everything you set in a terminal dies when it closes. To make it permanent, put it in a startup file:

| File | Runs when |
|---|---|
| `~/.bashrc` | every new interactive bash shell (aliases, PATH tweaks) |
| `~/.profile` / `~/.bash_profile` | login shells (once per login) |
| `/etc/profile`, `/etc/bash.bashrc` | the same, for every user |

```bash
alias ll='ls -alF'      # shortcut
source ~/.bashrc        # reload without opening a new shell
```

[[lab-task:4]]

> **Memory hook:** a **PATH** is a *route the barista walks* to find a tool. Put your shelf (`~/bin`) first on the route and your tools win.

[[lab-task:5]]

What you should see:

```
$ cd /tmp && hello-atlas
Atlas online
```

> **End of day 1.** Tom's note said RISTRETTO, and below it, in small letters: "Tomorrow, unpack the boxes." Atlas now knows your name and runs your own command. Tomorrow: files.
