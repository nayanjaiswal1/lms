package projectmarket

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/profile"
)

// Service is the project marketplace domain's business logic layer.
type Service struct {
	repo         *Repo
	pool         *pgxpool.Pool
	profileRepo  *profile.Repo
	aiProvider   ai.LLMProvider
	jobsRegistry *jobs.Registry
	// gitlabSvc backs CreateTeamFromSelection's handoff into the existing
	// assignment/team provisioning flow (service_team.go) — projectmarket
	// never writes gitlab_* tables directly, it only calls the same
	// CreateTeam/AddTeamMember methods a staff member's own click would.
	gitlabSvc *gitlab.Service
}

// NewService builds the projectmarket Service. profileRepo backs the AI
// scoring job's GitHub-signal lookup (Service.SocialLinks — no separate
// OAuth connection needed, the student's self-reported profile link is
// enough for a public, unauthenticated GitHub API read). gitlabSvc is nil-
// safe to omit only in tests; CreateTeamFromSelection is the one call site
// that needs it.
func NewService(pool *pgxpool.Pool, profileRepo *profile.Repo, aiProvider ai.LLMProvider, jobsRegistry *jobs.Registry, gitlabSvc *gitlab.Service) *Service {
	return &Service{repo: NewRepo(pool), pool: pool, profileRepo: profileRepo, aiProvider: aiProvider, jobsRegistry: jobsRegistry, gitlabSvc: gitlabSvc}
}

// ─── requirements ───────────────────────────────────────────────────────────

// CreateRequirement inserts a new draft requirement. Publishing to the open
// board is a separate, explicit staff action (see PublishRequirement).
func (s *Service) CreateRequirement(ctx context.Context, orgID, userID string, req ProjectRequirement) (*ProjectRequirement, error) {
	req.OrgID = orgID
	req.CreatedBy = userID
	req.Status = RequirementStatusDraft
	return s.repo.CreateRequirement(ctx, req)
}

// GetRequirement returns a single org-scoped requirement.
func (s *Service) GetRequirement(ctx context.Context, orgID, id string) (*ProjectRequirement, error) {
	return s.repo.GetRequirement(ctx, orgID, id)
}

// ListRequirements returns every requirement in the org — the staff
// management list.
func (s *Service) ListRequirements(ctx context.Context, orgID string) ([]ProjectRequirement, error) {
	return s.repo.ListRequirements(ctx, orgID)
}

// ListBoard returns the open board: every open, not-yet-expired requirement,
// with the caller's own application status attached where it exists.
func (s *Service) ListBoard(ctx context.Context, orgID, userID string) ([]RequirementBoardRow, error) {
	return s.repo.ListBoard(ctx, orgID, userID)
}

// UpdateRequirement applies a partial patch to a requirement's editable fields.
func (s *Service) UpdateRequirement(ctx context.Context, orgID, id string, p RequirementPatch) (*ProjectRequirement, error) {
	return s.repo.UpdateRequirement(ctx, orgID, id, p)
}

// PublishRequirement transitions a draft requirement to open, making it
// visible on the board and eligible for applications.
func (s *Service) PublishRequirement(ctx context.Context, orgID, id string) (*ProjectRequirement, error) {
	return s.repo.SetRequirementStatus(ctx, orgID, id, RequirementStatusDraft, RequirementStatusOpen)
}

// CloseRequirement transitions an open requirement to closed — stops new
// applications; existing applications remain reviewable.
func (s *Service) CloseRequirement(ctx context.Context, orgID, id string) (*ProjectRequirement, error) {
	return s.repo.SetRequirementStatus(ctx, orgID, id, RequirementStatusOpen, RequirementStatusClosed)
}

// ─── applications ───────────────────────────────────────────────────────────

// Apply submits a student's application against an open, not-yet-expired
// requirement. Returns ErrRequirementClosed if the requirement isn't open or
// its deadline has passed, ErrAlreadyApplied on a duplicate.
func (s *Service) Apply(ctx context.Context, orgID, userID, requirementID, motivation, resumeText string) (*ProjectApplication, error) {
	req, err := s.repo.GetRequirement(ctx, orgID, requirementID)
	if err != nil {
		return nil, err
	}
	if req.Status != RequirementStatusOpen || !req.ApplicationDeadline.After(time.Now()) {
		return nil, ErrRequirementClosed
	}

	app := ProjectApplication{
		OrgID:         orgID,
		RequirementID: requirementID,
		UserID:        userID,
		Status:        ApplicationStatusSubmitted,
	}
	if motivation != "" {
		app.Motivation = &motivation
	}
	if resumeText != "" {
		app.ResumeText = &resumeText
	}
	return s.repo.CreateApplication(ctx, app)
}

// ListApplicationsForStaff returns every application against a requirement,
// with applicant name/email attached, for the staff review screen.
func (s *Service) ListApplicationsForStaff(ctx context.Context, orgID, requirementID string) ([]ProjectApplication, error) {
	return s.repo.ListApplicationsForStaff(ctx, orgID, requirementID)
}

// ListMyApplications returns the authenticated student's own applications.
func (s *Service) ListMyApplications(ctx context.Context, orgID, userID string) ([]ProjectApplication, error) {
	return s.repo.ListMyApplications(ctx, orgID, userID)
}

// validApplicationStatuses is the set ReviewApplication accepts — a staff
// reviewer moves an application forward or rejects it; nothing here writes
// "submitted" back (that's only ever the insert-time default).
var validApplicationStatuses = map[string]bool{
	ApplicationStatusShortlisted: true,
	ApplicationStatusSelected:    true,
	ApplicationStatusRejected:    true,
}

// ReviewApplication records a staff decision on one application.
func (s *Service) ReviewApplication(ctx context.Context, orgID, id, status, reviewedBy string) (*ProjectApplication, error) {
	if !validApplicationStatuses[status] {
		return nil, fmt.Errorf("%w: status must be shortlisted, selected, or rejected", ErrConflict)
	}
	return s.repo.SetApplicationStatus(ctx, orgID, id, status, reviewedBy)
}

// WithdrawApplication lets a student withdraw their own application.
func (s *Service) WithdrawApplication(ctx context.Context, orgID, id, userID string) error {
	return s.repo.WithdrawApplication(ctx, orgID, id, userID)
}

// ─── team creation from selection ──────────────────────────────────────────

// ErrNoSelectedApplications — CreateTeamFromSelection has nothing to add: no
// application against this requirement is currently "selected". Deliberately
// its own sentinel rather than wrapping ErrConflict — WriteDomainError
// matches every spec key via errors.Is over an unordered map, so a wrapped
// error could just as easily surface ErrConflict's generic message instead
// of this one.
var ErrNoSelectedApplications = errors.New("projectmarket: no applications are marked selected yet")

// CreateTeamFromSelection creates a new team under an existing assignment
// and adds every "selected" applicant to it as a member — the one-click
// version of what staff would otherwise do by hand (create the team, then
// add each selected student one at a time). It does not create the
// assignment itself: that still goes through the normal "New assignment"
// flow, since it carries real GitLab provisioning choices (template repo,
// visibility, branch protection) this package has no reason to decide.
// Members that fail to add (e.g. already on another team for this
// assignment) are skipped, not fatal — the caller gets back which user IDs
// actually got added.
func (s *Service) CreateTeamFromSelection(ctx context.Context, orgID, userID, requirementID string, req TeamFromSelectionRequest) (*gitlab.ProjectTeam, []string, error) {
	selected, err := s.repo.ListSelectedApplications(ctx, orgID, requirementID)
	if err != nil {
		return nil, nil, err
	}
	if len(selected) == 0 {
		return nil, nil, ErrNoSelectedApplications
	}

	team, err := s.gitlabSvc.CreateTeam(ctx, orgID, userID, req.AssignmentID, req.TeamName, req.TeamSlug)
	if err != nil {
		return nil, nil, fmt.Errorf("projectmarket: create team from selection: %w", err)
	}

	added := make([]string, 0, len(selected))
	for _, app := range selected {
		if _, err := s.gitlabSvc.AddTeamMember(ctx, orgID, team.ID, app.UserID, gitlab.MemberRoleMember, gitlab.AccessLevelDeveloper, userID); err != nil {
			continue
		}
		added = append(added, app.UserID)
	}
	return team, added, nil
}
