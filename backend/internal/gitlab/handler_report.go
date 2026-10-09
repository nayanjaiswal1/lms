package gitlab

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// RequestOriginalityScan handles POST /api/workspace-cohorts/{assignmentID}/originality
// — creates a pending scan report and enqueues gitlab.originality_scan to
// run it.
func (h *Handler) RequestOriginalityScan(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	report, err := h.service.RequestOriginalityScan(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusAccepted, report)
}

// ListOriginalityReports handles GET /api/workspace-cohorts/{assignmentID}/originality.
func (h *Handler) ListOriginalityReports(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	list, err := h.service.ListOriginalityReports(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, list)
}

// RequestHandoff handles POST /api/workspace-cohorts/teams/{teamID}/handoff —
// staff-initiated capstone handoff for a team member (fork or transfer).
func (h *Handler) RequestHandoff(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req HandoffRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if fields := ValidateHandoffRequest(req); len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	handoff, err := h.service.RequestHandoff(r.Context(), claims.OrgID, chi.URLParam(r, "teamID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusAccepted, handoff)
}
