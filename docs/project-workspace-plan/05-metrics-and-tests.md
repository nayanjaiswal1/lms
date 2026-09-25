# 05 — Metrics & Dashboard Computation + Test & Verification Plan

Source design: [../project-workspace.md](../project-workspace.md). Planning only — no code changed.

Grounded against `backend/internal/gitlab/repo_dashboard.go` / `service_dashboard.go` (live queries over mirror tables, no rollup table until proven slow), `gitlab/service_webhook.go` (dedupe-insert for GitLab events), `backend/internal/digest` (one-per-user-per-day digest — model for §16.8), `backend/internal/testdb` (template-clone-per-test Postgres), and `wiki/repo.go` (`pg_trgm similarity()`).

---

## PART A — Metrics & dashboard computation

### A.0 Conventions
- Every query scoped by `project_id`, then by date range / track / person / release from `GET /dashboard`.
- Compute live from `work_items` + `work_item_events` + related tables — no aggregation table unless measured slow (§16 rule).
- LEFT JOIN + `COALESCE(…,0)` for "present with zero" vs "absent", as in `GetTeamContributions`.
- Worst-case scale for estimates: **one project with 50 members, 5,000 items, 100,000 events**.

### A.1 Schema additions needed (gaps in §17)
1. **`work_item_events.project_id`** — denormalized at insert (same as `gitlab_commits.team_id`), so one composite index serves every dashboard query.
2. **`work_items.epic_id`, `work_items.feature_id`** — ancestor pointers maintained in the same transaction as `parent_id` changes. Depth is fixed, so no recursive CTE on each load.
3. **`sprint_commitments(sprint_id, item_id, committed_at)`** — snapshot at sprint start for "sprint commitment %".
4. **`project_events(id, project_id, kind, from_value, to_value, actor_id, created_at)`** — history for `project_status` / `brief_status` ("days active → agreed", health colour change).
5. **`project_digests(project_id, digest_date, health_color, sent_at)`**, `UNIQUE(project_id, digest_date)` — digest idempotency + previous health colour (mirrors `revision_digests`).
6. **`work_items.is_regression bool default false`** — explicit regression flag (Flow E2).
7. Verify the GitLab MR mirror stores additions/deletions (not seen in `001_baseline.sql`) — required for MR size.

### A.2 Indexes

| Index | Backs |
|---|---|
| `work_item_events(project_id, created_at)` | burndown, throughput, digest "since last run" |
| `work_item_events(project_id, kind, to_value, created_at)` | stage / cycle / lead time, throughput, reopens |
| `work_item_events(item_id, kind, created_at)` | per-item history, doc turnaround, `/items/{id}/events` |
| `work_items(project_id, type, status)` | progress %, bugs by severity, WIP |
| `work_items(project_id, due_at) WHERE status NOT IN ('done','wont_do','duplicate')` | overdue |
| `work_items(project_id, track_id, status)` | track metrics |
| `work_items(project_id, release_id, status)` | release metrics |
| `work_item_assignees(user_id, role)` | per-person load / WIP |
| `work_item_time_logs(item_id, user_id, logged_on)` | time logged |
| `work_item_reviews(item_id, target)` | review rounds |
| GIN `gin_trgm_ops` on `requirement_questions.question` | duplicate question check |

At the stated scale every query is an index scan of a few thousand rows — under ~150 ms, no materialized view needed for a single project.

### A.3 Metric by metric

**§16.2 Delivery**

| Metric | Approach | MV? |
|---|---|---|
| Progress % | `COUNT FILTER (status='done')` ÷ `COUNT FILTER (status<>'wont_do')` grouped by `feature_id`/`epic_id`; `SUM(estimate_minutes)` when set | No |
| Burndown / burnup | `generate_series` over sprint days LEFT JOIN each item's first-done day from events | No |
| Throughput | `date_trunc('week', first_done_at)` by track; first-done via `ROW_NUMBER() … = 1` so reopen→done isn't double-counted | No (MV only for org-wide cross-project view) |
| Lead / cycle time (median, p85) | CTE: created, first `in_progress`, first `done`; `percentile_cont` | No |
| Stage time | `LEAD(created_at) OVER (PARTITION BY item_id ORDER BY created_at)` → duration per status → percentiles | No |
| Blocked time | Stage time for `blocked`. **Top blockers not computable** — see A.5 #1 | — |
| Overdue | `work_items` filter | No |
| Scope churn | **Not computable** without sprint/release reassignment events — A.5 #2 | — |
| Requirement clarity | `requirement_questions` aggregates; days active→agreed needs `project_events` | No |
| Sprint commitment | done ÷ `sprint_commitments` rows | No |
| Forecast | arithmetic over last-3-weeks throughput | No |
| Doc turnaround | first `doc` event `to_value='approved'` − created; rounds = count of `in_review` transitions | No |

**§16.3 Quality**

| Metric | Approach |
|---|---|
| Open bugs by severity + age | `GROUP BY severity`, open statuses only |
| Bug inflow vs fix | created week vs first-done week |
| Reopen rate | `reopen_count > 0` ÷ items with a `testing` event, by track / assignee |
| Escaped bugs | `is_regression` joined to `release_id` |
| Bug density | bugs ÷ tasks per `feature_id` |
| CI pass rate | `work_item_gitlab.pipeline_status` success ÷ non-null for `kind='mr'` |
| MR review rounds | count of `work_item_reviews` target=`code` per item |
| MR size | needs additions/deletions on MR mirror (A.1 #7) |
| Test coverage signal | done items with a tester ÷ done items |

**§16.4 Team & person** — `GROUP BY user_id` across assignees, items, time logs, `gitlab_commits` / MR mirrors, onboarding, peer feedback. Trivial at 50 members. Review responsiveness and "reviews waiting > 3d" use reviewer `work_item_assignees.assigned_at` as the request time — an **approximation** (A.5 #7).

**§16.5 Track** — same aggregates by `track_id`. Cross-track blockers: `work_item_links(kind='blocks')` joined on both sides' `track_id`, different tracks, blocked item open.

**§16.6 Release** — same aggregates by `release_id`; readiness checklist is composed in the service from already-computed booleans.

**§16.7 Health** — pure Go `EvaluateHealth(metrics, thresholds) (color, reasons)` reusing the tile results already computed for the response (no re-query). Thresholds from `health_thresholds jsonb`.

**§16.8 Daily digest** — cron in the `internal/digest` style: per project with owner/manager, collect new blockers since last `project_digests.sent_at`, overdue, stale reviews, inactive members, WIP breaches, health colour vs previous row. S1 bugs sent immediately from the severity-set event. `UNIQUE(project_id, digest_date)` makes reruns no-ops.

### A.4 `GET /api/projects/{id}/dashboard` response shape

```go
type DashboardResponse struct {
    Header struct {
        Status        string
        DaysLeft      *int
        ReleaseTarget *string
        Health        string   // green | yellow | red
        HealthReasons []string
    }
    NeedsAttention struct {
        BlockedItems     []ItemSummary
        OverdueItems     []ItemSummary
        StaleReviews     []ReviewSummary
        OpenS1S2Bugs     []ItemSummary
        StuckOnboarding  []MemberSummary
        InactiveMembers  []MemberSummary
        LeaderlessTracks []TrackSummary
    }
    Delivery struct {
        Burndown           []BurndownPoint
        ThroughputWeek     []ThroughputPoint
        LeadTime           PercentileStat
        CycleTime          PercentileStat
        StageTime          map[string]PercentileStat
        ScopeChurn         ScopeChurnStat
        RequirementClarity RequirementClarityStat
        SprintCommitment   *float64
        Forecast           ForecastStat
        DocTurnaround      PercentileStat
    }
    Quality struct {
        BugsBySeverity     []BugSeverityCount
        BugInflowVsFix     []BugFlowPoint
        ReopenRate         float64
        EscapedBugs        int
        BugDensity         []FeatureBugDensity
        CIPassRate         float64
        MRReviewRounds     PercentileStat
        MRSize             PercentileStat
        TestCoverageSignal float64
    }
    People    []PersonMetrics
    PlanTree  []PlanTreeNode // epic -> feature roll-up %, doc status, release, owner, risk
    Tracks    []TrackMetrics
    Release   *ReleaseMetrics
    AISummary *string // cached weekly summary
}
```

Each summary row carries the ids / filter params the frontend needs to drill into `GET /items?…` — no bespoke drill-down endpoint.

### A.5 Metrics not computable from §17 as written
1. **Top blockers** — `blocked` transition must reference a `blocks` link / `blocking_item_id`.
2. **Scope churn** — needs an event kind for `sprint_id` / `release_id` changes.
3. **Sprint commitment** — needs `sprint_commitments` snapshot.
4. **Days active → agreed** — needs `project_events`.
5. **Escaped bugs** — needs `is_regression`.
6. **MR size** — needs additions/deletions on MR mirror.
7. **Review responsiveness** — no review-request timestamp; `assigned_at` is a proxy.
8. **Health colour change** — needs `project_digests`.
9. **Epic/feature roll-ups, bug density** — need `epic_id` / `feature_id`.

Resolve these in §17 before Phase 4 dashboard work starts.

---

## PART B — Test & verification plan

Pattern: pure-Go table tests for state machines and permission matrices; `*_db_test.go` with `internal/testdb` (`TestMain → testdb.RunMain`) for anything touching SQL, mirroring `projectmarket/repo_db_test.go` and `gitlab/design_db_test.go`.

### Phase 1 — lifecycle, roles, recruiting

| Test | Type | Proves |
|---|---|---|
| Lifecycle transitions, every illegal edge | unit | §4 state machine |
| Permission matrix role × action; `RequireProjectRole` against real `project_members` for all roles | unit + db | middleware enforces §3 |
| **Seat-cap race** — N goroutines accept with 1 seat left; lock spans count **and** insert | db, concurrent | §5 race closed |
| Interest upsert on `(requirement_id, lower(email))` | db | one row, `updated_at` bumped |
| Reapply cooldown (<30d neutral, ≥30d allowed) | db | §5 |
| Share-token rotation → old token 404 | db | §5 |
| 90-day purge keeps accepted rows | db + job | privacy |
| Onboarding gate blocks self-assign | unit + db | §6 |

### Phase 2 — work items, hierarchy, dedup

| Test | Type | Proves |
|---|---|---|
| **Key counter race** — N concurrent creates → no duplicate / skipped keys | db, concurrent | §7 key rule |
| **Optimistic lock** — stale `version` → 409 + current row | db | §7 |
| Parent/type legality (all legal + illegal edges, cross-project parent) | unit + db | §7 hierarchy |
| `blocks` cycle check (2-node and 3-node) | db | §7 |
| Assignment rules: reviewer≠developer, tester≠developer, doc reviewer≠author, one owner, self-assign only unassigned, WIP limit+1 rejected | unit + db | §7 |
| Dedup similarity: near match found, unrelated not; `duplicates` closes + moves watchers | db | §7 |
| `project_tasks → work_items` migration on real testdb: all rows `type='task'`, keys in creation order, old table dropped | db | migration |
| Every legal transition writes exactly one event; illegal writes none | db | audit trail |

### Phase 3 — requirement, doc gate, bug triage

| Test | Type | Proves |
|---|---|---|
| Duplicate question linked to existing thread | db | Flow B2 |
| "You decide" → assumption; 3d reminder / 5d manager may mark assumption (injectable clock) | unit + job | Flow B2 |
| Owner == manager still needs a second approver | db | Flow B2 |
| Doc gate: submit needs reviewer; changes_requested loop; stale-version approval rejected; removed reviewer's vote dropped; post-approval edit → change request without blocking tasks | db | Flow D |
| Separation of duties rejected at service/DB level, not only in a pure function | db | §2 |
| Bug triage: duplicate / not-a-bug / confirmed; S1 skips WIP + immediate notify | db | Flow E2 |
| Meeting action item → ticket with dup check; attendance recorded | db | Flow G |

### Phase 4 — GitLab, time logs, dashboard

| Test | Type | Proves |
|---|---|---|
| **Webhook replay** — same event id twice → no duplicate link / transition / event | db (reuse `webhook_test.go` harness) | Flow H |
| Key parsing: branch / MR / commit; other-project key ignored + logged; non-member author ignored | db | Flow H |
| Status automation: commit→in_progress; MR open→in_review; merged **and** green→testing (each alone does not); closed unmerged→in_progress; 2 MRs, 1 open → not testing | db | §9 |
| GitLab API failure → retry with backoff, "sync pending", UI not blocked | job, fake client | Flow H |
| Time log: ≤1440 min/day; edit blocked after 7 days | db | §17 |
| Member leave: owner items unassigned + notify; reviewer/tester removed; GitLab revoked; re-add reattaches history | db | Flow J |
| Track lead leaves → no new assignments in track until replaced | db | Flow J |
| **Metrics correctness** — seeded fixture with fixed timestamps → exact expected burndown, cycle time, reopen rate, CI pass rate, etc. for every §16.2–16.4 metric | db | Part A |
| Health rules table + one real "S1 open 25h → red" | unit + db | §16.7 |
| Digest: one project hitting every alert → all present; second run same day no-op | db | §16.8 |

### Phase 5 — releases, completion, AI, exports

| Test | Type | Proves |
|---|---|---|
| `frozen` blocks new features, allows bugs; `released` needs features done or moved | db | §13 |
| Forecast vs hand-computed date | unit | §16.2 |
| Peer feedback: owner sees per rater; member sees average only at ≥3, never who; `from≠to`; unique per pair | db | §20 #4 |
| Member report numbers match seeded fixture exactly | db | §15 |
| AI summary / breakdown / suggestion cached; regenerate max 3/day; call-counting mock never re-invoked in window | unit | AI-called-once rule |
| CSV export: owner/manager only; content matches seed | db | §16.10 |

---

## Manual end-to-end walkthrough (every release candidate)

1. Owner creates a project with a vague `raw_requirement` (≥50 chars) → `draft`.
2. Publish → `recruiting`; `/api/p/{token}` shows the raw requirement as-is.
3. Non-user submits the form twice with the same email → one row only.
4. Accept with seats exactly at max → next accept returns 409.
5. New member joins → welcome, onboarding checklist, GitLab access (if enabled).
6. Self-assign before required onboarding → blocked; after → allowed.
7. Start project → `active`, `brief_status=clarifying`.
8. Member asks a question; a near-duplicate from another member is linked to it.
9. Owner answers one, says "you decide" on another → assumption recorded.
10. Manager (≠ owner) writes brief from template; owner + manager approve → `agreed`. Owner==manager case still needs another approver.
11. Manager creates epic; track lead creates feature in own track; spec doc auto-created as `draft`.
12. Doc: submit → changes requested → revise → approve latest. Approving an old version is rejected.
13. Tasks created under approved feature (manually or AI-suggested + accepted); confirm tasks couldn't pass `todo` earlier.
14. Developer takes owner role; separate reviewer and tester; assigning the developer as reviewer is rejected.
15. Branch/commit with `MF-123` → `in_progress`.
16. MR with key → `in_review`; reviewer synced to MR.
17. Merge **and** green CI → `testing` (red pipeline or unmerged doesn't move it).
18. Tester fails → `reopened` with note, `reopen_count`+1; re-test passes → `done`.
19. Dashboard reflects the item; tile drill-down returns the exact filtered list.
20. Create release, target feature, freeze (features blocked, bugs allowed), release; notes cite the approved doc version.
21. Bug reported on the released feature, triaged as regression → shows in escaped bugs.
22. Remove a member → owned items unassigned + notify, roles dropped, GitLab revoked; re-add → history back.
23. Complete project → peer feedback; <3 ratings shows nothing to the member, ≥3 shows average only; owner sees individual.
24. Certificate + member report match what happened in steps 14–22.
25. Digest fired for blockers / S1 / health change and never twice on the same day.
