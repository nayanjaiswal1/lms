package handlers

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/projectmarket"
)

// ProjectmarketScoreRequirementHandler implements jobs.Handler for
// HandlerProjectmarketScoreRequirement jobs — staff-triggered (no cron
// entry): ranks every not-yet-scored application against one requirement
// (see projectmarket.Service.ScoreRequirement).
type ProjectmarketScoreRequirementHandler struct {
	svc *projectmarket.Service
}

// NewProjectmarketScoreRequirementHandler constructs a ProjectmarketScoreRequirementHandler.
func NewProjectmarketScoreRequirementHandler(svc *projectmarket.Service) *ProjectmarketScoreRequirementHandler {
	return &ProjectmarketScoreRequirementHandler{svc: svc}
}

type projectmarketScorePayload struct {
	OrgID         string `json:"org_id"`
	RequirementID string `json:"requirement_id"`
}

// Handle scores the requirement named in the job payload.
func (h *ProjectmarketScoreRequirementHandler) Handle(ctx context.Context, job jobs.Job) error {
	var payload projectmarketScorePayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("handlers.projectmarket_score: decode payload: %w", err)
	}
	if payload.OrgID == "" || payload.RequirementID == "" {
		return fmt.Errorf("handlers.projectmarket_score: missing org_id or requirement_id")
	}
	if err := h.svc.ScoreRequirement(ctx, payload.OrgID, payload.RequirementID); err != nil {
		return fmt.Errorf("handlers.projectmarket_score: %w", err)
	}
	return nil
}
