package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// GitlabIngestEventHandler implements jobs.Handler for HandlerGitlabIngestEvent
// jobs — one per webhook_events row. Triggered by handler_webhook.go's
// receiver on a fresh (non-redelivered) event insert; dispatches by
// event_type per kind-herding-cookie.md §4 and marks the row dispatched/
// ignored/failed (see gitlab.Service.IngestEvent).
type GitlabIngestEventHandler struct {
	svc *gitlab.Service
}

// NewGitlabIngestEventHandler constructs a GitlabIngestEventHandler.
func NewGitlabIngestEventHandler(svc *gitlab.Service) *GitlabIngestEventHandler {
	return &GitlabIngestEventHandler{svc: svc}
}

type gitlabIngestEventPayload struct {
	EventID string `json:"event_id"`
}

// Handle ingests the webhook event named in the job payload.
func (h *GitlabIngestEventHandler) Handle(ctx context.Context, job jobs.Job) error {
	var payload gitlabIngestEventPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("handlers.gitlab_ingest_event: decode payload: %w", err)
	}
	if payload.EventID == "" {
		return fmt.Errorf("handlers.gitlab_ingest_event: missing event_id")
	}
	if err := h.svc.IngestEvent(ctx, payload.EventID); err != nil {
		return fmt.Errorf("handlers.gitlab_ingest_event: %w", err)
	}
	return nil
}
