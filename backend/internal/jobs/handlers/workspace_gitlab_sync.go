package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/workspace"
)

// WorkspaceGitlabSyncHandler implements jobs.Handler for
// HandlerWorkspaceGitlabSync — retries one pending MR-reviewer sync
// (docs/project-workspace-plan/contract-phase4.md 4a step 5). One attempt per
// invocation; the job system's own retry/backoff (MaxRetries) covers repeated
// failures.
type WorkspaceGitlabSyncHandler struct {
	svc *workspace.Service
}

// NewWorkspaceGitlabSyncHandler constructs a WorkspaceGitlabSyncHandler.
func NewWorkspaceGitlabSyncHandler(svc *workspace.Service) *WorkspaceGitlabSyncHandler {
	return &WorkspaceGitlabSyncHandler{svc: svc}
}

type workspaceGitlabSyncPayload struct {
	OrgID  string `json:"org_id"`
	TeamID string `json:"team_id"`
	ItemID string `json:"item_id"`
	MRRef  string `json:"mr_ref"`
}

// Handle retries the reviewer sync described by job.Payload.
func (h *WorkspaceGitlabSyncHandler) Handle(ctx context.Context, job jobs.Job) error {
	var p workspaceGitlabSyncPayload
	if err := json.Unmarshal(job.Payload, &p); err != nil {
		return fmt.Errorf("handlers.workspace_gitlab_sync: decode payload: %w", err)
	}
	if err := h.svc.SyncGitlabReviewers(ctx, p.OrgID, p.TeamID, p.ItemID, p.MRRef); err != nil {
		return fmt.Errorf("handlers.workspace_gitlab_sync: %w", err)
	}
	return nil
}
