package handlers

import (
	"context"
	"fmt"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// GitlabPollSyncHandler implements jobs.Handler for HandlerGitlabPollSync
// jobs — cron */10min (cmd/server/main.go), a self-healing pull for
// installations running webhook_mode='poll' or any provisioned team whose
// hook has gone silent (see gitlab.Service.PollSync).
type GitlabPollSyncHandler struct {
	svc *gitlab.Service
}

// NewGitlabPollSyncHandler constructs a GitlabPollSyncHandler.
func NewGitlabPollSyncHandler(svc *gitlab.Service) *GitlabPollSyncHandler {
	return &GitlabPollSyncHandler{svc: svc}
}

// Handle re-syncs every team the poll sweep currently applies to.
func (h *GitlabPollSyncHandler) Handle(ctx context.Context, _ jobs.Job) error {
	if err := h.svc.PollSync(ctx); err != nil {
		return fmt.Errorf("handlers.gitlab_poll_sync: %w", err)
	}
	return nil
}
