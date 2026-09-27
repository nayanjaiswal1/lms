package handlers

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/workspace"
)

// WorkspaceInactivitySweepHandler implements jobs.Handler for
// HandlerWorkspaceInactivitySweep — the daily 03:00 sweep of inactive active
// members across every project (docs/project-workspace-plan/
// contract-phase4.md 4c).
type WorkspaceInactivitySweepHandler struct {
	svc *workspace.Service
}

// NewWorkspaceInactivitySweepHandler constructs a WorkspaceInactivitySweepHandler.
func NewWorkspaceInactivitySweepHandler(svc *workspace.Service) *WorkspaceInactivitySweepHandler {
	return &WorkspaceInactivitySweepHandler{svc: svc}
}

// Handle runs one inactivity sweep pass.
func (h *WorkspaceInactivitySweepHandler) Handle(ctx context.Context, _ jobs.Job) error {
	sent, err := h.svc.RunInactivitySweep(ctx)
	if err != nil {
		return fmt.Errorf("handlers.workspace_inactivity_sweep: %w", err)
	}
	slog.InfoContext(ctx, "handlers.workspace_inactivity_sweep: done", "sent", sent)
	return nil
}
