# 03 — Backend Implementation Plan (packages, services, jobs, integrations)

Source design: [../project-workspace.md](../project-workspace.md). Planning only — no code changed. Reconciled decisions that override parts of this file are in [00-decisions.md](00-decisions.md).

## 1. Package

### 1.1 New package `backend/internal/workspace`
Not an extension of `projectmarket` or `gitlab`:
- `projectmarket` is a staff board → authenticated apply → staff select flow with a 4-state status. Workspace is any permitted member → public anonymous interest → 7-state lifecycle + separate `brief_status`. Two packages writing two status models onto one row is the coupling CLAUDE.md DRY warns against.
- `gitlab` is course-batch provisioning (assignment → team, template fork, checkpoints, grading). Reuse its **REST client and webhook pipeline**, not its assignment/team model.
- Five phases as reviewable PRs only works with ~20 new tables in their own package.

Own table `workspace_projects` (not an ALTER on `project_requirements`) — see [00-decisions.md](00-decisions.md).

### 1.2 Files

| File | Responsibility |
|---|---|
| `models.go` | All domain structs + DTOs + status/role consts |
| `statemachine.go` | **Only** place for project / brief / doc / work-item machines, hierarchy table, shared DFS cycle check |
| `repo.go` | `Repo`, scan helpers, sentinel errors (`ErrNotFound`, `ErrConflict`, `ErrForbidden`) |
| `repo_project.go` | projects CRUD, share token, `FOR UPDATE` seat lock + count |
| `repo_interest.go` | interest upsert, list/review, purge |
| `repo_members.go` | members, tracks, track members |
| `repo_onboarding.go` | steps, progress |
| `repo_requirement.go` | requirement versions, questions, trgm dup check |
| `repo_items.go` | items CRUD, counter bump + insert, optimistic update, similarity |
| `repo_assignees.go`, `repo_links.go`, `repo_events.go`, `repo_reviews.go`, `repo_timelogs.go` | per table; events also hold dashboard read queries |
| `repo_meetings.go`, `repo_releases.go`, `repo_feedback.go` | per table |
| `repo_dashboard.go` | every §16 metric, live |
| `service.go` | `Service` + `NewService(pool, wikiSvc, calendarSvc, inviteSvc, notifSvc, aiProvider, jobs, gitlabSvc, certSvc)` |
| `service_project.go` | `CreateProject`, `SetProjectStatus` (single entry), `RotateShareToken`, `TransferOwner` |
| `service_recruiting.go` | `GetPublicProject`, `SubmitInterest`, `ListInterests`, `ReviewInterest` |
| `service_onboarding.go` | `AddMember`, steps/progress, track pick/approve, `CanSelfAssign` |
| `service_requirement.go` | `UpdateRequirement`, `AskQuestion`, `AnswerQuestion`, `SubmitBrief`, `ApproveBrief` |
| `service_items.go` | `CreateWorkItem`, `UpdateWorkItem`, `MoveWorkItem`, `SetAssignee`, `CreateLink`, `MarkDuplicate`, `ListSimilarItems` |
| `service_doc.go` | `SubmitDoc`, `ReviewDoc`, `ScheduleDesignReview` |
| `service_execution.go` | `TransitionItem` (single entry) + GitLab auto-triggers + `MarkReopened` |
| `service_bug_triage.go` | `ReportBug`, `TriageBug` |
| `service_change_request.go` | `RequestDocChange` |
| `service_meetings.go` | meetings, attendance, action item → ticket, standups, sprints |
| `service_gitlab.go` | implements `gitlab.WorkItemLinker`; GitLab access grant/revoke |
| `service_releases.go` | create / freeze / release + notes |
| `service_member_leave.go` | `RemoveMember` |
| `service_completion.go` | `CompleteProject`, `SubmitPeerFeedback`, `BuildMemberReport`, `IssueCertificate` |
| `service_dashboard.go` | `GetDashboard`, `GetMetricSeries`, health, CSV |
| `service_ai.go` | all AI calls, cache-then-call |
| `sod.go` | single separation-of-duties check (see 02 §8) |
| `middleware.go` | `RequireProjectRole`, `ProjectStatusGate` (see 02 §2) |
| `handler.go` + `handler_project.go`, `handler_recruiting.go`, `handler_members.go`, `handler_requirement.go`, `handler_items.go`, `handler_doc.go`, `handler_meetings.go`, `handler_releases.go`, `handler_dashboard.go`, `handler_completion.go` | one per flow group |
| `routes.go` | `RegisterRoutes`, `RegisterPublicRoutes` |

Changed existing files:

| File | Change |
|---|---|
| `gitlab/service_webhook.go` | `extractTicketKeys` from commit message / branch / MR title+description+source branch → `s.linkTicketKeys` (nil-safe, errors logged, never fails ingest) |
| `gitlab/service.go` | `WorkItemLinker` interface + `SetWorkItemLinker` late-bound setter; exported `ClientForOrg(ctx, orgID)` wrapping `clientFor` |
| `gitlab/client_mr.go` | new `SetMergeRequestReviewers(ctx, projectID, mrIID, reviewerIDs)` |
| `orgs/invite.go` | Join fixes + `CreateForProject` (02 §4.6) |
| `orgs/member.go` | org removal cascades workspace leave |
| `wiki/*` | project-scoped spaces + v1 `content_versions` row on create |
| `certificates/service.go` | additive project-completion issuance (verify existing manual-issue path first) |
| `ai/prompts.go` | new prompt constants |
| `jobs/handlers/constants.go` + `jobs/handlers/workspace_*.go` | new jobs (§4) |
| `privacy/repo.go` | purge + export entries |
| `api/router.go` | build workspace router, `gitlabSvc.SetWorkItemLinker(workspaceSvc)`, mount routes |

## 2. Services per flow

**A — Recruiting**
- `CreateProject` — validation in service (lengths, sizes ≥2 … ≤50); create project wiki space then project row storing `wiki_space_id` (orphan space harmless if later step fails), owner member, key prefix.
- `SetProjectStatus` — `statemachine.ProjectStatus.Allowed` + preconditions (`checkStart`, `checkComplete`); `UPDATE … WHERE status=$from`.
- `TransferOwner` — target must be manager; swap in one tx.
- `GetPublicProject` — 404 unless recruiting or active+accepting.
- `SubmitInterest` — rate limit + honeypot at handler; upsert on `(project_id, email citext)`; neutral branches for member / cooldown; one generic 202; owner notified by digest.
- `ReviewInterest` — accept: `FOR UPDATE` project, seat count, then add/invite **in the same tx** (lock spans check and write).

**B — Onboarding**
- `AddMember` — insert member + seed `onboarding_progress` in one tx; after commit best-effort welcome notification + `grantGitlabAccess`.
- `MarkOnboardingStepDone`, `PickTrack` / `ApproveTrackPick`, `CanSelfAssign`.

**B2 — Vague requirement → brief**
- `UpdateRequirement` — owner; new version row + `brief_status` clarifying; if was agreed, open change requests for approved feature docs.
- `AskQuestion` — trgm dup check; returns existing thread instead of inserting.
- `AnswerQuestion` — owner answers; manager may mark assumption after 5 days.
- `SubmitBrief` / `ApproveBrief` — `brief_approvals` rows on the current version; agreed needs owner + a different manager/TL.

**C — Work items**
- `CreateWorkItem` — hierarchy check; one tx: `UPDATE workspace_projects SET item_seq=item_seq+1 RETURNING item_seq` then insert; similar items returned to caller (non-blocking).
- `UpdateWorkItem` — `WHERE id=$1 AND version=$2`; 0 rows → `ErrConflict` + current row.
- `MoveWorkItem` — hierarchy re-check.
- `SetAssignee` — all §7 rules before upsert; WIP count for `in_progress`.
- `CreateLink` — `blocks` cycle check + insert in one tx under advisory xact lock.
- `MarkDuplicate` — close + notify assignees and reporter.

**D — Doc gate**
- Feature creation creates the spec page from the "Feature Spec" template (seeded once).
- `SubmitDoc` — ≥1 reviewer; draft → in_review.
- `ReviewDoc` — stores version number; stale version rejected; all current reviewers approve same latest → approved; changes_requested keeps in_review.
- Reviewer removed to zero → manager notified, status unchanged.
- `ScheduleDesignReview` — `calendar.Service.CreateEvent`, reviewers as attendees.

**E / E2 — Execution & bugs**
- `TransitionItem` — role per §9, machine, WIP, blockers, SoD; status update + event in one tx.
- Auto-triggers (GitLab only): `AdvanceOnBranchOrCommit`, `AdvanceOnMROpened`, `AdvanceOnAllMRsMergedAndCIGreen`, `RevertOnMRClosedUnmerged` — forward-only.
- `MarkReopened` — `reopen_count+1`, event.
- `ReportBug` — `type=bug`, `todo`, `severity NULL` until triaged.
- `TriageBug` — duplicate / not a bug / confirmed; S1 bypasses WIP, immediate notify.

**F — Change request**
- `RequestDocChange` — diff from wiki versions (no new diff engine); approved → in_review; child tasks get `spec_changed_at` (cleared on re-approval); churn read from events.

**G — Meetings**
- `ScheduleMeeting` — calendar event + notes page from per-kind template + `project_meetings` row.
- `RecordAttendance` (per occurrence), `ConvertActionItemToTicket` (dup check → `CreateWorkItem`).
- `PostStandup` — upsert per day; blockers may reference ticket keys → shown on dashboard (no automatic status change).
- `CreateSprint` / `CloseSprint` — explicit carry-over or backlog choice.

**H — GitLab**
- `LinkGitlabRef(ctx, orgID, teamID, key, kind, ref)` — resolve prefix → project owning team; member/assignee checks (02 §5); upsert `work_item_gitlab`; call auto-trigger; set MR reviewers on MR open.

**I — Releases**
- `CreateRelease`, `FreezeRelease` (item create/update rejects new features), `MarkReleased` (all features done or moved) + notes AI.

**J — Member leave**
- `RemoveMember` — one tx per 02 §2; after commit `revokeGitlabAccess`.

**K — Completion**
- `CompleteProject` — preconditions, status, then best-effort `gitlab.Client.ArchiveProject` (read-only in place — **not** `service_handoff.go`, which transfers to another namespace), opens feedback window.
- `SubmitPeerFeedback`, `BuildMemberReport` (pure aggregation), `IssueCertificate`.

## 3. State machines (`statemachine.go`)

```go
type Machine map[string]map[string]bool

func (m Machine) Allowed(from, to string) bool { return m[from][to] }

var ProjectStatus = newMachine(map[string][]string{
    "draft":      {"recruiting", "cancelled"},
    "recruiting": {"active", "cancelled"},
    "active":     {"paused", "completed", "cancelled"},
    "paused":     {"active", "cancelled"},
    "completed":  {"archived"},
    "cancelled":  {"archived"},
})

var BriefStatus = newMachine(map[string][]string{
    "raw":        {"clarifying"},
    "clarifying": {"agreed"},
    "agreed":     {"clarifying"},
})

var DocStatus = newMachine(map[string][]string{
    "draft":             {"in_review"},
    "in_review":         {"approved", "changes_requested"},
    "changes_requested": {"in_review"},
    "approved":          {"in_review"},
})

var WorkItemStatus = newMachine(map[string][]string{
    "todo":        {"in_progress", "blocked", "wont_do"},
    "in_progress": {"in_review", "blocked", "wont_do"},
    "in_review":   {"testing", "in_progress", "blocked", "wont_do"},
    "testing":     {"done", "reopened", "blocked"},
    "blocked":     {"todo", "in_progress", "in_review", "testing"},
    "done":        {"reopened"},
    "reopened":    {"in_progress"},
})

var HierarchyRules = map[string][]string{ // parent -> children
    "":        {"epic", "bug"}, // project root
    "epic":    {"feature", "bug"},
    "feature": {"task", "bug"},
    "task":    {"subtask"},
    "bug":     {"subtask"},
}
```

Epic/feature status is computed at read time, never stored as a transition.

## 4. Background jobs
Registered in `jobs/handlers`, wired in `cmd/server/main.go` cron defs, sweep + idempotency key pattern.

| Handler | Cron | Does |
|---|---|---|
| `workspace.brief_reminder` | hourly | questions unanswered 3d → owner; 5d → manager "may mark assumption" |
| `workspace.doc_review_reminder` | hourly | in_review docs idle 3d → reviewers; 5d → manager |
| `workspace.inactivity_sweep` | daily 03:00 | no activity 7d → manager; 14d → suggest removal (human decides) |
| `workspace.close_expired_and_purge` | daily 04:00 | close past-deadline recruiting; PII purge (02 §4.7) |
| `workspace.manager_digest` | daily 08:00 | one digest per owner/manager per project, idempotent per day |
| `workspace.ai_weekly_summary` | Mon 06:00 | fan-out one job per active project, key `project + ISO week` |

GitLab retries reuse the existing `gitlab.jobIngestEvent` retry/backoff and `gitlab.poll_sync`; failed links set `state='sync_pending'`. Invite→member linking happens inside `Join`'s tx (no reconcile job).

## 5. AI calls
All via `ai.LLMProvider.Complete`, `Available()` guard, JSON mode, cache-before-call, delimited inputs (02 §6).

| # | Prompt | Input | Cache key | Cap |
|---|---|---|---|---|
| 1 | Interest rank | skills, message, portfolio host | interest row | on owner click |
| 2 | Gap analysis | requirement + Q&A | requirement version | 1/version |
| 3 | Epic suggestion | agreed brief | brief version | 1/version |
| 4 | Task breakdown | approved doc | item + approved version | 1/version |
| 5 | Assignee suggestion | item + members' skills/WIP | **not cached** (live load) | rate limit ~1/min/user/item — explicit exception to "AI called once" |
| 6 | Change impact | doc diff + open tasks | item + new version | 1/version |
| 7 | Release notes | done items + doc summaries | release | 1 auto + capped regen |
| 8 | Weekly summary | metrics + blockers | project + ISO week | 1/week + 3 manual/day |
| 9 | Why late | feature events + blockers | item + date | 1/day |

All share the per-project daily AI cap. Cache store: `workspace_ai_cache(project_id, kind, cache_key, output, created_at)` unique on `(project_id, kind, cache_key)`.

## 6. Webhook wiring
1. `extractTicketKeys(texts...)` with `\b([A-Z]{2,6})-(\d{1,9})\b`, deduped.
2. Push: after each commit upsert, keys from message + branch → `linkTicketKeys(kind commit/branch)`.
3. MR: keys from title + description + source branch → `linkTicketKeys(kind mr, state)`.
4. `linkTicketKeys` no-op if linker nil; errors logged only.
5. Interface in `gitlab` (avoids import cycle):
   ```go
   type WorkItemLinker interface {
       LinkGitlabRef(ctx context.Context, orgID, teamID, ticketKey, kind string, ref GitlabRefInfo) error
   }
   ```
   `gitlab.Service.SetWorkItemLinker` is called once in `router.go` after both services exist. This is the first late-bound dependency in the codebase (workspace needs gitlab for access grants; gitlab needs workspace for linking) — review explicitly.

## 7. Phase checklist (sub-batches = one PR each)

**Phase 1** (testdb repo tests from the first PR)
- 1a: models, statemachine (project/brief), repo, repo_project, service, service_project, handler(s), routes, middleware, sod, migration (core tables + permissions), `orgs.Join` fixes.
- 1b: interests, public routes, share token, rate limits, honeypot, purge job.
- 1c: members, tracks, onboarding, `CreateForProject`, org-removal cascade, project wiki space.

**Phase 2** (Opus review of migration + permission matrix before merge)
- 2a: work-item machine + hierarchy, repo_items, create/update/move, handlers, migration.
- 2b: assignees, links, events, assignment rules, cycle check.
- 2c: board/list endpoints; delete `handler_planning.go` fixtures (`planningdata/*.json`, `PlanningBoard`, `PlanningIssues`).

**Phase 3**
- 3a: requirement + questions + brief approvals + reminder job + templates.
- 3b: doc reviews + reminder job.
- 3c: change request + bug triage.
- 3d: meetings, attendance, standups.

**Phase 4**
- 4a: gitlab changes (§6), `service_gitlab.go`, router wiring.
- 4b: time logs.
- 4c: member leave + inactivity sweep.
- 4d: dashboard, health, digest job.

**Phase 5**
- 5a: releases, sprints, forecast.
- 5b: peer feedback, completion, certificate.
- 5c: AI calls + weekly summary job.
- 5d: CSV export.

## 8. Risks (raised by this slice)
1. `/api/projects` is owned by `internal/project` and `internal/gitlab` → use `/api/workspaces`.
2. `/api/p/{…}` owned by `internal/assessment` → use `/api/public/workspaces/{token}`.
3. Extending `project_requirements` overloads it with an incompatible status model → own table.
4. Invite→project handoff undefined in design → handled inside `Join` tx.
5. Completion "handoff" reference wrong → `ArchiveProject`.
6. "Watchers" table doesn't exist → notify assignees + reporter.
7. Standup blockers have no link to items → reference ticket keys; dashboard display only.
8. AI assignee suggestion can't be cached → documented exception.
9. First late-bound setter wiring → explicit review.
10. Tiny team brief approval → resolved by `team_size_min ≥ 2` (see 00-decisions).

## Critical files
- `backend/internal/api/router.go`
- `backend/internal/gitlab/service_webhook.go`, `gitlab/service.go`, `gitlab/client_mr.go`
- `backend/internal/projectmarket/repo.go` (locked counter + status transition idioms)
- `backend/internal/wiki/service.go`
- `backend/db/migrations/`
