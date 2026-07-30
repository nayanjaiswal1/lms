package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// GitlabHandoffHandler implements jobs.Handler for HandlerGitlabHandoff
// jobs — instructor/student-triggered (no cron entry), one job per
// (team, user): forks or transfers a team's project into the requested
// target namespace per the handoff's mode (see gitlab.Service.RunHandoff).
type GitlabHandoffHandler struct {
	svc *gitlab.Service
}

// NewGitlabHandoffHandler constructs a GitlabHandoffHandler.
func NewGitlabHandoffHandler(svc *gitlab.Service) *GitlabHandoffHandler {
	return &GitlabHandoffHandler{svc: svc}
}

type gitlabHandoffPayload struct {
	HandoffID string `json:"handoff_id"`
}

// Handle runs the handoff named in the job payload.
func (h *GitlabHandoffHandler) Handle(ctx context.Context, job jobs.Job) error {
	var payload gitlabHandoffPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("handlers.gitlab_handoff: decode payload: %w", err)
	}
	if payload.HandoffID == "" {
		return fmt.Errorf("handlers.gitlab_handoff: missing handoff_id")
	}
	if err := h.svc.RunHandoff(ctx, payload.HandoffID); err != nil {
		return fmt.Errorf("handlers.gitlab_handoff: %w", err)
	}
	return nil
}
