-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-10-09T18:03:13Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Git: Commits, Branches, Merges, Rebase and Recovery ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, is_public, estimated_hours)
VALUES ('ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Git: Commits, Branches, Merges, Rebase and Recovery', 'git', 'A hands-on Git course taught entirely in real terminals. Every section pairs a short, diagram-led lesson with graded labs that inspect your actual repository: first commits, clones and remotes, branching and merging, resolving conflicts, rebasing (including interactive rebase), undoing and recovering work with restore, reset, revert, reflog, cherry-pick and stash, investigating history with blame, log -S/-G and bisect, and a capstone team workflow against a local origin.', NULL, 'beginner', ARRAY['git','version-control','cli'], 'published', true, false, 6.7)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, is_public=EXCLUDED.is_public, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

UPDATE course_sections SET position = position + 100000 WHERE course_id = 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44';
UPDATE course_modules SET position = position + 100000 WHERE course_id = 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44';

-- Section: Setup and First Commits
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('30bd438b-14f7-5688-bfd5-d78aef9b27d3', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Setup and First Commits', 1, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('74b2f660-185b-521e-8bba-942899d63e41', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '30bd438b-14f7-5688-bfd5-d78aef9b27d3', 'Init, Stage, Commit, Amend, Ignore', 'notes', 0, $md$## The three areas

Git tracks your work in three places. Files move between them with explicit commands:

```
 WORKING TREE            INDEX (staging)             REPOSITORY (.git)
 files you edit   --->   next commit's snapshot --->  permanent history
                 git add                    git commit
       <---------------- git restore -----------------
```

`git init` creates the repository, `git status` tells you what sits in each area, and `git diff`
compares two of them.

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
    "explanation": "A commit is built from the index. Edits you did not git add are not part of it." }
] }
```

[[lab-task:1]]

What you should see after `git init hello` and `git status`:

```
Initialized empty Git repository in /home/labuser/work/hello/.git/
On branch main

No commits yet

nothing to commit (create/copy files and use "git add" to track)
```

## Identity and your first commit

Every commit stores an author. Configure it once:

```bash
git config --global user.name  "Ada Student"
git config --global user.email "ada@example.com"
git config --list --show-origin | grep user
```

[[lab-task:2]]

Then create and commit a file. Before and after:

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

[[lab-task:3]]

What you should see (the hash will differ):

```
3f1c9ab (HEAD -> main) Add README
```

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
    "explanation": "user.name and user.email are read from config at commit time and baked into the commit object." }
] }
```

## Ignoring files with .gitignore

Logs, build output and secrets should never be committed. List patterns in `.gitignore`:

```
*.log
build/
```

Ignore rules only apply to files Git is not already tracking. Verify a rule with
`git check-ignore -v app.log`.

[[lab-task:4]]

What you should see from `git status` once the rules exist and everything is committed:

```
On branch main
nothing to commit, working tree clean
```

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
    "explanation": ".gitignore only affects untracked files. A tracked file keeps being tracked until you remove it from the index with git rm --cached." }
] }
```

## status and diff: reading the three areas

```
 working tree --git diff--> index --git diff --staged--> HEAD

 README.md  (edited, added)       -> shows under "Changes to be committed"
 main.sh    (edited, not added)   -> shows under "Changes not staged"
```

```bash
echo "Learning git" >> README.md && git add README.md
echo "echo done" >> main.sh
git status -s
git diff            # main.sh only (unstaged)
git diff --staged   # README.md only (staged)
```

[[lab-task:5]]

What you should see from `git status -s`:

```
M  README.md
 M main.sh
```

The left column is the index versus HEAD, the right column is working tree versus index.

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
    "explanation": "Use git diff --staged to see index versus HEAD." }
] }
```

## Fixing the last commit with --amend

```
BEFORE amend                         AFTER git commit --amend

 A---B---C  <- main                   A---B---C'  <- main
                                           \
                                            C (orphaned, still in reflog)
```

```bash
git commit -m "Update readme"
git add main.sh
git commit --amend -m "Update README and script"
git log --oneline
```

[[lab-task:6]]

What you should see:

```
b94e2d1 (HEAD -> main) Update README and script
7a03c55 Add main script and gitignore
3f1c9ab Add README
```

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
    "explanation": "The amended commit is a different object. Anyone who already has the old one now has diverging history." }
] }
```
$md$, 40, $json$[{"id":"git-first-areas-q1","type":"mcq","correct":"b"},{"id":"git-first-commit-q1","type":"mcq","correct":"b"},{"id":"git-first-ignore-q1","type":"mcq","correct":"b"},{"id":"git-first-diff-q1","type":"mcq","correct":"a"},{"id":"git-first-amend-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('f5d6201c-312b-5a8a-a6ab-266493edfa55', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '74b2f660-185b-521e-8bba-942899d63e41', 'module', 'Init, Stage, Commit, Amend, Ignore', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$git config --system init.defaultBranch main
git config --system safe.directory '*'
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

-- Section: Clone and Remotes
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('d7c6f575-b087-5a71-9221-aabdc36b6f72', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Clone and Remotes', 2, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('947b350f-4ed2-52fc-a567-1835f9dc5805', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'd7c6f575-b087-5a71-9221-aabdc36b6f72', 'Clone, Fetch, Pull, Push and Tracking Branches', 'notes', 0, $md$## A remote is just another repository

`origin` is a nickname for a URL (here a bare repository on disk, in real life GitHub or GitLab).
Your clone keeps a read-only copy of each remote branch as `origin/<name>` (a remote-tracking
branch). It only moves when you `fetch`, `pull` or `push`.

```
        origin  (/srv/git/origin.git)
        A---B---C  <- main
                 \
                  D  <- feature/login
   ============================================
        your clone
        A---B---C  <- main, origin/main
                 \
                  D  <- origin/feature/login
```

```bash
git clone /srv/git/origin.git app
cd app
git remote -v
git branch -a
```

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
    "explanation": "Remote-tracking branches are only updated when you talk to the remote (fetch, pull, push)." }
] }
```

[[lab-task:1]]

What you should see from `git remote -v`:

```
origin  /srv/git/origin.git (fetch)
origin  /srv/git/origin.git (push)
```

## Tracking branches

A local branch can name an upstream. `git switch feature/login` in a clone where only
`origin/feature/login` exists creates it for you:

```
before:  main -> origin/main            (feature/login only as origin/feature/login)
after :  main -> origin/main
         feature/login -> origin/feature/login   (new tracking branch)
```

```bash
git switch feature/login
git branch -vv
```

[[lab-task:2]]

What you should see:

```
* feature/login 5d2e9a1 [origin/feature/login] Add login form
  main          8c1f7b3 [origin/main] Add license
```

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
    "explanation": "The upstream is what status, pull and push compare against." }
] }
```

## fetch vs pull, and a rejected push

`fetch` only updates `origin/*`. `pull` is `fetch` followed by a merge (or rebase) into your branch.

```
You commit locally, a teammate pushes first:

            origin/main (server)           your clone
 before:    A---B---C---T                  A---B---C---N   <- main
                                                       \
                                           origin/main -> C   (stale)

 git push  -> REJECTED: server has T that you do not have (non-fast-forward)

 git fetch:                                A---B---C---N   <- main
                                                \
                                                 T         <- origin/main
```

```bash
teammate-push
git push            # rejected - read the message
git fetch
git log --oneline --graph --all
```

[[lab-task:3]]
[[lab-task:4]]

What you should see from the rejected push and the graph:

```
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to '/srv/git/origin.git'

* 9d4b0c2 (origin/main) Teammate: add changelog
| * 41ae6f8 (HEAD -> main) Add notes.txt
|/
* 8c1f7b3 Add license
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
    "explanation": "fetch is safe: it never changes your branches or files." },
  { "id": "git-clone-fetch-q2", "type": "mcq",
    "prompt": "A push is rejected with 'fetch first'. What is the usual fix?",
    "options": [
      {"id":"a","text":"git push --force"},
      {"id":"b","text":"Delete the remote"},
      {"id":"c","text":"Integrate the remote work (pull, or fetch + merge/rebase) and push again"},
      {"id":"d","text":"Re-clone the repository"}],
    "correct": "c",
    "explanation": "Force pushing would erase the teammate's commit. Integrate first, then push a fast-forward." }
] }
```

## Integrating and pushing

```
 before pull               after git pull (merge)          after git push
 N <- main                 M <- main  (merge commit)       server main = M
 T <- origin/main           / \                            (fast-forward)
                           N   T <- origin/main
```

```bash
git pull --no-rebase
git push
git log --oneline --graph
```

[[lab-task:5]]

What you should see:

```
*   c7e21d0 (HEAD -> main, origin/main) Merge branch 'main' of /srv/git/origin
|\
| * 9d4b0c2 Teammate: add changelog
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
    "explanation": "pull = fetch + integrate. Knowing the two halves lets you inspect before integrating." }
] }
```

## Publishing a new branch

```
 before:  feature/search            (local only)
 after :  feature/search -> origin/feature/search     git push -u origin feature/search
```

```bash
git switch -c feature/search
echo search > search.txt && git add search.txt && git commit -m "Add search stub"
git push -u origin feature/search
git ls-remote origin
```

[[lab-task:6]]

What you should see from `git ls-remote origin` (hashes differ):

```
c7e21d0...	HEAD
c7e21d0...	refs/heads/main
5d2e9a1...	refs/heads/feature/login
e0b64f9...	refs/heads/feature/search
```

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
    "explanation": "-u is short for --set-upstream and writes the tracking configuration." }
] }
```
$md$, 45, $json$[{"id":"git-clone-remote-q1","type":"mcq","correct":"b"},{"id":"git-clone-track-q1","type":"mcq","correct":"a"},{"id":"git-clone-fetch-q1","type":"mcq","correct":"b"},{"id":"git-clone-fetch-q2","type":"mcq","correct":"c"},{"id":"git-clone-pull-q1","type":"mcq","correct":"a"},{"id":"git-clone-publish-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '947b350f-4ed2-52fc-a567-1835f9dc5805', 'module', 'Clone, Fetch, Pull, Push and Tracking Branches', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --system init.defaultBranch main
git config --system safe.directory '*'
git config --system pull.rebase false
git config --system user.name "Lab Student"
git config --system user.email "student@lab.local"
rm -rf /srv/git /home/labuser/work/app /tmp/seed
mkdir -p /srv/git
git init -q --bare /srv/git/origin.git
git clone -q /srv/git/origin.git /tmp/seed 2>/dev/null
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
git --git-dir=/srv/git/origin.git symbolic-ref HEAD refs/heads/main
cat > /usr/local/bin/teammate-push <<'SCRIPT'
#!/bin/bash
# Simulates a teammate pushing a commit to origin/main.
set -e
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
git clone -q /srv/git/origin.git "$t/w" 2>/dev/null; cd "$t/w"
if git log --format=%s | grep -qx "Teammate: add changelog"; then echo "teammate already pushed"; exit 0; fi
echo "# Changelog" > CHANGELOG.md; git add -A
GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com \
GIT_AUTHOR_DATE="2024-01-10T10:00:00+0000" GIT_COMMITTER_DATE="2024-01-10T10:00:00+0000" git commit -q -m "Teammate: add changelog"
git push -q origin main
echo "teammate pushed to origin/main"
SCRIPT
chmod 755 /usr/local/bin/teammate-push
chmod -R a+rwX /srv/git
$script$, NULL, 45, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '292d0dec-8892-5e07-b9f1-c367e915691b' AND id NOT IN ('9bdbbf8f-61fb-58f8-93b7-bb3642c64ac6', 'e33683d5-72e4-5e9f-86d8-ce8ab93750fd', 'ba243adf-812f-547b-94d8-14e1f1153cfa', '365f0f9d-f97b-5c6a-b8cf-76af5f30ec5e', '3cd8124f-c316-576e-b447-a7c74f3dfb34', '266084c9-e3c5-576a-b499-943755c5dbc8');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '292d0dec-8892-5e07-b9f1-c367e915691b';
DELETE FROM lab_tasks WHERE lab_id = '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab' AND id NOT IN ('4fab9e36-245a-5109-9ed1-72c9448e763c', 'e2c240b8-c9b9-5c7a-aeca-f8667b4f31da', '9080cd27-8ebf-5570-a221-54d126263d25', '1895b7cf-e85c-5ec6-b6e1-288dcb22efa7', '1366dcc7-86a3-5f9b-9412-09b3734824a6', '812f0aba-9a39-5e39-9b18-39f4817967ec');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4fab9e36-245a-5109-9ed1-72c9448e763c', '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', 1, 'Clone the shared repository', $md$The team repository lives at /srv/git/origin.git (a bare repository acting as "the server"). Clone it into a directory called app inside your work directory.$md$, $script$r=/home/labuser/work/app
[ "$(git -C $r remote get-url origin)" = /srv/git/origin.git ] &&
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
('1895b7cf-e85c-5ec6-b6e1-288dcb22efa7', '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', 4, 'Fetch a teammate''s work without merging', $md$Run the helper command teammate-push (it simulates a colleague pushing to origin/main). Then try git push - it will be rejected. Run git fetch (not pull) so origin/main updates while your own main stays untouched.$md$, $script$r=/home/labuser/work/app
o=$(git -C $r ls-remote origin refs/heads/main | cut -f1)
[ "$(git -C $r rev-parse origin/main)" = "$o" ] &&
[ "$(git -C $r rev-parse main)" != "$o" ] &&
git -C $r log origin/main --format=%s | grep -qx "Teammate: add changelog" &&
[ "$(git -C $r log main -1 --format=%s)" = "Add notes.txt" ]
$script$, 'teammate-push is already on your PATH. After git push is rejected, git fetch updates origin/main but never touches your branches. Compare with git log --oneline --graph --all.', 'Push is rejected (non-fast-forward) because origin/main has a commit you lack. fetch downloads it into the remote-tracking branch only; pull would also merge it into your branch.', 20, false, true),
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
VALUES ('292d0dec-8892-5e07-b9f1-c367e915691b', '6c5b265a-1410-5ebf-b84d-e855e2ddd1ab', 1, $json$[{"id":"4fab9e36-245a-5109-9ed1-72c9448e763c","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":1,"title":"Clone the shared repository","description":"The team repository lives at /srv/git/origin.git (a bare repository acting as \"the server\"). Clone it into a directory called app inside your work directory.","verification_script":"r=/home/labuser/work/app\n[ \"$(git -C $r remote get-url origin)\" = /srv/git/origin.git ] \u0026\u0026\n[ \"$(git -C $r symbolic-ref HEAD)\" = refs/heads/main ] \u0026\u0026\n[ \"$(git -C $r rev-list --count HEAD)\" = 3 ]\n","hint_context":"git clone \u003curl\u003e \u003cdirectory\u003e. A local path works as a URL. Afterwards run git remote -v to see where origin points.","explanation_context":"Clone copies all history, creates the remote named origin, remote-tracking refs (origin/main ...) and checks out main with main tracking origin/main.","points":10,"is_optional":false,"is_stateful":true},{"id":"e2c240b8-c9b9-5c7a-aeca-f8667b4f31da","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":2,"title":"Check out a remote branch","description":"origin also has a branch feature/login. Create a local branch feature/login that tracks origin/feature/login (git switch can do this for you).","verification_script":"r=/home/labuser/work/app\n[ \"$(git -C $r config branch.feature/login.remote)\" = origin ] \u0026\u0026\n[ \"$(git -C $r config branch.feature/login.merge)\" = refs/heads/feature/login ] \u0026\u0026\ngit -C $r log feature/login --format=%s | grep -qx \"Add login form\"\n","hint_context":"git branch -a lists remote-tracking branches. git switch feature/login creates a tracking branch when only origin/feature/login exists.","explanation_context":"A tracking branch remembers its upstream, so git status can say \"ahead 1, behind 2\" and plain git pull / git push know where to go.","points":10,"is_optional":false,"is_stateful":true},{"id":"9080cd27-8ebf-5570-a221-54d126263d25","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":3,"title":"Commit locally on main","description":"Switch back to main and commit a new file notes.txt (any content) with the message \"Add notes.txt\". Do not push yet.","verification_script":"r=/home/labuser/work/app\n[ \"$(git -C $r rev-list --count origin/main..main)\" = 1 ] \u0026\u0026\n[ \"$(git -C $r log main -1 --format=%s)\" = \"Add notes.txt\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --count main..origin/main)\" = 0 ]\n","hint_context":"git switch main, then create, add and commit the file. git status should now say \"ahead of origin/main by 1 commit\".","explanation_context":"Commits are local until pushed. origin/main is only your last known copy of the remote branch, so main being ahead is normal.","points":10,"is_optional":false,"is_stateful":true},{"id":"1895b7cf-e85c-5ec6-b6e1-288dcb22efa7","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":4,"title":"Fetch a teammate's work without merging","description":"Run the helper command teammate-push (it simulates a colleague pushing to origin/main). Then try git push - it will be rejected. Run git fetch (not pull) so origin/main updates while your own main stays untouched.","verification_script":"r=/home/labuser/work/app\no=$(git -C $r ls-remote origin refs/heads/main | cut -f1)\n[ \"$(git -C $r rev-parse origin/main)\" = \"$o\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse main)\" != \"$o\" ] \u0026\u0026\ngit -C $r log origin/main --format=%s | grep -qx \"Teammate: add changelog\" \u0026\u0026\n[ \"$(git -C $r log main -1 --format=%s)\" = \"Add notes.txt\" ]\n","hint_context":"teammate-push is already on your PATH. After git push is rejected, git fetch updates origin/main but never touches your branches. Compare with git log --oneline --graph --all.","explanation_context":"Push is rejected (non-fast-forward) because origin/main has a commit you lack. fetch downloads it into the remote-tracking branch only; pull would also merge it into your branch.","points":20,"is_optional":false,"is_stateful":true},{"id":"1366dcc7-86a3-5f9b-9412-09b3734824a6","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":5,"title":"Integrate and push","description":"Bring the teammate's commit into main with git pull (merge strategy) and push main so origin has both the changelog commit and your notes commit.","verification_script":"r=/home/labuser/work/app\no=$(git -C $r ls-remote origin refs/heads/main | cut -f1)\n[ \"$(git -C $r rev-parse main)\" = \"$o\" ] \u0026\u0026\ngit -C $r log origin/main --format=%s | grep -qx \"Add notes.txt\" \u0026\u0026\ngit -C $r log origin/main --format=%s | grep -qx \"Teammate: add changelog\" \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"git pull = git fetch + git merge. The system default is merge (pull.rebase=false). Afterwards git push publishes the merge.","explanation_context":"Your main and origin/main had diverged, so pull creates a merge commit joining them; the follow-up push is then a fast-forward for the server.","points":20,"is_optional":false,"is_stateful":true},{"id":"812f0aba-9a39-5e39-9b18-39f4817967ec","lab_id":"6c5b265a-1410-5ebf-b84d-e855e2ddd1ab","position":6,"title":"Publish a new branch with upstream tracking","description":"Create a branch feature/search with one commit \"Add search stub\" (add a file search.txt) and push it to origin, setting the upstream so a bare git push works later.","verification_script":"r=/home/labuser/work/app\no=$(git -C $r ls-remote origin refs/heads/feature/search | cut -f1)\n[ -n \"$o\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse feature/search)\" = \"$o\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse feature/search@{upstream})\" = \"$o\" ] \u0026\u0026\n[ \"$(git -C $r log feature/search -1 --format=%s)\" = \"Add search stub\" ]\n","hint_context":"git push -u origin \u003cbranch\u003e pushes and records the upstream in one step.","explanation_context":"-u (--set-upstream) writes branch.\u003cname\u003e.remote and .merge, which is what makes git status and bare git pull/push work for that branch.","points":15,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('9bdbbf8f-61fb-58f8-93b7-bb3642c64ac6', '292d0dec-8892-5e07-b9f1-c367e915691b', '4fab9e36-245a-5109-9ed1-72c9448e763c', 1, 'Clone the shared repository', $md$The team repository lives at /srv/git/origin.git (a bare repository acting as "the server"). Clone it into a directory called app inside your work directory.$md$, $script$r=/home/labuser/work/app
[ "$(git -C $r remote get-url origin)" = /srv/git/origin.git ] &&
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
('365f0f9d-f97b-5c6a-b8cf-76af5f30ec5e', '292d0dec-8892-5e07-b9f1-c367e915691b', '1895b7cf-e85c-5ec6-b6e1-288dcb22efa7', 4, 'Fetch a teammate''s work without merging', $md$Run the helper command teammate-push (it simulates a colleague pushing to origin/main). Then try git push - it will be rejected. Run git fetch (not pull) so origin/main updates while your own main stays untouched.$md$, $script$r=/home/labuser/work/app
o=$(git -C $r ls-remote origin refs/heads/main | cut -f1)
[ "$(git -C $r rev-parse origin/main)" = "$o" ] &&
[ "$(git -C $r rev-parse main)" != "$o" ] &&
git -C $r log origin/main --format=%s | grep -qx "Teammate: add changelog" &&
[ "$(git -C $r log main -1 --format=%s)" = "Add notes.txt" ]
$script$, 'teammate-push is already on your PATH. After git push is rejected, git fetch updates origin/main but never touches your branches. Compare with git log --oneline --graph --all.', 'Push is rejected (non-fast-forward) because origin/main has a commit you lack. fetch downloads it into the remote-tracking branch only; pull would also merge it into your branch.', 20, false, true),
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

-- Section: Branching and Merging
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('498e7765-54bf-5ac3-a80c-bab3bb98f650', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Branching and Merging', 3, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e7308f90-9b11-586e-a880-349ba6e409b0', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '498e7765-54bf-5ac3-a80c-bab3bb98f650', 'Branches, Fast-Forward and Merge Commits', 'notes', 0, $md$## A branch is a pointer

A branch is a 41-byte file holding a commit hash. `HEAD` says which branch you are on. Creating a
branch copies a pointer, nothing else.

```
BEFORE  git switch -c feature/greeting     AFTER one commit on the new branch

 A---B---C  <- main <- HEAD                 A---B---C  <- main
                                                     \
                                                      D  <- feature/greeting <- HEAD
```

```bash
cd ~/work/shop
git switch -c feature/greeting
echo hello > greeting.txt && git add greeting.txt && git commit -m "Add greeting"
git log --oneline --graph --all
```

[[lab-task:1]]

What you should see (hashes differ):

```
* 2ab9c40 (HEAD -> feature/greeting) Add greeting
| * 77d1e0a (feature/cart) Add cart totals
| * 0c4f8e2 Add cart file
|/
* 5e13a9b (main) Add checkout
* 9b2d6c1 Add product list
* 1f0a7d3 Initial commit
```

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
    "explanation": "Branches are cheap because they are just references to commits." }
] }
```

## Fast-forward merges

If the branch you are on has not moved since the other branch split off, merging just slides the
pointer forward:

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

[[lab-task:2]]

What you should see:

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
    "explanation": "Nothing diverged, so the pointer simply moves ahead." }
] }
```

## Merge commits (three-way)

Now main has `D` (greeting) while `feature/cart` still hangs off `C`. Histories diverged, so Git
makes a commit with two parents:

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

[[lab-task:3]]

What you should see:

```
*   e5a1d77 (HEAD -> main) Merge feature/cart
|\
| * 77d1e0a (feature/cart) Add cart totals
| * 0c4f8e2 Add cart file
* | 2ab9c40 Add greeting
|/
* 5e13a9b Add checkout
```

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
    "explanation": "One parent per merged line of history: the target branch and the merged-in branch." }
] }
```

## --no-ff: keep the branch visible

```
 without --no-ff (fast-forward)         with --no-ff

 A---B---C---F  <- main                  A---B---C-------M  <- main
 (feature commits look like main's)               \     /
                                                   F---G  <- feature/footer
```

```bash
git switch -c feature/footer
echo footer > footer.txt && git add footer.txt && git commit -m "Add footer"
git switch main
git merge --no-ff feature/footer -m "Merge feature/footer"
```

[[lab-task:4]]

What you should see from `git log --oneline --graph -4`:

```
*   a41c0be (HEAD -> main) Merge feature/footer
|\
| * 3f9d812 (feature/footer) Add footer
|/
*   e5a1d77 Merge feature/cart
```

Finally, tidy up. Deleting a branch only deletes the pointer:

```bash
git branch -d feature/greeting feature/cart feature/footer
git branch
```

[[lab-task:5]]

What you should see:

```
* main
```

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
    "explanation": "The merge commit groups the branch's commits and gives you one commit to revert later." },
  { "id": "git-branch-noff-q2", "type": "mcq",
    "prompt": "git branch -d refuses to delete a branch. What does that usually mean?",
    "options": [
      {"id":"a","text":"The branch has commits not yet merged into the current branch"},
      {"id":"b","text":"The branch is too old"},
      {"id":"c","text":"You must be root"},
      {"id":"d","text":"The repo is read-only"}],
    "correct": "a",
    "explanation": "-d is the safe delete. Use -D only when you are sure the work is disposable." }
] }
```
$md$, 40, $json$[{"id":"git-branch-pointer-q1","type":"mcq","correct":"b"},{"id":"git-branch-ff-q1","type":"mcq","correct":"b"},{"id":"git-branch-merge-q1","type":"mcq","correct":"b"},{"id":"git-branch-noff-q1","type":"mcq","correct":"b"},{"id":"git-branch-noff-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('e94f6752-6fb4-5825-8c8b-d36ed06f5eb5', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'e7308f90-9b11-586e-a880-349ba6e409b0', 'module', 'Branches, Fast-Forward and Merge Commits', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --system init.defaultBranch main
git config --system safe.directory '*'
git config --system user.name "Lab Student"
git config --system user.email "student@lab.local"
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

-- Section: Merge Conflicts
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('0bfdc51c-0996-5a60-beac-0ac183d3389c', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Merge Conflicts', 4, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('74fb2616-b5a3-50ad-a6ed-381dfce33769', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0bfdc51c-0996-5a60-beac-0ac183d3389c', 'Reading, Resolving, Aborting and Remembering Conflicts', 'notes', 0, $md$## Why conflicts happen

Git merges by comparing each branch to their common ancestor. If only one side changed a line, that
change wins. If both sides changed the same lines differently, Git stops and asks you.

```
 ancestor:  timeout=30
 main    :  timeout=60        both changed the same line
 feature :  timeout=45        ->  CONFLICT
```

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
    "explanation": "If only one side changed a region, Git takes that change automatically." }
] }
```

## Reading the markers

```bash
git switch main
git merge feature/timeout
git status
cat app.conf
```

[[lab-task:1]]

What you should see:

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

Above `=======` is your side (HEAD, the branch you are on). Below it is the incoming branch.

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
    "explanation": "HEAD is your current branch (ours); below ======= is theirs." }
] }
```

## Resolving and completing the merge

Resolving = edit the file to the final text, then tell Git with `git add`. Finish with `git commit`.

```
 resolve         git add app.conf      git commit
 (edit file) --> (conflict cleared) --> merge commit M (parents: main tip, feature tip)

   A---B---C---M  <- main
        \     /
         D---+   <- feature/timeout
```

```bash
# edit app.conf: keep timeout=60 and retries=3, delete the markers
git add app.conf
git commit
git log --oneline --graph
```

[[lab-task:2]]
[[lab-task:3]]

What you should see:

```
*   6be1f20 (HEAD -> main) Merge branch 'feature/timeout'
|\
| * c2a9d41 (feature/timeout) Raise timeout to 45 and add retries
* | 14e8b07 Raise timeout to 60
|/
* a70d3e5 Initial config
```

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
    "explanation": "git add marks the path resolved; git commit records the merge commit." },
  { "id": "git-conflict-resolve-q2", "type": "mcq",
    "prompt": "What is the safest way to check no markers were left in the repository?",
    "options": [
      {"id":"a","text":"git grep -nE '^(<<<<<<<|>>>>>>>)'"},
      {"id":"b","text":"git gc"},
      {"id":"c","text":"git remote -v"},
      {"id":"d","text":"git tag"}],
    "correct": "a",
    "explanation": "Markers are plain text, so Git will happily commit them if you stage a file without cleaning it." }
] }
```

## Aborting a merge

If you start a merge and it is not the right time, back out cleanly:

```
 DURING conflict                     AFTER git merge --abort
 main + half-resolved files    -->   exactly the pre-merge state of main
```

```bash
git merge feature/log-level      # conflict
git merge --abort
git status
```

[[lab-task:4]]
[[lab-task:5]]

What you should see:

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
    "explanation": "It is only available while a merge is in progress; afterwards use reset or revert instead." }
] }
```

## rerere: reuse recorded resolution

Turn on `rerere` and Git remembers how you resolved each conflict. When the same conflict
appears again (re-merge, rebase, cherry-pick), it replays your answer.

```
 conflict #1:  preimage ---you resolve---> postimage      saved in .git/rr-cache/<hash>/
 conflict #2 (same hunk) -> "Resolved 'logging.conf' using previous resolution."
```

```bash
git config rerere.enabled true
git merge feature/log-level      # conflict, recorded
# resolve to level=warn
git add logging.conf && git commit --no-edit
ls .git/rr-cache/*/
```

[[lab-task:6]]

What you should see:

```
Recorded preimage for 'logging.conf'
...
Recorded resolution for 'logging.conf'.
postimage  preimage
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
    "explanation": "Each repeat of an identical conflict is resolved automatically from the recorded postimage." }
] }
```
$md$, 40, $json$[{"id":"git-conflict-why-q1","type":"mcq","correct":"b"},{"id":"git-conflict-markers-q1","type":"mcq","correct":"b"},{"id":"git-conflict-resolve-q1","type":"mcq","correct":"a"},{"id":"git-conflict-resolve-q2","type":"mcq","correct":"a"},{"id":"git-conflict-abort-q1","type":"mcq","correct":"b"},{"id":"git-conflict-rerere-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('08fe5130-784d-56e8-ad02-34ff566fe34c', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '74fb2616-b5a3-50ad-a6ed-381dfce33769', 'module', 'Reading, Resolving, Aborting and Remembering Conflicts', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --system init.defaultBranch main
git config --system safe.directory '*'
git config --system user.name "Lab Student"
git config --system user.email "student@lab.local"
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

-- Section: Rebase
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('bc66d97b-4855-5638-8fbb-d9d46ae7f1b7', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Rebase', 5, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('86e78574-a4f8-5c6a-9b7a-7100dd51962d', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'bc66d97b-4855-5638-8fbb-d9d46ae7f1b7', 'Rebase, Interactive Rebase and force-with-lease', 'notes', 0, $md$## Rebase: move a branch onto a new base

Merge joins two histories; rebase **replays** your commits on top of another branch. The result
is a straight line, but your commits get new hashes.

```
BEFORE                                AFTER  git switch feature; git rebase main

 A---B---C---D  <- main                A---B---C---D  <- main
      \                                              \
       E---F  <- feature                              E'---F'  <- feature
                                       (E and F are replaced by copies E' and F')
```

```bash
cd ~/work/blog
git switch feature/comments
git rebase main
git log --oneline --graph --all
```

[[lab-task:1]]

What you should see:

```
* 7c3a2e9 (HEAD -> feature/comments) Add comment form
* 0f6b18d Add comments page
* b1e47a0 (main) Rename title to Dev Blog
* 5d9c30f Add footer
* 2a8f6c1 Add about page
* e0d31b7 Initial blog
```

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
    "explanation": "Each commit has a new parent, so a new hash. The old commits remain in the reflog." }
] }
```

## Conflicts during a rebase

A conflict stops the replay on the commit that cannot apply. You have three choices:

```
 git rebase main  --> CONFLICT while applying E
      |
      +-- fix files, git add, git rebase --continue   (carry on with next commit)
      +-- git rebase --skip                           (drop this commit)
      +-- git rebase --abort                          (go back to before the rebase)
```

In a rebase the labels flip: "ours" (HEAD) is the branch you are rebasing **onto**, "theirs" is the
commit being replayed.

```bash
git switch feature/title
git rebase main          # CONFLICT in index.md
git rebase --abort       # back to the start
git rebase main          # conflict again
# edit index.md, then
git add index.md
GIT_EDITOR=true git rebase --continue
```

[[lab-task:2]]
[[lab-task:3]]
[[lab-task:4]]

What you should see while stopped:

```
Auto-merging index.md
CONFLICT (content): Merge conflict in index.md
error: could not apply 3e5f1aa... Rename blog title
hint: Resolve all conflicts manually, mark them as resolved with
hint: "git add/rm <conflicted_files>", then run "git rebase --continue".

$ git status
interactive rebase in progress; onto b1e47a0
```

And afterwards:

```
Successfully rebased and updated refs/heads/feature/title.
```

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
    "explanation": "--skip would drop the commit being applied; --abort undoes the whole rebase." }
] }
```

## Interactive rebase: squash, reorder, reword

`git rebase -i main` opens a todo list, oldest commit first. Edit the verbs, save, and Git replays:

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

Verbs: `pick` keep, `reword` keep and edit message, `squash` meld and combine messages, `fixup`
meld and discard message, `drop` delete, and reordering lines reorders commits.

Scripts can drive it with `GIT_SEQUENCE_EDITOR` (the todo editor) and `GIT_EDITOR` (the message
editor), e.g. `GIT_SEQUENCE_EDITOR='sed -i s/^pick/reword/' git rebase -i main`.

```bash
git switch feature/profile
git rebase -i main
```

[[lab-task:5]]
[[lab-task:6]]

What you should see afterwards:

```
* 91c0d4e (HEAD -> feature/profile) Add profile avatar
* 6a2fb85 Add profile page
* b1e47a0 (main) Rename title to Dev Blog
```

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
    "explanation": "Both meld the commit into the previous one; only squash lets you keep its message." }
] }
```

## Never rebase shared history; use force-with-lease

Rebasing rewrites commits. If teammates already built on the old ones, their history and yours
no longer match:

```
 origin/feature:  A---B---C---D        teammate has D checked out
 you rebase  ->   A---B---C'---D'      (new hashes)
 push --force     origin now has C'D'  -> teammate's D is orphaned, their next pull is a mess
```

Rule: rebase only commits nobody else has based work on (your own unpublished branch, or a
branch you own). When you must update a branch you already pushed, use
`--force-with-lease`; it refuses if the remote moved since you last fetched.

```bash
git push                                  # rejected: non-fast-forward
git push --force-with-lease origin feature/profile
```

[[lab-task:7]]

What you should see:

```
 ! [rejected]        feature/profile -> feature/profile (non-fast-forward)
...
 + 0b7e5ad...91c0d4e feature/profile -> feature/profile (forced update)
```

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
    "explanation": "It checks the remote still points where your remote-tracking ref says before overwriting." },
  { "id": "git-rebase-lease-q2", "type": "mcq",
    "prompt": "Which branch should you NEVER rebase?",
    "options": [
      {"id":"a","text":"A private local branch nobody has pulled"},
      {"id":"b","text":"A shared branch like main that others have pulled"},
      {"id":"c","text":"A branch with one commit"},
      {"id":"d","text":"A branch with no remote"}],
    "correct": "b",
    "explanation": "Rewriting commits others already have forces them to reconcile two versions of history." }
] }
```
$md$, 55, $json$[{"id":"git-rebase-basic-q1","type":"mcq","correct":"b"},{"id":"git-rebase-conflict-q1","type":"mcq","correct":"b"},{"id":"git-rebase-interactive-q1","type":"mcq","correct":"a"},{"id":"git-rebase-lease-q1","type":"mcq","correct":"a"},{"id":"git-rebase-lease-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('3aad60ea-7c5d-53e8-af8f-aec913118978', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '86e78574-a4f8-5c6a-9b7a-7100dd51962d', 'module', 'Rebase, Interactive Rebase and force-with-lease', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --system init.defaultBranch main
git config --system safe.directory '*'
git config --system user.name "Lab Student"
git config --system user.email "student@lab.local"
rm -rf /home/labuser/work/blog /srv/git
mkdir -p /srv/git /home/labuser/work/blog && cd /home/labuser/work/blog
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
git init -q --bare /srv/git/blog.git
git remote add origin /srv/git/blog.git
git push -q origin main feature/profile
git branch -q --set-upstream-to=origin/main main
git branch -q --set-upstream-to=origin/feature/profile feature/profile
chmod -R a+rwX /home/labuser/work/blog /srv/git
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
$script$, 'In the todo list move the "fix typo" and "bio" lines directly under the skeleton line and change pick to fixup (f). Leave the avatar line last. In this lab terminal the editor is nano or vim.', 'fixup melds a commit into the one above it and discards its message; reordering lines reorders history. Commits that touch different files reorder without conflicts.', 20, false, true),
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
VALUES ('203db899-fc15-5412-ab91-ebf9232eb368', '3aad60ea-7c5d-53e8-af8f-aec913118978', 1, $json$[{"id":"bcde4793-12fb-57a0-bfe5-9b6942674344","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":1,"title":"Rebase a feature branch onto main","description":"In ~/work/blog, feature/comments was started before main gained two commits. Rebase feature/comments onto main so its two commits sit on top of main's tip with no merge commit.","verification_script":"r=/home/labuser/work/blog\ngit -C $r merge-base --is-ancestor main feature/comments \u0026\u0026\n[ \"$(git -C $r rev-list --count main..feature/comments)\" = 2 ] \u0026\u0026\n[ \"$(git -C $r rev-list --merges --count main..feature/comments)\" = 0 ] \u0026\u0026\n[ \"$(git -C $r log feature/comments -1 --format=%s)\" = \"Add comment form\" ] \u0026\u0026\n[ ! -d $r/.git/rebase-merge ]\n","hint_context":"git switch feature/comments, then git rebase main. Check the result with git log --oneline --graph --all.","explanation_context":"Rebase replays each of your commits on top of a new base, creating new commits with new hashes. The result is a straight line instead of a merge.","points":15,"is_optional":false,"is_stateful":true},{"id":"adf90221-77b3-5bf9-b623-24d7c2ee0222","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":2,"title":"Hit a conflict mid-rebase","description":"feature/title renames the heading to \"# The Blog\" but main already renamed it to \"# Dev Blog\". Rebase feature/title onto main and stop at the conflict.","verification_script":"r=/home/labuser/work/blog\n[ -d $r/.git/rebase-merge ] \u0026\u0026\ngit -C $r ls-files -u | grep -q index.md\n","hint_context":"git switch feature/title \u0026\u0026 git rebase main. Git pauses and prints which commit it was applying.","explanation_context":"Rebase replays commits one at a time; a conflict stops it with the branch in a detached state until you continue or abort.","points":10,"is_optional":false,"is_stateful":true},{"id":"f96af6df-620c-5041-a031-da09aee8b416","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":3,"title":"Abort the rebase","description":"Change your mind - abort the rebase so feature/title is exactly as it was before.","verification_script":"r=/home/labuser/work/blog\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\n[ \"$(git -C $r rev-parse --abbrev-ref HEAD)\" = feature/title ] \u0026\u0026\n! git -C $r merge-base --is-ancestor main feature/title \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"git rebase --abort.","explanation_context":"--abort returns the branch to its pre-rebase tip. Your original commits were never modified, so nothing is lost.","points":10,"is_optional":false,"is_stateful":true},{"id":"7e94857a-650f-5846-b07b-3b43af49d2b3","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":4,"title":"Resolve and continue the rebase","description":"Rebase feature/title onto main again. This time resolve index.md so its first line is \"# The Dev Blog\" (second line \"Welcome\"), git add it and run git rebase --continue.","verification_script":"r=/home/labuser/work/blog\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\ngit -C $r merge-base --is-ancestor main feature/title \u0026\u0026\n[ \"$(git -C $r rev-list --count main..feature/title)\" = 1 ] \u0026\u0026\n[ \"$(git -C $r log feature/title -1 --format=%s)\" = \"Rename blog title\" ] \u0026\u0026\n[ \"$(git -C $r show feature/title:index.md | head -1)\" = \"# The Dev Blog\" ] \u0026\u0026\n[ -z \"$(git -C $r grep -nE '^(\u003c\u003c\u003c\u003c\u003c\u003c\u003c|=======|\u003e\u003e\u003e\u003e\u003e\u003e\u003e)' feature/title)\" ]\n","hint_context":"After editing, git add index.md then git rebase --continue (set GIT_EDITOR=true to skip the message editor).","explanation_context":"In a rebase \"ours\" is the branch you are rebasing onto and \"theirs\" is your commit being replayed - the reverse of a merge. The continue step creates the rewritten commit.","points":20,"is_optional":false,"is_stateful":true},{"id":"95dc5233-5561-5aab-a9d5-3f7924ffe30f","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":5,"title":"Squash and reorder with interactive rebase","description":"feature/profile has four messy commits (\"wip: profile skeleton\", \"wip: add avatar\", \"fix typo in profile\", \"wip: bio\"). Use git rebase -i main to fold the typo fix and bio into the skeleton commit and keep the avatar commit last, leaving exactly two commits.","verification_script":"r=/home/labuser/work/blog\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\n[ \"$(git -C $r rev-list --count main..feature/profile)\" = 2 ] \u0026\u0026\n[ \"$(git -C $r show --name-only --format= feature/profile)\" = avatar.md ] \u0026\u0026\ngit -C $r show feature/profile~1:profile.md | grep -qx '# Profile' \u0026\u0026\ngit -C $r show feature/profile~1:profile.md | grep -qx 'bio: hello'\n","hint_context":"In the todo list move the \"fix typo\" and \"bio\" lines directly under the skeleton line and change pick to fixup (f). Leave the avatar line last. In this lab terminal the editor is nano or vim.","explanation_context":"fixup melds a commit into the one above it and discards its message; reordering lines reorders history. Commits that touch different files reorder without conflicts.","points":20,"is_optional":false,"is_stateful":true},{"id":"45ea28b5-8236-53f3-b3d4-3e3376a5ae4a","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":6,"title":"Reword the commits","description":"Reword the two remaining commits (oldest first) to \"Add profile page\" and \"Add profile avatar\" using interactive rebase.","verification_script":"r=/home/labuser/work/blog\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\n[ \"$(git -C $r log --reverse --format=%s main..feature/profile)\" = \"$(printf 'Add profile page\\nAdd profile avatar')\" ]\n","hint_context":"Change pick to reword (r) on both lines; Git opens the editor once per commit.","explanation_context":"reword keeps the content and rewrites only the message. Since every following commit has a new parent, the hashes of later commits change too.","points":15,"is_optional":false,"is_stateful":true},{"id":"91c64a7d-f740-5808-9377-8efb56735633","lab_id":"3aad60ea-7c5d-53e8-af8f-aec913118978","position":7,"title":"Update the shared branch safely","description":"origin still holds the old, un-squashed feature/profile. A plain git push is rejected because history was rewritten. Push the rewritten branch with --force-with-lease (never plain --force). origin's main must stay untouched.","verification_script":"r=/home/labuser/work/blog\n[ \"$(git -C $r ls-remote origin refs/heads/feature/profile | cut -f1)\" = \"$(git -C $r rev-parse feature/profile)\" ] \u0026\u0026\n[ \"$(git -C $r ls-remote origin refs/heads/main | cut -f1)\" = \"$(git -C $r rev-parse main)\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --count origin/feature/profile)\" = \"$(git -C $r rev-list --count feature/profile)\" ]\n","hint_context":"git push --force-with-lease origin feature/profile. It refuses if someone else pushed to the branch since your last fetch.","explanation_context":"--force-with-lease overwrites the remote branch only if it still points where you last saw it, protecting a teammate's newer commits that a blind --force would destroy.","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
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
$script$, 'In the todo list move the "fix typo" and "bio" lines directly under the skeleton line and change pick to fixup (f). Leave the avatar line last. In this lab terminal the editor is nano or vim.', 'fixup melds a commit into the one above it and discards its message; reordering lines reorders history. Commits that touch different files reorder without conflicts.', 20, false, true),
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

-- Section: Undo and Recovery
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('7a77d065-f51b-5ec5-9aea-a09bdcfb797c', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Undo and Recovery', 6, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a9dbf033-3c13-5141-b45d-b5b6a1e8d407', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '7a77d065-f51b-5ec5-9aea-a09bdcfb797c', 'restore, reset, revert, reflog, cherry-pick and stash', 'notes', 0, $md$## restore: discard or unstage

`git restore` fixes the working tree and the index without moving any branch.

```
 BEFORE                                   AFTER
 HEAD   : ledger v1                       HEAD   : ledger v1
 index  : ledger v1                       index  : ledger v1
 working: ledger v1 + GARBAGE             working: ledger v1       git restore ledger.txt

 git restore --staged secret.txt:  index loses the file, working copy untouched
```

```bash
cd ~/work/ledger
git status
git restore ledger.txt
git restore --staged secret.txt
```

[[lab-task:1]]
[[lab-task:2]]

What you should see:

```
$ git status -s
 M ledger.txt
A  secret.txt
(after both restores)
?? secret.txt
```

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
    "explanation": "Plain git restore <file> would discard the working-tree edits instead." }
] }
```

## reset: soft, mixed, hard

`reset` moves the current branch to another commit, and then decides how much else to rewind:

```
              moves HEAD    resets INDEX    overwrites WORKING TREE
 --soft           yes            no                 no
 --mixed (default) yes           yes                no
 --hard           yes            yes                yes   (destructive)
```

```
BEFORE: A---B---C  <- main (HEAD)         git reset X HEAD~1

 --soft :  A---B  <- main   index = C's content (staged)   working = C's content
 --mixed:  A---B  <- main   index = B              working = C's content (unstaged)
 --hard :  A---B  <- main   index = B              working = B      (C's changes gone)
           C is now unreachable (but in the reflog)
```

```bash
git reset --soft HEAD~1 && git commit -m "Add March entries"   # fix a commit message
git reset --mixed HEAD~1                                      # unstage and keep edits
git commit -am "Add March entries"
git reset --hard HEAD~2                                       # drop commits AND edits
```

[[lab-task:3]]
[[lab-task:4]]
[[lab-task:5]]
[[lab-task:6]]

What you should see after `git reset --hard HEAD~2`:

```
HEAD is now at 4be2c19 Add February entries
```

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
    "explanation": "--soft leaves index and working tree alone; --mixed unstages; --hard discards." },
  { "id": "git-undo-reset-q2", "type": "mcq",
    "prompt": "Which reset mode can destroy uncommitted work?",
    "options": [
      {"id":"a","text":"--soft"},
      {"id":"b","text":"--mixed"},
      {"id":"c","text":"--hard"},
      {"id":"d","text":"None of them"}],
    "correct": "c",
    "explanation": "--hard overwrites the working tree, and uncommitted edits are not in the reflog." }
] }
```

## reflog: the safety net

`git reflog` records every move of HEAD. After a `reset --hard` the commits are unreachable from
any branch but still reachable via the reflog.

```
 git reflog
 4be2c19 HEAD@{0}: reset: moving to HEAD~2
 a91d6f3 HEAD@{1}: commit: Add April entries      <-- the "lost" commit
 5c07b8e HEAD@{2}: commit: Add March entries

 git reset --hard a91d6f3     main points at April again:  A---B---C---D---E <- main
```

```bash
git reflog
git reset --hard <hash of "commit: Add April entries">
```

[[lab-task:7]]

What you should see:

```
HEAD is now at a91d6f3 Add April entries
```

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
    "explanation": "The reflog keeps the previous positions of HEAD (for 90 days by default for reachable-once commits)." }
] }
```

## revert: undo safely on shared history

`reset` rewrites history; `revert` adds a new commit that undoes an old one.

```
BEFORE                               AFTER git revert C

 A---B---C---D  <- main               A---B---C---D---C'  <- main
                                      C' = inverse of C   (C stays in history)
```

For a merge commit there are two parents, so tell Git which one is the mainline:

```
        M  <- main (merge of feature into main)       git revert -m 1 M
       / \                                             -m 1 = keep parent 1 (main's side),
      B   F  <- feature                                undo everything F brought in
```

```bash
git revert --no-edit <hash of "Add March entries">
git merge --no-ff feature/bonus -m "Merge feature/bonus"
git revert -m 1 --no-edit HEAD
```

[[lab-task:8]]
[[lab-task:9]]
[[lab-task:10]]

What you should see:

```
[main 7ad03ce] Revert "Merge feature/bonus"
 Date: ...
 1 file changed, 1 deletion(-)
 delete mode 100644 bonus.txt
```

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
    "explanation": "Rewriting shared history forces everyone else to repair their branches." },
  { "id": "git-undo-revert-q2", "type": "mcq",
    "prompt": "What does git revert -m 1 <merge> keep?",
    "options": [
      {"id":"a","text":"The side of parent 1 (the branch the merge was made on) and undoes what the other parent brought in"},
      {"id":"b","text":"Only the other parent's changes"},
      {"id":"c","text":"Nothing"},
      {"id":"d","text":"Both sides"}],
    "correct": "a",
    "explanation": "-m picks the mainline parent; changes relative to it are inverted." }
] }
```

## cherry-pick: borrow one commit

```
BEFORE                                AFTER  git switch main; git cherry-pick S

 main:    A---B---C                    main:    A---B---C---S'   (S' = copy of S)
 audit:        \                       audit:        \
                L---S                                 L---S   (unchanged)
```

```bash
git log --oneline feature/audit
git cherry-pick <hash of "Add audit summary">
```

[[lab-task:11]]

What you should see:

```
[main 3b9f1a2] Add audit summary
 Author: Priya Auditor <priya@example.com>
 1 file changed, 1 insertion(+)
```

```knowledge-check
{ "questions": [
  { "id": "git-undo-pick-q1", "type": "mcq",
    "prompt": "A cherry-picked commit has the same hash as the original.",
    "options": [
      {"id":"a","text":"True"},
      {"id":"b","text":"False - it is a new commit with a different parent, so a different hash"}],
    "correct": "b",
    "explanation": "The diff and message are copied but the commit identity (parent, date) differs." }
] }
```

## stash: park work in progress

```
 working tree dirty ----git stash push -m "wip total"----> working tree clean
                                     stash@{0} holds the edits
 later: git stash pop  ------------------------------------> edits are back, stash entry dropped
```

```bash
echo "WIP total" >> ledger.txt
git stash push -m "wip total"
git stash list
git stash pop
```

[[lab-task:12]]
[[lab-task:13]]

What you should see from `git stash list`:

```
stash@{0}: On main: wip total
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
    "explanation": "apply is useful when you want to apply the same stash on several branches." }
] }
```
$md$, 60, $json$[{"id":"git-undo-restore-q1","type":"mcq","correct":"a"},{"id":"git-undo-reset-q1","type":"mcq","correct":"a"},{"id":"git-undo-reset-q2","type":"mcq","correct":"c"},{"id":"git-undo-reflog-q1","type":"mcq","correct":"b"},{"id":"git-undo-revert-q1","type":"mcq","correct":"a"},{"id":"git-undo-revert-q2","type":"mcq","correct":"a"},{"id":"git-undo-pick-q1","type":"mcq","correct":"b"},{"id":"git-undo-stash-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('04d7844d-96d2-5567-8035-339262255ab7', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'a9dbf033-3c13-5141-b45d-b5b6a1e8d407', 'module', 'restore, reset, revert, reflog, cherry-pick and stash', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --system init.defaultBranch main
git config --system safe.directory '*'
git config --system user.name "Lab Student"
git config --system user.email "student@lab.local"
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

-- Section: Investigating History
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('462878a1-6134-50d3-953c-444b70b83668', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Investigating History', 7, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e9c35a89-dd93-5e9a-bcb3-722e6879a5f3', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '462878a1-6134-50d3-953c-444b70b83668', 'blame, log -S/-G, --follow, bisect and show', 'notes', 0, $md$## blame: who wrote this line?

`git blame file` prefixes every line with the commit, author and date that last changed it.
`-L start,end` narrows the range.

```
 commit history of tax.sh                 git blame -L1,1 tax.sh
 c1 Alice: rate=10                        ^
 c7 Dave : rate=15   <- last change  --->  7a3f9c1 (Dave Hotfix 2024-06-07 1) rate=15
```

```bash
cd ~/work/inventory
git blame -L1,1 tax.sh
echo "rate_author=Dave Hotfix" >> ~/work/answers.txt
```

[[lab-task:1]]

What you should see (hashes differ):

```
7a3f9c1 (Dave Hotfix 2024-06-07 10:00:00 +0000 1) rate=15
```

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
    "explanation": "Blame is about the last change to each line, which is the starting point for digging deeper with git log." }
] }
```

## blame -w and -C: seeing through refactors

Reformatting and moving code make plain blame blame the wrong person.

```
 c4 Carol writes  "  echo $(( $1 * 10 / 100 ))"
 c9 Eve re-indents "\techo ..."           plain blame -> Eve      blame -w -> Carol

 c6 Gina writes shipping.sh
 c10 Frank moves the lines to util.sh    plain blame -> Frank    blame -C -> Gina
```

```bash
git blame -L2,2 discount.sh        # Eve
git blame -w -L2,2 discount.sh     # Carol
git blame util.sh | sed -n 4p       # Frank
git blame -C util.sh | sed -n 4p    # Gina (run it on the whole file, not with -L)
```

[[lab-task:2]]
[[lab-task:3]]

What you should see:

```
$ git blame -L2,2 discount.sh
d41e0b7 (Eve Formatter 2024-06-09 10:00:00 +0000 2) 	echo $(( $1 * 10 / 100 ))
$ git blame -w -L2,2 discount.sh
b09c7a2 (Carol Pricing 2024-06-04 10:00:00 +0000 2) 	echo $(( $1 * 10 / 100 ))
```

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
    "explanation": "-w ignores whitespace when attributing lines." },
  { "id": "git-inv-blamewc-q2", "type": "mcq",
    "prompt": "Code was moved from one file to another in a single commit. Which flag lets blame follow it?",
    "options": [
      {"id":"a","text":"-C"},
      {"id":"b","text":"-w"},
      {"id":"c","text":"-L"},
      {"id":"d","text":"-s"}],
    "correct": "a",
    "explanation": "-C detects lines moved or copied between files; repeat it for deeper searches." }
] }
```

## log -S, -G and --follow: searching history

```
 -S 'text'   commits where the COUNT of 'text' changed (added / removed)
 -G 'regex'  commits whose diff has a +/- line matching regex (also catches edits)
 --follow f  history of one file across renames

 config.sh:   Misc changes  (+timeout=30 +LEGACY_FLAG=1)
              Bump timeout  (-timeout=30 +timeout=45)   found by -G, NOT by -S 'timeout='
              Tidy up       (-LEGACY_FLAG=1)             found by -S LEGACY_FLAG
```

```bash
git log -S LEGACY_FLAG --oneline
git log -G 'timeout=' --oneline
git log --follow --oneline -- pricing.sh
```

[[lab-task:4]]
[[lab-task:5]]
[[lab-task:6]]

What you should see:

```
$ git log -S LEGACY_FLAG --oneline
9e1b3d0 Tidy up
c3a77f4 Misc changes
$ git log -G 'timeout=' --oneline
5f0e2c8 Bump timeout
c3a77f4 Misc changes
```

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
    "explanation": "-S only fires when the number of occurrences changes; -G matches any changed line." }
] }
```

## bisect: binary search for a bug

Mark one known-good and one known-bad commit; Git checks out the middle, you (or a script) say
good or bad, and the range halves each time.

```
 v1.0 (good)                                              HEAD (bad)
  c5   c6   c7   c8   c9   c10  c11  c12  c13
  good  ?    ?    ?    ?    ?    ?    ?   bad
              test c9 -> bad    [c5 .. c9]
              test c7 -> bad    [c5 .. c7]
              test c6 -> good   first bad = c7  "Speed up tax calc"
```

```bash
git bisect start HEAD v1.0
git bisect run sh check.sh     # exit 0 = good, 1 = bad
git rev-parse refs/bisect/bad > ~/work/culprit.txt
git bisect reset
git show -s --format='%an <%ae>' "$(cat ~/work/culprit.txt)"
```

[[lab-task:7]]
[[lab-task:8]]

What you should see:

```
running 'sh' 'check.sh'
FAIL
7a3f9c1e... is the first bad commit
commit 7a3f9c1e...
Author: Dave Hotfix <dave@example.com>
    Speed up tax calc
bisect found first bad commit
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
    "explanation": "Each test halves the remaining range: log2(1000) is roughly 10." },
  { "id": "git-inv-bisect-q2", "type": "mcq",
    "prompt": "What does a script given to git bisect run return for a good commit?",
    "options": [
      {"id":"a","text":"Exit status 0"},
      {"id":"b","text":"Exit status 1"},
      {"id":"c","text":"Any output"},
      {"id":"d","text":"The word good"}],
    "correct": "a",
    "explanation": "0 means good, 1 to 127 (except 125 = skip) means bad." }
] }
```
$md$, 50, $json$[{"id":"git-inv-blame-q1","type":"mcq","correct":"a"},{"id":"git-inv-blamewc-q1","type":"mcq","correct":"a"},{"id":"git-inv-blamewc-q2","type":"mcq","correct":"a"},{"id":"git-inv-search-q1","type":"mcq","correct":"b"},{"id":"git-inv-bisect-q1","type":"mcq","correct":"a"},{"id":"git-inv-bisect-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('fa0d802e-7fab-5376-a664-5c4af7a73dd5', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'e9c35a89-dd93-5e9a-bcb3-722e6879a5f3', 'module', 'blame, log -S/-G, --follow, bisect and show', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --system init.defaultBranch main
git config --system safe.directory '*'
git config --system user.name "Lab Student"
git config --system user.email "student@lab.local"
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

-- Section: Capstone - Team Workflow
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('8231161f-ca60-5da8-bf27-4161f81d0844', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Capstone - Team Workflow', 8, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6d5dda11-b14a-5131-aa88-7b55ea3b1fe0', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '8231161f-ca60-5da8-bf27-4161f81d0844', 'Feature Branch to Release, and Fixing a Bad Commit on main', 'notes', 0, $md$## The workflow we are about to run

A typical team loop: branch, commit, publish, rebase on the latest main, clean up, merge, tag,
and (when something slips through) revert. Keep this picture in mind:

```
 origin/main  A---B---C---T--------M---R(tag v1.1.0)---X---X'(revert of X)
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
    "explanation": "Conflicts are resolved by the author, not at merge time on the shared branch." }
] }
```

## Build and publish the feature

```
 BEFORE                               AFTER (3 commits + pushed)
 main: A---B---C  (origin/main)       main: A---B---C
                                                    \
                                      feature: D1---D2---D3  (also origin/feature/discount-banner)
```

```bash
cd ~/work && git clone /srv/git/storefront.git storefront && cd storefront
git switch -c feature/discount-banner
# three commits ...
git push -u origin feature/discount-banner
```

[[lab-task:1]]
[[lab-task:2]]

What you should see from `git log --oneline --graph --all`:

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
    "explanation": "Git only knows branches; the PR UI is a feature of the hosting service." }
] }
```

## main moves: rebase and resolve

```
 after teammate-land: origin/main  A---B---C---T
                      feature                \
                                              (still based on C)  D1---D2---D3

 git rebase origin/main:   A---B---C---T---D1'---D2'---D3'   (conflict on D3: GREETING line)
```

```bash
teammate land-greeting
git fetch
git switch feature/discount-banner
git rebase origin/main        # CONFLICT in app.sh
# fix app.sh: GREETING="Hello, welcome to the store"
git add app.sh && GIT_EDITOR=true git rebase --continue
```

[[lab-task:3]]
[[lab-task:4]]

What you should see:

```
Auto-merging app.sh
CONFLICT (content): Merge conflict in app.sh
error: could not apply 8d1f6c2... Update greeting
...
Successfully rebased and updated refs/heads/feature/discount-banner.
```

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
    "explanation": "Only the commit touching the line main also changed conflicts; the others replay cleanly." }
] }
```

## Tidy up: squash and update the remote

```
 BEFORE                                      AFTER
 main---T---D1'---D2'---D3'                  main---T---D'
 remote still has old D1 D2 D3               git push --force-with-lease -> remote has D'
```

```bash
git rebase -i origin/main      # 2nd, 3rd line -> fixup; reword to "Add discount banner"
git push --force-with-lease origin feature/discount-banner
```

[[lab-task:5]]
[[lab-task:6]]

What you should see:

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
    "explanation": "History was rewritten, so a plain push is rejected. The lease keeps it safe." }
] }
```

## Merge, tag, release

```
 BEFORE merge                 AFTER git merge --no-ff + tag
 main: A---B---C---T          A---B---C---T-----M   <- main, tag v1.1.0 (annotated)
                \                          \   /
 feature:        D'                          D'
```

```bash
git switch main && git pull
git merge --no-ff feature/discount-banner -m "Merge feature/discount-banner"
git push
git tag -a v1.1.0 -m "Release 1.1.0"
git push origin v1.1.0
```

[[lab-task:7]]
[[lab-task:8]]

What you should see from `git ls-remote --tags origin`:

```
a14c7be...	refs/tags/v1.1.0
5be0a93...	refs/tags/v1.1.0^{}
```

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
    "explanation": "Tags are references of their own and must be pushed on request." }
] }
```

## A bad commit reaches main

Never reset or force-push shared `main`. Revert:

```
 BEFORE revert                     AFTER git revert X; git push
 ...---M---X  <- main (broken)     ...---M---X---X'  <- main (fixed, history intact)
```

```bash
teammate land-bad
git pull
sh check.sh                              # FAIL
git revert <hash of "Switch to experimental rounding">
git push
sh check.sh                              # OK
```

[[lab-task:9]]

What you should see:

```
[main 6d2e8f1] Revert "Switch to experimental rounding"
 1 file changed, 1 insertion(+), 1 deletion(-)
OK
```

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
    "explanation": "Shared history is append-only; a revert is an ordinary, reviewable commit." }
] }
```
$md$, 60, $json$[{"id":"git-cap-flow-q1","type":"mcq","correct":"a"},{"id":"git-cap-publish-q1","type":"mcq","correct":"a"},{"id":"git-cap-rebase-q1","type":"mcq","correct":"a"},{"id":"git-cap-squash-q1","type":"mcq","correct":"a"},{"id":"git-cap-tag-q1","type":"mcq","correct":"a"},{"id":"git-cap-revert-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('dd19c2d2-b23f-540c-a234-9c4126c54766', '00000000-0000-0000-0000-000000000001', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '6d5dda11-b14a-5131-aa88-7b55ea3b1fe0', 'module', 'Feature Branch to Release, and Fixing a Bad Commit on main', NULL, 'terminal', 'mindforge/lab-debug:1', 0, $script$umask 000
git config --system init.defaultBranch main
git config --system safe.directory '*'
git config --system pull.rebase false
git config --system user.name "Lab Student"
git config --system user.email "student@lab.local"
rm -rf /srv/git /home/labuser/work/storefront /tmp/seed
mkdir -p /srv/git
git init -q --bare /srv/git/storefront.git
git clone -q /srv/git/storefront.git /tmp/seed 2>/dev/null
cd /tmp/seed
export GIT_AUTHOR_NAME="Maya Lead" GIT_AUTHOR_EMAIL=maya@example.com GIT_COMMITTER_NAME="Maya Lead" GIT_COMMITTER_EMAIL=maya@example.com
c() { git add -A; GIT_AUTHOR_DATE="$1T10:00:00+0000" GIT_COMMITTER_DATE="$1T10:00:00+0000" git commit -q -m "$2"; }
echo "# Storefront" > README.md; c 2024-07-01 "Initial commit"
printf 'GREETING="Welcome"\nround() { echo $(( ($1 + 5) / 10 * 10 )); }\n' > app.sh; c 2024-07-02 "Add app script"
printf '. ./app.sh\n[ "$(round 14)" = 10 ] || { echo FAIL; exit 1; }\necho OK\n' > check.sh; c 2024-07-03 "Add check script"
git push -q origin main
cd /; rm -rf /tmp/seed
git --git-dir=/srv/git/storefront.git symbolic-ref HEAD refs/heads/main
cat > /usr/local/bin/teammate <<'SCRIPT'
#!/bin/bash
# Simulates Maya pushing to origin/main. usage: teammate land-greeting | land-bad
set -e
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
git clone -q /srv/git/storefront.git "$t/w" 2>/dev/null; cd "$t/w"
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
chmod 755 /usr/local/bin/teammate
chmod -R a+rwX /srv/git
$script$, NULL, 60, 3, 0, false, false, NULL, 'console', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '54c2960c-8c22-5cf6-9a52-1e7813c77002' AND id NOT IN ('3b335974-a7c9-5414-a3fb-1e1e222943a1', '0f26bc79-ced6-5741-8df0-e81afdd96ad3', 'ef3badec-661f-5956-894a-6e159955288a', '7a8b3d3e-7059-50fc-a280-7a4b3b05bf37', 'a7564021-9195-5d7c-b26e-1496070472b0', '739caf5a-e19a-5ad0-aa82-754834daca79', 'e7483c86-2aa9-5229-a831-43a952056fdc', '3b430220-5751-56d5-8ec5-92612bd9de8d', '504c0041-9c6b-58a9-8a22-4788761b5772');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '54c2960c-8c22-5cf6-9a52-1e7813c77002';
DELETE FROM lab_tasks WHERE lab_id = 'dd19c2d2-b23f-540c-a234-9c4126c54766' AND id NOT IN ('f1a90460-ec4b-5e7f-be18-8b810ec8a8d6', '3e787a98-3c96-5a16-bcd0-e1e3951f3013', '90a5a745-5d4e-55a7-b39e-7543262d5a58', '5223d9e1-2b63-5b83-8b29-3ead2d836db8', 'dfbaba7f-41e8-5db1-93c8-008a00bea4c6', 'def03691-0b8a-5fa4-b2ab-00f35d7cb19c', '34efc9e3-90c1-55fb-aa4c-3f571e6e6870', '47f4dd60-c208-5a9b-b80c-5761d679d1dd', 'beb80b5f-c387-54a0-a0da-8996c7fb9d9d');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'dd19c2d2-b23f-540c-a234-9c4126c54766';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('f1a90460-ec4b-5e7f-be18-8b810ec8a8d6', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 1, 'Build the feature on a branch', $md$Clone /srv/git/storefront.git into ~/work/storefront. Create branch feature/discount-banner with exactly three commits: add banner.txt, tweak banner.txt (a "WIP" commit), and change the GREETING line in app.sh to GREETING="Welcome to the store".$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r rev-list --count origin/main..feature/discount-banner)" = 3 ] &&
git -C $r show feature/discount-banner:banner.txt >/dev/null &&
git -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING="Welcome to the store"'
$script$, 'git clone, git switch -c feature/discount-banner, then three separate git commit invocations. Use sed -i or an editor for the GREETING change.', 'Small, separate commits are normal while working; you will tidy them before the review.', 15, false, true),
('3e787a98-3c96-5a16-bcd0-e1e3951f3013', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 2, 'Push the branch (open the pull request)', $md$Publish feature/discount-banner to origin and set its upstream - on a real server this is what lets you open a pull request.$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)" = "$(git -C $r rev-parse feature/discount-banner)" ] &&
[ "$(git -C $r rev-parse feature/discount-banner@{upstream})" = "$(git -C $r rev-parse feature/discount-banner)" ]
$script$, 'git push -u origin feature/discount-banner', 'A pull request is just a branch on the server plus a request to merge it. Everything else (review, CI) happens around that branch.', 10, false, true),
('90a5a745-5d4e-55a7-b39e-7543262d5a58', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 3, 'A teammate lands a change on main', $md$Run the helper teammate land-greeting (it pushes a commit to origin/main, changing the same GREETING line). Then fetch so you can see it in origin/main.$md$, $script$r=/home/labuser/work/storefront
git -C $r log origin/main --format=%s | grep -qx "Change greeting wording" &&
[ "$(git -C $r rev-parse origin/main)" = "$(git -C $r ls-remote origin refs/heads/main | cut -f1)" ]
$script$, 'teammate land-greeting, then git fetch, then git log --oneline --graph --all.', 'While your branch was open, main moved. Your branch is now based on an older main and touches a line that changed on both sides.', 10, false, true),
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
('beb80b5f-c387-54a0-a0da-8996c7fb9d9d', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 9, 'Revert a bad commit pushed to main', $md$Run teammate land-bad - it pushes a commit "Switch to experimental rounding" that breaks check.sh on main. Pull it, revert that commit (do not rewrite history) and push so check.sh passes again on origin/main.$md$, $script$o=/srv/git/storefront.git
git --git-dir=$o log main --format=%s | grep -qx 'Revert "Switch to experimental rounding"' &&
git --git-dir=$o log main --format=%s | grep -qx 'Switch to experimental rounding' &&
[ "$(git --git-dir=$o rev-parse main)" = "$(git -C /home/labuser/work/storefront rev-parse main)" ] &&
d=$(mktemp -d) && git --git-dir=$o archive main | tar -x -C $d && (cd $d && sh check.sh | grep -qx OK)
$script$, 'teammate land-bad, git pull, git log --oneline to find the bad hash, git revert <hash>, git push. Run sh check.sh to confirm.', 'main is shared and already pulled by others, so you add a new commit that undoes the bad one. History stays append-only and the fix can ship immediately.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('54c2960c-8c22-5cf6-9a52-1e7813c77002', 'dd19c2d2-b23f-540c-a234-9c4126c54766', 1, $json$[{"id":"f1a90460-ec4b-5e7f-be18-8b810ec8a8d6","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":1,"title":"Build the feature on a branch","description":"Clone /srv/git/storefront.git into ~/work/storefront. Create branch feature/discount-banner with exactly three commits: add banner.txt, tweak banner.txt (a \"WIP\" commit), and change the GREETING line in app.sh to GREETING=\"Welcome to the store\".","verification_script":"r=/home/labuser/work/storefront\n[ \"$(git -C $r rev-list --count origin/main..feature/discount-banner)\" = 3 ] \u0026\u0026\ngit -C $r show feature/discount-banner:banner.txt \u003e/dev/null \u0026\u0026\ngit -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING=\"Welcome to the store\"'\n","hint_context":"git clone, git switch -c feature/discount-banner, then three separate git commit invocations. Use sed -i or an editor for the GREETING change.","explanation_context":"Small, separate commits are normal while working; you will tidy them before the review.","points":15,"is_optional":false,"is_stateful":true},{"id":"3e787a98-3c96-5a16-bcd0-e1e3951f3013","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":2,"title":"Push the branch (open the pull request)","description":"Publish feature/discount-banner to origin and set its upstream - on a real server this is what lets you open a pull request.","verification_script":"r=/home/labuser/work/storefront\n[ \"$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)\" = \"$(git -C $r rev-parse feature/discount-banner)\" ] \u0026\u0026\n[ \"$(git -C $r rev-parse feature/discount-banner@{upstream})\" = \"$(git -C $r rev-parse feature/discount-banner)\" ]\n","hint_context":"git push -u origin feature/discount-banner","explanation_context":"A pull request is just a branch on the server plus a request to merge it. Everything else (review, CI) happens around that branch.","points":10,"is_optional":false,"is_stateful":true},{"id":"90a5a745-5d4e-55a7-b39e-7543262d5a58","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":3,"title":"A teammate lands a change on main","description":"Run the helper teammate land-greeting (it pushes a commit to origin/main, changing the same GREETING line). Then fetch so you can see it in origin/main.","verification_script":"r=/home/labuser/work/storefront\ngit -C $r log origin/main --format=%s | grep -qx \"Change greeting wording\" \u0026\u0026\n[ \"$(git -C $r rev-parse origin/main)\" = \"$(git -C $r ls-remote origin refs/heads/main | cut -f1)\" ]\n","hint_context":"teammate land-greeting, then git fetch, then git log --oneline --graph --all.","explanation_context":"While your branch was open, main moved. Your branch is now based on an older main and touches a line that changed on both sides.","points":10,"is_optional":false,"is_stateful":true},{"id":"5223d9e1-2b63-5b83-8b29-3ead2d836db8","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":4,"title":"Rebase the branch and resolve the conflict","description":"Rebase feature/discount-banner onto origin/main. The greeting commit conflicts; resolve app.sh so GREETING is \"Hello, welcome to the store\" (keep the round line unchanged), continue the rebase, and end with the same three commits on top of origin/main.","verification_script":"r=/home/labuser/work/storefront\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\ngit -C $r merge-base --is-ancestor origin/main feature/discount-banner \u0026\u0026\n[ \"$(git -C $r rev-list --count origin/main..feature/discount-banner)\" = 3 ] \u0026\u0026\ngit -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING=\"Hello, welcome to the store\"' \u0026\u0026\ngit -C $r show feature/discount-banner:app.sh | grep -q '^round()' \u0026\u0026\n[ -z \"$(git -C $r grep -nE '^(\u003c\u003c\u003c\u003c\u003c\u003c\u003c|=======|\u003e\u003e\u003e\u003e\u003e\u003e\u003e)' feature/discount-banner)\" ]\n","hint_context":"git switch feature/discount-banner \u0026\u0026 git rebase origin/main. Fix app.sh, git add app.sh, GIT_EDITOR=true git rebase --continue.","explanation_context":"Rebasing replays your three commits on the new main so the final merge is trivial and history stays linear. The conflict is the same one a merge would have raised.","points":20,"is_optional":false,"is_stateful":true},{"id":"dfbaba7f-41e8-5db1-93c8-008a00bea4c6","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":5,"title":"Squash the branch into one commit","description":"Use interactive rebase to squash the three commits into a single commit with the message \"Add discount banner\".","verification_script":"r=/home/labuser/work/storefront\n[ ! -d $r/.git/rebase-merge ] \u0026\u0026\n[ \"$(git -C $r rev-list --count origin/main..feature/discount-banner)\" = 1 ] \u0026\u0026\n[ \"$(git -C $r log feature/discount-banner -1 --format=%s)\" = \"Add discount banner\" ] \u0026\u0026\ngit -C $r show feature/discount-banner:banner.txt \u003e/dev/null \u0026\u0026\ngit -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING=\"Hello, welcome to the store\"'\n","hint_context":"git rebase -i origin/main, change the 2nd and 3rd pick to fixup (or squash), then reword the remaining commit.","explanation_context":"Reviewers and git bisect prefer one coherent commit per change. Squashing removes the WIP noise before it lands on main.","points":15,"is_optional":false,"is_stateful":true},{"id":"def03691-0b8a-5fa4-b2ab-00f35d7cb19c","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":6,"title":"Update the remote branch safely","description":"The remote branch still has the old three commits. Update it with --force-with-lease.","verification_script":"r=/home/labuser/work/storefront\n[ \"$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)\" = \"$(git -C $r rev-parse feature/discount-banner)\" ] \u0026\u0026\n[ \"$(git -C $r log origin/feature/discount-banner -1 --format=%s)\" = \"Add discount banner\" ]\n","hint_context":"git push --force-with-lease origin feature/discount-banner","explanation_context":"Rewriting your own feature branch after review feedback is normal; the lease protects against overwriting a reviewer's pushed fixup.","points":10,"is_optional":false,"is_stateful":true},{"id":"34efc9e3-90c1-55fb-aa4c-3f571e6e6870","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":7,"title":"Merge the pull request into main","description":"Update local main from origin, then merge feature/discount-banner into main with --no-ff and the message \"Merge feature/discount-banner\", and push main.","verification_script":"r=/home/labuser/work/storefront\n[ \"$(git -C $r ls-remote origin refs/heads/main | cut -f1)\" = \"$(git -C $r rev-parse main)\" ] \u0026\u0026\n[ \"$(git -C $r log main -1 --format=%s)\" = \"Merge feature/discount-banner\" ] \u0026\u0026\n[ \"$(git -C $r rev-list --parents -n 1 main | wc -w)\" = 3 ] \u0026\u0026\n[ \"$(git -C $r log main^1 -1 --format=%s)\" = \"Change greeting wording\" ] \u0026\u0026\n[ \"$(git -C $r log main^2 -1 --format=%s)\" = \"Add discount banner\" ] \u0026\u0026\n[ -z \"$(git -C $r status --porcelain)\" ]\n","hint_context":"git switch main \u0026\u0026 git pull, then git merge --no-ff feature/discount-banner -m \"Merge feature/discount-banner\", then git push.","explanation_context":"Because the branch was rebased onto the latest main, the merge cannot conflict. --no-ff keeps one merge commit as the unit of the pull request.","points":20,"is_optional":false,"is_stateful":true},{"id":"47f4dd60-c208-5a9b-b80c-5761d679d1dd","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":8,"title":"Tag the release","description":"Create an annotated tag v1.1.0 with the message \"Release 1.1.0\" on the current main tip and push it to origin.","verification_script":"r=/home/labuser/work/storefront\n[ \"$(git -C $r cat-file -t v1.1.0)\" = tag ] \u0026\u0026\ngit -C $r tag -n1 v1.1.0 | grep -q 'Release 1.1.0' \u0026\u0026\n[ \"$(git -C $r ls-remote origin 'refs/tags/v1.1.0^{}' | cut -f1)\" = \"$(git -C $r rev-parse main)\" ]\n","hint_context":"git tag -a v1.1.0 -m \"Release 1.1.0\", then git push origin v1.1.0 (tags are not pushed by a plain git push).","explanation_context":"An annotated tag is a real object with a tagger, date and message, which is what releases should use. Tags are pushed explicitly.","points":15,"is_optional":false,"is_stateful":true},{"id":"beb80b5f-c387-54a0-a0da-8996c7fb9d9d","lab_id":"dd19c2d2-b23f-540c-a234-9c4126c54766","position":9,"title":"Revert a bad commit pushed to main","description":"Run teammate land-bad - it pushes a commit \"Switch to experimental rounding\" that breaks check.sh on main. Pull it, revert that commit (do not rewrite history) and push so check.sh passes again on origin/main.","verification_script":"o=/srv/git/storefront.git\ngit --git-dir=$o log main --format=%s | grep -qx 'Revert \"Switch to experimental rounding\"' \u0026\u0026\ngit --git-dir=$o log main --format=%s | grep -qx 'Switch to experimental rounding' \u0026\u0026\n[ \"$(git --git-dir=$o rev-parse main)\" = \"$(git -C /home/labuser/work/storefront rev-parse main)\" ] \u0026\u0026\nd=$(mktemp -d) \u0026\u0026 git --git-dir=$o archive main | tar -x -C $d \u0026\u0026 (cd $d \u0026\u0026 sh check.sh | grep -qx OK)\n","hint_context":"teammate land-bad, git pull, git log --oneline to find the bad hash, git revert \u003chash\u003e, git push. Run sh check.sh to confirm.","explanation_context":"main is shared and already pulled by others, so you add a new commit that undoes the bad one. History stays append-only and the fix can ship immediately.","points":25,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('3b335974-a7c9-5414-a3fb-1e1e222943a1', '54c2960c-8c22-5cf6-9a52-1e7813c77002', 'f1a90460-ec4b-5e7f-be18-8b810ec8a8d6', 1, 'Build the feature on a branch', $md$Clone /srv/git/storefront.git into ~/work/storefront. Create branch feature/discount-banner with exactly three commits: add banner.txt, tweak banner.txt (a "WIP" commit), and change the GREETING line in app.sh to GREETING="Welcome to the store".$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r rev-list --count origin/main..feature/discount-banner)" = 3 ] &&
git -C $r show feature/discount-banner:banner.txt >/dev/null &&
git -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING="Welcome to the store"'
$script$, 'git clone, git switch -c feature/discount-banner, then three separate git commit invocations. Use sed -i or an editor for the GREETING change.', 'Small, separate commits are normal while working; you will tidy them before the review.', 15, false, true),
('0f26bc79-ced6-5741-8df0-e81afdd96ad3', '54c2960c-8c22-5cf6-9a52-1e7813c77002', '3e787a98-3c96-5a16-bcd0-e1e3951f3013', 2, 'Push the branch (open the pull request)', $md$Publish feature/discount-banner to origin and set its upstream - on a real server this is what lets you open a pull request.$md$, $script$r=/home/labuser/work/storefront
[ "$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)" = "$(git -C $r rev-parse feature/discount-banner)" ] &&
[ "$(git -C $r rev-parse feature/discount-banner@{upstream})" = "$(git -C $r rev-parse feature/discount-banner)" ]
$script$, 'git push -u origin feature/discount-banner', 'A pull request is just a branch on the server plus a request to merge it. Everything else (review, CI) happens around that branch.', 10, false, true),
('ef3badec-661f-5956-894a-6e159955288a', '54c2960c-8c22-5cf6-9a52-1e7813c77002', '90a5a745-5d4e-55a7-b39e-7543262d5a58', 3, 'A teammate lands a change on main', $md$Run the helper teammate land-greeting (it pushes a commit to origin/main, changing the same GREETING line). Then fetch so you can see it in origin/main.$md$, $script$r=/home/labuser/work/storefront
git -C $r log origin/main --format=%s | grep -qx "Change greeting wording" &&
[ "$(git -C $r rev-parse origin/main)" = "$(git -C $r ls-remote origin refs/heads/main | cut -f1)" ]
$script$, 'teammate land-greeting, then git fetch, then git log --oneline --graph --all.', 'While your branch was open, main moved. Your branch is now based on an older main and touches a line that changed on both sides.', 10, false, true),
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
('504c0041-9c6b-58a9-8a22-4788761b5772', '54c2960c-8c22-5cf6-9a52-1e7813c77002', 'beb80b5f-c387-54a0-a0da-8996c7fb9d9d', 9, 'Revert a bad commit pushed to main', $md$Run teammate land-bad - it pushes a commit "Switch to experimental rounding" that breaks check.sh on main. Pull it, revert that commit (do not rewrite history) and push so check.sh passes again on origin/main.$md$, $script$o=/srv/git/storefront.git
git --git-dir=$o log main --format=%s | grep -qx 'Revert "Switch to experimental rounding"' &&
git --git-dir=$o log main --format=%s | grep -qx 'Switch to experimental rounding' &&
[ "$(git --git-dir=$o rev-parse main)" = "$(git -C /home/labuser/work/storefront rev-parse main)" ] &&
d=$(mktemp -d) && git --git-dir=$o archive main | tar -x -C $d && (cd $d && sh check.sh | grep -qx OK)
$script$, 'teammate land-bad, git pull, git log --oneline to find the bad hash, git revert <hash>, git push. Run sh check.sh to confirm.', 'main is shared and already pulled by others, so you add a new commit that undoes the bad one. History stays append-only and the fix can ship immediately.', 25, false, true)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '54c2960c-8c22-5cf6-9a52-1e7813c77002', updated_at = now()
WHERE id = 'dd19c2d2-b23f-540c-a234-9c4126c54766' AND published_version_id IS NULL;

-- Section: Cheat Sheet
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('0bb14d20-e0f6-573d-b293-2dd7b7d0a02b', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', 'Cheat Sheet', 9, NULL)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2462e786-3387-523e-acf7-0bb1e9635c31', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '0bb14d20-e0f6-573d-b293-2dd7b7d0a02b', 'One-Page Git Cheat Sheet', 'notes', 0, $md$Safety legend: **safe** changes nothing you cannot recover, **rewrites** creates new commits and
leaves the old ones only in the reflog, **destructive** can lose uncommitted work.

## Inspect (read-only)

| Command | What it changes | Safety |
|---|---|---|
| `git status` / `git status -s` | Nothing, shows the three areas | safe |
| `git diff` / `git diff --staged` | Nothing, working vs index / index vs HEAD | safe |
| `git log --oneline --graph --all` | Nothing, draws the commit graph | safe |
| `git show <rev>` / `git show <rev>:<path>` | Nothing, one commit or file version | safe |
| `git blame -L a,b -w -C <file>` | Nothing, who last changed each line | safe |
| `git log -S str` / `-G regex` / `--follow file` | Nothing, searches history | safe |
| `git reflog` | Nothing, where HEAD has been | safe |

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
    "explanation": "git diff alone shows unstaged changes." }
] }
```

## Record and share

| Command | What it changes | Safety |
|---|---|---|
| `git add <path>` | Index | safe |
| `git commit -m msg` | Adds a commit, moves the branch | safe |
| `git commit --amend` | Replaces the last commit | rewrites |
| `git clone <url>` | Creates a repo with origin and tracking branches | safe |
| `git fetch` | Remote-tracking branches only | safe |
| `git pull` | fetch + merge (or rebase) into current branch | safe, may conflict |
| `git push` / `git push -u origin <branch>` | Remote branch (fast-forward only) | safe |
| `git push --force-with-lease` | Overwrites the remote branch if unchanged since your fetch | rewrites (shared) |
| `git push --force` | Overwrites the remote branch blindly | destructive for teammates |
| `git tag -a v1 -m msg` + `git push origin v1` | Adds an annotated tag | safe |

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
    "explanation": "pull would also integrate into the current branch." }
] }
```

## Branch, merge, rebase

| Command | What it changes | Safety |
|---|---|---|
| `git switch -c <name>` | New branch pointer, moves HEAD | safe |
| `git merge <branch>` | Fast-forwards or adds a merge commit | safe, may conflict |
| `git merge --no-ff <branch>` | Always adds a merge commit | safe |
| `git merge --abort` | Returns to the pre-merge state | safe |
| `git branch -d <name>` | Deletes a merged branch pointer | safe |
| `git branch -D <name>` | Deletes an unmerged branch pointer | destructive (recoverable via reflog) |
| `git rebase <base>` | Replays your commits with new hashes | rewrites |
| `git rebase -i <base>` | Squash, reword, reorder, drop | rewrites |
| `git rebase --continue` / `--abort` | Continue after a fix / go back | safe |
| `git config rerere.enabled true` | Remembers conflict resolutions | safe |

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
    "explanation": "Rewriting shared history makes everyone else's copy diverge." }
] }
```

## Undo and recover

| Command | What it changes | Safety |
|---|---|---|
| `git restore <file>` | Working tree file from index | destructive (uncommitted edits lost) |
| `git restore --staged <file>` | Index only | safe |
| `git reset --soft <rev>` | Branch pointer only, changes stay staged | rewrites |
| `git reset --mixed <rev>` (default) | Branch + index, changes stay in working tree | rewrites |
| `git reset --hard <rev>` | Branch + index + working tree | destructive |
| `git revert <rev>` / `git revert -m 1 <merge>` | Adds a commit that undoes another | safe (shared branches) |
| `git cherry-pick <rev>` | Copies one commit onto the current branch | safe, may conflict |
| `git stash push -m msg` / `git stash pop` | Parks / restores uncommitted work | safe |
| `git reflog` + `git reset --hard <hash>` | Recovers commits lost by reset or amend | safe if done within ~90 days |
| `git bisect start BAD GOOD` + `git bisect run <cmd>` | Temporarily checks out commits, then `git bisect reset` | safe |

```
              HEAD    INDEX    WORKING TREE
 --soft       moves   keeps    keeps
 --mixed      moves   reset    keeps
 --hard       moves   reset    reset
```

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
    "explanation": "The reflog keeps old positions of HEAD until garbage collection." },
  { "id": "git-cheat-undo-q2", "type": "mcq",
    "prompt": "Which undo is safe on a shared branch?",
    "options": [
      {"id":"a","text":"git revert"},
      {"id":"b","text":"git reset --hard plus force push"},
      {"id":"c","text":"git commit --amend plus force push"},
      {"id":"d","text":"git rebase -i plus force push"}],
    "correct": "a",
    "explanation": "revert only appends history." }
] }
```
$md$, 10, $json$[{"id":"git-cheat-inspect-q1","type":"mcq","correct":"a"},{"id":"git-cheat-share-q1","type":"mcq","correct":"a"},{"id":"git-cheat-branch-q1","type":"mcq","correct":"a"},{"id":"git-cheat-undo-q1","type":"mcq","correct":"a"},{"id":"git-cheat-undo-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('77fd5af5-36a1-58bd-8e72-f1087ec57d24', '00000000-0000-0000-0000-000000000014', 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

DELETE FROM course_modules WHERE course_id = 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44' AND id NOT IN ('74b2f660-185b-521e-8bba-942899d63e41', '947b350f-4ed2-52fc-a567-1835f9dc5805', 'e7308f90-9b11-586e-a880-349ba6e409b0', '74fb2616-b5a3-50ad-a6ed-381dfce33769', '86e78574-a4f8-5c6a-9b7a-7100dd51962d', 'a9dbf033-3c13-5141-b45d-b5b6a1e8d407', 'e9c35a89-dd93-5e9a-bcb3-722e6879a5f3', '6d5dda11-b14a-5131-aa88-7b55ea3b1fe0', '2462e786-3387-523e-acf7-0bb1e9635c31');
DELETE FROM course_sections WHERE course_id = 'ece2cd04-2e10-5cb1-a0b5-9eef2950ce44' AND id NOT IN ('30bd438b-14f7-5688-bfd5-d78aef9b27d3', 'd7c6f575-b087-5a71-9221-aabdc36b6f72', '498e7765-54bf-5ac3-a80c-bab3bb98f650', '0bfdc51c-0996-5a60-beac-0ac183d3389c', 'bc66d97b-4855-5638-8fbb-d9d46ae7f1b7', '7a77d065-f51b-5ec5-9aea-a09bdcfb797c', '462878a1-6134-50d3-953c-444b70b83668', '8231161f-ca60-5da8-bf27-4161f81d0844', '0bb14d20-e0f6-573d-b293-2dd7b7d0a02b');

