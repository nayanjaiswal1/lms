package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// GitlabTemplateSyncHandler implements jobs.Handler for
// HandlerGitlabTemplateSync jobs — instructor-triggered (no cron entry):
// opens a cross-fork merge request from an assignment's template project
// into every ready team's fork (see gitlab.Service.RunTemplateSync).
type GitlabTemplateSyncHandler struct {
	svc *gitlab.Service
}

// NewGitlabTemplateSyncHandler constructs a GitlabTemplateSyncHandler.
func NewGitlabTemplateSyncHandler(svc *gitlab.Service) *GitlabTemplateSyncHandler {
	return &GitlabTemplateSyncHandler{svc: svc}
}

type gitlabTemplateSyncPayload struct {
	AssignmentID string `json:"assignment_id"`
}

// Handle syncs the template into every team named in the job payload's assignment.
func (h *GitlabTemplateSyncHandler) Handle(ctx context.Context, job jobs.Job) error {
	var payload gitlabTemplateSyncPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("handlers.gitlab_template_sync: decode payload: %w", err)
	}
	if payload.AssignmentID == "" {
		return fmt.Errorf("handlers.gitlab_template_sync: missing assignment_id")
	}
	if err := h.svc.RunTemplateSync(ctx, payload.AssignmentID); err != nil {
		return fmt.Errorf("handlers.gitlab_template_sync: %w", err)
	}
	return nil
}
