package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// GitlabOriginalityScanHandler implements jobs.Handler for
// HandlerGitlabOriginalityScan jobs — instructor-triggered (no cron entry):
// downloads every team's (+ the template's) repository archive and runs the
// shingling/Jaccard originality comparison (see
// gitlab.Service.RunOriginalityScan).
type GitlabOriginalityScanHandler struct {
	svc *gitlab.Service
}

// NewGitlabOriginalityScanHandler constructs a GitlabOriginalityScanHandler.
func NewGitlabOriginalityScanHandler(svc *gitlab.Service) *GitlabOriginalityScanHandler {
	return &GitlabOriginalityScanHandler{svc: svc}
}

type gitlabOriginalityScanPayload struct {
	ReportID string `json:"report_id"`
}

// Handle runs the originality scan named in the job payload's report.
func (h *GitlabOriginalityScanHandler) Handle(ctx context.Context, job jobs.Job) error {
	var payload gitlabOriginalityScanPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("handlers.gitlab_originality_scan: decode payload: %w", err)
	}
	if payload.ReportID == "" {
		return fmt.Errorf("handlers.gitlab_originality_scan: missing report_id")
	}
	if err := h.svc.RunOriginalityScan(ctx, payload.ReportID); err != nil {
		return fmt.Errorf("handlers.gitlab_originality_scan: %w", err)
	}
	return nil
}
