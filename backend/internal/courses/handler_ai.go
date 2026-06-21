package courses

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/httputil"
)

// GenerateOutline calls the AI provider to produce a course outline JSON.
// Returns the outline to the instructor for review; no DB rows are created.
func (h *Handler) GenerateOutline(w http.ResponseWriter, r *http.Request) {
	_, ok := ctxClaims(w, r)
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
	if !decodeJSON(w, r, &req) {
		return
	}

	topic := ai.SanitizeTopic(req.Topic, 200)
	if topic == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"topic": "Topic is required."})
		return
	}
	level := req.Level
	if level == "" {
		level = "intermediate"
	}
	count := req.ModuleCount
	if count <= 0 {
		count = 8
	}
	if count > 30 {
		count = 30
	}

	ctx, cancel := context.WithTimeout(r.Context(), h.service.cfg.LLMTimeout)
	defer cancel()

	userPrompt := fmt.Sprintf("Topic: %s\nDifficulty: %s\nNumber of modules: %d", topic, level, count)

	resp, err := h.service.ai.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.CourseOutlineSystemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    2048,
		JSONMode:     true,
	})
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			httputil.WriteError(w, http.StatusServiceUnavailable, "AI response timed out. Please try again.")
			return
		}
		msg := err.Error()
		if strings.Contains(msg, "rate_limit") {
			httputil.WriteError(w, http.StatusServiceUnavailable, "AI service is rate-limited. Please wait and try again.")
			return
		}
		if strings.Contains(msg, "api error") {
			httputil.WriteError(w, http.StatusBadGateway, "AI service returned an error. Please try again.")
			return
		}
		// Network or unknown upstream failure.
		httputil.WriteError(w, http.StatusBadGateway, "AI service is unavailable. Please try again.")
		return
	}

	var outline CourseOutline
	if err := json.Unmarshal([]byte(resp.Content), &outline); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "AI returned an invalid response structure.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, outline)
}
