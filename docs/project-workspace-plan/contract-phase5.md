# Phase 5 API contract (lead-owned) — releases, sprints, completion, AI, exports

Types: `backend/internal/workspace/models_phase5.go` (+ TS mirror). Migration 040 written (lead). Tests deferred — build + vet only.

## Releases & sprints (5a)
```go
func (s *Service) ListReleases(ctx, pc *ProjectCtx) ([]Release, error)
func (s *Service) CreateRelease(ctx, pc *ProjectCtx, req CreateReleaseRequest) (*Release, error)          // manager+, StatusesPlanning
func (s *Service) UpdateRelease(ctx, pc *ProjectCtx, releaseID string, req UpdateReleaseRequest) (*Release, error) // ReleaseStatusMachine; freeze sets frozen_at; released requires every targeted feature done|wont_do (ErrReleaseNotReady), writes release_snapshots (item status + approved_doc_version for every item targeting it), released_at; all under release row FOR UPDATE
func (s *Service) SetItemRelease(ctx, pc *ProjectCtx, itemID string, req SetItemReleaseRequest) (*WorkItem, error) // optimistic version; target release frozen → only bugs (ErrReleaseFrozen); `release` event
func (s *Service) GetReleaseNotes(ctx, pc *ProjectCtx, releaseID string, polish bool) (*ReleaseNotes, error) // items from snapshots (or live if not released) citing doc versions; polish=true → AI, cached kind=release_notes key="release:{id}", regenerate capped via SummaryRegenPerDay
func (s *Service) ListSprints(ctx, pc *ProjectCtx) ([]Sprint, error)
func (s *Service) CreateSprint(ctx, pc *ProjectCtx, req CreateSprintRequest) (*Sprint, error)            // sprints_enabled (ErrSprintsDisabled); ≤28 days; EXCLUDE violation → ErrSprintOverlap
func (s *Service) StartSprint(ctx, pc *ProjectCtx, sprintID string) (*Sprint, error)                     // one active (unique index → ErrConflict); snapshot sprint_commitments for items with sprint_id
func (s *Service) CloseSprint(ctx, pc *ProjectCtx, sprintID string, req CloseSprintRequest) (*Sprint, error) // unfinished → next sprint or backlog (sprint_id NULL), `sprint` events; ErrUnfinishedChoice if missing
func (s *Service) SetItemSprint(ctx, pc *ProjectCtx, itemID string, req SetItemSprintRequest) (*WorkItem, error) // `sprint` event (scope churn after start)
```
CreateWorkItem/UpdateWorkItem: a feature can't target a frozen release. Dashboard (extend service_dashboard.go): burndown over the active sprint when sprints_enabled; SprintCommitment = done ÷ committed; Release metrics (ReleaseMetrics) for `release=` filter or the nearest planned/frozen release; forecast target = release target_at; scope churn counts `sprint`/`release` events after sprint start / freeze.

## Completion (5b)
- SetProjectStatus active→completed: reject if any item in in_progress/in_review/testing (ErrCompleteBlocked); set completed_at, feedback_closes_at = +14d; after commit archive the GitLab repo via `Client.ArchiveProject` (best-effort, logged) when team provisioned.
```go
func (s *Service) GetFeedback(ctx, pc *ProjectCtx) (*FeedbackView, error)
func (s *Service) SubmitPeerFeedback(ctx, pc *ProjectCtx, req PeerFeedbackRequest) error   // completed & now < feedback_closes_at (ErrFeedbackClosed); from≠to; both were assignees on ≥1 common item (ErrNoSharedWork); upsert (editable until close)
func (s *Service) BuildMemberReport(ctx, pc *ProjectCtx, userID string) (*MemberReport, error) // self, manager+ (all), TL (own track members); peer rating per 02 §7.1
func (s *Service) IssueCertificate(ctx, pc *ProjectCtx, req IssueCertificateRequest) (*MemberReport, error) // owner, completed; reuse the existing certificates manual-issue path (read internal/certificates first; if no suitable issuance exists, add an additive project-completion issuance there)
func (s *Service) SetShowcaseOptIn(ctx, pc *ProjectCtx, optIn bool) error                      // self
```
Visibility: managers never see individual ratings (D15); owner/overseer see All.

## AI (5c) — all via service_ai.go helpers: Available() guard, cache-before-call in workspace_ai_cache, delimited inputs (strip the delimiter from input), JSON mode + strict parse + clamp, per-project cap `rl:pw:ai:{project}` AIPerProjectDay, results rendered as plain text, never auto-applied.
```go
func (s *Service) SuggestEpics(ctx, pc *ProjectCtx) (*ItemSuggestions, error)                     // brief agreed; key "brief:req{v}:wiki{n}"; manager+
func (s *Service) SuggestTaskBreakdown(ctx, pc *ProjectCtx, featureID string) (*ItemSuggestions, error) // doc approved; key "item:{id}:doc{v}"; manager+ or TL
func (s *Service) SuggestAssignees(ctx, pc *ProjectCtx, itemID string) ([]AssigneeSuggestion, error)   // NOT cached (D20); rl:pw:assignee:{user}:{item} AssigneeSuggestPerMinute/min; inputs: track, member skills (from interests/profile), live WIP — no PII beyond first names
func (s *Service) ExplainLate(ctx, pc *ProjectCtx, featureID string) (*LateExplanation, error)         // key "item:{id}:{date}"
func (s *Service) ChangeImpact(ctx, pc *ProjectCtx, featureID string) (*ChangeImpact, error)            // key "item:{id}:doc{v}"
func (s *Service) WeeklySummary(ctx, pc *ProjectCtx, regenerate bool) (*WeeklySummary, error)           // manager+; key ISO week; regenerate capped SummaryRegenPerDay/day per project
func (s *Service) RunWeeklySummaries(ctx context.Context) (int, error)                                  // job: fan-out one job per active project, idempotency key project+ISO week
```
Never send peer feedback, others' time logs or interest PII to AI. Dashboard `AISummary` = cached current-week summary for manager+ only.
Job `workspace.ai_weekly_summary` Mon 06:00.

## CSV export (5d)
`GET …/export/{kind}.csv` kind ∈ items | time_logs | members; manager+; `rl:pw:export:{user}` ExportPerUserHour/h; streamed `text/csv` via encoding/csv with formula-injection guard (prefix `'` for cells starting with = + - @).

## Routes
| Method | Path | Min | Gate |
|---|---|---|---|
| GET | …/releases | viewer | — |
| POST | …/releases | manager | StatusesPlanning |
| PATCH | …/releases/{releaseID} | manager | StatusesPlanning |
| GET | …/releases/{releaseID}/notes?polish= | viewer (polish: manager) | — |
| PUT | …/items/{itemID}/release | member (service: manager+/TL for features) | StatusesPlanning |
| GET | …/sprints | viewer | — |
| POST | …/sprints | manager | StatusesWork |
| POST | …/sprints/{sprintID}/start | manager | StatusesWork |
| POST | …/sprints/{sprintID}/close | manager | StatusesWork |
| PUT | …/items/{itemID}/sprint | member | StatusesWork |
| GET | …/feedback | member | — |
| POST | …/feedback | member | StatusesFeedback |
| GET | …/members/{userID}/report | member | — |
| POST | …/certificates | owner | StatusesFeedback |
| PUT | …/membership/showcase | member | — |
| POST | …/ai/epics | manager | StatusesPlanning |
| POST | …/items/{itemID}/ai/breakdown | member (service: manager+/TL) | StatusesPlanning |
| POST | …/items/{itemID}/ai/assignees | member (service: manager+/TL) | StatusesPlanning |
| POST | …/items/{itemID}/ai/why-late | manager | — |
| POST | …/items/{itemID}/ai/change-impact | manager | StatusesDiscuss |
| POST | …/ai/weekly-summary?regenerate= | manager | — |
| GET | …/export/{kind}.csv | manager | — |

Errors: ErrReleaseFrozen 409, ErrReleaseNotReady 409, ErrSprintsDisabled 409, ErrSprintOverlap 409, ErrFeedbackClosed 409, ErrNoSharedWork 403, ErrCompleteBlocked 409, ErrUnfinishedChoice 422.

## Frontend (Phase 5)
`/workspaces/[id]/sprints` (redirect to home when sprints disabled; sprint panel with commitment, burndown chart, close dialog with carry-over/backlog choice), `/workspaces/[id]/releases` (release panel, readiness checklist, freeze/release, notes view + AI polish), `/workspaces/[id]/feedback` (rate teammates 1–5 + comment while open; own aggregate only when available; owner table), `/workspaces/[id]/members/[userId]/report`, certificate issue dialog (owner), AI buttons (`.ai-surface`, `.ai-badge`, suggestions rendered as plain text with "Create" per suggestion going through the normal create path), assignee suggestion in the assignee picker, weekly summary card on the dashboard (regenerate, max 3/day message), CSV export buttons (manager+), showcase opt-in toggle.
