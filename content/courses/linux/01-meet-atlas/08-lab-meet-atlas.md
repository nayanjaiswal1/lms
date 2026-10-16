---
kind: lesson
id_key: linux/meet-atlas/lesson
course: linux
section: meet-atlas
section_title: "Chapter 1: Meet Atlas - the Shell and the Map"
section_position: 1
title: "Lab: Find Tom's Note and Make Atlas Yours"
position: 7
estimated_minutes: 25
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

## Why this matters

You have read how the shell, the filesystem map and PATH work. Now use them on a
real machine. Tom left a hidden note on atlas, and by the end of this lab atlas
will know your name and run a command you wrote. Each task is checked
automatically.

## Before you start

Your lab copy of atlas lives under `~/work/atlas`. Look around first:

```bash
cd ~/work/atlas
ls
```

Expected output:

```
etc  home  srv  var
```

The same map as a real server, in miniature.

## Task 1: ask atlas who it is

Create the directory `~/work/answers`, then save the running kernel release into
`answers/kernel.txt`. `uname -r` prints it; `>` sends a command's output into a
file instead of the screen (lesson 1 and chapter 3 cover this).

[[lab-task:1]]

Check yourself: `cat ~/work/answers/kernel.txt` shows one line like
`6.8.0-45-generic`.

## Task 2: find where the shell lives

Commands are files on disk. Save the full path of the `bash` program into
`answers/bash-path.txt`. Lesson 5 showed two commands that print it.

[[lab-task:2]]

## Task 3: find Tom's hidden note

Tom's note is somewhere under `~/work/atlas`. Plain `ls` will not show it: Tom
liked names that start with a dot. Save only the codeword (one word, capital
letters) into `answers/codeword.txt`.

[[lab-task:3]]

What you should see when you find the hidden folder:

```
$ ls -la var/log/old
drwxr-xr-x 3 labuser labuser 4096 ... .
drwxr-xr-x 3 labuser labuser 4096 ... ..
drwxr-xr-x 2 labuser labuser 4096 ... .archive
-rw-r--r-- 1 labuser labuser   25 ... notes.txt
```

## Task 4: make atlas remember you

In `~/.bashrc`, export `ATLAS_ROLE=apprentice` and define an alias `atlas` that
runs `cd /home/labuser/work/atlas`. Use `>>` so you append, then
`source ~/.bashrc` to try it.

[[lab-task:4]]

## Task 5: teach atlas a new command

Create the script `~/bin/hello-atlas` that prints exactly `Atlas online`, make
it executable, and add `~/bin` to your PATH in `~/.bashrc`.

[[lab-task:5]]

What you should see:

```
$ cd /tmp && hello-atlas
Atlas online
```

## Remember

- `uname -r` = kernel release; `command -v` = where a program lives.
- Hidden files start with a dot; `ls -a` and `find` reveal them.
- `~/.bashrc` makes exports, aliases and PATH changes permanent.
- An executable file in a PATH directory is a command.

> **End of day 1.** Tom's note said RISTRETTO, and below it, in small letters:
> "Tomorrow, unpack the boxes."
