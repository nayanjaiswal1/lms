package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/captures"
	"github.com/mindforge/backend/internal/jobs"
)

// CapturesProcessHandler implements jobs.Handler for HandlerCapturesProcess,
// delegating to captures.Processor for the actual pipeline (extract, AI
// structure, dedup-ready).
type CapturesProcessHandler struct {
	processor *captures.Processor
}

// NewCapturesProcessHandler constructs a CapturesProcessHandler.
func NewCapturesProcessHandler(processor *captures.Processor) *CapturesProcessHandler {
	return &CapturesProcessHandler{processor: processor}
}

func (h *CapturesProcessHandler) Handle(ctx context.Context, job jobs.Job) error {
	var p captures.JobPayload
	if err := json.Unmarshal(job.Payload, &p); err != nil {
		return fmt.Errorf("handlers.captures_process: decode payload: %w", err)
	}
	if p.CaptureID == "" || p.UserID == "" {
		return fmt.Errorf("handlers.captures_process: payload missing capture_id/user_id")
	}
	return h.processor.Process(ctx, p.CaptureID, p.UserID)
}
