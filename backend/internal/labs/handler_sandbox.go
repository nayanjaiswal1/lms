package labs

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// HandleListPorts returns the TCP ports currently listening inside the
// session's container (sandbox workspace port list / preview picker).
//
//	GET /api/labs/sessions/{sessionId}/ports
func (h *Handler) HandleListPorts(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	ports, err := h.service.ListPorts(r.Context(), sessionID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ports)
}

// HandleRunScript executes the lab's student-visible run_script (sample
// tests) inside the session container. Unscored, rate-limited.
//
//	POST /api/labs/sessions/{sessionId}/run
func (h *Handler) HandleRunScript(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	result, err := h.service.RunScript(r.Context(), sessionID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}

// HandleSubmitAll runs every task's hidden verification script in one batch
// and returns per-task pass/fail plus the resulting score/completion state.
//
//	POST /api/labs/sessions/{sessionId}/submit
func (h *Handler) HandleSubmitAll(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	result, err := h.service.SubmitAll(r.Context(), sessionID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}
