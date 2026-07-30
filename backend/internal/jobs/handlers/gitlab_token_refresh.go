package handlers

import (
	"context"
	"fmt"
	"time"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// gitlabTokenRefreshWindow is how far ahead of expiry a token is refreshed —
// matches the cron cadence (*/15 * * * *, cmd/server/main.go) with margin so
// a token never actually goes stale between ticks.
const gitlabTokenRefreshWindow = 30 * time.Minute

// GitlabTokenRefreshHandler implements jobs.Handler for HandlerGitlabTokenRefresh
// jobs. On each tick it refreshes any org installation (OAuth-kind only —
// PATs have no refresh token) or member connection whose access token expires
// within the window, flagging status='expired' on refresh failure. Batch 1
// has no generic notifications package yet (that lands in Batch 5), so
// expiry is only logged today, not also pushed to the user — see
// gitlab.Service.RefreshExpiringTokens's own doc comment.
type GitlabTokenRefreshHandler struct {
	svc *gitlab.Service
}

// NewGitlabTokenRefreshHandler constructs a GitlabTokenRefreshHandler.
func NewGitlabTokenRefreshHandler(svc *gitlab.Service) *GitlabTokenRefreshHandler {
	return &GitlabTokenRefreshHandler{svc: svc}
}

// Handle refreshes every GitLab OAuth token expiring within the window.
func (h *GitlabTokenRefreshHandler) Handle(ctx context.Context, _ jobs.Job) error {
	if err := h.svc.RefreshExpiringTokens(ctx, gitlabTokenRefreshWindow); err != nil {
		return fmt.Errorf("handlers.gitlab_token_refresh: %w", err)
	}
	return nil
}
