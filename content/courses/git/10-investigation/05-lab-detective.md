---
kind: lesson
id_key: git/investigation/lesson
course: git
section: investigation
section_title: Investigating History
section_position: 9
title: "Lab: Detective Work in a Real History"
position: 4
estimated_minutes: 40
source:
  - Pro Git book, ch. 7.5 "Debugging with Git"
  - git-blame(1), git-log(1), git-bisect(1), git-show(1) manual pages
lab:
  lab_type: terminal
  environment: mindforge/lab-debug:1
  max_duration: 50
  max_resets: 3
  is_required: false
  workspace_layout: console
  setup_script: |
    umask 000
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
  tasks:
    - id_key: blame-line
      title: Find who wrote a line with blame -L
      points: 10
      description: In ~/work/inventory the tax rate line (line 1 of tax.sh) looks wrong. Use git blame -L to find its author and write the line rate_author=<name> into ~/work/answers.txt (for example rate_author=Jane Doe).
      verification_script: |
        grep -qx 'rate_author=Dave Hotfix' /home/labuser/work/answers.txt
      hint_context: git blame -L 1,1 tax.sh prints the commit and author that last touched line 1. Add --porcelain for machine-readable output.
      explanation_context: blame annotates each line with the commit that last changed it. -L limits the range so you only look at the line you care about.
      solution_script: |
        cd ~/work/inventory
        a=$(git blame -L1,1 --porcelain tax.sh | sed -n 's/^author //p')
        printf 'rate_author=%s\n' "$a" >> ~/work/answers.txt
    - id_key: blame-ignore-whitespace
      title: See through a reformat with blame -w
      points: 15
      description: Line 2 of discount.sh holds the real discount calculation, but a later reformat commit re-indented it. Plain blame names the reformatter; use git blame -w to ignore whitespace and find the real author. Write discount_author=<name> to ~/work/answers.txt.
      verification_script: |
        grep -qx 'discount_author=Carol Pricing' /home/labuser/work/answers.txt
      hint_context: Compare git blame -L2,2 discount.sh with git blame -w -L2,2 discount.sh.
      explanation_context: -w ignores whitespace-only changes when assigning blame, so a re-indent commit no longer hides the commit that wrote the logic.
      solution_script: |
        cd ~/work/inventory
        a=$(git blame -w -L2,2 --porcelain discount.sh | sed -n 's/^author //p')
        printf 'discount_author=%s\n' "$a" >> ~/work/answers.txt
    - id_key: blame-moved-code
      title: Follow moved code with blame -C
      points: 15
      description: Line 4 of util.sh (the if statement of shipping) was moved there from shipping.sh by someone else. Plain blame points at the mover; use git blame -C to trace the line to the commit that really wrote it. Write shipping_author=<name> to ~/work/answers.txt.
      verification_script: |
        grep -qx 'shipping_author=Gina Shipping' /home/labuser/work/answers.txt
      hint_context: Run git blame -C util.sh on the whole file (copy detection does not work well with -L) and read the author on the if line, which is line 4.
      explanation_context: -C looks for lines that came from another file in the same commit, -C -C also searches the commit that created the file, and -C -C -C searches all history. They make blame follow refactors.
      solution_script: |
        cd ~/work/inventory
        a=$(git blame -C util.sh | sed -nE '4s/^[^(]*\((.*[^ ]) +[0-9]{4}-.*/\1/p')
        printf 'shipping_author=%s\n' "$a" >> ~/work/answers.txt
    - id_key: log-pickaxe-s
      title: Find when a string disappeared with log -S
      points: 15
      description: The constant LEGACY_FLAG used to exist in config.sh. Use git log -S to list the commits that added or removed it, work out which one removed it, and write legacy_removed_in=<that commit's subject> to ~/work/answers.txt.
      verification_script: |
        grep -qx 'legacy_removed_in=Tidy up' /home/labuser/work/answers.txt
      hint_context: git log -S LEGACY_FLAG --oneline shows both the adding and the removing commit. Add -p to see which direction each went.
      explanation_context: -S (the pickaxe) lists commits where the number of occurrences of a string changed - i.e. where it was added or removed.
      solution_script: |
        cd ~/work/inventory
        s=$(git log -S LEGACY_FLAG --format=%s -1)
        printf 'legacy_removed_in=%s\n' "$s" >> ~/work/answers.txt
    - id_key: log-regex-g
      title: Find a changed value with log -G
      points: 15
      description: The timeout value in config.sh was changed from 30 to 45 at some point. Plain -S timeout= will not find that, because the number of occurrences did not change. Use git log -G with a regex to find the commit that CHANGED the value (not the one that created the file) and write timeout_changed_in=<subject> to ~/work/answers.txt.
      verification_script: |
        grep -qx 'timeout_changed_in=Bump timeout' /home/labuser/work/answers.txt
      hint_context: git log -G 'timeout=' --oneline lists every commit whose diff touches a matching line. The oldest one created the file.
      explanation_context: -G matches the regex against added or removed diff lines, so it catches edits to a line that -S (count-based) misses.
      solution_script: |
        cd ~/work/inventory
        s=$(git log -G 'timeout=' --format=%s -1)
        printf 'timeout_changed_in=%s\n' "$s" >> ~/work/answers.txt
    - id_key: log-follow-rename
      title: Follow a file across a rename
      points: 15
      description: pricing.sh used to be called price.sh. Use git log --follow to walk its history past the rename and write pricing_origin=<subject of the commit that first created the file> to ~/work/answers.txt.
      verification_script: |
        grep -qx 'pricing_origin=Add price helper' /home/labuser/work/answers.txt
      hint_context: git log --follow --oneline -- pricing.sh keeps listing commits under the old name. The last line is the creation.
      explanation_context: Git does not store renames; it detects them by similarity. --follow (single file only) applies that detection while walking history.
      solution_script: |
        cd ~/work/inventory
        s=$(git log --follow --format=%s -- pricing.sh | tail -1)
        printf 'pricing_origin=%s\n' "$s" >> ~/work/answers.txt
    - id_key: bisect-run
      title: Find the breaking commit with bisect run
      points: 25
      description: check.sh passes at the tag v1.0 but fails on main. Use git bisect start / git bisect run sh check.sh to let Git find the first bad commit, save its full hash in ~/work/culprit.txt, then end the bisect with git bisect reset so you are back on main.
      verification_script: |
        r=/home/labuser/work/inventory
        [ "$(git -C $r log -1 --format=%s "$(cat /home/labuser/work/culprit.txt)")" = "Speed up tax calc" ] &&
        [ ! -f $r/.git/BISECT_LOG ] &&
        [ "$(git -C $r rev-parse --abbrev-ref HEAD)" = main ]
      hint_context: git bisect start HEAD v1.0 ; git bisect run sh check.sh. When it prints "<hash> is the first bad commit", record it, then git bisect reset.
      explanation_context: bisect does a binary search over history, checking out the midpoint and asking your command (exit 0 = good, 1-124 = bad) until one commit remains - log2(N) steps for N commits.
      solution_script: |
        cd ~/work/inventory
        git bisect start HEAD v1.0 >/dev/null
        git bisect run sh check.sh >/dev/null
        git rev-parse refs/bisect/bad > ~/work/culprit.txt
        git bisect reset
    - id_key: show-culprit
      title: Inspect the culprit with git show
      points: 10
      description: Use git show on the culprit commit to read its details and write culprit_email=<author email> to ~/work/answers.txt.
      verification_script: |
        grep -qx 'culprit_email=dave@example.com' /home/labuser/work/answers.txt
      hint_context: git show -s --format='%an <%ae>' <hash> prints only the author line; git show <hash> shows the whole diff.
      explanation_context: git show prints one commit's metadata and patch (and also works for blobs, git show <rev>:<path>, and tags).
      solution_script: |
        cd ~/work/inventory
        e=$(git show -s --format=%ae "$(cat ~/work/culprit.txt)")
        printf 'culprit_email=%s\n' "$e" >> ~/work/answers.txt
---

## Why this matters

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
