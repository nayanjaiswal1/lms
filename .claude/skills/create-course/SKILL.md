---
name: create-course
description: "Reference for creating a MindForge course fixture — schema for courses/sections/modules, how each of the 5 module types (video/pdf/notes/assessment/lab) links to its content table, and the two creation paths (Canonical Markdown pipeline vs. direct API/SQL). Use whenever asked to create, seed, or author a course, a lab, a quiz, or course content."
---

# Creating a MindForge Course

A course is `courses -> course_sections -> course_modules`. Full schema: `docs/courses.md`.
Read this skill fully before writing any course-creation code — it exists so you don't have
to re-derive schema/FK order from scratch each time.

## Which path to use

| Situation | Path |
|---|---|
| Course only needs `video`/`pdf`/`notes`/`assessment` modules, going through the app normally | **API path** — `POST /api/courses` etc. (below) |
| Course needs `lab` modules, or you're bulk-authoring a whole course from existing content (markdown/docs) | **Canonical Markdown pipeline** (below) — this is the only supported way to create `lab` modules |
| One-off manual seed/debug row | Direct SQL, following the exact column list + FK order below |

`lab` modules can **never** go through `POST /api/sections/{sectionID}/modules` — the handler
rejects `type=lab` (`backend/internal/courses/handler.go`, `moduleCreateReq`, ~line 399/426).

## Path 1 — Canonical Markdown pipeline (labs, quizzes, bulk content)

Real, working example: `content/courses/fast-kubernetes/**` -> generated into
`backend/db/fixtures/k8s_fastkube.generated.sql` via:

```bash
cd backend && go run ./cmd/coursegen generate --in ../content/courses/<slug> --out db/fixtures/<slug>.generated.sql
```

- Input is any `.md` file under `--in`, found recursively by `filepath.WalkDir` — **filename
  doesn't matter** (`01-lesson.md` is just convention), only the `kind:` frontmatter field
  routes it (`backend/internal/contentpipeline/generator/generator.go:60`, `parse.go`).
- Output SQL is **idempotent** (`ON CONFLICT ... DO UPDATE`), safe to regenerate repeatedly.
- IDs are deterministic UUIDv5s derived from each doc's `id_key` (`canonical/ids.go`) —
  never invent random UUIDs for canonical content, or regeneration will duplicate rows.
- Rendering logic lives in `backend/internal/contentpipeline/generator/render*.go` — read the
  relevant one (`render_lesson.go` / `render_quiz.go` / `render_lab.go`) before hand-editing
  generated SQL.

### ⚠️ Known limitation — course metadata is hardcoded for one course

`render.go:renderCourse` (~line 59-85) does NOT read course title/description/difficulty/tags
from any frontmatter — there is no "course" document kind. It hardcodes:
- `title` = title-cased course slug (`fast-kubernetes` -> `Fast Kubernetes`)
- `description` = fixed template string
- `difficulty` = `"intermediate"` (always)
- `tags` = `["kubernetes","k8s","devops","containers"]` (always — also hardcoded per-question in `render_quiz.go:57`)
- `is_free` = `true`, `status` = `"published"` (always)
- `estimated_hours` = sum of all `estimated_minutes` / 60

**If asked to generate a second, non-Kubernetes course through this pipeline**, these fields
must first be parameterized (e.g. read from a small manifest file per course, or a new
`--title/--difficulty/--tags` flag) — do not silently ship a new course mislabeled
"intermediate"/kubernetes-tagged. Flag this to the user rather than guessing.

### Frontmatter shape per kind (`backend/internal/contentpipeline/canonical/types.go`)

Common fields on every doc: `kind`, `id_key` (stable, never change once authored — reseeds the
UUID), `course` (slug), `section` (slug), `section_title`, `section_position`, `title`,
`position` (order within section), `estimated_minutes`, `source` (list of upstream files this
was derived from — required, feeds `coursegen audit`).

**`kind: lesson`** -> `course_modules(type='notes')`. Markdown body after frontmatter becomes
`content_body` verbatim.

**`kind: quiz`** -> `assessments` + `questions` + `question_versions` + `assessment_questions`
+ `course_modules(type='assessment')`. Extra fields: `pass_percentage`, `duration_minutes`,
`questions: []` where each question has `id_key, type (mcq|coding|subjective), difficulty,
points, prompt, multiple, options[{text,correct}], explanation` (mcq) or
`languages, starter_code, test_cases[{stdin,expected,hidden,weight}]` (coding). mcq needs ≥2
options and exactly one `correct: true` unless `multiple: true`; coding needs ≥1 test case.

**`kind: lab`** -> `lab_definitions` + `lab_tasks` + `lab_task_versions` + publish UPDATE +
`course_modules(type='lab')`. Extra fields: `lab_type` (must be `terminal|code|playground|guided`),
`environment` (container image), `max_duration`, `max_resets`, `hint_penalty_pct`, `is_required`,
`setup_script`, `files: [{path, content}]` (written into the container workdir before
`setup_script` runs), `tasks: [{id_key, title, points, is_optional, is_stateful, description,
verification_script, hint_context, explanation_context, solution_script}]`. Every non-playground
lab needs ≥1 task; an `is_required` lab needs ≥1 non-optional task. **`solution_script` must
never be written to any generated SQL/DB row** — it exists only for the generator's own
optional self-test mode (see `docs/labs.md`).

### FK insert order (why it matters if you ever hand-write SQL)

- **Lab**: `course_modules` row first (type='lab', no content columns) -> `lab_definitions`
  (`module_id` FK, NOT NULL) -> `lab_tasks` -> `lab_task_versions` -> `UPDATE lab_definitions
  SET is_published=true, published_version_id=...`.
- **Quiz**: reverse order — `questions`+`question_versions` -> `assessments` -> 
  `assessment_questions` -> `course_modules` row LAST (type='assessment', `assessment_id` FK
  must already exist).
- **Lesson**: just one `course_modules` row (type='notes', `content_body` inline).

## Path 2 — API path (video/pdf/notes/assessment, normal authoring flow)

```
POST /api/courses                              draft course
POST /api/courses/{courseID}/sections           add a section
POST /api/sections/{sectionID}/modules          add a module (video/pdf/notes/assessment only)
POST /api/courses/{courseID}/publish            draft -> published
```

Handler + repo: `backend/internal/courses/handler.go` (`courseCreateReq` ~line 95,
`moduleCreateReq` ~line 399), `backend/internal/courses/repo.go` (`CreateCourse` line 49,
`CreateSection` line 329, `CreateModule` line 416). Frontend equivalent:
`frontend/components/courses/course-wizard.tsx` (sequential: create course -> per-section
create -> per-module create) — it has no lab/assessment-authoring UI either; same restriction.

For an `assessment` module via this path, create the assessment through the assessment domain
first (`backend/internal/assessment`) and pass its ID as `assessment_id`.

## Full schema reference

`docs/courses.md` has the complete `CREATE TABLE` statements for
`courses/course_sections/course_modules/enrollments/module_progress/course_reviews`.
`docs/labs.md` has `lab_definitions`/`lab_tasks` schema and edge cases.
Don't re-grep the migrations — read that doc first.
