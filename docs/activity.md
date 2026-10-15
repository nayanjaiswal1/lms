# Activity

A read-only, day-by-day "what did I do, and when" timeline for a student —
the dashboard's "Recent activity" widget and the full `/activity` page. Built
so a student can revise and track progress: see what module completed when,
and see it the moment an AI client updates their learning through the
[AI Connector (MCP)](ai-connector.md) — a reflection logged via
`log_understanding` or a flashcard graded via `mark_revision_result` shows up
here just like anything done in-app.

## Design

No new unified event-log table. Every source below already carries its own
per-user timestamp; `backend/internal/activity` aggregates them at read time
with one `UNION ALL` query, the same pattern `frontend/app/(app)/dashboard/page.tsx`
already uses to merge assessments and calendar events into one sorted
timeline. The one genuine gap was flashcard reviews — `srs_cards` only ever
held *current* scheduling state, no history — so the activity-feed schema in `001_baseline.sql`
added `srs_reviews`, written atomically alongside every `srs_cards` update
inside `srs.ReviewCard` (shared by `POST /api/srs/review` and the MCP
`mark_revision_result` tool). See [docs/learning.md](learning.md#spaced-repetition-sm-2).

## Sources

| `kind` | Source table | Timestamp | Notes |
|---|---|---|---|
| `module_completed` | `module_progress` | `completed_at` | `status = 'completed'` only |
| `course_completed` | `enrollments` | `completed_at` | |
| `quiz_attempt` | `assessment_attempts` | `submitted_at` | includes pass/fail + score in the summary |
| `reflection` | `lesson_reflections` | `created_at` | written by the MCP `log_understanding` tool (or the in-app Reflect box) |
| `sheet_problem_solved` | `user_problem_progress` | `solved_at` | keyed by `topic_tag`, shared across every sheet containing it |
| `lab_completed` | `lab_sessions` | `completed_at` | |
| `card_reviewed` | `srs_reviews` | `reviewed_at` | new table, see above |
| `annotation:highlight`, `annotation:mistake` | `learning_annotations` | `created_at` | unified branch with `annotation_type` filter; replaced separate `highlights`/`mistake_entries` branches |

## API

```
GET /api/activity?limit=<1..200, default 50>&cursor=<opaque>&tz=<minutes east of UTC, default 0>
```

Cursor-paginated, newest first — same `base64(unixMicro:key)` shape as
`GET /api/mcp-action-log` (`backend/internal/mcpconnect/action_log.go`), except
the tiebreak field is `key` (`"<kind>:<source row id>"`, synthesized per branch
since a `UNION ALL` over heterogeneous tables has no shared surrogate id) not
a plain row id.

`?tz=` follows the same convention as `GET /api/whatnow/plan/day` — a UTC
offset in minutes, not an IANA zone name — used only to compute each entry's
`day` (`YYYY-MM-DD`) client-locally in Go after the query returns. The
`/activity` page is a server component and has no way to read the browser's
offset, so it currently sends none and gets UTC days: a student east of UTC
can see a late-evening item filed under the next day.

```
-- ponytail: day-grouping defaults to UTC (?tz= unset). Upgrade path: pipe
-- user_profiles.timezone (already exists, nullable) into the request when
-- someone notices — no query or schema change needed, just plumbing.
```

### Response

```json
{
  "entries": [
    {
      "key": "module_completed:9c2e...",
      "kind": "module_completed",
      "occurred_at": "2026-08-02T14:30:00Z",
      "day": "2026-08-02",
      "title": "Two Pointers",
      "summary": "DSA Fundamentals",
      "ref_id": "9c2e...",
      "ref_type": "module",
      "ref_slug": "dsa-fundamentals"
    }
  ],
  "next_cursor": "MTc1NDEy..."
}
```

## Multi-tenant scoping

`module_progress`/`enrollments` (via `courses.org_id`), `assessment_attempts`,
and `lesson_reflections` are all filtered to the caller's active org.
`user_problem_progress` (sheets) and `srs_cards`/`srs_reviews` have no
`org_id` — they're per-user personal data by design, not per-tenant, so they
appear in the feed regardless of which org the session is currently scoped
to. This is intentional, not a leak: don't "fix" it by adding an org filter
to those two sources.

## Adding a new source

Each source is one `UNION ALL` branch in `backend/internal/activity/repo.go`
plus one partial `(user_id, ts DESC) ` index in a new migration — see
`001_baseline.sql` (activity feed section) for the pattern. Deliberately not included yet:
`coding_submissions`, `practice_sessions`, `wiki_pages`. Add one when it's
actually asked for, not before — every branch added is one more index to keep
the `MergeAppend` query plan intact as data grows (see the `ponytail:`
comment in `repo.go`).

**Note:** `highlights` and `mistake_entries` are now unified under one
`learning_annotations` branch (annotation_type='highlight'/'mistake'); they
are no longer separate sources.

## Weekly recap

A Sunday email summarising the last 7 days: activity counts per kind
(`activity.Repo.CountByKind`, same `eventsCTE` as the feed so kinds stay in
sync) and current habit streaks (`weeklyrecap.CurrentStreak`, pure; the
in-progress period never breaks a streak).

- Cron `weekly_recap.fanout` at `0 9 * * 0` (**UTC for everyone** - no per-user
  local hour, unlike `digest.nightly`). It enqueues one `weekly_recap.user` job
  per active user with an org membership, idempotency key
  `weekly_recap:{isoYear-Www}:{userID}`.
- `weekly_recap.user` sends nothing when there is zero activity in the window
  and no active streak; otherwise it enqueues `email.send` (type
  `notification`, key `weekly_recap_email:{week}:{userID}`), which honors
  `cfg.ShouldSendRealEmail`.
- Opt-out: `user_profiles.notifications.weekly_recap` (`false` = off, absent =
  on). Toggled in Settings > Profile > Preferences.
- Streak lookback is capped at 366 days.
