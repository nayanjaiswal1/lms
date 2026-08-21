package handlers

import (
	"context"
	"fmt"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/projectmarket"
)

// ProjectmarketCloseExpiredHandler implements jobs.Handler for
// HandlerProjectmarketCloseExpired jobs — cron sweep (cmd/server/main.go):
// flips every "open" requirement past its application_deadline to "closed"
// (see projectmarket.Service.CloseExpiredRequirements).
type ProjectmarketCloseExpiredHandler struct {
	svc *projectmarket.Service
}

// NewProjectmarketCloseExpiredHandler constructs a ProjectmarketCloseExpiredHandler.
func NewProjectmarketCloseExpiredHandler(svc *projectmarket.Service) *ProjectmarketCloseExpiredHandler {
	return &ProjectmarketCloseExpiredHandler{svc: svc}
}

// Handle closes every requirement the cron sweep currently applies to.
func (h *ProjectmarketCloseExpiredHandler) Handle(ctx context.Context, _ jobs.Job) error {
	if err := h.svc.CloseExpiredRequirements(ctx); err != nil {
		return fmt.Errorf("handlers.projectmarket_close_expired: %w", err)
	}
	return nil
}
