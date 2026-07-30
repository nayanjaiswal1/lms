// Package gitlab implements the GitLab integration domain. Batch 1 covers
// only the connection layer: an org-level installation (PAT or OAuth service
// account) and per-user personal connections (OAuth+PKCE), following the
// same handler.go/repo.go/service.go/routes.go split as internal/assessment.
// Later batches add teams/checkpoints/webhooks/dashboards/originality/handoff
// as their own repo_<concern>.go / service_<concern>.go / handler_<concern>.go
// files alongside these, not by growing these base files.
package gitlab

import "time"

// Auth kinds for GitlabInstallation.AuthKind.
const (
	AuthKindOAuth = "oauth"
	AuthKindPAT   = "pat"
)

// Tiers for GitlabInstallation.Tier.
const (
	TierFree     = "free"
	TierPremium  = "premium"
	TierUltimate = "ultimate"
)

// Installation statuses.
const (
	InstallationStatusPending = "pending"
	InstallationStatusActive  = "active"
	InstallationStatusError   = "error"
	InstallationStatusRevoked = "revoked"
	InstallationStatusExpired = "expired"
)

// Connection statuses.
const (
	ConnectionStatusActive  = "active"
	ConnectionStatusExpired = "expired"
	ConnectionStatusRevoked = "revoked"
)

// OAuth state purposes — disambiguates the two flows that share one callback
// route (GET /api/gitlab/callback): an admin completing installation OAuth
// consent, or a member connecting their own account.
const (
	OAuthPurposeInstallation = "installation"
	OAuthPurposeConnection   = "connection"
)

// GitlabInstallation is one named GitLab credential in an org's pool —
// either a Personal Access Token or an OAuth service account, both
// supported — used for all admin-level group/project/member work. An org
// can hold several (e.g. "GitLab.com" + a self-hosted instance); exactly one
// per org has IsDefault=true (migration 024's partial unique index enforces
// this), which is what every project_assignment with a nil InstallationID
// resolves to. It also carries the one registered GitLab OAuth Application
// (OAuthClientID/Secret) that powers every member's own personal connection
// below, independent of which AuthKind the installation itself uses.
type GitlabInstallation struct {
	ID                   string
	OrgID                string
	Name                 string
	IsDefault            bool
	BaseURL              string
	Tier                 string
	GitlabUserID         *int64
	GitlabUsername       *string
	AccessTokenEnc       []byte
	AccessTokenExpiresAt *time.Time
	RefreshTokenEnc      []byte
	AuthKind             string
	OAuthClientID        *string
	OAuthClientSecretEnc []byte
	RootGroupID          *int64
	RootGroupPath        *string
	WebhookSecretEnc     []byte
	WebhookMode          string
	Status               string
	LastError            *string
	LastVerifiedAt       *time.Time
	CreatedBy            *string
	CreatedAt            time.Time
	UpdatedAt            time.Time
}

// GitlabConnection is a per-user, opt-in OAuth+PKCE link to the member's own
// GitLab account — attributes future commits/MRs to the real person rather
// than the installation's bot identity.
type GitlabConnection struct {
	ID                   string
	OrgID                string
	UserID               string
	GitlabUserID         int64
	GitlabUsername       string
	GitlabEmail          *string
	AvatarURL            *string
	AccessTokenEnc       []byte
	AccessTokenExpiresAt *time.Time
	RefreshTokenEnc      []byte
	Scopes               []string
	Status               string
	LastUsedAt           *time.Time
	CreatedAt            time.Time
	UpdatedAt            time.Time
	RevokedAt            *time.Time
}

// GitlabOAuthState is the server-side PKCE verifier + pending-flow state
// row — the verifier must survive a cross-site top-level redirect back from
// the GitLab instance, which a cookie alone cannot carry.
type GitlabOAuthState struct {
	State                string
	OrgID                string
	UserID               string
	Purpose              string
	CodeVerifier         string
	BaseURL              *string
	OAuthClientID        *string
	OAuthClientSecretEnc []byte
	RedirectTo           *string
	// Name and InstallationID are purpose='installation' only. InstallationID
	// set means this flow completes an update to that existing pool row;
	// nil means it creates a new one, named Name.
	Name           *string
	InstallationID *string
	ExpiresAt      time.Time
	CreatedAt      time.Time
}

// InstallationStatusView is the admin-facing installation detail — never
// includes token material.
type InstallationStatusView struct {
	ID             string     `json:"id"`
	Name           string     `json:"name"`
	IsDefault      bool       `json:"is_default"`
	Connected      bool       `json:"connected"`
	BaseURL        string     `json:"base_url,omitempty"`
	Tier           string     `json:"tier,omitempty"`
	AuthKind       string     `json:"auth_kind,omitempty"`
	Status         string     `json:"status,omitempty"`
	GitlabUsername string     `json:"gitlab_username,omitempty"`
	HasOAuthApp    bool       `json:"has_oauth_app"`
	LastError      *string    `json:"last_error,omitempty"`
	LastVerifiedAt *time.Time `json:"last_verified_at,omitempty"`
	CreatedAt      *time.Time `json:"created_at,omitempty"`
}

// StatusView is what GET /api/gitlab/status returns to any org member — the
// coarse combined picture the settings page needs: every installation in the
// org's pool, and whether the current user has their own personal connection
// (which always resolves against the org's default installation — see
// Service.userClientFor's own doc comment for why personal connections don't
// carry their own installation selection).
type StatusView struct {
	Installations []InstallationStatusView `json:"installations"`
	Connection    ConnectionStatusView     `json:"connection"`
}

// GitlabOrgConfig is the org-wide GitLab policy row: whether individual
// project assignments may pin themselves to a specific pool installation, or
// must all follow the org's current default. Mirrors the existing
// per-domain org-config pattern (lab_org_config, org_auth_config) — one row
// per org, absent means "default" (AllowProjectOverride: true), same
// absence convention GetInstallation already uses for "not connected yet".
type GitlabOrgConfig struct {
	OrgID                string    `json:"org_id"`
	AllowProjectOverride bool      `json:"allow_project_override"`
	UpdatedAt            time.Time `json:"updated_at"`
}

// ConnectionStatusView is the member-facing personal-connection detail —
// never includes token material.
type ConnectionStatusView struct {
	Connected      bool       `json:"connected"`
	GitlabUsername string     `json:"gitlab_username,omitempty"`
	Status         string     `json:"status,omitempty"`
	Scopes         []string   `json:"scopes,omitempty"`
	LastUsedAt     *time.Time `json:"last_used_at,omitempty"`
	CreatedAt      *time.Time `json:"created_at,omitempty"`
}

// ─── Batch 2: project/team layer ───────────────────────────────────────────

// Assignment statuses.
const (
	AssignmentStatusDraft    = "draft"
	AssignmentStatusActive   = "active"
	AssignmentStatusArchived = "archived"
)

// Assignment/project visibility (never "public" — kind-herding-cookie.md §0
// decision #3 requires the template, and therefore every fork, stay
// private/internal).
const (
	VisibilityPrivate  = "private"
	VisibilityInternal = "internal"
)

// Team provision statuses.
const (
	ProvisionPending      = "pending"
	ProvisionProvisioning = "provisioning"
	ProvisionReady        = "ready"
	ProvisionFailed       = "failed"
)

// Team member roles.
const (
	MemberRoleLead   = "lead"
	MemberRoleMember = "member"
)

// Team member sync statuses. "removing" is the state a member sits in
// between DELETE /members/{userID} and the sync_members job actually
// revoking their GitLab access — the local row is never deleted first,
// so a crash mid-removal never leaves someone with orphaned repo access
// MindForge has already forgotten about.
const (
	SyncStatusPending  = "pending"
	SyncStatusSynced   = "synced"
	SyncStatusFailed   = "failed"
	SyncStatusRemoving = "removing"
)

// GitLab project access levels — project_team_members.gitlab_access_level's
// CHECK constraint mirrors GitLab's own numeric scale, not this app's invention.
const (
	AccessLevelReporter   = 20
	AccessLevelDeveloper  = 30
	AccessLevelMaintainer = 40
)

// ProjectAssignment is an instructor-defined project spec for a batch: which
// template repo teams fork from, how big a subgroup/visibility/branch-
// protection policy every team under it shares, and its publish lifecycle
// (draft -> active triggers real GitLab provisioning; see service_provision.go).
type ProjectAssignment struct {
	ID                   string     `json:"id"`
	OrgID                string     `json:"org_id"`
	BatchID              string     `json:"batch_id"`
	CourseID             *string    `json:"course_id,omitempty"`
	LabID                *string    `json:"lab_id,omitempty"`
	Title                string     `json:"title"`
	Slug                 string     `json:"slug"`
	Description          *string    `json:"description,omitempty"`
	TemplateProjectID    *int64     `json:"template_project_id,omitempty"`
	TemplateProjectPath  *string    `json:"template_project_path,omitempty"`
	GitlabGroupID        *int64     `json:"gitlab_group_id,omitempty"`
	GitlabGroupPath      *string    `json:"gitlab_group_path,omitempty"`
	// InstallationID pins this assignment (and every team provisioned under
	// it) to one specific pool installation. Nil means "follow the org's
	// current default installation" — see Service.resolveInstallation.
	// Settable at create time and via PUT .../installation (a dedicated
	// endpoint, not the generic AssignmentPatch below: COALESCE-based PATCH
	// can't distinguish "omitted" from "explicitly clear back to default").
	InstallationID       *string    `json:"installation_id,omitempty"`
	Visibility           string     `json:"visibility"`
	RequiredApprovals    int        `json:"required_approvals"`
	ProtectDefaultBranch bool       `json:"protect_default_branch"`
	DefaultBranch        string     `json:"default_branch"`
	StartsAt             *time.Time `json:"starts_at,omitempty"`
	DueAt                *time.Time `json:"due_at,omitempty"`
	Status               string     `json:"status"`
	CreatedBy            string     `json:"created_by"`
	CreatedAt            time.Time  `json:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at"`
}

// AssignmentPatch is PATCH /api/projects/assignments/{id}'s editable field
// set — a nil field leaves the current value untouched.
type AssignmentPatch struct {
	Title                *string    `json:"title"`
	Description          *string    `json:"description"`
	Visibility           *string    `json:"visibility"`
	RequiredApprovals    *int       `json:"required_approvals"`
	ProtectDefaultBranch *bool      `json:"protect_default_branch"`
	DefaultBranch        *string    `json:"default_branch"`
	StartsAt             *time.Time `json:"starts_at"`
	DueAt                *time.Time `json:"due_at"`
}

// ProjectTeam is one student team's fork of an assignment's template project.
type ProjectTeam struct {
	ID                string     `json:"id"`
	OrgID             string     `json:"org_id"`
	AssignmentID      string     `json:"assignment_id"`
	Name              string     `json:"name"`
	Slug              string     `json:"slug"`
	GitlabProjectID   *int64     `json:"gitlab_project_id,omitempty"`
	GitlabProjectPath *string    `json:"gitlab_project_path,omitempty"`
	GitlabWebURL      *string    `json:"gitlab_web_url,omitempty"`
	GitlabHookID      *int64     `json:"gitlab_hook_id,omitempty"`
	PagesURL          *string    `json:"pages_url,omitempty"`
	ProvisionStatus   string     `json:"provision_status"`
	ProvisionError    *string    `json:"provision_error,omitempty"`
	ProvisionedAt     *time.Time `json:"provisioned_at,omitempty"`
	CreatedBy         *string    `json:"created_by,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

// TeamPatch is PATCH /api/projects/teams/{id}'s editable field set.
type TeamPatch struct {
	Name *string `json:"name"`
	Slug *string `json:"slug"`
}

// ProjectTeamMember is one student's membership on a team. AssignmentID is
// denormalized on purpose — it's what lets the composite FK
// (team_id, assignment_id) -> project_teams(id, assignment_id) enforce "one
// team per student per assignment" as a real DB constraint (see the
// UNIQUE(assignment_id, user_id) constraint alongside it).
type ProjectTeamMember struct {
	TeamID            string     `json:"team_id"`
	UserID            string     `json:"user_id"`
	AssignmentID      string     `json:"assignment_id"`
	Role              string     `json:"role"`
	GitlabAccessLevel int        `json:"gitlab_access_level"`
	SyncStatus        string     `json:"sync_status"`
	SyncError         *string    `json:"sync_error,omitempty"`
	SyncedAt          *time.Time `json:"synced_at,omitempty"`
	AddedBy           *string    `json:"added_by,omitempty"`
	AddedAt           time.Time  `json:"added_at"`
	// Name/Email are populated only by Repo.ListTeamMembers' joined query —
	// zero-valued on rows returned by AddTeamMember/scanMember alone.
	Name  string `json:"name,omitempty"`
	Email string `json:"email,omitempty"`
}

// ─── Batch 3: activity mirror (webhook-fed) ────────────────────────────────

// Merge request states mirrored verbatim from GitLab.
const (
	MRStateOpened = "opened"
	MRStateMerged = "merged"
	MRStateClosed = "closed"
	MRStateLocked = "locked"
)

// Issue states mirrored verbatim from GitLab.
const (
	IssueStateOpened = "opened"
	IssueStateClosed = "closed"
)

// MR review kinds. ReviewKindApproval is set by isApprovalNote's phrase match
// (service_webhook.go) — kind-herding-cookie.md §0 decision #4's MindForge-
// side approval tracking, which works identically on Free/CE and
// Premium/Ultimate since it never depends on GitLab's own approval_rules API.
const (
	ReviewKindComment       = "comment"
	ReviewKindApproval      = "approval"
	ReviewKindChangeRequest = "change_request"
)

// gitlab_webhook_events.status values.
const (
	WebhookEventReceived   = "received"
	WebhookEventDispatched = "dispatched"
	WebhookEventIgnored    = "ignored"
	WebhookEventFailed     = "failed"
)

// GitlabCommit mirrors one gitlab_commits row — a single commit pushed to a
// team's repo, keyed UNIQUE(team_id, sha) so redelivered push events upsert
// rather than duplicate.
type GitlabCommit struct {
	ID                 string
	OrgID              string
	TeamID             string
	SHA                string
	Branch             *string
	AuthorGitlabUserID *int64
	UserID             *string
	AuthorEmail        *string
	AuthorName         *string
	Message            *string
	Additions          *int
	Deletions          *int
	FilesChanged       *int
	IsMerge            bool
	CommittedAt        *time.Time
	RecordedAt         time.Time
}

// GitlabMergeRequest mirrors one gitlab_merge_requests row, keyed
// UNIQUE(team_id, mr_iid).
type GitlabMergeRequest struct {
	ID                 string
	OrgID              string
	TeamID             string
	MRIID              int64
	MRID               *int64
	Title              string
	Description        *string
	State              string
	SourceBranch       *string
	TargetBranch       *string
	AuthorGitlabUserID *int64
	AuthorUserID       *string
	WebURL             *string
	ApprovalsCount     int
	ChangesCount       *int
	OpenedAt           *time.Time
	MergedAt           *time.Time
	ClosedAt           *time.Time
	UpdatedAt          time.Time
}

// GitlabMRReview mirrors one gitlab_mr_reviews row — a single note on an MR,
// keyed UNIQUE(merge_request_id, note_id) so a redelivered Note Hook upserts
// rather than duplicates.
type GitlabMRReview struct {
	ID                   string
	MergeRequestID       string
	ReviewerGitlabUserID *int64
	ReviewerUserID       *string
	Kind                 string
	NoteID               int64
	Body                 *string
	FilePath             *string
	CreatedAt            time.Time
}

// GitlabPipeline mirrors one gitlab_pipelines row, keyed
// UNIQUE(team_id, pipeline_id).
type GitlabPipeline struct {
	ID              string
	OrgID           string
	TeamID          string
	PipelineID      int64
	SHA             *string
	Ref             *string
	Status          string
	WebURL          *string
	DurationSeconds *int
	StartedAt       *time.Time
	FinishedAt      *time.Time
	UpdatedAt       time.Time
}

// GitlabIssue mirrors one gitlab_issues row, keyed UNIQUE(team_id, issue_iid).
// CheckpointID is resolved from the issue's milestone_id via
// Repo.FindCheckpointByMilestone (service_webhook.go's ingestIssueEvent) — it
// stays nil for any issue whose milestone doesn't match a checkpoint's own
// gitlab_milestone_id, which is the normal, expected state for a checkpoint
// that has no GitLab milestone yet (e.g. it was never provisioned because
// the assignment wasn't provisioned at checkpoint-creation time).
type GitlabIssue struct {
	ID                   string
	OrgID                string
	TeamID               string
	IssueIID             int64
	IssueID              *int64
	Title                string
	State                string
	MilestoneID          *int64
	CheckpointID         *string
	AssigneeGitlabUserID *int64
	AssigneeUserID       *string
	Weight               *int
	Labels               []string
	GLCreatedAt          *time.Time
	GLClosedAt           *time.Time
	UpdatedAt            time.Time
}

// GitlabWebhookEvent mirrors one gitlab_webhook_events row — the raw,
// redelivery-safe record of an inbound webhook delivery, keyed
// UNIQUE(org_id, event_uuid).
type GitlabWebhookEvent struct {
	ID          string
	OrgID       string
	ProjectID   *int64
	EventType   string
	EventUUID   string
	Payload     []byte
	Status      string
	Error       *string
	ReceivedAt  time.Time
	ProcessedAt *time.Time
}

// ─── Batch 3 add-on: read-only team activity feed ──────────────────────────
//
// GET /api/projects/teams/{teamID}/activity exposes the activity mirror
// above as a small team-detail read view — recent commits, recent merge
// requests, and the latest pipeline, each a plain ORDER BY ... LIMIT read.
// No aggregation, scoring, or cross-team leaderboard logic lives here; that's
// Batch 4's contribution-tracking/dashboards scope (kind-herding-cookie.md
// §7). These view types are deliberately narrower than GitlabCommit/
// GitlabMergeRequest/GitlabPipeline above — only the fields the feed
// actually renders, with json tags those internal mirror structs don't carry.

// TeamActivityCommit is one row of the activity feed's recent-commits list.
type TeamActivityCommit struct {
	SHA         string     `json:"sha"`
	Message     *string    `json:"message"`
	AuthorName  *string    `json:"author_name"`
	CommittedAt *time.Time `json:"committed_at"`
}

// TeamActivityMergeRequest is one row of the activity feed's merge-requests list.
type TeamActivityMergeRequest struct {
	Title          string  `json:"title"`
	State          string  `json:"state"`
	WebURL         *string `json:"web_url"`
	ApprovalsCount int     `json:"approvals_count"`
}

// TeamActivityPipeline is the activity feed's latest-pipeline summary.
type TeamActivityPipeline struct {
	Status string  `json:"status"`
	WebURL *string `json:"web_url"`
}

// TeamActivityView is GET /api/projects/teams/{teamID}/activity's response body.
type TeamActivityView struct {
	Commits       []TeamActivityCommit       `json:"commits"`
	MergeRequests []TeamActivityMergeRequest `json:"merge_requests"`
	Pipeline      *TeamActivityPipeline      `json:"pipeline"`
}

// ─── Batch 4: contribution tracking & dashboards ───────────────────────────
//
// No new tables here — kind-herding-cookie.md §0.6 explicitly defers a
// per-user contribution rollup table ("gitlab_commits + GROUP BY answers
// every dashboard query today; add a rollup when that query measurably slows
// down"). Every view below is a direct aggregation read over the Batch 3
// activity-mirror tables (repo_dashboard.go).

// ContributionRow is one student's aggregated commit activity on a single
// team. IsFreeRider is the deliberately simple MVP signal §7 calls for:
// zero commits on the team, not a weighted score against the team average —
// that's a ponytail deferral of its own, not something to over-build here.
type ContributionRow struct {
	UserID       string     `json:"user_id"`
	Name         string     `json:"name"`
	Email        string     `json:"email"`
	CommitCount  int        `json:"commit_count"`
	Additions    int        `json:"additions"`
	Deletions    int        `json:"deletions"`
	LastCommitAt *time.Time `json:"last_commit_at,omitempty"`
	IsFreeRider  bool       `json:"is_free_rider"`
}

// TeamContributionsView is GET /api/projects/teams/{teamID}/contributions
// (staff+mentor) and GET /api/my/projects/{teamID}/contributions
// (row-scoped student) response body.
type TeamContributionsView struct {
	TeamID        string            `json:"team_id"`
	Contributions []ContributionRow `json:"contributions"`
}

// LeaderboardRow is one student's ranked commit totals across every team
// under an assignment — GET .../leaderboard.
type LeaderboardRow struct {
	Rank        int    `json:"rank"`
	UserID      string `json:"user_id"`
	Name        string `json:"name"`
	Email       string `json:"email"`
	TeamID      string `json:"team_id"`
	TeamName    string `json:"team_name"`
	CommitCount int    `json:"commit_count"`
	Additions   int    `json:"additions"`
	Deletions   int    `json:"deletions"`
}

// AssignmentLeaderboardView is GET /api/projects/assignments/{assignmentID}/leaderboard's response body.
type AssignmentLeaderboardView struct {
	AssignmentID string           `json:"assignment_id"`
	Leaderboard  []LeaderboardRow `json:"leaderboard"`
}

// BurndownCheckpoint is one checkpoint's issue open/close tally for the
// assignment-wide burndown chart. This is correctly empty until Batch 5
// wires up checkpoint CRUD and milestone->checkpoint issue mapping — the
// join against gitlab_issues.checkpoint_id is right today, there is simply
// nothing in project_checkpoints yet for it to match (see migration 023
// §1.4's idx_gitlab_issues_burndown, built for exactly this query).
type BurndownCheckpoint struct {
	CheckpointID string     `json:"checkpoint_id"`
	Title        string     `json:"title"`
	Position     int        `json:"position"`
	DueAt        *time.Time `json:"due_at,omitempty"`
	TotalIssues  int        `json:"total_issues"`
	OpenIssues   int        `json:"open_issues"`
	ClosedIssues int        `json:"closed_issues"`
}

// AssignmentBurndownView is GET /api/projects/assignments/{assignmentID}/burndown's response body.
type AssignmentBurndownView struct {
	AssignmentID string               `json:"assignment_id"`
	Checkpoints  []BurndownCheckpoint `json:"checkpoints"`
}

// TeamDashboardSummary is one team's rolled-up commit/MR/pipeline/free-rider
// summary for the assignment-wide instructor dashboard — the
// assignment-wide, aggregated counterpart to Batch 3's per-team
// TeamActivityView (which stays unaggregated recent-activity, on purpose).
type TeamDashboardSummary struct {
	TeamID               string  `json:"team_id"`
	TeamName             string  `json:"team_name"`
	MemberCount          int     `json:"member_count"`
	CommitCount          int     `json:"commit_count"`
	OpenMRCount          int     `json:"open_mr_count"`
	MergedMRCount        int     `json:"merged_mr_count"`
	LatestPipelineStatus *string `json:"latest_pipeline_status,omitempty"`
	FreeRiderCount       int     `json:"free_rider_count"`
}

// AssignmentDashboardView is GET /api/projects/assignments/{assignmentID}/dashboard's response body.
type AssignmentDashboardView struct {
	AssignmentID string                 `json:"assignment_id"`
	Teams        []TeamDashboardSummary `json:"teams"`
}

// MyProjectSummary is one row of GET /api/my/projects — the authenticated
// student's own team memberships only, joined through project_team_members
// on their own user_id (never a client-supplied filter).
type MyProjectSummary struct {
	TeamID          string  `json:"team_id"`
	TeamName        string  `json:"team_name"`
	AssignmentID    string  `json:"assignment_id"`
	AssignmentTitle string  `json:"assignment_title"`
	Role            string  `json:"role"`
	ProvisionStatus string  `json:"provision_status"`
	GitlabWebURL    *string `json:"gitlab_web_url,omitempty"`
	PagesURL        *string `json:"pages_url,omitempty"`
}

// ─── Batch 5: checkpoints & peer review ────────────────────────────────────

// project_team_checkpoints.status values — the submission lifecycle for one
// team against one checkpoint.
const (
	CheckpointStatusOpen      = "open"
	CheckpointStatusSubmitted = "submitted"
	CheckpointStatusApproved  = "approved"
	CheckpointStatusMerged    = "merged"
	CheckpointStatusGraded    = "graded"
)

// project_team_checkpoints.ci_status values — mirrored verbatim from
// gitlab_pipelines.status (see service_checkpoint.go's mirrorPipelineToCheckpoint),
// which is itself GitLab's own pipeline status vocabulary, so no translation
// table is needed between the two.
const (
	CIStatusNone     = "none"
	CIStatusPending  = "pending"
	CIStatusRunning  = "running"
	CIStatusSuccess  = "success"
	CIStatusFailed   = "failed"
	CIStatusCanceled = "canceled"
)

// ProjectCheckpoint is one instructor-defined milestone within an assignment
// (e.g. "Checkpoint 1: API skeleton"), ordered by Position — each team
// submits against it via a merge request (see ProjectTeamCheckpoint).
// RequiredApprovals for the merge gate lives on the parent ProjectAssignment,
// not here — migration 023 gives project_checkpoints no such column of its
// own (confirmed directly against the migration rather than assumed).
type ProjectCheckpoint struct {
	ID                string     `json:"id"`
	OrgID             string     `json:"org_id"`
	AssignmentID      string     `json:"assignment_id"`
	Title             string     `json:"title"`
	Description       *string    `json:"description,omitempty"`
	Position          int        `json:"position"`
	DueAt             *time.Time `json:"due_at,omitempty"`
	Weight            int        `json:"weight"`
	RequiresMR        bool       `json:"requires_mr"`
	RequiresCIPass    bool       `json:"requires_ci_pass"`
	GitlabMilestoneID *int64     `json:"gitlab_milestone_id,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

// CheckpointPatch is PATCH .../checkpoints/{checkpointID}'s editable field set.
type CheckpointPatch struct {
	Title          *string    `json:"title"`
	Description    *string    `json:"description"`
	DueAt          *time.Time `json:"due_at"`
	Weight         *int       `json:"weight"`
	RequiresMR     *bool      `json:"requires_mr"`
	RequiresCIPass *bool      `json:"requires_ci_pass"`
}

// ProjectTeamCheckpoint is one team's submission state against one
// checkpoint — MR-as-submission, CI result, approval count, lateness, and
// grade all live on this one row (migration 023's own consolidation).
type ProjectTeamCheckpoint struct {
	ID              string     `json:"id"`
	OrgID           string     `json:"org_id"`
	TeamID          string     `json:"team_id"`
	CheckpointID    string     `json:"checkpoint_id"`
	MRIID           *int64     `json:"mr_iid,omitempty"`
	MRID            *int64     `json:"mr_id,omitempty"`
	MRWebURL        *string    `json:"mr_web_url,omitempty"`
	MRState         *string    `json:"mr_state,omitempty"`
	ApprovalsCount  int        `json:"approvals_count"`
	CIStatus        string     `json:"ci_status"`
	CIPipelineID    *int64     `json:"ci_pipeline_id,omitempty"`
	SnapshotSHA     *string    `json:"snapshot_sha,omitempty"`
	SnapshotAt      *time.Time `json:"snapshot_at,omitempty"`
	IsLate          bool       `json:"is_late"`
	LateCommitCount int        `json:"late_commit_count"`
	Score           *float64   `json:"score,omitempty"`
	Feedback        *string    `json:"feedback,omitempty"`
	GradedBy        *string    `json:"graded_by,omitempty"`
	GradedAt        *time.Time `json:"graded_at,omitempty"`
	Status          string     `json:"status"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

// GradePatch is PATCH .../submissions/{teamID}/grade's request body.
type GradePatch struct {
	Score    float64 `json:"score"`
	Feedback *string `json:"feedback"`
}

// ─── Batch 5 (gap fix): student-facing "my checkpoints" ────────────────────
//
// Every checkpoint/submission route above is staff-only (RequireOrgRole).
// This closes the resulting product gap: a student has no way to see their
// own team's checkpoint list plus submission status/grade/feedback. Mirrors
// TeamContributionsView's row-scoping shape (GetMyProject's membership check
// gates the read, same as GetMyProjectContributions) rather than inventing a
// new pattern.

// MyCheckpointRow is one checkpoint under the caller's team's assignment,
// LEFT JOINed against that team's own project_team_checkpoints row — the
// submission fields are nil when the team hasn't submitted against this
// checkpoint yet (no row exists for that team+checkpoint pair), never a
// zero-value that could be mistaken for a real 0 approvals/score.
type MyCheckpointRow struct {
	CheckpointID   string     `json:"checkpoint_id"`
	Title          string     `json:"title"`
	Description    *string    `json:"description,omitempty"`
	Position       int        `json:"position"`
	DueAt          *time.Time `json:"due_at,omitempty"`
	Weight         int        `json:"weight"`
	RequiresMR     bool       `json:"requires_mr"`
	RequiresCIPass bool       `json:"requires_ci_pass"`
	MRWebURL       *string    `json:"mr_web_url,omitempty"`
	MRState        *string    `json:"mr_state,omitempty"`
	ApprovalsCount *int       `json:"approvals_count,omitempty"`
	CIStatus       *string    `json:"ci_status,omitempty"`
	Score          *float64   `json:"score,omitempty"`
	Feedback       *string    `json:"feedback,omitempty"`
	Status         *string    `json:"status,omitempty"`
}

// MyProjectCheckpointsView is GET /api/my/projects/{teamID}/checkpoints's
// response body.
type MyProjectCheckpointsView struct {
	TeamID      string            `json:"team_id"`
	Checkpoints []MyCheckpointRow `json:"checkpoints"`
}

// ─── Batch 6: originality + handoff ────────────────────────────────────────

// Originality report statuses.
const (
	OriginalityStatusPending  = "pending"
	OriginalityStatusRunning  = "running"
	OriginalityStatusComplete = "complete"
	OriginalityStatusFailed   = "failed"
)

// Handoff modes — selectable per action (kind-herding-cookie.md §0.5), no
// hardcoded default beyond what the caller/UI picks.
const (
	HandoffModeFork     = "fork"
	HandoffModeTransfer = "transfer"
)

// Handoff statuses.
const (
	HandoffStatusPending  = "pending"
	HandoffStatusRunning  = "running"
	HandoffStatusComplete = "complete"
	HandoffStatusFailed   = "failed"
)

// ProjectOriginalityReport is one instructor-requested scan run over an
// assignment's teams (+ its template project) — see service_originality.go's
// RunOriginalityScan for the shingling/Jaccard comparison it drives.
type ProjectOriginalityReport struct {
	ID           string     `json:"id"`
	OrgID        string     `json:"org_id"`
	AssignmentID string     `json:"assignment_id"`
	Status       string     `json:"status"`
	TeamsScanned int        `json:"teams_scanned"`
	FilesScanned int        `json:"files_scanned"`
	Error        *string    `json:"error,omitempty"`
	RequestedBy  *string    `json:"requested_by,omitempty"`
	RequestedAt  time.Time  `json:"requested_at"`
	CompletedAt  *time.Time `json:"completed_at,omitempty"`
}

// ProjectOriginalityMatch is one file-pair whose Jaccard similarity crossed
// originalityMatchThreshold. TeamBID nil means the match is against the
// assignment's template project, not another team (migration 023's own
// nullable-means-template convention).
type ProjectOriginalityMatch struct {
	ID           string  `json:"id"`
	ReportID     string  `json:"report_id"`
	TeamAID      string  `json:"team_a_id"`
	TeamBID      *string `json:"team_b_id,omitempty"`
	FilePathA    string  `json:"file_path_a"`
	FilePathB    string  `json:"file_path_b"`
	Similarity   float64 `json:"similarity"`
	MatchedLines *int    `json:"matched_lines,omitempty"`
	Sample       *string `json:"sample,omitempty"`
}

// OriginalityReportView is one row of GET .../originality's response — a
// report plus its own matches, so the instructor UI doesn't need a second
// round-trip per report (reports are few and matches are threshold-bounded,
// so this stays small).
type OriginalityReportView struct {
	ProjectOriginalityReport
	Matches []ProjectOriginalityMatch `json:"matches"`
}

// ProjectHandoff is one capstone repo handoff — fork (a new project in the
// target namespace, forked from the team's current project, keeping
// history) or transfer (the team's existing project itself relocates into
// the target namespace) — selectable per action per kind-herding-cookie.md
// §0.5.
type ProjectHandoff struct {
	ID                  string     `json:"id"`
	OrgID               string     `json:"org_id"`
	TeamID              string     `json:"team_id"`
	UserID              string     `json:"user_id"`
	Mode                string     `json:"mode"`
	TargetNamespaceID   *int64     `json:"target_namespace_id,omitempty"`
	TargetNamespacePath *string    `json:"target_namespace_path,omitempty"`
	NewProjectID        *int64     `json:"new_project_id,omitempty"`
	NewWebURL           *string    `json:"new_web_url,omitempty"`
	Status              string     `json:"status"`
	Error               *string    `json:"error,omitempty"`
	RequestedAt         time.Time  `json:"requested_at"`
	CompletedAt         *time.Time `json:"completed_at,omitempty"`
}

// HandoffRequest is POST /api/projects/teams/{teamID}/handoff's request body.
type HandoffRequest struct {
	UserID              string `json:"user_id"`
	Mode                string `json:"mode"`
	TargetNamespaceID   int64  `json:"target_namespace_id"`
	TargetNamespacePath string `json:"target_namespace_path"`
}
