---
kind: lesson
id_key: git/first-commits/identity-commit
course: git
section: first-commits
section_title: Setup and First Commits
section_position: 2
title: "Identity, Config and Your First Commit"
position: 1
estimated_minutes: 9
source:
  - Pro Git book, ch. 1.6 "First-Time Git Setup" and ch. 2.2 "Recording Changes"
  - git-config(1), git-commit(1) manual pages
---

## Why this matters

Every commit records who made it. If your name and email are wrong, your work
is credited to "root" or to a stranger, and hosts like GitHub cannot link the
commit to your account. Set it once, then make your first commit with a message
your team can actually use.

## Mental model: a signed, dated envelope

A commit is a sealed envelope. Inside: the snapshot. On the outside: author
name, email, date and a short note saying what is inside and why. Git reads the
name and email from its **config** at the moment you commit and writes them
onto the envelope forever.

### Where config lives

| Level | Flag | File | Applies to |
|---|---|---|---|
| System | `--system` | `/etc/gitconfig` | Every user on the machine |
| Global | `--global` | `~/.gitconfig` | Every repo of your user |
| Local | `--local` (default) | `.git/config` | This one repo |

The most specific level wins: local beats global beats system. Use local to set
a work email in one work repo.

## See it work

### Set your identity once

```bash
git config --global user.name  "Ada Student"
git config --global user.email "ada@example.com"
git config --list --show-origin | grep user
```

What this does: writes two keys into `~/.gitconfig`, then lists every setting
with the file it came from. Expected output:

```
file:/home/labuser/.gitconfig   user.name=Ada Student
file:/home/labuser/.gitconfig   user.email=ada@example.com
```

Two more settings worth having from day one:

```bash
git config --global init.defaultBranch main   # first branch is called main
git config --global core.editor nano          # editor for messages (or vim, "code --wait")
```

### Make the commit

```
BEFORE (after git add)            AFTER (git commit -m "Add README")

 working: README.md                working: README.md
 index  : README.md                index  : README.md
 HEAD   : (none)                   HEAD   : A  <- main
                                          A = "Add README"
```

```bash
echo "# Hello" > README.md
git add README.md
git commit -m "Add README"
git log --oneline
```

Expected output of the last command (the hash will differ):

```
3f1c9ab (HEAD -> main) Add README
```

Without `-m`, Git opens your editor for the message. Save and close it to
finish the commit; an empty message aborts.

```knowledge-check
{ "questions": [
  { "id": "git-first-commit-q1", "type": "mcq",
    "prompt": "Where does Git get the author name stored in a commit?",
    "options": [
      {"id":"a","text":"The operating system login name, always"},
      {"id":"b","text":"user.name and user.email from git config"},
      {"id":"c","text":"The remote repository owner"},
      {"id":"d","text":"The file's last modified time"}],
    "correct": "b",
    "explanation": "user.name and user.email are read from config at commit time and baked into the commit object. The OS login is only a fallback guess when nothing is configured, and the remote and file times play no part." }
] }
```

### Write messages people can use

A good message answers "what does this commit do, and why?".

```
Add login rate limiting                 <- subject: imperative, ~50 chars, no period

Block an IP for 60 s after 5 failed     <- blank line, then the body:
logins. Stops password-guessing bots     why the change was needed
seen in last week's logs.
```

Rule of thumb: the subject completes the sentence "If applied, this commit
will... *add login rate limiting*". Many teams also use the **Conventional
Commits** style: `feat: add login rate limiting`, `fix: ...`, `docs: ...`.

| Weak | Better |
|---|---|
| `stuff` | `Fix crash when cart is empty` |
| `updates` | `Rename price helper to pricing` |
| `final fix 2` | `Round tax to two decimals` |

## Try it

Your global email is your personal one, but one repository is for work and needs
`ada@company.com`. Which command do you run, and where?

<details>
<summary>Show answer</summary>

Inside the work repository:

```bash
git config user.email "ada@company.com"
```

No flag means `--local`, stored in that repo's `.git/config`. It overrides the
global value only there.

</details>

## Common mistakes

- **Committing before setting identity.** Git then guesses something like
  `labuser@hostname`, or refuses. Fix future commits with `git config`; fix the
  last commit with `git commit --amend --reset-author --no-edit`.
- **Using a different email from your hosting account.** GitHub cannot link the
  commits to you. Use the same email (or the host's private no-reply email).
- **Messages like "wip" on shared branches.** Fine while working, but tidy them
  before review (Section 8 shows how).

## Remember

- `user.name` and `user.email` go into every commit; set them with `--global`.
- Config levels: system < global < local. Local wins.
- `git add` then `git commit -m "..."` makes a commit; `git log --oneline` lists them.
- Message subject: imperative, short, says what and why.

**Self-check:**

1. Which file does `git config --global` write to?
2. Which wins when global and local both set `user.email`?
3. Rewrite `fixed stuff` as a useful subject for a commit that fixes a crash when the cart is empty.
