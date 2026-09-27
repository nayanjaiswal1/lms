# Phase 1 API contract (lead-owned)

Binding for backend, frontend and test agents. Types are in
`backend/internal/workspace/models.go` (Go) and `frontend/lib/workspace/types.ts` (TS).
Response envelope is the repo's standard: `{"data": ...}` / `{"error": "..."}` /
`{"error":"validation failed","fields":{...}}`.

## Already written by the lead (do not edit)
- `db/migrations/036_project_workspace_core.sql` (+ `.down.sql`)
- `internal/workspace/models.go`, `statemachine.go`, `middleware.go`, `repo.go`, `service.go`
- `internal/orgs/invite.go` (Join fixes), `internal/orgs/invite_project.go`
  (`InviteService.CreateForProject(ctx, tx, orgID, actorUserID, email) (inviteID string, err error)` —
  returns `orgs.ErrAlreadyMember` when the email is an active org member;
  `InviteService.IssueProjectInviteToken(ctx, orgID, inviteID) (*orgs.Invite, token string, err error)`)
- `internal/config/config.go` → `cfg.Workspace` (`config.WorkspaceLimits`) holds every rate limit.
- `internal/api/router.go` wiring (lead does it after merge; backend agent exposes `workspace.New(deps) *Handler`,
  `(*Handler).RegisterRoutes(r chi.Router, authzSvc *authz.Service)`, `(*Handler).RegisterPublicRoutes(r chi.Router)`, `(*Handler).Service() *Service`).

## Service method signatures (exact — tests call these)

`pc *ProjectCtx` is what `RequireProjectRole` resolved; services trust `pc.ProjectID/OrgID/UserID/Role/Overseer`.

```go
// service_project.go
func (s *Service) CreateProject(ctx context.Context, orgID, userID string, req CreateProjectRequest) (*Project, error)
func (s *Service) ListProjects(ctx context.Context, orgID, userID, cursor string, limit int) (Page[ProjectSummary], error)
func (s *Service) GetProject(ctx context.Context, pc *ProjectCtx) (*ProjectDetail, error)
func (s *Service) UpdateProject(ctx context.Context, pc *ProjectCtx, req UpdateProjectRequest) (*Project, error)
func (s *Service) SetProjectStatus(ctx context.Context, pc *ProjectCtx, to string) (*Project, error)
func (s *Service) RotateShareToken(ctx context.Context, pc *ProjectCtx) (string, error)
func (s *Service) TransferOwner(ctx context.Context, pc *ProjectCtx, toUserID string) error
func (s *Service) GetRequirement(ctx context.Context, pc *ProjectCtx) (*RequirementView, error)
func (s *Service) UpdateRequirement(ctx context.Context, pc *ProjectCtx, text string) (*RequirementView, error)

// service_recruiting.go
func (s *Service) GetPublicProject(ctx context.Context, shareToken string) (*PublicProject, error)            // ErrNotFound for unknown/draft/cancelled/archived/rotated/not-accepting
func (s *Service) SubmitInterest(ctx context.Context, shareToken string, req SubmitInterestRequest) error      // nil for every accepted-shape outcome (D14); ErrNotFound; ErrInvalidInput (with FieldError)
func (s *Service) ListInterests(ctx context.Context, pc *ProjectCtx, status, cursor string, limit int) (Page[Interest], error)
func (s *Service) ReviewInterest(ctx context.Context, pc *ProjectCtx, interestID, decision string) (*ReviewInterestResult, error) // ErrSeatsFull, ErrAlreadyReviewed
func (s *Service) RankInterest(ctx context.Context, pc *ProjectCtx, interestID string) (*Interest, error)    // cached on the row; AI never sees name/email
func (s *Service) SeatsUsed(ctx context.Context, db DBTX, projectID string) (int, error)
func (s *Service) PurgeInterests(ctx context.Context) (int64, error)                                          // daily job
func (s *Service) ExpireInvitedInterests(ctx context.Context) (int64, error)                                  // accepted + invite expired → invite_expired

// service_onboarding.go (members, tracks, onboarding)
func (s *Service) ListMembers(ctx context.Context, pc *ProjectCtx) ([]Member, error)
func (s *Service) AddMember(ctx context.Context, pc *ProjectCtx, req AddMemberRequest) (*Member, error)      // existing org member → status invited
func (s *Service) RespondToInvite(ctx context.Context, orgID, userID, projectID string, accept bool) error   // invitee; no RequireProjectRole
func (s *Service) ListMyInvitations(ctx context.Context, orgID, userID string) ([]ProjectSummary, error)
func (s *Service) UpdateMemberRole(ctx context.Context, pc *ProjectCtx, userID, role string) (*Member, error)
func (s *Service) RemoveMember(ctx context.Context, pc *ProjectCtx, userID string) error                     // self = leave (status left), else removed
func (s *Service) ListTracks(ctx context.Context, pc *ProjectCtx) ([]Track, error)
func (s *Service) CreateTrack(ctx context.Context, pc *ProjectCtx, req CreateTrackRequest) (*Track, error)
func (s *Service) UpdateTrack(ctx context.Context, pc *ProjectCtx, trackID string, req UpdateTrackRequest) (*Track, error)
func (s *Service) DeleteTrack(ctx context.Context, pc *ProjectCtx, trackID string) error
func (s *Service) JoinTrack(ctx context.Context, pc *ProjectCtx, trackID, userID string) error              // self → pending; manager/lead → approved
func (s *Service) ApproveTrackMember(ctx context.Context, pc *ProjectCtx, trackID, userID string) error
func (s *Service) LeaveTrack(ctx context.Context, pc *ProjectCtx, trackID, userID string) error
func (s *Service) ListOnboarding(ctx context.Context, pc *ProjectCtx) ([]OnboardingStep, error)             // DoneAt = caller's
func (s *Service) CreateOnboardingStep(ctx context.Context, pc *ProjectCtx, req CreateOnboardingStepRequest) (*OnboardingStep, error)
func (s *Service) UpdateOnboardingStep(ctx context.Context, pc *ProjectCtx, stepID string, req UpdateOnboardingStepRequest) (*OnboardingStep, error)
func (s *Service) DeleteOnboardingStep(ctx context.Context, pc *ProjectCtx, stepID string) error
func (s *Service) SetOnboardingStepDone(ctx context.Context, pc *ProjectCtx, stepID string, done bool) error
func (s *Service) CanSelfAssign(ctx context.Context, db DBTX, projectID, userID string) (bool, error)      // all required steps done
func (s *Service) IsTrackLead(ctx context.Context, db DBTX, projectID, trackID, userID string) (bool, error)
```

Extra model the backend agent adds to `models.go`'s neighbour file `models_phase1.go` (backend-owned):
```go
type RequirementView struct {
    Requirement        string               `json:"requirement"`
    RequirementVersion int                  `json:"requirement_version"`
    BriefStatus        string               `json:"brief_status"`
    Versions           []RequirementVersion `json:"versions"`
}
// FieldError carries per-field validation messages; handler writes WriteFieldErrors(422).
type FieldError struct{ Fields map[string]string }
func (e *FieldError) Error() string
func (e *FieldError) Unwrap() error { return ErrInvalidInput }
```

## Rules the services enforce (beyond the middleware)
- CreateProject: title 3–200, requirement 50–20000, `2 ≤ min ≤ max ≤ 50`, skills ≤15×40, key_prefix `^[A-Z]{2,6}$` (default = first letters of title, upper, padded to 2–6; collision → `ErrKeyPrefixTaken`), share token 32 bytes crypto/rand base64url.
  One tx: project row, owner member (active), requirement_versions v1, project wiki space (wiki_spaces.project_id = project, name = title, unique slug). Audit `project.created`.
  Rate limit `rl:pw:create:{user}` CreatePerUserDay / 24h → `ErrRateLimited`.
- SetProjectStatus: `ProjectStatusMachine.Allowed`; one tx `SELECT … FOR UPDATE`; `UPDATE … WHERE project_status=$from`.
  draft→recruiting: requirement ≥ 50 chars. recruiting→active: active manager/member count ≥ team_size_min, ≥1 track, `team_id` set if gitlab_enabled (Phase 4 provisions; until then gitlab_enabled projects need team_id → `ErrPreconditionFail` with message) ; sets `activated_at` once and `brief_status` raw→clarifying.
  active→completed: no items in progress/review/testing (Phase 2 adds the check; in Phase 1 there are no items). Sets completed_at, feedback_closes_at = +14d.
  Audit every transition `project.status_changed` with from/to.
- Overseer mutations without membership also write audit `project.oversee_action`.
- TransferOwner: target must be an active manager; swap roles in one tx (old owner → manager).
- UpdateProject: key_prefix change rejected once item_seq > 0 (`ErrKeyPrefixLocked`); team size bounds as create; max ≥ current seats.
- UpdateRequirement (owner; draft/recruiting/active): new requirement_versions row, bump requirement_version; if brief_status was agreed → clarifying (Phase 3 adds change requests).
- Seats = active or invited manager/member rows + accepted interests whose linked invite is still pending (not accepted, not revoked, not expired). Owner/viewers excluded.
- ReviewInterest accept: one tx — `SELECT … FROM workspace_projects WHERE id=$1 FOR UPDATE`; seats < team_size_max else `ErrSeatsFull`; `UPDATE project_interests SET status='accepted' … WHERE id=$iid AND project_id=$p AND status='new'` (0 rows → `ErrAlreadyReviewed`);
  email is an active org member → `project_members(status='invited', role='member')` (ON CONFLICT: re-activate only left/removed rows as invited) and in-app notification; else `invites.CreateForProject` → set `invite_id`; after commit enqueue job `workspace.project_invite_email {org_id, invite_id, project_title}`.
  Outcome is always "invited" (never reveals account existence). Rate `rl:pw:accept:{project}` AcceptPerProjectDay/24h.
  Reject: status rejected, reviewed_by/at. No email in Phase 1.
- SubmitInterest: honeypot `website != ""` → nil (drop). Validation per 02 §4.3 (name 1–100, email net/mail ≤254 lower-cased, ≤15 skills ×40, portfolio `https?://` ≤500, message ≤2000, control chars stripped). Upsert per 01 §4 (reapply after 30d cooldown). Project must be recruiting, or active+accepting_interests; deadline not passed; seats left > 0 — else the same nil (page shows closed). Rate limits (IP/email-hash/project) are applied in the handler.
- GetPublicProject: recruiting, or active + accepting_interests; never names/emails/ids. `Open=false` + `ClosedReason` ("deadline_passed" | "seats_full" | "not_accepting") when shown but closed.
- AddMember: target must be an active org member; seats check under project FOR UPDATE; role member|viewer|manager (manager only when caller Role==owner).
- UpdateMemberRole: manager sets member/viewer only; only owner grants/revokes manager; owner role never via this route.
- RemoveMember: nobody removes owner (`ErrOwnerCantLeave`); managers remove member/viewer; only owner removes a manager; self can leave. Sets status left/removed + left_at, deletes their project_track_members rows. Audit.
- Org member removal (orgs/member.go) marks that user `removed` on every workspace in the org in the same tx (skip owner rows — owner of a project can't be removed from org without transfer? → set owner rows untouched and log; document).
- Tracks: name unique per project (case-insensitive) → ErrConflict; lead must be an active member. Self-join → pending; manager+/lead of that track adds → approved.
- Onboarding: steps CRUD manager+; SetOnboardingStepDone caller only.

## Routes (all under RequireAuth + RequireCSRF except public)

Min role / status gate are applied with `RequireProjectRole(pool, perms, min)` and `ProjectStatusGate(...)`.

| Method | Path | Min role | Gate | Body → data |
|---|---|---|---|---|
| POST | /api/workspaces | `authz.RequirePermission(projects.create)` | — | CreateProjectRequest → Project (201) |
| GET | /api/workspaces?cursor=&limit= | auth | — | Page[ProjectSummary] |
| GET | /api/workspaces/invitations | auth | — | []ProjectSummary |
| POST | /api/workspaces/{workspaceID}/membership/respond | auth (service checks invited row) | — | RespondInviteRequest → {} |
| GET | /api/workspaces/{workspaceID} | viewer | — | ProjectDetail |
| PATCH | /api/workspaces/{workspaceID} | owner | StatusesNotFinal | UpdateProjectRequest → Project |
| PATCH | /api/workspaces/{workspaceID}/status | owner | — | SetStatusRequest → Project |
| POST | /api/workspaces/{workspaceID}/share-token | owner | StatusesLive | → {"share_token": "..."} |
| POST | /api/workspaces/{workspaceID}/transfer-owner | owner | StatusesLive | TransferOwnerRequest → {} |
| GET | /api/workspaces/{workspaceID}/requirement | viewer | — | RequirementView |
| PUT | /api/workspaces/{workspaceID}/requirement | owner | StatusesPlanning | {"requirement": "..."} → RequirementView |
| GET | /api/workspaces/{workspaceID}/interests?status=&cursor=&limit= | manager | — | Page[Interest] |
| PATCH | /api/workspaces/{workspaceID}/interests/{interestID} | manager | StatusesRecruit | ReviewInterestRequest → ReviewInterestResult |
| POST | /api/workspaces/{workspaceID}/interests/{interestID}/rank | manager | StatusesRecruit | → Interest |
| GET | /api/workspaces/{workspaceID}/members | viewer | — | []Member |
| POST | /api/workspaces/{workspaceID}/members | manager | StatusesPlanning | AddMemberRequest → Member |
| PATCH | /api/workspaces/{workspaceID}/members/{userID} | manager | StatusesPlanning | UpdateMemberRequest → Member |
| DELETE | /api/workspaces/{workspaceID}/members/{userID} | viewer (service: self or manager) | StatusesLive | → {} |
| GET | /api/workspaces/{workspaceID}/tracks | viewer | — | []Track |
| POST | /api/workspaces/{workspaceID}/tracks | manager | StatusesPlanning | CreateTrackRequest → Track |
| PATCH | /api/workspaces/{workspaceID}/tracks/{trackID} | manager | StatusesPlanning | UpdateTrackRequest → Track |
| DELETE | /api/workspaces/{workspaceID}/tracks/{trackID} | manager | StatusesPlanning | → {} |
| POST | /api/workspaces/{workspaceID}/tracks/{trackID}/members | member | StatusesPlanning | TrackMembershipRequest → {} |
| POST | /api/workspaces/{workspaceID}/tracks/{trackID}/members/{userID}/approve | member (service: lead or manager+) | StatusesPlanning | → {} |
| DELETE | /api/workspaces/{workspaceID}/tracks/{trackID}/members/{userID} | member (service: self, lead, manager+) | StatusesPlanning | → {} |
| GET | /api/workspaces/{workspaceID}/onboarding | viewer | — | []OnboardingStep |
| POST | /api/workspaces/{workspaceID}/onboarding | manager | StatusesPlanning | CreateOnboardingStepRequest → OnboardingStep |
| PATCH | /api/workspaces/{workspaceID}/onboarding/{stepID} | manager | StatusesPlanning | UpdateOnboardingStepRequest → OnboardingStep |
| DELETE | /api/workspaces/{workspaceID}/onboarding/{stepID} | manager | StatusesPlanning | → {} |
| PUT | /api/workspaces/{workspaceID}/onboarding/{stepID}/done | member | StatusesNotFinal | {"done": bool} → {} |
| GET | /api/public/workspaces/{shareToken} | public, `rl:pw:view:ip:{ip}` | — | PublicProject; headers `Referrer-Policy: no-referrer`, `X-Robots-Tag: noindex`, `Cache-Control: no-store` |
| POST | /api/public/workspaces/{shareToken}/interest | public, MaxBytesReader 16KB, `rl:pw:int:ip:{ip}`, `rl:pw:int:email:{sha256(lower(email))}`, `rl:pw:int:proj:{token}` | — | SubmitInterestRequest → 202 `{"data":{"message": InterestAckMessage}}` |

Error mapping (handler.go): ErrNotFound 404 · ErrForbidden 403 · ErrConflict/ErrSeatsFull/ErrAlreadyReviewed/ErrKeyPrefixTaken/ErrKeyPrefixLocked/ErrInvalidState/ErrAlreadyMember/ErrOwnerCantLeave/ErrPreconditionFail 409 (message = err text) · *FieldError 422 fields · ErrInvalidInput 400 · ErrRateLimited 429 with `Retry-After`.

## Jobs
- `workspace.project_invite_email` (one-time): IssueProjectInviteToken → email "someone expressed interest using this address; ignore if not you" + link `{FrontendURL}/orgs/join?token=` (same sender path as `jobs/handlers/invite.go`).
- `workspace.purge_interests` (daily 04:00 cron): `ExpireInvitedInterests` then `PurgeInterests` (02 §4.7).

## Frontend (D3)
`/workspaces`, `/workspaces/new`, `/workspaces/[id]` (home), `/workspaces/[id]/interests`, `/workspaces/[id]/members`,
`/workspaces/[id]/tracks`, `/workspaces/[id]/onboarding`, `/workspaces/[id]/requirement`, `/workspaces/[id]/settings`, public `/join/[token]`.
Interest POST is a server action through a new no-cookie helper `apiActionPublic` in `lib/server/api.ts` that forwards `clientIpHeaders()` (the backend trusts XFF only from TRUSTED_PROXY_CIDRS), so the per-IP limit keys on the real client IP — same pattern as every other server call.
