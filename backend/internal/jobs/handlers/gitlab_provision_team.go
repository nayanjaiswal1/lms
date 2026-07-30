package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// GitlabProvisionTeamHandler implements jobs.Handler for
// HandlerGitlabProvisionTeam jobs — forks a team's GitLab project from its
// assignment's template, protects the default branch, and syncs roster
// membership. Triggered by assignment publish or team creation (see
// gitlab.Service.PublishAssignment/CreateTeam), never by a cron sweep — each
// team is provisioned once, not on a recurring schedule.
type GitlabProvisionTeamHandler struct {
	svc *gitlab.Service
}

// NewGitlabProvisionTeamHandler constructs a GitlabProvisionTeamHandler.
func NewGitlabProvisionTeamHandler(svc *gitlab.Service) *GitlabProvisionTeamHandler {
	return &GitlabProvisionTeamHandler{svc: svc}
}

type gitlabProvisionTeamPayload struct {
	TeamID string `json:"team_id"`
}

// Handle provisions the team named in the job payload.
func (h *GitlabProvisionTeamHandler) Handle(ctx context.Context, job jobs.Job) error {
	var payload gitlabProvisionTeamPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("handlers.gitlab_provision_team: decode payload: %w", err)
	}
	if payload.TeamID == "" {
		return fmt.Errorf("handlers.gitlab_provision_team: missing team_id")
	}
	if err := h.svc.ProvisionTeam(ctx, payload.TeamID); err != nil {
		return fmt.Errorf("handlers.gitlab_provision_team: %w", err)
	}
	return nil
}
