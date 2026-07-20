---
name: fold-in-notes
description: "Fold pasted interview-prep / study notes (from another chat, Notion, a transcript dump) into an existing MindForge course as new lesson content — without duplicating what the course already covers. Use whenever the user pastes a chunk of Q&A/notes/explanations, whether or not they say 'add this' explicitly — a pasted technical dump is itself the trigger, per the user's standing instruction not to have to ask every time. Non-technical/personal pastes go to the `notes` skill instead, not here."
---

# Folding pasted notes into an existing course

The user will periodically paste a large, messy chunk of content (interview Q&A,
notes exported from another Claude session, a raw topic list) and say "add this" —
meaning: fold it into an **existing** MindForge course as new lesson content, not
create a new course and not just save it as a standalone file. This skill is the
procedure for doing that correctly. It assumes the target course already exists
under `content/courses/<slug>/`; for creating a course from scratch, use the
`create-course` skill instead.

## The procedure, in order

### 0. Don't wait to be asked

A pasted technical Q&A/notes dump is the trigger by itself. Run steps 1-6
immediately — check coverage, write the genuine gaps, regenerate the fixture,
report what was skipped — without first asking "do you want me to add this?"
The user has said explicitly they don't want to repeat that instruction every
time a paste lands. Only pause to ask when:
- The content doesn't clearly match any existing course's stack (see
  "Off-stack content" below) and doesn't obviously belong anywhere else either, or
- It's genuinely ambiguous whether the paste is technical (→ this skill) or
  personal (→ the `notes` skill, which lives outside this project). Classify
  by content, not by phrasing — a paste with no "add this" attached is still
  technical if it's technical content.

Never apply the regenerated fixture to a live database without asking first —
that step (`psql ... -f ...`) is the one place a real confirmation is still
required, because it mutates shared state.

### 1. Identify the right course and section

Read `content/courses/<slug>/course.yaml` to confirm the course's stack/scope
matches the pasted content (e.g. `interview-prep-45` is Python/Django/FastAPI/React —
Java-specific content like POJO doesn't belong there even if the user pastes it).
Pick the section (`backend`/`frontend`/`system-design`/`dsa`/etc.) whose topic the
content matches.

### 2. Check what's already covered — do not skip this

Before writing anything, grep the **whole course** for the specific terms in the
pasted content, not just the target section — related material often lives in an
unexpected section (e.g. GROUP BY shows up in `system-design` and `dsa`, not just
`backend`).

```bash
grep -rliE "term-one|term-two|term-three" content/courses/<slug>/
```

For every hit, open the file and read enough to judge depth — a passing mention
("`.hasOwnProperty()`, etc.") is not coverage; a dedicated explanation with a code
example is. Build a short mental list: covered-in-depth (skip), covered-shallow
(maybe supplement), not covered (add).

This step is the entire point of the skill — the pasted dumps in this project are
consistently 70-90% already covered by the existing 45-day curriculum. Writing
everything blind produces bloat and duplicate/contradictory explanations. Only the
genuine gaps get new files.

### 3. Find a safe position number

`course_modules` has `UNIQUE (section_id, position)` — you cannot reuse a position
already taken by a module in that section. List existing positions first:

```bash
for f in content/courses/<slug>/<section>/*.md; do
  grep -m1 "^position:" "$f" | sed "s|^|$(basename "$f"): |"
done | sort -t: -k2 -n
```

Day-numbered sections typically run 1..28 sequentially, then jump to a 90s block
for supplementary "Notes:"/lab/drill files, leaving a gap in between (e.g. 29-89
free). Never renumber existing lessons to make room — always find the next free
number in the existing gap or after the highest used position. `kind: quiz` files
in the same numeric block (e.g. week-drill quizzes at 91-94) are not eligible for
reuse either — check `kind:` on files near the number you're about to pick.

### 4. Write one file per coherent topic cluster, following the "Notes:" convention

Match the existing supplementary-lesson pattern exactly — look at a `9X-notes-*.md`
file in the target section before writing:

```yaml
---
kind: lesson
id_key: <course-slug>/note-<short-topic-slug>
course: <course-slug>
section: <section>
section_title: "<Exact Section Title>"   # copy from a sibling file, don't invent
section_position: <N>                     # copy from a sibling file, don't invent
title: "Notes: <Human Title>"
position: <the free number from step 3>
estimated_minutes: <15-20 typically>
source:
    - interview-prep-notes.md
---
```

Body structure: short intro (why this matters / what it builds on), one `##` per
sub-topic, code examples where the source content had them, a `## Key takeaways`
bullet list at the end. Do not restate what step 2 already found covered elsewhere —
link the relationship instead ("This builds on the prototype-chain lesson (Day 0) —
two mechanisms that lesson doesn't cover: ...").

**Group by topic cluster, not one file per Q&A line.** A pasted dump with a dozen
loose questions usually collapses into 2-4 real files once duplicates are removed
(e.g. one CSS layout file, one JS-internals file, one React file, one backend file).
Fewer, denser files beat many thin ones — matches this project's existing notes
files, which each cover 2-4 related sub-topics.

### 5. Regenerate the fixture

```bash
cd backend && go run ./cmd/coursegen generate --in ../content/courses/<slug> --out db/fixtures/<slug>.generated.sql
```

Confirm it prints `coursegen generate: wrote db/fixtures/<slug>.generated.sql` with
no errors. The output is idempotent (`ON CONFLICT ... DO UPDATE`) — safe to rerun.
This does **not** apply the SQL to the database; that's a separate, explicit step
(`psql ... -f db/fixtures/<slug>.generated.sql` against the running container) —
ask before running it, since it mutates a real database.

### 6. Report what was skipped and why

Per this project's ponytail convention: end with a short list of what was **not**
added and where it already lives, plus what was added. Don't just report the diff —
the skipped-as-duplicate list is what proves step 2 actually happened.

## Off-stack content

If the pasted content is topically unrelated to every existing course (e.g. medical
notes, general life stuff), it does not belong in any course — write it as a plain
markdown file outside `content/courses/` instead (or use the `notes` skill if one is
available) and say so explicitly rather than forcing it into an unrelated course.

**Technical but no matching course** (e.g. Perforce/VCS tooling, a niche library —
technical, but not Django/FastAPI/React/DSA/system-design/K8s and not on any
existing course's stack): still don't force it in. Route it to
`~/Notes/technical/<topic-slug>.md` via the `notes` skill instead — do this
automatically too, same as step 0, without asking first.
