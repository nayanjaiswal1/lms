// Package workspace implements Project Workspaces (docs/project-workspace.md,
// plan in docs/project-workspace-plan/): a vague requirement → public share
// link → interests → team → tracks → Epic/Feature/Task work items with a
// doc-first gate, GitLab linking and a manager dashboard.
//
// It owns its own tables (workspace_projects and children, migrations
// 036–040) and never writes the projectmarket marketplace tables.
package workspace

import (
	"errors"
	"time"
)

// ─── Project lifecycle ────────────────────────────────────────────────────────

const (
	ProjectDraft      = "draft"
	ProjectRecruiting = "recruiting"
	ProjectActive     = "active"
	ProjectPaused     = "paused"
	ProjectCompleted  = "completed"
	ProjectCancelled  = "cancelled"
	ProjectArchived   = "archived"
)

const (
	BriefRaw        = "raw"
	BriefClarifying = "clarifying"
	BriefAgreed     = "agreed"
)

// Status gate sets (02 §2). A route's gate names which project statuses may
// mutate through it; GETs are never gated.
var (
	StatusesPlanning = []string{ProjectDraft, ProjectRecruiting, ProjectActive}
	StatusesWork     = []string{ProjectActive}
	StatusesDiscuss  = []string{ProjectDraft, ProjectRecruiting, ProjectActive, ProjectPaused}
	StatusesFeedback = []string{ProjectCompleted}
	StatusesRecruit  = []string{ProjectRecruiting, ProjectActive}
	StatusesLive     = []string{ProjectDraft, ProjectRecruiting, ProjectActive, ProjectPaused, ProjectCompleted}
	StatusesNotFinal = []string{ProjectDraft, ProjectRecruiting, ProjectActive, ProjectPaused}
)

// ─── Project roles ────────────────────────────────────────────────────────────

const (
	RoleOwner   = "owner"
	RoleManager = "manager"
	RoleMember  = "member"
	RoleViewer  = "viewer"
)

// roleRank orders project roles; a route's minimum role is compared by rank.
var roleRank = map[string]int{RoleViewer: 1, RoleMember: 2, RoleManager: 3, RoleOwner: 4}

// RoleAtLeast reports whether role meets min.
func RoleAtLeast(role, min string) bool { return roleRank[role] >= roleRank[min] && roleRank[role] > 0 }

const (
	MemberInvited = "invited"
	MemberActive  = "active"
	MemberLeft    = "left"
	MemberRemoved = "removed"
)

const (
	TrackMemberPending  = "pending"
	TrackMemberApproved = "approved"
)

const (
	InterestNew           = "new"
	InterestAccepted      = "accepted"
	InterestRejected      = "rejected"
	InterestInviteExpired = "invite_expired"
	InterestJoined        = "joined"
)

// Permission codes seeded by 036.
const (
	PermProjectsCreate  = "projects.create"
	PermProjectsOversee = "projects.oversee"
)

// ─── Work items (Phase 2+) ────────────────────────────────────────────────────

const (
	ItemTypeEpic    = "epic"
	ItemTypeFeature = "feature"
	ItemTypeTask    = "task"
	ItemTypeBug     = "bug"
	ItemTypeSubtask = "subtask"
)

const (
	ItemTodo       = "todo"
	ItemInProgress = "in_progress"
	ItemInReview   = "in_review"
	ItemTesting    = "testing"
	ItemDone       = "done"
	ItemBlocked    = "blocked"
	ItemReopened   = "reopened"
	ItemWontDo     = "wont_do"
)

const (
	DocDraft            = "draft"
	DocInReview         = "in_review"
	DocChangesRequested = "changes_requested"
	DocApproved         = "approved"
)

const (
	AssigneeOwner     = "owner"
	AssigneeDeveloper = "developer"
	AssigneeReviewer  = "reviewer"
	AssigneeTester    = "tester"
)

const (
	LinkBlocks     = "blocks"
	LinkRelates    = "relates"
	LinkDuplicates = "duplicates"
)

// ─── Validation limits (00-decisions + 02 §4.3) ───────────────────────────────

const (
	TitleMinLen          = 3
	TitleMaxLen          = 200
	RequirementMinLen    = 50
	RequirementMaxLen    = 20000
	TeamSizeFloor        = 2
	TeamSizeCeiling      = 50
	MaxSkills            = 15
	MaxSkillLen          = 40
	InterestNameMaxLen   = 100
	InterestEmailMaxLen  = 254
	InterestMessageMax   = 2000
	PortfolioURLMaxLen   = 500
	InterestBodyMaxBytes = 16 << 10
	TrackNameMaxLen      = 60
	OnboardingTitleMax   = 200
	ReapplyCooldown      = 30 * 24 * time.Hour
	InterestRetention    = 90 * 24 * time.Hour
	ShareTokenBytes      = 32
	PageSizeDefault      = 25
	PageSizeMax          = 100
)

// InterestAckMessage is the one response every public submission gets (D14):
// new, duplicate, already a member, inside the reject cooldown, honeypot.
const InterestAckMessage = "Thanks — the project owner will review your interest."

// ─── Sentinel errors (mapped to HTTP in handler.go) ───────────────────────────

var (
	ErrNotFound         = errors.New("not found")
	ErrForbidden        = errors.New("forbidden")
	ErrConflict         = errors.New("conflict")
	ErrInvalidInput     = errors.New("invalid input")
	ErrInvalidState     = errors.New("invalid state for this action")
	ErrSeatsFull        = errors.New("seats are full — raise the team size limit first")
	ErrAlreadyReviewed  = errors.New("this interest was already reviewed")
	ErrKeyPrefixTaken   = errors.New("key prefix is already used by another project in this organization")
	ErrKeyPrefixLocked  = errors.New("key prefix can't change once work items exist")
	ErrNotOrgMember     = errors.New("user is not an active member of this organization")
	ErrAlreadyMember    = errors.New("user is already on this project")
	ErrOwnerCantLeave   = errors.New("the owner can't leave — transfer ownership to a manager first")
	ErrPreconditionFail = errors.New("precondition failed")
	ErrRateLimited      = errors.New("rate limited")
)

// ─── Rows ─────────────────────────────────────────────────────────────────────

// Project is one workspace_projects row. ShareToken is only serialised for
// owners/overseers (the handler clears it otherwise).
type Project struct {
	ID                  string          `json:"id"`
	OrgID               string          `json:"org_id"`
	Title               string          `json:"title"`
	Requirement         string          `json:"requirement"`
	RequirementVersion  int             `json:"requirement_version"`
	Skills              []string        `json:"skills"`
	TeamSizeMin         int             `json:"team_size_min"`
	TeamSizeMax         int             `json:"team_size_max"`
	InterestDeadline    *time.Time      `json:"interest_deadline"`
	KeyPrefix           string          `json:"key_prefix"`
	ProjectStatus       string          `json:"project_status"`
	BriefStatus         string          `json:"brief_status"`
	ShareToken          string          `json:"share_token,omitempty"`
	ShareTokenRotatedAt *time.Time      `json:"share_token_rotated_at"`
	AcceptingInterests  bool            `json:"accepting_interests"`
	BriefWikiPageID     *string         `json:"brief_wiki_page_id"`
	TeamID              *string         `json:"team_id"`
	GitlabEnabled       bool            `json:"gitlab_enabled"`
	SprintsEnabled      bool            `json:"sprints_enabled"`
	WipLimit            int             `json:"wip_limit"`
	ItemSeq             int             `json:"item_seq"`
	HealthThresholds    HealthThreshold `json:"health_thresholds"`
	ActivatedAt         *time.Time      `json:"activated_at"`
	BriefAgreedAt       *time.Time      `json:"brief_agreed_at"`
	CompletedAt         *time.Time      `json:"completed_at"`
	FeedbackClosesAt    *time.Time      `json:"feedback_closes_at"`
	CreatedBy           *string         `json:"created_by"`
	CreatedAt           time.Time       `json:"created_at"`
	UpdatedAt           time.Time       `json:"updated_at"`
}

// HealthThreshold mirrors workspace_projects.health_thresholds (design §16.7).
type HealthThreshold struct {
	S1OpenHours     int `json:"s1_open_hours"`
	ForecastRedPct  int `json:"forecast_red_pct"`
	BlockedRedPct   int `json:"blocked_red_pct"`
	ReviewWaitDays  int `json:"review_wait_days"`
	ReopenYellowPct int `json:"reopen_yellow_pct"`
}

// ProjectSummary is one row of GET /api/workspaces.
type ProjectSummary struct {
	ID            string    `json:"id"`
	Title         string    `json:"title"`
	KeyPrefix     string    `json:"key_prefix"`
	ProjectStatus string    `json:"project_status"`
	BriefStatus   string    `json:"brief_status"`
	MyRole        string    `json:"my_role"`
	MemberCount   int       `json:"member_count"`
	TeamSizeMax   int       `json:"team_size_max"`
	CreatedAt     time.Time `json:"created_at"`
}

// ProjectDetail is GET /api/workspaces/{workspaceID}: the row plus the
// caller's live role so the frontend never needs a second round trip (04 §2).
type ProjectDetail struct {
	Project
	MyRole         string   `json:"my_role"`
	IsOverseer     bool     `json:"is_overseer"`
	MyTrackIDs     []string `json:"my_track_ids"`
	LedTrackIDs    []string `json:"led_track_ids"`
	SeatsUsed      int      `json:"seats_used"`
	WikiSpaceID    *string  `json:"wiki_space_id"`
	WikiSpaceSlug  *string  `json:"wiki_space_slug"`
	OnboardingDone bool     `json:"onboarding_done"`
}

// PublicProject is the anonymous share page payload (02 §4.2): no names,
// emails or internal ids.
type PublicProject struct {
	Title            string     `json:"title"`
	Requirement      string     `json:"requirement"`
	Skills           []string   `json:"skills"`
	InterestDeadline *time.Time `json:"interest_deadline"`
	TeamSizeMin      int        `json:"team_size_min"`
	TeamSizeMax      int        `json:"team_size_max"`
	SeatsLeft        int        `json:"seats_left"`
	Open             bool       `json:"open"`
	ClosedReason     string     `json:"closed_reason,omitempty"`
	OrgName          string     `json:"org_name"`
}

// Member is one project_members row joined to the user. Email is only set
// for manager+ callers.
type Member struct {
	ProjectID string     `json:"project_id"`
	UserID    string     `json:"user_id"`
	Name      string     `json:"name"`
	Email     string     `json:"email,omitempty"`
	AvatarURL *string    `json:"avatar_url"`
	Role      string     `json:"role"`
	Status    string     `json:"status"`
	AddedBy   *string    `json:"added_by"`
	JoinedAt  time.Time  `json:"joined_at"`
	LeftAt    *time.Time `json:"left_at"`
	TrackIDs  []string   `json:"track_ids"`
	// OnboardingPct is required-steps-done ÷ required steps (0–100).
	OnboardingPct int `json:"onboarding_pct"`
}

// Track is one project_tracks row with its members.
type Track struct {
	ID         string        `json:"id"`
	ProjectID  string        `json:"project_id"`
	Name       string        `json:"name"`
	LeadUserID *string       `json:"lead_user_id"`
	LeadName   *string       `json:"lead_name"`
	CreatedAt  time.Time     `json:"created_at"`
	Members    []TrackMember `json:"members"`
}

// TrackMember is one project_track_members row.
type TrackMember struct {
	UserID     string  `json:"user_id"`
	Name       string  `json:"name"`
	Status     string  `json:"status"`
	ApprovedBy *string `json:"approved_by"`
}

// Interest is one project_interests row (manager+ only — carries PII).
type Interest struct {
	ID           string     `json:"id"`
	ProjectID    string     `json:"project_id"`
	Name         string     `json:"name"`
	Email        string     `json:"email"`
	Skills       []string   `json:"skills"`
	PortfolioURL *string    `json:"portfolio_url"`
	Message      *string    `json:"message"`
	Status       string     `json:"status"`
	InviteID     *string    `json:"invite_id"`
	UserID       *string    `json:"user_id"`
	AIScore      *float64   `json:"ai_score"`
	AIRationale  *string    `json:"ai_rationale"`
	AIScoredAt   *time.Time `json:"ai_scored_at"`
	ReviewedBy   *string    `json:"reviewed_by"`
	ReviewedAt   *time.Time `json:"reviewed_at"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}

type RequirementVersion struct {
	Version        int       `json:"version"`
	RawRequirement string    `json:"raw_requirement"`
	CreatedBy      *string   `json:"created_by"`
	CreatedAt      time.Time `json:"created_at"`
}

// OnboardingStep is one onboarding_steps row plus the caller's completion.
type OnboardingStep struct {
	ID         string     `json:"id"`
	ProjectID  string     `json:"project_id"`
	Title      string     `json:"title"`
	WikiPageID *string    `json:"wiki_page_id"`
	Required   bool       `json:"required"`
	Position   int        `json:"position"`
	DoneAt     *time.Time `json:"done_at"`
	CreatedAt  time.Time  `json:"created_at"`
}

// Page is the cursor-paginated list envelope used by every list endpoint.
type Page[T any] struct {
	Items      []T    `json:"items"`
	NextCursor string `json:"next_cursor,omitempty"`
}

// ─── Requests ─────────────────────────────────────────────────────────────────

// CreateProjectRequest is POST /api/workspaces.
type CreateProjectRequest struct {
	Title            string     `json:"title"`
	Requirement      string     `json:"requirement"`
	Skills           []string   `json:"skills"`
	TeamSizeMin      int        `json:"team_size_min"`
	TeamSizeMax      int        `json:"team_size_max"`
	InterestDeadline *time.Time `json:"interest_deadline"`
	KeyPrefix        string     `json:"key_prefix"`
	GitlabEnabled    *bool      `json:"gitlab_enabled"`
	SprintsEnabled   *bool      `json:"sprints_enabled"`
}

// UpdateProjectRequest is PATCH /api/workspaces/{workspaceID} (owner):
// settings only — requirement text changes go through PUT …/requirement.
type UpdateProjectRequest struct {
	Title              *string          `json:"title"`
	Skills             *[]string        `json:"skills"`
	TeamSizeMin        *int             `json:"team_size_min"`
	TeamSizeMax        *int             `json:"team_size_max"`
	InterestDeadline   *time.Time       `json:"interest_deadline"`
	ClearDeadline      bool             `json:"clear_interest_deadline"`
	KeyPrefix          *string          `json:"key_prefix"`
	AcceptingInterests *bool            `json:"accepting_interests"`
	GitlabEnabled      *bool            `json:"gitlab_enabled"`
	SprintsEnabled     *bool            `json:"sprints_enabled"`
	WipLimit           *int             `json:"wip_limit"`
	HealthThresholds   *HealthThreshold `json:"health_thresholds"`
}

// SetStatusRequest is PATCH …/status.
type SetStatusRequest struct {
	Status string `json:"status"`
}

// TransferOwnerRequest is POST …/transfer-owner.
type TransferOwnerRequest struct {
	UserID string `json:"user_id"`
}

// SubmitInterestRequest is the public form body. Website is the honeypot.
type SubmitInterestRequest struct {
	Name         string   `json:"name"`
	Email        string   `json:"email"`
	Skills       []string `json:"skills"`
	PortfolioURL string   `json:"portfolio_url"`
	Message      string   `json:"message"`
	Website      string   `json:"website"`
}

// ReviewInterestRequest is PATCH …/interests/{interestID}.
type ReviewInterestRequest struct {
	Decision string `json:"decision"` // "accept" | "reject"
}

// ReviewInterestResult tells the owner what happened without revealing
// whether the email had an account (02 §4.4): always "Invitation sent" or
// "Added to project" for existing org members.
type ReviewInterestResult struct {
	Interest Interest `json:"interest"`
	Outcome  string   `json:"outcome"` // "invited" | "member_invited" | "rejected"
}

// AddMemberRequest is POST …/members: an existing org member, added as
// status=invited and confirmed in-app (02 §4.6).
type AddMemberRequest struct {
	// Exactly one of UserID / Email; Email resolves to an active member of
	// the project's org.
	UserID string `json:"user_id"`
	Email  string `json:"email"`
	Role   string `json:"role"`
}

// UpdateMemberRequest is PATCH …/members/{userID}.
type UpdateMemberRequest struct {
	Role string `json:"role"`
}

// RespondInviteRequest is POST …/membership/respond (the invitee).
type RespondInviteRequest struct {
	Accept bool `json:"accept"`
}

// CreateTrackRequest / UpdateTrackRequest are the track CRUD bodies.
type CreateTrackRequest struct {
	Name       string  `json:"name"`
	LeadUserID *string `json:"lead_user_id"`
}

type UpdateTrackRequest struct {
	Name       *string `json:"name"`
	LeadUserID *string `json:"lead_user_id"`
	ClearLead  bool    `json:"clear_lead"`
}

// TrackMembershipRequest is POST …/tracks/{trackID}/members: a member picks
// a track (pending) or a manager/lead adds someone (approved).
type TrackMembershipRequest struct {
	UserID string `json:"user_id"`
}

// CreateOnboardingStepRequest / UpdateOnboardingStepRequest are step CRUD.
type CreateOnboardingStepRequest struct {
	Title      string  `json:"title"`
	WikiPageID *string `json:"wiki_page_id"`
	Required   *bool   `json:"required"`
	Position   *int    `json:"position"`
}

type UpdateOnboardingStepRequest struct {
	Title      *string `json:"title"`
	WikiPageID *string `json:"wiki_page_id"`
	Required   *bool   `json:"required"`
	Position   *int    `json:"position"`
}
