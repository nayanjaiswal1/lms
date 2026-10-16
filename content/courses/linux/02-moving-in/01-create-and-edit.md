---
kind: lesson
id_key: linux/moving-in/create-and-edit
course: linux
section: moving-in
section_title: "Chapter 2: Moving In - Working with Files"
section_position: 2
title: "Creating Files and Directories, and Editing Them"
position: 0
estimated_minutes: 7
source:
  - mkdir(1), touch(1), rmdir(1), nano(1), vim(1) manual pages
  - GNU Bash Reference Manual, "Brace Expansion" and "Redirections"
---

## Why this matters

> **Tuesday.** Rhea points at a pile of digital boxes Tom dumped in
> `~/work/moving`: "The shop needs a proper home. Unpack, throw out the junk,
> and don't delete anything we need. There is no recycle bin on Linux."

Building a folder layout and writing small text files is half of daily admin
work: config files, notes, scripts. You need to do it fast and without
accidents.

## Mental model: bulldozer and stapler

Two symbols write text into files, and they behave very differently:

```
 echo "hello" >  file.txt     BULLDOZER: flattens the file, then writes
 echo "more"  >> file.txt     STAPLER:   adds a page at the end
```

> **Memory hook:** `>` is a **bulldozer**, `>>` is a **stapler**.

## See it work

```bash
mkdir shop                            # one directory
mkdir -p shop/config/recipes          # whole path, no error if it exists
mkdir -p shop/{config,logs,backups}   # brace expansion -> three dirs
ls shop
```

What this does: `-p` creates every missing parent and stays quiet if a
directory already exists. `{config,logs,backups}` is **brace expansion**: bash
turns one word into three *before* `mkdir` runs, so `mkdir` receives
`shop/config shop/logs shop/backups`. Expected output:

```
backups  config  logs
```

Check what bash will do with braces using `echo`:

```bash
echo shop/{config,logs,backups}
```

```
shop/config shop/logs shop/backups
```

### Files

```bash
touch notes.txt                 # create an empty file (or update its timestamp)
echo "Espresso 3.00" > menu.txt # create/overwrite with content
echo "Latte 4.50" >> menu.txt   # append a line
cat menu.txt
```

```
Espresso 3.00
Latte 4.50
```

For multi-line content, a **here-document** saves typing:

```bash
cat > hours.txt <<'EOF'
Mon-Fri 07:00-18:00
Sat     08:00-14:00
EOF
```

Everything between the two `EOF` lines goes into the file.

### Removing empty directories

```bash
rmdir emptydir      # only works if the directory is EMPTY
```

`rmdir` refusing a non-empty directory is a safety feature. The next lesson
covers `rm -r`.

### Editing on a server

Servers have no mouse-driven editor. Learn the survival keys of two:

| nano (easy) | vi / vim (always installed) |
|---|---|
| `nano file.txt` | `vi file.txt` |
| type directly | press `i` to start typing (insert mode) |
| `Ctrl+O` Enter = save | `Esc` then `:w` Enter = save |
| `Ctrl+X` = exit | `Esc` then `:q` Enter = quit |
| shortcuts are listed at the bottom | `Esc` then `:wq` = save and quit, `:q!` = quit without saving |

If you get stuck in vi, press `Esc` a few times, type `:q!` and Enter.

## Try it

With one command, create `~/work/cafe/menu`, `~/work/cafe/staff` and
`~/work/cafe/stock`, even though `~/work/cafe` does not exist yet. Then add two
lines to `~/work/cafe/menu/today.txt` without losing the first one.

<details>
<summary>Show answer</summary>

```bash
mkdir -p ~/work/cafe/{menu,staff,stock}
echo "Espresso" > ~/work/cafe/menu/today.txt
echo "Mocha" >> ~/work/cafe/menu/today.txt
```

The second command must use `>>`. Another `>` would replace "Espresso".

</details>

## Common mistakes

- **Spaces inside braces.** `{config, logs}` is not expanded; bash sees two
  separate words. Write `{config,logs}`.
- **`>` when you meant `>>`.** The old content is gone instantly. When editing
  important files, copy first: `cp app.conf app.conf.bak`.
- **Forgetting `-p`.** `mkdir a/b/c` fails if `a/b` does not exist.
- **Panicking in vi.** `Esc`, then `:q!`. Nothing is saved, nothing is broken.

## Remember

- `mkdir -p` makes whole paths; braces make many names at once.
- `touch` creates empty files; `>` overwrites, `>>` appends.
- Here-documents (`<<'EOF'`) write multi-line files.
- nano: `Ctrl+O`, `Ctrl+X`. vi: `i`, `Esc`, `:wq`, `:q!`.

**Self-check:**

1. What does `mkdir -p` do differently from plain `mkdir`?
2. What does `echo x{1,2,3}` print?
3. How do you quit vi without saving?
