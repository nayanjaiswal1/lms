package gitlab

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/httputil"
)

// RequestOriginalityScan handles POST /api/projects/assignments/{assignmentID}/originality
// — creates a pending scan report and enqueues gitlab.originality_scan to
// run it.
func (h *Handler) RequestOriginalityScan(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
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

// ListOriginalityReports handles GET /api/projects/assignments/{assignmentID}/originality.
func (h *Handler) ListOriginalityReports(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
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

// RequestHandoff handles POST /api/projects/teams/{teamID}/handoff — creates
// (or resets) a capstone handoff request and enqueues gitlab.handoff to run
// it, fork or transfer per the request's mode (§0.5).
func (h *Handler) RequestHandoff(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req HandoffRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	fields := map[string]string{}
	if req.UserID == "" {
		fields["user_id"] = "A user_id is required."
	}
	if req.Mode != HandoffModeFork && req.Mode != HandoffModeTransfer {
		fields["mode"] = "mode must be 'fork' or 'transfer'."
	}
	if req.TargetNamespaceID == 0 {
		fields["target_namespace_id"] = "A target_namespace_id is required."
	}
	if len(fields) > 0 {
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
