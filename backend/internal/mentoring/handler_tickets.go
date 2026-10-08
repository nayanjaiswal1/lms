package mentoring

import (
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/pagination"
)

// RequestMentor lets the authenticated student open a mentor ticket for a
// course they're enrolled in, when they don't already have an active one.
// Body: {"course_id": "..."}.
func (h *Handler) RequestMentor(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		CourseID string `json:"course_id"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if req.CourseID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"course_id": "course_id is required."})
		return
	}
	ticket, err := h.service.RequestMentor(r.Context(), claims.OrgID, claims.UserID, req.CourseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, ticket)
}

// ListTicketChangeRequests handles GET /api/mentor-tickets/{ticketID}/change-requests
// (mentoring.assign_tickets) — the change requests filed against a ticket.
func (h *Handler) ListTicketChangeRequests(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	items, err := h.service.ListTicketChangeRequests(r.Context(), claims.OrgID, httputil.URLParam(r, "ticketID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, pagination.Page[ChangeRequest]{Items: items})
}

// ListTicketReports handles GET /api/mentor-tickets/{ticketID}/reports
// (mentoring.manage_reports) — the complaints filed in a ticket's context.
func (h *Handler) ListTicketReports(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	items, err := h.service.ListTicketReports(r.Context(), claims.OrgID, httputil.URLParam(r, "ticketID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, pagination.Page[Report]{Items: items})
}

// ClaimTicket lets the authenticated mentor self-assign an open ticket.
func (h *Handler) ClaimTicket(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	ticket, err := h.service.ClaimTicket(r.Context(), claims.OrgID, httputil.URLParam(r, "ticketID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ticket)
}

// AssignTicket lets a permitted staff member hand-assign a mentor to an open
// ticket. Body: {"mentor_id": "..."}.
func (h *Handler) AssignTicket(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		MentorID string `json:"mentor_id"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if req.MentorID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"mentor_id": "mentor_id is required."})
		return
	}
	ticket, err := h.service.AssignTicket(r.Context(), claims.OrgID, httputil.URLParam(r, "ticketID"), req.MentorID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ticket)
}

// CloseTicket closes a ticket. Allowed for the ticket's student (ending their
// own mentorship), the ticket's assigned mentor, or anyone holding
// mentoring.assign_tickets — enforced here (not via middleware) since it's an
// either/or condition rather than a single role/permission gate.
func (h *Handler) CloseTicket(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	ticketID := httputil.URLParam(r, "ticketID")
	ticket, err := h.service.GetTicket(r.Context(), claims.OrgID, ticketID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	isOwnTicket := ticket.RequesterID == claims.UserID
	isAssignedMentor := ticket.AssignedTo != nil && *ticket.AssignedTo == claims.UserID
	if !isOwnTicket && !isAssignedMentor {
		allowed, err := h.authzSvc.HasPermission(r.Context(), claims.UserID, claims.OrgID, PermissionAssignTickets)
		if err != nil {
			httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
			return
		}
		if !allowed {
			httputil.WriteError(w, http.StatusForbidden, "You do not have permission to close this ticket.")
			return
		}
	}

	closed, err := h.service.CloseTicket(r.Context(), claims.OrgID, ticketID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, closed)
}
