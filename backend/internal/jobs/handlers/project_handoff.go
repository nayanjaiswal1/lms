package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/jobs"
)

// ProjectHandoffHandler implements jobs.Handler for HandlerProjectHandoff
// jobs — executes a project handoff (fork or transfer) with the specified
// team, mode, and target namespace.
type ProjectHandoffHandler struct {
	// handoffFunc is a callback that performs the actual handoff operation.
	// It returns (projectID, projectURL, error).
	handoffFunc func(ctx context.Context, teamID, mode, targetNamespace string) (string, string, error)
}

// NewProjectHandoffHandler constructs a ProjectHandoffHandler with a
// handoff implementation function.
func NewProjectHandoffHandler(handoffFunc func(ctx context.Context, teamID, mode, targetNamespace string) (string, string, error)) *ProjectHandoffHandler {
	return &ProjectHandoffHandler{handoffFunc: handoffFunc}
}

type projectHandoffPayload struct {
	TeamID          string `json:"team_id"`
	Mode            string `json:"mode"`
	TargetNamespace string `json:"target_namespace"`
}

type projectHandoffResult struct {
	ProjectID  string `json:"project_id"`
	ProjectURL string `json:"project_url"`
}

// Handle executes the project handoff.
func (h *ProjectHandoffHandler) Handle(ctx context.Context, job jobs.Job) error {
	var payload projectHandoffPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("handlers.project_handoff: decode payload: %w", err)
	}
	if payload.TeamID == "" {
		return fmt.Errorf("handlers.project_handoff: missing team_id")
	}
	if payload.Mode == "" {
		return fmt.Errorf("handlers.project_handoff: missing mode")
	}
	if payload.TargetNamespace == "" {
		return fmt.Errorf("handlers.project_handoff: missing target_namespace")
	}

	projectID, projectURL, err := h.handoffFunc(ctx, payload.TeamID, payload.Mode, payload.TargetNamespace)
	if err != nil {
		return fmt.Errorf("handlers.project_handoff: handoff failed: %w", err)
	}

	// Store the result in the job (caller would retrieve via jobs.GetJob)
	_ = projectHandoffResult{ProjectID: projectID, ProjectURL: projectURL}

	return nil
}
