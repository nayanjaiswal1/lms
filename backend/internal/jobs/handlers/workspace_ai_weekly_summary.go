package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/workspace"
)

// WorkspaceAIWeeklySummaryHandler implements jobs.Handler for
// HandlerWorkspaceAIWeeklySummary — the Monday 06:00 fan-out
// (docs/project-workspace-plan/contract-phase5.md 5c): one
// workspace.ai_weekly_summary_project job per active project.
type WorkspaceAIWeeklySummaryHandler struct {
	svc *workspace.Service
}

// NewWorkspaceAIWeeklySummaryHandler constructs a WorkspaceAIWeeklySummaryHandler.
func NewWorkspaceAIWeeklySummaryHandler(svc *workspace.Service) *WorkspaceAIWeeklySummaryHandler {
	return &WorkspaceAIWeeklySummaryHandler{svc: svc}
}

// Handle enqueues one per-project job for every active workspace.
func (h *WorkspaceAIWeeklySummaryHandler) Handle(ctx context.Context, _ jobs.Job) error {
	enqueued, err := h.svc.RunWeeklySummaries(ctx)
	if err != nil {
		return fmt.Errorf("handlers.workspace_ai_weekly_summary: %w", err)
	}
	slog.InfoContext(ctx, "handlers.workspace_ai_weekly_summary: done", "enqueued", enqueued)
	return nil
}

// WorkspaceAIWeeklySummaryProjectPayload is the JSON payload for
// workspace.ai_weekly_summary_project jobs.
type WorkspaceAIWeeklySummaryProjectPayload struct {
	ProjectID string `json:"project_id"`
}

// WorkspaceAIWeeklySummaryProjectHandler implements jobs.Handler for
// HandlerWorkspaceAIWeeklySummaryProject — the one AI call per project per
// week (skipped if a manager already regenerated this week's summary).
type WorkspaceAIWeeklySummaryProjectHandler struct {
	svc *workspace.Service
}

// NewWorkspaceAIWeeklySummaryProjectHandler constructs a
// WorkspaceAIWeeklySummaryProjectHandler.
func NewWorkspaceAIWeeklySummaryProjectHandler(svc *workspace.Service) *WorkspaceAIWeeklySummaryProjectHandler {
	return &WorkspaceAIWeeklySummaryProjectHandler{svc: svc}
}

// Handle computes and caches one project's weekly summary.
func (h *WorkspaceAIWeeklySummaryProjectHandler) Handle(ctx context.Context, job jobs.Job) error {
	var p WorkspaceAIWeeklySummaryProjectPayload
	if err := json.Unmarshal(job.Payload, &p); err != nil {
		return fmt.Errorf("handlers.workspace_ai_weekly_summary_project: unmarshal payload: %w", err)
	}
	if p.ProjectID == "" {
		return fmt.Errorf("handlers.workspace_ai_weekly_summary_project: payload missing project_id")
	}
	if err := h.svc.ComputeWeeklySummaryForJob(ctx, p.ProjectID); err != nil {
		return fmt.Errorf("handlers.workspace_ai_weekly_summary_project: %w", err)
	}
	return nil
}
