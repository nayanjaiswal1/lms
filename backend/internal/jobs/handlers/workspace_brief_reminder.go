package handlers

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/workspace"
)

// WorkspaceBriefReminderHandler implements jobs.Handler for
// HandlerWorkspaceBriefReminder — the hourly sweep of unanswered clarifying
// questions (docs/project-workspace-plan/contract-phase3.md's Jobs section).
type WorkspaceBriefReminderHandler struct {
	svc *workspace.Service
}

// NewWorkspaceBriefReminderHandler constructs a WorkspaceBriefReminderHandler.
func NewWorkspaceBriefReminderHandler(svc *workspace.Service) *WorkspaceBriefReminderHandler {
	return &WorkspaceBriefReminderHandler{svc: svc}
}

// Handle runs one reminder pass.
func (h *WorkspaceBriefReminderHandler) Handle(ctx context.Context, _ jobs.Job) error {
	sent, err := h.svc.SendBriefReminders(ctx)
	if err != nil {
		return fmt.Errorf("handlers.workspace_brief_reminder: %w", err)
	}
	slog.InfoContext(ctx, "handlers.workspace_brief_reminder: done", "sent", sent)
	return nil
}
