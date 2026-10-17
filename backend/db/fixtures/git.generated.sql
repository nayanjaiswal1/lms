-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-10-16T15:57:22Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Git: Commits, Branches, Merges, Rebase and Recovery ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, is_public, estimated_hours)
VALUES ('ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Git: Commits, Branches, Merges, Rebase and Recovery', 'git', 'A hands-on Git course in short, one-idea lessons, each followed by graded labs in a real terminal and scenario quizzes. Start from commits, the staging area, remotes and authentication; learn branching, merging, conflicts and rebase; see how Git works inside (objects, refs, the index, the reflog); undo and recover anything with restore, reset, revert, cherry-pick and stash; investigate history with blame, pickaxe search and bisect; then work like a team with branching strategies, tags and releases, hooks, commit signing, worktrees, submodules, large-repo tools and a troubleshooting playbook, ending in a capstone feature-to-release workflow and a final exam.', '/course-covers/git.png', 'beginner', ARRAY['git','version-control','cli'], 'published', true, false, 16.8)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, is_public=EXCLUDED.is_public, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

UPDATE course_sections SET position = position + 100000 WHERE course_id = 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44';
UPDATE course_modules SET position = position + 100000 WHERE course_id = 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44';

-- Section: Big Picture: Why Git
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('0384711a-2cc2-592c-ab3b-3c6fe336cbcc', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Big Picture: Why Git', 1, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('d6dc6197-76ec-5c0b-8983-66c2a01b5a38', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0384711a-2cc2-592c-ab3b-3c6fe336cbcc', 'Big Picture: What Git Is and How This Course Works', 'notes', 0, $md$## Why this matters

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
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1c094615-76a8-5b1f-8648-dafea434db57', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0384711a-2cc2-592c-ab3b-3c6fe336cbcc', 'Commits Are Snapshots, Branches Are Pointers', 'notes', 1, $md$## Why this matters

Two ideas explain most of Git: a **commit** is a full snapshot with a unique
name, and a **branch** is a tiny label pointing at one commit. Once these click,
commands like merge, rebase and reset stop feeling like magic.

## Mental model: a chain of photos with sticky notes

Imagine taking a photo of your whole desk every time you finish a task. Each
photo has a caption and says which photo came before it. That is a commit.

Now put a sticky note saying "main" on the newest photo. When you take the next
photo, you move the sticky note forward. That sticky note is a branch.

```
 A <-- B <-- C          each commit points to its parent
             ^
            main        a branch is a label on one commit
             ^
            HEAD        HEAD says which label you are using
```

## See it work

### A commit is a snapshot, not a diff

When you commit, Git stores the **whole project** as it looked at that moment
(it reuses unchanged files internally, so this is cheap). Git can still show you
the differences between two snapshots on demand.

Each commit gets a 40-character ID called a **hash**, computed from:

- the snapshot of files,
- the author, date and message,
- the hash of the **parent** commit.

```bash
git log --format='%h %p %s'
```

What this does: prints each commit's short hash, its parent's short hash and
its message. Expected output (hashes differ):

```
9e41c2d 3f1c9ab Add summary stub
3f1c9ab         Add quarterly report
```

The first commit has no parent. It is called the **root commit**.

Because each hash includes the parent's hash, changing any old commit would
change every hash after it. This is why history cannot be edited silently.

### Getting a file back from a snapshot

Committed snapshots stay in the repository. If you overwrite a tracked file by
accident, Git can copy the committed version back:

```bash
git status            # report.txt shows as "modified"
git restore report.txt
git status
```

Expected output of the last command:

```
On branch main
nothing to commit, working tree clean
```

```knowledge-check
{ "questions": [
  { "id": "git-foundation-q1", "type": "mcq",
    "prompt": "You overwrote a tracked file by accident and had committed it earlier. Is the old content lost?",
    "options": [
      {"id":"a","text":"Yes, the file is gone for good"},
      {"id":"b","text":"No, Git still has the committed snapshot and can restore it"},
      {"id":"c","text":"Only if you have a remote"},
      {"id":"d","text":"Only if you saved a backup copy"}],
    "correct": "b",
    "explanation": "Committed snapshots stay in the repository. git restore brings the file back. A remote is not needed, and no manual backup is needed." }
] }
```

### A branch is just a pointer

```
 main        A---B
                  \
 experiment        C     <- your risky idea, isolated
```

```bash
git switch -c experiment   # create a branch here and move onto it
```

Creating a branch writes one small file containing a commit hash. It does not
copy your files. That is why branches are instant and free. Try a bold idea on a
branch; if it fails, delete the branch and `main` never noticed.

```knowledge-check
{ "questions": [
  { "id": "git-foundation-q2", "type": "mcq",
    "prompt": "What is a Git branch?",
    "options": [
      {"id":"a","text":"A full copy of all project files"},
      {"id":"b","text":"A movable pointer to a commit"},
      {"id":"c","text":"A separate repository"},
      {"id":"d","text":"A list of changed lines"}],
    "correct": "b",
    "explanation": "A branch is a tiny pointer, which is why creating one is instant. It copies no files, is not a separate repository, and stores no line changes." }
] }
```

## Try it

Look at this history:

```
 A---B---C   <- main
      \
       D     <- fix
```

1. What is D's parent?
2. If you commit while on `main`, which label moves?

<details>
<summary>Show answer</summary>

1. B. The line from D goes back to B.
2. `main` moves to the new commit. `fix` stays on D. Only the branch you are on
   (the one HEAD points to) moves when you commit.

</details>

## Common mistakes

- **Thinking a commit stores only the changed lines.** It stores a full
  snapshot. Diffs are calculated when you ask for them.
- **Thinking a branch is a folder copy.** Nothing is copied. Switching
  branches just swaps which snapshot your folder shows.
- **Fearing the hash.** You never need to type all 40 characters. The first 7
  are usually enough, and branch names work almost everywhere a hash does.

## Remember

- Commit = full snapshot + author + message + parent link, named by a hash.
- Changing an old commit changes every hash after it.
- Branch = movable label on one commit. HEAD = the label you are using.
- `git restore <file>` copies the committed version back over your edits.

**Self-check:**

1. What three kinds of information go into a commit's hash?
2. Why is creating a branch instant?
3. Which branch moves when you commit?
$md$, 9, $json$[{"id":"git-foundation-q1","type":"mcq","correct":"b"},{"id":"git-foundation-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0f965b49-b633-5fb1-82b3-2b65dcf9af2e', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0384711a-2cc2-592c-ab3b-3c6fe336cbcc', 'Lab: Rescue a File, Find the First Commit, Branch Safely', 'notes', 2, $md$## Why this matters

You have read what Git protects you from. Now feel it: rescue an overwritten
file, find where a history began, and try a risky idea on a branch without
touching `main`. Each task is checked automatically in a real terminal.

## Before you start

The lab already contains a repository at `~/work/notes` with two commits. Someone
just pasted the wrong text over `report.txt`. Move into it first:

```bash
cd ~/work/notes
git status
```

Expected output:

```
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   report.txt
```

Read the hint lines. Git usually tells you the next command.

## Task 1: rescue the report

The committed snapshot still holds the real report. Copy it back over the
broken file (lesson 2 showed the command).

[[lab-task:1]]

What you should see after the fix:

```
$ git status
On branch main
nothing to commit, working tree clean
```

## Task 2: find the first commit

Every history starts at a root commit (a commit with no parent). Print full
hashes with `git log --format=%H`; the oldest commit is the last line. Save just
that hash into `~/work/first.txt`.

[[lab-task:2]]

Check yourself: `cat ~/work/first.txt` shows a single 40-character hash.

## Task 3: experiment on a branch

Create a branch named `experiment`, change `summary.txt` on it and commit with
the message `Try a bold rewrite`. `main` must stay exactly as it was.

```
 main        A---B
                  \
 experiment        C   "Try a bold rewrite"
```

[[lab-task:3]]

Check yourself:

```bash
git log --oneline --all --graph
git show main:summary.txt     # still prints: TODO: write summary
```

## Remember

- `git status` reads the situation and suggests the next command.
- `git restore <file>` brings back the committed version.
- A branch lets you experiment while `main` stays safe.
$md$, 20, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('cc52be6c-09b7-567c-9a9c-e61e072f27ba', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0f965b49-b633-5fb1-82b3-2b65dcf9af2e', 'module', 'Lab: Rescue a File, Find the First Commit, Branch Safely', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
rm -rf /home/labuser/work/notes /home/labuser/work/first.txt
mkdir -p /home/labuser/work/notes && cd /home/labuser/work/notes
git init -q
export GIT_AUTHOR_DATE="2024-01-01T10:00:00+0000" GIT_COMMITTER_DATE="2024-01-01T10:00:00+0000"
echo "Quarterly report: revenue up 12 percent" > report.txt
git add -A; git commit -q -m "Add quarterly report"
export GIT_AUTHOR_DATE="2024-01-02T10:00:00+0000" GIT_COMMITTER_DATE="2024-01-02T10:00:00+0000"
echo "TODO: write summary" > summary.txt
git add -A; git commit -q -m "Add summary stub"
echo "oops, pasted the wrong thing" > report.txt
chmod -R a+rwX /home/labuser/work/notes
$script$, NULL, 30, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '9e9ba1b8-3cd8-58df-a3f2-91061f21f5cf' AND id NOT IN ('8a2dbe40-b5a7-5fbc-930b-d4e63cdd51e3', 'e7569ab1-2fc5-5971-a4c2-ccd13acf78f1', '22b5ed44-c00d-5be6-8151-a8b8760af9f3');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '9e9ba1b8-3cd8-58df-a3f2-91061f21f5cf';
DELETE FROM lab_tasks WHERE lab_id = 'cc52be6c-09b7-567c-9a9c-e61e072f27ba' AND id NOT IN ('57aee3ea-1351-5a27-b8c4-cc4ad40e2178', '6aa49c71-9b47-55ef-bbdf-00a36a8cc585', 'e6972c82-98ed-501d-89bc-6270289b3271');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'cc52be6c-09b7-567c-9a9c-e61e072f27ba';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('57aee3ea-1351-5a27-b8c4-cc4ad40e2178', 'cc52be6c-09b7-567c-9a9c-e61e072f27ba', 1, 'Rescue the overwritten report', $md$In the notes repository inside your work directory, report.txt was just overwritten by accident and the real report is gone from disk. Bring it back exactly as it was in the last commit.$md$, $script$r=/home/labuser/work/notes
[ "$(cat $r/report.txt)" = "Quarterly report: revenue up 12 percent" ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git status will tell you which command restores a file from the last commit.', 'Git keeps every committed snapshot, so an overwritten file is one command from being back. git restore copies the committed version over the working copy.', 10, false, true),
('6aa49c71-9b47-55ef-bbdf-00a36a8cc585', 'cc52be6c-09b7-567c-9a9c-e61e072f27ba', 2, 'Find where the story began', $md$Find the full hash of the very first commit in the notes repository and write it, alone on one line, into a file called first.txt inside your work directory.$md$, $script$r=/home/labuser/work/notes
[ "$(tr -d '[:space:]' < /home/labuser/work/first.txt)" = "$(git -C $r rev-list --max-parents=0 HEAD)" ]
$script$, 'git log --oneline shows short hashes. git log --format=%H prints full ones, and the first commit is the last line.', 'Every commit has a unique hash computed from its content and its parent. The first commit has no parent, so it is the root of the history.', 10, false, true),
('e6972c82-98ed-501d-89bc-6270289b3271', 'cc52be6c-09b7-567c-9a9c-e61e072f27ba', 3, 'Experiment without fear', $md$Create a branch called experiment, and on it make one commit with the message "Try a bold rewrite" that changes summary.txt. Branch main must stay exactly as it was.$md$, $script$r=/home/labuser/work/notes
[ "$(git -C $r rev-list --count main)" = 2 ] &&
[ "$(git -C $r rev-list --count experiment)" = 3 ] &&
[ "$(git -C $r log -1 --format=%s experiment)" = "Try a bold rewrite" ] &&
[ "$(git -C $r show main:summary.txt)" = "TODO: write summary" ]
$script$, 'git switch -c experiment creates and moves to the branch. Edit summary.txt, then add and commit.', 'A branch is just a pointer to a commit, so creating one is instant and free. Your experiment lives on its own line of history and main is untouched.', 15, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('9e9ba1b8-3cd8-58df-a3f2-91061f21f5cf', 'cc52be6c-09b7-567c-9a9c-e61e072f27ba', 1, $json$[{"id":"57aee3ea-1351-5a27-b8c4-cc4ad40e2178","lab_id":"cc52be6c-09b7-567c-9a9c-e61e072f27ba","position":1,"title":"Rescue the overwritten report","description":"In the notes repository inside your work directory, report.txt was just overwritten by accident and the real report is gone from disk. Bring it back exactly as it was in the last commit.","verification_script":"r=/home/labuser/work/notes\n[ \"$(cat $r/report.txt)\" = \"Quarterly report: revenue up 12 percent\" ] \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"git status will tell you which command restores a file from the last commit.","explanation_context":"Git keeps every committed snapshot, so an overwritten file is one command from being back. git restore copies the committed version over the working copy.","points":10,"is_optional":false,"is_stateful":true},{"id":"6aa49c71-9b47-55ef-bbdf-00a36a8cc585","lab_id":"cc52be6c-09b7-567c-9a9c-e61e072f27ba","position":2,"title":"Find where the story began","description":"Find the full hash of the very first commit in the notes repository and write it, alone on one line, into a file called first.txt inside your work directory.","verification_script":"r=/home/labuser/work/notes\n[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/first.txt)\" = \"$(git -C $r rev-list --max-parents=0 HEAD)\" ]\n","hint_context":"git log --oneline shows short hashes. git log --format=%H prints full ones, and the first commit is the last line.","explanation_context":"Every commit has a unique hash computed from its content and its parent. The first commit has no parent, so it is the root of the history.","points":10,"is_optional":false,"is_stateful":true},{"id":"e6972c82-98ed-501d-89bc-6270289b3271","lab_id":"cc52be6c-09b7-567c-9a9c-e61e072f27ba","position":3,"title":"Experiment without fear","description":"Create a branch called experiment, and on it make one commit with the message \"Try a bold rewrite\" that changes summary.txt. Branch main must stay exactly as it was.","verification_script":"r=/home/labuser/work/notes\n[ \"$(git -C $r rev-list --count main)\" = 2 ] \u0026\u0026\n[ \"$(git -C $r rev-list --count experiment)\" = 3 ] \u0026\u0026\n[ \"$(git -C $r log -1 --format=%s experiment)\" = \"Try a bold rewrite\" ] \u0026\u0026\n[ \"$(git -C $r show main:summary.txt)\" = \"TODO: write summary\" ]\n","hint_context":"git switch -c experiment creates and moves to the branch. Edit summary.txt, then add and commit.","explanation_context":"A branch is just a pointer to a commit, so creating one is instant and free. Your experiment lives on its own line of history and main is untouched.","points":15,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('8a2dbe40-b5a7-5fbc-930b-d4e63cdd51e3', '9e9ba1b8-3cd8-58df-a3f2-91061f21f5cf', '57aee3ea-1351-5a27-b8c4-cc4ad40e2178', 1, 'Rescue the overwritten report', $md$In the notes repository inside your work directory, report.txt was just overwritten by accident and the real report is gone from disk. Bring it back exactly as it was in the last commit.$md$, $script$r=/home/labuser/work/notes
[ "$(cat $r/report.txt)" = "Quarterly report: revenue up 12 percent" ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git status will tell you which command restores a file from the last commit.', 'Git keeps every committed snapshot, so an overwritten file is one command from being back. git restore copies the committed version over the working copy.', 10, false, true),
('e7569ab1-2fc5-5971-a4c2-ccd13acf78f1', '9e9ba1b8-3cd8-58df-a3f2-91061f21f5cf', '6aa49c71-9b47-55ef-bbdf-00a36a8cc585', 2, 'Find where the story began', $md$Find the full hash of the very first commit in the notes repository and write it, alone on one line, into a file called first.txt inside your work directory.$md$, $script$r=/home/labuser/work/notes
[ "$(tr -d '[:space:]' < /home/labuser/work/first.txt)" = "$(git -C $r rev-list --max-parents=0 HEAD)" ]
$script$, 'git log --oneline shows short hashes. git log --format=%H prints full ones, and the first commit is the last line.', 'Every commit has a unique hash computed from its content and its parent. The first commit has no parent, so it is the root of the history.', 10, false, true),
('22b5ed44-c00d-5be6-8151-a8b8760af9f3', '9e9ba1b8-3cd8-58df-a3f2-91061f21f5cf', 'e6972c82-98ed-501d-89bc-6270289b3271', 3, 'Experiment without fear', $md$Create a branch called experiment, and on it make one commit with the message "Try a bold rewrite" that changes summary.txt. Branch main must stay exactly as it was.$md$, $script$r=/home/labuser/work/notes
[ "$(git -C $r rev-list --count main)" = 2 ] &&
[ "$(git -C $r rev-list --count experiment)" = 3 ] &&
[ "$(git -C $r log -1 --format=%s experiment)" = "Try a bold rewrite" ] &&
[ "$(git -C $r show main:summary.txt)" = "TODO: write summary" ]
$script$, 'git switch -c experiment creates and moves to the branch. Edit summary.txt, then add and commit.', 'A branch is just a pointer to a commit, so creating one is instant and free. Your experiment lives on its own line of history and main is untouched.', 15, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '9e9ba1b8-3cd8-58df-a3f2-91061f21f5cf', updated_at = now()
WHERE id = 'cc52be6c-09b7-567c-9a9c-e61e072f27ba' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e229f8ed-c11b-55ee-b634-2fe4c052b423', '00000000-0000-0000-0000-000000000001', 'mcq', 'You are on a plane with no Wi-Fi. Which of these can you still do in your clo...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('6a7f5212-54e2-5a9f-91f4-186ac0d32d02', 'e229f8ed-c11b-55ee-b634-2fe4c052b423', 1, $json${"prompt":"You are on a plane with no Wi-Fi. Which of these can you still do in your clone of a Git repository?","multiple":false,"options":[{"id":"a","text":"Nothing; Git needs the server for every command","is_correct":false},{"id":"b","text":"Commit, create branches and read the full history","is_correct":true},{"id":"c","text":"Only read files; commits wait until you are online","is_correct":false},{"id":"d","text":"Push to GitHub, which queues the upload","is_correct":false}],"explanation":"A clone is a complete repository, so committing, branching and reading history are all local. Only talking to another copy (push, pull, fetch) needs a network. Git has no offline push queue: push simply fails until you are online."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7559b761-8f93-54b4-85b8-98cefb0a385b', '00000000-0000-0000-0000-000000000001', 'mcq', 'A teammate says: ''I changed the message of a commit from last month and nobod...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('63619c58-abab-584b-a9fd-c3827f63ca10', '7559b761-8f93-54b4-85b8-98cefb0a385b', 1, $json${"prompt":"A teammate says: 'I changed the message of a commit from last month and nobody noticed.' Why should that sound suspicious?","multiple":false,"options":[{"id":"a","text":"Commit messages cannot be edited by any command","is_correct":false},{"id":"b","text":"Each commit's hash includes its parent's hash, so changing an old commit changes every later hash, which shows up for everyone who has the old history","is_correct":true},{"id":"c","text":"Git emails the whole team when a message changes","is_correct":false},{"id":"d","text":"Only the repository owner can edit messages","is_correct":false}],"explanation":"History is a hash chain. Editing an old commit creates a new commit with a new hash, and every commit after it also gets a new hash. Other clones still have the old hashes, so the histories diverge visibly. Messages can be rewritten (rebase), but not silently; Git sends no emails and has no owner-only edit rule."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8bfbe397-4f09-5707-997e-ccd3cf52f703', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your history is A---B---C with main on C. You create a branch `idea` and comm...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ee8d499d-90a6-5530-808f-42b27ec9b207', '8bfbe397-4f09-5707-997e-ccd3cf52f703', 1, $json${"prompt":"Your history is A---B---C with main on C. You create a branch `idea` and commit D while on it. Where do the labels point now?","multiple":false,"options":[{"id":"a","text":"main on D, idea on C","is_correct":false},{"id":"b","text":"main on C, idea on D","is_correct":true},{"id":"c","text":"Both on D","is_correct":false},{"id":"d","text":"Both on C; labels only move when you push","is_correct":false}],"explanation":"Only the branch you are on (the one HEAD points to) moves when you commit. You were on idea, so idea moves to D and main stays on C. Labels move locally on every commit; pushing is not involved."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cdaa0ebd-c7c3-5e1b-814e-1bce4612951f', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why is creating a branch in Git instant, even in a huge project?', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4f2b1a80-da3c-5954-b9e6-184e42dc6f96', 'cdaa0ebd-c7c3-5e1b-814e-1bce4612951f', 1, $json${"prompt":"Why is creating a branch in Git instant, even in a huge project?","multiple":false,"options":[{"id":"a","text":"Git copies files in the background","is_correct":false},{"id":"b","text":"A branch is a small file holding one commit hash; no project files are copied","is_correct":true},{"id":"c","text":"Branches are stored on the server, not on disk","is_correct":false},{"id":"d","text":"Git compresses the copy","is_correct":false}],"explanation":"A branch is a pointer to a commit. There is no copy, background or compressed, and branches live locally in .git, not only on a server."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('851d9489-be66-5b6b-be85-8357847fc56b', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the relationship between Git and GitHub?', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('74624901-81fe-57de-80b1-2388a0b83485', '851d9489-be66-5b6b-be85-8357847fc56b', 1, $json${"prompt":"What is the relationship between Git and GitHub?","multiple":false,"options":[{"id":"a","text":"They are two names for the same program","is_correct":false},{"id":"b","text":"GitHub is a hosting service for Git repositories that adds features like pull requests; Git is the version control program itself","is_correct":true},{"id":"c","text":"Git is the website, GitHub is the command-line tool","is_correct":false},{"id":"d","text":"GitHub is required for Git to work","is_correct":false}],"explanation":"Git runs on your machine and works without any server. GitHub, GitLab and Bitbucket host shared copies and add review, CI and access control. Git does not depend on them."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5108266b-2271-5547-979b-51473b38672e', '00000000-0000-0000-0000-000000000001', 'mcq', 'You overwrote report.txt with junk. It was committed yesterday. Which command...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d9d6a2b1-0c5b-5cda-8908-8873c2850d3e', '5108266b-2271-5547-979b-51473b38672e', 1, $json${"prompt":"You overwrote report.txt with junk. It was committed yesterday. Which command brings back yesterday's version of the file?","multiple":false,"options":[{"id":"a","text":"git restore report.txt","is_correct":true},{"id":"b","text":"git commit report.txt","is_correct":false},{"id":"c","text":"git init","is_correct":false},{"id":"d","text":"git log report.txt","is_correct":false}],"explanation":"git restore copies the committed version over the working copy. git commit would save the junk as a new snapshot, git init creates a new repository, and git log only lists history."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('74905e86-ea8f-5d9f-8455-5869b8b4a706', '00000000-0000-0000-0000-000000000001', 'Quiz: Big Picture', 'git-foundation-quiz', 'Quiz covering Big Picture: Why Git.', 'mcq', 'published', 'module', '0d98c661-e4d9-5afb-b37d-daa8aa72b66d', 8, 70, 5, 12, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '74905e86-ea8f-5d9f-8455-5869b8b4a706' AND question_id NOT IN ('e229f8ed-c11b-55ee-b634-2fe4c052b423', '7559b761-8f93-54b4-85b8-98cefb0a385b', '8bfbe397-4f09-5707-997e-ccd3cf52f703', 'cdaa0ebd-c7c3-5e1b-814e-1bce4612951f', '851d9489-be66-5b6b-be85-8357847fc56b', '5108266b-2271-5547-979b-51473b38672e');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('0ae9b5ea-37c5-50e2-909a-534e3c85f1d9', '74905e86-ea8f-5d9f-8455-5869b8b4a706', 'e229f8ed-c11b-55ee-b634-2fe4c052b423', '6a7f5212-54e2-5a9f-91f4-186ac0d32d02', 0, 2),
('4601b341-be59-543f-9c15-d80a8ae0f66f', '74905e86-ea8f-5d9f-8455-5869b8b4a706', '7559b761-8f93-54b4-85b8-98cefb0a385b', '63619c58-abab-584b-a9fd-c3827f63ca10', 1, 2),
('900b72b0-69ba-5b53-94d5-cca6a84eee98', '74905e86-ea8f-5d9f-8455-5869b8b4a706', '8bfbe397-4f09-5707-997e-ccd3cf52f703', 'ee8d499d-90a6-5530-808f-42b27ec9b207', 2, 2),
('d7c6edfa-e6a2-5f01-8358-3f1696dbbc44', '74905e86-ea8f-5d9f-8455-5869b8b4a706', 'cdaa0ebd-c7c3-5e1b-814e-1bce4612951f', '4f2b1a80-da3c-5954-b9e6-184e42dc6f96', 3, 2),
('061f60ce-a24e-57a7-ab5c-ce6b08ee737a', '74905e86-ea8f-5d9f-8455-5869b8b4a706', '851d9489-be66-5b6b-be85-8357847fc56b', '74624901-81fe-57de-80b1-2388a0b83485', 4, 2),
('25fd64b1-755b-5876-9dad-c48e91daf1ab', '74905e86-ea8f-5d9f-8455-5869b8b4a706', '5108266b-2271-5547-979b-51473b38672e', 'd9d6a2b1-0c5b-5cda-8908-8873c2850d3e', 5, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('0d98c661-e4d9-5afb-b37d-daa8aa72b66d', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0384711a-2cc2-592c-ab3b-3c6fe336cbcc', 'Quiz: Big Picture', 'assessment', 3, 6, '74905e86-ea8f-5d9f-8455-5869b8b4a706')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Setup and First Commits
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('30bd438b-14f7-5688-bfd5-d78aef9b27d3', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Setup and First Commits', 2, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a9550002-456c-5497-9e5b-c003a8ee3911', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '30bd438b-14f7-5688-bfd5-d78aef9b27d3', 'The Three Areas: Working Tree, Index and Repository', 'notes', 0, $md$## Why this matters

Day 1 at Brightside. Maya hands you an empty folder: "Start the hello tool.
Commit as you go; the whole team will read this history." Almost every beginner
confusion ("why is my change not in the commit?") comes from not knowing which
of Git's three areas a file is in. Learn the areas once and `git status` becomes
easy to read.

## Mental model: desk, outbox, archive

| Area | Analogy | What it holds |
|---|---|---|
| **Working tree** | Your desk | The files you see and edit |
| **Index** (staging area) | The outbox tray | Exactly what the next commit will contain |
| **Repository** (`.git`) | The archive | Every commit ever made |

You work at the desk, put finished pages in the outbox, and when the outbox is
ready you seal it into the archive as one commit.

```
 WORKING TREE            INDEX (staging)             REPOSITORY (.git)
 files you edit   --->   next commit's snapshot --->  permanent history
                 git add                    git commit
       <---------------- git restore -----------------
```

> **One-sentence definition:** the **index** is a draft of your next commit.
> `git add` updates the draft; `git commit` saves the draft as a snapshot.

Why have a draft at all? Because you often edit five files but want to commit
only two of them as one tidy change.

## See it work

### Create a repository

```bash
mkdir -p ~/work/hello && cd ~/work/hello
git init
git status
```

What this does: `git init` creates the hidden `.git` directory (the repository).
Nothing is committed yet. Expected output:

```
Initialized empty Git repository in /home/labuser/work/hello/.git/
On branch main

No commits yet

nothing to commit (create/copy files and use "git add" to track)
```

The first branch is called `main` because of the setting
`init.defaultBranch`. Older Git versions used `master`. You can set it once with
`git config --global init.defaultBranch main`.

### Watch a file move through the areas

```bash
echo "# Hello" > README.md
git status -s       # ?? README.md   -> untracked: only on your desk
git add README.md
git status -s       # A  README.md   -> added to the index (outbox)
```

- **Untracked** = Git has never seen this file. It is not in the index or any
  commit.
- **Tracked** = the file is in the index (and usually in the last commit).

Never delete or edit files inside `.git` by hand. It is Git's database.

```knowledge-check
{ "questions": [
  { "id": "git-first-areas-q1", "type": "mcq",
    "prompt": "Which area does git commit actually snapshot?",
    "options": [
      {"id":"a","text":"The working tree"},
      {"id":"b","text":"The index (staging area)"},
      {"id":"c","text":"The remote repository"},
      {"id":"d","text":"Only files modified in the last hour"}],
    "correct": "b",
    "explanation": "A commit is built from the index. Edits you did not git add are not part of it, the remote is not involved, and time does not matter." }
] }
```

## Try it

You edit `a.txt` and `b.txt`, then run `git add a.txt` and `git commit -m
"Update a"`. Where is your change to `b.txt` now?

<details>
<summary>Show answer</summary>

Still only in the working tree (on your desk). It was never added to the index,
so it is not in the commit. `git status` lists it under "Changes not staged for
commit".

</details>

## Common mistakes

- **Running `git init` in your home directory.** Then every file you own looks
  untracked. Run it inside the project folder. If it happened, delete only that
  stray `~/.git` directory.
- **Thinking `git add` is only for new files.** You `git add` every change you
  want in the next commit, including edits to tracked files.
- **Editing after `git add` and expecting the edit to be committed.** The index
  holds the version from the moment you ran `git add`. Add again after editing.

## Remember

- Three areas: working tree (desk) -> index (outbox) -> repository (archive).
- `git add` = put into the next commit. `git commit` = save the index.
- `git status` tells you which area every changed file is in.
- `git init` creates `.git`; never edit it by hand.

**Self-check:**

1. What does the index contain?
2. What does `??` mean in `git status -s`?
3. You edited a file after `git add`. Which version will the commit contain?
$md$, 8, $json$[{"id":"git-first-areas-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5a838085-8cf1-5b89-826b-3cd3fc75a0b7', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '30bd438b-14f7-5688-bfd5-d78aef9b27d3', 'Identity, Config and Your First Commit', 'notes', 1, $md$## Why this matters

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
$md$, 9, $json$[{"id":"git-first-commit-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('659a4382-f208-55a0-8b4a-959595e3ee51', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '30bd438b-14f7-5688-bfd5-d78aef9b27d3', 'Ignoring Files with .gitignore', 'notes', 2, $md$## Why this matters

Logs, build output, dependency folders and secrets must never be committed.
Logs bloat history, build output causes pointless conflicts, and a committed
password stays in history even after you delete the file. `.gitignore` keeps
them out from the start.

## Mental model: a bouncer for untracked files

`.gitignore` is a bouncer at the door of the index. It stops **new** (untracked)
files from walking in when you run `git add .`. It does nothing to files that
are already inside (tracked).

```
 untracked file --> [ .gitignore bouncer ] --x  blocked: not shown in status, not added
 tracked file   --> already inside; the bouncer ignores it
```

## See it work

### Write the rules

```bash
printf '*.log\nbuild/\n.env\n' > .gitignore
cat .gitignore
```

What this does: creates a `.gitignore` with three patterns. Expected output:

```
*.log
build/
.env
```

| Pattern | Matches |
|---|---|
| `*.log` | any file ending in `.log`, in any folder |
| `build/` | a directory named `build`, anywhere |
| `/build/` | only `build` at the repository root |
| `.env` | a file named `.env` anywhere |
| `!keep.log` | an exception: do NOT ignore `keep.log` |
| `docs/**/*.tmp` | `.tmp` files at any depth under `docs` |
| `# note` | a comment |

Commit `.gitignore` itself so the whole team shares the rules.

### Check that a rule works

```bash
echo noise > app.log
git status -s                 # app.log is NOT listed
git check-ignore -v app.log
```

Expected output of the last command:

```
.gitignore:1:*.log	app.log
```

It tells you the file, line number and pattern that matched. Use it whenever
you wonder "why is this file ignored?".

### Where else ignore rules can live

| File | Shared with team? | Use for |
|---|---|---|
| `.gitignore` (committed) | Yes | Project build output, logs, `.env` |
| `.git/info/exclude` | No | Your personal scratch files in one repo |
| `core.excludesFile` (e.g. `~/.config/git/ignore`) | No | Editor and OS junk (`.DS_Store`, `.idea/`) everywhere |

### Stopping tracking of a file that is already committed

```bash
git rm --cached app.log      # remove from the index, keep the file on disk
echo "*.log" >> .gitignore
git commit -m "Stop tracking app.log"
```

`--cached` means "only the index". Without it, `git rm` also deletes the file
from your disk.

```knowledge-check
{ "questions": [
  { "id": "git-first-ignore-q1", "type": "mcq",
    "prompt": "You add app.log to .gitignore AFTER committing it. What happens to the already-tracked app.log?",
    "options": [
      {"id":"a","text":"It is deleted from history"},
      {"id":"b","text":"It stays tracked until you git rm --cached it"},
      {"id":"c","text":"It is removed from disk"},
      {"id":"d","text":"Git refuses further commits"}],
    "correct": "b",
    "explanation": ".gitignore only affects untracked files. A tracked file keeps being tracked until you remove it from the index with git rm --cached. Nothing is deleted from history or disk, and commits keep working." }
] }
```

## Try it

You committed `.env` containing a database password last week. You now add
`.env` to `.gitignore` and run `git rm --cached .env` and commit. Is the
password safe?

<details>
<summary>Show answer</summary>

No. The password is still inside last week's commit, and anyone with the repo
can read it with `git show <old-commit>:.env`. Treat it as leaked: **rotate the
password first**, then optionally rewrite history (Section 13 covers
`git filter-repo`).

</details>

## Common mistakes

- **Expecting `.gitignore` to untrack committed files.** It never does. Use
  `git rm --cached`.
- **Ignoring the folder but adding a file inside it by name.** `git add -f`
  forces an ignored file in; avoid unless you mean it.
- **Putting personal editor junk in the project `.gitignore`.** Use your global
  excludes file so every repo benefits and teammates are not bothered.
- **Ignoring `.env` but committing `.env.example` with real values.** The example
  file must contain placeholders only.

## Remember

- `.gitignore` stops **untracked** files from being added. It never touches tracked ones.
- `git check-ignore -v <file>` shows which rule matched.
- `git rm --cached <file>` untracks a file but keeps it on disk.
- A secret that was ever committed is leaked: rotate it.

**Self-check:**

1. What does a trailing `/` in a pattern mean?
2. Which command explains why a file is ignored?
3. What is the difference between `git rm` and `git rm --cached`?
$md$, 7, $json$[{"id":"git-first-ignore-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4a5cf9bb-5097-5349-9cfc-c053e5dd500a', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '30bd438b-14f7-5688-bfd5-d78aef9b27d3', 'Reading status and diff', 'notes', 3, $md$## Why this matters

Before every commit you should know exactly what you are about to save.
`git status` tells you **which** files changed and in which area. `git diff`
tells you **what** changed inside them. Reading both takes ten seconds and stops
you committing debug prints, secrets and half-finished work.

## Mental model: two comparisons

There are two gaps between the three areas, and one command for each gap:

```
 working tree --git diff--> index --git diff --staged--> HEAD (last commit)

 README.md  (edited, added)       -> shows under "Changes to be committed"
 main.sh    (edited, not added)   -> shows under "Changes not staged"
```

- `git diff` = desk vs outbox (what you have **not** staged yet).
- `git diff --staged` (same as `--cached`) = outbox vs archive (what the next
  commit **will** contain).
- `git diff HEAD` = desk vs archive (everything changed since the last commit).

## See it work

### The short status format

```bash
echo "Learning git" >> README.md && git add README.md
echo "echo done" >> main.sh
git status -s
```

Expected output:

```
M  README.md
 M main.sh
```

Read it as two columns:

| Left column | Right column |
|---|---|
| index vs HEAD (staged) | working tree vs index (not staged) |

So `M ` (left) means staged, ` M` (right) means modified but not staged, and
`MM` means "staged once, then edited again". Other letters: `A` added, `D`
deleted, `R` renamed, `??` untracked, `UU` conflict.

### The two diffs

```bash
git diff            # shows only main.sh (unstaged)
git diff --staged   # shows only README.md (staged)
```

Expected output of `git diff --staged`:

```
diff --git a/README.md b/README.md
index 1b3e6c2..5d6a0f4 100644
--- a/README.md
+++ b/README.md
@@ -1 +1,2 @@
 # Hello
+Learning git
```

How to read a diff:

- `---` / `+++` name the old and new versions.
- `@@ -1 +1,2 @@` = the hunk starts at line 1; old had 1 line, new has 2.
- Lines starting with `+` were added, `-` removed, a space means unchanged
  context.

Useful variations: `git diff --stat` (summary per file), `git diff --word-diff`
(changes inside long lines), `git diff main feature` (two branches).

```knowledge-check
{ "questions": [
  { "id": "git-first-diff-q1", "type": "mcq",
    "prompt": "git diff prints nothing but git status shows a file under 'Changes to be committed'. Why?",
    "options": [
      {"id":"a","text":"The change is already staged, and plain git diff only compares working tree to index"},
      {"id":"b","text":"The file was ignored"},
      {"id":"c","text":"Git diff only works on binary files"},
      {"id":"d","text":"The repository is corrupt"}],
    "correct": "a",
    "explanation": "Use git diff --staged to see index versus HEAD. An ignored file would not appear in status at all, git diff works on text, and nothing is corrupt." }
] }
```

### Stage only part of a file

```bash
git add -p main.sh
```

What this does: shows each changed hunk and asks `Stage this hunk [y,n,q,a,d,s,e,?]?`.
Answer `y` or `n` per hunk. This is how you split one messy edit into two clean
commits.

## Try it

`git status -s` prints `MM app.py`. What happened, and what does
`git diff --staged` show versus `git diff`?

<details>
<summary>Show answer</summary>

You edited `app.py`, ran `git add`, then edited it again. `git diff --staged`
shows the first edit (what will be committed). `git diff` shows the second edit
(not staged yet). Run `git add app.py` again if you want both in the commit.

</details>

## Common mistakes

- **Using `git add .` blindly.** It stages everything, including stray debug
  files. Look at `git status` first, or stage files by name.
- **Reading only `git diff` before committing.** It hides staged changes. Use
  `git diff --staged` to review what you are about to commit.
- **Panicking at `MM`.** It only means the file has both staged and unstaged
  changes.

## Remember

- `git status -s`: left column = staged, right column = not staged.
- `git diff` = not staged yet. `git diff --staged` = what the commit will contain.
- `git add -p` stages hunk by hunk.
- Always review `git diff --staged` before `git commit`.

**Self-check:**

1. Which command shows what the next commit will contain?
2. What does ` M` (space, M) mean in short status?
3. How do you stage only half of the changes in one file?
$md$, 8, $json$[{"id":"git-first-diff-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a246bc5f-7923-5df0-9f3b-464b8fccb699', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '30bd438b-14f7-5688-bfd5-d78aef9b27d3', 'Fixing the Last Commit with --amend', 'notes', 4, $md$## Why this matters

You commit, then notice a typo in the message or a file you forgot to add.
Making a second commit called "oops" clutters history. `git commit --amend`
fixes the last commit instead, as long as nobody else has it yet.

## Mental model: reseal the envelope (with a new envelope)

Amend does **not** edit the old commit. Commits never change. Amend builds a
**new** commit from the current index, with the same parent as the old one, and
moves the branch to it. The old commit is left behind, unreachable.

```
BEFORE amend                         AFTER git commit --amend

 A---B---C  <- main                   A---B---C'  <- main
                                           \
                                            C (orphaned, still in reflog)
```

`C'` has a different hash from `C`, because its content or message differs.

## See it work

### Add a forgotten file

```bash
git commit -m "Update readme"
git add main.sh                         # forgot this one
git commit --amend -m "Update README and script"
git log --oneline
```

What this does: the first commit misses `main.sh`; amend replaces that commit
with one that has both files and a better message. Expected output:

```
b94e2d1 (HEAD -> main) Update README and script
7a03c55 Add main script and gitignore
3f1c9ab Add README
```

Only three commits. The "Update readme" commit is gone from the branch.

### Fix only the message

```bash
git commit --amend -m "Fix crash when cart is empty"
```

With nothing staged, amend keeps the same snapshot and only changes the
message.

### Keep the message, add a file

```bash
git add forgotten.txt
git commit --amend --no-edit
```

`--no-edit` reuses the existing message without opening the editor.

### Why amend is dangerous after pushing

```
 your laptop:  A---B---C'   (amended)
 origin     :  A---B---C    (teammates already pulled C)
```

Your branch and the server now disagree. A normal `git push` is rejected, and a
force push would remove `C` from under your teammates' feet.

```knowledge-check
{ "questions": [
  { "id": "git-first-amend-q1", "type": "mcq",
    "prompt": "Why should you not amend a commit you already pushed?",
    "options": [
      {"id":"a","text":"Amend creates a new commit with a new hash, so the pushed one diverges from your local branch"},
      {"id":"b","text":"Amend deletes the remote repository"},
      {"id":"c","text":"Amend only works on the first commit"},
      {"id":"d","text":"Amend is not a real command"}],
    "correct": "a",
    "explanation": "The amended commit is a different object. Anyone who already has the old one now has diverging history. Amend never touches the remote, works on any last commit, and is a standard option of git commit." }
] }
```

## Try it

You committed "Add tax calcualtor" (typo) one minute ago and have not pushed.
Fix the message without changing the files.

<details>
<summary>Show answer</summary>

```bash
git commit --amend -m "Add tax calculator"
```

Make sure nothing is staged first (`git status`), or that staged change will be
folded into the commit too.

</details>

## Common mistakes

- **Amending with unrelated changes staged.** Amend takes the **whole current
  index**. Check `git status` first.
- **Amending a pushed commit on a shared branch.** Make a new commit instead.
  On your own feature branch it is fine, followed by
  `git push --force-with-lease` (Section 8).
- **Thinking the old commit is destroyed.** It is still in the reflog for weeks
  (Section 9), so a bad amend can be undone.

## Remember

- `--amend` replaces the last commit with a new one (new hash).
- `--amend -m "..."` fixes the message; `--amend --no-edit` adds staged files.
- Never amend commits others already have.
- The old commit stays recoverable through the reflog.

**Self-check:**

1. Does amend modify the old commit?
2. What does `--no-edit` do?
3. What goes wrong if you amend a commit your teammate already pulled?
$md$, 7, $json$[{"id":"git-first-amend-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('74b2f660-185b-521e-8bba-942899d63e41', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '30bd438b-14f7-5688-bfd5-d78aef9b27d3', 'Lab: Your First Clean History', 'notes', 5, $md$## Why this matters

Maya wants a tidy three-commit history in a new `hello` project. This lab uses
everything from the last five lessons: the three areas, identity, commits,
`.gitignore`, status and diff, and amend. Each task is checked automatically.

## Task 1: create the repository

Make `~/work/hello` and turn it into a repository. The first branch is already
configured to be `main` in this lab.

[[lab-task:1]]

Expected output of `git init` and `git status`:

```
Initialized empty Git repository in /home/labuser/work/hello/.git/
On branch main

No commits yet

nothing to commit (create/copy files and use "git add" to track)
```

## Task 2: tell Git who you are

Set the global name `Ada Student` and email `ada@example.com`.

[[lab-task:2]]

Check: `git config --list --show-origin | grep user`.

## Task 3: first commit

Create `README.md` with the single line `# Hello`, stage it and commit it as
`Add README`.

[[lab-task:3]]

Expected `git log --oneline` (hash differs):

```
3f1c9ab (HEAD -> main) Add README
```

## Task 4: ignore generated files

Create `main.sh`, a `.gitignore` that ignores `*.log` and `build/`, and the
noise files `app.log` and `build/out.txt`. Commit only `main.sh` and
`.gitignore` as `Add main script and gitignore`.

[[lab-task:4]]

Expected `git status` afterwards (the ignored files stay on disk, unlisted):

```
On branch main
nothing to commit, working tree clean
```

Confirm a rule with `git check-ignore -v app.log`.

## Task 5: one staged, one not

Append `Learning git` to `README.md` and stage it. Append `echo done` to
`main.sh` and do **not** stage it. Compare `git diff` and `git diff --staged`.

[[lab-task:5]]

Expected `git status -s`:

```
M  README.md
 M main.sh
```

## Task 6: commit, then amend

Commit the staged change as `Update readme`. Then stage `main.sh` and amend so
one commit named `Update README and script` holds both files.

[[lab-task:6]]

Expected `git log --oneline`:

```
b94e2d1 (HEAD -> main) Update README and script
7a03c55 Add main script and gitignore
3f1c9ab Add README
```

## Remember

- Look at `git status` before and after every command while you learn.
- Commit only what is staged; review it with `git diff --staged`.
- Amend replaces the last commit; do it before you push.
$md$, 35, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('f5d6201c-312b-5a8a-a6ab-266493edfa55', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '74b2f660-185b-521e-8bba-942899d63e41', 'module', 'Lab: Your First Clean History', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$git config --global init.defaultBranch main
git config --global safe.directory '*'
rm -rf /home/labuser/work/hello
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'ff32e128-79ca-5208-a651-3aae00f780d4' AND id NOT IN ('7ddac7a4-4ae7-5fb4-93e4-917356e02ab4', '0feb15d0-e518-506c-b501-a7f23a24cae7', 'fdca5969-6538-5ddc-91a8-eaabab490960', '0a114c4d-b83a-5d57-8070-ef78a610cde0', 'b9282be3-3dda-581c-8714-06ff0117361e', '7211a23b-8a73-52dd-bed3-bfda9f8db1f7');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'ff32e128-79ca-5208-a651-3aae00f780d4';
DELETE FROM lab_tasks WHERE lab_id = 'f5d6201c-312b-5a8a-a6ab-266493edfa55' AND id NOT IN ('48e82dcb-95a6-55ba-819f-47f9b6aaecc8', 'd64f0870-5ad6-5d4a-8704-75c4a780b604', '2bd61ff6-302b-57c8-ab39-572e908a1ef4', 'eefd6463-1503-5055-87d6-5ccbc1a20c75', '2a1d52a9-eddc-5b22-9de5-da256e3f8b6d', '2141e05f-273d-51d9-9c9b-f11149e14eb2');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'f5d6201c-312b-5a8a-a6ab-266493edfa55';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('48e82dcb-95a6-55ba-819f-47f9b6aaecc8', 'f5d6201c-312b-5a8a-a6ab-266493edfa55', 1, 'Create a repository', $md$Create a new directory called hello inside your work directory and turn it into a Git repository whose first branch is named main.$md$, $script$r=/home/labuser/work/hello
[ "$(git -C $r rev-parse --is-inside-work-tree)" = true ] &&
[ "$(git -C $r symbolic-ref HEAD)" = refs/heads/main ]
$script$, 'git init creates the hidden .git directory. The default branch name is already main in this lab; check it with git status.', 'git init writes the .git directory (objects, refs, HEAD). Nothing is committed yet, so HEAD points at a branch (main) that does not exist until the first commit.', 10, false, true),
('d64f0870-5ad6-5d4a-8704-75c4a780b604', 'f5d6201c-312b-5a8a-a6ab-266493edfa55', 2, 'Tell Git who you are', $md$Set your global identity to the name "Ada Student" and the email "ada@example.com".$md$, $script$[ "$(git config --global --get user.name)" = "Ada Student" ] &&
[ "$(git config --global --get user.email)" = "ada@example.com" ]
$script$, 'git config --global writes to ~/.gitconfig and applies to every repository you use.', 'Every commit records an author name and email. They come from user.name and user.email; --global stores them once for all repos.', 10, false, true),
('2bd61ff6-302b-57c8-ab39-572e908a1ef4', 'f5d6201c-312b-5a8a-a6ab-266493edfa55', 3, 'Make your first commit', $md$Inside hello, create README.md containing the single line "# Hello", stage it and commit it with the message "Add README".$md$, $script$r=/home/labuser/work/hello
[ "$(git -C $r rev-list --count HEAD)" = 1 ] &&
[ "$(git -C $r log -1 --format=%s)" = "Add README" ] &&
[ "$(git -C $r log -1 --format=%an)" = "Ada Student" ] &&
[ "$(git -C $r show HEAD:README.md)" = "# Hello" ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'Three steps - create the file, git add it, git commit -m with the message. git status before and after shows the difference.', 'A commit snapshots the staging area (index), not the working tree. git add moves the file into the index; git commit turns the index into a permanent commit.', 15, false, true),
('eefd6463-1503-5055-87d6-5ccbc1a20c75', 'f5d6201c-312b-5a8a-a6ab-266493edfa55', 4, 'Ignore generated files', $md$Create main.sh (any content), a .gitignore that ignores *.log files and the build/ directory, plus an app.log file and a build/out.txt file. Commit main.sh and .gitignore with the message "Add main script and gitignore" while app.log and build/ stay on disk but untracked.$md$, $script$r=/home/labuser/work/hello
[ "$(git -C $r log -1 --format=%s)" = "Add main script and gitignore" ] &&
git -C $r ls-files --error-unmatch main.sh .gitignore >/dev/null &&
[ -f $r/app.log ] && [ -f $r/build/out.txt ] &&
git -C $r check-ignore -q app.log && git -C $r check-ignore -q build/out.txt &&
[ -z "$(git -C $r ls-files | grep -E 'app.log|build/')" ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'A .gitignore line like *.log matches any log file, and build/ matches a directory. git status should NOT list app.log or build/ once the rules exist.', '.gitignore only affects untracked files. Because app.log and build/ never entered the index, Git silently skips them; git check-ignore -v shows which rule matched.', 15, false, true),
('2a1d52a9-eddc-5b22-9de5-da256e3f8b6d', 'f5d6201c-312b-5a8a-a6ab-266493edfa55', 5, 'Split staged and unstaged changes', $md$Append the line "Learning git" to README.md and stage it. Then append the line "echo done" to main.sh but do NOT stage it. Use git diff and git diff --staged to see the two views.$md$, $script$r=/home/labuser/work/hello
[ "$(git -C $r diff --cached --name-only)" = README.md ] &&
[ "$(git -C $r diff --name-only)" = main.sh ] &&
git -C $r diff --cached | grep -q '^+Learning git$' &&
git -C $r diff | grep -q '^+echo done$'
$script$, 'git add README.md stages only that file. git diff compares working tree to the index; git diff --staged compares the index to HEAD.', 'Git has three areas - working tree, index, HEAD. git diff shows working vs index, git diff --staged shows index vs HEAD, so the same file can appear in either or both.', 15, false, true),
('2141e05f-273d-51d9-9c9b-f11149e14eb2', 'f5d6201c-312b-5a8a-a6ab-266493edfa55', 6, 'Commit and then amend', $md$Commit the staged README change with the message "Update readme". Then realise main.sh belongs in the same commit, stage it, and amend so there is one commit with the message "Update README and script" that contains both files. History should have exactly three commits.$md$, $script$r=/home/labuser/work/hello
[ "$(git -C $r rev-list --count HEAD)" = 3 ] &&
[ "$(git -C $r log -1 --format=%s)" = "Update README and script" ] &&
git -C $r show --name-only --format= HEAD | grep -qx README.md &&
git -C $r show --name-only --format= HEAD | grep -qx main.sh &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git commit --amend -m "new message" after staging the extra file replaces the last commit instead of adding a new one.', '--amend does not edit a commit, it builds a replacement from the current index and moves the branch to it; the old commit becomes unreachable (but is still in the reflog). Never amend commits you already pushed.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('ff32e128-79ca-5208-a651-3aae00f780d4', 'f5d6201c-312b-5a8a-a6ab-266493edfa55', 1, $json$[{"id":"48e82dcb-95a6-55ba-819f-47f9b6aaecc8","lab_id":"f5d6201c-312b-5a8a-a6ab-266493edfa55","position":1,"title":"Create a repository","description":"Create a new directory called hello inside your work directory and turn it into a Git repository whose first branch is named main.","verification_script":"r=/home/labuser/work/hello\n[ \"$(git -C $r rev-parse --is-inside-work-tree)\" = true ] \u0026\u0026\n[ \"$(git -C $r symbolic-ref HEAD)\" = refs/heads/main ]\n","hint_context":"git init creates the hidden .git directory. The default branch name is already main in this lab; check it with git status.","explanation_context":"git init writes the .git directory (objects, refs, HEAD). Nothing is committed yet, so HEAD points at a branch (main) that does not exist until the first commit.","points":10,"is_optional":false,"is_stateful":true},{"id":"d64f0870-5ad6-5d4a-8704-75c4a780b604","lab_id":"f5d6201c-312b-5a8a-a6ab-266493edfa55","position":2,"title":"Tell Git who you are","description":"Set your global identity to the name \"Ada Student\" and the email \"ada@example.com\".","verification_script":"[ \"$(git config --global --get user.name)\" = \"Ada Student\" ] \u0026\u0026\n[ \"$(git config --global --get user.email)\" = \"ada@example.com\" ]\n","hint_context":"git config --global writes to ~/.gitconfig and applies to every repository you use.","explanation_context":"Every commit records an author name and email. They come from user.name and user.email; --global stores them once for all repos.","points":10,"is_optional":false,"is_stateful":true},{"id":"2bd61ff6-302b-57c8-ab39-572e908a1ef4","lab_id":"f5d6201c-312b-5a8a-a6ab-266493edfa55","position":3,"title":"Make your first commit","description":"Inside hello, create README.md containing the single line \"# Hello\", stage it and commit it with the message \"Add README\".","verification_script":"r=/home/labuser/work/hello\n[ \"$(git -C $r rev-list --count HEAD)\" = 1 ] \u0026\u0026\n[ \"$(git -C $r log -1 --format=%s)\" = \"Add README\" ] \u0026\u0026\n[ \"$(git -C $r log -1 --format=%an)\" = \"Ada Student\" ] \u0026\u0026\n[ \"$(git -C $r show HEAD:README.md)\" = \"# Hello\" ] \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"Three steps - create the file, git add it, git commit -m with the message. git status before and after shows the difference.","explanation_context":"A commit snapshots the staging area (index), not the working tree. git add moves the file into the index; git commit turns the index into a permanent commit.","points":15,"is_optional":false,"is_stateful":true},{"id":"eefd6463-1503-5055-87d6-5ccbc1a20c75","lab_id":"f5d6201c-312b-5a8a-a6ab-266493edfa55","position":4,"title":"Ignore generated files","description":"Create main.sh (any content), a .gitignore that ignores *.log files and the build/ directory, plus an app.log file and a build/out.txt file. Commit main.sh and .gitignore with the message \"Add main script and gitignore\" while app.log and build/ stay on disk but untracked.","verification_script":"r=/home/labuser/work/hello\n[ \"$(git -C $r log -1 --format=%s)\" = \"Add main script and gitignore\" ] \u0026\u0026\ngit -C $r ls-files --error-unmatch main.sh .gitignore \u003e/dev/null \u0026\u0026\n[ -f $r/app.log ] \u0026\u0026 [ -f $r/build/out.txt ] \u0026\u0026\ngit -C $r check-ignore -q app.log \u0026\u0026 git -C $r check-ignore -q build/out.txt \u0026\u0026\n[ -z \"$(git -C $r ls-files | grep -E 'app.log|build/')\" ] \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"A .gitignore line like *.log matches any log file, and build/ matches a directory. git status should NOT list app.log or build/ once the rules exist.","explanation_context":".gitignore only affects untracked files. Because app.log and build/ never entered the index, Git silently skips them; git check-ignore -v shows which rule matched.","points":15,"is_optional":false,"is_stateful":true},{"id":"2a1d52a9-eddc-5b22-9de5-da256e3f8b6d","lab_id":"f5d6201c-312b-5a8a-a6ab-266493edfa55","position":5,"title":"Split staged and unstaged changes","description":"Append the line \"Learning git\" to README.md and stage it. Then append the line \"echo done\" to main.sh but do NOT stage it. Use git diff and git diff --staged to see the two views.","verification_script":"r=/home/labuser/work/hello\n[ \"$(git -C $r diff --cached --name-only)\" = README.md ] \u0026\u0026\n[ \"$(git -C $r diff --name-only)\" = main.sh ] \u0026\u0026\ngit -C $r diff --cached | grep -q '^+Learning git$' \u0026\u0026\ngit -C $r diff | grep -q '^+echo done$'\n","hint_context":"git add README.md stages only that file. git diff compares working tree to the index; git diff --staged compares the index to HEAD.","explanation_context":"Git has three areas - working tree, index, HEAD. git diff shows working vs index, git diff --staged shows index vs HEAD, so the same file can appear in either or both.","points":15,"is_optional":false,"is_stateful":true},{"id":"2141e05f-273d-51d9-9c9b-f11149e14eb2","lab_id":"f5d6201c-312b-5a8a-a6ab-266493edfa55","position":6,"title":"Commit and then amend","description":"Commit the staged README change with the message \"Update readme\". Then realise main.sh belongs in the same commit, stage it, and amend so there is one commit with the message \"Update README and script\" that contains both files. History should have exactly three commits.","verification_script":"r=/home/labuser/work/hello\n[ \"$(git -C $r rev-list --count HEAD)\" = 3 ] \u0026\u0026\n[ \"$(git -C $r log -1 --format=%s)\" = \"Update README and script\" ] \u0026\u0026\ngit -C $r show --name-only --format= HEAD | grep -qx README.md \u0026\u0026\ngit -C $r show --name-only --format= HEAD | grep -qx main.sh \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"git commit --amend -m \"new message\" after staging the extra file replaces the last commit instead of adding a new one.","explanation_context":"--amend does not edit a commit, it builds a replacement from the current index and moves the branch to it; the old commit becomes unreachable (but is still in the reflog). Never amend commits you already pushed.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('7ddac7a4-4ae7-5fb4-93e4-917356e02ab4', 'ff32e128-79ca-5208-a651-3aae00f780d4', '48e82dcb-95a6-55ba-819f-47f9b6aaecc8', 1, 'Create a repository', $md$Create a new directory called hello inside your work directory and turn it into a Git repository whose first branch is named main.$md$, $script$r=/home/labuser/work/hello
[ "$(git -C $r rev-parse --is-inside-work-tree)" = true ] &&
[ "$(git -C $r symbolic-ref HEAD)" = refs/heads/main ]
$script$, 'git init creates the hidden .git directory. The default branch name is already main in this lab; check it with git status.', 'git init writes the .git directory (objects, refs, HEAD). Nothing is committed yet, so HEAD points at a branch (main) that does not exist until the first commit.', 10, false, true),
('0feb15d0-e518-506c-b501-a7f23a24cae7', 'ff32e128-79ca-5208-a651-3aae00f780d4', 'd64f0870-5ad6-5d4a-8704-75c4a780b604', 2, 'Tell Git who you are', $md$Set your global identity to the name "Ada Student" and the email "ada@example.com".$md$, $script$[ "$(git config --global --get user.name)" = "Ada Student" ] &&
[ "$(git config --global --get user.email)" = "ada@example.com" ]
$script$, 'git config --global writes to ~/.gitconfig and applies to every repository you use.', 'Every commit records an author name and email. They come from user.name and user.email; --global stores them once for all repos.', 10, false, true),
('fdca5969-6538-5ddc-91a8-eaabab490960', 'ff32e128-79ca-5208-a651-3aae00f780d4', '2bd61ff6-302b-57c8-ab39-572e908a1ef4', 3, 'Make your first commit', $md$Inside hello, create README.md containing the single line "# Hello", stage it and commit it with the message "Add README".$md$, $script$r=/home/labuser/work/hello
[ "$(git -C $r rev-list --count HEAD)" = 1 ] &&
[ "$(git -C $r log -1 --format=%s)" = "Add README" ] &&
[ "$(git -C $r log -1 --format=%an)" = "Ada Student" ] &&
[ "$(git -C $r show HEAD:README.md)" = "# Hello" ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'Three steps - create the file, git add it, git commit -m with the message. git status before and after shows the difference.', 'A commit snapshots the staging area (index), not the working tree. git add moves the file into the index; git commit turns the index into a permanent commit.', 15, false, true),
('0a114c4d-b83a-5d57-8070-ef78a610cde0', 'ff32e128-79ca-5208-a651-3aae00f780d4', 'eefd6463-1503-5055-87d6-5ccbc1a20c75', 4, 'Ignore generated files', $md$Create main.sh (any content), a .gitignore that ignores *.log files and the build/ directory, plus an app.log file and a build/out.txt file. Commit main.sh and .gitignore with the message "Add main script and gitignore" while app.log and build/ stay on disk but untracked.$md$, $script$r=/home/labuser/work/hello
[ "$(git -C $r log -1 --format=%s)" = "Add main script and gitignore" ] &&
git -C $r ls-files --error-unmatch main.sh .gitignore >/dev/null &&
[ -f $r/app.log ] && [ -f $r/build/out.txt ] &&
git -C $r check-ignore -q app.log && git -C $r check-ignore -q build/out.txt &&
[ -z "$(git -C $r ls-files | grep -E 'app.log|build/')" ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'A .gitignore line like *.log matches any log file, and build/ matches a directory. git status should NOT list app.log or build/ once the rules exist.', '.gitignore only affects untracked files. Because app.log and build/ never entered the index, Git silently skips them; git check-ignore -v shows which rule matched.', 15, false, true),
('b9282be3-3dda-581c-8714-06ff0117361e', 'ff32e128-79ca-5208-a651-3aae00f780d4', '2a1d52a9-eddc-5b22-9de5-da256e3f8b6d', 5, 'Split staged and unstaged changes', $md$Append the line "Learning git" to README.md and stage it. Then append the line "echo done" to main.sh but do NOT stage it. Use git diff and git diff --staged to see the two views.$md$, $script$r=/home/labuser/work/hello
[ "$(git -C $r diff --cached --name-only)" = README.md ] &&
[ "$(git -C $r diff --name-only)" = main.sh ] &&
git -C $r diff --cached | grep -q '^+Learning git$' &&
git -C $r diff | grep -q '^+echo done$'
$script$, 'git add README.md stages only that file. git diff compares working tree to the index; git diff --staged compares the index to HEAD.', 'Git has three areas - working tree, index, HEAD. git diff shows working vs index, git diff --staged shows index vs HEAD, so the same file can appear in either or both.', 15, false, true),
('7211a23b-8a73-52dd-bed3-bfda9f8db1f7', 'ff32e128-79ca-5208-a651-3aae00f780d4', '2141e05f-273d-51d9-9c9b-f11149e14eb2', 6, 'Commit and then amend', $md$Commit the staged README change with the message "Update readme". Then realise main.sh belongs in the same commit, stage it, and amend so there is one commit with the message "Update README and script" that contains both files. History should have exactly three commits.$md$, $script$r=/home/labuser/work/hello
[ "$(git -C $r rev-list --count HEAD)" = 3 ] &&
[ "$(git -C $r log -1 --format=%s)" = "Update README and script" ] &&
git -C $r show --name-only --format= HEAD | grep -qx README.md &&
git -C $r show --name-only --format= HEAD | grep -qx main.sh &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git commit --amend -m "new message" after staging the extra file replaces the last commit instead of adding a new one.', '--amend does not edit a commit, it builds a replacement from the current index and moves the branch to it; the old commit becomes unreachable (but is still in the reflog). Never amend commits you already pushed.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'ff32e128-79ca-5208-a651-3aae00f780d4', updated_at = now()
WHERE id = 'f5d6201c-312b-5a8a-a6ab-266493edfa55' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c8965b12-fa4a-5c4b-8cab-3e220e008169', '00000000-0000-0000-0000-000000000001', 'mcq', 'You edit config.py and utils.py, run `git add config.py`, then `git commit -m...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('19c18972-d26c-5f52-aef0-ea91e1b4cbf9', 'c8965b12-fa4a-5c4b-8cab-3e220e008169', 1, $json${"prompt":"You edit config.py and utils.py, run `git add config.py`, then `git commit -m 'Fix config'`. A teammate pulls your commit. Does it contain the utils.py change?","multiple":false,"options":[{"id":"a","text":"Yes, commit saves every modified file","is_correct":false},{"id":"b","text":"No, only what was in the index is committed; utils.py is still an unstaged change on your machine","is_correct":true},{"id":"c","text":"Yes, but only if utils.py is tracked","is_correct":false},{"id":"d","text":"No, and the utils.py change is now lost","is_correct":false}],"explanation":"A commit snapshots the index. utils.py was never added, so it is not in the commit, even though it is tracked. The change is not lost: it is still in your working tree, listed under 'Changes not staged for commit'."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('fb761b3d-6431-54c7-bf92-43e40f7a5738', '00000000-0000-0000-0000-000000000001', 'mcq', '`git status -s` shows `MM report.md`. What does it mean?', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('85c603df-1cf8-5e07-97fd-102ec41771a3', 'fb761b3d-6431-54c7-bf92-43e40f7a5738', 1, $json${"prompt":"`git status -s` shows `MM report.md`. What does it mean?","multiple":false,"options":[{"id":"a","text":"The file has a merge conflict","is_correct":false},{"id":"b","text":"The file was modified twice in two commits","is_correct":false},{"id":"c","text":"The file has staged changes AND further unstaged changes made after `git add`","is_correct":true},{"id":"d","text":"The file is modified on two branches","is_correct":false}],"explanation":"Left column = index vs HEAD (staged), right column = working tree vs index (not staged). Both show M. A conflict shows UU, and short status never looks at other commits or branches."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f2ac9e81-28a9-56d0-8576-6d49442c9155', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your project .gitignore contains `*.log`, but `git status` still lists `serve...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('de26a029-687a-5a8e-a65f-24064be15b32', 'f2ac9e81-28a9-56d0-8576-6d49442c9155', 1, $json${"prompt":"Your project .gitignore contains `*.log`, but `git status` still lists `server.log` as modified. Why?","multiple":false,"options":[{"id":"a","text":"The pattern needs to be `**/*.log`","is_correct":false},{"id":"b","text":"server.log was committed before the rule existed, and .gitignore never affects tracked files","is_correct":true},{"id":"c","text":".gitignore only works after a push","is_correct":false},{"id":"d","text":"Git caches ignore rules for 24 hours","is_correct":false}],"explanation":"Ignore rules only stop untracked files. Use `git rm --cached server.log` and commit to stop tracking it. `*.log` already matches at any depth, and there is no push requirement or cache delay."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b78ec921-80c0-5f19-879c-4fdfc9d6415b', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command shows exactly what your next commit will contain?', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d8726bb0-cf74-5de9-9034-816a8ea6c441', 'b78ec921-80c0-5f19-879c-4fdfc9d6415b', 1, $json${"prompt":"Which command shows exactly what your next commit will contain?","multiple":false,"options":[{"id":"a","text":"git diff","is_correct":false},{"id":"b","text":"git diff --staged","is_correct":true},{"id":"c","text":"git log -p","is_correct":false},{"id":"d","text":"git status --ignored","is_correct":false}],"explanation":"--staged compares the index with HEAD, which is the next commit's content. Plain git diff shows changes NOT staged, git log -p shows past commits, and --ignored lists ignored files."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('aefd3be6-1b46-582d-a26c-6f4ca795dda6', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your global email is personal, but in one work repository you must commit as ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('8fe0ff31-2bb1-5f4a-b6e3-af6d8459f2ab', 'aefd3be6-1b46-582d-a26c-6f4ca795dda6', 1, $json${"prompt":"Your global email is personal, but in one work repository you must commit as ada@company.com. What is the cleanest fix?","multiple":false,"options":[{"id":"a","text":"Change the global email every time you switch projects","is_correct":false},{"id":"b","text":"Run `git config user.email ada@company.com` inside the work repository","is_correct":true},{"id":"c","text":"Edit each commit after making it","is_correct":false},{"id":"d","text":"Set it with --system","is_correct":false}],"explanation":"Without a flag, git config writes the local .git/config, which overrides global only for that repo. Switching global settings is error-prone, editing every commit is wasteful, and --system would affect every repo and user on the machine."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e0f3df30-eb7a-5c0a-a154-1b159ebbd19f', '00000000-0000-0000-0000-000000000001', 'mcq', 'You committed and pushed to the shared main branch, then noticed a typo in th...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d377d6bc-62ba-53b5-b322-cfc9c109c56f', 'e0f3df30-eb7a-5c0a-a154-1b159ebbd19f', 1, $json${"prompt":"You committed and pushed to the shared main branch, then noticed a typo in the message. What should you do?","multiple":false,"options":[{"id":"a","text":"git commit --amend and git push --force","is_correct":false},{"id":"b","text":"Leave it, or fix it with a follow-up commit; do not rewrite a pushed commit on a shared branch","is_correct":true},{"id":"c","text":"Delete the repository and push again","is_correct":false},{"id":"d","text":"git commit --amend; amend never changes hashes","is_correct":false}],"explanation":"Amend creates a new commit with a new hash, so force-pushing it rewrites history teammates may already have. A message typo is not worth that. Amend always changes the hash, and deleting the repo is absurd."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6cd83c04-c885-50f3-8fd6-4268acdd7083', '00000000-0000-0000-0000-000000000001', 'mcq', 'A .env file with an API key was committed two weeks ago. You add .env to .git...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a33b9da6-1fe0-5bf5-88b8-30c1f609edb9', '6cd83c04-c885-50f3-8fd6-4268acdd7083', 1, $json${"prompt":"A .env file with an API key was committed two weeks ago. You add .env to .gitignore and run `git rm --cached .env`. What is still required?","multiple":false,"options":[{"id":"a","text":"Nothing; the key is now gone","is_correct":false},{"id":"b","text":"Rotate (revoke and replace) the API key, because it is still readable in old commits","is_correct":true},{"id":"c","text":"Run git gc to delete the key from history","is_correct":false},{"id":"d","text":"Rename the file to .env.old","is_correct":false}],"explanation":"Old commits still contain the key; anyone with the repo can read it. Rotate it first. git gc does not remove objects that are still reachable from history, and renaming does nothing to old commits."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3cc143ba-476a-585c-92f4-7a69592fc69d', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 1): what does `git restore notes.txt` do?', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a4966602-7088-51cf-aba0-a5f39ad2224a', '3cc143ba-476a-585c-92f4-7a69592fc69d', 1, $json${"prompt":"Review (Section 1): what does `git restore notes.txt` do?","multiple":false,"options":[{"id":"a","text":"Copies the version of notes.txt from the index back over your working copy, discarding unstaged edits","is_correct":true},{"id":"b","text":"Undoes the last commit","is_correct":false},{"id":"c","text":"Downloads notes.txt from the server","is_correct":false},{"id":"d","text":"Stages notes.txt","is_correct":false}],"explanation":"restore replaces the working-tree file with the staged/committed version. It does not move commits, never talks to a server, and staging is git add."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('646c1e42-eedb-5045-a341-e785cd85dea2', '00000000-0000-0000-0000-000000000001', 'Quiz: Setup and First Commits', 'git-first-commits-quiz', 'Quiz covering Setup and First Commits.', 'mcq', 'published', 'module', '72b998d1-c7e1-597d-9061-ca868befdaa3', 12, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '646c1e42-eedb-5045-a341-e785cd85dea2' AND question_id NOT IN ('c8965b12-fa4a-5c4b-8cab-3e220e008169', 'fb761b3d-6431-54c7-bf92-43e40f7a5738', 'f2ac9e81-28a9-56d0-8576-6d49442c9155', 'b78ec921-80c0-5f19-879c-4fdfc9d6415b', 'aefd3be6-1b46-582d-a26c-6f4ca795dda6', 'e0f3df30-eb7a-5c0a-a154-1b159ebbd19f', '6cd83c04-c885-50f3-8fd6-4268acdd7083', '3cc143ba-476a-585c-92f4-7a69592fc69d');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('3e6de05f-8082-5654-bf52-9675f7fc6cfa', '646c1e42-eedb-5045-a341-e785cd85dea2', 'c8965b12-fa4a-5c4b-8cab-3e220e008169', '19c18972-d26c-5f52-aef0-ea91e1b4cbf9', 0, 2),
('79c9c013-b0b5-548a-9b30-b2639f54a2f8', '646c1e42-eedb-5045-a341-e785cd85dea2', 'fb761b3d-6431-54c7-bf92-43e40f7a5738', '85c603df-1cf8-5e07-97fd-102ec41771a3', 1, 2),
('c265d18b-077c-5199-9984-31adc087a6e3', '646c1e42-eedb-5045-a341-e785cd85dea2', 'f2ac9e81-28a9-56d0-8576-6d49442c9155', 'de26a029-687a-5a8e-a65f-24064be15b32', 2, 2),
('0b95f690-a3ed-58a8-970c-2a2a15f6409d', '646c1e42-eedb-5045-a341-e785cd85dea2', 'b78ec921-80c0-5f19-879c-4fdfc9d6415b', 'd8726bb0-cf74-5de9-9034-816a8ea6c441', 3, 2),
('0802ec54-d3d9-543b-9deb-d45a4c8f4a74', '646c1e42-eedb-5045-a341-e785cd85dea2', 'aefd3be6-1b46-582d-a26c-6f4ca795dda6', '8fe0ff31-2bb1-5f4a-b6e3-af6d8459f2ab', 4, 2),
('dcb2ec67-3a5f-5a08-8d87-dda5355bfc78', '646c1e42-eedb-5045-a341-e785cd85dea2', 'e0f3df30-eb7a-5c0a-a154-1b159ebbd19f', 'd377d6bc-62ba-53b5-b322-cfc9c109c56f', 5, 2),
('3c6baa68-23f3-5e44-a9e6-838078fada62', '646c1e42-eedb-5045-a341-e785cd85dea2', '6cd83c04-c885-50f3-8fd6-4268acdd7083', 'a33b9da6-1fe0-5bf5-88b8-30c1f609edb9', 6, 2),
('b168dff4-11eb-5ce9-afa8-53cdc890c6b7', '646c1e42-eedb-5045-a341-e785cd85dea2', '3cc143ba-476a-585c-92f4-7a69592fc69d', 'a4966602-7088-51cf-aba0-a5f39ad2224a', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('72b998d1-c7e1-597d-9061-ca868befdaa3', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '30bd438b-14f7-5688-bfd5-d78aef9b27d3', 'Quiz: Setup and First Commits', 'assessment', 6, 10, '646c1e42-eedb-5045-a341-e785cd85dea2')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Connecting to the Team
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('578c95ce-e505-5625-828c-b7e7a369f64b', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Connecting to the Team', 3, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1d8b92d2-c0e0-5c8d-a6ab-5cd7178913ab', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '578c95ce-e505-5625-828c-b7e7a369f64b', 'Remotes: Names for Other Copies', 'notes', 0, $md$## Why this matters

Day 2. Your history lives only on your laptop. Maya says: "Join the team repo so
I can see your work." To share work you connect your repository to another copy
of it, called a **remote**. Most "push does not work" problems are simply a
wrong remote URL.

## Mental model: contacts in your phone

A remote is a contact entry: a short **name** (like "Mum") saved for a long
**number**. `origin` is just the name Git gives by default to the place you
cloned from. It is not special and you can rename it.

```
 your repo                         remotes (name -> URL)
 +-----------+   origin  ---->  git@github.com:brightside/shop.git
 | .git      |   backup  ---->  /home/labuser/srv/git/backup.git
 +-----------+   upstream ---->  https://github.com/original/shop.git
```

> **One-sentence definition:** a **remote** is a saved name for the URL of
> another copy of the repository.

### URL forms you will meet

| Form | Example | Auth |
|---|---|---|
| SSH | `git@github.com:brightside/shop.git` | SSH key |
| HTTPS | `https://github.com/brightside/shop.git` | Username + token |
| Local path | `/home/labuser/srv/git/team.git` | File permissions |
| File URL | `file:///home/labuser/srv/git/team.git` | File permissions |

Servers usually store **bare** repositories (created with `git init --bare`):
just the `.git` contents, no working tree, because nobody edits files on the
server.

## See it work

### List, add, change, remove

```bash
git remote -v
```

What this does: lists each remote with its fetch and push URL. Expected output:

```
origin  /home/labuser/srv/git/team.git (fetch)
origin  /home/labuser/srv/git/team.git (push)
```

```bash
git remote add backup /home/labuser/srv/git/backup.git       # add a second remote
git remote set-url origin /home/labuser/srv/git/team.git      # fix a wrong URL
git remote rename backup mirror                  # rename
git remote remove mirror                         # delete the entry (not the server repo)
git remote show origin                           # details: branches, tracking
```

### Test the connection without changing anything

```bash
git ls-remote origin
```

What this does: asks the remote for its list of branches and tags. If it
prints refs, the URL and access are fine. If it fails, the message tells you
why:

```
fatal: '/home/labuser/srv/git/tean.git' does not appear to be a git repository
fatal: Could not read from remote repository.
```

That `tean` is a typo. Fix it with `git remote set-url`.

### First push

```
 before push                     after git push origin main
 you   : A---B---C               you   : A---B---C
 origin: A---B                   origin: A---B---C
```

```bash
git push origin main
```

A commit exists only on your machine until you push it.

## Try it

You forked a project on GitHub, cloned your fork, and now want to receive
updates from the original project too. What do you add?

<details>
<summary>Show answer</summary>

A second remote, by convention called `upstream`:

```bash
git remote add upstream https://github.com/original/shop.git
git fetch upstream
```

`origin` stays your fork (where you push); `upstream` is where you pull
updates from.

</details>

## Common mistakes

- **Thinking `git remote remove` deletes the server repo.** It only deletes the
  name from your local config.
- **Pushing to the wrong remote.** With several remotes, always name it:
  `git push origin main`, not just `git push`, until upstreams are set.
- **Typos in the URL.** "Repository not found" or "does not appear to be a git
  repository" is often just that. Check `git remote -v` first.

## Remember

- A remote = name -> URL. `origin` is only the default name.
- `git remote -v` to see, `add` / `set-url` / `remove` to change.
- `git ls-remote origin` tests access without changing anything.
- Commits stay local until you `git push`.

**Self-check:**

1. What is `origin`?
2. Which command fixes a remote's URL?
3. Why do servers use bare repositories?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5e0fd21a-c311-570b-afc8-2810dc21eab6', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '578c95ce-e505-5625-828c-b7e7a369f64b', 'Proving Who You Are: SSH Keys and Tokens', 'notes', 1, $md$## Why this matters

On a real host (GitHub, GitLab, Bitbucket) this is where most beginners get
stuck. Hosts stopped accepting account passwords for Git operations, so you
need either an **SSH key** or a **personal access token**. Pick one, set it up
once, and learn the three error messages that tell you what is wrong.

## Mental model: a key or a badge

```
 SSH    git@host:you/project.git     a key pair: the PRIVATE key stays on your
                                     machine; the PUBLIC key is given to the host
                                     (like giving the host a lock only your key opens)

 HTTPS  https://host/you/project.git  username + personal access token
                                      (a revocable badge with chosen permissions)
```

- **Public key** (`id_ed25519.pub`): safe to share. Paste it into the host.
- **Private key** (`id_ed25519`): never share, never commit, never email.
- **Personal access token (PAT)**: a long random string you create on the host
  and use instead of your password. Give it an expiry date and the smallest
  permissions needed.

## See it work

### SSH in four commands

```bash
ssh-keygen -t ed25519 -C "you@example.com"     # 1. create the key pair
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519   # 2. load it into the agent
cat ~/.ssh/id_ed25519.pub                      # 3. copy this into the host's SSH keys page
ssh -T git@github.com                          # 4. test
```

What step 1 does: creates `~/.ssh/id_ed25519` and `~/.ssh/id_ed25519.pub`,
asking for an optional passphrase (use one; the agent remembers it). Step 4's
expected output on GitHub:

```
Hi ada-student! You've successfully authenticated, but GitHub does not provide shell access.
```

Then use the SSH URL: `git remote set-url origin git@github.com:brightside/shop.git`.

### HTTPS with a token

1. On the host: Settings -> Developer settings / Access tokens -> create a token
   with repository read/write scope and an expiry.
2. `git push`; when asked for a password, paste the **token**.
3. Let a credential helper remember it:

```bash
git config --global credential.helper cache     # in memory, 15 minutes by default
# or a secure OS store: manager (Git Credential Manager), osxkeychain, libsecret
```

`credential.helper store` also works, but it saves the token in **plain text**
in `~/.git-credentials`. Avoid it on shared machines.

### When it fails, read the error

```
 Permission denied (publickey)   public key not added to the host, or key not loaded in ssh-agent
 Authentication failed           expired/wrong token, or the account password was used
 Repository not found            URL typo, or no access to a private repo
```

Debug SSH with `ssh -vT git@github.com`; it prints which key files it tried.

```knowledge-check
{ "questions": [
  { "id": "git-connection-q1", "type": "mcq",
    "prompt": "You get 'Permission denied (publickey)' when pushing over SSH. What do you check first?",
    "options": [
      {"id":"a","text":"That the public key is uploaded to the host and the key is loaded in ssh-agent"},
      {"id":"b","text":"That the branch is called main"},
      {"id":"c","text":"That the commit message is short"},
      {"id":"d","text":"That the repository has a README"}],
    "correct": "a",
    "explanation": "The host must know your public key, and your machine must offer the matching private key. Branch names, messages and READMEs have nothing to do with authentication." },
  { "id": "git-connection-q2", "type": "mcq",
    "prompt": "git push over HTTPS says 'Authentication failed' although your account password is correct. Most likely cause?",
    "options": [
      {"id":"a","text":"Hosts require a personal access token, not the account password"},
      {"id":"b","text":"The branch is named main"},
      {"id":"c","text":"Your commits are too large"},
      {"id":"d","text":"SSH is also enabled"}],
    "correct": "a",
    "explanation": "GitHub and GitLab no longer accept account passwords for Git over HTTPS. Branch names and commit size do not cause authentication errors, and having SSH set up does not block HTTPS." }
] }
```

## Try it

A new teammate committed their `~/.ssh/id_ed25519` file into the repo by
mistake. What must happen, in order?

<details>
<summary>Show answer</summary>

1. Remove that public key from their host account immediately (the private key
   is compromised).
2. Generate a new key pair and register the new public key.
3. Remove the file from the repo (and ideally from history, Section 13).

Deleting the file alone is not enough: it remains in history.

</details>

## Common mistakes

- **Pasting the private key into the host.** Always paste the `.pub` file.
- **Tokens with no expiry and full scopes.** If leaked, they open everything.
  Use fine-grained, expiring tokens.
- **Mixing URL types.** A repo cloned over HTTPS keeps asking for a token even
  after you set up SSH. Switch the remote URL to the SSH form.
- **Typing your password at the HTTPS prompt.** It must be the token.

## Remember

- SSH: private key stays home, public key goes to the host. Test with `ssh -T`.
- HTTPS: use a personal access token as the password; store it with a credential helper.
- `publickey` = key problem. `Authentication failed` = token problem. `not found` = URL or access.
- A leaked key or token must be revoked, not just deleted.

**Self-check:**

1. Which of the two key files do you upload to GitHub?
2. Why is `credential.helper store` risky?
3. What does "Repository not found" usually mean on a private repo?
$md$, 9, $json$[{"id":"git-connection-q1","type":"mcq","correct":"a"},{"id":"git-connection-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('65110615-38ef-5178-bc97-6e91ff88397c', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '578c95ce-e505-5625-828c-b7e7a369f64b', 'Lab: Fix a Remote and Push to the Team', 'notes', 2, $md$## Why this matters

Maya cloned an onboarding repository for you, but `git fetch` fails. Fix the
remote, push your first commit to the team, and add a backup remote. In this
sandbox the "server" repositories are bare repos on disk under `/home/labuser/srv/git`, so no
keys or tokens are needed; the commands are the same as with GitHub.

## Task 1: fix the broken remote

```bash
cd ~/work/onboarding
git remote -v
git fetch          # fails - read the message
```

Expected error:

```
fatal: '/home/labuser/srv/git/tean.git' does not appear to be a git repository
fatal: Could not read from remote repository.
```

Point `origin` at the real repository, `/home/labuser/srv/git/team.git`.

[[lab-task:1]]

What you should see once the URL is right:

```
$ git remote -v
origin  /home/labuser/srv/git/team.git (fetch)
origin  /home/labuser/srv/git/team.git (push)
```

## Task 2: say hello to the team

Create `welcome.txt` containing `Hello from the new developer`, commit it as
`Add welcome note`, and push to `origin main`.

```
 before push                     after git push origin main
 you   : A---B                   you   : A---B
 origin: A                       origin: A---B
```

[[lab-task:2]]

Check: `git ls-remote origin main` prints the same hash as `git rev-parse HEAD`.

## Task 3: add a second remote

Add a remote named `backup` pointing at `/home/labuser/srv/git/backup.git`, then push `main`
to it.

[[lab-task:3]]

Expected `git remote -v`:

```
backup  /home/labuser/srv/git/backup.git (fetch)
backup  /home/labuser/srv/git/backup.git (push)
origin  /home/labuser/srv/git/team.git (fetch)
origin  /home/labuser/srv/git/team.git (push)
```

## Remember

- When fetch or push fails, check `git remote -v` before anything else.
- `git push <remote> <branch>` names exactly where your commits go.
- One repository can have many remotes.
$md$, 20, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('c34c02e3-aeb7-5608-b7c0-a601eac54d2e', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '65110615-38ef-5178-bc97-6e91ff88397c', 'module', 'Lab: Fix a Remote and Push to the Team', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
rm -rf /home/labuser/srv/git /home/labuser/work/onboarding /tmp/seed
mkdir -p /home/labuser/srv/git
git init -q --bare /home/labuser/srv/git/team.git
git init -q --bare /home/labuser/srv/git/backup.git
git clone -q /home/labuser/srv/git/team.git /tmp/seed 2>/dev/null
cd /tmp/seed
export GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com
echo "# Brightside Shop" > README.md; git add -A
GIT_AUTHOR_DATE="2024-01-01T10:00:00+0000" GIT_COMMITTER_DATE="2024-01-01T10:00:00+0000" git commit -q -m "Initial commit"
git push -q origin main
cd /; rm -rf /tmp/seed
git --git-dir=/home/labuser/srv/git/team.git symbolic-ref HEAD refs/heads/main
git --git-dir=/home/labuser/srv/git/backup.git symbolic-ref HEAD refs/heads/main
git clone -q /home/labuser/srv/git/team.git /home/labuser/work/onboarding 2>/dev/null
git -C /home/labuser/work/onboarding remote set-url origin /home/labuser/srv/git/tean.git
chmod -R a+rwX /home/labuser/srv/git /home/labuser/work/onboarding
$script$, NULL, 30, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '29967a89-042d-52f1-9f58-17eca219b36c' AND id NOT IN ('55bcc819-d765-540c-8100-3e0d05e7134d', '939bf1f2-60aa-5da3-a413-75f4e73c430b', 'a84da144-7072-54cd-818a-43925e52e1dd');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '29967a89-042d-52f1-9f58-17eca219b36c';
DELETE FROM lab_tasks WHERE lab_id = 'c34c02e3-aeb7-5608-b7c0-a601eac54d2e' AND id NOT IN ('17f854d6-9d71-5b44-82bb-b6080627c702', 'ca96d10f-2aba-58fe-a0a1-8fbb9b3f09ec', '35e262f4-b4b6-55c8-ad82-a7e275db2f42');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'c34c02e3-aeb7-5608-b7c0-a601eac54d2e';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('17f854d6-9d71-5b44-82bb-b6080627c702', 'c34c02e3-aeb7-5608-b7c0-a601eac54d2e', 1, 'Fix the broken remote', $md$Maya set up your onboarding repository in your work directory, but git fetch fails - the origin URL has a typo. Point origin at the real team repository, /home/labuser/srv/git/team.git.$md$, $script$r=/home/labuser/work/onboarding
[ "$(git -C $r remote get-url origin)" = /home/labuser/srv/git/team.git ] &&
git -C $r ls-remote origin >/dev/null 2>&1
$script$, 'git remote -v shows the current URL, git remote set-url origin <url> changes it. Run git fetch afterwards to confirm it works.', 'A remote is only a name for a URL. When fetch says repository not found, check the URL first - a typo is the most common cause.', 10, false, true),
('ca96d10f-2aba-58fe-a0a1-8fbb9b3f09ec', 'c34c02e3-aeb7-5608-b7c0-a601eac54d2e', 2, 'Say hello to the team', $md$In onboarding, create welcome.txt containing the line "Hello from the new developer", commit it with the message "Add welcome note", and push it to origin main.$md$, $script$r=/home/labuser/work/onboarding
[ "$(git --git-dir=/home/labuser/srv/git/team.git show main:welcome.txt)" = "Hello from the new developer" ] &&
[ "$(git --git-dir=/home/labuser/srv/git/team.git log -1 --format=%s main)" = "Add welcome note" ] &&
[ "$(git -C $r rev-parse HEAD)" = "$(git --git-dir=/home/labuser/srv/git/team.git rev-parse main)" ]
$script$, 'Create the file, git add, git commit -m, then git push origin main.', 'A commit exists only locally until you push. After the push, the team repository''s main points at your commit, so Maya can pull it.', 15, false, true),
('35e262f4-b4b6-55c8-ad82-a7e275db2f42', 'c34c02e3-aeb7-5608-b7c0-a601eac54d2e', 3, 'Add a second remote', $md$A repository can have several remotes. Add a remote called backup that points to /home/labuser/srv/git/backup.git and push main to it.$md$, $script$r=/home/labuser/work/onboarding
[ "$(git -C $r remote get-url backup)" = /home/labuser/srv/git/backup.git ] &&
[ "$(git --git-dir=/home/labuser/srv/git/backup.git rev-parse main)" = "$(git -C $r rev-parse main)" ]
$script$, 'git remote add <name> <url>, then git push backup main.', 'origin is just the default name. Any number of remotes can exist, each a different URL, and you choose which one each push goes to.', 15, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('29967a89-042d-52f1-9f58-17eca219b36c', 'c34c02e3-aeb7-5608-b7c0-a601eac54d2e', 1, $json$[{"id":"17f854d6-9d71-5b44-82bb-b6080627c702","lab_id":"c34c02e3-aeb7-5608-b7c0-a601eac54d2e","position":1,"title":"Fix the broken remote","description":"Maya set up your onboarding repository in your work directory, but git fetch fails - the origin URL has a typo. Point origin at the real team repository, /home/labuser/srv/git/team.git.","verification_script":"r=/home/labuser/work/onboarding\n[ \"$(git -C $r remote get-url origin)\" = /home/labuser/srv/git/team.git ] \u0026\u0026\ngit -C $r ls-remote origin \u003e/dev/null 2\u003e\u00261\n","hint_context":"git remote -v shows the current URL, git remote set-url origin \u003curl\u003e changes it. Run git fetch afterwards to confirm it works.","explanation_context":"A remote is only a name for a URL. When fetch says repository not found, check the URL first - a typo is the most common cause.","points":10,"is_optional":false,"is_stateful":true},{"id":"ca96d10f-2aba-58fe-a0a1-8fbb9b3f09ec","lab_id":"c34c02e3-aeb7-5608-b7c0-a601eac54d2e","position":2,"title":"Say hello to the team","description":"In onboarding, create welcome.txt containing the line \"Hello from the new developer\", commit it with the message \"Add welcome note\", and push it to origin main.","verification_script":"r=/home/labuser/work/onboarding\n[ \"$(git --git-dir=/home/labuser/srv/git/team.git show main:welcome.txt)\" = \"Hello from the new developer\" ] \u0026\u0026\n[ \"$(git --git-dir=/home/labuser/srv/git/team.git log -1 --format=%s main)\" = \"Add welcome note\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse HEAD)\" = \"$(git --git-dir=/home/labuser/srv/git/team.git rev-parse main)\" ]\n","hint_context":"Create the file, git add, git commit -m, then git push origin main.","explanation_context":"A commit exists only locally until you push. After the push, the team repository's main points at your commit, so Maya can pull it.","points":15,"is_optional":false,"is_stateful":true},{"id":"35e262f4-b4b6-55c8-ad82-a7e275db2f42","lab_id":"c34c02e3-aeb7-5608-b7c0-a601eac54d2e","position":3,"title":"Add a second remote","description":"A repository can have several remotes. Add a remote called backup that points to /home/labuser/srv/git/backup.git and push main to it.","verification_script":"r=/home/labuser/work/onboarding\n[ \"$(git -C $r remote get-url backup)\" = /home/labuser/srv/git/backup.git ] \u0026\u0026\n[ \"$(git --git-dir=/home/labuser/srv/git/backup.git rev-parse main)\" = \"$(git -C $r rev-parse main)\" ]\n","hint_context":"git remote add \u003cname\u003e \u003curl\u003e, then git push backup main.","explanation_context":"origin is just the default name. Any number of remotes can exist, each a different URL, and you choose which one each push goes to.","points":15,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('55bcc819-d765-540c-8100-3e0d05e7134d', '29967a89-042d-52f1-9f58-17eca219b36c', '17f854d6-9d71-5b44-82bb-b6080627c702', 1, 'Fix the broken remote', $md$Maya set up your onboarding repository in your work directory, but git fetch fails - the origin URL has a typo. Point origin at the real team repository, /home/labuser/srv/git/team.git.$md$, $script$r=/home/labuser/work/onboarding
[ "$(git -C $r remote get-url origin)" = /home/labuser/srv/git/team.git ] &&
git -C $r ls-remote origin >/dev/null 2>&1
$script$, 'git remote -v shows the current URL, git remote set-url origin <url> changes it. Run git fetch afterwards to confirm it works.', 'A remote is only a name for a URL. When fetch says repository not found, check the URL first - a typo is the most common cause.', 10, false, true),
('939bf1f2-60aa-5da3-a413-75f4e73c430b', '29967a89-042d-52f1-9f58-17eca219b36c', 'ca96d10f-2aba-58fe-a0a1-8fbb9b3f09ec', 2, 'Say hello to the team', $md$In onboarding, create welcome.txt containing the line "Hello from the new developer", commit it with the message "Add welcome note", and push it to origin main.$md$, $script$r=/home/labuser/work/onboarding
[ "$(git --git-dir=/home/labuser/srv/git/team.git show main:welcome.txt)" = "Hello from the new developer" ] &&
[ "$(git --git-dir=/home/labuser/srv/git/team.git log -1 --format=%s main)" = "Add welcome note" ] &&
[ "$(git -C $r rev-parse HEAD)" = "$(git --git-dir=/home/labuser/srv/git/team.git rev-parse main)" ]
$script$, 'Create the file, git add, git commit -m, then git push origin main.', 'A commit exists only locally until you push. After the push, the team repository''s main points at your commit, so Maya can pull it.', 15, false, true),
('a84da144-7072-54cd-818a-43925e52e1dd', '29967a89-042d-52f1-9f58-17eca219b36c', '35e262f4-b4b6-55c8-ad82-a7e275db2f42', 3, 'Add a second remote', $md$A repository can have several remotes. Add a remote called backup that points to /home/labuser/srv/git/backup.git and push main to it.$md$, $script$r=/home/labuser/work/onboarding
[ "$(git -C $r remote get-url backup)" = /home/labuser/srv/git/backup.git ] &&
[ "$(git --git-dir=/home/labuser/srv/git/backup.git rev-parse main)" = "$(git -C $r rev-parse main)" ]
$script$, 'git remote add <name> <url>, then git push backup main.', 'origin is just the default name. Any number of remotes can exist, each a different URL, and you choose which one each push goes to.', 15, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '29967a89-042d-52f1-9f58-17eca219b36c', updated_at = now()
WHERE id = 'c34c02e3-aeb7-5608-b7c0-a601eac54d2e' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7f7ff6c6-401b-535a-94d5-db9192fc8acf', '00000000-0000-0000-0000-000000000001', 'mcq', '`git fetch` fails with ''ERROR: Repository not found.'' `git remote -v` shows o...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b7d4c0f4-c90b-50c3-8b5d-17a2a5f09489', '7f7ff6c6-401b-535a-94d5-db9192fc8acf', 1, $json${"prompt":"`git fetch` fails with 'ERROR: Repository not found.' `git remote -v` shows origin as git@github.com:brightsde/shop.git, and you do have access to brightside/shop. What do you do?","multiple":false,"options":[{"id":"a","text":"Generate a new SSH key","is_correct":false},{"id":"b","text":"Fix the typo with `git remote set-url origin git@github.com:brightside/shop.git`","is_correct":true},{"id":"c","text":"Delete and re-clone the repository","is_correct":false},{"id":"d","text":"Run git init","is_correct":false}],"explanation":"The URL says brightsde, a typo. set-url fixes it in one command. A key problem would say 'Permission denied (publickey)', re-cloning is unnecessary, and git init creates a new empty repository."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3eb80542-22ed-5fcf-a2e2-f7f2098d92a6', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which file do you paste into GitHub''s ''SSH keys'' settings page?', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('fb44119c-fa88-5cdc-a6aa-560998e13ccd', '3eb80542-22ed-5fcf-a2e2-f7f2098d92a6', 1, $json${"prompt":"Which file do you paste into GitHub's 'SSH keys' settings page?","multiple":false,"options":[{"id":"a","text":"~/.ssh/id_ed25519","is_correct":false},{"id":"b","text":"~/.ssh/id_ed25519.pub","is_correct":true},{"id":"c","text":"~/.gitconfig","is_correct":false},{"id":"d","text":"~/.git-credentials","is_correct":false}],"explanation":"The .pub file is the public key and is safe to share. The file without .pub is the private key and must never leave your machine. .gitconfig holds settings and .git-credentials holds stored passwords/tokens."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('57821027-a739-5ea8-9d01-f4bea0e40471', '00000000-0000-0000-0000-000000000001', 'mcq', 'You forked a project and cloned your fork. You want to receive new commits fr...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('429e9b9f-cce6-5fa8-8bf9-6511b092533d', '57821027-a739-5ea8-9d01-f4bea0e40471', 1, $json${"prompt":"You forked a project and cloned your fork. You want to receive new commits from the original project. What is the usual setup?","multiple":false,"options":[{"id":"a","text":"Change origin to the original project's URL","is_correct":false},{"id":"b","text":"Add a second remote called upstream pointing to the original, and fetch from it","is_correct":true},{"id":"c","text":"Clone the original project into a subfolder","is_correct":false},{"id":"d","text":"Ask the maintainers to push to your fork","is_correct":false}],"explanation":"origin stays your fork (you push there; you usually cannot push to the original), upstream is the read source. Changing origin would break your pushes, a nested clone is a separate repo, and maintainers do not push to forks."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c1b5470f-af1b-52c9-a699-077da3a27c15', '00000000-0000-0000-0000-000000000001', 'mcq', 'A teammate stored their token with `git config --global credential.helper sto...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('de65623b-4b2f-5ed2-9141-8e86c46b1f51', 'c1b5470f-af1b-52c9-a699-077da3a27c15', 1, $json${"prompt":"A teammate stored their token with `git config --global credential.helper store` on a shared lab machine. What is the risk?","multiple":false,"options":[{"id":"a","text":"None; the token is encrypted","is_correct":false},{"id":"b","text":"The token is saved in plain text in ~/.git-credentials where others with access to the account or backups can read it","is_correct":true},{"id":"c","text":"The token expires immediately","is_correct":false},{"id":"d","text":"Git will stop asking for SSH keys","is_correct":false}],"explanation":"The store helper writes credentials unencrypted. Prefer cache (memory) or an OS keychain/Credential Manager. Storage does not change the token's expiry, and the helper does not affect SSH."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c9133584-77d7-512d-949f-252ad237c3af', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does `git remote remove backup` do?', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('56463fe9-a0ce-56de-9bac-b3c31a84662c', 'c9133584-77d7-512d-949f-252ad237c3af', 1, $json${"prompt":"What does `git remote remove backup` do?","multiple":false,"options":[{"id":"a","text":"Deletes the backup repository on the server","is_correct":false},{"id":"b","text":"Removes only the local name 'backup' and its remote-tracking branches from your repository config","is_correct":true},{"id":"c","text":"Deletes all branches that were pushed to backup","is_correct":false},{"id":"d","text":"Removes the last commit pushed to backup","is_correct":false}],"explanation":"Remotes are local bookmarks. Removing one never touches the server or any commits."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ac6898d1-ed69-5a23-91c2-7c9691e46f63', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 2): you ran `git add app.py`, then edited app.py again, then ...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('fbf26e07-af64-5ecc-b1fa-5b641bc97556', 'ac6898d1-ed69-5a23-91c2-7c9691e46f63', 1, $json${"prompt":"Review (Section 2): you ran `git add app.py`, then edited app.py again, then committed. Which version is in the commit?","multiple":false,"options":[{"id":"a","text":"The version from the moment you ran git add","is_correct":true},{"id":"b","text":"The latest version on disk","is_correct":false},{"id":"c","text":"Both versions, as two commits","is_correct":false},{"id":"d","text":"Neither; the commit fails","is_correct":false}],"explanation":"The index holds the content as it was when you staged it. The later edit is still unstaged. Git never splits it into two commits by itself, and the commit succeeds."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('e4125232-e039-5bef-af15-29af09a5140c', '00000000-0000-0000-0000-000000000001', 'Quiz: Connecting to the Team', 'git-connection-quiz', 'Quiz covering Connecting to the Team.', 'mcq', 'published', 'module', '0b58b4f0-df56-5e5b-a3aa-d2f262507f7b', 10, 70, 5, 12, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'e4125232-e039-5bef-af15-29af09a5140c' AND question_id NOT IN ('7f7ff6c6-401b-535a-94d5-db9192fc8acf', '3eb80542-22ed-5fcf-a2e2-f7f2098d92a6', '57821027-a739-5ea8-9d01-f4bea0e40471', 'c1b5470f-af1b-52c9-a699-077da3a27c15', 'c9133584-77d7-512d-949f-252ad237c3af', 'ac6898d1-ed69-5a23-91c2-7c9691e46f63');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('9ab543a9-a015-5fc1-995a-e8b317b32517', 'e4125232-e039-5bef-af15-29af09a5140c', '7f7ff6c6-401b-535a-94d5-db9192fc8acf', 'b7d4c0f4-c90b-50c3-8b5d-17a2a5f09489', 0, 2),
('1b1220d9-b5a5-5149-b49f-881926ffedff', 'e4125232-e039-5bef-af15-29af09a5140c', '3eb80542-22ed-5fcf-a2e2-f7f2098d92a6', 'fb44119c-fa88-5cdc-a6aa-560998e13ccd', 1, 2),
('52fc44ac-bd67-5350-8438-d99a20de7686', 'e4125232-e039-5bef-af15-29af09a5140c', '57821027-a739-5ea8-9d01-f4bea0e40471', '429e9b9f-cce6-5fa8-8bf9-6511b092533d', 2, 2),
('116a8b05-97b3-5571-b141-b1641ecabf12', 'e4125232-e039-5bef-af15-29af09a5140c', 'c1b5470f-af1b-52c9-a699-077da3a27c15', 'de65623b-4b2f-5ed2-9141-8e86c46b1f51', 3, 2),
('5549053a-cef4-5e05-a327-e6a2a38cbe8f', 'e4125232-e039-5bef-af15-29af09a5140c', 'c9133584-77d7-512d-949f-252ad237c3af', '56463fe9-a0ce-56de-9bac-b3c31a84662c', 4, 2),
('7b2aeb5d-785b-57d8-b0d6-225b2f924f51', 'e4125232-e039-5bef-af15-29af09a5140c', 'ac6898d1-ed69-5a23-91c2-7c9691e46f63', 'fbf26e07-af64-5ecc-b1fa-5b641bc97556', 5, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('0b58b4f0-df56-5e5b-a3aa-d2f262507f7b', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '578c95ce-e505-5625-828c-b7e7a369f64b', 'Quiz: Connecting to the Team', 'assessment', 3, 8, 'e4125232-e039-5bef-af15-29af09a5140c')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Clone, Fetch, Pull and Push
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('d7c6f575-b087-5a71-9221-aabdc36b6f72', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Clone, Fetch, Pull and Push', 4, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('47d223f7-3f28-5818-8db6-b6749b2830cb', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'd7c6f575-b087-5a71-9221-aabdc36b6f72', 'Clone, Remote-Tracking Branches and Upstreams', 'notes', 0, $md$## Why this matters

Maya says: "Pull my latest, add your change, push it back." Before you can do
that you need a clone and you need to read three kinds of branch names:
`main`, `origin/main` and the link between them. Confusing them is the root of
most "but I pulled!" surprises.

## Mental model: your branch, your notes about theirs, and the link

```
        origin  (/home/labuser/srv/git/origin.git)
        A---B---C  <- main
                 \
                  D  <- feature/login
   ============================================
        your clone
        A---B---C  <- main, origin/main
                 \
                  D  <- origin/feature/login
```

- `main` - **your** local branch. Moves when you commit.
- `origin/main` - a **remote-tracking branch**: your last-known note of where
  the server's `main` was. It is read-only and moves only when you `fetch`,
  `pull` or `push`.
- **Upstream** - the setting that links `main` to `origin/main`, so `git status`,
  `git pull` and `git push` know what to compare with.

> **One-sentence definition:** `origin/main` is a snapshot of the server's branch
> as of your last contact, not a live view.

## See it work

### Clone

```bash
git clone /home/labuser/srv/git/origin.git app
cd app
git remote -v
git branch -a
```

What this does: copies the full history, creates remote `origin`, creates
`origin/*` tracking branches, and checks out `main` linked to `origin/main`.
Expected output of `git branch -a`:

```
* main
  remotes/origin/HEAD -> origin/main
  remotes/origin/feature/login
  remotes/origin/main
```

Only `main` is a local branch. The others are your notes about the server.

```knowledge-check
{ "questions": [
  { "id": "git-clone-remote-q1", "type": "mcq",
    "prompt": "What is origin/main in your clone?",
    "options": [
      {"id":"a","text":"A live view of the server's main branch"},
      {"id":"b","text":"A local snapshot of where the server's main was at your last fetch"},
      {"id":"c","text":"A second copy of your own main branch"},
      {"id":"d","text":"A tag"}],
    "correct": "b",
    "explanation": "Remote-tracking branches are only updated when you talk to the remote (fetch, pull, push). They are not live, not a copy of your branch, and not tags." }
] }
```

### Start working on a remote branch

```bash
git switch feature/login
git branch -vv
```

What this does: no local `feature/login` exists, but `origin/feature/login`
does, so `git switch` creates a local branch from it and sets the upstream.
Expected output:

```
* feature/login 5d2e9a1 [origin/feature/login] Add login form
  main          8c1f7b3 [origin/main] Add license
```

The square brackets show the upstream. After you commit locally it becomes
`[origin/main: ahead 1]`; after a fetch brings new server commits it can show
`[origin/main: ahead 1, behind 2]`.

```knowledge-check
{ "questions": [
  { "id": "git-clone-track-q1", "type": "mcq",
    "prompt": "What does git branch -vv show in square brackets?",
    "options": [
      {"id":"a","text":"The upstream (tracked) branch of each local branch"},
      {"id":"b","text":"The author of the last commit"},
      {"id":"c","text":"Files with conflicts"},
      {"id":"d","text":"Stashed changes"}],
    "correct": "a",
    "explanation": "The upstream is what status, pull and push compare against. Authors, conflicts and stashes are shown by other commands." }
] }
```

### Useful clone options

| Option | Effect |
|---|---|
| `git clone <url> mydir` | Clone into a folder named `mydir` |
| `--branch dev` | Check out `dev` instead of the default branch |
| `--depth 1` | Shallow clone: only the latest commit (fast CI checkouts) |
| `--filter=blob:none` | Partial clone: download file contents only when needed |

The last two matter for huge repositories (Section 12).

## Try it

`git status` says: `Your branch is up to date with 'origin/main'.` A teammate
pushed 5 minutes ago. Is your `main` really up to date with the server?

<details>
<summary>Show answer</summary>

Not necessarily. Status compares with `origin/main`, your **last-known** note.
Until you run `git fetch`, Git does not know about the teammate's push.
"Up to date" means "up to date with what I last saw".

</details>

## Common mistakes

- **Committing on `origin/main`.** You cannot; switching to it gives a
  detached HEAD. Work on a local branch.
- **Trusting "up to date" without fetching.** Run `git fetch` first.
- **Cloning inside another repository.** You get a nested repo that the outer
  one sees as a strange folder. Clone into a clean directory.

## Remember

- Clone = full history + remote `origin` + `origin/*` notes + local `main`.
- `origin/main` moves only on fetch, pull or push.
- Upstream links a local branch to its remote branch; see it with `git branch -vv`.
- `git switch <name>` creates a tracking branch from `origin/<name>`.

**Self-check:**

1. What is the difference between `main` and `origin/main`?
2. What does "ahead 1, behind 2" mean?
3. Why can "up to date" be wrong?
$md$, 8, $json$[{"id":"git-clone-remote-q1","type":"mcq","correct":"b"},{"id":"git-clone-track-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0cc26ec8-10e6-5ba0-9bba-6594b7666c7d', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'd7c6f575-b087-5a71-9221-aabdc36b6f72', 'fetch vs pull: Look Before You Merge', 'notes', 1, $md$## Why this matters

`git pull` is the command beginners use most and understand least. It is
really two commands glued together. Knowing the two halves lets you check what
a teammate changed **before** it lands in your branch, and explains the pull
error modern Git shows when histories have diverged.

## Mental model: check the mailbox, then open the letters

- `git fetch` = check the mailbox. New letters arrive in `origin/*`. Nothing on
  your desk changes.
- `git merge origin/main` (or `git rebase origin/main`) = open the letters and
  file them into your own branch.
- `git pull` = both, in one step.

```
 pull = fetch + integrate

 git fetch:       origin/* updated        your branches: untouched
 git merge:       your branch absorbs origin/main
```

## See it work

### fetch is always safe

```bash
git fetch
git log --oneline --graph --all
```

What this does: downloads new commits and moves `origin/main`; never touches
your branches or files. Expected graph when you and a teammate both committed:

```
* 9d4b0c2 (origin/main) Teammate: add changelog
| * 41ae6f8 (HEAD -> main) Add notes.txt
|/
* 8c1f7b3 Add license
```

Now you can inspect before integrating:

```bash
git log main..origin/main --oneline     # commits on the server you do not have
git diff main...origin/main             # what they changed since you split
```

```knowledge-check
{ "questions": [
  { "id": "git-clone-fetch-q1", "type": "mcq",
    "prompt": "After git fetch, which of these has changed?",
    "options": [
      {"id":"a","text":"Your local main branch and working tree"},
      {"id":"b","text":"Only the remote-tracking branches such as origin/main"},
      {"id":"c","text":"Nothing, fetch only prints a message"},
      {"id":"d","text":"The server's branches"}],
    "correct": "b",
    "explanation": "fetch is safe: it never changes your branches or files, and it only reads from the server. It does change something: your origin/* notes." }
] }
```

### pull: fetch and integrate

```
 before pull               after git pull (merge)          after git push
 N <- main                 M <- main  (merge commit)       server main = M
 T <- origin/main           / \                            (fast-forward)
                           N   T <- origin/main
```

```bash
git pull --no-rebase      # fetch + merge
git log --oneline --graph
```

Expected output:

```
*   c7e21d0 (HEAD -> main) Merge branch 'main' of /home/labuser/srv/git/origin
|\
| * 9d4b0c2 (origin/main) Teammate: add changelog
* | 41ae6f8 Add notes.txt
|/
* 8c1f7b3 Add license
```

```knowledge-check
{ "questions": [
  { "id": "git-clone-pull-q1", "type": "mcq",
    "prompt": "git pull is equivalent to:",
    "options": [
      {"id":"a","text":"git fetch followed by git merge (or rebase) of the upstream branch"},
      {"id":"b","text":"git push in the other direction"},
      {"id":"c","text":"git clone again"},
      {"id":"d","text":"git fetch only"}],
    "correct": "a",
    "explanation": "pull = fetch + integrate. Knowing the two halves lets you inspect before integrating. It is not a reverse push, not a re-clone, and it does more than fetch." }
] }
```

### The "divergent branches" message

When both sides have new commits and you have not said how to integrate, modern
Git (2.33+) stops:

```
hint: You have divergent branches and need to specify how to reconcile them.
...
fatal: Need to specify how to reconcile divergent branches.
```

Pick a default once:

| Setting | What pull does when histories diverged |
|---|---|
| `git config --global pull.rebase false` | Merge (creates a merge commit) |
| `git config --global pull.rebase true` | Rebase your commits on top (linear history; Section 8) |
| `git config --global pull.ff only` | Refuse; you decide manually |

Per command: `git pull --no-rebase`, `git pull --rebase`, `git pull --ff-only`.

## Try it

You are about to leave for the weekend and just want to see what the team
pushed today, without touching your half-finished branch. Which commands?

<details>
<summary>Show answer</summary>

```bash
git fetch
git log --oneline HEAD..origin/main
```

`fetch` updates only `origin/*`; the log lists the commits you do not have yet.
Your branch and working tree are untouched.

</details>

## Common mistakes

- **Pulling with uncommitted changes.** If the incoming commits touch the same
  files, Git refuses. Commit or stash (Section 9) first.
- **Thinking fetch "did nothing".** It updated `origin/*`. Look with
  `git log --all --graph`.
- **Accidental merge commits from habitual `git pull`.** Many teams set
  `pull.rebase true` or `pull.ff only` to avoid noise.

## Remember

- `fetch` downloads into `origin/*` and changes nothing else. Always safe.
- `pull` = `fetch` + merge (or rebase).
- `git log main..origin/main` = what you have not integrated yet.
- Set `pull.rebase` (or `pull.ff only`) once to avoid the divergent-branches error.

**Self-check:**

1. Which command updates `origin/main` without touching `main`?
2. What are the two halves of `git pull`?
3. What does `git log main..origin/main` list?
$md$, 8, $json$[{"id":"git-clone-fetch-q1","type":"mcq","correct":"b"},{"id":"git-clone-pull-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('07675baf-17f1-59ee-b3cd-f6a001ad47b2', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'd7c6f575-b087-5a71-9221-aabdc36b6f72', 'push: Publishing Branches and Handling Rejections', 'notes', 2, $md$## Why this matters

Your first rejected push feels like an error. It is actually Git protecting a
teammate's work. Learn what the rejection means, how to publish a new branch
with one command, and how to clean up branches on the server.

## Mental model: the server only accepts "forward"

A normal push may only move a server branch **forward**: your branch must
already contain everything the server branch has. This is called a
**fast-forward**.

```
You commit locally, a teammate pushes first:

            origin/main (server)           your clone
 before:    A---B---C---T                  A---B---C---N   <- main

 git push  -> REJECTED: server has T that you do not have (non-fast-forward)
```

If the server accepted your push, `T` would be thrown away. So it refuses.

## See it work

### A rejected push and the fix

```bash
git push
```

Expected output:

```
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to '/home/labuser/srv/git/origin.git'
hint: Updates were rejected because the remote contains work that you do not
hint: have locally. ...
```

The fix is always: **integrate first, then push.**

```bash
git pull --no-rebase    # or: git pull --rebase
git push
```

Now your branch contains `T`, so the push is a fast-forward for the server.

```knowledge-check
{ "questions": [
  { "id": "git-clone-fetch-q2", "type": "mcq",
    "prompt": "A push is rejected with 'fetch first'. What is the usual fix?",
    "options": [
      {"id":"a","text":"git push --force"},
      {"id":"b","text":"Delete the remote"},
      {"id":"c","text":"Integrate the remote work (pull, or fetch + merge/rebase) and push again"},
      {"id":"d","text":"Re-clone the repository"}],
    "correct": "c",
    "explanation": "Force pushing would erase the teammate's commit. Deleting the remote or re-cloning loses your local work or setup. Integrate first, then push a fast-forward." }
] }
```

### Publish a new branch

```
 before:  feature/search            (local only)
 after :  feature/search -> origin/feature/search     git push -u origin feature/search
```

```bash
git switch -c feature/search
echo search > search.txt && git add search.txt && git commit -m "Add search stub"
git push -u origin feature/search
```

What `-u` (`--set-upstream`) does: pushes **and** records
`origin/feature/search` as the upstream, so later a bare `git push` or
`git pull` knows where to go. Expected last line:

```
branch 'feature/search' set up to track 'origin/feature/search'.
```

Tip: `git config --global push.autoSetupRemote true` makes the first plain
`git push` of a new branch do this automatically.

```knowledge-check
{ "questions": [
  { "id": "git-clone-publish-q1", "type": "mcq",
    "prompt": "What does the -u in git push -u origin feature/search do?",
    "options": [
      {"id":"a","text":"Updates all submodules"},
      {"id":"b","text":"Records origin/feature/search as the upstream so later bare git pull/push work"},
      {"id":"c","text":"Uploads untracked files"},
      {"id":"d","text":"Forces the push"}],
    "correct": "b",
    "explanation": "-u is short for --set-upstream and writes the tracking configuration. It has nothing to do with submodules, untracked files are never pushed, and it does not force anything." }
] }
```

### See what is on the server

```bash
git ls-remote origin
```

Expected output (hashes differ):

```
c7e21d0...	HEAD
c7e21d0...	refs/heads/main
5d2e9a1...	refs/heads/feature/login
e0b64f9...	refs/heads/feature/search
```

### Delete and prune remote branches

```bash
git push origin --delete feature/search   # delete the branch on the server
git fetch --prune                         # drop origin/* notes for branches deleted on the server
```

Set `git config --global fetch.prune true` to prune on every fetch.

## Try it

You ran `git push` on a new branch and got: `fatal: The current branch
feature/x has no upstream branch.` What one command fixes it?

<details>
<summary>Show answer</summary>

```bash
git push -u origin feature/x
```

After that, plain `git push` works for this branch.

</details>

## Common mistakes

- **Answering a rejection with `--force`.** That deletes your teammate's
  commits from the server. Integrate instead.
- **Pushing to the wrong branch.** `git push origin main` while on a feature
  branch pushes your **local main**, not the feature. Read the command carefully.
- **Expecting tags to go up with a plain push.** They do not (Section 11).
- **Stale `origin/*` branches piling up.** Use `fetch --prune`.

## Remember

- Push only fast-forwards the server branch. Rejected = integrate, then push.
- `git push -u origin <branch>` publishes and sets the upstream.
- `git ls-remote origin` shows what the server really has.
- `git push origin --delete <branch>` + `git fetch --prune` clean up.

**Self-check:**

1. Why does Git reject a non-fast-forward push?
2. What does `-u` record?
3. Which command removes stale `origin/*` branches?
$md$, 8, $json$[{"id":"git-clone-fetch-q2","type":"mcq","correct":"c"},{"id":"git-clone-publish-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('947b350f-4ed2-52fc-a567-1835f9dc5805', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'd7c6f575-b087-5a71-9221-aabdc36b6f72', 'Lab: Clone, Track, Fetch, Pull and Push', 'notes', 3, $md$## Why this matters

This is the loop you will run every working day: clone, track a branch, commit,
get rejected because a teammate pushed first, fetch, integrate, push, and
publish a new branch. The "server" is the bare repository `/home/labuser/srv/git/origin.git`.
A helper command, `~/bin/teammate-push`, plays Maya pushing to `main`.

## Task 1: clone

Clone `/home/labuser/srv/git/origin.git` into `~/work/app`.

[[lab-task:1]]

Expected `git remote -v` inside `app`:

```
origin  /home/labuser/srv/git/origin.git (fetch)
origin  /home/labuser/srv/git/origin.git (push)
```

## Task 2: track a remote branch

`origin/feature/login` exists, but you have no local `feature/login`. Create one
that tracks it.

[[lab-task:2]]

Expected `git branch -vv`:

```
* feature/login 5d2e9a1 [origin/feature/login] Add login form
  main          8c1f7b3 [origin/main] Add license
```

## Task 3: commit locally

Back on `main`, commit a new file `notes.txt` as `Add notes.txt`. Do not push.
`git status` should now say `ahead of 'origin/main' by 1 commit`.

[[lab-task:3]]

## Task 4: get rejected, then fetch

Run `~/bin/teammate-push`, then try `git push` and read the rejection. Then `git fetch`
(not pull) so only `origin/main` moves.

```
 after teammate-push and git fetch:

 * 9d4b0c2 (origin/main) Teammate: add changelog
 | * 41ae6f8 (HEAD -> main) Add notes.txt
 |/
 * 8c1f7b3 Add license
```

[[lab-task:4]]

Expected rejection:

```
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to '/home/labuser/srv/git/origin.git'
```

## Task 5: integrate and push

Merge the teammate's commit with `git pull` (merge strategy is the default in
this lab), then push.

[[lab-task:5]]

Expected `git log --oneline --graph`:

```
*   c7e21d0 (HEAD -> main, origin/main) Merge branch 'main' of /home/labuser/srv/git/origin
|\
| * 9d4b0c2 Teammate: add changelog
* | 41ae6f8 Add notes.txt
|/
* 8c1f7b3 Add license
```

## Task 6: publish a new branch

Create `feature/search` with one commit `Add search stub` (file `search.txt`)
and push it with upstream tracking.

[[lab-task:6]]

Check: `git ls-remote origin` lists `refs/heads/feature/search`, and
`git status` on the branch says `up to date with 'origin/feature/search'`.

## Remember

- Rejected push = someone pushed first. Fetch, integrate, push.
- `fetch` is safe to run any time.
- `push -u` once per new branch.
$md$, 35, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '947b350f-4ed2-52fc-a567-1835f9dc5805', 'module', 'Lab: Clone, Track, Fetch, Pull and Push', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global pull.rebase false
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
rm -rf /home/labuser/srv/git /home/labuser/work/app /tmp/seed
mkdir -p /home/labuser/srv/git
git init -q --bare /home/labuser/srv/git/origin.git
git clone -q /home/labuser/srv/git/origin.git /tmp/seed 2>/dev/null
cd /tmp/seed
export GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com
c() { GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
echo "# Shop" > README.md; git add -A; c 2024-01-01 "Initial commit"
echo 'echo shop' > app.sh; git add -A; c 2024-01-02 "Add app script"
echo MIT > LICENSE; git add -A; c 2024-01-03 "Add license"
git push -q origin main
git switch -q -c feature/login
echo "login form" > login.txt; git add -A; c 2024-01-04 "Add login form"
git push -q origin feature/login
cd /; rm -rf /tmp/seed
git --git-dir=/home/labuser/srv/git/origin.git symbolic-ref HEAD refs/heads/main
mkdir -p /home/labuser/bin
cat > /home/labuser/bin/teammate-push <<'SCRIPT'
#!/bin/bash
# Simulates a teammate pushing a commit to origin/main.
set -e
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
git clone -q /home/labuser/srv/git/origin.git "$t/w" 2>/dev/null; cd "$t/w"
if git log --format=%s | grep -qx "Teammate: add changelog"; then echo "teammate already pushed"; exit 0; fi
echo "# Changelog" > CHANGELOG.md; git add -A
GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com \
GIT_AUTHOR_DATE="2024-01-10T10:00:00+0000" GIT_COMMITTER_DATE="2024-01-10T10:00:00+0000" git commit -q -m "Teammate: add changelog"
git push -q origin main
echo "teammate pushed to origin/main"
SCRIPT
chmod 755 /home/labuser/bin/teammate-push
chmod -R a+rwX /home/labuser/srv/git
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '292d0dec-8892-5e07-b9f1-c367e915691b' AND id NOT IN ('9bdbbf8f-61fb-58f8-93b7-bb3642c64ac6', 'e33683d5-72e4-5e9f-86d8-ce8ab93750fd', 'ba243adf-812f-547b-94d8-14e1f1153cfa', '365f0f9d-f97b-5c6a-b8cf-76af5f30ec5e', '3cd8124f-c316-576e-b447-a7c74f3dfb34', '266084c9-e3c5-576a-b499-943755c5dbc8');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '292d0dec-8892-5e07-b9f1-c367e915691b';
DELETE FROM lab_tasks WHERE lab_id = '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab' AND id NOT IN ('4fab9e36-245a-5109-9ed1-72c9448e763c', 'e2c240b8-c9b9-5c7a-aeca-f8667b4f31da', '9080cd27-8ebf-5570-a221-54d126263d25', '1895b7cf-e85c-5ec6-b6e1-288dcb22efa7', '1366dcc7-86a3-5f9b-9412-09b3734824a6', '812f0aba-9a39-5e39-9b18-39f4817967ec');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4fab9e36-245a-5109-9ed1-72c9448e763c', '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', 1, 'Clone the shared repository', $md$The team repository lives at /home/labuser/srv/git/origin.git (a bare repository acting as "the server"). Clone it into a directory called app inside your work directory.$md$, $script$r=/home/labuser/work/app
[ "$(git -C $r remote get-url origin)" = /home/labuser/srv/git/origin.git ] &&
[ "$(git -C $r symbolic-ref HEAD)" = refs/heads/main ] &&
[ "$(git -C $r rev-list --count HEAD)" = 3 ]
$script$, 'git clone <url> <directory>. A local path works as a URL. Afterwards run git remote -v to see where origin points.', 'Clone copies all history, creates the remote named origin, remote-tracking refs (origin/main ...) and checks out main with main tracking origin/main.', 10, false, true),
('e2c240b8-c9b9-5c7a-aeca-f8667b4f31da', '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', 2, 'Check out a remote branch', $md$origin also has a branch feature/login. Create a local branch feature/login that tracks origin/feature/login (git switch can do this for you).$md$, $script$r=/home/labuser/work/app
[ "$(git -C $r config branch.feature/login.remote)" = origin ] &&
[ "$(git -C $r config branch.feature/login.merge)" = refs/heads/feature/login ] &&
git -C $r log feature/login --format=%s | grep -qx "Add login form"
$script$, 'git branch -a lists remote-tracking branches. git switch feature/login creates a tracking branch when only origin/feature/login exists.', 'A tracking branch remembers its upstream, so git status can say "ahead 1, behind 2" and plain git pull / git push know where to go.', 10, false, true),
('9080cd27-8ebf-5570-a221-54d126263d25', '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', 3, 'Commit locally on main', $md$Switch back to main and commit a new file notes.txt (any content) with the message "Add notes.txt". Do not push yet.$md$, $script$r=/home/labuser/work/app
[ "$(git -C $r rev-list --count origin/main..main)" = 1 ] &&
[ "$(git -C $r log main -1 --format=%s)" = "Add notes.txt" ] &&
[ "$(git -C $r rev-list --count main..origin/main)" = 0 ]
$script$, 'git switch main, then create, add and commit the file. git status should now say "ahead of origin/main by 1 commit".', 'Commits are local until pushed. origin/main is only your last known copy of the remote branch, so main being ahead is normal.', 10, false, true),
('1895b7cf-e85c-5ec6-b6e1-288dcb22efa7', '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', 4, 'Fetch a teammate''s work without merging', $md$Run the helper command ~/bin/teammate-push (it simulates a colleague pushing to origin/main). Then try git push - it will be rejected. Run git fetch (not pull) so origin/main updates while your own main stays untouched.$md$, $script$r=/home/labuser/work/app
o=$(git -C $r ls-remote origin refs/heads/main | cut -f1)
[ "$(git -C $r rev-parse origin/main)" = "$o" ] &&
[ "$(git -C $r rev-parse main)" != "$o" ] &&
git -C $r log origin/main --format=%s | grep -qx "Teammate: add changelog" &&
[ "$(git -C $r log main -1 --format=%s)" = "Add notes.txt" ]
$script$, 'Run ~/bin/teammate-push first. After git push is rejected, git fetch updates origin/main but never touches your branches. Compare with git log --oneline --graph --all.', 'Push is rejected (non-fast-forward) because origin/main has a commit you lack. fetch downloads it into the remote-tracking branch only; pull would also merge it into your branch.', 20, false, true),
('1366dcc7-86a3-5f9b-9412-09b3734824a6', '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', 5, 'Integrate and push', $md$Bring the teammate's commit into main with git pull (merge strategy) and push main so origin has both the changelog commit and your notes commit.$md$, $script$r=/home/labuser/work/app
o=$(git -C $r ls-remote origin refs/heads/main | cut -f1)
[ "$(git -C $r rev-parse main)" = "$o" ] &&
git -C $r log origin/main --format=%s | grep -qx "Add notes.txt" &&
git -C $r log origin/main --format=%s | grep -qx "Teammate: add changelog" &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git pull = git fetch + git merge. The system default is merge (pull.rebase=false). Afterwards git push publishes the merge.', 'Your main and origin/main had diverged, so pull creates a merge commit joining them; the follow-up push is then a fast-forward for the server.', 20, false, true),
('812f0aba-9a39-5e39-9b18-39f4817967ec', '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', 6, 'Publish a new branch with upstream tracking', $md$Create a branch feature/search with one commit "Add search stub" (add a file search.txt) and push it to origin, setting the upstream so a bare git push works later.$md$, $script$r=/home/labuser/work/app
o=$(git -C $r ls-remote origin refs/heads/feature/search | cut -f1)
[ -n "$o" ] &&
[ "$(git -C $r rev-parse feature/search)" = "$o" ] &&
[ "$(git -C $r rev-parse feature/search@{upstream})" = "$o" ] &&
[ "$(git -C $r log feature/search -1 --format=%s)" = "Add search stub" ]
$script$, 'git push -u origin <branch> pushes and records the upstream in one step.', '-u (--set-upstream) writes branch.<name>.remote and .merge, which is what makes git status and bare git pull/push work for that branch.', 15, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('292d0dec-8892-5e07-b9f1-c367e915691b', '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', 1, $json$[{"id":"4fab9e36-245a-5109-9ed1-72c9448e763c","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":1,"title":"Clone the shared repository","description":"The team repository lives at /home/labuser/srv/git/origin.git (a bare repository acting as \"the server\"). Clone it into a directory called app inside your work directory.","verification_script":"r=/home/labuser/work/app\n[ \"$(git -C $r remote get-url origin)\" = /home/labuser/srv/git/origin.git ] \u0026\u0026\n[ \"$(git -C $r symbolic-ref HEAD)\" = refs/heads/main ] \u0026\u0026\n[ \"$(git -C $r rev-list --count HEAD)\" = 3 ]\n","hint_context":"git clone \u003curl\u003e \u003cdirectory\u003e. A local path works as a URL. Afterwards run git remote -v to see where origin points.","explanation_context":"Clone copies all history, creates the remote named origin, remote-tracking refs (origin/main ...) and checks out main with main tracking origin/main.","points":10,"is_optional":false,"is_stateful":true},{"id":"e2c240b8-c9b9-5c7a-aeca-f8667b4f31da","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":2,"title":"Check out a remote branch","description":"origin also has a branch feature/login. Create a local branch feature/login that tracks origin/feature/login (git switch can do this for you).","verification_script":"r=/home/labuser/work/app\n[ \"$(git -C $r config branch.feature/login.remote)\" = origin ] \u0026\u0026\n[ \"$(git -C $r config branch.feature/login.merge)\" = refs/heads/feature/login ] \u0026\u0026\ngit -C $r log feature/login --format=%s | grep -qx \"Add login form\"\n","hint_context":"git branch -a lists remote-tracking branches. git switch feature/login creates a tracking branch when only origin/feature/login exists.","explanation_context":"A tracking branch remembers its upstream, so git status can say \"ahead 1, behind 2\" and plain git pull / git push know where to go.","points":10,"is_optional":false,"is_stateful":true},{"id":"9080cd27-8ebf-5570-a221-54d126263d25","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":3,"title":"Commit locally on main","description":"Switch back to main and commit a new file notes.txt (any content) with the message \"Add notes.txt\". Do not push yet.","verification_script":"r=/home/labuser/work/app\n[ \"$(git -C $r rev-list --count origin/main..main)\" = 1 ] \u0026\u0026\n[ \"$(git -C $r log main -1 --format=%s)\" = \"Add notes.txt\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --count main..origin/main)\" = 0 ]\n","hint_context":"git switch main, then create, add and commit the file. git status should now say \"ahead of origin/main by 1 commit\".","explanation_context":"Commits are local until pushed. origin/main is only your last known copy of the remote branch, so main being ahead is normal.","points":10,"is_optional":false,"is_stateful":true},{"id":"1895b7cf-e85c-5ec6-b6e1-288dcb22efa7","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":4,"title":"Fetch a teammate's work without merging","description":"Run the helper command ~/bin/teammate-push (it simulates a colleague pushing to origin/main). Then try git push - it will be rejected. Run git fetch (not pull) so origin/main updates while your own main stays untouched.","verification_script":"r=/home/labuser/work/app\no=$(git -C $r ls-remote origin refs/heads/main | cut -f1)\n[ \"$(git -C $r rev-parse origin/main)\" = \"$o\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse main)\" != \"$o\" ] \u0026\u0026\ngit -C $r log origin/main --format=%s | grep -qx \"Teammate: add changelog\" \u0026\u0026\n[ \"$(git -C $r log main -1 --format=%s)\" = \"Add notes.txt\" ]\n","hint_context":"Run ~/bin/teammate-push first. After git push is rejected, git fetch updates origin/main but never touches your branches. Compare with git log --oneline --graph --all.","explanation_context":"Push is rejected (non-fast-forward) because origin/main has a commit you lack. fetch downloads it into the remote-tracking branch only; pull would also merge it into your branch.","points":20,"is_optional":false,"is_stateful":true},{"id":"1366dcc7-86a3-5f9b-9412-09b3734824a6","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":5,"title":"Integrate and push","description":"Bring the teammate's commit into main with git pull (merge strategy) and push main so origin has both the changelog commit and your notes commit.","verification_script":"r=/home/labuser/work/app\no=$(git -C $r ls-remote origin refs/heads/main | cut -f1)\n[ \"$(git -C $r rev-parse main)\" = \"$o\" ] \u0026\u0026\ngit -C $r log origin/main --format=%s | grep -qx \"Add notes.txt\" \u0026\u0026\ngit -C $r log origin/main --format=%s | grep -qx \"Teammate: add changelog\" \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"git pull = git fetch + git merge. The system default is merge (pull.rebase=false). Afterwards git push publishes the merge.","explanation_context":"Your main and origin/main had diverged, so pull creates a merge commit joining them; the follow-up push is then a fast-forward for the server.","points":20,"is_optional":false,"is_stateful":true},{"id":"812f0aba-9a39-5e39-9b18-39f4817967ec","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":6,"title":"Publish a new branch with upstream tracking","description":"Create a branch feature/search with one commit \"Add search stub\" (add a file search.txt) and push it to origin, setting the upstream so a bare git push works later.","verification_script":"r=/home/labuser/work/app\no=$(git -C $r ls-remote origin refs/heads/feature/search | cut -f1)\n[ -n \"$o\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse feature/search)\" = \"$o\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse feature/search@{upstream})\" = \"$o\" ] \u0026\u0026\n[ \"$(git -C $r log feature/search -1 --format=%s)\" = \"Add search stub\" ]\n","hint_context":"git push -u origin \u003cbranch\u003e pushes and records the upstream in one step.","explanation_context":"-u (--set-upstream) writes branch.\u003cname\u003e.remote and .merge, which is what makes git status and bare git pull/push work for that branch.","points":15,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('9bdbbf8f-61fb-58f8-93b7-bb3642c64ac6', '292d0dec-8892-5e07-b9f1-c367e915691b', '4fab9e36-245a-5109-9ed1-72c9448e763c', 1, 'Clone the shared repository', $md$The team repository lives at /home/labuser/srv/git/origin.git (a bare repository acting as "the server"). Clone it into a directory called app inside your work directory.$md$, $script$r=/home/labuser/work/app
[ "$(git -C $r remote get-url origin)" = /home/labuser/srv/git/origin.git ] &&
[ "$(git -C $r symbolic-ref HEAD)" = refs/heads/main ] &&
[ "$(git -C $r rev-list --count HEAD)" = 3 ]
$script$, 'git clone <url> <directory>. A local path works as a URL. Afterwards run git remote -v to see where origin points.', 'Clone copies all history, creates the remote named origin, remote-tracking refs (origin/main ...) and checks out main with main tracking origin/main.', 10, false, true),
('e33683d5-72e4-5e9f-86d8-ce8ab93750fd', '292d0dec-8892-5e07-b9f1-c367e915691b', 'e2c240b8-c9b9-5c7a-aeca-f8667b4f31da', 2, 'Check out a remote branch', $md$origin also has a branch feature/login. Create a local branch feature/login that tracks origin/feature/login (git switch can do this for you).$md$, $script$r=/home/labuser/work/app
[ "$(git -C $r config branch.feature/login.remote)" = origin ] &&
[ "$(git -C $r config branch.feature/login.merge)" = refs/heads/feature/login ] &&
git -C $r log feature/login --format=%s | grep -qx "Add login form"
$script$, 'git branch -a lists remote-tracking branches. git switch feature/login creates a tracking branch when only origin/feature/login exists.', 'A tracking branch remembers its upstream, so git status can say "ahead 1, behind 2" and plain git pull / git push know where to go.', 10, false, true),
('ba243adf-812f-547b-94d8-14e1f1153cfa', '292d0dec-8892-5e07-b9f1-c367e915691b', '9080cd27-8ebf-5570-a221-54d126263d25', 3, 'Commit locally on main', $md$Switch back to main and commit a new file notes.txt (any content) with the message "Add notes.txt". Do not push yet.$md$, $script$r=/home/labuser/work/app
[ "$(git -C $r rev-list --count origin/main..main)" = 1 ] &&
[ "$(git -C $r log main -1 --format=%s)" = "Add notes.txt" ] &&
[ "$(git -C $r rev-list --count main..origin/main)" = 0 ]
$script$, 'git switch main, then create, add and commit the file. git status should now say "ahead of origin/main by 1 commit".', 'Commits are local until pushed. origin/main is only your last known copy of the remote branch, so main being ahead is normal.', 10, false, true),
('365f0f9d-f97b-5c6a-b8cf-76af5f30ec5e', '292d0dec-8892-5e07-b9f1-c367e915691b', '1895b7cf-e85c-5ec6-b6e1-288dcb22efa7', 4, 'Fetch a teammate''s work without merging', $md$Run the helper command ~/bin/teammate-push (it simulates a colleague pushing to origin/main). Then try git push - it will be rejected. Run git fetch (not pull) so origin/main updates while your own main stays untouched.$md$, $script$r=/home/labuser/work/app
o=$(git -C $r ls-remote origin refs/heads/main | cut -f1)
[ "$(git -C $r rev-parse origin/main)" = "$o" ] &&
[ "$(git -C $r rev-parse main)" != "$o" ] &&
git -C $r log origin/main --format=%s | grep -qx "Teammate: add changelog" &&
[ "$(git -C $r log main -1 --format=%s)" = "Add notes.txt" ]
$script$, 'Run ~/bin/teammate-push first. After git push is rejected, git fetch updates origin/main but never touches your branches. Compare with git log --oneline --graph --all.', 'Push is rejected (non-fast-forward) because origin/main has a commit you lack. fetch downloads it into the remote-tracking branch only; pull would also merge it into your branch.', 20, false, true),
('3cd8124f-c316-576e-b447-a7c74f3dfb34', '292d0dec-8892-5e07-b9f1-c367e915691b', '1366dcc7-86a3-5f9b-9412-09b3734824a6', 5, 'Integrate and push', $md$Bring the teammate's commit into main with git pull (merge strategy) and push main so origin has both the changelog commit and your notes commit.$md$, $script$r=/home/labuser/work/app
o=$(git -C $r ls-remote origin refs/heads/main | cut -f1)
[ "$(git -C $r rev-parse main)" = "$o" ] &&
git -C $r log origin/main --format=%s | grep -qx "Add notes.txt" &&
git -C $r log origin/main --format=%s | grep -qx "Teammate: add changelog" &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git pull = git fetch + git merge. The system default is merge (pull.rebase=false). Afterwards git push publishes the merge.', 'Your main and origin/main had diverged, so pull creates a merge commit joining them; the follow-up push is then a fast-forward for the server.', 20, false, true),
('266084c9-e3c5-576a-b499-943755c5dbc8', '292d0dec-8892-5e07-b9f1-c367e915691b', '812f0aba-9a39-5e39-9b18-39f4817967ec', 6, 'Publish a new branch with upstream tracking', $md$Create a branch feature/search with one commit "Add search stub" (add a file search.txt) and push it to origin, setting the upstream so a bare git push works later.$md$, $script$r=/home/labuser/work/app
o=$(git -C $r ls-remote origin refs/heads/feature/search | cut -f1)
[ -n "$o" ] &&
[ "$(git -C $r rev-parse feature/search)" = "$o" ] &&
[ "$(git -C $r rev-parse feature/search@{upstream})" = "$o" ] &&
[ "$(git -C $r log feature/search -1 --format=%s)" = "Add search stub" ]
$script$, 'git push -u origin <branch> pushes and records the upstream in one step.', '-u (--set-upstream) writes branch.<name>.remote and .merge, which is what makes git status and bare git pull/push work for that branch.', 15, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '292d0dec-8892-5e07-b9f1-c367e915691b', updated_at = now()
WHERE id = '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3cfc11f9-a5a6-514d-9eaf-49da3c14445a', '00000000-0000-0000-0000-000000000001', 'mcq', '`git status` says ''Your branch is up to date with origin/main'', yet a teammat...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ab5be590-ae41-51c8-8573-439cfb239d3d', '3cfc11f9-a5a6-514d-9eaf-49da3c14445a', 1, $json${"prompt":"`git status` says 'Your branch is up to date with origin/main', yet a teammate says they pushed an hour ago. Who is right?","multiple":false,"options":[{"id":"a","text":"Git; status always checks the server","is_correct":false},{"id":"b","text":"Possibly both: status compares with origin/main as of your last fetch, so you may simply not have fetched","is_correct":true},{"id":"c","text":"The teammate; status is broken","is_correct":false},{"id":"d","text":"Neither; pushes take a day to appear","is_correct":false}],"explanation":"status never contacts the server. Run git fetch and status will show 'behind'. Nothing is broken, and pushes are visible immediately to anyone who fetches."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7daa41ca-d3f5-5ad8-8e1b-4444f448be93', '00000000-0000-0000-0000-000000000001', 'mcq', 'You want to review a teammate''s new commits on main before they touch your br...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1c2963ff-43fb-5f06-810e-e9718fd17479', '7daa41ca-d3f5-5ad8-8e1b-4444f448be93', 1, $json${"prompt":"You want to review a teammate's new commits on main before they touch your branch. Which sequence fits?","multiple":false,"options":[{"id":"a","text":"git pull, then git log","is_correct":false},{"id":"b","text":"git fetch, then git log main..origin/main and git diff main...origin/main","is_correct":true},{"id":"c","text":"git push, then git log","is_correct":false},{"id":"d","text":"git clone into a new folder every time","is_correct":false}],"explanation":"fetch only updates origin/main, so you can inspect first. pull would integrate before you looked, push sends your work instead, and re-cloning is slow and unnecessary."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cb4f985e-0456-5bb7-b4b7-13c521940d5e', '00000000-0000-0000-0000-000000000001', 'mcq', '`git push` prints ''! [rejected] main -> main (fetch first)''. A colleague sugg...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a26ab78b-b1cc-5d24-9c38-719d32739879', 'cb4f985e-0456-5bb7-b4b7-13c521940d5e', 1, $json${"prompt":"`git push` prints '! [rejected] main -\u003e main (fetch first)'. A colleague suggests `git push --force`. What happens if you do?","multiple":false,"options":[{"id":"a","text":"The server keeps both your commits and theirs","is_correct":false},{"id":"b","text":"The server's main is replaced by yours and the teammate's commit disappears from it","is_correct":true},{"id":"c","text":"Git merges automatically on the server","is_correct":false},{"id":"d","text":"The push is still rejected; force only works on tags","is_correct":false}],"explanation":"Force overwrites the server branch, dropping commits you did not have. Servers never merge for you, and force works on branches (unless the server protects them). Integrate and push normally instead."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('734a605e-39c5-5f0f-b8b2-f5a1a88c4f14', '00000000-0000-0000-0000-000000000001', 'mcq', 'You created feature/cart locally. What is the command to publish it AND make ...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('708c74b3-37bc-5045-bf80-311206fb111c', '734a605e-39c5-5f0f-b8b2-f5a1a88c4f14', 1, $json${"prompt":"You created feature/cart locally. What is the command to publish it AND make later plain `git push` work?","multiple":false,"options":[{"id":"a","text":"git push","is_correct":false},{"id":"b","text":"git push -u origin feature/cart","is_correct":true},{"id":"c","text":"git fetch -u origin feature/cart","is_correct":false},{"id":"d","text":"git remote add feature/cart","is_correct":false}],"explanation":"-u sets the upstream while pushing. Plain git push fails for a branch with no upstream (unless push.autoSetupRemote is set), fetch downloads instead of uploading, and remote add creates a remote, not a branch."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('abc88a9a-0cb9-5a4e-8263-d20f70352c60', '00000000-0000-0000-0000-000000000001', 'mcq', '`git pull` fails with ''fatal: Need to specify how to reconcile divergent bran...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('3971c957-14e4-55ae-bce7-56e65e4f9841', 'abc88a9a-0cb9-5a4e-8263-d20f70352c60', 1, $json${"prompt":"`git pull` fails with 'fatal: Need to specify how to reconcile divergent branches.' What does it mean?","multiple":false,"options":[{"id":"a","text":"The remote is unreachable","is_correct":false},{"id":"b","text":"Both your branch and the remote branch have new commits, and no pull strategy (merge, rebase or ff-only) is configured","is_correct":true},{"id":"c","text":"You have a merge conflict","is_correct":false},{"id":"d","text":"Your branch has no upstream","is_correct":false}],"explanation":"Set pull.rebase true/false or pull.ff only, or pass --rebase/--no-rebase. An unreachable remote gives a connection error, a conflict only happens after integration starts, and a missing upstream gives a different message."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e974c2c2-685a-5c81-a47b-69317a551e90', '00000000-0000-0000-0000-000000000001', 'mcq', 'Branches deleted on the server still appear in `git branch -r`. How do you cl...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('41159248-5601-5909-adb1-bd5e3d2ab53f', 'e974c2c2-685a-5c81-a47b-69317a551e90', 1, $json${"prompt":"Branches deleted on the server still appear in `git branch -r`. How do you clean them up?","multiple":false,"options":[{"id":"a","text":"git branch -D origin/old-branch","is_correct":false},{"id":"b","text":"git fetch --prune","is_correct":true},{"id":"c","text":"git push --prune","is_correct":false},{"id":"d","text":"git remote remove origin","is_correct":false}],"explanation":"fetch --prune removes remote-tracking branches whose server branch is gone. branch -D works on local branches, push --prune deletes on the server (dangerous), and removing origin breaks your setup."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d7d5a02c-2405-58ae-89d4-7ca896c804db', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 3): you get ''Permission denied (publickey)'' on push. Which is...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9dabb46a-43e3-5c8b-8b80-4ef0b4c68a45', 'd7d5a02c-2405-58ae-89d4-7ca896c804db', 1, $json${"prompt":"Review (Section 3): you get 'Permission denied (publickey)' on push. Which is the most likely cause?","multiple":false,"options":[{"id":"a","text":"Your public key is not registered with the host or not loaded in ssh-agent","is_correct":true},{"id":"b","text":"You have not fetched recently","is_correct":false},{"id":"c","text":"The branch has no upstream","is_correct":false},{"id":"d","text":"The commit message is too long","is_correct":false}],"explanation":"publickey errors are SSH authentication problems. Fetch state, upstreams and messages do not affect authentication."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('019d482f-072b-56ca-a6bc-ec82b9fc8df4', '00000000-0000-0000-0000-000000000001', 'Quiz: Clone, Fetch, Pull and Push', 'git-clone-remotes-quiz', 'Quiz covering Clone, Fetch, Pull and Push.', 'mcq', 'published', 'module', 'f256ea86-e619-5891-91da-63c4bcaac387', 12, 70, 5, 14, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '019d482f-072b-56ca-a6bc-ec82b9fc8df4' AND question_id NOT IN ('3cfc11f9-a5a6-514d-9eaf-49da3c14445a', '7daa41ca-d3f5-5ad8-8e1b-4444f448be93', 'cb4f985e-0456-5bb7-b4b7-13c521940d5e', '734a605e-39c5-5f0f-b8b2-f5a1a88c4f14', 'abc88a9a-0cb9-5a4e-8263-d20f70352c60', 'e974c2c2-685a-5c81-a47b-69317a551e90', 'd7d5a02c-2405-58ae-89d4-7ca896c804db');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('314a5cee-f749-59a1-a454-7002dab49d10', '019d482f-072b-56ca-a6bc-ec82b9fc8df4', '3cfc11f9-a5a6-514d-9eaf-49da3c14445a', 'ab5be590-ae41-51c8-8573-439cfb239d3d', 0, 2),
('46164428-30de-5fff-a4b5-5d2c51d7544f', '019d482f-072b-56ca-a6bc-ec82b9fc8df4', '7daa41ca-d3f5-5ad8-8e1b-4444f448be93', '1c2963ff-43fb-5f06-810e-e9718fd17479', 1, 2),
('a77a3840-83b9-53db-836f-fdf846d9dbb5', '019d482f-072b-56ca-a6bc-ec82b9fc8df4', 'cb4f985e-0456-5bb7-b4b7-13c521940d5e', 'a26ab78b-b1cc-5d24-9c38-719d32739879', 2, 2),
('94f8667e-f923-5a2e-9fe2-d538ef0a678d', '019d482f-072b-56ca-a6bc-ec82b9fc8df4', '734a605e-39c5-5f0f-b8b2-f5a1a88c4f14', '708c74b3-37bc-5045-bf80-311206fb111c', 3, 2),
('758111a7-24a0-5cb2-a584-3347782ade2d', '019d482f-072b-56ca-a6bc-ec82b9fc8df4', 'abc88a9a-0cb9-5a4e-8263-d20f70352c60', '3971c957-14e4-55ae-bce7-56e65e4f9841', 4, 2),
('bf006dfd-5725-5fbc-9e4c-3d1faf05ba58', '019d482f-072b-56ca-a6bc-ec82b9fc8df4', 'e974c2c2-685a-5c81-a47b-69317a551e90', '41159248-5601-5909-adb1-bd5e3d2ab53f', 5, 2),
('55038347-c014-54ca-a7cb-c5ea1cb85ed2', '019d482f-072b-56ca-a6bc-ec82b9fc8df4', 'd7d5a02c-2405-58ae-89d4-7ca896c804db', '9dabb46a-43e3-5c8b-8b80-4ef0b4c68a45', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('f256ea86-e619-5891-91da-63c4bcaac387', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'd7c6f575-b087-5a71-9221-aabdc36b6f72', 'Quiz: Clone, Fetch, Pull and Push', 'assessment', 4, 10, '019d482f-072b-56ca-a6bc-ec82b9fc8df4')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Branching and Merging
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('498e7765-54bf-5ac3-a80c-bab3bb98f650', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Branching and Merging', 5, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('47c62acd-63ce-5106-abed-6470491a63dc', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '498e7765-54bf-5ac3-a80c-bab3bb98f650', 'Creating, Switching and Deleting Branches', 'notes', 0, $md$## Why this matters

Maya is mid-release: "Don't touch main. Do your login form on a branch." On a
team, every change starts on a branch so that `main` stays releasable. You need
to create branches, move between them and clean them up without fear.

## Mental model: bookmarks in one book

All branches live in one book of commits. A branch is a bookmark; `HEAD` is
your finger saying which bookmark you are reading. Switching branches swaps the
pages on your desk (the working tree) to that bookmark's snapshot.

```
BEFORE  git switch -c feature/greeting     AFTER one commit on the new branch

 A---B---C  <- main <- HEAD                 A---B---C  <- main
                                                     \
                                                      D  <- feature/greeting <- HEAD
```

Under the hood a branch is a 41-byte file (40 hex characters + newline) in
`.git/refs/heads/`. Creating one copies a pointer, nothing else.

## See it work

### Create and switch

```bash
cd ~/work/shop
git switch -c feature/greeting       # create + switch (old style: git checkout -b)
echo hello > greeting.txt && git add greeting.txt && git commit -m "Add greeting"
git log --oneline --graph --all
```

Expected output (hashes differ):

```
* 2ab9c40 (HEAD -> feature/greeting) Add greeting
| * 77d1e0a (feature/cart) Add cart totals
| * 0c4f8e2 Add cart file
|/
* 5e13a9b (main) Add checkout
* 9b2d6c1 Add product list
* 1f0a7d3 Initial commit
```

`git log --oneline --graph --all` is the single most useful command for seeing
branches. Make an alias: `git config --global alias.lg "log --oneline --graph --all"`,
then type `git lg`.

```knowledge-check
{ "questions": [
  { "id": "git-branch-pointer-q1", "type": "mcq",
    "prompt": "What does creating a new branch copy?",
    "options": [
      {"id":"a","text":"All files in the repository"},
      {"id":"b","text":"Only a pointer to the current commit"},
      {"id":"c","text":"The whole history"},
      {"id":"d","text":"The staging area only"}],
    "correct": "b",
    "explanation": "Branches are cheap because they are just references to commits. No files, history or index are copied." }
] }
```

### The everyday branch commands

| Command | What it does |
|---|---|
| `git branch` | List local branches; `*` marks the current one |
| `git switch <name>` | Move to an existing branch |
| `git switch -c <name> [start]` | Create (optionally from `start`) and switch |
| `git switch -` | Jump back to the previous branch |
| `git branch -m <new>` | Rename the current branch |
| `git branch -d <name>` | Delete a branch that is fully merged |
| `git branch -D <name>` | Force-delete, even if unmerged |
| `git branch --merged` | List branches already merged into the current one |

`git checkout` does both switching and file restoring; the newer `switch` and
`restore` split those jobs so mistakes are harder. You will still see
`checkout` in older guides.

### Uncommitted changes travel with you

If you switch with uncommitted edits, Git carries them along when it can. If
the target branch has a different version of the same file, Git refuses:

```
error: Your local changes to the following files would be overwritten by checkout:
	app.sh
Please commit your changes or stash them before you switch branches.
```

Commit or stash (Section 9) first.

### Deleting branches

```bash
git branch -d feature/greeting
```

Deleting a branch removes only the label. Commits that are reachable from
another branch (for example, merged into `main`) are untouched.

```knowledge-check
{ "questions": [
  { "id": "git-branch-noff-q2", "type": "mcq",
    "prompt": "git branch -d refuses to delete a branch. What does that usually mean?",
    "options": [
      {"id":"a","text":"The branch has commits not yet merged into the current branch"},
      {"id":"b","text":"The branch is too old"},
      {"id":"c","text":"You must be root"},
      {"id":"d","text":"The repo is read-only"}],
    "correct": "a",
    "explanation": "-d is the safe delete. Use -D only when you are sure the work is disposable. Age, root access and read-only repos are not the reason." }
] }
```

### Detached HEAD in one paragraph

`git switch --detach <commit>` (or `git checkout <hash>`) puts `HEAD` directly
on a commit instead of on a branch. Fine for looking around. If you commit
there, no branch points to the new commits, so they are easy to lose. Before
leaving, save them with `git switch -c rescue-branch`. Section 7 explains why.

## Try it

You are on `main` with no changes. Create a branch `fix/typo` from the commit
two before `main`'s tip, without switching to it.

<details>
<summary>Show answer</summary>

```bash
git branch fix/typo main~2
```

`git branch <name> <start>` creates without switching. `main~2` means "two
commits before main" (Section 7 covers this syntax).

</details>

## Common mistakes

- **Starting work on `main` by accident.** Run `git switch -c feature/x` before
  the first edit. If you already committed, Section 13 shows how to move the
  commits.
- **Reaching for `-D` when `-d` refuses.** Check `git log main..branch` first to
  see what you would orphan.
- **Branch names with spaces.** Use `feature/login-form` style.

## Remember

- Branch = 41-byte pointer file. `HEAD` = which branch you are on.
- `git switch -c` creates, `git switch` moves, `git branch -d` deletes merged ones.
- `git log --oneline --graph --all` shows every branch.
- Deleting a branch deletes only the label.

**Self-check:**

1. What is stored in a branch file?
2. Why does `git branch -d` sometimes refuse?
3. What risk comes with committing on a detached HEAD?
$md$, 8, $json$[{"id":"git-branch-pointer-q1","type":"mcq","correct":"b"},{"id":"git-branch-noff-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('52cae17c-b055-5328-bae9-2f3b5be104f8', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '498e7765-54bf-5ac3-a80c-bab3bb98f650', 'Fast-Forward, Merge Commits, --no-ff and Squash Merges', 'notes', 1, $md$## Why this matters

`git merge` produces different history shapes depending on the situation and
the flags. Teams choose a shape on purpose: a straight line, visible feature
bubbles, or one commit per pull request. You need to predict what a merge will
do before you run it.

## Mental model: catching up vs joining

- **Fast-forward** = catching up. Your branch is simply behind; slide the label
  forward. No new commit.
- **Three-way merge** = joining. Both sides moved; Git makes a new commit with
  **two parents** that ties the lines together.

You always merge **into the branch you are on**: `git switch main` then
`git merge feature`.

## See it work

### Fast-forward

```
BEFORE                                AFTER  git switch main; git merge feature/greeting

 A---B---C  <- main                    A---B---C---D  <- main, feature/greeting
          \
           D  <- feature/greeting
```

```bash
git switch main
git merge feature/greeting
```

Expected output:

```
Updating 5e13a9b..2ab9c40
Fast-forward
 greeting.txt | 1 +
 1 file changed, 1 insertion(+)
```

```knowledge-check
{ "questions": [
  { "id": "git-branch-ff-q1", "type": "mcq",
    "prompt": "When can Git fast-forward a merge?",
    "options": [
      {"id":"a","text":"When both branches have new commits"},
      {"id":"b","text":"When the current branch is an ancestor of the branch being merged"},
      {"id":"c","text":"Only for the main branch"},
      {"id":"d","text":"When there are no files changed"}],
    "correct": "b",
    "explanation": "Nothing diverged, so the pointer simply moves ahead. If both sides have new commits a merge commit is needed; branch names and file counts do not matter." }
] }
```

### Three-way merge commit

Now `main` has `D` while `feature/cart` still starts from `C`. Git compares
three snapshots: the **merge base** (common ancestor `C`), your tip and their
tip.

```
BEFORE                                  AFTER  git merge feature/cart

 A---B---C---D  <- main                  A---B---C---D---M  <- main
          \                                       \     /
           E---F  <- feature/cart                  E---F  <- feature/cart
```

```bash
git merge feature/cart -m "Merge feature/cart"
git log --oneline --graph
```

Expected output:

```
*   e5a1d77 (HEAD -> main) Merge feature/cart
|\
| * 77d1e0a (feature/cart) Add cart totals
| * 0c4f8e2 Add cart file
* | 2ab9c40 Add greeting
|/
* 5e13a9b Add checkout
```

`M^1` (first parent) is the branch you were on; `M^2` is the branch you merged.

```knowledge-check
{ "questions": [
  { "id": "git-branch-merge-q1", "type": "mcq",
    "prompt": "How many parents does a normal merge commit have?",
    "options": [
      {"id":"a","text":"One"},
      {"id":"b","text":"Two"},
      {"id":"c","text":"Three"},
      {"id":"d","text":"None"}],
    "correct": "b",
    "explanation": "One parent per merged line of history: the target branch and the merged-in branch. Only the root commit has none, normal commits have one, and three or more happens only with rare octopus merges." }
] }
```

### Choosing the shape

```
 without --no-ff (fast-forward)         with --no-ff

 A---B---C---F  <- main                  A---B---C-------M  <- main
 (feature commits look like main's)               \     /
                                                   F---G  <- feature/footer
```

| Command | Result | Typical use |
|---|---|---|
| `git merge X` | Fast-forward if possible, else merge commit | Default |
| `git merge --no-ff X` | Always a merge commit | Keep each feature as one visible unit you can revert |
| `git merge --ff-only X` | Fast-forward or refuse | Updating local main from origin/main safely |
| `git merge --squash X` + `git commit` | One ordinary commit with all X's changes; X's commits are not linked | One clean commit per pull request |

Hosting services offer the same choices as buttons: "Create a merge commit",
"Squash and merge", "Rebase and merge".

```knowledge-check
{ "questions": [
  { "id": "git-branch-noff-q1", "type": "mcq",
    "prompt": "Why use git merge --no-ff?",
    "options": [
      {"id":"a","text":"It is faster"},
      {"id":"b","text":"It records a merge commit so the feature branch stays visible in history even when a fast-forward was possible"},
      {"id":"c","text":"It deletes the feature branch"},
      {"id":"d","text":"It rewrites commit hashes"}],
    "correct": "b",
    "explanation": "The merge commit groups the branch's commits and gives you one commit to revert later. It is not faster, deletes nothing, and leaves existing hashes alone." }
] }
```

## Try it

You want to update your local `main` from `origin/main`, but if you have
accidentally committed on `main` you want Git to stop rather than create a
merge commit. Which command?

<details>
<summary>Show answer</summary>

```bash
git merge --ff-only origin/main
```

or `git pull --ff-only`. If `main` has diverged it fails with
`fatal: Not possible to fast-forward, aborting.`, and nothing changes.

</details>

## Common mistakes

- **Merging in the wrong direction.** `git merge main` while on `feature`
  brings main into feature, not the other way round. Check `git branch` first.
- **Expecting `--squash` to delete or merge the branch.** It only stages the
  combined changes; you still commit, and Git does not record the branch as
  merged, so `git branch -d` will refuse afterwards (use `-D`).
- **Forgetting the merge base.** A three-way merge compares against the common
  ancestor, not just the two tips. That is why unchanged-on-one-side edits merge
  cleanly.

## Remember

- Merge into the branch you are on.
- Fast-forward = slide the label; merge commit = two parents.
- `--no-ff` always records a merge, `--ff-only` refuses to, `--squash` makes one plain commit.
- `M^1` = your side, `M^2` = merged side.

**Self-check:**

1. What is the merge base?
2. Which flag guarantees no merge commit is created?
3. What is the difference between `--no-ff` and `--squash`?
$md$, 9, $json$[{"id":"git-branch-ff-q1","type":"mcq","correct":"b"},{"id":"git-branch-merge-q1","type":"mcq","correct":"b"},{"id":"git-branch-noff-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e7308f90-9b11-586e-a880-349ba6e409b0', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '498e7765-54bf-5ac3-a80c-bab3bb98f650', 'Lab: Branch, Fast-Forward and Merge', 'notes', 2, $md$## Why this matters

The `~/work/shop` repository has `main` (three commits) and `feature/cart`
(two commits started from `main`). You will create a branch, fast-forward,
make a true merge, force a merge commit with `--no-ff`, and clean up.

Start by looking:

```bash
cd ~/work/shop
git log --oneline --graph --all
```

## Task 1: branch and commit

Create `feature/greeting` from `main`, add `greeting.txt`, commit it as
`Add greeting`. `main` must not move.

[[lab-task:1]]

Expected graph:

```
* 2ab9c40 (HEAD -> feature/greeting) Add greeting
| * 77d1e0a (feature/cart) Add cart totals
| * 0c4f8e2 Add cart file
|/
* 5e13a9b (main) Add checkout
```

## Task 2: fast-forward

Switch to `main` and merge `feature/greeting`. `main` has not moved, so this is
a fast-forward.

[[lab-task:2]]

Expected output contains `Fast-forward`.

## Task 3: a real merge

`feature/cart` started before the greeting commit, so history has diverged.
Merge it into `main` with the message `Merge feature/cart`.

[[lab-task:3]]

Expected graph:

```
*   e5a1d77 (HEAD -> main) Merge feature/cart
|\
| * 77d1e0a (feature/cart) Add cart totals
| * 0c4f8e2 Add cart file
* | 2ab9c40 (feature/greeting) Add greeting
|/
* 5e13a9b Add checkout
```

## Task 4: --no-ff

Create `feature/footer` from `main` with one commit `Add footer`
(`footer.txt`). Merge it into `main` with `--no-ff` and the message
`Merge feature/footer`, even though a fast-forward was possible.

[[lab-task:4]]

Expected `git log --oneline --graph -4`:

```
*   a41c0be (HEAD -> main) Merge feature/footer
|\
| * 3f9d812 (feature/footer) Add footer
|/
*   e5a1d77 Merge feature/cart
```

## Task 5: clean up

Delete the three merged feature branches. Only `main` remains; every commit
stays in history.

[[lab-task:5]]

Expected `git branch`:

```
* main
```

## Remember

- Look at the graph before and after each merge.
- `-d` deletes only merged branches; that is your safety net.
$md$, 30, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('e94f6752-6fb4-5825-8c8b-d36ed06f5eb5', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'e7308f90-9b11-586e-a880-349ba6e409b0', 'module', 'Lab: Branch, Fast-Forward and Merge', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
rm -rf /home/labuser/work/shop
mkdir /home/labuser/work/shop && cd /home/labuser/work/shop
git init -q
M() { git add -A; GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
echo "# Shop" > README.md; M 2024-02-01 "Initial commit"
echo "apple" > products.txt; M 2024-02-02 "Add product list"
echo "pay" > checkout.txt; M 2024-02-03 "Add checkout"
git switch -q -c feature/cart
echo "cart" > cart.txt; M 2024-02-04 "Add cart file"
echo "cart total" >> cart.txt; M 2024-02-05 "Add cart totals"
git switch -q main
chmod -R a+rwX /home/labuser/work/shop
$script$, NULL, 40, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'e9c7b17a-351a-50d3-8f53-c4a2043f4bbd' AND id NOT IN ('33a6b153-cb50-543b-b137-44bda4ac1ae5', '2670c84b-dcd1-5621-878f-bc8d4a7ac7eb', 'd09e0200-7ca0-5a42-a05d-3f2e7ffb8bc2', '1865df4d-fd4d-5127-8904-f843e9c28de2', '27cf451a-cff1-5eb3-897e-abdb69302236');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'e9c7b17a-351a-50d3-8f53-c4a2043f4bbd';
DELETE FROM lab_tasks WHERE lab_id = 'e94f6752-6fb4-5825-8c8b-d36ed06f5eb5' AND id NOT IN ('f1bccdba-5d8c-52c4-b2c6-7bc5dd0cbb3b', 'aa5746e6-5b7a-593a-8cd0-1a712b5f8168', '051a5b6b-0131-512a-b8b2-463d5e121761', 'acfc22f5-a700-5342-93cb-8821faa43e3c', '925c7cc5-8db0-5c30-aa1e-d6a57673822b');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'e94f6752-6fb4-5825-8c8b-d36ed06f5eb5';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('f1bccdba-5d8c-52c4-b2c6-7bc5dd0cbb3b', 'e94f6752-6fb4-5825-8c8b-d36ed06f5eb5', 1, 'Create a branch and commit on it', $md$In ~/work/shop create a branch feature/greeting from main, add greeting.txt and commit it with the message "Add greeting". main must stay untouched.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r log feature/greeting -1 --format=%s)" = "Add greeting" ] &&
[ "$(git -C $r rev-list --count main)" = 3 ] &&
[ "$(git -C $r rev-list --count main..feature/greeting)" = 1 ]
$script$, 'git switch -c feature/greeting creates and switches in one step. Check git branch afterwards.', 'A branch is only a movable pointer to a commit. Creating one is instant; committing moves just the pointer of the branch you are on.', 15, false, true),
('aa5746e6-5b7a-593a-8cd0-1a712b5f8168', 'e94f6752-6fb4-5825-8c8b-d36ed06f5eb5', 2, 'Fast-forward main', $md$Switch back to main and merge feature/greeting. Because main has not moved, Git should fast-forward without creating a merge commit.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ] &&
[ "$(git -C $r rev-parse main)" = "$(git -C $r rev-parse feature/greeting)" ] &&
[ "$(git -C $r rev-list --merges --count main)" = 0 ] &&
[ "$(git -C $r rev-list --count main)" = 4 ]
$script$, 'Merge into the branch you are standing on. git switch main first, then git merge feature/greeting.', 'When the target branch is an ancestor of the branch being merged, Git just moves the pointer forward. No new commit is needed.', 15, false, true),
('051a5b6b-0131-512a-b8b2-463d5e121761', 'e94f6752-6fb4-5825-8c8b-d36ed06f5eb5', 3, 'Merge diverged work', $md$feature/cart was started before the greeting commit, so history has diverged. Merge it into main with the merge-commit message "Merge feature/cart".$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ] &&
[ "$(git -C $r log -1 --format=%s)" = "Merge feature/cart" ] &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
git -C $r merge-base --is-ancestor feature/cart HEAD &&
git -C $r merge-base --is-ancestor feature/greeting HEAD &&
[ -f $r/cart.txt ] && [ -f $r/greeting.txt ]
$script$, 'git merge feature/cart -m "Merge feature/cart" - a three-way merge since both sides have new commits.', 'With work on both sides, Git finds the common ancestor and creates a merge commit with two parents. Both lines of history are preserved.', 20, false, true),
('acfc22f5-a700-5342-93cb-8821faa43e3c', 'e94f6752-6fb4-5825-8c8b-d36ed06f5eb5', 4, 'Force a merge commit with --no-ff', $md$Create branch feature/footer from main with one commit "Add footer" (file footer.txt). Switch to main and merge it using --no-ff with the message "Merge feature/footer", even though a fast-forward was possible.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r log -1 --format=%s)" = "Merge feature/footer" ] &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
[ "$(git -C $r log HEAD^2 -1 --format=%s)" = "Add footer" ] &&
[ "$(git -C $r log HEAD^1 -1 --format=%s)" = "Merge feature/cart" ]
$script$, 'Branch, commit, switch back to main, then git merge --no-ff feature/footer -m "...". HEAD^1 is the main side, HEAD^2 the merged branch.', '--no-ff always records a merge commit, so the history still shows that a group of commits belonged to one feature branch.', 20, false, true),
('925c7cc5-8db0-5c30-aa1e-d6a57673822b', 'e94f6752-6fb4-5825-8c8b-d36ed06f5eb5', 5, 'Clean up merged branches', $md$Delete the three merged feature branches (feature/greeting, feature/cart, feature/footer) so only main remains. The commits stay in history.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r for-each-ref --format='%(refname:short)' refs/heads)" = main ] &&
git -C $r log --format=%s | grep -qx "Add footer" &&
git -C $r log --format=%s | grep -qx "Add cart totals"
$script$, 'git branch -d refuses to delete unmerged branches - that is a safety net. You can pass several names.', 'Deleting a branch removes only the pointer. Because the commits are reachable from main they are never lost.', 10, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('e9c7b17a-351a-50d3-8f53-c4a2043f4bbd', 'e94f6752-6fb4-5825-8c8b-d36ed06f5eb5', 1, $json$[{"id":"f1bccdba-5d8c-52c4-b2c6-7bc5dd0cbb3b","lab_id":"e94f6752-6fb4-5825-8c8b-d36ed06f5eb5","position":1,"title":"Create a branch and commit on it","description":"In ~/work/shop create a branch feature/greeting from main, add greeting.txt and commit it with the message \"Add greeting\". main must stay untouched.","verification_script":"r=/home/labuser/work/shop\n[ \"$(git -C $r log feature/greeting -1 --format=%s)\" = \"Add greeting\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --count main)\" = 3 ] \u0026\u0026\n[ \"$(git -C $r rev-list --count main..feature/greeting)\" = 1 ]\n","hint_context":"git switch -c feature/greeting creates and switches in one step. Check git branch afterwards.","explanation_context":"A branch is only a movable pointer to a commit. Creating one is instant; committing moves just the pointer of the branch you are on.","points":15,"is_optional":false,"is_stateful":true},{"id":"aa5746e6-5b7a-593a-8cd0-1a712b5f8168","lab_id":"e94f6752-6fb4-5825-8c8b-d36ed06f5eb5","position":2,"title":"Fast-forward main","description":"Switch back to main and merge feature/greeting. Because main has not moved, Git should fast-forward without creating a merge commit.","verification_script":"r=/home/labuser/work/shop\n[ \"$(git -C $r rev-parse --abbrev-ref HEAD)\" = main ] \u0026\u0026\n[ \"$(git -C $r rev-parse main)\" = \"$(git -C $r rev-parse feature/greeting)\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --merges --count main)\" = 0 ] \u0026\u0026\n[ \"$(git -C $r rev-list --count main)\" = 4 ]\n","hint_context":"Merge into the branch you are standing on. git switch main first, then git merge feature/greeting.","explanation_context":"When the target branch is an ancestor of the branch being merged, Git just moves the pointer forward. No new commit is needed.","points":15,"is_optional":false,"is_stateful":true},{"id":"051a5b6b-0131-512a-b8b2-463d5e121761","lab_id":"e94f6752-6fb4-5825-8c8b-d36ed06f5eb5","position":3,"title":"Merge diverged work","description":"feature/cart was started before the greeting commit, so history has diverged. Merge it into main with the merge-commit message \"Merge feature/cart\".","verification_script":"r=/home/labuser/work/shop\n[ \"$(git -C $r rev-parse --abbrev-ref HEAD)\" = main ] \u0026\u0026\n[ \"$(git -C $r log -1 --format=%s)\" = \"Merge feature/cart\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --parents -n 1 HEAD | wc -w)\" = 3 ] \u0026\u0026\ngit -C $r merge-base --is-ancestor feature/cart HEAD \u0026\u0026\ngit -C $r merge-base --is-ancestor feature/greeting HEAD \u0026\u0026\n[ -f $r/cart.txt ] \u0026\u0026 [ -f $r/greeting.txt ]\n","hint_context":"git merge feature/cart -m \"Merge feature/cart\" - a three-way merge since both sides have new commits.","explanation_context":"With work on both sides, Git finds the common ancestor and creates a merge commit with two parents. Both lines of history are preserved.","points":20,"is_optional":false,"is_stateful":true},{"id":"acfc22f5-a700-5342-93cb-8821faa43e3c","lab_id":"e94f6752-6fb4-5825-8c8b-d36ed06f5eb5","position":4,"title":"Force a merge commit with --no-ff","description":"Create branch feature/footer from main with one commit \"Add footer\" (file footer.txt). Switch to main and merge it using --no-ff with the message \"Merge feature/footer\", even though a fast-forward was possible.","verification_script":"r=/home/labuser/work/shop\n[ \"$(git -C $r log -1 --format=%s)\" = \"Merge feature/footer\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --parents -n 1 HEAD | wc -w)\" = 3 ] \u0026\u0026\n[ \"$(git -C $r log HEAD^2 -1 --format=%s)\" = \"Add footer\" ] \u0026\u0026\n[ \"$(git -C $r log HEAD^1 -1 --format=%s)\" = \"Merge feature/cart\" ]\n","hint_context":"Branch, commit, switch back to main, then git merge --no-ff feature/footer -m \"...\". HEAD^1 is the main side, HEAD^2 the merged branch.","explanation_context":"--no-ff always records a merge commit, so the history still shows that a group of commits belonged to one feature branch.","points":20,"is_optional":false,"is_stateful":true},{"id":"925c7cc5-8db0-5c30-aa1e-d6a57673822b","lab_id":"e94f6752-6fb4-5825-8c8b-d36ed06f5eb5","position":5,"title":"Clean up merged branches","description":"Delete the three merged feature branches (feature/greeting, feature/cart, feature/footer) so only main remains. The commits stay in history.","verification_script":"r=/home/labuser/work/shop\n[ \"$(git -C $r for-each-ref --format='%(refname:short)' refs/heads)\" = main ] \u0026\u0026\ngit -C $r log --format=%s | grep -qx \"Add footer\" \u0026\u0026\ngit -C $r log --format=%s | grep -qx \"Add cart totals\"\n","hint_context":"git branch -d refuses to delete unmerged branches - that is a safety net. You can pass several names.","explanation_context":"Deleting a branch removes only the pointer. Because the commits are reachable from main they are never lost.","points":10,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('33a6b153-cb50-543b-b137-44bda4ac1ae5', 'e9c7b17a-351a-50d3-8f53-c4a2043f4bbd', 'f1bccdba-5d8c-52c4-b2c6-7bc5dd0cbb3b', 1, 'Create a branch and commit on it', $md$In ~/work/shop create a branch feature/greeting from main, add greeting.txt and commit it with the message "Add greeting". main must stay untouched.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r log feature/greeting -1 --format=%s)" = "Add greeting" ] &&
[ "$(git -C $r rev-list --count main)" = 3 ] &&
[ "$(git -C $r rev-list --count main..feature/greeting)" = 1 ]
$script$, 'git switch -c feature/greeting creates and switches in one step. Check git branch afterwards.', 'A branch is only a movable pointer to a commit. Creating one is instant; committing moves just the pointer of the branch you are on.', 15, false, true),
('2670c84b-dcd1-5621-878f-bc8d4a7ac7eb', 'e9c7b17a-351a-50d3-8f53-c4a2043f4bbd', 'aa5746e6-5b7a-593a-8cd0-1a712b5f8168', 2, 'Fast-forward main', $md$Switch back to main and merge feature/greeting. Because main has not moved, Git should fast-forward without creating a merge commit.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ] &&
[ "$(git -C $r rev-parse main)" = "$(git -C $r rev-parse feature/greeting)" ] &&
[ "$(git -C $r rev-list --merges --count main)" = 0 ] &&
[ "$(git -C $r rev-list --count main)" = 4 ]
$script$, 'Merge into the branch you are standing on. git switch main first, then git merge feature/greeting.', 'When the target branch is an ancestor of the branch being merged, Git just moves the pointer forward. No new commit is needed.', 15, false, true),
('d09e0200-7ca0-5a42-a05d-3f2e7ffb8bc2', 'e9c7b17a-351a-50d3-8f53-c4a2043f4bbd', '051a5b6b-0131-512a-b8b2-463d5e121761', 3, 'Merge diverged work', $md$feature/cart was started before the greeting commit, so history has diverged. Merge it into main with the merge-commit message "Merge feature/cart".$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ] &&
[ "$(git -C $r log -1 --format=%s)" = "Merge feature/cart" ] &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
git -C $r merge-base --is-ancestor feature/cart HEAD &&
git -C $r merge-base --is-ancestor feature/greeting HEAD &&
[ -f $r/cart.txt ] && [ -f $r/greeting.txt ]
$script$, 'git merge feature/cart -m "Merge feature/cart" - a three-way merge since both sides have new commits.', 'With work on both sides, Git finds the common ancestor and creates a merge commit with two parents. Both lines of history are preserved.', 20, false, true),
('1865df4d-fd4d-5127-8904-f843e9c28de2', 'e9c7b17a-351a-50d3-8f53-c4a2043f4bbd', 'acfc22f5-a700-5342-93cb-8821faa43e3c', 4, 'Force a merge commit with --no-ff', $md$Create branch feature/footer from main with one commit "Add footer" (file footer.txt). Switch to main and merge it using --no-ff with the message "Merge feature/footer", even though a fast-forward was possible.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r log -1 --format=%s)" = "Merge feature/footer" ] &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
[ "$(git -C $r log HEAD^2 -1 --format=%s)" = "Add footer" ] &&
[ "$(git -C $r log HEAD^1 -1 --format=%s)" = "Merge feature/cart" ]
$script$, 'Branch, commit, switch back to main, then git merge --no-ff feature/footer -m "...". HEAD^1 is the main side, HEAD^2 the merged branch.', '--no-ff always records a merge commit, so the history still shows that a group of commits belonged to one feature branch.', 20, false, true),
('27cf451a-cff1-5eb3-897e-abdb69302236', 'e9c7b17a-351a-50d3-8f53-c4a2043f4bbd', '925c7cc5-8db0-5c30-aa1e-d6a57673822b', 5, 'Clean up merged branches', $md$Delete the three merged feature branches (feature/greeting, feature/cart, feature/footer) so only main remains. The commits stay in history.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r for-each-ref --format='%(refname:short)' refs/heads)" = main ] &&
git -C $r log --format=%s | grep -qx "Add footer" &&
git -C $r log --format=%s | grep -qx "Add cart totals"
$script$, 'git branch -d refuses to delete unmerged branches - that is a safety net. You can pass several names.', 'Deleting a branch removes only the pointer. Because the commits are reachable from main they are never lost.', 10, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'e9c7b17a-351a-50d3-8f53-c4a2043f4bbd', updated_at = now()
WHERE id = 'e94f6752-6fb4-5825-8c8b-d36ed06f5eb5' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ef1e87a9-3645-5dba-b0e8-0bf5bf09a5a4', '00000000-0000-0000-0000-000000000001', 'mcq', 'You are on main. You run `git merge feature`. main has had no new commits sin...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('69afba00-09b6-5a3b-ab06-74e5c0e05c1b', 'ef1e87a9-3645-5dba-b0e8-0bf5bf09a5a4', 1, $json${"prompt":"You are on main. You run `git merge feature`. main has had no new commits since feature was created. What happens?","multiple":false,"options":[{"id":"a","text":"A merge commit with two parents is created","is_correct":false},{"id":"b","text":"main's label slides forward to feature's tip (fast-forward); no new commit","is_correct":true},{"id":"c","text":"feature is moved to main","is_correct":false},{"id":"d","text":"Git refuses because nothing diverged","is_correct":false}],"explanation":"main is an ancestor of feature, so Git fast-forwards. A merge commit appears only with --no-ff or when both sides moved. The branch you merge from never moves, and Git does not refuse a fast-forward."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b2bc7820-914b-53d7-9f1c-c274ebce1cc1', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your team wants every pull request to show up as one revertable unit in main,...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('745d5135-5b5c-5e0f-af3d-ec158c4a2a7e', 'b2bc7820-914b-53d7-9f1c-c274ebce1cc1', 1, $json${"prompt":"Your team wants every pull request to show up as one revertable unit in main, while keeping the individual commits. Which merge style fits?","multiple":false,"options":[{"id":"a","text":"git merge --ff-only","is_correct":false},{"id":"b","text":"git merge --no-ff","is_correct":true},{"id":"c","text":"git merge --squash","is_correct":false},{"id":"d","text":"Rebase and fast-forward","is_correct":false}],"explanation":"--no-ff always records a merge commit grouping the branch's commits; revert that one commit to undo the feature. --ff-only and rebase+ff leave no grouping commit, and --squash keeps the unit but throws away the individual commits."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8b4f99af-c4af-54ef-8016-60a985aa9997', '00000000-0000-0000-0000-000000000001', 'mcq', 'After `git merge --squash feature && git commit`, `git branch -d feature` ref...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('88ed51f5-eb25-5775-9d1a-837bcef40ef9', '8b4f99af-c4af-54ef-8016-60a985aa9997', 1, $json${"prompt":"After `git merge --squash feature \u0026\u0026 git commit`, `git branch -d feature` refuses. Why?","multiple":false,"options":[{"id":"a","text":"Squash merges are not real merges: the new commit has one parent, so Git does not see feature's commits as merged","is_correct":true},{"id":"b","text":"You must push first","is_correct":false},{"id":"c","text":"-d only works on remote branches","is_correct":false},{"id":"d","text":"The squash failed silently","is_correct":false}],"explanation":"Squash copies the changes into a single ordinary commit. feature's commits are not ancestors of main, so -d's safety check fails. Use -D once you are sure. Pushing is irrelevant, -d is for local branches, and the squash worked."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('487785c9-f2fb-5829-b79f-4baa4b16baff', '00000000-0000-0000-0000-000000000001', 'mcq', 'You try to switch branches and get ''Your local changes to the following files...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('da8bdfdf-f31d-5bf7-bfa1-8b8ff003b1b2', '487785c9-f2fb-5829-b79f-4baa4b16baff', 1, $json${"prompt":"You try to switch branches and get 'Your local changes to the following files would be overwritten'. What is the safe next step?","multiple":false,"options":[{"id":"a","text":"git switch --force","is_correct":false},{"id":"b","text":"Commit or stash your changes, then switch","is_correct":true},{"id":"c","text":"Delete the other branch","is_correct":false},{"id":"d","text":"git reset --hard","is_correct":false}],"explanation":"Git refuses to destroy uncommitted edits. Commit or stash keeps them. --force and reset --hard throw your edits away, and deleting the branch loses its commits' label."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('de548796-af53-57e2-a132-7f363b059ef7', '00000000-0000-0000-0000-000000000001', 'mcq', 'M is a merge commit made on main from feature. What are M^1 and M^2?', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e7b5433e-9d8a-5b82-98ea-2725dd29f1af', 'de548796-af53-57e2-a132-7f363b059ef7', 1, $json${"prompt":"M is a merge commit made on main from feature. What are M^1 and M^2?","multiple":false,"options":[{"id":"a","text":"M^1 is the previous main tip; M^2 is the feature tip","is_correct":true},{"id":"b","text":"M^1 is the feature tip; M^2 is the previous main tip","is_correct":false},{"id":"c","text":"M^1 and M^2 are the two commits before M on main","is_correct":false},{"id":"d","text":"They are the same commit","is_correct":false}],"explanation":"The first parent is the branch you were on when merging; the second parent is the branch you merged in. Two commits back on main would be M~2."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('414b916f-bd7b-5ee2-ad65-be12fca9b710', '00000000-0000-0000-0000-000000000001', 'mcq', 'You delete a merged feature branch with git branch -d. What happens to its co...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('41eb2d62-4915-56e3-835c-ceb58bc75d5e', '414b916f-bd7b-5ee2-ad65-be12fca9b710', 1, $json${"prompt":"You delete a merged feature branch with git branch -d. What happens to its commits?","multiple":false,"options":[{"id":"a","text":"They are deleted","is_correct":false},{"id":"b","text":"Nothing; they are still reachable from main because they were merged","is_correct":true},{"id":"c","text":"They are moved into main as new commits","is_correct":false},{"id":"d","text":"They become a tag","is_correct":false}],"explanation":"A branch is only a label. Merged commits are part of main's history, so deleting the label loses nothing. Nothing is copied or turned into a tag."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('85794069-ff2b-51cf-b9fc-76ab9acbf9ab', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 4): you want to update local main from origin/main and be sur...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bcec48dd-9997-5266-9be0-07764bca2f17', '85794069-ff2b-51cf-b9fc-76ab9acbf9ab', 1, $json${"prompt":"Review (Section 4): you want to update local main from origin/main and be sure no merge commit is ever created by accident. Which command?","multiple":false,"options":[{"id":"a","text":"git pull --ff-only","is_correct":true},{"id":"b","text":"git pull --no-rebase","is_correct":false},{"id":"c","text":"git fetch --all","is_correct":false},{"id":"d","text":"git push --force","is_correct":false}],"explanation":"--ff-only refuses if a fast-forward is not possible. pull --no-rebase may create a merge commit, fetch alone does not update main, and push --force sends your branch the wrong way."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('58ed9918-8309-5c1d-8c44-5fcd107e43b3', '00000000-0000-0000-0000-000000000001', 'Quiz: Branching and Merging', 'git-branch-merge-quiz', 'Quiz covering Branching and Merging.', 'mcq', 'published', 'module', 'cb571aa7-e3b5-5f39-a2cc-dfcb18bf5ce4', 12, 70, 5, 14, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '58ed9918-8309-5c1d-8c44-5fcd107e43b3' AND question_id NOT IN ('ef1e87a9-3645-5dba-b0e8-0bf5bf09a5a4', 'b2bc7820-914b-53d7-9f1c-c274ebce1cc1', '8b4f99af-c4af-54ef-8016-60a985aa9997', '487785c9-f2fb-5829-b79f-4baa4b16baff', 'de548796-af53-57e2-a132-7f363b059ef7', '414b916f-bd7b-5ee2-ad65-be12fca9b710', '85794069-ff2b-51cf-b9fc-76ab9acbf9ab');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('dbe82385-87c9-571c-a559-ae94fd8743dd', '58ed9918-8309-5c1d-8c44-5fcd107e43b3', 'ef1e87a9-3645-5dba-b0e8-0bf5bf09a5a4', '69afba00-09b6-5a3b-ab06-74e5c0e05c1b', 0, 2),
('04c06488-1b6a-5288-a239-ba6d712cd15b', '58ed9918-8309-5c1d-8c44-5fcd107e43b3', 'b2bc7820-914b-53d7-9f1c-c274ebce1cc1', '745d5135-5b5c-5e0f-af3d-ec158c4a2a7e', 1, 2),
('1891e51a-8849-5df1-9f6f-af5eb57bee44', '58ed9918-8309-5c1d-8c44-5fcd107e43b3', '8b4f99af-c4af-54ef-8016-60a985aa9997', '88ed51f5-eb25-5775-9d1a-837bcef40ef9', 2, 2),
('5ea2b38e-c0e9-5c92-b61d-cf75298284a0', '58ed9918-8309-5c1d-8c44-5fcd107e43b3', '487785c9-f2fb-5829-b79f-4baa4b16baff', 'da8bdfdf-f31d-5bf7-bfa1-8b8ff003b1b2', 3, 2),
('fc6f6f4a-49d0-5848-8559-4fac435f289a', '58ed9918-8309-5c1d-8c44-5fcd107e43b3', 'de548796-af53-57e2-a132-7f363b059ef7', 'e7b5433e-9d8a-5b82-98ea-2725dd29f1af', 4, 2),
('132574d6-a8a4-5881-9162-a35bc2296d2a', '58ed9918-8309-5c1d-8c44-5fcd107e43b3', '414b916f-bd7b-5ee2-ad65-be12fca9b710', '41eb2d62-4915-56e3-835c-ceb58bc75d5e', 5, 2),
('c7bc7700-25d8-5d3d-931a-8e993411dd70', '58ed9918-8309-5c1d-8c44-5fcd107e43b3', '85794069-ff2b-51cf-b9fc-76ab9acbf9ab', 'bcec48dd-9997-5266-9be0-07764bca2f17', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('cb571aa7-e3b5-5f39-a2cc-dfcb18bf5ce4', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '498e7765-54bf-5ac3-a80c-bab3bb98f650', 'Quiz: Branching and Merging', 'assessment', 3, 10, '58ed9918-8309-5c1d-8c44-5fcd107e43b3')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Merge Conflicts
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('0bfdc51c-0996-5a60-beac-0ac183d3389c', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Merge Conflicts', 6, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1db9f751-9cff-5192-b741-bc7fb7400c76', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0bfdc51c-0996-5a60-beac-0ac183d3389c', 'Why Conflicts Happen and How to Read Them', 'notes', 0, $md$## Why this matters

Git stops and prints `CONFLICT`. Most beginners panic here. A conflict is not an
error and nothing is broken: it is Git asking a question it cannot answer
alone. Once you can read the markers, answering takes a minute.

## Mental model: two editors, one sentence

Git merges by comparing each side with their **common ancestor** (the merge
base):

- Only one side changed a line? Take that change. No question.
- Both sides changed the **same lines** differently? Git cannot know which one
  you want, so it asks.

```
 ancestor:  timeout=30
 main    :  timeout=60        both changed the same line
 feature :  timeout=45        ->  CONFLICT
```

Like two editors rewriting the same sentence of a book: the publisher has to
pick, or write a third version.

```knowledge-check
{ "questions": [
  { "id": "git-conflict-why-q1", "type": "mcq",
    "prompt": "When does Git report a merge conflict?",
    "options": [
      {"id":"a","text":"Whenever two branches exist"},
      {"id":"b","text":"When both branches changed the same lines in different ways since the common ancestor"},
      {"id":"c","text":"When a branch is older than a week"},
      {"id":"d","text":"When a file is larger than 1 MB"}],
    "correct": "b",
    "explanation": "If only one side changed a region, Git takes that change automatically. Branch count, age and file size do not cause conflicts." }
] }
```

## See it work

### Trigger and inspect

```bash
git switch main
git merge feature/timeout
```

Expected output:

```
Auto-merging app.conf
CONFLICT (content): Merge conflict in app.conf
Automatic merge failed; fix conflicts and then commit the result.
```

```bash
git status
```

```
On branch main
You have unmerged paths.
  (fix conflicts and run "git commit")
  (use "git merge --abort" to abort the merge)

Unmerged paths:
  (use "git add <file>..." to mark resolution)
	both modified:   app.conf
```

Status tells you you are **in the middle of a merge** and lists the files to fix.

### Read the markers

```bash
cat app.conf
```

```
name=app
<<<<<<< HEAD
timeout=60
=======
timeout=45
>>>>>>> feature/timeout
log=info
retries=3
```

| Marker | Meaning |
|---|---|
| `<<<<<<< HEAD` | Start of **your** side (the branch you are on, "ours") |
| `=======` | Divider |
| `>>>>>>> feature/timeout` | End of **their** side (the branch being merged, "theirs") |

Notice `retries=3` sits outside the markers. Only the feature branch added it,
so Git took it automatically. Only the truly contested lines are marked.

```
 DURING the merge
   A---B---C  <- main <- HEAD         .git/MERGE_HEAD -> feature/timeout tip
        \
         D  <- feature/timeout
   index holds 3 versions of app.conf (ancestor / ours / theirs) = "unmerged"
```

```knowledge-check
{ "questions": [
  { "id": "git-conflict-markers-q1", "type": "mcq",
    "prompt": "In a conflict block, what sits between <<<<<<< HEAD and =======?",
    "options": [
      {"id":"a","text":"The incoming branch's version"},
      {"id":"b","text":"The version from the branch you are currently on"},
      {"id":"c","text":"The common ancestor"},
      {"id":"d","text":"A summary written by Git"}],
    "correct": "b",
    "explanation": "HEAD is your current branch (ours); below ======= is theirs. The ancestor is only shown with the diff3/zdiff3 style, and Git writes no summary." }
] }
```

### See the ancestor too (recommended setting)

```bash
git config --global merge.conflictStyle zdiff3
```

Now conflicts also show the original text between `|||||||` and `=======`:

```
<<<<<<< HEAD
timeout=60
||||||| 8c1f7b3
timeout=30
=======
timeout=45
>>>>>>> feature/timeout
```

Knowing it **was** 30 tells you both sides raised it, which helps you decide.
`zdiff3` needs Git 2.35+; older versions have `diff3`.

## Try it

A conflict block shows `<<<<<<< HEAD`, then `color=blue`, then `=======`, then
`color=green`, then `>>>>>>> redesign`. You are on `main`. Which branch wanted
green?

<details>
<summary>Show answer</summary>

`redesign`. The bottom half (after `=======`) is the branch named after
`>>>>>>>`, the one you are merging in. `main` (HEAD) wanted blue.

</details>

## Common mistakes

- **Thinking the whole file conflicted.** Only marked blocks need you; the rest
  merged automatically.
- **Mixing up ours and theirs.** In a merge, ours = HEAD = the branch you are
  on. (During a rebase it flips; Section 8.)
- **Committing with markers still in the file.** Git does not stop you if you
  `git add` a file with markers. Search for them first.

## Remember

- Conflict = both sides changed the same lines since the merge base.
- `git status` lists "both modified" files and says you are mid-merge.
- Above `=======` = ours (HEAD). Below = theirs (the merged branch).
- Set `merge.conflictStyle zdiff3` to also see the ancestor.

**Self-check:**

1. Which three versions does Git compare during a merge?
2. What does "both modified" mean in status?
3. What extra information does `zdiff3` show?
$md$, 8, $json$[{"id":"git-conflict-why-q1","type":"mcq","correct":"b"},{"id":"git-conflict-markers-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('cfc858d6-1d98-5314-bc5c-48de47f625c1', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0bfdc51c-0996-5a60-beac-0ac183d3389c', 'Resolving, Completing and Aborting a Merge', 'notes', 1, $md$## Why this matters

Reading a conflict is half the job. Now answer it: decide the final text, tell
Git you are done, and finish the merge. Equally important: know how to back out
cleanly when the merge is not worth doing right now.

## Mental model: fill in the form, stamp it, file it

1. **Edit** - make the file look exactly how it should end up. Delete all
   markers.
2. **Stamp** - `git add <file>` marks that file resolved.
3. **File** - `git commit` creates the merge commit.

```
 resolve         git add app.conf      git commit
 (edit file) --> (conflict cleared) --> merge commit M (parents: main tip, feature tip)

   A---B---C---M  <- main
        \     /
         D---+   <- feature/timeout
```

Resolution is **your decision**, not picking a side by habit. Often the right
answer combines both (keep main's `timeout=60` *and* feature's `retries=3`).

## See it work

### Resolve by editing

```bash
nano app.conf          # make it: name=app / timeout=60 / log=info / retries=3
git add app.conf
git status
```

Expected status:

```
On branch main
All conflicts fixed but you are still merging.
  (use "git commit" to conclude merge)
```

```bash
git commit --no-edit      # keep the default "Merge branch 'feature/timeout'" message
git log --oneline --graph
```

Expected output:

```
*   6be1f20 (HEAD -> main) Merge branch 'feature/timeout'
|\
| * c2a9d41 (feature/timeout) Raise timeout to 45 and add retries
* | 14e8b07 Raise timeout to 60
|/
* a70d3e5 Initial config
```

Without `--no-edit`, Git opens the editor with that message pre-filled; save
and close.

### Before committing: no markers left

```bash
git diff --check                        # warns about leftover markers in unstaged changes
git grep -nE '^(<<<<<<<|=======|>>>>>>>)'   # search tracked files for markers
```

Both print nothing when you are clean. Markers are plain text: Git will happily
commit them if you stage a file without cleaning it.

```knowledge-check
{ "questions": [
  { "id": "git-conflict-resolve-q1", "type": "mcq",
    "prompt": "After editing a conflicted file you must:",
    "options": [
      {"id":"a","text":"git add it, then git commit to complete the merge"},
      {"id":"b","text":"Delete the .git directory"},
      {"id":"c","text":"git push immediately"},
      {"id":"d","text":"Run git clone"}],
    "correct": "a",
    "explanation": "git add marks the path resolved; git commit records the merge commit. Deleting .git destroys the repository, pushing before committing sends nothing new, and cloning is unrelated." },
  { "id": "git-conflict-resolve-q2", "type": "mcq",
    "prompt": "What is the safest way to check no markers were left in the repository?",
    "options": [
      {"id":"a","text":"git grep -nE '^(<<<<<<<|>>>>>>>)'"},
      {"id":"b","text":"git gc"},
      {"id":"c","text":"git remote -v"},
      {"id":"d","text":"git tag"}],
    "correct": "a",
    "explanation": "Markers are plain text, so Git will happily commit them if you stage a file without cleaning it. gc, remote and tag do not look at file contents." }
] }
```

### Take one whole side for a file

When you know one side is simply right for a file:

```bash
git checkout --ours   config/settings.yml    # keep my branch's version
git checkout --theirs package-lock.json      # take the incoming version
git add config/settings.yml package-lock.json
```

For a whole merge: `git merge -X ours feature` resolves **conflicting hunks**
in favour of your side (non-conflicting changes from feature still come in).

### Visual tools

`git mergetool` opens a configured 3-way tool (vimdiff, meld, VS Code, ...).
Set one with `git config --global merge.tool vscode` plus the tool's command.
Editors like VS Code also show "Accept Current / Incoming / Both" buttons right
above the markers.

### Abort: back out cleanly

```
 DURING conflict                     AFTER git merge --abort
 main + half-resolved files    -->   exactly the pre-merge state of main
```

```bash
git merge feature/log-level      # conflict
git merge --abort
git status
```

Expected output:

```
On branch main
nothing to commit, working tree clean
```

```knowledge-check
{ "questions": [
  { "id": "git-conflict-abort-q1", "type": "mcq",
    "prompt": "What does git merge --abort do?",
    "options": [
      {"id":"a","text":"Deletes the other branch"},
      {"id":"b","text":"Restores the repository to its state before the merge started"},
      {"id":"c","text":"Commits the conflict markers"},
      {"id":"d","text":"Pushes to origin"}],
    "correct": "b",
    "explanation": "It is only available while a merge is in progress; afterwards use reset or revert instead. It deletes no branch, commits nothing and never pushes." }
] }
```

Start every merge with a clean working tree. Then `--abort` can always restore
it exactly.

## Try it

You resolved `app.conf`, ran `git add app.conf`, but `git commit` says
`error: Committing is not possible because you have unmerged files.` What is
going on?

<details>
<summary>Show answer</summary>

Another file still has a conflict. Run `git status` and look under
"Unmerged paths". Resolve and `git add` that file too, then commit.

</details>

## Common mistakes

- **Picking "ours" for everything to make it go away.** You silently throw away
  a teammate's work. Read each block.
- **Forgetting to run the tests after resolving.** A merge can be textually
  clean and still broken (for example, one side renamed a function the other
  side calls).
- **Using `--abort` after committing.** Too late; the merge is done. Use
  `git reset --hard ORIG_HEAD` (local only) or `git revert -m 1` (shared).

## Remember

- Resolve = edit to the final text, `git add`, `git commit`.
- `git diff --check` / `git grep` for markers before committing.
- `git checkout --ours|--theirs <file>` takes one side for a whole file.
- `git merge --abort` returns to the pre-merge state while still merging.

**Self-check:**

1. What does `git add` mean during a conflict?
2. How do you take the incoming version of one file?
3. When does `git merge --abort` stop working?
$md$, 9, $json$[{"id":"git-conflict-resolve-q1","type":"mcq","correct":"a"},{"id":"git-conflict-resolve-q2","type":"mcq","correct":"a"},{"id":"git-conflict-abort-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('3e253d61-0096-5930-a0c8-71326f790755', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0bfdc51c-0996-5a60-beac-0ac183d3389c', 'rerere: Let Git Remember Your Resolutions', 'notes', 2, $md$## Why this matters

On a long-lived branch you can hit the **same** conflict again and again: every
time you re-merge, rebase onto a new main, or retry an aborted merge. Resolving
it by hand each time is boring and error-prone. `rerere` ("reuse recorded
resolution") records your answer once and replays it automatically.

## Mental model: a sticky note on the question

The first time a conflict appears, Git photographs the conflicted text (the
**preimage**). When you resolve it, Git photographs your answer (the
**postimage**). Next time the identical conflict appears, Git finds the photo
and applies the same answer.

```
 conflict #1:  preimage ---you resolve---> postimage      saved in .git/rr-cache/<hash>/
 conflict #2 (same hunk) -> "Resolved 'logging.conf' using previous resolution."
```

It matches on the conflicting text, not on branch names, so it works across
merge, rebase, cherry-pick and revert.

## See it work

### Turn it on

```bash
git config rerere.enabled true          # this repo; use --global for all repos
```

Enable it **before** the merge, or the first conflict is not recorded.

### Record a resolution

```bash
git merge feature/log-level      # conflict in logging.conf
```

Expected output now includes a new line:

```
Auto-merging logging.conf
CONFLICT (content): Merge conflict in logging.conf
Recorded preimage for 'logging.conf'
Automatic merge failed; fix conflicts and then commit the result.
```

Resolve and commit as usual:

```bash
printf 'level=warn\n' > logging.conf
git add logging.conf
git commit --no-edit
ls .git/rr-cache/*/
```

Expected output:

```
Recorded resolution for 'logging.conf'.
[main 4d2f9b1] Merge branch 'feature/log-level'
postimage  preimage
```

### Replay

If the same conflict comes back (say you undo the merge and do it again later),
Git prints:

```
Resolved 'logging.conf' using previous resolution.
```

The file already contains your answer. rerere does **not** stage it for you by
default: check it, then `git add` and continue. (`rerere.autoUpdate true` stages
automatically.)

### Manage it

```bash
git rerere status       # files whose resolution rerere is tracking right now
git rerere diff         # what rerere would apply
git rerere forget logging.conf   # drop a wrong recorded resolution
```

```knowledge-check
{ "questions": [
  { "id": "git-conflict-rerere-q1", "type": "mcq",
    "prompt": "When is rerere most useful?",
    "options": [
      {"id":"a","text":"When you repeat the same merge or rebase many times, such as a long-lived branch rebased daily"},
      {"id":"b","text":"For encrypting commits"},
      {"id":"c","text":"For speeding up git clone"},
      {"id":"d","text":"For deleting old branches"}],
    "correct": "a",
    "explanation": "Each repeat of an identical conflict is resolved automatically from the recorded postimage. rerere has nothing to do with encryption, clone speed or branch cleanup." }
] }
```

## Try it

You enabled rerere, resolved a conflict badly, committed, and then undid the
merge. Next time you merge, Git re-applies your bad resolution. How do you stop
that?

<details>
<summary>Show answer</summary>

While the conflict is in progress, run:

```bash
git rerere forget <file>
```

Git drops the recorded resolution, puts the conflict markers back, and you can
resolve it correctly (which records the new answer).

</details>

## Common mistakes

- **Enabling it after the conflict.** The preimage is recorded only when the
  conflict first appears with rerere on.
- **Trusting replays blindly.** A replayed resolution can be wrong in a new
  context. Always review and run tests.
- **Expecting it to be shared.** `.git/rr-cache` is local; teammates do not get
  your recorded resolutions.

## Remember

- `git config rerere.enabled true` (or `--global`).
- First conflict: preimage recorded; your fix: postimage recorded.
- Same conflict later: "Resolved ... using previous resolution."
- `git rerere forget <file>` drops a bad recording.

**Self-check:**

1. What do preimage and postimage contain?
2. Does rerere stage the replayed file for you by default?
3. Where are recordings stored?
$md$, 6, $json$[{"id":"git-conflict-rerere-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('74fb2616-b5a3-50ad-a6ed-381dfce33769', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0bfdc51c-0996-5a60-beac-0ac183d3389c', 'Lab: Resolve, Abort and Remember Conflicts', 'notes', 3, $md$## Why this matters

In `~/work/config-app`, `main` and two feature branches all edited the same
config lines. You will trigger a conflict, resolve it by combining both sides,
finish the merge, abort a second one, and finally let rerere record a
resolution.

```bash
cd ~/work/config-app
git log --oneline --graph --all
```

## Task 1: trigger the conflict

Merge `feature/timeout` into `main` and stop at the conflict. Do not resolve
yet.

[[lab-task:1]]

Expected output and file:

```
Auto-merging app.conf
CONFLICT (content): Merge conflict in app.conf
Automatic merge failed; fix conflicts and then commit the result.

name=app
<<<<<<< HEAD
timeout=60
=======
timeout=45
>>>>>>> feature/timeout
log=info
retries=3
```

## Task 2: resolve by combining

Make `app.conf` keep `timeout=60` from `main` **and** `retries=3` from the
feature branch. Remove every marker and stage the file. Do not commit yet.

[[lab-task:2]]

Check: `git status` says `All conflicts fixed but you are still merging.`

## Task 3: complete the merge

Commit with the default message.

[[lab-task:3]]

Expected graph:

```
*   6be1f20 (HEAD -> main) Merge branch 'feature/timeout'
|\
| * c2a9d41 (feature/timeout) Raise timeout to 45 and add retries
* | 14e8b07 Raise timeout to 60
|/
* a70d3e5 Initial config
```

## Task 4: a second conflict

Merge `feature/log-level`. `logging.conf` conflicts (debug vs warn). Stop there.

[[lab-task:4]]

## Task 5: abort

Decide it is not the right time. Abort so the repository is exactly as before.

[[lab-task:5]]

Expected `git status`:

```
On branch main
nothing to commit, working tree clean
```

## Task 6: record a resolution with rerere

Enable rerere for this repository, merge `feature/log-level` again, resolve
`logging.conf` as `level=warn`, and commit.

[[lab-task:6]]

Expected messages along the way:

```
Recorded preimage for 'logging.conf'
...
Recorded resolution for 'logging.conf'.
```

and `ls .git/rr-cache/*/` shows `postimage  preimage`.

## Remember

- Read `git status` at every step of a conflict.
- Combine both sides when both are right.
- `--abort` is your undo button while the merge is in progress.
$md$, 30, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('08fe5130-784d-56e8-ad02-34ff566fe34c', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '74fb2616-b5a3-50ad-a6ed-381dfce33769', 'module', 'Lab: Resolve, Abort and Remember Conflicts', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
rm -rf /home/labuser/work/config-app
mkdir /home/labuser/work/config-app && cd /home/labuser/work/config-app
git init -q
M() { git add -A; GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
printf 'name=app\ntimeout=30\nlog=info\n' > app.conf
printf 'level=info\n' > logging.conf
M 2024-03-01 "Initial config"
git switch -q -c feature/timeout
printf 'name=app\ntimeout=45\nlog=info\nretries=3\n' > app.conf
M 2024-03-02 "Raise timeout to 45 and add retries"
git switch -q main
git switch -q -c feature/log-level
printf 'level=debug\n' > logging.conf
M 2024-03-03 "Enable debug logging"
git switch -q main
printf 'name=app\ntimeout=60\nlog=info\n' > app.conf
M 2024-03-04 "Raise timeout to 60"
printf 'level=warn\n' > logging.conf
M 2024-03-05 "Quiet logging"
chmod -R a+rwX /home/labuser/work/config-app
$script$, NULL, 40, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '89d20ac8-0796-5272-812e-4292bd52f6fc' AND id NOT IN ('9da0d9cb-f9d5-54b6-a8a7-69f11971c8e4', 'e3b688ae-1dab-5644-8063-e68a020f2fc5', '7e9449d0-112b-5ec3-aaa9-2b04d869dc3f', '871cfb2f-fd33-5930-b821-d33b95b4ccde', 'dfb27534-8740-5bbb-9c29-f43d358f9235', 'c122201b-6539-59ef-9e72-e62c71740d1f');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '89d20ac8-0796-5272-812e-4292bd52f6fc';
DELETE FROM lab_tasks WHERE lab_id = '08fe5130-784d-56e8-ad02-34ff566fe34c' AND id NOT IN ('0a4c401c-5b93-53f3-a6f7-ed23b8024c37', '59337a30-ab53-50e6-8fe4-c0aa362856fe', '697ae072-e42a-538c-b670-f19a5faeb446', 'c556745d-8284-5820-a6f2-61b7fade364b', '9a9a48cb-49c3-5938-a955-e56869719385', '90f1ec05-5d69-531f-90d1-3d3ec8538b0f');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '08fe5130-784d-56e8-ad02-34ff566fe34c';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('0a4c401c-5b93-53f3-a6f7-ed23b8024c37', '08fe5130-784d-56e8-ad02-34ff566fe34c', 1, 'Trigger a merge conflict', $md$In ~/work/config-app, merge branch feature/timeout into main. Both branches changed the timeout line, so Git must stop with a conflict in app.conf. Leave the merge unfinished.$md$, $script$r=/home/labuser/work/config-app
git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
[ "$(git -C $r rev-parse MERGE_HEAD)" = "$(git -C $r rev-parse feature/timeout)" ] &&
git -C $r ls-files -u | grep -q app.conf &&
grep -q '^<<<<<<<' $r/app.conf
$script$, 'git merge feature/timeout. When it says CONFLICT, run git status and open app.conf to see the markers.', 'Both sides changed the same line relative to the common ancestor, so Git cannot choose. It writes both versions between <<<<<<<, ======= and >>>>>>> and records MERGE_HEAD so you can finish or abort.', 10, false, true),
('59337a30-ab53-50e6-8fe4-c0aa362856fe', '08fe5130-784d-56e8-ad02-34ff566fe34c', 2, 'Resolve the conflict', $md$Edit app.conf so it keeps the larger timeout from main (timeout=60) AND the new retries=3 line from the feature branch. Remove all conflict markers and stage the file. Do not commit yet.$md$, $script$r=/home/labuser/work/config-app
git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
[ -z "$(git -C $r ls-files -u)" ] &&
! grep -qE '^(<<<<<<<|=======|>>>>>>>)' $r/app.conf &&
git -C $r show :app.conf | grep -qx 'timeout=60' &&
git -C $r show :app.conf | grep -qx 'retries=3' &&
! git -C $r show :app.conf | grep -q 'timeout=45'
$script$, 'Delete the three marker lines and the line you do not want, keep timeout=60 and retries=3, then git add app.conf. git diff --staged confirms.', 'Conflict markers are just text; resolving means producing the final content yourself. git add tells Git the conflict for that path is resolved and moves it out of the unmerged state.', 20, false, true),
('697ae072-e42a-538c-b670-f19a5faeb446', '08fe5130-784d-56e8-ad02-34ff566fe34c', 3, 'Complete the merge', $md$Finish the merge with git commit (accept the default message). Afterwards the working tree must be clean and contain no conflict markers anywhere.$md$, $script$r=/home/labuser/work/config-app
! git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
git -C $r log -1 --format=%s | grep -q '^Merge' &&
git -C $r merge-base --is-ancestor feature/timeout HEAD &&
[ -z "$(git -C $r grep -nE '^(<<<<<<<|>>>>>>>)' HEAD)" ] &&
git -C $r show HEAD:app.conf | grep -qx 'timeout=60' &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git commit with no -m opens the editor with a pre-filled merge message; save and quit. Or use git commit --no-edit.', 'The merge commit is created from the resolved index and has two parents, so both lines of history stay linked.', 10, false, true),
('c556745d-8284-5820-a6f2-61b7fade364b', '08fe5130-784d-56e8-ad02-34ff566fe34c', 4, 'Start a second conflicting merge', $md$Now merge feature/log-level into main. logging.conf conflicts (debug vs warn). Stop at the conflict.$md$, $script$r=/home/labuser/work/config-app
git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
[ "$(git -C $r rev-parse MERGE_HEAD)" = "$(git -C $r rev-parse feature/log-level)" ] &&
git -C $r ls-files -u | grep -q logging.conf
$script$, 'git merge feature/log-level, then read git status - it lists logging.conf as "both modified".', 'Same mechanics as before; this time you will back out instead of resolving.', 10, false, true),
('9a9a48cb-49c3-5938-a955-e56869719385', '08fe5130-784d-56e8-ad02-34ff566fe34c', 5, 'Abort the merge', $md$Decide this merge is not worth doing right now and abort it so the repository returns exactly to its state before you started.$md$, $script$r=/home/labuser/work/config-app
! git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
[ -z "$(git -C $r status --porcelain)" ] &&
! git -C $r merge-base --is-ancestor feature/log-level HEAD &&
[ "$(cat $r/logging.conf)" = "level=warn" ]
$script$, 'git merge --abort restores the pre-merge state. It only works while the merge is still in progress.', '--abort resets the index and working tree to the commit you were on before the merge, discarding half-resolved edits. Nothing is lost from committed history.', 15, false, true),
('90f1ec05-5d69-531f-90d1-3d3ec8538b0f', '08fe5130-784d-56e8-ad02-34ff566fe34c', 6, 'Let rerere remember the resolution', $md$Enable rerere for this repository (git config rerere.enabled true), merge feature/log-level again, resolve logging.conf as level=warn, and commit the merge. Git then records your resolution so the same conflict can be replayed automatically later.$md$, $script$r=/home/labuser/work/config-app
[ "$(git -C $r config --get rerere.enabled)" = true ] &&
ls $r/.git/rr-cache/*/postimage >/dev/null 2>&1 &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
git -C $r merge-base --is-ancestor feature/log-level HEAD &&
[ "$(git -C $r show HEAD:logging.conf)" = "level=warn" ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'Enable rerere BEFORE the merge so the conflict is recorded. After resolving, git add and git commit; the postimage appears under .git/rr-cache.', 'rerere (reuse recorded resolution) stores the conflicted preimage and your resolved postimage keyed by the conflict''s hash. If the same conflict reappears (rebase, re-merge) Git applies your earlier fix automatically.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('89d20ac8-0796-5272-812e-4292bd52f6fc', '08fe5130-784d-56e8-ad02-34ff566fe34c', 1, $json$[{"id":"0a4c401c-5b93-53f3-a6f7-ed23b8024c37","lab_id":"08fe5130-784d-56e8-ad02-34ff566fe34c","position":1,"title":"Trigger a merge conflict","description":"In ~/work/config-app, merge branch feature/timeout into main. Both branches changed the timeout line, so Git must stop with a conflict in app.conf. Leave the merge unfinished.","verification_script":"r=/home/labuser/work/config-app\ngit -C $r rev-parse -q --verify MERGE_HEAD \u003e/dev/null \u0026\u0026\n[ \"$(git -C $r rev-parse MERGE_HEAD)\" = \"$(git -C $r rev-parse feature/timeout)\" ] \u0026\u0026\ngit -C $r ls-files -u | grep -q app.conf \u0026\u0026\ngrep -q '^\u003c\u003c\u003c\u003c\u003c\u003c\u003c' $r/app.conf\n","hint_context":"git merge feature/timeout. When it says CONFLICT, run git status and open app.conf to see the markers.","explanation_context":"Both sides changed the same line relative to the common ancestor, so Git cannot choose. It writes both versions between \u003c\u003c\u003c\u003c\u003c\u003c\u003c, ======= and \u003e\u003e\u003e\u003e\u003e\u003e\u003e and records MERGE_HEAD so you can finish or abort.","points":10,"is_optional":false,"is_stateful":true},{"id":"59337a30-ab53-50e6-8fe4-c0aa362856fe","lab_id":"08fe5130-784d-56e8-ad02-34ff566fe34c","position":2,"title":"Resolve the conflict","description":"Edit app.conf so it keeps the larger timeout from main (timeout=60) AND the new retries=3 line from the feature branch. Remove all conflict markers and stage the file. Do not commit yet.","verification_script":"r=/home/labuser/work/config-app\ngit -C $r rev-parse -q --verify MERGE_HEAD \u003e/dev/null \u0026\u0026\n[ -z \"$(git -C $r ls-files -u)\" ] \u0026\u0026\n! grep -qE '^(\u003c\u003c\u003c\u003c\u003c\u003c\u003c|=======|\u003e\u003e\u003e\u003e\u003e\u003e\u003e)' $r/app.conf \u0026\u0026\ngit -C $r show :app.conf | grep -qx 'timeout=60' \u0026\u0026\ngit -C $r show :app.conf | grep -qx 'retries=3' \u0026\u0026\n! git -C $r show :app.conf | grep -q 'timeout=45'\n","hint_context":"Delete the three marker lines and the line you do not want, keep timeout=60 and retries=3, then git add app.conf. git diff --staged confirms.","explanation_context":"Conflict markers are just text; resolving means producing the final content yourself. git add tells Git the conflict for that path is resolved and moves it out of the unmerged state.","points":20,"is_optional":false,"is_stateful":true},{"id":"697ae072-e42a-538c-b670-f19a5faeb446","lab_id":"08fe5130-784d-56e8-ad02-34ff566fe34c","position":3,"title":"Complete the merge","description":"Finish the merge with git commit (accept the default message). Afterwards the working tree must be clean and contain no conflict markers anywhere.","verification_script":"r=/home/labuser/work/config-app\n! git -C $r rev-parse -q --verify MERGE_HEAD \u003e/dev/null \u0026\u0026\n[ \"$(git -C $r rev-list --parents -n 1 HEAD | wc -w)\" = 3 ] \u0026\u0026\ngit -C $r log -1 --format=%s | grep -q '^Merge' \u0026\u0026\ngit -C $r merge-base --is-ancestor feature/timeout HEAD \u0026\u0026\n[ -z \"$(git -C $r grep -nE '^(\u003c\u003c\u003c\u003c\u003c\u003c\u003c|\u003e\u003e\u003e\u003e\u003e\u003e\u003e)' HEAD)\" ] \u0026\u0026\ngit -C $r show HEAD:app.conf | grep -qx 'timeout=60' \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"git commit with no -m opens the editor with a pre-filled merge message; save and quit. Or use git commit --no-edit.","explanation_context":"The merge commit is created from the resolved index and has two parents, so both lines of history stay linked.","points":10,"is_optional":false,"is_stateful":true},{"id":"c556745d-8284-5820-a6f2-61b7fade364b","lab_id":"08fe5130-784d-56e8-ad02-34ff566fe34c","position":4,"title":"Start a second conflicting merge","description":"Now merge feature/log-level into main. logging.conf conflicts (debug vs warn). Stop at the conflict.","verification_script":"r=/home/labuser/work/config-app\ngit -C $r rev-parse -q --verify MERGE_HEAD \u003e/dev/null \u0026\u0026\n[ \"$(git -C $r rev-parse MERGE_HEAD)\" = \"$(git -C $r rev-parse feature/log-level)\" ] \u0026\u0026\ngit -C $r ls-files -u | grep -q logging.conf\n","hint_context":"git merge feature/log-level, then read git status - it lists logging.conf as \"both modified\".","explanation_context":"Same mechanics as before; this time you will back out instead of resolving.","points":10,"is_optional":false,"is_stateful":true},{"id":"9a9a48cb-49c3-5938-a955-e56869719385","lab_id":"08fe5130-784d-56e8-ad02-34ff566fe34c","position":5,"title":"Abort the merge","description":"Decide this merge is not worth doing right now and abort it so the repository returns exactly to its state before you started.","verification_script":"r=/home/labuser/work/config-app\n! git -C $r rev-parse -q --verify MERGE_HEAD \u003e/dev/null \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ] \u0026\u0026\n! git -C $r merge-base --is-ancestor feature/log-level HEAD \u0026\u0026\n[ \"$(cat $r/logging.conf)\" = \"level=warn\" ]\n","hint_context":"git merge --abort restores the pre-merge state. It only works while the merge is still in progress.","explanation_context":"--abort resets the index and working tree to the commit you were on before the merge, discarding half-resolved edits. Nothing is lost from committed history.","points":15,"is_optional":false,"is_stateful":true},{"id":"90f1ec05-5d69-531f-90d1-3d3ec8538b0f","lab_id":"08fe5130-784d-56e8-ad02-34ff566fe34c","position":6,"title":"Let rerere remember the resolution","description":"Enable rerere for this repository (git config rerere.enabled true), merge feature/log-level again, resolve logging.conf as level=warn, and commit the merge. Git then records your resolution so the same conflict can be replayed automatically later.","verification_script":"r=/home/labuser/work/config-app\n[ \"$(git -C $r config --get rerere.enabled)\" = true ] \u0026\u0026\nls $r/.git/rr-cache/*/postimage \u003e/dev/null 2\u003e\u00261 \u0026\u0026\n[ \"$(git -C $r rev-list --parents -n 1 HEAD | wc -w)\" = 3 ] \u0026\u0026\ngit -C $r merge-base --is-ancestor feature/log-level HEAD \u0026\u0026\n[ \"$(git -C $r show HEAD:logging.conf)\" = \"level=warn\" ] \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"Enable rerere BEFORE the merge so the conflict is recorded. After resolving, git add and git commit; the postimage appears under .git/rr-cache.","explanation_context":"rerere (reuse recorded resolution) stores the conflicted preimage and your resolved postimage keyed by the conflict's hash. If the same conflict reappears (rebase, re-merge) Git applies your earlier fix automatically.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('9da0d9cb-f9d5-54b6-a8a7-69f11971c8e4', '89d20ac8-0796-5272-812e-4292bd52f6fc', '0a4c401c-5b93-53f3-a6f7-ed23b8024c37', 1, 'Trigger a merge conflict', $md$In ~/work/config-app, merge branch feature/timeout into main. Both branches changed the timeout line, so Git must stop with a conflict in app.conf. Leave the merge unfinished.$md$, $script$r=/home/labuser/work/config-app
git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
[ "$(git -C $r rev-parse MERGE_HEAD)" = "$(git -C $r rev-parse feature/timeout)" ] &&
git -C $r ls-files -u | grep -q app.conf &&
grep -q '^<<<<<<<' $r/app.conf
$script$, 'git merge feature/timeout. When it says CONFLICT, run git status and open app.conf to see the markers.', 'Both sides changed the same line relative to the common ancestor, so Git cannot choose. It writes both versions between <<<<<<<, ======= and >>>>>>> and records MERGE_HEAD so you can finish or abort.', 10, false, true),
('e3b688ae-1dab-5644-8063-e68a020f2fc5', '89d20ac8-0796-5272-812e-4292bd52f6fc', '59337a30-ab53-50e6-8fe4-c0aa362856fe', 2, 'Resolve the conflict', $md$Edit app.conf so it keeps the larger timeout from main (timeout=60) AND the new retries=3 line from the feature branch. Remove all conflict markers and stage the file. Do not commit yet.$md$, $script$r=/home/labuser/work/config-app
git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
[ -z "$(git -C $r ls-files -u)" ] &&
! grep -qE '^(<<<<<<<|=======|>>>>>>>)' $r/app.conf &&
git -C $r show :app.conf | grep -qx 'timeout=60' &&
git -C $r show :app.conf | grep -qx 'retries=3' &&
! git -C $r show :app.conf | grep -q 'timeout=45'
$script$, 'Delete the three marker lines and the line you do not want, keep timeout=60 and retries=3, then git add app.conf. git diff --staged confirms.', 'Conflict markers are just text; resolving means producing the final content yourself. git add tells Git the conflict for that path is resolved and moves it out of the unmerged state.', 20, false, true),
('7e9449d0-112b-5ec3-aaa9-2b04d869dc3f', '89d20ac8-0796-5272-812e-4292bd52f6fc', '697ae072-e42a-538c-b670-f19a5faeb446', 3, 'Complete the merge', $md$Finish the merge with git commit (accept the default message). Afterwards the working tree must be clean and contain no conflict markers anywhere.$md$, $script$r=/home/labuser/work/config-app
! git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
git -C $r log -1 --format=%s | grep -q '^Merge' &&
git -C $r merge-base --is-ancestor feature/timeout HEAD &&
[ -z "$(git -C $r grep -nE '^(<<<<<<<|>>>>>>>)' HEAD)" ] &&
git -C $r show HEAD:app.conf | grep -qx 'timeout=60' &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git commit with no -m opens the editor with a pre-filled merge message; save and quit. Or use git commit --no-edit.', 'The merge commit is created from the resolved index and has two parents, so both lines of history stay linked.', 10, false, true),
('871cfb2f-fd33-5930-b821-d33b95b4ccde', '89d20ac8-0796-5272-812e-4292bd52f6fc', 'c556745d-8284-5820-a6f2-61b7fade364b', 4, 'Start a second conflicting merge', $md$Now merge feature/log-level into main. logging.conf conflicts (debug vs warn). Stop at the conflict.$md$, $script$r=/home/labuser/work/config-app
git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
[ "$(git -C $r rev-parse MERGE_HEAD)" = "$(git -C $r rev-parse feature/log-level)" ] &&
git -C $r ls-files -u | grep -q logging.conf
$script$, 'git merge feature/log-level, then read git status - it lists logging.conf as "both modified".', 'Same mechanics as before; this time you will back out instead of resolving.', 10, false, true),
('dfb27534-8740-5bbb-9c29-f43d358f9235', '89d20ac8-0796-5272-812e-4292bd52f6fc', '9a9a48cb-49c3-5938-a955-e56869719385', 5, 'Abort the merge', $md$Decide this merge is not worth doing right now and abort it so the repository returns exactly to its state before you started.$md$, $script$r=/home/labuser/work/config-app
! git -C $r rev-parse -q --verify MERGE_HEAD >/dev/null &&
[ -z "$(git -C $r status --porcelain)" ] &&
! git -C $r merge-base --is-ancestor feature/log-level HEAD &&
[ "$(cat $r/logging.conf)" = "level=warn" ]
$script$, 'git merge --abort restores the pre-merge state. It only works while the merge is still in progress.', '--abort resets the index and working tree to the commit you were on before the merge, discarding half-resolved edits. Nothing is lost from committed history.', 15, false, true),
('c122201b-6539-59ef-9e72-e62c71740d1f', '89d20ac8-0796-5272-812e-4292bd52f6fc', '90f1ec05-5d69-531f-90d1-3d3ec8538b0f', 6, 'Let rerere remember the resolution', $md$Enable rerere for this repository (git config rerere.enabled true), merge feature/log-level again, resolve logging.conf as level=warn, and commit the merge. Git then records your resolution so the same conflict can be replayed automatically later.$md$, $script$r=/home/labuser/work/config-app
[ "$(git -C $r config --get rerere.enabled)" = true ] &&
ls $r/.git/rr-cache/*/postimage >/dev/null 2>&1 &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
git -C $r merge-base --is-ancestor feature/log-level HEAD &&
[ "$(git -C $r show HEAD:logging.conf)" = "level=warn" ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'Enable rerere BEFORE the merge so the conflict is recorded. After resolving, git add and git commit; the postimage appears under .git/rr-cache.', 'rerere (reuse recorded resolution) stores the conflicted preimage and your resolved postimage keyed by the conflict''s hash. If the same conflict reappears (rebase, re-merge) Git applies your earlier fix automatically.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '89d20ac8-0796-5272-812e-4292bd52f6fc', updated_at = now()
WHERE id = '08fe5130-784d-56e8-ad02-34ff566fe34c' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('bf5761e4-dcd4-5d13-83d6-15891d18ba21', '00000000-0000-0000-0000-000000000001', 'mcq', 'Since the merge base, main changed line 10 of api.py and feature changed line...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e9b5b49f-0bd2-52b2-8271-f334a9b05c47', 'bf5761e4-dcd4-5d13-83d6-15891d18ba21', 1, $json${"prompt":"Since the merge base, main changed line 10 of api.py and feature changed line 80 of the same file. You merge feature into main. What happens?","multiple":false,"options":[{"id":"a","text":"Conflict, because both branches changed api.py","is_correct":false},{"id":"b","text":"Clean merge: each region was changed on only one side, so Git takes both changes","is_correct":true},{"id":"c","text":"Git keeps main's version of the whole file","is_correct":false},{"id":"d","text":"Git asks you to choose one version of the file","is_correct":false}],"explanation":"Conflicts are per region (hunk), not per file. Different, non-adjacent regions merge automatically. Git never keeps one side of a whole file unless told to."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('64e84da7-043c-537f-b89b-cfe6126466cf', '00000000-0000-0000-0000-000000000001', 'mcq', 'You are on main merging `feature/pay`. The block shows `<<<<<<< HEAD` / `fee=...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('3a63fbc4-d33f-5e3e-907b-4607c465f72a', '64e84da7-043c-537f-b89b-cfe6126466cf', 1, $json${"prompt":"You are on main merging `feature/pay`. The block shows `\u003c\u003c\u003c\u003c\u003c\u003c\u003c HEAD` / `fee=2` / `=======` / `fee=3` / `\u003e\u003e\u003e\u003e\u003e\u003e\u003e feature/pay`. Which statement is true?","multiple":false,"options":[{"id":"a","text":"fee=2 is from feature/pay","is_correct":false},{"id":"b","text":"fee=2 is from main (ours); fee=3 is from feature/pay (theirs)","is_correct":true},{"id":"c","text":"fee=2 is the original value from the merge base","is_correct":false},{"id":"d","text":"Both values come from main","is_correct":false}],"explanation":"In a merge, HEAD is the branch you are on. The ancestor value only appears with diff3/zdiff3 style, between ||||||| and =======."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0d03b5b1-5a02-517c-827b-7d34c8e3ab87', '00000000-0000-0000-0000-000000000001', 'mcq', 'You fixed both conflicted files and ran `git add` on them. What does `git sta...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b00c765e-06f6-56c5-a23d-ae15b046a5ac', '0d03b5b1-5a02-517c-827b-7d34c8e3ab87', 1, $json${"prompt":"You fixed both conflicted files and ran `git add` on them. What does `git status` say, and what is the next command?","multiple":false,"options":[{"id":"a","text":"'All conflicts fixed but you are still merging'; run git commit","is_correct":true},{"id":"b","text":"'nothing to commit'; run git push","is_correct":false},{"id":"c","text":"'You have unmerged paths'; run git merge --continue only","is_correct":false},{"id":"d","text":"'detached HEAD'; run git switch main","is_correct":false}],"explanation":"After staging all resolutions you are still mid-merge until you commit (git merge --continue also works and runs commit). 'Unmerged paths' would mean a file is still unresolved, and you are not detached."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c46c2831-036b-5623-a252-491657650334', '00000000-0000-0000-0000-000000000001', 'mcq', 'In a big merge, package-lock.json conflicts in 40 places. You know the incomi...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ce967f1f-5498-5174-9a92-e419c04a17a6', 'c46c2831-036b-5623-a252-491657650334', 1, $json${"prompt":"In a big merge, package-lock.json conflicts in 40 places. You know the incoming branch's lock file is correct. What is the quickest correct move?","multiple":false,"options":[{"id":"a","text":"Edit all 40 blocks by hand","is_correct":false},{"id":"b","text":"git checkout --theirs package-lock.json, then git add it","is_correct":true},{"id":"c","text":"git merge --abort and delete the file","is_correct":false},{"id":"d","text":"git add package-lock.json with the markers","is_correct":false}],"explanation":"--theirs takes the merged-in branch's whole file. Hand-editing is slow and risky, aborting loses the merge, and staging markers commits a broken file."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ecd1a474-6a55-5b71-9cad-02e1871918d8', '00000000-0000-0000-0000-000000000001', 'mcq', 'A merge resolved without any conflict, but the app no longer starts: main ren...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('88a5ee6a-6e18-50b0-917d-d8ddc8040e4d', 'ecd1a474-6a55-5b71-9cad-02e1871918d8', 1, $json${"prompt":"A merge resolved without any conflict, but the app no longer starts: main renamed `get_user()` to `fetch_user()` while feature added a new call to `get_user()`. What does this show?","multiple":false,"options":[{"id":"a","text":"Git has a bug","is_correct":false},{"id":"b","text":"A textually clean merge can still be semantically broken; always run tests after merging","is_correct":true},{"id":"c","text":"rerere applied a wrong resolution","is_correct":false},{"id":"d","text":"The merge base was wrong","is_correct":false}],"explanation":"Git merges text, not meaning. The edits touched different lines, so there was no conflict. Nothing is buggy, rerere only acts on recorded conflicts, and the merge base was correct."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('81be0dfb-57ed-5b7f-bbdb-54d61762973c', '00000000-0000-0000-0000-000000000001', 'mcq', 'You rebase a long-lived branch onto main every morning and resolve the same c...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f1546eb4-6c63-5b9e-8201-f23e41d8c643', '81be0dfb-57ed-5b7f-bbdb-54d61762973c', 1, $json${"prompt":"You rebase a long-lived branch onto main every morning and resolve the same conflict each time. What helps most?","multiple":false,"options":[{"id":"a","text":"git config rerere.enabled true","is_correct":true},{"id":"b","text":"git config merge.ff false","is_correct":false},{"id":"c","text":"git gc --aggressive","is_correct":false},{"id":"d","text":"git merge -X theirs every time","is_correct":false}],"explanation":"rerere replays recorded resolutions of identical conflicts. merge.ff changes history shape, gc compresses storage, and -X theirs blindly discards your side of every conflict."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0a0f77b0-e7be-501b-bc1d-a2095ed53a61', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 5): you merge feature into main and Git prints ''Fast-forward''...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5d196642-09a5-5cf1-b38d-ae9c1c0b4f36', '0a0f77b0-e7be-501b-bc1d-a2095ed53a61', 1, $json${"prompt":"Review (Section 5): you merge feature into main and Git prints 'Fast-forward'. How many new commits were created?","multiple":false,"options":[{"id":"a","text":"Zero; main's label just moved forward","is_correct":true},{"id":"b","text":"One merge commit","is_correct":false},{"id":"c","text":"One per feature commit","is_correct":false},{"id":"d","text":"Two","is_correct":false}],"explanation":"A fast-forward creates no commit at all. A merge commit appears only when histories diverged or with --no-ff."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('691f824c-df9a-5ff6-a346-2d5740e94197', '00000000-0000-0000-0000-000000000001', 'Quiz: Merge Conflicts', 'git-merge-conflicts-quiz', 'Quiz covering Merge Conflicts.', 'mcq', 'published', 'module', '20ad5e4c-0262-5bcd-8650-8c54dac29f73', 12, 70, 5, 14, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '691f824c-df9a-5ff6-a346-2d5740e94197' AND question_id NOT IN ('bf5761e4-dcd4-5d13-83d6-15891d18ba21', '64e84da7-043c-537f-b89b-cfe6126466cf', '0d03b5b1-5a02-517c-827b-7d34c8e3ab87', 'c46c2831-036b-5623-a252-491657650334', 'ecd1a474-6a55-5b71-9cad-02e1871918d8', '81be0dfb-57ed-5b7f-bbdb-54d61762973c', '0a0f77b0-e7be-501b-bc1d-a2095ed53a61');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('e346b301-ea66-5a26-9ce5-31c7859c0d8b', '691f824c-df9a-5ff6-a346-2d5740e94197', 'bf5761e4-dcd4-5d13-83d6-15891d18ba21', 'e9b5b49f-0bd2-52b2-8271-f334a9b05c47', 0, 2),
('01c15917-abb6-56df-a256-7f4daf310e2b', '691f824c-df9a-5ff6-a346-2d5740e94197', '64e84da7-043c-537f-b89b-cfe6126466cf', '3a63fbc4-d33f-5e3e-907b-4607c465f72a', 1, 2),
('f7ef0019-61c7-5f86-927f-a123d4b0b0bb', '691f824c-df9a-5ff6-a346-2d5740e94197', '0d03b5b1-5a02-517c-827b-7d34c8e3ab87', 'b00c765e-06f6-56c5-a23d-ae15b046a5ac', 2, 2),
('73c44f4e-d00f-5bcb-9637-f2fa8d039b97', '691f824c-df9a-5ff6-a346-2d5740e94197', 'c46c2831-036b-5623-a252-491657650334', 'ce967f1f-5498-5174-9a92-e419c04a17a6', 3, 2),
('7b5148a0-050b-5e8b-aa20-f171ef3b973d', '691f824c-df9a-5ff6-a346-2d5740e94197', 'ecd1a474-6a55-5b71-9cad-02e1871918d8', '88a5ee6a-6e18-50b0-917d-d8ddc8040e4d', 4, 2),
('a6ebd09b-d7fd-5a23-879b-d3460faaea8d', '691f824c-df9a-5ff6-a346-2d5740e94197', '81be0dfb-57ed-5b7f-bbdb-54d61762973c', 'f1546eb4-6c63-5b9e-8201-f23e41d8c643', 5, 2),
('3c92ba10-e313-5884-9c37-adf444023515', '691f824c-df9a-5ff6-a346-2d5740e94197', '0a0f77b0-e7be-501b-bc1d-a2095ed53a61', '5d196642-09a5-5cf1-b38d-ae9c1c0b4f36', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('20ad5e4c-0262-5bcd-8650-8c54dac29f73', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0bfdc51c-0996-5a60-beac-0ac183d3389c', 'Quiz: Merge Conflicts', 'assessment', 4, 10, '691f824c-df9a-5ff6-a346-2d5740e94197')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Under the Hood: Objects, Refs and the Index
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('e0b3c433-037f-599c-a7bf-214e35421662', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Under the Hood: Objects, Refs and the Index', 7, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('500a4b7b-7cfd-592d-814b-a3d8396d6537', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'e0b3c433-037f-599c-a7bf-214e35421662', 'The Object Database: Blobs, Trees, Commits and Tags', 'notes', 0, $md$## Why this matters

So far you have used Git through its friendly commands. Under them sits a tiny,
elegant database with only four kinds of object. Once you can see it, rebase,
reset, cherry-pick and the reflog all become obvious: they just create objects
and move labels. It is also a classic interview topic.

## Mental model: a warehouse of labelled boxes

Git's `.git/objects` folder is a warehouse. Every box is sealed and labelled
with a fingerprint (hash) **computed from its contents**. Same contents = same
label, so nothing is ever stored twice. Boxes are never opened and changed;
you only add new ones.

> **One-sentence definition:** Git is a **content-addressable** store: you give
> it data, it gives you back a hash, and that hash is the data's permanent name.

The four object types:

| Object | Holds | Analogy |
|---|---|---|
| **blob** | The bytes of one file (no name!) | A page |
| **tree** | A list of names -> blobs and subtrees, with modes | A folder listing |
| **commit** | One root tree + parent(s) + author, committer, message | A dated cover letter |
| **tag** (annotated) | A pointer to an object + tagger + message | A signed label |

```
 commit e5fda59 ----> tree 5889598 (root)
  "Add README and app"   |-- README.md -> blob fec5601   "# Hello"
                         '-- src/      -> tree 13803ae
                                           '-- app.sh -> blob 8b2fe54  "echo hi"
```

## See it work

### Ask Git to hash some content

```bash
echo "# Hello" | git hash-object --stdin
```

What this does: computes the blob hash for that content without storing it.
Expected output, identical on every machine in the world:

```
fec56017dc1b1ac87ad6e54e3cb3a20bb8dcc5ab
```

Add `-w` to also write the blob into the database.

### Walk from a commit down to a file

```bash
git cat-file -t HEAD          # type of the object
git cat-file -p HEAD          # pretty-print it
```

Expected output:

```
commit
tree 58895983f0bc0369f144effc936e853a95f9083b
author Ada Student <ada@example.com> 1704103200 +0000
committer Ada Student <ada@example.com> 1704103200 +0000

Add README and app
```

That is the whole commit: a tree, author and committer (name, email, Unix
time, timezone), and the message. A non-root commit also has `parent <hash>`
lines (two for a merge).

```bash
git cat-file -p 'HEAD^{tree}'
```

```
100644 blob fec56017dc1b1ac87ad6e54e3cb3a20bb8dcc5ab	README.md
040000 tree 13803ae2f49ec21cb219869c5558aef862f47410	src
```

The tree stores the **file names** and modes (`100644` normal file, `100755`
executable, `040000` directory, `120000` symlink, `160000` submodule). The blob
stores only content. That is why renaming a file creates a new tree but reuses
the same blob.

### Annotated tags are objects too

```bash
git tag -a v1 -m "Release 1"
git cat-file -p v1
```

```
object e5fda59241d1283c91fa2b05a24226a7ab85f105
type commit
tag v1
tagger Ada Student <ada@example.com> 1792164929 +0000

Release 1
```

A **lightweight** tag (`git tag v1` without `-a`) creates no object; it is just
a label, like a branch that never moves.

### About the hash

Git hashes `"<type> <size>\0<content>"` with SHA-1 by default (a hardened
variant that detects known collision attacks). Repositories can also use
SHA-256 (`git init --object-format=sha256`), which the Git project plans to make
the default in the future. You can type any unique prefix, usually 7+
characters.

## Try it

Two files in different folders, `docs/LICENSE` and `vendor/LICENSE`, have
identical content. How many blobs does Git store for them?

<details>
<summary>Show answer</summary>

One. The blob hash depends only on content, so both tree entries point to the
same blob. Names live in the trees.

</details>

## Common mistakes

- **Thinking commits store diffs.** A commit points to a full tree. Diffs are
  computed by comparing two trees.
- **Thinking a blob knows its filename.** It does not; trees hold names.
- **Thinking objects can be edited.** Any change makes a new object with a new
  hash. "Rewriting history" means creating new objects and moving labels.

## Remember

- Four objects: blob (content), tree (names), commit (snapshot + parents + meta), tag.
- Hash = name derived from content; identical content is stored once.
- `git cat-file -t` (type) and `-p` (print) let you walk the graph.
- Objects are immutable; history changes are new objects plus moved labels.

**Self-check:**

1. Which object stores file names?
2. What does a commit object contain?
3. Why does renaming a file not duplicate its content?
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('c093176a-bb3b-5ea2-872c-e5dae4804077', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'e0b3c433-037f-599c-a7bf-214e35421662', 'Refs, HEAD, Detached HEAD and Revision Syntax', 'notes', 1, $md$## Why this matters

Objects are immutable and named by hashes nobody wants to type. **Refs** give
them human names and are the only thing that moves when you commit, reset or
rebase. Understanding refs and `HEAD` explains detached HEAD, "lost" commits,
and the `~` / `^` syntax you see in every tutorial.

## Mental model: sticky notes on boxes

The commit DAG (boxes linked to their parents) never changes. Refs are sticky
notes stuck on boxes. Committing = add a box, move the note.

> **DAG** = directed acyclic graph: each commit points to its parent(s), arrows
> only go backwards in time, and there are no loops.

```
 refs/heads/main  ----------------------.
 refs/tags/v1.0 ------------.            v
                     A <--- B <--- C <--- D
                                    ^
 refs/heads/fix --------------------'
 HEAD --> "ref: refs/heads/main"      (HEAD points to a branch, which points to a commit)
```

| Ref | Lives in | Moves when |
|---|---|---|
| `refs/heads/<branch>` | `.git/refs/heads/` | You commit, merge, reset on that branch |
| `refs/remotes/origin/<b>` | `.git/refs/remotes/` | fetch, pull, push |
| `refs/tags/<tag>` | `.git/refs/tags/` | Never (by convention) |
| `HEAD` | `.git/HEAD` | You switch branches |
| `refs/stash` | `.git/refs/stash` | You stash |

Many refs may also be packed into one file, `.git/packed-refs`, for speed.
Always use commands like `git show-ref` instead of reading files directly.

## See it work

### HEAD is (usually) a pointer to a pointer

```bash
cat .git/HEAD
git rev-parse HEAD
git show-ref
```

Expected output:

```
ref: refs/heads/main
e5fda59241d1283c91fa2b05a24226a7ab85f105
e5fda59241d1283c91fa2b05a24226a7ab85f105 refs/heads/main
812bd18cfdc59a9c25eecda7f0bf7df972a94a40 refs/tags/v1
```

`HEAD` is a **symbolic ref**: it names a branch. When you commit, Git writes the
new commit, then updates the branch HEAD names.

### Detached HEAD

```bash
git switch --detach v1
cat .git/HEAD
git status
```

```
e5fda59241d1283c91fa2b05a24226a7ab85f105
HEAD detached at e5fda59
nothing to commit, working tree clean
```

Now `HEAD` holds a hash directly. Commits you make here are attached to no
branch:

```
 main --> D
          \
           X---Y   <- HEAD only. Switch away and nothing points at Y.
```

Save them before leaving: `git switch -c keep-this`. Already left? The reflog
remembers (Section 9): `git reflog`, find Y, `git branch keep-this <hash>`.

### Moving a ref by hand

```bash
git update-ref refs/heads/manual HEAD~1     # create/move branch "manual"
git branch manual2 HEAD~1                   # same effect, friendlier
```

Both just write a hash into a ref. This is all a branch is.

### Revision syntax cheat sheet

| Syntax | Means |
|---|---|
| `HEAD~1`, `HEAD~3` | 1st / 3rd generation back, following **first** parents |
| `HEAD^` = `HEAD^1` | First parent |
| `HEAD^2` | **Second** parent (only merges have one) |
| `main@{upstream}`, `@{u}` | The branch's upstream, e.g. `origin/main` |
| `main@{2}` | Where main pointed 2 moves ago (reflog) |
| `v1^{commit}`, `HEAD^{tree}` | Peel a tag to its commit / a commit to its tree |
| `HEAD:src/app.sh` | The blob for that path in that commit |
| `A..B` | Commits reachable from B but not from A |
| `A...B` | Commits reachable from either but not both |
| `:/fix typo` | Youngest commit whose message matches |

`git rev-parse <anything>` turns any of these into a hash, perfect for
checking your understanding.

## Try it

`M` is a merge commit on `main`. What is the difference between `M~2` and
`M^2`?

<details>
<summary>Show answer</summary>

`M~2` = grandparent along the first-parent line (two steps back on `main`).
`M^2` = the **second parent** of M, i.e. the tip of the branch that was merged
in. `~` counts generations; `^` picks which parent.

</details>

## Common mistakes

- **Panicking at "detached HEAD".** It is a normal state for looking at old
  commits. Just do not leave new commits there without a branch.
- **Editing `.git/refs` files by hand.** Refs may be packed or use the newer
  `reftable` format; use `git update-ref` / `git branch`.
- **Confusing `..` and `...`.** For `git log`, `main..feature` = what feature
  has that main does not. For `git diff`, `main...feature` = changes on feature
  since it split from main.

## Remember

- Refs are names for commits; only refs move, objects never change.
- `HEAD` normally points to a branch; detached HEAD points to a commit.
- Commits made on a detached HEAD need a branch, or they become unreachable.
- `~n` = n generations back (first parent); `^n` = nth parent.

**Self-check:**

1. What does `.git/HEAD` contain on a normal branch?
2. How do you keep commits made on a detached HEAD?
3. What does `git log main..feature` show?
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0476992a-d624-5231-9954-81609f76eba5', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'e0b3c433-037f-599c-a7bf-214e35421662', 'The Index, Packfiles and Garbage Collection', 'notes', 2, $md$## Why this matters

Two final pieces complete the picture. The **index** is a real file that
explains staging and conflicts. **Reachability and garbage collection** explain
why "deleted" commits can be recovered, and for how long. Together they tell
you when Git can truly lose data and when it cannot.

## Mental model: the order form and the cleaner

- The **index** (`.git/index`) is an order form listing every path that will go
  into the next commit, with the blob hash for each. `git add` writes the blob
  and updates the line on the form.
- **Garbage collection** is a cleaner who throws out boxes that no sticky note
  (ref) or recent reflog entry leads to, but only after a grace period.

## See it work

### Look at the index

```bash
git ls-files -s
```

Expected output:

```
100644 fec56017dc1b1ac87ad6e54e3cb3a20bb8dcc5ab 0	README.md
100644 8b2fe5434fec16870a71cd8b272c7fcf6d352536 0	src/app.sh
```

Each line: mode, blob hash, **stage number**, path. Stage `0` is normal. During
a conflict a path has three entries instead:

| Stage | Holds |
|---|---|
| 1 | Common ancestor (merge base) version |
| 2 | "Ours" (HEAD) version |
| 3 | "Theirs" version |

That is what "unmerged" means, and why `git add` resolves a conflict: it
collapses stages 1-3 into one stage-0 entry. You can view each with
`git show :2:app.conf`.

`git add` already stores the blob in `.git/objects`. So even an edit that was
only staged (never committed) can sometimes be dug out later with `git fsck`.

### Loose objects and packfiles

```bash
git count-objects -v
```

Expected output in a fresh repo:

```
count: 5
size: 20
in-pack: 0
packs: 0
...
```

New objects start as individual **loose** files, zlib-compressed, under
`.git/objects/ab/cdef...` (first two hex characters = folder). Periodically
(`git gc`, or automatically) Git packs them into **packfiles** that store
similar objects as deltas. That is why a repo with a long history is still
small, and why "snapshots" do not waste space.

### Reachability: what can be lost

An object is **reachable** if you can walk to it from any ref (branches, tags,
remote-tracking refs, stash) or any reflog entry.

```
 refs ---> commits ---> trees ---> blobs        reachable: safe forever
 reflog -> old commits (after reset/rebase)      safe until the reflog entry expires
 nothing -> dangling objects                     removed by gc after a grace period
```

Default timers:

| Setting | Default | Meaning |
|---|---|---|
| `gc.reflogExpire` | 90 days | Reflog entries still reachable from the branch |
| `gc.reflogExpireUnreachable` | 30 days | Reflog entries for commits no longer on the branch (e.g. after `reset --hard`) |
| `gc.pruneExpire` | 2 weeks | Unreachable loose objects older than this can be deleted |

Find dangling objects (for example a dropped stash) with:

```bash
git fsck --lost-found       # lists dangling commits/blobs, copies them to .git/lost-found
```

What can **really** be lost: changes that were never staged or committed. Git
never saw them.

## Try it

You staged a file with `git add secret-draft.md`, then ran
`git reset --hard` before committing. Is the content recoverable?

<details>
<summary>Show answer</summary>

Probably yes, for about two weeks. `git add` wrote a blob. It is now dangling:

```bash
git fsck --lost-found
git show <dangling-blob-hash>
```

If you had never run `git add`, it would be gone.

</details>

## Common mistakes

- **Running `git gc --prune=now` in a panic.** It deletes exactly the
  unreachable objects you might need. Recover first, clean later.
- **Believing deleted branches are gone instantly.** Their commits stay in the
  reflog for weeks.
- **Committing huge binaries "just once".** Every version stays in history and
  every clone downloads it (Section 12 covers Git LFS).

## Remember

- The index lists path -> blob for the next commit; `git ls-files -s` shows it.
- Conflicts = stages 1 (base), 2 (ours), 3 (theirs) in the index.
- Loose objects get packed into delta-compressed packfiles.
- Reachable objects are safe; unreachable ones survive weeks via reflog/grace periods.
- Never-staged edits are the only thing Git truly cannot recover.

**Self-check:**

1. What does stage 2 hold during a conflict?
2. What makes an object reachable?
3. Which work can Git never recover?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f9c6c023-3368-50eb-bde8-3f297f6ed5ea', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'e0b3c433-037f-599c-a7bf-214e35421662', 'Lab: Explore Objects and Refs by Hand', 'notes', 3, $md$## Why this matters

Reading about objects and refs is abstract. In this lab you create a blob by
hand, walk from a commit to its tree and to an old file version, make a branch
by writing a ref, and rescue a commit that no branch points at. After this,
"rebase made new commits" and "reset moved the branch" will feel concrete.

```bash
cd ~/work/vault
git log --oneline --graph --all
```

Expected (hashes differ):

```
* 6c1d2e0 (HEAD -> main) Add key list
* 3b7a9f4 Go to production
* 91e0c55 (tag: v1) Switch to staging
* 0f2d8aa Initial vault
```

The "Detached experiment" commit does not appear: nothing points at it.

## Task 1: store a blob

Ask Git to hash the line `hello objects` **and write it** into the database.

[[lab-task:1]]

Check: `echo "hello objects" | git hash-object --stdin` prints a hash, and
`git cat-file -p <that hash>` prints `hello objects`.

## Task 2: find the root tree

Every commit points to one root tree. Save HEAD's tree hash into
`~/work/tree.txt`.

[[lab-task:2]]

Look inside it with `git cat-file -p 'HEAD^{tree}'`:

```
100644 blob ...	README.md
100644 blob ...	config.txt
100644 blob ...	keys.txt
```

## Task 3: a file in an old release

Use the `<rev>:<path>` syntax to get the blob of `config.txt` at tag `v1`, and
save its hash into `~/work/blob.txt`.

[[lab-task:3]]

Check: `git cat-file -p v1:config.txt` prints `mode=staging`, while
`cat config.txt` prints `mode=prod`.

## Task 4: a branch is just a ref

Create the branch `manual` at `main~1` with `git update-ref`.

[[lab-task:4]]

Check: `git show-ref` now lists `refs/heads/manual`.

## Task 5: rescue the lost commit

Find "Detached experiment" in the reflog and give it a branch named `rescued`.

[[lab-task:5]]

Expected snippet of `git reflog`:

```
6c1d2e0 HEAD@{0}: checkout: moving from 7a0e413... to main
7a0e413 HEAD@{1}: commit: Detached experiment
3b7a9f4 HEAD@{2}: checkout: moving from main to HEAD~1
```

## Remember

- `hash-object -w`, `cat-file -t/-p` and `rev-parse` let you inspect anything.
- `<rev>:<path>` names a file version; `<rev>^{tree}` names a snapshot.
- Branches are refs; the reflog keeps commits findable after refs move away.
$md$, 30, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('b53cde06-8936-588a-96d2-50fbbc77bb3f', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'f9c6c023-3368-50eb-bde8-3f297f6ed5ea', 'module', 'Lab: Explore Objects and Refs by Hand', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
rm -rf /home/labuser/work/vault /home/labuser/work/tree.txt /home/labuser/work/blob.txt
mkdir -p /home/labuser/work/vault && cd /home/labuser/work/vault
git init -q
M() { git add -A; GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
echo "# Vault" > README.md; echo "mode=dev" > config.txt; M 2024-08-01 "Initial vault"
echo "mode=staging" > config.txt; M 2024-08-02 "Switch to staging"
GIT_COMMITTER_DATE="2024-08-02T12:00:00+0000" git tag -a v1 -m "Release 1"
echo "mode=prod" > config.txt; M 2024-08-03 "Go to production"
echo "keys" > keys.txt; M 2024-08-04 "Add key list"
git switch -q --detach HEAD~1
echo "experiment" > experiment.txt; M 2024-08-05 "Detached experiment"
git switch -q main 2>/dev/null
chmod -R a+rwX /home/labuser/work/vault
$script$, NULL, 40, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '8d4746fc-546f-5132-b6a6-ca3f976674c4' AND id NOT IN ('05e28d0f-4f57-5293-8852-e52956ad0202', 'd7c653b3-1801-5a64-99e7-8d7a1b1abdd3', '0b372f93-06e1-5585-8303-647dff557f0f', '4cbb0922-74d9-5cc9-be1b-390e9df2d3ea', 'b115011b-d71c-5908-8b0e-4441fe2e1b54');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '8d4746fc-546f-5132-b6a6-ca3f976674c4';
DELETE FROM lab_tasks WHERE lab_id = 'b53cde06-8936-588a-96d2-50fbbc77bb3f' AND id NOT IN ('3766ebac-7082-506a-ab22-0ba3ebb1d542', '29637af5-9fe8-5f4d-8f8d-0e8241564392', '5d07838b-46f4-5b42-aff3-5ae12a2d4e6a', 'c4852031-1ecd-5cfe-8aed-30f8191f21aa', '147715f7-923a-5b61-b961-caac49cfed74');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'b53cde06-8936-588a-96d2-50fbbc77bb3f';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('3766ebac-7082-506a-ab22-0ba3ebb1d542', 'b53cde06-8936-588a-96d2-50fbbc77bb3f', 1, 'Store a blob by hand', $md$In ~/work/vault, write a blob whose content is the line "hello objects" (with a trailing newline, as echo produces) straight into the object database, without creating any file or commit.$md$, $script$r=/home/labuser/work/vault
h=$(printf 'hello objects\n' | git -C $r hash-object --stdin)
git -C $r cat-file -e "$h" 2>/dev/null &&
[ "$(git -C $r cat-file -t "$h")" = blob ]
$script$, 'git hash-object --stdin only prints the hash; add -w to write the object. Pipe the content in with echo.', 'hash-object -w stores content as a loose blob under .git/objects and prints its hash. Nothing references it yet, so it is a dangling object that gc may eventually prune.', 10, false, true),
('29637af5-9fe8-5f4d-8f8d-0e8241564392', 'b53cde06-8936-588a-96d2-50fbbc77bb3f', 2, 'Find the root tree of HEAD', $md$Write the full hash of the root tree object of the current HEAD commit, alone on one line, into ~/work/tree.txt.$md$, $script$r=/home/labuser/work/vault
[ "$(tr -d '[:space:]' < /home/labuser/work/tree.txt)" = "$(git -C $r rev-parse 'HEAD^{tree}')" ]
$script$, 'git cat-file -p HEAD prints the commit; its first line is "tree <hash>". git rev-parse ''HEAD^{tree}'' gives the same hash directly.', 'Every commit points to exactly one root tree, the snapshot of the whole project. The tree lists names and points to blobs and subtrees.', 10, false, true),
('5d07838b-46f4-5b42-aff3-5ae12a2d4e6a', 'b53cde06-8936-588a-96d2-50fbbc77bb3f', 3, 'Find a file''s blob in an older release', $md$The annotated tag v1 marks an older release. Write the full blob hash of config.txt as it was at v1, alone on one line, into ~/work/blob.txt.$md$, $script$r=/home/labuser/work/vault
[ "$(tr -d '[:space:]' < /home/labuser/work/blob.txt)" = "$(git -C $r rev-parse v1:config.txt)" ]
$script$, 'The <rev>:<path> syntax names the blob for a path in a commit. git rev-parse v1:config.txt prints its hash; git cat-file -p v1:config.txt shows its content (mode=staging).', 'v1 is a tag object; Git peels it to the commit, then to the root tree, then looks up config.txt in that tree. Different content means a different blob than today''s config.txt.', 15, false, true),
('c4852031-1ecd-5cfe-8aed-30f8191f21aa', 'b53cde06-8936-588a-96d2-50fbbc77bb3f', 4, 'Create a branch with update-ref', $md$Create a branch named manual that points at the commit one before main's tip (main~1). Use git update-ref to see that a branch is only a ref holding a hash.$md$, $script$r=/home/labuser/work/vault
[ "$(git -C $r rev-parse --verify -q refs/heads/manual)" = "$(git -C $r rev-parse main~1)" ]
$script$, 'git update-ref refs/heads/manual main~1. Then git log --oneline --all --graph shows the new label.', 'update-ref writes a hash into a ref (and records it in the reflog). git branch manual main~1 does the same thing with a friendlier interface.', 10, false, true),
('147715f7-923a-5b61-b961-caac49cfed74', 'b53cde06-8936-588a-96d2-50fbbc77bb3f', 5, 'Rescue a commit made on a detached HEAD', $md$Someone made a commit "Detached experiment" on a detached HEAD and then switched back to main, so no branch points at it. Create a branch named rescued that points at that commit.$md$, $script$r=/home/labuser/work/vault
[ "$(git -C $r log -1 --format=%s rescued 2>/dev/null)" = "Detached experiment" ] &&
git -C $r show rescued:experiment.txt | grep -qx experiment
$script$, 'git reflog lists every position HEAD has had, including the line "commit: Detached experiment". Copy that hash and run git branch rescued <hash>.', 'The commit was never lost, only unreferenced. The HEAD reflog still points to it, and a new branch makes it reachable again so garbage collection will never remove it.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('8d4746fc-546f-5132-b6a6-ca3f976674c4', 'b53cde06-8936-588a-96d2-50fbbc77bb3f', 1, $json$[{"id":"3766ebac-7082-506a-ab22-0ba3ebb1d542","lab_id":"b53cde06-8936-588a-96d2-50fbbc77bb3f","position":1,"title":"Store a blob by hand","description":"In ~/work/vault, write a blob whose content is the line \"hello objects\" (with a trailing newline, as echo produces) straight into the object database, without creating any file or commit.","verification_script":"r=/home/labuser/work/vault\nh=$(printf 'hello objects\\n' | git -C $r hash-object --stdin)\ngit -C $r cat-file -e \"$h\" 2\u003e/dev/null \u0026\u0026\n[ \"$(git -C $r cat-file -t \"$h\")\" = blob ]\n","hint_context":"git hash-object --stdin only prints the hash; add -w to write the object. Pipe the content in with echo.","explanation_context":"hash-object -w stores content as a loose blob under .git/objects and prints its hash. Nothing references it yet, so it is a dangling object that gc may eventually prune.","points":10,"is_optional":false,"is_stateful":true},{"id":"29637af5-9fe8-5f4d-8f8d-0e8241564392","lab_id":"b53cde06-8936-588a-96d2-50fbbc77bb3f","position":2,"title":"Find the root tree of HEAD","description":"Write the full hash of the root tree object of the current HEAD commit, alone on one line, into ~/work/tree.txt.","verification_script":"r=/home/labuser/work/vault\n[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/tree.txt)\" = \"$(git -C $r rev-parse 'HEAD^{tree}')\" ]\n","hint_context":"git cat-file -p HEAD prints the commit; its first line is \"tree \u003chash\u003e\". git rev-parse 'HEAD^{tree}' gives the same hash directly.","explanation_context":"Every commit points to exactly one root tree, the snapshot of the whole project. The tree lists names and points to blobs and subtrees.","points":10,"is_optional":false,"is_stateful":true},{"id":"5d07838b-46f4-5b42-aff3-5ae12a2d4e6a","lab_id":"b53cde06-8936-588a-96d2-50fbbc77bb3f","position":3,"title":"Find a file's blob in an older release","description":"The annotated tag v1 marks an older release. Write the full blob hash of config.txt as it was at v1, alone on one line, into ~/work/blob.txt.","verification_script":"r=/home/labuser/work/vault\n[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/blob.txt)\" = \"$(git -C $r rev-parse v1:config.txt)\" ]\n","hint_context":"The \u003crev\u003e:\u003cpath\u003e syntax names the blob for a path in a commit. git rev-parse v1:config.txt prints its hash; git cat-file -p v1:config.txt shows its content (mode=staging).","explanation_context":"v1 is a tag object; Git peels it to the commit, then to the root tree, then looks up config.txt in that tree. Different content means a different blob than today's config.txt.","points":15,"is_optional":false,"is_stateful":true},{"id":"c4852031-1ecd-5cfe-8aed-30f8191f21aa","lab_id":"b53cde06-8936-588a-96d2-50fbbc77bb3f","position":4,"title":"Create a branch with update-ref","description":"Create a branch named manual that points at the commit one before main's tip (main~1). Use git update-ref to see that a branch is only a ref holding a hash.","verification_script":"r=/home/labuser/work/vault\n[ \"$(git -C $r rev-parse --verify -q refs/heads/manual)\" = \"$(git -C $r rev-parse main~1)\" ]\n","hint_context":"git update-ref refs/heads/manual main~1. Then git log --oneline --all --graph shows the new label.","explanation_context":"update-ref writes a hash into a ref (and records it in the reflog). git branch manual main~1 does the same thing with a friendlier interface.","points":10,"is_optional":false,"is_stateful":true},{"id":"147715f7-923a-5b61-b961-caac49cfed74","lab_id":"b53cde06-8936-588a-96d2-50fbbc77bb3f","position":5,"title":"Rescue a commit made on a detached HEAD","description":"Someone made a commit \"Detached experiment\" on a detached HEAD and then switched back to main, so no branch points at it. Create a branch named rescued that points at that commit.","verification_script":"r=/home/labuser/work/vault\n[ \"$(git -C $r log -1 --format=%s rescued 2\u003e/dev/null)\" = \"Detached experiment\" ] \u0026\u0026\ngit -C $r show rescued:experiment.txt | grep -qx experiment\n","hint_context":"git reflog lists every position HEAD has had, including the line \"commit: Detached experiment\". Copy that hash and run git branch rescued \u003chash\u003e.","explanation_context":"The commit was never lost, only unreferenced. The HEAD reflog still points to it, and a new branch makes it reachable again so garbage collection will never remove it.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('05e28d0f-4f57-5293-8852-e52956ad0202', '8d4746fc-546f-5132-b6a6-ca3f976674c4', '3766ebac-7082-506a-ab22-0ba3ebb1d542', 1, 'Store a blob by hand', $md$In ~/work/vault, write a blob whose content is the line "hello objects" (with a trailing newline, as echo produces) straight into the object database, without creating any file or commit.$md$, $script$r=/home/labuser/work/vault
h=$(printf 'hello objects\n' | git -C $r hash-object --stdin)
git -C $r cat-file -e "$h" 2>/dev/null &&
[ "$(git -C $r cat-file -t "$h")" = blob ]
$script$, 'git hash-object --stdin only prints the hash; add -w to write the object. Pipe the content in with echo.', 'hash-object -w stores content as a loose blob under .git/objects and prints its hash. Nothing references it yet, so it is a dangling object that gc may eventually prune.', 10, false, true),
('d7c653b3-1801-5a64-99e7-8d7a1b1abdd3', '8d4746fc-546f-5132-b6a6-ca3f976674c4', '29637af5-9fe8-5f4d-8f8d-0e8241564392', 2, 'Find the root tree of HEAD', $md$Write the full hash of the root tree object of the current HEAD commit, alone on one line, into ~/work/tree.txt.$md$, $script$r=/home/labuser/work/vault
[ "$(tr -d '[:space:]' < /home/labuser/work/tree.txt)" = "$(git -C $r rev-parse 'HEAD^{tree}')" ]
$script$, 'git cat-file -p HEAD prints the commit; its first line is "tree <hash>". git rev-parse ''HEAD^{tree}'' gives the same hash directly.', 'Every commit points to exactly one root tree, the snapshot of the whole project. The tree lists names and points to blobs and subtrees.', 10, false, true),
('0b372f93-06e1-5585-8303-647dff557f0f', '8d4746fc-546f-5132-b6a6-ca3f976674c4', '5d07838b-46f4-5b42-aff3-5ae12a2d4e6a', 3, 'Find a file''s blob in an older release', $md$The annotated tag v1 marks an older release. Write the full blob hash of config.txt as it was at v1, alone on one line, into ~/work/blob.txt.$md$, $script$r=/home/labuser/work/vault
[ "$(tr -d '[:space:]' < /home/labuser/work/blob.txt)" = "$(git -C $r rev-parse v1:config.txt)" ]
$script$, 'The <rev>:<path> syntax names the blob for a path in a commit. git rev-parse v1:config.txt prints its hash; git cat-file -p v1:config.txt shows its content (mode=staging).', 'v1 is a tag object; Git peels it to the commit, then to the root tree, then looks up config.txt in that tree. Different content means a different blob than today''s config.txt.', 15, false, true),
('4cbb0922-74d9-5cc9-be1b-390e9df2d3ea', '8d4746fc-546f-5132-b6a6-ca3f976674c4', 'c4852031-1ecd-5cfe-8aed-30f8191f21aa', 4, 'Create a branch with update-ref', $md$Create a branch named manual that points at the commit one before main's tip (main~1). Use git update-ref to see that a branch is only a ref holding a hash.$md$, $script$r=/home/labuser/work/vault
[ "$(git -C $r rev-parse --verify -q refs/heads/manual)" = "$(git -C $r rev-parse main~1)" ]
$script$, 'git update-ref refs/heads/manual main~1. Then git log --oneline --all --graph shows the new label.', 'update-ref writes a hash into a ref (and records it in the reflog). git branch manual main~1 does the same thing with a friendlier interface.', 10, false, true),
('b115011b-d71c-5908-8b0e-4441fe2e1b54', '8d4746fc-546f-5132-b6a6-ca3f976674c4', '147715f7-923a-5b61-b961-caac49cfed74', 5, 'Rescue a commit made on a detached HEAD', $md$Someone made a commit "Detached experiment" on a detached HEAD and then switched back to main, so no branch points at it. Create a branch named rescued that points at that commit.$md$, $script$r=/home/labuser/work/vault
[ "$(git -C $r log -1 --format=%s rescued 2>/dev/null)" = "Detached experiment" ] &&
git -C $r show rescued:experiment.txt | grep -qx experiment
$script$, 'git reflog lists every position HEAD has had, including the line "commit: Detached experiment". Copy that hash and run git branch rescued <hash>.', 'The commit was never lost, only unreferenced. The HEAD reflog still points to it, and a new branch makes it reachable again so garbage collection will never remove it.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '8d4746fc-546f-5132-b6a6-ca3f976674c4', updated_at = now()
WHERE id = 'b53cde06-8936-588a-96d2-50fbbc77bb3f' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f9695cae-b185-5907-8d49-22e9b02fb074', '00000000-0000-0000-0000-000000000001', 'mcq', 'You rename src/util.py to src/helpers.py without changing its content and com...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1e6dca6f-b791-5525-a380-7cd2d57fc66d', 'f9695cae-b185-5907-8d49-22e9b02fb074', 1, $json${"prompt":"You rename src/util.py to src/helpers.py without changing its content and commit. Which new objects does Git create?","multiple":false,"options":[{"id":"a","text":"A new blob for the file, a new tree and a new commit","is_correct":false},{"id":"b","text":"New trees (src and root) and a new commit; the blob is reused because the content is identical","is_correct":true},{"id":"c","text":"Only a new commit","is_correct":false},{"id":"d","text":"Nothing; renames are stored in the index only","is_correct":false}],"explanation":"Blobs hold content only, so the same content keeps the same blob. Names live in trees, so the src tree and the root tree change, and a new commit points at the new root tree."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ea2e8005-ff5a-5bce-826e-a5848adfe245', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which object type stores the commit message and the parent hashes?', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('fec1fa98-e144-52a7-a22a-8f94d0558522', 'ea2e8005-ff5a-5bce-826e-a5848adfe245', 1, $json${"prompt":"Which object type stores the commit message and the parent hashes?","multiple":false,"options":[{"id":"a","text":"blob","is_correct":false},{"id":"b","text":"tree","is_correct":false},{"id":"c","text":"commit","is_correct":true},{"id":"d","text":"ref","is_correct":false}],"explanation":"A commit object contains tree, parent(s), author, committer and message. Blobs hold file bytes, trees hold names, and refs are not objects at all, just names pointing at objects."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cf888ca1-49b7-5724-a0d8-5df2c905e87d', '00000000-0000-0000-0000-000000000001', 'mcq', 'You checked out an old commit by hash, made two commits, then ran `git switch...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c80f0d9b-8edc-56e7-a179-da9220e710b1', 'cf888ca1-49b7-5724-a0d8-5df2c905e87d', 1, $json${"prompt":"You checked out an old commit by hash, made two commits, then ran `git switch main`. Git warns you are leaving 2 commits behind. How do you keep them?","multiple":false,"options":[{"id":"a","text":"They are already on main","is_correct":false},{"id":"b","text":"Find them in `git reflog` and run `git branch keep \u003chash\u003e`","is_correct":true},{"id":"c","text":"Run git gc so they are saved","is_correct":false},{"id":"d","text":"They are lost permanently","is_correct":false}],"explanation":"Commits on a detached HEAD belong to no branch, but the HEAD reflog remembers them. A branch makes them reachable again. gc does the opposite (prunes), and they are not on main."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('df756e9e-4a80-508e-b991-066e7e614653', '00000000-0000-0000-0000-000000000001', 'mcq', 'M is a merge commit. What does `git show M^2` show?', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0730ceed-36f3-5c1f-b0b4-0536a2f8b2fe', 'df756e9e-4a80-508e-b991-066e7e614653', 1, $json${"prompt":"M is a merge commit. What does `git show M^2` show?","multiple":false,"options":[{"id":"a","text":"The commit two generations before M on the first-parent line","is_correct":false},{"id":"b","text":"The second parent of M, i.e. the tip of the branch that was merged in","is_correct":true},{"id":"c","text":"The second file changed in M","is_correct":false},{"id":"d","text":"Nothing; ^2 is invalid","is_correct":false}],"explanation":"^n picks the nth parent; ~n walks n generations back along first parents. M~2 would be the grandparent on the main line."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('22b65fe6-00f0-5bdc-96bc-71177d6a415d', '00000000-0000-0000-0000-000000000001', 'mcq', 'During a merge conflict, `git ls-files -s app.conf` prints three lines with s...', 'advanced', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f59580f2-10a1-56bb-bb66-dde19adb6f20', '22b65fe6-00f0-5bdc-96bc-71177d6a415d', 1, $json${"prompt":"During a merge conflict, `git ls-files -s app.conf` prints three lines with stage numbers 1, 2 and 3. What is stage 3?","multiple":false,"options":[{"id":"a","text":"The common ancestor version","is_correct":false},{"id":"b","text":"Your version (HEAD)","is_correct":false},{"id":"c","text":"The incoming branch's version (theirs)","is_correct":true},{"id":"d","text":"The working-tree version","is_correct":false}],"explanation":"Stage 1 = merge base, 2 = ours, 3 = theirs. The working tree file is not in the index at all; it is what you edit."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('925afe32-ec50-53a4-a49b-f99a76a6f195', '00000000-0000-0000-0000-000000000001', 'mcq', 'A teammate ran `git reset --hard HEAD~3` an hour ago and now needs those comm...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('08199b7e-0d24-5bc1-b91d-70418932607e', '925afe32-ec50-53a4-a49b-f99a76a6f195', 1, $json${"prompt":"A teammate ran `git reset --hard HEAD~3` an hour ago and now needs those commits. Which statement is correct?","multiple":false,"options":[{"id":"a","text":"They are gone; reset --hard deletes commits immediately","is_correct":false},{"id":"b","text":"They are still in the object database and listed in the reflog; recover with git reflog and git reset --hard \u003chash\u003e","is_correct":true},{"id":"c","text":"Only a remote can restore them","is_correct":false},{"id":"d","text":"git gc --prune=now will restore them","is_correct":false}],"explanation":"reset only moves a ref. The commits stay reachable from the reflog (30 days by default for unreachable entries). gc --prune=now would remove unreachable objects, the opposite of what you want."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('290ae3c8-9d40-5657-b9de-72f5051d2567', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which kind of work can Git NOT recover?', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ca11fe2c-abf7-5e31-870e-33d89ddfdec5', '290ae3c8-9d40-5657-b9de-72f5051d2567', 1, $json${"prompt":"Which kind of work can Git NOT recover?","multiple":false,"options":[{"id":"a","text":"A commit removed by reset --hard","is_correct":false},{"id":"b","text":"A deleted branch's commits","is_correct":false},{"id":"c","text":"Edits you never staged or committed, discarded by git restore or reset --hard","is_correct":true},{"id":"d","text":"A commit dropped during interactive rebase","is_correct":false}],"explanation":"Git only knows about content it stored. Never-staged edits were never written as objects. All the others are still reachable via the reflog for weeks."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b5644819-bd39-5f8e-bb38-8dcc6e4de195', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 6): during a MERGE conflict, what does `git checkout --ours f...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bb321ff5-2ac3-5a4f-a822-d7254a346b54', 'b5644819-bd39-5f8e-bb38-8dcc6e4de195', 1, $json${"prompt":"Review (Section 6): during a MERGE conflict, what does `git checkout --ours file` keep?","multiple":false,"options":[{"id":"a","text":"The version from the branch you are on (HEAD)","is_correct":true},{"id":"b","text":"The version from the branch being merged in","is_correct":false},{"id":"c","text":"The merge base version","is_correct":false},{"id":"d","text":"The version with conflict markers","is_correct":false}],"explanation":"In a merge, ours = HEAD = the current branch. (In a rebase it flips, which the next section covers.)"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('9368be0b-d21a-5f46-9a75-36316805f823', '00000000-0000-0000-0000-000000000001', 'Quiz: Under the Hood', 'git-internals-quiz', 'Quiz covering Under the Hood: Objects, Refs and the Index.', 'mcq', 'published', 'module', 'e5a7bc3d-8d91-5d20-aae7-6d0e4957ad07', 12, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '9368be0b-d21a-5f46-9a75-36316805f823' AND question_id NOT IN ('f9695cae-b185-5907-8d49-22e9b02fb074', 'ea2e8005-ff5a-5bce-826e-a5848adfe245', 'cf888ca1-49b7-5724-a0d8-5df2c905e87d', 'df756e9e-4a80-508e-b991-066e7e614653', '22b65fe6-00f0-5bdc-96bc-71177d6a415d', '925afe32-ec50-53a4-a49b-f99a76a6f195', '290ae3c8-9d40-5657-b9de-72f5051d2567', 'b5644819-bd39-5f8e-bb38-8dcc6e4de195');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('fe45bab8-99c0-55e2-8199-e945c8a24ded', '9368be0b-d21a-5f46-9a75-36316805f823', 'f9695cae-b185-5907-8d49-22e9b02fb074', '1e6dca6f-b791-5525-a380-7cd2d57fc66d', 0, 2),
('02ec0314-e9f1-5cb3-a550-92e1e983e617', '9368be0b-d21a-5f46-9a75-36316805f823', 'ea2e8005-ff5a-5bce-826e-a5848adfe245', 'fec1fa98-e144-52a7-a22a-8f94d0558522', 1, 2),
('a0adb385-97e5-5a96-a71f-cc6d30dfecb8', '9368be0b-d21a-5f46-9a75-36316805f823', 'cf888ca1-49b7-5724-a0d8-5df2c905e87d', 'c80f0d9b-8edc-56e7-a179-da9220e710b1', 2, 2),
('97136f6e-976f-59bb-a3e7-c9f1378630ff', '9368be0b-d21a-5f46-9a75-36316805f823', 'df756e9e-4a80-508e-b991-066e7e614653', '0730ceed-36f3-5c1f-b0b4-0536a2f8b2fe', 3, 2),
('f54bc6c3-a050-5dad-9dbc-cb2145d1da7a', '9368be0b-d21a-5f46-9a75-36316805f823', '22b65fe6-00f0-5bdc-96bc-71177d6a415d', 'f59580f2-10a1-56bb-bb66-dde19adb6f20', 4, 2),
('2a3e7d7f-9caa-512e-a0e0-a4fb67960890', '9368be0b-d21a-5f46-9a75-36316805f823', '925afe32-ec50-53a4-a49b-f99a76a6f195', '08199b7e-0d24-5bc1-b91d-70418932607e', 5, 2),
('8225842d-166c-5163-a163-4fa58560d85e', '9368be0b-d21a-5f46-9a75-36316805f823', '290ae3c8-9d40-5657-b9de-72f5051d2567', 'ca11fe2c-abf7-5e31-870e-33d89ddfdec5', 6, 2),
('72c36e10-3b58-505c-916c-77a5969557b4', '9368be0b-d21a-5f46-9a75-36316805f823', 'b5644819-bd39-5f8e-bb38-8dcc6e4de195', 'bb321ff5-2ac3-5a4f-a822-d7254a346b54', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('e5a7bc3d-8d91-5d20-aae7-6d0e4957ad07', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'e0b3c433-037f-599c-a7bf-214e35421662', 'Quiz: Under the Hood', 'assessment', 4, 10, '9368be0b-d21a-5f46-9a75-36316805f823')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Rebase and Rewriting History
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('bc66d97b-4855-5638-8fbb-d9d46ae7f1b7', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Rebase and Rewriting History', 8, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('06333fa0-0a73-5674-8283-1273b143ddca', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'bc66d97b-4855-5638-8fbb-d9d46ae7f1b7', 'Rebase: Replay Your Commits on a New Base', 'notes', 0, $md$## Why this matters

Review day. Maya asks: "Put your branch on top of the latest main so the review
shows only your changes." Merging main into your branch works but adds noisy
merge commits. **Rebase** moves your commits so they start from main's tip,
giving a straight, easy-to-read history.

## Mental model: re-applying your edits to a fresh printout

You wrote edits on a printout of a document. Meanwhile the original was updated.
Rebase takes a fresh printout and re-applies your edits, one by one, in order.
The edits are the same ideas, but they are now on new paper. In Git terms:
**new commits with new hashes**.

```
BEFORE                                AFTER  git switch feature; git rebase main

 A---B---C---D  <- main                A---B---C---D  <- main
      \                                              \
       E---F  <- feature                              E'---F'  <- feature
                                       (E and F are replaced by copies E' and F')
```

What Git does internally:

1. Find the commits on `feature` that are not on `main` (E, F).
2. Move `feature` to `main`'s tip (D).
3. Re-apply E's changes as a new commit E', then F's as F'.

The old E and F still exist (reachable from the reflog), just no longer on the
branch. Remember from Section 7: objects never change; rebase makes new ones and
moves a ref.

## See it work

```bash
cd ~/work/blog
git switch feature/comments
git rebase main
git log --oneline --graph --all
```

Expected output:

```
* 7c3a2e9 (HEAD -> feature/comments) Add comment form
* 0f6b18d Add comments page
* b1e47a0 (main) Rename title to Dev Blog
* 5d9c30f Add footer
* 2a8f6c1 Add about page
* e0d31b7 Initial blog
```

A straight line. If `main` is merged with `feature/comments` now, it is a
fast-forward.

```knowledge-check
{ "questions": [
  { "id": "git-rebase-basic-q1", "type": "mcq",
    "prompt": "After git rebase main, the commits of your feature branch...",
    "options": [
      {"id":"a","text":"Keep exactly the same hashes"},
      {"id":"b","text":"Are replaced by new commits with new hashes on top of main"},
      {"id":"c","text":"Are deleted"},
      {"id":"d","text":"Are merged into one commit"}],
    "correct": "b",
    "explanation": "Each commit has a new parent, so a new hash. The old commits remain in the reflog, nothing is deleted, and plain rebase keeps them as separate commits." }
] }
```

### Conflicts during a rebase

Rebase applies commits one at a time, so a conflict stops it **on the commit
that cannot apply**. You have three choices:

```
 git rebase main  --> CONFLICT while applying E
      |
      +-- fix files, git add, git rebase --continue   (carry on with next commit)
      +-- git rebase --skip                           (drop this commit)
      +-- git rebase --abort                          (go back to before the rebase)
```

Expected output when it stops:

```
Auto-merging index.md
CONFLICT (content): Merge conflict in index.md
error: could not apply 3e5f1aa... Rename blog title
hint: Resolve all conflicts manually, mark them as resolved with
hint: "git add/rm <conflicted_files>", then run "git rebase --continue".
```

```bash
# edit index.md, then
git add index.md
GIT_EDITOR=true git rebase --continue    # GIT_EDITOR=true keeps the message without opening an editor
```

Expected: `Successfully rebased and updated refs/heads/feature/title.`

**The labels flip.** During a rebase, "ours" (HEAD) is the branch you are
rebasing **onto** (main plus already-replayed commits), and "theirs" is **your**
commit being replayed. The opposite of a merge. So `git checkout --theirs file`
during a rebase keeps *your* version.

```knowledge-check
{ "questions": [
  { "id": "git-rebase-conflict-q1", "type": "mcq",
    "prompt": "During a rebase conflict, which command gives up and restores the branch to its pre-rebase state?",
    "options": [
      {"id":"a","text":"git rebase --continue"},
      {"id":"b","text":"git rebase --abort"},
      {"id":"c","text":"git reset --hard origin/main"},
      {"id":"d","text":"git rebase --skip"}],
    "correct": "b",
    "explanation": "--skip would drop the commit being applied; --abort undoes the whole rebase. --continue carries on, and reset --hard origin/main would throw your branch's work away." }
] }
```

## Try it

Your branch has 5 commits. While rebasing onto main, commit 3 conflicts. After
you resolve it and run `--continue`, can commits 4 and 5 conflict too?

<details>
<summary>Show answer</summary>

Yes. Each commit is replayed separately, so each can stop with its own conflict.
That is why long-lived branches with many commits are painful to rebase, and
why squashing first (lesson 3) or enabling rerere helps.

</details>

## Common mistakes

- **Running `git commit` in the middle of a rebase.** Use `git rebase --continue`;
  it creates the commit for you.
- **Forgetting you are mid-rebase.** `git status` says
  `interactive rebase in progress; onto b1e47a0`. Finish or abort before doing
  anything else.
- **Mixing up ours/theirs.** Rebase flips them. Read the file, not the label.
- **Rebasing a branch others use.** Lesson 4 explains why that hurts.

## Remember

- Rebase = replay your commits on a new base; they get new hashes.
- Conflicts stop on one commit: fix, `git add`, `git rebase --continue`.
- `--abort` returns to exactly where you started; `--skip` drops the current commit.
- In a rebase, ours = the new base, theirs = your commit.

**Self-check:**

1. Why do rebased commits get new hashes?
2. What are the three ways out of a rebase conflict?
3. In a rebase, what does `--theirs` refer to?
$md$, 9, $json$[{"id":"git-rebase-basic-q1","type":"mcq","correct":"b"},{"id":"git-rebase-conflict-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('55df3884-66ec-5229-87e6-269aac20c1fb', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'bc66d97b-4855-5638-8fbb-d9d46ae7f1b7', 'Rebase vs Merge: When to Use Which', 'notes', 1, $md$## Why this matters

"Should we rebase or merge?" starts arguments on every team and comes up in
interviews. Both integrate work; they differ in what history they leave
behind and in who they can hurt. The real answer is a simple rule plus a team
convention.

## Mental model: diary vs edited book

- **Merge** keeps the **diary**: exactly what happened, including that two
  people worked in parallel. Honest, but messy to read.
- **Rebase** produces an **edited book**: the story retold in a clean order, as
  if you started from the latest main. Easy to read, but rewritten.

```
 merge:   A---B---D---M          rebase:   A---B---D---C'---E'
           \       /                       (C, E replaced by copies)
            C-----E
```

## Side by side

| | Merge | Rebase |
|---|---|---|
| History shape | Branches and merge commits | Straight line |
| Existing commits | Untouched | Replaced by copies (new hashes) |
| Safe on shared branches | Yes | **No** (rewrites what others have) |
| Conflicts | Resolved once, in the merge commit | Possibly once per replayed commit |
| `git bisect` / `git log` | Works, graph is busier | Easy, linear |
| Shows "when work happened in parallel" | Yes | No |

### The golden rule

> **Never rebase commits that other people have already based work on.**

Rebasing your own local or personal feature branch: fine. Rebasing `main`, or a
branch your teammate has pulled and committed on: they now have the old
commits, you have the new copies, and their next pull duplicates or conflicts
everything.

## See it work

### The common team convention

1. Work on a feature branch.
2. Keep it current with **rebase** onto `origin/main` (your private branch, so
   rewriting is fine).
3. Integrate into `main` with a **merge** (or the host's "squash" / "rebase and
   merge" button). `main` itself is never rewritten.

```bash
git fetch
git rebase origin/main            # update my feature branch
git push --force-with-lease       # update my PR branch (lesson 4)
```

### pull --rebase for small local changes

You made one commit on `main` while a teammate pushed. Instead of a merge
commit "Merge branch 'main' of ...":

```bash
git pull --rebase
```

What this does: fetch, then replay **your unpushed** commits on top of
`origin/main`. Your commits were never shared, so rewriting them is safe.

```
 before:  origin/main A---B---T      your main A---B---N
 after :  your main   A---B---T---N'   (no merge commit)
```

Make it the default with `git config --global pull.rebase true`. Add
`git config --global rebase.autoStash true` so Git stashes uncommitted edits
around the rebase automatically.

### When to prefer merge

- Integrating a long-lived branch with many authors.
- When you need an exact record (regulated environments, release branches).
- When the branch is already shared and you are not its only user.

## Try it

You and Priya both commit on `feature/report`, which you both push to. You want
the latest `main` in it. Rebase or merge?

<details>
<summary>Show answer</summary>

**Merge** `main` into `feature/report` (or agree with Priya first). The branch
is shared, so rebasing would rewrite commits Priya already has. If you really
want a rebase, coordinate: she pushes everything, you rebase and
force-with-lease, she resets her copy to the new branch.

</details>

## Common mistakes

- **"Rebase is always better."** It is cleaner, not safer. On shared branches it
  causes real damage.
- **"Merge commits are bad."** A merge commit per feature is a useful,
  revertable unit. What teams dislike is the noise of accidental
  "Merge branch 'main' of ..." commits from habitual pulls.
- **Rebasing a branch that contains merges.** Plain rebase flattens them. Use
  `git rebase --rebase-merges` if you must keep them.

## Remember

- Merge preserves history; rebase rewrites it into a line.
- Golden rule: never rebase commits others have built on.
- Typical flow: rebase your feature branch, merge into main.
- `pull.rebase true` (+ `rebase.autoStash true`) avoids noisy pull merges.

**Self-check:**

1. State the golden rule of rebasing.
2. Name one advantage of each approach.
3. Why is `git pull --rebase` safe for unpushed commits?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('48da31e4-f78a-5e0d-9848-adb9a0866d71', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'bc66d97b-4855-5638-8fbb-d9d46ae7f1b7', 'Interactive Rebase: Squash, Reorder, Reword, Drop', 'notes', 2, $md$## Why this matters

While working you commit "wip", "fix typo", "really fix it". Reviewers and
future readers (and `git bisect`) want a short story of clean, meaningful
commits. Interactive rebase lets you edit your branch's history like a to-do
list before anyone else sees it.

## Mental model: editing a playlist

`git rebase -i main` shows your branch's commits as a playlist, **oldest at the
top**. You edit the list (reorder lines, change the verb in front of each), save,
and Git replays the playlist exactly as written.

```
 pick   1111 wip: profile skeleton        pick   1111 wip: profile skeleton
 pick   2222 wip: add avatar        -->   fixup  3333 fix typo in profile
 pick   3333 fix typo in profile          fixup  4444 wip: bio
 pick   4444 wip: bio                     pick   2222 wip: add avatar
```

```
BEFORE (4 commits)                  AFTER (2 commits)

 main---P1---P2---P3---P4            main---P1'---P2'
        skel avatar typo bio              skel+typo+bio  avatar
```

## See it work

### The verbs

| Verb | Short | Effect |
|---|---|---|
| `pick` | `p` | Keep the commit as is |
| `reword` | `r` | Keep content, edit the message |
| `edit` | `e` | Stop after applying, so you can amend or split it |
| `squash` | `s` | Meld into the commit above; combine both messages |
| `fixup` | `f` | Meld into the commit above; discard this message |
| `drop` | `d` | Delete the commit (or just delete the line) |
| `exec` | `x` | Run a shell command, e.g. `x npm test`; stop if it fails |

Reordering lines reorders commits. Commits touching different files reorder
without conflicts.

### Run it

```bash
git switch feature/profile
git rebase -i main
```

Git opens your editor with the list. Edit, save, close. Expected result:

```
* 91c0d4e (HEAD -> feature/profile) Add profile avatar
* 6a2fb85 Add profile page
* b1e47a0 (main) Rename title to Dev Blog
```

Prefer `git rebase -i main` (or `origin/main`) over `HEAD~N`: it always picks
exactly the commits on your branch.

```knowledge-check
{ "questions": [
  { "id": "git-rebase-interactive-q1", "type": "mcq",
    "prompt": "What is the difference between squash and fixup in an interactive rebase?",
    "options": [
      {"id":"a","text":"squash keeps and combines the commit message, fixup discards it"},
      {"id":"b","text":"fixup deletes the file"},
      {"id":"c","text":"They are identical"},
      {"id":"d","text":"squash pushes to the remote"}],
    "correct": "a",
    "explanation": "Both meld the commit into the previous one; only squash lets you keep its message. Neither deletes files or pushes." }
] }
```

### Plan fixups as you go: --fixup and --autosquash

```bash
git commit --fixup=6a2fb85          # creates "fixup! Add profile page"
git rebase -i --autosquash main     # Git pre-moves and marks it as fixup
```

Set `git config --global rebase.autoSquash true` to make this the default.

### Scripting it

The todo list editor is `GIT_SEQUENCE_EDITOR`; the message editor is
`GIT_EDITOR`. Useful in labs and scripts:

```bash
GIT_SEQUENCE_EDITOR="sed -i '2,\$s/^pick/fixup/'" git rebase -i main   # squash all into the first
```

### Move a branch to a different base: --onto

You started `feature/b` from `feature/a`, but `feature/a` was dropped. Move only
B's own commits onto main:

```bash
git rebase --onto main feature/a feature/b
```

Read it as: "take commits after `feature/a` up to `feature/b`, replay them onto
`main`".

## Try it

Your branch has commits (oldest first): `Add search`, `Debug prints`,
`Fix search for empty query`. You want one commit `Add search` (including the
fix) and no debug prints. Write the todo list.

<details>
<summary>Show answer</summary>

```
pick  aaa Add search
fixup ccc Fix search for empty query
drop  bbb Debug prints
```

`fixup` must sit directly under the commit it melds into; `drop` (or deleting
the line) removes the debug commit. If the fix touches the same lines as the
debug prints, expect a conflict.

</details>

## Common mistakes

- **Reading the list bottom-up.** Oldest is at the top, unlike `git log`.
- **Putting `fixup` on the first line.** There is nothing above it to meld
  into; Git refuses.
- **Rewriting commits already on main or pushed to a shared branch.** Only
  clean up your own unshared work.
- **Losing work with `drop`.** Recoverable: `git reflog`, then
  `git reset --hard <pre-rebase hash>` (or use `ORIG_HEAD` right after).

## Remember

- `git rebase -i <base>`: oldest commit first; edit verbs, save, Git replays.
- `fixup` melds and drops the message; `squash` melds and keeps it.
- `commit --fixup` + `rebase --autosquash` automates cleanup.
- `rebase --onto new old branch` moves only a branch's own commits.

**Self-check:**

1. Which verb lets you split a commit?
2. Why is `git rebase -i main` safer than `git rebase -i HEAD~5`?
3. How do you undo a bad interactive rebase?
$md$, 9, $json$[{"id":"git-rebase-interactive-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('9c513ab8-e630-5148-b54a-cda3727cf505', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'bc66d97b-4855-5638-8fbb-d9d46ae7f1b7', 'Pushing Rewritten History Safely: --force-with-lease', 'notes', 3, $md$## Why this matters

You rebased or squashed a branch you had already pushed (your pull request).
Now `git push` is rejected. The tempting fix, `--force`, can silently delete a
reviewer's commit. `--force-with-lease` does the same job with a safety check.

## Mental model: a lease on the branch

Plain `--force` says: "make the server branch equal mine, whatever is there."

`--force-with-lease` says: "make it equal mine, **but only if** it still points
where I last saw it (my `origin/<branch>`)". If someone pushed in between, your
lease is broken and the push is refused.

```
 origin/feature:  A---B---C---D        teammate has D checked out
 you rebase  ->   A---B---C'---D'      (new hashes)
 push --force     origin now has C'D'  -> teammate's D is orphaned, their next pull is a mess
```

## See it work

### The rejection

```bash
git push
```

Expected output after a rebase of an already-pushed branch:

```
 ! [rejected]        feature/profile -> feature/profile (non-fast-forward)
```

Your branch no longer contains the server's commits (they were replaced by
copies), so it is not a fast-forward.

### The safe overwrite

```bash
git push --force-with-lease origin feature/profile
```

Expected output:

```
 + 0b7e5ad...91c0d4e feature/profile -> feature/profile (forced update)
```

The `+` and "forced update" confirm the history was replaced.

If a teammate pushed meanwhile, you get instead:

```
 ! [rejected]        feature/profile -> feature/profile (stale info)
```

Then: `git fetch`, look at their commit, integrate it (rebase again), and retry.

### One more safety net

A plain `git fetch` updates `origin/<branch>`, which silently renews your lease
even if you never looked at the new commits. Add:

```bash
git push --force-with-lease --force-if-includes
```

`--force-if-includes` (Git 2.30+) also checks that the remote tip is somewhere
in your branch's reflog, i.e. that you actually integrated it. Set it once with
`git config --global push.useForceIfIncludes true`.

```knowledge-check
{ "questions": [
  { "id": "git-rebase-lease-q1", "type": "mcq",
    "prompt": "Why is --force-with-lease safer than --force?",
    "options": [
      {"id":"a","text":"It refuses to overwrite the remote branch if it has commits you have not seen"},
      {"id":"b","text":"It is faster"},
      {"id":"c","text":"It also rebases for you"},
      {"id":"d","text":"It deletes the remote branch first"}],
    "correct": "a",
    "explanation": "It checks the remote still points where your remote-tracking ref says before overwriting. It is not faster, does not rebase, and never deletes the branch." },
  { "id": "git-rebase-lease-q2", "type": "mcq",
    "prompt": "Which branch should you NEVER rebase?",
    "options": [
      {"id":"a","text":"A private local branch nobody has pulled"},
      {"id":"b","text":"A shared branch like main that others have pulled"},
      {"id":"c","text":"A branch with one commit"},
      {"id":"d","text":"A branch with no remote"}],
    "correct": "b",
    "explanation": "Rewriting commits others already have forces them to reconcile two versions of history. Private, single-commit or local-only branches are safe to rebase." }
] }
```

### Protect important branches on the server

Hosts let you mark `main` (and release branches) as **protected**: no force
pushes, no deletion, changes only through reviewed pull requests. Turn this on
for every shared repository; it makes the golden rule impossible to break by
accident.

## Try it

You rebased your PR branch and ran `git push --force-with-lease`. It says
`(stale info)`. What happened, and what is the safe sequence now?

<details>
<summary>Show answer</summary>

Someone (maybe a reviewer adding a fixup) pushed to your PR branch after your
last fetch. Safe sequence:

```bash
git fetch
git log --oneline feature/profile..origin/feature/profile   # see their commit
git rebase origin/feature/profile    # or cherry-pick their commit onto yours
git push --force-with-lease
```

</details>

## Common mistakes

- **Using `--force` by habit.** Make an alias instead:
  `git config --global alias.pushf "push --force-with-lease --force-if-includes"`.
- **Force-pushing `main`.** Never; revert instead (Section 9). Protect the
  branch on the host.
- **Running `git fetch` right before force-pushing without looking.** The lease
  then always succeeds; use `--force-if-includes`.

## Remember

- After rewriting a pushed branch, a normal push is rejected (non-fast-forward).
- `--force-with-lease` overwrites only if the server is where you last saw it.
- Add `--force-if-includes` so a blind fetch does not defeat the lease.
- Protect `main` on the server; never force-push shared branches.

**Self-check:**

1. What does "(stale info)" mean?
2. What extra check does `--force-if-includes` add?
3. Which branches should be protected on the host?
$md$, 7, $json$[{"id":"git-rebase-lease-q1","type":"mcq","correct":"a"},{"id":"git-rebase-lease-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('86e78574-a4f8-5c6a-9b7a-7100dd51962d', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'bc66d97b-4855-5638-8fbb-d9d46ae7f1b7', 'Lab: Rebase, Squash, Reword and Push Safely', 'notes', 4, $md$## Why this matters

`~/work/blog` has a `main` that moved on, and three feature branches: one that
rebases cleanly, one that conflicts, and one with four messy commits that is
already pushed to `origin`. You will rebase, abort, resolve, squash, reword and
then publish the rewritten branch safely.

```bash
cd ~/work/blog
git log --oneline --graph --all
```

## Task 1: a clean rebase

Rebase `feature/comments` onto `main`.

[[lab-task:1]]

Expected graph afterwards:

```
* 7c3a2e9 (HEAD -> feature/comments) Add comment form
* 0f6b18d Add comments page
* b1e47a0 (main) Rename title to Dev Blog
```

## Task 2: hit a conflict

`feature/title` and `main` both renamed the heading in `index.md`. Rebase
`feature/title` onto `main` and stop at the conflict.

[[lab-task:2]]

Expected:

```
CONFLICT (content): Merge conflict in index.md
error: could not apply 3e5f1aa... Rename blog title
```

`git status` shows `interactive rebase in progress`.

## Task 3: abort

Back out completely.

[[lab-task:3]]

## Task 4: resolve and continue

Rebase again. Resolve `index.md` so the first line is `# The Dev Blog` and the
second is `Welcome`, then `git add` and continue (prefix with `GIT_EDITOR=true`
to skip the message editor).

[[lab-task:4]]

Expected: `Successfully rebased and updated refs/heads/feature/title.`

## Task 5: squash with interactive rebase

On `feature/profile`, run `git rebase -i main`. Move `fix typo in profile` and
`wip: bio` directly under `wip: profile skeleton` and mark both `fixup`. Keep
`wip: add avatar` last.

```
pick   1111 wip: profile skeleton
fixup  3333 fix typo in profile
fixup  4444 wip: bio
pick   2222 wip: add avatar
```

The lab's default editor is `vi`. Prefer nano? Run
`git config --global core.editor nano` first (save with Ctrl+O, Enter; exit with
Ctrl+X).

[[lab-task:5]]

## Task 6: reword

Run interactive rebase again and `reword` both commits to `Add profile page`
(oldest) and `Add profile avatar`.

[[lab-task:6]]

Expected:

```
* 91c0d4e (HEAD -> feature/profile) Add profile avatar
* 6a2fb85 Add profile page
* b1e47a0 (main) Rename title to Dev Blog
```

## Task 7: publish safely

`origin` still has the old four commits. Try `git push` (rejected), then use
`--force-with-lease`. `origin/main` must not change.

[[lab-task:7]]

Expected:

```
 + 0b7e5ad...91c0d4e feature/profile -> feature/profile (forced update)
```

## Remember

- Rebase, resolve, `--continue`; or `--abort` to start over.
- Clean up with `rebase -i` before review.
- Rewritten pushed branch: `--force-with-lease`, never plain `--force`.
$md$, 45, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('3aad60ea-7c5d-53e8-af8f-aec913118978', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '86e78574-a4f8-5c6a-9b7a-7100dd51962d', 'module', 'Lab: Rebase, Squash, Reword and Push Safely', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
rm -rf /home/labuser/work/blog /home/labuser/srv/git
mkdir -p /home/labuser/srv/git /home/labuser/work/blog && cd /home/labuser/work/blog
git init -q
M() { git add -A; GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
printf '# My Blog\nWelcome\n' > index.md
echo 'body{}' > style.css
M 2024-04-01 "Initial blog"
echo about > about.md; M 2024-04-02 "Add about page"
git switch -q -c feature/comments
echo comments > comments.md; M 2024-04-03 "Add comments page"
echo form >> comments.md; M 2024-04-04 "Add comment form"
git switch -q main
git switch -q -c feature/title
printf '# The Blog\nWelcome\n' > index.md; M 2024-04-05 "Rename blog title"
git switch -q main
echo footer > footer.md; M 2024-04-06 "Add footer"
printf '# Dev Blog\nWelcome\n' > index.md; M 2024-04-07 "Rename title to Dev Blog"
git switch -q -c feature/profile
printf '# Proflie\nname: TBD\n' > profile.md; M 2024-04-08 "wip: profile skeleton"
echo avatar.png > avatar.md; M 2024-04-09 "wip: add avatar"
printf '# Profile\nname: TBD\n' > profile.md; M 2024-04-10 "fix typo in profile"
echo 'bio: hello' >> profile.md; M 2024-04-11 "wip: bio"
git switch -q main
git init -q --bare /home/labuser/srv/git/blog.git
git remote add origin /home/labuser/srv/git/blog.git
git push -q origin main feature/profile
git branch -q --set-upstream-to=origin/main main
git branch -q --set-upstream-to=origin/feature/profile feature/profile
chmod -R a+rwX /home/labuser/work/blog /home/labuser/srv/git
$script$, NULL, 55, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '203db899-fc15-5412-ab91-ebf9232eb368' AND id NOT IN ('09690c6c-036e-5aaa-9b3b-c881bb6230e7', '6a54303b-a6c5-5c54-8f4a-b0fb7e4d32ef', 'c525b8be-96fb-5146-8ca3-5dbb1c5fc2a1', '1b002822-803a-57f8-b5b0-7b1335f6c262', 'a272e50d-c51b-5a50-aa8c-8a31c2d84b1a', 'baec5242-971c-5860-b169-b5c110bb58d1', 'd7988132-49b2-5ce9-b875-2c6404510cff');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '203db899-fc15-5412-ab91-ebf9232eb368';
DELETE FROM lab_tasks WHERE lab_id = '3aad60ea-7c5d-53e8-af8f-aec913118978' AND id NOT IN ('bcde4793-12fb-57a0-bfe5-9b6942674344', 'adf90221-77b3-5bf9-b623-24d7c2ee0222', 'f96af6df-620c-5041-a031-da09aee8b416', '7e94857a-650f-5846-b07b-3b43af49d2b3', '95dc5233-5561-5aab-a9d5-3f7924ffe30f', '45ea28b5-8236-53f3-b3d4-3e3376a5ae4a', '91c64a7d-f740-5808-9377-8efb56735633');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '3aad60ea-7c5d-53e8-af8f-aec913118978';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('bcde4793-12fb-57a0-bfe5-9b6942674344', '3aad60ea-7c5d-53e8-af8f-aec913118978', 1, 'Rebase a feature branch onto main', $md$In ~/work/blog, feature/comments was started before main gained two commits. Rebase feature/comments onto main so its two commits sit on top of main's tip with no merge commit.$md$, $script$r=/home/labuser/work/blog
git -C $r merge-base --is-ancestor main feature/comments &&
[ "$(git -C $r rev-list --count main..feature/comments)" = 2 ] &&
[ "$(git -C $r rev-list --merges --count main..feature/comments)" = 0 ] &&
[ "$(git -C $r log feature/comments -1 --format=%s)" = "Add comment form" ] &&
[ ! -d $r/.git/rebase-merge ]
$script$, 'git switch feature/comments, then git rebase main. Check the result with git log --oneline --graph --all.', 'Rebase replays each of your commits on top of a new base, creating new commits with new hashes. The result is a straight line instead of a merge.', 15, false, true),
('adf90221-77b3-5bf9-b623-24d7c2ee0222', '3aad60ea-7c5d-53e8-af8f-aec913118978', 2, 'Hit a conflict mid-rebase', $md$feature/title renames the heading to "# The Blog" but main already renamed it to "# Dev Blog". Rebase feature/title onto main and stop at the conflict.$md$, $script$r=/home/labuser/work/blog
[ -d $r/.git/rebase-merge ] &&
git -C $r ls-files -u | grep -q index.md
$script$, 'git switch feature/title && git rebase main. Git pauses and prints which commit it was applying.', 'Rebase replays commits one at a time; a conflict stops it with the branch in a detached state until you continue or abort.', 10, false, true),
('f96af6df-620c-5041-a031-da09aee8b416', '3aad60ea-7c5d-53e8-af8f-aec913118978', 3, 'Abort the rebase', $md$Change your mind - abort the rebase so feature/title is exactly as it was before.$md$, $script$r=/home/labuser/work/blog
[ ! -d $r/.git/rebase-merge ] &&
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = feature/title ] &&
! git -C $r merge-base --is-ancestor main feature/title &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git rebase --abort.', '--abort returns the branch to its pre-rebase tip. Your original commits were never modified, so nothing is lost.', 10, false, true),
('7e94857a-650f-5846-b07b-3b43af49d2b3', '3aad60ea-7c5d-53e8-af8f-aec913118978', 4, 'Resolve and continue the rebase', $md$Rebase feature/title onto main again. This time resolve index.md so its first line is "# The Dev Blog" (second line "Welcome"), git add it and run git rebase --continue.$md$, $script$r=/home/labuser/work/blog
[ ! -d $r/.git/rebase-merge ] &&
git -C $r merge-base --is-ancestor main feature/title &&
[ "$(git -C $r rev-list --count main..feature/title)" = 1 ] &&
[ "$(git -C $r log feature/title -1 --format=%s)" = "Rename blog title" ] &&
[ "$(git -C $r show feature/title:index.md | head -1)" = "# The Dev Blog" ] &&
[ -z "$(git -C $r grep -nE '^(<<<<<<<|=======|>>>>>>>)' feature/title)" ]
$script$, 'After editing, git add index.md then git rebase --continue (set GIT_EDITOR=true to skip the message editor).', 'In a rebase "ours" is the branch you are rebasing onto and "theirs" is your commit being replayed - the reverse of a merge. The continue step creates the rewritten commit.', 20, false, true),
('95dc5233-5561-5aab-a9d5-3f7924ffe30f', '3aad60ea-7c5d-53e8-af8f-aec913118978', 5, 'Squash and reorder with interactive rebase', $md$feature/profile has four messy commits ("wip: profile skeleton", "wip: add avatar", "fix typo in profile", "wip: bio"). Use git rebase -i main to fold the typo fix and bio into the skeleton commit and keep the avatar commit last, leaving exactly two commits.$md$, $script$r=/home/labuser/work/blog
[ ! -d $r/.git/rebase-merge ] &&
[ "$(git -C $r rev-list --count main..feature/profile)" = 2 ] &&
[ "$(git -C $r show --name-only --format= feature/profile)" = avatar.md ] &&
git -C $r show feature/profile~1:profile.md | grep -qx '# Profile' &&
git -C $r show feature/profile~1:profile.md | grep -qx 'bio: hello'
$script$, 'In the todo list move the "fix typo" and "bio" lines directly under the skeleton line and change pick to fixup (f). Leave the avatar line last. The default editor here is vi; run git config --global core.editor nano to use nano instead.', 'fixup melds a commit into the one above it and discards its message; reordering lines reorders history. Commits that touch different files reorder without conflicts.', 20, false, true),
('45ea28b5-8236-53f3-b3d4-3e3376a5ae4a', '3aad60ea-7c5d-53e8-af8f-aec913118978', 6, 'Reword the commits', $md$Reword the two remaining commits (oldest first) to "Add profile page" and "Add profile avatar" using interactive rebase.$md$, $script$r=/home/labuser/work/blog
[ ! -d $r/.git/rebase-merge ] &&
[ "$(git -C $r log --reverse --format=%s main..feature/profile)" = "$(printf 'Add profile page\nAdd profile avatar')" ]
$script$, 'Change pick to reword (r) on both lines; Git opens the editor once per commit.', 'reword keeps the content and rewrites only the message. Since every following commit has a new parent, the hashes of later commits change too.', 15, false, true),
('91c64a7d-f740-5808-9377-8efb56735633', '3aad60ea-7c5d-53e8-af8f-aec913118978', 7, 'Update the shared branch safely', $md$origin still holds the old, un-squashed feature/profile. A plain git push is rejected because history was rewritten. Push the rewritten branch with --force-with-lease (never plain --force). origin's main must stay untouched.$md$, $script$r=/home/labuser/work/blog
[ "$(git -C $r ls-remote origin refs/heads/feature/profile | cut -f1)" = "$(git -C $r rev-parse feature/profile)" ] &&
[ "$(git -C $r ls-remote origin refs/heads/main | cut -f1)" = "$(git -C $r rev-parse main)" ] &&
[ "$(git -C $r rev-list --count origin/feature/profile)" = "$(git -C $r rev-list --count feature/profile)" ]
$script$, 'git push --force-with-lease origin feature/profile. It refuses if someone else pushed to the branch since your last fetch.', '--force-with-lease overwrites the remote branch only if it still points where you last saw it, protecting a teammate''s newer commits that a blind --force would destroy.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('203db899-fc15-5412-ab91-ebf9232eb368', '3aad60ea-7c5d-53e8-af8f-aec913118978', 1, $json$[{"id":"bcde4793-12fb-57a0-bfe5-9b6942674344","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":1,"title":"Rebase a feature branch onto main","description":"In ~/work/blog, feature/comments was started before main gained two commits. Rebase feature/comments onto main so its two commits sit on top of main's tip with no merge commit.","verification_script":"r=/home/labuser/work/blog\ngit -C $r merge-base --is-ancestor main feature/comments \u0026\u0026\n[ \"$(git -C $r rev-list --count main..feature/comments)\" = 2 ] \u0026\u0026\n[ \"$(git -C $r rev-list --merges --count main..feature/comments)\" = 0 ] \u0026\u0026\n[ \"$(git -C $r log feature/comments -1 --format=%s)\" = \"Add comment form\" ] \u0026\u0026\n[ ! -d $r/.git/rebase-merge ]\n","hint_context":"git switch feature/comments, then git rebase main. Check the result with git log --oneline --graph --all.","explanation_context":"Rebase replays each of your commits on top of a new base, creating new commits with new hashes. The result is a straight line instead of a merge.","points":15,"is_optional":false,"is_stateful":true},{"id":"adf90221-77b3-5bf9-b623-24d7c2ee0222","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":2,"title":"Hit a conflict mid-rebase","description":"feature/title renames the heading to \"# The Blog\" but main already renamed it to \"# Dev Blog\". Rebase feature/title onto main and stop at the conflict.","verification_script":"r=/home/labuser/work/blog\n[ -d $r/.git/rebase-merge ] \u0026\u0026\ngit -C $r ls-files -u | grep -q index.md\n","hint_context":"git switch feature/title \u0026\u0026 git rebase main. Git pauses and prints which commit it was applying.","explanation_context":"Rebase replays commits one at a time; a conflict stops it with the branch in a detached state until you continue or abort.","points":10,"is_optional":false,"is_stateful":true},{"id":"f96af6df-620c-5041-a031-da09aee8b416","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":3,"title":"Abort the rebase","description":"Change your mind - abort the rebase so feature/title is exactly as it was before.","verification_script":"r=/home/labuser/work/blog\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\n[ \"$(git -C $r rev-parse --abbrev-ref HEAD)\" = feature/title ] \u0026\u0026\n! git -C $r merge-base --is-ancestor main feature/title \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"git rebase --abort.","explanation_context":"--abort returns the branch to its pre-rebase tip. Your original commits were never modified, so nothing is lost.","points":10,"is_optional":false,"is_stateful":true},{"id":"7e94857a-650f-5846-b07b-3b43af49d2b3","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":4,"title":"Resolve and continue the rebase","description":"Rebase feature/title onto main again. This time resolve index.md so its first line is \"# The Dev Blog\" (second line \"Welcome\"), git add it and run git rebase --continue.","verification_script":"r=/home/labuser/work/blog\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\ngit -C $r merge-base --is-ancestor main feature/title \u0026\u0026\n[ \"$(git -C $r rev-list --count main..feature/title)\" = 1 ] \u0026\u0026\n[ \"$(git -C $r log feature/title -1 --format=%s)\" = \"Rename blog title\" ] \u0026\u0026\n[ \"$(git -C $r show feature/title:index.md | head -1)\" = \"# The Dev Blog\" ] \u0026\u0026\n[ -z \"$(git -C $r grep -nE '^(\u003c\u003c\u003c\u003c\u003c\u003c\u003c|=======|\u003e\u003e\u003e\u003e\u003e\u003e\u003e)' feature/title)\" ]\n","hint_context":"After editing, git add index.md then git rebase --continue (set GIT_EDITOR=true to skip the message editor).","explanation_context":"In a rebase \"ours\" is the branch you are rebasing onto and \"theirs\" is your commit being replayed - the reverse of a merge. The continue step creates the rewritten commit.","points":20,"is_optional":false,"is_stateful":true},{"id":"95dc5233-5561-5aab-a9d5-3f7924ffe30f","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":5,"title":"Squash and reorder with interactive rebase","description":"feature/profile has four messy commits (\"wip: profile skeleton\", \"wip: add avatar\", \"fix typo in profile\", \"wip: bio\"). Use git rebase -i main to fold the typo fix and bio into the skeleton commit and keep the avatar commit last, leaving exactly two commits.","verification_script":"r=/home/labuser/work/blog\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\n[ \"$(git -C $r rev-list --count main..feature/profile)\" = 2 ] \u0026\u0026\n[ \"$(git -C $r show --name-only --format= feature/profile)\" = avatar.md ] \u0026\u0026\ngit -C $r show feature/profile~1:profile.md | grep -qx '# Profile' \u0026\u0026\ngit -C $r show feature/profile~1:profile.md | grep -qx 'bio: hello'\n","hint_context":"In the todo list move the \"fix typo\" and \"bio\" lines directly under the skeleton line and change pick to fixup (f). Leave the avatar line last. The default editor here is vi; run git config --global core.editor nano to use nano instead.","explanation_context":"fixup melds a commit into the one above it and discards its message; reordering lines reorders history. Commits that touch different files reorder without conflicts.","points":20,"is_optional":false,"is_stateful":true},{"id":"45ea28b5-8236-53f3-b3d4-3e3376a5ae4a","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":6,"title":"Reword the commits","description":"Reword the two remaining commits (oldest first) to \"Add profile page\" and \"Add profile avatar\" using interactive rebase.","verification_script":"r=/home/labuser/work/blog\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\n[ \"$(git -C $r log --reverse --format=%s main..feature/profile)\" = \"$(printf 'Add profile page\\nAdd profile avatar')\" ]\n","hint_context":"Change pick to reword (r) on both lines; Git opens the editor once per commit.","explanation_context":"reword keeps the content and rewrites only the message. Since every following commit has a new parent, the hashes of later commits change too.","points":15,"is_optional":false,"is_stateful":true},{"id":"91c64a7d-f740-5808-9377-8efb56735633","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":7,"title":"Update the shared branch safely","description":"origin still holds the old, un-squashed feature/profile. A plain git push is rejected because history was rewritten. Push the rewritten branch with --force-with-lease (never plain --force). origin's main must stay untouched.","verification_script":"r=/home/labuser/work/blog\n[ \"$(git -C $r ls-remote origin refs/heads/feature/profile | cut -f1)\" = \"$(git -C $r rev-parse feature/profile)\" ] \u0026\u0026\n[ \"$(git -C $r ls-remote origin refs/heads/main | cut -f1)\" = \"$(git -C $r rev-parse main)\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --count origin/feature/profile)\" = \"$(git -C $r rev-list --count feature/profile)\" ]\n","hint_context":"git push --force-with-lease origin feature/profile. It refuses if someone else pushed to the branch since your last fetch.","explanation_context":"--force-with-lease overwrites the remote branch only if it still points where you last saw it, protecting a teammate's newer commits that a blind --force would destroy.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('09690c6c-036e-5aaa-9b3b-c881bb6230e7', '203db899-fc15-5412-ab91-ebf9232eb368', 'bcde4793-12fb-57a0-bfe5-9b6942674344', 1, 'Rebase a feature branch onto main', $md$In ~/work/blog, feature/comments was started before main gained two commits. Rebase feature/comments onto main so its two commits sit on top of main's tip with no merge commit.$md$, $script$r=/home/labuser/work/blog
git -C $r merge-base --is-ancestor main feature/comments &&
[ "$(git -C $r rev-list --count main..feature/comments)" = 2 ] &&
[ "$(git -C $r rev-list --merges --count main..feature/comments)" = 0 ] &&
[ "$(git -C $r log feature/comments -1 --format=%s)" = "Add comment form" ] &&
[ ! -d $r/.git/rebase-merge ]
$script$, 'git switch feature/comments, then git rebase main. Check the result with git log --oneline --graph --all.', 'Rebase replays each of your commits on top of a new base, creating new commits with new hashes. The result is a straight line instead of a merge.', 15, false, true),
('6a54303b-a6c5-5c54-8f4a-b0fb7e4d32ef', '203db899-fc15-5412-ab91-ebf9232eb368', 'adf90221-77b3-5bf9-b623-24d7c2ee0222', 2, 'Hit a conflict mid-rebase', $md$feature/title renames the heading to "# The Blog" but main already renamed it to "# Dev Blog". Rebase feature/title onto main and stop at the conflict.$md$, $script$r=/home/labuser/work/blog
[ -d $r/.git/rebase-merge ] &&
git -C $r ls-files -u | grep -q index.md
$script$, 'git switch feature/title && git rebase main. Git pauses and prints which commit it was applying.', 'Rebase replays commits one at a time; a conflict stops it with the branch in a detached state until you continue or abort.', 10, false, true),
('c525b8be-96fb-5146-8ca3-5dbb1c5fc2a1', '203db899-fc15-5412-ab91-ebf9232eb368', 'f96af6df-620c-5041-a031-da09aee8b416', 3, 'Abort the rebase', $md$Change your mind - abort the rebase so feature/title is exactly as it was before.$md$, $script$r=/home/labuser/work/blog
[ ! -d $r/.git/rebase-merge ] &&
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = feature/title ] &&
! git -C $r merge-base --is-ancestor main feature/title &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git rebase --abort.', '--abort returns the branch to its pre-rebase tip. Your original commits were never modified, so nothing is lost.', 10, false, true),
('1b002822-803a-57f8-b5b0-7b1335f6c262', '203db899-fc15-5412-ab91-ebf9232eb368', '7e94857a-650f-5846-b07b-3b43af49d2b3', 4, 'Resolve and continue the rebase', $md$Rebase feature/title onto main again. This time resolve index.md so its first line is "# The Dev Blog" (second line "Welcome"), git add it and run git rebase --continue.$md$, $script$r=/home/labuser/work/blog
[ ! -d $r/.git/rebase-merge ] &&
git -C $r merge-base --is-ancestor main feature/title &&
[ "$(git -C $r rev-list --count main..feature/title)" = 1 ] &&
[ "$(git -C $r log feature/title -1 --format=%s)" = "Rename blog title" ] &&
[ "$(git -C $r show feature/title:index.md | head -1)" = "# The Dev Blog" ] &&
[ -z "$(git -C $r grep -nE '^(<<<<<<<|=======|>>>>>>>)' feature/title)" ]
$script$, 'After editing, git add index.md then git rebase --continue (set GIT_EDITOR=true to skip the message editor).', 'In a rebase "ours" is the branch you are rebasing onto and "theirs" is your commit being replayed - the reverse of a merge. The continue step creates the rewritten commit.', 20, false, true),
('a272e50d-c51b-5a50-aa8c-8a31c2d84b1a', '203db899-fc15-5412-ab91-ebf9232eb368', '95dc5233-5561-5aab-a9d5-3f7924ffe30f', 5, 'Squash and reorder with interactive rebase', $md$feature/profile has four messy commits ("wip: profile skeleton", "wip: add avatar", "fix typo in profile", "wip: bio"). Use git rebase -i main to fold the typo fix and bio into the skeleton commit and keep the avatar commit last, leaving exactly two commits.$md$, $script$r=/home/labuser/work/blog
[ ! -d $r/.git/rebase-merge ] &&
[ "$(git -C $r rev-list --count main..feature/profile)" = 2 ] &&
[ "$(git -C $r show --name-only --format= feature/profile)" = avatar.md ] &&
git -C $r show feature/profile~1:profile.md | grep -qx '# Profile' &&
git -C $r show feature/profile~1:profile.md | grep -qx 'bio: hello'
$script$, 'In the todo list move the "fix typo" and "bio" lines directly under the skeleton line and change pick to fixup (f). Leave the avatar line last. The default editor here is vi; run git config --global core.editor nano to use nano instead.', 'fixup melds a commit into the one above it and discards its message; reordering lines reorders history. Commits that touch different files reorder without conflicts.', 20, false, true),
('baec5242-971c-5860-b169-b5c110bb58d1', '203db899-fc15-5412-ab91-ebf9232eb368', '45ea28b5-8236-53f3-b3d4-3e3376a5ae4a', 6, 'Reword the commits', $md$Reword the two remaining commits (oldest first) to "Add profile page" and "Add profile avatar" using interactive rebase.$md$, $script$r=/home/labuser/work/blog
[ ! -d $r/.git/rebase-merge ] &&
[ "$(git -C $r log --reverse --format=%s main..feature/profile)" = "$(printf 'Add profile page\nAdd profile avatar')" ]
$script$, 'Change pick to reword (r) on both lines; Git opens the editor once per commit.', 'reword keeps the content and rewrites only the message. Since every following commit has a new parent, the hashes of later commits change too.', 15, false, true),
('d7988132-49b2-5ce9-b875-2c6404510cff', '203db899-fc15-5412-ab91-ebf9232eb368', '91c64a7d-f740-5808-9377-8efb56735633', 7, 'Update the shared branch safely', $md$origin still holds the old, un-squashed feature/profile. A plain git push is rejected because history was rewritten. Push the rewritten branch with --force-with-lease (never plain --force). origin's main must stay untouched.$md$, $script$r=/home/labuser/work/blog
[ "$(git -C $r ls-remote origin refs/heads/feature/profile | cut -f1)" = "$(git -C $r rev-parse feature/profile)" ] &&
[ "$(git -C $r ls-remote origin refs/heads/main | cut -f1)" = "$(git -C $r rev-parse main)" ] &&
[ "$(git -C $r rev-list --count origin/feature/profile)" = "$(git -C $r rev-list --count feature/profile)" ]
$script$, 'git push --force-with-lease origin feature/profile. It refuses if someone else pushed to the branch since your last fetch.', '--force-with-lease overwrites the remote branch only if it still points where you last saw it, protecting a teammate''s newer commits that a blind --force would destroy.', 20, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '203db899-fc15-5412-ab91-ebf9232eb368', updated_at = now()
WHERE id = '3aad60ea-7c5d-53e8-af8f-aec913118978' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ca5ee70d-7799-5687-a3ba-733d4a1b5fb9', '00000000-0000-0000-0000-000000000001', 'mcq', 'You rebase your private branch feature/x onto main. A colleague asks why the ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7cb642ab-5d1d-59ea-91d8-bb08a25a3408', 'ca5ee70d-7799-5687-a3ba-733d4a1b5fb9', 1, $json${"prompt":"You rebase your private branch feature/x onto main. A colleague asks why the commit hashes in your PR all changed. What is the correct explanation?","multiple":false,"options":[{"id":"a","text":"Rebase re-applies each commit on a new parent, and a commit's hash includes its parent, so every replayed commit is new","is_correct":true},{"id":"b","text":"Git randomises hashes on every push","is_correct":false},{"id":"c","text":"Rebase compresses commits, which changes hashes","is_correct":false},{"id":"d","text":"The hashes did not change; only the dates did","is_correct":false}],"explanation":"New parent -\u003e new commit object -\u003e new hash. Hashes are deterministic, not random; rebase does not compress; and the hashes do change."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f3d9338d-fc05-5187-a1fe-a65b6112a910', '00000000-0000-0000-0000-000000000001', 'mcq', 'Mid-rebase, a conflict appears in config.yml. You want to keep YOUR branch''s ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('082d6a0d-3af2-5f5c-9eda-eef7bde805fc', 'f3d9338d-fc05-5187-a1fe-a65b6112a910', 1, $json${"prompt":"Mid-rebase, a conflict appears in config.yml. You want to keep YOUR branch's version of the file. Which command?","multiple":false,"options":[{"id":"a","text":"git checkout --ours config.yml","is_correct":false},{"id":"b","text":"git checkout --theirs config.yml","is_correct":true},{"id":"c","text":"git merge --abort","is_correct":false},{"id":"d","text":"git rebase --skip","is_correct":false}],"explanation":"In a rebase the labels flip: ours = the base being rebased onto, theirs = your commit being replayed. --ours would take main's version, merge --abort does not apply to a rebase, and --skip would drop your whole commit."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8a359f8d-2d4d-5fdb-9be6-ab801caa9c14', '00000000-0000-0000-0000-000000000001', 'mcq', 'Two developers push to the shared branch release/2.1. One of them wants to re...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('217065d7-db84-51b7-9233-bacd87d7dd6a', '8a359f8d-2d4d-5fdb-9be6-ab801caa9c14', 1, $json${"prompt":"Two developers push to the shared branch release/2.1. One of them wants to rebase it onto main to 'tidy it up'. What is the best advice?","multiple":false,"options":[{"id":"a","text":"Go ahead and push --force","is_correct":false},{"id":"b","text":"Do not rebase a shared branch; merge main into it, or coordinate so nobody has unpushed work and everyone resets afterwards","is_correct":true},{"id":"c","text":"Rebase is fine as long as you use --force-with-lease","is_correct":false},{"id":"d","text":"Delete the branch and recreate it","is_correct":false}],"explanation":"The golden rule: never rebase commits others have built on. --force-with-lease protects against overwriting unseen commits, but teammates still hold the old history and must repair their clones. Deleting and recreating is the same rewrite."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('06465577-1cbe-59d3-997a-9a300805b0c0', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the interactive rebase todo list, where is the oldest commit?', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f577affc-9985-5d6d-b928-15bdffa9eb67', '06465577-1cbe-59d3-997a-9a300805b0c0', 1, $json${"prompt":"In the interactive rebase todo list, where is the oldest commit?","multiple":false,"options":[{"id":"a","text":"At the top","is_correct":true},{"id":"b","text":"At the bottom","is_correct":false},{"id":"c","text":"Sorted by author","is_correct":false},{"id":"d","text":"It is not shown","is_correct":false}],"explanation":"The todo list is the order commits will be replayed, oldest first. git log shows newest first, which is why people often read the list upside down."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cbc7db76-0533-51b5-a1bc-9ce47a99fe7f', '00000000-0000-0000-0000-000000000001', 'mcq', 'You want to fold a ''fix typo'' commit into the commit above it and throw away ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c5aac799-7c45-5e72-8b79-5674c626fbe1', 'cbc7db76-0533-51b5-a1bc-9ce47a99fe7f', 1, $json${"prompt":"You want to fold a 'fix typo' commit into the commit above it and throw away the 'fix typo' message. Which verb?","multiple":false,"options":[{"id":"a","text":"squash","is_correct":false},{"id":"b","text":"fixup","is_correct":true},{"id":"c","text":"edit","is_correct":false},{"id":"d","text":"drop","is_correct":false}],"explanation":"fixup melds and discards the message. squash melds but opens the editor to combine messages, edit stops for amending, and drop removes the change entirely."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('dd163718-ef1d-593a-b4e8-1f77d82deb6f', '00000000-0000-0000-0000-000000000001', 'mcq', 'After rebasing your PR branch, `git push --force-with-lease` is rejected with...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4bd7c15d-a6ec-595c-8daa-d84119a5537e', 'dd163718-ef1d-593a-b4e8-1f77d82deb6f', 1, $json${"prompt":"After rebasing your PR branch, `git push --force-with-lease` is rejected with '(stale info)'. What happened?","multiple":false,"options":[{"id":"a","text":"Your network is slow","is_correct":false},{"id":"b","text":"Someone pushed to the branch after your last fetch, so the server no longer matches your origin/\u003cbranch\u003e","is_correct":true},{"id":"c","text":"Force-with-lease only works on main","is_correct":false},{"id":"d","text":"Your branch has a merge conflict","is_correct":false}],"explanation":"The lease protects that unseen commit. Fetch, integrate it, and push again. It is not a network or conflict problem, and the option works on any branch."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cde45542-00ac-5606-958c-c54ac588b9eb', '00000000-0000-0000-0000-000000000001', 'mcq', 'You made one unpushed commit on main; a teammate pushed one too. You want to ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('72c59aaf-c7f6-596e-b5a4-e077fdc57fb4', 'cde45542-00ac-5606-958c-c54ac588b9eb', 1, $json${"prompt":"You made one unpushed commit on main; a teammate pushed one too. You want to avoid a 'Merge branch main of ...' commit. Which command?","multiple":false,"options":[{"id":"a","text":"git pull --rebase","is_correct":true},{"id":"b","text":"git push --force","is_correct":false},{"id":"c","text":"git merge --no-ff origin/main","is_correct":false},{"id":"d","text":"git rebase -i HEAD~10","is_correct":false}],"explanation":"pull --rebase replays your unpushed commit on top of origin/main. Safe because nobody else has it. Force-push would delete the teammate's commit, --no-ff creates exactly the merge commit you wanted to avoid, and rebase -i HEAD~10 rewrites shared commits."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6cb48a64-07c4-547a-a402-000b13bf74e8', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 7): you dropped the wrong commit during an interactive rebase...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e6c9d810-86b7-5a1e-8b0f-dbf8e46ec363', '6cb48a64-07c4-547a-a402-000b13bf74e8', 1, $json${"prompt":"Review (Section 7): you dropped the wrong commit during an interactive rebase that finished a minute ago. How do you get back the pre-rebase branch?","multiple":false,"options":[{"id":"a","text":"git reset --hard ORIG_HEAD, or find the pre-rebase hash in git reflog and reset to it","is_correct":true},{"id":"b","text":"git rebase --abort","is_correct":false},{"id":"c","text":"It is lost","is_correct":false},{"id":"d","text":"git revert HEAD","is_correct":false}],"explanation":"Rebase records ORIG_HEAD and the reflog keeps the old tip. --abort only works while the rebase is still running, nothing is lost, and revert would add an inverse of the last commit, not restore the dropped one."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('3288b1af-9452-5af7-8932-c453c481c559', '00000000-0000-0000-0000-000000000001', 'Quiz: Rebase and Rewriting History', 'git-rebase-quiz', 'Quiz covering Rebase and Rewriting History.', 'mcq', 'published', 'module', '7e585198-89cd-5b29-a6ee-139fcba6245d', 14, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '3288b1af-9452-5af7-8932-c453c481c559' AND question_id NOT IN ('ca5ee70d-7799-5687-a3ba-733d4a1b5fb9', 'f3d9338d-fc05-5187-a1fe-a65b6112a910', '8a359f8d-2d4d-5fdb-9be6-ab801caa9c14', '06465577-1cbe-59d3-997a-9a300805b0c0', 'cbc7db76-0533-51b5-a1bc-9ce47a99fe7f', 'dd163718-ef1d-593a-b4e8-1f77d82deb6f', 'cde45542-00ac-5606-958c-c54ac588b9eb', '6cb48a64-07c4-547a-a402-000b13bf74e8');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('b1d44f00-2f5c-5f2b-8100-1424c1bbb20a', '3288b1af-9452-5af7-8932-c453c481c559', 'ca5ee70d-7799-5687-a3ba-733d4a1b5fb9', '7cb642ab-5d1d-59ea-91d8-bb08a25a3408', 0, 2),
('84e72ca8-eff7-595e-bdb5-ccf46929c7a4', '3288b1af-9452-5af7-8932-c453c481c559', 'f3d9338d-fc05-5187-a1fe-a65b6112a910', '082d6a0d-3af2-5f5c-9eda-eef7bde805fc', 1, 2),
('539425ea-02a8-525e-8258-5332b14be3c3', '3288b1af-9452-5af7-8932-c453c481c559', '8a359f8d-2d4d-5fdb-9be6-ab801caa9c14', '217065d7-db84-51b7-9233-bacd87d7dd6a', 2, 2),
('3d24c8dd-8728-55ce-8132-e1a47218416e', '3288b1af-9452-5af7-8932-c453c481c559', '06465577-1cbe-59d3-997a-9a300805b0c0', 'f577affc-9985-5d6d-b928-15bdffa9eb67', 3, 2),
('12cce108-2e61-5a79-963b-4f5838cbedba', '3288b1af-9452-5af7-8932-c453c481c559', 'cbc7db76-0533-51b5-a1bc-9ce47a99fe7f', 'c5aac799-7c45-5e72-8b79-5674c626fbe1', 4, 2),
('1fbc959f-3591-5442-a389-da96d8217140', '3288b1af-9452-5af7-8932-c453c481c559', 'dd163718-ef1d-593a-b4e8-1f77d82deb6f', '4bd7c15d-a6ec-595c-8daa-d84119a5537e', 5, 2),
('cf193240-87e3-529c-b5a3-ea71c64ae38d', '3288b1af-9452-5af7-8932-c453c481c559', 'cde45542-00ac-5606-958c-c54ac588b9eb', '72c59aaf-c7f6-596e-b5a4-e077fdc57fb4', 6, 2),
('2bda261f-0571-55d0-9519-a7cd7068a17f', '3288b1af-9452-5af7-8932-c453c481c559', '6cb48a64-07c4-547a-a402-000b13bf74e8', 'e6c9d810-86b7-5a1e-8b0f-dbf8e46ec363', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('7e585198-89cd-5b29-a6ee-139fcba6245d', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'bc66d97b-4855-5638-8fbb-d9d46ae7f1b7', 'Quiz: Rebase and Rewriting History', 'assessment', 5, 12, '3288b1af-9452-5af7-8932-c453c481c559')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Undo and Recovery
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('7a77d065-f51b-5ec5-9aea-a09bdcfb797c', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Undo and Recovery', 9, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('619ea6a0-66c9-5105-ac7d-e8430ee6ee3c', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '7a77d065-f51b-5ec5-9aea-a09bdcfb797c', 'restore and clean: Undo Uncommitted Changes', 'notes', 0, $md$## Why this matters

"I just deleted my work" is something everyone says once. This section gives
you the right undo for every situation. Start with the simplest: changes you
have **not committed yet**. These are also the only undos that can destroy work
for good, so learn exactly what each one throws away.

## Mental model: three erasers for three places

| Situation | Eraser | Touches | Reversible? |
|---|---|---|---|
| Unwanted edit in a tracked file | `git restore <file>` | Working tree | **No** |
| File staged by mistake | `git restore --staged <file>` | Index only | Yes (edit stays on disk) |
| Untracked junk files | `git clean` | Untracked files | **No** |

None of these move a branch or touch commits.

```
 BEFORE                                   AFTER
 HEAD   : ledger v1                       HEAD   : ledger v1
 index  : ledger v1                       index  : ledger v1
 working: ledger v1 + GARBAGE             working: ledger v1       git restore ledger.txt

 git restore --staged secret.txt:  index loses the file, working copy untouched
```

## See it work

### Discard an edit

```bash
cd ~/work/ledger
git status -s
git diff ledger.txt          # look before you throw away
git restore ledger.txt
```

What this does: copies the index version of `ledger.txt` over your working
copy. Expected `git status -s` before and after both restores (below):

```
 M ledger.txt
A  secret.txt
(after both restores)
?? secret.txt
```

### Unstage a file

```bash
git restore --staged secret.txt
```

What this does: copies HEAD's version into the index (for a new file, removes it
from the index). The file stays on disk, now untracked. Then add it to
`.gitignore`.

```knowledge-check
{ "questions": [
  { "id": "git-undo-restore-q1", "type": "mcq",
    "prompt": "Which command removes a file from the staging area without deleting your edits?",
    "options": [
      {"id":"a","text":"git restore --staged <file>"},
      {"id":"b","text":"git restore <file>"},
      {"id":"c","text":"git reset --hard"},
      {"id":"d","text":"git clean -f"}],
    "correct": "a",
    "explanation": "Plain git restore <file> would discard the working-tree edits instead. reset --hard discards all changes, and clean -f deletes untracked files." }
] }
```

### Restore from any commit

```bash
git restore --source=HEAD~2 ledger.txt        # the version from two commits ago
git restore --source=main --staged --worktree app.sh   # both index and file from main
```

Older equivalents you will see in guides: `git checkout -- file` (= restore)
and `git reset HEAD file` (= restore --staged).

### Remove untracked files

```bash
git clean -n        # dry run: list what WOULD be deleted
git clean -f        # delete untracked files
git clean -fd       # ... and untracked directories
git clean -fdx      # ... and ignored files too (build output, .env!)
```

Always run `-n` first. `-x` deletes ignored files, including local secrets and
caches you may want.

## Try it

You ran `git add .` and staged `debug.log` along with real work. You want to
keep the real work staged and stop `debug.log` from being committed, but keep
the log on disk. Which command?

<details>
<summary>Show answer</summary>

```bash
git restore --staged debug.log
echo "*.log" >> .gitignore
```

Only the index entry is removed; the file and your other staged changes stay.

</details>

## Common mistakes

- **`git restore <file>` when you meant `--staged`.** Your edits are gone; they
  were never stored, so even the reflog cannot help.
- **`git clean -fdx` without a dry run.** It deletes ignored files like `.env`
  and local databases.
- **Expecting restore to undo a commit.** It does not move branches; use
  `reset` or `revert` (next lessons).

## Remember

- `git restore <file>` discards uncommitted edits (permanent).
- `git restore --staged <file>` unstages; edits stay.
- `--source=<commit>` restores a file from any commit.
- `git clean -n` before `git clean -f`; `-x` also removes ignored files.

**Self-check:**

1. Which of these undos can lose work permanently?
2. What is the modern replacement for `git checkout -- file`?
3. What does `git clean -n` do?
$md$, 7, $json$[{"id":"git-undo-restore-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('444e98ed-bd14-56fd-ab33-637c7e30f968', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '7a77d065-f51b-5ec5-9aea-a09bdcfb797c', 'reset: --soft, --mixed and --hard', 'notes', 1, $md$## Why this matters

`git reset` is the most powerful undo for **local, unpushed** commits: redo a
commit, unstage everything, or throw commits away. It is also the command that
scares people most, because one flag decides whether your work survives. Learn
the three modes as three levels of rewind.

## Mental model: rewind the tape, choose how far

Reset always does step 1, and the mode decides whether it continues:

1. **Move the branch** (and HEAD) to the target commit. *(all modes)*
2. **Make the index match** that commit. *(`--mixed`, `--hard`)*
3. **Make the working tree match** that commit. *(`--hard` only)*

```
              moves HEAD    resets INDEX    overwrites WORKING TREE
 --soft           yes            no                 no
 --mixed (default) yes           yes                no
 --hard           yes            yes                yes   (destructive)
```

Mnemonic: **S**oft = **S**taged stays, **M**ixed = **M**odified (unstaged)
stays, **H**ard = **H**istory and changes **H**ave gone.

```
BEFORE: A---B---C  <- main (HEAD)         git reset X HEAD~1

 --soft :  A---B  <- main   index = C's content (staged)   working = C's content
 --mixed:  A---B  <- main   index = B              working = C's content (unstaged)
 --hard :  A---B  <- main   index = B              working = B      (C's changes gone)
           C is now unreachable (but in the reflog)
```

## See it work

### --soft: redo the last commit

```bash
git reset --soft HEAD~1
git commit -m "Add March entries"
```

What this does: un-commits "Add Marsh entries" but keeps every change staged, so
the next commit recreates it with a better message. (Same result as
`git commit --amend` here; soft reset also works for squashing the last 3
commits: `git reset --soft HEAD~3 && git commit`.)

### --mixed: un-commit and unstage

```bash
git reset HEAD~1          # --mixed is the default
git status -s
```

Expected output:

```
 M ledger.txt
```

The commit is gone from the branch; its changes are plain unstaged edits, ready
to be split into different commits.

### --hard: throw it all away

```bash
git reset --hard HEAD~2
```

Expected output:

```
HEAD is now at 4be2c19 Add February entries
```

The two commits are off the branch (recoverable via the reflog, next lesson).
Any **uncommitted** edits are destroyed for good.

```knowledge-check
{ "questions": [
  { "id": "git-undo-reset-q1", "type": "mcq",
    "prompt": "After git reset --soft HEAD~1, where do the undone commit's changes live?",
    "options": [
      {"id":"a","text":"Staged in the index"},
      {"id":"b","text":"Unstaged in the working tree"},
      {"id":"c","text":"Deleted"},
      {"id":"d","text":"In a stash"}],
    "correct": "a",
    "explanation": "--soft leaves index and working tree alone; --mixed unstages; --hard discards. Nothing goes into a stash." },
  { "id": "git-undo-reset-q2", "type": "mcq",
    "prompt": "Which reset mode can destroy uncommitted work?",
    "options": [
      {"id":"a","text":"--soft"},
      {"id":"b","text":"--mixed"},
      {"id":"c","text":"--hard"},
      {"id":"d","text":"None of them"}],
    "correct": "c",
    "explanation": "--hard overwrites the working tree, and uncommitted edits are not in the reflog. --soft and --mixed keep your working tree as it is." }
] }
```

### Useful targets

| Target | Meaning |
|---|---|
| `HEAD~1` | One commit back |
| `origin/main` | Make my branch match the server (drop my local commits) |
| `ORIG_HEAD` | Where HEAD was before the last reset/merge/rebase (quick undo) |
| `<hash from reflog>` | Any earlier state |

`git reset --keep <target>` is a safer `--hard`: it refuses if it would
overwrite uncommitted changes.

## Try it

You made three small local commits on `feature` and want them as one commit
before pushing. Do it with reset.

<details>
<summary>Show answer</summary>

```bash
git reset --soft HEAD~3
git commit -m "Add search feature"
```

`--soft` keeps all three commits' changes staged, so one commit captures them.
Interactive rebase with `fixup` does the same with more control.

</details>

## Common mistakes

- **Resetting commits that are already pushed to a shared branch.** Your branch
  then disagrees with the server; others keep the old commits. Use `revert`.
- **`--hard` with uncommitted work you wanted.** Commit or stash first, or use
  `--keep`.
- **Confusing `git reset <file>` with `git reset --hard`.** With a path, reset
  only unstages that file (like `restore --staged`); it never moves the branch.

## Remember

- Reset moves the branch; the mode decides what else rewinds.
- `--soft` keeps staged, `--mixed` keeps edits unstaged, `--hard` keeps nothing.
- Only for local, unpushed commits.
- Lost commits after reset are recoverable; lost uncommitted edits are not.

**Self-check:**

1. Which mode is the default?
2. How do you squash the last three commits with reset?
3. Why is `--hard` dangerous but `--soft` not?
$md$, 9, $json$[{"id":"git-undo-reset-q1","type":"mcq","correct":"a"},{"id":"git-undo-reset-q2","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('57793e90-a4e4-54ea-8067-00633a4dfcf4', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '7a77d065-f51b-5ec5-9aea-a09bdcfb797c', 'reflog: The Safety Net Under Everything', 'notes', 2, $md$## Why this matters

A bad `reset --hard`, a botched rebase, a deleted branch, an amend you regret:
all of them look like lost work. They are almost never lost. The **reflog**
records every position your branches and HEAD have had, so you can walk back to
any of them.

## Mental model: your browser history

`git log` is the official story of a branch. The reflog is your **browser
history**: every place HEAD has been, in order, including detours that are no
longer part of any branch. It is **local** (never pushed or cloned) and private
to your repository.

```
 git reflog
 4be2c19 HEAD@{0}: reset: moving to HEAD~2
 a91d6f3 HEAD@{1}: commit: Add April entries      <-- the "lost" commit
 5c07b8e HEAD@{2}: commit: Add March entries

 git reset --hard a91d6f3     main points at April again:  A---B---C---D---E <- main
```

## See it work

### Find and restore lost commits

```bash
git reflog
```

Expected output (top = most recent):

```
4be2c19 (HEAD -> main) HEAD@{0}: reset: moving to HEAD~2
a91d6f3 HEAD@{1}: commit: Add April entries
5c07b8e HEAD@{2}: commit: Add March entries
4be2c19 (HEAD -> main) HEAD@{3}: reset: moving to HEAD~1
```

Pick the line from **before** the mistake and go back to it:

```bash
git reset --hard a91d6f3          # or: git reset --hard HEAD@{1}
```

Expected:

```
HEAD is now at a91d6f3 Add April entries
```

If you only want to look or keep both versions, create a branch instead:
`git branch rescue a91d6f3`.

```knowledge-check
{ "questions": [
  { "id": "git-undo-reflog-q1", "type": "mcq",
    "prompt": "You ran git reset --hard and lost commits. What is your first move?",
    "options": [
      {"id":"a","text":"Re-clone the repo"},
      {"id":"b","text":"git reflog to find the old commit hash, then reset or branch to it"},
      {"id":"c","text":"git gc --prune=now"},
      {"id":"d","text":"Nothing - it is gone"}],
    "correct": "b",
    "explanation": "The reflog keeps previous positions of HEAD (entries for commits no longer on a branch expire after 30 days by default). Re-cloning only gets what was pushed, and gc --prune=now could delete exactly the objects you need." }
] }
```

### Per-branch reflogs and time travel

```bash
git reflog show feature/login        # history of one branch
git log -g --oneline                 # reflog as a log
git show main@{yesterday}            # where main was yesterday
git diff main@{1} main               # what the last move of main changed
```

### What the reflog can and cannot save

| Situation | Recoverable? |
|---|---|
| `reset --hard`, bad rebase, bad amend | Yes, find the old HEAD |
| Deleted branch (`branch -D`) | Yes, its last commit is in HEAD's reflog if you had it checked out |
| Dropped stash | Not in the reflog; use `git fsck --unreachable` (Section 13) |
| Uncommitted, unstaged edits | **No** - Git never stored them |
| Work in a clone you deleted | **No** - the reflog lived inside it |

Default expiry: 90 days for entries still reachable from the branch, 30 days
for entries pointing at commits no longer on it (`gc.reflogExpire`,
`gc.reflogExpireUnreachable`).

## Try it

You ran `git rebase -i main`, dropped a commit by mistake, and the rebase
finished. Recover the branch exactly as it was before the rebase.

<details>
<summary>Show answer</summary>

```bash
git reflog
# find the line just before "rebase (start)", e.g. "HEAD@{5}: commit: ..."
git reset --hard HEAD@{5}
```

Right after a rebase, `git reset --hard ORIG_HEAD` also works.

</details>

## Common mistakes

- **Panicking and running `git gc --prune=now`.** That can delete the very
  objects the reflog points at.
- **Expecting the reflog on another machine.** It is local; a fresh clone has
  none of your history of moves.
- **Choosing the wrong line.** Each line is the state *after* that action. To
  undo an action, pick the line below it.

## Remember

- `git reflog` = every place HEAD has been, newest first.
- Recover with `git reset --hard <hash>` or `git branch rescue <hash>`.
- `HEAD@{n}`, `main@{yesterday}` and `ORIG_HEAD` are handy names.
- Local only; entries expire (30/90 days); never-committed edits are not in it.

**Self-check:**

1. Is the reflog pushed to the server?
2. Which line do you pick to undo the latest action?
3. Name one thing the reflog cannot recover.
$md$, 7, $json$[{"id":"git-undo-reflog-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('cbd2e806-7598-55ef-9e8b-02aba5067f5c', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '7a77d065-f51b-5ec5-9aea-a09bdcfb797c', 'revert: Undo Safely on Shared History', 'notes', 3, $md$## Why this matters

A bad commit is already on `main`, and teammates and CI have pulled it. You
cannot rewrite that history without breaking everyone's clones. `git revert`
undoes the change by **adding** a new commit, so history only grows and every
clone stays consistent.

## Mental model: a correction notice

A newspaper cannot un-print yesterday's paper. It prints a **correction** in
today's paper. Revert is the correction: a new commit whose changes are the
exact inverse of the bad one.

```
BEFORE                               AFTER git revert C

 A---B---C---D  <- main               A---B---C---D---C'  <- main
                                      C' = inverse of C   (C stays in history)
```

| | reset | revert |
|---|---|---|
| What it does | Moves the branch back | Adds an inverse commit |
| History | Rewritten | Append-only |
| Safe after push | No | **Yes** |

## See it work

### Revert one commit

```bash
git log --oneline
git revert --no-edit 5c07b8e        # hash of "Add March entries"
```

Expected output:

```
[main 2e81c4d] Revert "Add March entries"
 1 file changed, 1 deletion(-)
```

`--no-edit` keeps the default message `Revert "<original subject>"`, whose
body says `This reverts commit 5c07b8e...`. Without it, Git opens the editor
so you can explain **why** you reverted. Good practice on shared branches.

Revert can conflict if later commits changed the same lines; resolve as usual,
then `git revert --continue` (or `--abort`).

```knowledge-check
{ "questions": [
  { "id": "git-undo-revert-q1", "type": "mcq",
    "prompt": "Why is revert preferred over reset on a branch teammates already pulled?",
    "options": [
      {"id":"a","text":"It adds a new commit instead of rewriting history, so nobody's clone diverges"},
      {"id":"b","text":"It is faster"},
      {"id":"c","text":"It deletes the original commit"},
      {"id":"d","text":"It works without a repository"}],
    "correct": "a",
    "explanation": "Rewriting shared history forces everyone else to repair their branches. Revert is not faster, it keeps the original commit, and it needs a repository like any command." }
] }
```

### Revert a merge commit

A merge has two parents, so Git needs to know which side is the "mainline" to
keep:

```
        M  <- main (merge of feature into main)       git revert -m 1 M
       / \                                             -m 1 = keep parent 1 (main's side),
      B   F  <- feature                                undo everything F brought in
```

```bash
git revert -m 1 --no-edit HEAD
```

Expected:

```
[main 7ad03ce] Revert "Merge feature/bonus"
 1 file changed, 1 deletion(-)
 delete mode 100644 bonus.txt
```

Without `-m`, Git refuses: `error: commit ... is a merge but no -m option was
given.`

**Gotcha:** Git still considers `feature/bonus` merged. If you fix the feature
and merge it again later, only the **new** commits come in. To bring the whole
feature back, first revert the revert (`git revert <revert-commit>`).

```knowledge-check
{ "questions": [
  { "id": "git-undo-revert-q2", "type": "mcq",
    "prompt": "What does git revert -m 1 <merge> keep?",
    "options": [
      {"id":"a","text":"The side of parent 1 (the branch the merge was made on) and undoes what the other parent brought in"},
      {"id":"b","text":"Only the other parent's changes"},
      {"id":"c","text":"Nothing"},
      {"id":"d","text":"Both sides"}],
    "correct": "a",
    "explanation": "-m picks the mainline parent; changes relative to it are inverted. It does not keep only the other side, nor both, nor nothing." }
] }
```

### Revert several commits

```bash
git revert --no-commit HEAD~3..HEAD   # stage the inverse of the last 3 commits
git commit -m "Revert checkout redesign (breaks Safari)"
```

## Try it

Commit `X` on shared `main` broke the build. Two good commits came after it.
Undo only `X` and publish the fix.

<details>
<summary>Show answer</summary>

```bash
git pull
git revert X          # explain why in the message
git push
```

The good commits stay; `X` stays in history; a new commit removes its effect.

</details>

## Common mistakes

- **Using reset + force-push on `main`.** Breaks every clone and CI. Revert.
- **Forgetting `-m 1` on merges.** Git refuses without it.
- **Re-merging a reverted branch and wondering why changes are missing.**
  Revert the revert first.

## Remember

- Revert = new commit with the inverse changes; history stays append-only.
- Use it for anything already pushed to a shared branch.
- Merge commits need `-m 1` (keep the mainline side).
- After reverting a merge, re-merging needs the revert reverted.

**Self-check:**

1. Does revert delete the original commit?
2. Why does reverting a merge need `-m`?
3. How do you bring back a feature whose merge you reverted?
$md$, 8, $json$[{"id":"git-undo-revert-q1","type":"mcq","correct":"a"},{"id":"git-undo-revert-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('461a1a8c-3466-5f4d-8982-e9f2063c6d21', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '7a77d065-f51b-5ec5-9aea-a09bdcfb797c', 'cherry-pick: Copy One Commit to Another Branch', 'notes', 4, $md$## Why this matters

A bug fix landed on `main`, but the release branch `release/1.4` needs it too,
without the other 30 commits on main. Or you committed to the wrong branch.
`git cherry-pick` copies exactly the commits you choose.

## Mental model: photocopy a single page

Cherry-pick takes one commit's **changes** (its diff against its parent) and
applies them on top of your current branch as a **new commit**. Same message,
same author, but a new parent, so a new hash.

```
BEFORE                                AFTER  git switch main; git cherry-pick S

 main:    A---B---C                    main:    A---B---C---S'   (S' = copy of S)
 audit:        \                       audit:        \
                L---S                                 L---S   (unchanged)
```

## See it work

### Pick one commit

```bash
git log --oneline feature/audit
git switch main
git cherry-pick <hash of "Add audit summary">
```

Expected output:

```
[main 3b9f1a2] Add audit summary
 Author: Priya Auditor <priya@example.com>
 Date: Tue May 7 10:00:00 2024 +0000
 1 file changed, 1 insertion(+)
 create mode 100644 summary.txt
```

The author is preserved (Priya); you become the **committer**.

```knowledge-check
{ "questions": [
  { "id": "git-undo-pick-q1", "type": "mcq",
    "prompt": "A cherry-picked commit has the same hash as the original.",
    "options": [
      {"id":"a","text":"True"},
      {"id":"b","text":"False - it is a new commit with a different parent, so a different hash"}],
    "correct": "b",
    "explanation": "The diff and message are copied but the commit identity (parent, committer, date) differs, so the hash differs." }
] }
```

### Useful options

| Command | Effect |
|---|---|
| `git cherry-pick A B C` | Copy several commits in order |
| `git cherry-pick A..B` | Copy the range after A up to B |
| `git cherry-pick -x <hash>` | Add "(cherry picked from commit ...)" to the message; recommended for backports |
| `git cherry-pick -n <hash>` | Apply changes without committing |
| `git cherry-pick -m 1 <merge>` | Pick a merge commit (relative to parent 1) |
| `--continue` / `--skip` / `--abort` | After a conflict, like rebase |

### Backport a fix to a release branch

```bash
git switch release/1.4
git cherry-pick -x 9f2c1e7      # the fix from main
git push
```

`-x` lets anyone trace the backport to the original commit.

### When not to cherry-pick

Cherry-picking many commits between long-lived branches creates duplicates
(same change, different hashes). Later merges may conflict or show the change
twice. If you need most of a branch, merge or rebase it instead.

## Try it

You committed `Fix login redirect` on `main` by mistake; it belongs on
`feature/login`. Nothing is pushed. Move it.

<details>
<summary>Show answer</summary>

```bash
git switch feature/login
git cherry-pick main          # main's tip = the misplaced commit
git switch main
git reset --hard HEAD~1       # remove it from main (local, unpushed only)
```

Section 13 shows the same fix for several commits.

</details>

## Common mistakes

- **Expecting the same hash.** It is a copy; tools that compare hashes see two
  different commits.
- **Cherry-picking without `-x` on backports.** Later nobody knows where the
  change came from.
- **Using it as a substitute for merging.** Many picks between branches cause
  duplicate commits and confusing conflicts.

## Remember

- Cherry-pick copies a commit's changes as a new commit on the current branch.
- Author is kept; hash is new.
- `-x` records the source; ranges and multiple hashes work.
- Conflicts: fix, `git add`, `git cherry-pick --continue`.

**Self-check:**

1. What does cherry-pick actually copy: the snapshot or the diff?
2. Why add `-x` to a backport?
3. When is merging better than cherry-picking?
$md$, 7, $json$[{"id":"git-undo-pick-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f02760d9-646a-5b96-9caf-9dc2b1c09e96', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '7a77d065-f51b-5ec5-9aea-a09bdcfb797c', 'stash: Park Work in Progress', 'notes', 5, $md$## Why this matters

You are halfway through a change when Maya says: "Production is down, switch to
main now." Your edits are not ready to commit, and Git will not let you switch
if they clash. `git stash` puts them aside in one command and brings them back
later.

## Mental model: a drawer for unfinished work

Stash sweeps your uncommitted changes into a drawer and leaves your desk clean
(working tree matches HEAD). The drawer is a stack: the newest item is
`stash@{0}`.

```
 working tree dirty ----git stash push -m "wip total"----> working tree clean
                                     stash@{0} holds the edits
 later: git stash pop  ------------------------------------> edits are back, stash entry dropped
```

Internally each stash is a commit (plus one for the index) stored under
`refs/stash`, not on any branch.

## See it work

### Stash and list

```bash
echo "WIP total" >> ledger.txt
git stash push -m "wip total"
git stash list
git status -s
```

Expected output:

```
Saved working directory and index state On main: wip total
stash@{0}: On main: wip total
```

`git status -s` prints nothing: the tree is clean.

### Bring it back

```bash
git stash pop          # apply stash@{0} and drop it
```

```knowledge-check
{ "questions": [
  { "id": "git-undo-stash-q1", "type": "mcq",
    "prompt": "What is the difference between git stash pop and git stash apply?",
    "options": [
      {"id":"a","text":"pop applies and removes the stash entry; apply keeps it"},
      {"id":"b","text":"pop deletes the repo"},
      {"id":"c","text":"apply only works on tags"},
      {"id":"d","text":"There is none"}],
    "correct": "a",
    "explanation": "apply is useful when you want to apply the same stash on several branches. pop never touches the repo itself, and both work on any branch." }
] }
```

If `pop` hits a conflict, the stash is **kept** so nothing is lost. Resolve,
then `git stash drop` yourself.

### The useful options

| Command | Effect |
|---|---|
| `git stash push -u` | Also stash **untracked** files (default: tracked only) |
| `git stash push -p` | Choose hunks interactively |
| `git stash push -- path/` | Stash only some paths |
| `git stash push --staged` | Stash only what is staged (Git 2.35+) |
| `git stash show -p stash@{1}` | See a stash's diff |
| `git stash apply stash@{1}` | Apply an older stash, keep it |
| `git stash drop stash@{1}` / `clear` | Delete one / all (careful) |
| `git stash branch new-branch` | Create a branch from where you stashed and apply it there |

`git stash branch` is the cleanest fix when a stash no longer applies because
the code moved on.

### Stash or commit?

Stashes have no good names, are easy to forget, and are local only. For
anything longer than a quick context switch, a **WIP commit on a branch** is
safer: `git switch -c wip/report && git commit -am "WIP"`, and amend or squash it
later.

## Try it

You need to switch branches but have edits to `app.sh` **and** a new file
`notes.md` you have not added. Plain `git stash` leaves `notes.md` behind. What
do you run?

<details>
<summary>Show answer</summary>

```bash
git stash push -u -m "wip app and notes"
```

`-u` includes untracked files. Restore later with `git stash pop`.

</details>

## Common mistakes

- **Forgetting untracked files.** Use `-u`.
- **Piling up ten anonymous stashes.** Always add `-m "message"`, and clean up
  with `git stash list` regularly.
- **`git stash clear` by accident.** Dropped stashes can sometimes be found
  with `git fsck --unreachable` (Section 13), but do not rely on it.

## Remember

- `git stash push -m "msg"` parks changes; `git stash pop` brings them back.
- `pop` = apply + drop; `apply` keeps the entry.
- `-u` includes untracked files; `stash branch` rescues stale stashes.
- For longer pauses, prefer a WIP commit on a branch.

**Self-check:**

1. What does plain `git stash` leave behind?
2. What happens to the stash entry if `pop` conflicts?
3. When is a WIP commit better than a stash?
$md$, 7, $json$[{"id":"git-undo-stash-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a9dbf033-3c13-5141-b45d-b5b6a1e8d407', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '7a77d065-f51b-5ec5-9aea-a09bdcfb797c', 'Lab: Undo Anything', 'notes', 6, $md$## Why this matters

`~/work/ledger` is a small accounting repo in a messy state: a junk line in
`ledger.txt`, a secret file staged by accident, a typo in a commit message, and
two feature branches. You will use every undo from this section, in the order
you would meet them on the job.

```bash
cd ~/work/ledger
git status
git log --oneline --graph --all
```

## Part 1: uncommitted changes

**Task 1.** Throw away the uncommitted `GARBAGE` line in `ledger.txt`.

[[lab-task:1]]

**Task 2.** Unstage `secret.txt` but keep it on disk.

[[lab-task:2]]

Expected `git status -s` afterwards:

```
?? secret.txt
```

## Part 2: reset

**Task 3.** The last commit says `Add Marsh entries`. Use `reset --soft` and
recommit as `Add March entries` (still four commits).

[[lab-task:3]]

**Task 4.** Step back to `Add February entries` with a **mixed** reset so the
March line stays as an unstaged edit.

[[lab-task:4]]

Expected `git status -s`:

```
 M ledger.txt
```

**Task 5.** Commit March again (`Add March entries`), then add `april.txt`
containing `Apr: 200` as `Add April entries`.

[[lab-task:5]]

**Task 6.** Throw away both commits and their changes with `reset --hard`.

[[lab-task:6]]

Expected: `HEAD is now at 4be2c19 Add February entries`.

## Part 3: recover

**Task 7.** You needed April after all. Find it in the reflog and move `main`
back to it.

[[lab-task:7]]

Expected `git reflog` top lines:

```
4be2c19 HEAD@{0}: reset: moving to HEAD~2
a91d6f3 HEAD@{1}: commit: Add April entries
```

## Part 4: shared-history undo

Pretend `main` is already pushed from here on, so no more resets.

**Task 8.** Revert `Add March entries` (keep April).

[[lab-task:8]]

**Task 9.** Merge `feature/bonus` with `--no-ff` and the message
`Merge feature/bonus`.

[[lab-task:9]]

**Task 10.** The bonus feature must come out: revert the merge commit, keeping
the main side (`-m 1`).

[[lab-task:10]]

Expected:

```
[main 7ad03ce] Revert "Merge feature/bonus"
 1 file changed, 1 deletion(-)
 delete mode 100644 bonus.txt
```

## Part 5: copy and park

**Task 11.** Bring only `Add audit summary` from `feature/audit` onto `main`.

[[lab-task:11]]

Check: `git log -1 --format='%an'` prints `Priya Auditor`.

**Task 12.** Append `WIP total` to `ledger.txt` and stash it with the message
`wip total`.

[[lab-task:12]]

Expected `git stash list`:

```
stash@{0}: On main: wip total
```

**Task 13.** Bring the stash back and drop it in one step.

[[lab-task:13]]

## Remember

| Situation | Command |
|---|---|
| Discard an uncommitted edit | `git restore <file>` |
| Unstage | `git restore --staged <file>` |
| Redo local commits | `git reset --soft` / `--mixed` |
| Drop local commits | `git reset --hard` (then reflog if wrong) |
| Undo a pushed commit | `git revert` (`-m 1` for merges) |
| Copy one commit | `git cherry-pick` |
| Park unfinished work | `git stash push -m` / `pop` |
$md$, 50, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('04d7844d-96d2-5567-8035-339262255ab7', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'a9dbf033-3c13-5141-b45d-b5b6a1e8d407', 'module', 'Lab: Undo Anything', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
rm -rf /home/labuser/work/ledger
mkdir /home/labuser/work/ledger && cd /home/labuser/work/ledger
git init -q
A() { git add -A; GIT_AUTHOR_NAME="$3" GIT_AUTHOR_EMAIL="$4" GIT_COMMITTER_NAME="$3" GIT_COMMITTER_EMAIL="$4" GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
M() { A "$1" "$2" "Maya Lead" maya@example.com; }
echo "# Ledger" > ledger.txt;   M 2024-05-01 "Create ledger"
echo "Jan: 100" >> ledger.txt;  M 2024-05-02 "Add January entries"
echo "Feb: 120" >> ledger.txt;  M 2024-05-03 "Add February entries"
echo "Mar: 90" >> ledger.txt;   M 2024-05-04 "Add Marsh entries"
git switch -q -c feature/bonus
echo "bonus: 10" > bonus.txt;   M 2024-05-05 "Add bonus file"
git switch -q main
git switch -q -c feature/audit
echo "audit log" > auditlog.txt;  A 2024-05-06 "Add audit log" "Priya Auditor" priya@example.com
echo "audit summary" > summary.txt; A 2024-05-07 "Add audit summary" "Priya Auditor" priya@example.com
git switch -q main
echo "GARBAGE" >> ledger.txt
echo "api-key=abc" > secret.txt
git add secret.txt
chmod -R a+rwX /home/labuser/work/ledger
$script$, NULL, 60, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'd38247c4-782e-542b-99a2-5bbdba9f4d1d' AND id NOT IN ('1ea1e827-b28d-5ef1-83c0-d142c0f69605', '70eff26b-58e6-509d-af4e-d595b680efab', '4e0a77dd-4af1-5f0e-80f8-329f6973035b', '9660e933-a410-5380-b0e3-21a6f13c4bc0', 'cc50d4b4-964c-5488-9f42-dc7f3e3eb526', '7430200c-20ba-542c-af2a-2050915b216e', '1390a89c-5c1b-545b-8ceb-ac218496b0e1', '0069b923-ca58-50f6-94a9-b1e20c8dc85c', '55199883-edd1-587e-aea8-7ffa70343e54', '327a582c-355f-5d24-9315-3080f7c871ef', '904af7b4-30f8-5071-9d01-9fc4da9ebc4a', '7d31e86f-a75b-5d29-92d3-971e10196ecc', 'de51fdbd-8ce0-5e54-bdf5-a09660615180');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'd38247c4-782e-542b-99a2-5bbdba9f4d1d';
DELETE FROM lab_tasks WHERE lab_id = '04d7844d-96d2-5567-8035-339262255ab7' AND id NOT IN ('141985cb-97a4-5c88-a9aa-40e7e7ff8bac', 'a34b655f-2bc5-5f37-a481-edcff6512e12', '65a85e80-ef62-54ee-a1c4-cb6536c6fba2', '9c8ac66e-d65d-5192-9505-eb21e286df15', '07d3e279-2564-567d-a8fb-9f192325bae8', 'b8bff31a-8b6a-526c-9804-f91fcccb3f66', 'e824955b-74a0-5850-8144-e27ceca3f164', '014a12bc-96e3-56d9-8209-604d337051ca', 'e667f5e3-9ff6-572e-8709-b211bbcfb06d', '2632023f-1e2a-5162-86ff-60729a508cc5', '7e6302e7-94fb-5bfd-9cfd-3c25776cbd39', '2981d328-239a-5dfe-b2f5-9c8c18c75ebf', '8190bf50-d5e0-5772-8076-5d250fe2915d');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '04d7844d-96d2-5567-8035-339262255ab7';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('141985cb-97a4-5c88-a9aa-40e7e7ff8bac', '04d7844d-96d2-5567-8035-339262255ab7', 1, 'Discard an unwanted edit', $md$In ~/work/ledger someone left a junk line (GARBAGE) in ledger.txt. Throw that uncommitted edit away so ledger.txt matches the last commit again.$md$, $script$r=/home/labuser/work/ledger
git -C $r diff --quiet -- ledger.txt && ! grep -q GARBAGE $r/ledger.txt
$script$, 'git restore <file> copies the file from the index back into the working tree. It discards the edit permanently, so read git diff first.', 'git restore (the modern replacement for git checkout -- file) overwrites the working-tree file from the index. Uncommitted edits are not in any commit, so this cannot be undone.', 10, false, true),
('a34b655f-2bc5-5f37-a481-edcff6512e12', '04d7844d-96d2-5567-8035-339262255ab7', 2, 'Unstage a file you must not commit', $md$secret.txt was staged by accident. Remove it from the staging area but keep the file on disk, untracked.$md$, $script$r=/home/labuser/work/ledger
git -C $r diff --cached --quiet &&
[ -f $r/secret.txt ] &&
git -C $r ls-files --others --exclude-standard | grep -qx secret.txt
$script$, 'git restore --staged <file> undoes git add without touching the file itself.', 'restore --staged copies HEAD''s version of the path into the index, so the file drops out of the next commit while your working copy stays intact.', 10, false, true),
('65a85e80-ef62-54ee-a1c4-cb6536c6fba2', '04d7844d-96d2-5567-8035-339262255ab7', 3, 'Re-do the last commit with reset --soft', $md$The last commit message "Add Marsh entries" has a typo. Move the branch back one commit while keeping the changes staged (reset --soft), then commit again with the message "Add March entries". There must still be exactly four commits on main.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Add March entries" ] &&
[ "$(git -C $r rev-list --count HEAD)" = 4 ] &&
git -C $r diff --quiet HEAD &&
git -C $r reflog | grep -q 'reset: moving to'
$script$, 'git reset --soft HEAD~1 moves only the branch pointer; the old commit''s changes stay staged, ready for git commit -m.', '--soft moves HEAD (and the branch) but leaves the index and working tree alone, so everything the undone commit contained is still staged.', 15, false, true),
('9c8ac66e-d65d-5192-9505-eb21e286df15', '04d7844d-96d2-5567-8035-339262255ab7', 4, 'Unstage everything with reset --mixed', $md$Step main back to "Add February entries" with a mixed reset, so the March line remains in ledger.txt as an unstaged working-tree change. Nothing may be staged.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Add February entries" ] &&
git -C $r diff --cached --quiet &&
! git -C $r diff --quiet -- ledger.txt &&
grep -qx 'Mar: 90' $r/ledger.txt &&
[ "$(git -C $r reflog | grep -c 'reset: moving to')" -ge 2 ]
$script$, 'git reset (default is --mixed) HEAD~1. git status then lists ledger.txt under "Changes not staged for commit".', '--mixed moves HEAD and resets the index to match, but keeps the working tree. Your edits survive as plain unstaged modifications.', 15, false, true),
('07d3e279-2564-567d-a8fb-9f192325bae8', '04d7844d-96d2-5567-8035-339262255ab7', 5, 'Recommit March and add April', $md$Commit the March change again with the message "Add March entries", then create april.txt containing "Apr: 200" and commit it as "Add April entries".$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log --format=%s -3 | paste -sd,)" = "Add April entries,Add March entries,Add February entries" ] &&
[ "$(git -C $r rev-list --count HEAD)" = 5 ] &&
git -C $r diff --quiet HEAD
$script$, 'git commit -am commits tracked-file changes. april.txt is new, so git add it first.', 'This sets up a history with two commits you are about to throw away, so you can practise recovering them.', 10, false, true),
('b8bff31a-8b6a-526c-9804-f91fcccb3f66', '04d7844d-96d2-5567-8035-339262255ab7', 6, 'Throw work away with reset --hard', $md$Discard the last two commits AND their changes: reset --hard so main is back at "Add February entries" with no March line and no april.txt.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Add February entries" ] &&
git -C $r diff --quiet HEAD &&
[ ! -f $r/april.txt ] &&
! grep -q 'Mar: 90' $r/ledger.txt
$script$, 'git reset --hard HEAD~2 rewinds the branch two commits and overwrites the working tree.', '--hard moves HEAD, resets the index and overwrites the working tree. The commits are no longer on any branch, but Git still remembers them in the reflog for a while.', 10, false, true),
('e824955b-74a0-5850-8144-e27ceca3f164', '04d7844d-96d2-5567-8035-339262255ab7', 7, 'Recover the lost commits from the reflog', $md$Oops - you needed April after all. Use git reflog to find the commit "Add April entries" and move main back to it so both the March and April commits are restored.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Add April entries" ] &&
[ -f $r/april.txt ] &&
git -C $r log --format=%s | grep -qx "Add March entries" &&
git -C $r diff --quiet HEAD
$script$, 'git reflog lists every position HEAD has been at. Find the line "commit - Add April entries" and git reset --hard <that hash>.', 'The reflog is a private diary of where your refs pointed. Commits unreachable from any branch survive until garbage collection (90 days by default), so a bad reset is recoverable.', 20, false, true),
('014a12bc-96e3-56d9-8209-604d337051ca', '04d7844d-96d2-5567-8035-339262255ab7', 8, 'Revert a published commit', $md$The March entries were wrong, but history is already shared so you must not rewrite it. Revert the commit "Add March entries" with git revert (default message), keeping April.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = 'Revert "Add March entries"' ] &&
! grep -q 'Mar: 90' $r/ledger.txt &&
[ -f $r/april.txt ] &&
git -C $r log --format=%s | grep -qx "Add March entries"
$script$, 'git revert <hash-of-March-commit> --no-edit. Find the hash with git log --oneline.', 'revert creates a NEW commit that applies the inverse patch. The original commit stays in history, so it is safe on shared branches, unlike reset.', 15, false, true),
('e667f5e3-9ff6-572e-8709-b211bbcfb06d', '04d7844d-96d2-5567-8035-339262255ab7', 9, 'Merge a feature branch', $md$Merge feature/bonus into main with --no-ff and the message "Merge feature/bonus".$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Merge feature/bonus" ] &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
[ -f $r/bonus.txt ]
$script$, 'git merge --no-ff feature/bonus -m "Merge feature/bonus".', 'This creates a merge commit with two parents, which is what makes reverting a merge special in the next task.', 10, false, true),
('2632023f-1e2a-5162-86ff-60729a508cc5', '04d7844d-96d2-5567-8035-339262255ab7', 10, 'Revert a merge commit with -m 1', $md$The bonus feature must come out. Revert the merge commit itself. A merge has two parents so Git needs to know which side to keep - use mainline parent 1 (the main side).$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = 'Revert "Merge feature/bonus"' ] &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 2 ] &&
[ ! -f $r/bonus.txt ] &&
git -C $r merge-base --is-ancestor feature/bonus HEAD
$script$, 'git revert -m 1 HEAD --no-edit. Without -m Git refuses because it cannot tell which parent is the mainline.', '-m 1 says "undo the changes relative to parent 1", i.e. everything the merge brought in from the other branch. Note that Git now considers that branch already merged, so re-merging it later needs the revert reverted first.', 20, false, true),
('7e6302e7-94fb-5bfd-9cfd-3c25776cbd39', '04d7844d-96d2-5567-8035-339262255ab7', 11, 'Cherry-pick a single commit', $md$feature/audit has two commits. Bring only "Add audit summary" onto main with cherry-pick, leaving auditlog.txt behind. The original author must be preserved.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Add audit summary" ] &&
[ "$(git -C $r log -1 --format=%an)" = "Priya Auditor" ] &&
[ -f $r/summary.txt ] && [ ! -f $r/auditlog.txt ] &&
[ "$(git -C $r rev-parse HEAD)" != "$(git -C $r rev-parse feature/audit)" ]
$script$, 'Find the hash with git log --oneline feature/audit, then git cherry-pick <hash> while on main.', 'cherry-pick re-applies one commit''s diff on top of the current branch as a brand-new commit (new hash), keeping the original author and message.', 15, false, true),
('2981d328-239a-5dfe-b2f5-9c8c18c75ebf', '04d7844d-96d2-5567-8035-339262255ab7', 12, 'Stash work in progress', $md$Append the line "WIP total" to ledger.txt, then stash it with the message "wip total" so the working tree is clean again.$md$, $script$r=/home/labuser/work/ledger
git -C $r stash list | grep -q 'wip total' &&
git -C $r diff --quiet HEAD &&
! grep -q 'WIP total' $r/ledger.txt
$script$, 'git stash push -m "wip total" saves tracked changes and restores a clean tree.', 'A stash is a commit stored outside your branches. It lets you switch context quickly and come back later.', 10, false, true),
('8190bf50-d5e0-5772-8076-5d250fe2915d', '04d7844d-96d2-5567-8035-339262255ab7', 13, 'Bring the stash back', $md$Re-apply the stashed change and drop it from the stash list in one step.$md$, $script$r=/home/labuser/work/ledger
[ -z "$(git -C $r stash list)" ] &&
grep -qx 'WIP total' $r/ledger.txt
$script$, 'git stash pop applies the newest stash and removes it; git stash apply would keep it.', 'pop = apply + drop. If applying hits a conflict, the stash is kept so you do not lose it.', 10, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('d38247c4-782e-542b-99a2-5bbdba9f4d1d', '04d7844d-96d2-5567-8035-339262255ab7', 1, $json$[{"id":"141985cb-97a4-5c88-a9aa-40e7e7ff8bac","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":1,"title":"Discard an unwanted edit","description":"In ~/work/ledger someone left a junk line (GARBAGE) in ledger.txt. Throw that uncommitted edit away so ledger.txt matches the last commit again.","verification_script":"r=/home/labuser/work/ledger\ngit -C $r diff --quiet -- ledger.txt \u0026\u0026 ! grep -q GARBAGE $r/ledger.txt\n","hint_context":"git restore \u003cfile\u003e copies the file from the index back into the working tree. It discards the edit permanently, so read git diff first.","explanation_context":"git restore (the modern replacement for git checkout -- file) overwrites the working-tree file from the index. Uncommitted edits are not in any commit, so this cannot be undone.","points":10,"is_optional":false,"is_stateful":true},{"id":"a34b655f-2bc5-5f37-a481-edcff6512e12","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":2,"title":"Unstage a file you must not commit","description":"secret.txt was staged by accident. Remove it from the staging area but keep the file on disk, untracked.","verification_script":"r=/home/labuser/work/ledger\ngit -C $r diff --cached --quiet \u0026\u0026\n[ -f $r/secret.txt ] \u0026\u0026\ngit -C $r ls-files --others --exclude-standard | grep -qx secret.txt\n","hint_context":"git restore --staged \u003cfile\u003e undoes git add without touching the file itself.","explanation_context":"restore --staged copies HEAD's version of the path into the index, so the file drops out of the next commit while your working copy stays intact.","points":10,"is_optional":false,"is_stateful":true},{"id":"65a85e80-ef62-54ee-a1c4-cb6536c6fba2","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":3,"title":"Re-do the last commit with reset --soft","description":"The last commit message \"Add Marsh entries\" has a typo. Move the branch back one commit while keeping the changes staged (reset --soft), then commit again with the message \"Add March entries\". There must still be exactly four commits on main.","verification_script":"r=/home/labuser/work/ledger\n[ \"$(git -C $r log -1 --format=%s)\" = \"Add March entries\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --count HEAD)\" = 4 ] \u0026\u0026\ngit -C $r diff --quiet HEAD \u0026\u0026\ngit -C $r reflog | grep -q 'reset: moving to'\n","hint_context":"git reset --soft HEAD~1 moves only the branch pointer; the old commit's changes stay staged, ready for git commit -m.","explanation_context":"--soft moves HEAD (and the branch) but leaves the index and working tree alone, so everything the undone commit contained is still staged.","points":15,"is_optional":false,"is_stateful":true},{"id":"9c8ac66e-d65d-5192-9505-eb21e286df15","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":4,"title":"Unstage everything with reset --mixed","description":"Step main back to \"Add February entries\" with a mixed reset, so the March line remains in ledger.txt as an unstaged working-tree change. Nothing may be staged.","verification_script":"r=/home/labuser/work/ledger\n[ \"$(git -C $r log -1 --format=%s)\" = \"Add February entries\" ] \u0026\u0026\ngit -C $r diff --cached --quiet \u0026\u0026\n! git -C $r diff --quiet -- ledger.txt \u0026\u0026\ngrep -qx 'Mar: 90' $r/ledger.txt \u0026\u0026\n[ \"$(git -C $r reflog | grep -c 'reset: moving to')\" -ge 2 ]\n","hint_context":"git reset (default is --mixed) HEAD~1. git status then lists ledger.txt under \"Changes not staged for commit\".","explanation_context":"--mixed moves HEAD and resets the index to match, but keeps the working tree. Your edits survive as plain unstaged modifications.","points":15,"is_optional":false,"is_stateful":true},{"id":"07d3e279-2564-567d-a8fb-9f192325bae8","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":5,"title":"Recommit March and add April","description":"Commit the March change again with the message \"Add March entries\", then create april.txt containing \"Apr: 200\" and commit it as \"Add April entries\".","verification_script":"r=/home/labuser/work/ledger\n[ \"$(git -C $r log --format=%s -3 | paste -sd,)\" = \"Add April entries,Add March entries,Add February entries\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --count HEAD)\" = 5 ] \u0026\u0026\ngit -C $r diff --quiet HEAD\n","hint_context":"git commit -am commits tracked-file changes. april.txt is new, so git add it first.","explanation_context":"This sets up a history with two commits you are about to throw away, so you can practise recovering them.","points":10,"is_optional":false,"is_stateful":true},{"id":"b8bff31a-8b6a-526c-9804-f91fcccb3f66","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":6,"title":"Throw work away with reset --hard","description":"Discard the last two commits AND their changes: reset --hard so main is back at \"Add February entries\" with no March line and no april.txt.","verification_script":"r=/home/labuser/work/ledger\n[ \"$(git -C $r log -1 --format=%s)\" = \"Add February entries\" ] \u0026\u0026\ngit -C $r diff --quiet HEAD \u0026\u0026\n[ ! -f $r/april.txt ] \u0026\u0026\n! grep -q 'Mar: 90' $r/ledger.txt\n","hint_context":"git reset --hard HEAD~2 rewinds the branch two commits and overwrites the working tree.","explanation_context":"--hard moves HEAD, resets the index and overwrites the working tree. The commits are no longer on any branch, but Git still remembers them in the reflog for a while.","points":10,"is_optional":false,"is_stateful":true},{"id":"e824955b-74a0-5850-8144-e27ceca3f164","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":7,"title":"Recover the lost commits from the reflog","description":"Oops - you needed April after all. Use git reflog to find the commit \"Add April entries\" and move main back to it so both the March and April commits are restored.","verification_script":"r=/home/labuser/work/ledger\n[ \"$(git -C $r log -1 --format=%s)\" = \"Add April entries\" ] \u0026\u0026\n[ -f $r/april.txt ] \u0026\u0026\ngit -C $r log --format=%s | grep -qx \"Add March entries\" \u0026\u0026\ngit -C $r diff --quiet HEAD\n","hint_context":"git reflog lists every position HEAD has been at. Find the line \"commit - Add April entries\" and git reset --hard \u003cthat hash\u003e.","explanation_context":"The reflog is a private diary of where your refs pointed. Commits unreachable from any branch survive until garbage collection (90 days by default), so a bad reset is recoverable.","points":20,"is_optional":false,"is_stateful":true},{"id":"014a12bc-96e3-56d9-8209-604d337051ca","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":8,"title":"Revert a published commit","description":"The March entries were wrong, but history is already shared so you must not rewrite it. Revert the commit \"Add March entries\" with git revert (default message), keeping April.","verification_script":"r=/home/labuser/work/ledger\n[ \"$(git -C $r log -1 --format=%s)\" = 'Revert \"Add March entries\"' ] \u0026\u0026\n! grep -q 'Mar: 90' $r/ledger.txt \u0026\u0026\n[ -f $r/april.txt ] \u0026\u0026\ngit -C $r log --format=%s | grep -qx \"Add March entries\"\n","hint_context":"git revert \u003chash-of-March-commit\u003e --no-edit. Find the hash with git log --oneline.","explanation_context":"revert creates a NEW commit that applies the inverse patch. The original commit stays in history, so it is safe on shared branches, unlike reset.","points":15,"is_optional":false,"is_stateful":true},{"id":"e667f5e3-9ff6-572e-8709-b211bbcfb06d","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":9,"title":"Merge a feature branch","description":"Merge feature/bonus into main with --no-ff and the message \"Merge feature/bonus\".","verification_script":"r=/home/labuser/work/ledger\n[ \"$(git -C $r log -1 --format=%s)\" = \"Merge feature/bonus\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --parents -n 1 HEAD | wc -w)\" = 3 ] \u0026\u0026\n[ -f $r/bonus.txt ]\n","hint_context":"git merge --no-ff feature/bonus -m \"Merge feature/bonus\".","explanation_context":"This creates a merge commit with two parents, which is what makes reverting a merge special in the next task.","points":10,"is_optional":false,"is_stateful":true},{"id":"2632023f-1e2a-5162-86ff-60729a508cc5","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":10,"title":"Revert a merge commit with -m 1","description":"The bonus feature must come out. Revert the merge commit itself. A merge has two parents so Git needs to know which side to keep - use mainline parent 1 (the main side).","verification_script":"r=/home/labuser/work/ledger\n[ \"$(git -C $r log -1 --format=%s)\" = 'Revert \"Merge feature/bonus\"' ] \u0026\u0026\n[ \"$(git -C $r rev-list --parents -n 1 HEAD | wc -w)\" = 2 ] \u0026\u0026\n[ ! -f $r/bonus.txt ] \u0026\u0026\ngit -C $r merge-base --is-ancestor feature/bonus HEAD\n","hint_context":"git revert -m 1 HEAD --no-edit. Without -m Git refuses because it cannot tell which parent is the mainline.","explanation_context":"-m 1 says \"undo the changes relative to parent 1\", i.e. everything the merge brought in from the other branch. Note that Git now considers that branch already merged, so re-merging it later needs the revert reverted first.","points":20,"is_optional":false,"is_stateful":true},{"id":"7e6302e7-94fb-5bfd-9cfd-3c25776cbd39","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":11,"title":"Cherry-pick a single commit","description":"feature/audit has two commits. Bring only \"Add audit summary\" onto main with cherry-pick, leaving auditlog.txt behind. The original author must be preserved.","verification_script":"r=/home/labuser/work/ledger\n[ \"$(git -C $r log -1 --format=%s)\" = \"Add audit summary\" ] \u0026\u0026\n[ \"$(git -C $r log -1 --format=%an)\" = \"Priya Auditor\" ] \u0026\u0026\n[ -f $r/summary.txt ] \u0026\u0026 [ ! -f $r/auditlog.txt ] \u0026\u0026\n[ \"$(git -C $r rev-parse HEAD)\" != \"$(git -C $r rev-parse feature/audit)\" ]\n","hint_context":"Find the hash with git log --oneline feature/audit, then git cherry-pick \u003chash\u003e while on main.","explanation_context":"cherry-pick re-applies one commit's diff on top of the current branch as a brand-new commit (new hash), keeping the original author and message.","points":15,"is_optional":false,"is_stateful":true},{"id":"2981d328-239a-5dfe-b2f5-9c8c18c75ebf","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":12,"title":"Stash work in progress","description":"Append the line \"WIP total\" to ledger.txt, then stash it with the message \"wip total\" so the working tree is clean again.","verification_script":"r=/home/labuser/work/ledger\ngit -C $r stash list | grep -q 'wip total' \u0026\u0026\ngit -C $r diff --quiet HEAD \u0026\u0026\n! grep -q 'WIP total' $r/ledger.txt\n","hint_context":"git stash push -m \"wip total\" saves tracked changes and restores a clean tree.","explanation_context":"A stash is a commit stored outside your branches. It lets you switch context quickly and come back later.","points":10,"is_optional":false,"is_stateful":true},{"id":"8190bf50-d5e0-5772-8076-5d250fe2915d","lab_id":"04d7844d-96d2-5567-8035-339262255ab7","position":13,"title":"Bring the stash back","description":"Re-apply the stashed change and drop it from the stash list in one step.","verification_script":"r=/home/labuser/work/ledger\n[ -z \"$(git -C $r stash list)\" ] \u0026\u0026\ngrep -qx 'WIP total' $r/ledger.txt\n","hint_context":"git stash pop applies the newest stash and removes it; git stash apply would keep it.","explanation_context":"pop = apply + drop. If applying hits a conflict, the stash is kept so you do not lose it.","points":10,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('1ea1e827-b28d-5ef1-83c0-d142c0f69605', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', '141985cb-97a4-5c88-a9aa-40e7e7ff8bac', 1, 'Discard an unwanted edit', $md$In ~/work/ledger someone left a junk line (GARBAGE) in ledger.txt. Throw that uncommitted edit away so ledger.txt matches the last commit again.$md$, $script$r=/home/labuser/work/ledger
git -C $r diff --quiet -- ledger.txt && ! grep -q GARBAGE $r/ledger.txt
$script$, 'git restore <file> copies the file from the index back into the working tree. It discards the edit permanently, so read git diff first.', 'git restore (the modern replacement for git checkout -- file) overwrites the working-tree file from the index. Uncommitted edits are not in any commit, so this cannot be undone.', 10, false, true),
('70eff26b-58e6-509d-af4e-d595b680efab', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', 'a34b655f-2bc5-5f37-a481-edcff6512e12', 2, 'Unstage a file you must not commit', $md$secret.txt was staged by accident. Remove it from the staging area but keep the file on disk, untracked.$md$, $script$r=/home/labuser/work/ledger
git -C $r diff --cached --quiet &&
[ -f $r/secret.txt ] &&
git -C $r ls-files --others --exclude-standard | grep -qx secret.txt
$script$, 'git restore --staged <file> undoes git add without touching the file itself.', 'restore --staged copies HEAD''s version of the path into the index, so the file drops out of the next commit while your working copy stays intact.', 10, false, true),
('4e0a77dd-4af1-5f0e-80f8-329f6973035b', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', '65a85e80-ef62-54ee-a1c4-cb6536c6fba2', 3, 'Re-do the last commit with reset --soft', $md$The last commit message "Add Marsh entries" has a typo. Move the branch back one commit while keeping the changes staged (reset --soft), then commit again with the message "Add March entries". There must still be exactly four commits on main.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Add March entries" ] &&
[ "$(git -C $r rev-list --count HEAD)" = 4 ] &&
git -C $r diff --quiet HEAD &&
git -C $r reflog | grep -q 'reset: moving to'
$script$, 'git reset --soft HEAD~1 moves only the branch pointer; the old commit''s changes stay staged, ready for git commit -m.', '--soft moves HEAD (and the branch) but leaves the index and working tree alone, so everything the undone commit contained is still staged.', 15, false, true),
('9660e933-a410-5380-b0e3-21a6f13c4bc0', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', '9c8ac66e-d65d-5192-9505-eb21e286df15', 4, 'Unstage everything with reset --mixed', $md$Step main back to "Add February entries" with a mixed reset, so the March line remains in ledger.txt as an unstaged working-tree change. Nothing may be staged.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Add February entries" ] &&
git -C $r diff --cached --quiet &&
! git -C $r diff --quiet -- ledger.txt &&
grep -qx 'Mar: 90' $r/ledger.txt &&
[ "$(git -C $r reflog | grep -c 'reset: moving to')" -ge 2 ]
$script$, 'git reset (default is --mixed) HEAD~1. git status then lists ledger.txt under "Changes not staged for commit".', '--mixed moves HEAD and resets the index to match, but keeps the working tree. Your edits survive as plain unstaged modifications.', 15, false, true),
('cc50d4b4-964c-5488-9f42-dc7f3e3eb526', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', '07d3e279-2564-567d-a8fb-9f192325bae8', 5, 'Recommit March and add April', $md$Commit the March change again with the message "Add March entries", then create april.txt containing "Apr: 200" and commit it as "Add April entries".$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log --format=%s -3 | paste -sd,)" = "Add April entries,Add March entries,Add February entries" ] &&
[ "$(git -C $r rev-list --count HEAD)" = 5 ] &&
git -C $r diff --quiet HEAD
$script$, 'git commit -am commits tracked-file changes. april.txt is new, so git add it first.', 'This sets up a history with two commits you are about to throw away, so you can practise recovering them.', 10, false, true),
('7430200c-20ba-542c-af2a-2050915b216e', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', 'b8bff31a-8b6a-526c-9804-f91fcccb3f66', 6, 'Throw work away with reset --hard', $md$Discard the last two commits AND their changes: reset --hard so main is back at "Add February entries" with no March line and no april.txt.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Add February entries" ] &&
git -C $r diff --quiet HEAD &&
[ ! -f $r/april.txt ] &&
! grep -q 'Mar: 90' $r/ledger.txt
$script$, 'git reset --hard HEAD~2 rewinds the branch two commits and overwrites the working tree.', '--hard moves HEAD, resets the index and overwrites the working tree. The commits are no longer on any branch, but Git still remembers them in the reflog for a while.', 10, false, true),
('1390a89c-5c1b-545b-8ceb-ac218496b0e1', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', 'e824955b-74a0-5850-8144-e27ceca3f164', 7, 'Recover the lost commits from the reflog', $md$Oops - you needed April after all. Use git reflog to find the commit "Add April entries" and move main back to it so both the March and April commits are restored.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Add April entries" ] &&
[ -f $r/april.txt ] &&
git -C $r log --format=%s | grep -qx "Add March entries" &&
git -C $r diff --quiet HEAD
$script$, 'git reflog lists every position HEAD has been at. Find the line "commit - Add April entries" and git reset --hard <that hash>.', 'The reflog is a private diary of where your refs pointed. Commits unreachable from any branch survive until garbage collection (90 days by default), so a bad reset is recoverable.', 20, false, true),
('0069b923-ca58-50f6-94a9-b1e20c8dc85c', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', '014a12bc-96e3-56d9-8209-604d337051ca', 8, 'Revert a published commit', $md$The March entries were wrong, but history is already shared so you must not rewrite it. Revert the commit "Add March entries" with git revert (default message), keeping April.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = 'Revert "Add March entries"' ] &&
! grep -q 'Mar: 90' $r/ledger.txt &&
[ -f $r/april.txt ] &&
git -C $r log --format=%s | grep -qx "Add March entries"
$script$, 'git revert <hash-of-March-commit> --no-edit. Find the hash with git log --oneline.', 'revert creates a NEW commit that applies the inverse patch. The original commit stays in history, so it is safe on shared branches, unlike reset.', 15, false, true),
('55199883-edd1-587e-aea8-7ffa70343e54', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', 'e667f5e3-9ff6-572e-8709-b211bbcfb06d', 9, 'Merge a feature branch', $md$Merge feature/bonus into main with --no-ff and the message "Merge feature/bonus".$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Merge feature/bonus" ] &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 3 ] &&
[ -f $r/bonus.txt ]
$script$, 'git merge --no-ff feature/bonus -m "Merge feature/bonus".', 'This creates a merge commit with two parents, which is what makes reverting a merge special in the next task.', 10, false, true),
('327a582c-355f-5d24-9315-3080f7c871ef', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', '2632023f-1e2a-5162-86ff-60729a508cc5', 10, 'Revert a merge commit with -m 1', $md$The bonus feature must come out. Revert the merge commit itself. A merge has two parents so Git needs to know which side to keep - use mainline parent 1 (the main side).$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = 'Revert "Merge feature/bonus"' ] &&
[ "$(git -C $r rev-list --parents -n 1 HEAD | wc -w)" = 2 ] &&
[ ! -f $r/bonus.txt ] &&
git -C $r merge-base --is-ancestor feature/bonus HEAD
$script$, 'git revert -m 1 HEAD --no-edit. Without -m Git refuses because it cannot tell which parent is the mainline.', '-m 1 says "undo the changes relative to parent 1", i.e. everything the merge brought in from the other branch. Note that Git now considers that branch already merged, so re-merging it later needs the revert reverted first.', 20, false, true),
('904af7b4-30f8-5071-9d01-9fc4da9ebc4a', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', '7e6302e7-94fb-5bfd-9cfd-3c25776cbd39', 11, 'Cherry-pick a single commit', $md$feature/audit has two commits. Bring only "Add audit summary" onto main with cherry-pick, leaving auditlog.txt behind. The original author must be preserved.$md$, $script$r=/home/labuser/work/ledger
[ "$(git -C $r log -1 --format=%s)" = "Add audit summary" ] &&
[ "$(git -C $r log -1 --format=%an)" = "Priya Auditor" ] &&
[ -f $r/summary.txt ] && [ ! -f $r/auditlog.txt ] &&
[ "$(git -C $r rev-parse HEAD)" != "$(git -C $r rev-parse feature/audit)" ]
$script$, 'Find the hash with git log --oneline feature/audit, then git cherry-pick <hash> while on main.', 'cherry-pick re-applies one commit''s diff on top of the current branch as a brand-new commit (new hash), keeping the original author and message.', 15, false, true),
('7d31e86f-a75b-5d29-92d3-971e10196ecc', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', '2981d328-239a-5dfe-b2f5-9c8c18c75ebf', 12, 'Stash work in progress', $md$Append the line "WIP total" to ledger.txt, then stash it with the message "wip total" so the working tree is clean again.$md$, $script$r=/home/labuser/work/ledger
git -C $r stash list | grep -q 'wip total' &&
git -C $r diff --quiet HEAD &&
! grep -q 'WIP total' $r/ledger.txt
$script$, 'git stash push -m "wip total" saves tracked changes and restores a clean tree.', 'A stash is a commit stored outside your branches. It lets you switch context quickly and come back later.', 10, false, true),
('de51fdbd-8ce0-5e54-bdf5-a09660615180', 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', '8190bf50-d5e0-5772-8076-5d250fe2915d', 13, 'Bring the stash back', $md$Re-apply the stashed change and drop it from the stash list in one step.$md$, $script$r=/home/labuser/work/ledger
[ -z "$(git -C $r stash list)" ] &&
grep -qx 'WIP total' $r/ledger.txt
$script$, 'git stash pop applies the newest stash and removes it; git stash apply would keep it.', 'pop = apply + drop. If applying hits a conflict, the stash is kept so you do not lose it.', 10, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'd38247c4-782e-542b-99a2-5bbdba9f4d1d', updated_at = now()
WHERE id = '04d7844d-96d2-5567-8035-339262255ab7' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e81bb4ec-300b-53f4-a3e8-4138e75b1351', '00000000-0000-0000-0000-000000000001', 'mcq', 'A commit with a broken migration was pushed to main an hour ago; CI and two t...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7dba6e0b-0124-59dd-b75d-8c998d8c7ef6', 'e81bb4ec-300b-53f4-a3e8-4138e75b1351', 1, $json${"prompt":"A commit with a broken migration was pushed to main an hour ago; CI and two teammates have pulled it. What is the right undo?","multiple":false,"options":[{"id":"a","text":"git reset --hard HEAD~1 and git push --force","is_correct":false},{"id":"b","text":"git revert \u003chash\u003e and git push","is_correct":true},{"id":"c","text":"git restore --source=HEAD~1 . and commit nothing","is_correct":false},{"id":"d","text":"git commit --amend and push","is_correct":false}],"explanation":"Shared history must only grow, so add an inverse commit. reset + force and amend + push both rewrite commits others have; restoring files without committing changes nothing for anyone else."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('4f620d64-9b25-58fc-ba6d-c7753d1fb803', '00000000-0000-0000-0000-000000000001', 'mcq', 'You made 4 local commits that should be one. You want all their changes stage...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d55562c2-511b-5115-af8f-895d070f2fc3', '4f620d64-9b25-58fc-ba6d-c7753d1fb803', 1, $json${"prompt":"You made 4 local commits that should be one. You want all their changes staged so you can commit once. Which command?","multiple":false,"options":[{"id":"a","text":"git reset --soft HEAD~4","is_correct":true},{"id":"b","text":"git reset --hard HEAD~4","is_correct":false},{"id":"c","text":"git revert HEAD~4","is_correct":false},{"id":"d","text":"git restore --staged .","is_correct":false}],"explanation":"--soft moves the branch back but leaves everything staged. --hard would discard the changes, revert adds an inverse commit, and restore --staged unstages instead of un-committing."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2f782b52-2f0c-58ae-9d15-10a3794bbdeb', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which of these can permanently lose work that Git cannot recover?', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('076e20aa-8b66-5bf9-a56a-831490ff5591', '2f782b52-2f0c-58ae-9d15-10a3794bbdeb', 1, $json${"prompt":"Which of these can permanently lose work that Git cannot recover?","multiple":false,"options":[{"id":"a","text":"git reset --hard HEAD~2 on committed work","is_correct":false},{"id":"b","text":"git branch -D feature after committing on it","is_correct":false},{"id":"c","text":"git restore app.py on edits that were never staged or committed","is_correct":true},{"id":"d","text":"Dropping a commit in interactive rebase","is_correct":false}],"explanation":"Never-staged edits were never stored, so nothing can bring them back. The other three lose only refs; the commits are still in the reflog."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('05c39bfa-1281-5ed7-bef2-c873ebe5129a', '00000000-0000-0000-0000-000000000001', 'mcq', 'You reverted a merge of feature/search last week. The team fixed the bug on f...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('048c3685-7d29-5940-b477-529319354c26', '05c39bfa-1281-5ed7-bef2-c873ebe5129a', 1, $json${"prompt":"You reverted a merge of feature/search last week. The team fixed the bug on feature/search and merged it again, but most of the search code is still missing on main. Why?","multiple":false,"options":[{"id":"a","text":"Git considers the old feature commits already merged, and the revert still undoes them; revert the revert first","is_correct":true},{"id":"b","text":"Merges never bring back deleted files","is_correct":false},{"id":"c","text":"The second merge needed --no-ff","is_correct":false},{"id":"d","text":"rerere replayed an old resolution","is_correct":false}],"explanation":"Reverting a merge undoes the changes but not the fact that the commits are ancestors of main. Only the new fix commits come in on re-merge. --no-ff and rerere do not matter here, and merges can restore files."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a0b80466-0b3c-5a38-a5d5-aece6a15af52', '00000000-0000-0000-0000-000000000001', 'mcq', 'A security fix is on main as commit 9f2c1e7. Release branch release/1.4 needs...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('694653db-8426-5883-9916-dae87d1b825a', 'a0b80466-0b3c-5a38-a5d5-aece6a15af52', 1, $json${"prompt":"A security fix is on main as commit 9f2c1e7. Release branch release/1.4 needs only that fix. What do you run on release/1.4?","multiple":false,"options":[{"id":"a","text":"git merge main","is_correct":false},{"id":"b","text":"git cherry-pick -x 9f2c1e7","is_correct":true},{"id":"c","text":"git rebase main","is_correct":false},{"id":"d","text":"git revert 9f2c1e7","is_correct":false}],"explanation":"cherry-pick copies just that commit; -x records the source. Merging or rebasing would bring every other main commit into the release, and revert would undo the fix."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e02b832f-9c5b-5182-abff-dccbf9cd3d27', '00000000-0000-0000-0000-000000000001', 'mcq', 'You need to switch branches urgently. You have edits to two tracked files and...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('24c77486-199b-5e89-a5f5-0d4129a59b8e', 'e02b832f-9c5b-5182-abff-dccbf9cd3d27', 1, $json${"prompt":"You need to switch branches urgently. You have edits to two tracked files and one new untracked file. Which command parks all three?","multiple":false,"options":[{"id":"a","text":"git stash","is_correct":false},{"id":"b","text":"git stash push -u","is_correct":true},{"id":"c","text":"git stash apply","is_correct":false},{"id":"d","text":"git restore .","is_correct":false}],"explanation":"-u includes untracked files; plain stash would leave the new file behind. apply restores a stash rather than creating one, and restore discards edits."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2db1de1a-3d24-5247-9e7d-e206b2dce67b', '00000000-0000-0000-0000-000000000001', 'mcq', 'After `git reset --hard HEAD~3` you realise you needed those commits. `git re...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0e2a5de8-6fa3-56b2-9172-309b447edf28', '2db1de1a-3d24-5247-9e7d-e206b2dce67b', 1, $json${"prompt":"After `git reset --hard HEAD~3` you realise you needed those commits. `git reflog` shows `HEAD@{0}: reset: moving to HEAD~3` and `HEAD@{1}: commit: Add export`. What restores the branch?","multiple":false,"options":[{"id":"a","text":"git reset --hard HEAD@{1}","is_correct":true},{"id":"b","text":"git reset --hard HEAD@{0}","is_correct":false},{"id":"c","text":"git revert HEAD@{1}","is_correct":false},{"id":"d","text":"git stash pop","is_correct":false}],"explanation":"Each reflog line is the state after an action; HEAD@{1} is the state just before the reset. HEAD@{0} is the current (bad) state, revert would add an inverse commit, and stash is unrelated."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c834b956-f6d8-5623-a786-565e57e604d2', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 8): you rebased your already-pushed PR branch. What is the co...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('77bcf2ef-9be5-52ad-b9a7-973ffabd9441', 'c834b956-f6d8-5623-a786-565e57e604d2', 1, $json${"prompt":"Review (Section 8): you rebased your already-pushed PR branch. What is the correct push?","multiple":false,"options":[{"id":"a","text":"git push --force-with-lease","is_correct":true},{"id":"b","text":"git push","is_correct":false},{"id":"c","text":"git push --force on main","is_correct":false},{"id":"d","text":"git push --tags","is_correct":false}],"explanation":"History was rewritten, so a plain push is rejected; the lease protects any commits you have not seen. Force-pushing main is never right, and --tags pushes tags only."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('d201c7be-1668-559c-a600-f5f8dc71bfef', '00000000-0000-0000-0000-000000000001', 'Quiz: Undo and Recovery', 'git-undo-recovery-quiz', 'Quiz covering Undo and Recovery.', 'mcq', 'published', 'module', '8c6e0590-7180-5b22-8458-4d3ad9353d1f', 15, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'd201c7be-1668-559c-a600-f5f8dc71bfef' AND question_id NOT IN ('e81bb4ec-300b-53f4-a3e8-4138e75b1351', '4f620d64-9b25-58fc-ba6d-c7753d1fb803', '2f782b52-2f0c-58ae-9d15-10a3794bbdeb', '05c39bfa-1281-5ed7-bef2-c873ebe5129a', 'a0b80466-0b3c-5a38-a5d5-aece6a15af52', 'e02b832f-9c5b-5182-abff-dccbf9cd3d27', '2db1de1a-3d24-5247-9e7d-e206b2dce67b', 'c834b956-f6d8-5623-a786-565e57e604d2');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('01e1a975-35a8-58f7-b4cb-e636fcb033c1', 'd201c7be-1668-559c-a600-f5f8dc71bfef', 'e81bb4ec-300b-53f4-a3e8-4138e75b1351', '7dba6e0b-0124-59dd-b75d-8c998d8c7ef6', 0, 2),
('24f7ece5-bb55-5f74-8388-ec4c8e52f03b', 'd201c7be-1668-559c-a600-f5f8dc71bfef', '4f620d64-9b25-58fc-ba6d-c7753d1fb803', 'd55562c2-511b-5115-af8f-895d070f2fc3', 1, 2),
('cec18b1b-a413-57e0-9727-82c5ccd345c6', 'd201c7be-1668-559c-a600-f5f8dc71bfef', '2f782b52-2f0c-58ae-9d15-10a3794bbdeb', '076e20aa-8b66-5bf9-a56a-831490ff5591', 2, 2),
('d0a52ddb-f208-5b72-990a-23a29b34703b', 'd201c7be-1668-559c-a600-f5f8dc71bfef', '05c39bfa-1281-5ed7-bef2-c873ebe5129a', '048c3685-7d29-5940-b477-529319354c26', 3, 2),
('471f126d-a31b-591f-9f91-9a67a8209076', 'd201c7be-1668-559c-a600-f5f8dc71bfef', 'a0b80466-0b3c-5a38-a5d5-aece6a15af52', '694653db-8426-5883-9916-dae87d1b825a', 4, 2),
('568f515d-670f-5e37-8d81-0ab6525a99fd', 'd201c7be-1668-559c-a600-f5f8dc71bfef', 'e02b832f-9c5b-5182-abff-dccbf9cd3d27', '24c77486-199b-5e89-a5f5-0d4129a59b8e', 5, 2),
('4b562174-ded4-5fa7-9724-6865987a66de', 'd201c7be-1668-559c-a600-f5f8dc71bfef', '2db1de1a-3d24-5247-9e7d-e206b2dce67b', '0e2a5de8-6fa3-56b2-9172-309b447edf28', 6, 2),
('b446a616-735d-5508-8f9b-2eb2b05a4066', 'd201c7be-1668-559c-a600-f5f8dc71bfef', 'c834b956-f6d8-5623-a786-565e57e604d2', '77bcf2ef-9be5-52ad-b9a7-973ffabd9441', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('8c6e0590-7180-5b22-8458-4d3ad9353d1f', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '7a77d065-f51b-5ec5-9aea-a09bdcfb797c', 'Quiz: Undo and Recovery', 'assessment', 7, 12, 'd201c7be-1668-559c-a600-f5f8dc71bfef')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Investigating History
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('462878a1-6134-50d3-953c-444b70b83668', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Investigating History', 10, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('c88b17d1-e601-5190-8efa-b6f4d275192e', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '462878a1-6134-50d3-953c-444b70b83668', 'Reading History with log and show', 'notes', 0, $md$## Why this matters

Production is broken. A test that passed last week now fails. Who changed what,
when and why? History answers that, but `git log` on a real project prints
thousands of commits. You need filters that cut it to the five commits that
matter.

## Mental model: a searchable logbook

`git log` is a ship's logbook. You rarely read it front to back; you ask
questions: "entries by Dave", "entries touching tax.sh", "entries last week",
"entries on this branch but not on main". Each question is a flag.

## See it work

### Shapes of output

```bash
git log --oneline -5                     # last 5, one line each
git log --oneline --graph --all          # every branch as a graph
git log --stat -3                        # which files each commit changed
git log -p -1                            # full patch of the latest commit
git log --format='%h %an %ad %s' --date=short -3
```

What the last one prints (format placeholders: `%h` short hash, `%an` author,
`%ad` date, `%s` subject):

```
a71e3c9 Heidi Renamer 2024-06-13 Rename price helper
9e1b3d0 Bob Docs 2024-06-12 Tidy up
5f0e2c8 Alice Dev 2024-06-11 Bump timeout
```

### Filters

| Question | Command |
|---|---|
| By author | `git log --author="Dave"` |
| By message text | `git log --grep="tax" -i` |
| By date | `git log --since="2 weeks ago" --until=yesterday` |
| Touching a file or folder | `git log -- tax.sh` |
| On feature, not on main | `git log main..feature` |
| Only merges / no merges | `--merges` / `--no-merges` |
| Main line only (one entry per merged PR) | `git log --first-parent main` |

Combine freely: `git log --author=Dave --since=1.week -- src/`.

The `--` separates options and revisions from **paths**. Use it whenever a file
name could look like a branch name.

### show: one object in detail

```bash
git show 7a3f9c1                 # metadata + patch of one commit
git show -s --format='%an <%ae>' 7a3f9c1   # just the author line
git show v1.0:tax.sh             # a file as it was at a tag
git show v1.0                    # tag info + the commit
```

Expected output of the second command:

```
Dave Hotfix <dave@example.com>
```

### Who did how much

```bash
git shortlog -sn          # commit counts per author
```

## Try it

Write one command that lists, one line each, the commits from the last 30 days
that touched anything under `src/payments/`, excluding merges.

<details>
<summary>Show answer</summary>

```bash
git log --oneline --since="30 days ago" --no-merges -- src/payments/
```

</details>

## Common mistakes

- **Reading `git log` without `--oneline` or a limit.** You drown. Start narrow.
- **Forgetting `--all`.** Without it, `log` shows only commits reachable from
  HEAD, so other branches look missing.
- **Author vs committer.** After rebase or cherry-pick they can differ;
  `%an` is who wrote it, `%cn` who applied it.

## Remember

- `--oneline --graph --all` for shape; `--stat` / `-p` for detail.
- Filter by `--author`, `--grep`, `--since`, `-- <path>`, `A..B`.
- `git show <rev>` for one commit; `git show <rev>:<path>` for an old file.
- `--first-parent` reads a merge-based main branch as one entry per feature.

**Self-check:**

1. How do you list commits on `feature` that are not on `main`?
2. What does `--` do in `git log -- tax.sh`?
3. How do you print an old version of a file without checking it out?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('860fbf9f-197a-5bc2-bfa6-2cf196f6eada', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '462878a1-6134-50d3-953c-444b70b83668', 'blame: Who Last Changed This Line, Really?', 'notes', 1, $md$## Why this matters

You find a strange line: `rate=15`. Before changing it you want the commit that
introduced it and the reason in its message. `git blame` finds that commit in
seconds. But reformatting and moved code fool it, so you also need the flags
that see through refactors.

(Despite the name, blame is about context, not fault. Many tools call it
"annotate".)

## Mental model: a sticky note on every line

Blame puts a sticky note on each line: "last changed by commit X, author Y, on
date Z". It shows only the **last** change. To go further back you then run
`git log` or blame the parent commit.

```
 commit history of tax.sh                 git blame -L1,1 tax.sh
 c1 Alice: rate=10                        ^
 c7 Dave : rate=15   <- last change  --->  7a3f9c1 (Dave Hotfix 2024-06-07 1) rate=15
```

## See it work

### Basic blame on a line range

```bash
cd ~/work/inventory
git blame -L1,1 tax.sh
```

What this does: annotates only line 1. Expected output (hash differs):

```
7a3f9c1 (Dave Hotfix 2024-06-07 10:00:00 +0000 1) rate=15
```

Then read the why: `git show 7a3f9c1`.

`-L` also accepts a function: `git blame -L :tax tax.sh` (by funcname regex).

```knowledge-check
{ "questions": [
  { "id": "git-inv-blame-q1", "type": "mcq",
    "prompt": "What does git blame show for a line?",
    "options": [
      {"id":"a","text":"The commit and author that most recently changed that line"},
      {"id":"b","text":"The person who reviewed it"},
      {"id":"c","text":"Every commit that ever touched the file"},
      {"id":"d","text":"The branch it lives on"}],
    "correct": "a",
    "explanation": "Blame is about the last change to each line, which is the starting point for digging deeper with git log. Git does not know reviewers, does not list every commit, and does not track branches per line." }
] }
```

### Seeing through refactors

Reformatting and moving code make plain blame name the wrong person.

```
 c4 Carol writes  "  echo $(( $1 * 10 / 100 ))"
 c9 Eve re-indents "\techo ..."           plain blame -> Eve      blame -w -> Carol

 c6 Gina writes shipping.sh
 c10 Frank moves the lines to util.sh    plain blame -> Frank    blame -C -> Gina
```

```bash
git blame -L2,2 discount.sh        # Eve
git blame -w -L2,2 discount.sh     # Carol
git blame util.sh | sed -n 4p      # Frank
git blame -C util.sh | sed -n 4p   # Gina (run it on the whole file, not with -L)
```

Expected output of the first two:

```
d41e0b7 (Eve Formatter 2024-06-09 10:00:00 +0000 2) 	echo $(( $1 * 10 / 100 ))
b09c7a2 (Carol Pricing 2024-06-04 10:00:00 +0000 2) 	echo $(( $1 * 10 / 100 ))
```

| Flag | Ignores / follows |
|---|---|
| `-w` | Whitespace-only changes |
| `-M` | Lines moved **within** the file |
| `-C` | Lines moved/copied from other files changed in the same commit |
| `-C -C` / `-C -C -C` | Also the commit that created the file / any commit (slower) |

```knowledge-check
{ "questions": [
  { "id": "git-inv-blamewc-q1", "type": "mcq",
    "prompt": "A formatter re-indented a file and now blame names the formatter. Which flag finds the real author?",
    "options": [
      {"id":"a","text":"-w to ignore whitespace changes"},
      {"id":"b","text":"-q"},
      {"id":"c","text":"--first-parent"},
      {"id":"d","text":"-v"}],
    "correct": "a",
    "explanation": "-w ignores whitespace when attributing lines. The other flags do not change how whitespace edits are attributed." },
  { "id": "git-inv-blamewc-q2", "type": "mcq",
    "prompt": "Code was moved from one file to another in a single commit. Which flag lets blame follow it?",
    "options": [
      {"id":"a","text":"-C"},
      {"id":"b","text":"-w"},
      {"id":"c","text":"-L"},
      {"id":"d","text":"-s"}],
    "correct": "a",
    "explanation": "-C detects lines moved or copied between files; repeat it for deeper searches. -w handles whitespace, -L limits lines, and -s hides author names." }
] }
```

### Ignore known bulk-formatting commits for everyone

List the hashes of "reformat the whole codebase" commits in a file and tell
blame to skip them:

```bash
echo d41e0b7... >> .git-blame-ignore-revs
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

GitHub and GitLab read `.git-blame-ignore-revs` automatically in their blame
views.

## Try it

`git blame` says line 40 of `api.py` was last changed by commit `abc123`
"Rename variables". You want the commit before that which wrote the logic. What
do you run?

<details>
<summary>Show answer</summary>

Blame the parent of that commit:

```bash
git blame -L40,40 abc123^ -- api.py
```

(The line number may shift slightly in older versions; adjust or use `-L :func`.)
Or follow the line's whole history with `git log -L40,40:api.py`.

</details>

## Common mistakes

- **Stopping at the first answer.** The last change is often a rename or
  reformat. Use `-w`, `-C`, or blame the parent.
- **Using blame to point fingers.** Use it to find the commit message and the
  pull request that explain *why*.
- **`-C` with `-L` on a narrow range.** Detection can miss moves; blame the
  whole file and pick the line.

## Remember

- `git blame -L a,b file` = last commit per line in a range.
- `-w` sees through re-indents; `-C` follows code moved between files.
- `.git-blame-ignore-revs` hides formatting commits for the whole team.
- After blame, `git show <hash>` to read the reason.

**Self-check:**

1. What does blame show: the first or the last change to a line?
2. Which flag handles a reformat, and which handles moved code?
3. How do you look further back than the last change?
$md$, 8, $json$[{"id":"git-inv-blame-q1","type":"mcq","correct":"a"},{"id":"git-inv-blamewc-q1","type":"mcq","correct":"a"},{"id":"git-inv-blamewc-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0067b420-0f5e-52bc-a262-582ab17dc51b', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '462878a1-6134-50d3-953c-444b70b83668', 'Searching History: log -S, -G, -L and --follow', 'notes', 2, $md$## Why this matters

Blame works for code that still exists. But what about a constant that was
**deleted**, a value that changed months ago, or a file that was renamed?
Git can search inside every diff ever made. These "pickaxe" searches answer
"when did this string appear or disappear?".

## Mental model: two different metal detectors

- `-S 'text'` beeps when the **number of occurrences** of the text changes in a
  commit, i.e. it was added or removed.
- `-G 'regex'` beeps when any **added or removed line** matches, which also
  catches edits where the text stays but the line changes.

```
 -S 'text'   commits where the COUNT of 'text' changed (added / removed)
 -G 'regex'  commits whose diff has a +/- line matching regex (also catches edits)
 --follow f  history of one file across renames

 config.sh:   Misc changes  (+timeout=30 +LEGACY_FLAG=1)
              Bump timeout  (-timeout=30 +timeout=45)   found by -G, NOT by -S 'timeout='
              Tidy up       (-LEGACY_FLAG=1)             found by -S LEGACY_FLAG
```

## See it work

### When was it added, when removed?

```bash
git log -S LEGACY_FLAG --oneline
```

Expected output:

```
9e1b3d0 Tidy up
c3a77f4 Misc changes
```

Newest first: removed in "Tidy up", added in "Misc changes". Add `-p` to see
the diffs.

### When did the value change?

```bash
git log -G 'timeout=' --oneline
```

Expected output:

```
5f0e2c8 Bump timeout
c3a77f4 Misc changes
```

`-S 'timeout='` would show only "Misc changes": in "Bump timeout" one
`timeout=` line was removed and one added, so the count did not change.

```knowledge-check
{ "questions": [
  { "id": "git-inv-search-q1", "type": "mcq",
    "prompt": "A value changed from timeout=30 to timeout=45. Which search finds that commit?",
    "options": [
      {"id":"a","text":"git log -S 'timeout='"},
      {"id":"b","text":"git log -G 'timeout='"},
      {"id":"c","text":"git log --follow"},
      {"id":"d","text":"git blame -C"}],
    "correct": "b",
    "explanation": "-S only fires when the number of occurrences changes; -G matches any changed line. --follow tracks renames, and blame -C follows moved code but does not search history for a value change." }
] }
```

### Across renames: --follow

```bash
git log --follow --oneline -- pricing.sh
```

Expected output (last line = creation under the old name `price.sh`):

```
a71e3c9 Rename price helper
4c0d8b2 Add price helper
```

Git does not store renames; it detects them by content similarity. `--follow`
works for a single file only.

### The history of a function or line range: -L

```bash
git log -L :tax:tax.sh          # every change to function "tax" in tax.sh
git log -L 1,3:config.sh        # every change to lines 1-3
```

Each entry shows the commit and just the diff for that range. Often faster than
repeated blame.

### Search the current code (or any version)

```bash
git grep -n "LEGACY_FLAG"            # tracked files in the working tree
git grep -n "LEGACY_FLAG" v1.0       # files as they were at v1.0
```

`git grep` is fast and respects `.gitignore` (skips `node_modules`, builds).

## Try it

An API key string `sk_live_` was committed and later deleted. You need every
commit that ever added or removed it, with the diffs.

<details>
<summary>Show answer</summary>

```bash
git log -S 'sk_live_' -p --all
```

`--all` includes every branch. Then rotate the key (Section 13): deleting it
from the latest commit never removed it from history.

</details>

## Common mistakes

- **Using `-S` for value changes.** Use `-G` when the line changes but the
  text count does not.
- **Forgetting `--all`.** The commit may be on another branch.
- **`--follow` with several paths or a directory.** It only works on one file.

## Remember

- `-S text` = added or removed; `-G regex` = any changed line matching.
- `--follow -- file` walks history past renames.
- `git log -L` tracks a function or line range over time.
- `git grep` searches files now or at any revision.

**Self-check:**

1. Why can `-S` miss an edit?
2. What is the limitation of `--follow`?
3. How do you see every change to one function?
$md$, 8, $json$[{"id":"git-inv-search-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('575d0948-fdbb-511c-a687-a5c46700fb79', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '462878a1-6134-50d3-953c-444b70b83668', 'bisect: Binary Search for the Commit That Broke It', 'notes', 3, $md$## Why this matters

"It worked at v1.0, it is broken now, and there are 400 commits in between."
Reading them all would take days. `git bisect` finds the first bad commit in
about 9 tests, and if you have a script that detects the bug, Git runs it for
you.

## Mental model: guess the number

"I am thinking of a number between 1 and 1000." Ask "higher or lower?" and you
need about 10 guesses. Bisect plays that game with commits: test the middle
commit, throw away the half that cannot contain the culprit, repeat.

```
 v1.0 (good)                                              HEAD (bad)
  c5   c6   c7   c8   c9   c10  c11  c12  c13
  good  ?    ?    ?    ?    ?    ?    ?   bad
              test c9 -> bad    [c5 .. c9]
              test c7 -> bad    [c5 .. c7]
              test c6 -> good   first bad = c7  "Speed up tax calc"
```

Tests needed ~ log2(number of commits): 1000 commits -> about 10.

## See it work

### Manual bisect

```bash
git bisect start
git bisect bad              # current commit is broken
git bisect good v1.0        # this one worked
# Git checks out a middle commit. Test it, then say:
git bisect good             # or: git bisect bad
# ...repeat until Git prints "<hash> is the first bad commit"
git bisect reset            # go back to where you started
```

Use `git bisect skip` when a commit cannot be tested (it does not build). Use
`git bisect log` to see your answers so far.

### Automatic bisect with a script

```bash
git bisect start HEAD v1.0
git bisect run sh check.sh
```

What this does: Git checks out each middle commit and runs `sh check.sh`.
The **exit code** is the answer:

| Exit code | Meaning |
|---|---|
| `0` | good |
| `1`-`127` except `125` | bad |
| `125` | skip (cannot test this commit) |
| `128`+ | stop bisecting (something is badly wrong) |

Expected output (trimmed):

```
running 'sh' 'check.sh'
FAIL
7a3f9c1e... is the first bad commit
commit 7a3f9c1e...
Author: Dave Hotfix <dave@example.com>
    Speed up tax calc
bisect found first bad commit
```

Save the answer, then always reset:

```bash
git rev-parse refs/bisect/bad > ~/work/culprit.txt
git bisect reset
git show -s --format='%an <%ae>' "$(cat ~/work/culprit.txt)"
```

```knowledge-check
{ "questions": [
  { "id": "git-inv-bisect-q1", "type": "mcq",
    "prompt": "About how many test runs does git bisect need for 1000 commits?",
    "options": [
      {"id":"a","text":"About 10 (binary search)"},
      {"id":"b","text":"About 500"},
      {"id":"c","text":"1000"},
      {"id":"d","text":"It depends on the file sizes"}],
    "correct": "a",
    "explanation": "Each test halves the remaining range: log2(1000) is roughly 10. 500 or 1000 would be a linear search, and file sizes do not matter." },
  { "id": "git-inv-bisect-q2", "type": "mcq",
    "prompt": "What does a script given to git bisect run return for a good commit?",
    "options": [
      {"id":"a","text":"Exit status 0"},
      {"id":"b","text":"Exit status 1"},
      {"id":"c","text":"Any output"},
      {"id":"d","text":"The word good"}],
    "correct": "a",
    "explanation": "0 means good, 1 to 127 (except 125 = skip) means bad. Output text is ignored; only the exit status counts." }
] }
```

### Tips for good bisects

- Write the test **outside** the repo (or untracked) so it exists in every
  checked-out commit.
- Bisect a history of small commits: a giant "big refactor" commit is a huge
  haystack even after bisect finds it. Another reason to squash *thoughtfully*.
- With merge-heavy history, `git bisect start --first-parent` (Git 2.29+) tests
  only the main line, i.e. one step per merged pull request.
- Words other than good/bad: `git bisect start --term-old=fast --term-new=slow`
  for "when did it get slow?".

## Try it

Your test needs a build step, and some old commits do not compile at all. How
should your bisect script handle those commits?

<details>
<summary>Show answer</summary>

Exit with **125** when the build fails, so Git skips that commit instead of
calling it bad:

```bash
#!/bin/sh
make >/dev/null 2>&1 || exit 125
./run-test
```

</details>

## Common mistakes

- **Forgetting `git bisect reset`.** You stay on a detached HEAD in the middle of
  history and wonder where your branch went.
- **Answering by gut feeling.** One wrong good/bad sends the search to the wrong
  half. Use a script when you can.
- **A test that is itself in history.** If the test file did not exist in old
  commits, every old commit looks "bad". Keep the script outside the tree.

## Remember

- Bisect = binary search: about log2(N) tests.
- `start`, mark one `bad` and one `good`, answer, then `reset`.
- `git bisect run <cmd>`: exit 0 good, 1-127 bad, 125 skip.
- Small commits make the culprit easy to understand.

**Self-check:**

1. Which exit code tells bisect to skip a commit?
2. Why keep the test script outside the repository?
3. What command must you always run at the end?
$md$, 8, $json$[{"id":"git-inv-bisect-q1","type":"mcq","correct":"a"},{"id":"git-inv-bisect-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e9c35a89-dd93-5e9a-bcb3-722e6879a5f3', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '462878a1-6134-50d3-953c-444b70b83668', 'Lab: Detective Work in a Real History', 'notes', 4, $md$## Why this matters

`~/work/inventory` has two weeks of history from seven people: a reformat, a
moved function, a deleted flag, a changed value, a renamed file and a bug that
broke `check.sh`. Answer each question with the right tool and write the
answers into `~/work/answers.txt`, one `key=value` per line.

```bash
cd ~/work/inventory
git log --oneline
```

## Task 1: who set the tax rate?

Use `git blame -L` on line 1 of `tax.sh`. Write `rate_author=<name>`.

[[lab-task:1]]

Expected blame line:

```
7a3f9c1 (Dave Hotfix 2024-06-07 10:00:00 +0000 1) rate=15
```

```bash
echo "rate_author=Dave Hotfix" >> ~/work/answers.txt
```

## Task 2: see through the reformat

Plain blame on line 2 of `discount.sh` names the person who re-indented it. Use
`-w` and write `discount_author=<name>`.

[[lab-task:2]]

## Task 3: follow the moved code

Line 4 of `util.sh` was moved from `shipping.sh`. Use `git blame -C` on the
whole file and write `shipping_author=<name>`.

[[lab-task:3]]

## Task 4: when did the flag disappear?

Use `git log -S LEGACY_FLAG` and write `legacy_removed_in=<subject>` for the
commit that removed it.

[[lab-task:4]]

Expected:

```
9e1b3d0 Tidy up
c3a77f4 Misc changes
```

## Task 5: when did the value change?

Use `git log -G 'timeout='` and write `timeout_changed_in=<subject>` for the
commit that changed the value (not the one that created the file).

[[lab-task:5]]

## Task 6: before the rename

`pricing.sh` used to be `price.sh`. Use `git log --follow` and write
`pricing_origin=<subject of the creating commit>`.

[[lab-task:6]]

## Task 7: find the breaking commit

`check.sh` passes at tag `v1.0` but fails on `main`. Run an automatic bisect,
save the culprit's full hash in `~/work/culprit.txt`, then reset.

```bash
git bisect start HEAD v1.0
git bisect run sh check.sh
git rev-parse refs/bisect/bad > ~/work/culprit.txt
git bisect reset
```

[[lab-task:7]]

Expected: `... is the first bad commit` and the subject `Speed up tax calc`.

## Task 8: inspect the culprit

Use `git show` to read the culprit and write `culprit_email=<author email>`.

[[lab-task:8]]

## Remember

| Question | Tool |
|---|---|
| Who last changed this line? | `git blame -L` (+ `-w`, `-C`) |
| When was this text added/removed? | `git log -S` |
| When did this line change? | `git log -G` |
| History before a rename? | `git log --follow` |
| Which commit broke it? | `git bisect run` |
$md$, 40, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('fa0d802e-7fab-5376-a664-5c4af7a73dd5', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'e9c35a89-dd93-5e9a-bcb3-722e6879a5f3', 'module', 'Lab: Detective Work in a Real History', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
rm -rf /home/labuser/work/inventory /home/labuser/work/answers.txt /home/labuser/work/culprit.txt
mkdir /home/labuser/work/inventory && cd /home/labuser/work/inventory
git init -q
A() { git add -A; GIT_AUTHOR_NAME="$3" GIT_AUTHOR_EMAIL="$4" GIT_COMMITTER_NAME="$3" GIT_COMMITTER_EMAIL="$4" GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
printf 'rate=10\ntax() { echo $(( $1 * rate / 100 )); }\n' > tax.sh
A 2024-06-01 "Add tax calculator" "Alice Dev" alice@example.com
echo "# Inventory" > README.md
A 2024-06-02 "Add README" "Bob Docs" bob@example.com
printf '# shared helpers\nlog() { echo "$1"; }\n' > util.sh
A 2024-06-02 "Add util helpers" "Bob Docs" bob@example.com
printf 'price() { echo $(( $1 + $1 * 5 / 100 )); }\n' > price.sh
A 2024-06-03 "Add price helper" "Alice Dev" alice@example.com
printf 'discount() {\n  echo $(( $1 * 10 / 100 ))\n}\n' > discount.sh
A 2024-06-04 "Add discount helper" "Carol Pricing" carol@example.com
printf '. ./tax.sh\n[ "$(tax 200)" = 20 ] || { echo FAIL; exit 1; }\necho OK\n' > check.sh
A 2024-06-05 "Add check script" "Alice Dev" alice@example.com
git tag v1.0
printf 'shipping() {\n  if [ "$1" -gt 100 ]; then echo 0; else echo 7; fi\n  # free shipping above one hundred, flat rate seven otherwise\n  # the rate is charged per order and not per item in the cart\n  # international orders are handled by a separate carrier module\n  # remember to update the customer facing shipping policy page\n}\n' > shipping.sh
A 2024-06-06 "Add shipping helper" "Gina Shipping" gina@example.com
printf 'rate=15\ntax() { echo $(( $1 * rate / 100 )); }\n' > tax.sh
A 2024-06-07 "Speed up tax calc" "Dave Hotfix" dave@example.com
printf 'timeout=30\nLEGACY_FLAG=1\n' > config.sh
A 2024-06-08 "Misc changes" "Bob Docs" bob@example.com
printf 'discount() {\n\techo $(( $1 * 10 / 100 ))\n}\n' > discount.sh
A 2024-06-09 "Reindent scripts" "Eve Formatter" eve@example.com
printf '. ./util.sh\n' > shipping.sh
printf 'shipping() {\n  if [ "$1" -gt 100 ]; then echo 0; else echo 7; fi\n  # free shipping above one hundred, flat rate seven otherwise\n  # the rate is charged per order and not per item in the cart\n  # international orders are handled by a separate carrier module\n  # remember to update the customer facing shipping policy page\n}\n' >> util.sh
A 2024-06-10 "Move shipping helper to util.sh" "Frank Mover" frank@example.com
printf 'timeout=45\nLEGACY_FLAG=1\n' > config.sh
A 2024-06-11 "Bump timeout" "Alice Dev" alice@example.com
printf 'timeout=45\n' > config.sh
A 2024-06-12 "Tidy up" "Bob Docs" bob@example.com
git mv price.sh pricing.sh
A 2024-06-13 "Rename price helper" "Heidi Renamer" heidi@example.com
chmod -R a+rwX /home/labuser/work/inventory
$script$, NULL, 50, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '94eabe80-9819-53bb-8ac8-0f6b2f3604d8' AND id NOT IN ('c51341fd-7b0b-5a7e-8901-46e688a15006', '569b8806-0d72-591c-883d-2b1b28000a07', 'ffb5601c-1ecf-5d5e-81f8-c5f89a7e8976', 'ecc3c034-9c33-53d2-8c5d-3dec081ddd53', 'ecfa8e3c-d334-5c76-a864-33c6eb8fdec8', 'f7c98625-7647-5d34-bdae-4636945c5d4e', 'e957c2bc-0fd9-579e-b7cd-fd18ce26acb2', 'fcb6e15b-f215-52fc-a3d0-811fd7e72567');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '94eabe80-9819-53bb-8ac8-0f6b2f3604d8';
DELETE FROM lab_tasks WHERE lab_id = 'fa0d802e-7fab-5376-a664-5c4af7a73dd5' AND id NOT IN ('50744668-f562-5d2e-84c2-6950fe4c3d57', '7114905f-f7a2-54f9-b136-7254e6d72c4a', '494bde68-76ad-51a8-92e0-f11b9b8c619d', '6a60ca40-6af9-5244-b971-d6b7e8ee1806', 'c2138659-6cde-57e2-b2fd-e0ccab5b1f29', '70715bf3-e351-5af1-afed-3218625a2d72', '5838f9d4-8b69-525a-b953-c9d186603419', '18d26c1c-6f6c-54f7-8dd2-d3a42823964f');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'fa0d802e-7fab-5376-a664-5c4af7a73dd5';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('50744668-f562-5d2e-84c2-6950fe4c3d57', 'fa0d802e-7fab-5376-a664-5c4af7a73dd5', 1, 'Find who wrote a line with blame -L', $md$In ~/work/inventory the tax rate line (line 1 of tax.sh) looks wrong. Use git blame -L to find its author and write the line rate_author=<name> into ~/work/answers.txt (for example rate_author=Jane Doe).$md$, $script$grep -qx 'rate_author=Dave Hotfix' /home/labuser/work/answers.txt
$script$, 'git blame -L 1,1 tax.sh prints the commit and author that last touched line 1. Add --porcelain for machine-readable output.', 'blame annotates each line with the commit that last changed it. -L limits the range so you only look at the line you care about.', 10, false, false),
('7114905f-f7a2-54f9-b136-7254e6d72c4a', 'fa0d802e-7fab-5376-a664-5c4af7a73dd5', 2, 'See through a reformat with blame -w', $md$Line 2 of discount.sh holds the real discount calculation, but a later reformat commit re-indented it. Plain blame names the reformatter; use git blame -w to ignore whitespace and find the real author. Write discount_author=<name> to ~/work/answers.txt.$md$, $script$grep -qx 'discount_author=Carol Pricing' /home/labuser/work/answers.txt
$script$, 'Compare git blame -L2,2 discount.sh with git blame -w -L2,2 discount.sh.', '-w ignores whitespace-only changes when assigning blame, so a re-indent commit no longer hides the commit that wrote the logic.', 15, false, false),
('494bde68-76ad-51a8-92e0-f11b9b8c619d', 'fa0d802e-7fab-5376-a664-5c4af7a73dd5', 3, 'Follow moved code with blame -C', $md$Line 4 of util.sh (the if statement of shipping) was moved there from shipping.sh by someone else. Plain blame points at the mover; use git blame -C to trace the line to the commit that really wrote it. Write shipping_author=<name> to ~/work/answers.txt.$md$, $script$grep -qx 'shipping_author=Gina Shipping' /home/labuser/work/answers.txt
$script$, 'Run git blame -C util.sh on the whole file (copy detection does not work well with -L) and read the author on the if line, which is line 4.', '-C looks for lines that came from another file in the same commit, -C -C also searches the commit that created the file, and -C -C -C searches all history. They make blame follow refactors.', 15, false, false),
('6a60ca40-6af9-5244-b971-d6b7e8ee1806', 'fa0d802e-7fab-5376-a664-5c4af7a73dd5', 4, 'Find when a string disappeared with log -S', $md$The constant LEGACY_FLAG used to exist in config.sh. Use git log -S to list the commits that added or removed it, work out which one removed it, and write legacy_removed_in=<that commit's subject> to ~/work/answers.txt.$md$, $script$grep -qx 'legacy_removed_in=Tidy up' /home/labuser/work/answers.txt
$script$, 'git log -S LEGACY_FLAG --oneline shows both the adding and the removing commit. Add -p to see which direction each went.', '-S (the pickaxe) lists commits where the number of occurrences of a string changed - i.e. where it was added or removed.', 15, false, false),
('c2138659-6cde-57e2-b2fd-e0ccab5b1f29', 'fa0d802e-7fab-5376-a664-5c4af7a73dd5', 5, 'Find a changed value with log -G', $md$The timeout value in config.sh was changed from 30 to 45 at some point. Plain -S timeout= will not find that, because the number of occurrences did not change. Use git log -G with a regex to find the commit that CHANGED the value (not the one that created the file) and write timeout_changed_in=<subject> to ~/work/answers.txt.$md$, $script$grep -qx 'timeout_changed_in=Bump timeout' /home/labuser/work/answers.txt
$script$, 'git log -G ''timeout='' --oneline lists every commit whose diff touches a matching line. The oldest one created the file.', '-G matches the regex against added or removed diff lines, so it catches edits to a line that -S (count-based) misses.', 15, false, false),
('70715bf3-e351-5af1-afed-3218625a2d72', 'fa0d802e-7fab-5376-a664-5c4af7a73dd5', 6, 'Follow a file across a rename', $md$pricing.sh used to be called price.sh. Use git log --follow to walk its history past the rename and write pricing_origin=<subject of the commit that first created the file> to ~/work/answers.txt.$md$, $script$grep -qx 'pricing_origin=Add price helper' /home/labuser/work/answers.txt
$script$, 'git log --follow --oneline -- pricing.sh keeps listing commits under the old name. The last line is the creation.', 'Git does not store renames; it detects them by similarity. --follow (single file only) applies that detection while walking history.', 15, false, false),
('5838f9d4-8b69-525a-b953-c9d186603419', 'fa0d802e-7fab-5376-a664-5c4af7a73dd5', 7, 'Find the breaking commit with bisect run', $md$check.sh passes at the tag v1.0 but fails on main. Use git bisect start / git bisect run sh check.sh to let Git find the first bad commit, save its full hash in ~/work/culprit.txt, then end the bisect with git bisect reset so you are back on main.$md$, $script$r=/home/labuser/work/inventory
[ "$(git -C $r log -1 --format=%s "$(cat /home/labuser/work/culprit.txt)")" = "Speed up tax calc" ] &&
[ ! -f $r/.git/BISECT_LOG ] &&
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ]
$script$, 'git bisect start HEAD v1.0 ; git bisect run sh check.sh. When it prints "<hash> is the first bad commit", record it, then git bisect reset.', 'bisect does a binary search over history, checking out the midpoint and asking your command (exit 0 = good, 1-124 = bad) until one commit remains - log2(N) steps for N commits.', 25, false, false),
('18d26c1c-6f6c-54f7-8dd2-d3a42823964f', 'fa0d802e-7fab-5376-a664-5c4af7a73dd5', 8, 'Inspect the culprit with git show', $md$Use git show on the culprit commit to read its details and write culprit_email=<author email> to ~/work/answers.txt.$md$, $script$grep -qx 'culprit_email=dave@example.com' /home/labuser/work/answers.txt
$script$, 'git show -s --format=''%an <%ae>'' <hash> prints only the author line; git show <hash> shows the whole diff.', 'git show prints one commit''s metadata and patch (and also works for blobs, git show <rev>:<path>, and tags).', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('94eabe80-9819-53bb-8ac8-0f6b2f3604d8', 'fa0d802e-7fab-5376-a664-5c4af7a73dd5', 1, $json$[{"id":"50744668-f562-5d2e-84c2-6950fe4c3d57","lab_id":"fa0d802e-7fab-5376-a664-5c4af7a73dd5","position":1,"title":"Find who wrote a line with blame -L","description":"In ~/work/inventory the tax rate line (line 1 of tax.sh) looks wrong. Use git blame -L to find its author and write the line rate_author=\u003cname\u003e into ~/work/answers.txt (for example rate_author=Jane Doe).","verification_script":"grep -qx 'rate_author=Dave Hotfix' /home/labuser/work/answers.txt\n","hint_context":"git blame -L 1,1 tax.sh prints the commit and author that last touched line 1. Add --porcelain for machine-readable output.","explanation_context":"blame annotates each line with the commit that last changed it. -L limits the range so you only look at the line you care about.","points":10,"is_optional":false,"is_stateful":false},{"id":"7114905f-f7a2-54f9-b136-7254e6d72c4a","lab_id":"fa0d802e-7fab-5376-a664-5c4af7a73dd5","position":2,"title":"See through a reformat with blame -w","description":"Line 2 of discount.sh holds the real discount calculation, but a later reformat commit re-indented it. Plain blame names the reformatter; use git blame -w to ignore whitespace and find the real author. Write discount_author=\u003cname\u003e to ~/work/answers.txt.","verification_script":"grep -qx 'discount_author=Carol Pricing' /home/labuser/work/answers.txt\n","hint_context":"Compare git blame -L2,2 discount.sh with git blame -w -L2,2 discount.sh.","explanation_context":"-w ignores whitespace-only changes when assigning blame, so a re-indent commit no longer hides the commit that wrote the logic.","points":15,"is_optional":false,"is_stateful":false},{"id":"494bde68-76ad-51a8-92e0-f11b9b8c619d","lab_id":"fa0d802e-7fab-5376-a664-5c4af7a73dd5","position":3,"title":"Follow moved code with blame -C","description":"Line 4 of util.sh (the if statement of shipping) was moved there from shipping.sh by someone else. Plain blame points at the mover; use git blame -C to trace the line to the commit that really wrote it. Write shipping_author=\u003cname\u003e to ~/work/answers.txt.","verification_script":"grep -qx 'shipping_author=Gina Shipping' /home/labuser/work/answers.txt\n","hint_context":"Run git blame -C util.sh on the whole file (copy detection does not work well with -L) and read the author on the if line, which is line 4.","explanation_context":"-C looks for lines that came from another file in the same commit, -C -C also searches the commit that created the file, and -C -C -C searches all history. They make blame follow refactors.","points":15,"is_optional":false,"is_stateful":false},{"id":"6a60ca40-6af9-5244-b971-d6b7e8ee1806","lab_id":"fa0d802e-7fab-5376-a664-5c4af7a73dd5","position":4,"title":"Find when a string disappeared with log -S","description":"The constant LEGACY_FLAG used to exist in config.sh. Use git log -S to list the commits that added or removed it, work out which one removed it, and write legacy_removed_in=\u003cthat commit's subject\u003e to ~/work/answers.txt.","verification_script":"grep -qx 'legacy_removed_in=Tidy up' /home/labuser/work/answers.txt\n","hint_context":"git log -S LEGACY_FLAG --oneline shows both the adding and the removing commit. Add -p to see which direction each went.","explanation_context":"-S (the pickaxe) lists commits where the number of occurrences of a string changed - i.e. where it was added or removed.","points":15,"is_optional":false,"is_stateful":false},{"id":"c2138659-6cde-57e2-b2fd-e0ccab5b1f29","lab_id":"fa0d802e-7fab-5376-a664-5c4af7a73dd5","position":5,"title":"Find a changed value with log -G","description":"The timeout value in config.sh was changed from 30 to 45 at some point. Plain -S timeout= will not find that, because the number of occurrences did not change. Use git log -G with a regex to find the commit that CHANGED the value (not the one that created the file) and write timeout_changed_in=\u003csubject\u003e to ~/work/answers.txt.","verification_script":"grep -qx 'timeout_changed_in=Bump timeout' /home/labuser/work/answers.txt\n","hint_context":"git log -G 'timeout=' --oneline lists every commit whose diff touches a matching line. The oldest one created the file.","explanation_context":"-G matches the regex against added or removed diff lines, so it catches edits to a line that -S (count-based) misses.","points":15,"is_optional":false,"is_stateful":false},{"id":"70715bf3-e351-5af1-afed-3218625a2d72","lab_id":"fa0d802e-7fab-5376-a664-5c4af7a73dd5","position":6,"title":"Follow a file across a rename","description":"pricing.sh used to be called price.sh. Use git log --follow to walk its history past the rename and write pricing_origin=\u003csubject of the commit that first created the file\u003e to ~/work/answers.txt.","verification_script":"grep -qx 'pricing_origin=Add price helper' /home/labuser/work/answers.txt\n","hint_context":"git log --follow --oneline -- pricing.sh keeps listing commits under the old name. The last line is the creation.","explanation_context":"Git does not store renames; it detects them by similarity. --follow (single file only) applies that detection while walking history.","points":15,"is_optional":false,"is_stateful":false},{"id":"5838f9d4-8b69-525a-b953-c9d186603419","lab_id":"fa0d802e-7fab-5376-a664-5c4af7a73dd5","position":7,"title":"Find the breaking commit with bisect run","description":"check.sh passes at the tag v1.0 but fails on main. Use git bisect start / git bisect run sh check.sh to let Git find the first bad commit, save its full hash in ~/work/culprit.txt, then end the bisect with git bisect reset so you are back on main.","verification_script":"r=/home/labuser/work/inventory\n[ \"$(git -C $r log -1 --format=%s \"$(cat /home/labuser/work/culprit.txt)\")\" = \"Speed up tax calc\" ] \u0026\u0026\n[ ! -f $r/.git/BISECT_LOG ] \u0026\u0026\n[ \"$(git -C $r rev-parse --abbrev-ref HEAD)\" = main ]\n","hint_context":"git bisect start HEAD v1.0 ; git bisect run sh check.sh. When it prints \"\u003chash\u003e is the first bad commit\", record it, then git bisect reset.","explanation_context":"bisect does a binary search over history, checking out the midpoint and asking your command (exit 0 = good, 1-124 = bad) until one commit remains - log2(N) steps for N commits.","points":25,"is_optional":false,"is_stateful":false},{"id":"18d26c1c-6f6c-54f7-8dd2-d3a42823964f","lab_id":"fa0d802e-7fab-5376-a664-5c4af7a73dd5","position":8,"title":"Inspect the culprit with git show","description":"Use git show on the culprit commit to read its details and write culprit_email=\u003cauthor email\u003e to ~/work/answers.txt.","verification_script":"grep -qx 'culprit_email=dave@example.com' /home/labuser/work/answers.txt\n","hint_context":"git show -s --format='%an \u003c%ae\u003e' \u003chash\u003e prints only the author line; git show \u003chash\u003e shows the whole diff.","explanation_context":"git show prints one commit's metadata and patch (and also works for blobs, git show \u003crev\u003e:\u003cpath\u003e, and tags).","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('c51341fd-7b0b-5a7e-8901-46e688a15006', '94eabe80-9819-53bb-8ac8-0f6b2f3604d8', '50744668-f562-5d2e-84c2-6950fe4c3d57', 1, 'Find who wrote a line with blame -L', $md$In ~/work/inventory the tax rate line (line 1 of tax.sh) looks wrong. Use git blame -L to find its author and write the line rate_author=<name> into ~/work/answers.txt (for example rate_author=Jane Doe).$md$, $script$grep -qx 'rate_author=Dave Hotfix' /home/labuser/work/answers.txt
$script$, 'git blame -L 1,1 tax.sh prints the commit and author that last touched line 1. Add --porcelain for machine-readable output.', 'blame annotates each line with the commit that last changed it. -L limits the range so you only look at the line you care about.', 10, false, false),
('569b8806-0d72-591c-883d-2b1b28000a07', '94eabe80-9819-53bb-8ac8-0f6b2f3604d8', '7114905f-f7a2-54f9-b136-7254e6d72c4a', 2, 'See through a reformat with blame -w', $md$Line 2 of discount.sh holds the real discount calculation, but a later reformat commit re-indented it. Plain blame names the reformatter; use git blame -w to ignore whitespace and find the real author. Write discount_author=<name> to ~/work/answers.txt.$md$, $script$grep -qx 'discount_author=Carol Pricing' /home/labuser/work/answers.txt
$script$, 'Compare git blame -L2,2 discount.sh with git blame -w -L2,2 discount.sh.', '-w ignores whitespace-only changes when assigning blame, so a re-indent commit no longer hides the commit that wrote the logic.', 15, false, false),
('ffb5601c-1ecf-5d5e-81f8-c5f89a7e8976', '94eabe80-9819-53bb-8ac8-0f6b2f3604d8', '494bde68-76ad-51a8-92e0-f11b9b8c619d', 3, 'Follow moved code with blame -C', $md$Line 4 of util.sh (the if statement of shipping) was moved there from shipping.sh by someone else. Plain blame points at the mover; use git blame -C to trace the line to the commit that really wrote it. Write shipping_author=<name> to ~/work/answers.txt.$md$, $script$grep -qx 'shipping_author=Gina Shipping' /home/labuser/work/answers.txt
$script$, 'Run git blame -C util.sh on the whole file (copy detection does not work well with -L) and read the author on the if line, which is line 4.', '-C looks for lines that came from another file in the same commit, -C -C also searches the commit that created the file, and -C -C -C searches all history. They make blame follow refactors.', 15, false, false),
('ecc3c034-9c33-53d2-8c5d-3dec081ddd53', '94eabe80-9819-53bb-8ac8-0f6b2f3604d8', '6a60ca40-6af9-5244-b971-d6b7e8ee1806', 4, 'Find when a string disappeared with log -S', $md$The constant LEGACY_FLAG used to exist in config.sh. Use git log -S to list the commits that added or removed it, work out which one removed it, and write legacy_removed_in=<that commit's subject> to ~/work/answers.txt.$md$, $script$grep -qx 'legacy_removed_in=Tidy up' /home/labuser/work/answers.txt
$script$, 'git log -S LEGACY_FLAG --oneline shows both the adding and the removing commit. Add -p to see which direction each went.', '-S (the pickaxe) lists commits where the number of occurrences of a string changed - i.e. where it was added or removed.', 15, false, false),
('ecfa8e3c-d334-5c76-a864-33c6eb8fdec8', '94eabe80-9819-53bb-8ac8-0f6b2f3604d8', 'c2138659-6cde-57e2-b2fd-e0ccab5b1f29', 5, 'Find a changed value with log -G', $md$The timeout value in config.sh was changed from 30 to 45 at some point. Plain -S timeout= will not find that, because the number of occurrences did not change. Use git log -G with a regex to find the commit that CHANGED the value (not the one that created the file) and write timeout_changed_in=<subject> to ~/work/answers.txt.$md$, $script$grep -qx 'timeout_changed_in=Bump timeout' /home/labuser/work/answers.txt
$script$, 'git log -G ''timeout='' --oneline lists every commit whose diff touches a matching line. The oldest one created the file.', '-G matches the regex against added or removed diff lines, so it catches edits to a line that -S (count-based) misses.', 15, false, false),
('f7c98625-7647-5d34-bdae-4636945c5d4e', '94eabe80-9819-53bb-8ac8-0f6b2f3604d8', '70715bf3-e351-5af1-afed-3218625a2d72', 6, 'Follow a file across a rename', $md$pricing.sh used to be called price.sh. Use git log --follow to walk its history past the rename and write pricing_origin=<subject of the commit that first created the file> to ~/work/answers.txt.$md$, $script$grep -qx 'pricing_origin=Add price helper' /home/labuser/work/answers.txt
$script$, 'git log --follow --oneline -- pricing.sh keeps listing commits under the old name. The last line is the creation.', 'Git does not store renames; it detects them by similarity. --follow (single file only) applies that detection while walking history.', 15, false, false),
('e957c2bc-0fd9-579e-b7cd-fd18ce26acb2', '94eabe80-9819-53bb-8ac8-0f6b2f3604d8', '5838f9d4-8b69-525a-b953-c9d186603419', 7, 'Find the breaking commit with bisect run', $md$check.sh passes at the tag v1.0 but fails on main. Use git bisect start / git bisect run sh check.sh to let Git find the first bad commit, save its full hash in ~/work/culprit.txt, then end the bisect with git bisect reset so you are back on main.$md$, $script$r=/home/labuser/work/inventory
[ "$(git -C $r log -1 --format=%s "$(cat /home/labuser/work/culprit.txt)")" = "Speed up tax calc" ] &&
[ ! -f $r/.git/BISECT_LOG ] &&
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ]
$script$, 'git bisect start HEAD v1.0 ; git bisect run sh check.sh. When it prints "<hash> is the first bad commit", record it, then git bisect reset.', 'bisect does a binary search over history, checking out the midpoint and asking your command (exit 0 = good, 1-124 = bad) until one commit remains - log2(N) steps for N commits.', 25, false, false),
('fcb6e15b-f215-52fc-a3d0-811fd7e72567', '94eabe80-9819-53bb-8ac8-0f6b2f3604d8', '18d26c1c-6f6c-54f7-8dd2-d3a42823964f', 8, 'Inspect the culprit with git show', $md$Use git show on the culprit commit to read its details and write culprit_email=<author email> to ~/work/answers.txt.$md$, $script$grep -qx 'culprit_email=dave@example.com' /home/labuser/work/answers.txt
$script$, 'git show -s --format=''%an <%ae>'' <hash> prints only the author line; git show <hash> shows the whole diff.', 'git show prints one commit''s metadata and patch (and also works for blobs, git show <rev>:<path>, and tags).', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '94eabe80-9819-53bb-8ac8-0f6b2f3604d8', updated_at = now()
WHERE id = 'fa0d802e-7fab-5376-a664-5c4af7a73dd5' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e238deeb-14ca-5d09-92e3-7c0e2675eefe', '00000000-0000-0000-0000-000000000001', 'mcq', 'A function `legacyAuth()` no longer exists anywhere in the code. You need to ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('163c9546-25c8-5066-8a83-e038f99aa31c', 'e238deeb-14ca-5d09-92e3-7c0e2675eefe', 1, $json${"prompt":"A function `legacyAuth()` no longer exists anywhere in the code. You need to know when it was deleted. What do you run?","multiple":false,"options":[{"id":"a","text":"git blame on the file","is_correct":false},{"id":"b","text":"git log -S 'legacyAuth(' --oneline","is_correct":true},{"id":"c","text":"git grep legacyAuth","is_correct":false},{"id":"d","text":"git bisect start","is_correct":false}],"explanation":"-S lists commits where the count of the string changed; the newest one removed it. blame and git grep only see code that still exists, and bisect needs a good/bad test."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6a26f85f-04a8-54fd-91b5-db6d1c849307', '00000000-0000-0000-0000-000000000001', 'mcq', 'A company-wide formatter commit touched every file last month. Blame now name...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('72d0dd44-b4c5-5250-afa7-605bdff3a6bc', '6a26f85f-04a8-54fd-91b5-db6d1c849307', 1, $json${"prompt":"A company-wide formatter commit touched every file last month. Blame now names it for nearly every line. What is the team-wide fix?","multiple":false,"options":[{"id":"a","text":"Revert the formatter commit","is_correct":false},{"id":"b","text":"Add its hash to .git-blame-ignore-revs and set blame.ignoreRevsFile","is_correct":true},{"id":"c","text":"Use git log --follow","is_correct":false},{"id":"d","text":"Use git blame -C on every file","is_correct":false}],"explanation":"The ignore-revs file makes blame (and GitHub/GitLab blame views) skip that commit. Reverting undoes the formatting, --follow is for renames, and -C is for moved code, not formatting."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('59a73a52-abd7-5688-8ef6-a0306cd1641b', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your bisect script must build the project first, and some old commits fail to...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7cdbcc6c-87f5-54fa-ae12-e81c2390f3c8', '59a73a52-abd7-5688-8ef6-a0306cd1641b', 1, $json${"prompt":"Your bisect script must build the project first, and some old commits fail to build. What should the script return for those?","multiple":false,"options":[{"id":"a","text":"0","is_correct":false},{"id":"b","text":"1","is_correct":false},{"id":"c","text":"125","is_correct":true},{"id":"d","text":"255","is_correct":false}],"explanation":"125 tells bisect to skip an untestable commit. 0 would mark it good and 1 bad, both wrong guesses; 128 and above abort the whole bisect."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('9317206f-aef2-5358-ad6d-ef8475438fe7', '00000000-0000-0000-0000-000000000001', 'mcq', 'Between a known-good tag and HEAD there are about 2000 commits. Roughly how m...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b73e14f6-9569-5e77-b85f-7bfc9948dd5f', '9317206f-aef2-5358-ad6d-ef8475438fe7', 1, $json${"prompt":"Between a known-good tag and HEAD there are about 2000 commits. Roughly how many tests will bisect need?","multiple":false,"options":[{"id":"a","text":"About 11","is_correct":true},{"id":"b","text":"About 100","is_correct":false},{"id":"c","text":"About 1000","is_correct":false},{"id":"d","text":"2000","is_correct":false}],"explanation":"log2(2000) is about 11. Binary search halves the range every step; 1000 or 2000 would be a linear search."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('814b95fa-5ce1-5bf3-ad6a-c2be7b141085', '00000000-0000-0000-0000-000000000001', 'mcq', 'You want the commits on your branch feature/report that are not yet on main, ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('41dede5c-51b8-5738-9046-31fd0ab7506e', '814b95fa-5ce1-5bf3-ad6a-c2be7b141085', 1, $json${"prompt":"You want the commits on your branch feature/report that are not yet on main, newest first, one line each. Which command?","multiple":false,"options":[{"id":"a","text":"git log --oneline main..feature/report","is_correct":true},{"id":"b","text":"git log --oneline feature/report..main","is_correct":false},{"id":"c","text":"git log --oneline --all","is_correct":false},{"id":"d","text":"git diff main feature/report","is_correct":false}],"explanation":"A..B means 'reachable from B but not from A'. The reversed range lists main's commits that feature lacks, --all lists everything, and diff shows file changes rather than commits."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c5f67f3c-7f4d-5956-8009-be913b19a5a3', '00000000-0000-0000-0000-000000000001', 'mcq', 'A config value changed from retries=3 to retries=5. Which search finds that c...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d5581fd5-6272-525e-b3ef-9ab961134c22', 'c5f67f3c-7f4d-5956-8009-be913b19a5a3', 1, $json${"prompt":"A config value changed from retries=3 to retries=5. Which search finds that commit?","multiple":false,"options":[{"id":"a","text":"git log -S 'retries='","is_correct":false},{"id":"b","text":"git log -G 'retries='","is_correct":true},{"id":"c","text":"git log --follow","is_correct":false},{"id":"d","text":"git shortlog -sn","is_correct":false}],"explanation":"One retries= line was removed and one added, so the count is unchanged and -S misses it. -G matches any changed line. --follow handles renames and shortlog summarises authors."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('781f706d-09cf-5533-8aa6-fd8e51378be6', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 9): bisect found that commit X on shared main broke checkout....', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('45d0eae7-7054-5ea4-b12e-a9faf6b8b4cf', '781f706d-09cf-5533-8aa6-fd8e51378be6', 1, $json${"prompt":"Review (Section 9): bisect found that commit X on shared main broke checkout. Several good commits came after it. How do you fix main?","multiple":false,"options":[{"id":"a","text":"git revert X and push","is_correct":true},{"id":"b","text":"git reset --hard X~1 and force-push","is_correct":false},{"id":"c","text":"git rebase -i to drop X and force-push","is_correct":false},{"id":"d","text":"git cherry-pick X","is_correct":false}],"explanation":"Revert removes X's effect with a new commit, keeping shared history intact and the later good commits in place. Reset and rebase rewrite shared history (and reset also drops the good commits); cherry-pick would apply X again."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('859eb651-618b-5169-993c-71473a8dc778', '00000000-0000-0000-0000-000000000001', 'Quiz: Investigating History', 'git-investigation-quiz', 'Quiz covering Investigating History.', 'mcq', 'published', 'module', '22e0a992-56e3-559d-8189-3eebb0232e71', 12, 70, 5, 14, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '859eb651-618b-5169-993c-71473a8dc778' AND question_id NOT IN ('e238deeb-14ca-5d09-92e3-7c0e2675eefe', '6a26f85f-04a8-54fd-91b5-db6d1c849307', '59a73a52-abd7-5688-8ef6-a0306cd1641b', '9317206f-aef2-5358-ad6d-ef8475438fe7', '814b95fa-5ce1-5bf3-ad6a-c2be7b141085', 'c5f67f3c-7f4d-5956-8009-be913b19a5a3', '781f706d-09cf-5533-8aa6-fd8e51378be6');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('dc20bfd8-5cb3-5836-b853-2b36b4834980', '859eb651-618b-5169-993c-71473a8dc778', 'e238deeb-14ca-5d09-92e3-7c0e2675eefe', '163c9546-25c8-5066-8a83-e038f99aa31c', 0, 2),
('bb4bd3e6-a2a5-53cd-a6fe-63a4443ea10d', '859eb651-618b-5169-993c-71473a8dc778', '6a26f85f-04a8-54fd-91b5-db6d1c849307', '72d0dd44-b4c5-5250-afa7-605bdff3a6bc', 1, 2),
('a13b0a29-8be9-518e-9acc-54d2decce1c7', '859eb651-618b-5169-993c-71473a8dc778', '59a73a52-abd7-5688-8ef6-a0306cd1641b', '7cdbcc6c-87f5-54fa-ae12-e81c2390f3c8', 2, 2),
('76756f5a-392d-59af-875e-b706582010ea', '859eb651-618b-5169-993c-71473a8dc778', '9317206f-aef2-5358-ad6d-ef8475438fe7', 'b73e14f6-9569-5e77-b85f-7bfc9948dd5f', 3, 2),
('7acfd05f-dff0-5ff0-97aa-f1c22539ee0b', '859eb651-618b-5169-993c-71473a8dc778', '814b95fa-5ce1-5bf3-ad6a-c2be7b141085', '41dede5c-51b8-5738-9046-31fd0ab7506e', 4, 2),
('d829018b-e4a4-5223-921e-f8db8d4a3dff', '859eb651-618b-5169-993c-71473a8dc778', 'c5f67f3c-7f4d-5956-8009-be913b19a5a3', 'd5581fd5-6272-525e-b3ef-9ab961134c22', 5, 2),
('f56db921-6d9c-5a08-ae7c-8a3454963eb7', '859eb651-618b-5169-993c-71473a8dc778', '781f706d-09cf-5533-8aa6-fd8e51378be6', '45d0eae7-7054-5ea4-b12e-a9faf6b8b4cf', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('22e0a992-56e3-559d-8189-3eebb0232e71', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '462878a1-6134-50d3-953c-444b70b83668', 'Quiz: Investigating History', 'assessment', 5, 10, '859eb651-618b-5169-993c-71473a8dc778')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Team Workflows, Releases, Hooks and Signing
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('b512cc2b-eecf-5fd0-8acd-e11f22b48966', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Team Workflows, Releases, Hooks and Signing', 11, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5531cbf5-4631-5f85-9266-50bad4dd2776', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'b512cc2b-eecf-5fd0-8acd-e11f22b48966', 'Branching Strategies: GitHub Flow, Trunk-Based, Git Flow', 'notes', 0, $md$## Why this matters

Git gives you branches; it does not tell a team how to use them. Every team
picks a **branching strategy**: which long-lived branches exist, where features
start, how code reaches production. Interviewers ask about it, and joining a
team means learning theirs on day one.

## Mental model: roads into the city

- **Trunk-based**: one main road (`main`); everyone joins it often through very
  short side streets.
- **GitHub flow**: one main road; each feature is a side street (branch) that
  merges back through a checkpoint (pull request with review and CI).
- **Git flow**: several parallel roads (`main`, `develop`, `release/*`,
  `hotfix/*`) with rules about which road feeds which.

## The three strategies

### GitHub flow (most common default)

```
 main  ----*----------*-----------*-----   always deployable
            \        /             \
 feature     A---B--'   (PR: review + CI, then merge)
```

1. Branch from `main`: `git switch -c feature/login`.
2. Commit, push, open a **pull request** (PR; GitLab says merge request).
3. CI runs, teammates review, you push fixes.
4. Merge into `main` (merge, squash or rebase button), delete the branch.
5. Deploy `main`.

A pull request is not a Git feature: it is a branch on the server plus a
request to merge it, with review and CI built around it by the host.

### Trunk-based development

```
 main  --*--*--*--*--*--*--*--   many small merges per day
          \/ \/    \/
       (branches live hours, not weeks)
```

Branches live less than a day or two. Unfinished features hide behind **feature
flags** (config switches) so half-done code can be merged safely. Used by teams
that deploy many times per day; it minimises merge conflicts because nothing
drifts far from main.

### Git flow

```
 main     ----*---------------------*------   tagged releases only
               \                   /
 release/1.2    \           *----*            stabilise, then merge to main + develop
                 \         /
 develop    ------*---*---*---*----            integration branch
                       \ /
 feature/x              *
 hotfix/1.1.1  branch from main, merge to main + develop
```

Suits software shipped in versions with long support (desktop apps, libraries,
on-premise products). Its author noted in 2020 that for continuously deployed
web apps a simpler flow is usually better.

### Choosing

| If your team... | Prefer |
|---|---|
| Deploys a web service continuously | GitHub flow or trunk-based |
| Deploys many times a day, strong CI, feature flags | Trunk-based |
| Ships numbered versions and maintains old ones | Git flow or release branches |

### Rules that hold in every strategy

- `main` is protected: no force push, merges via reviewed PRs, CI must pass.
- Keep branches short-lived; rebase or merge `main` in often.
- Small PRs (a few hundred lines) get better reviews.
- Name branches by purpose: `feature/...`, `fix/...`, `chore/...`.
- Write release notes from good commit messages (Conventional Commits help
  tools generate them).

## Try it

A team deploys their website ten times a day but long feature branches keep
causing painful merges. What change would you suggest?

<details>
<summary>Show answer</summary>

Move toward trunk-based development: merge small changes into `main` at least
daily, hide unfinished features behind feature flags, and rely on CI to keep
`main` green. Short-lived branches cannot drift far, so conflicts stay small.

</details>

## Common mistakes

- **Adopting Git flow by default.** Its extra branches add ceremony a
  continuously deployed app does not need.
- **Long-lived feature branches.** The longer a branch lives, the bigger the
  final merge. Integrate often.
- **No branch protection.** One accidental force-push can rewrite `main` for
  everyone.

## Remember

- GitHub flow: branch -> PR (review + CI) -> merge -> deploy.
- Trunk-based: tiny branches, merge daily, feature flags.
- Git flow: `develop`, `release/*`, `hotfix/*`; for versioned products.
- Always: protected `main`, short branches, small PRs.

**Self-check:**

1. What is a pull request in Git terms?
2. What problem do feature flags solve in trunk-based development?
3. When does Git flow make sense?
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2df84d55-b6ad-5e0b-98f8-fd4de8dc2d6c', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'b512cc2b-eecf-5fd0-8acd-e11f22b48966', 'Tags, Semantic Versioning and Releases', 'notes', 1, $md$## Why this matters

"Which code is running in production?" "What changed since 2.3.0?" Tags answer
both. A tag gives a permanent name to the exact commit you released, so you can
rebuild it, compare against it, or branch a hotfix from it years later.

## Mental model: a branch that never moves

A branch label moves with every commit. A **tag** is a label glued to one
commit forever. Two kinds:

| | Lightweight | Annotated |
|---|---|---|
| Create | `git tag v1.2.0` | `git tag -a v1.2.0 -m "Release 1.2.0"` |
| Stored as | Just a ref | A tag **object** (tagger, date, message) + ref |
| Can be signed | No | Yes (`-s`) |
| Use for | Private bookmarks | **Releases** |

`git describe` and many tools ignore lightweight tags by default, another
reason to use annotated tags for releases.

## See it work

### Tag a release

```bash
git tag -a v1.1.0 -m "Release 1.1.0"        # tags HEAD
git tag -a v1.0.1 -m "Hotfix" 4f7a1d9       # tag an older commit
git tag -n1                                  # list with first message line
git show v1.1.0                              # tag info + the commit
```

Expected `git tag -n1`:

```
v1.0.1          Hotfix
v1.1.0          Release 1.1.0
```

### Tags are not pushed by default

```bash
git push origin v1.1.0          # one tag
git push --follow-tags          # pushes annotated tags reachable from pushed commits
git ls-remote --tags origin
```

Expected `ls-remote` output:

```
a14c7be...	refs/tags/v1.1.0
5be0a93...	refs/tags/v1.1.0^{}
```

The `^{}` line is the commit the annotated tag points to ("peeled").

```knowledge-check
{ "questions": [
  { "id": "git-cap-tag-q1", "type": "mcq",
    "prompt": "Does a plain git push publish tags?",
    "options": [
      {"id":"a","text":"No - push them explicitly (git push origin <tag> or --tags)"},
      {"id":"b","text":"Yes, always"},
      {"id":"c","text":"Only annotated tags"},
      {"id":"d","text":"Only on the main branch"}],
    "correct": "a",
    "explanation": "Tags are references of their own and must be pushed on request (or with --follow-tags / push.followTags). Plain push sends no tags of either kind, on any branch." }
] }
```

Set `git config --global push.followTags true` to push annotated tags with
their commits automatically.

### Semantic versioning

`MAJOR.MINOR.PATCH`, e.g. `v2.4.1`:

- **MAJOR** - breaking change for users (2.x -> 3.0.0)
- **MINOR** - new feature, backwards compatible (2.4 -> 2.5.0)
- **PATCH** - bug fix only (2.4.0 -> 2.4.1)
- Pre-releases: `v3.0.0-rc.1`

### Find your place relative to tags

```bash
git describe
```

Expected output a few commits after `v1.0`:

```
v1.0-3-g9d4b0c2
```

Read it as: nearest annotated tag `v1.0`, 3 commits later, at commit `9d4b0c2`
(`g` = git). Builds often embed this as their version string.

```bash
git log --oneline v1.0..v1.1.0      # what went into 1.1.0 (release notes)
git switch -c hotfix/1.0.1 v1.0     # branch a fix from an old release
```

### Delete or move a tag

```bash
git tag -d v1.1.0                    # local
git push origin --delete v1.1.0      # remote
```

Never move a published release tag; people and caches already trust it. Make a
new version instead (`v1.1.1`).

### Hosting "releases"

GitHub/GitLab Releases are a page attached to a tag: notes plus downloadable
build artifacts. The tag is the Git part; the rest is the host.

## Try it

You released `v2.0.0`, then found a typo in the tag message. It is already
pushed and users downloaded it. What do you do?

<details>
<summary>Show answer</summary>

Leave the tag alone. Moving a published tag breaks trust and caches, and other
clones will not update their copy automatically. A message typo is not worth
it; if the code was wrong, release `v2.0.1`.

</details>

## Common mistakes

- **Lightweight tags for releases.** No author, date or message, and ignored by
  `describe`.
- **Forgetting to push tags.** CI that builds on tags never triggers.
- **Re-tagging a release.** Users who fetched the old tag keep it.

## Remember

- Annotated tag (`-a`) for releases; lightweight for private bookmarks.
- Push tags explicitly (`git push origin v1.2.0`) or set `push.followTags`.
- SemVer: MAJOR breaking, MINOR features, PATCH fixes.
- `git describe` = nearest tag + distance; never move published tags.

**Self-check:**

1. What does an annotated tag store that a lightweight one does not?
2. What does `v1.0-3-g9d4b0c2` mean?
3. Which version part changes for a breaking API change?
$md$, 8, $json$[{"id":"git-cap-tag-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('89a9d394-e5fa-5c01-bba3-37bcdfb18e5c', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'b512cc2b-eecf-5fd0-8acd-e11f22b48966', 'Git Hooks: Automatic Checks Before Commit and Push', 'notes', 2, $md$## Why this matters

Linting, formatting, secret scanning and commit-message rules are easy to
forget. **Hooks** are scripts Git runs automatically at key moments, so the
check happens every time without anyone remembering. They catch problems in
seconds on your laptop instead of minutes later in CI.

## Mental model: tripwires on the path

Each hook is a tripwire at a step of the commit/push path. If the script exits
non-zero, the step is cancelled.

```
 git commit:  pre-commit -> prepare-commit-msg -> commit-msg -> (commit) -> post-commit
 git push:    pre-push -> (upload) ---> SERVER: pre-receive -> update -> post-receive
```

| Hook | Runs | Typical use | Can block? |
|---|---|---|---|
| `pre-commit` | Before the commit is created | Lint/format staged files, secret scan | Yes |
| `commit-msg` | After the message is written; gets its file path as `$1` | Enforce message format | Yes |
| `pre-push` | Before uploading | Run fast tests | Yes |
| `post-merge`, `post-checkout` | After the action | Reinstall dependencies | No |
| `pre-receive` (server) | When the server receives a push | Enforce policy for everyone | Yes |

## See it work

### Where hooks live

By default: `.git/hooks/<name>`, an executable file with exactly the hook's
name (no extension). Git ships `*.sample` files there as examples.

`.git/hooks` is **not** versioned or cloned. To share hooks with the team, keep
them in the repo and point Git at the folder:

```bash
mkdir -p .githooks
git config core.hooksPath .githooks
```

Each teammate still runs that `git config` once (or a setup script does it).

### A commit-msg hook

Require messages like `SHOP-42: Add coupon support`:

```bash
cat > .githooks/commit-msg <<'EOF'
#!/bin/sh
# $1 = path to the file holding the proposed message
if ! head -1 "$1" | grep -qE '^[A-Z]+-[0-9]+: .+'; then
  echo "commit-msg: subject must look like 'SHOP-42: Describe change'" >&2
  exit 1
fi
EOF
chmod +x .githooks/commit-msg
```

What it does: reads the first line of the message; exits 1 (blocking the
commit) if it lacks a ticket key. Try it:

```bash
git commit --allow-empty -m "fix stuff"
```

Expected output:

```
commit-msg: subject must look like 'SHOP-42: Describe change'
```

and no commit is created. `git commit -m "SHOP-42: Add coupon support"` works.

### A pre-commit hook that checks staged content

```sh
#!/bin/sh
# block commits that add obvious secrets
if git diff --cached -U0 | grep -qE '^\+.*(AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH) PRIVATE KEY)'; then
  echo "pre-commit: possible secret in staged changes" >&2
  exit 1
fi
```

Check **staged** content (`git diff --cached`), not the working tree, because
the commit is built from the index.

### Frameworks and limits

- Tools such as **pre-commit** (pre-commit.com), Husky (JavaScript) or
  Lefthook manage hook installation and run linters on staged files only.
- Anyone can skip client hooks with `git commit --no-verify` (`-n`). Hooks are a
  convenience, not security. Enforce rules for real in **CI** and server-side
  (protected branches, required checks, `pre-receive`).

## Try it

Your `pre-push` hook runs the full test suite (8 minutes) and people now use
`--no-verify` all the time. What would you change?

<details>
<summary>Show answer</summary>

Keep hooks fast (seconds): lint and format only changed files in `pre-commit`,
maybe a quick unit subset in `pre-push`. Move the full suite to CI as a
required check on pull requests. Slow hooks train people to bypass them.

</details>

## Common mistakes

- **Forgetting `chmod +x`.** A non-executable hook is silently ignored (Git
  prints a hint).
- **Naming it `commit-msg.sh`.** The file must be named exactly `commit-msg`.
- **Expecting `.git/hooks` to be shared.** It is not cloned; use
  `core.hooksPath` or a hook manager.
- **Treating hooks as enforcement.** `--no-verify` skips them.

## Remember

- Hooks = executable scripts named after an event; non-zero exit blocks.
- `pre-commit` checks staged content, `commit-msg` checks the message (`$1`).
- Share hooks via a versioned folder + `core.hooksPath`.
- Real enforcement lives in CI and on the server.

**Self-check:**

1. Which argument does `commit-msg` receive?
2. Why are hooks in `.git/hooks` not shared with teammates?
3. How can a developer bypass client hooks?
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0f1c8982-6dc1-57e7-a0a0-286515db7b75', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'b512cc2b-eecf-5fd0-8acd-e11f22b48966', 'Signing Commits and Tags (SSH and GPG)', 'notes', 3, $md$## Why this matters

Anyone can run `git config user.name "Maya Lead"` and commit as Maya. The
author field is just text. A **signature** proves a commit or tag was made by
someone holding a specific private key. Many companies and open-source projects
require signed commits on protected branches, and supply-chain security
standards build on it.

## Mental model: a wax seal

The author line is a name written on the envelope; anyone can write it. A
signature is a wax seal from a ring only you own. Others check the seal against
your public key.

```
 commit content --sign with PRIVATE key--> signature stored in the commit
 verifier       --check with PUBLIC key--> "Good signature from Ada" or "BAD"
```

Two key types work:

| | SSH signing (Git 2.34+) | GPG |
|---|---|---|
| Key you probably already have | Yes (`~/.ssh/id_ed25519`) | Needs `gpg` setup |
| Setup effort | Low | Higher (keyrings, expiry, subkeys) |
| Host support | GitHub, GitLab | GitHub, GitLab |

## See it work

### Set up SSH signing once

```bash
git config --global gpg.format ssh
git config --global user.signingKey ~/.ssh/id_ed25519.pub
git config --global commit.gpgSign true     # sign every commit
git config --global tag.gpgSign true        # sign every annotated tag
```

Despite the `gpg` in the names, these keys control SSH signing too. Then upload
the same public key on the host as a **signing key** (a separate setting from
the authentication key list, even if the key is the same).

### Sign and verify

```bash
git commit -S -m "Add coupon support"   # -S signs this commit (automatic if commit.gpgSign=true)
git tag -s v1.2.0 -m "Release 1.2.0"    # signed annotated tag
```

To verify SSH signatures locally, Git needs a list of trusted keys:

```bash
echo "ada@example.com $(cat ~/.ssh/id_ed25519.pub)" > ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
git log --show-signature -1
git verify-commit HEAD
git verify-tag v1.2.0
```

Expected `verify-commit` output for a valid signature:

```
Good "git" signature for ada@example.com with ED25519 key SHA256:...
```

On GitHub/GitLab, signed commits from a registered key show a **Verified**
badge. Branch protection can require it.

### GPG in two lines

```bash
gpg --full-generate-key                          # create a key
git config --global user.signingKey <KEY-ID>     # gpg.format stays the default (openpgp)
```

Export the public key with `gpg --armor --export <KEY-ID>` for the host.

### What signing does not do

- It does not encrypt anything; content stays readable.
- It proves who signed, not that the code is good.
- Rebasing or amending creates new commits that must be signed again
  (automatic with `commit.gpgSign true`). Commits made by the host's merge
  button are signed by the host's key.

## Try it

Your company requires signed commits on `main`. You rebased your PR branch and
the host now shows your commits as "Unverified". Why, and how do you fix it?

<details>
<summary>Show answer</summary>

Rebase created **new** commits, and they were not signed (signing was not
enabled for every commit). Enable `commit.gpgSign true`, then re-sign the
branch's commits, for example:

```bash
git rebase --exec 'git commit --amend --no-edit -S' origin/main
git push --force-with-lease
```

</details>

## Common mistakes

- **Uploading the key only as an authentication key.** Hosts need it listed as
  a signing key to show "Verified".
- **Signing with an email the host does not know.** The commit email must
  match a verified email on your account.
- **Thinking `user.name` proves identity.** Only signatures do.

## Remember

- Author fields are just text; signatures prove key ownership.
- SSH signing: `gpg.format ssh` + `user.signingKey` + `commit.gpgSign true`.
- Verify with `git log --show-signature`, `git verify-commit`, `git verify-tag`.
- Rewritten commits need re-signing.

**Self-check:**

1. Why can't the author field be trusted on its own?
2. Which setting makes Git use SSH keys for signing?
3. Why do rebased commits lose their signatures?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5390022b-f895-5bd5-9d13-e3b338776aab', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'b512cc2b-eecf-5fd0-8acd-e11f22b48966', 'Lab: Tag a Release and Enforce Commit Messages with a Hook', 'notes', 4, $md$## Why this matters

Releases need permanent names, and teams need rules that run themselves. In
`~/work/shop-release` you will tag an older commit as a release, publish the
tag, read `git describe`, and add a shared hook that enforces the team's commit
message format.

```bash
cd ~/work/shop-release
git log --oneline
```

Expected:

```
1a2b3c4 (HEAD -> main, origin/main) SHOP-5: Add coupon rules
8d9e0f1 SHOP-4: Start coupons
5c6d7e8 SHOP-3: Finish checkout
...
```

## Task 1: tag an older commit

Release 2.0.0 was `SHOP-3: Finish checkout`. Create an **annotated** tag
`v2.0.0` with the message `Release 2.0.0` on that commit.

[[lab-task:1]]

Check: `git cat-file -t v2.0.0` prints `tag` (a lightweight tag would print
`commit`).

## Task 2: push it

[[lab-task:2]]

Expected `git ls-remote --tags origin`:

```
<tag-object-hash>	refs/tags/v2.0.0
<commit-hash>	refs/tags/v2.0.0^{}
```

## Task 3: where is HEAD relative to the release?

Save `git describe` output into `~/work/describe.txt`.

[[lab-task:3]]

Expected shape: `v2.0.0-2-g1a2b3c4` (two commits after the tag).

## Task 4: a shared commit-msg hook

Create `.githooks/commit-msg` that exits 1 unless the subject starts with a
ticket key such as `SHOP-42: `. Make it executable and set `core.hooksPath`.

```sh
#!/bin/sh
head -1 "$1" | grep -qE '^[A-Z]+-[0-9]+: .+' || {
  echo "commit-msg: subject must look like 'SHOP-42: Describe change'" >&2
  exit 1
}
```

[[lab-task:4]]

## Task 5: commit the hook, through the hook

First try `git commit -m "add hook"` and watch it be rejected. Then commit with
`SHOP-7: Add commit-msg hook`.

[[lab-task:5]]

Check: `git ls-tree HEAD .githooks/` shows mode `100755`.

## Remember

- Annotated tags for releases; push them explicitly.
- `git describe` turns any commit into a readable version.
- Share hooks with a versioned folder and `core.hooksPath`; enforce for real in CI.
$md$, 30, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('bc0ca6ba-ee7b-5816-823d-252442cb20fc', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '5390022b-f895-5bd5-9d13-e3b338776aab', 'module', 'Lab: Tag a Release and Enforce Commit Messages with a Hook', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
rm -rf /home/labuser/work/shop-release /home/labuser/srv/git/shop-release.git /home/labuser/work/describe.txt /tmp/seed
mkdir -p /home/labuser/srv/git
git init -q --bare /home/labuser/srv/git/shop-release.git
git --git-dir=/home/labuser/srv/git/shop-release.git symbolic-ref HEAD refs/heads/main
mkdir -p /home/labuser/work/shop-release && cd /home/labuser/work/shop-release
git init -q
M() { git add -A; GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
echo "# Shop" > README.md; M 2024-09-01 "SHOP-1: Initial shop"
echo "cart" > cart.txt; M 2024-09-02 "SHOP-2: Add cart"
echo "checkout" > checkout.txt; M 2024-09-03 "SHOP-3: Finish checkout"
echo "coupons" > coupons.txt; M 2024-09-04 "SHOP-4: Start coupons"
echo "coupon rules" >> coupons.txt; M 2024-09-05 "SHOP-5: Add coupon rules"
git remote add origin /home/labuser/srv/git/shop-release.git
git push -q -u origin main 2>/dev/null
$script$, NULL, 40, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'dd24556d-4ee1-53fe-b631-c3215a624e85' AND id NOT IN ('1bb6c4b7-884f-5e24-9c13-f3367926a58e', '4e4f46c9-d7a3-551e-acce-9d1946b26626', '35d54923-21db-5e86-91f2-b6eb3f144fdf', '98d1cab1-dbf0-57e1-9c87-d6da28176a3e', 'c1436008-93c1-5f0b-ab81-63b657a3d3eb');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'dd24556d-4ee1-53fe-b631-c3215a624e85';
DELETE FROM lab_tasks WHERE lab_id = 'bc0ca6ba-ee7b-5816-823d-252442cb20fc' AND id NOT IN ('6aa8e9dc-5791-5167-b66d-383d08d0f8bf', '5e6a052c-23dc-50d6-af53-fcca8ee4937c', '8bf116a3-e25a-5bae-aa14-f932f8a8d9eb', 'e78ba882-14f0-5d7c-af3b-4246fbb4a381', '4c65d65c-cfb0-56d9-9eaa-5b2b4867d9fc');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'bc0ca6ba-ee7b-5816-823d-252442cb20fc';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('6aa8e9dc-5791-5167-b66d-383d08d0f8bf', 'bc0ca6ba-ee7b-5816-823d-252442cb20fc', 1, 'Tag an older commit as a release', $md$In ~/work/shop-release, release 2.0.0 was the commit "SHOP-3: Finish checkout", not the current tip. Create an annotated tag v2.0.0 with the message "Release 2.0.0" on that commit.$md$, $script$r=/home/labuser/work/shop-release
[ "$(git -C $r cat-file -t v2.0.0 2>/dev/null)" = tag ] &&
[ "$(git -C $r log -1 --format=%s 'v2.0.0^{commit}')" = "SHOP-3: Finish checkout" ] &&
git -C $r tag -n1 v2.0.0 | grep -q 'Release 2.0.0'
$script$, 'Find the hash with git log --oneline, then git tag -a v2.0.0 -m "Release 2.0.0" <hash>. Without -a you get a lightweight tag, which is not a tag object.', 'An annotated tag is its own object with tagger, date and message, pointing at a commit. Tags can point at any commit, not only HEAD.', 15, false, true),
('5e6a052c-23dc-50d6-af53-fcca8ee4937c', 'bc0ca6ba-ee7b-5816-823d-252442cb20fc', 2, 'Publish the tag', $md$Push the tag v2.0.0 to origin. A plain git push does not send tags.$md$, $script$r=/home/labuser/work/shop-release
[ "$(git --git-dir=/home/labuser/srv/git/shop-release.git rev-parse -q --verify refs/tags/v2.0.0)" = "$(git -C $r rev-parse v2.0.0)" ]
$script$, 'git push origin v2.0.0, then git ls-remote --tags origin to confirm.', 'Tags are refs of their own. They travel only when pushed explicitly (or with --follow-tags / push.followTags).', 10, false, true),
('8bf116a3-e25a-5bae-aa14-f932f8a8d9eb', 'bc0ca6ba-ee7b-5816-823d-252442cb20fc', 3, 'Describe HEAD relative to the release', $md$Write the output of git describe for the current HEAD, alone on one line, into ~/work/describe.txt.$md$, $script$r=/home/labuser/work/shop-release
d=$(git -C $r describe 2>/dev/null) && [ -n "$d" ] &&
[ "$(tr -d '[:space:]' < /home/labuser/work/describe.txt)" = "$d" ]
$script$, 'git describe > ~/work/describe.txt. It prints the nearest annotated tag, the number of commits since it, and the abbreviated hash.', 'describe gives every commit a human-readable version like v2.0.0-2-g1a2b3c4 (2 commits after v2.0.0), which build systems embed as a version string.', 10, false, true),
('e78ba882-14f0-5d7c-af3b-4246fbb4a381', 'bc0ca6ba-ee7b-5816-823d-252442cb20fc', 4, 'Add a shared commit-msg hook', $md$Create an executable hook .githooks/commit-msg in the repository that rejects any commit whose subject does not start with a ticket key like "SHOP-42: ", and make Git use that folder for hooks (core.hooksPath).$md$, $script$r=/home/labuser/work/shop-release
h=$r/.githooks/commit-msg
[ "$(git -C $r config --get core.hooksPath)" = .githooks ] && [ -x "$h" ] &&
t=$(mktemp) && echo "fix stuff" > "$t" && ! (cd $r && "$h" "$t" >/dev/null 2>&1) &&
echo "SHOP-42: Add coupon support" > "$t" && (cd $r && "$h" "$t" >/dev/null 2>&1)
$script$, 'The hook gets the message file path as $1. Test the first line with grep -qE ''^[A-Z]+-[0-9]+: '' and exit 1 when it does not match. chmod +x the file, then git config core.hooksPath .githooks.', '.git/hooks is never cloned, so teams keep hooks in a versioned folder and point core.hooksPath at it. A non-zero exit from commit-msg cancels the commit.', 20, false, true),
('4c65d65c-cfb0-56d9-9eaa-5b2b4867d9fc', 'bc0ca6ba-ee7b-5816-823d-252442cb20fc', 5, 'Commit the hook through the hook', $md$Commit .githooks/commit-msg with the message "SHOP-7: Add commit-msg hook" (try a bad message first and watch it fail). The file must be committed as executable.$md$, $script$r=/home/labuser/work/shop-release
[ "$(git -C $r log -1 --format=%s)" = "SHOP-7: Add commit-msg hook" ] &&
[ "$(git -C $r ls-tree HEAD .githooks/commit-msg | cut -d' ' -f1)" = 100755 ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git add .githooks/commit-msg, then git commit -m "SHOP-7: Add commit-msg hook". A message like "add hook" should be rejected by your hook.', 'Git records the executable bit (mode 100755), so teammates who set core.hooksPath get a working hook straight from the repository.', 15, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('dd24556d-4ee1-53fe-b631-c3215a624e85', 'bc0ca6ba-ee7b-5816-823d-252442cb20fc', 1, $json$[{"id":"6aa8e9dc-5791-5167-b66d-383d08d0f8bf","lab_id":"bc0ca6ba-ee7b-5816-823d-252442cb20fc","position":1,"title":"Tag an older commit as a release","description":"In ~/work/shop-release, release 2.0.0 was the commit \"SHOP-3: Finish checkout\", not the current tip. Create an annotated tag v2.0.0 with the message \"Release 2.0.0\" on that commit.","verification_script":"r=/home/labuser/work/shop-release\n[ \"$(git -C $r cat-file -t v2.0.0 2\u003e/dev/null)\" = tag ] \u0026\u0026\n[ \"$(git -C $r log -1 --format=%s 'v2.0.0^{commit}')\" = \"SHOP-3: Finish checkout\" ] \u0026\u0026\ngit -C $r tag -n1 v2.0.0 | grep -q 'Release 2.0.0'\n","hint_context":"Find the hash with git log --oneline, then git tag -a v2.0.0 -m \"Release 2.0.0\" \u003chash\u003e. Without -a you get a lightweight tag, which is not a tag object.","explanation_context":"An annotated tag is its own object with tagger, date and message, pointing at a commit. Tags can point at any commit, not only HEAD.","points":15,"is_optional":false,"is_stateful":true},{"id":"5e6a052c-23dc-50d6-af53-fcca8ee4937c","lab_id":"bc0ca6ba-ee7b-5816-823d-252442cb20fc","position":2,"title":"Publish the tag","description":"Push the tag v2.0.0 to origin. A plain git push does not send tags.","verification_script":"r=/home/labuser/work/shop-release\n[ \"$(git --git-dir=/home/labuser/srv/git/shop-release.git rev-parse -q --verify refs/tags/v2.0.0)\" = \"$(git -C $r rev-parse v2.0.0)\" ]\n","hint_context":"git push origin v2.0.0, then git ls-remote --tags origin to confirm.","explanation_context":"Tags are refs of their own. They travel only when pushed explicitly (or with --follow-tags / push.followTags).","points":10,"is_optional":false,"is_stateful":true},{"id":"8bf116a3-e25a-5bae-aa14-f932f8a8d9eb","lab_id":"bc0ca6ba-ee7b-5816-823d-252442cb20fc","position":3,"title":"Describe HEAD relative to the release","description":"Write the output of git describe for the current HEAD, alone on one line, into ~/work/describe.txt.","verification_script":"r=/home/labuser/work/shop-release\nd=$(git -C $r describe 2\u003e/dev/null) \u0026\u0026 [ -n \"$d\" ] \u0026\u0026\n[ \"$(tr -d '[:space:]' \u003c /home/labuser/work/describe.txt)\" = \"$d\" ]\n","hint_context":"git describe \u003e ~/work/describe.txt. It prints the nearest annotated tag, the number of commits since it, and the abbreviated hash.","explanation_context":"describe gives every commit a human-readable version like v2.0.0-2-g1a2b3c4 (2 commits after v2.0.0), which build systems embed as a version string.","points":10,"is_optional":false,"is_stateful":true},{"id":"e78ba882-14f0-5d7c-af3b-4246fbb4a381","lab_id":"bc0ca6ba-ee7b-5816-823d-252442cb20fc","position":4,"title":"Add a shared commit-msg hook","description":"Create an executable hook .githooks/commit-msg in the repository that rejects any commit whose subject does not start with a ticket key like \"SHOP-42: \", and make Git use that folder for hooks (core.hooksPath).","verification_script":"r=/home/labuser/work/shop-release\nh=$r/.githooks/commit-msg\n[ \"$(git -C $r config --get core.hooksPath)\" = .githooks ] \u0026\u0026 [ -x \"$h\" ] \u0026\u0026\nt=$(mktemp) \u0026\u0026 echo \"fix stuff\" \u003e \"$t\" \u0026\u0026 ! (cd $r \u0026\u0026 \"$h\" \"$t\" \u003e/dev/null 2\u003e\u00261) \u0026\u0026\necho \"SHOP-42: Add coupon support\" \u003e \"$t\" \u0026\u0026 (cd $r \u0026\u0026 \"$h\" \"$t\" \u003e/dev/null 2\u003e\u00261)\n","hint_context":"The hook gets the message file path as $1. Test the first line with grep -qE '^[A-Z]+-[0-9]+: ' and exit 1 when it does not match. chmod +x the file, then git config core.hooksPath .githooks.","explanation_context":".git/hooks is never cloned, so teams keep hooks in a versioned folder and point core.hooksPath at it. A non-zero exit from commit-msg cancels the commit.","points":20,"is_optional":false,"is_stateful":true},{"id":"4c65d65c-cfb0-56d9-9eaa-5b2b4867d9fc","lab_id":"bc0ca6ba-ee7b-5816-823d-252442cb20fc","position":5,"title":"Commit the hook through the hook","description":"Commit .githooks/commit-msg with the message \"SHOP-7: Add commit-msg hook\" (try a bad message first and watch it fail). The file must be committed as executable.","verification_script":"r=/home/labuser/work/shop-release\n[ \"$(git -C $r log -1 --format=%s)\" = \"SHOP-7: Add commit-msg hook\" ] \u0026\u0026\n[ \"$(git -C $r ls-tree HEAD .githooks/commit-msg | cut -d' ' -f1)\" = 100755 ] \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"git add .githooks/commit-msg, then git commit -m \"SHOP-7: Add commit-msg hook\". A message like \"add hook\" should be rejected by your hook.","explanation_context":"Git records the executable bit (mode 100755), so teammates who set core.hooksPath get a working hook straight from the repository.","points":15,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('1bb6c4b7-884f-5e24-9c13-f3367926a58e', 'dd24556d-4ee1-53fe-b631-c3215a624e85', '6aa8e9dc-5791-5167-b66d-383d08d0f8bf', 1, 'Tag an older commit as a release', $md$In ~/work/shop-release, release 2.0.0 was the commit "SHOP-3: Finish checkout", not the current tip. Create an annotated tag v2.0.0 with the message "Release 2.0.0" on that commit.$md$, $script$r=/home/labuser/work/shop-release
[ "$(git -C $r cat-file -t v2.0.0 2>/dev/null)" = tag ] &&
[ "$(git -C $r log -1 --format=%s 'v2.0.0^{commit}')" = "SHOP-3: Finish checkout" ] &&
git -C $r tag -n1 v2.0.0 | grep -q 'Release 2.0.0'
$script$, 'Find the hash with git log --oneline, then git tag -a v2.0.0 -m "Release 2.0.0" <hash>. Without -a you get a lightweight tag, which is not a tag object.', 'An annotated tag is its own object with tagger, date and message, pointing at a commit. Tags can point at any commit, not only HEAD.', 15, false, true),
('4e4f46c9-d7a3-551e-acce-9d1946b26626', 'dd24556d-4ee1-53fe-b631-c3215a624e85', '5e6a052c-23dc-50d6-af53-fcca8ee4937c', 2, 'Publish the tag', $md$Push the tag v2.0.0 to origin. A plain git push does not send tags.$md$, $script$r=/home/labuser/work/shop-release
[ "$(git --git-dir=/home/labuser/srv/git/shop-release.git rev-parse -q --verify refs/tags/v2.0.0)" = "$(git -C $r rev-parse v2.0.0)" ]
$script$, 'git push origin v2.0.0, then git ls-remote --tags origin to confirm.', 'Tags are refs of their own. They travel only when pushed explicitly (or with --follow-tags / push.followTags).', 10, false, true),
('35d54923-21db-5e86-91f2-b6eb3f144fdf', 'dd24556d-4ee1-53fe-b631-c3215a624e85', '8bf116a3-e25a-5bae-aa14-f932f8a8d9eb', 3, 'Describe HEAD relative to the release', $md$Write the output of git describe for the current HEAD, alone on one line, into ~/work/describe.txt.$md$, $script$r=/home/labuser/work/shop-release
d=$(git -C $r describe 2>/dev/null) && [ -n "$d" ] &&
[ "$(tr -d '[:space:]' < /home/labuser/work/describe.txt)" = "$d" ]
$script$, 'git describe > ~/work/describe.txt. It prints the nearest annotated tag, the number of commits since it, and the abbreviated hash.', 'describe gives every commit a human-readable version like v2.0.0-2-g1a2b3c4 (2 commits after v2.0.0), which build systems embed as a version string.', 10, false, true),
('98d1cab1-dbf0-57e1-9c87-d6da28176a3e', 'dd24556d-4ee1-53fe-b631-c3215a624e85', 'e78ba882-14f0-5d7c-af3b-4246fbb4a381', 4, 'Add a shared commit-msg hook', $md$Create an executable hook .githooks/commit-msg in the repository that rejects any commit whose subject does not start with a ticket key like "SHOP-42: ", and make Git use that folder for hooks (core.hooksPath).$md$, $script$r=/home/labuser/work/shop-release
h=$r/.githooks/commit-msg
[ "$(git -C $r config --get core.hooksPath)" = .githooks ] && [ -x "$h" ] &&
t=$(mktemp) && echo "fix stuff" > "$t" && ! (cd $r && "$h" "$t" >/dev/null 2>&1) &&
echo "SHOP-42: Add coupon support" > "$t" && (cd $r && "$h" "$t" >/dev/null 2>&1)
$script$, 'The hook gets the message file path as $1. Test the first line with grep -qE ''^[A-Z]+-[0-9]+: '' and exit 1 when it does not match. chmod +x the file, then git config core.hooksPath .githooks.', '.git/hooks is never cloned, so teams keep hooks in a versioned folder and point core.hooksPath at it. A non-zero exit from commit-msg cancels the commit.', 20, false, true),
('c1436008-93c1-5f0b-ab81-63b657a3d3eb', 'dd24556d-4ee1-53fe-b631-c3215a624e85', '4c65d65c-cfb0-56d9-9eaa-5b2b4867d9fc', 5, 'Commit the hook through the hook', $md$Commit .githooks/commit-msg with the message "SHOP-7: Add commit-msg hook" (try a bad message first and watch it fail). The file must be committed as executable.$md$, $script$r=/home/labuser/work/shop-release
[ "$(git -C $r log -1 --format=%s)" = "SHOP-7: Add commit-msg hook" ] &&
[ "$(git -C $r ls-tree HEAD .githooks/commit-msg | cut -d' ' -f1)" = 100755 ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git add .githooks/commit-msg, then git commit -m "SHOP-7: Add commit-msg hook". A message like "add hook" should be rejected by your hook.', 'Git records the executable bit (mode 100755), so teammates who set core.hooksPath get a working hook straight from the repository.', 15, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'dd24556d-4ee1-53fe-b631-c3215a624e85', updated_at = now()
WHERE id = 'bc0ca6ba-ee7b-5816-823d-252442cb20fc' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('20d1ee55-c001-5eec-8a3e-8a5188612bdd', '00000000-0000-0000-0000-000000000001', 'mcq', 'A SaaS team deploys main to production many times a day. Which branching stra...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('673bda7b-1aad-5936-a538-ba453ad6b7fe', '20d1ee55-c001-5eec-8a3e-8a5188612bdd', 1, $json${"prompt":"A SaaS team deploys main to production many times a day. Which branching strategy fits best?","multiple":false,"options":[{"id":"a","text":"Git flow with develop, release and hotfix branches","is_correct":false},{"id":"b","text":"Trunk-based development or GitHub flow with short-lived branches and protected main","is_correct":true},{"id":"c","text":"One long-lived branch per developer, merged monthly","is_correct":false},{"id":"d","text":"No branches; everyone pushes directly with --force","is_correct":false}],"explanation":"Continuous deployment wants small, frequent integration into one always-deployable main. Git flow adds release ceremony meant for versioned products, monthly merges create huge conflicts, and force-pushing main destroys work."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b3fb8c25-f691-5ad8-811e-d465927d0f5f', '00000000-0000-0000-0000-000000000001', 'mcq', 'CI builds a release whenever a tag v* is pushed. You ran `git tag -a v1.4.0 -...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('452bbb1e-da09-5f9d-9f2a-e57713b1afaf', 'b3fb8c25-f691-5ad8-811e-d465927d0f5f', 1, $json${"prompt":"CI builds a release whenever a tag v* is pushed. You ran `git tag -a v1.4.0 -m 'Release 1.4.0'` and `git push`. CI did not start. Why?","multiple":false,"options":[{"id":"a","text":"Annotated tags cannot trigger CI","is_correct":false},{"id":"b","text":"A plain git push does not send tags; run git push origin v1.4.0","is_correct":true},{"id":"c","text":"Tags must be lightweight","is_correct":false},{"id":"d","text":"The tag needs to be on a branch called release","is_correct":false}],"explanation":"Tags are only pushed explicitly or with --follow-tags/push.followTags. Annotated tags are exactly what release tooling expects, and tags can point at any commit."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('828a56e0-0ba1-5645-9957-78609d34c2b6', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your library''s public function signature changed in a way that breaks callers...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9fb23387-de11-5959-ab14-2052b2acf1d8', '828a56e0-0ba1-5645-9957-78609d34c2b6', 1, $json${"prompt":"Your library's public function signature changed in a way that breaks callers. Current version is 2.7.3. What is the next SemVer version?","multiple":false,"options":[{"id":"a","text":"2.7.4","is_correct":false},{"id":"b","text":"2.8.0","is_correct":false},{"id":"c","text":"3.0.0","is_correct":true},{"id":"d","text":"2.7.3-breaking","is_correct":false}],"explanation":"Breaking changes bump MAJOR and reset the others. PATCH is for fixes, MINOR for compatible features, and a suffix marks pre-releases, not breaking changes."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('12ab2952-cb66-5de5-bd8b-b1c7d88c9d96', '00000000-0000-0000-0000-000000000001', 'mcq', 'You added an executable .git/hooks/commit-msg to enforce ticket keys. A teamm...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e1995cac-eebc-5a70-a413-0cc8f8259800', '12ab2952-cb66-5de5-bd8b-b1c7d88c9d96', 1, $json${"prompt":"You added an executable .git/hooks/commit-msg to enforce ticket keys. A teammate clones the repo and their commits are not checked. Why?","multiple":false,"options":[{"id":"a","text":"Hooks only run on the server","is_correct":false},{"id":"b","text":".git/hooks is not part of the repository content and is never cloned; share hooks via a committed folder plus core.hooksPath or a hook manager","is_correct":true},{"id":"c","text":"commit-msg hooks only run with --verify","is_correct":false},{"id":"d","text":"The teammate uses a different branch","is_correct":false}],"explanation":"Each clone has its own .git/hooks with only sample files. Client hooks do run locally (that is the point), run by default, and do not depend on branches."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('610cbcf6-9b78-5fee-942c-2df29ff442bf', '00000000-0000-0000-0000-000000000001', 'mcq', 'Management wants a guarantee that no commit with a failing linter ever reache...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f31c9dc2-d6ef-5479-9f13-84e5adf0fba2', '610cbcf6-9b78-5fee-942c-2df29ff442bf', 1, $json${"prompt":"Management wants a guarantee that no commit with a failing linter ever reaches main. Is a pre-commit hook enough?","multiple":false,"options":[{"id":"a","text":"Yes; hooks cannot be skipped","is_correct":false},{"id":"b","text":"No; `git commit --no-verify` skips client hooks, so also require the lint check in CI and protect main","is_correct":true},{"id":"c","text":"Yes, if it is also a pre-push hook","is_correct":false},{"id":"d","text":"No; hooks only work for commit messages","is_correct":false}],"explanation":"Client hooks are a convenience. Enforcement belongs in CI and server-side branch protection. pre-push can also be skipped with --no-verify, and pre-commit can run any check, not only messages."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a216c164-b4a3-5690-8796-1c6dffa97156', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why does a signed commit prove more than the author field?', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('3e681b4e-2607-518b-a5da-4cbd8fc509ba', 'a216c164-b4a3-5690-8796-1c6dffa97156', 1, $json${"prompt":"Why does a signed commit prove more than the author field?","multiple":false,"options":[{"id":"a","text":"Anyone can set user.name and user.email to any value, but only the holder of the private key can produce a signature that verifies against the public key","is_correct":true},{"id":"b","text":"Signing encrypts the commit so others cannot read it","is_correct":false},{"id":"c","text":"Signed commits cannot be reverted","is_correct":false},{"id":"d","text":"The host checks the author's password at commit time","is_correct":false}],"explanation":"The author line is plain text. Signing does not encrypt, does not prevent reverts, and hosts never see commits until push, so they cannot check passwords at commit time."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ba93770b-e86d-52db-a43f-b677b9131804', '00000000-0000-0000-0000-000000000001', 'mcq', '`git describe` prints v3.1.0-12-g4e5f6a7. What does it mean?', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('652cbd05-d300-5c1d-82a4-da92b8d29b54', 'ba93770b-e86d-52db-a43f-b677b9131804', 1, $json${"prompt":"`git describe` prints v3.1.0-12-g4e5f6a7. What does it mean?","multiple":false,"options":[{"id":"a","text":"The nearest annotated tag is v3.1.0; HEAD is 12 commits after it, at commit 4e5f6a7","is_correct":true},{"id":"b","text":"Version 3.1.0, build 12, generation 4e5f6a7","is_correct":false},{"id":"c","text":"Twelve tags exist after v3.1.0","is_correct":false},{"id":"d","text":"HEAD is 12 commits before v3.1.0","is_correct":false}],"explanation":"Format: \u003ctag\u003e-\u003ccommits since tag\u003e-g\u003cshort hash\u003e. It counts commits, not tags or builds, and always looks backwards from HEAD."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('66999eab-3a5c-53de-a596-2ed13c7df831', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 10): which command shows every commit on any branch that adde...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1d241c4c-fc73-57e0-ab55-0dcd7631bbad', '66999eab-3a5c-53de-a596-2ed13c7df831', 1, $json${"prompt":"Review (Section 10): which command shows every commit on any branch that added or removed the string 'API_KEY', with diffs?","multiple":false,"options":[{"id":"a","text":"git log -S API_KEY -p --all","is_correct":true},{"id":"b","text":"git grep API_KEY","is_correct":false},{"id":"c","text":"git blame -C","is_correct":false},{"id":"d","text":"git log --follow API_KEY","is_correct":false}],"explanation":"-S finds additions/removals, -p shows diffs, --all covers every branch. git grep searches current files only, blame annotates existing lines, and --follow tracks a file's renames."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('2f3f737a-436f-5e0c-a0d7-bbaeb1a1e86e', '00000000-0000-0000-0000-000000000001', 'Quiz: Team Workflows, Releases, Hooks and Signing', 'git-workflows-quiz', 'Quiz covering Team Workflows, Releases, Hooks and Signing.', 'mcq', 'published', 'module', 'fa392afe-ceae-5502-a3ee-fad508319da3', 12, 70, 5, 16, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '2f3f737a-436f-5e0c-a0d7-bbaeb1a1e86e' AND question_id NOT IN ('20d1ee55-c001-5eec-8a3e-8a5188612bdd', 'b3fb8c25-f691-5ad8-811e-d465927d0f5f', '828a56e0-0ba1-5645-9957-78609d34c2b6', '12ab2952-cb66-5de5-bd8b-b1c7d88c9d96', '610cbcf6-9b78-5fee-942c-2df29ff442bf', 'a216c164-b4a3-5690-8796-1c6dffa97156', 'ba93770b-e86d-52db-a43f-b677b9131804', '66999eab-3a5c-53de-a596-2ed13c7df831');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('9bc10640-6067-5e85-9aff-d58616b360f9', '2f3f737a-436f-5e0c-a0d7-bbaeb1a1e86e', '20d1ee55-c001-5eec-8a3e-8a5188612bdd', '673bda7b-1aad-5936-a538-ba453ad6b7fe', 0, 2),
('d505a9f2-3b9b-525e-b71a-7e5aceac9d24', '2f3f737a-436f-5e0c-a0d7-bbaeb1a1e86e', 'b3fb8c25-f691-5ad8-811e-d465927d0f5f', '452bbb1e-da09-5f9d-9f2a-e57713b1afaf', 1, 2),
('3aece991-dd7f-5b7d-9c91-f24f7a9771cf', '2f3f737a-436f-5e0c-a0d7-bbaeb1a1e86e', '828a56e0-0ba1-5645-9957-78609d34c2b6', '9fb23387-de11-5959-ab14-2052b2acf1d8', 2, 2),
('3447f473-4061-5128-98ec-74ed34a2d52f', '2f3f737a-436f-5e0c-a0d7-bbaeb1a1e86e', '12ab2952-cb66-5de5-bd8b-b1c7d88c9d96', 'e1995cac-eebc-5a70-a413-0cc8f8259800', 3, 2),
('30ec0b04-cc02-5e3f-a270-d9db38a3fce6', '2f3f737a-436f-5e0c-a0d7-bbaeb1a1e86e', '610cbcf6-9b78-5fee-942c-2df29ff442bf', 'f31c9dc2-d6ef-5479-9f13-84e5adf0fba2', 4, 2),
('442f7c26-13a7-5871-ace1-a2422d794106', '2f3f737a-436f-5e0c-a0d7-bbaeb1a1e86e', 'a216c164-b4a3-5690-8796-1c6dffa97156', '3e681b4e-2607-518b-a5da-4cbd8fc509ba', 5, 2),
('64aebc71-1bd7-5e44-86fa-c0a0fe6435d5', '2f3f737a-436f-5e0c-a0d7-bbaeb1a1e86e', 'ba93770b-e86d-52db-a43f-b677b9131804', '652cbd05-d300-5c1d-82a4-da92b8d29b54', 6, 2),
('4a6e8898-7684-55f4-8bd6-7690c1449f02', '2f3f737a-436f-5e0c-a0d7-bbaeb1a1e86e', '66999eab-3a5c-53de-a596-2ed13c7df831', '1d241c4c-fc73-57e0-ab55-0dcd7631bbad', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('fa392afe-ceae-5502-a3ee-fad508319da3', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'b512cc2b-eecf-5fd0-8acd-e11f22b48966', 'Quiz: Team Workflows, Releases, Hooks and Signing', 'assessment', 5, 10, '2f3f737a-436f-5e0c-a0d7-bbaeb1a1e86e')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Power Tools: Worktrees, Submodules and Large Repos
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('b2ad8505-d4d2-5871-a812-03fb6c8db169', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Power Tools: Worktrees, Submodules and Large Repos', 12, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('42932fd5-7539-5e4e-94a6-23ebcf6adb20', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'b2ad8505-d4d2-5871-a812-03fb6c8db169', 'Worktrees: Several Branches Checked Out at Once', 'notes', 0, $md$## Why this matters

You are deep in a feature with a running dev server and half-edited files.
An urgent hotfix arrives. Stashing, switching, rebuilding, then switching back
is slow and risky. A **worktree** gives you a second folder with another branch
checked out, sharing the same repository. Fix the bug there; your feature
folder is untouched.

## Mental model: two desks, one filing cabinet

One `.git` database (the filing cabinet), several working directories (desks),
each with its own branch, index and files. Commits made at any desk land in the
same cabinet, so every desk sees them immediately. No second clone, no second
download.

```
 ~/work/shop          (main worktree)     branch feature/coupons
 ~/work/shop-hotfix   (linked worktree)   branch hotfix/price
        \_______________ share _______________/
                     ~/work/shop/.git
```

## See it work

### Add a worktree

```bash
cd ~/work/shop
git worktree add ../shop-hotfix -b hotfix/price main
git worktree list
```

What this does: creates folder `../shop-hotfix`, creates branch
`hotfix/price` from `main`, and checks it out there. Expected output:

```
Preparing worktree (new branch 'hotfix/price')
HEAD is now at c46b46c Add checkout
/home/labuser/work/shop         c46b46c [feature/coupons]
/home/labuser/work/shop-hotfix  c46b46c [hotfix/price]
```

### Work in it

```bash
cd ../shop-hotfix
# fix, test, commit as usual
git commit -am "Fix price rounding"
git push -u origin hotfix/price
cd ../shop
git log --oneline hotfix/price -1      # the commit is visible here too
```

### Clean up

```bash
git worktree remove ../shop-hotfix     # deletes the folder (refuses if it has uncommitted changes)
git worktree prune                      # forget worktrees whose folders you deleted by hand
```

The branch `hotfix/price` stays; only the extra folder goes.

### The one rule

A branch can be checked out in **only one** worktree at a time:

```
fatal: 'main' is already used by worktree at '/home/labuser/work/shop'
```

That prevents two folders from moving the same branch in different directions.
Use `--detach` if you just want to look at a commit.

### Good uses

- Hotfix or review a PR without disturbing current work.
- Run a long test suite on one branch while coding on another.
- Compare behaviour of two versions side by side.
- Give each AI coding agent or script its own isolated checkout.

## Try it

You want to review a colleague's branch `feature/search` (already fetched) in a
separate folder without creating a new local branch name. What command?

<details>
<summary>Show answer</summary>

```bash
git worktree add ../review-search feature/search
```

If a local `feature/search` does not exist yet, Git creates it tracking
`origin/feature/search` (like `git switch`). Use
`git worktree add --detach ../review origin/feature/search` to avoid a local
branch entirely.

</details>

## Common mistakes

- **Deleting the folder with `rm -rf` and forgetting.** Git still thinks the
  branch is checked out there; run `git worktree prune`.
- **Cloning the repo twice instead.** Two clones double disk use and do not see
  each other's commits without fetching.
- **Creating a worktree inside the main working tree.** Put it next to it
  (`../name`) so the main tree does not see it as untracked files.

## Remember

- `git worktree add <path> -b <new-branch> <start>` = new folder + branch.
- All worktrees share one `.git`: commits are visible everywhere at once.
- One branch per worktree at a time.
- `git worktree list`, `remove`, `prune` to manage.

**Self-check:**

1. What is shared between worktrees, and what is separate?
2. Why can't `main` be checked out in two worktrees?
3. What does `git worktree prune` clean up?
$md$, 7, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8155f7ed-47e1-5f8d-9c55-e2131a82b967', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'b2ad8505-d4d2-5871-a812-03fb6c8db169', 'Submodules (and Subtrees): Repositories Inside Repositories', 'notes', 1, $md$## Why this matters

Your app uses a shared UI library that lives in its own repository and is
versioned separately. You want a **specific version** of it inside your
project. Submodules do that, and they confuse almost everyone the first time
("why is the folder empty?"). Know how they work, and when to avoid them.

## Mental model: a bookmark to an exact page of another book

A submodule does not copy the other repo's files into your history. Your repo
stores only:

1. `.gitmodules` - where to get the other repo (path -> URL).
2. A **gitlink** in your tree - the exact commit hash of the other repo to use
   (mode `160000`).

```
 app repo tree
 |-- src/...
 |-- .gitmodules          path = vendor/ui-lib, url = .../ui-lib.git
 '-- vendor/ui-lib  ->  gitlink 9357447   (a commit in ANOTHER repository)
```

Updating the library in your app = committing a new gitlink hash. Nothing moves
automatically.

## See it work

### Add a submodule

```bash
git submodule add https://example.com/ui-lib.git vendor/ui-lib
git status -s
git commit -m "Add ui-lib submodule"
```

Expected `git status -s` before the commit:

```
A  .gitmodules
A  vendor/ui-lib
```

`git ls-files -s vendor/ui-lib` shows the gitlink:

```
160000 9357447dd34cbf4e244315e5209746b122367380 0	vendor/ui-lib
```

**Local-path gotcha (Git 2.38.1+):** submodules from local paths or `file://`
URLs are blocked by default for security:

```
fatal: transport 'file' not allowed
```

For a trusted local repo, allow it for that one command:
`git -c protocol.file.allow=always submodule add /path/to/lib.git vendor/ui-lib`.

### Clone a project that has submodules

```bash
git clone --recurse-submodules <url>
# already cloned without it? the folder is empty, so:
git submodule update --init --recursive
```

### Update the library version

```bash
cd vendor/ui-lib
git fetch && git switch --detach v2.3.0     # pick the version you want
cd ../..
git add vendor/ui-lib                       # record the new gitlink
git commit -m "Bump ui-lib to v2.3.0"
```

Or `git submodule update --remote vendor/ui-lib` to move to the latest commit of
the branch configured in `.gitmodules`, then commit.

After teammates pull your bump they run `git submodule update` (or set
`git config --global submodule.recurse true` so pull/switch do it).

### Remove a submodule

```bash
git rm vendor/ui-lib          # removes gitlink, folder and .gitmodules entry
git commit -m "Remove ui-lib submodule"
```

### Alternatives

| Need | Consider |
|---|---|
| Vendored code you rarely update, want plain files in history | `git subtree` (copies the code into your repo) |
| Language libraries | The package manager (npm, pip, Go modules, Maven) |
| Many related projects, atomic changes across them | One monorepo |

## Try it

A new teammate cloned the app and `vendor/ui-lib` is an empty folder; the build
fails. What happened and what is the fix?

<details>
<summary>Show answer</summary>

A plain clone does not fetch submodule contents. Run:

```bash
git submodule update --init --recursive
```

Next time: `git clone --recurse-submodules`.

</details>

## Common mistakes

- **Committing inside the submodule and forgetting to commit the gitlink in the
  parent.** Teammates never get your library change.
- **Pushing the parent before the submodule's commit.** Others get a gitlink to
  a commit that does not exist on the server. Push the submodule first (or
  `git push --recurse-submodules=check`).
- **Being surprised by detached HEAD inside the submodule.** That is normal: the
  parent pins a commit, not a branch.

## Remember

- A submodule = `.gitmodules` URL + a gitlink commit hash (mode 160000).
- Clone with `--recurse-submodules` or run `git submodule update --init --recursive`.
- Bump a version: change the submodule's checkout, `git add` it in the parent, commit.
- Local/file URLs need `protocol.file.allow=always` on modern Git.

**Self-check:**

1. What does the parent repo actually store for a submodule?
2. Why is a freshly cloned submodule folder empty?
3. What must be pushed first: the submodule commit or the parent?
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('c3c96639-7da2-5670-a5d4-ff195ed6f239', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'b2ad8505-d4d2-5871-a812-03fb6c8db169', 'Working with Huge Repositories and Large Files', 'notes', 2, $md$## Why this matters

A monorepo with 10 years of history, 300,000 files and some 200 MB design
assets can take an hour to clone and seconds for every `git status`. CI clones
it hundreds of times a day. A few built-in features make huge repositories
fast, and one extension (Git LFS) keeps big binaries out of history.

## Mental model: download less, look at less, keep it tidy

| Problem | Fix | Idea |
|---|---|---|
| Too much **history** | Shallow clone | Only the last N commits |
| Too many **file versions** | Partial clone | Fetch file contents on demand |
| Too many **files on disk** | Sparse checkout | Only the folders you work on |
| Slow commands over time | Background maintenance | Keep packs and indexes fresh |
| Big **binaries** | Git LFS | Store pointers in Git, files elsewhere |

## See it work

### Shallow clone (CI favourite)

```bash
git clone --depth 1 https://example.com/big.git
git rev-parse --is-shallow-repository      # true
```

Fast, but `log`, `blame` and `bisect` only see what you downloaded. Get more
later with `git fetch --deepen=100` or `git fetch --unshallow`.

Gotcha: from a **local path** `--depth` is ignored:

```
warning: --depth is ignored in local clones; use file:// instead.
```

Use `git clone --depth 1 file:///srv/big.git` instead.

### Partial clone (best for developers)

```bash
git clone --filter=blob:none https://example.com/big.git
```

What this does: downloads all commits and trees but **no file contents**
except those needed for the checkout; older versions are fetched on demand when
you look at them. Full history for `log`, much smaller download. Use
`--filter=tree:0` for CI that needs only the current files plus commits.

### Sparse checkout

```bash
git sparse-checkout set services/payments libs/common
git sparse-checkout list
git sparse-checkout disable          # back to everything
```

What this does: only those folders (plus files at the root) appear in your
working tree. `git status` and builds get faster because there are fewer files.
Combine with partial clone:
`git clone --filter=blob:none --sparse <url>`.

### Keep it fast

```bash
git maintenance start        # schedules background tasks: prefetch, commit-graph, loose objects, incremental repack
git config core.fsmonitor true   # (where supported) a daemon watches files so status need not scan everything
```

`scalar clone <url>` (shipped with Git since 2.38) sets up partial clone,
sparse checkout and maintenance in one command for very large repos.

### Large binary files: Git LFS

Every version of every committed file stays in history forever. Ten versions of
a 200 MB video = 2 GB that **every** clone downloads.

```bash
git lfs install                    # once per machine
git lfs track "*.psd" "*.mp4"      # writes rules into .gitattributes
git add .gitattributes design.psd
git commit -m "Track design files with LFS"
```

Git stores a tiny pointer file; the real file lives on the LFS server and is
downloaded only for the version you check out. Hosts often reject plain-Git
files over 100 MB, so set LFS up **before** the first big file is committed.

Moving existing big files into LFS rewrites history (`git lfs migrate import`),
with the same team coordination as any rewrite.

## Try it

CI takes 9 minutes just to clone the monorepo, and the build only needs the
latest files. Which two clone options would you try?

<details>
<summary>Show answer</summary>

`--depth 1` (shallow: only the latest commit) and, if the build touches only
some folders, `--filter=blob:none --sparse` plus `git sparse-checkout set
<folders>`. Many CI systems expose these as "fetch depth" and "sparse checkout"
settings.

</details>

## Common mistakes

- **Shallow clones for developers.** Blame, log and bisect break in confusing
  ways. Prefer partial clone (`--filter=blob:none`).
- **Adding LFS after the fact.** The big files are already in history; only a
  rewrite removes them.
- **Committing generated files** (builds, `node_modules`, datasets). Ignore and
  regenerate them instead.

## Remember

- Shallow (`--depth`) = less history; partial (`--filter=blob:none`) = contents on demand.
- `git sparse-checkout set <dirs>` = fewer files on disk.
- `git maintenance start` / `scalar` keep huge repos fast.
- Big binaries go in Git LFS from day one.

**Self-check:**

1. What does a partial clone skip downloading?
2. Why should developers prefer partial over shallow clones?
3. What does Git store in the repo for an LFS-tracked file?
$md$, 9, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('cc041893-9627-556a-aacc-8628ed11567e', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'b2ad8505-d4d2-5871-a812-03fb6c8db169', 'Lab: Hotfix in a Worktree, Add a Submodule, Shallow-Clone', 'notes', 3, $md$## Why this matters

These three tools solve problems you will meet on bigger teams: an urgent fix
while your work is half done (worktree), a shared library pinned to a version
(submodule), and a slow clone (shallow). The repositories are ready under
`~/work/shop` and `~/srv/git`.

```bash
cd ~/work/shop
git status -s
```

Expected:

```
 M coupons.txt
```

That is your half-finished work. Leave it alone throughout this lab.

## Task 1: open a hotfix worktree

Add `~/work/shop-hotfix` with a new branch `hotfix/price` from `main`.

[[lab-task:1]]

Expected `git worktree list`:

```
/home/labuser/work/shop         1b2c3d4 [feature/coupons]
/home/labuser/work/shop-hotfix  5e6f7a8 [hotfix/price]
```

## Task 2: fix the price there

In `~/work/shop-hotfix`, set `price.txt` to `price=9.99` and commit
`Fix price rounding`.

[[lab-task:2]]

Check from the main folder: `git log --oneline -1 hotfix/price`.

## Task 3: remove the worktree

[[lab-task:3]]

## Task 4: add the UI library as a submodule

Add `/home/labuser/srv/git/ui-lib.git` at `vendor/ui-lib` and commit only the
submodule. Try it first without the `-c` option to see the security error:

```
fatal: transport 'file' not allowed
```

[[lab-task:4]]

Check: `git ls-tree HEAD vendor/ui-lib` shows mode `160000` and type `commit`.

## Task 5: shallow clone

Clone `big.git` into `~/work/big-shallow` with depth 1. Try a plain path first
and read the warning.

[[lab-task:5]]

Expected: `git -C ~/work/big-shallow log --oneline` prints a single commit.

## Remember

- Worktrees: parallel checkouts sharing one repository.
- Submodules pin another repo's exact commit; local paths need `protocol.file.allow`.
- Shallow clones need a real transfer (`file://` locally, or a server URL).
$md$, 30, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('a8a427b3-a034-57da-a92b-640dd62d39c4', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'cc041893-9627-556a-aacc-8628ed11567e', 'module', 'Lab: Hotfix in a Worktree, Add a Submodule, Shallow-Clone', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
w=/home/labuser/work; s=/home/labuser/srv/git
rm -rf $w/shop $w/shop-hotfix $w/big-shallow $s/ui-lib.git $s/big.git /tmp/seed
mkdir -p $s
M() { git add -A; GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
git init -q /tmp/seed && cd /tmp/seed
echo "button v1" > button.css; M 2024-10-01 "UI lib v1"
echo "button v2" > button.css; M 2024-10-02 "UI lib v2"
git init -q --bare $s/ui-lib.git && git push -q $s/ui-lib.git main
git --git-dir=$s/ui-lib.git symbolic-ref HEAD refs/heads/main
cd / && rm -rf /tmp/seed && git init -q /tmp/seed && cd /tmp/seed
for i in 1 2 3 4 5; do echo "data $i" > data.txt; M 2024-10-0$i "Big repo commit $i"; done
git init -q --bare $s/big.git && git push -q $s/big.git main
git --git-dir=$s/big.git symbolic-ref HEAD refs/heads/main
cd / && rm -rf /tmp/seed
mkdir -p $w/shop && cd $w/shop && git init -q
echo "# Shop" > README.md; echo "price=9.9" > price.txt; M 2024-10-01 "Initial shop"
echo "checkout" > checkout.txt; M 2024-10-02 "Add checkout"
git switch -q -c feature/coupons
echo "coupons draft" > coupons.txt; M 2024-10-03 "Start coupons"
echo "half-finished coupon rules" >> coupons.txt
$script$, NULL, 40, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '110b039d-543c-58b9-a63d-03481d85a1bf' AND id NOT IN ('4f275e42-9a6e-54f3-8990-d6d120da02dd', '477de946-c9a3-5a1d-b6f7-2f627c892f37', 'cfac4237-dcfc-5625-a4cf-5a1d9c543d9e', '1855a5d1-e0a3-5e6e-85dd-111340797584', 'a0eb2434-2d33-5d78-8d45-0dd4d6f762b6');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '110b039d-543c-58b9-a63d-03481d85a1bf';
DELETE FROM lab_tasks WHERE lab_id = 'a8a427b3-a034-57da-a92b-640dd62d39c4' AND id NOT IN ('253d5249-1a7a-50a0-bde2-27a18e1682a0', 'f798f7d8-1ed7-5369-8fdb-9fc63ea20dd1', '28f6a0ce-cb70-5ca6-adf1-efc66e179d59', 'c7e9194f-1198-519c-b609-77be19936abb', '20763610-aa00-5259-8f25-58655e57ea12');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'a8a427b3-a034-57da-a92b-640dd62d39c4';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('253d5249-1a7a-50a0-bde2-27a18e1682a0', 'a8a427b3-a034-57da-a92b-640dd62d39c4', 1, 'Open a hotfix worktree', $md$You are on feature/coupons in ~/work/shop with uncommitted work. Without touching it, add a worktree at ~/work/shop-hotfix with a new branch hotfix/price created from main.$md$, $script$r=/home/labuser/work/shop
l=$(git -C $r worktree list --porcelain)
echo "$l" | grep -qx 'worktree /home/labuser/work/shop-hotfix' &&
echo "$l" | grep -qx 'branch refs/heads/hotfix/price' &&
[ "$(git -C /home/labuser/work/shop-hotfix rev-parse HEAD)" = "$(git -C $r rev-parse main)" ] &&
! git -C $r diff --quiet -- coupons.txt
$script$, 'From inside ~/work/shop run git worktree add ../shop-hotfix -b hotfix/price main. Your half-finished coupons.txt edit stays where it is.', 'A linked worktree is a second working directory that shares the same .git database, with its own branch, index and files.', 15, false, true),
('f798f7d8-1ed7-5369-8fdb-9fc63ea20dd1', 'a8a427b3-a034-57da-a92b-640dd62d39c4', 2, 'Commit the hotfix in the worktree', $md$In ~/work/shop-hotfix change price.txt to the single line "price=9.99" and commit it with the message "Fix price rounding". Your feature work in ~/work/shop must stay uncommitted and untouched.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r log -1 --format=%s hotfix/price)" = "Fix price rounding" ] &&
[ "$(git -C $r show hotfix/price:price.txt)" = "price=9.99" ] &&
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = feature/coupons ] &&
grep -qx 'half-finished coupon rules' $r/coupons.txt
$script$, 'cd ~/work/shop-hotfix, edit the file, git commit -am "Fix price rounding". Then git log --oneline hotfix/price from ~/work/shop shows the same commit.', 'Both folders share one object database and one set of refs, so the hotfix commit is instantly visible from the main worktree.', 15, false, true),
('28f6a0ce-cb70-5ca6-adf1-efc66e179d59', 'a8a427b3-a034-57da-a92b-640dd62d39c4', 3, 'Remove the worktree, keep the branch', $md$The hotfix is committed. Remove the ~/work/shop-hotfix worktree with git worktree remove. The branch hotfix/price must still exist.$md$, $script$r=/home/labuser/work/shop
[ ! -d /home/labuser/work/shop-hotfix ] &&
[ "$(git -C $r worktree list --porcelain | grep -c '^worktree ')" = 1 ] &&
git -C $r rev-parse -q --verify hotfix/price >/dev/null
$script$, 'Run git worktree remove ../shop-hotfix from ~/work/shop (not from inside the folder you are removing).', 'remove deletes the folder and Git''s bookkeeping for it. Branches and commits live in the shared repository and are not affected.', 10, false, true),
('c7e9194f-1198-519c-b609-77be19936abb', 'a8a427b3-a034-57da-a92b-640dd62d39c4', 4, 'Add a submodule', $md$In ~/work/shop add the UI library /home/labuser/srv/git/ui-lib.git as a submodule at vendor/ui-lib, and commit only the submodule (.gitmodules and vendor/ui-lib) with the message "Add ui-lib submodule". Local-path submodules are blocked by default; allow the file transport for that one command.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r log -1 --format=%s)" = "Add ui-lib submodule" ] &&
[ "$(git -C $r ls-tree HEAD vendor/ui-lib | cut -d' ' -f1-2)" = "160000 commit" ] &&
[ "$(git -C $r ls-tree HEAD vendor/ui-lib | cut -f1 | cut -d' ' -f3)" = "$(git --git-dir=/home/labuser/srv/git/ui-lib.git rev-parse main)" ] &&
git -C $r show HEAD:.gitmodules | grep -q 'url = /home/labuser/srv/git/ui-lib.git'
$script$, 'git -c protocol.file.allow=always submodule add /home/labuser/srv/git/ui-lib.git vendor/ui-lib stages both paths; then git commit -m "Add ui-lib submodule" (do not git add -A, or your half-finished coupons edit goes in too).', 'The parent repo stores .gitmodules (path and URL) and a gitlink (mode 160000) pinning one exact commit of the library. Since Git 2.38.1 the file transport is disabled for submodules unless explicitly allowed.', 20, false, true),
('20763610-aa00-5259-8f25-58655e57ea12', 'a8a427b3-a034-57da-a92b-640dd62d39c4', 5, 'Make a shallow clone', $md$Clone /home/labuser/srv/git/big.git into ~/work/big-shallow with only the latest commit (depth 1). Note that --depth is ignored for plain local paths.$md$, $script$r=/home/labuser/work/big-shallow
[ "$(git -C $r rev-parse --is-shallow-repository 2>/dev/null)" = true ] &&
[ "$(git -C $r rev-list --count HEAD)" = 1 ] &&
[ "$(git -C $r log -1 --format=%s)" = "Big repo commit 5" ]
$script$, 'git clone --depth 1 /home/labuser/srv/git/big.git prints "warning: --depth is ignored in local clones". Use a file:// URL: git clone --depth 1 file:///home/labuser/srv/git/big.git ~/work/big-shallow.', 'Shallow clones download only the newest commits. For a local path Git normally hard-links the whole object store instead of transferring, so it ignores --depth; the file:// URL forces a real transfer that honours it.', 15, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('110b039d-543c-58b9-a63d-03481d85a1bf', 'a8a427b3-a034-57da-a92b-640dd62d39c4', 1, $json$[{"id":"253d5249-1a7a-50a0-bde2-27a18e1682a0","lab_id":"a8a427b3-a034-57da-a92b-640dd62d39c4","position":1,"title":"Open a hotfix worktree","description":"You are on feature/coupons in ~/work/shop with uncommitted work. Without touching it, add a worktree at ~/work/shop-hotfix with a new branch hotfix/price created from main.","verification_script":"r=/home/labuser/work/shop\nl=$(git -C $r worktree list --porcelain)\necho \"$l\" | grep -qx 'worktree /home/labuser/work/shop-hotfix' \u0026\u0026\necho \"$l\" | grep -qx 'branch refs/heads/hotfix/price' \u0026\u0026\n[ \"$(git -C /home/labuser/work/shop-hotfix rev-parse HEAD)\" = \"$(git -C $r rev-parse main)\" ] \u0026\u0026\n! git -C $r diff --quiet -- coupons.txt\n","hint_context":"From inside ~/work/shop run git worktree add ../shop-hotfix -b hotfix/price main. Your half-finished coupons.txt edit stays where it is.","explanation_context":"A linked worktree is a second working directory that shares the same .git database, with its own branch, index and files.","points":15,"is_optional":false,"is_stateful":true},{"id":"f798f7d8-1ed7-5369-8fdb-9fc63ea20dd1","lab_id":"a8a427b3-a034-57da-a92b-640dd62d39c4","position":2,"title":"Commit the hotfix in the worktree","description":"In ~/work/shop-hotfix change price.txt to the single line \"price=9.99\" and commit it with the message \"Fix price rounding\". Your feature work in ~/work/shop must stay uncommitted and untouched.","verification_script":"r=/home/labuser/work/shop\n[ \"$(git -C $r log -1 --format=%s hotfix/price)\" = \"Fix price rounding\" ] \u0026\u0026\n[ \"$(git -C $r show hotfix/price:price.txt)\" = \"price=9.99\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse --abbrev-ref HEAD)\" = feature/coupons ] \u0026\u0026\ngrep -qx 'half-finished coupon rules' $r/coupons.txt\n","hint_context":"cd ~/work/shop-hotfix, edit the file, git commit -am \"Fix price rounding\". Then git log --oneline hotfix/price from ~/work/shop shows the same commit.","explanation_context":"Both folders share one object database and one set of refs, so the hotfix commit is instantly visible from the main worktree.","points":15,"is_optional":false,"is_stateful":true},{"id":"28f6a0ce-cb70-5ca6-adf1-efc66e179d59","lab_id":"a8a427b3-a034-57da-a92b-640dd62d39c4","position":3,"title":"Remove the worktree, keep the branch","description":"The hotfix is committed. Remove the ~/work/shop-hotfix worktree with git worktree remove. The branch hotfix/price must still exist.","verification_script":"r=/home/labuser/work/shop\n[ ! -d /home/labuser/work/shop-hotfix ] \u0026\u0026\n[ \"$(git -C $r worktree list --porcelain | grep -c '^worktree ')\" = 1 ] \u0026\u0026\ngit -C $r rev-parse -q --verify hotfix/price \u003e/dev/null\n","hint_context":"Run git worktree remove ../shop-hotfix from ~/work/shop (not from inside the folder you are removing).","explanation_context":"remove deletes the folder and Git's bookkeeping for it. Branches and commits live in the shared repository and are not affected.","points":10,"is_optional":false,"is_stateful":true},{"id":"c7e9194f-1198-519c-b609-77be19936abb","lab_id":"a8a427b3-a034-57da-a92b-640dd62d39c4","position":4,"title":"Add a submodule","description":"In ~/work/shop add the UI library /home/labuser/srv/git/ui-lib.git as a submodule at vendor/ui-lib, and commit only the submodule (.gitmodules and vendor/ui-lib) with the message \"Add ui-lib submodule\". Local-path submodules are blocked by default; allow the file transport for that one command.","verification_script":"r=/home/labuser/work/shop\n[ \"$(git -C $r log -1 --format=%s)\" = \"Add ui-lib submodule\" ] \u0026\u0026\n[ \"$(git -C $r ls-tree HEAD vendor/ui-lib | cut -d' ' -f1-2)\" = \"160000 commit\" ] \u0026\u0026\n[ \"$(git -C $r ls-tree HEAD vendor/ui-lib | cut -f1 | cut -d' ' -f3)\" = \"$(git --git-dir=/home/labuser/srv/git/ui-lib.git rev-parse main)\" ] \u0026\u0026\ngit -C $r show HEAD:.gitmodules | grep -q 'url = /home/labuser/srv/git/ui-lib.git'\n","hint_context":"git -c protocol.file.allow=always submodule add /home/labuser/srv/git/ui-lib.git vendor/ui-lib stages both paths; then git commit -m \"Add ui-lib submodule\" (do not git add -A, or your half-finished coupons edit goes in too).","explanation_context":"The parent repo stores .gitmodules (path and URL) and a gitlink (mode 160000) pinning one exact commit of the library. Since Git 2.38.1 the file transport is disabled for submodules unless explicitly allowed.","points":20,"is_optional":false,"is_stateful":true},{"id":"20763610-aa00-5259-8f25-58655e57ea12","lab_id":"a8a427b3-a034-57da-a92b-640dd62d39c4","position":5,"title":"Make a shallow clone","description":"Clone /home/labuser/srv/git/big.git into ~/work/big-shallow with only the latest commit (depth 1). Note that --depth is ignored for plain local paths.","verification_script":"r=/home/labuser/work/big-shallow\n[ \"$(git -C $r rev-parse --is-shallow-repository 2\u003e/dev/null)\" = true ] \u0026\u0026\n[ \"$(git -C $r rev-list --count HEAD)\" = 1 ] \u0026\u0026\n[ \"$(git -C $r log -1 --format=%s)\" = \"Big repo commit 5\" ]\n","hint_context":"git clone --depth 1 /home/labuser/srv/git/big.git prints \"warning: --depth is ignored in local clones\". Use a file:// URL: git clone --depth 1 file:///home/labuser/srv/git/big.git ~/work/big-shallow.","explanation_context":"Shallow clones download only the newest commits. For a local path Git normally hard-links the whole object store instead of transferring, so it ignores --depth; the file:// URL forces a real transfer that honours it.","points":15,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4f275e42-9a6e-54f3-8990-d6d120da02dd', '110b039d-543c-58b9-a63d-03481d85a1bf', '253d5249-1a7a-50a0-bde2-27a18e1682a0', 1, 'Open a hotfix worktree', $md$You are on feature/coupons in ~/work/shop with uncommitted work. Without touching it, add a worktree at ~/work/shop-hotfix with a new branch hotfix/price created from main.$md$, $script$r=/home/labuser/work/shop
l=$(git -C $r worktree list --porcelain)
echo "$l" | grep -qx 'worktree /home/labuser/work/shop-hotfix' &&
echo "$l" | grep -qx 'branch refs/heads/hotfix/price' &&
[ "$(git -C /home/labuser/work/shop-hotfix rev-parse HEAD)" = "$(git -C $r rev-parse main)" ] &&
! git -C $r diff --quiet -- coupons.txt
$script$, 'From inside ~/work/shop run git worktree add ../shop-hotfix -b hotfix/price main. Your half-finished coupons.txt edit stays where it is.', 'A linked worktree is a second working directory that shares the same .git database, with its own branch, index and files.', 15, false, true),
('477de946-c9a3-5a1d-b6f7-2f627c892f37', '110b039d-543c-58b9-a63d-03481d85a1bf', 'f798f7d8-1ed7-5369-8fdb-9fc63ea20dd1', 2, 'Commit the hotfix in the worktree', $md$In ~/work/shop-hotfix change price.txt to the single line "price=9.99" and commit it with the message "Fix price rounding". Your feature work in ~/work/shop must stay uncommitted and untouched.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r log -1 --format=%s hotfix/price)" = "Fix price rounding" ] &&
[ "$(git -C $r show hotfix/price:price.txt)" = "price=9.99" ] &&
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = feature/coupons ] &&
grep -qx 'half-finished coupon rules' $r/coupons.txt
$script$, 'cd ~/work/shop-hotfix, edit the file, git commit -am "Fix price rounding". Then git log --oneline hotfix/price from ~/work/shop shows the same commit.', 'Both folders share one object database and one set of refs, so the hotfix commit is instantly visible from the main worktree.', 15, false, true),
('cfac4237-dcfc-5625-a4cf-5a1d9c543d9e', '110b039d-543c-58b9-a63d-03481d85a1bf', '28f6a0ce-cb70-5ca6-adf1-efc66e179d59', 3, 'Remove the worktree, keep the branch', $md$The hotfix is committed. Remove the ~/work/shop-hotfix worktree with git worktree remove. The branch hotfix/price must still exist.$md$, $script$r=/home/labuser/work/shop
[ ! -d /home/labuser/work/shop-hotfix ] &&
[ "$(git -C $r worktree list --porcelain | grep -c '^worktree ')" = 1 ] &&
git -C $r rev-parse -q --verify hotfix/price >/dev/null
$script$, 'Run git worktree remove ../shop-hotfix from ~/work/shop (not from inside the folder you are removing).', 'remove deletes the folder and Git''s bookkeeping for it. Branches and commits live in the shared repository and are not affected.', 10, false, true),
('1855a5d1-e0a3-5e6e-85dd-111340797584', '110b039d-543c-58b9-a63d-03481d85a1bf', 'c7e9194f-1198-519c-b609-77be19936abb', 4, 'Add a submodule', $md$In ~/work/shop add the UI library /home/labuser/srv/git/ui-lib.git as a submodule at vendor/ui-lib, and commit only the submodule (.gitmodules and vendor/ui-lib) with the message "Add ui-lib submodule". Local-path submodules are blocked by default; allow the file transport for that one command.$md$, $script$r=/home/labuser/work/shop
[ "$(git -C $r log -1 --format=%s)" = "Add ui-lib submodule" ] &&
[ "$(git -C $r ls-tree HEAD vendor/ui-lib | cut -d' ' -f1-2)" = "160000 commit" ] &&
[ "$(git -C $r ls-tree HEAD vendor/ui-lib | cut -f1 | cut -d' ' -f3)" = "$(git --git-dir=/home/labuser/srv/git/ui-lib.git rev-parse main)" ] &&
git -C $r show HEAD:.gitmodules | grep -q 'url = /home/labuser/srv/git/ui-lib.git'
$script$, 'git -c protocol.file.allow=always submodule add /home/labuser/srv/git/ui-lib.git vendor/ui-lib stages both paths; then git commit -m "Add ui-lib submodule" (do not git add -A, or your half-finished coupons edit goes in too).', 'The parent repo stores .gitmodules (path and URL) and a gitlink (mode 160000) pinning one exact commit of the library. Since Git 2.38.1 the file transport is disabled for submodules unless explicitly allowed.', 20, false, true),
('a0eb2434-2d33-5d78-8d45-0dd4d6f762b6', '110b039d-543c-58b9-a63d-03481d85a1bf', '20763610-aa00-5259-8f25-58655e57ea12', 5, 'Make a shallow clone', $md$Clone /home/labuser/srv/git/big.git into ~/work/big-shallow with only the latest commit (depth 1). Note that --depth is ignored for plain local paths.$md$, $script$r=/home/labuser/work/big-shallow
[ "$(git -C $r rev-parse --is-shallow-repository 2>/dev/null)" = true ] &&
[ "$(git -C $r rev-list --count HEAD)" = 1 ] &&
[ "$(git -C $r log -1 --format=%s)" = "Big repo commit 5" ]
$script$, 'git clone --depth 1 /home/labuser/srv/git/big.git prints "warning: --depth is ignored in local clones". Use a file:// URL: git clone --depth 1 file:///home/labuser/srv/git/big.git ~/work/big-shallow.', 'Shallow clones download only the newest commits. For a local path Git normally hard-links the whole object store instead of transferring, so it ignores --depth; the file:// URL forces a real transfer that honours it.', 15, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '110b039d-543c-58b9-a63d-03481d85a1bf', updated_at = now()
WHERE id = 'a8a427b3-a034-57da-a92b-640dd62d39c4' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ec967e7d-1257-5581-9302-5d92a15b9a41', '00000000-0000-0000-0000-000000000001', 'mcq', 'You are mid-feature with a running dev server and uncommitted edits. A produc...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f5935a1d-9ea0-5a20-8276-3958de25132d', 'ec967e7d-1257-5581-9302-5d92a15b9a41', 1, $json${"prompt":"You are mid-feature with a running dev server and uncommitted edits. A production fix must ship now. What is the least disruptive approach?","multiple":false,"options":[{"id":"a","text":"git stash, switch to main, fix, switch back, git stash pop","is_correct":false},{"id":"b","text":"git worktree add ../hotfix -b hotfix/x main and fix it in that folder","is_correct":true},{"id":"c","text":"Commit your half-finished work to main","is_correct":false},{"id":"d","text":"Clone the repository again from the server","is_correct":false}],"explanation":"A worktree gives a second checkout sharing the same repository, so your feature folder, files and server stay untouched. Stashing works but disrupts the running setup, committing WIP to main is wrong, and a second clone wastes disk and does not share commits."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b52d3162-e09d-550f-b706-e7edcdec30ca', '00000000-0000-0000-0000-000000000001', 'mcq', '`git worktree add ../review main` fails with "''main'' is already used by workt...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('39b19917-abaa-502a-9dc0-1b5a23c2c738', 'b52d3162-e09d-550f-b706-e7edcdec30ca', 1, $json${"prompt":"`git worktree add ../review main` fails with \"'main' is already used by worktree\". Why?","multiple":false,"options":[{"id":"a","text":"Worktrees cannot use main at all","is_correct":false},{"id":"b","text":"A branch can be checked out in only one worktree at a time, and main is checked out in your primary folder","is_correct":true},{"id":"c","text":"The folder ../review already exists","is_correct":false},{"id":"d","text":"You must fetch first","is_correct":false}],"explanation":"Git prevents two working trees from moving the same branch. Use another branch or --detach. main is allowed in a worktree if no other worktree has it; the folder and fetch state are not the issue here."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a7c35db8-ded7-5091-9286-a7f708521ad1', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does a parent repository store for a submodule at vendor/ui-lib?', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('da4f5a23-563a-5db8-af52-0c60dcab6fca', 'a7c35db8-ded7-5091-9286-a7f708521ad1', 1, $json${"prompt":"What does a parent repository store for a submodule at vendor/ui-lib?","multiple":false,"options":[{"id":"a","text":"A full copy of the library's files and history","is_correct":false},{"id":"b","text":"The library's URL in .gitmodules and a gitlink: the exact commit hash of the library to use","is_correct":true},{"id":"c","text":"Only the URL; the latest commit is always used","is_correct":false},{"id":"d","text":"A symlink to another folder","is_correct":false}],"explanation":"Submodules pin an exact commit (tree entry mode 160000). Files and history live in the library's own repository, nothing floats to 'latest' automatically, and no symlink is involved."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('38f6bcbe-6783-5b8e-b1a0-7e3c4973b8b4', '00000000-0000-0000-0000-000000000001', 'mcq', '`git submodule add /srv/libs/ui.git vendor/ui` fails with "fatal: transport ''...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e44d2d24-d0f7-52c3-ba7c-33cd644dda2e', '38f6bcbe-6783-5b8e-b1a0-7e3c4973b8b4', 1, $json${"prompt":"`git submodule add /srv/libs/ui.git vendor/ui` fails with \"fatal: transport 'file' not allowed\". What is going on?","multiple":false,"options":[{"id":"a","text":"The path is wrong","is_correct":false},{"id":"b","text":"Since Git 2.38.1, submodules from local or file:// URLs are blocked by default for security; allow it for a trusted repo with -c protocol.file.allow=always","is_correct":true},{"id":"c","text":"Submodules require SSH","is_correct":false},{"id":"d","text":"You need to run git init in vendor/ui first","is_correct":false}],"explanation":"A security fix disabled the file transport for submodules by default. A wrong path gives a different 'not a git repository' error, HTTPS and SSH both work, and git init in the target is not needed."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e2669cb5-124a-5c4b-9e68-42a631ba6544', '00000000-0000-0000-0000-000000000001', 'mcq', 'Developers on a 15 GB monorepo want fast clones but still need full `git log`...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9bfc07dd-f011-5ca0-bab5-83090e67ab33', 'e2669cb5-124a-5c4b-9e68-42a631ba6544', 1, $json${"prompt":"Developers on a 15 GB monorepo want fast clones but still need full `git log` and `git blame`. Which option fits best?","multiple":false,"options":[{"id":"a","text":"git clone --depth 1","is_correct":false},{"id":"b","text":"git clone --filter=blob:none (partial clone)","is_correct":true},{"id":"c","text":"Download a zip of the repository","is_correct":false},{"id":"d","text":"git clone --bare","is_correct":false}],"explanation":"Partial clone downloads all commits and trees, fetching file contents on demand, so history commands still work. A shallow clone cuts history (log/blame/bisect break), a zip has no history at all, and --bare has no working tree to develop in."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5eb73739-a8e1-5463-8776-2b002a70c026', '00000000-0000-0000-0000-000000000001', 'mcq', 'A designer wants to commit 300 MB Photoshop files that change weekly. What sh...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('74546516-f757-5658-8ccd-f2afd7643d1f', '5eb73739-a8e1-5463-8776-2b002a70c026', 1, $json${"prompt":"A designer wants to commit 300 MB Photoshop files that change weekly. What should the team do first?","multiple":false,"options":[{"id":"a","text":"Commit them normally; Git compresses everything","is_correct":false},{"id":"b","text":"Set up Git LFS (git lfs track '*.psd') before the first commit of those files","is_correct":true},{"id":"c","text":"Put them in .gitignore and email them","is_correct":false},{"id":"d","text":"Use a shallow clone","is_correct":false}],"explanation":"Every version of a committed binary stays in history and every clone downloads it; binaries also compress poorly. LFS stores pointers in Git and the files on an LFS server. Emailing loses versioning, and shallow clones do not stop the history from growing."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6b1d1e44-b9e7-557d-b370-a7d214310a8a', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 11): you want everyone''s commits checked for a ticket key in ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4426fe9f-afa3-5c30-acfe-9d7143fd1913', '6b1d1e44-b9e7-557d-b370-a7d214310a8a', 1, $json${"prompt":"Review (Section 11): you want everyone's commits checked for a ticket key in the message, including people who use --no-verify. Where must the check live?","multiple":false,"options":[{"id":"a","text":"In CI and/or a server-side hook (e.g. pre-receive), backed by branch protection","is_correct":true},{"id":"b","text":"Only in .git/hooks/commit-msg","is_correct":false},{"id":"c","text":"In .gitignore","is_correct":false},{"id":"d","text":"In each developer's ~/.gitconfig","is_correct":false}],"explanation":"Client hooks can be skipped and are not cloned. Only checks on the server or in required CI apply to everyone. .gitignore and personal config cannot enforce anything."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('2ac3b340-185d-5981-92b6-0ca47fa3060b', '00000000-0000-0000-0000-000000000001', 'Quiz: Worktrees, Submodules and Large Repos', 'git-power-tools-quiz', 'Quiz covering Power Tools: Worktrees, Submodules and Large Repos.', 'mcq', 'published', 'module', 'a681d69d-1026-54a9-b13e-7ca9038ca38f', 12, 70, 5, 14, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '2ac3b340-185d-5981-92b6-0ca47fa3060b' AND question_id NOT IN ('ec967e7d-1257-5581-9302-5d92a15b9a41', 'b52d3162-e09d-550f-b706-e7edcdec30ca', 'a7c35db8-ded7-5091-9286-a7f708521ad1', '38f6bcbe-6783-5b8e-b1a0-7e3c4973b8b4', 'e2669cb5-124a-5c4b-9e68-42a631ba6544', '5eb73739-a8e1-5463-8776-2b002a70c026', '6b1d1e44-b9e7-557d-b370-a7d214310a8a');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('ac7b7671-aba4-500b-aa6a-8b91b6163fc8', '2ac3b340-185d-5981-92b6-0ca47fa3060b', 'ec967e7d-1257-5581-9302-5d92a15b9a41', 'f5935a1d-9ea0-5a20-8276-3958de25132d', 0, 2),
('89c9a06a-550f-535e-85e4-4bd8248e32ee', '2ac3b340-185d-5981-92b6-0ca47fa3060b', 'b52d3162-e09d-550f-b706-e7edcdec30ca', '39b19917-abaa-502a-9dc0-1b5a23c2c738', 1, 2),
('c68a3586-8678-578a-9bbb-985f990587f2', '2ac3b340-185d-5981-92b6-0ca47fa3060b', 'a7c35db8-ded7-5091-9286-a7f708521ad1', 'da4f5a23-563a-5db8-af52-0c60dcab6fca', 2, 2),
('c60bb433-5949-5865-b204-b35c21165c80', '2ac3b340-185d-5981-92b6-0ca47fa3060b', '38f6bcbe-6783-5b8e-b1a0-7e3c4973b8b4', 'e44d2d24-d0f7-52c3-ba7c-33cd644dda2e', 3, 2),
('3db461e3-33fb-5c33-9ef2-4279d93d6d77', '2ac3b340-185d-5981-92b6-0ca47fa3060b', 'e2669cb5-124a-5c4b-9e68-42a631ba6544', '9bfc07dd-f011-5ca0-bab5-83090e67ab33', 4, 2),
('9e2a08aa-29c8-54e1-a481-6ca872995805', '2ac3b340-185d-5981-92b6-0ca47fa3060b', '5eb73739-a8e1-5463-8776-2b002a70c026', '74546516-f757-5658-8ccd-f2afd7643d1f', 5, 2),
('58a375a4-2402-5fc6-b9a7-68445a136b00', '2ac3b340-185d-5981-92b6-0ca47fa3060b', '6b1d1e44-b9e7-557d-b370-a7d214310a8a', '4426fe9f-afa3-5c30-acfe-9d7143fd1913', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('a681d69d-1026-54a9-b13e-7ca9038ca38f', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'b2ad8505-d4d2-5871-a812-03fb6c8db169', 'Quiz: Worktrees, Submodules and Large Repos', 'assessment', 4, 10, '2ac3b340-185d-5981-92b6-0ca47fa3060b')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Troubleshooting Playbook
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('be6c1623-145f-564c-b5fb-dc4ae6b24ddb', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Troubleshooting Playbook', 13, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8627ebc6-e7af-5c09-9dce-264ff7489106', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'be6c1623-145f-564c-b5fb-dc4ae6b24ddb', 'The Git Emergency Playbook: 12 Common Problems', 'notes', 0, $md$## Why this matters

Most Git emergencies are the same dozen situations. Each has a calm,
two-command fix, and most of them reuse what you already learned: refs move,
objects stay, the reflog remembers. This lesson is a lookup table to come back
to.

## Mental model: three questions before any fix

1. **Is it pushed?** Pushed to a shared branch -> only add commits (revert).
   Local only -> you may rewrite (reset, rebase, amend).
2. **Is anything uncommitted?** Commit or stash it first, so a fix cannot
   destroy it.
3. **What does `git status` say?** It names the state (mid-merge, mid-rebase,
   detached) and usually the command to get out.

Mnemonic: **P-U-S** - Pushed? Uncommitted? Status?

## See it work: the playbook

### 1. "I committed on main, it should be on a branch" (not pushed)

```bash
git switch -c feature/report      # new branch keeps the commits
git switch main
git reset --hard origin/main      # main back to the server state
```

```
 before: main: A---B---X---Y  (origin/main = B)
 after : main: A---B           feature/report: A---B---X---Y
```

### 2. "I committed to the wrong branch" (it belongs on an existing one)

```bash
git switch right-branch
git cherry-pick wrong-branch~1 wrong-branch   # or a range
git switch wrong-branch && git reset --hard HEAD~2
```

### 3. "I'm in detached HEAD"

`git status` says `HEAD detached at ...`. Just looking? `git switch main`. Made
commits? `git switch -c keep-them` first. Already left? `git reflog` (Section 7).

### 4. "I deleted a branch I needed"

```bash
git reflog | grep feature/export     # or look for its last commit message
git branch feature/export <hash>
```

`git branch -D` also prints the hash it deleted: `Deleted branch x (was 1a2b3c4).`

### 5. "I dropped a stash"

Stashes are commits but not in the reflog once dropped. Find dangling ones:

```bash
git fsck --no-reflogs --unreachable | grep commit
git stash apply <hash>          # check each candidate with git show first
```

### 6. "Your branch and 'origin/main' have diverged"

Both sides have new commits. Decide how to integrate:

```bash
git pull --rebase      # your unpushed commits on top (linear)
# or
git pull --no-rebase   # merge commit
```

Never answer it with `push --force` on a shared branch.

### 7. "fatal: refusing to merge unrelated histories"

The two branches share no root commit, usually because the remote was created
with a README and you `git init`-ed locally. If you really mean to combine them:
`git pull origin main --allow-unrelated-histories`. Otherwise you have the
wrong remote URL.

### 8. "Unable to create '.../.git/index.lock': File exists"

Another Git process is running (editor integration, a hung command), or one
crashed. Check nothing is running (`ps aux | grep git`), then:

```bash
rm .git/index.lock
```

### 9. "fatal: detected dubious ownership in repository"

The repo folder belongs to another user (shared drives, containers, `sudo`).
Git refuses for security. If you trust it:

```bash
git config --global --add safe.directory /path/to/repo
```

### 10. Every line shows as changed (line endings / file mode)

Windows (CRLF) and Linux/macOS (LF) line endings, or executable bits flipping.
Fix it for everyone in the repo with `.gitattributes`:

```
* text=auto eol=lf
*.bat text eol=crlf
*.png binary
```

Then `git add --renormalize .` and commit. A mode-only diff
(`old mode 100644 / new mode 100755`) can be silenced with
`git config core.fileMode false` on filesystems that do not support it.

### 11. Push rejected: file too large

Hosts refuse files over a limit (GitHub: 100 MB). Removing the file in a new
commit is **not enough**; it is still in the unpushed history. If the commit is
local, `git reset --soft origin/main`, unstage the file, ignore it or track it
with LFS, and recommit. If it is deeper, rewrite with `git filter-repo`
(next lesson).

### 12. "I committed a secret"

Rotate it **first**. Then clean history (next lesson).

## Try it

You made two commits on local `main` that belong on a new branch
`feature/export`, and nothing is pushed. Write the three commands.

<details>
<summary>Show answer</summary>

```bash
git branch feature/export          # label the current commit
git reset --hard origin/main       # move main back (uncommitted work? stash first)
git switch feature/export
```

</details>

## Common mistakes

- **Fixing before reading `git status`.** It often names the exact way out.
- **Reaching for `--force` or `rm -rf .git`.** Almost every situation has a
  non-destructive fix.
- **Re-cloning to "start fresh".** You lose local branches, stashes and the
  reflog: the very tools that would have saved you.

## Remember

- P-U-S: Pushed? Uncommitted? Status?
- Misplaced commits: label them with a branch, then reset the wrong branch.
- Lost things: reflog for commits and branches, `fsck --unreachable` for stashes.
- Lock files, dubious ownership, line endings: read the message, apply the one-line fix.

**Self-check:**

1. What are the three P-U-S questions?
2. How do you recover a dropped stash?
3. Why is removing a big file in a new commit not enough before pushing?
$md$, 11, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2ba53323-54d5-56ba-8688-991b02a47555', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'be6c1623-145f-564c-b5fb-dc4ae6b24ddb', 'A Secret Was Committed: Rotate, Then Rewrite History', 'notes', 1, $md$## Why this matters

An API key, a password, a private key in a commit. Bots scan public
repositories for leaked keys within minutes. Even in a private repo, everyone
with access, every fork and every clone has the secret. The fix has a strict
order, and most people get it backwards.

## Mental model: a leaked house key

If you lose a house key, you **change the lock first**. Searching the street for
the key afterwards is optional. A secret in Git history is a leaked key:
deleting it from the repo does not un-leak it.

```
 1. ROTATE   revoke the secret and issue a new one        (mandatory, immediately)
 2. CLEAN    remove it from history                        (reduces future exposure)
 3. PREVENT  .gitignore, secret scanning, pre-commit hook  (stops the next one)
```

## See it work

### Step 1: rotate

Revoke the key in the provider's console (cloud, payment, database), create a
new one, put it in your secret manager or environment, redeploy. Until this is
done, nothing else matters.

### If it is only in your last local commit (not pushed)

Easiest case; no history rewrite on the server needed:

```bash
git rm --cached .env
echo ".env" >> .gitignore
git add .gitignore
git commit --amend --no-edit
```

Check the result with `git show --stat HEAD`. Rotate anyway if there is any
chance it left your machine.

### If it is deeper in history or pushed: git filter-repo

`git filter-repo` is the tool the Git project recommends (it replaced the slow,
error-prone `git filter-branch`). It is a separate install
(`pip install git-filter-repo` or your package manager).

Work on a fresh clone:

```bash
git clone --mirror git@github.com:brightside/shop.git
cd shop.git
git filter-repo --invert-paths --path .env                    # remove a file from every commit
# or replace the secret text everywhere:
printf 'sk_live_51H...==>REDACTED\n' > ../replacements.txt
git filter-repo --replace-text ../replacements.txt
git push --force --mirror
```

What this does: rewrites every commit that contained the file or text. **Every
hash after the first affected commit changes**, so this is the biggest rewrite
there is.

Afterwards:

- Every teammate must re-clone (or carefully reset); old clones still contain
  the secret and will re-push it if merged.
- Open pull requests and forks keep the old commits. On GitHub/GitLab, contact
  support to purge cached views and PR refs if needed.
- Protected branches must be temporarily unprotected for the force push.

The BFG Repo-Cleaner is an older alternative with similar results.

### Step 3: prevent the next leak

- `.gitignore` for `.env`, key files and local config; commit only
  `.env.example` with placeholders.
- Enable the host's **secret scanning and push protection** (blocks pushes
  containing known key formats).
- Run a scanner such as gitleaks or trufflehog in a `pre-commit` hook and in CI.
- Load secrets from environment variables or a secret manager, never from
  tracked files.

## Try it

A teammate says: "I pushed our Stripe key an hour ago, but I already deleted
the file in a new commit, so we are fine." What do you tell them, in order?

<details>
<summary>Show answer</summary>

1. Not fine: the key is still in the earlier commit, visible to anyone with
   access (and to scanners if the repo is public).
2. Revoke the key in Stripe and issue a new one **now**.
3. Then decide whether to rewrite history with `git filter-repo` (and coordinate
   re-clones), and enable secret scanning / push protection.

</details>

## Common mistakes

- **Cleaning history but not rotating.** Any clone, fork, CI cache or scraper
  made before the rewrite still has the secret.
- **Using `git filter-branch`.** Slow and easy to get wrong; its own manual
  page recommends filter-repo.
- **Rewriting without telling the team.** Old clones re-introduce the secret on
  the next merge.

## Remember

- Order: **rotate**, then clean, then prevent.
- Last unpushed commit: `git rm --cached` + `--amend`.
- Deeper or pushed: `git filter-repo` on a mirror clone, force-push, everyone re-clones.
- Prevent with `.gitignore`, secret scanning, push protection and pre-commit scanners.

**Self-check:**

1. What must happen before any history rewrite?
2. Why must teammates re-clone after `filter-repo`?
3. Name two ways to stop the next secret before it is pushed.
$md$, 8, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('05a166ac-81a6-5466-9507-cf531dbab488', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'be6c1623-145f-564c-b5fb-dc4ae6b24ddb', 'Lab: Four Git Emergencies', 'notes', 2, $md$## Why this matters

These are the emergencies people actually post in team chat. The repository
`~/work/fixit` has all four. Before each fix, run the P-U-S check from the
playbook: **P**ushed? **U**ncommitted? **S**tatus?

```bash
cd ~/work/fixit
git status
git log --oneline --graph --all
```

Expected:

```
* 9c1d2e3 (HEAD -> main) Add report totals
* 4b5a6f7 Add report header
* 2e3f4a5 (origin/main) Add settings
* 1a2b3c4 Initial app
```

## Task 1: commits on the wrong branch

The two report commits are not pushed and belong on `feature/report`.

```
 before: main: ...---S---R1---R2   (origin/main = S)
 after : main: ...---S             feature/report: ...---S---R1---R2
```

[[lab-task:1]]

## Task 2: a committed .env

`.env` was pushed in `Add settings` (assume the key has been rotated). Untrack
it, keep the file, ignore it, commit `Stop tracking .env`.

[[lab-task:2]]

Check: `git status` no longer mentions `.env`, and `cat .env` still works.

## Task 3: a deleted branch

`feature/export` was force-deleted. Find its commit in the reflog and recreate
the branch.

[[lab-task:3]]

Expected reflog line to look for:

```
5d6e7f8 HEAD@{6}: commit: Add CSV export
```

## Task 4: a dropped stash

A stash named `idea` was dropped. Stashes are not in HEAD's reflog, so search
for dangling commits:

```bash
git fsck --no-reflogs --unreachable
git show -s <hash>          # look for "On main: idea"
git stash apply <hash>
```

[[lab-task:4]]

Check: `tail -1 notes.txt` prints `half-finished idea`.

## Remember

- Label first (`git branch`), then move (`reset`).
- Untracking does not remove history; rotation does the real fix.
- Reflog for branches and commits; `fsck --unreachable` for stashes.
$md$, 30, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('565f05f0-fc31-5d0c-a770-5b74e2d1d8a1', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '05a166ac-81a6-5466-9507-cf531dbab488', 'module', 'Lab: Four Git Emergencies', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
w=/home/labuser/work/fixit; s=/home/labuser/srv/git
rm -rf $w $s/fixit.git
mkdir -p $s $w && git init -q --bare $s/fixit.git
git --git-dir=$s/fixit.git symbolic-ref HEAD refs/heads/main
cd $w && git init -q
M() { git add -A; GIT_AUTHOR_NAME="Lab Student" GIT_AUTHOR_EMAIL=student@lab.local GIT_COMMITTER_NAME="Lab Student" GIT_COMMITTER_EMAIL=student@lab.local GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
echo "# Fixit" > README.md; echo "notes" > notes.txt; M 2024-11-01 "Initial app"
echo "port=8080" > settings.txt; echo "API_KEY=abc123" > .env; M 2024-11-02 "Add settings"
git remote add origin $s/fixit.git && git push -q -u origin main 2>/dev/null
git switch -q -c feature/export
echo "id,total" > export.csv; M 2024-11-03 "Add CSV export"
git switch -q main
git branch -q -D feature/export
echo "Report" > report.txt; M 2024-11-04 "Add report header"
echo "Total: 42" >> report.txt; M 2024-11-05 "Add report totals"
echo "half-finished idea" >> notes.txt
git stash push -q -m "idea"
git stash drop -q
$script$, NULL, 40, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '09ce9d13-d9fa-5cee-a923-20f3a4d5f90e' AND id NOT IN ('3bc54e9f-7f2a-55aa-867b-03ccd9821a81', '77cb1429-1b38-55d1-9746-b839184a2900', '67634a77-076a-5b05-9d75-e2b859dd05db', 'c5ba0162-b379-549a-b851-a306dc4c80b3');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '09ce9d13-d9fa-5cee-a923-20f3a4d5f90e';
DELETE FROM lab_tasks WHERE lab_id = '565f05f0-fc31-5d0c-a770-5b74e2d1d8a1' AND id NOT IN ('0e9f8580-59b1-5923-9050-a25788e08204', 'ab4a5615-9740-58db-9765-072c22d24e89', '3f62d412-5c65-590a-af65-9115a02f9620', '19f9b63c-992d-591d-89eb-3907e907a64c');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '565f05f0-fc31-5d0c-a770-5b74e2d1d8a1';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('0e9f8580-59b1-5923-9050-a25788e08204', '565f05f0-fc31-5d0c-a770-5b74e2d1d8a1', 1, 'Move commits made on main to a feature branch', $md$In ~/work/fixit the last two commits on main ("Add report header", "Add report totals") were never pushed and belong on a new branch feature/report. Create that branch with both commits and put main back where origin/main is.$md$, $script$r=/home/labuser/work/fixit
[ "$(git -C $r log --format=%s -2 feature/report 2>/dev/null | paste -sd,)" = "Add report totals,Add report header" ] &&
[ "$(git -C $r rev-parse main)" = "$(git -C $r rev-parse origin/main)" ] &&
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ] &&
[ ! -f $r/report.txt ]
$script$, 'git branch feature/report labels the current commit. Then git reset --hard origin/main moves main back. The commits stay on feature/report.', 'A branch is only a label, so you label the misplaced commits first, then move main. Nothing was pushed, so resetting main rewrites nothing anyone else has.', 20, false, true),
('ab4a5615-9740-58db-9765-072c22d24e89', '565f05f0-fc31-5d0c-a770-5b74e2d1d8a1', 2, 'Stop tracking a committed .env file', $md$.env with an API key was committed and pushed in "Add settings" (the key has already been rotated). Stop tracking .env while keeping the file on disk, ignore it, and commit both changes on main with the message "Stop tracking .env".$md$, $script$r=/home/labuser/work/fixit
[ "$(git -C $r log -1 --format=%s main)" = "Stop tracking .env" ] &&
! git -C $r cat-file -e main:.env 2>/dev/null &&
git -C $r show main:.gitignore | grep -qx '.env' &&
[ -f $r/.env ] && git -C $r check-ignore -q .env
$script$, 'git rm --cached .env removes it from the index only. echo .env >> .gitignore, git add .gitignore, then commit.', 'Untracking stops future commits from containing .env, but the old commit still has it. That is why rotation came first; rewriting history (git filter-repo) is the optional extra step.', 15, false, true),
('3f62d412-5c65-590a-af65-9115a02f9620', '565f05f0-fc31-5d0c-a770-5b74e2d1d8a1', 3, 'Restore a deleted branch', $md$Someone force-deleted the branch feature/export, whose only new commit was "Add CSV export". Recreate feature/export pointing at that commit.$md$, $script$r=/home/labuser/work/fixit
[ "$(git -C $r log -1 --format=%s feature/export 2>/dev/null)" = "Add CSV export" ] &&
[ "$(git -C $r show feature/export:export.csv | head -1)" = "id,total" ]
$script$, 'git reflog shows "commit: Add CSV export" from when the branch was checked out. git branch feature/export <that hash>.', 'Deleting a branch removes only the ref. The commit stays in the object database and in HEAD''s reflog, so a new ref brings it back.', 20, false, true),
('19f9b63c-992d-591d-89eb-3907e907a64c', '565f05f0-fc31-5d0c-a770-5b74e2d1d8a1', 4, 'Recover a dropped stash', $md$A stash named "idea" (an extra line "half-finished idea" in notes.txt) was dropped by mistake. Find the dangling stash commit and apply it so notes.txt contains that line again.$md$, $script$grep -qx 'half-finished idea' /home/labuser/work/fixit/notes.txt
$script$, 'git fsck --no-reflogs --unreachable lists dangling commits. Check each with git show -s <hash>; the stash has the subject "On main: idea". Then git stash apply <hash>.', 'A stash is a commit stored under refs/stash. Dropping it removes the ref, and stash entries are not in HEAD''s reflog, but the commit object lives on until garbage collection, so fsck can still find it.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('09ce9d13-d9fa-5cee-a923-20f3a4d5f90e', '565f05f0-fc31-5d0c-a770-5b74e2d1d8a1', 1, $json$[{"id":"0e9f8580-59b1-5923-9050-a25788e08204","lab_id":"565f05f0-fc31-5d0c-a770-5b74e2d1d8a1","position":1,"title":"Move commits made on main to a feature branch","description":"In ~/work/fixit the last two commits on main (\"Add report header\", \"Add report totals\") were never pushed and belong on a new branch feature/report. Create that branch with both commits and put main back where origin/main is.","verification_script":"r=/home/labuser/work/fixit\n[ \"$(git -C $r log --format=%s -2 feature/report 2\u003e/dev/null | paste -sd,)\" = \"Add report totals,Add report header\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse main)\" = \"$(git -C $r rev-parse origin/main)\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse --abbrev-ref HEAD)\" = main ] \u0026\u0026\n[ ! -f $r/report.txt ]\n","hint_context":"git branch feature/report labels the current commit. Then git reset --hard origin/main moves main back. The commits stay on feature/report.","explanation_context":"A branch is only a label, so you label the misplaced commits first, then move main. Nothing was pushed, so resetting main rewrites nothing anyone else has.","points":20,"is_optional":false,"is_stateful":true},{"id":"ab4a5615-9740-58db-9765-072c22d24e89","lab_id":"565f05f0-fc31-5d0c-a770-5b74e2d1d8a1","position":2,"title":"Stop tracking a committed .env file","description":".env with an API key was committed and pushed in \"Add settings\" (the key has already been rotated). Stop tracking .env while keeping the file on disk, ignore it, and commit both changes on main with the message \"Stop tracking .env\".","verification_script":"r=/home/labuser/work/fixit\n[ \"$(git -C $r log -1 --format=%s main)\" = \"Stop tracking .env\" ] \u0026\u0026\n! git -C $r cat-file -e main:.env 2\u003e/dev/null \u0026\u0026\ngit -C $r show main:.gitignore | grep -qx '.env' \u0026\u0026\n[ -f $r/.env ] \u0026\u0026 git -C $r check-ignore -q .env\n","hint_context":"git rm --cached .env removes it from the index only. echo .env \u003e\u003e .gitignore, git add .gitignore, then commit.","explanation_context":"Untracking stops future commits from containing .env, but the old commit still has it. That is why rotation came first; rewriting history (git filter-repo) is the optional extra step.","points":15,"is_optional":false,"is_stateful":true},{"id":"3f62d412-5c65-590a-af65-9115a02f9620","lab_id":"565f05f0-fc31-5d0c-a770-5b74e2d1d8a1","position":3,"title":"Restore a deleted branch","description":"Someone force-deleted the branch feature/export, whose only new commit was \"Add CSV export\". Recreate feature/export pointing at that commit.","verification_script":"r=/home/labuser/work/fixit\n[ \"$(git -C $r log -1 --format=%s feature/export 2\u003e/dev/null)\" = \"Add CSV export\" ] \u0026\u0026\n[ \"$(git -C $r show feature/export:export.csv | head -1)\" = \"id,total\" ]\n","hint_context":"git reflog shows \"commit: Add CSV export\" from when the branch was checked out. git branch feature/export \u003cthat hash\u003e.","explanation_context":"Deleting a branch removes only the ref. The commit stays in the object database and in HEAD's reflog, so a new ref brings it back.","points":20,"is_optional":false,"is_stateful":true},{"id":"19f9b63c-992d-591d-89eb-3907e907a64c","lab_id":"565f05f0-fc31-5d0c-a770-5b74e2d1d8a1","position":4,"title":"Recover a dropped stash","description":"A stash named \"idea\" (an extra line \"half-finished idea\" in notes.txt) was dropped by mistake. Find the dangling stash commit and apply it so notes.txt contains that line again.","verification_script":"grep -qx 'half-finished idea' /home/labuser/work/fixit/notes.txt\n","hint_context":"git fsck --no-reflogs --unreachable lists dangling commits. Check each with git show -s \u003chash\u003e; the stash has the subject \"On main: idea\". Then git stash apply \u003chash\u003e.","explanation_context":"A stash is a commit stored under refs/stash. Dropping it removes the ref, and stash entries are not in HEAD's reflog, but the commit object lives on until garbage collection, so fsck can still find it.","points":25,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('3bc54e9f-7f2a-55aa-867b-03ccd9821a81', '09ce9d13-d9fa-5cee-a923-20f3a4d5f90e', '0e9f8580-59b1-5923-9050-a25788e08204', 1, 'Move commits made on main to a feature branch', $md$In ~/work/fixit the last two commits on main ("Add report header", "Add report totals") were never pushed and belong on a new branch feature/report. Create that branch with both commits and put main back where origin/main is.$md$, $script$r=/home/labuser/work/fixit
[ "$(git -C $r log --format=%s -2 feature/report 2>/dev/null | paste -sd,)" = "Add report totals,Add report header" ] &&
[ "$(git -C $r rev-parse main)" = "$(git -C $r rev-parse origin/main)" ] &&
[ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ] &&
[ ! -f $r/report.txt ]
$script$, 'git branch feature/report labels the current commit. Then git reset --hard origin/main moves main back. The commits stay on feature/report.', 'A branch is only a label, so you label the misplaced commits first, then move main. Nothing was pushed, so resetting main rewrites nothing anyone else has.', 20, false, true),
('77cb1429-1b38-55d1-9746-b839184a2900', '09ce9d13-d9fa-5cee-a923-20f3a4d5f90e', 'ab4a5615-9740-58db-9765-072c22d24e89', 2, 'Stop tracking a committed .env file', $md$.env with an API key was committed and pushed in "Add settings" (the key has already been rotated). Stop tracking .env while keeping the file on disk, ignore it, and commit both changes on main with the message "Stop tracking .env".$md$, $script$r=/home/labuser/work/fixit
[ "$(git -C $r log -1 --format=%s main)" = "Stop tracking .env" ] &&
! git -C $r cat-file -e main:.env 2>/dev/null &&
git -C $r show main:.gitignore | grep -qx '.env' &&
[ -f $r/.env ] && git -C $r check-ignore -q .env
$script$, 'git rm --cached .env removes it from the index only. echo .env >> .gitignore, git add .gitignore, then commit.', 'Untracking stops future commits from containing .env, but the old commit still has it. That is why rotation came first; rewriting history (git filter-repo) is the optional extra step.', 15, false, true),
('67634a77-076a-5b05-9d75-e2b859dd05db', '09ce9d13-d9fa-5cee-a923-20f3a4d5f90e', '3f62d412-5c65-590a-af65-9115a02f9620', 3, 'Restore a deleted branch', $md$Someone force-deleted the branch feature/export, whose only new commit was "Add CSV export". Recreate feature/export pointing at that commit.$md$, $script$r=/home/labuser/work/fixit
[ "$(git -C $r log -1 --format=%s feature/export 2>/dev/null)" = "Add CSV export" ] &&
[ "$(git -C $r show feature/export:export.csv | head -1)" = "id,total" ]
$script$, 'git reflog shows "commit: Add CSV export" from when the branch was checked out. git branch feature/export <that hash>.', 'Deleting a branch removes only the ref. The commit stays in the object database and in HEAD''s reflog, so a new ref brings it back.', 20, false, true),
('c5ba0162-b379-549a-b851-a306dc4c80b3', '09ce9d13-d9fa-5cee-a923-20f3a4d5f90e', '19f9b63c-992d-591d-89eb-3907e907a64c', 4, 'Recover a dropped stash', $md$A stash named "idea" (an extra line "half-finished idea" in notes.txt) was dropped by mistake. Find the dangling stash commit and apply it so notes.txt contains that line again.$md$, $script$grep -qx 'half-finished idea' /home/labuser/work/fixit/notes.txt
$script$, 'git fsck --no-reflogs --unreachable lists dangling commits. Check each with git show -s <hash>; the stash has the subject "On main: idea". Then git stash apply <hash>.', 'A stash is a commit stored under refs/stash. Dropping it removes the ref, and stash entries are not in HEAD''s reflog, but the commit object lives on until garbage collection, so fsck can still find it.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '09ce9d13-d9fa-5cee-a923-20f3a4d5f90e', updated_at = now()
WHERE id = '565f05f0-fc31-5d0c-a770-5b74e2d1d8a1' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('45f688e8-7930-5585-abdf-ab68b2b79bc2', '00000000-0000-0000-0000-000000000001', 'mcq', 'You pushed a commit containing a live cloud access key to a private repo 10 m...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('167f6e89-698a-59fb-816e-bc663c3b92eb', '45f688e8-7930-5585-abdf-ab68b2b79bc2', 1, $json${"prompt":"You pushed a commit containing a live cloud access key to a private repo 10 minutes ago. What is the FIRST thing to do?","multiple":false,"options":[{"id":"a","text":"Run git filter-repo to remove it from history","is_correct":false},{"id":"b","text":"Revoke/rotate the key with the cloud provider","is_correct":true},{"id":"c","text":"Delete the file in a new commit","is_correct":false},{"id":"d","text":"Make the repository private again","is_correct":false}],"explanation":"Assume the key is compromised the moment it left your machine. Rotation is the only real fix; cleaning history and deleting the file only reduce future exposure, and the repo is already private."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0a2824a8-4493-5150-a4b9-d45aab03fc1a', '00000000-0000-0000-0000-000000000001', 'mcq', 'You made three commits on local main that should be on a feature branch. Noth...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('db11026a-4b1e-56a9-847e-be0db4b7e4d4', '0a2824a8-4493-5150-a4b9-d45aab03fc1a', 1, $json${"prompt":"You made three commits on local main that should be on a feature branch. Nothing is pushed. Which sequence is correct?","multiple":false,"options":[{"id":"a","text":"git branch feature/x; git reset --hard origin/main; git switch feature/x","is_correct":true},{"id":"b","text":"git reset --hard origin/main; git branch feature/x","is_correct":false},{"id":"c","text":"git push --force; git switch -c feature/x","is_correct":false},{"id":"d","text":"git revert HEAD~3..HEAD; git switch -c feature/x","is_correct":false}],"explanation":"Label the commits first, then move main back. Resetting first would leave the commits unlabelled (recoverable only via reflog), force-pushing publishes the mistake, and revert adds inverse commits to main instead of moving the work."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a588943d-95ba-59cc-a55d-796f2ddf9df8', '00000000-0000-0000-0000-000000000001', 'mcq', 'Every Git command fails with "Unable to create ''.git/index.lock'': File exists...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a5ae4bc7-f50e-56fc-9a85-c28d6480c92d', 'a588943d-95ba-59cc-a55d-796f2ddf9df8', 1, $json${"prompt":"Every Git command fails with \"Unable to create '.git/index.lock': File exists\". No other Git process is running. What do you do?","multiple":false,"options":[{"id":"a","text":"Delete the repository and re-clone","is_correct":false},{"id":"b","text":"Remove the stale .git/index.lock file","is_correct":true},{"id":"c","text":"Run git gc --prune=now","is_correct":false},{"id":"d","text":"Run git reset --hard","is_correct":false}],"explanation":"A crashed Git process left its lock file. Once you have confirmed nothing is running, deleting it is safe. Re-cloning throws away local branches and reflogs, gc and reset do not remove the lock (and reset would fail on it)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d737da4a-1915-5ad8-95d5-54023f0a3632', '00000000-0000-0000-0000-000000000001', 'mcq', 'A teammate on Windows commits and suddenly every line of every file shows as ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('89664a80-3ac8-52b9-8a3a-eb5b6e0b7cde', 'd737da4a-1915-5ad8-95d5-54023f0a3632', 1, $json${"prompt":"A teammate on Windows commits and suddenly every line of every file shows as changed. What is the lasting team-wide fix?","multiple":false,"options":[{"id":"a","text":"Ask everyone to use the same editor","is_correct":false},{"id":"b","text":"Add a .gitattributes with text=auto (and eol rules), then git add --renormalize . and commit","is_correct":true},{"id":"c","text":"Disable git diff","is_correct":false},{"id":"d","text":"Use git blame -w","is_correct":false}],"explanation":"Line-ending normalisation belongs in .gitattributes, which is committed and applies to everyone. Editors vary, disabling diff hides the problem, and blame -w only affects blame output."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('71fa8bd6-b295-5096-a94e-e39fc3633eed', '00000000-0000-0000-0000-000000000001', 'mcq', 'You dropped a stash yesterday by mistake. How can you find it?', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ee61b5f4-5081-583f-991d-ab9a1048366b', '71fa8bd6-b295-5096-a94e-e39fc3633eed', 1, $json${"prompt":"You dropped a stash yesterday by mistake. How can you find it?","multiple":false,"options":[{"id":"a","text":"git reflog shows dropped stashes","is_correct":false},{"id":"b","text":"git fsck --no-reflogs --unreachable lists dangling commits; the stash commit has a subject like 'On main: ...'","is_correct":true},{"id":"c","text":"git stash list --all","is_correct":false},{"id":"d","text":"It cannot be recovered","is_correct":false}],"explanation":"Stash commits are not in HEAD's reflog and leave refs/stash when dropped, but the objects remain until gc prunes them. stash list has no --all to show dropped entries."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('097451d4-c0eb-5f92-8b73-8d170eed4590', '00000000-0000-0000-0000-000000000001', 'mcq', 'After rewriting history with git filter-repo and force-pushing, why must team...', 'advanced', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2d57d59a-2a37-5f38-8415-ba125973783d', '097451d4-c0eb-5f92-8b73-8d170eed4590', 1, $json${"prompt":"After rewriting history with git filter-repo and force-pushing, why must teammates re-clone instead of just pulling?","multiple":false,"options":[{"id":"a","text":"Pulling is disabled after a force push","is_correct":false},{"id":"b","text":"Their clones still hold the old commits containing the secret; merging would bring them back, and every rewritten commit has a new hash","is_correct":true},{"id":"c","text":"filter-repo changes the remote URL","is_correct":false},{"id":"d","text":"Re-cloning is faster than pulling","is_correct":false}],"explanation":"A pull would merge the old history (with the secret) into the new one. Pulling still works technically, the URL is unchanged, and speed is not the point."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5f4b0567-6f29-554a-8ede-6e43f203efad', '00000000-0000-0000-0000-000000000001', 'mcq', 'Review (Section 12): a new teammate''s clone has an empty vendor/ui-lib folder...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7b32cbf0-27a0-513e-b3cd-008973854ed3', '5f4b0567-6f29-554a-8ede-6e43f203efad', 1, $json${"prompt":"Review (Section 12): a new teammate's clone has an empty vendor/ui-lib folder and the build fails. What should they run?","multiple":false,"options":[{"id":"a","text":"git submodule update --init --recursive","is_correct":true},{"id":"b","text":"git pull --rebase","is_correct":false},{"id":"c","text":"git worktree add vendor/ui-lib","is_correct":false},{"id":"d","text":"git lfs pull","is_correct":false}],"explanation":"A plain clone does not fetch submodule contents. pull updates the parent only, worktree creates a checkout of the same repo, and LFS handles large files, not submodules."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('09f8392e-7fec-5a65-b32e-12c3b32d1afb', '00000000-0000-0000-0000-000000000001', 'Quiz: Troubleshooting', 'git-troubleshooting-quiz', 'Quiz covering Troubleshooting Playbook.', 'mcq', 'published', 'module', '80d4a547-b1e4-5290-bc65-4040eb18d56e', 12, 70, 5, 14, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '09f8392e-7fec-5a65-b32e-12c3b32d1afb' AND question_id NOT IN ('45f688e8-7930-5585-abdf-ab68b2b79bc2', '0a2824a8-4493-5150-a4b9-d45aab03fc1a', 'a588943d-95ba-59cc-a55d-796f2ddf9df8', 'd737da4a-1915-5ad8-95d5-54023f0a3632', '71fa8bd6-b295-5096-a94e-e39fc3633eed', '097451d4-c0eb-5f92-8b73-8d170eed4590', '5f4b0567-6f29-554a-8ede-6e43f203efad');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('84348d0b-7f4c-5357-9c9e-d0b2a33dcab4', '09f8392e-7fec-5a65-b32e-12c3b32d1afb', '45f688e8-7930-5585-abdf-ab68b2b79bc2', '167f6e89-698a-59fb-816e-bc663c3b92eb', 0, 2),
('76bdad9b-0026-596e-957d-6a83faedd227', '09f8392e-7fec-5a65-b32e-12c3b32d1afb', '0a2824a8-4493-5150-a4b9-d45aab03fc1a', 'db11026a-4b1e-56a9-847e-be0db4b7e4d4', 1, 2),
('3f24e56c-82de-519a-9364-d5123de92256', '09f8392e-7fec-5a65-b32e-12c3b32d1afb', 'a588943d-95ba-59cc-a55d-796f2ddf9df8', 'a5ae4bc7-f50e-56fc-9a85-c28d6480c92d', 2, 2),
('8551b895-2dd8-5139-b10e-be392e10779b', '09f8392e-7fec-5a65-b32e-12c3b32d1afb', 'd737da4a-1915-5ad8-95d5-54023f0a3632', '89664a80-3ac8-52b9-8a3a-eb5b6e0b7cde', 3, 2),
('2faa25ea-107c-5d95-8caa-91724b0e97ed', '09f8392e-7fec-5a65-b32e-12c3b32d1afb', '71fa8bd6-b295-5096-a94e-e39fc3633eed', 'ee61b5f4-5081-583f-991d-ab9a1048366b', 4, 2),
('7d29f7b0-c084-5208-b55e-cdcf17e4702b', '09f8392e-7fec-5a65-b32e-12c3b32d1afb', '097451d4-c0eb-5f92-8b73-8d170eed4590', '2d57d59a-2a37-5f38-8415-ba125973783d', 5, 2),
('2965db7d-395b-5b3a-9af9-a86025698eca', '09f8392e-7fec-5a65-b32e-12c3b32d1afb', '5f4b0567-6f29-554a-8ede-6e43f203efad', '7b32cbf0-27a0-513e-b3cd-008973854ed3', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('80d4a547-b1e4-5290-bc65-4040eb18d56e', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'be6c1623-145f-564c-b5fb-dc4ae6b24ddb', 'Quiz: Troubleshooting', 'assessment', 3, 10, '09f8392e-7fec-5a65-b32e-12c3b32d1afb')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Capstone: Team Workflow
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('8231161f-ca60-5da8-bf27-4161f81d0844', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Capstone: Team Workflow', 14, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6d5dda11-b14a-5131-aa88-7b55ea3b1fe0', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '8231161f-ca60-5da8-bf27-4161f81d0844', 'Capstone Lab: Feature Branch to Release', 'notes', 0, $md$## Why this matters

Your first real release at Brightside. No hints about which command to use:
just the situation, like on the job. Build a feature on a branch, publish it,
catch up with a teammate's change, clean up, merge, tag, and fix a bad commit
that reaches `main`. The server is `/home/labuser/srv/git/storefront.git`; the
helper `~/bin/teammate` plays Maya.

## The workflow you are about to run

```
 origin/main  A---B---C---T--------M---(tag v1.1.0)---X---X'(revert of X)
                          \       /
 feature branch            D'----+     (D' = squashed + rebased copy of D1 D2 D3)

 T = teammate's commit that landed while you worked
 X = bad commit pushed to main,  X' = revert of X
```

```knowledge-check
{ "questions": [
  { "id": "git-cap-flow-q1", "type": "mcq",
    "prompt": "Why rebase the feature branch onto the latest main before merging?",
    "options": [
      {"id":"a","text":"So you resolve conflicts on your branch, and the final merge into main is clean and linear to review"},
      {"id":"b","text":"Because merge does not work after a fetch"},
      {"id":"c","text":"To rename commits"},
      {"id":"d","text":"To delete main"}],
    "correct": "a",
    "explanation": "Conflicts are resolved by the author, not at merge time on the shared branch. Merge works fine after fetch, rebase is not for renaming, and main is never deleted." }
] }
```

## Stage 1: build and publish

Clone the repo into `~/work/storefront` and create `feature/discount-banner`
with three commits: add `banner.txt`, a "WIP" tweak to it, and change the
`GREETING` line in `app.sh` to `GREETING="Welcome to the store"`.

[[lab-task:1]]

Publish the branch with upstream tracking (on a real host this is where you open
the pull request).

[[lab-task:2]]

Expected `git log --oneline --graph --all`:

```
* 8d1f6c2 (HEAD -> feature/discount-banner, origin/feature/discount-banner) Update greeting
* 02ab7e4 WIP banner styling
* c9e5130 Add banner text
* 4f7a1d9 (origin/main, origin/HEAD, main) Add check script
```

```knowledge-check
{ "questions": [
  { "id": "git-cap-publish-q1", "type": "mcq",
    "prompt": "What is a pull request, in Git terms?",
    "options": [
      {"id":"a","text":"A branch on the server plus a request to merge it, with review around it"},
      {"id":"b","text":"A special kind of commit"},
      {"id":"c","text":"A git command that downloads code"},
      {"id":"d","text":"A tag"}],
    "correct": "a",
    "explanation": "Git only knows branches; the PR UI is a feature of the hosting service. It is not a commit type, not git pull, and not a tag." }
] }
```

## Stage 2: main moves

Run `~/bin/teammate land-greeting` and fetch.

[[lab-task:3]]

Rebase your branch onto `origin/main`. The greeting commit conflicts: resolve
`app.sh` to `GREETING="Hello, welcome to the store"`, keep the `round` line,
and continue.

```
 after teammate:  origin/main  A---B---C---T
                  feature                \
                                          (still based on C)  D1---D2---D3

 git rebase origin/main:   A---B---C---T---D1'---D2'---D3'   (conflict on D3: GREETING line)
```

[[lab-task:4]]

```knowledge-check
{ "questions": [
  { "id": "git-cap-rebase-q1", "type": "mcq",
    "prompt": "In which commit of the replay did the conflict appear, and why?",
    "options": [
      {"id":"a","text":"The greeting commit: both main and the branch changed the GREETING line"},
      {"id":"b","text":"The banner.txt commit: new files always conflict"},
      {"id":"c","text":"The first commit, always"},
      {"id":"d","text":"None - rebase never conflicts"}],
    "correct": "a",
    "explanation": "Only the commit touching the line main also changed conflicts; the others replay cleanly. New files do not conflict, the first commit is not special, and rebases can conflict." }
] }
```

## Stage 3: tidy up and update the PR

Squash the three commits into one named `Add discount banner`, then update the
remote branch safely.

[[lab-task:5]]

[[lab-task:6]]

Expected:

```
* 5be0a93 (HEAD -> feature/discount-banner, origin/feature/discount-banner) Add discount banner
* 3a1c7f0 (origin/main, main) Change greeting wording
```

```knowledge-check
{ "questions": [
  { "id": "git-cap-squash-q1", "type": "mcq",
    "prompt": "After squashing a branch you already pushed, which push command is appropriate?",
    "options": [
      {"id":"a","text":"git push --force-with-lease"},
      {"id":"b","text":"git push (plain)"},
      {"id":"c","text":"git push --delete"},
      {"id":"d","text":"git pull"}],
    "correct": "a",
    "explanation": "History was rewritten, so a plain push is rejected. The lease keeps it safe. --delete removes the branch and pull downloads instead of uploading." }
] }
```

## Stage 4: merge and release

Update local `main`, merge the branch with `--no-ff` and the message
`Merge feature/discount-banner`, push, then create and push the annotated tag
`v1.1.0` (`Release 1.1.0`).

[[lab-task:7]]

[[lab-task:8]]

Expected `git ls-remote --tags origin`:

```
a14c7be...	refs/tags/v1.1.0
5be0a93...	refs/tags/v1.1.0^{}
```

## Stage 5: a bad commit reaches main

Run `~/bin/teammate land-bad`. Pull, confirm `sh check.sh` fails, undo the bad
commit **without rewriting history**, push, and confirm `sh check.sh` prints
`OK`.

```
 BEFORE revert                     AFTER git revert X; git push
 ...---M---X  <- main (broken)     ...---M---X---X'  <- main (fixed, history intact)
```

[[lab-task:9]]

```knowledge-check
{ "questions": [
  { "id": "git-cap-revert-q1", "type": "mcq",
    "prompt": "Why revert instead of reset --hard and force-push on a shared main?",
    "options": [
      {"id":"a","text":"Force-pushing would rewrite history that teammates and CI already have; revert adds a fixing commit"},
      {"id":"b","text":"Revert is always faster"},
      {"id":"c","text":"Reset does not work on main"},
      {"id":"d","text":"There is no difference"}],
    "correct": "a",
    "explanation": "Shared history is append-only; a revert is an ordinary, reviewable commit. Speed is not the reason, reset works on any branch, and the difference is exactly who gets broken." }
] }
```

## You made it

You ran the full loop: branch, publish, rebase, resolve, squash, lease-push,
merge, tag, revert. Next: the course review and the final exam.
$md$, 60, $json$[{"id":"git-cap-flow-q1","type":"mcq","correct":"a"},{"id":"git-cap-publish-q1","type":"mcq","correct":"a"},{"id":"git-cap-rebase-q1","type":"mcq","correct":"a"},{"id":"git-cap-squash-q1","type":"mcq","correct":"a"},{"id":"git-cap-revert-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('dd19c2d2-b23f-540c-a234-9c4126c54766', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '6d5dda11-b14a-5131-aa88-7b55ea3b1fe0', 'module', 'Capstone Lab: Feature Branch to Release', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --global init.defaultBranch main
git config --global safe.directory '*'
git config --global pull.rebase false
git config --global user.name "Lab Student"
git config --global user.email "student@lab.local"
rm -rf /home/labuser/srv/git /home/labuser/work/storefront /tmp/seed
mkdir -p /home/labuser/srv/git
git init -q --bare /home/labuser/srv/git/storefront.git
git clone -q /home/labuser/srv/git/storefront.git /tmp/seed 2>/dev/null
cd /tmp/seed
export GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com
c() { git add -A; GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
echo "# Storefront" > README.md; c 2024-07-01 "Initial commit"
printf 'GREETING="Welcome"\nround() { echo $(( ($1 + 5) / 10 * 10 )); }\n' > app.sh; c 2024-07-02 "Add app script"
printf '. ./app.sh\n[ "$(round 14)" = 10 ] || { echo FAIL; exit 1; }\necho OK\n' > check.sh; c 2024-07-03 "Add check script"
git push -q origin main
cd /; rm -rf /tmp/seed
git --git-dir=/home/labuser/srv/git/storefront.git symbolic-ref HEAD refs/heads/main
mkdir -p /home/labuser/bin
cat > /home/labuser/bin/teammate <<'SCRIPT'
#!/bin/bash
# Simulates Maya pushing to origin/main. usage: teammate land-greeting | land-bad
set -e
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
git clone -q /home/labuser/srv/git/storefront.git "$t/w" 2>/dev/null; cd "$t/w"
case "$1" in
  land-greeting) subject="Change greeting wording"; date=2024-07-10
    edit() { sed -i 's/^GREETING=.*/GREETING="Hello, welcome"/' app.sh; } ;;
  land-bad) subject="Switch to experimental rounding"; date=2024-07-20
    edit() { sed -i 's/(\$1 + 5)/($1 + 9)/' app.sh; } ;;
  *) echo "usage: teammate land-greeting | land-bad" >&2; exit 2 ;;
esac
if git log --format=%s | grep -qx "$subject"; then echo "already landed: $subject"; exit 0; fi
edit; git add -A
GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com \
GIT_AUTHOR_DATE="${date}T10:00:00+0000" GIT_COMMITTER_DATE="${date}T10:00:00+0000" git commit -q -m "$subject"
git push -q origin main
echo "pushed to origin/main: $subject"
SCRIPT
chmod 755 /home/labuser/bin/teammate
chmod -R a+rwX /home/labuser/srv/git
$script$, NULL, 60, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '54c2960c-8c22-5cf6-9a52-1e7813c77002' AND id NOT IN ('3b335974-a7c9-5414-a3fb-1e1e222943a1', '0f26bc79-ced6-5741-8df0-e81afdd96ad3', 'ef3badec-661f-5956-894a-6e159955288a', '7a8b3d3e-7059-50fc-a280-7a4b3b05bf37', 'a7564021-9195-5d7c-b26e-1496070472b0', '739caf5a-e19a-5ad0-aa82-754834daca79', 'e7483c86-2aa9-5229-a831-43a952056fdc', '3b430220-5751-56d5-8ec5-92612bd9de8d', '504c0041-9c6b-58a9-8a22-4788761b5772');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '54c2960c-8c22-5cf6-9a52-1e7813c77002';
DELETE FROM lab_tasks WHERE lab_id = 'dd19c2d2-b23f-540c-a234-9c4126c54766' AND id NOT IN ('f1a90460-ec4b-5e7f-be18-8b810ec8a8d6', '3e787a98-3c96-5a16-bcd0-e1e3951f3013', '90a5a745-5d4e-55a7-b39e-7543262d5a58', '5223d9e1-2b63-5b83-8b29-3ead2d836db8', 'dfbaba7f-41e8-5db1-93c8-008a00bea4c6', 'def03691-0b8a-5fa4-b2ab-00f35d7cb19c', '34efc9e3-90c1-55fb-aa4c-3f571e6e6870', '47f4dd60-c208-5a9b-b80c-5761d679d1dd', 'beb80b5f-c387-54a0-a0da-8996c7fb9d9d');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'dd19c2d2-b23f-540c-a234-9c4126c54766';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('f1a90460-ec4b-5e7f-be18-8b810ec8a8d6', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 1, 'Build the feature on a branch', $md$Clone /home/labuser/srv/git/storefront.git into ~/work/storefront. Create branch feature/discount-banner with exactly three commits: add banner.txt, tweak banner.txt (a "WIP" commit), and change the GREETING line in app.sh to GREETING="Welcome to the store".$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r rev-list --count origin/main..feature/discount-banner)" = 3 ] &&
git -C $r show feature/discount-banner:banner.txt >/dev/null &&
git -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING="Welcome to the store"'
$script$, 'git clone, git switch -c feature/discount-banner, then three separate git commit invocations. Use sed -i or an editor for the GREETING change.', 'Small, separate commits are normal while working; you will tidy them before the review.', 15, false, true),
('3e787a98-3c96-5a16-bcd0-e1e3951f3013', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 2, 'Push the branch (open the pull request)', $md$Publish feature/discount-banner to origin and set its upstream - on a real server this is what lets you open a pull request.$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)" = "$(git -C $r rev-parse feature/discount-banner)" ] &&
[ "$(git -C $r rev-parse feature/discount-banner@{upstream})" = "$(git -C $r rev-parse feature/discount-banner)" ]
$script$, 'git push -u origin feature/discount-banner', 'A pull request is just a branch on the server plus a request to merge it. Everything else (review, CI) happens around that branch.', 10, false, true),
('90a5a745-5d4e-55a7-b39e-7543262d5a58', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 3, 'A teammate lands a change on main', $md$Run the helper ~/bin/teammate land-greeting (it pushes a commit to origin/main, changing the same GREETING line). Then fetch so you can see it in origin/main.$md$, $script$r=/home/labuser/work/storefront
git -C $r log origin/main --format=%s | grep -qx "Change greeting wording" &&
[ "$(git -C $r rev-parse origin/main)" = "$(git -C $r ls-remote origin refs/heads/main | cut -f1)" ]
$script$, '~/bin/teammate land-greeting, then git fetch, then git log --oneline --graph --all.', 'While your branch was open, main moved. Your branch is now based on an older main and touches a line that changed on both sides.', 10, false, true),
('5223d9e1-2b63-5b83-8b29-3ead2d836db8', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 4, 'Rebase the branch and resolve the conflict', $md$Rebase feature/discount-banner onto origin/main. The greeting commit conflicts; resolve app.sh so GREETING is "Hello, welcome to the store" (keep the round line unchanged), continue the rebase, and end with the same three commits on top of origin/main.$md$, $script$r=/home/labuser/work/storefront
[ ! -d $r/.git/rebase-merge ] &&
git -C $r merge-base --is-ancestor origin/main feature/discount-banner &&
[ "$(git -C $r rev-list --count origin/main..feature/discount-banner)" = 3 ] &&
git -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING="Hello, welcome to the store"' &&
git -C $r show feature/discount-banner:app.sh | grep -q '^round()' &&
[ -z "$(git -C $r grep -nE '^(<<<<<<<|=======|>>>>>>>)' feature/discount-banner)" ]
$script$, 'git switch feature/discount-banner && git rebase origin/main. Fix app.sh, git add app.sh, GIT_EDITOR=true git rebase --continue.', 'Rebasing replays your three commits on the new main so the final merge is trivial and history stays linear. The conflict is the same one a merge would have raised.', 20, false, true),
('dfbaba7f-41e8-5db1-93c8-008a00bea4c6', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 5, 'Squash the branch into one commit', $md$Use interactive rebase to squash the three commits into a single commit with the message "Add discount banner".$md$, $script$r=/home/labuser/work/storefront
[ ! -d $r/.git/rebase-merge ] &&
[ "$(git -C $r rev-list --count origin/main..feature/discount-banner)" = 1 ] &&
[ "$(git -C $r log feature/discount-banner -1 --format=%s)" = "Add discount banner" ] &&
git -C $r show feature/discount-banner:banner.txt >/dev/null &&
git -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING="Hello, welcome to the store"'
$script$, 'git rebase -i origin/main, change the 2nd and 3rd pick to fixup (or squash), then reword the remaining commit.', 'Reviewers and git bisect prefer one coherent commit per change. Squashing removes the WIP noise before it lands on main.', 15, false, true),
('def03691-0b8a-5fa4-b2ab-00f35d7cb19c', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 6, 'Update the remote branch safely', $md$The remote branch still has the old three commits. Update it with --force-with-lease.$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)" = "$(git -C $r rev-parse feature/discount-banner)" ] &&
[ "$(git -C $r log origin/feature/discount-banner -1 --format=%s)" = "Add discount banner" ]
$script$, 'git push --force-with-lease origin feature/discount-banner', 'Rewriting your own feature branch after review feedback is normal; the lease protects against overwriting a reviewer''s pushed fixup.', 10, false, true),
('34efc9e3-90c1-55fb-aa4c-3f571e6e6870', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 7, 'Merge the pull request into main', $md$Update local main from origin, then merge feature/discount-banner into main with --no-ff and the message "Merge feature/discount-banner", and push main.$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r ls-remote origin refs/heads/main | cut -f1)" = "$(git -C $r rev-parse main)" ] &&
[ "$(git -C $r log main -1 --format=%s)" = "Merge feature/discount-banner" ] &&
[ "$(git -C $r rev-list --parents -n 1 main | wc -w)" = 3 ] &&
[ "$(git -C $r log main^1 -1 --format=%s)" = "Change greeting wording" ] &&
[ "$(git -C $r log main^2 -1 --format=%s)" = "Add discount banner" ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git switch main && git pull, then git merge --no-ff feature/discount-banner -m "Merge feature/discount-banner", then git push.', 'Because the branch was rebased onto the latest main, the merge cannot conflict. --no-ff keeps one merge commit as the unit of the pull request.', 20, false, true),
('47f4dd60-c208-5a9b-b80c-5761d679d1dd', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 8, 'Tag the release', $md$Create an annotated tag v1.1.0 with the message "Release 1.1.0" on the current main tip and push it to origin.$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r cat-file -t v1.1.0)" = tag ] &&
git -C $r tag -n1 v1.1.0 | grep -q 'Release 1.1.0' &&
[ "$(git -C $r ls-remote origin 'refs/tags/v1.1.0^{}' | cut -f1)" = "$(git -C $r rev-parse main)" ]
$script$, 'git tag -a v1.1.0 -m "Release 1.1.0", then git push origin v1.1.0 (tags are not pushed by a plain git push).', 'An annotated tag is a real object with a tagger, date and message, which is what releases should use. Tags are pushed explicitly.', 15, false, true),
('beb80b5f-c387-54a0-a0da-8996c7fb9d9d', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 9, 'Revert a bad commit pushed to main', $md$Run ~/bin/teammate land-bad - it pushes a commit "Switch to experimental rounding" that breaks check.sh on main. Pull it, revert that commit (do not rewrite history) and push so check.sh passes again on origin/main.$md$, $script$o=/home/labuser/srv/git/storefront.git
git --git-dir=$o log main --format=%s | grep -qx 'Revert "Switch to experimental rounding"' &&
git --git-dir=$o log main --format=%s | grep -qx 'Switch to experimental rounding' &&
[ "$(git --git-dir=$o rev-parse main)" = "$(git -C /home/labuser/work/storefront rev-parse main)" ] &&
d=$(mktemp -d) && git --git-dir=$o archive main | tar -x -C $d && (cd $d && sh check.sh | grep -qx OK)
$script$, '~/bin/teammate land-bad, git pull, git log --oneline to find the bad hash, git revert <hash>, git push. Run sh check.sh to confirm.', 'main is shared and already pulled by others, so you add a new commit that undoes the bad one. History stays append-only and the fix can ship immediately.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('54c2960c-8c22-5cf6-9a52-1e7813c77002', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 1, $json$[{"id":"f1a90460-ec4b-5e7f-be18-8b810ec8a8d6","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":1,"title":"Build the feature on a branch","description":"Clone /home/labuser/srv/git/storefront.git into ~/work/storefront. Create branch feature/discount-banner with exactly three commits: add banner.txt, tweak banner.txt (a \"WIP\" commit), and change the GREETING line in app.sh to GREETING=\"Welcome to the store\".","verification_script":"r=/home/labuser/work/storefront\n[ \"$(git -C $r rev-list --count origin/main..feature/discount-banner)\" = 3 ] \u0026\u0026\ngit -C $r show feature/discount-banner:banner.txt \u003e/dev/null \u0026\u0026\ngit -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING=\"Welcome to the store\"'\n","hint_context":"git clone, git switch -c feature/discount-banner, then three separate git commit invocations. Use sed -i or an editor for the GREETING change.","explanation_context":"Small, separate commits are normal while working; you will tidy them before the review.","points":15,"is_optional":false,"is_stateful":true},{"id":"3e787a98-3c96-5a16-bcd0-e1e3951f3013","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":2,"title":"Push the branch (open the pull request)","description":"Publish feature/discount-banner to origin and set its upstream - on a real server this is what lets you open a pull request.","verification_script":"r=/home/labuser/work/storefront\n[ \"$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)\" = \"$(git -C $r rev-parse feature/discount-banner)\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse feature/discount-banner@{upstream})\" = \"$(git -C $r rev-parse feature/discount-banner)\" ]\n","hint_context":"git push -u origin feature/discount-banner","explanation_context":"A pull request is just a branch on the server plus a request to merge it. Everything else (review, CI) happens around that branch.","points":10,"is_optional":false,"is_stateful":true},{"id":"90a5a745-5d4e-55a7-b39e-7543262d5a58","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":3,"title":"A teammate lands a change on main","description":"Run the helper ~/bin/teammate land-greeting (it pushes a commit to origin/main, changing the same GREETING line). Then fetch so you can see it in origin/main.","verification_script":"r=/home/labuser/work/storefront\ngit -C $r log origin/main --format=%s | grep -qx \"Change greeting wording\" \u0026\u0026\n[ \"$(git -C $r rev-parse origin/main)\" = \"$(git -C $r ls-remote origin refs/heads/main | cut -f1)\" ]\n","hint_context":"~/bin/teammate land-greeting, then git fetch, then git log --oneline --graph --all.","explanation_context":"While your branch was open, main moved. Your branch is now based on an older main and touches a line that changed on both sides.","points":10,"is_optional":false,"is_stateful":true},{"id":"5223d9e1-2b63-5b83-8b29-3ead2d836db8","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":4,"title":"Rebase the branch and resolve the conflict","description":"Rebase feature/discount-banner onto origin/main. The greeting commit conflicts; resolve app.sh so GREETING is \"Hello, welcome to the store\" (keep the round line unchanged), continue the rebase, and end with the same three commits on top of origin/main.","verification_script":"r=/home/labuser/work/storefront\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\ngit -C $r merge-base --is-ancestor origin/main feature/discount-banner \u0026\u0026\n[ \"$(git -C $r rev-list --count origin/main..feature/discount-banner)\" = 3 ] \u0026\u0026\ngit -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING=\"Hello, welcome to the store\"' \u0026\u0026\ngit -C $r show feature/discount-banner:app.sh | grep -q '^round()' \u0026\u0026\n[ -z \"$(git -C $r grep -nE '^(\u003c\u003c\u003c\u003c\u003c\u003c\u003c|=======|\u003e\u003e\u003e\u003e\u003e\u003e\u003e)' feature/discount-banner)\" ]\n","hint_context":"git switch feature/discount-banner \u0026\u0026 git rebase origin/main. Fix app.sh, git add app.sh, GIT_EDITOR=true git rebase --continue.","explanation_context":"Rebasing replays your three commits on the new main so the final merge is trivial and history stays linear. The conflict is the same one a merge would have raised.","points":20,"is_optional":false,"is_stateful":true},{"id":"dfbaba7f-41e8-5db1-93c8-008a00bea4c6","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":5,"title":"Squash the branch into one commit","description":"Use interactive rebase to squash the three commits into a single commit with the message \"Add discount banner\".","verification_script":"r=/home/labuser/work/storefront\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\n[ \"$(git -C $r rev-list --count origin/main..feature/discount-banner)\" = 1 ] \u0026\u0026\n[ \"$(git -C $r log feature/discount-banner -1 --format=%s)\" = \"Add discount banner\" ] \u0026\u0026\ngit -C $r show feature/discount-banner:banner.txt \u003e/dev/null \u0026\u0026\ngit -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING=\"Hello, welcome to the store\"'\n","hint_context":"git rebase -i origin/main, change the 2nd and 3rd pick to fixup (or squash), then reword the remaining commit.","explanation_context":"Reviewers and git bisect prefer one coherent commit per change. Squashing removes the WIP noise before it lands on main.","points":15,"is_optional":false,"is_stateful":true},{"id":"def03691-0b8a-5fa4-b2ab-00f35d7cb19c","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":6,"title":"Update the remote branch safely","description":"The remote branch still has the old three commits. Update it with --force-with-lease.","verification_script":"r=/home/labuser/work/storefront\n[ \"$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)\" = \"$(git -C $r rev-parse feature/discount-banner)\" ] \u0026\u0026\n[ \"$(git -C $r log origin/feature/discount-banner -1 --format=%s)\" = \"Add discount banner\" ]\n","hint_context":"git push --force-with-lease origin feature/discount-banner","explanation_context":"Rewriting your own feature branch after review feedback is normal; the lease protects against overwriting a reviewer's pushed fixup.","points":10,"is_optional":false,"is_stateful":true},{"id":"34efc9e3-90c1-55fb-aa4c-3f571e6e6870","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":7,"title":"Merge the pull request into main","description":"Update local main from origin, then merge feature/discount-banner into main with --no-ff and the message \"Merge feature/discount-banner\", and push main.","verification_script":"r=/home/labuser/work/storefront\n[ \"$(git -C $r ls-remote origin refs/heads/main | cut -f1)\" = \"$(git -C $r rev-parse main)\" ] \u0026\u0026\n[ \"$(git -C $r log main -1 --format=%s)\" = \"Merge feature/discount-banner\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --parents -n 1 main | wc -w)\" = 3 ] \u0026\u0026\n[ \"$(git -C $r log main^1 -1 --format=%s)\" = \"Change greeting wording\" ] \u0026\u0026\n[ \"$(git -C $r log main^2 -1 --format=%s)\" = \"Add discount banner\" ] \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"git switch main \u0026\u0026 git pull, then git merge --no-ff feature/discount-banner -m \"Merge feature/discount-banner\", then git push.","explanation_context":"Because the branch was rebased onto the latest main, the merge cannot conflict. --no-ff keeps one merge commit as the unit of the pull request.","points":20,"is_optional":false,"is_stateful":true},{"id":"47f4dd60-c208-5a9b-b80c-5761d679d1dd","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":8,"title":"Tag the release","description":"Create an annotated tag v1.1.0 with the message \"Release 1.1.0\" on the current main tip and push it to origin.","verification_script":"r=/home/labuser/work/storefront\n[ \"$(git -C $r cat-file -t v1.1.0)\" = tag ] \u0026\u0026\ngit -C $r tag -n1 v1.1.0 | grep -q 'Release 1.1.0' \u0026\u0026\n[ \"$(git -C $r ls-remote origin 'refs/tags/v1.1.0^{}' | cut -f1)\" = \"$(git -C $r rev-parse main)\" ]\n","hint_context":"git tag -a v1.1.0 -m \"Release 1.1.0\", then git push origin v1.1.0 (tags are not pushed by a plain git push).","explanation_context":"An annotated tag is a real object with a tagger, date and message, which is what releases should use. Tags are pushed explicitly.","points":15,"is_optional":false,"is_stateful":true},{"id":"beb80b5f-c387-54a0-a0da-8996c7fb9d9d","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":9,"title":"Revert a bad commit pushed to main","description":"Run ~/bin/teammate land-bad - it pushes a commit \"Switch to experimental rounding\" that breaks check.sh on main. Pull it, revert that commit (do not rewrite history) and push so check.sh passes again on origin/main.","verification_script":"o=/home/labuser/srv/git/storefront.git\ngit --git-dir=$o log main --format=%s | grep -qx 'Revert \"Switch to experimental rounding\"' \u0026\u0026\ngit --git-dir=$o log main --format=%s | grep -qx 'Switch to experimental rounding' \u0026\u0026\n[ \"$(git --git-dir=$o rev-parse main)\" = \"$(git -C /home/labuser/work/storefront rev-parse main)\" ] \u0026\u0026\nd=$(mktemp -d) \u0026\u0026 git --git-dir=$o archive main | tar -x -C $d \u0026\u0026 (cd $d \u0026\u0026 sh check.sh | grep -qx OK)\n","hint_context":"~/bin/teammate land-bad, git pull, git log --oneline to find the bad hash, git revert \u003chash\u003e, git push. Run sh check.sh to confirm.","explanation_context":"main is shared and already pulled by others, so you add a new commit that undoes the bad one. History stays append-only and the fix can ship immediately.","points":25,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('3b335974-a7c9-5414-a3fb-1e1e222943a1', '54c2960c-8c22-5cf6-9a52-1e7813c77002', 'f1a90460-ec4b-5e7f-be18-8b810ec8a8d6', 1, 'Build the feature on a branch', $md$Clone /home/labuser/srv/git/storefront.git into ~/work/storefront. Create branch feature/discount-banner with exactly three commits: add banner.txt, tweak banner.txt (a "WIP" commit), and change the GREETING line in app.sh to GREETING="Welcome to the store".$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r rev-list --count origin/main..feature/discount-banner)" = 3 ] &&
git -C $r show feature/discount-banner:banner.txt >/dev/null &&
git -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING="Welcome to the store"'
$script$, 'git clone, git switch -c feature/discount-banner, then three separate git commit invocations. Use sed -i or an editor for the GREETING change.', 'Small, separate commits are normal while working; you will tidy them before the review.', 15, false, true),
('0f26bc79-ced6-5741-8df0-e81afdd96ad3', '54c2960c-8c22-5cf6-9a52-1e7813c77002', '3e787a98-3c96-5a16-bcd0-e1e3951f3013', 2, 'Push the branch (open the pull request)', $md$Publish feature/discount-banner to origin and set its upstream - on a real server this is what lets you open a pull request.$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)" = "$(git -C $r rev-parse feature/discount-banner)" ] &&
[ "$(git -C $r rev-parse feature/discount-banner@{upstream})" = "$(git -C $r rev-parse feature/discount-banner)" ]
$script$, 'git push -u origin feature/discount-banner', 'A pull request is just a branch on the server plus a request to merge it. Everything else (review, CI) happens around that branch.', 10, false, true),
('ef3badec-661f-5956-894a-6e159955288a', '54c2960c-8c22-5cf6-9a52-1e7813c77002', '90a5a745-5d4e-55a7-b39e-7543262d5a58', 3, 'A teammate lands a change on main', $md$Run the helper ~/bin/teammate land-greeting (it pushes a commit to origin/main, changing the same GREETING line). Then fetch so you can see it in origin/main.$md$, $script$r=/home/labuser/work/storefront
git -C $r log origin/main --format=%s | grep -qx "Change greeting wording" &&
[ "$(git -C $r rev-parse origin/main)" = "$(git -C $r ls-remote origin refs/heads/main | cut -f1)" ]
$script$, '~/bin/teammate land-greeting, then git fetch, then git log --oneline --graph --all.', 'While your branch was open, main moved. Your branch is now based on an older main and touches a line that changed on both sides.', 10, false, true),
('7a8b3d3e-7059-50fc-a280-7a4b3b05bf37', '54c2960c-8c22-5cf6-9a52-1e7813c77002', '5223d9e1-2b63-5b83-8b29-3ead2d836db8', 4, 'Rebase the branch and resolve the conflict', $md$Rebase feature/discount-banner onto origin/main. The greeting commit conflicts; resolve app.sh so GREETING is "Hello, welcome to the store" (keep the round line unchanged), continue the rebase, and end with the same three commits on top of origin/main.$md$, $script$r=/home/labuser/work/storefront
[ ! -d $r/.git/rebase-merge ] &&
git -C $r merge-base --is-ancestor origin/main feature/discount-banner &&
[ "$(git -C $r rev-list --count origin/main..feature/discount-banner)" = 3 ] &&
git -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING="Hello, welcome to the store"' &&
git -C $r show feature/discount-banner:app.sh | grep -q '^round()' &&
[ -z "$(git -C $r grep -nE '^(<<<<<<<|=======|>>>>>>>)' feature/discount-banner)" ]
$script$, 'git switch feature/discount-banner && git rebase origin/main. Fix app.sh, git add app.sh, GIT_EDITOR=true git rebase --continue.', 'Rebasing replays your three commits on the new main so the final merge is trivial and history stays linear. The conflict is the same one a merge would have raised.', 20, false, true),
('a7564021-9195-5d7c-b26e-1496070472b0', '54c2960c-8c22-5cf6-9a52-1e7813c77002', 'dfbaba7f-41e8-5db1-93c8-008a00bea4c6', 5, 'Squash the branch into one commit', $md$Use interactive rebase to squash the three commits into a single commit with the message "Add discount banner".$md$, $script$r=/home/labuser/work/storefront
[ ! -d $r/.git/rebase-merge ] &&
[ "$(git -C $r rev-list --count origin/main..feature/discount-banner)" = 1 ] &&
[ "$(git -C $r log feature/discount-banner -1 --format=%s)" = "Add discount banner" ] &&
git -C $r show feature/discount-banner:banner.txt >/dev/null &&
git -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING="Hello, welcome to the store"'
$script$, 'git rebase -i origin/main, change the 2nd and 3rd pick to fixup (or squash), then reword the remaining commit.', 'Reviewers and git bisect prefer one coherent commit per change. Squashing removes the WIP noise before it lands on main.', 15, false, true),
('739caf5a-e19a-5ad0-aa82-754834daca79', '54c2960c-8c22-5cf6-9a52-1e7813c77002', 'def03691-0b8a-5fa4-b2ab-00f35d7cb19c', 6, 'Update the remote branch safely', $md$The remote branch still has the old three commits. Update it with --force-with-lease.$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)" = "$(git -C $r rev-parse feature/discount-banner)" ] &&
[ "$(git -C $r log origin/feature/discount-banner -1 --format=%s)" = "Add discount banner" ]
$script$, 'git push --force-with-lease origin feature/discount-banner', 'Rewriting your own feature branch after review feedback is normal; the lease protects against overwriting a reviewer''s pushed fixup.', 10, false, true),
('e7483c86-2aa9-5229-a831-43a952056fdc', '54c2960c-8c22-5cf6-9a52-1e7813c77002', '34efc9e3-90c1-55fb-aa4c-3f571e6e6870', 7, 'Merge the pull request into main', $md$Update local main from origin, then merge feature/discount-banner into main with --no-ff and the message "Merge feature/discount-banner", and push main.$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r ls-remote origin refs/heads/main | cut -f1)" = "$(git -C $r rev-parse main)" ] &&
[ "$(git -C $r log main -1 --format=%s)" = "Merge feature/discount-banner" ] &&
[ "$(git -C $r rev-list --parents -n 1 main | wc -w)" = 3 ] &&
[ "$(git -C $r log main^1 -1 --format=%s)" = "Change greeting wording" ] &&
[ "$(git -C $r log main^2 -1 --format=%s)" = "Add discount banner" ] &&
[ -z "$(git -C $r status --porcelain)" ]
$script$, 'git switch main && git pull, then git merge --no-ff feature/discount-banner -m "Merge feature/discount-banner", then git push.', 'Because the branch was rebased onto the latest main, the merge cannot conflict. --no-ff keeps one merge commit as the unit of the pull request.', 20, false, true),
('3b430220-5751-56d5-8ec5-92612bd9de8d', '54c2960c-8c22-5cf6-9a52-1e7813c77002', '47f4dd60-c208-5a9b-b80c-5761d679d1dd', 8, 'Tag the release', $md$Create an annotated tag v1.1.0 with the message "Release 1.1.0" on the current main tip and push it to origin.$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r cat-file -t v1.1.0)" = tag ] &&
git -C $r tag -n1 v1.1.0 | grep -q 'Release 1.1.0' &&
[ "$(git -C $r ls-remote origin 'refs/tags/v1.1.0^{}' | cut -f1)" = "$(git -C $r rev-parse main)" ]
$script$, 'git tag -a v1.1.0 -m "Release 1.1.0", then git push origin v1.1.0 (tags are not pushed by a plain git push).', 'An annotated tag is a real object with a tagger, date and message, which is what releases should use. Tags are pushed explicitly.', 15, false, true),
('504c0041-9c6b-58a9-8a22-4788761b5772', '54c2960c-8c22-5cf6-9a52-1e7813c77002', 'beb80b5f-c387-54a0-a0da-8996c7fb9d9d', 9, 'Revert a bad commit pushed to main', $md$Run ~/bin/teammate land-bad - it pushes a commit "Switch to experimental rounding" that breaks check.sh on main. Pull it, revert that commit (do not rewrite history) and push so check.sh passes again on origin/main.$md$, $script$o=/home/labuser/srv/git/storefront.git
git --git-dir=$o log main --format=%s | grep -qx 'Revert "Switch to experimental rounding"' &&
git --git-dir=$o log main --format=%s | grep -qx 'Switch to experimental rounding' &&
[ "$(git --git-dir=$o rev-parse main)" = "$(git -C /home/labuser/work/storefront rev-parse main)" ] &&
d=$(mktemp -d) && git --git-dir=$o archive main | tar -x -C $d && (cd $d && sh check.sh | grep -qx OK)
$script$, '~/bin/teammate land-bad, git pull, git log --oneline to find the bad hash, git revert <hash>, git push. Run sh check.sh to confirm.', 'main is shared and already pulled by others, so you add a new commit that undoes the bad one. History stays append-only and the fix can ship immediately.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '54c2960c-8c22-5cf6-9a52-1e7813c77002', updated_at = now()
WHERE id = 'dd19c2d2-b23f-540c-a234-9c4126c54766' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b2514430-3a8d-5ec2-abef-1b11498475ab', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '8231161f-ca60-5da8-bf27-4161f81d0844', 'Course Review: Flashcards for Spaced Recall', 'notes', 1, $md$## How to use this page

Cover the right column and answer each prompt out loud, then check. Mark the
ones you missed and come back to them tomorrow, in three days and in a week.
Spaced, effortful recall beats re-reading.

## Core model

| Prompt | Answer |
|---|---|
| What is a commit? | A full snapshot (root tree) + parent(s) + author/committer + message, named by its hash |
| What is a branch? | A movable ref (41-byte file) holding one commit hash |
| What is HEAD? | A pointer to the current branch (or directly to a commit when detached) |
| The three areas | Working tree -> index (staging) -> repository |
| Four object types | blob (content), tree (names), commit, annotated tag |
| Why does rewriting change hashes? | A hash covers content and parent hash, so any change ripples forward |
| `origin/main` is... | Your last-known snapshot of the server's main; moves only on fetch/pull/push |

## Everyday commands

| Prompt | Answer |
|---|---|
| See what the next commit will contain | `git diff --staged` |
| Stage part of a file | `git add -p` |
| Fix the last unpushed commit | `git commit --amend` |
| Untrack a committed file, keep it on disk | `git rm --cached <file>` (+ `.gitignore`) |
| Publish a new branch with tracking | `git push -u origin <branch>` |
| Download without integrating | `git fetch` |
| pull = | fetch + merge (or rebase) |
| Push rejected "fetch first" | Integrate (pull/rebase), then push. Never `--force` on shared branches |

## Branching, merging, rebasing

| Prompt | Answer |
|---|---|
| When is a merge a fast-forward? | When the current branch is an ancestor of the merged branch |
| `--no-ff` vs `--squash` | Always a merge commit vs one plain commit with no link to the branch |
| Conflict markers: top half is... | Ours = HEAD = the branch you are on (in a merge) |
| ours/theirs during a rebase | Flipped: ours = new base, theirs = your commit |
| Golden rule of rebase | Never rebase commits others have built on |
| squash vs fixup | Both meld; squash keeps the message, fixup drops it |
| Safe overwrite of a pushed branch | `git push --force-with-lease` (+ `--force-if-includes`) |
| Remember conflict resolutions | `git config rerere.enabled true` |

## Undo and recovery

| Prompt | Answer |
|---|---|
| Discard an uncommitted edit | `git restore <file>` (permanent) |
| Unstage | `git restore --staged <file>` |
| reset modes | soft: staged stays; mixed: edits stay unstaged; hard: everything goes |
| Undo a pushed commit | `git revert <hash>` (`-m 1` for merges) |
| Lost commits after reset/rebase | `git reflog`, then `reset --hard` or `branch` to the hash |
| Dropped stash | `git fsck --no-reflogs --unreachable`, then `git stash apply <hash>` |
| Copy one commit to another branch | `git cherry-pick -x <hash>` |
| Park unfinished work incl. new files | `git stash push -u -m "msg"` |
| What Git can never recover | Edits that were never staged or committed |

## Investigation

| Prompt | Answer |
|---|---|
| Who last changed line 10? | `git blame -L10,10 <file>` (`-w` reformat, `-C` moved code) |
| When was a string added/removed? | `git log -S '<string>'` |
| When did a line's value change? | `git log -G '<regex>'` |
| History across a rename | `git log --follow -- <file>` |
| Find the breaking commit | `git bisect start BAD GOOD` + `git bisect run <test>`; exit 0 good, 125 skip |

## Team practice and scale

| Prompt | Answer |
|---|---|
| GitHub flow in one line | Branch -> PR with review and CI -> merge -> deploy main |
| Release tag | `git tag -a v1.2.0 -m "..."`, then `git push origin v1.2.0` |
| SemVer | MAJOR breaking, MINOR features, PATCH fixes |
| Share hooks | Versioned folder + `core.hooksPath`; enforce for real in CI |
| SSH signing | `gpg.format ssh`, `user.signingKey`, `commit.gpgSign true` |
| Second checkout of the same repo | `git worktree add ../dir -b branch` |
| Submodule stores | `.gitmodules` URL + a gitlink commit hash |
| Huge repo, full history, fast clone | `git clone --filter=blob:none` (+ sparse-checkout) |
| Big binaries | Git LFS, set up before the first commit |
| Committed a secret | Rotate first, then `git filter-repo`, then prevent |

## Self-check

1. Explain to a friend, in three sentences, why `git reset --hard` is usually
   recoverable but `git restore <file>` is not.
2. Draw the graph before and after rebasing a two-commit branch onto a main that
   gained one commit.
3. Your team deploys main ten times a day. Which branching strategy and which
   merge settings would you propose, and why?
$md$, 12, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('99f0680f-294c-513d-ade4-5b7bce1020e0', '00000000-0000-0000-0000-000000000001', 'mcq', 'You edited three files and ran `git add a.py`. You then run `git commit -m ''U...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('458b4ff0-9c42-5063-847b-15300b53e43a', '99f0680f-294c-513d-ade4-5b7bce1020e0', 1, $json${"prompt":"You edited three files and ran `git add a.py`. You then run `git commit -m 'Update'`. What is in the commit?","multiple":false,"options":[{"id":"a","text":"All three files","is_correct":false},{"id":"b","text":"Only the change to a.py, as it was when you staged it","is_correct":true},{"id":"c","text":"Nothing; you must use -a","is_correct":false},{"id":"d","text":"a.py and any new files","is_correct":false}],"explanation":"A commit snapshots the index. Unstaged edits stay in the working tree. -a is optional and only adds tracked modified files; new files are never added implicitly."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e591864d-98c0-56ad-906d-8733ab670c21', '00000000-0000-0000-0000-000000000001', 'mcq', 'You rename README.md to README.txt without changing content and commit. How m...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ffb48162-75cc-5445-838d-baa2053ce226', 'e591864d-98c0-56ad-906d-8733ab670c21', 1, $json${"prompt":"You rename README.md to README.txt without changing content and commit. How many NEW blob objects does Git store?","multiple":false,"options":[{"id":"a","text":"Zero; the content is identical, so the existing blob is reused","is_correct":true},{"id":"b","text":"One, for the new name","is_correct":false},{"id":"c","text":"Two, old and new","is_correct":false},{"id":"d","text":"It depends on the file size","is_correct":false}],"explanation":"Blobs are named by content. Names live in trees, so only a new tree and a new commit are created."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b337f95b-3054-5be8-90ee-5cd24c8c7793', '00000000-0000-0000-0000-000000000001', 'mcq', '`git status` says ''Your branch and origin/main have diverged, and have 2 and ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b239d488-b4b4-5857-b9ea-03927c0f63d0', 'b337f95b-3054-5be8-90ee-5cd24c8c7793', 1, $json${"prompt":"`git status` says 'Your branch and origin/main have diverged, and have 2 and 3 different commits each'. Your 2 commits are unpushed. Which command gives a linear history safely?","multiple":false,"options":[{"id":"a","text":"git push --force","is_correct":false},{"id":"b","text":"git pull --rebase","is_correct":true},{"id":"c","text":"git reset --hard origin/main","is_correct":false},{"id":"d","text":"git merge --squash origin/main","is_correct":false}],"explanation":"pull --rebase replays your unpushed commits on top of the 3 remote ones. Force-push deletes the teammates' commits, reset --hard throws away yours, and a squash merge creates an odd unlinked commit."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('53ab4861-1e6e-5e1b-a92e-ec2edfd6e916', '00000000-0000-0000-0000-000000000001', 'mcq', 'During `git rebase main`, a conflict in pricing.py stops the rebase. You want...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7c00b658-e905-5a7e-bb2e-f31c3dd600b3', '53ab4861-1e6e-5e1b-a92e-ec2edfd6e916', 1, $json${"prompt":"During `git rebase main`, a conflict in pricing.py stops the rebase. You want YOUR feature commit's version of that file. Which command?","multiple":false,"options":[{"id":"a","text":"git checkout --ours pricing.py","is_correct":false},{"id":"b","text":"git checkout --theirs pricing.py","is_correct":true},{"id":"c","text":"git rebase --skip","is_correct":false},{"id":"d","text":"git merge --abort","is_correct":false}],"explanation":"In a rebase, theirs is the commit being replayed (yours) and ours is the base. --skip drops your entire commit and merge --abort does not apply to rebases."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0a51d80d-cf60-564f-8d30-a7a19297e918', '00000000-0000-0000-0000-000000000001', 'mcq', 'A feature merged into main last week (merge commit M) must be removed from pr...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('53c9ad49-f0aa-53dd-b353-daac3d94bf9a', '0a51d80d-cf60-564f-8d30-a7a19297e918', 1, $json${"prompt":"A feature merged into main last week (merge commit M) must be removed from production. main is shared. What do you do?","multiple":false,"options":[{"id":"a","text":"git reset --hard M^1 and force-push","is_correct":false},{"id":"b","text":"git revert -m 1 M and push","is_correct":true},{"id":"c","text":"git revert M (no options)","is_correct":false},{"id":"d","text":"git branch -D feature","is_correct":false}],"explanation":"-m 1 keeps main's side and undoes what the feature brought in, as a new commit. Reset + force rewrites shared history, revert without -m is refused for merges, and deleting the branch leaves the merged code in main."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('fec5d5a3-1ac6-5fb5-a275-9227de0e75af', '00000000-0000-0000-0000-000000000001', 'mcq', 'You ran `git reset --hard HEAD~4` on your local branch and immediately regret...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e5401c43-b65b-5299-9b68-63bc9ce5d97a', 'fec5d5a3-1ac6-5fb5-a275-9227de0e75af', 1, $json${"prompt":"You ran `git reset --hard HEAD~4` on your local branch and immediately regret it. What is the fastest recovery?","multiple":false,"options":[{"id":"a","text":"git reset --hard ORIG_HEAD (or the hash from git reflog)","is_correct":true},{"id":"b","text":"git revert HEAD~4","is_correct":false},{"id":"c","text":"git fetch","is_correct":false},{"id":"d","text":"Re-clone from the server","is_correct":false}],"explanation":"reset records ORIG_HEAD and the reflog has the old tip. revert adds inverse commits, fetch only updates remote-tracking refs, and the server lacks your unpushed commits."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6eab352f-dfa5-538e-a0ed-6987ea800c75', '00000000-0000-0000-0000-000000000001', 'mcq', 'A config value changed from max_conn=10 to max_conn=50 at some point last yea...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('39f9b47e-fd7a-5e86-8ab0-16b74a7ff52c', '6eab352f-dfa5-538e-a0ed-6987ea800c75', 1, $json${"prompt":"A config value changed from max_conn=10 to max_conn=50 at some point last year. Which command finds the commit?","multiple":false,"options":[{"id":"a","text":"git log -S 'max_conn='","is_correct":false},{"id":"b","text":"git log -G 'max_conn='","is_correct":true},{"id":"c","text":"git blame -C config.ini","is_correct":false},{"id":"d","text":"git log --follow config.ini","is_correct":false}],"explanation":"The number of 'max_conn=' occurrences did not change, so -S misses it; -G matches changed lines. blame shows only the latest change and --follow is about renames (though it lists all commits touching the file, it does not search content)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6fd17d2e-1935-5ac2-8157-d45a90ce9c41', '00000000-0000-0000-0000-000000000001', 'mcq', 'There are 500 commits between a good tag and the broken HEAD. You have a test...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e8c67e41-ff97-5f95-af6c-7be4095362d6', '6fd17d2e-1935-5ac2-8157-d45a90ce9c41', 1, $json${"prompt":"There are 500 commits between a good tag and the broken HEAD. You have a test script. What gets you to the culprit fastest?","multiple":false,"options":[{"id":"a","text":"git bisect start HEAD v2.0 \u0026\u0026 git bisect run ./test.sh","is_correct":true},{"id":"b","text":"git log -p and read every diff","is_correct":false},{"id":"c","text":"git blame on every file","is_correct":false},{"id":"d","text":"git revert each commit until the test passes","is_correct":false}],"explanation":"bisect run needs about 9 test runs (log2 500). Reading diffs or blaming is slow and unreliable, and reverting commits one by one is destructive and linear."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b8dbb5fb-ba79-59b9-9972-44373f8ee72d', '00000000-0000-0000-0000-000000000001', 'mcq', 'You rebased your already-pushed PR branch. A reviewer pushed a fixup commit t...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5ef3d7de-a1ec-5399-aa56-b0bf058f1017', 'b8dbb5fb-ba79-59b9-9972-44373f8ee72d', 1, $json${"prompt":"You rebased your already-pushed PR branch. A reviewer pushed a fixup commit to it 5 minutes ago that you have not fetched. What happens with `git push --force-with-lease`?","multiple":false,"options":[{"id":"a","text":"The reviewer's commit is overwritten","is_correct":false},{"id":"b","text":"The push is rejected as stale, protecting the reviewer's commit","is_correct":true},{"id":"c","text":"Git merges the two automatically","is_correct":false},{"id":"d","text":"The push succeeds and keeps both","is_correct":false}],"explanation":"The lease checks the server still points where your origin/\u003cbranch\u003e says. It does not, so the push is refused. Plain --force would overwrite; Git never merges during push."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6bb57fb2-d365-508b-b70b-27566afc92d9', '00000000-0000-0000-0000-000000000001', 'mcq', 'You created an annotated tag v3.0.0 and ran `git push`. Teammates cannot see ...', 'beginner', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('8a4b25a5-4703-593b-bb3f-dde357c056d6', '6bb57fb2-d365-508b-b70b-27566afc92d9', 1, $json${"prompt":"You created an annotated tag v3.0.0 and ran `git push`. Teammates cannot see the tag. Why?","multiple":false,"options":[{"id":"a","text":"Annotated tags are local only","is_correct":false},{"id":"b","text":"Plain git push does not push tags; run git push origin v3.0.0 (or use --follow-tags)","is_correct":true},{"id":"c","text":"Tags need a separate remote","is_correct":false},{"id":"d","text":"Teammates must run git tag --sync","is_correct":false}],"explanation":"Tags are pushed explicitly. Annotated tags can be pushed like any ref, no separate remote is needed, and --sync does not exist."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e218d7f6-4488-59df-9722-b527e9fd5195', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your team wants the commit-message rule enforced for every contributor, even ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0bfba9b3-e998-5765-8062-0e15607a24c4', 'e218d7f6-4488-59df-9722-b527e9fd5195', 1, $json${"prompt":"Your team wants the commit-message rule enforced for every contributor, even those who use --no-verify. Where must it be enforced?","multiple":false,"options":[{"id":"a","text":"In a committed .githooks/commit-msg only","is_correct":false},{"id":"b","text":"In CI or a server-side check, with branch protection requiring it","is_correct":true},{"id":"c","text":"In each developer's global config","is_correct":false},{"id":"d","text":"In .gitattributes","is_correct":false}],"explanation":"Client hooks are skippable and opt-in. Only server-side or required CI checks apply to everyone; config and attributes cannot enforce message rules."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b6ea58e1-4473-522c-9598-d855be868904', '00000000-0000-0000-0000-000000000001', 'mcq', 'You need to fix a production bug while your feature branch has uncommitted wo...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2dc6ba09-73f3-51ae-91ef-afe23af19f4b', 'b6ea58e1-4473-522c-9598-d855be868904', 1, $json${"prompt":"You need to fix a production bug while your feature branch has uncommitted work and a running dev server. Which tool keeps your current folder untouched?","multiple":false,"options":[{"id":"a","text":"git worktree add ../hotfix -b hotfix/bug main","is_correct":true},{"id":"b","text":"git switch main","is_correct":false},{"id":"c","text":"git clone --depth 1","is_correct":false},{"id":"d","text":"git submodule add","is_correct":false}],"explanation":"A worktree is a second checkout of the same repository in another folder. Switching changes your current files, a shallow clone is a separate repo without your local branches, and submodules embed other repositories."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f57125ac-18b9-5605-9a48-c7c27313f4f4', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your CI clone of a 20 GB repository takes 10 minutes; the build needs only th...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('916fc12a-38a3-5c3d-ad41-93425629db38', 'f57125ac-18b9-5605-9a48-c7c27313f4f4', 1, $json${"prompt":"Your CI clone of a 20 GB repository takes 10 minutes; the build needs only the latest files of two folders. What helps most?","multiple":false,"options":[{"id":"a","text":"git clone --depth 1 --filter=blob:none --sparse, then git sparse-checkout set \u003ctwo folders\u003e","is_correct":true},{"id":"b","text":"git gc --aggressive on the server every night","is_correct":false},{"id":"c","text":"git clone --mirror","is_correct":false},{"id":"d","text":"Moving to Git LFS for all files","is_correct":false}],"explanation":"Shallow + partial + sparse downloads and checks out only what the build needs. gc helps size slightly, --mirror downloads everything, and LFS is for large binaries, not general source."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0622229b-2926-5224-b857-493d53e6b6ed', '00000000-0000-0000-0000-000000000001', 'mcq', 'A database password was pushed in a commit an hour ago. Put these in the righ...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5b09d3b2-39de-5f96-862c-86ad52e967c1', '0622229b-2926-5224-b857-493d53e6b6ed', 1, $json${"prompt":"A database password was pushed in a commit an hour ago. Put these in the right order: (A) git filter-repo and force-push, (B) rotate the password, (C) enable secret scanning/push protection.","multiple":false,"options":[{"id":"a","text":"A, B, C","is_correct":false},{"id":"b","text":"B, A, C","is_correct":true},{"id":"c","text":"C, A, B","is_correct":false},{"id":"d","text":"A, C, B","is_correct":false}],"explanation":"Rotate first: the secret must be assumed compromised. Then clean history to limit future exposure, then prevent the next leak."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('888188be-71fa-5f4a-b413-444493ad1944', '00000000-0000-0000-0000-000000000001', 'mcq', 'You committed two commits on local main that belong on feature/x, nothing pus...', 'intermediate', 2, ARRAY['git','version-control','cli'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ac5132c1-10fb-5791-8487-591d5ca9c6db', '888188be-71fa-5f4a-b413-444493ad1944', 1, $json${"prompt":"You committed two commits on local main that belong on feature/x, nothing pushed. Which sequence fixes it?","multiple":false,"options":[{"id":"a","text":"git branch feature/x; git reset --hard origin/main","is_correct":true},{"id":"b","text":"git revert HEAD~2..HEAD; git switch -c feature/x","is_correct":false},{"id":"c","text":"git push; git switch -c feature/x","is_correct":false},{"id":"d","text":"git stash; git switch -c feature/x; git stash pop","is_correct":false}],"explanation":"Label the commits with a branch, then move main back. revert adds inverse commits to main, pushing publishes the mistake, and stash only handles uncommitted changes."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('60132e6e-5f92-58c6-b46c-5020564de2f0', '00000000-0000-0000-0000-000000000001', 'Final Exam: Git', 'git-capstone-final-exam', 'Quiz covering Capstone: Team Workflow.', 'mcq', 'published', 'module', '4b761e29-c0f6-5fad-bd39-6b2727b84320', 30, 70, 5, 30, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '60132e6e-5f92-58c6-b46c-5020564de2f0' AND question_id NOT IN ('99f0680f-294c-513d-ade4-5b7bce1020e0', 'e591864d-98c0-56ad-906d-8733ab670c21', 'b337f95b-3054-5be8-90ee-5cd24c8c7793', '53ab4861-1e6e-5e1b-a92e-ec2edfd6e916', '0a51d80d-cf60-564f-8d30-a7a19297e918', 'fec5d5a3-1ac6-5fb5-a275-9227de0e75af', '6eab352f-dfa5-538e-a0ed-6987ea800c75', '6fd17d2e-1935-5ac2-8157-d45a90ce9c41', 'b8dbb5fb-ba79-59b9-9972-44373f8ee72d', '6bb57fb2-d365-508b-b70b-27566afc92d9', 'e218d7f6-4488-59df-9722-b527e9fd5195', 'b6ea58e1-4473-522c-9598-d855be868904', 'f57125ac-18b9-5605-9a48-c7c27313f4f4', '0622229b-2926-5224-b857-493d53e6b6ed', '888188be-71fa-5f4a-b413-444493ad1944');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('95595e7c-ea95-5ce7-8c99-05ead6c4466e', '60132e6e-5f92-58c6-b46c-5020564de2f0', '99f0680f-294c-513d-ade4-5b7bce1020e0', '458b4ff0-9c42-5063-847b-15300b53e43a', 0, 2),
('ff40a75b-4011-5996-adcf-7e7e595d4583', '60132e6e-5f92-58c6-b46c-5020564de2f0', 'e591864d-98c0-56ad-906d-8733ab670c21', 'ffb48162-75cc-5445-838d-baa2053ce226', 1, 2),
('55001765-1e04-5e95-addb-31887e484c58', '60132e6e-5f92-58c6-b46c-5020564de2f0', 'b337f95b-3054-5be8-90ee-5cd24c8c7793', 'b239d488-b4b4-5857-b9ea-03927c0f63d0', 2, 2),
('cdd75a05-c96f-5e56-81fe-250f50f590de', '60132e6e-5f92-58c6-b46c-5020564de2f0', '53ab4861-1e6e-5e1b-a92e-ec2edfd6e916', '7c00b658-e905-5a7e-bb2e-f31c3dd600b3', 3, 2),
('6f3f5341-daf0-5e39-9502-bde287685c7c', '60132e6e-5f92-58c6-b46c-5020564de2f0', '0a51d80d-cf60-564f-8d30-a7a19297e918', '53c9ad49-f0aa-53dd-b353-daac3d94bf9a', 4, 2),
('ce06abb4-1afb-50ff-aea1-321f922262b0', '60132e6e-5f92-58c6-b46c-5020564de2f0', 'fec5d5a3-1ac6-5fb5-a275-9227de0e75af', 'e5401c43-b65b-5299-9b68-63bc9ce5d97a', 5, 2),
('8a969c32-b019-51a9-b9ae-f36bfb4ec4e8', '60132e6e-5f92-58c6-b46c-5020564de2f0', '6eab352f-dfa5-538e-a0ed-6987ea800c75', '39f9b47e-fd7a-5e86-8ab0-16b74a7ff52c', 6, 2),
('c34dee7b-bc97-50c2-908d-5a2ecb525423', '60132e6e-5f92-58c6-b46c-5020564de2f0', '6fd17d2e-1935-5ac2-8157-d45a90ce9c41', 'e8c67e41-ff97-5f95-af6c-7be4095362d6', 7, 2),
('334f1696-7ad3-5488-91e6-a26004eb5074', '60132e6e-5f92-58c6-b46c-5020564de2f0', 'b8dbb5fb-ba79-59b9-9972-44373f8ee72d', '5ef3d7de-a1ec-5399-aa56-b0bf058f1017', 8, 2),
('9a47bfb8-29fa-5407-b80a-4e5f12a2d3ec', '60132e6e-5f92-58c6-b46c-5020564de2f0', '6bb57fb2-d365-508b-b70b-27566afc92d9', '8a4b25a5-4703-593b-bb3f-dde357c056d6', 9, 2),
('5dc77685-6e46-591a-9c4b-9d26d82c9d96', '60132e6e-5f92-58c6-b46c-5020564de2f0', 'e218d7f6-4488-59df-9722-b527e9fd5195', '0bfba9b3-e998-5765-8062-0e15607a24c4', 10, 2),
('fef54391-5f97-52e8-a532-fbea8b94cb57', '60132e6e-5f92-58c6-b46c-5020564de2f0', 'b6ea58e1-4473-522c-9598-d855be868904', '2dc6ba09-73f3-51ae-91ef-afe23af19f4b', 11, 2),
('b76ee9b6-33a9-5781-88ba-d6cd655ebe66', '60132e6e-5f92-58c6-b46c-5020564de2f0', 'f57125ac-18b9-5605-9a48-c7c27313f4f4', '916fc12a-38a3-5c3d-ad41-93425629db38', 12, 2),
('598087f0-ba0c-55bd-8c49-abaf1d69ac95', '60132e6e-5f92-58c6-b46c-5020564de2f0', '0622229b-2926-5224-b857-493d53e6b6ed', '5b09d3b2-39de-5f96-862c-86ad52e967c1', 13, 2),
('ef95c824-6d20-5df6-9643-ef8bfcccd199', '60132e6e-5f92-58c6-b46c-5020564de2f0', '888188be-71fa-5f4a-b413-444493ad1944', 'ac5132c1-10fb-5791-8487-591d5ca9c6db', 14, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('4b761e29-c0f6-5fad-bd39-6b2727b84320', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '8231161f-ca60-5da8-bf27-4161f81d0844', 'Final Exam: Git', 'assessment', 2, 25, '60132e6e-5f92-58c6-b46c-5020564de2f0')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Cheat Sheet
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('0bb14d20-e0f6-573d-b293-2dd7b7d0a02b', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Cheat Sheet', 15, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2462e786-3387-523e-acf7-0bb1e9635c31', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0bb14d20-e0f6-573d-b293-2dd7b7d0a02b', 'One-Page Git Cheat Sheet', 'notes', 0, $md$> **Everything from the course, as reference.** Keep it open until the commands
> are muscle memory. Lessons explain the why; this page is for looking up.

Safety legend: **safe** changes nothing you cannot recover, **rewrites** creates
new commits and leaves the old ones only in the reflog, **destructive** can lose
uncommitted work.

## Setup

| Command | What it does |
|---|---|
| `git config --global user.name "Name"` / `user.email` | Identity stored in every commit |
| `git config --global init.defaultBranch main` | First branch name for new repos |
| `git config --global pull.rebase true` | `pull` rebases instead of merging |
| `git config --global push.autoSetupRemote true` | First push of a new branch sets upstream |
| `git config --global merge.conflictStyle zdiff3` | Conflicts also show the ancestor |
| `git config --global rerere.enabled true` | Remember conflict resolutions |
| `git config --list --show-origin` | Every setting and its file |

## Inspect (read-only)

| Command | What it changes | Safety |
|---|---|---|
| `git status` / `git status -s` | Nothing, shows the three areas | safe |
| `git diff` / `git diff --staged` | Nothing, working vs index / index vs HEAD | safe |
| `git log --oneline --graph --all` | Nothing, draws the commit graph | safe |
| `git log main..feature` | Nothing, commits on feature not on main | safe |
| `git show <rev>` / `git show <rev>:<path>` | Nothing, one commit or file version | safe |
| `git blame -L a,b -w -C <file>` | Nothing, who last changed each line | safe |
| `git log -S str` / `-G regex` / `--follow file` / `-L :func:file` | Nothing, searches history | safe |
| `git reflog` | Nothing, where HEAD has been | safe |
| `git cat-file -p <obj>` / `git ls-files -s` | Nothing, raw objects / index | safe |

```
 working tree --git diff--> index --git diff --staged--> HEAD
```

```knowledge-check
{ "questions": [
  { "id": "git-cheat-inspect-q1", "type": "mcq",
    "prompt": "Which command shows what is staged for the next commit?",
    "options": [
      {"id":"a","text":"git diff --staged"},
      {"id":"b","text":"git diff"},
      {"id":"c","text":"git reflog"},
      {"id":"d","text":"git blame"}],
    "correct": "a",
    "explanation": "git diff alone shows unstaged changes; reflog lists HEAD moves and blame annotates lines." }
] }
```

## Record and share

| Command | What it changes | Safety |
|---|---|---|
| `git add <path>` / `git add -p` | Index | safe |
| `git commit -m msg` | Adds a commit, moves the branch | safe |
| `git commit --amend` | Replaces the last commit | rewrites |
| `git rm --cached <file>` | Untracks, keeps file on disk | safe |
| `git clone <url>` (`--depth 1`, `--filter=blob:none`) | Creates a repo with origin and tracking branches | safe |
| `git remote -v` / `add` / `set-url` | Remote names and URLs | safe |
| `git fetch` (`--prune`) | Remote-tracking branches only | safe |
| `git pull` (`--rebase`, `--ff-only`) | fetch + merge (or rebase) into current branch | safe, may conflict |
| `git push` / `git push -u origin <branch>` | Remote branch (fast-forward only) | safe |
| `git push --force-with-lease --force-if-includes` | Overwrites the remote branch if unchanged since your fetch | rewrites (shared) |
| `git push --force` | Overwrites the remote branch blindly | destructive for teammates |
| `git push origin --delete <branch>` | Deletes a server branch | destructive (server) |

```
 local commits --git push--> origin        origin --git fetch--> origin/* --merge/rebase--> branch
```

```knowledge-check
{ "questions": [
  { "id": "git-cheat-share-q1", "type": "mcq",
    "prompt": "Which command updates origin/main in your clone without touching your own branches?",
    "options": [
      {"id":"a","text":"git fetch"},
      {"id":"b","text":"git pull"},
      {"id":"c","text":"git merge"},
      {"id":"d","text":"git reset --hard"}],
    "correct": "a",
    "explanation": "pull would also integrate into the current branch; merge and reset change your branch." }
] }
```

## Branch, merge, rebase

| Command | What it changes | Safety |
|---|---|---|
| `git switch -c <name> [start]` | New branch pointer, moves HEAD | safe |
| `git merge <branch>` | Fast-forwards or adds a merge commit | safe, may conflict |
| `git merge --no-ff` / `--ff-only` / `--squash` | Always merge commit / never / one plain commit | safe |
| `git merge --abort` | Returns to the pre-merge state | safe |
| `git checkout --ours <file>` / `--theirs` | Takes one side during a conflict | safe |
| `git branch -d <name>` | Deletes a merged branch pointer | safe |
| `git branch -D <name>` | Deletes an unmerged branch pointer | destructive (recoverable via reflog) |
| `git rebase <base>` | Replays your commits with new hashes | rewrites |
| `git rebase -i <base>` (`--autosquash`) | Squash, reword, reorder, drop | rewrites |
| `git rebase --onto <new> <old> <branch>` | Moves only a branch's own commits | rewrites |
| `git rebase --continue` / `--skip` / `--abort` | Continue / drop commit / go back | safe |

```
 merge:   A---B---M          rebase:   A---B---C'---D'
           \     /                     (C, D replaced by copies)
            C---D
```

```knowledge-check
{ "questions": [
  { "id": "git-cheat-branch-q1", "type": "mcq",
    "prompt": "Which of these should never be done to a branch others have already pulled?",
    "options": [
      {"id":"a","text":"Rebase it and force push"},
      {"id":"b","text":"Merge into it"},
      {"id":"c","text":"Revert a commit on it"},
      {"id":"d","text":"Tag it"}],
    "correct": "a",
    "explanation": "Rewriting shared history makes everyone else's copy diverge. Merging, reverting and tagging only add history." }
] }
```

## Undo and recover

| Command | What it changes | Safety |
|---|---|---|
| `git restore <file>` (`--source=<rev>`) | Working tree file from index (or a commit) | destructive (uncommitted edits lost) |
| `git restore --staged <file>` | Index only | safe |
| `git clean -n` / `-fd` | Lists / deletes untracked files | destructive |
| `git reset --soft <rev>` | Branch pointer only, changes stay staged | rewrites |
| `git reset --mixed <rev>` (default) | Branch + index, changes stay in working tree | rewrites |
| `git reset --hard <rev>` | Branch + index + working tree | destructive |
| `git revert <rev>` / `git revert -m 1 <merge>` | Adds a commit that undoes another | safe (shared branches) |
| `git cherry-pick -x <rev>` | Copies one commit onto the current branch | safe, may conflict |
| `git stash push -u -m msg` / `git stash pop` | Parks / restores uncommitted work | safe |
| `git reflog` + `git reset --hard <hash>` | Recovers commits lost by reset, rebase or amend | safe within the expiry (30 days unreachable) |
| `git fsck --no-reflogs --unreachable` | Finds dangling commits (dropped stashes) | safe |
| `git bisect start BAD GOOD` + `git bisect run <cmd>` | Temporarily checks out commits, then `git bisect reset` | safe |

```
              HEAD    INDEX    WORKING TREE
 --soft       moves   keeps    keeps
 --mixed      moves   reset    keeps
 --hard       moves   reset    reset
```

Which undo? **Not committed** -> restore. **Committed, not pushed** -> reset /
amend / rebase -i. **Pushed to a shared branch** -> revert.

```knowledge-check
{ "questions": [
  { "id": "git-cheat-undo-q1", "type": "mcq",
    "prompt": "You ran reset --hard and need the commits back. What do you do?",
    "options": [
      {"id":"a","text":"git reflog, find the hash, git reset --hard <hash>"},
      {"id":"b","text":"git clone again"},
      {"id":"c","text":"git gc"},
      {"id":"d","text":"Nothing, they are gone"}],
    "correct": "a",
    "explanation": "The reflog keeps old positions of HEAD until they expire. A fresh clone lacks unpushed commits and gc could delete them." },
  { "id": "git-cheat-undo-q2", "type": "mcq",
    "prompt": "Which undo is safe on a shared branch?",
    "options": [
      {"id":"a","text":"git revert"},
      {"id":"b","text":"git reset --hard plus force push"},
      {"id":"c","text":"git commit --amend plus force push"},
      {"id":"d","text":"git rebase -i plus force push"}],
    "correct": "a",
    "explanation": "revert only appends history; the others rewrite commits teammates already have." }
] }
```

## Releases, hooks, signing

| Command | What it does |
|---|---|
| `git tag -a v1.2.0 -m msg [rev]` | Annotated release tag |
| `git push origin v1.2.0` / `--follow-tags` | Publish tags |
| `git describe` | Nearest tag + distance, e.g. `v1.2.0-3-g9d4b0c2` |
| `git config core.hooksPath .githooks` | Use versioned hooks |
| `git commit --no-verify` | Skips client hooks (why CI must enforce) |
| `git config --global gpg.format ssh` + `user.signingKey` + `commit.gpgSign true` | Sign commits with SSH |
| `git verify-commit HEAD` / `git log --show-signature` | Check signatures |

## Scale and structure

| Command | What it does |
|---|---|
| `git worktree add ../dir -b branch [start]` / `list` / `remove` | Extra checkouts of one repo |
| `git submodule add <url> <path>` | Pin another repo at a commit |
| `git clone --recurse-submodules` / `git submodule update --init --recursive` | Fetch submodule contents |
| `git clone --filter=blob:none` | Partial clone: contents on demand |
| `git sparse-checkout set <dirs>` | Only some folders on disk |
| `git maintenance start` | Background repo upkeep |
| `git lfs track "*.psd"` | Store big binaries outside history |
| `git filter-repo --invert-paths --path <file>` | Remove a file from all history (after rotating secrets) |
$md$, 10, $json$[{"id":"git-cheat-inspect-q1","type":"mcq","correct":"a"},{"id":"git-cheat-share-q1","type":"mcq","correct":"a"},{"id":"git-cheat-branch-q1","type":"mcq","correct":"a"},{"id":"git-cheat-undo-q1","type":"mcq","correct":"a"},{"id":"git-cheat-undo-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('77fd5af5-36a1-58bd-8e72-f1087ec57d24', '00000000-0000-0000-0000-000000000014', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

DELETE FROM course_modules WHERE course_id = 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44' AND id NOT IN ('d6dc6197-76ec-5c0b-8983-66c2a01b5a38', '1c094615-76a8-5b1f-8648-dafea434db57', '0f965b49-b633-5fb1-82b3-2b65dcf9af2e', '0d98c661-e4d9-5afb-b37d-daa8aa72b66d', 'a9550002-456c-5497-9e5b-c003a8ee3911', '5a838085-8cf1-5b89-826b-3cd3fc75a0b7', '659a4382-f208-55a0-8b4a-959595e3ee51', '4a5cf9bb-5097-5349-9cfc-c053e5dd500a', 'a246bc5f-7923-5df0-9f3b-464b8fccb699', '74b2f660-185b-521e-8bba-942899d63e41', '72b998d1-c7e1-597d-9061-ca868befdaa3', '1d8b92d2-c0e0-5c8d-a6ab-5cd7178913ab', '5e0fd21a-c311-570b-afc8-2810dc21eab6', '65110615-38ef-5178-bc97-6e91ff88397c', '0b58b4f0-df56-5e5b-a3aa-d2f262507f7b', '47d223f7-3f28-5818-8db6-b6749b2830cb', '0cc26ec8-10e6-5ba0-9bba-6594b7666c7d', '07675baf-17f1-59ee-b3cd-f6a001ad47b2', '947b350f-4ed2-52fc-a567-1835f9dc5805', 'f256ea86-e619-5891-91da-63c4bcaac387', '47c62acd-63ce-5106-abed-6470491a63dc', '52cae17c-b055-5328-bae9-2f3b5be104f8', 'e7308f90-9b11-586e-a880-349ba6e409b0', 'cb571aa7-e3b5-5f39-a2cc-dfcb18bf5ce4', '1db9f751-9cff-5192-b741-bc7fb7400c76', 'cfc858d6-1d98-5314-bc5c-48de47f625c1', '3e253d61-0096-5930-a0c8-71326f790755', '74fb2616-b5a3-50ad-a6ed-381dfce33769', '20ad5e4c-0262-5bcd-8650-8c54dac29f73', '500a4b7b-7cfd-592d-814b-a3d8396d6537', 'c093176a-bb3b-5ea2-872c-e5dae4804077', '0476992a-d624-5231-9954-81609f76eba5', 'f9c6c023-3368-50eb-bde8-3f297f6ed5ea', 'e5a7bc3d-8d91-5d20-aae7-6d0e4957ad07', '06333fa0-0a73-5674-8283-1273b143ddca', '55df3884-66ec-5229-87e6-269aac20c1fb', '48da31e4-f78a-5e0d-9848-adb9a0866d71', '9c513ab8-e630-5148-b54a-cda3727cf505', '86e78574-a4f8-5c6a-9b7a-7100dd51962d', '7e585198-89cd-5b29-a6ee-139fcba6245d', '619ea6a0-66c9-5105-ac7d-e8430ee6ee3c', '444e98ed-bd14-56fd-ab33-637c7e30f968', '57793e90-a4e4-54ea-8067-00633a4dfcf4', 'cbd2e806-7598-55ef-9e8b-02aba5067f5c', '461a1a8c-3466-5f4d-8982-e9f2063c6d21', 'f02760d9-646a-5b96-9caf-9dc2b1c09e96', 'a9dbf033-3c13-5141-b45d-b5b6a1e8d407', '8c6e0590-7180-5b22-8458-4d3ad9353d1f', 'c88b17d1-e601-5190-8efa-b6f4d275192e', '860fbf9f-197a-5bc2-bfa6-2cf196f6eada', '0067b420-0f5e-52bc-a262-582ab17dc51b', '575d0948-fdbb-511c-a687-a5c46700fb79', 'e9c35a89-dd93-5e9a-bcb3-722e6879a5f3', '22e0a992-56e3-559d-8189-3eebb0232e71', '5531cbf5-4631-5f85-9266-50bad4dd2776', '2df84d55-b6ad-5e0b-98f8-fd4de8dc2d6c', '89a9d394-e5fa-5c01-bba3-37bcdfb18e5c', '0f1c8982-6dc1-57e7-a0a0-286515db7b75', '5390022b-f895-5bd5-9d13-e3b338776aab', 'fa392afe-ceae-5502-a3ee-fad508319da3', '42932fd5-7539-5e4e-94a6-23ebcf6adb20', '8155f7ed-47e1-5f8d-9c55-e2131a82b967', 'c3c96639-7da2-5670-a5d4-ff195ed6f239', 'cc041893-9627-556a-aacc-8628ed11567e', 'a681d69d-1026-54a9-b13e-7ca9038ca38f', '8627ebc6-e7af-5c09-9dce-264ff7489106', '2ba53323-54d5-56ba-8688-991b02a47555', '05a166ac-81a6-5466-9507-cf531dbab488', '80d4a547-b1e4-5290-bc65-4040eb18d56e', '6d5dda11-b14a-5131-aa88-7b55ea3b1fe0', 'b2514430-3a8d-5ec2-abef-1b11498475ab', '4b761e29-c0f6-5fad-bd39-6b2727b84320', '2462e786-3387-523e-acf7-0bb1e9635c31');
DELETE FROM course_sections WHERE course_id = 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44' AND id NOT IN ('0384711a-2cc2-592c-ab3b-3c6fe336cbcc', '30bd438b-14f7-5688-bfd5-d78aef9b27d3', '578c95ce-e505-5625-828c-b7e7a369f64b', 'd7c6f575-b087-5a71-9221-aabdc36b6f72', '498e7765-54bf-5ac3-a80c-bab3bb98f650', '0bfdc51c-0996-5a60-beac-0ac183d3389c', 'e0b3c433-037f-599c-a7bf-214e35421662', 'bc66d97b-4855-5638-8fbb-d9d46ae7f1b7', '7a77d065-f51b-5ec5-9aea-a09bdcfb797c', '462878a1-6134-50d3-953c-444b70b83668', 'b512cc2b-eecf-5fd0-8acd-e11f22b48966', 'b2ad8505-d4d2-5871-a812-03fb6c8db169', 'be6c1623-145f-564c-b5fb-dc4ae6b24ddb', '8231161f-ca60-5da8-bf27-4161f81d0844', '0bb14d20-e0f6-573d-b293-2dd7b7d0a02b');

