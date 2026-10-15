---
kind: lesson
id_key: linux/the-logbook/lesson
course: linux
section: the-logbook
section_title: "Chapter 3: The Logbook"
section_position: 3
title: Viewing Text, grep, Pipes, Redirection, sed and awk
position: 0
estimated_minutes: 50
source:
  - grep(1), sort(1), uniq(1), cut(1), sed(1), awk(1), tee(1) manual pages
  - GNU Bash Reference Manual, "Redirections" and "Pipelines"
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 45
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    w=/home/labuser/work
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
  tasks:
    - id_key: count-errors
      title: How bad is it?
      points: 15
      is_stateful: true
      description: Count how many lines in logbook/app.log contain the word ERROR and save just the number into answers/errors.txt.
      verification_script: |
        w=/home/labuser/work
        [ "$(tr -d '[:space:]' < $w/answers/errors.txt)" = "$(grep -c ERROR $w/logbook/app.log)" ]
      hint_context: grep -c PATTERN FILE prints the number of matching lines instead of the lines themselves.
      explanation_context: grep -c counts matching lines. grep PATTERN FILE | wc -l gives the same answer by counting the printed lines.
      solution_script: |
        cd /home/labuser/work && grep -c ERROR logbook/app.log > answers/errors.txt
    - id_key: top-ip
      title: Who is hammering the shop?
      points: 25
      is_stateful: true
      description: Find the IP address that made the most requests in logbook/access.log (the IP is the first field on each line) and save only that IP into answers/top-ip.txt.
      verification_script: |
        w=/home/labuser/work
        want=$(awk '{print $1}' $w/logbook/access.log | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
        [ "$(tr -d '[:space:]' < $w/answers/top-ip.txt)" = "$want" ]
      hint_context: Pipe it - awk '{print $1}' extracts the IP, sort groups equal lines, uniq -c counts each group, sort -rn puts the biggest count first, head -1 keeps the winner.
      explanation_context: sort | uniq -c | sort -rn | head is the classic "top N" pipeline. uniq only merges adjacent duplicates, which is why sort must come first.
      solution_script: |
        cd /home/labuser/work
        awk '{print $1}' logbook/access.log | sort | uniq -c | sort -rn | head -1 | awk '{print $2}' > answers/top-ip.txt
    - id_key: failing-paths
      title: Which pages are crashing?
      points: 20
      is_stateful: true
      description: Save the list of distinct request paths that returned status 500 into answers/500-paths.txt, one path per line, sorted alphabetically with no duplicates. In access.log the path is field 7 and the status code is field 9.
      verification_script: |
        w=/home/labuser/work
        diff <(awk '$9 == 500 {print $7}' $w/logbook/access.log | sort -u) <(grep -v '^$' $w/answers/500-paths.txt) >/dev/null
      hint_context: awk '$9 == 500 {print $7}' filters on one field and prints another. sort -u sorts and removes duplicates.
      explanation_context: awk splits each line on whitespace into $1, $2 ... so it can filter on one column and print another in one step. sort -u is sort plus uniq.
      solution_script: |
        cd /home/labuser/work
        awk '$9 == 500 {print $7}' logbook/access.log | sort -u > answers/500-paths.txt
    - id_key: mask-passwords
      title: Hide the leaked passwords
      points: 20
      is_stateful: true
      description: The app wrote passwords into its log. Create logbook/app-clean.log - a copy of app.log where every password=VALUE is replaced with password=*** - using sed. Leave app.log itself unchanged.
      verification_script: |
        w=/home/labuser/work/logbook
        [ -f $w/app-clean.log ] &&
        [ "$(wc -l < $w/app-clean.log)" = "$(wc -l < $w/app.log)" ] &&
        ! grep -q 'password=[^*]' $w/app-clean.log &&
        [ "$(grep -c 'password=\*\*\*' $w/app-clean.log)" = "$(grep -c 'password=' $w/app.log)" ] &&
        grep -q 'password=s3cret' $w/app.log
      hint_context: sed 's/password=[^ ]*/password=***/' FILE > NEWFILE - [^ ]* means "everything up to the next space". Without -i sed prints the result and leaves the original alone.
      explanation_context: sed s/old/new/ edits a stream line by line. Writing to a new file keeps the evidence intact; sed -i edits in place, which is risky on the only copy of a log.
      solution_script: |
        cd /home/labuser/work/logbook
        sed 's/password=[^ ]*/password=***/' app.log > app-clean.log
    - id_key: split-streams
      title: Separate the good from the bad
      points: 20
      is_stateful: true
      description: Run ls /home/labuser/work/logbook /no/such/dir as one command so that the normal output goes to answers/out.txt and the error message goes to answers/err.txt.
      verification_script: |
        a=/home/labuser/work/answers
        grep -q access.log $a/out.txt && grep -q 'No such file' $a/err.txt &&
        ! grep -q access.log $a/err.txt && ! grep -q 'No such file' $a/out.txt
      hint_context: "The > operator redirects stdout (stream 1) and 2> redirects stderr (stream 2). Both can be used on the same command."
      explanation_context: Every program has three streams - stdin (0), stdout (1), stderr (2). Splitting them lets scripts keep errors in a log while passing clean data down a pipe.
      solution_script: |
        ls /home/labuser/work/logbook /no/such/dir > /home/labuser/work/answers/out.txt 2> /home/labuser/work/answers/err.txt
---

> **Wednesday, 10:14.** Customers are complaining that checkout is broken. Rhea: "Tom always said *the logs never lie*. Don't guess - read the logbook." You have two files in `~/work/logbook`: the web server's `access.log` and the app's `app.log`. Today you learn to turn thousands of lines into one answer.

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
