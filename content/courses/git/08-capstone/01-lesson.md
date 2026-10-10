---
kind: lesson
id_key: git/capstone/lesson
course: git
section: capstone
section_title: Capstone - Team Workflow
section_position: 10
title: Feature Branch to Release, and Fixing a Bad Commit on main
position: 0
estimated_minutes: 60
source:
  - Pro Git book, ch. 5 "Distributed Git" and ch. 2.6 "Tagging"
  - git-tag(1), git-revert(1), git-rebase(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 60
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    umask 000
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
  tasks:
    - id_key: feature-branch
      title: Build the feature on a branch
      points: 15
      is_stateful: true
      description: 'Clone /srv/git/storefront.git into ~/work/storefront. Create branch feature/discount-banner with exactly three commits: add banner.txt, tweak banner.txt (a "WIP" commit), and change the GREETING line in app.sh to GREETING="Welcome to the store".'
      verification_script: |
        r=/home/labuser/work/storefront
        [ "$(git -C $r rev-list --count origin/main..feature/discount-banner)" = 3 ] &&
        git -C $r show feature/discount-banner:banner.txt >/dev/null &&
        git -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING="Welcome to the store"'
      hint_context: git clone, git switch -c feature/discount-banner, then three separate git commit invocations. Use sed -i or an editor for the GREETING change.
      explanation_context: Small, separate commits are normal while working; you will tidy them before the review.
      solution_script: |
        cd ~/work && git clone /srv/git/storefront.git storefront && cd storefront
        git switch -c feature/discount-banner
        echo "SALE 10% off" > banner.txt && git add banner.txt && git commit -m "Add banner text"
        echo "style: bold" >> banner.txt && git commit -am "WIP banner styling"
        sed -i 's/^GREETING=.*/GREETING="Welcome to the store"/' app.sh && git commit -am "Update greeting"
    - id_key: open-pr
      title: Push the branch (open the pull request)
      points: 10
      is_stateful: true
      description: Publish feature/discount-banner to origin and set its upstream - on a real server this is what lets you open a pull request.
      verification_script: |
        r=/home/labuser/work/storefront
        [ "$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)" = "$(git -C $r rev-parse feature/discount-banner)" ] &&
        [ "$(git -C $r rev-parse feature/discount-banner@{upstream})" = "$(git -C $r rev-parse feature/discount-banner)" ]
      hint_context: git push -u origin feature/discount-banner
      explanation_context: A pull request is just a branch on the server plus a request to merge it. Everything else (review, CI) happens around that branch.
      solution_script: |
        cd ~/work/storefront
        git push -u origin feature/discount-banner
    - id_key: main-moves
      title: A teammate lands a change on main
      points: 10
      is_stateful: true
      description: Run the helper teammate land-greeting (it pushes a commit to origin/main, changing the same GREETING line). Then fetch so you can see it in origin/main.
      verification_script: |
        r=/home/labuser/work/storefront
        git -C $r log origin/main --format=%s | grep -qx "Change greeting wording" &&
        [ "$(git -C $r rev-parse origin/main)" = "$(git -C $r ls-remote origin refs/heads/main | cut -f1)" ]
      hint_context: teammate land-greeting, then git fetch, then git log --oneline --graph --all.
      explanation_context: While your branch was open, main moved. Your branch is now based on an older main and touches a line that changed on both sides.
      solution_script: |
        teammate land-greeting
        cd ~/work/storefront && git fetch
    - id_key: rebase-resolve
      title: Rebase the branch and resolve the conflict
      points: 20
      is_stateful: true
      description: Rebase feature/discount-banner onto origin/main. The greeting commit conflicts; resolve app.sh so GREETING is "Hello, welcome to the store" (keep the round line unchanged), continue the rebase, and end with the same three commits on top of origin/main.
      verification_script: |
        r=/home/labuser/work/storefront
        [ ! -d $r/.git/rebase-merge ] &&
        git -C $r merge-base --is-ancestor origin/main feature/discount-banner &&
        [ "$(git -C $r rev-list --count origin/main..feature/discount-banner)" = 3 ] &&
        git -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING="Hello, welcome to the store"' &&
        git -C $r show feature/discount-banner:app.sh | grep -q '^round()' &&
        [ -z "$(git -C $r grep -nE '^(<<<<<<<|=======|>>>>>>>)' feature/discount-banner)" ]
      hint_context: git switch feature/discount-banner && git rebase origin/main. Fix app.sh, git add app.sh, GIT_EDITOR=true git rebase --continue.
      explanation_context: Rebasing replays your three commits on the new main so the final merge is trivial and history stays linear. The conflict is the same one a merge would have raised.
      solution_script: |
        cd ~/work/storefront
        git switch feature/discount-banner
        git rebase origin/main || true
        printf 'GREETING="Hello, welcome to the store"\nround() { echo $(( ($1 + 5) / 10 * 10 )); }\n' > app.sh
        git add app.sh
        GIT_EDITOR=true git rebase --continue
    - id_key: squash-branch
      title: Squash the branch into one commit
      points: 15
      is_stateful: true
      description: Use interactive rebase to squash the three commits into a single commit with the message "Add discount banner".
      verification_script: |
        r=/home/labuser/work/storefront
        [ ! -d $r/.git/rebase-merge ] &&
        [ "$(git -C $r rev-list --count origin/main..feature/discount-banner)" = 1 ] &&
        [ "$(git -C $r log feature/discount-banner -1 --format=%s)" = "Add discount banner" ] &&
        git -C $r show feature/discount-banner:banner.txt >/dev/null &&
        git -C $r show feature/discount-banner:app.sh | grep -qx 'GREETING="Hello, welcome to the store"'
      hint_context: git rebase -i origin/main, change the 2nd and 3rd pick to fixup (or squash), then reword the remaining commit.
      explanation_context: Reviewers and git bisect prefer one coherent commit per change. Squashing removes the WIP noise before it lands on main.
      solution_script: |
        cd ~/work/storefront
        git switch feature/discount-banner
        GIT_SEQUENCE_EDITOR="sed -i '2,\$s/^pick/fixup/'" git rebase -i origin/main
        git commit --amend -m "Add discount banner"
    - id_key: force-push-branch
      title: Update the remote branch safely
      points: 10
      is_stateful: true
      description: The remote branch still has the old three commits. Update it with --force-with-lease.
      verification_script: |
        r=/home/labuser/work/storefront
        [ "$(git -C $r ls-remote origin refs/heads/feature/discount-banner | cut -f1)" = "$(git -C $r rev-parse feature/discount-banner)" ] &&
        [ "$(git -C $r log origin/feature/discount-banner -1 --format=%s)" = "Add discount banner" ]
      hint_context: git push --force-with-lease origin feature/discount-banner
      explanation_context: Rewriting your own feature branch after review feedback is normal; the lease protects against overwriting a reviewer's pushed fixup.
      solution_script: |
        cd ~/work/storefront
        git push --force-with-lease origin feature/discount-banner
    - id_key: merge-to-main
      title: Merge the pull request into main
      points: 20
      is_stateful: true
      description: Update local main from origin, then merge feature/discount-banner into main with --no-ff and the message "Merge feature/discount-banner", and push main.
      verification_script: |
        r=/home/labuser/work/storefront
        [ "$(git -C $r ls-remote origin refs/heads/main | cut -f1)" = "$(git -C $r rev-parse main)" ] &&
        [ "$(git -C $r log main -1 --format=%s)" = "Merge feature/discount-banner" ] &&
        [ "$(git -C $r rev-list --parents -n 1 main | wc -w)" = 3 ] &&
        [ "$(git -C $r log main^1 -1 --format=%s)" = "Change greeting wording" ] &&
        [ "$(git -C $r log main^2 -1 --format=%s)" = "Add discount banner" ] &&
        [ -z "$(git -C $r status --porcelain)" ]
      hint_context: git switch main && git pull, then git merge --no-ff feature/discount-banner -m "Merge feature/discount-banner", then git push.
      explanation_context: Because the branch was rebased onto the latest main, the merge cannot conflict. --no-ff keeps one merge commit as the unit of the pull request.
      solution_script: |
        cd ~/work/storefront
        git switch main
        git pull --no-rebase
        git merge --no-ff --no-edit -m "Merge feature/discount-banner" feature/discount-banner
        git push
    - id_key: tag-release
      title: Tag the release
      points: 15
      is_stateful: true
      description: Create an annotated tag v1.1.0 with the message "Release 1.1.0" on the current main tip and push it to origin.
      verification_script: |
        r=/home/labuser/work/storefront
        [ "$(git -C $r cat-file -t v1.1.0)" = tag ] &&
        git -C $r tag -n1 v1.1.0 | grep -q 'Release 1.1.0' &&
        [ "$(git -C $r ls-remote origin 'refs/tags/v1.1.0^{}' | cut -f1)" = "$(git -C $r rev-parse main)" ]
      hint_context: git tag -a v1.1.0 -m "Release 1.1.0", then git push origin v1.1.0 (tags are not pushed by a plain git push).
      explanation_context: An annotated tag is a real object with a tagger, date and message, which is what releases should use. Tags are pushed explicitly.
      solution_script: |
        cd ~/work/storefront
        git tag -a v1.1.0 -m "Release 1.1.0"
        git push origin v1.1.0
    - id_key: revert-bad-main
      title: Revert a bad commit pushed to main
      points: 25
      is_stateful: true
      description: Run teammate land-bad - it pushes a commit "Switch to experimental rounding" that breaks check.sh on main. Pull it, revert that commit (do not rewrite history) and push so check.sh passes again on origin/main.
      verification_script: |
        o=/srv/git/storefront.git
        git --git-dir=$o log main --format=%s | grep -qx 'Revert "Switch to experimental rounding"' &&
        git --git-dir=$o log main --format=%s | grep -qx 'Switch to experimental rounding' &&
        [ "$(git --git-dir=$o rev-parse main)" = "$(git -C /home/labuser/work/storefront rev-parse main)" ] &&
        d=$(mktemp -d) && git --git-dir=$o archive main | tar -x -C $d && (cd $d && sh check.sh | grep -qx OK)
      hint_context: teammate land-bad, git pull, git log --oneline to find the bad hash, git revert <hash>, git push. Run sh check.sh to confirm.
      explanation_context: main is shared and already pulled by others, so you add a new commit that undoes the bad one. History stays append-only and the fix can ship immediately.
      solution_script: |
        teammate land-bad
        cd ~/work/storefront
        git pull --no-rebase
        git revert --no-edit "$(git log --format=%h --grep='^Switch to experimental rounding$' -1)"
        git push
---

> **Your first real release.** No hints about which command to use this time - just the situation, like on the job. Feature branch, review, release, and a bad commit on main to fix.

## The workflow we are about to run

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

> **You made it.** Keep the cheat sheet open next to your terminal for the first few weeks.
