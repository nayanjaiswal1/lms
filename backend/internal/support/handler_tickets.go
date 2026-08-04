package support

import (
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// canManage reports whether the caller holds support.manage in orgID — the
// staff-queue permission that also unlocks viewing/replying to any ticket,
// not just one's own.
func (h *Handler) canManage(r *http.Request, userID, orgID string) (bool, error) {
	return h.authzSvc.HasPermission(r.Context(), userID, orgID, PermissionManage)
}

// CreateTicket lets any authenticated org member raise a new support ticket.
// Body: {"subject": "...", "message": "..."}.
func (h *Handler) CreateTicket(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Subject string `json:"subject"`
		Message string `json:"message"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	ticket, err := h.service.CreateTicket(r.Context(), claims.OrgID, claims.UserID, req.Subject, req.Message)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, ticket)
}

// UpdateProperties sets a ticket's category and priority — the staff triage
// step. Staff-only — gated by support.manage in routes.go. Body:
// {"category": "...", "priority": "..."}.
func (h *Handler) UpdateProperties(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Category string `json:"category"`
		Priority string `json:"priority"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	ticket, err := h.service.UpdateProperties(r.Context(), claims.OrgID, urlParam(r, "ticketID"), req.Category, req.Priority)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ticket)
}

// ListMyTickets returns the authenticated caller's own tickets.
func (h *Handler) ListMyTickets(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	tickets, err := h.service.ListMyTickets(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"tickets": tickets})
}

// ListTickets returns every ticket in the org, optionally filtered by
// ?status=. Staff-only — gated by support.manage in routes.go.
func (h *Handler) ListTickets(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	tickets, err := h.service.ListTickets(r.Context(), claims.OrgID, queryStrPtr(r, "status"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"tickets": tickets})
}

// GetTicket returns a single ticket's detail — allowed for its own reporter
// or a caller holding support.manage.
func (h *Handler) GetTicket(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	canManage, err := h.canManage(r, claims.UserID, claims.OrgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return
	}
	ticket, err := h.service.GetTicket(r.Context(), claims.OrgID, urlParam(r, "ticketID"), claims.UserID, canManage)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ticket)
}

// UpdateStatus changes a ticket's status. Staff-only — gated by
// support.manage in routes.go. Body: {"status": "..."}.
func (h *Handler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Status string `json:"status"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	ticket, err := h.service.UpdateStatus(r.Context(), claims.OrgID, urlParam(r, "ticketID"), req.Status, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ticket)
}

// ListMessages returns a ticket's full reply thread — allowed for its own
// reporter or a caller holding support.manage.
func (h *Handler) ListMessages(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	canManage, err := h.canManage(r, claims.UserID, claims.OrgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return
	}
	messages, err := h.service.ListMessages(r.Context(), claims.OrgID, urlParam(r, "ticketID"), claims.UserID, canManage)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"messages": messages})
}

// SendMessage posts a reply on a ticket's thread — allowed for its own
// reporter or a caller holding support.manage. Body: {"body": "..."}.
func (h *Handler) SendMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Body string `json:"body"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	canManage, err := h.canManage(r, claims.UserID, claims.OrgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return
	}
	message, err := h.service.SendMessage(r.Context(), claims.OrgID, urlParam(r, "ticketID"), claims.UserID, req.Body, canManage)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, message)
}
