package handlers

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/workspace"
)

// WorkspaceManagerDigestHandler implements jobs.Handler for
// HandlerWorkspaceManagerDigest — the daily 08:00 per-project manager digest
// (docs/project-workspace-plan/contract-phase4.md 4d).
type WorkspaceManagerDigestHandler struct {
	svc *workspace.Service
}

// NewWorkspaceManagerDigestHandler constructs a WorkspaceManagerDigestHandler.
func NewWorkspaceManagerDigestHandler(svc *workspace.Service) *WorkspaceManagerDigestHandler {
	return &WorkspaceManagerDigestHandler{svc: svc}
}

// Handle sends one day's worth of digests.
func (h *WorkspaceManagerDigestHandler) Handle(ctx context.Context, _ jobs.Job) error {
	sent, err := h.svc.SendDigests(ctx, time.Now())
	if err != nil {
		return fmt.Errorf("handlers.workspace_manager_digest: %w", err)
	}
	slog.InfoContext(ctx, "handlers.workspace_manager_digest: done", "sent", sent)
	return nil
}
