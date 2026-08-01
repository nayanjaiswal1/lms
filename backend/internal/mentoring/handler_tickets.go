package mentoring

import (
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// ListTickets returns mentor tickets for the caller's org, optionally
// filtered by ?status= and, for a mentor's own queue, ?mine=true.
func (h *Handler) ListTickets(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	status := queryStrPtr(r, "status")
	var mentorID *string
	if r.URL.Query().Get("mine") == "true" {
		mentorID = &claims.UserID
	}
	tickets, err := h.service.ListTickets(r.Context(), claims.OrgID, status, mentorID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"tickets": tickets})
}

// ListMyTickets returns the authenticated student's own mentor tickets —
// the student-facing counterpart to ListTickets (which is staff-only).
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

// GetTicketHistory returns a ticket plus its full mentor-assignment history —
// allowed only for that ticket's student or currently assigned mentor.
func (h *Handler) GetTicketHistory(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	ticket, assignments, err := h.service.GetTicketHistory(r.Context(), claims.OrgID, urlParam(r, "ticketID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"ticket": ticket, "assignments": assignments})
}

// GetTicketDetail returns the full staff-facing lifecycle for a ticket —
// assignments, change requests, and (if the caller holds
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

	isOwnTicket := ticket.StudentID == claims.UserID
	isAssignedMentor := ticket.AssignedMentorID != nil && *ticket.AssignedMentorID == claims.UserID
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
