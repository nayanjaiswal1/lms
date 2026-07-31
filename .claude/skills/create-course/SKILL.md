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
| Course needs `lab` modules (standalone or attached to a lesson), or you're bulk-authoring a whole course from existing content (markdown/docs) | **Canonical Markdown pipeline** (below) — this is the only supported way to create `lab` modules |
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
- **The module upsert does NOT update `section_id`** — moving a module to a different
  `section:` in canonical markdown will not re-home the existing DB row on reseed. To
  restructure sections: delete the course's `course_modules` (except `type='lab'` —
  `lab_definitions.module_id` FK is NO ACTION and the `scope_module_consistency` CHECK
  forbids nulling it) + old `course_sections`, load the fixture, then `UPDATE` the lab
  modules' `section_id` manually and delete the now-empty old sections, all in one
  transaction (done 2026-07-15 for interview-prep-45's week→subject restructure).
- IDs are deterministic UUIDv5s derived from each doc's `id_key` (`canonical/ids.go`) —
  never invent random UUIDs for canonical content, or regeneration will duplicate rows.
- Rendering logic lives in `backend/internal/contentpipeline/generator/render*.go` — read the
  relevant one (`render_lesson.go` / `render_quiz.go` / `render_lab.go`) before hand-editing
  generated SQL.

### Course metadata — `course.yaml` per course directory

There is no "course" document kind; course-level fields live in one
`<course-dir>/course.yaml` (`canonical/course_meta.go`, `CourseMeta`): `title`,
`description`, `difficulty` (beginner|intermediate|advanced|expert), `tags`, `is_free`.
A missing file falls back to legacy defaults (title-cased slug, "intermediate", empty tags) —
always write a course.yaml for a new course. `status` is always `"published"`;
`estimated_hours` = sum of all `estimated_minutes` / 60. Working example:
`content/courses/interview-prep-45/course.yaml`.

### ⚠️ Question `difficulty` is NOT easy/medium/hard

The `questions` table CHECK constraint only allows `beginner|intermediate|advanced|expert`.
The canonical validator does NOT catch this — `easy`/`medium`/`hard` loads only fail at
`psql -f` time with `questions_difficulty_check`.

### Frontmatter shape per kind (`backend/internal/contentpipeline/canonical/types.go`)

Common fields on every doc: `kind`, `id_key` (stable, never change once authored — reseeds the
UUID), `course` (slug), `section` (slug), `section_title`, `section_position`, `title`,
`position` (order within section), `estimated_minutes`, `source` (list of upstream files this
was derived from — required, feeds `coursegen audit`).

**`kind: lesson`** -> `course_modules(type='notes')`. Markdown body after frontmatter becomes
`content_body` verbatim.

#### ⚠️ Every lesson needs inline knowledge checks — this is not optional

A lesson is not "done" when it's just prose. Every `## concept` heading needs a ` ```knowledge-check `
fenced JSON block placed right after that concept's content (before the next `##`) — one small
check per concept, not one block batching every concept at the end of the lesson. This is what
makes reading a lesson feel like a Google-style tutorial (read a concept, immediately prove you got
it) instead of a wall of text with a quiz bolted on at the end.

Shape (`backend/internal/contentpipeline/generator/render_lesson.go` `parseKnowledgeCheck`,
`frontend/lib/courses/markdown.ts` `parseKnowledgeCheck`):

```
```knowledge-check
{ "questions": [
    { "id": "<course>-<section>-<concept>-q1", "type": "mcq", "prompt": "...",
      "options": [{"id":"a","text":"..."}, ...], "correct": "a", "explanation": "..." }
] }
```
```

- 1–2 questions per concept, 4 options, exactly one `correct: true`-equivalent (the `correct` key
  names the right option id) unless the question is `type: "sql"` (client-graded, no `correct` key
  sent server-side).
- **Ids must be globally unique within the lesson.** The generator now supports multiple
  ` ```knowledge-check ` blocks per lesson and merges them into one
  `course_modules.knowledge_check` array, but two blocks sharing an `id` is a hard generator error
  (`duplicate knowledge-check question id`) — it would otherwise grade one question against the
  other's answer key.
- `correct` is stripped from every question before it reaches the browser (`markdown.ts`) — full
  answer keys live only in `course_modules.knowledge_check` for server-side grading
  (`backend/internal/courses/handler_student.go`).
- **Every question is a hard gate on "Mark as Complete"** (`ModuleGateProvider` requires all of
  them passed) — keep counts low; this is a comprehension check per concept, not a full quiz.
- Older courses (java-mastery, sql-mastery) batch one block at the end of the lesson instead of
  one per concept — that's the legacy shape from before this rule existed. Do not copy it for new
  content; retrofit older courses to the per-concept shape opportunistically, don't leave new
  courses matching the old pattern.

**`kind: quiz`** -> `assessments` + `questions` + `question_versions` + `assessment_questions`
+ `course_modules(type='assessment')`. Extra fields: `pass_percentage`, `duration_minutes`,
`questions: []` where each question has `id_key, type (mcq|coding|subjective), difficulty,
points, prompt, multiple, options[{text,correct}], explanation` (mcq) or
`languages, starter_code, test_cases[{stdin,expected,hidden,weight}]` (coding). mcq needs ≥2
options and exactly one `correct: true` unless `multiple: true`; coding needs ≥1 test case.

**`kind: lab`** -> `lab_definitions` + `lab_tasks` + `lab_task_versions` + publish UPDATE +
`course_modules(type='lab')`. Extra fields: `lab_type` (must be
`terminal|code|playground|guided|sandbox`), `environment` (container image), `max_duration`,
`max_resets`, `hint_penalty_pct`, `is_required`, `setup_script`, `run_script` (sandbox only:
student-visible sample-test command behind the workspace Run button; empty = no Run button;
written to the DB but never sent to the client), `files: [{path, content}]` (written into the
container workdir before `setup_script` runs), `tasks: [{id_key, title, points, is_optional,
is_stateful, description, verification_script, hint_context, explanation_context,
solution_script}]`. Every lab that isn't `playground` or `sandbox` needs ≥1 task; an
`is_required` lab needs ≥1 non-optional task. `sandbox` labs render the CodeSandbox-style IDE
(multi-terminal, auto-detected ports, Run/Submit batch grading) instead of the task checklist —
see docs/labs.md "Lab Types". **`solution_script` must
never be written to any generated SQL/DB row** — it exists only for the generator's own
optional self-test mode (see `docs/labs.md`).

### FK insert order (why it matters if you ever hand-write SQL)

- **Lab**: `course_modules` row first (type='lab', no content columns) -> `lab_definitions`
  (`module_id` FK, NOT NULL) -> `lab_tasks` -> `lab_task_versions` -> `UPDATE lab_definitions
  SET is_published=true, published_version_id=...`.
- **Quiz**: reverse order — `questions`+`question_versions` -> `assessments` -> 
  `assessment_questions` -> `course_modules` row LAST (type='assessment', `assessment_id` FK
  must already exist).
- **Lesson**: one `course_modules` row (type='notes', `content_body` inline) — plus, if the
  lesson has a nested `lab:` block (see below), the full lab row-set attached to that same
  module id, emitted right after it in the same generated script.

Sessions read task snapshots from `lab_task_version_items` (NOT the legacy
`lab_task_versions.tasks` JSONB) — `Repo.GetPublishedVersion` returns ErrNotFound on zero
item rows, which 404s every student lab endpoint. `renderLab` emits these rows; if a
generated lab 404s in the app despite loading fine, check that table first.

### Web-app labs (Django / FastAPI / React — app already running, student edits files)

Reusable sandbox images (`lab-images/`): `mindforge/lab-python-web:3.12` (Django, FastAPI,
uvicorn preinstalled — lab network has NO internet) and `mindforge/lab-node-web:22` (Vite+React
scaffold with node_modules baked at `/opt/scaffold/react-app`). Adding an exercise = one lab
markdown file, never a new image. Pattern (working examples:
`content/courses/interview-prep-45/week-1-fundamentals/9{5,6,7}-lab-*.md`):

- Ship the app source via `files:` plus a `.lab/start.sh` — each image's entrypoint runs an
  `app-runner` (as labuser) that waits for that script and supervises the app with restarts.
  Do NOT start servers from `setup_script`: it runs as root (cap-drop ALL blocks setuid) and
  must finish inside `ProvisionTimeoutSeconds`.
- Set `preview_port:` (8000 Django/FastAPI, 5173 Vite) in the lab frontmatter — it drives the
  CodeSandbox-style live app preview pane (iframe via labproxy's authenticated
  `/preview/{token}/` reverse proxy + cookie catch-all for absolute asset paths). 0/omitted =
  no preview pane.
- `setup_script` = a single fast readiness probe (`curl -sf --max-time 2 localhost:PORT/`);
  the platform retries it.
- `verification_script` runs as labuser with `timeout 10` — curl/grep-level checks only.
  React: bundle the student's component with `node_modules/.bin/esbuild --bundle --format=cjs`
  (the esbuild bin is a native ELF — never `node .../bin/esbuild`; `--format=esm` breaks on
  react-dom/server's CJS requires) and assert on `renderToStaticMarkup` output.
- Starter files are written by root heredocs; `buildSetupScript` chmods them 666 (and created
  dirs 777) so students can edit them — root cannot chown (cap-drop ALL).
- React workdir gets node_modules as a SYMLINK to the scaffold (real copy floods the file
  explorer's `find` listing); Vite's `cacheDir` must point somewhere writable (`/tmp`).

### Inline lab checks on a lesson (`kind: lesson` + nested `lab:`)

For a hands-on lesson, attach the lab directly to the **notes** module instead of
adding a separate `kind: lab` module to the section: put the full lab field set
(everything a standalone `kind: lab` doc has — `lab_type, environment, max_duration,
max_resets, hint_penalty_pct, is_required, setup_script, run_script, files, tasks`)
under a `lab:` key in the lesson's frontmatter, then place a `[[lab-task:N]]` marker
(its own paragraph, 1-based, matching the authoring order of `tasks:`) after each
`## concept` heading whose hands-on check you want inline. `renderLesson` emits the
notes module, then the same lab row-set `renderLab` would (`lab_definitions` /
`lab_tasks` / `lab_task_versions` / `lab_task_version_items`), with
`lab_definitions.module_id` pointing at the **notes module's own id** — there is no
separate lab module in the section list. Working example:
`content/courses/docker/container-commands/01-lesson.md`.

Two validator rules keep this from silently breaking in the browser: every marker's
`N` must be `1 <= N <= len(tasks)` (an out-of-range marker renders nothing — no error
in the app, just an invisible gap), and a lesson with `Lab.Tasks` but zero markers is
rejected (the Launch-Lab hero only renders at the first marker's position, so a
lab with no marker is unreachable). Lab tasks do **not** gate "Mark as Complete" —
only a `knowledge-check` block does — so a hands-on lesson should generally carry
both: knowledge-check for comprehension, lab tasks for doing.

### Nested Docker labs — `environment: mindforge/lab-docker:27`

This is the one lab image that runs a real Docker daemon *inside* the student's own
sandbox (teaching Docker itself needs Docker inside the lab container). It is
operator- and org-gated and **off by default** — see `docs/labs.md` "Nested Docker
labs" for the security model (`LABS_NESTED_DOCKER_IMAGES`, `lab_org_config.
allowed_images`, the isolated `mindforge-labs-dind` network). What follows is the
**content-authoring** side, learned by actually building and running the image and
its tasks end to end against the real flags `container.go` emits — not theoretical:

- **Every `docker run`/`docker build` in a task's `description`, `hint_context`,
  `verification_script`, and `solution_script` needs `--network host`** (`docker
  build` needs `--network=host` specifically whenever its Dockerfile has a `RUN`
  instruction — a Dockerfile with only `FROM`/`CMD`/`COPY` doesn't need it, but adding
  it unconditionally is a safe habit). Without it, container/build-step creation
  fails outright with `failed to disable IPv6 on container's interface eth0: unknown`
  — this sandbox's rootless dockerd runs inside its own nested network namespace,
  and creating a *second* level of netns (any bridge-attached container, including
  the implicit default bridge) hits a rootless-in-rootless kernel limitation with no
  known fix short of `sysbox-runc` (see `docs/labs.md`). This is not optional for
  some tasks and skippable for others — assume every task needs it.
- **The terminal cannot `curl`/`wget` a container's port directly, even with
  `--network host`.** The rootless dockerd (and everything it runs) lives in its own
  network namespace, separate from the one the student's terminal (ttyd) and
  `verification_script`/`Exec()` actually run in — only the docker **socket** (a
  file) bridges the two, not TCP/IP. Two consequences:
  - To verify a container is serving something, run a **second** `--network host`
    container that does the fetch (e.g. `docker run --rm --network host busybox:1.36
    wget -qO- http://127.0.0.1:PORT`) — two host-networked containers share the same
    network stack as *each other*, just not as the terminal. This is the pattern
    every task in `content/courses/docker/` uses; copy it rather than re-deriving.
  - `docker build`, `docker push`, `docker pull`, `docker load`, `docker exec` all
    work fine typed directly in the terminal — these are carried out by the daemon
    itself (which shares the lab-docker container's own network with anything it
    runs), not by the terminal's own network stack. Only a bare `curl`/`wget`/`nc`
    from the terminal to a container's port is affected.
- **Compose**: give every service `network_mode: host` in the compose file — same
  reasoning as `--network host` for a plain `docker run`, and it also means Compose
  never gets to create its own project bridge network (which would hit the same
  limitation). This does mean two Compose services can't resolve each other by
  service name in this sandbox (no compose-managed network exists to do that DNS
  resolution over) — only via `127.0.0.1` if both are `network_mode: host`.
- **User-defined bridge networks** (`docker network create` + a container attached to
  it) hit the identical failure the moment a container tries to join — the `network
  create` call itself works fine (pure control-plane, no netns/veth involved), so a
  task can still teach *creating and inspecting* a network structurally
  (`docker network inspect ... --format '{{.Driver}}'`), it just can't verify two
  containers actually resolving each other by name live. See
  `content/courses/docker/networking-volumes/01-lesson.md` for the pattern: the
  network-creation task is verified live, the "containers reach each other by name"
  teaching point is prose-only with the constraint explained, not a graded task.
- **The offline registry** (`localhost:5000`, `mindforge/lab-docker`'s entrypoint
  starts it via `--network host` internally) is reachable through `docker push`/
  `docker pull`/`docker tag` directly, per the daemon-vs-terminal distinction above —
  no helper container needed for registry exercises, only for raw HTTP checks against
  it (a catalog query via `curl` would need the two-container pattern; a
  push-then-pull round trip through the `docker` CLI does not).
- **Base images must be preloaded, never pulled at runtime** — the lab network has no
  internet (same constraint as every other lab image). `mindforge/lab-docker`'s
  Dockerfile bakes in `docker save` tarballs for `alpine:3.20`, `busybox:1.36`,
  `nginx:1.27-alpine`, `python:3.12-alpine`, `registry:2`, `docker load`'d by the
  entrypoint at container boot — extend that list (rebuild the image) rather than
  assuming any other image is available.

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
