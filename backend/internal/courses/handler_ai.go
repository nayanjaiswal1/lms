package courses

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// GenerateOutline calls the AI provider to produce a course outline JSON.
// Returns the outline to the instructor for review; no DB rows are created.
// The async job that persists the same outline (jobs/handlers) shares
// ai.GenerateOutline, so the preview and the job cannot drift.
func (h *Handler) GenerateOutline(w http.ResponseWriter, r *http.Request) {
	_, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}

	if !h.service.ai.Available() {
		httputil.WriteError(w, http.StatusServiceUnavailable, "AI features are not configured.")
		return
	}

	var req struct {
		Topic       string `json:"topic"`
		Level       string `json:"level"`
		ModuleCount int    `json:"module_count"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), h.service.cfg.LLMTimeout)
	defer cancel()

	outline, _, err := ai.GenerateOutline(ctx, h.service.ai, ai.OutlineParams{
		Topic:       req.Topic,
		Level:       req.Level,
		ModuleCount: req.ModuleCount,
	})
	if err != nil {
		writeOutlineError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, outline)
}

// writeOutlineError maps outline generation failures onto the HTTP contract the
// preview UI relies on. The domain sentinels are checked first so a bad input
// or a malformed model reply never gets reported as an upstream outage.
func writeOutlineError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ai.ErrOutlineTopicRequired):
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"topic": "Topic is required."})
	case errors.Is(err, ai.ErrOutlineUnparsable):
		httputil.WriteError(w, http.StatusInternalServerError, "AI returned an invalid response structure.")
	case errors.Is(err, context.DeadlineExceeded), errors.Is(err, context.Canceled):
		httputil.WriteError(w, http.StatusServiceUnavailable, "AI response timed out. Please try again.")
	case strings.Contains(err.Error(), "rate_limit"):
		httputil.WriteError(w, http.StatusServiceUnavailable, "AI service is rate-limited. Please wait and try again.")
	case strings.Contains(err.Error(), "api error"):
		httputil.WriteError(w, http.StatusBadGateway, "AI service returned an error. Please try again.")
	default:
		// Network or unknown upstream failure.
		httputil.WriteError(w, http.StatusBadGateway, "AI service is unavailable. Please try again.")
	}
}
