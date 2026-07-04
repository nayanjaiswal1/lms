package mentoring

import (
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// RequestMentorChange lets the authenticated student (who must be the
// ticket's own student) ask for a different mentor. Body: {"reason": "..."}.
func (h *Handler) RequestMentorChange(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Reason string `json:"reason"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	cr, err := h.service.RequestMentorChange(r.Context(), claims.OrgID, urlParam(r, "ticketID"), claims.UserID, req.Reason)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, cr)
}

// ListChangeRequests returns mentor change requests for the caller's org,
// optionally filtered by ?status=.
func (h *Handler) ListChangeRequests(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	requests, err := h.service.ListChangeRequests(r.Context(), claims.OrgID, queryStrPtr(r, "status"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"requests": requests})
}

// ApproveChangeRequest approves a pending change request and reopens its
// ticket. Body: {"note"?: "..."}.
func (h *Handler) ApproveChangeRequest(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Note string `json:"note"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	cr, ticket, err := h.service.ApproveChangeRequest(r.Context(), claims.OrgID, urlParam(r, "requestID"), claims.UserID, req.Note)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"request": cr, "ticket": ticket})
}

// DenyChangeRequest denies a pending change request. Body: {"note"?: "..."}.
func (h *Handler) DenyChangeRequest(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Note string `json:"note"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	cr, err := h.service.DenyChangeRequest(r.Context(), claims.OrgID, urlParam(r, "requestID"), claims.UserID, req.Note)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, cr)
}
