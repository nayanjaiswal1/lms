package mentoring

import (
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// CreateOrGetConversation starts (or resumes) a ticket-independent DM thread
// between the caller and a mentor. Body: {"mentor_id": "..."}.
func (h *Handler) CreateOrGetConversation(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		MentorID string `json:"mentor_id"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	conv, err := h.service.GetOrCreateConversation(r.Context(), claims.OrgID, claims.UserID, req.MentorID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, conv)
}

// ListMyConversations returns every DM conversation the caller is a party to.
func (h *Handler) ListMyConversations(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	conversations, err := h.service.ListMyConversations(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"conversations": conversations})
}

// ListConversationMessages returns the caller's DM thread for a conversation
// — allowed only for that conversation's student or mentor.
func (h *Handler) ListConversationMessages(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	messages, err := h.service.ListConversationMessages(r.Context(), claims.OrgID, urlParam(r, "conversationID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"messages": messages})
}

// SendConversationMessage posts a message on a DM thread. Body: {"body": "..."}.
func (h *Handler) SendConversationMessage(w http.ResponseWriter, r *http.Request) {
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
	msg, err := h.service.SendConversationMessage(r.Context(), claims.OrgID, urlParam(r, "conversationID"), claims.UserID, req.Body)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, msg)
}
