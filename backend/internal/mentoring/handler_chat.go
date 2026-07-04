package mentoring

import (
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// ListChatMessages returns the authenticated caller's chat thread for a
// ticket — allowed only for that ticket's student or currently assigned mentor.
func (h *Handler) ListChatMessages(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	messages, err := h.service.ListChatMessages(r.Context(), claims.OrgID, urlParam(r, "ticketID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"messages": messages})
}

// SendChatMessage posts a message on a ticket's chat thread. Body: {"body": "..."}.
func (h *Handler) SendChatMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Body string `json:"body"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	msg, err := h.service.SendChatMessage(r.Context(), claims.OrgID, urlParam(r, "ticketID"), claims.UserID, req.Body)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, msg)
}
