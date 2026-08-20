package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// GitlabAIReviewMRHandler implements jobs.Handler for
// HandlerGitlabAIReviewMR jobs — posts one AI code-quality comment on a
// merge request (see gitlab.Service.ReviewMergeRequest). Review only, never
// a commit or a merge.
type GitlabAIReviewMRHandler struct {
	svc *gitlab.Service
}

// NewGitlabAIReviewMRHandler constructs a GitlabAIReviewMRHandler.
func NewGitlabAIReviewMRHandler(svc *gitlab.Service) *GitlabAIReviewMRHandler {
	return &GitlabAIReviewMRHandler{svc: svc}
}

type gitlabAIReviewMRPayload struct {
	MRID string `json:"mr_id"`
}

// Handle reviews the merge request named in the job payload.
func (h *GitlabAIReviewMRHandler) Handle(ctx context.Context, job jobs.Job) error {
	var payload gitlabAIReviewMRPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("handlers.gitlab_ai_review_mr: decode payload: %w", err)
	}
	if payload.MRID == "" {
		return fmt.Errorf("handlers.gitlab_ai_review_mr: missing mr_id")
	}
	if err := h.svc.ReviewMergeRequest(ctx, payload.MRID); err != nil {
		return fmt.Errorf("handlers.gitlab_ai_review_mr: %w", err)
	}
	return nil
}
