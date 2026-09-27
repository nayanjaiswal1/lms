package handlers

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/workspace"
)

// WorkspacePurgeHandler implements jobs.Handler for HandlerWorkspacePurge
// jobs — the daily 04:00 cron sweep (docs/project-workspace-plan/
// contract-phase1.md's Jobs section, 02 §4.7): release seats an invite can
// no longer claim, then purge/scrub stale interests.
type WorkspacePurgeHandler struct {
	svc *workspace.Service
}

// NewWorkspacePurgeHandler constructs a WorkspacePurgeHandler.
func NewWorkspacePurgeHandler(svc *workspace.Service) *WorkspacePurgeHandler {
	return &WorkspacePurgeHandler{svc: svc}
}

// Handle runs one purge pass.
func (h *WorkspacePurgeHandler) Handle(ctx context.Context, _ jobs.Job) error {
	expired, err := h.svc.ExpireInvitedInterests(ctx)
	if err != nil {
		return fmt.Errorf("handlers.workspace_purge: expire invited interests: %w", err)
	}
	purged, err := h.svc.PurgeInterests(ctx)
	if err != nil {
		return fmt.Errorf("handlers.workspace_purge: purge interests: %w", err)
	}
	slog.InfoContext(ctx, "handlers.workspace_purge: done", "expired", expired, "purged", purged)
	return nil
}
