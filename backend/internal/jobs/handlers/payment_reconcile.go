package handlers

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/mindforge/backend/internal/jobs"
)

// PaymentReconciler flags stuck payments; satisfied by *mentoring.Service.
type PaymentReconciler interface {
	ReconcilePayments(ctx context.Context, staleAfter time.Duration) (int, error)
}

// PaymentReconcileHandler runs the stuck-payment sweep on a schedule.
type PaymentReconcileHandler struct {
	reconciler PaymentReconciler
	staleAfter time.Duration
}

// NewPaymentReconcileHandler constructs the handler; staleAfter is how long a
// purchase or event may sit unresolved before it is alerted on.
func NewPaymentReconcileHandler(r PaymentReconciler, staleAfter time.Duration) *PaymentReconcileHandler {
	return &PaymentReconcileHandler{reconciler: r, staleAfter: staleAfter}
}

// Handle implements jobs.Handler.
func (h *PaymentReconcileHandler) Handle(ctx context.Context, _ jobs.Job) error {
	n, err := h.reconciler.ReconcilePayments(ctx, h.staleAfter)
	if err != nil {
		return fmt.Errorf("payment reconcile: %w", err)
	}
	if n > 0 {
		slog.WarnContext(ctx, "payment reconcile: stuck items flagged", "count", n)
	}
	return nil
}
