package mentoring

import (
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// ReportMentor lets any authenticated user file a complaint against a mentor.
// Body: {"reason", "description", "ticket_id"?}.
func (h *Handler) ReportMentor(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Reason      string  `json:"reason"`
		Description string  `json:"description"`
		TicketID    *string `json:"ticket_id"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	report, err := h.service.ReportMentor(r.Context(), claims.OrgID, urlParam(r, "mentorID"), claims.UserID, req.Reason, req.Description, req.TicketID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, report)
}

// ListReports returns mentor complaint reports for the caller's org,
// optionally filtered by ?status=.
func (h *Handler) ListReports(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	reports, err := h.service.ListReports(r.Context(), claims.OrgID, queryStrPtr(r, "status"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"reports": reports})
}

// ResolveReport marks a report resolved or dismissed.
// Body: {"status": "resolved"|"dismissed", "resolution_note"?: "..."}.
func (h *Handler) ResolveReport(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Status         string `json:"status"`
		ResolutionNote string `json:"resolution_note"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	report, err := h.service.ResolveReport(r.Context(), claims.OrgID, urlParam(r, "reportID"), claims.UserID, req.Status, req.ResolutionNote)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, report)
}
