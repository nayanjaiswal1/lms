# Analytics

Status: backend implemented; frontend pages built separately.

Instructor and org-admin view of how students move through courses: where they drop off, which quiz questions trip them, who is falling behind, and how enrollments trend. Read-only; all code lives in package `courses` (`repo_analytics.go`, `handler_analytics.go`).

## Metric definitions

- **Completed** — `enrollments.completed_at` is never written, so a student is completed when every non-deleted module of the course has `module_progress.status = 'completed'`. A course with zero modules has no completers.
- **Funnel** — `enrolled` (all enrollments), `started` (any module not `not_started`), `reached_25/50/75` (completed modules / total >= the threshold), `completed`.
- **Lesson drop-off** — lessons ordered by section position then module position. `drop_off = max(previous lesson completed - this completed, 0)`; the first lesson is 0. `completion_rate` = completed / enrolled * 100.
- **Hardest questions** — correct rate per submitted answer (not per student): correct evaluated answers / evaluated answers. Includes assessment modules and `knowledge_check` assessments attached to a module. Only answers by students enrolled in this course count (so a quiz shared with another course does not mix cohorts; anonymous attempts are dropped). Questions with fewer than `min_answers` answers are excluded. Sorted by correct rate ascending, then answers descending.
- **Last active** — later of `enrolled_at` and the newest `module_progress.updated_at` for the course.
- **At risk** — not completed AND enrolled at least `inactive_days` ago (grace period, so new students are never flagged) AND (last active older than `inactive_days` OR progress < `max_progress_pct`). Reasons: `inactive`, `low_progress`. Only active org members are listed (suspended/removed excluded). `risk=all` lists every such member without the at-risk predicate (reasons still follow the same rule).
- **Days** — enrollment trend buckets are UTC days, zero-filled, exactly `days` points ending today.

## API

All GET, JSON, snake_case. Require `courses.view_analytics` and are rate limited per user.

| Endpoint | Query (default, range) | Response |
|---|---|---|
| `/api/courses/{courseID}/analytics` | `days` (30, 7-180) | `{course_id, generated_at, funnel, lessons, trend}` |
| `/api/courses/{courseID}/analytics/questions` | `limit` (10, 1-200), `offset` (0), `min_answers` (5, 1-1000) | `{questions, total, limit, offset}` |
| `/api/courses/{courseID}/analytics/students` | `risk` (`at_risk`\|`all`, at_risk), `inactive_days` (14, 1-365), `max_progress_pct` (25, 0-100), `limit` (25, 1-200), `offset` | `{students, total, limit, offset}` |
| `/api/analytics/courses` | `limit` (20, 1-200), `offset` | `{courses, total, limit, offset}` |
| `/api/analytics/enrollment-trend` | `days` (30, 7-180) | `{points}` |

Out-of-range or malformed params return 422 with field errors. A non-UUID or other-org `courseID` returns 404.

Shapes: `funnel {enrolled, started, reached_25, reached_50, reached_75, completed}`; `lessons[] {module_id, title, type, section_title, position, started, completed, completion_rate, drop_off}`; `trend[]/points[] {date "YYYY-MM-DD", enrollments}`; `questions[] {assessment_question_id, question_id, title, type, module_id, module_title, answered, students, correct_rate}`; `students[] {user_id, name, email, enrolled_at, completed_modules, total_modules, progress_pct, last_active_at, days_inactive, risk_reasons[]}`; `courses[] {course_id, title, slug, status, enrolled, completed, avg_progress_pct, active_last_7d}`.

## Authorization and tenancy

Routes use `authz.RequirePermission(PermissionViewAnalytics)`; no migration (the permission is already seeded and granted to owner/admin/instructor). Every query is scoped by `claims.OrgID`; per-course queries call `ownsCourse` first and return `ErrNotFound` for another org's course, and the progress CTE also joins `courses.org_id`.

## Rate limit

`ANALYTICS_RATE_LIMIT_MAX` (60) per `ANALYTICS_RATE_LIMIT_WINDOW` (1m), keyed per user (`rl:analytics:<user>`), 429 with `Retry-After`.

## Performance

Queries aggregate `module_progress` by course and are index-backed by course/module keys. Lessons are unpaginated (a course has at most low hundreds). Question and student lists are paginated with `count(*) OVER()` totals, capped at 200 per page; `total` is 0 when the offset is past the end. Org course summaries page the courses first, then run one lateral aggregate per page row.

## Frontend

Per-course analytics page and an org overview page (separate frontend work); they consume the endpoints above.

## Tests

`backend/internal/courses/repo_analytics_db_test.go` (funnel, drop-off, hardest-question ordering and min-answers, shared-quiz cohort isolation, at-risk branches, grace period, removed member, pagination totals, trend zero-fill, tenant isolation) and `TestBoundedInt`. DB tests use `internal/testdb` (Docker or `TESTDB_URL`).
