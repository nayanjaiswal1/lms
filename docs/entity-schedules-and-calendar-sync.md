# Entity schedules & calendar sync (batches, courses, lessons)

## What this is

`batches` (cohorts/bootcamps), `courses`, and `course_modules` (lessons) each have an
optional `starts_at`/`ends_at` window — same nullable-TIMESTAMPTZ shape assessments
already used. These windows automatically show up as read-only entries in the in-app
calendar the moment a user is enrolled/assigned/a member — there is no separate "sync"
step, no button, no background job.

"Bootcamp" is not a separate entity — it's a label (`parent_type`) on the same `batches`
table used for assessment context tagging. Giving `batches` a schedule covers "bootcamp"
too.

Out of scope (not built): push to real Google Calendar (that OAuth integration doesn't
exist in this codebase yet — see `docs/calendar-sync.md`), a frontend UI for setting/
viewing these dates, and any per-user preference to opt out of seeing them.

## Schema (migration `038_entity_schedules.sql`)

```sql
ALTER TABLE batches        ADD COLUMN starts_at TIMESTAMPTZ, ADD COLUMN ends_at TIMESTAMPTZ, ...
ALTER TABLE courses        ADD COLUMN starts_at TIMESTAMPTZ, ADD COLUMN ends_at TIMESTAMPTZ, ...
ALTER TABLE course_modules ADD COLUMN starts_at TIMESTAMPTZ, ADD COLUMN ends_at TIMESTAMPTZ, ...
```

Each gets a `CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at)` and a
partial index `(starts_at, ends_at) WHERE starts_at IS NOT NULL` (course_modules' index
also filters `deleted_at IS NULL`) so the calendar's overlap queries stay indexed.

## API

| Endpoint | Change |
|---|---|
| `POST /api/batches` | Accepts `starts_at`, `ends_at` |
| `PATCH /api/batches/{batchID}` | **New** — batches had no update endpoint at all before this. Full-replace semantics (matches `UpdateCourse`'s convention): omitted fields overwrite with their zero value, not a partial merge. |
| `GET /api/batches`, `GET /api/batches/{id}` | Response now includes `starts_at`, `ends_at`, `updated_at` |
| `POST /api/courses`, `PATCH /api/courses/{id}` | Accepts `starts_at`, `ends_at` |
| `POST /api/sections/{id}/modules`, `PATCH /api/modules/{id}` | Accepts `starts_at`, `ends_at` (this is the per-lesson field) |

All four create/update paths validate `ends_at > starts_at` server-side (422 with a
`fields.ends_at` message), mirroring the check `assessments` already does for its own
`starts_at`/`ends_at`.

## Calendar auto-sync mechanism

`backend/internal/calendar/repo.go`'s `Repo.ListRange` (backing `GET /api/calendar/events`)
already merged in read-only "virtual" entries for assessment windows
(`listVirtualAssessmentEvents`) before this change — never written to `calendar_events`,
computed on every read. Three more virtual sources were added the same way:

- `listVirtualBatchEvents` — one entry per batch with a schedule, visible to anyone in
  `batch_members` or `batch_mentors`.
- `listVirtualCourseEvents` — one entry per course with a schedule, visible to anyone
  with a row in `enrollments`.
- `listVirtualLessonEvents` — one entry per `course_modules` row with a schedule, visible
  to anyone enrolled in its parent course.

New pseudo `event_type` values: `"batch"`, `"course"`, `"lesson"` (alongside the existing
`"assessment"`) — these are never valid on a real `calendar_events` row, only ever seen
on `Event` values with `is_virtual: true`.

**Why "auto-sync" needs no explicit trigger:** these aren't rows that get created or
updated when someone gets enrolled/assigned — every call to `GET /api/calendar/events`
re-runs the join against whatever `enrollments` / `assessment_assignments` /
`batch_members` / `batch_mentors` looks like *right now*. Assign, enroll, unenroll, or
change a schedule, and the very next calendar read reflects it. Verified live:

1. Course had no schedule → student not enrolled → calendar: nothing.
2. Course given a schedule, student self-enrolls (`POST /api/courses/{id}/enroll`) →
   calendar immediately shows the course window. No calendar-side call was made.
3. Same pattern confirmed for a direct assessment assignment
   (`POST /api/assessments/{id}/assignments`): assign → calendar reflects it on the next read.

## Known follow-ups (not built)

- **Frontend UI** — no date pickers on the course wizard, module editor, or batch forms;
  no visual distinction for the three new virtual event types on the calendar page
  (`event-block.tsx`'s `primaryLayerFor` still needs a branch for them — today it
  collapses every virtual event into the `"assessment"` swatch).
- **Per-user opt-out** — there's no preference to hide these from a user's calendar; if
  enrolled/assigned/a member, the entry always shows. Would need a small settings table
  plus a filter in `ListRange` if wanted.
- **Real Google Calendar push** — still unimplemented (see `docs/calendar-sync.md`);
  these virtual entries are in-app only, same as assessment windows always were.
