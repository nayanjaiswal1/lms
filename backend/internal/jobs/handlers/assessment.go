package handlers

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/jobs"
)

const HandlerAssessmentExpire = "assessment.expire_attempts"

// assessmentExpireBatchLimit caps how many attempts one run force-submits.
// Each one can involve Judge0 grading calls, so this stays smaller than the
// lab reaper's batch size to keep a single run bounded.
const assessmentExpireBatchLimit = 25

// AssessmentExpireHandler force-submits abandoned timed-assessment attempts.
// Mirrors LabExpireHandler: without this, a student who closes the tab
// mid-attempt leaves it stuck "in_progress" forever — never graded, never
// counted, invisible to instructor reporting.
type AssessmentExpireHandler struct {
	handler *assessment.Handler
}

// NewAssessmentExpireHandler constructs an AssessmentExpireHandler from an
// already-wired assessment.Handler (constructed separately from the router's
// own instance — safe, since it holds no in-process state beyond shared
// pointers, the same pattern used for coursesSvcForJobs in main.go).
func NewAssessmentExpireHandler(handler *assessment.Handler) *AssessmentExpireHandler {
	return &AssessmentExpireHandler{handler: handler}
}

func (h *AssessmentExpireHandler) Handle(ctx context.Context, job jobs.Job) error {
	count, err := h.handler.AutoSubmitExpiredAttempts(ctx, assessmentExpireBatchLimit)
	if err != nil {
		return fmt.Errorf("assessment.expire_attempts: %w", err)
	}
	slog.Info("assessment.expire_attempts: force-submitted attempts", "count", count)
	return nil
}
