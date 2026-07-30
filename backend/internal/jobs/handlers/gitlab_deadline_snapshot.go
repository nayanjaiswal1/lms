package handlers

import (
	"context"
	"fmt"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// GitlabDeadlineSnapshotHandler implements jobs.Handler for
// HandlerGitlabDeadlineSnapshot jobs — cron */5min (cmd/server/main.go):
// finds every checkpoint past due_at whose team hasn't been HEAD-snapshotted
// yet and takes that snapshot (see gitlab.Service.SnapshotDueCheckpoints).
type GitlabDeadlineSnapshotHandler struct {
	svc *gitlab.Service
}

// NewGitlabDeadlineSnapshotHandler constructs a GitlabDeadlineSnapshotHandler.
func NewGitlabDeadlineSnapshotHandler(svc *gitlab.Service) *GitlabDeadlineSnapshotHandler {
	return &GitlabDeadlineSnapshotHandler{svc: svc}
}

// Handle snapshots every checkpoint the cron sweep currently applies to.
func (h *GitlabDeadlineSnapshotHandler) Handle(ctx context.Context, _ jobs.Job) error {
	if err := h.svc.SnapshotDueCheckpoints(ctx); err != nil {
		return fmt.Errorf("handlers.gitlab_deadline_snapshot: %w", err)
	}
	return nil
}
