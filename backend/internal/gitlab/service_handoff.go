package gitlab

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
)

// Job handler key for this file's job — see service_provision.go's own
// jobProvisionTeam doc comment for why these are plain string literals
// rather than a shared constants import. MUST stay in sync with
// handlers.HandlerGitlabHandoff in internal/jobs/handlers/constants.go.
const jobHandoff = "gitlab.handoff"

const handoffTimeoutMS = 180000

// RequestHandoff validates the request and creates/resets a project_handoffs
// row, then enqueues gitlab.handoff — one job per (team, user), per
// kind-herding-cookie.md §3's job table. No idempotency key: unlike the
// automatic provisioning triggers, a handoff is always an explicit
// staff/student action — ReprovisionTeam's same reasoning applies (an
// explicit retry should always get a fresh attempt, never silently no-op
// against a stale key).
func (s *Service) RequestHandoff(ctx context.Context, orgID, teamID string, req HandoffRequest) (*ProjectHandoff, error) {
	if req.Mode != HandoffModeFork && req.Mode != HandoffModeTransfer {
		return nil, fmt.Errorf("gitlab: request handoff: %w: mode must be %q or %q", ErrConflict, HandoffModeFork, HandoffModeTransfer)
	}
	team, err := s.repo.GetTeam(ctx, orgID, teamID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: request handoff: %w", err)
	}
	if team.GitlabProjectID == nil {
		return nil, fmt.Errorf("gitlab: request handoff: %w: team has no provisioned GitLab project", ErrConflict)
	}
	if _, err := s.repo.GetTeamMember(ctx, teamID, req.UserID); err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil, fmt.Errorf("gitlab: request handoff: %w: user is not a member of this team", ErrConflict)
		}
		return nil, fmt.Errorf("gitlab: request handoff: %w", err)
	}

	var targetNamespaceID *int64
	if req.TargetNamespaceID != 0 {
		targetNamespaceID = &req.TargetNamespaceID
	}
	var targetNamespacePath *string
	if req.TargetNamespacePath != "" {
		targetNamespacePath = &req.TargetNamespacePath
	}
	handoff, err := s.repo.UpsertHandoff(ctx, ProjectHandoff{
		OrgID: orgID, TeamID: teamID, UserID: req.UserID, Mode: req.Mode,
		TargetNamespaceID: targetNamespaceID, TargetNamespacePath: targetNamespacePath,
	})
	if err != nil {
		return nil, fmt.Errorf("gitlab: request handoff: %w", err)
	}

	timeout := handoffTimeoutMS
	if _, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler: jobHandoff, Priority: jobs.PriorityHigh,
		Payload: map[string]string{"handoff_id": handoff.ID}, OrgID: &orgID, TimeoutMS: &timeout,
	}); err != nil {
		return nil, fmt.Errorf("gitlab: enqueue handoff: %w", err)
	}
	return handoff, nil
}

// RunHandoff is the gitlab.handoff job body: forks or transfers the team's
// project into the requested target namespace per handoff.Mode (§0.5 —
// selectable per action, no hardcoded default beyond whatever the caller
// already chose when requesting it).
func (s *Service) RunHandoff(ctx context.Context, handoffID string) error {
	handoff, err := s.repo.GetHandoffByID(ctx, handoffID)
	if err != nil {
		return fmt.Errorf("gitlab: run handoff: get handoff: %w", err)
	}
	if err := s.repo.SetHandoffStatus(ctx, handoffID, HandoffStatusRunning, nil); err != nil {
		return fmt.Errorf("gitlab: run handoff: mark running: %w", err)
	}

	newProjectID, newWebURL, runErr := s.runHandoffSteps(ctx, handoff)
	if runErr != nil {
		msg := runErr.Error()
		if err := s.repo.SetHandoffStatus(ctx, handoffID, HandoffStatusFailed, &msg); err != nil {
			slog.ErrorContext(ctx, "gitlab: mark handoff failed", "handoff_id", handoffID, "error", err)
		}
		return fmt.Errorf("gitlab: run handoff: %w", runErr)
	}

	if err := s.repo.CompleteHandoff(ctx, handoffID, newProjectID, newWebURL); err != nil {
		return fmt.Errorf("gitlab: run handoff: record completion: %w", err)
	}
	s.notifyUser(ctx, handoff.OrgID, handoff.UserID, notifications.New{
		Type:      "gitlab.handoff_complete",
		Title:     "Your project handoff is complete",
		Body:      strPtr(fmt.Sprintf("Your %s handoff finished — the project is now available at %s.", handoff.Mode, newWebURL)),
		LinkURL:   &newWebURL,
		Priority:  notifications.PriorityNormal,
		DedupeKey: fmt.Sprintf("gitlab.handoff_complete:%s", handoff.ID),
	})
	return nil
}

// runHandoffSteps performs the actual GitLab-side move/fork and returns the
// resulting project's identity for CompleteHandoff to persist.
func (s *Service) runHandoffSteps(ctx context.Context, handoff *ProjectHandoff) (int64, string, error) {
	team, err := s.repo.GetTeamByID(ctx, handoff.TeamID)
	if err != nil {
		return 0, "", fmt.Errorf("get team: %w", err)
	}
	if team.GitlabProjectID == nil {
		return 0, "", fmt.Errorf("team has no provisioned GitLab project")
	}
	if handoff.TargetNamespaceID == nil {
		return 0, "", fmt.Errorf("handoff has no target_namespace_id")
	}
	client, err := s.clientForTeam(ctx, handoff.OrgID, team.AssignmentID)
	if err != nil {
		return 0, "", fmt.Errorf("resolve installation client: %w", err)
	}

	switch handoff.Mode {
	case HandoffModeTransfer:
		// Transfer moves the team's existing project itself into the target
		// namespace — same GitLab project ID, new path_with_namespace/web_url.
		project, err := client.TransferProject(ctx, *team.GitlabProjectID, *handoff.TargetNamespaceID)
		if err != nil {
			return 0, "", fmt.Errorf("transfer project: %w", err)
		}
		// Refresh the team's own path/URL so MindForge's own links keep
		// working post-transfer — same project ID, so SetTeamForkResult's
		// "persist a project's identity" shape fits without a new method.
		if err := s.repo.SetTeamForkResult(ctx, team.ID, project.ID, project.PathWithNamespace, project.WebURL); err != nil {
			slog.WarnContext(ctx, "gitlab: handoff: persist transferred team path failed", "team_id", team.ID, "error", err)
		}
		return project.ID, project.WebURL, nil

	case HandoffModeFork:
		// Fork creates a new, independent project in the target namespace,
		// keeping history via the fork relationship — kind-herding-cookie.md
		// §0.5/§0 decision #3's "the fork path for handoff reuses the
		// existing ForkProject." The team's own project/row is deliberately
		// untouched: the team keeps its MindForge-managed repo exactly as-is.
		path := team.Slug + "-handoff"
		name := team.Name + " (handoff)"
		fork, err := client.ForkProject(ctx, *team.GitlabProjectID, *handoff.TargetNamespaceID, path, name)
		if err != nil {
			return 0, "", fmt.Errorf("fork project: %w", err)
		}
		if err := s.pollImportFinished(ctx, client, fork.ID); err != nil {
			return 0, "", fmt.Errorf("wait for fork import: %w", err)
		}
		return fork.ID, fork.WebURL, nil

	default:
		return 0, "", fmt.Errorf("unknown handoff mode %q", handoff.Mode)
	}
}
