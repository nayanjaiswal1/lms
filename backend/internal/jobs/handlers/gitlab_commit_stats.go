package handlers

import (
	"context"
	"fmt"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// gitlabCommitStatsBatchSize bounds one commit_stats job run to 50 commits
// (kind-herding-cookie.md §3) — a push touching hundreds of commits still
// only costs a few job runs rather than one unbounded API-call storm.
const gitlabCommitStatsBatchSize = 50

// GitlabCommitStatsHandler implements jobs.Handler for
// HandlerGitlabCommitStats jobs — fetches per-sha diff stats
// (additions/deletions) for commits mirrored without them yet. Triggered
// once per push ingest (see gitlab.Service.ingestPushEvent); safe to run
// redundantly since it only ever pulls from the "additions IS NULL" queue.
type GitlabCommitStatsHandler struct {
	svc *gitlab.Service
}

// NewGitlabCommitStatsHandler constructs a GitlabCommitStatsHandler.
func NewGitlabCommitStatsHandler(svc *gitlab.Service) *GitlabCommitStatsHandler {
	return &GitlabCommitStatsHandler{svc: svc}
}

// Handle fetches diff stats for up to gitlabCommitStatsBatchSize pending commits.
func (h *GitlabCommitStatsHandler) Handle(ctx context.Context, _ jobs.Job) error {
	if err := h.svc.FetchPendingCommitStats(ctx, gitlabCommitStatsBatchSize); err != nil {
		return fmt.Errorf("handlers.gitlab_commit_stats: %w", err)
	}
	return nil
}
