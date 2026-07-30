package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// GitlabSyncMembersHandler implements jobs.Handler for HandlerGitlabSyncMembers
// jobs — reconciles project_team_members against a team's actual GitLab
// project membership. Triggered per-team on roster change (see
// gitlab.Service.AddTeamMember/RemoveTeamMember/RequestSync) and by the
// 30-min cron sweep, which carries no team_id payload and reconciles every
// team with a pending change instead of just one.
type GitlabSyncMembersHandler struct {
	svc *gitlab.Service
}

// NewGitlabSyncMembersHandler constructs a GitlabSyncMembersHandler.
func NewGitlabSyncMembersHandler(svc *gitlab.Service) *GitlabSyncMembersHandler {
	return &GitlabSyncMembersHandler{svc: svc}
}

type gitlabSyncMembersPayload struct {
	TeamID string `json:"team_id"`
}

// Handle syncs one team (job.Payload carries team_id) or sweeps every team
// with a pending roster change (cron trigger — empty payload).
func (h *GitlabSyncMembersHandler) Handle(ctx context.Context, job jobs.Job) error {
	var payload gitlabSyncMembersPayload
	if len(job.Payload) > 0 {
		if err := json.Unmarshal(job.Payload, &payload); err != nil {
			return fmt.Errorf("handlers.gitlab_sync_members: decode payload: %w", err)
		}
	}
	if payload.TeamID == "" {
		if err := h.svc.SyncAllPendingTeams(ctx); err != nil {
			return fmt.Errorf("handlers.gitlab_sync_members: sweep: %w", err)
		}
		return nil
	}
	if err := h.svc.SyncTeamMembers(ctx, payload.TeamID); err != nil {
		return fmt.Errorf("handlers.gitlab_sync_members: %w", err)
	}
	return nil
}
