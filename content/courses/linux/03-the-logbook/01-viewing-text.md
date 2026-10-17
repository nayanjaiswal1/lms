---
kind: lesson
id_key: linux/the-logbook/viewing-text
course: linux
section: the-logbook
section_title: "Chapter 3: The Logbook - Text Tools and Pipes"
section_position: 3
title: "Looking at Files: cat, less, head, tail and wc"
position: 0
estimated_minutes: 6
source:
  - cat(1), less(1), head(1), tail(1), wc(1) manual pages
---

## Why this matters

> **Wednesday, 10:14.** Customers say checkout is broken. Rhea: "Tom always said
> *the logs never lie*. Don't guess, read the logbook." In `~/work/logbook` you
> have the web server's `access.log` and the app's `app.log`.

Logs are text, and they are big. Dumping a 2 GB log to the screen helps nobody.
You need to look at the right part: the start, the end, or the live stream.

## Mental model: a queue of customers

A log is a queue. New lines join at the **end**.

```
 first line  ... ... ... ... ... ... ... ... ... ... last line  <- new lines arrive here
 \__ head __/                                   \__ tail __/
                                                tail -f = stand at the end and watch
```

> **Memory hook:** `head` and `tail` are the two ends of the coffee queue.
> `tail -f` is standing at the end **forever**, watching new customers arrive.

## See it work

```bash
cd ~/work/logbook
wc -l app.log access.log
```

What this does: counts lines in each file (always check the size before
opening). Expected output:

```
   80 app.log
  275 access.log
  355 total
```

```bash
head -n 3 app.log      # first 3 lines
tail -n 2 app.log      # last 2 lines
```

```
2026-10-14 10:1:00 INFO order placed order=1
2026-10-14 10:2:00 INFO order placed order=2
2026-10-14 10:3:00 ERROR payment gateway timeout order=3
2026-10-14 10:19:00 INFO order placed order=79
2026-10-14 10:20:00 ERROR payment gateway timeout order=80
```

`-n` sets how many lines (default 10). `tail -n +50` means "from line 50 to the
end".

### Following a live log

```bash
tail -f /var/log/syslog         # print new lines as they arrive; Ctrl+C stops
tail -F app.log                 # same, but survives log rotation
```

`-F` reopens the file if it is renamed and recreated, which is what log rotation
does every night (chapter 6).

### Scrolling with less

```bash
less access.log
```

| Key | Action |
|---|---|
| Space / b | page down / back |
| `g` / `G` | top / bottom |
| `/500` Enter | search forward for "500"; `n` next, `N` previous |
| `F` | follow mode (like `tail -f`); Ctrl+C to stop following |
| `q` | quit |

`less` opens huge files instantly because it reads only what it shows.

### cat and wc

```bash
cat small.txt           # print the whole file (fine for small files)
cat a.txt b.txt         # concatenate: print both, one after another
wc -l file              # lines; -w words, -c bytes
```

`cat` stands for con**cat**enate. On a big log, prefer `less`.

## Try it

Show the last 20 lines of `access.log`, then open it in `less` and jump to the
first line containing `404`.

<details>
<summary>Show answer</summary>

```bash
tail -n 20 access.log
less access.log      # then type /404 and press Enter; n for the next one
```

</details>

## Common mistakes

- **`cat` on a huge file.** Your terminal scrolls for minutes. Use `less`, `head`
  or `tail`.
- **`tail -f` on a rotated log.** After rotation it watches the old, renamed
  file and shows nothing new. Use `tail -F`.
- **Opening a log in an editor.** `vi` or `nano` load the whole file and can
  save changes by accident. `less` is read-only.

## Remember

- `wc -l` to size it up, `head`/`tail` for the ends, `less` to explore.
- `tail -f` (or `-F`) follows a live log.
- In `less`: `/word` search, `G` end, `F` follow, `q` quit.

**Self-check:**

1. What is the difference between `tail -f` and `tail -F`?
2. How do you jump to the end of a file in `less`?
3. Which command counts the lines of a file?
