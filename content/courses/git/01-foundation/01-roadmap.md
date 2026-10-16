---
kind: lesson
id_key: git/foundation/roadmap
course: git
section: foundation
section_title: "Big Picture: Why Git"
section_position: 1
title: "Big Picture: What Git Is and How This Course Works"
position: 0
estimated_minutes: 8
source:
  - Pro Git book, ch. 1 "Getting Started"
---

## Why this matters

You have a report due. You paste the wrong text over it, save, and close the
editor. The real report is gone. Without version control that is a bad
afternoon. With Git it is one command, and you will run it in the first lab.

Git is the tool almost every software team uses to keep the history of their
work. Knowing it well saves you from lost work, broken releases and painful
team merges.

## Mental model: a time machine with save points

> **One-sentence definition:** Git is a program that saves snapshots of your
> project (called **commits**) and lets you move between them, compare them and
> combine work from many people.

Think of a video game with save points:

- You **save** whenever the project is in a good state (a commit).
- You can **load** any earlier save (restore old files).
- You can start a **second storyline** from any save without losing the first
  one (a branch).
- A friend can **send you their storyline** and you can merge it into yours
  (pull, merge).

Before Git, history lived in file names like `report_final_v2_REAL.docx`. Git
records every change, who made it and why.

### Centralized vs distributed

```
 Centralized (e.g. SVN)              Distributed (Git)
 +--------+                          +--------+   +--------+
 | server | <- the only history      | laptop |   | GitHub |  every copy has
 +--------+                          +--------+   +--------+  the FULL history
   ^   ^                                  ^            ^
 no server = no commits               work offline, sync when ready
```

Your copy of a project (a **clone**) is a complete repository. Commits,
branches and history all work without a network. A server such as GitHub or
GitLab is just another copy that the team agrees to share.

- **Repository (repo):** a project folder plus its full history, stored in a
  hidden `.git` directory.
- **Remote:** another copy of the repo, usually on a server.

## See it work

You will type all of this yourself later. For now, just read the shape of a
Git session:

```bash
git init               # turn the current folder into a repository
git add report.txt     # choose what goes into the next snapshot
git commit -m "Add report"   # save the snapshot with a message
git log --oneline      # list the snapshots
```

Expected output of the last command (your hash will differ):

```
3f1c9ab (HEAD -> main) Add report
```

`3f1c9ab` is the commit's short ID. `main` is the branch you are on. `HEAD`
means "where you are now".

## The course roadmap

Each section teaches one group of skills, then a lab checks them in a real
terminal, then a quiz makes you recall them.

| # | Section | You will be able to... |
|---|---|---|
| 1 | Big picture | Explain commits and branches; rescue a file |
| 2 | First commits | Init, stage, commit, ignore files, amend |
| 3 | Connecting | Add remotes, authenticate with SSH or tokens |
| 4 | Clone, fetch, pull, push | Run the daily team loop |
| 5 | Branching and merging | Branch, fast-forward, merge commits |
| 6 | Conflicts | Read, resolve and abort conflicts calmly |
| 7 | Under the hood | Explain objects, refs, the index and the DAG |
| 8 | Rebase | Rebase, clean up history, force-push safely |
| 9 | Undo and recovery | restore, reset, reflog, revert, cherry-pick, stash |
| 10 | Investigation | log, blame, pickaxe search, bisect |
| 11 | Team workflows | Branching strategies, tags, hooks, signing |
| 12 | Power tools | Worktrees, submodules, huge repositories |
| 13 | Troubleshooting | Fix the 12 most common Git emergencies |
| 14 | Capstone | Run a full feature-to-release workflow |

The story: you join a small company called **Brightside** on day one. Maya, the
tech lead, gives you tasks that get harder each day.

### How to study each lesson

Every lesson has the same parts, so you always know where you are:

1. **Why this matters** - the real problem.
2. **Mental model** - a picture to hang the idea on.
3. **See it work** - a short example with expected output.
4. **Try it** - a small task; the answer is hidden until you click.
5. **Common mistakes** - traps to avoid.
6. **Remember** - the few lines worth keeping.

Answer the self-check questions **from memory** before scrolling back. Pulling
an answer out of your head is what makes it stick.

## Try it

Without looking back: name two things Git lets you do that copying files into
`report_v2`, `report_v3` folders does not.

<details>
<summary>Show answer</summary>

Any two of: see exactly what changed between versions and who changed it; work
on two ideas at once on separate branches; combine work from several people
automatically; go back to any earlier version with one command; work offline
with full history.

</details>

## Common mistakes

- **"Git and GitHub are the same thing."** Git is the program on your machine.
  GitHub (and GitLab, Bitbucket) are websites that host Git repositories and add
  pull requests, reviews and CI.
- **"I need the internet to commit."** You do not. Only sharing (push, pull,
  fetch) needs the network.
- **Treating Git as a backup tool only.** It is a history and collaboration
  tool. A repo that only lives on your laptop is not a backup.

## Remember

- Git saves **snapshots** (commits) of your whole project.
- Every clone holds the **full history**; servers are just shared copies.
- `HEAD` = where you are now. `main` = the usual name of the main branch.
- Each section: lessons, then a lab, then a quiz.

**Self-check:**

1. What is the difference between Git and GitHub?
2. Which Git actions need a network connection?
3. What does `HEAD` mean in `(HEAD -> main)`?
