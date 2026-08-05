package mentoring

import (
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
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
	if !decodeJSON(w, r, &req) {
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

// GetTicketDetail returns the full staff-facing lifecycle for a ticket —
// the ticket, its change requests, and (if the caller holds
// mentoring.manage_reports) complaint reports — the single aggregate behind
// the ticket detail page. The route is gated by mentoring.assign_tickets
// (see routes.go); the report section is additionally gated inline here
// since it's a stricter, separately-grantable permission.
func (h *Handler) GetTicketDetail(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	canViewReports, err := h.authzSvc.HasPermission(r.Context(), claims.UserID, claims.OrgID, PermissionManageReports)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return
	}
	detail, err := h.service.GetTicketDetail(r.Context(), claims.OrgID, urlParam(r, "ticketID"), canViewReports)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, detail)
}

// ClaimTicket lets the authenticated mentor self-assign an open ticket.
func (h *Handler) ClaimTicket(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	ticket, err := h.service.ClaimTicket(r.Context(), claims.OrgID, urlParam(r, "ticketID"), claims.UserID)
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
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.MentorID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"mentor_id": "mentor_id is required."})
		return
	}
	ticket, err := h.service.AssignTicket(r.Context(), claims.OrgID, urlParam(r, "ticketID"), req.MentorID, claims.UserID)
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
	ticketID := urlParam(r, "ticketID")
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
