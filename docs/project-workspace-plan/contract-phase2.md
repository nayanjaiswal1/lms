# Phase 2 API contract (lead-owned) — work items

Types: `backend/internal/workspace/models_items.go` (Go), `frontend/lib/workspace/types.ts` (TS, items section).
Lead-written, do not edit: `db/migrations/037_work_items.sql` (+down), `models_items.go`, `sod.go`,
`statemachine.go` (WorkItemStatusMachine, HierarchyRules, ChildAllowed, HasPath), `httputil.WriteErrorWithData`.

## Service signatures (exact — tests call these)
```go
// service_items.go
func (s *Service) CreateWorkItem(ctx context.Context, pc *ProjectCtx, req CreateWorkItemRequest) (*CreateWorkItemResult, error)
func (s *Service) GetWorkItem(ctx context.Context, pc *ProjectCtx, itemRef string) (*ItemDetail, error)   // itemRef = uuid or key "PAY-12"
func (s *Service) ListWorkItems(ctx context.Context, pc *ProjectCtx, f ItemFilter) (Page[WorkItem], error)
func (s *Service) UpdateWorkItem(ctx context.Context, pc *ProjectCtx, itemID string, req UpdateWorkItemRequest) (*WorkItem, error) // *ConflictError on stale version
func (s *Service) MoveWorkItem(ctx context.Context, pc *ProjectCtx, itemID string, req MoveWorkItemRequest) (*WorkItem, error)
func (s *Service) ArchiveWorkItem(ctx context.Context, pc *ProjectCtx, itemID string) error
func (s *Service) DeleteWorkItem(ctx context.Context, pc *ProjectCtx, itemID string) error             // ErrNotDeletable
func (s *Service) ListSimilarItems(ctx context.Context, pc *ProjectCtx, q string) ([]SimilarItem, error)
func (s *Service) ListItemEvents(ctx context.Context, pc *ProjectCtx, itemID, cursor string, limit int) (Page[ItemEvent], error)
// service_assign.go
func (s *Service) SetAssignees(ctx context.Context, pc *ProjectCtx, itemID string, req SetAssigneesRequest) ([]Assignee, error)
// service_links.go
func (s *Service) CreateLink(ctx context.Context, pc *ProjectCtx, itemID string, req CreateLinkRequest) (*ItemLink, error)
func (s *Service) DeleteLink(ctx context.Context, pc *ProjectCtx, itemID, toItemID, kind string) error
// service_execution.go
func (s *Service) TransitionItem(ctx context.Context, pc *ProjectCtx, itemID string, req TransitionRequest) (*WorkItem, error)
// Internal single entry used by TransitionItem now and GitLab automation (source=gitlab) in Phase 4:
func (s *Service) transitionTx(ctx context.Context, tx pgx.Tx, t transitionInput) (*WorkItem, error)
```

## Rules
**Create** (route gate StatusesPlanning; min role member):
- epic: manager+. feature: manager+ or lead of `track_id` (required for a TL). task/bug/subtask: member+.
- Parent must be in the same project and `ChildAllowed(parent.type, type)` (root = ""); else ErrIllegalHierarchy. `epic_id`/`feature_id` derived from the parent chain in the same tx. A task/bug/subtask with no `track_id` inherits its feature's (or parent's) track.
- Key: `UPDATE workspace_projects SET item_seq = item_seq + 1 WHERE id=$1 AND project_status IN ('draft','recruiting','active') RETURNING item_seq, key_prefix` inside the create tx (never MAX+1). Insert item + `create` event in the same tx.
- Severity only on bugs; priority default medium. Similar items (open, same project, excluding the new one) returned in the result.
**Update** (gate StatusesDiscuss; paused → only `description`): creator, any assignee, manager+, or lead of the item's track. `UPDATE … WHERE id AND project_id AND version=$v AND archived_at IS NULL`; 0 rows → re-read → *ConflictError{Current} (404 if gone). One `field` event per changed field (severity changes → `severity` event).
**Move**: same editors; new parent same project + ChildAllowed; recompute epic_id/feature_id for the item and all descendants in one tx under the project graph advisory lock; `parent` event.
**Delete**: only `todo` with exactly one event (`create`), by creator or manager+; else ErrNotDeletable. **Archive**: creator or manager+, sets archived_at, `archive` event; not while it has non-archived children.
**Similar**: q 1–200 chars; rate `rl:pw:similar:{user}` cfg.Workspace.SimilarPerUserMinute/min; one tx `SET LOCAL pg_trgm.similarity_threshold = 0.4` then `title % $q` ordered by similarity, LIMIT 5, open non-archived items only.
**Transition** (route gate StatusesPlanning; single entry `transitionTx`): lock item `FOR UPDATE`, version must match (else *ConflictError), `WorkItemStatusMachine.Allowed(from,to)` else ErrIllegalTransition; epic/feature: only `wont_do` by manager+ (their status is otherwise a roll-up).
- Moving to in_progress / in_review / testing / done needs project `active` (ErrInvalidState) and `brief_status='agreed'` (ErrBriefNotAgreed).
- Doc gate: a `task` whose feature's `doc_status <> 'approved'` can't enter in_progress (ErrDocNotApproved). Bugs/subtasks have no doc gate.
- in_progress: actor is owner/developer on the item or project manager+; item must have an owner; no open incoming `blocks` link (ErrBlockedByOpen); WIP: lock the item owner's `project_members` row FOR UPDATE, count their owned in_progress items in this project; `>= wip_limit` → ErrWipLimit (S1 bugs exempt).
- in_review: owner/developer or manager+.
- testing (from in_review): SodCheck(review_code) — a reviewer who is not a developer. (GitLab automation in Phase 4 calls transitionTx with source=gitlab and skips the actor role check but never SoD-relevant moves.)
- done (from testing): the tester; if no tester assigned, an assignee who is not a developer, or manager+ who is not a developer — always SodCheck(test_pass/set_done).
- reopened: from testing (tester, SodCheck(test_fail)) or from done (tester, reporter=created_by, or manager+); reason required; `reopen_count + 1`.
- blocked: any assignee or manager+; reason AND `blocker_item_id` required; creates the `blocker → item` blocks link if absent (cycle-checked under the graph lock); sets blocked_reason; leaving blocked clears it.
- wont_do: project owner/manager (manager+), reason required.
- Write the status + `version+1` + `status` event (from/to/reason/source) in the same tx, then roll up ancestors in the same tx (lock feature then epic after the child): all non-archived children done|wont_do with ≥1 done → done; all wont_do → wont_do; any child past todo → in_progress; else todo. A parent explicitly set wont_do is left alone. Roll-up changes write a `status` event with source=system.
**Assignees** (PUT full set; gate StatusesPlanning): lock item FOR UPDATE; diff current vs desired.
- Who: manager+ or lead of the item's track may set anything. A member may only add themselves as `owner` when the item has no owner, the item's track is one they're an approved member of (or the item has no track), and CanSelfAssign is true (ErrOnboardingIncomplete); and may remove themselves.
- Each assignee: active project member; if not project owner/manager they must be an approved member of the item's track (when it has one).
- ValidateAssigneeRoles(result) (one owner, reviewer≠developer, tester≠developer → ErrSoD).
- A task under a feature with no track can't be assigned (ErrPreconditionFail "set the feature's track first"); a track with no lead blocks new assignments by non-managers (ErrTrackLeaderless).
- `assign`/`unassign` events per change; unique-owner violation (23505) → ErrConflict.
**Links** (gate StatusesPlanning; member+): both items same project (else 404), from≠to.
- blocks: `SELECT pg_advisory_xact_lock(hashtextextended('work_item_graph:' || $project, 0))`, recursive reach check (01 §4) → ErrLinkCycle, then insert. Same lock is taken by Move.
- relates: unique per unordered pair (ErrConflict on dup). duplicates: this item duplicates `to`; closes this item to `wont_do` with reason "Duplicate of KEY" through transitionTx (source=system, skips role checks), notify its assignees + reporter after commit.
- `link`/`unlink` events on the from item.
**Planning fixtures (2c)**: delete `backend/internal/gitlab/handler_planning.go`, `planningdata/`, `planning_test.go` and their two routes in `gitlab/routes.go`; register `GET /api/gitlab/planning/board` and `GET /api/gitlab/planning/issues` from the workspace package instead, built from the caller's assigned open work items across their active workspaces (same JSON shapes as `frontend/lib/server/gitlab-planning.ts` AeBoard / AeIssuesPage — fill every field from real data, empty arrays where there's no source; quadrant from priority+due date: urgent|high & due ≤3d → do_now, urgent|high → schedule, others due ≤3d → delegate, rest → eliminate — match the quadrant keys used in the fixture).

## Routes (add to routes.go)
| Method | Path | Min | Gate | Body → data |
|---|---|---|---|---|
| GET | /api/workspaces/{workspaceID}/items?type=&status=&track=&assignee=&parent=&feature=&epic=&q=&archived=&cursor=&limit= | viewer | — | Page[WorkItem] |
| POST | /api/workspaces/{workspaceID}/items | member | StatusesPlanning | CreateWorkItemRequest → CreateWorkItemResult (201) |
| GET | /api/workspaces/{workspaceID}/items/similar?q= | viewer | — | []SimilarItem |
| GET | /api/workspaces/{workspaceID}/items/{itemID} | viewer | — | ItemDetail (itemID = uuid or key) |
| PATCH | /api/workspaces/{workspaceID}/items/{itemID} | member | StatusesDiscuss | UpdateWorkItemRequest → WorkItem; 409 → `{"error": msg, "data": current WorkItem}` via httputil.WriteErrorWithData |
| POST | /api/workspaces/{workspaceID}/items/{itemID}/move | member | StatusesPlanning | MoveWorkItemRequest → WorkItem (409 same) |
| POST | /api/workspaces/{workspaceID}/items/{itemID}/archive | member | StatusesPlanning | → {} |
| DELETE | /api/workspaces/{workspaceID}/items/{itemID} | member | StatusesPlanning | → {} |
| POST | /api/workspaces/{workspaceID}/items/{itemID}/transition | member | StatusesPlanning | TransitionRequest → WorkItem (409 same) |
| PUT | /api/workspaces/{workspaceID}/items/{itemID}/assignees | member | StatusesPlanning | SetAssigneesRequest → []Assignee |
| POST | /api/workspaces/{workspaceID}/items/{itemID}/links | member | StatusesPlanning | CreateLinkRequest → ItemLink |
| DELETE | /api/workspaces/{workspaceID}/items/{itemID}/links/{toItemID}/{kind} | member | StatusesPlanning | → {} |
| GET | /api/workspaces/{workspaceID}/items/{itemID}/events?cursor=&limit= | viewer | — | Page[ItemEvent] |

Error mapping additions: ErrStaleVersion/*ConflictError 409 (with data), ErrIllegalHierarchy 422, ErrIllegalTransition 409, ErrBlockedByOpen 409, ErrWipLimit 409, ErrLinkCycle 409, ErrSoD 403, ErrBriefNotAgreed 409, ErrDocNotApproved 409, ErrOnboardingIncomplete 403, ErrNotDeletable 409, ErrReasonRequired 422, ErrTrackLeaderless 409.

## Frontend (Phase 2)
- D17: `ActionResult` gains `conflict?: T` filled from the 409 body's `data` in `apiAction`/`apiUpload` (lead does this edit in `lib/server/api.ts`).
- `/workspaces/[id]/board` ("Backlog board": kanban by status for task/bug/subtask, WIP badge per person from item list, mobile = one column + segment control, status change via menu honoring `legal_transitions` from the item detail or the static machine; illegal targets disabled), `/workspaces/[id]/list` (ResponsiveTable, filters in URL via nuqs), `/workspaces/[id]/items/[key]` (04 §4 layout: header, description, banners, tabs Overview|Activity, right rail assignees/transitions/links; locked transitions show a lock + tooltip reason), create-item dialog with debounced similar check ("Link as duplicate instead" per hit; submit stays enabled), conflict dialog (your version vs current; "Reload current", owner/manager "Overwrite" = resubmit with current.version).
