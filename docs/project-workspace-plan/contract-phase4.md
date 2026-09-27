# Phase 4 API contract (lead-owned) — GitLab linking, time logs, member leave, dashboard

Types: `backend/internal/workspace/models_phase4.go` (+ TS mirror). Migration 039 written (lead). Tests deferred — build + vet only.

## GitLab (4a)
- `gitlab/service.go`: add
  ```go
  type GitlabRefInfo struct { Kind, Ref string; MergeRequestID *string; MRState string; AuthorUserID *string; SourceBranch string }
  type WorkItemLinker interface { LinkGitlabRef(ctx context.Context, orgID, teamID, ticketKey string, info GitlabRefInfo) error }
  func (s *Service) SetWorkItemLinker(l WorkItemLinker)          // late-bound, set once in router.go (first late-bound dep — review note in code)
  func (s *Service) ClientForOrg(ctx context.Context, orgID string) (*Client, error)
  ```
- `gitlab/service_webhook.go`: `extractTicketKeys(texts ...string) []string` (TicketKeyPattern semantics, deduped). Push: after each commit upsert → keys from message + branch → linker (kind commit / branch, author = pusher's mapped MindForge user). MR: keys from title + description + source branch → linker (kind mr, state, author = MR author mapped). Also store `head_pipeline_status`, `additions`, `deletions` on `gitlab_merge_requests` from MR/pipeline events where the payload has them (MR `object_attributes.head_pipeline`… / pipeline event `merge_request.iid`). Linker nil → no-op; linker errors are logged, never fail ingest. Replay safety = existing `gitlab_webhook_events` dedupe + `work_item_gitlab` upsert.
- `gitlab/client_mr.go`: `SetMergeRequestReviewers(ctx, projectID, mrIID int64, reviewerGitlabIDs []int64) error` via the existing guarded client.
- `workspace/service_gitlab.go` implements `LinkGitlabRef`:
  1. resolve `workspace_projects` by `team_id = teamID AND org_id`; key prefix must equal the project's `key_prefix` else log "ignored: foreign key" and return nil; item by key_num (not archived) else ignore.
  2. project archived → ignore. Author must be an active project member to link; else log + ignore.
  3. upsert `work_item_gitlab (item_id, kind, gitlab_ref)` (mr: merge_request_id).
  4. status automation only if project `active` and author is `owner`/`developer` on the item, forward-only through `transitionTx` (source=gitlab): commit/branch → todo→in_progress; MR opened → in_progress→in_review; MR merged AND every linked MR of the item merged AND latest pipeline success → in_review→testing; MR closed unmerged → in_review→in_progress. Never touches done / wont_do / blocked. Automation must still respect brief-agreed / doc gate / WIP / blockers (skip silently when blocked by a gate).
  5. on MR open: sync reviewers (item reviewer assignees with linked GitLab identity) via `SetMergeRequestReviewers`; failure → `sync_status='pending'` and enqueue job `workspace.gitlab_sync` (retry with backoff via jobs MaxRetries); success → synced.
- Workspace GitLab provisioning (D8): `POST …/gitlab/provision` (owner, StatusesPlanning, gitlab_enabled): one hidden batch per org (reuse if exists; name constant `WorkspaceBatchName`, mark hidden via an existing column if batches has one — otherwise document the D8 follow-up), a `project_assignments` row for the workspace, a `project_teams` row with the active members, set `workspace_projects.team_id`, then call the existing provisioning job/path. Member add/remove afterwards grants/revokes GitLab access best-effort after commit (`grantGitlabAccess` / `revokeGitlabAccess` via existing team-member provisioning functions).
- Complete (Phase 5) archives the repo with `Client.ArchiveProject`.

## Time logs (4b)
```go
func (s *Service) ListTimeLogs(ctx, pc *ProjectCtx, itemID, userID, cursor string, limit int) (Page[TimeLog], error) // visibility 02 §7.2: member own only, TL own track, manager+ all
func (s *Service) LogTime(ctx, pc *ProjectCtx, itemID string, req TimeLogRequest) (*TimeLog, error)                  // own; 1–720; logged_on not future and ≥ today-7d; daily cap under pg_advisory_xact_lock(hashtextextended('time_log:'||user||':'||day,0)) → ErrTimeLogCap
func (s *Service) UpdateTimeLog(ctx, pc *ProjectCtx, logID string, req TimeLogRequest) (*TimeLog, error)             // own, created within 7d (ErrTimeLogLocked), same cap lock
func (s *Service) DeleteTimeLog(ctx, pc *ProjectCtx, logID string) error
```
Routes: `GET …/time-logs?item=&user=&cursor=`, `POST …/items/{itemID}/time-logs` (member, StatusesWork), `PATCH|DELETE …/time-logs/{logID}` (member, StatusesWork).

## Member leave (4c)
Extend `RemoveMember` (and the org-removal cascade in orgs/member.go) in one tx: status left/removed + left_at; for their open items: `owner` assignment deleted (+ `unassign` event, manager notified after commit), reviewer/tester rows deleted, developer rows deleted; pending doc reviews on the current version stop counting automatically; if they lead a track → `lead_user_id = NULL` (track becomes leaderless → new assignments blocked until a lead is set; managers notified). After commit revoke GitLab access. Re-add (AddMember on a left/removed row) reactivates the same row (history intact).
Job `workspace.inactivity_sweep` daily 03:00: active members with no event/time-log/commit/standup activity 7d → notify managers; 14d → notify managers "consider removal" (dedupe keys per member+stage+week).

## Dashboard (4d)
```go
func (s *Service) GetDashboard(ctx, pc *ProjectCtx, f DashboardFilter) (*Dashboard, error)
func (s *Service) EvaluateHealth(p *Project, d *Dashboard) HealthReport   // pure; thresholds from project.health_thresholds; 🔴 S1 open > s1_open_hours, forecast over target > forecast_red_pct, blocked > blocked_red_pct% of open; 🟡 forecast > target, reviews waiting > review_wait_days, reopen rate > reopen_yellow_pct, any inactive member
func (s *Service) SendDigests(ctx context.Context, day time.Time) (int, error) // one per project per day: INSERT workspace_digests ON CONFLICT DO NOTHING first — 0 rows → skip (idempotent); notify owner+managers with new blockers, overdue, stale reviews, inactive members, WIP breaches, S1s, health change vs previous row
func (s *Service) ExportCSV(ctx, pc *ProjectCtx, kind string, w io.Writer) error // Phase 5
```
Visibility (02 §7.2, D15): owner/overseer/manager full; track lead: project totals + own track rows/people; member: totals + own person row; viewer: totals only (People empty). `user=`/`track=` filters outside scope → ErrForbidden. All queries live over work_items/work_item_events/assignees/time logs/work_item_gitlab/gitlab_* mirrors/reviews/questions/standups/meeting_attendance — no aggregation tables. Every AttentionItem carries the ItemRef so the UI links to the filtered list. Release metrics stay nil until Phase 5; AISummary nil until Phase 5.
S1 bugs also notify immediately (already done in triage).
Routes: `GET …/dashboard?from=&to=&track=&user=&release=` (viewer), `GET …/items/{itemID}/gitlab` (viewer) → []GitlabLink, `POST …/gitlab/provision` (owner).
Job: `workspace.manager_digest` daily 08:00.

## Frontend (Phase 4)
Item detail: GitLab tab (MRs/branches/commits, pipeline badge, "sync pending"), time-logs panel (mine + team per visibility, log dialog with 1–720 validation, edit within 7 days). Members page: leave/remove banners and leaderless-track warning. `/workspaces/[id]/dashboard` per 04 §5: header with health badge (click → reasons), Needs attention list (rows link to filtered `/workspaces/[id]/list?…`), Delivery | Quality | Team sections, Recharts via `dynamic(ssr:false)` burndown pattern (`components/projects/assignment-burndown*.tsx`), plan tree (expand/collapse), tracks + people tables (ResponsiveTable), filters in URL via nuqs. Settings page: GitLab provision button.
