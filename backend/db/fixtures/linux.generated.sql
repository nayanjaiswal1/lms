-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-10-15T08:26:00Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Linux: The Atlas Story ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, is_public, estimated_hours)
VALUES ('ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Linux: The Atlas Story', 'linux', 'Learn Linux by living it. You join Orbit Coffee as the new junior sysadmin and inherit "atlas", the server that runs the whole shop. Across ten story chapters you learn the filesystem, files and links, text tools and pipes, users and permissions, processes and signals, systemd, logs and cron, packages, disks and archives, networking and SSH, and Bash scripting. Every chapter has one hands-on terminal lab, and the last chapter is Incident Week: real outage scenarios you diagnose and fix yourself. One final exam closes the course.', '/course-covers/linux.svg', 'beginner', ARRAY['linux','bash','sysadmin','devops','cli'], 'published', true, false, 8.8)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, is_public=EXCLUDED.is_public, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

UPDATE course_sections SET position = position + 100000 WHERE course_id = 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf';
UPDATE course_modules SET position = position + 100000 WHERE course_id = 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf';

-- Section: Chapter 1: Meet Atlas
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('4078896b-224c-5318-8a4a-c389cca4bece', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 1: Meet Atlas', 1, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a50e29c4-cd7e-5b52-bfea-bf5cd4825d59', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '4078896b-224c-5318-8a4a-c389cca4bece', 'Linux, the Shell and the Filesystem Map', 'notes', 0, $md$> **Monday, 9:00.** You are the new junior sysadmin at **Orbit Coffee**, a small roastery that sells beans online. Rhea, the ops lead, slides a laptop across the desk: "Everything we sell runs on one Linux server called **atlas**. Our old admin, Tom, left last month. He hid notes all over the box. Find them, learn atlas, and by Friday you're on call." This course follows your first weeks on atlas - every chapter is one day of the story, and every lab happens on a real Linux machine.

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
$md$, 45, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('eb18d200-624b-53e4-8ac5-751d4dda5229', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'a50e29c4-cd7e-5b52-bfea-bf5cd4825d59', 'module', 'Linux, the Shell and the Filesystem Map', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
rm -rf $w/atlas $w/answers
mkdir -p $w/atlas/etc/brewbot $w/atlas/var/log/old/.archive $w/atlas/home/tom $w/atlas/srv/brewbot
echo "port = 8080" > $w/atlas/etc/brewbot/brewbot.conf
echo "Welcome to atlas. Look deeper - and look for what is hidden." > $w/atlas/home/tom/README
echo "nothing here, keep going" > $w/atlas/var/log/old/notes.txt
echo "If you found this, the codeword is RISTRETTO" > $w/atlas/var/log/old/.archive/.tom-note
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed' AND id NOT IN ('7f67d19f-8874-5b63-b5b3-69094b1e3f39', '72c12f27-ba4c-52db-8688-8ec19b822c56', 'cda34423-ecc5-57cd-9e5f-6a58c06c841b', '57304ba3-0462-5bfe-83a5-046b0035ad08', 'cb03a349-1803-5ef9-bbda-7b8dfdcd16bc');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed';
DELETE FROM lab_tasks WHERE lab_id = 'eb18d200-624b-53e4-8ac5-751d4dda5229' AND id NOT IN ('e99a9388-6e2f-5e67-8b42-e5ead23e4c27', 'fbf1cc53-b9a5-57e4-8b18-77cadbf1620d', 'fb16e9f8-d8da-5149-a377-cd78f3dd4304', '9c2e5b47-866e-50c0-a07a-34182ef6ef18', 'bcef36e7-8285-5295-8769-312665efb73a');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'eb18d200-624b-53e4-8ac5-751d4dda5229';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('e99a9388-6e2f-5e67-8b42-e5ead23e4c27', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 1, 'Ask atlas who it is', $md$Create the directory /home/labuser/work/answers, then save the running kernel release (the output of uname -r) into answers/kernel.txt.$md$, $script$f=/home/labuser/work/answers/kernel.txt
[ -f $f ] && [ "$(tr -d '[:space:]' < $f)" = "$(uname -r)" ]
$script$, 'uname prints kernel information; -r is the release. Redirect its output with > into the file. mkdir creates the answers directory first.', 'The kernel is the core of Linux. uname -r asks the running kernel for its release string; > redirects a command''s output into a file instead of the screen.', 10, false, true),
('fbf1cc53-b9a5-57e4-8b18-77cadbf1620d', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 2, 'Find where the shell lives', $md$Save the full path of the bash program into answers/bash-path.txt.$md$, $script$p=$(tr -d '[:space:]' < /home/labuser/work/answers/bash-path.txt)
[ -x "$p" ] && [ "$(basename "$p")" = bash ]
$script$, 'command -v bash (or which bash) prints the path of the program bash runs when you type its name.', 'Commands are just programs on disk. The shell searches each directory in PATH and runs the first match; which and command -v show you where that match is.', 10, false, true),
('fb16e9f8-d8da-5149-a377-cd78f3dd4304', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 3, 'Find Tom''s hidden note', $md$The old admin, Tom, hid a note somewhere under /home/labuser/work/atlas. Find it and save only the codeword (one word, capital letters) into answers/codeword.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/codeword.txt)" = RISTRETTO ]
$script$, 'Files and directories whose names start with a dot are hidden from plain ls. Use ls -la in each directory, or find /home/labuser/work/atlas -name ''.*''.', 'A leading dot is the only thing that makes a file hidden in Linux - it is a naming convention, not a permission. ls -a and find show them.', 20, false, true),
('9c2e5b47-866e-50c0-a07a-34182ef6ef18', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 4, 'Make atlas remember you', $md$In ~/.bashrc, export the variable ATLAS_ROLE with the value apprentice, and define an alias called atlas that runs cd /home/labuser/work/atlas. Open a new shell (or run source ~/.bashrc) to try it.$md$, $script$[ "$(bash -ic 'echo $ATLAS_ROLE' 2>/dev/null)" = apprentice ] &&
bash -ic 'alias atlas' 2>/dev/null | grep -q 'cd /home/labuser/work/atlas'
$script$, 'Add two lines to the end of ~/.bashrc - export ATLAS_ROLE=apprentice and alias atlas=''cd /home/labuser/work/atlas''. echo ''line'' >> ~/.bashrc appends without overwriting.', 'Variables set in a terminal vanish when it closes. ~/.bashrc runs at the start of every interactive Bash shell, so exports and aliases placed there come back every time.', 20, false, true),
('bcef36e7-8285-5295-8769-312665efb73a', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 5, 'Teach atlas a new command', $md$Create the script ~/bin/hello-atlas that prints exactly "Atlas online", make it executable, and add ~/bin to your PATH in ~/.bashrc so typing hello-atlas from any directory works.$md$, $script$[ "$(bash -ic 'cd /tmp && hello-atlas' 2>/dev/null)" = "Atlas online" ]
$script$, 'The script needs a first line #!/bin/bash and a line echo "Atlas online". chmod +x makes it runnable. export PATH="$HOME/bin:$PATH" in ~/.bashrc puts the directory on the search path.', 'A command is any executable file in a PATH directory. Prepending ~/bin to PATH makes your own scripts behave exactly like system commands.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', 'eb18d200-624b-53e4-8ac5-751d4dda5229', 1, $json$[{"id":"e99a9388-6e2f-5e67-8b42-e5ead23e4c27","lab_id":"eb18d200-624b-53e4-8ac5-751d4dda5229","position":1,"title":"Ask atlas who it is","description":"Create the directory /home/labuser/work/answers, then save the running kernel release (the output of uname -r) into answers/kernel.txt.","verification_script":"f=/home/labuser/work/answers/kernel.txt\n[ -f $f ] \u0026\u0026 [ \"$(tr -d '[:space:]' \u003c $f)\" = \"$(uname -r)\" ]\n","hint_context":"uname prints kernel information; -r is the release. Redirect its output with \u003e into the file. mkdir creates the answers directory first.","explanation_context":"The kernel is the core of Linux. uname -r asks the running kernel for its release string; \u003e redirects a command's output into a file instead of the screen.","points":10,"is_optional":false,"is_stateful":true},{"id":"fbf1cc53-b9a5-57e4-8b18-77cadbf1620d","lab_id":"eb18d200-624b-53e4-8ac5-751d4dda5229","position":2,"title":"Find where the shell lives","description":"Save the full path of the bash program into answers/bash-path.txt.","verification_script":"p=$(tr -d '[:space:]' \u003c /home/labuser/work/answers/bash-path.txt)\n[ -x \"$p\" ] \u0026\u0026 [ \"$(basename \"$p\")\" = bash ]\n","hint_context":"command -v bash (or which bash) prints the path of the program bash runs when you type its name.","explanation_context":"Commands are just programs on disk. The shell searches each directory in PATH and runs the first match; which and command -v show you where that match is.","points":10,"is_optional":false,"is_stateful":true},{"id":"fb16e9f8-d8da-5149-a377-cd78f3dd4304","lab_id":"eb18d200-624b-53e4-8ac5-751d4dda5229","position":3,"title":"Find Tom's hidden note","description":"The old admin, Tom, hid a note somewhere under /home/labuser/work/atlas. Find it and save only the codeword (one word, capital letters) into answers/codeword.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/codeword.txt)\" = RISTRETTO ]\n","hint_context":"Files and directories whose names start with a dot are hidden from plain ls. Use ls -la in each directory, or find /home/labuser/work/atlas -name '.*'.","explanation_context":"A leading dot is the only thing that makes a file hidden in Linux - it is a naming convention, not a permission. ls -a and find show them.","points":20,"is_optional":false,"is_stateful":true},{"id":"9c2e5b47-866e-50c0-a07a-34182ef6ef18","lab_id":"eb18d200-624b-53e4-8ac5-751d4dda5229","position":4,"title":"Make atlas remember you","description":"In ~/.bashrc, export the variable ATLAS_ROLE with the value apprentice, and define an alias called atlas that runs cd /home/labuser/work/atlas. Open a new shell (or run source ~/.bashrc) to try it.","verification_script":"[ \"$(bash -ic 'echo $ATLAS_ROLE' 2\u003e/dev/null)\" = apprentice ] \u0026\u0026\nbash -ic 'alias atlas' 2\u003e/dev/null | grep -q 'cd /home/labuser/work/atlas'\n","hint_context":"Add two lines to the end of ~/.bashrc - export ATLAS_ROLE=apprentice and alias atlas='cd /home/labuser/work/atlas'. echo 'line' \u003e\u003e ~/.bashrc appends without overwriting.","explanation_context":"Variables set in a terminal vanish when it closes. ~/.bashrc runs at the start of every interactive Bash shell, so exports and aliases placed there come back every time.","points":20,"is_optional":false,"is_stateful":true},{"id":"bcef36e7-8285-5295-8769-312665efb73a","lab_id":"eb18d200-624b-53e4-8ac5-751d4dda5229","position":5,"title":"Teach atlas a new command","description":"Create the script ~/bin/hello-atlas that prints exactly \"Atlas online\", make it executable, and add ~/bin to your PATH in ~/.bashrc so typing hello-atlas from any directory works.","verification_script":"[ \"$(bash -ic 'cd /tmp \u0026\u0026 hello-atlas' 2\u003e/dev/null)\" = \"Atlas online\" ]\n","hint_context":"The script needs a first line #!/bin/bash and a line echo \"Atlas online\". chmod +x makes it runnable. export PATH=\"$HOME/bin:$PATH\" in ~/.bashrc puts the directory on the search path.","explanation_context":"A command is any executable file in a PATH directory. Prepending ~/bin to PATH makes your own scripts behave exactly like system commands.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('7f67d19f-8874-5b63-b5b3-69094b1e3f39', 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', 'e99a9388-6e2f-5e67-8b42-e5ead23e4c27', 1, 'Ask atlas who it is', $md$Create the directory /home/labuser/work/answers, then save the running kernel release (the output of uname -r) into answers/kernel.txt.$md$, $script$f=/home/labuser/work/answers/kernel.txt
[ -f $f ] && [ "$(tr -d '[:space:]' < $f)" = "$(uname -r)" ]
$script$, 'uname prints kernel information; -r is the release. Redirect its output with > into the file. mkdir creates the answers directory first.', 'The kernel is the core of Linux. uname -r asks the running kernel for its release string; > redirects a command''s output into a file instead of the screen.', 10, false, true),
('72c12f27-ba4c-52db-8688-8ec19b822c56', 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', 'fbf1cc53-b9a5-57e4-8b18-77cadbf1620d', 2, 'Find where the shell lives', $md$Save the full path of the bash program into answers/bash-path.txt.$md$, $script$p=$(tr -d '[:space:]' < /home/labuser/work/answers/bash-path.txt)
[ -x "$p" ] && [ "$(basename "$p")" = bash ]
$script$, 'command -v bash (or which bash) prints the path of the program bash runs when you type its name.', 'Commands are just programs on disk. The shell searches each directory in PATH and runs the first match; which and command -v show you where that match is.', 10, false, true),
('cda34423-ecc5-57cd-9e5f-6a58c06c841b', 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', 'fb16e9f8-d8da-5149-a377-cd78f3dd4304', 3, 'Find Tom''s hidden note', $md$The old admin, Tom, hid a note somewhere under /home/labuser/work/atlas. Find it and save only the codeword (one word, capital letters) into answers/codeword.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/codeword.txt)" = RISTRETTO ]
$script$, 'Files and directories whose names start with a dot are hidden from plain ls. Use ls -la in each directory, or find /home/labuser/work/atlas -name ''.*''.', 'A leading dot is the only thing that makes a file hidden in Linux - it is a naming convention, not a permission. ls -a and find show them.', 20, false, true),
('57304ba3-0462-5bfe-83a5-046b0035ad08', 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', '9c2e5b47-866e-50c0-a07a-34182ef6ef18', 4, 'Make atlas remember you', $md$In ~/.bashrc, export the variable ATLAS_ROLE with the value apprentice, and define an alias called atlas that runs cd /home/labuser/work/atlas. Open a new shell (or run source ~/.bashrc) to try it.$md$, $script$[ "$(bash -ic 'echo $ATLAS_ROLE' 2>/dev/null)" = apprentice ] &&
bash -ic 'alias atlas' 2>/dev/null | grep -q 'cd /home/labuser/work/atlas'
$script$, 'Add two lines to the end of ~/.bashrc - export ATLAS_ROLE=apprentice and alias atlas=''cd /home/labuser/work/atlas''. echo ''line'' >> ~/.bashrc appends without overwriting.', 'Variables set in a terminal vanish when it closes. ~/.bashrc runs at the start of every interactive Bash shell, so exports and aliases placed there come back every time.', 20, false, true),
('cb03a349-1803-5ef9-bbda-7b8dfdcd16bc', 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', 'bcef36e7-8285-5295-8769-312665efb73a', 5, 'Teach atlas a new command', $md$Create the script ~/bin/hello-atlas that prints exactly "Atlas online", make it executable, and add ~/bin to your PATH in ~/.bashrc so typing hello-atlas from any directory works.$md$, $script$[ "$(bash -ic 'cd /tmp && hello-atlas' 2>/dev/null)" = "Atlas online" ]
$script$, 'The script needs a first line #!/bin/bash and a line echo "Atlas online". chmod +x makes it runnable. export PATH="$HOME/bin:$PATH" in ~/.bashrc puts the directory on the search path.', 'A command is any executable file in a PATH directory. Prepending ~/bin to PATH makes your own scripts behave exactly like system commands.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'b8d0f8b5-e6cf-5443-9c94-6f515f4467ed', updated_at = now()
WHERE id = 'eb18d200-624b-53e4-8ac5-751d4dda5229' AND published_version_id IS NULL;

-- Section: Chapter 2: Moving In
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('63d08802-94af-5e70-adb6-8cdf39e53b00', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 2: Moving In', 2, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('7aca830d-151a-5ddd-b824-189d87652f8d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '63d08802-94af-5e70-adb6-8cdf39e53b00', 'Files, Directories, Links and Finding Things', 'notes', 0, $md$> **Tuesday.** Rhea points at a pile of digital boxes Tom dumped in `~/work/moving`: "The shop needs a proper home. Unpack, throw out the junk, and don't delete anything we need - there is no recycle bin on Linux."

## Creating files and directories

```bash
mkdir shop                       # one directory
mkdir -p shop/config/recipes     # whole path, no error if it exists
mkdir -p shop/{config,logs,backups}   # brace expansion -> three dirs
touch notes.txt                  # create empty file (or update its timestamp)
echo "hello" > file.txt          # create/overwrite with content
echo "more"  >> file.txt         # append
rmdir emptydir                   # remove an EMPTY directory
```

Editors on a server: `nano file.txt` (easy, shortcuts at the bottom: `Ctrl+O` save, `Ctrl+X` exit) or `vi file.txt` (always installed). Survival `vi`: `i` to type, `Esc` to stop, `:wq` save and quit, `:q!` quit without saving.

> **Memory hook:** `>` is a **bulldozer** (flattens the file), `>>` is a **stapler** (adds a page).

[[lab-task:1]]

## Copy, move, rename, delete

```bash
cp a.txt b.txt              # copy file
cp -r dir1 dir2             # copy directory (recursive)
cp -a src dst               # archive copy: keep permissions, times, links
mv old.txt new.txt          # rename
mv file.txt dir/            # move
rm file.txt                 # delete file
rm -r dir                   # delete directory and everything inside
rm -i *.log                 # ask before each delete
```

```
 cp:  box/recipes ---copy---> shop/config/recipes     (both exist after)
 mv:  box/menu.txt --move---> shop/menu.txt           (only one exists after)
```

There is **no undo**. `rm -rf /` with a typo in a variable has ended careers. Habits that save you: run `ls` with the same pattern first, use `rm -i` when unsure, never run `rm -rf $DIR/` without checking `$DIR` is set.

**Wildcards (globs)** are expanded by the shell before the command runs:

| Pattern | Matches |
|---|---|
| `*` | anything (`*.log`) |
| `?` | exactly one character (`file?.txt`) |
| `[abc]` / `[0-9]` | one character from the set |
| `{a,b}` | brace expansion - not a match, it generates both words |

[[lab-task:2]]

## Finding things

```bash
find /var/log -name "*.log"            # by name (quote the pattern!)
find . -iname "readme*"                # case-insensitive
find . -type d -name config            # directories only (f = files)
find / -size +100M 2>/dev/null         # bigger than 100 MiB
find . -mtime -1                       # modified in the last 24h
find . -user labuser                   # by owner
find . -name "*.bak" -delete           # find and delete
find . -name "*.sh" -exec chmod +x {} \;   # run a command on each match
locate nginx.conf                      # fast, uses a prebuilt index (updatedb)
```

> **Memory hook:** `find WHERE WHAT DO` - *where* to look, *what* to match, what to *do* with it. Always run it once **without** the DO part.

[[lab-task:3]]

## Inodes and links

A file name is not the file. The data lives in an **inode** (metadata: size, owner, permissions, where the blocks are). A directory is just a list of `name -> inode number`.

```
  directory entries          inode 4211            data blocks
  menu.txt   ---------\     +-------------+       +-----------+
                       >--> | size, owner |-----> | Espresso  |
  backups/menu.hard --/     | links: 2    |       | 3.00 ...  |
                            +-------------+       +-----------+
  current-menu  -> "/home/labuser/work/shop/menu.txt"   (symlink: just a path)
```

| | Hard link (`ln`) | Symbolic link (`ln -s`) |
|---|---|---|
| What it is | a second name for the same inode | a tiny file containing a path |
| Original deleted | data survives | link breaks (dangling) |
| Across filesystems | no | yes |
| For directories | no | yes |

```bash
ln -s /etc/nginx/sites-available/shop /etc/nginx/sites-enabled/shop   # classic symlink use
ls -li                  # first column = inode number
stat menu.txt           # full inode details
readlink -f current-menu    # where does the link really point?
```

> **Memory hook:** a **symlink is a sticky note** with an address on it; a **hard link is a second front door** into the same room.

[[lab-task:4]]

What you should see from `ls -li shop shop/backups`:

```
4211 -rw-r--r-- 2 labuser labuser 41 ... menu.txt
4300 lrwxrwxrwx 1 labuser labuser 32 ... current-menu -> /home/labuser/work/shop/menu.txt
4211 -rw-r--r-- 2 labuser labuser 41 ... menu.hard
```

Same inode (4211) and a link count of 2 - one file, two names.

## Sizes and file types

```bash
du -sh shop             # total size of a directory
du -ah moving | sort -h | tail -5    # the five biggest things
ls -lhS                 # list sorted by size
file beans-inventory.csv    # what kind of data is this, really?
```

Linux does not care about extensions - `file` looks at the content.

[[lab-task:5]]

> **End of day 2.** The shop has a home, the junk is gone, and you noticed `beans-inventory.csv` was hogging space. Inside the box you find Tom's next note: "The logs never lie. Read them."
$md$, 45, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('f88e3d11-37ed-5d49-a2fc-588e50584208', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '7aca830d-151a-5ddd-b824-189d87652f8d', 'module', 'Files, Directories, Links and Finding Things', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
rm -rf $w/moving $w/shop $w/answers
mkdir -p $w/moving/box/recipes $w/moving/box/old $w/moving/garage $w/answers
echo "Espresso 3.00 | Latte 4.50 | Mocha 5.00" > $w/moving/box/menu.txt
echo "18g in, 36g out, 28 seconds" > $w/moving/box/recipes/espresso.txt
echo "1 espresso + 200ml steamed milk" > $w/moving/box/recipes/latte.txt
echo "old menu" > $w/moving/box/old/menu-2019.bak
echo "old prices" > $w/moving/box/old/prices.bak
echo "draft" > $w/moving/box/recipes/mocha.bak
echo "tools list" > $w/moving/garage/tools.txt
echo "spare" > $w/moving/garage/spare.bak
head -c 2097152 /dev/urandom > $w/moving/garage/beans-inventory.csv
head -c 4096 /dev/urandom > $w/moving/box/old/receipts.csv
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '4dcf5149-1aba-5323-a07f-9c7061e18ff8' AND id NOT IN ('23449351-d653-5286-9afa-7448431995b4', '408ee77e-ed5e-5281-8b77-eff44b5f19a9', '27393828-6d30-5fed-b91e-a620fc0efb26', 'fc55826c-c5ee-5384-bfa9-f36c046189ca', 'b28d1720-b68a-5f0d-8e1a-ea3fbe02b42a');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '4dcf5149-1aba-5323-a07f-9c7061e18ff8';
DELETE FROM lab_tasks WHERE lab_id = 'f88e3d11-37ed-5d49-a2fc-588e50584208' AND id NOT IN ('6998c437-10ca-5703-a08f-054b11d8caf9', 'cb39898d-640f-51f7-9e9f-54c3e17881b5', '7109941e-a02e-58a9-b567-fcff498603fb', 'e8c3cc24-07d3-5bed-babd-cb22b692cc9c', '32019b28-5296-5165-a93b-76db427f321e');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'f88e3d11-37ed-5d49-a2fc-588e50584208';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('6998c437-10ca-5703-a08f-054b11d8caf9', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 1, 'Build the shop skeleton', $md$Create /home/labuser/work/shop with three subdirectories inside it - config, logs and backups - using a single mkdir command.$md$, $script$s=/home/labuser/work/shop
[ -d $s/config ] && [ -d $s/logs ] && [ -d $s/backups ]
$script$, 'mkdir -p creates parent directories as needed, and brace expansion {config,logs,backups} turns one word into three.', 'mkdir -p never fails if a directory already exists and creates every missing parent. Bash expands shop/{a,b,c} into three separate arguments before mkdir even runs.', 10, false, true),
('cb39898d-640f-51f7-9e9f-54c3e17881b5', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 2, 'Unpack the box', $md$Copy the whole moving/box/recipes directory (with its contents) to shop/config/recipes, and move moving/box/menu.txt to shop/menu.txt so it no longer exists in the box.$md$, $script$w=/home/labuser/work
[ -f $w/shop/config/recipes/espresso.txt ] && [ -f $w/shop/config/recipes/latte.txt ] &&
[ -f $w/moving/box/recipes/espresso.txt ] &&
[ -f $w/shop/menu.txt ] && [ ! -e $w/moving/box/menu.txt ]
$script$, 'cp needs -r to copy a directory. mv both moves and renames; the source disappears.', 'cp -r copies a tree and leaves the original in place. mv only changes where the name points, so within one filesystem it is instant even for huge files.', 15, false, true),
('7109941e-a02e-58a9-b567-fcff498603fb', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 3, 'Throw out the junk', $md$Delete every file ending in .bak anywhere under moving/ (there are several, in different folders) with one find command. Every other file must survive.$md$, $script$w=/home/labuser/work/moving
[ -z "$(find $w -name '*.bak')" ] &&
[ -f $w/garage/tools.txt ] && [ -f $w/box/old/receipts.csv ] && [ -f $w/garage/beans-inventory.csv ]
$script$, 'find DIR -name ''*.bak'' lists matches; run it first to check, then add -delete. Quote the pattern so the shell does not expand it.', 'find walks the whole tree. Always run it without -delete first - rm and -delete have no undo and no recycle bin in Linux.', 20, false, true),
('e8c3cc24-07d3-5bed-babd-cb22b692cc9c', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 4, 'Two kinds of links', $md$Create a symbolic link shop/current-menu pointing to /home/labuser/work/shop/menu.txt, and a hard link shop/backups/menu.hard to the same menu.txt.$md$, $script$s=/home/labuser/work/shop
[ -L $s/current-menu ] && [ "$(readlink -f $s/current-menu)" = $s/menu.txt ] &&
[ ! -L $s/backups/menu.hard ] && [ $s/backups/menu.hard -ef $s/menu.txt ]
$script$, 'ln -s TARGET LINKNAME makes a symlink; ln TARGET LINKNAME (no -s) makes a hard link. ls -li shows inode numbers - hard links share one.', 'A symlink is a small file holding a path, so it breaks if the target moves. A hard link is a second name for the same inode, so the data lives until the last name is removed.', 25, false, true),
('32019b28-5296-5165-a93b-76db427f321e', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 5, 'What is eating the space?', $md$Find the largest file anywhere under moving/ and save its file name (just the name, not the path) into answers/biggest.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/biggest.txt)" = beans-inventory.csv ]
$script$, 'find moving -type f -size +1M lists files bigger than 1 MiB, or ls -lhR / du -ah moving | sort -h shows sizes.', 'find -size filters by size, and du -ah | sort -h ranks everything. This is the first thing you do when a disk fills up.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('4dcf5149-1aba-5323-a07f-9c7061e18ff8', 'f88e3d11-37ed-5d49-a2fc-588e50584208', 1, $json$[{"id":"6998c437-10ca-5703-a08f-054b11d8caf9","lab_id":"f88e3d11-37ed-5d49-a2fc-588e50584208","position":1,"title":"Build the shop skeleton","description":"Create /home/labuser/work/shop with three subdirectories inside it - config, logs and backups - using a single mkdir command.","verification_script":"s=/home/labuser/work/shop\n[ -d $s/config ] \u0026\u0026 [ -d $s/logs ] \u0026\u0026 [ -d $s/backups ]\n","hint_context":"mkdir -p creates parent directories as needed, and brace expansion {config,logs,backups} turns one word into three.","explanation_context":"mkdir -p never fails if a directory already exists and creates every missing parent. Bash expands shop/{a,b,c} into three separate arguments before mkdir even runs.","points":10,"is_optional":false,"is_stateful":true},{"id":"cb39898d-640f-51f7-9e9f-54c3e17881b5","lab_id":"f88e3d11-37ed-5d49-a2fc-588e50584208","position":2,"title":"Unpack the box","description":"Copy the whole moving/box/recipes directory (with its contents) to shop/config/recipes, and move moving/box/menu.txt to shop/menu.txt so it no longer exists in the box.","verification_script":"w=/home/labuser/work\n[ -f $w/shop/config/recipes/espresso.txt ] \u0026\u0026 [ -f $w/shop/config/recipes/latte.txt ] \u0026\u0026\n[ -f $w/moving/box/recipes/espresso.txt ] \u0026\u0026\n[ -f $w/shop/menu.txt ] \u0026\u0026 [ ! -e $w/moving/box/menu.txt ]\n","hint_context":"cp needs -r to copy a directory. mv both moves and renames; the source disappears.","explanation_context":"cp -r copies a tree and leaves the original in place. mv only changes where the name points, so within one filesystem it is instant even for huge files.","points":15,"is_optional":false,"is_stateful":true},{"id":"7109941e-a02e-58a9-b567-fcff498603fb","lab_id":"f88e3d11-37ed-5d49-a2fc-588e50584208","position":3,"title":"Throw out the junk","description":"Delete every file ending in .bak anywhere under moving/ (there are several, in different folders) with one find command. Every other file must survive.","verification_script":"w=/home/labuser/work/moving\n[ -z \"$(find $w -name '*.bak')\" ] \u0026\u0026\n[ -f $w/garage/tools.txt ] \u0026\u0026 [ -f $w/box/old/receipts.csv ] \u0026\u0026 [ -f $w/garage/beans-inventory.csv ]\n","hint_context":"find DIR -name '*.bak' lists matches; run it first to check, then add -delete. Quote the pattern so the shell does not expand it.","explanation_context":"find walks the whole tree. Always run it without -delete first - rm and -delete have no undo and no recycle bin in Linux.","points":20,"is_optional":false,"is_stateful":true},{"id":"e8c3cc24-07d3-5bed-babd-cb22b692cc9c","lab_id":"f88e3d11-37ed-5d49-a2fc-588e50584208","position":4,"title":"Two kinds of links","description":"Create a symbolic link shop/current-menu pointing to /home/labuser/work/shop/menu.txt, and a hard link shop/backups/menu.hard to the same menu.txt.","verification_script":"s=/home/labuser/work/shop\n[ -L $s/current-menu ] \u0026\u0026 [ \"$(readlink -f $s/current-menu)\" = $s/menu.txt ] \u0026\u0026\n[ ! -L $s/backups/menu.hard ] \u0026\u0026 [ $s/backups/menu.hard -ef $s/menu.txt ]\n","hint_context":"ln -s TARGET LINKNAME makes a symlink; ln TARGET LINKNAME (no -s) makes a hard link. ls -li shows inode numbers - hard links share one.","explanation_context":"A symlink is a small file holding a path, so it breaks if the target moves. A hard link is a second name for the same inode, so the data lives until the last name is removed.","points":25,"is_optional":false,"is_stateful":true},{"id":"32019b28-5296-5165-a93b-76db427f321e","lab_id":"f88e3d11-37ed-5d49-a2fc-588e50584208","position":5,"title":"What is eating the space?","description":"Find the largest file anywhere under moving/ and save its file name (just the name, not the path) into answers/biggest.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/biggest.txt)\" = beans-inventory.csv ]\n","hint_context":"find moving -type f -size +1M lists files bigger than 1 MiB, or ls -lhR / du -ah moving | sort -h shows sizes.","explanation_context":"find -size filters by size, and du -ah | sort -h ranks everything. This is the first thing you do when a disk fills up.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('23449351-d653-5286-9afa-7448431995b4', '4dcf5149-1aba-5323-a07f-9c7061e18ff8', '6998c437-10ca-5703-a08f-054b11d8caf9', 1, 'Build the shop skeleton', $md$Create /home/labuser/work/shop with three subdirectories inside it - config, logs and backups - using a single mkdir command.$md$, $script$s=/home/labuser/work/shop
[ -d $s/config ] && [ -d $s/logs ] && [ -d $s/backups ]
$script$, 'mkdir -p creates parent directories as needed, and brace expansion {config,logs,backups} turns one word into three.', 'mkdir -p never fails if a directory already exists and creates every missing parent. Bash expands shop/{a,b,c} into three separate arguments before mkdir even runs.', 10, false, true),
('408ee77e-ed5e-5281-8b77-eff44b5f19a9', '4dcf5149-1aba-5323-a07f-9c7061e18ff8', 'cb39898d-640f-51f7-9e9f-54c3e17881b5', 2, 'Unpack the box', $md$Copy the whole moving/box/recipes directory (with its contents) to shop/config/recipes, and move moving/box/menu.txt to shop/menu.txt so it no longer exists in the box.$md$, $script$w=/home/labuser/work
[ -f $w/shop/config/recipes/espresso.txt ] && [ -f $w/shop/config/recipes/latte.txt ] &&
[ -f $w/moving/box/recipes/espresso.txt ] &&
[ -f $w/shop/menu.txt ] && [ ! -e $w/moving/box/menu.txt ]
$script$, 'cp needs -r to copy a directory. mv both moves and renames; the source disappears.', 'cp -r copies a tree and leaves the original in place. mv only changes where the name points, so within one filesystem it is instant even for huge files.', 15, false, true),
('27393828-6d30-5fed-b91e-a620fc0efb26', '4dcf5149-1aba-5323-a07f-9c7061e18ff8', '7109941e-a02e-58a9-b567-fcff498603fb', 3, 'Throw out the junk', $md$Delete every file ending in .bak anywhere under moving/ (there are several, in different folders) with one find command. Every other file must survive.$md$, $script$w=/home/labuser/work/moving
[ -z "$(find $w -name '*.bak')" ] &&
[ -f $w/garage/tools.txt ] && [ -f $w/box/old/receipts.csv ] && [ -f $w/garage/beans-inventory.csv ]
$script$, 'find DIR -name ''*.bak'' lists matches; run it first to check, then add -delete. Quote the pattern so the shell does not expand it.', 'find walks the whole tree. Always run it without -delete first - rm and -delete have no undo and no recycle bin in Linux.', 20, false, true),
('fc55826c-c5ee-5384-bfa9-f36c046189ca', '4dcf5149-1aba-5323-a07f-9c7061e18ff8', 'e8c3cc24-07d3-5bed-babd-cb22b692cc9c', 4, 'Two kinds of links', $md$Create a symbolic link shop/current-menu pointing to /home/labuser/work/shop/menu.txt, and a hard link shop/backups/menu.hard to the same menu.txt.$md$, $script$s=/home/labuser/work/shop
[ -L $s/current-menu ] && [ "$(readlink -f $s/current-menu)" = $s/menu.txt ] &&
[ ! -L $s/backups/menu.hard ] && [ $s/backups/menu.hard -ef $s/menu.txt ]
$script$, 'ln -s TARGET LINKNAME makes a symlink; ln TARGET LINKNAME (no -s) makes a hard link. ls -li shows inode numbers - hard links share one.', 'A symlink is a small file holding a path, so it breaks if the target moves. A hard link is a second name for the same inode, so the data lives until the last name is removed.', 25, false, true),
('b28d1720-b68a-5f0d-8e1a-ea3fbe02b42a', '4dcf5149-1aba-5323-a07f-9c7061e18ff8', '32019b28-5296-5165-a93b-76db427f321e', 5, 'What is eating the space?', $md$Find the largest file anywhere under moving/ and save its file name (just the name, not the path) into answers/biggest.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/biggest.txt)" = beans-inventory.csv ]
$script$, 'find moving -type f -size +1M lists files bigger than 1 MiB, or ls -lhR / du -ah moving | sort -h shows sizes.', 'find -size filters by size, and du -ah | sort -h ranks everything. This is the first thing you do when a disk fills up.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '4dcf5149-1aba-5323-a07f-9c7061e18ff8', updated_at = now()
WHERE id = 'f88e3d11-37ed-5d49-a2fc-588e50584208' AND published_version_id IS NULL;

-- Section: Chapter 3: The Logbook
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 3: The Logbook', 3, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('c5763494-4508-5099-965a-3b07d56d84c9', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'Viewing Text, grep, Pipes, Redirection, sed and awk', 'notes', 0, $md$> **Wednesday, 10:14.** Customers are complaining that checkout is broken. Rhea: "Tom always said *the logs never lie*. Don't guess - read the logbook." You have two files in `~/work/logbook`: the web server's `access.log` and the app's `app.log`. Today you learn to turn thousands of lines into one answer.

## Looking at files

```bash
cat file.txt            # dump the whole file (fine for small files)
less file.txt           # scroll: Space/b page, /word search, n next, G end, q quit
head -n 20 file.txt     # first 20 lines
tail -n 20 file.txt     # last 20 lines
tail -f /var/log/syslog # follow: keep printing new lines live (Ctrl+C to stop)
wc -l file.txt          # count lines (-w words, -c bytes)
```

> **Memory hook:** `head` and `tail` are the two ends of a coffee queue. `tail -f` is standing at the end of the queue **forever**, watching new customers arrive.

## grep: find the needle

```bash
grep ERROR app.log              # lines containing ERROR
grep -i error app.log           # ignore case
grep -c ERROR app.log           # count matching lines
grep -v INFO app.log            # invert: lines WITHOUT INFO
grep -n timeout app.log         # show line numbers
grep -r "port" /etc/brewbot/    # search every file in a directory
grep -E "ERROR|WARN" app.log    # extended regex: either word
grep -A2 -B1 ERROR app.log      # 2 lines After, 1 Before each match
```

Regex survival kit: `^` start of line, `$` end of line, `.` any char, `*` repeat previous 0+ times, `[0-9]` one digit, `[^ ]` anything but a space.

[[lab-task:1]]

## Pipes and redirection

Every program has three streams:

```
            +-----------+
 stdin  0 ->|  program  |-> 1 stdout  (normal output)
            |           |-> 2 stderr  (errors)
            +-----------+
```

| Syntax | Meaning |
|---|---|
| `cmd > file` | stdout to file (overwrite) |
| `cmd >> file` | stdout to file (append) |
| `cmd 2> file` | stderr to file |
| `cmd > file 2>&1` | both streams to the same file |
| `cmd &> file` | same, bash shorthand |
| `cmd 2>/dev/null` | throw errors away (`/dev/null` is the black hole) |
| `cmd < file` | read stdin from a file |
| `cmd1 \| cmd2` | stdout of cmd1 becomes stdin of cmd2 |
| `cmd \| tee file` | show on screen *and* save to file |

The pipe `|` is the soul of Linux: small tools, each doing one thing, chained together.

```
 cat access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -3
      lines     ->   just IPs      -> grouped -> counted -> biggest -> top 3
```

> **Memory hook:** a pipe is a **coffee filter chain** - every stage takes what drips from the stage above and passes on something smaller.

## Slicing and counting: cut, sort, uniq, tr

```bash
cut -d: -f1 /etc/passwd          # field 1, ":" separated (all usernames)
cut -c1-10 file                  # characters 1-10
sort names.txt                   # alphabetical
sort -n numbers.txt              # numeric
sort -rn                         # numeric, biggest first
sort -k2 -t, data.csv            # by column 2 of a CSV
sort -u                          # sort + remove duplicates
uniq -c                          # count ADJACENT duplicates (so sort first!)
tr 'a-z' 'A-Z' < file            # translate characters
tr -d '\r' < win.txt > unix.txt  # delete Windows carriage returns
```

[[lab-task:2]]

What you should see:

```
$ awk '{print $1}' logbook/access.log | sort | uniq -c | sort -rn
     95 192.168.1.20
     60 172.16.0.9
     60 10.0.0.7
     60 10.0.0.5
```

## awk: columns made easy

`awk` splits each line into fields: `$1`, `$2`, ... `$NF` (last), and `NR` is the line number.

```bash
awk '{print $1, $9}' access.log              # IP and status
awk '$9 == 500' access.log                   # only lines where status is 500
awk '$9 == 500 {print $7}' access.log        # ...and print the path
awk -F: '{print $1, $7}' /etc/passwd         # custom separator
awk '{sum += $10} END {print sum}' access.log   # add up bytes sent
```

[[lab-task:3]]

## sed: edit the stream

```bash
sed 's/old/new/' file          # replace first match on each line
sed 's/old/new/g' file         # replace every match
sed -n '10,20p' file           # print only lines 10-20
sed '/^#/d' config             # delete comment lines
sed -i.bak 's/80/8080/' conf   # edit IN PLACE, keep conf.bak as backup
```

Without `-i`, sed never touches the file - it prints the result. That makes it safe to test, then redirect to a new file.

> **Memory hook:** **s**ed **s**ubstitutes: `s/what/with/`. **awk** **a**sks about columns.

[[lab-task:4]]

[[lab-task:5]]

What you should see:

```
$ cat answers/err.txt
ls: cannot access '/no/such/dir': No such file or directory
```

## Comparing files

```bash
diff old.conf new.conf         # line differences
diff -u old.conf new.conf      # unified format (what git shows)
cmp a.bin b.bin                # byte-level, for binaries
```

> **End of day 3.** The pipeline told the story: `/checkout` and `/api/orders` were throwing 500s, and one IP was hammering the cart. You masked the leaked passwords before anyone saw them. In the corner of the log you spot Tom's next note: "Not everyone should have every key."
$md$, 50, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('8fac3d77-167a-50ca-8617-771b36111113', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c5763494-4508-5099-965a-3b07d56d84c9', 'module', 'Viewing Text, grep, Pipes, Redirection, sed and awk', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
rm -rf $w/logbook $w/answers
mkdir -p $w/logbook $w/answers
a=$w/logbook/access.log
: > $a
for i in $(seq 1 240); do
  case $((i % 4)) in 0) ip=10.0.0.5;; 1) ip=10.0.0.7;; 2) ip=192.168.1.20;; *) ip=172.16.0.9;; esac
  case $((i % 5)) in 0) p=/;; 1) p=/menu;; 2) p=/cart;; 3) p=/checkout;; *) p=/api/orders;; esac
  code=200
  [ $((i % 7)) -eq 0 ] && [ $p = /checkout ] && code=500
  [ $((i % 6)) -eq 0 ] && [ $p = /api/orders ] && code=500
  [ $((i % 13)) -eq 0 ] && code=404
  echo "$ip - - [14/Oct/2026:10:$((i % 60)):00 +0000] \"GET $p HTTP/1.1\" $code $((i * 17))" >> $a
done
for i in $(seq 1 35); do
  echo "192.168.1.20 - - [14/Oct/2026:11:$((i % 60)):00 +0000] \"GET /cart HTTP/1.1\" 200 512" >> $a
done
l=$w/logbook/app.log
: > $l
for i in $(seq 1 80); do
  case $((i % 10)) in
    0|3) echo "2026-10-14 10:$((i % 60)):00 ERROR payment gateway timeout order=$i" >> $l;;
    5) echo "2026-10-14 10:$((i % 60)):00 WARN slow query 1200ms order=$i" >> $l;;
    *) if [ $((i % 4)) -eq 0 ]; then
         echo "2026-10-14 10:$((i % 60)):00 INFO login user=u$i password=s3cret$i" >> $l
       else
         echo "2026-10-14 10:$((i % 60)):00 INFO order placed order=$i" >> $l
       fi;;
  esac
done
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '24fc0e64-cd84-52bf-b66a-43d0926f076d' AND id NOT IN ('77a75381-8db9-5dbd-ad84-0a218fc076ba', 'b6bed250-c2e3-567a-9f29-620e2b2bf5b0', '1f86d9d0-64c3-5211-9d72-34268ffa756d', '8bad94bd-de18-5c12-8309-6efd82054b8e', '4f9aee3b-3265-5e22-84e6-81a9c75e6d53');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '24fc0e64-cd84-52bf-b66a-43d0926f076d';
DELETE FROM lab_tasks WHERE lab_id = '8fac3d77-167a-50ca-8617-771b36111113' AND id NOT IN ('4d64c7a8-54b4-54e6-b58d-d1e668c05651', '3f7db9c2-95ee-5754-a15e-29221780cba2', 'b640ca4c-f2fc-58e3-8fa9-da9e3644d634', '79f69cf3-8ef8-5748-be31-0aab8681c8e8', '029b8920-d1bf-5d12-ae86-b8b14af6a8e4');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '8fac3d77-167a-50ca-8617-771b36111113';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4d64c7a8-54b4-54e6-b58d-d1e668c05651', '8fac3d77-167a-50ca-8617-771b36111113', 1, 'How bad is it?', $md$Count how many lines in logbook/app.log contain the word ERROR and save just the number into answers/errors.txt.$md$, $script$w=/home/labuser/work
[ "$(tr -d '[:space:]' < $w/answers/errors.txt)" = "$(grep -c ERROR $w/logbook/app.log)" ]
$script$, 'grep -c PATTERN FILE prints the number of matching lines instead of the lines themselves.', 'grep -c counts matching lines. grep PATTERN FILE | wc -l gives the same answer by counting the printed lines.', 15, false, true),
('3f7db9c2-95ee-5754-a15e-29221780cba2', '8fac3d77-167a-50ca-8617-771b36111113', 2, 'Who is hammering the shop?', $md$Find the IP address that made the most requests in logbook/access.log (the IP is the first field on each line) and save only that IP into answers/top-ip.txt.$md$, $script$w=/home/labuser/work
want=$(awk '{print $1}' $w/logbook/access.log | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
[ "$(tr -d '[:space:]' < $w/answers/top-ip.txt)" = "$want" ]
$script$, 'Pipe it - awk ''{print $1}'' extracts the IP, sort groups equal lines, uniq -c counts each group, sort -rn puts the biggest count first, head -1 keeps the winner.', 'sort | uniq -c | sort -rn | head is the classic "top N" pipeline. uniq only merges adjacent duplicates, which is why sort must come first.', 25, false, true),
('b640ca4c-f2fc-58e3-8fa9-da9e3644d634', '8fac3d77-167a-50ca-8617-771b36111113', 3, 'Which pages are crashing?', $md$Save the list of distinct request paths that returned status 500 into answers/500-paths.txt, one path per line, sorted alphabetically with no duplicates. In access.log the path is field 7 and the status code is field 9.$md$, $script$w=/home/labuser/work
diff <(awk '$9 == 500 {print $7}' $w/logbook/access.log | sort -u) <(grep -v '^$' $w/answers/500-paths.txt) >/dev/null
$script$, 'awk ''$9 == 500 {print $7}'' filters on one field and prints another. sort -u sorts and removes duplicates.', 'awk splits each line on whitespace into $1, $2 ... so it can filter on one column and print another in one step. sort -u is sort plus uniq.', 20, false, true),
('79f69cf3-8ef8-5748-be31-0aab8681c8e8', '8fac3d77-167a-50ca-8617-771b36111113', 4, 'Hide the leaked passwords', $md$The app wrote passwords into its log. Create logbook/app-clean.log - a copy of app.log where every password=VALUE is replaced with password=*** - using sed. Leave app.log itself unchanged.$md$, $script$w=/home/labuser/work/logbook
[ -f $w/app-clean.log ] &&
[ "$(wc -l < $w/app-clean.log)" = "$(wc -l < $w/app.log)" ] &&
! grep -q 'password=[^*]' $w/app-clean.log &&
[ "$(grep -c 'password=\*\*\*' $w/app-clean.log)" = "$(grep -c 'password=' $w/app.log)" ] &&
grep -q 'password=s3cret' $w/app.log
$script$, 'sed ''s/password=[^ ]*/password=***/'' FILE > NEWFILE - [^ ]* means "everything up to the next space". Without -i sed prints the result and leaves the original alone.', 'sed s/old/new/ edits a stream line by line. Writing to a new file keeps the evidence intact; sed -i edits in place, which is risky on the only copy of a log.', 20, false, true),
('029b8920-d1bf-5d12-ae86-b8b14af6a8e4', '8fac3d77-167a-50ca-8617-771b36111113', 5, 'Separate the good from the bad', $md$Run ls /home/labuser/work/logbook /no/such/dir as one command so that the normal output goes to answers/out.txt and the error message goes to answers/err.txt.$md$, $script$a=/home/labuser/work/answers
grep -q access.log $a/out.txt && grep -q 'No such file' $a/err.txt &&
! grep -q access.log $a/err.txt && ! grep -q 'No such file' $a/out.txt
$script$, 'The > operator redirects stdout (stream 1) and 2> redirects stderr (stream 2). Both can be used on the same command.', 'Every program has three streams - stdin (0), stdout (1), stderr (2). Splitting them lets scripts keep errors in a log while passing clean data down a pipe.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('24fc0e64-cd84-52bf-b66a-43d0926f076d', '8fac3d77-167a-50ca-8617-771b36111113', 1, $json$[{"id":"4d64c7a8-54b4-54e6-b58d-d1e668c05651","lab_id":"8fac3d77-167a-50ca-8617-771b36111113","position":1,"title":"How bad is it?","description":"Count how many lines in logbook/app.log contain the word ERROR and save just the number into answers/errors.txt.","verification_script":"w=/home/labuser/work\n[ \"$(tr -d '[:space:]' \u003c $w/answers/errors.txt)\" = \"$(grep -c ERROR $w/logbook/app.log)\" ]\n","hint_context":"grep -c PATTERN FILE prints the number of matching lines instead of the lines themselves.","explanation_context":"grep -c counts matching lines. grep PATTERN FILE | wc -l gives the same answer by counting the printed lines.","points":15,"is_optional":false,"is_stateful":true},{"id":"3f7db9c2-95ee-5754-a15e-29221780cba2","lab_id":"8fac3d77-167a-50ca-8617-771b36111113","position":2,"title":"Who is hammering the shop?","description":"Find the IP address that made the most requests in logbook/access.log (the IP is the first field on each line) and save only that IP into answers/top-ip.txt.","verification_script":"w=/home/labuser/work\nwant=$(awk '{print $1}' $w/logbook/access.log | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')\n[ \"$(tr -d '[:space:]' \u003c $w/answers/top-ip.txt)\" = \"$want\" ]\n","hint_context":"Pipe it - awk '{print $1}' extracts the IP, sort groups equal lines, uniq -c counts each group, sort -rn puts the biggest count first, head -1 keeps the winner.","explanation_context":"sort | uniq -c | sort -rn | head is the classic \"top N\" pipeline. uniq only merges adjacent duplicates, which is why sort must come first.","points":25,"is_optional":false,"is_stateful":true},{"id":"b640ca4c-f2fc-58e3-8fa9-da9e3644d634","lab_id":"8fac3d77-167a-50ca-8617-771b36111113","position":3,"title":"Which pages are crashing?","description":"Save the list of distinct request paths that returned status 500 into answers/500-paths.txt, one path per line, sorted alphabetically with no duplicates. In access.log the path is field 7 and the status code is field 9.","verification_script":"w=/home/labuser/work\ndiff \u003c(awk '$9 == 500 {print $7}' $w/logbook/access.log | sort -u) \u003c(grep -v '^$' $w/answers/500-paths.txt) \u003e/dev/null\n","hint_context":"awk '$9 == 500 {print $7}' filters on one field and prints another. sort -u sorts and removes duplicates.","explanation_context":"awk splits each line on whitespace into $1, $2 ... so it can filter on one column and print another in one step. sort -u is sort plus uniq.","points":20,"is_optional":false,"is_stateful":true},{"id":"79f69cf3-8ef8-5748-be31-0aab8681c8e8","lab_id":"8fac3d77-167a-50ca-8617-771b36111113","position":4,"title":"Hide the leaked passwords","description":"The app wrote passwords into its log. Create logbook/app-clean.log - a copy of app.log where every password=VALUE is replaced with password=*** - using sed. Leave app.log itself unchanged.","verification_script":"w=/home/labuser/work/logbook\n[ -f $w/app-clean.log ] \u0026\u0026\n[ \"$(wc -l \u003c $w/app-clean.log)\" = \"$(wc -l \u003c $w/app.log)\" ] \u0026\u0026\n! grep -q 'password=[^*]' $w/app-clean.log \u0026\u0026\n[ \"$(grep -c 'password=\\*\\*\\*' $w/app-clean.log)\" = \"$(grep -c 'password=' $w/app.log)\" ] \u0026\u0026\ngrep -q 'password=s3cret' $w/app.log\n","hint_context":"sed 's/password=[^ ]*/password=***/' FILE \u003e NEWFILE - [^ ]* means \"everything up to the next space\". Without -i sed prints the result and leaves the original alone.","explanation_context":"sed s/old/new/ edits a stream line by line. Writing to a new file keeps the evidence intact; sed -i edits in place, which is risky on the only copy of a log.","points":20,"is_optional":false,"is_stateful":true},{"id":"029b8920-d1bf-5d12-ae86-b8b14af6a8e4","lab_id":"8fac3d77-167a-50ca-8617-771b36111113","position":5,"title":"Separate the good from the bad","description":"Run ls /home/labuser/work/logbook /no/such/dir as one command so that the normal output goes to answers/out.txt and the error message goes to answers/err.txt.","verification_script":"a=/home/labuser/work/answers\ngrep -q access.log $a/out.txt \u0026\u0026 grep -q 'No such file' $a/err.txt \u0026\u0026\n! grep -q access.log $a/err.txt \u0026\u0026 ! grep -q 'No such file' $a/out.txt\n","hint_context":"The \u003e operator redirects stdout (stream 1) and 2\u003e redirects stderr (stream 2). Both can be used on the same command.","explanation_context":"Every program has three streams - stdin (0), stdout (1), stderr (2). Splitting them lets scripts keep errors in a log while passing clean data down a pipe.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('77a75381-8db9-5dbd-ad84-0a218fc076ba', '24fc0e64-cd84-52bf-b66a-43d0926f076d', '4d64c7a8-54b4-54e6-b58d-d1e668c05651', 1, 'How bad is it?', $md$Count how many lines in logbook/app.log contain the word ERROR and save just the number into answers/errors.txt.$md$, $script$w=/home/labuser/work
[ "$(tr -d '[:space:]' < $w/answers/errors.txt)" = "$(grep -c ERROR $w/logbook/app.log)" ]
$script$, 'grep -c PATTERN FILE prints the number of matching lines instead of the lines themselves.', 'grep -c counts matching lines. grep PATTERN FILE | wc -l gives the same answer by counting the printed lines.', 15, false, true),
('b6bed250-c2e3-567a-9f29-620e2b2bf5b0', '24fc0e64-cd84-52bf-b66a-43d0926f076d', '3f7db9c2-95ee-5754-a15e-29221780cba2', 2, 'Who is hammering the shop?', $md$Find the IP address that made the most requests in logbook/access.log (the IP is the first field on each line) and save only that IP into answers/top-ip.txt.$md$, $script$w=/home/labuser/work
want=$(awk '{print $1}' $w/logbook/access.log | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
[ "$(tr -d '[:space:]' < $w/answers/top-ip.txt)" = "$want" ]
$script$, 'Pipe it - awk ''{print $1}'' extracts the IP, sort groups equal lines, uniq -c counts each group, sort -rn puts the biggest count first, head -1 keeps the winner.', 'sort | uniq -c | sort -rn | head is the classic "top N" pipeline. uniq only merges adjacent duplicates, which is why sort must come first.', 25, false, true),
('1f86d9d0-64c3-5211-9d72-34268ffa756d', '24fc0e64-cd84-52bf-b66a-43d0926f076d', 'b640ca4c-f2fc-58e3-8fa9-da9e3644d634', 3, 'Which pages are crashing?', $md$Save the list of distinct request paths that returned status 500 into answers/500-paths.txt, one path per line, sorted alphabetically with no duplicates. In access.log the path is field 7 and the status code is field 9.$md$, $script$w=/home/labuser/work
diff <(awk '$9 == 500 {print $7}' $w/logbook/access.log | sort -u) <(grep -v '^$' $w/answers/500-paths.txt) >/dev/null
$script$, 'awk ''$9 == 500 {print $7}'' filters on one field and prints another. sort -u sorts and removes duplicates.', 'awk splits each line on whitespace into $1, $2 ... so it can filter on one column and print another in one step. sort -u is sort plus uniq.', 20, false, true),
('8bad94bd-de18-5c12-8309-6efd82054b8e', '24fc0e64-cd84-52bf-b66a-43d0926f076d', '79f69cf3-8ef8-5748-be31-0aab8681c8e8', 4, 'Hide the leaked passwords', $md$The app wrote passwords into its log. Create logbook/app-clean.log - a copy of app.log where every password=VALUE is replaced with password=*** - using sed. Leave app.log itself unchanged.$md$, $script$w=/home/labuser/work/logbook
[ -f $w/app-clean.log ] &&
[ "$(wc -l < $w/app-clean.log)" = "$(wc -l < $w/app.log)" ] &&
! grep -q 'password=[^*]' $w/app-clean.log &&
[ "$(grep -c 'password=\*\*\*' $w/app-clean.log)" = "$(grep -c 'password=' $w/app.log)" ] &&
grep -q 'password=s3cret' $w/app.log
$script$, 'sed ''s/password=[^ ]*/password=***/'' FILE > NEWFILE - [^ ]* means "everything up to the next space". Without -i sed prints the result and leaves the original alone.', 'sed s/old/new/ edits a stream line by line. Writing to a new file keeps the evidence intact; sed -i edits in place, which is risky on the only copy of a log.', 20, false, true),
('4f9aee3b-3265-5e22-84e6-81a9c75e6d53', '24fc0e64-cd84-52bf-b66a-43d0926f076d', '029b8920-d1bf-5d12-ae86-b8b14af6a8e4', 5, 'Separate the good from the bad', $md$Run ls /home/labuser/work/logbook /no/such/dir as one command so that the normal output goes to answers/out.txt and the error message goes to answers/err.txt.$md$, $script$a=/home/labuser/work/answers
grep -q access.log $a/out.txt && grep -q 'No such file' $a/err.txt &&
! grep -q access.log $a/err.txt && ! grep -q 'No such file' $a/out.txt
$script$, 'The > operator redirects stdout (stream 1) and 2> redirects stderr (stream 2). Both can be used on the same command.', 'Every program has three streams - stdin (0), stdout (1), stderr (2). Splitting them lets scripts keep errors in a log while passing clean data down a pipe.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '24fc0e64-cd84-52bf-b66a-43d0926f076d', updated_at = now()
WHERE id = '8fac3d77-167a-50ca-8617-771b36111113' AND published_version_id IS NULL;

-- Section: Chapter 4: Keys and Locks
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('ace77ee1-65f9-5db8-a581-1431f13b56fc', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 4: Keys and Locks', 4, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a675c34c-0a48-58af-87ad-010cc471a6b6', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'Users, Groups, Permissions and sudo', 'notes', 0, $md$> **Thursday.** Rhea is upset: "Someone read our database password last night. Tom's old deploy script was world-readable." Tom's note said *not everyone should have every key*. Today you learn who can open what on atlas.

## Users and groups

Every process runs as a **user**, and every file belongs to a **user** and a **group**. Linux checks those two facts on every single file access.

```bash
whoami              # your user name
id                  # uid=1001(labuser) gid=1001(labuser) groups=...
groups              # just the groups
who / w             # who is logged in right now
```

The staff register lives in three text files:

```
/etc/passwd   labuser:x:1001:1001:Lab User:/home/labuser:/bin/bash
               name  pw UID  GID  comment  home          shell
/etc/shadow   labuser:$y$j9T$...:19800:0:99999:7:::     (password hashes, root only)
/etc/group    baristas:x:2001:labuser,rhea              (group:pw:GID:members)
```

UID **0** is **root** - the superuser who bypasses permission checks. UIDs below 1000 are usually system accounts for services (`www-data`, `postgres`), which often have the shell `/usr/sbin/nologin` so nobody can log in as them.

Managing users (needs root):

```bash
sudo useradd -m -s /bin/bash -G baristas sam   # create user with home + group
sudo passwd sam                                # set password
sudo usermod -aG docker sam                    # ADD to a group (-a matters!)
sudo groupadd roasters                         # new group
sudo userdel -r sam                            # delete user and home
sudo chage -l sam                              # password ageing info
```

> **Memory hook:** `usermod -aG` - **a**ppend to **G**roups. Forget the `-a` and the user is *removed* from every other group. "**A**lways **a**ppend."

[[lab-task:1]]

## Reading permissions

```
 -rwxr-x---  1  rhea  baristas  512  Oct 14  deploy.sh
 |\_/\_/\_/     |     |
 | |  |  |      owner group
 | |  |  others: ---  nothing
 | |  group:     r-x  read + execute
 | owner:        rwx  read + write + execute
 type: - file, d directory, l symlink
```

| | On a file | On a directory |
|---|---|---|
| **r** | read the content | list the names inside (`ls`) |
| **w** | change the content | create, delete, rename entries |
| **x** | run it as a program | enter it (`cd`) and reach files inside |

Linux checks **one** class only: if you are the owner, owner bits apply; else if you are in the group, group bits; else others.

## chmod: changing the locks

Numbers: each class is a sum of **r=4, w=2, x=1**.

```
 7 = rwx   6 = rw-   5 = r-x   4 = r--   0 = ---

 chmod 755 script.sh     rwxr-xr-x   programs, directories
 chmod 644 notes.txt     rw-r--r--   normal files
 chmod 600 secret.key    rw-------   private keys, passwords
 chmod 700 ~/.ssh        rwx------   private directories
```

> **Memory hook:** **R**eal **W**izards e**X**ist: **4 - 2 - 1**. Add the wizards you want: read+write = 4+2 = 6.

Symbols are handy for small changes:

```bash
chmod u+x deploy.sh          # owner: add execute
chmod go-rwx secrets.env     # group & others: remove everything
chmod g=r deploy.sh          # group: exactly read
chmod -R g+w shared/         # recursive
```

`u` user/owner, `g` group, `o` others, `a` all.

[[lab-task:2]]

[[lab-task:3]]

What you should see:

```
$ ls -l keys
-rwxr----- 1 labuser labuser 15 ... deploy.sh
-rw------- 1 labuser labuser 21 ... secrets.env
```

## chown and chgrp: changing the owner

```bash
sudo chown rhea deploy.sh             # new owner
sudo chown rhea:baristas deploy.sh    # owner and group
sudo chown -R www-data:www-data /srv/shop   # whole tree, e.g. for the web server
chgrp baristas notes.txt              # group only (you must be in that group)
```

Only root can give a file away to another user - otherwise you could dodge disk quotas by "gifting" files.

## Special bits: SUID, SGID, sticky

| Bit | Value | On a file | On a directory | Looks like |
|---|---|---|---|---|
| SUID | 4000 | runs as the file's **owner** | - | `-rwsr-xr-x` |
| SGID | 2000 | runs as the file's group | new files inherit the dir's group | `drwxrwsr-x` |
| Sticky | 1000 | - | only the owner can delete their files | `drwxrwxrwt` |

`/usr/bin/passwd` is SUID root - that is how a normal user can update the root-only `/etc/shadow`. SUID binaries are a favourite attack target: `find / -perm -4000 2>/dev/null` lists them all.

> **Memory hook:** the **sticky** bit is **chewing gum on a locker** - anyone can put things in, but only you can take yours out. `/tmp` is the classic sticky directory.

[[lab-task:4]]

## umask: default permissions

New files start at `666`, new directories at `777`, then the **umask** removes bits:

```
  files:  666 - 022 = 644      directories: 777 - 022 = 755    (common default)
  files:  666 - 027 = 640      directories: 777 - 027 = 750    (safer)
  files:  666 - 077 = 600      directories: 777 - 077 = 700    (private)
```

```bash
umask           # show current (0022)
umask 027       # set for this shell; put it in ~/.bashrc to keep it
```

[[lab-task:5]]

## sudo: borrowing root's keys

Never log in as root for daily work. Use `sudo` for the one command that needs it:

```bash
sudo apt update              # run one command as root
sudo -i                      # root shell (be careful)
sudo -u postgres psql        # run as another user
sudo -l                      # what am I allowed to run?
sudo visudo                  # edit /etc/sudoers SAFELY (syntax-checked)
```

Who may use sudo is decided by `/etc/sudoers` and `/etc/sudoers.d/`. On Ubuntu, members of the `sudo` group get full access (`wheel` on RHEL/Fedora). Every sudo use is logged (`/var/log/auth.log`) - that is how Rhea will find out who read the password.

```
# /etc/sudoers.d/baristas
%baristas ALL=(ALL) /usr/bin/systemctl restart brewbot
#  who    host  as-whom   which command (only this one!)
```

**ACLs** go beyond owner/group/others when one extra person needs access:

```bash
setfacl -m u:sam:r secrets.env    # give sam read, nobody else changes
getfacl secrets.env               # a + at the end of ls -l means an ACL exists
```

> **End of day 4.** The deploy script is locked, secrets are 600, and new files are private by default. Rhea checks `/var/log/auth.log` and finds the culprit: a forgotten test account. Tom's next note was taped under a desk: "Atlas is never doing just one thing."
$md$, 50, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('598576e4-b7c4-5a9d-9bef-83dfe9c66470', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'a675c34c-0a48-58af-87ad-010cc471a6b6', 'module', 'Users, Groups, Permissions and sudo', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
rm -rf $w/keys $w/answers
mkdir -p $w/answers
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed' AND id NOT IN ('a7132b41-aeee-5df6-aacb-4fa97efafbbe', '6dd9579d-1a7a-5fb5-9fae-acdff2369637', '7d7443e0-bd97-5db6-bc3f-20181326e47f', '69c98ab3-e74f-5d37-aa50-db876a8bf65c', 'a2de368a-135c-58c7-932e-c1b7312a8af9');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed';
DELETE FROM lab_tasks WHERE lab_id = '598576e4-b7c4-5a9d-9bef-83dfe9c66470' AND id NOT IN ('05829d63-f443-57a2-ac89-e4c9f90e5022', 'ec14c71d-3444-5b1a-9fec-75d48cfe11e9', '3f389c90-9e39-59b5-a462-03670f957f63', '01566597-6b21-56c7-aa75-defae5ae6f5c', 'eb16d62d-851c-5c61-be37-c5e05baa43ff');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '598576e4-b7c4-5a9d-9bef-83dfe9c66470';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('05829d63-f443-57a2-ac89-e4c9f90e5022', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 1, 'Read the staff register', $md$Using /etc/passwd, save labuser's numeric UID and login shell, separated by one space, into answers/passwd-check.txt - for example "1234 /bin/sh".$md$, $script$want="$(id -u labuser) $(getent passwd labuser | cut -d: -f7)"
[ "$(head -1 /home/labuser/work/answers/passwd-check.txt | tr -s ' ' | sed 's/ *$//')" = "$want" ]
$script$, 'grep ''^labuser:'' /etc/passwd shows the line. Field 3 is the UID and field 7 is the shell - awk -F: ''{print $3, $7}'' prints both.', '/etc/passwd has seven colon-separated fields - name:x:UID:GID:comment:home:shell. The x means the password hash lives in the root-only /etc/shadow.', 25, false, true),
('ec14c71d-3444-5b1a-9fec-75d48cfe11e9', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 2, 'Lock the deploy script', $md$Create the directory /home/labuser/work/keys and inside it a file deploy.sh (any content). Give it permissions so the owner can read, write and execute, the group can only read, and others get nothing.$md$, $script$f=/home/labuser/work/keys/deploy.sh
[ -f $f ] && [ "$(stat -c %a $f)" = 740 ] && [ "$(stat -c %U $f)" = labuser ]
$script$, 'Add up r=4 w=2 x=1 for each of owner, group and others. rwx = 7, r-- = 4, --- = 0.', 'chmod 740 sets owner rwx (4+2+1), group r-- (4), others --- (0). ls -l shows it as -rwxr-----.', 20, false, true),
('3f389c90-9e39-59b5-a462-03670f957f63', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 3, 'Hide the secrets', $md$Create keys/secrets.env containing the line DB_PASSWORD=espresso and make it readable and writable by its owner only.$md$, $script$f=/home/labuser/work/keys/secrets.env
grep -qx 'DB_PASSWORD=espresso' $f && [ "$(stat -c %a $f)" = 600 ]
$script$, 'Owner rw- is 6, group and others nothing is 0. chmod 600 or chmod u=rw,go= both work.', 'Credentials files should be 600. SSH, database clients and many tools refuse to use a key or secret file that others can read.', 15, false, true),
('01566597-6b21-56c7-aa75-defae5ae6f5c', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 4, 'A shared drop box', $md$Create the directory keys/drop that everyone can write into, but where users can only delete their own files (the same behaviour as /tmp).$md$, $script$d=/home/labuser/work/keys/drop
[ -d $d ] && [ "$(stat -c %a $d)" = 1777 ]
$script$, 'Compare with ls -ld /tmp - the trailing t is the sticky bit. Its numeric value is 1000, so 777 plus sticky is 1777.', 'On a directory, the sticky bit (t) stops users from deleting or renaming files they do not own, even though the directory is world-writable. That is exactly how /tmp works.', 20, false, true),
('eb16d62d-851c-5c61-be37-c5e05baa43ff', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 5, 'Safer defaults for new files', $md$Set your umask to 027 permanently in ~/.bashrc, so new files are never readable by others.$md$, $script$[ "$(bash -ic umask 2>/dev/null)" = 0027 ]
$script$, 'Append the line umask 027 to ~/.bashrc. The umask lists the bits to REMOVE from the default 666 (files) / 777 (directories).', 'With umask 027, new files become 640 and new directories 750 - the group can read, others get nothing. Putting it in ~/.bashrc applies it to every new shell.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', '598576e4-b7c4-5a9d-9bef-83dfe9c66470', 1, $json$[{"id":"05829d63-f443-57a2-ac89-e4c9f90e5022","lab_id":"598576e4-b7c4-5a9d-9bef-83dfe9c66470","position":1,"title":"Read the staff register","description":"Using /etc/passwd, save labuser's numeric UID and login shell, separated by one space, into answers/passwd-check.txt - for example \"1234 /bin/sh\".","verification_script":"want=\"$(id -u labuser) $(getent passwd labuser | cut -d: -f7)\"\n[ \"$(head -1 /home/labuser/work/answers/passwd-check.txt | tr -s ' ' | sed 's/ *$//')\" = \"$want\" ]\n","hint_context":"grep '^labuser:' /etc/passwd shows the line. Field 3 is the UID and field 7 is the shell - awk -F: '{print $3, $7}' prints both.","explanation_context":"/etc/passwd has seven colon-separated fields - name:x:UID:GID:comment:home:shell. The x means the password hash lives in the root-only /etc/shadow.","points":25,"is_optional":false,"is_stateful":true},{"id":"ec14c71d-3444-5b1a-9fec-75d48cfe11e9","lab_id":"598576e4-b7c4-5a9d-9bef-83dfe9c66470","position":2,"title":"Lock the deploy script","description":"Create the directory /home/labuser/work/keys and inside it a file deploy.sh (any content). Give it permissions so the owner can read, write and execute, the group can only read, and others get nothing.","verification_script":"f=/home/labuser/work/keys/deploy.sh\n[ -f $f ] \u0026\u0026 [ \"$(stat -c %a $f)\" = 740 ] \u0026\u0026 [ \"$(stat -c %U $f)\" = labuser ]\n","hint_context":"Add up r=4 w=2 x=1 for each of owner, group and others. rwx = 7, r-- = 4, --- = 0.","explanation_context":"chmod 740 sets owner rwx (4+2+1), group r-- (4), others --- (0). ls -l shows it as -rwxr-----.","points":20,"is_optional":false,"is_stateful":true},{"id":"3f389c90-9e39-59b5-a462-03670f957f63","lab_id":"598576e4-b7c4-5a9d-9bef-83dfe9c66470","position":3,"title":"Hide the secrets","description":"Create keys/secrets.env containing the line DB_PASSWORD=espresso and make it readable and writable by its owner only.","verification_script":"f=/home/labuser/work/keys/secrets.env\ngrep -qx 'DB_PASSWORD=espresso' $f \u0026\u0026 [ \"$(stat -c %a $f)\" = 600 ]\n","hint_context":"Owner rw- is 6, group and others nothing is 0. chmod 600 or chmod u=rw,go= both work.","explanation_context":"Credentials files should be 600. SSH, database clients and many tools refuse to use a key or secret file that others can read.","points":15,"is_optional":false,"is_stateful":true},{"id":"01566597-6b21-56c7-aa75-defae5ae6f5c","lab_id":"598576e4-b7c4-5a9d-9bef-83dfe9c66470","position":4,"title":"A shared drop box","description":"Create the directory keys/drop that everyone can write into, but where users can only delete their own files (the same behaviour as /tmp).","verification_script":"d=/home/labuser/work/keys/drop\n[ -d $d ] \u0026\u0026 [ \"$(stat -c %a $d)\" = 1777 ]\n","hint_context":"Compare with ls -ld /tmp - the trailing t is the sticky bit. Its numeric value is 1000, so 777 plus sticky is 1777.","explanation_context":"On a directory, the sticky bit (t) stops users from deleting or renaming files they do not own, even though the directory is world-writable. That is exactly how /tmp works.","points":20,"is_optional":false,"is_stateful":true},{"id":"eb16d62d-851c-5c61-be37-c5e05baa43ff","lab_id":"598576e4-b7c4-5a9d-9bef-83dfe9c66470","position":5,"title":"Safer defaults for new files","description":"Set your umask to 027 permanently in ~/.bashrc, so new files are never readable by others.","verification_script":"[ \"$(bash -ic umask 2\u003e/dev/null)\" = 0027 ]\n","hint_context":"Append the line umask 027 to ~/.bashrc. The umask lists the bits to REMOVE from the default 666 (files) / 777 (directories).","explanation_context":"With umask 027, new files become 640 and new directories 750 - the group can read, others get nothing. Putting it in ~/.bashrc applies it to every new shell.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('a7132b41-aeee-5df6-aacb-4fa97efafbbe', 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', '05829d63-f443-57a2-ac89-e4c9f90e5022', 1, 'Read the staff register', $md$Using /etc/passwd, save labuser's numeric UID and login shell, separated by one space, into answers/passwd-check.txt - for example "1234 /bin/sh".$md$, $script$want="$(id -u labuser) $(getent passwd labuser | cut -d: -f7)"
[ "$(head -1 /home/labuser/work/answers/passwd-check.txt | tr -s ' ' | sed 's/ *$//')" = "$want" ]
$script$, 'grep ''^labuser:'' /etc/passwd shows the line. Field 3 is the UID and field 7 is the shell - awk -F: ''{print $3, $7}'' prints both.', '/etc/passwd has seven colon-separated fields - name:x:UID:GID:comment:home:shell. The x means the password hash lives in the root-only /etc/shadow.', 25, false, true),
('6dd9579d-1a7a-5fb5-9fae-acdff2369637', 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', 'ec14c71d-3444-5b1a-9fec-75d48cfe11e9', 2, 'Lock the deploy script', $md$Create the directory /home/labuser/work/keys and inside it a file deploy.sh (any content). Give it permissions so the owner can read, write and execute, the group can only read, and others get nothing.$md$, $script$f=/home/labuser/work/keys/deploy.sh
[ -f $f ] && [ "$(stat -c %a $f)" = 740 ] && [ "$(stat -c %U $f)" = labuser ]
$script$, 'Add up r=4 w=2 x=1 for each of owner, group and others. rwx = 7, r-- = 4, --- = 0.', 'chmod 740 sets owner rwx (4+2+1), group r-- (4), others --- (0). ls -l shows it as -rwxr-----.', 20, false, true),
('7d7443e0-bd97-5db6-bc3f-20181326e47f', 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', '3f389c90-9e39-59b5-a462-03670f957f63', 3, 'Hide the secrets', $md$Create keys/secrets.env containing the line DB_PASSWORD=espresso and make it readable and writable by its owner only.$md$, $script$f=/home/labuser/work/keys/secrets.env
grep -qx 'DB_PASSWORD=espresso' $f && [ "$(stat -c %a $f)" = 600 ]
$script$, 'Owner rw- is 6, group and others nothing is 0. chmod 600 or chmod u=rw,go= both work.', 'Credentials files should be 600. SSH, database clients and many tools refuse to use a key or secret file that others can read.', 15, false, true),
('69c98ab3-e74f-5d37-aa50-db876a8bf65c', 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', '01566597-6b21-56c7-aa75-defae5ae6f5c', 4, 'A shared drop box', $md$Create the directory keys/drop that everyone can write into, but where users can only delete their own files (the same behaviour as /tmp).$md$, $script$d=/home/labuser/work/keys/drop
[ -d $d ] && [ "$(stat -c %a $d)" = 1777 ]
$script$, 'Compare with ls -ld /tmp - the trailing t is the sticky bit. Its numeric value is 1000, so 777 plus sticky is 1777.', 'On a directory, the sticky bit (t) stops users from deleting or renaming files they do not own, even though the directory is world-writable. That is exactly how /tmp works.', 20, false, true),
('a2de368a-135c-58c7-932e-c1b7312a8af9', 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', 'eb16d62d-851c-5c61-be37-c5e05baa43ff', 5, 'Safer defaults for new files', $md$Set your umask to 027 permanently in ~/.bashrc, so new files are never readable by others.$md$, $script$[ "$(bash -ic umask 2>/dev/null)" = 0027 ]
$script$, 'Append the line umask 027 to ~/.bashrc. The umask lists the bits to REMOVE from the default 666 (files) / 777 (directories).', 'With umask 027, new files become 640 and new directories 750 - the group can read, others get nothing. Putting it in ~/.bashrc applies it to every new shell.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'acdf1861-3d00-5b64-ad7e-b0d9897ee7ed', updated_at = now()
WHERE id = '598576e4-b7c4-5a9d-9bef-83dfe9c66470' AND published_version_id IS NULL;

-- Section: Chapter 5: The Engine Room
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('ec8f752c-74df-5e68-b66e-b63f6f3212a5', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 5: The Engine Room', 5, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('231dac95-528c-5b9c-a5b1-e9236c5325f8', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'ec8f752c-74df-5e68-b66e-b63f6f3212a5', 'Processes, Jobs, Signals and Resources', 'notes', 0, $md$> **Friday morning.** Atlas feels slow. Rhea: "A server is never doing just one thing - right now it's running hundreds of programs. Find out who is using the engine." Welcome to the engine room.

## What a process is

A **program** is a file on disk (`/usr/bin/sleep`). A **process** is a running copy of it, with:

- a **PID** (process ID) and a **PPID** (its parent's PID)
- an owner (the user it runs as)
- memory, open files, a current directory, environment variables
- a **state**: `R` running, `S` sleeping (waiting), `D` uninterruptible (usually waiting on disk), `T` stopped, `Z` zombie

Every process is started by another one, forming a family tree. At the top is **PID 1** - on a real server that is **systemd**, the ancestor of everything.

```
systemd (1)
 |-- sshd (812)
 |    `-- sshd (2210) -- bash (2211) -- ps (2300)    <- you
 |-- nginx (901) --+-- nginx worker (902)
 |                 `-- nginx worker (903)
 `-- brewbot (1040)
```

```bash
ps                  # processes in this terminal
ps aux              # every process: USER PID %CPU %MEM ... COMMAND
ps -ef --forest     # tree view
pstree -p           # family tree with PIDs (if installed)
pgrep -a nginx      # find processes by name
pidof nginx         # just the PIDs
```

> **Memory hook:** the program is the **recipe**, the process is the **coffee being made** right now. One recipe, many cups - each with its own order number (PID).

[[lab-task:1]]

## Watching resources

```bash
top                 # live view: q quit, P sort by CPU, M by memory, k kill
htop                # friendlier top, if installed
uptime              # load average over 1, 5 and 15 minutes
free -h             # memory: total, used, free, available
vmstat 1            # CPU, memory, IO every second
nproc               # number of CPUs
```

Reading `uptime`:

```
 10:42:01 up 12 days,  3 users,  load average: 3.90, 2.10, 1.05
                                                1 min  5 min  15 min
```

The load average is the number of processes running or waiting. Compare it with `nproc`: **load 4 on 4 CPUs = fully busy**; load 8 on 4 CPUs = a queue is forming. Rising left-to-right numbers (1.05 -> 3.90) mean it is getting worse.

In `free -h`, look at **available**, not free - Linux uses spare memory as disk cache and gives it back when needed. "Free memory is wasted memory."

## Foreground, background and jobs

```bash
sleep 300           # foreground: the shell waits
Ctrl+Z              # suspend it (state T)
bg                  # resume it in the background
jobs                # list this shell's jobs: [1]+ Running sleep 300 &
fg %1               # bring job 1 back to the foreground
sleep 300 &         # start directly in the background
nohup ./backup.sh &         # survive terminal close (ignores SIGHUP)
```

For long work on remote servers use `tmux` or `screen`: they keep a whole session alive when your SSH connection drops.

[[lab-task:2]]

## Priorities: nice and renice

```
  -20 ......... 0 ......... 19
  greedy     default     polite
```

```bash
nice -n 10 ./backup.sh          # start with lower priority
renice -n 5 -p 1234             # change a running process
sudo renice -n -5 -p 1234       # only root may raise priority
```

> **Memory hook:** the **nicer** you are, the **longer** you wait in the queue. Root is the only one allowed to cut in line (negative nice).

[[lab-task:3]]

[[lab-task:4]]

What you should see:

```
$ ps -o pid,ni,cmd -C sleep
  PID  NI CMD
  412   5 sleep 3001
  418  15 sleep 3002
```

## Signals: talking to processes

A signal is a tiny message from the kernel or another process.

| Signal | Number | Meaning | Can be caught? |
|---|---|---|---|
| SIGHUP | 1 | terminal closed / "reload your config" | yes |
| SIGINT | 2 | Ctrl+C | yes |
| SIGKILL | 9 | die now | **no** |
| SIGTERM | 15 | please exit cleanly (default for `kill`) | yes |
| SIGSTOP | 19 | pause (Ctrl+Z sends SIGTSTP, 20) | no |
| SIGCONT | 18 | resume | yes |

```bash
kill 1234           # SIGTERM - polite
kill -9 1234        # SIGKILL - last resort, no cleanup
kill -HUP 1234      # many daemons (nginx) reload config on HUP
pkill -f brewbot    # by name / command line
killall nginx       # every process with that name
kill -l             # list all signals
```

> **Memory hook:** **15 asks, 9 insists.** "Fifteen is a friend, nine is the end." Always send 15, wait a few seconds, and use 9 only if the process ignores you - SIGKILL can leave half-written files and stale lock files behind.

**Zombies** (`Z`) are processes that have exited but whose parent never collected their exit status. They use no CPU or memory, only a PID slot. You cannot kill a zombie - it is already dead. Fix or restart the **parent**.

[[lab-task:5]]

## /proc: the live order screen

Every process is a directory in `/proc`:

```bash
ls /proc/1234/
cat /proc/1234/cmdline | tr '\0' ' '   # full command line
cat /proc/1234/status                  # state, memory, threads
ls -l /proc/1234/fd                    # open files
ls -l /proc/1234/cwd                   # current directory
cat /proc/loadavg /proc/meminfo        # system-wide numbers
```

Tools like `ps`, `top` and `free` are just reading these files for you.

> **End of day 5.** You found a forgotten backup job hogging the CPU, reniced it, and stopped an old worker politely. Rhea nods: "Good. Tonight you see who keeps atlas running while we sleep." Tom's note on the engine room door: "Services, logs, and the clock."
$md$, 45, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('f9596c0e-936d-5c50-9933-2993da793da8', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '231dac95-528c-5b9c-a5b1-e9236c5325f8', 'module', 'Processes, Jobs, Signals and Resources', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
rm -rf $w/answers
mkdir -p $w/answers
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7' AND id NOT IN ('6d1c21f6-4a8e-5578-987c-e62e31d3d789', 'd0f21ca6-61d6-55d5-9aa3-73977a90a7ad', 'cd501072-5eb2-525f-bdb8-edac90807b7b', '2c7bfa68-d9a4-59ff-a25c-e5a1c0ad63f3', '24b0a1f5-ea00-5816-b072-d591fd8b0441');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7';
DELETE FROM lab_tasks WHERE lab_id = 'f9596c0e-936d-5c50-9933-2993da793da8' AND id NOT IN ('4ec4bba8-6a8e-5dd7-93d9-d1e24855604c', 'd8b404c0-e4a0-5274-8856-f823bca13c8b', 'b51d2b45-4984-5a55-9f5a-1a53f0be9fb5', '7166209d-f6c1-5851-9731-67d8a0bb86e0', '4b7ee0eb-abba-5095-b910-71177f8280ac');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'f9596c0e-936d-5c50-9933-2993da793da8';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4ec4bba8-6a8e-5dd7-93d9-d1e24855604c', 'f9596c0e-936d-5c50-9933-2993da793da8', 1, 'Who is process number one?', $md$Look in /proc and save the name of the process with PID 1 into answers/pid1.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/pid1.txt)" = "$(cat /proc/1/comm)" ]
$script$, 'Every process has a directory /proc/PID. The file comm inside it holds the process name. ps -p 1 -o comm= works too.', 'PID 1 is the first process the kernel starts. On a full server it is systemd; inside a container it is whatever the image''s entrypoint is.', 15, false, true),
('d8b404c0-e4a0-5274-8856-f823bca13c8b', 'f9596c0e-936d-5c50-9933-2993da793da8', 2, 'A worker that survives logout', $md$Start the command sleep 3001 in the background so it keeps running even if your terminal is closed.$md$, $script$pgrep -u labuser -f '^sleep 3001$' >/dev/null
$script$, 'An ampersand at the end runs a command in the background. Prefix it with nohup so it ignores the hangup signal sent when the terminal closes.', 'When a terminal closes, its processes receive SIGHUP and usually die. nohup makes the process ignore SIGHUP and sends its output to nohup.out.', 20, false, true),
('b51d2b45-4984-5a55-9f5a-1a53f0be9fb5', 'f9596c0e-936d-5c50-9933-2993da793da8', 3, 'Run a low-priority job', $md$Start sleep 3002 in the background with a niceness of 15, so it only gets CPU time nobody else wants.$md$, $script$p=$(pgrep -u labuser -f '^sleep 3002$' | head -1)
[ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 15 ]
$script$, 'nice -n 15 COMMAND starts a command with niceness 15. Add an ampersand to background it.', 'Niceness runs from -20 (greedy) to 19 (polite). Higher niceness means lower priority. Normal users can only make processes nicer, never greedier.', 20, false, true),
('7166209d-f6c1-5851-9731-67d8a0bb86e0', 'f9596c0e-936d-5c50-9933-2993da793da8', 4, 'Change priority on the fly', $md$Without restarting it, change the niceness of the running sleep 3001 process to 5.$md$, $script$p=$(pgrep -u labuser -f '^sleep 3001$' | head -1)
[ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 5 ]
$script$, 'Find the PID with pgrep -f ''sleep 3001'' or ps aux | grep sleep, then renice -n 5 -p PID.', 'renice changes the priority of a process that is already running - handy when a backup job starts slowing down the web server.', 20, false, true),
('4b7ee0eb-abba-5095-b910-71177f8280ac', 'f9596c0e-936d-5c50-9933-2993da793da8', 5, 'Stop a process politely', $md$Stop the sleep 3002 process with the polite termination signal (not the forceful one), then save the number of the signal you sent into answers/signal.txt.$md$, $script$! pgrep -u labuser -f '^sleep 3002$' >/dev/null &&
[ "$(tr -d '[:space:]' < /home/labuser/work/answers/signal.txt)" = 15 ]
$script$, 'kill PID sends SIGTERM by default. kill -l lists every signal with its number.', 'SIGTERM (15) asks a process to clean up and exit. SIGKILL (9) cannot be caught - the kernel removes the process immediately, with no chance to save data. Always try 15 first.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', 'f9596c0e-936d-5c50-9933-2993da793da8', 1, $json$[{"id":"4ec4bba8-6a8e-5dd7-93d9-d1e24855604c","lab_id":"f9596c0e-936d-5c50-9933-2993da793da8","position":1,"title":"Who is process number one?","description":"Look in /proc and save the name of the process with PID 1 into answers/pid1.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/pid1.txt)\" = \"$(cat /proc/1/comm)\" ]\n","hint_context":"Every process has a directory /proc/PID. The file comm inside it holds the process name. ps -p 1 -o comm= works too.","explanation_context":"PID 1 is the first process the kernel starts. On a full server it is systemd; inside a container it is whatever the image's entrypoint is.","points":15,"is_optional":false,"is_stateful":true},{"id":"d8b404c0-e4a0-5274-8856-f823bca13c8b","lab_id":"f9596c0e-936d-5c50-9933-2993da793da8","position":2,"title":"A worker that survives logout","description":"Start the command sleep 3001 in the background so it keeps running even if your terminal is closed.","verification_script":"pgrep -u labuser -f '^sleep 3001$' \u003e/dev/null\n","hint_context":"An ampersand at the end runs a command in the background. Prefix it with nohup so it ignores the hangup signal sent when the terminal closes.","explanation_context":"When a terminal closes, its processes receive SIGHUP and usually die. nohup makes the process ignore SIGHUP and sends its output to nohup.out.","points":20,"is_optional":false,"is_stateful":true},{"id":"b51d2b45-4984-5a55-9f5a-1a53f0be9fb5","lab_id":"f9596c0e-936d-5c50-9933-2993da793da8","position":3,"title":"Run a low-priority job","description":"Start sleep 3002 in the background with a niceness of 15, so it only gets CPU time nobody else wants.","verification_script":"p=$(pgrep -u labuser -f '^sleep 3002$' | head -1)\n[ -n \"$p\" ] \u0026\u0026 [ \"$(ps -o ni= -p $p | tr -d ' ')\" = 15 ]\n","hint_context":"nice -n 15 COMMAND starts a command with niceness 15. Add an ampersand to background it.","explanation_context":"Niceness runs from -20 (greedy) to 19 (polite). Higher niceness means lower priority. Normal users can only make processes nicer, never greedier.","points":20,"is_optional":false,"is_stateful":true},{"id":"7166209d-f6c1-5851-9731-67d8a0bb86e0","lab_id":"f9596c0e-936d-5c50-9933-2993da793da8","position":4,"title":"Change priority on the fly","description":"Without restarting it, change the niceness of the running sleep 3001 process to 5.","verification_script":"p=$(pgrep -u labuser -f '^sleep 3001$' | head -1)\n[ -n \"$p\" ] \u0026\u0026 [ \"$(ps -o ni= -p $p | tr -d ' ')\" = 5 ]\n","hint_context":"Find the PID with pgrep -f 'sleep 3001' or ps aux | grep sleep, then renice -n 5 -p PID.","explanation_context":"renice changes the priority of a process that is already running - handy when a backup job starts slowing down the web server.","points":20,"is_optional":false,"is_stateful":true},{"id":"4b7ee0eb-abba-5095-b910-71177f8280ac","lab_id":"f9596c0e-936d-5c50-9933-2993da793da8","position":5,"title":"Stop a process politely","description":"Stop the sleep 3002 process with the polite termination signal (not the forceful one), then save the number of the signal you sent into answers/signal.txt.","verification_script":"! pgrep -u labuser -f '^sleep 3002$' \u003e/dev/null \u0026\u0026\n[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/signal.txt)\" = 15 ]\n","hint_context":"kill PID sends SIGTERM by default. kill -l lists every signal with its number.","explanation_context":"SIGTERM (15) asks a process to clean up and exit. SIGKILL (9) cannot be caught - the kernel removes the process immediately, with no chance to save data. Always try 15 first.","points":25,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('6d1c21f6-4a8e-5578-987c-e62e31d3d789', '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', '4ec4bba8-6a8e-5dd7-93d9-d1e24855604c', 1, 'Who is process number one?', $md$Look in /proc and save the name of the process with PID 1 into answers/pid1.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/pid1.txt)" = "$(cat /proc/1/comm)" ]
$script$, 'Every process has a directory /proc/PID. The file comm inside it holds the process name. ps -p 1 -o comm= works too.', 'PID 1 is the first process the kernel starts. On a full server it is systemd; inside a container it is whatever the image''s entrypoint is.', 15, false, true),
('d0f21ca6-61d6-55d5-9aa3-73977a90a7ad', '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', 'd8b404c0-e4a0-5274-8856-f823bca13c8b', 2, 'A worker that survives logout', $md$Start the command sleep 3001 in the background so it keeps running even if your terminal is closed.$md$, $script$pgrep -u labuser -f '^sleep 3001$' >/dev/null
$script$, 'An ampersand at the end runs a command in the background. Prefix it with nohup so it ignores the hangup signal sent when the terminal closes.', 'When a terminal closes, its processes receive SIGHUP and usually die. nohup makes the process ignore SIGHUP and sends its output to nohup.out.', 20, false, true),
('cd501072-5eb2-525f-bdb8-edac90807b7b', '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', 'b51d2b45-4984-5a55-9f5a-1a53f0be9fb5', 3, 'Run a low-priority job', $md$Start sleep 3002 in the background with a niceness of 15, so it only gets CPU time nobody else wants.$md$, $script$p=$(pgrep -u labuser -f '^sleep 3002$' | head -1)
[ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 15 ]
$script$, 'nice -n 15 COMMAND starts a command with niceness 15. Add an ampersand to background it.', 'Niceness runs from -20 (greedy) to 19 (polite). Higher niceness means lower priority. Normal users can only make processes nicer, never greedier.', 20, false, true),
('2c7bfa68-d9a4-59ff-a25c-e5a1c0ad63f3', '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', '7166209d-f6c1-5851-9731-67d8a0bb86e0', 4, 'Change priority on the fly', $md$Without restarting it, change the niceness of the running sleep 3001 process to 5.$md$, $script$p=$(pgrep -u labuser -f '^sleep 3001$' | head -1)
[ -n "$p" ] && [ "$(ps -o ni= -p $p | tr -d ' ')" = 5 ]
$script$, 'Find the PID with pgrep -f ''sleep 3001'' or ps aux | grep sleep, then renice -n 5 -p PID.', 'renice changes the priority of a process that is already running - handy when a backup job starts slowing down the web server.', 20, false, true),
('24b0a1f5-ea00-5816-b072-d591fd8b0441', '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', '4b7ee0eb-abba-5095-b910-71177f8280ac', 5, 'Stop a process politely', $md$Stop the sleep 3002 process with the polite termination signal (not the forceful one), then save the number of the signal you sent into answers/signal.txt.$md$, $script$! pgrep -u labuser -f '^sleep 3002$' >/dev/null &&
[ "$(tr -d '[:space:]' < /home/labuser/work/answers/signal.txt)" = 15 ]
$script$, 'kill PID sends SIGTERM by default. kill -l lists every signal with its number.', 'SIGTERM (15) asks a process to clean up and exit. SIGKILL (9) cannot be caught - the kernel removes the process immediately, with no chance to save data. Always try 15 first.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '7c7c2435-0a8e-5f4c-83be-b8f79c54e6e7', updated_at = now()
WHERE id = 'f9596c0e-936d-5c50-9933-2993da793da8' AND published_version_id IS NULL;

-- Section: Chapter 6: The Night Shift
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('1d2e633e-0589-50da-b212-4e9f881d0b3c', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 6: The Night Shift', 6, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e969cf2f-c441-5630-9036-2f68365cdbb8', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '1d2e633e-0589-50da-b212-4e9f881d0b3c', 'Boot, systemd Services, Logs, cron and Log Rotation', 'notes', 0, $md$> **Friday night, on call for the first time.** Your phone buzzes at 2:07am: *brewbot is down, no orders are coming in.* Tom's note said "services, logs, and the clock". Tonight you learn who starts programs on atlas, where they write their diary, and how atlas does chores on a schedule.

## How atlas boots

```
 power on
   |
 [1] BIOS / UEFI        checks hardware, finds a boot disk
   |
 [2] GRUB (bootloader)  menu, loads the kernel + initramfs from /boot
   |
 [3] Kernel             detects hardware, mounts the root filesystem
   |
 [4] systemd (PID 1)    starts every service in dependency order
   |
 [5] target reached     multi-user.target (server) or graphical.target (desktop)
   |
 login prompt
```

> **Memory hook:** "**B**ig **G**reen **K**ettles **S**team" - **B**IOS, **G**RUB, **K**ernel, **S**ystemd.

`dmesg` shows kernel messages from boot (hardware, drivers, disk errors). `systemd-analyze blame` shows which services slowed boot.

## systemd and systemctl

systemd is PID 1 and the manager of **units**. The most common unit types:

| Type | Example | What it is |
|---|---|---|
| `.service` | `nginx.service` | a program to keep running |
| `.timer` | `logrotate.timer` | a schedule (modern cron) |
| `.target` | `multi-user.target` | a group of units = a "boot state" |
| `.socket`, `.mount`, `.path` | | start on connection / mount / file change |

```bash
systemctl status brewbot          # running? last log lines? PID?
sudo systemctl start brewbot      # start now
sudo systemctl stop brewbot       # stop now
sudo systemctl restart brewbot    # stop + start
sudo systemctl reload nginx       # re-read config without dropping connections
sudo systemctl enable brewbot     # start at every boot
sudo systemctl enable --now brewbot   # enable AND start
sudo systemctl disable brewbot    # don't start at boot
systemctl is-active brewbot       # active / inactive / failed
systemctl list-units --failed     # what is broken right now?
sudo systemctl daemon-reload      # after editing a unit file
```

> **Memory hook:** **start** is *today*, **enable** is *every day*. A service can be started but not enabled (dies at reboot) or enabled but not started (runs from the next boot).

A unit file is a small INI file. Your own go in `/etc/systemd/system/`; package-provided ones live in `/lib/systemd/system/`.

```ini
# /etc/systemd/system/brewbot.service
[Unit]
Description=Orbit Coffee order bot
# start after networking is up
After=network.target

[Service]
ExecStart=/opt/brewbot/bin/brewbot
# never run apps as root
User=brewbot
# come back if it crashes
Restart=on-failure
Environment=PORT=8080

[Install]
# "enable" hooks it into normal boot
WantedBy=multi-user.target
```

Comments in unit files must be on their own line - systemd would treat `After=network.target # comment` as part of the value.

[[lab-task:1]]

## Logs: journalctl and /var/log

systemd's **journal** collects output from every service:

```bash
journalctl -u brewbot             # one unit's logs
journalctl -u brewbot -f          # follow live
journalctl -u brewbot --since "1 hour ago"
journalctl -p err -b              # errors (and worse) since this boot
journalctl -b -1                  # the previous boot (after a crash/reboot)
journalctl --disk-usage           # how big is the journal?
```

Classic text logs still live in `/var/log`:

| File | Contains |
|---|---|
| `/var/log/syslog` (Debian/Ubuntu) or `/var/log/messages` (RHEL) | general system log |
| `/var/log/auth.log` or `/var/log/secure` | logins, sudo, SSH |
| `/var/log/kern.log` | kernel |
| `/var/log/nginx/`, `/var/log/apache2/` | web servers |
| `/var/log/dpkg.log`, `/var/log/apt/` | package installs |

Log **priorities** from worst to mildest: `emerg, alert, crit, err, warning, notice, info, debug`.

> **Memory hook:** when a service is down, run the **two S's**: `systemctl status` (what state?) then `journalctl -u` (what did it say?). The answer is almost always in the last 20 lines.

[[lab-task:2]]

What you should see:

```
$ grep -E 'FATAL|counter|too quickly' night/journal.txt | tail -3
Oct 14 02:00:18 atlas brewbot[1071]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:18 atlas systemd[1]: brewbot.service: Scheduled restart job ...
Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Start request repeated too quickly.
```

At 2:15am you run `sudo chmod 640 /etc/brewbot/brewbot.conf && sudo chgrp brewbot /etc/brewbot/brewbot.conf`, then `sudo systemctl reset-failed brewbot && sudo systemctl start brewbot`. Orders flow again.

## cron: chores on a schedule

Each user has a crontab (`crontab -e` edits it, `crontab -l` lists it). System-wide jobs go in `/etc/crontab` and `/etc/cron.d/`, plus drop-in folders `/etc/cron.daily/`, `/etc/cron.weekly/`.

```
 .---------------- minute       (0-59)
 |  .------------- hour         (0-23)
 |  |  .---------- day of month (1-31)
 |  |  |  .------- month        (1-12)
 |  |  |  |  .---- day of week  (0-7, 0 and 7 = Sunday)
 |  |  |  |  |
 30 2  *  *  *   /opt/brewbot/backup.sh       every day at 02:30
 */15 * * * 1-5  /opt/brewbot/health.sh       every 15 min, Mon-Fri
 0  9  1  *  *   /opt/report.sh               9am on the 1st of each month
 @reboot         /opt/brewbot/warmup.sh       once at boot
```

> **Memory hook:** "**M**y **H**amster **D**rinks **M**ilk **W**eekly" - **M**inute, **H**our, **D**ay, **M**onth, **W**eekday.

Cron traps: jobs run with a **tiny PATH** (`/usr/bin:/bin`) and no `.bashrc`, so use full paths. Output is mailed or lost - redirect it: `... >> /var/log/backup.log 2>&1`. Check `grep CRON /var/log/syslog` to see if a job ran. `at 23:00` runs a one-off job; systemd **timers** are the modern alternative with logs in the journal.

[[lab-task:3]]

[[lab-task:4]]

## Log rotation

Logs grow forever unless something trims them. **logrotate** (run daily) renames `app.log` to `app.log.1`, compresses old ones, and deletes the oldest:

```
/var/log/brewbot/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

| Directive | Meaning |
|---|---|
| `daily` | rotate every day (or `weekly`, `monthly`, `size 100M`) |
| `rotate 7` | keep 7 old copies |
| `compress` | gzip old copies |
| `missingok` | no error if the log doesn't exist |
| `notifempty` | don't rotate an empty log |
| `copytruncate` | copy then empty the live file, for apps that can't reopen logs |

Configs live in `/etc/logrotate.d/`. Test one with `sudo logrotate -d /etc/logrotate.d/brewbot` (dry run).

[[lab-task:5]]

> **End of day 6.** Brewbot runs again and its logs will never fill the disk. Rhea, half asleep on the phone: "Nice work. Monday we're getting new disks - and we need some software installed." Tom's next note: "Know your storeroom."
$md$, 50, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('bf5b7a41-b247-574c-bc5b-499280eecbd8', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'e969cf2f-c441-5630-9036-2f68365cdbb8', 'module', 'Boot, systemd Services, Logs, cron and Log Rotation', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$mkdir -p /home/labuser/work
mkdir -p /home/labuser/work/night && chmod 777 /home/labuser/work/night
cat > /home/labuser/work/night/journal.txt <<'MFEOF'
Oct 14 02:00:01 atlas systemd[1]: Started cron.service - Regular background program processing daemon.
Oct 14 02:00:02 atlas systemd[1]: Started nginx.service - A high performance web server.
Oct 14 02:00:03 atlas systemd[1]: Starting brewbot.service - Orbit Coffee order bot...
Oct 14 02:00:03 atlas brewbot[1040]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:03 atlas systemd[1]: brewbot.service: Main process exited, code=exited, status=1/FAILURE
Oct 14 02:00:03 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
Oct 14 02:00:08 atlas systemd[1]: brewbot.service: Scheduled restart job, restart counter is at 1.
Oct 14 02:00:08 atlas brewbot[1051]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:08 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
Oct 14 02:00:13 atlas systemd[1]: brewbot.service: Scheduled restart job, restart counter is at 2.
Oct 14 02:00:13 atlas brewbot[1060]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:13 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
Oct 14 02:00:18 atlas systemd[1]: brewbot.service: Scheduled restart job, restart counter is at 3.
Oct 14 02:00:18 atlas brewbot[1071]: FATAL cannot open /etc/brewbot/brewbot.conf: Permission denied
Oct 14 02:00:18 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Start request repeated too quickly.
Oct 14 02:00:19 atlas systemd[1]: brewbot.service: Failed with result 'exit-code'.
Oct 14 02:00:19 atlas systemd[1]: Failed to start brewbot.service - Orbit Coffee order bot.
Oct 14 02:05:00 atlas CRON[1102]: (root) CMD (/usr/local/bin/sync-prices.sh)
Oct 14 02:30:00 atlas sshd[1120]: Accepted publickey for rhea from 10.0.0.7 port 51522 ssh2

MFEOF
chmod 666 /home/labuser/work/night/journal.txt
w=/home/labuser/work
rm -rf $w/units $w/cron $w/logrotate $w/answers
mkdir -p $w/answers
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570' AND id NOT IN ('11690a1d-d6e4-564b-80bf-75bc0dd102c4', '5d802c56-4119-5e53-8d5c-ab82dba75a18', 'b2cf88fd-35a0-55e7-a3da-386886e35869', 'd7074474-e5ad-5350-8df9-e963be0be9fa', '96fa4ea5-1b1b-5fbc-9e6f-9c3717575ed8');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570';
DELETE FROM lab_tasks WHERE lab_id = 'bf5b7a41-b247-574c-bc5b-499280eecbd8' AND id NOT IN ('4ea6e642-9cef-54b9-b472-34a884112377', '2a2bb681-8f25-5500-9806-588a57d96e8f', '15558316-5268-5690-bc10-94f2fbf741fe', 'b8bfe9e0-1dae-5ae3-876a-1e5ab4354317', 'e8aa0414-7f50-587b-a650-56e983fa7b04');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'bf5b7a41-b247-574c-bc5b-499280eecbd8';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4ea6e642-9cef-54b9-b472-34a884112377', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 1, 'Write brewbot''s unit file', $md$Create /home/labuser/work/units/brewbot.service. In a [Unit] section give it any Description and order it after network.target. In a [Service] section run /opt/brewbot/bin/brewbot as the user brewbot and restart it only when it fails. In an [Install] section make it start in the normal multi-user boot target.$md$, $script$f=/home/labuser/work/units/brewbot.service
grep -q '^\[Unit\]' $f && grep -q '^Description=..*' $f && grep -q '^After=.*network.target' $f &&
grep -q '^\[Service\]' $f && grep -q '^ExecStart=/opt/brewbot/bin/brewbot' $f &&
grep -q '^User=brewbot$' $f && grep -q '^Restart=on-failure$' $f &&
grep -q '^\[Install\]' $f && grep -q '^WantedBy=multi-user.target$' $f
$script$, 'Copy the unit file example from the lesson and adjust it. Keys are Description, After, ExecStart, User, Restart and WantedBy - one per line, no spaces around the equals sign.', 'After= orders startup, ExecStart= is the command, Restart=on-failure brings the service back when it crashes, and WantedBy=multi-user.target is what systemctl enable hooks into.', 25, false, true),
('2a2bb681-8f25-5500-9806-588a57d96e8f', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 2, 'What crashed at 2am?', $md$night/journal.txt is last night's journal. Save the name of the unit that failed to start (for example nginx.service) into answers/failed-unit.txt, and the highest restart counter systemd reached into answers/restarts.txt.$md$, $script$a=/home/labuser/work/answers
[ "$(tr -d '[:space:]' < $a/failed-unit.txt)" = brewbot.service ] &&
[ "$(tr -d '[:space:]' < $a/restarts.txt)" = 3 ]
$script$, 'grep -i fail night/journal.txt shows the failing unit. grep ''restart counter'' shows each restart; the last one has the highest number.', 'systemd restarted brewbot three times, then hit its start rate limit ("Start request repeated too quickly") and gave up. The real cause is on the brewbot line - Permission denied on its config file.', 25, false, true),
('15558316-5268-5690-bc10-94f2fbf741fe', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 3, 'Schedule the nightly backup', $md$Create /home/labuser/work/cron/brewbot.cron containing a crontab line that runs /opt/brewbot/backup.sh every day at 02:30.$md$, $script$awk '$6 == "/opt/brewbot/backup.sh" && $1 == "30" && ($2 == "2" || $2 == "02") && $3 == "*" && $4 == "*" && $5 == "*" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron
$script$, 'The five time fields are minute, hour, day of month, month, day of week. A star means every.', '30 2 * * * means minute 30 of hour 2, on every day of every month, any weekday.', 15, false, true),
('b8bfe9e0-1dae-5ae3-876a-1e5ab4354317', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 4, 'Health check on weekdays', $md$Add a second line to cron/brewbot.cron that runs /opt/brewbot/health.sh every 15 minutes, Monday to Friday only.$md$, $script$awk '$6 == "/opt/brewbot/health.sh" && $1 == "*/15" && $2 == "*" && $3 == "*" && $4 == "*" && $5 == "1-5" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron &&
grep -q backup.sh /home/labuser/work/cron/brewbot.cron
$script$, 'A step value */15 in the minute field means every 15 minutes. Day of week 1-5 is Monday to Friday (0 or 7 is Sunday). Use >> to append so the backup line stays.', '*/15 * * * 1-5 fires at :00, :15, :30 and :45 of every hour, only on weekdays.', 15, false, true),
('e8aa0414-7f50-587b-a650-56e983fa7b04', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 5, 'Stop the logs from eating the disk', $md$Create /home/labuser/work/logrotate/brewbot - a logrotate config for /var/log/brewbot/*.log that rotates daily, keeps 7 old copies, compresses them, does not complain if the log is missing, and skips empty logs.$md$, $script$f=/home/labuser/work/logrotate/brewbot
grep -q '^/var/log/brewbot/\*\.log *{' $f && grep -qw daily $f && grep -Eq '^\s*rotate\s+7\s*$' $f &&
grep -Eq '^\s*compress\s*$' $f && grep -qw missingok $f && grep -qw notifempty $f && grep -q '^}' $f
$script$, 'Use the logrotate example from the lesson - the path, then a block in braces with one directive per line - daily, rotate 7, compress, missingok, notifempty.', 'logrotate runs daily from cron or a systemd timer. Without it, a chatty log grows until the disk is full - one of the most common outages there is.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('d8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', 'bf5b7a41-b247-574c-bc5b-499280eecbd8', 1, $json$[{"id":"4ea6e642-9cef-54b9-b472-34a884112377","lab_id":"bf5b7a41-b247-574c-bc5b-499280eecbd8","position":1,"title":"Write brewbot's unit file","description":"Create /home/labuser/work/units/brewbot.service. In a [Unit] section give it any Description and order it after network.target. In a [Service] section run /opt/brewbot/bin/brewbot as the user brewbot and restart it only when it fails. In an [Install] section make it start in the normal multi-user boot target.","verification_script":"f=/home/labuser/work/units/brewbot.service\ngrep -q '^\\[Unit\\]' $f \u0026\u0026 grep -q '^Description=..*' $f \u0026\u0026 grep -q '^After=.*network.target' $f \u0026\u0026\ngrep -q '^\\[Service\\]' $f \u0026\u0026 grep -q '^ExecStart=/opt/brewbot/bin/brewbot' $f \u0026\u0026\ngrep -q '^User=brewbot$' $f \u0026\u0026 grep -q '^Restart=on-failure$' $f \u0026\u0026\ngrep -q '^\\[Install\\]' $f \u0026\u0026 grep -q '^WantedBy=multi-user.target$' $f\n","hint_context":"Copy the unit file example from the lesson and adjust it. Keys are Description, After, ExecStart, User, Restart and WantedBy - one per line, no spaces around the equals sign.","explanation_context":"After= orders startup, ExecStart= is the command, Restart=on-failure brings the service back when it crashes, and WantedBy=multi-user.target is what systemctl enable hooks into.","points":25,"is_optional":false,"is_stateful":true},{"id":"2a2bb681-8f25-5500-9806-588a57d96e8f","lab_id":"bf5b7a41-b247-574c-bc5b-499280eecbd8","position":2,"title":"What crashed at 2am?","description":"night/journal.txt is last night's journal. Save the name of the unit that failed to start (for example nginx.service) into answers/failed-unit.txt, and the highest restart counter systemd reached into answers/restarts.txt.","verification_script":"a=/home/labuser/work/answers\n[ \"$(tr -d '[:space:]' \u003c $a/failed-unit.txt)\" = brewbot.service ] \u0026\u0026\n[ \"$(tr -d '[:space:]' \u003c $a/restarts.txt)\" = 3 ]\n","hint_context":"grep -i fail night/journal.txt shows the failing unit. grep 'restart counter' shows each restart; the last one has the highest number.","explanation_context":"systemd restarted brewbot three times, then hit its start rate limit (\"Start request repeated too quickly\") and gave up. The real cause is on the brewbot line - Permission denied on its config file.","points":25,"is_optional":false,"is_stateful":true},{"id":"15558316-5268-5690-bc10-94f2fbf741fe","lab_id":"bf5b7a41-b247-574c-bc5b-499280eecbd8","position":3,"title":"Schedule the nightly backup","description":"Create /home/labuser/work/cron/brewbot.cron containing a crontab line that runs /opt/brewbot/backup.sh every day at 02:30.","verification_script":"awk '$6 == \"/opt/brewbot/backup.sh\" \u0026\u0026 $1 == \"30\" \u0026\u0026 ($2 == \"2\" || $2 == \"02\") \u0026\u0026 $3 == \"*\" \u0026\u0026 $4 == \"*\" \u0026\u0026 $5 == \"*\" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron\n","hint_context":"The five time fields are minute, hour, day of month, month, day of week. A star means every.","explanation_context":"30 2 * * * means minute 30 of hour 2, on every day of every month, any weekday.","points":15,"is_optional":false,"is_stateful":true},{"id":"b8bfe9e0-1dae-5ae3-876a-1e5ab4354317","lab_id":"bf5b7a41-b247-574c-bc5b-499280eecbd8","position":4,"title":"Health check on weekdays","description":"Add a second line to cron/brewbot.cron that runs /opt/brewbot/health.sh every 15 minutes, Monday to Friday only.","verification_script":"awk '$6 == \"/opt/brewbot/health.sh\" \u0026\u0026 $1 == \"*/15\" \u0026\u0026 $2 == \"*\" \u0026\u0026 $3 == \"*\" \u0026\u0026 $4 == \"*\" \u0026\u0026 $5 == \"1-5\" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron \u0026\u0026\ngrep -q backup.sh /home/labuser/work/cron/brewbot.cron\n","hint_context":"A step value */15 in the minute field means every 15 minutes. Day of week 1-5 is Monday to Friday (0 or 7 is Sunday). Use \u003e\u003e to append so the backup line stays.","explanation_context":"*/15 * * * 1-5 fires at :00, :15, :30 and :45 of every hour, only on weekdays.","points":15,"is_optional":false,"is_stateful":true},{"id":"e8aa0414-7f50-587b-a650-56e983fa7b04","lab_id":"bf5b7a41-b247-574c-bc5b-499280eecbd8","position":5,"title":"Stop the logs from eating the disk","description":"Create /home/labuser/work/logrotate/brewbot - a logrotate config for /var/log/brewbot/*.log that rotates daily, keeps 7 old copies, compresses them, does not complain if the log is missing, and skips empty logs.","verification_script":"f=/home/labuser/work/logrotate/brewbot\ngrep -q '^/var/log/brewbot/\\*\\.log *{' $f \u0026\u0026 grep -qw daily $f \u0026\u0026 grep -Eq '^\\s*rotate\\s+7\\s*$' $f \u0026\u0026\ngrep -Eq '^\\s*compress\\s*$' $f \u0026\u0026 grep -qw missingok $f \u0026\u0026 grep -qw notifempty $f \u0026\u0026 grep -q '^}' $f\n","hint_context":"Use the logrotate example from the lesson - the path, then a block in braces with one directive per line - daily, rotate 7, compress, missingok, notifempty.","explanation_context":"logrotate runs daily from cron or a systemd timer. Without it, a chatty log grows until the disk is full - one of the most common outages there is.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('11690a1d-d6e4-564b-80bf-75bc0dd102c4', 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', '4ea6e642-9cef-54b9-b472-34a884112377', 1, 'Write brewbot''s unit file', $md$Create /home/labuser/work/units/brewbot.service. In a [Unit] section give it any Description and order it after network.target. In a [Service] section run /opt/brewbot/bin/brewbot as the user brewbot and restart it only when it fails. In an [Install] section make it start in the normal multi-user boot target.$md$, $script$f=/home/labuser/work/units/brewbot.service
grep -q '^\[Unit\]' $f && grep -q '^Description=..*' $f && grep -q '^After=.*network.target' $f &&
grep -q '^\[Service\]' $f && grep -q '^ExecStart=/opt/brewbot/bin/brewbot' $f &&
grep -q '^User=brewbot$' $f && grep -q '^Restart=on-failure$' $f &&
grep -q '^\[Install\]' $f && grep -q '^WantedBy=multi-user.target$' $f
$script$, 'Copy the unit file example from the lesson and adjust it. Keys are Description, After, ExecStart, User, Restart and WantedBy - one per line, no spaces around the equals sign.', 'After= orders startup, ExecStart= is the command, Restart=on-failure brings the service back when it crashes, and WantedBy=multi-user.target is what systemctl enable hooks into.', 25, false, true),
('5d802c56-4119-5e53-8d5c-ab82dba75a18', 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', '2a2bb681-8f25-5500-9806-588a57d96e8f', 2, 'What crashed at 2am?', $md$night/journal.txt is last night's journal. Save the name of the unit that failed to start (for example nginx.service) into answers/failed-unit.txt, and the highest restart counter systemd reached into answers/restarts.txt.$md$, $script$a=/home/labuser/work/answers
[ "$(tr -d '[:space:]' < $a/failed-unit.txt)" = brewbot.service ] &&
[ "$(tr -d '[:space:]' < $a/restarts.txt)" = 3 ]
$script$, 'grep -i fail night/journal.txt shows the failing unit. grep ''restart counter'' shows each restart; the last one has the highest number.', 'systemd restarted brewbot three times, then hit its start rate limit ("Start request repeated too quickly") and gave up. The real cause is on the brewbot line - Permission denied on its config file.', 25, false, true),
('b2cf88fd-35a0-55e7-a3da-386886e35869', 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', '15558316-5268-5690-bc10-94f2fbf741fe', 3, 'Schedule the nightly backup', $md$Create /home/labuser/work/cron/brewbot.cron containing a crontab line that runs /opt/brewbot/backup.sh every day at 02:30.$md$, $script$awk '$6 == "/opt/brewbot/backup.sh" && $1 == "30" && ($2 == "2" || $2 == "02") && $3 == "*" && $4 == "*" && $5 == "*" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron
$script$, 'The five time fields are minute, hour, day of month, month, day of week. A star means every.', '30 2 * * * means minute 30 of hour 2, on every day of every month, any weekday.', 15, false, true),
('d7074474-e5ad-5350-8df9-e963be0be9fa', 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', 'b8bfe9e0-1dae-5ae3-876a-1e5ab4354317', 4, 'Health check on weekdays', $md$Add a second line to cron/brewbot.cron that runs /opt/brewbot/health.sh every 15 minutes, Monday to Friday only.$md$, $script$awk '$6 == "/opt/brewbot/health.sh" && $1 == "*/15" && $2 == "*" && $3 == "*" && $4 == "*" && $5 == "1-5" {ok=1} END {exit !ok}' /home/labuser/work/cron/brewbot.cron &&
grep -q backup.sh /home/labuser/work/cron/brewbot.cron
$script$, 'A step value */15 in the minute field means every 15 minutes. Day of week 1-5 is Monday to Friday (0 or 7 is Sunday). Use >> to append so the backup line stays.', '*/15 * * * 1-5 fires at :00, :15, :30 and :45 of every hour, only on weekdays.', 15, false, true),
('96fa4ea5-1b1b-5fbc-9e6f-9c3717575ed8', 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', 'e8aa0414-7f50-587b-a650-56e983fa7b04', 5, 'Stop the logs from eating the disk', $md$Create /home/labuser/work/logrotate/brewbot - a logrotate config for /var/log/brewbot/*.log that rotates daily, keeps 7 old copies, compresses them, does not complain if the log is missing, and skips empty logs.$md$, $script$f=/home/labuser/work/logrotate/brewbot
grep -q '^/var/log/brewbot/\*\.log *{' $f && grep -qw daily $f && grep -Eq '^\s*rotate\s+7\s*$' $f &&
grep -Eq '^\s*compress\s*$' $f && grep -qw missingok $f && grep -qw notifempty $f && grep -q '^}' $f
$script$, 'Use the logrotate example from the lesson - the path, then a block in braces with one directive per line - daily, rotate 7, compress, missingok, notifempty.', 'logrotate runs daily from cron or a systemd timer. Without it, a chatty log grows until the disk is full - one of the most common outages there is.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'd8b3d0c3-601b-5aaa-9a60-f4e1fdbc3570', updated_at = now()
WHERE id = 'bf5b7a41-b247-574c-bc5b-499280eecbd8' AND published_version_id IS NULL;

-- Section: Chapter 7: The Storeroom
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 7: The Storeroom', 7, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('11b28bd9-4431-59fb-b0c4-9e422068f6cc', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', 'Packages, Disks, Filesystems, Mounts and Archives', 'notes', 0, $md$> **Monday, week 2.** A delivery of new disks arrives, and the dev team wants software installed. Rhea: "Before you install anything, know what's already in the storeroom - and never let a disk fill up silently." Tom's note: *know your storeroom*.

## Packages: installing software the right way

On Linux you rarely download installers from websites. You use the distro's **package manager**, which fetches signed packages from trusted repositories and handles dependencies.

| | Debian / Ubuntu | RHEL / Fedora / Rocky | Alpine |
|---|---|---|---|
| Package format | `.deb` | `.rpm` | `.apk` |
| High-level tool | `apt` | `dnf` (older: `yum`) | `apk` |
| Low-level tool | `dpkg` | `rpm` | - |

```bash
sudo apt update                  # refresh the list of available packages
sudo apt upgrade                 # upgrade everything installed
sudo apt install nginx           # install (+ dependencies)
sudo apt remove nginx            # remove, keep config files
sudo apt purge nginx             # remove including config
sudo apt autoremove              # remove dependencies nobody needs anymore
apt search redis                 # find packages
apt show nginx                   # details
dpkg -l | grep nginx             # is it installed? which version?
dpkg -L nginx                    # which files did it install?
dpkg -S /usr/sbin/nginx          # which package owns this file?
```

> **Memory hook:** `apt update` reads the **menu**, `apt upgrade` **orders** the new dishes. Always update before you install.

Repositories are listed in `/etc/apt/sources.list` and `/etc/apt/sources.list.d/`. Other ways software arrives: `snap`/`flatpak` (self-contained apps), language package managers (`pip`, `npm`), and compiling from source (`./configure && make && sudo make install`) - avoid that last one on servers when a package exists.

[[lab-task:1]]

[[lab-task:2]]

## Disks, partitions and filesystems

```
  /dev/sda            the whole first disk (SATA/SCSI/virtual)
  |-- /dev/sda1       partition 1  -> ext4  mounted at /boot
  `-- /dev/sda2       partition 2  -> ext4  mounted at /
  /dev/nvme0n1p1      NVMe disk 0, partition 1
  /dev/sdb            the new disk - not partitioned yet
```

```bash
lsblk               # disk and partition tree with mount points
lsblk -f            # plus filesystem types and UUIDs
df -h               # space used on each mounted filesystem
df -i               # INODES used - a disk can be "full" with space left!
du -sh /var/log     # size of one directory
du -sh /* 2>/dev/null | sort -h    # find the heavy top-level directories
free -h             # memory and swap
```

A filesystem organises a partition into files and directories: **ext4** (the Linux default), **xfs** (RHEL default, big files), **btrfs** (snapshots), **vfat** (USB sticks, EFI), **tmpfs** (in RAM).

> **Memory hook:** **df** = **d**isk **f**ree (how full is the whole shelf?). **du** = **d**isk **u**sage (how much does this box weigh?). Start with df, drill down with du.

[[lab-task:3]]

## Adding a new disk, step by step

```bash
sudo fdisk /dev/sdb                  # or parted: create partition sdb1
sudo mkfs.ext4 /dev/sdb1             # put a filesystem on it (ERASES it!)
sudo mkdir -p /srv/data
sudo mount /dev/sdb1 /srv/data       # attach it into the tree
df -h /srv/data
sudo umount /srv/data                # detach (nobody may be using it)
```

A `mount` is forgotten at reboot. To make it permanent, add a line to **/etc/fstab**:

```
# device                                    mountpoint  type  options   dump pass
UUID=3f2a9c1e-...                           /srv/data   ext4  defaults  0    2
```

Use the **UUID** (from `lsblk -f` or `blkid`), not `/dev/sdb1` - device names can change between boots. Test with `sudo mount -a` **before** rebooting: a broken fstab line can stop the server from booting.

**LVM** (Logical Volume Manager) adds a flexible layer: disks become *physical volumes*, pooled into a *volume group*, carved into *logical volumes* that can grow later (`lvextend -r`). **Swap** is disk space used as overflow memory (`swapon --show`).

## Archives and compression

```bash
tar -czf backup.tar.gz dir/       # create, gzip
tar -cJf backup.tar.xz dir/       # create, xz (smaller, slower)
tar -tzf backup.tar.gz            # list contents
tar -xzf backup.tar.gz            # extract here
tar -xzf backup.tar.gz -C /tmp    # extract somewhere else
gzip big.log  /  gunzip big.log.gz      # compress a single file
zip -r site.zip site/  /  unzip site.zip
```

> **Memory hook:** tar flags read like a sentence: **c**reate **z**ipped **f**ile, e**x**tract **z**ipped **f**ile, **t**ell me what is in the **z**ipped **f**ile.

[[lab-task:4]]

[[lab-task:5]]

What you should see:

```
$ tar -tzf delivery.tar.gz
delivery/
delivery/manifest.txt
delivery/invoice.txt
```

## Copying between places: rsync

```bash
rsync -av src/ /backup/src/             # copy only what changed
rsync -av --delete src/ /backup/src/    # also delete files removed from src
rsync -avz src/ user@host:/backup/src/  # over SSH, compressed
rsync -av --dry-run src/ dst/           # show what would happen
```

The trailing slash matters: `src/` means "the contents of src", `src` means "the directory src itself".

> **End of day 7.** The new disk is mounted by UUID, the storeroom is backed up, and the delivery is unpacked. Rhea: "Tomorrow the payment provider needs to reach brewbot. Learn how atlas talks to the world." Tom's note: "Every door has a number."
$md$, 50, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('50515b20-5794-5c5f-83ed-c0d96f5353b1', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '11b28bd9-4431-59fb-b0c4-9e422068f6cc', 'module', 'Packages, Disks, Filesystems, Mounts and Archives', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$w=/home/labuser/work
rm -rf $w/storeroom $w/backups $w/unpacked $w/answers $w/delivery.tar.gz
mkdir -p $w/storeroom/beans $w/storeroom/cups $w/storeroom/syrups $w/answers
head -c 3145728 /dev/urandom > $w/storeroom/beans/arabica.bin
head -c 204800 /dev/urandom > $w/storeroom/cups/paper.bin
head -c 1048576 /dev/urandom > $w/storeroom/syrups/vanilla.bin
t=$(mktemp -d)
mkdir -p $t/delivery
echo "20 bags arabica, 5 boxes cups, 3 bottles vanilla" > $t/delivery/manifest.txt
echo "paid" > $t/delivery/invoice.txt
tar -czf $w/delivery.tar.gz -C $t delivery
rm -rf $t
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '66ce2671-166b-51c5-9017-75b87e77f60e' AND id NOT IN ('b70801f1-c42e-5e7f-a27c-99564232c1c1', '4706ec9a-fc23-576b-b422-ec8c1ba46e00', '55ff6aa1-6f38-5beb-8363-d08e513fe2fb', '316e0a15-515a-5404-990e-dfb5ce9039e5', 'd8c63b7e-2443-5b3d-8b5a-a4bf5d94e724');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '66ce2671-166b-51c5-9017-75b87e77f60e';
DELETE FROM lab_tasks WHERE lab_id = '50515b20-5794-5c5f-83ed-c0d96f5353b1' AND id NOT IN ('7acb13d9-2540-590b-a259-a8a1fec74c29', '3bcb7d63-2da2-57d1-8a38-c43668065aa3', '6e44b33b-1608-5cef-97f9-904682b036c5', '4ba88926-3372-5910-b83e-af606d3d0ec3', '73cac90e-b532-5266-86ae-af99b62a29a2');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '50515b20-5794-5c5f-83ed-c0d96f5353b1';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('7acb13d9-2540-590b-a259-a8a1fec74c29', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 1, 'Which bash do we have?', $md$Use the Debian package tools to save the installed version of the bash package into answers/bash-version.txt (the version string only, for example 5.0-6ubuntu1).$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/bash-version.txt)" = "$(dpkg-query -W -f='${Version}' bash)" ]
$script$, 'dpkg -l bash shows it in a table; dpkg-query -W -f=''${Version}'' bash prints only the version.', 'dpkg is the low-level tool that knows every installed .deb package; apt sits on top of it and adds downloading and dependency resolution.', 15, false, true),
('3bcb7d63-2da2-57d1-8a38-c43668065aa3', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 2, 'Who installed this file?', $md$Find which package installed the file /usr/bin/jq and save just the package name into answers/jq-owner.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/jq-owner.txt)" = "$(dpkg -S /usr/bin/jq | cut -d: -f1)" ]
$script$, 'dpkg -S PATH searches installed packages for a file and prints package-name - path.', 'dpkg -S (search) maps a file back to its package, and dpkg -L PACKAGE does the reverse. On RHEL the same questions are rpm -qf FILE and rpm -ql PACKAGE.', 15, false, true),
('6e44b33b-1608-5cef-97f9-904682b036c5', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 3, 'Which shelf is heaviest?', $md$Save the name of the largest subdirectory of /home/labuser/work/storeroom (just the name, like cups) into answers/biggest-dir.txt.$md$, $script$want=$(du -s /home/labuser/work/storeroom/*/ | sort -n | tail -1 | awk '{print $2}' | xargs basename)
[ "$(tr -d '[:space:]' < /home/labuser/work/answers/biggest-dir.txt)" = "$want" ]
$script$, 'du -sh storeroom/* shows one total per subdirectory; pipe through sort -h to rank them.', 'du measures what files actually use on disk, df measures whole filesystems. When df says a disk is full, du -sh /* | sort -h is how you walk down to the culprit.', 20, false, true),
('4ba88926-3372-5910-b83e-af606d3d0ec3', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 4, 'Back up the storeroom', $md$Create the compressed archive /home/labuser/work/backups/storeroom.tar.gz containing the storeroom directory. Paths inside the archive must start with storeroom/ (not /home/...).$md$, $script$a=/home/labuser/work/backups/storeroom.tar.gz
gzip -t $a && tar -tzf $a | grep -q '^storeroom/beans/arabica.bin$' && ! tar -tzf $a | grep -q '^/\|^home/'
$script$, 'Run tar from inside /home/labuser/work so the paths are relative - tar -czf backups/storeroom.tar.gz storeroom. c create, z gzip, f file name.', 'tar stores paths exactly as you give them. Archiving a relative path means it can be extracted anywhere; tar -tzf lists the contents without extracting.', 25, false, true),
('73cac90e-b532-5266-86ae-af99b62a29a2', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 5, 'Unpack the delivery', $md$Extract /home/labuser/work/delivery.tar.gz into the directory /home/labuser/work/unpacked, so that unpacked/delivery/manifest.txt exists.$md$, $script$grep -q arabica /home/labuser/work/unpacked/delivery/manifest.txt
$script$, 'tar -xzf ARCHIVE -C DIR extracts into DIR (which must exist - mkdir it first). List first with tar -tzf to see what is inside.', 'x extracts, -C changes into a directory first. Always list an archive from a stranger before extracting it - it could contain absolute paths or overwrite your files.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('66ce2671-166b-51c5-9017-75b87e77f60e', '50515b20-5794-5c5f-83ed-c0d96f5353b1', 1, $json$[{"id":"7acb13d9-2540-590b-a259-a8a1fec74c29","lab_id":"50515b20-5794-5c5f-83ed-c0d96f5353b1","position":1,"title":"Which bash do we have?","description":"Use the Debian package tools to save the installed version of the bash package into answers/bash-version.txt (the version string only, for example 5.0-6ubuntu1).","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/bash-version.txt)\" = \"$(dpkg-query -W -f='${Version}' bash)\" ]\n","hint_context":"dpkg -l bash shows it in a table; dpkg-query -W -f='${Version}' bash prints only the version.","explanation_context":"dpkg is the low-level tool that knows every installed .deb package; apt sits on top of it and adds downloading and dependency resolution.","points":15,"is_optional":false,"is_stateful":true},{"id":"3bcb7d63-2da2-57d1-8a38-c43668065aa3","lab_id":"50515b20-5794-5c5f-83ed-c0d96f5353b1","position":2,"title":"Who installed this file?","description":"Find which package installed the file /usr/bin/jq and save just the package name into answers/jq-owner.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/jq-owner.txt)\" = \"$(dpkg -S /usr/bin/jq | cut -d: -f1)\" ]\n","hint_context":"dpkg -S PATH searches installed packages for a file and prints package-name - path.","explanation_context":"dpkg -S (search) maps a file back to its package, and dpkg -L PACKAGE does the reverse. On RHEL the same questions are rpm -qf FILE and rpm -ql PACKAGE.","points":15,"is_optional":false,"is_stateful":true},{"id":"6e44b33b-1608-5cef-97f9-904682b036c5","lab_id":"50515b20-5794-5c5f-83ed-c0d96f5353b1","position":3,"title":"Which shelf is heaviest?","description":"Save the name of the largest subdirectory of /home/labuser/work/storeroom (just the name, like cups) into answers/biggest-dir.txt.","verification_script":"want=$(du -s /home/labuser/work/storeroom/*/ | sort -n | tail -1 | awk '{print $2}' | xargs basename)\n[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/biggest-dir.txt)\" = \"$want\" ]\n","hint_context":"du -sh storeroom/* shows one total per subdirectory; pipe through sort -h to rank them.","explanation_context":"du measures what files actually use on disk, df measures whole filesystems. When df says a disk is full, du -sh /* | sort -h is how you walk down to the culprit.","points":20,"is_optional":false,"is_stateful":true},{"id":"4ba88926-3372-5910-b83e-af606d3d0ec3","lab_id":"50515b20-5794-5c5f-83ed-c0d96f5353b1","position":4,"title":"Back up the storeroom","description":"Create the compressed archive /home/labuser/work/backups/storeroom.tar.gz containing the storeroom directory. Paths inside the archive must start with storeroom/ (not /home/...).","verification_script":"a=/home/labuser/work/backups/storeroom.tar.gz\ngzip -t $a \u0026\u0026 tar -tzf $a | grep -q '^storeroom/beans/arabica.bin$' \u0026\u0026 ! tar -tzf $a | grep -q '^/\\|^home/'\n","hint_context":"Run tar from inside /home/labuser/work so the paths are relative - tar -czf backups/storeroom.tar.gz storeroom. c create, z gzip, f file name.","explanation_context":"tar stores paths exactly as you give them. Archiving a relative path means it can be extracted anywhere; tar -tzf lists the contents without extracting.","points":25,"is_optional":false,"is_stateful":true},{"id":"73cac90e-b532-5266-86ae-af99b62a29a2","lab_id":"50515b20-5794-5c5f-83ed-c0d96f5353b1","position":5,"title":"Unpack the delivery","description":"Extract /home/labuser/work/delivery.tar.gz into the directory /home/labuser/work/unpacked, so that unpacked/delivery/manifest.txt exists.","verification_script":"grep -q arabica /home/labuser/work/unpacked/delivery/manifest.txt\n","hint_context":"tar -xzf ARCHIVE -C DIR extracts into DIR (which must exist - mkdir it first). List first with tar -tzf to see what is inside.","explanation_context":"x extracts, -C changes into a directory first. Always list an archive from a stranger before extracting it - it could contain absolute paths or overwrite your files.","points":25,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('b70801f1-c42e-5e7f-a27c-99564232c1c1', '66ce2671-166b-51c5-9017-75b87e77f60e', '7acb13d9-2540-590b-a259-a8a1fec74c29', 1, 'Which bash do we have?', $md$Use the Debian package tools to save the installed version of the bash package into answers/bash-version.txt (the version string only, for example 5.0-6ubuntu1).$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/bash-version.txt)" = "$(dpkg-query -W -f='${Version}' bash)" ]
$script$, 'dpkg -l bash shows it in a table; dpkg-query -W -f=''${Version}'' bash prints only the version.', 'dpkg is the low-level tool that knows every installed .deb package; apt sits on top of it and adds downloading and dependency resolution.', 15, false, true),
('4706ec9a-fc23-576b-b422-ec8c1ba46e00', '66ce2671-166b-51c5-9017-75b87e77f60e', '3bcb7d63-2da2-57d1-8a38-c43668065aa3', 2, 'Who installed this file?', $md$Find which package installed the file /usr/bin/jq and save just the package name into answers/jq-owner.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/jq-owner.txt)" = "$(dpkg -S /usr/bin/jq | cut -d: -f1)" ]
$script$, 'dpkg -S PATH searches installed packages for a file and prints package-name - path.', 'dpkg -S (search) maps a file back to its package, and dpkg -L PACKAGE does the reverse. On RHEL the same questions are rpm -qf FILE and rpm -ql PACKAGE.', 15, false, true),
('55ff6aa1-6f38-5beb-8363-d08e513fe2fb', '66ce2671-166b-51c5-9017-75b87e77f60e', '6e44b33b-1608-5cef-97f9-904682b036c5', 3, 'Which shelf is heaviest?', $md$Save the name of the largest subdirectory of /home/labuser/work/storeroom (just the name, like cups) into answers/biggest-dir.txt.$md$, $script$want=$(du -s /home/labuser/work/storeroom/*/ | sort -n | tail -1 | awk '{print $2}' | xargs basename)
[ "$(tr -d '[:space:]' < /home/labuser/work/answers/biggest-dir.txt)" = "$want" ]
$script$, 'du -sh storeroom/* shows one total per subdirectory; pipe through sort -h to rank them.', 'du measures what files actually use on disk, df measures whole filesystems. When df says a disk is full, du -sh /* | sort -h is how you walk down to the culprit.', 20, false, true),
('316e0a15-515a-5404-990e-dfb5ce9039e5', '66ce2671-166b-51c5-9017-75b87e77f60e', '4ba88926-3372-5910-b83e-af606d3d0ec3', 4, 'Back up the storeroom', $md$Create the compressed archive /home/labuser/work/backups/storeroom.tar.gz containing the storeroom directory. Paths inside the archive must start with storeroom/ (not /home/...).$md$, $script$a=/home/labuser/work/backups/storeroom.tar.gz
gzip -t $a && tar -tzf $a | grep -q '^storeroom/beans/arabica.bin$' && ! tar -tzf $a | grep -q '^/\|^home/'
$script$, 'Run tar from inside /home/labuser/work so the paths are relative - tar -czf backups/storeroom.tar.gz storeroom. c create, z gzip, f file name.', 'tar stores paths exactly as you give them. Archiving a relative path means it can be extracted anywhere; tar -tzf lists the contents without extracting.', 25, false, true),
('d8c63b7e-2443-5b3d-8b5a-a4bf5d94e724', '66ce2671-166b-51c5-9017-75b87e77f60e', '73cac90e-b532-5266-86ae-af99b62a29a2', 5, 'Unpack the delivery', $md$Extract /home/labuser/work/delivery.tar.gz into the directory /home/labuser/work/unpacked, so that unpacked/delivery/manifest.txt exists.$md$, $script$grep -q arabica /home/labuser/work/unpacked/delivery/manifest.txt
$script$, 'tar -xzf ARCHIVE -C DIR extracts into DIR (which must exist - mkdir it first). List first with tar -tzf to see what is inside.', 'x extracts, -C changes into a directory first. Always list an archive from a stranger before extracting it - it could contain absolute paths or overwrite your files.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '66ce2671-166b-51c5-9017-75b87e77f60e', updated_at = now()
WHERE id = '50515b20-5794-5c5f-83ed-c0d96f5353b1' AND published_version_id IS NULL;

-- Section: Chapter 8: Talking to the World
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 8: Talking to the World', 8, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('05b5b666-8186-5ee0-86e5-aefff70dd17b', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'IP, Ports, DNS, curl, SSH and Firewalls', 'notes', 0, $md$> **Tuesday, week 2.** The payment provider emails: *we can't reach your server*. Rhea: "Before you blame them, prove atlas is listening. Every service has an address and a door number." Tom's note: *every door has a number*.

## Addresses and ports

```
   IP address = the building           port = the door
   10.0.0.42                            :443  (HTTPS)

   client 203.0.113.5:51522  ------>  atlas 10.0.0.42:443  (nginx)
```

| Address | Meaning |
|---|---|
| `127.0.0.1` / `::1` | **localhost** - this machine, traffic never leaves it |
| `10.x`, `172.16-31.x`, `192.168.x` | private networks (offices, clouds, home) |
| `0.0.0.0` (in "listening on") | every interface on this machine |
| `/24` in `10.0.0.0/24` | subnet mask: the first 24 bits are the network, 256 addresses |

Well-known ports - worth memorising:

| Port | Service | Port | Service |
|---|---|---|---|
| 22 | SSH | 443 | HTTPS |
| 25 | SMTP (mail) | 3306 | MySQL |
| 53 | DNS | 5432 | PostgreSQL |
| 80 | HTTP | 6379 | Redis |

Ports below 1024 are **privileged**: only root can listen on them. That is why apps often listen on 8080 behind nginx on 80/443.

> **Memory hook:** the IP is the **street address of the café**, the port is **which door** - front door 80 for walk-ins, the locked side door 22 for staff (SSH).

## Inspecting the network

```bash
ip a                     # interfaces and their IP addresses (old: ifconfig)
ip r                     # routing table - "default via 10.0.0.1" is the gateway
ss -tulpn                # listening TCP/UDP ports and which process owns them
ss -tn                   # current TCP connections
ping -c 3 10.0.0.1       # is the host reachable? (ICMP, may be blocked)
traceroute example.com   # every hop on the way (or tracepath / mtr)
hostname -I              # this machine's IPs
```

`ss -tulpn` is the most useful networking command on a server:

```
Netid State  Local Address:Port  Process
tcp   LISTEN 0.0.0.0:22          users:(("sshd",pid=812))
tcp   LISTEN 127.0.0.1:8080      users:(("brewbot",pid=1040))
tcp   LISTEN 0.0.0.0:443         users:(("nginx",pid=901))
```

Note `127.0.0.1:8080` - brewbot only listens on localhost, so nobody outside can reach it directly. That is correct here (nginx forwards to it), but it is also the number one reason for "the app runs but I can't connect".

## Talking HTTP with curl

```bash
curl http://localhost:8080/             # GET, print the body
curl -I https://orbit.coffee            # headers only
curl -v https://orbit.coffee            # verbose: DNS, TLS, request, response
curl -s URL | jq .                      # quiet + pretty JSON
curl -X POST -H 'Content-Type: application/json' -d '{"qty":2}' URL
curl -o file.tar.gz URL                 # save to a file (or wget URL)
curl -sf URL || echo "DOWN"             # -f: fail on HTTP errors, great in scripts
```

[[lab-task:1]]

[[lab-task:2]]

What you should see:

```
$ curl -I http://localhost:8080/
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.12.x
Content-type: text/html
...
```

[[lab-task:3]]

## DNS: names to numbers

```
 orbit.coffee  --->  resolver (/etc/resolv.conf)  --->  203.0.113.10
```

```bash
dig orbit.coffee +short       # ask DNS (or: nslookup, host)
dig MX orbit.coffee           # mail servers
getent hosts orbit.coffee     # resolve the way programs do (includes /etc/hosts)
cat /etc/resolv.conf          # which DNS server this machine asks
cat /etc/hosts                # local overrides, checked BEFORE DNS
```

`/etc/hosts` lets you pin a name to an IP on one machine - great for testing a new server before switching DNS:

```
127.0.0.1   localhost
10.0.0.42   atlas atlas.internal
```

> **Memory hook:** "**It's always DNS.**" When a name fails but the IP works, the problem is name resolution, not the network.

## SSH: the staff door

```bash
ssh deploy@10.0.0.42                 # log in
ssh -p 2222 deploy@10.0.0.42         # non-standard port
ssh-keygen -t ed25519 -C "you@orbit" # make a key pair: private + .pub
ssh-copy-id deploy@10.0.0.42         # install your public key on the server
scp backup.tar.gz deploy@atlas:/tmp/ # copy a file over SSH
ssh -L 5432:localhost:5432 atlas     # tunnel: reach atlas's DB on your localhost:5432
```

Key-based login: your **private key** (`~/.ssh/id_ed25519`) never leaves your laptop; the **public key** goes into the server's `~/.ssh/authorized_keys`.

> **Memory hook:** the public key is the **lock** you can hand out to every door; the private key is the **only key** - never copy it, never share it.

Permissions matter - SSH silently refuses keys if they are too open: `~/.ssh` **700**, private key and `config` **600**, `authorized_keys` **600**.

A `~/.ssh/config` saves typing:

```
Host atlas
    HostName 10.0.0.42
    User deploy
    Port 2222
    IdentityFile ~/.ssh/atlas_ed25519
```

Now `ssh atlas` and `scp file atlas:/tmp/` just work.

[[lab-task:4]]

Hardening the server side (`/etc/ssh/sshd_config`, then `sudo systemctl reload ssh`): `PasswordAuthentication no`, `PermitRootLogin no`. Keep a second session open while you test - a typo can lock you out.

## Firewalls

```bash
sudo ufw status verbose          # Ubuntu's friendly firewall
sudo ufw allow 22/tcp            # ALWAYS allow SSH before enabling!
sudo ufw allow 443/tcp
sudo ufw allow from 10.0.0.0/24 to any port 5432    # DB only from the office
sudo ufw enable
sudo firewall-cmd --list-all     # RHEL's firewalld equivalent
sudo iptables -L -n              # the low-level rules underneath (nftables on newer systems)
```

Cloud servers have a second firewall outside the machine (security groups). "Connection timed out" usually means a firewall dropped it; "connection refused" means you reached the machine but nothing listens on that port.

> **Memory hook:** **refused = nobody home** (wrong port or service down). **timed out = the gate is locked** (firewall or routing).

> **End of day 8.** `ss -tulpn` showed brewbot listening on 127.0.0.1 only, and nginx's config had the wrong upstream port. One fix and the payment provider is happy. Rhea: "You're doing a lot of things by hand. Tomorrow - teach atlas to do them itself." Tom's note: "Lazy admins write scripts."
$md$, 50, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('c6764360-64ae-5f00-b5c1-1284857edd59', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '05b5b666-8186-5ee0-86e5-aefff70dd17b', 'module', 'IP, Ports, DNS, curl, SSH and Firewalls', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$mkdir -p /home/labuser/work
mkdir -p /home/labuser/work/site && chmod 777 /home/labuser/work/site
cat > /home/labuser/work/site/index.html <<'MFEOF'
<!doctype html>
<title>Orbit Coffee</title>
<h1>Orbit Coffee - fresh beans, roasted on atlas</h1>

MFEOF
chmod 666 /home/labuser/work/site/index.html
cat > /home/labuser/work/site/status.json <<'MFEOF'
{"service": "brewbot", "version": "2.4.1", "healthy": true, "orders_today": 128}

MFEOF
chmod 666 /home/labuser/work/site/status.json
w=/home/labuser/work
rm -rf $w/answers
mkdir -p $w/answers
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'a47bb5ca-ad33-5ed0-8073-791e40bc8528' AND id NOT IN ('01d41da1-b906-5a2a-9611-506ec83b7bc8', 'e781e94d-6f3e-5352-8ee4-942d46a25a8e', '6dab314a-0893-58b4-b906-1de5f8d99f06', '9ab214e9-e05b-5081-94ef-1c3b1831f85f');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'a47bb5ca-ad33-5ed0-8073-791e40bc8528';
DELETE FROM lab_tasks WHERE lab_id = 'c6764360-64ae-5f00-b5c1-1284857edd59' AND id NOT IN ('65c3b575-649a-51e1-9a03-c5aef17b7d51', '0302c7ee-54c2-5b9e-ad11-e55a6d467c33', '7767e693-9768-5ff4-9515-7da35cfa1ef6', 'cce6963a-26ee-5b63-a41d-d3170d60b899');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'c6764360-64ae-5f00-b5c1-1284857edd59';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('65c3b575-649a-51e1-9a03-c5aef17b7d51', 'c6764360-64ae-5f00-b5c1-1284857edd59', 1, 'Open the shop''s front door', $md$Serve the /home/labuser/work/site directory over HTTP on port 8080 using Python's built-in web server, running in the background so you keep your prompt.$md$, $script$curl -sf --max-time 3 http://localhost:8080/ | grep -q 'Orbit Coffee'
$script$, 'python3 -m http.server 8080 --directory /home/labuser/work/site serves a folder. Put nohup in front and an ampersand at the end to background it.', 'A server is just a process that listens on a port. localhost (127.0.0.1) is the loopback address - traffic that never leaves the machine.', 25, false, true),
('0302c7ee-54c2-5b9e-ad11-e55a6d467c33', 'c6764360-64ae-5f00-b5c1-1284857edd59', 2, 'Read the response headers', $md$Save only the HTTP response headers of http://localhost:8080/ into answers/headers.txt.$md$, $script$f=/home/labuser/work/answers/headers.txt
grep -q 'HTTP/1.[01] 200' $f && grep -qi '^Server: SimpleHTTP' $f && ! grep -q '<h1>' $f
$script$, 'curl -I sends a HEAD request and prints only the headers. Redirect the output with >.', 'Headers carry the status code, content type and server name. curl -I is the fastest way to ask "is it up, and what is answering?"', 20, false, true),
('7767e693-9768-5ff4-9515-7da35cfa1ef6', 'c6764360-64ae-5f00-b5c1-1284857edd59', 3, 'Ask the API a question', $md$Fetch http://localhost:8080/status.json with curl and use jq to extract only the version field. Save that value (no quotes) into answers/api-version.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/api-version.txt)" = 2.4.1 ]
$script$, 'curl -s URL | jq -r .version - the -s hides curl''s progress bar and jq -r prints raw text without quotes.', 'curl talks HTTP, jq slices JSON. Together they replace a browser for checking any API from a terminal.', 25, false, true),
('cce6963a-26ee-5b63-a41d-d3170d60b899', 'c6764360-64ae-5f00-b5c1-1284857edd59', 4, 'A shortcut for SSH', $md$Create ~/.ssh/config with a host entry named atlas that connects to the address 10.0.0.42 as the user deploy on port 2222, using the key file ~/.ssh/atlas_ed25519. The ~/.ssh directory must be accessible only by you (700) and the config file readable and writable only by you (600).$md$, $script$c=$HOME/.ssh/config
[ "$(stat -c %a $HOME/.ssh)" = 700 ] && [ "$(stat -c %a $c)" = 600 ] &&
grep -Eq '^\s*Host\s+atlas\s*$' $c && grep -Eiq '^\s*HostName\s+10\.0\.0\.42\s*$' $c &&
grep -Eiq '^\s*User\s+deploy\s*$' $c && grep -Eiq '^\s*Port\s+2222\s*$' $c &&
grep -Eiq '^\s*IdentityFile\s+~/\.ssh/atlas_ed25519\s*$' $c
$script$, 'One line Host atlas, then indented lines HostName, User, Port and IdentityFile. mkdir -p ~/.ssh, chmod 700 ~/.ssh, chmod 600 ~/.ssh/config.', 'With this entry, ssh atlas expands to ssh -i ~/.ssh/atlas_ed25519 -p 2222 deploy@10.0.0.42. SSH refuses keys and configs that other users can read or write.', 30, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('a47bb5ca-ad33-5ed0-8073-791e40bc8528', 'c6764360-64ae-5f00-b5c1-1284857edd59', 1, $json$[{"id":"65c3b575-649a-51e1-9a03-c5aef17b7d51","lab_id":"c6764360-64ae-5f00-b5c1-1284857edd59","position":1,"title":"Open the shop's front door","description":"Serve the /home/labuser/work/site directory over HTTP on port 8080 using Python's built-in web server, running in the background so you keep your prompt.","verification_script":"curl -sf --max-time 3 http://localhost:8080/ | grep -q 'Orbit Coffee'\n","hint_context":"python3 -m http.server 8080 --directory /home/labuser/work/site serves a folder. Put nohup in front and an ampersand at the end to background it.","explanation_context":"A server is just a process that listens on a port. localhost (127.0.0.1) is the loopback address - traffic that never leaves the machine.","points":25,"is_optional":false,"is_stateful":true},{"id":"0302c7ee-54c2-5b9e-ad11-e55a6d467c33","lab_id":"c6764360-64ae-5f00-b5c1-1284857edd59","position":2,"title":"Read the response headers","description":"Save only the HTTP response headers of http://localhost:8080/ into answers/headers.txt.","verification_script":"f=/home/labuser/work/answers/headers.txt\ngrep -q 'HTTP/1.[01] 200' $f \u0026\u0026 grep -qi '^Server: SimpleHTTP' $f \u0026\u0026 ! grep -q '\u003ch1\u003e' $f\n","hint_context":"curl -I sends a HEAD request and prints only the headers. Redirect the output with \u003e.","explanation_context":"Headers carry the status code, content type and server name. curl -I is the fastest way to ask \"is it up, and what is answering?\"","points":20,"is_optional":false,"is_stateful":true},{"id":"7767e693-9768-5ff4-9515-7da35cfa1ef6","lab_id":"c6764360-64ae-5f00-b5c1-1284857edd59","position":3,"title":"Ask the API a question","description":"Fetch http://localhost:8080/status.json with curl and use jq to extract only the version field. Save that value (no quotes) into answers/api-version.txt.","verification_script":"[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/answers/api-version.txt)\" = 2.4.1 ]\n","hint_context":"curl -s URL | jq -r .version - the -s hides curl's progress bar and jq -r prints raw text without quotes.","explanation_context":"curl talks HTTP, jq slices JSON. Together they replace a browser for checking any API from a terminal.","points":25,"is_optional":false,"is_stateful":true},{"id":"cce6963a-26ee-5b63-a41d-d3170d60b899","lab_id":"c6764360-64ae-5f00-b5c1-1284857edd59","position":4,"title":"A shortcut for SSH","description":"Create ~/.ssh/config with a host entry named atlas that connects to the address 10.0.0.42 as the user deploy on port 2222, using the key file ~/.ssh/atlas_ed25519. The ~/.ssh directory must be accessible only by you (700) and the config file readable and writable only by you (600).","verification_script":"c=$HOME/.ssh/config\n[ \"$(stat -c %a $HOME/.ssh)\" = 700 ] \u0026\u0026 [ \"$(stat -c %a $c)\" = 600 ] \u0026\u0026\ngrep -Eq '^\\s*Host\\s+atlas\\s*$' $c \u0026\u0026 grep -Eiq '^\\s*HostName\\s+10\\.0\\.0\\.42\\s*$' $c \u0026\u0026\ngrep -Eiq '^\\s*User\\s+deploy\\s*$' $c \u0026\u0026 grep -Eiq '^\\s*Port\\s+2222\\s*$' $c \u0026\u0026\ngrep -Eiq '^\\s*IdentityFile\\s+~/\\.ssh/atlas_ed25519\\s*$' $c\n","hint_context":"One line Host atlas, then indented lines HostName, User, Port and IdentityFile. mkdir -p ~/.ssh, chmod 700 ~/.ssh, chmod 600 ~/.ssh/config.","explanation_context":"With this entry, ssh atlas expands to ssh -i ~/.ssh/atlas_ed25519 -p 2222 deploy@10.0.0.42. SSH refuses keys and configs that other users can read or write.","points":30,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('01d41da1-b906-5a2a-9611-506ec83b7bc8', 'a47bb5ca-ad33-5ed0-8073-791e40bc8528', '65c3b575-649a-51e1-9a03-c5aef17b7d51', 1, 'Open the shop''s front door', $md$Serve the /home/labuser/work/site directory over HTTP on port 8080 using Python's built-in web server, running in the background so you keep your prompt.$md$, $script$curl -sf --max-time 3 http://localhost:8080/ | grep -q 'Orbit Coffee'
$script$, 'python3 -m http.server 8080 --directory /home/labuser/work/site serves a folder. Put nohup in front and an ampersand at the end to background it.', 'A server is just a process that listens on a port. localhost (127.0.0.1) is the loopback address - traffic that never leaves the machine.', 25, false, true),
('e781e94d-6f3e-5352-8ee4-942d46a25a8e', 'a47bb5ca-ad33-5ed0-8073-791e40bc8528', '0302c7ee-54c2-5b9e-ad11-e55a6d467c33', 2, 'Read the response headers', $md$Save only the HTTP response headers of http://localhost:8080/ into answers/headers.txt.$md$, $script$f=/home/labuser/work/answers/headers.txt
grep -q 'HTTP/1.[01] 200' $f && grep -qi '^Server: SimpleHTTP' $f && ! grep -q '<h1>' $f
$script$, 'curl -I sends a HEAD request and prints only the headers. Redirect the output with >.', 'Headers carry the status code, content type and server name. curl -I is the fastest way to ask "is it up, and what is answering?"', 20, false, true),
('6dab314a-0893-58b4-b906-1de5f8d99f06', 'a47bb5ca-ad33-5ed0-8073-791e40bc8528', '7767e693-9768-5ff4-9515-7da35cfa1ef6', 3, 'Ask the API a question', $md$Fetch http://localhost:8080/status.json with curl and use jq to extract only the version field. Save that value (no quotes) into answers/api-version.txt.$md$, $script$[ "$(tr -d '[:space:]' < /home/labuser/work/answers/api-version.txt)" = 2.4.1 ]
$script$, 'curl -s URL | jq -r .version - the -s hides curl''s progress bar and jq -r prints raw text without quotes.', 'curl talks HTTP, jq slices JSON. Together they replace a browser for checking any API from a terminal.', 25, false, true),
('9ab214e9-e05b-5081-94ef-1c3b1831f85f', 'a47bb5ca-ad33-5ed0-8073-791e40bc8528', 'cce6963a-26ee-5b63-a41d-d3170d60b899', 4, 'A shortcut for SSH', $md$Create ~/.ssh/config with a host entry named atlas that connects to the address 10.0.0.42 as the user deploy on port 2222, using the key file ~/.ssh/atlas_ed25519. The ~/.ssh directory must be accessible only by you (700) and the config file readable and writable only by you (600).$md$, $script$c=$HOME/.ssh/config
[ "$(stat -c %a $HOME/.ssh)" = 700 ] && [ "$(stat -c %a $c)" = 600 ] &&
grep -Eq '^\s*Host\s+atlas\s*$' $c && grep -Eiq '^\s*HostName\s+10\.0\.0\.42\s*$' $c &&
grep -Eiq '^\s*User\s+deploy\s*$' $c && grep -Eiq '^\s*Port\s+2222\s*$' $c &&
grep -Eiq '^\s*IdentityFile\s+~/\.ssh/atlas_ed25519\s*$' $c
$script$, 'One line Host atlas, then indented lines HostName, User, Port and IdentityFile. mkdir -p ~/.ssh, chmod 700 ~/.ssh, chmod 600 ~/.ssh/config.', 'With this entry, ssh atlas expands to ssh -i ~/.ssh/atlas_ed25519 -p 2222 deploy@10.0.0.42. SSH refuses keys and configs that other users can read or write.', 30, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'a47bb5ca-ad33-5ed0-8073-791e40bc8528', updated_at = now()
WHERE id = 'c6764360-64ae-5f00-b5c1-1284857edd59' AND published_version_id IS NULL;

-- Section: Chapter 9: Teaching Atlas Tricks
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 9: Teaching Atlas Tricks', 9, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('64a3a363-df99-5bae-aeba-0d274cc5bcd0', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', 'Bash Scripting - Variables, Conditions, Loops, Functions and Exit Codes', 'notes', 0, $md$> **Wednesday, week 2.** Rhea counts on her fingers: "You checked services by hand, made backups by hand, read logs by hand. Tom wrote on the whiteboard: *lazy admins write scripts*. Today atlas learns to do your chores." A script is just the commands you already know, saved in a file, plus a little logic.

## Anatomy of a script

```bash
#!/bin/bash
# greet.sh - say hello
set -euo pipefail

name="$1"
echo "Hello, $name!"
```

```bash
chmod +x greet.sh
./greet.sh Rhea          # run it (./ because the current dir is not in PATH)
bash greet.sh Rhea       # or hand it to bash directly
bash -x greet.sh Rhea    # debug: print every command before running it
```

- **Shebang** `#!/bin/bash` - line one tells the kernel which interpreter runs the file.
- **`set -euo pipefail`** - the safety belt: `-e` stop on the first failing command, `-u` error on unset variables, `-o pipefail` a pipeline fails if *any* part fails.

> **Memory hook:** "**E**very **U**nsafe **O**ption, **P**lease **F**ail" - put `set -euo pipefail` at the top of every script.

## Variables and quoting

```bash
shop="Orbit Coffee"          # no spaces around =
echo "$shop"                 # always quote: "$var"
echo "${shop}-backup"        # braces separate the name from text
today=$(date +%Y-%m-%d)      # command substitution: capture output
count=$((3 + 4))             # arithmetic
echo '$shop'                 # single quotes: NO expansion, prints $shop
port=${PORT:-8080}           # default value if PORT is unset or empty
```

Why quote? Without quotes, a value with spaces splits into several words: `rm $file` where `file="my notes.txt"` tries to delete `my` and `notes.txt`.

Special variables:

| Variable | Meaning |
|---|---|
| `$0` | script name |
| `$1`, `$2` ... | arguments |
| `$#` | number of arguments |
| `"$@"` | all arguments, each safely quoted |
| `$?` | exit status of the last command |
| `$$` | this script's PID |

## Loops

```bash
for n in 1 2 3; do echo "$n"; done
for n in {1..5}; do echo "Report $n" > "report-$n.txt"; done
for f in *.log; do gzip "$f"; done
for host in web1 web2 db1; do ssh "$host" uptime; done

while read -r name status; do        # read a file line by line
  echo "$name is $status"
done < services.txt

count=0
while [ $count -lt 3 ]; do count=$((count + 1)); done
```

[[lab-task:1]]

## Exit codes and conditions

Every command returns a number: **0 = success**, anything else = failure. `if` just checks that number.

```bash
if grep -q ERROR app.log; then
  echo "errors found"
elif [ -f app.log ]; then
  echo "clean log"
else
  echo "no log at all" >&2
  exit 1
fi

mkdir -p backups && echo "ready"     # && runs only on success
cd /srv/shop || exit 1               # || runs only on failure
```

Common tests inside `[ ]`:

| Test | True when |
|---|---|
| `-f path` / `-d path` / `-e path` | file / directory / anything exists |
| `-x path` / `-r path` / `-w path` | executable / readable / writable |
| `-z "$s"` / `-n "$s"` | string empty / not empty |
| `"$a" = "$b"` / `!=` | strings equal / differ |
| `$a -eq $b`, `-ne`, `-lt`, `-gt`, `-le`, `-ge` | number comparisons |

`[[ ]]` is bash's improved test: safer with empty variables, supports `&&`, `||` and pattern matching (`[[ $file == *.log ]]`).

> **Memory hook:** in the shell, **zero is a hero** - 0 means success, the opposite of most programming languages.

[[lab-task:2]]

## case and functions

```bash
case "$1" in
  start)   echo "starting" ;;
  stop)    echo "stopping" ;;
  *)       echo "Usage: $0 {start|stop}" >&2; exit 1 ;;
esac

log() {                               # a function
  echo "$(date +%T) $*" >> /var/log/brewbot-tools.log
}
is_up() {
  curl -sf --max-time 2 "http://localhost:$1/" >/dev/null   # its exit code is the result
}
if is_up 8080; then log "brewbot ok"; else log "brewbot DOWN"; fi
```

Inside a function, `$1` is the function's own first argument, and `local var=x` keeps a variable from leaking out.

[[lab-task:3]]

What you should see:

```
$ ./check-services.sh services.txt; echo "exit=$?"
ALERT: brewbot is stopped
ALERT: redis is failed
exit=2
```

## Making scripts robust

```bash
tmp=$(mktemp -d)                      # safe temp directory
trap 'rm -rf "$tmp"' EXIT             # clean up however the script ends
[ -d "$src" ] || { echo "no such dir: $src" >&2; exit 2; }
```

- Use **full paths** in anything cron runs.
- Send errors to **stderr** (`>&2`) and return **meaningful exit codes**.
- Run **`shellcheck script.sh`** - it catches unquoted variables and other classic bugs.
- Make scripts **idempotent**: running twice should be as safe as running once (`mkdir -p`, `ln -sf`).

[[lab-task:4]]

What you should see:

```
$ ./backup.sh /home/labuser/work/scripts /tmp/backups
/tmp/backups/scripts-20261014.tar.gz
```

> **End of day 9.** Atlas now checks its own services and backs itself up every night through cron. Rhea grins: "Good timing. Next week is Black Friday - our biggest sale of the year. You're on call for all of it." Tom's last note, stuck to the server rack: "When it breaks, stay calm and follow the method."
$md$, 55, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '64a3a363-df99-5bae-aeba-0d274cc5bcd0', 'module', 'Bash Scripting - Variables, Conditions, Loops, Functions and Exit Codes', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$mkdir -p /home/labuser/work
mkdir -p /home/labuser/work/scripts && chmod 777 /home/labuser/work/scripts
cat > /home/labuser/work/scripts/services.txt <<'MFEOF'
nginx running
brewbot stopped
postgres running
redis failed
cron running

MFEOF
chmod 666 /home/labuser/work/scripts/services.txt
rm -rf /home/labuser/work/scripts/reports /tmp/vb-src /tmp/vb-dest
$script$, NULL, 60, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '52bb484d-fd27-5861-861c-e0f1a4c6d641' AND id NOT IN ('851854b4-5edb-5760-86e5-a078f5f4672d', '20187e3c-bc71-5d45-b38c-e3acd611d333', 'f0e37c21-973f-507e-9e43-3ed1e59b2fb6', '9340dc4e-7314-5d54-b3ed-fa1bfdab3ec2');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '52bb484d-fd27-5861-861c-e0f1a4c6d641';
DELETE FROM lab_tasks WHERE lab_id = '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334' AND id NOT IN ('c5474ddd-1078-58de-bac2-b0a41d39c5f9', '9bc18c52-4bb1-57e0-b895-de397eeeaf8c', '448d095d-099e-5f3e-9b6d-dd9a03d44ed4', 'b389305a-d6a0-5c43-aba7-2ac0aac31735');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('c5474ddd-1078-58de-bac2-b0a41d39c5f9', '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', 1, 'Five reports with one loop', $md$Using a for loop at the prompt, create the directory /home/labuser/work/scripts/reports containing report-1.txt to report-5.txt, where each file holds one line "Report N" (Report 1, Report 2, ...).$md$, $script$d=/home/labuser/work/scripts/reports
for n in 1 2 3 4 5; do [ "$(cat $d/report-$n.txt)" = "Report $n" ] || exit 1; done
$script$, 'mkdir -p the directory, then: for n in 1 2 3 4 5; do echo "Report $n" > DIR/report-$n.txt; done - or use {1..5} instead of listing the numbers.', 'A for loop repeats a command for each word in a list. {1..5} is brace expansion that generates 1 2 3 4 5 before the loop even runs.', 15, false, true),
('9bc18c52-4bb1-57e0-b895-de397eeeaf8c', '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', 2, 'Your first real script', $md$Write the executable script /home/labuser/work/scripts/greet.sh. It must start with a bash shebang and have set -euo pipefail in its first lines. greet.sh Rhea prints exactly "Hello, Rhea! Welcome to Atlas.". Run with no argument, it prints a message containing the word Usage to stderr and exits with status 1.$md$, $script$s=/home/labuser/work/scripts/greet.sh
[ -x $s ] && head -1 $s | grep -q '^#!.*bash' && head -5 $s | grep -q 'set -euo pipefail' &&
[ "$($s Rhea)" = "Hello, Rhea! Welcome to Atlas." ] &&
[ -z "$($s 2>/dev/null)" ] && $s 2>&1 >/dev/null | grep -q Usage || exit 1
$s >/dev/null 2>&1; [ $? -eq 1 ]
$script$, 'Check the argument count with if [ $# -lt 1 ]. echo "..." >&2 writes to stderr, and exit 1 sets the status. Do not forget chmod +x.', '$# is the argument count and $1 the first argument. Errors go to stderr and a non-zero exit status, so callers and pipelines can tell success from failure.', 25, false, true),
('448d095d-099e-5f3e-9b6d-dd9a03d44ed4', '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', 3, 'A service watchdog', $md$Write the executable script /home/labuser/work/scripts/check-services.sh. It takes a file name as its argument, where each line is "NAME STATUS" (see scripts/services.txt). For every service whose status is not running it prints "ALERT: NAME is STATUS", in file order. Its exit status is the number of services that are not running (0 when everything is fine).$md$, $script$s=/home/labuser/work/scripts/check-services.sh
[ -x $s ] || exit 1
out=$($s /home/labuser/work/scripts/services.txt); rc=$?
[ $rc -eq 2 ] && [ "$out" = "$(printf 'ALERT: brewbot is stopped\nALERT: redis is failed')" ] || exit 1
printf 'a running\nb running\n' > /tmp/vb-ok.txt
out=$($s /tmp/vb-ok.txt); rc=$?
rm -f /tmp/vb-ok.txt
[ $rc -eq 0 ] && [ -z "$out" ]
$script$, 'while read -r name status; do ... done < "$1" reads the file line by line into two variables. Keep a counter with down=$((down + 1)) and finish with exit $down.', 'while read is the standard way to process a file line by line. Using the exit status as a count lets other tools (cron, monitoring) react without parsing the output.', 30, false, true),
('b389305a-d6a0-5c43-aba7-2ac0aac31735', '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', 4, 'The backup script Rhea asked for', $md$Write the executable script /home/labuser/work/scripts/backup.sh taking SRC_DIR and DEST_DIR. It creates DEST_DIR if needed and writes DEST_DIR/NAME-YYYYMMDD.tar.gz, where NAME is the last part of SRC_DIR and YYYYMMDD is today's date. If SRC_DIR is not an existing directory it prints an error to stderr and exits with status 2.$md$, $script$s=/home/labuser/work/scripts/backup.sh
[ -x $s ] || exit 1
rm -rf /tmp/vb-src /tmp/vb-dest && mkdir -p /tmp/vb-src && echo beans > /tmp/vb-src/a.txt
$s /tmp/vb-src /tmp/vb-dest >/dev/null 2>&1 || exit 1
f=/tmp/vb-dest/vb-src-$(date +%Y%m%d).tar.gz
[ -f $f ] && tar -tzf $f | grep -q 'a.txt' || exit 1
$s /tmp/no-such-dir /tmp/vb-dest >/dev/null 2>&1; rc=$?
rm -rf /tmp/vb-src /tmp/vb-dest
[ $rc -eq 2 ]
$script$, 'name=$(basename "$1") and today=$(date +%Y%m%d) build the file name. Test the source with if [ ! -d "$1" ]. tar -czf "$out" -C "$(dirname "$1")" "$name" keeps the paths short.', 'Command substitution $(...) captures a command''s output into a variable. Quoting every "$variable" keeps the script working when paths contain spaces.', 30, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('52bb484d-fd27-5861-861c-e0f1a4c6d641', '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334', 1, $json$[{"id":"c5474ddd-1078-58de-bac2-b0a41d39c5f9","lab_id":"85eb0f03-4f8b-50fe-8f6c-e3e2cd227334","position":1,"title":"Five reports with one loop","description":"Using a for loop at the prompt, create the directory /home/labuser/work/scripts/reports containing report-1.txt to report-5.txt, where each file holds one line \"Report N\" (Report 1, Report 2, ...).","verification_script":"d=/home/labuser/work/scripts/reports\nfor n in 1 2 3 4 5; do [ \"$(cat $d/report-$n.txt)\" = \"Report $n\" ] || exit 1; done\n","hint_context":"mkdir -p the directory, then: for n in 1 2 3 4 5; do echo \"Report $n\" \u003e DIR/report-$n.txt; done - or use {1..5} instead of listing the numbers.","explanation_context":"A for loop repeats a command for each word in a list. {1..5} is brace expansion that generates 1 2 3 4 5 before the loop even runs.","points":15,"is_optional":false,"is_stateful":true},{"id":"9bc18c52-4bb1-57e0-b895-de397eeeaf8c","lab_id":"85eb0f03-4f8b-50fe-8f6c-e3e2cd227334","position":2,"title":"Your first real script","description":"Write the executable script /home/labuser/work/scripts/greet.sh. It must start with a bash shebang and have set -euo pipefail in its first lines. greet.sh Rhea prints exactly \"Hello, Rhea! Welcome to Atlas.\". Run with no argument, it prints a message containing the word Usage to stderr and exits with status 1.","verification_script":"s=/home/labuser/work/scripts/greet.sh\n[ -x $s ] \u0026\u0026 head -1 $s | grep -q '^#!.*bash' \u0026\u0026 head -5 $s | grep -q 'set -euo pipefail' \u0026\u0026\n[ \"$($s Rhea)\" = \"Hello, Rhea! Welcome to Atlas.\" ] \u0026\u0026\n[ -z \"$($s 2\u003e/dev/null)\" ] \u0026\u0026 $s 2\u003e\u00261 \u003e/dev/null | grep -q Usage || exit 1\n$s \u003e/dev/null 2\u003e\u00261; [ $? -eq 1 ]\n","hint_context":"Check the argument count with if [ $# -lt 1 ]. echo \"...\" \u003e\u00262 writes to stderr, and exit 1 sets the status. Do not forget chmod +x.","explanation_context":"$# is the argument count and $1 the first argument. Errors go to stderr and a non-zero exit status, so callers and pipelines can tell success from failure.","points":25,"is_optional":false,"is_stateful":true},{"id":"448d095d-099e-5f3e-9b6d-dd9a03d44ed4","lab_id":"85eb0f03-4f8b-50fe-8f6c-e3e2cd227334","position":3,"title":"A service watchdog","description":"Write the executable script /home/labuser/work/scripts/check-services.sh. It takes a file name as its argument, where each line is \"NAME STATUS\" (see scripts/services.txt). For every service whose status is not running it prints \"ALERT: NAME is STATUS\", in file order. Its exit status is the number of services that are not running (0 when everything is fine).","verification_script":"s=/home/labuser/work/scripts/check-services.sh\n[ -x $s ] || exit 1\nout=$($s /home/labuser/work/scripts/services.txt); rc=$?\n[ $rc -eq 2 ] \u0026\u0026 [ \"$out\" = \"$(printf 'ALERT: brewbot is stopped\\nALERT: redis is failed')\" ] || exit 1\nprintf 'a running\\nb running\\n' \u003e /tmp/vb-ok.txt\nout=$($s /tmp/vb-ok.txt); rc=$?\nrm -f /tmp/vb-ok.txt\n[ $rc -eq 0 ] \u0026\u0026 [ -z \"$out\" ]\n","hint_context":"while read -r name status; do ... done \u003c \"$1\" reads the file line by line into two variables. Keep a counter with down=$((down + 1)) and finish with exit $down.","explanation_context":"while read is the standard way to process a file line by line. Using the exit status as a count lets other tools (cron, monitoring) react without parsing the output.","points":30,"is_optional":false,"is_stateful":true},{"id":"b389305a-d6a0-5c43-aba7-2ac0aac31735","lab_id":"85eb0f03-4f8b-50fe-8f6c-e3e2cd227334","position":4,"title":"The backup script Rhea asked for","description":"Write the executable script /home/labuser/work/scripts/backup.sh taking SRC_DIR and DEST_DIR. It creates DEST_DIR if needed and writes DEST_DIR/NAME-YYYYMMDD.tar.gz, where NAME is the last part of SRC_DIR and YYYYMMDD is today's date. If SRC_DIR is not an existing directory it prints an error to stderr and exits with status 2.","verification_script":"s=/home/labuser/work/scripts/backup.sh\n[ -x $s ] || exit 1\nrm -rf /tmp/vb-src /tmp/vb-dest \u0026\u0026 mkdir -p /tmp/vb-src \u0026\u0026 echo beans \u003e /tmp/vb-src/a.txt\n$s /tmp/vb-src /tmp/vb-dest \u003e/dev/null 2\u003e\u00261 || exit 1\nf=/tmp/vb-dest/vb-src-$(date +%Y%m%d).tar.gz\n[ -f $f ] \u0026\u0026 tar -tzf $f | grep -q 'a.txt' || exit 1\n$s /tmp/no-such-dir /tmp/vb-dest \u003e/dev/null 2\u003e\u00261; rc=$?\nrm -rf /tmp/vb-src /tmp/vb-dest\n[ $rc -eq 2 ]\n","hint_context":"name=$(basename \"$1\") and today=$(date +%Y%m%d) build the file name. Test the source with if [ ! -d \"$1\" ]. tar -czf \"$out\" -C \"$(dirname \"$1\")\" \"$name\" keeps the paths short.","explanation_context":"Command substitution $(...) captures a command's output into a variable. Quoting every \"$variable\" keeps the script working when paths contain spaces.","points":30,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('851854b4-5edb-5760-86e5-a078f5f4672d', '52bb484d-fd27-5861-861c-e0f1a4c6d641', 'c5474ddd-1078-58de-bac2-b0a41d39c5f9', 1, 'Five reports with one loop', $md$Using a for loop at the prompt, create the directory /home/labuser/work/scripts/reports containing report-1.txt to report-5.txt, where each file holds one line "Report N" (Report 1, Report 2, ...).$md$, $script$d=/home/labuser/work/scripts/reports
for n in 1 2 3 4 5; do [ "$(cat $d/report-$n.txt)" = "Report $n" ] || exit 1; done
$script$, 'mkdir -p the directory, then: for n in 1 2 3 4 5; do echo "Report $n" > DIR/report-$n.txt; done - or use {1..5} instead of listing the numbers.', 'A for loop repeats a command for each word in a list. {1..5} is brace expansion that generates 1 2 3 4 5 before the loop even runs.', 15, false, true),
('20187e3c-bc71-5d45-b38c-e3acd611d333', '52bb484d-fd27-5861-861c-e0f1a4c6d641', '9bc18c52-4bb1-57e0-b895-de397eeeaf8c', 2, 'Your first real script', $md$Write the executable script /home/labuser/work/scripts/greet.sh. It must start with a bash shebang and have set -euo pipefail in its first lines. greet.sh Rhea prints exactly "Hello, Rhea! Welcome to Atlas.". Run with no argument, it prints a message containing the word Usage to stderr and exits with status 1.$md$, $script$s=/home/labuser/work/scripts/greet.sh
[ -x $s ] && head -1 $s | grep -q '^#!.*bash' && head -5 $s | grep -q 'set -euo pipefail' &&
[ "$($s Rhea)" = "Hello, Rhea! Welcome to Atlas." ] &&
[ -z "$($s 2>/dev/null)" ] && $s 2>&1 >/dev/null | grep -q Usage || exit 1
$s >/dev/null 2>&1; [ $? -eq 1 ]
$script$, 'Check the argument count with if [ $# -lt 1 ]. echo "..." >&2 writes to stderr, and exit 1 sets the status. Do not forget chmod +x.', '$# is the argument count and $1 the first argument. Errors go to stderr and a non-zero exit status, so callers and pipelines can tell success from failure.', 25, false, true),
('f0e37c21-973f-507e-9e43-3ed1e59b2fb6', '52bb484d-fd27-5861-861c-e0f1a4c6d641', '448d095d-099e-5f3e-9b6d-dd9a03d44ed4', 3, 'A service watchdog', $md$Write the executable script /home/labuser/work/scripts/check-services.sh. It takes a file name as its argument, where each line is "NAME STATUS" (see scripts/services.txt). For every service whose status is not running it prints "ALERT: NAME is STATUS", in file order. Its exit status is the number of services that are not running (0 when everything is fine).$md$, $script$s=/home/labuser/work/scripts/check-services.sh
[ -x $s ] || exit 1
out=$($s /home/labuser/work/scripts/services.txt); rc=$?
[ $rc -eq 2 ] && [ "$out" = "$(printf 'ALERT: brewbot is stopped\nALERT: redis is failed')" ] || exit 1
printf 'a running\nb running\n' > /tmp/vb-ok.txt
out=$($s /tmp/vb-ok.txt); rc=$?
rm -f /tmp/vb-ok.txt
[ $rc -eq 0 ] && [ -z "$out" ]
$script$, 'while read -r name status; do ... done < "$1" reads the file line by line into two variables. Keep a counter with down=$((down + 1)) and finish with exit $down.', 'while read is the standard way to process a file line by line. Using the exit status as a count lets other tools (cron, monitoring) react without parsing the output.', 30, false, true),
('9340dc4e-7314-5d54-b3ed-fa1bfdab3ec2', '52bb484d-fd27-5861-861c-e0f1a4c6d641', 'b389305a-d6a0-5c43-aba7-2ac0aac31735', 4, 'The backup script Rhea asked for', $md$Write the executable script /home/labuser/work/scripts/backup.sh taking SRC_DIR and DEST_DIR. It creates DEST_DIR if needed and writes DEST_DIR/NAME-YYYYMMDD.tar.gz, where NAME is the last part of SRC_DIR and YYYYMMDD is today's date. If SRC_DIR is not an existing directory it prints an error to stderr and exits with status 2.$md$, $script$s=/home/labuser/work/scripts/backup.sh
[ -x $s ] || exit 1
rm -rf /tmp/vb-src /tmp/vb-dest && mkdir -p /tmp/vb-src && echo beans > /tmp/vb-src/a.txt
$s /tmp/vb-src /tmp/vb-dest >/dev/null 2>&1 || exit 1
f=/tmp/vb-dest/vb-src-$(date +%Y%m%d).tar.gz
[ -f $f ] && tar -tzf $f | grep -q 'a.txt' || exit 1
$s /tmp/no-such-dir /tmp/vb-dest >/dev/null 2>&1; rc=$?
rm -rf /tmp/vb-src /tmp/vb-dest
[ $rc -eq 2 ]
$script$, 'name=$(basename "$1") and today=$(date +%Y%m%d) build the file name. Test the source with if [ ! -d "$1" ]. tar -czf "$out" -C "$(dirname "$1")" "$name" keeps the paths short.', 'Command substitution $(...) captures a command''s output into a variable. Quoting every "$variable" keeps the script working when paths contain spaces.', 30, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '52bb484d-fd27-5861-861c-e0f1a4c6d641', updated_at = now()
WHERE id = '85eb0f03-4f8b-50fe-8f6c-e3e2cd227334' AND published_version_id IS NULL;

-- Section: Chapter 10: Incident Week
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('716c0129-f420-5354-9147-1d8b681dd59a', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Chapter 10: Incident Week', 10, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('99908f22-2062-52f6-88ad-daa4d7d1135f', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '716c0129-f420-5354-9147-1d8b681dd59a', 'Troubleshooting Real-World Scenarios', 'notes', 0, $md$> **Black Friday.** 9:02am. The sale went live two minutes ago and your pager is screaming: *disk 99% full, brewbot erroring, deploy failing.* Rhea is on a plane. Tom's last note is taped to the rack: **"When it breaks, stay calm and follow the method."** Everything you learned in chapters 1-9 now gets used at once.

## The method

Panicking and trying random fixes makes outages longer. Follow the same five steps every time:

```
 1. ERROR       read the exact error message - all of it
 2. RESOURCES   disk (df -h, df -i), memory (free -h), CPU/load (uptime, top)
 3. LOGS        systemctl status X, journalctl -u X, /var/log/*, dmesg
 4. PERMISSIONS ls -l, namei -l, id, who owns it, can this user reach it?
 5. CHANGES     what changed recently? deploys, config edits, updates, certs
```

> **Memory hook:** "**E**very **R**eal **L**inux **P**ro **C**hecks" - **E**rror, **R**esources, **L**ogs, **P**ermissions, **C**hanges.

And the first 60 seconds on any sick server:

```bash
uptime                 # load average - is it busy?
dmesg -T | tail        # kernel errors: OOM kills, disk errors
df -h; df -i           # space and inodes
free -h                # memory and swap
top                    # who is using CPU and memory?
systemctl --failed     # what is broken?
journalctl -p err -b   # errors since boot
ss -tulpn              # what is listening?
```

[[lab-task:1]]

## Scenario 1: "No space left on device"

**Symptom:** writes fail, services crash, `No space left on device` in logs.

```bash
df -h                                   # which filesystem is full?
sudo du -xh / 2>/dev/null | sort -h | tail -20   # -x stays on one filesystem
sudo find / -xdev -type f -size +500M 2>/dev/null
sudo journalctl --vacuum-size=200M      # shrink the journal
sudo apt clean                          # drop downloaded package files
```

**Fix:** empty or compress the giant log with `truncate -s 0 file` (not `rm` if a process has it open), delete old rotated logs and backups. **Prevent:** logrotate, monitoring alerts at 80%, separate `/var` partition.

[[lab-task:2]]

## Scenario 2: df says full, du says not

You deleted a 20 GB log but `df` still says 100%. A process still has the deleted file **open**, so the inode and its blocks live on.

```bash
sudo lsof +L1                  # open files with zero links (deleted)
sudo lsof | grep deleted
```

**Fix:** restart the process that holds it (`systemctl restart brewbot`), or truncate through `/proc`: `: > /proc/PID/fd/N`. **Lesson:** truncate logs, don't `rm` them while in use.

## Scenario 3: disk has space but writes fail - inodes

`df -h` shows 40% used, yet files cannot be created. **`df -i`** shows 100% IUse - millions of tiny files (sessions, cache, mail queue) used every inode.

```bash
df -i
sudo find /var -xdev -type f | cut -d/ -f2-3 | sort | uniq -c | sort -rn | head
```

**Fix:** delete the junk files (e.g. `find /var/lib/php/sessions -mtime +2 -delete`), fix the app that creates them.

## Scenario 4: a runaway or hung process

**Symptom:** server slow, one process at 100% CPU, or a worker that stopped doing anything.

```bash
top                            # press P (CPU) or M (memory)
ps aux --sort=-%cpu | head
pgrep -af brewbot-worker
kill PID; sleep 5; kill -9 PID # 15 first, 9 only if needed
```

**Prevent:** `Restart=on-failure` in the unit file, CPU limits (`CPUQuota=` in systemd), timeouts in the code.

[[lab-task:3]]

## Scenario 5: the OOM killer

**Symptom:** a process vanished with no error in its own log.

```bash
dmesg -T | grep -i -E 'killed process|out of memory'
journalctl -k | grep -i oom
free -h
```

When memory runs out the kernel's **OOM killer** kills the process with the highest score (usually the biggest). **Fix:** find the memory leak, add RAM or swap, set `MemoryMax=` on the service so it dies instead of the database.

## Scenario 6: high load, idle CPU - waiting on disk

`uptime` shows load 12 on 4 CPUs but `top` shows the CPU mostly idle. Look at `wa` (IO wait) in top's CPU line, and processes in state **`D`**.

```bash
top                       # %Cpu(s): ... 85.0 wa
vmstat 1                  # the "wa" and "b" (blocked) columns
iostat -x 1               # disk %util (sysstat package)
ps -eo state,pid,cmd | grep '^D'
```

Load counts processes **waiting**, not just computing. **Fix:** find the IO-heavy process (`iotop`), a slow or failing disk (`dmesg`), or a backup running at peak time (renice it, `ionice -c3`).

## Scenario 7: "Permission denied"

```bash
ls -l deploy.sh               # is the x bit set? who owns it?
namei -l /srv/shop/deploy.sh  # permissions of EVERY directory on the path
id                            # which user and groups am I?
mount | grep noexec           # is the filesystem mounted noexec?
```

**Fix:** `chmod u+x`, `chown` to the right user, add the user to the group (`usermod -aG`, then log in again), or run as the right user (`sudo -u www-data`). **Never** fix it with `chmod 777`.

[[lab-task:4]]

## Scenario 8: the service will not start

```bash
systemctl status brewbot            # state + last log lines
journalctl -u brewbot -n 50 --no-pager
sudo nginx -t                       # many programs validate their own config
sudo sshd -t
```

Usual causes: a typo in the config, a missing file, wrong permissions on a config or key, the port already in use, or a dependency (database) not up yet. **Fix one thing, validate, then restart.** If systemd gave up ("start request repeated too quickly"), run `systemctl reset-failed brewbot` first.

[[lab-task:5]]

## Scenario 9: "Address already in use"

```bash
sudo ss -tulpn | grep ':8080'       # who has the port?
sudo lsof -i :8080
```

Usually an old copy of the app is still running, or two services were configured with the same port. Stop the stray process or change one port.

## Scenario 10: "command not found"

```bash
echo $PATH
which brewctl ; type brewctl
ls -l /opt/brewbot/bin/
apt-file search bin/dig             # which package provides it? (or: dnf provides)
```

**Fix:** use the full path, add the directory to PATH in `~/.bashrc` (or `/etc/profile.d/` for everyone), or install the package. Under `sudo`, PATH is reset to `secure_path` - another common surprise.

[[lab-task:6]]

What you should see:

```
$ cd /tmp && brewctl status
brewbot: OK
```

## Scenario 11: cannot connect to a service

Work from the bottom up:

```
 1. is it running?          systemctl status brewbot
 2. is it listening?        ss -tulpn | grep 8080     (on 127.0.0.1 or 0.0.0.0?)
 3. works locally?          curl -v http://localhost:8080/
 4. reachable from outside? curl from another machine
 5. firewall?               sudo ufw status / cloud security group
```

- **Connection refused** - nothing is listening there (service down, wrong port, or bound to 127.0.0.1).
- **Connection timed out** - packets are dropped: firewall, security group, or routing.
- **502 Bad Gateway** from nginx - nginx is fine, the app behind it is not.

Time the request to separate "slow" from "down":

```bash
curl -o /dev/null -s -w "%{http_code} %{time_total}\n" http://localhost:8080/
```

Reading `ss -tulpn`: `t` TCP, `u` UDP, `l` listening only, `p` owning process, `n` numeric (no DNS lookups). And inside `top`: `P` sorts by CPU, `M` by memory, `k` kills a process.

An app inside a Docker container behaves the same way: if it binds `127.0.0.1` *inside* the container, the published port cannot reach it. Bind `0.0.0.0` in the container, then check `docker ps` for the port mapping.

[[lab-task:7]]

## Scenario 12: name resolution fails

`curl https://api.payments.example` fails, but `curl https://203.0.113.10` works.

```bash
dig api.payments.example +short
cat /etc/resolv.conf
getent hosts api.payments.example   # includes /etc/hosts
grep payments /etc/hosts            # a stale override?
```

**Fix:** correct the resolver, remove the stale `/etc/hosts` line, or wait out a DNS change (TTL). "It's always DNS."

## Scenario 13: SSH key refused

`Permission denied (publickey)`:

```bash
ssh -v deploy@atlas                     # client side: which keys were offered?
sudo tail -f /var/log/auth.log          # server side: why it refused
ls -ld ~ ~/.ssh ~/.ssh/authorized_keys  # home not group-writable, .ssh 700, keys 600
```

The usual cause is permissions that are too open on the server's `~/.ssh` or home directory, or the public key pasted into the wrong user's `authorized_keys`.

## Scenario 14: the cron job didn't run

```bash
grep CRON /var/log/syslog          # did cron even try?
crontab -l                         # is the line there, for the right user?
```

Cron runs with a minimal environment: use **full paths**, make the script **executable**, escape `%` (it means newline in crontab), and redirect output to a log (`>> /var/log/job.log 2>&1`) so failures are visible.

## Scenario 15: "Read-only file system"

The kernel remounts a filesystem read-only when it detects errors, to protect your data.

```bash
dmesg -T | grep -i -E 'ext4|i/o error|remount'
mount | grep ' / '                 # (ro, ...)
```

**Fix:** check the disk's health, schedule `fsck` on the unmounted filesystem (or from recovery mode for `/`), and restore from backup if the disk is failing. Do not just force a remount read-write.

## Scenario 16: TLS errors and wrong times

`certificate is not yet valid`, failing `apt update`, or confusing log timestamps - the clock is off.

```bash
timedatectl                        # is "System clock synchronized: yes"?
sudo timedatectl set-ntp true      # turn on NTP sync (systemd-timesyncd / chrony)
```

Also check that a certificate really has not expired: `echo | openssl s_client -connect orbit.coffee:443 2>/dev/null | openssl x509 -noout -dates`.

## Scenario 17: locked out of sudo

You broke `/etc/sudoers` or removed yourself from the sudo group. Never edit sudoers without `visudo` - it refuses to save a broken file. If it happens anyway: use another admin account, `pkexec visudo` on desktops, or boot into **recovery mode** (or the cloud provider's serial console) to fix it as root.

## Cheat sheet: symptom to first command

| Symptom | First command |
|---|---|
| No space left | `df -h`, then `du -xh / \| sort -h` |
| Full but nothing big | `lsof +L1` (deleted-open files), `df -i` (inodes) |
| Slow server | `uptime`, `top`, `vmstat 1` |
| Process vanished | `dmesg -T \| grep -i oom` |
| Permission denied | `ls -l`, `namei -l path`, `id` |
| Service down | `systemctl status X`, `journalctl -u X` |
| Port in use | `ss -tulpn \| grep :PORT` |
| Can't connect | `ss -tulpn`, `curl -v localhost`, firewall |
| Name doesn't resolve | `dig name`, `/etc/resolv.conf`, `/etc/hosts` |
| SSH refused | `ssh -v`, `/var/log/auth.log`, `~/.ssh` permissions |
| Cron didn't run | `grep CRON /var/log/syslog`, full paths |
| Read-only FS | `dmesg -T`, then fsck |
| command not found | `echo $PATH`, `which`, install package |

## The post-mortem

When the fire is out, write down: what happened, the timeline, the root cause, how it was fixed, and **what will stop it happening again** (a logrotate rule, an alert, a script). No blame - systems fail, people learn.

> **The end of Black Friday.** By 9:40am the disk was clear, the hung worker gone, the deploy shipped, brewbot back on port 8080, and the runbook command fixed. Orders hit a record. Rhea lands, reads your post-mortem, and pins Tom's notes to the wall - next to your name. You are atlas's admin now.
$md$, 60, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('02027500-659a-5c5f-b7dc-746a394f9083', '00000000-0000-0000-0000-000000000001', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '99908f22-2062-52f6-88ad-daa4d7d1135f', 'module', 'Troubleshooting Real-World Scenarios', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/start-incident.sh <<'MFEOF'
#!/bin/bash
# Opens Black Friday's incidents on atlas. Run once: bash ~/work/start-incident.sh
set -euo pipefail
w=/home/labuser/work/incident
mkdir -p $w/var/log/brewbot $w/bin $w/etc $w/app
head -c 31457280 /dev/zero > $w/var/log/brewbot/debug.log
printf '2026-11-27 09:00:01 INFO brewbot started\n2026-11-27 09:00:02 INFO accepting orders\n' > $w/var/log/brewbot/app.log
cat > $w/bin/brewbot-worker <<'EOF'
#!/bin/bash
while true; do sleep 60; done
EOF
cat > $w/deploy.sh <<'EOF'
#!/bin/bash
mkdir -p /home/labuser/work/incident/app
echo deployed > /home/labuser/work/incident/app/deployed.ok
echo "Deploy complete"
EOF
chmod 644 $w/deploy.sh
printf 'name = brewbot\nport = 80800\nworkers = 4\n' > $w/etc/brewbot.conf
cat > $w/bin/brewbot-check <<'EOF'
#!/bin/bash
conf=/home/labuser/work/incident/etc/brewbot.conf
p=$(awk -F' = ' '$1 == "port" {print $2}' $conf)
if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]; then
  echo "config OK"
else
  echo "ERROR: port '$p' out of range (1-65535) in $conf" >&2
  exit 1
fi
EOF
cat > $w/bin/brewctl <<'EOF'
#!/bin/bash
if [ "${1:-}" = status ]; then echo "brewbot: OK"; else echo "usage: brewctl status" >&2; exit 1; fi
EOF
chmod 755 $w/bin/brewbot-check $w/bin/brewctl $w/bin/brewbot-worker
mkdir -p $w/www
echo "brewbot storefront" > $w/www/index.html
printf 'name = brewbot-web\nbind = 127.0.0.1\nport = 8088\n' > $w/etc/brewbot-web.conf
cat > $w/bin/brewbot-web <<'EOF'
#!/bin/bash
w=/home/labuser/work/incident
bind=$(awk -F' = ' '$1 == "bind" {print $2}' $w/etc/brewbot-web.conf)
port=$(awk -F' = ' '$1 == "port" {print $2}' $w/etc/brewbot-web.conf)
cd $w/www && exec python3 -m http.server "$port" --bind "$bind"
EOF
chmod 755 $w/bin/brewbot-web
nohup bash $w/bin/brewbot-worker >/dev/null 2>&1 &
nohup $w/bin/brewbot-web >/dev/null 2>&1 &
touch $w/.incident-started
echo "PAGER: atlas disk 99% full, brewbot errors, deploy failing. Good luck."

MFEOF
chmod 666 /home/labuser/work/start-incident.sh
rm -rf /home/labuser/work/incident
$script$, NULL, 60, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '56fb8e99-6956-5184-941f-adca04839713' AND id NOT IN ('dd08f133-0057-5083-82e1-ce8b14f268ce', '7b440eb1-f1a2-5472-831e-fc75ccd6eaed', '656aa777-0dda-5b18-88b0-61a5c1baeef7', '4c2e41b7-c3d4-51f9-9cc5-82e172de974f', 'e9afd486-df8c-5904-8beb-65ebcd4882be', '7bc01984-42fc-53f5-9b65-6f820f6b467a', '61ca6c31-f89c-5fc0-809a-ebf875c49259');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '56fb8e99-6956-5184-941f-adca04839713';
DELETE FROM lab_tasks WHERE lab_id = '02027500-659a-5c5f-b7dc-746a394f9083' AND id NOT IN ('59d51559-b1c1-50b0-9c88-f107aa9ec3fe', '43921609-0e08-5541-81aa-fe6f0cfb9507', '2ae1e983-c29c-5e51-9c9d-3a645a5705a4', '8c913c34-26c0-534e-bc33-bf2ce52cf97d', '282c2039-0d42-5d80-862a-3699e38f165d', 'c584f42a-3760-5804-8293-80cf4b975feb', 'ba17fa69-87d0-5010-9ad0-b6601043582c');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '02027500-659a-5c5f-b7dc-746a394f9083';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('59d51559-b1c1-50b0-9c88-f107aa9ec3fe', '02027500-659a-5c5f-b7dc-746a394f9083', 1, 'The pager goes off', $md$Black Friday has started. Run bash /home/labuser/work/start-incident.sh once to open the incidents.$md$, $script$[ -f /home/labuser/work/incident/.incident-started ] &&
pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' >/dev/null
$script$, 'Type exactly bash /home/labuser/work/start-incident.sh and press Enter.', 'The script creates a full disk, a hung worker, a broken deploy, a bad config, a missing command and an unreachable web listener under ~/work/incident - one for each scenario that follows.', 10, false, true),
('43921609-0e08-5541-81aa-fe6f0cfb9507', '02027500-659a-5c5f-b7dc-746a394f9083', 2, 'Scenario 1 - the disk is full', $md$Something under /home/labuser/work/incident is eating the disk. Find the largest file and empty it to 0 bytes WITHOUT deleting it (pretend brewbot still has it open). Leave the other logs alone.$md$, $script$l=/home/labuser/work/incident/var/log/brewbot
[ -f $l/debug.log ] && [ ! -s $l/debug.log ] && [ -s $l/app.log ]
$script$, 'du -ah /home/labuser/work/incident | sort -h | tail finds the culprit. truncate -s 0 FILE or : > FILE empties it in place.', 'Deleting a log that a process still holds open frees nothing - the process keeps writing into the invisible inode. Truncating keeps the same inode and releases the space immediately.', 20, false, true),
('2ae1e983-c29c-5e51-9c9d-3a645a5705a4', '02027500-659a-5c5f-b7dc-746a394f9083', 3, 'Scenario 2 - a hung worker', $md$A stuck brewbot-worker process is running. Find it and stop it - politely first.$md$, $script$[ -f /home/labuser/work/incident/.incident-started ] &&
! pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' >/dev/null
$script$, 'ps aux | grep brewbot-worker or pgrep -af brewbot-worker shows the PID. kill PID sends SIGTERM; use kill -9 only if it refuses to die.', 'Find (ps, pgrep), ask politely (SIGTERM 15), confirm it is gone, and only then force (SIGKILL 9). On a real server you would then check why systemd did not restart it, or why it hung.', 20, false, true),
('8c913c34-26c0-534e-bc33-bf2ce52cf97d', '02027500-659a-5c5f-b7dc-746a394f9083', 4, 'Scenario 3 - Permission denied', $md$Running /home/labuser/work/incident/deploy.sh fails with Permission denied. Fix the cause (do not work around it with bash deploy.sh), then run ./deploy.sh successfully.$md$, $script$w=/home/labuser/work/incident
[ -x $w/deploy.sh ] && [ -f $w/app/deployed.ok ]
$script$, 'ls -l deploy.sh - is there an x anywhere in the permissions? chmod u+x adds it.', 'To run a file directly, the kernel needs the execute bit. "Permission denied" always means check ls -l on the file - and on every directory in its path (namei -l shows them all).', 15, false, true),
('282c2039-0d42-5d80-862a-3699e38f165d', '02027500-659a-5c5f-b7dc-746a394f9083', 5, 'Scenario 4 - the service will not start', $md$brewbot refuses to start. Run /home/labuser/work/incident/bin/brewbot-check, read the error, and fix incident/etc/brewbot.conf so brewbot listens on port 8080 and the check passes.$md$, $script$w=/home/labuser/work/incident
$w/bin/brewbot-check >/dev/null 2>&1 && grep -qx 'port = 8080' $w/etc/brewbot.conf && grep -qx 'workers = 4' $w/etc/brewbot.conf
$script$, 'The checker names the bad line. Edit it with nano, or sed -i ''s/^port = .*/port = 8080/'' FILE. Keep every other line.', 'Most "service won''t start" incidents are a bad config change. Read the error, fix one line, validate with the program''s own checker (nginx -t, sshd -t, brewbot-check) before restarting.', 15, false, true),
('c584f42a-3760-5804-8293-80cf4b975feb', '02027500-659a-5c5f-b7dc-746a394f9083', 6, 'Scenario 5 - command not found', $md$The runbook says to type brewctl status, but bash answers command not found. The tool exists in /home/labuser/work/incident/bin. Fix your PATH permanently in ~/.bashrc so brewctl status works from any directory.$md$, $script$[ "$(bash -ic 'cd /tmp && brewctl status' 2>/dev/null)" = "brewbot: OK" ]
$script$, 'Append export PATH="$PATH:/home/labuser/work/incident/bin" to ~/.bashrc, then open a new shell or source it.', 'command not found means no directory in PATH contains that name. Check with echo $PATH and which; the fix is either the full path, a PATH change, or installing the missing package.', 20, false, true),
('ba17fa69-87d0-5010-9ad0-b6601043582c', '02027500-659a-5c5f-b7dc-746a394f9083', 7, 'Scenario 6 - the app runs but nobody can reach it', $md$Customers report the brewbot storefront (port 8088) is unreachable from outside, yet the process is running. Find out why and fix it so the site listens on every interface. The config is incident/etc/brewbot-web.conf and the launcher is incident/bin/brewbot-web. Leave a working listener running.$md$, $script$w=/home/labuser/work/incident
grep -qx 'bind = 0.0.0.0' $w/etc/brewbot-web.conf &&
grep -qx 'port = 8088' $w/etc/brewbot-web.conf &&
ss -tln | awk '{print $4}' | grep -qx '0.0.0.0:8088' &&
[ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8088/)" = 200 ]
$script$, 'ss -tulpn | grep 8088 shows the address it is bound to. 127.0.0.1 means local only. Change bind in the config to 0.0.0.0, stop the old listener (pkill -f "http.server 8088"), then start brewbot-web again in the background with &.', 'A service bound to 127.0.0.1 answers only on the same machine, so curl localhost works while everyone else gets connection refused. Editing the config does nothing until the process restarts. This is the classic "works on the server, unreachable from outside" bug, and the same cause behind a container app that is not reachable through a published port.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('56fb8e99-6956-5184-941f-adca04839713', '02027500-659a-5c5f-b7dc-746a394f9083', 1, $json$[{"id":"59d51559-b1c1-50b0-9c88-f107aa9ec3fe","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":1,"title":"The pager goes off","description":"Black Friday has started. Run bash /home/labuser/work/start-incident.sh once to open the incidents.","verification_script":"[ -f /home/labuser/work/incident/.incident-started ] \u0026\u0026\npgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' \u003e/dev/null\n","hint_context":"Type exactly bash /home/labuser/work/start-incident.sh and press Enter.","explanation_context":"The script creates a full disk, a hung worker, a broken deploy, a bad config, a missing command and an unreachable web listener under ~/work/incident - one for each scenario that follows.","points":10,"is_optional":false,"is_stateful":true},{"id":"43921609-0e08-5541-81aa-fe6f0cfb9507","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":2,"title":"Scenario 1 - the disk is full","description":"Something under /home/labuser/work/incident is eating the disk. Find the largest file and empty it to 0 bytes WITHOUT deleting it (pretend brewbot still has it open). Leave the other logs alone.","verification_script":"l=/home/labuser/work/incident/var/log/brewbot\n[ -f $l/debug.log ] \u0026\u0026 [ ! -s $l/debug.log ] \u0026\u0026 [ -s $l/app.log ]\n","hint_context":"du -ah /home/labuser/work/incident | sort -h | tail finds the culprit. truncate -s 0 FILE or : \u003e FILE empties it in place.","explanation_context":"Deleting a log that a process still holds open frees nothing - the process keeps writing into the invisible inode. Truncating keeps the same inode and releases the space immediately.","points":20,"is_optional":false,"is_stateful":true},{"id":"2ae1e983-c29c-5e51-9c9d-3a645a5705a4","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":3,"title":"Scenario 2 - a hung worker","description":"A stuck brewbot-worker process is running. Find it and stop it - politely first.","verification_script":"[ -f /home/labuser/work/incident/.incident-started ] \u0026\u0026\n! pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' \u003e/dev/null\n","hint_context":"ps aux | grep brewbot-worker or pgrep -af brewbot-worker shows the PID. kill PID sends SIGTERM; use kill -9 only if it refuses to die.","explanation_context":"Find (ps, pgrep), ask politely (SIGTERM 15), confirm it is gone, and only then force (SIGKILL 9). On a real server you would then check why systemd did not restart it, or why it hung.","points":20,"is_optional":false,"is_stateful":true},{"id":"8c913c34-26c0-534e-bc33-bf2ce52cf97d","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":4,"title":"Scenario 3 - Permission denied","description":"Running /home/labuser/work/incident/deploy.sh fails with Permission denied. Fix the cause (do not work around it with bash deploy.sh), then run ./deploy.sh successfully.","verification_script":"w=/home/labuser/work/incident\n[ -x $w/deploy.sh ] \u0026\u0026 [ -f $w/app/deployed.ok ]\n","hint_context":"ls -l deploy.sh - is there an x anywhere in the permissions? chmod u+x adds it.","explanation_context":"To run a file directly, the kernel needs the execute bit. \"Permission denied\" always means check ls -l on the file - and on every directory in its path (namei -l shows them all).","points":15,"is_optional":false,"is_stateful":true},{"id":"282c2039-0d42-5d80-862a-3699e38f165d","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":5,"title":"Scenario 4 - the service will not start","description":"brewbot refuses to start. Run /home/labuser/work/incident/bin/brewbot-check, read the error, and fix incident/etc/brewbot.conf so brewbot listens on port 8080 and the check passes.","verification_script":"w=/home/labuser/work/incident\n$w/bin/brewbot-check \u003e/dev/null 2\u003e\u00261 \u0026\u0026 grep -qx 'port = 8080' $w/etc/brewbot.conf \u0026\u0026 grep -qx 'workers = 4' $w/etc/brewbot.conf\n","hint_context":"The checker names the bad line. Edit it with nano, or sed -i 's/^port = .*/port = 8080/' FILE. Keep every other line.","explanation_context":"Most \"service won't start\" incidents are a bad config change. Read the error, fix one line, validate with the program's own checker (nginx -t, sshd -t, brewbot-check) before restarting.","points":15,"is_optional":false,"is_stateful":true},{"id":"c584f42a-3760-5804-8293-80cf4b975feb","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":6,"title":"Scenario 5 - command not found","description":"The runbook says to type brewctl status, but bash answers command not found. The tool exists in /home/labuser/work/incident/bin. Fix your PATH permanently in ~/.bashrc so brewctl status works from any directory.","verification_script":"[ \"$(bash -ic 'cd /tmp \u0026\u0026 brewctl status' 2\u003e/dev/null)\" = \"brewbot: OK\" ]\n","hint_context":"Append export PATH=\"$PATH:/home/labuser/work/incident/bin\" to ~/.bashrc, then open a new shell or source it.","explanation_context":"command not found means no directory in PATH contains that name. Check with echo $PATH and which; the fix is either the full path, a PATH change, or installing the missing package.","points":20,"is_optional":false,"is_stateful":true},{"id":"ba17fa69-87d0-5010-9ad0-b6601043582c","lab_id":"02027500-659a-5c5f-b7dc-746a394f9083","position":7,"title":"Scenario 6 - the app runs but nobody can reach it","description":"Customers report the brewbot storefront (port 8088) is unreachable from outside, yet the process is running. Find out why and fix it so the site listens on every interface. The config is incident/etc/brewbot-web.conf and the launcher is incident/bin/brewbot-web. Leave a working listener running.","verification_script":"w=/home/labuser/work/incident\ngrep -qx 'bind = 0.0.0.0' $w/etc/brewbot-web.conf \u0026\u0026\ngrep -qx 'port = 8088' $w/etc/brewbot-web.conf \u0026\u0026\nss -tln | awk '{print $4}' | grep -qx '0.0.0.0:8088' \u0026\u0026\n[ \"$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8088/)\" = 200 ]\n","hint_context":"ss -tulpn | grep 8088 shows the address it is bound to. 127.0.0.1 means local only. Change bind in the config to 0.0.0.0, stop the old listener (pkill -f \"http.server 8088\"), then start brewbot-web again in the background with \u0026.","explanation_context":"A service bound to 127.0.0.1 answers only on the same machine, so curl localhost works while everyone else gets connection refused. Editing the config does nothing until the process restarts. This is the classic \"works on the server, unreachable from outside\" bug, and the same cause behind a container app that is not reachable through a published port.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('dd08f133-0057-5083-82e1-ce8b14f268ce', '56fb8e99-6956-5184-941f-adca04839713', '59d51559-b1c1-50b0-9c88-f107aa9ec3fe', 1, 'The pager goes off', $md$Black Friday has started. Run bash /home/labuser/work/start-incident.sh once to open the incidents.$md$, $script$[ -f /home/labuser/work/incident/.incident-started ] &&
pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' >/dev/null
$script$, 'Type exactly bash /home/labuser/work/start-incident.sh and press Enter.', 'The script creates a full disk, a hung worker, a broken deploy, a bad config, a missing command and an unreachable web listener under ~/work/incident - one for each scenario that follows.', 10, false, true),
('7b440eb1-f1a2-5472-831e-fc75ccd6eaed', '56fb8e99-6956-5184-941f-adca04839713', '43921609-0e08-5541-81aa-fe6f0cfb9507', 2, 'Scenario 1 - the disk is full', $md$Something under /home/labuser/work/incident is eating the disk. Find the largest file and empty it to 0 bytes WITHOUT deleting it (pretend brewbot still has it open). Leave the other logs alone.$md$, $script$l=/home/labuser/work/incident/var/log/brewbot
[ -f $l/debug.log ] && [ ! -s $l/debug.log ] && [ -s $l/app.log ]
$script$, 'du -ah /home/labuser/work/incident | sort -h | tail finds the culprit. truncate -s 0 FILE or : > FILE empties it in place.', 'Deleting a log that a process still holds open frees nothing - the process keeps writing into the invisible inode. Truncating keeps the same inode and releases the space immediately.', 20, false, true),
('656aa777-0dda-5b18-88b0-61a5c1baeef7', '56fb8e99-6956-5184-941f-adca04839713', '2ae1e983-c29c-5e51-9c9d-3a645a5705a4', 3, 'Scenario 2 - a hung worker', $md$A stuck brewbot-worker process is running. Find it and stop it - politely first.$md$, $script$[ -f /home/labuser/work/incident/.incident-started ] &&
! pgrep -u labuser -f '^bash /home/labuser/work/incident/bin/brewbot-worker$' >/dev/null
$script$, 'ps aux | grep brewbot-worker or pgrep -af brewbot-worker shows the PID. kill PID sends SIGTERM; use kill -9 only if it refuses to die.', 'Find (ps, pgrep), ask politely (SIGTERM 15), confirm it is gone, and only then force (SIGKILL 9). On a real server you would then check why systemd did not restart it, or why it hung.', 20, false, true),
('4c2e41b7-c3d4-51f9-9cc5-82e172de974f', '56fb8e99-6956-5184-941f-adca04839713', '8c913c34-26c0-534e-bc33-bf2ce52cf97d', 4, 'Scenario 3 - Permission denied', $md$Running /home/labuser/work/incident/deploy.sh fails with Permission denied. Fix the cause (do not work around it with bash deploy.sh), then run ./deploy.sh successfully.$md$, $script$w=/home/labuser/work/incident
[ -x $w/deploy.sh ] && [ -f $w/app/deployed.ok ]
$script$, 'ls -l deploy.sh - is there an x anywhere in the permissions? chmod u+x adds it.', 'To run a file directly, the kernel needs the execute bit. "Permission denied" always means check ls -l on the file - and on every directory in its path (namei -l shows them all).', 15, false, true),
('e9afd486-df8c-5904-8beb-65ebcd4882be', '56fb8e99-6956-5184-941f-adca04839713', '282c2039-0d42-5d80-862a-3699e38f165d', 5, 'Scenario 4 - the service will not start', $md$brewbot refuses to start. Run /home/labuser/work/incident/bin/brewbot-check, read the error, and fix incident/etc/brewbot.conf so brewbot listens on port 8080 and the check passes.$md$, $script$w=/home/labuser/work/incident
$w/bin/brewbot-check >/dev/null 2>&1 && grep -qx 'port = 8080' $w/etc/brewbot.conf && grep -qx 'workers = 4' $w/etc/brewbot.conf
$script$, 'The checker names the bad line. Edit it with nano, or sed -i ''s/^port = .*/port = 8080/'' FILE. Keep every other line.', 'Most "service won''t start" incidents are a bad config change. Read the error, fix one line, validate with the program''s own checker (nginx -t, sshd -t, brewbot-check) before restarting.', 15, false, true),
('7bc01984-42fc-53f5-9b65-6f820f6b467a', '56fb8e99-6956-5184-941f-adca04839713', 'c584f42a-3760-5804-8293-80cf4b975feb', 6, 'Scenario 5 - command not found', $md$The runbook says to type brewctl status, but bash answers command not found. The tool exists in /home/labuser/work/incident/bin. Fix your PATH permanently in ~/.bashrc so brewctl status works from any directory.$md$, $script$[ "$(bash -ic 'cd /tmp && brewctl status' 2>/dev/null)" = "brewbot: OK" ]
$script$, 'Append export PATH="$PATH:/home/labuser/work/incident/bin" to ~/.bashrc, then open a new shell or source it.', 'command not found means no directory in PATH contains that name. Check with echo $PATH and which; the fix is either the full path, a PATH change, or installing the missing package.', 20, false, true),
('61ca6c31-f89c-5fc0-809a-ebf875c49259', '56fb8e99-6956-5184-941f-adca04839713', 'ba17fa69-87d0-5010-9ad0-b6601043582c', 7, 'Scenario 6 - the app runs but nobody can reach it', $md$Customers report the brewbot storefront (port 8088) is unreachable from outside, yet the process is running. Find out why and fix it so the site listens on every interface. The config is incident/etc/brewbot-web.conf and the launcher is incident/bin/brewbot-web. Leave a working listener running.$md$, $script$w=/home/labuser/work/incident
grep -qx 'bind = 0.0.0.0' $w/etc/brewbot-web.conf &&
grep -qx 'port = 8088' $w/etc/brewbot-web.conf &&
ss -tln | awk '{print $4}' | grep -qx '0.0.0.0:8088' &&
[ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8088/)" = 200 ]
$script$, 'ss -tulpn | grep 8088 shows the address it is bound to. 127.0.0.1 means local only. Change bind in the config to 0.0.0.0, stop the old listener (pkill -f "http.server 8088"), then start brewbot-web again in the background with &.', 'A service bound to 127.0.0.1 answers only on the same machine, so curl localhost works while everyone else gets connection refused. Editing the config does nothing until the process restarts. This is the classic "works on the server, unreachable from outside" bug, and the same cause behind a container app that is not reachable through a published port.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '56fb8e99-6956-5184-941f-adca04839713', updated_at = now()
WHERE id = '02027500-659a-5c5f-b7dc-746a394f9083' AND published_version_id IS NULL;

-- Section: Final Exam: Atlas Certified
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('8b26cec3-ded3-5a1a-92dd-bb42562680dc', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', 'Final Exam: Atlas Certified', 11, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('631e7621-1f2d-5c5b-b31b-98d95922c155', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the coffee shop picture of Linux, which part is the kitchen that manages C...', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('459aedd2-1910-5155-bb1f-0abd5c8834ba', '631e7621-1f2d-5c5b-b31b-98d95922c155', 1, $json${"prompt":"In the coffee shop picture of Linux, which part is the kitchen that manages CPU, memory, disks and processes?","multiple":false,"options":[{"id":"a","text":"The kernel","is_correct":true},{"id":"b","text":"The shell (bash)","is_correct":false},{"id":"c","text":"The terminal","is_correct":false},{"id":"d","text":"The distribution","is_correct":false}],"explanation":"The kernel is the core that shares hardware between programs. The shell is the barista that takes your commands and asks the kernel to run them."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cbca87c0-7c74-5564-85b0-d371ee7545d8', '00000000-0000-0000-0000-000000000001', 'mcq', 'Brewbot''s configuration file and its log files most likely live in which two ...', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('df795f74-ef30-58a1-9d6c-6cdd687b95b8', 'cbca87c0-7c74-5564-85b0-d371ee7545d8', 1, $json${"prompt":"Brewbot's configuration file and its log files most likely live in which two directories?","multiple":false,"options":[{"id":"a","text":"/etc for the config, /var/log for the logs","is_correct":true},{"id":"b","text":"/usr for the config, /tmp for the logs","is_correct":false},{"id":"c","text":"/home for the config, /proc for the logs","is_correct":false},{"id":"d","text":"/bin for the config, /dev for the logs","is_correct":false}],"explanation":"/etc holds editable text configuration and /var holds data that varies, including logs under /var/log."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b3136879-d0a0-5050-acdf-624e579250ae', '00000000-0000-0000-0000-000000000001', 'mcq', 'You put an executable script called deploy in ~/bin, but typing deploy says c...', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9fe9dd4c-15d8-533a-b4de-fd718c1682d3', 'b3136879-d0a0-5050-acdf-624e579250ae', 1, $json${"prompt":"You put an executable script called deploy in ~/bin, but typing deploy says command not found. What is the most likely cause?","multiple":false,"options":[{"id":"a","text":"~/bin is not listed in the PATH variable","is_correct":true},{"id":"b","text":"Scripts can only run from /usr/bin","is_correct":false},{"id":"c","text":"The file name needs a .sh extension","is_correct":false},{"id":"d","text":"The kernel needs a reboot to see new commands","is_correct":false}],"explanation":"The shell only searches directories listed in PATH. Add export PATH=\"$HOME/bin:$PATH\" to ~/.bashrc."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('822b1374-8977-586e-8902-ae16c680cf65', '00000000-0000-0000-0000-000000000001', 'mcq', 'You create a symlink and a hard link to menu.txt, then delete menu.txt. What ...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c6a7ee6c-307b-5e0f-a97e-734eb225d55a', '822b1374-8977-586e-8902-ae16c680cf65', 1, $json${"prompt":"You create a symlink and a hard link to menu.txt, then delete menu.txt. What happens?","multiple":false,"options":[{"id":"a","text":"The hard link still shows the content; the symlink is now broken","is_correct":true},{"id":"b","text":"Both links still show the content","is_correct":false},{"id":"c","text":"Both links are broken","is_correct":false},{"id":"d","text":"The symlink still works; the hard link is broken","is_correct":false}],"explanation":"A hard link is another name for the same inode, so the data survives. A symlink only stores the path, which no longer exists."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7eb1b543-6d29-5109-b181-c2854b6ed8d1', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the safe habit before running find /srv -name ''*.tmp'' -delete?', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0f53e9b9-614d-586f-95fb-5d42f3c2b52b', '7eb1b543-6d29-5109-b181-c2854b6ed8d1', 1, $json${"prompt":"What is the safe habit before running find /srv -name '*.tmp' -delete?","multiple":false,"options":[{"id":"a","text":"Run the same find without -delete first and check the list","is_correct":true},{"id":"b","text":"Run it twice to make sure it worked","is_correct":false},{"id":"c","text":"Add sudo so it cannot fail","is_correct":false},{"id":"d","text":"Nothing - deleted files go to the trash and can be restored","is_correct":false}],"explanation":"Linux has no recycle bin. Always preview what find matches before adding -delete."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c3226f2b-9da0-5196-bb2c-c4286daf17be', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why does the top-IP pipeline need sort before uniq -c?', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5fb598ed-0cd9-5d4e-9289-0958df0d1e21', 'c3226f2b-9da0-5196-bb2c-c4286daf17be', 1, $json${"prompt":"Why does the top-IP pipeline need sort before uniq -c?","multiple":false,"options":[{"id":"a","text":"uniq only merges duplicate lines that are next to each other","is_correct":true},{"id":"b","text":"uniq cannot read from a pipe","is_correct":false},{"id":"c","text":"sort removes the timestamps from each line","is_correct":false},{"id":"d","text":"uniq -c only works on numbers","is_correct":false}],"explanation":"uniq compares each line only with the line before it, so equal lines must first be grouped together by sort."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d5c8c230-1e0b-542b-8a98-772cfb3e07f1', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command sends both normal output and errors of backup.sh to backup.log,...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ab234ad2-1b2c-517a-aa2f-1feb2bbf54ba', 'd5c8c230-1e0b-542b-8a98-772cfb3e07f1', 1, $json${"prompt":"Which command sends both normal output and errors of backup.sh to backup.log, appending to the file?","multiple":false,"options":[{"id":"a","text":"./backup.sh \u003e\u003e backup.log 2\u003e\u00261","is_correct":true},{"id":"b","text":"./backup.sh 2\u003e\u00261 \u003e backup.log","is_correct":false},{"id":"c","text":"./backup.sh | backup.log","is_correct":false},{"id":"d","text":"./backup.sh \u003e backup.log 2\u003e/dev/null","is_correct":false}],"explanation":"\u003e\u003e appends stdout to the file, then 2\u003e\u00261 points stderr at the same place. Order matters - redirections are processed left to right."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0aa4e899-21cc-55e5-a071-ba279d0dd815', '00000000-0000-0000-0000-000000000001', 'mcq', 'deploy.sh should be readable, writable and executable by its owner, readable ...', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('69a9b803-4fdf-5dac-81c3-08e626bfb6d7', '0aa4e899-21cc-55e5-a071-ba279d0dd815', 1, $json${"prompt":"deploy.sh should be readable, writable and executable by its owner, readable by the group, and nothing for others. Which command is correct?","multiple":false,"options":[{"id":"a","text":"chmod 740 deploy.sh","is_correct":true},{"id":"b","text":"chmod 750 deploy.sh","is_correct":false},{"id":"c","text":"chmod 704 deploy.sh","is_correct":false},{"id":"d","text":"chmod 777 deploy.sh","is_correct":false}],"explanation":"r=4 w=2 x=1. Owner rwx = 7, group r-- = 4, others --- = 0."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e77dc2e0-717f-5379-ad81-64e15eb75919', '00000000-0000-0000-0000-000000000001', 'mcq', 'You run sudo usermod -G docker sam and suddenly sam can no longer use sudo. Why?', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0186e08e-7ef3-5a64-b7c2-b05ef2b22f1a', 'e77dc2e0-717f-5379-ad81-64e15eb75919', 1, $json${"prompt":"You run sudo usermod -G docker sam and suddenly sam can no longer use sudo. Why?","multiple":false,"options":[{"id":"a","text":"Without -a, -G replaces all of sam's supplementary groups, removing sam from the sudo group","is_correct":true},{"id":"b","text":"The docker group blocks sudo","is_correct":false},{"id":"c","text":"usermod always resets the password","is_correct":false},{"id":"d","text":"Sam needs to reboot the server","is_correct":false}],"explanation":"Always use usermod -aG (append). -G alone sets the group list to exactly what you give."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1ffbf11f-71f8-5be6-b594-5cf47ceb3a07', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why can''t users delete each other''s files in /tmp, even though /tmp is writab...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d9018b26-dda6-541b-99f6-823633accfd4', '1ffbf11f-71f8-5be6-b594-5cf47ceb3a07', 1, $json${"prompt":"Why can't users delete each other's files in /tmp, even though /tmp is writable by everyone?","multiple":false,"options":[{"id":"a","text":"/tmp has the sticky bit, so only a file's owner (or root) can delete it","is_correct":true},{"id":"b","text":"/tmp is mounted read-only","is_correct":false},{"id":"c","text":"Every file in /tmp is SUID root","is_correct":false},{"id":"d","text":"The umask prevents deletion","is_correct":false}],"explanation":"drwxrwxrwt - the t is the sticky bit. On a directory it limits deleting and renaming to the file's owner."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1c221771-6eea-5155-a761-10ed3bbcfec9', '00000000-0000-0000-0000-000000000001', 'mcq', 'A worker process is stuck. What is the right order of signals to send?', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a28ad616-fc67-563f-ad67-6d852c4084f4', '1c221771-6eea-5155-a761-10ed3bbcfec9', 1, $json${"prompt":"A worker process is stuck. What is the right order of signals to send?","multiple":false,"options":[{"id":"a","text":"SIGTERM (15) first, and SIGKILL (9) only if it refuses to exit","is_correct":true},{"id":"b","text":"SIGKILL (9) first, it is faster","is_correct":false},{"id":"c","text":"SIGHUP (1) only, it always stops processes","is_correct":false},{"id":"d","text":"SIGSTOP (19), then wait for it to exit by itself","is_correct":false}],"explanation":"15 asks, 9 insists. SIGTERM lets the program clean up; SIGKILL cannot be caught and can leave half-written files."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c0651b5a-bde0-576f-a4e3-3b4a64709bf9', '00000000-0000-0000-0000-000000000001', 'mcq', 'uptime shows a load average of 12 on a 4-CPU server, but top shows the CPUs m...', 'advanced', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('374ff15c-0ad0-562e-9147-d2fde9758c2e', 'c0651b5a-bde0-576f-a4e3-3b4a64709bf9', 1, $json${"prompt":"uptime shows a load average of 12 on a 4-CPU server, but top shows the CPUs mostly idle with a high wa value. What is going on?","multiple":false,"options":[{"id":"a","text":"Processes are blocked waiting on disk IO, which counts toward load","is_correct":true},{"id":"b","text":"The load average is broken and should be ignored","is_correct":false},{"id":"c","text":"The server has too much free memory","is_correct":false},{"id":"d","text":"Twelve users are logged in","is_correct":false}],"explanation":"Linux load counts processes running or waiting, including uninterruptible (D state) disk waits. High wa means the disk, not the CPU, is the bottleneck."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f75565b6-a546-59a4-8df9-f6e57f693341', '00000000-0000-0000-0000-000000000001', 'mcq', 'You ran sudo systemctl start brewbot and it works, but after a reboot brewbot...', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2bac7394-b3ad-5e1c-b1ff-94a5ab2dff96', 'f75565b6-a546-59a4-8df9-f6e57f693341', 1, $json${"prompt":"You ran sudo systemctl start brewbot and it works, but after a reboot brewbot is not running. What did you forget?","multiple":false,"options":[{"id":"a","text":"sudo systemctl enable brewbot","is_correct":true},{"id":"b","text":"sudo systemctl reload brewbot","is_correct":false},{"id":"c","text":"sudo systemctl daemon-reload","is_correct":false},{"id":"d","text":"sudo systemctl status brewbot","is_correct":false}],"explanation":"start runs it now; enable hooks it into the boot target so it starts every time. enable --now does both."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a344c221-b459-59b5-a35a-42ab657b6baa', '00000000-0000-0000-0000-000000000001', 'mcq', 'Brewbot shows as failed. Which command shows what brewbot itself logged?', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b34b63c0-0b30-50ed-9cc8-1e6f8f294ba0', 'a344c221-b459-59b5-a35a-42ab657b6baa', 1, $json${"prompt":"Brewbot shows as failed. Which command shows what brewbot itself logged?","multiple":false,"options":[{"id":"a","text":"journalctl -u brewbot","is_correct":true},{"id":"b","text":"dmesg -u brewbot","is_correct":false},{"id":"c","text":"cat /proc/brewbot/log","is_correct":false},{"id":"d","text":"systemctl enable brewbot","is_correct":false}],"explanation":"journalctl -u UNIT filters the journal to one unit. Pair it with systemctl status for the current state."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('68d1413f-05cd-5cf0-926f-814a2a019766', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does the crontab line 0 3 * * 0 /opt/brewbot/backup.sh do?', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d8493143-7c82-5e4a-81e2-b0658fac67fc', '68d1413f-05cd-5cf0-926f-814a2a019766', 1, $json${"prompt":"What does the crontab line 0 3 * * 0 /opt/brewbot/backup.sh do?","multiple":false,"options":[{"id":"a","text":"Runs the backup at 03:00 every Sunday","is_correct":true},{"id":"b","text":"Runs the backup every 3 minutes","is_correct":false},{"id":"c","text":"Runs the backup at midnight on the 3rd of every month","is_correct":false},{"id":"d","text":"Runs the backup at 03:00 every day","is_correct":false}],"explanation":"Fields are minute, hour, day of month, month, day of week: minute 0, hour 3, any day, any month, weekday 0 = Sunday."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('28daf639-9558-5108-a769-1ae1caf9a159', '00000000-0000-0000-0000-000000000001', 'mcq', 'df -h says / is only 40% used, yet creating new files fails, and df -i shows ...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e778851b-9f7d-5b1a-b0d0-cff268894a95', '28daf639-9558-5108-a769-1ae1caf9a159', 1, $json${"prompt":"df -h says / is only 40% used, yet creating new files fails, and df -i shows 100%. What has run out?","multiple":false,"options":[{"id":"a","text":"Inodes - too many small files","is_correct":true},{"id":"b","text":"Swap space","is_correct":false},{"id":"c","text":"RAM","is_correct":false},{"id":"d","text":"File descriptors","is_correct":false}],"explanation":"Every file needs an inode. Millions of tiny files can exhaust inodes long before the blocks run out; df -i shows it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1c725e5b-4f0b-5b16-9425-9d61643ad8af', '00000000-0000-0000-0000-000000000001', 'mcq', 'You deleted a 20 GB log with rm, but df still shows the disk full. What is th...', 'advanced', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a23c2956-176d-596d-bbdc-0bd289f2d0f9', '1c725e5b-4f0b-5b16-9425-9d61643ad8af', 1, $json${"prompt":"You deleted a 20 GB log with rm, but df still shows the disk full. What is the most likely reason?","multiple":false,"options":[{"id":"a","text":"A running process still has the deleted file open, so its space is not released","is_correct":true},{"id":"b","text":"rm only moves files to a hidden trash folder","is_correct":false},{"id":"c","text":"df caches results for 24 hours","is_correct":false},{"id":"d","text":"The file system needs to be reformatted","is_correct":false}],"explanation":"The inode lives until the last open handle closes. lsof +L1 finds it; restart the process or truncate via /proc/PID/fd. Truncating instead of rm avoids this."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d5e96e4d-de21-59e9-93b7-ac1a3192f9ce', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why should /etc/fstab refer to a new disk by UUID instead of /dev/sdb1, and w...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bc381a35-6996-52b8-a5ee-e372b3457671', 'd5e96e4d-de21-59e9-93b7-ac1a3192f9ce', 1, $json${"prompt":"Why should /etc/fstab refer to a new disk by UUID instead of /dev/sdb1, and what do you run before rebooting?","multiple":false,"options":[{"id":"a","text":"Device names can change between boots; test the file with sudo mount -a","is_correct":true},{"id":"b","text":"UUIDs are faster to read; test with df -h","is_correct":false},{"id":"c","text":"/dev names are only for USB sticks; test with lsblk","is_correct":false},{"id":"d","text":"fstab does not accept /dev names; no test is needed","is_correct":false}],"explanation":"Disk order can change, but a filesystem UUID does not. mount -a mounts every fstab entry now, catching mistakes that could otherwise stop the boot."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c31f420a-c600-5581-b56d-ed27124868b3', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command lists what is inside backup.tar.gz without extracting it?', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('fa028a69-12bb-58ea-b65d-70df66ab8bd8', 'c31f420a-c600-5581-b56d-ed27124868b3', 1, $json${"prompt":"Which command lists what is inside backup.tar.gz without extracting it?","multiple":false,"options":[{"id":"a","text":"tar -tzf backup.tar.gz","is_correct":true},{"id":"b","text":"tar -xzf backup.tar.gz","is_correct":false},{"id":"c","text":"tar -czf backup.tar.gz","is_correct":false},{"id":"d","text":"gzip -l backup.tar.gz | tar","is_correct":false}],"explanation":"t = tell (list), z = gzip, f = file. x extracts and c creates."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c5da0533-ca52-5278-838a-ba1494e962f8', '00000000-0000-0000-0000-000000000001', 'mcq', 'From your laptop, curl to atlas:8080 says Connection refused. On atlas, ss -t...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4126ccb0-4fa0-5a95-9921-2d3b9256b993', 'c5da0533-ca52-5278-838a-ba1494e962f8', 1, $json${"prompt":"From your laptop, curl to atlas:8080 says Connection refused. On atlas, ss -tulpn shows brewbot on 127.0.0.1:8080. What is wrong?","multiple":false,"options":[{"id":"a","text":"Brewbot listens only on localhost, so outside connections reach no listener","is_correct":true},{"id":"b","text":"A firewall is dropping the packets","is_correct":false},{"id":"c","text":"DNS is resolving the wrong name","is_correct":false},{"id":"d","text":"The server is out of memory","is_correct":false}],"explanation":"Refused means nothing listens on that address and port. Bound to 127.0.0.1, brewbot only accepts local connections; a firewall drop would show as a timeout instead."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c82a64c4-af32-576d-9df6-829b84d82177', '00000000-0000-0000-0000-000000000001', 'mcq', 'SSH ignores your key and asks for a password. The server''s ~/.ssh is 777 and ...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c5c1e943-e446-5cb4-8fe3-24065eda3c56', 'c82a64c4-af32-576d-9df6-829b84d82177', 1, $json${"prompt":"SSH ignores your key and asks for a password. The server's ~/.ssh is 777 and authorized_keys is 666. What should they be?","multiple":false,"options":[{"id":"a","text":"~/.ssh 700 and authorized_keys 600","is_correct":true},{"id":"b","text":"~/.ssh 755 and authorized_keys 777","is_correct":false},{"id":"c","text":"Both 644","is_correct":false},{"id":"d","text":"Permissions do not matter to SSH","is_correct":false}],"explanation":"sshd refuses keys that other users could modify. Lock .ssh to 700 and the key files to 600."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('54692db7-3207-596f-a55d-d0a84e1f83d1', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does set -euo pipefail at the top of a Bash script do?', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('69eac406-ecc3-5e84-bb64-7532a797d6cd', '54692db7-3207-596f-a55d-d0a84e1f83d1', 1, $json${"prompt":"What does set -euo pipefail at the top of a Bash script do?","multiple":false,"options":[{"id":"a","text":"Stops on the first failing command, errors on unset variables, and fails a pipeline if any part fails","is_correct":true},{"id":"b","text":"Runs the script as root","is_correct":false},{"id":"c","text":"Enables colour output and Unicode","is_correct":false},{"id":"d","text":"Makes the script run in the background","is_correct":false}],"explanation":"-e exit on error, -u treat unset variables as errors, -o pipefail make a pipeline's status reflect any failing stage."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('25c90928-7c7a-5bad-88d3-aa2023584c78', '00000000-0000-0000-0000-000000000001', 'mcq', 'In Bash, what exit status means a command succeeded?', 'beginner', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4f316929-42fc-5b0e-9c34-9396f6c9148e', '25c90928-7c7a-5bad-88d3-aa2023584c78', 1, $json${"prompt":"In Bash, what exit status means a command succeeded?","multiple":false,"options":[{"id":"a","text":"0","is_correct":true},{"id":"b","text":"1","is_correct":false},{"id":"c","text":"-1","is_correct":false},{"id":"d","text":"255","is_correct":false}],"explanation":"Zero is a hero: 0 is success, any other number is a failure code. if, \u0026\u0026 and || all check it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f01018b8-54f3-5fbc-b2b6-412ecdd3c857', '00000000-0000-0000-0000-000000000001', 'mcq', 'Brewbot will not start right after a teammate edited its config. Following th...', 'intermediate', 5, ARRAY['linux','bash','sysadmin','devops','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b8502b94-50bf-5b39-80e5-9ea68d0eeaef', 'f01018b8-54f3-5fbc-b2b6-412ecdd3c857', 1, $json${"prompt":"Brewbot will not start right after a teammate edited its config. Following the incident method, what do you do first?","multiple":false,"options":[{"id":"a","text":"Read the error with systemctl status and journalctl -u brewbot, then validate the changed config","is_correct":true},{"id":"b","text":"Reboot the server and hope it comes back","is_correct":false},{"id":"c","text":"chmod -R 777 /etc/brewbot so permissions cannot be the problem","is_correct":false},{"id":"d","text":"Reinstall the operating system","is_correct":false}],"explanation":"Every Real Linux Pro Checks: Error, Resources, Logs, Permissions, Changes. A recent config change plus a startup failure points straight at the config - read the logs, fix one thing, validate, restart."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('7938e6a1-f9a9-568b-91e9-a09d6b757114', '00000000-0000-0000-0000-000000000001', 'Final Exam: Linux on Atlas', 'linux-final-exam', 'Quiz covering Final Exam: Atlas Certified.', 'mcq', 'published', 'module', 'c09b6d0f-f9b8-5c55-9a5c-e59ac936ee3d', 30, 70, 5, 120, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '7938e6a1-f9a9-568b-91e9-a09d6b757114' AND question_id NOT IN ('631e7621-1f2d-5c5b-b31b-98d95922c155', 'cbca87c0-7c74-5564-85b0-d371ee7545d8', 'b3136879-d0a0-5050-acdf-624e579250ae', '822b1374-8977-586e-8902-ae16c680cf65', '7eb1b543-6d29-5109-b181-c2854b6ed8d1', 'c3226f2b-9da0-5196-bb2c-c4286daf17be', 'd5c8c230-1e0b-542b-8a98-772cfb3e07f1', '0aa4e899-21cc-55e5-a071-ba279d0dd815', 'e77dc2e0-717f-5379-ad81-64e15eb75919', '1ffbf11f-71f8-5be6-b594-5cf47ceb3a07', '1c221771-6eea-5155-a761-10ed3bbcfec9', 'c0651b5a-bde0-576f-a4e3-3b4a64709bf9', 'f75565b6-a546-59a4-8df9-f6e57f693341', 'a344c221-b459-59b5-a35a-42ab657b6baa', '68d1413f-05cd-5cf0-926f-814a2a019766', '28daf639-9558-5108-a769-1ae1caf9a159', '1c725e5b-4f0b-5b16-9425-9d61643ad8af', 'd5e96e4d-de21-59e9-93b7-ac1a3192f9ce', 'c31f420a-c600-5581-b56d-ed27124868b3', 'c5da0533-ca52-5278-838a-ba1494e962f8', 'c82a64c4-af32-576d-9df6-829b84d82177', '54692db7-3207-596f-a55d-d0a84e1f83d1', '25c90928-7c7a-5bad-88d3-aa2023584c78', 'f01018b8-54f3-5fbc-b2b6-412ecdd3c857');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('53503d6f-3573-5600-aa96-47a1a602b6fc', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '631e7621-1f2d-5c5b-b31b-98d95922c155', '459aedd2-1910-5155-bb1f-0abd5c8834ba', 0, 5),
('7fe1f11c-075b-5225-878d-c9e69723860d', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'cbca87c0-7c74-5564-85b0-d371ee7545d8', 'df795f74-ef30-58a1-9d6c-6cdd687b95b8', 1, 5),
('2ecc2ec1-cb59-55ce-8be1-3780f5520034', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'b3136879-d0a0-5050-acdf-624e579250ae', '9fe9dd4c-15d8-533a-b4de-fd718c1682d3', 2, 5),
('cb4a900f-29da-5c25-92dc-82f6f52afcb5', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '822b1374-8977-586e-8902-ae16c680cf65', 'c6a7ee6c-307b-5e0f-a97e-734eb225d55a', 3, 5),
('167d265e-e87c-5a02-ab94-90c572986970', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '7eb1b543-6d29-5109-b181-c2854b6ed8d1', '0f53e9b9-614d-586f-95fb-5d42f3c2b52b', 4, 5),
('9b319f2a-89ac-5cd8-8ccb-5677440dea27', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'c3226f2b-9da0-5196-bb2c-c4286daf17be', '5fb598ed-0cd9-5d4e-9289-0958df0d1e21', 5, 5),
('9469bc36-7c16-50da-a174-d5e95a097c26', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'd5c8c230-1e0b-542b-8a98-772cfb3e07f1', 'ab234ad2-1b2c-517a-aa2f-1feb2bbf54ba', 6, 5),
('09ea92c6-d063-5683-a90d-08314637e973', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '0aa4e899-21cc-55e5-a071-ba279d0dd815', '69a9b803-4fdf-5dac-81c3-08e626bfb6d7', 7, 5),
('2735dc4d-967c-5e8d-bc74-f34bbb15fe22', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'e77dc2e0-717f-5379-ad81-64e15eb75919', '0186e08e-7ef3-5a64-b7c2-b05ef2b22f1a', 8, 5),
('ac4b094f-c2c3-581e-9910-157fe270ab72', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '1ffbf11f-71f8-5be6-b594-5cf47ceb3a07', 'd9018b26-dda6-541b-99f6-823633accfd4', 9, 5),
('23ec00e5-7ed0-5f50-bd76-0deed3621cba', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '1c221771-6eea-5155-a761-10ed3bbcfec9', 'a28ad616-fc67-563f-ad67-6d852c4084f4', 10, 5),
('3c6e8644-7557-593b-9b59-99ea49029ba8', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'c0651b5a-bde0-576f-a4e3-3b4a64709bf9', '374ff15c-0ad0-562e-9147-d2fde9758c2e', 11, 5),
('6b7adbdb-1082-545b-8cc8-772c7b3a4e09', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'f75565b6-a546-59a4-8df9-f6e57f693341', '2bac7394-b3ad-5e1c-b1ff-94a5ab2dff96', 12, 5),
('534b4685-0e72-5d8d-8dcc-26a59babe202', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'a344c221-b459-59b5-a35a-42ab657b6baa', 'b34b63c0-0b30-50ed-9cc8-1e6f8f294ba0', 13, 5),
('0c1025b1-e589-5f46-ac80-8a872ad322ab', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '68d1413f-05cd-5cf0-926f-814a2a019766', 'd8493143-7c82-5e4a-81e2-b0658fac67fc', 14, 5),
('089191f0-634e-529d-8df3-fca7206c0635', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '28daf639-9558-5108-a769-1ae1caf9a159', 'e778851b-9f7d-5b1a-b0d0-cff268894a95', 15, 5),
('1dd01d3e-3327-5714-bf9d-ef550edbf08a', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '1c725e5b-4f0b-5b16-9425-9d61643ad8af', 'a23c2956-176d-596d-bbdc-0bd289f2d0f9', 16, 5),
('51bd00d7-894c-5835-a169-644f381d1d44', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'd5e96e4d-de21-59e9-93b7-ac1a3192f9ce', 'bc381a35-6996-52b8-a5ee-e372b3457671', 17, 5),
('eb09df5b-2520-5be9-94c9-df4c7759f9c3', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'c31f420a-c600-5581-b56d-ed27124868b3', 'fa028a69-12bb-58ea-b65d-70df66ab8bd8', 18, 5),
('a2b7f82b-9689-562a-9141-3204515b228d', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'c5da0533-ca52-5278-838a-ba1494e962f8', '4126ccb0-4fa0-5a95-9921-2d3b9256b993', 19, 5),
('db239f63-11d0-5936-bbef-a0c022234edb', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'c82a64c4-af32-576d-9df6-829b84d82177', 'c5c1e943-e446-5cb4-8fe3-24065eda3c56', 20, 5),
('05c6c3e8-08be-56b9-9a2d-66f15f1d61f5', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '54692db7-3207-596f-a55d-d0a84e1f83d1', '69eac406-ecc3-5e84-bb64-7532a797d6cd', 21, 5),
('dc3ee37f-7f66-556e-bd62-b3fd58a0fa9c', '7938e6a1-f9a9-568b-91e9-a09d6b757114', '25c90928-7c7a-5bad-88d3-aa2023584c78', '4f316929-42fc-5b0e-9c34-9396f6c9148e', 22, 5),
('f166fdd9-82a4-54a2-9c8a-7670474dcdbd', '7938e6a1-f9a9-568b-91e9-a09d6b757114', 'f01018b8-54f3-5fbc-b2b6-412ecdd3c857', 'b8502b94-50bf-5b39-80e5-9ea68d0eeaef', 23, 5)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('c09b6d0f-f9b8-5c55-9a5c-e59ac936ee3d', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '8b26cec3-ded3-5a1a-92dd-bb42562680dc', 'Final Exam: Linux on Atlas', 'assessment', 0, 30, '7938e6a1-f9a9-568b-91e9-a09d6b757114')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('846f1551-d0eb-56ef-829d-5275cbdcfd21', '00000000-0000-0000-0000-000000000014', 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

DELETE FROM course_modules WHERE course_id = 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf' AND id NOT IN ('a50e29c4-cd7e-5b52-bfea-bf5cd4825d59', '7aca830d-151a-5ddd-b824-189d87652f8d', 'c5763494-4508-5099-965a-3b07d56d84c9', 'a675c34c-0a48-58af-87ad-010cc471a6b6', '231dac95-528c-5b9c-a5b1-e9236c5325f8', 'e969cf2f-c441-5630-9036-2f68365cdbb8', '11b28bd9-4431-59fb-b0c4-9e422068f6cc', '05b5b666-8186-5ee0-86e5-aefff70dd17b', '64a3a363-df99-5bae-aeba-0d274cc5bcd0', '99908f22-2062-52f6-88ad-daa4d7d1135f', 'c09b6d0f-f9b8-5c55-9a5c-e59ac936ee3d');
DELETE FROM course_sections WHERE course_id = 'ff3181db-8006-56ba-8bf0-e2e2dfdacfbf' AND id NOT IN ('4078896b-224c-5318-8a4a-c389cca4bece', '63d08802-94af-5e70-adb6-8cdf39e53b00', '97f1a659-cf0a-5ff6-a3b6-1c64ef8afacd', 'ace77ee1-65f9-5db8-a581-1431f13b56fc', 'ec8f752c-74df-5e68-b66e-b63f6f3212a5', '1d2e633e-0589-50da-b212-4e9f881d0b3c', 'e69dc5c5-35bf-5142-9c2a-307a9fa8f8c8', '6acc183c-467b-5c2d-8bfa-3db7c961c76d', 'c887f65a-8665-5c24-ae84-e8bcc9c37bb2', '716c0129-f420-5354-9147-1d8b681dd59a', '8b26cec3-ded3-5a1a-92dd-bb42562680dc');

