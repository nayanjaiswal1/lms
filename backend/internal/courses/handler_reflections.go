package courses

import (
	"errors"
	"net/http"
	"strings"

	"github.com/mindforge/backend/internal/httputil"
)

// maxReflectionLength bounds the free-text reflection so a single student
// can't write an unbounded blob into the DB — long enough for a genuine
// paragraph of reflection, short enough to keep storage (and future
// revision-plan/graph processing over this table) bounded.
const maxReflectionLength = 4000

// SubmitReflection records (or updates) the authenticated student's free-text
// "what did you understand from this lesson" reflection for a notes module.
// This is deliberately separate from the mcq/sql knowledge-check questions:
// it's ungraded, always-available input captured once per module, meant as
// raw signal for a future revision-plan / concept-dependency-graph feature —
// the module-complete gate does not depend on it.
func (h *Handler) SubmitReflection(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Response string `json:"response"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	response := strings.TrimSpace(req.Response)
	if response == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"response": "Write what you understood before submitting."})
		return
	}
	if len(response) > maxReflectionLength {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"response": "Keep it under 4000 characters."})
		return
	}
	ref, err := h.repo.UpsertReflection(r.Context(), LessonReflection{
		OrgID:    claims.OrgID,
		UserID:   claims.UserID,
		ModuleID: urlParam(r, "moduleID"),
		Response: response,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ref)
}

// GetMyReflection returns the authenticated student's existing reflection for
// a module (or null if they haven't written one yet), used to prefill the
// textarea on page load.
func (h *Handler) GetMyReflection(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	ref, err := h.repo.GetMyReflection(r.Context(), claims.UserID, urlParam(r, "moduleID"))
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteJSON(w, http.StatusOK, map[string]any{"response": nil})
			return
		}
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"response": ref.Response})
}
