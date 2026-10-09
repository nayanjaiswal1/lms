package workspace

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/mindforge/backend/internal/gitlab"
)

// teamIDOf resolves the workspace's linked GitLab team: ErrInvalidState (409)
// when GitLab is not configured or the project has no provisioned team.
func (s *Service) teamIDOf(ctx context.Context, pc *ProjectCtx) (string, error) {
	if s.gitlab == nil {
		return "", fmt.Errorf("%w: gitlab integration is not configured for this deployment", ErrInvalidState)
	}
	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return "", err
	}
	if project.TeamID == nil {
		return "", fmt.Errorf("%w: this workspace has no GitLab project yet", ErrInvalidState)
	}
	return *project.TeamID, nil
}

// mapGitlabErr translates gitlab sentinels into this package's so
// writeDomainError renders 404/409 instead of a 500.
func mapGitlabErr(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, gitlab.ErrNotFound):
		return fmt.Errorf("%w: %v", ErrNotFound, err)
	case errors.Is(err, gitlab.ErrConflict):
		return fmt.Errorf("%w: %v", ErrConflict, err)
	}
	return err
}

// withTeam resolves the team then runs fn, mapping gitlab errors.
func withTeam[T any](ctx context.Context, s *Service, pc *ProjectCtx, fn func(teamID string) (T, error)) (T, error) {
	var zero T
	teamID, err := s.teamIDOf(ctx, pc)
	if err != nil {
		return zero, err
	}
	v, err := fn(teamID)
	return v, mapGitlabErr(err)
}

func (s *Service) TeamGitActivity(ctx context.Context, pc *ProjectCtx) (*gitlab.TeamActivityView, error) {
	return withTeam(ctx, s, pc, func(t string) (*gitlab.TeamActivityView, error) {
		return s.gitlab.GetTeamActivity(ctx, pc.OrgID, t)
	})
}

func (s *Service) TeamGitContributions(ctx context.Context, pc *ProjectCtx) (*gitlab.TeamContributionsView, error) {
	return withTeam(ctx, s, pc, func(t string) (*gitlab.TeamContributionsView, error) {
		return s.gitlab.GetTeamContributions(ctx, pc.OrgID, t)
	})
}

func (s *Service) TeamGitOwnership(ctx context.Context, pc *ProjectCtx) (*gitlab.TeamOwnershipView, error) {
	return withTeam(ctx, s, pc, func(t string) (*gitlab.TeamOwnershipView, error) {
		return s.gitlab.GetTeamOwnership(ctx, pc.OrgID, t)
	})
}

func (s *Service) TeamCheckpoints(ctx context.Context, pc *ProjectCtx) (*gitlab.MyProjectCheckpointsView, error) {
	return withTeam(ctx, s, pc, func(t string) (*gitlab.MyProjectCheckpointsView, error) {
		return s.gitlab.GetTeamCheckpoints(ctx, pc.OrgID, t)
	})
}

func (s *Service) SubmitDesignProposal(ctx context.Context, pc *ProjectCtx, checkpointID, title string, description, link *string) (*gitlab.ProjectDesignProposal, error) {
	return withTeam(ctx, s, pc, func(t string) (*gitlab.ProjectDesignProposal, error) {
		return s.gitlab.SubmitDesignProposal(ctx, pc.OrgID, pc.UserID, checkpointID, t, title, description, link)
	})
}

func (s *Service) ListDesignProposals(ctx context.Context, pc *ProjectCtx, checkpointID string) ([]gitlab.DesignProposalView, error) {
	return withTeam(ctx, s, pc, func(t string) ([]gitlab.DesignProposalView, error) {
		return s.gitlab.ListDesignProposals(ctx, pc.OrgID, pc.UserID, checkpointID, t)
	})
}

// ProposalAction runs a vote/unvote/delete on a proposal; the gitlab calls
// membership-check the caller against the proposal's own team.
func (s *Service) ProposalAction(ctx context.Context, pc *ProjectCtx, proposalID string, fn func(g *gitlab.Service, orgID, userID string) error) error {
	teamID, err := s.teamIDOf(ctx, pc)
	if err != nil {
		return err
	}
	if err := s.requireProposalInTeam(ctx, pc.OrgID, proposalID, teamID); err != nil {
		return err
	}
	return mapGitlabErr(fn(s.gitlab, pc.OrgID, pc.UserID))
}

// requireProposalInTeam 404s unless the proposal belongs to teamID.
func (s *Service) requireProposalInTeam(ctx context.Context, orgID, proposalID, teamID string) error {
	owner, err := s.gitlab.ProposalTeamID(ctx, orgID, proposalID)
	if err != nil {
		return mapGitlabErr(err)
	}
	if owner != teamID {
		return ErrNotFound
	}
	return nil
}

// validateOwnerHandoff checks the owner-route request before any side effect.
// The owner may only hand the repo to themselves and only by fork: transfer
// relocates the team's shared project, which stays staff-only (as before
// workspaces existed, when only staff could request a handoff).
func validateOwnerHandoff(userID, mode string, namespaceID int64) error {
	fields := gitlab.ValidateHandoffRequest(gitlab.HandoffRequest{UserID: userID, Mode: mode, TargetNamespaceID: namespaceID})
	if len(fields) == 0 && mode != gitlab.HandoffModeFork {
		fields["mode"] = "Workspace owners can hand off by 'fork' only; ask staff for a transfer."
	}
	if len(fields) > 0 {
		return &FieldError{Fields: fields}
	}
	return nil
}

// HandoffGitlab forks the workspace's repo into the calling owner's own GitLab
// namespace. Everything is validated first (shape, rate limit, team
// membership, namespace visibility via the caller's own GitLab connection â€”
// all inside RequestHandoff); the source repo is unarchived later, inside the
// handoff job, so a rejected request never touches GitLab state.
func (s *Service) HandoffGitlab(ctx context.Context, pc *ProjectCtx, mode string, namespaceID int64, namespacePath string) (*gitlab.ProjectHandoff, error) {
	if err := validateOwnerHandoff(pc.UserID, mode, namespaceID); err != nil {
		return nil, err
	}
	teamID, err := s.teamIDOf(ctx, pc)
	if err != nil {
		return nil, err
	}
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:handoff:"+pc.ProjectID, s.cfg.Workspace.HandoffPerProjectDay, 24*time.Hour); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}
	h, err := s.gitlab.RequestHandoff(ctx, pc.OrgID, teamID, gitlab.HandoffRequest{
		UserID: pc.UserID, Mode: mode, TargetNamespaceID: namespaceID, TargetNamespacePath: namespacePath,
	})
	return h, mapGitlabErr(err)
}
