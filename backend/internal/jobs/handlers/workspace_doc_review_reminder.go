package handlers

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/workspace"
)

// WorkspaceDocReviewReminderHandler implements jobs.Handler for
// HandlerWorkspaceDocReviewReminder — the hourly sweep of feature specs stuck
// in_review (docs/project-workspace-plan/contract-phase3.md's Jobs section).
type WorkspaceDocReviewReminderHandler struct {
	svc *workspace.Service
}

// NewWorkspaceDocReviewReminderHandler constructs a WorkspaceDocReviewReminderHandler.
func NewWorkspaceDocReviewReminderHandler(svc *workspace.Service) *WorkspaceDocReviewReminderHandler {
	return &WorkspaceDocReviewReminderHandler{svc: svc}
}

// Handle runs one reminder pass.
func (h *WorkspaceDocReviewReminderHandler) Handle(ctx context.Context, _ jobs.Job) error {
	sent, err := h.svc.SendDocReviewReminders(ctx)
	if err != nil {
		return fmt.Errorf("handlers.workspace_doc_review_reminder: %w", err)
	}
	slog.InfoContext(ctx, "handlers.workspace_doc_review_reminder: done", "sent", sent)
	return nil
}
