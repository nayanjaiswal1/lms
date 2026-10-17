---
kind: lesson
id_key: linux/moving-in/copy-move-delete
course: linux
section: moving-in
section_title: "Chapter 2: Moving In - Working with Files"
section_position: 2
title: "Copy, Move, Rename, Delete - and Wildcards"
position: 1
estimated_minutes: 8
source:
  - cp(1), mv(1), rm(1) manual pages; glob(7)
  - GNU Bash Reference Manual, "Filename Expansion"
---

## Why this matters

Unpacking the boxes means copying recipes, moving the menu, and deleting junk.
These are the commands that cause the most damage when typed carelessly: `rm` has
no undo. Learn them with the safety habits built in.

## Mental model: photocopy vs carry

```
 cp:  box/recipes ---photocopy---> shop/config/recipes   (both exist after)
 mv:  box/menu.txt ---carry------> shop/menu.txt          (only one exists after)
 rm:  shredder. No bin, no undo.
```

`mv` within one filesystem does not copy any data. It only changes which
directory lists the name, so moving a 50 GB file is instant.

## See it work

```bash
cp menu.txt menu.bak           # copy a file
cp -r recipes/ backup/recipes  # copy a directory: -r = recursive
cp -a src/ dst/                # archive copy: keep permissions, times, links
mv old.txt new.txt             # rename
mv menu.txt shop/              # move into a directory
rm notes.txt                   # delete a file
rm -r olddir                   # delete a directory and everything inside
rm -i *.log                    # ask before each delete
```

Without `-r`, `cp` refuses directories:

```
$ cp recipes backup
cp: -r not specified; omitting directory 'recipes'
```

Use `-v` (verbose) on `cp`, `mv` and `rm` to see each action:

```bash
mv -v menu.txt shop/
```

```
renamed 'menu.txt' -> 'shop/menu.txt'
```

### Wildcards (globs)

The shell expands **wildcards** into matching file names before the command
runs. The command never sees the `*`.

| Pattern | Matches |
|---|---|
| `*` | anything, including nothing (`*.log`) |
| `?` | exactly one character (`file?.txt`) |
| `[abc]`, `[0-9]` | one character from the set |
| `{a,b}` | not a match: brace expansion always generates both words |

Preview what a pattern matches by giving it to `ls` or `echo` first:

```bash
echo *.bak
```

```
menu-2019.bak prices.bak
```

If nothing matches, bash passes the pattern through literally (`*.bak`), and the
command then complains that no such file exists.

### Safety habits for rm

`rm -rf` with a wrong variable has wiped whole servers. Before any delete:

1. Run `ls` with the exact same pattern first.
2. Use `rm -i` when unsure, or `-v` to see what happened.
3. In scripts, never write `rm -rf "$DIR"/` without checking that `$DIR` is set
   (chapter 9 shows `${DIR:?}`).
4. Prefer moving to a `trash/` folder when cleaning up something you do not fully
   understand.

## Try it

You are in `~/work/moving/box`. Copy the whole `recipes` directory to
`~/work/shop/config/recipes`, then move `menu.txt` into `~/work/shop/`. Which of
the two sources still exists afterwards?

<details>
<summary>Show answer</summary>

```bash
cp -r recipes ~/work/shop/config/recipes
mv menu.txt ~/work/shop/
```

`recipes` still exists (it was copied). `menu.txt` is gone from the box (it was
moved).

</details>

## Common mistakes

- **Trailing-slash and target confusion.** `cp -r recipes dest` creates
  `dest/recipes` if `dest` exists, but creates `dest` itself (a copy named
  `dest`) if it does not. Check with `ls` after.
- **`mv` silently overwrites.** If `shop/menu.txt` exists, `mv menu.txt shop/`
  replaces it. Use `mv -i` or `mv -n` (never overwrite) when it matters.
- **`rm *` in the wrong directory.** Always `pwd` first. A space typo,
  `rm -rf / tmp/x`, deletes from `/`.
- **Expecting a recycle bin.** Deleted from the shell means gone. Backups are the
  only undo.

## Remember

- `cp` copies (`-r` for directories, `-a` to keep attributes); `mv` moves or
  renames; `rm` deletes forever.
- Globs `*`, `?`, `[...]` are expanded by the shell; preview with `echo` or `ls`.
- Add `-i` to ask, `-v` to see what happened.
- `ls` first, `rm` second.

**Self-check:**

1. Which option does `cp` need to copy a directory?
2. Why is `mv` instant for a huge file on the same disk?
3. What does `?` match in a glob?
