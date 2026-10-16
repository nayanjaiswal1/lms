---
kind: lesson
id_key: git/workflows/lab-tags-hooks
course: git
section: workflows
section_title: "Team Workflows, Releases, Hooks and Signing"
section_position: 11
title: "Lab: Tag a Release and Enforce Commit Messages with a Hook"
position: 4
estimated_minutes: 30
source:
  - git-tag(1), git-describe(1), githooks(5) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 40
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    umask 000
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
  tasks:
    - id_key: tag-old-release
      title: Tag an older commit as a release
      points: 15
      is_stateful: true
      description: 'In ~/work/shop-release, release 2.0.0 was the commit "SHOP-3: Finish checkout", not the current tip. Create an annotated tag v2.0.0 with the message "Release 2.0.0" on that commit.'
      verification_script: |
        r=/home/labuser/work/shop-release
        [ "$(git -C $r cat-file -t v2.0.0 2>/dev/null)" = tag ] &&
        [ "$(git -C $r log -1 --format=%s 'v2.0.0^{commit}')" = "SHOP-3: Finish checkout" ] &&
        git -C $r tag -n1 v2.0.0 | grep -q 'Release 2.0.0'
      hint_context: Find the hash with git log --oneline, then git tag -a v2.0.0 -m "Release 2.0.0" <hash>. Without -a you get a lightweight tag, which is not a tag object.
      explanation_context: An annotated tag is its own object with tagger, date and message, pointing at a commit. Tags can point at any commit, not only HEAD.
      solution_script: |
        cd ~/work/shop-release
        git tag -a v2.0.0 -m "Release 2.0.0" "$(git log --format=%h --grep='Finish checkout' -1)"
    - id_key: push-tag
      title: Publish the tag
      points: 10
      is_stateful: true
      description: Push the tag v2.0.0 to origin. A plain git push does not send tags.
      verification_script: |
        r=/home/labuser/work/shop-release
        [ "$(git --git-dir=/home/labuser/srv/git/shop-release.git rev-parse -q --verify refs/tags/v2.0.0)" = "$(git -C $r rev-parse v2.0.0)" ]
      hint_context: git push origin v2.0.0, then git ls-remote --tags origin to confirm.
      explanation_context: Tags are refs of their own. They travel only when pushed explicitly (or with --follow-tags / push.followTags).
      solution_script: |
        cd ~/work/shop-release && git push origin v2.0.0
    - id_key: describe-head
      title: Describe HEAD relative to the release
      points: 10
      is_stateful: true
      description: Write the output of git describe for the current HEAD, alone on one line, into ~/work/describe.txt.
      verification_script: |
        r=/home/labuser/work/shop-release
        d=$(git -C $r describe 2>/dev/null) && [ -n "$d" ] &&
        [ "$(tr -d '[:space:]' < /home/labuser/work/describe.txt)" = "$d" ]
      hint_context: git describe > ~/work/describe.txt. It prints the nearest annotated tag, the number of commits since it, and the abbreviated hash.
      explanation_context: describe gives every commit a human-readable version like v2.0.0-2-g1a2b3c4 (2 commits after v2.0.0), which build systems embed as a version string.
      solution_script: |
        cd ~/work/shop-release && git describe > ~/work/describe.txt
    - id_key: shared-hook
      title: Add a shared commit-msg hook
      points: 20
      is_stateful: true
      description: 'Create an executable hook .githooks/commit-msg in the repository that rejects any commit whose subject does not start with a ticket key like "SHOP-42: ", and make Git use that folder for hooks (core.hooksPath).'
      verification_script: |
        r=/home/labuser/work/shop-release
        h=$r/.githooks/commit-msg
        [ "$(git -C $r config --get core.hooksPath)" = .githooks ] && [ -x "$h" ] &&
        t=$(mktemp) && echo "fix stuff" > "$t" && ! (cd $r && "$h" "$t" >/dev/null 2>&1) &&
        echo "SHOP-42: Add coupon support" > "$t" && (cd $r && "$h" "$t" >/dev/null 2>&1)
      hint_context: "The hook gets the message file path as $1. Test the first line with grep -qE '^[A-Z]+-[0-9]+: ' and exit 1 when it does not match. chmod +x the file, then git config core.hooksPath .githooks."
      explanation_context: .git/hooks is never cloned, so teams keep hooks in a versioned folder and point core.hooksPath at it. A non-zero exit from commit-msg cancels the commit.
      solution_script: |
        cd ~/work/shop-release
        mkdir -p .githooks
        printf '#!/bin/sh\nhead -1 "$1" | grep -qE "^[A-Z]+-[0-9]+: .+" || { echo "commit-msg: subject must look like SHOP-42: Describe change" >&2; exit 1; }\n' > .githooks/commit-msg
        chmod +x .githooks/commit-msg
        git config core.hooksPath .githooks
    - id_key: commit-through-hook
      title: Commit the hook through the hook
      points: 15
      is_stateful: true
      description: 'Commit .githooks/commit-msg with the message "SHOP-7: Add commit-msg hook" (try a bad message first and watch it fail). The file must be committed as executable.'
      verification_script: |
        r=/home/labuser/work/shop-release
        [ "$(git -C $r log -1 --format=%s)" = "SHOP-7: Add commit-msg hook" ] &&
        [ "$(git -C $r ls-tree HEAD .githooks/commit-msg | cut -d' ' -f1)" = 100755 ] &&
        [ -z "$(git -C $r status --porcelain)" ]
      hint_context: 'git add .githooks/commit-msg, then git commit -m "SHOP-7: Add commit-msg hook". A message like "add hook" should be rejected by your hook.'
      explanation_context: Git records the executable bit (mode 100755), so teammates who set core.hooksPath get a working hook straight from the repository.
      solution_script: |
        cd ~/work/shop-release
        git add .githooks/commit-msg
        git commit -m "add hook" || true
        git commit -m "SHOP-7: Add commit-msg hook"
---

## Why this matters

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
