# Phase 3 API contract (lead-owned) — clarification, brief, doc gate, triage, meetings

Types: `backend/internal/workspace/models_phase3.go`, TS mirror in `frontend/lib/workspace/types.ts` (Phase 3 section).
Migration `038_workspace_clarification_docs_meetings.sql` is written (lead). Tests are deferred (user decision) — build + vet only.

## Service signatures
```go
// service_requirement.go (extends Phase 1 file)
func (s *Service) ListQuestions(ctx, pc *ProjectCtx, cursor string, limit int) (Page[RequirementQuestion], error)
func (s *Service) AskQuestion(ctx, pc *ProjectCtx, req AskQuestionRequest) (*AskQuestionResult, error)       // brief raw|clarifying only; trgm dup (`question % $q`, SET LOCAL threshold 0.4) → returns existing, Duplicate=true
func (s *Service) SimilarQuestions(ctx, pc *ProjectCtx, q string) ([]RequirementQuestion, error)            // for the composer; rl similar key
func (s *Service) AnswerQuestion(ctx, pc *ProjectCtx, questionID string, req AnswerQuestionRequest) (*RequirementQuestion, error) // owner any time; manager only IsAssumption=true after 5d (ErrTooEarly)
func (s *Service) RequirementGaps(ctx, pc *ProjectCtx) (*RequirementGaps, error)                           // AI, cached workspace_ai_cache kind=requirement_gaps key="req:v{N}"; manager+
// service_brief.go
func (s *Service) GetBrief(ctx, pc *ProjectCtx) (*BriefView, error)
func (s *Service) CreateBriefPage(ctx, pc *ProjectCtx) (*BriefView, error)   // manager+ or any track lead; wiki page in the project space from the "Project Brief" template (seed template content in code if the org has no template of that title), sets brief_wiki_page_id; Q&A log section lists answered questions
func (s *Service) ApproveBrief(ctx, pc *ProjectCtx) (*BriefView, error)      // owner, manager or track lead; brief must be clarifying, page exists
// service_doc.go
func (s *Service) GetDoc(ctx, pc *ProjectCtx, itemID string) (*DocView, error)
func (s *Service) SubmitDoc(ctx, pc *ProjectCtx, itemID string) (*DocView, error)
func (s *Service) ReviewDoc(ctx, pc *ProjectCtx, itemID string, req ReviewDocRequest) (*DocView, error)
func (s *Service) RequestDocChange(ctx context.Context, tx pgx.Tx, pageID, userID string, newVersion int) error // wiki page-update hook (see Change request)
func (s *Service) ScheduleDesignReview(ctx, pc *ProjectCtx, itemID string, req ScheduleMeetingRequest) (*Meeting, error)
// service_bug_triage.go
func (s *Service) TriageBug(ctx, pc *ProjectCtx, itemID string, req TriageBugRequest) (*WorkItem, error)
// service_meetings.go
func (s *Service) ListMeetings(ctx, pc *ProjectCtx, cursor string, limit int) (Page[Meeting], error)
func (s *Service) ScheduleMeeting(ctx, pc *ProjectCtx, req ScheduleMeetingRequest) (*Meeting, error)
func (s *Service) RecordAttendance(ctx, pc *ProjectCtx, eventID string, req RecordAttendanceRequest) error
func (s *Service) ConvertActionItem(ctx, pc *ProjectCtx, eventID string, req ActionItemRequest) (*CreateWorkItemResult, error) // Force=false & similar hits → return result with Item zero-value? No: return ErrConflict-free result: if hits and !Force, return CreateWorkItemResult{Similar: hits} and create nothing (HTTP 200, item.id == "")
func (s *Service) PostStandup(ctx, pc *ProjectCtx, req PostStandupRequest) (*Standup, error)     // own, upsert per UTC day; active only
func (s *Service) ListStandups(ctx, pc *ProjectCtx, day string) ([]Standup, error)                // day YYYY-MM-DD, default today
// jobs (service_reminders.go)
func (s *Service) SendBriefReminders(ctx context.Context) (int, error)   // questions unanswered 3d → owner; 5d → managers "may mark assumption"; notifications DedupeKey per question+stage
func (s *Service) SendDocReviewReminders(ctx context.Context) (int, error) // in_review docs idle 3d → reviewers; 5d → managers
```

## Rules
- **Brief sign-off (D13):** `brief_approvals` row per approver for (project, current requirement_version) storing the brief page's *current* wiki version; re-approving updates it. Agreed when on the current requirement version and the SAME wiki version there is an approval by the project owner AND an approval by a *different* user whose role is manager or lead of any track. Then `brief_status='agreed'`, `brief_agreed_at = COALESCE(brief_agreed_at, now())`, audit. All under `SELECT … FROM workspace_projects FOR UPDATE`. Brief page edits after approvals simply make older approvals stale (version mismatch).
- **UpdateRequirement (extend Phase 1):** if brief was agreed → clarifying; every feature with doc_status approved gets a change request (doc → in_review, children spec_changed_at=now, `doc` event reason "requirement changed").
- **Feature spec creation:** CreateWorkItem for type=feature (extend service_items.go) creates a wiki page in the project space from the "Feature Spec" template (problem · scope · out of scope · API · UI · test plan · risks), `doc_status='draft'`, in the same tx (use the wiki tx helper from Phase 1).
- **SubmitDoc:** actor = feature owner/developer, creator, or manager+; ≥1 reviewer assignee (ErrNoReviewers); doc_status draft|changes_requested|approved(→change) → in_review via DocStatusMachine; `doc` event; notify reviewers.
- **ReviewDoc:** lock item FOR UPDATE; `wiki_version` must equal the page's current version (ErrStaleDocVersion); verdict changes_requested needs comment; approved → SodCheck(approve_doc). Insert work_item_reviews (target doc). changes_requested → doc_status changes_requested. approved → if every *current* reviewer's latest doc review is approved on this same version → doc_status approved, approved_doc_version=version, clear spec_changed_at on the feature's tasks. `review` + `doc` events.
- **Reviewer removed** (SetAssignees extension): their doc reviews on the current version stop counting automatically (only current reviewers count). If the last reviewer is removed while in_review → notify managers.
- **Change request (Flow F):** the wiki package gets a late-bound hook: `wiki.SetPageUpdateHook(func(ctx, tx pgx.Tx, pageID, userID string, newVersion int) error)` called inside UpdatePage's tx after the version bump; router wires it to `workspaceSvc.RequestDocChange`. RequestDocChange: if pageID is a feature doc with doc_status approved and newVersion > approved_doc_version → doc_status in_review, `doc` event reason "spec changed after approval", tasks under the feature get spec_changed_at=now (not blocked), notify reviewers. No-op for other pages.
- **TriageBug:** manager+ or lead of the bug's track. duplicate → CreateLink(duplicates) path (closes as wont_do). not_a_bug → wont_do with required reason (transitionTx source=user, role check bypassed for triage). confirmed → set severity (required), optional owner (through SetAssignees rules), parent (bug may move under feature/epic), is_regression; `severity` event; S1 → immediate notification to owner+managers (Priority high, AlsoEmail).
- **Meetings:** manager+ schedules (design review: feature owner/developer/manager+ via ScheduleDesignReview with reviewers as attendees). Calendar event via `calendar.Service.CreateEvent` (event_type custom, visibility shared, entity_type 'workspace_project', entity_id project id, attendees = requested active members); notes wiki page per kind template (seeded in code) in the project space; project_meetings row. RecordAttendance: manager+; attendees must be active members; upsert per (event, occurrence_at, user). ConvertActionItem: member+; runs ListSimilarItems on the title first.
- **Standups:** blockers text scanned for `\b([A-Z]{2,6})-(\d{1,9})\b` with this project's prefix → BlockerKeys resolved; no status change.
- Add `Deps.Calendar *calendar.Service` and `Deps.Wiki` (whatever the wiki package exports for page create/read in tx) to service.go — backend agent may edit service.go Deps/Service fields for this (lead grants it this phase).

## Routes
| Method | Path | Min | Gate |
|---|---|---|---|
| GET | …/questions?cursor= | viewer | — |
| GET | …/questions/similar?q= | viewer | — |
| POST | …/questions | member | StatusesDiscuss |
| POST | …/questions/{questionID}/answer | manager (service: owner, or manager for assumption) | StatusesDiscuss |
| POST | …/requirement/gaps | manager | StatusesDiscuss |
| GET | …/brief | viewer | — |
| POST | …/brief | member (service: manager+ or track lead) | StatusesDiscuss |
| POST | …/brief/approve | member (service: owner/manager/track lead) | StatusesDiscuss |
| GET | …/items/{itemID}/doc | viewer | — |
| POST | …/items/{itemID}/doc/submit | member | StatusesDiscuss |
| POST | …/items/{itemID}/doc/reviews | member | StatusesDiscuss |
| POST | …/items/{itemID}/doc/design-review | member | StatusesDiscuss |
| POST | …/items/{itemID}/triage | member (service: manager+ / TL) | StatusesPlanning |
| GET | …/meetings?cursor= | viewer | — |
| POST | …/meetings | manager | StatusesDiscuss |
| PUT | …/meetings/{eventID}/attendance | manager | StatusesDiscuss |
| POST | …/meetings/{eventID}/action-items | member | StatusesPlanning |
| GET | …/standups?day= | viewer | — |
| PUT | …/standups | member | StatusesWork |
Question comment threads reuse the existing comments table with subject_type `requirement_question` / item threads `work_item`: add `GET/POST …/questions/{questionID}/comments` and `GET/POST …/items/{itemID}/comments` (viewer read, member write, StatusesDiscuss), content 1–5000 chars, cursor-paginated.

Errors: ErrStaleDocVersion 409, ErrNoReviewers 409, ErrBriefMissing 409, ErrQuestionAnswered 409, ErrTooEarly 409.

Jobs: `workspace.brief_reminder` hourly, `workspace.doc_review_reminder` hourly (cron defs in cmd/server/main.go).

## Frontend (Phase 3)
`/workspaces/[id]/requirement` gains Q&A (question-thread, question-composer with debounced similar check "Already asked — view thread", owner answer/"you decide", AI gaps panel `.ai-surface`), `/workspaces/[id]/brief` (link to wiki page editor, approvals list, approve bar with disabled-reason tooltip), item detail Doc tab (doc-review-bar: submit, approve/request changes on the version shown, stale → reload; change-request banner when spec_changed_at set or doc changed since approval; design-review scheduler), `/workspaces/[id]/bugs` (severity-sorted triage queue with triage dialog), `/workspaces/[id]/meetings` (list, schedule dialog, attendance sheet, action-item → ticket with similar check), standup form + today's standups on meetings page. Comments panel for items and questions.
