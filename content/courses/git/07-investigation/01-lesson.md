---
kind: lesson
id_key: git/investigation/lesson
course: git
section: investigation
section_title: Investigating History
section_position: 7
title: blame, log -S/-G, --follow, bisect and show
position: 0
estimated_minutes: 50
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

## blame: who wrote this line?

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
