package gitlab

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// ─── staff+mentor dashboards ────────────────────────────────────────────────

// GetAssignmentDashboard handles GET /api/workspace-cohorts/{assignmentID}/dashboard.
func (h *Handler) GetAssignmentDashboard(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetAssignmentDashboard(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// GetAssignmentOwnership handles GET /api/workspace-cohorts/{assignmentID}/ownership.
func (h *Handler) GetAssignmentOwnership(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetAssignmentOwnership(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// GetAssignmentBurndown handles GET /api/workspace-cohorts/{assignmentID}/burndown.
func (h *Handler) GetAssignmentBurndown(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetAssignmentBurndown(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// GetAssignmentLeaderboard handles GET /api/workspace-cohorts/{assignmentID}/leaderboard.
func (h *Handler) GetAssignmentLeaderboard(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetAssignmentLeaderboard(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// ─── student-facing "my projects" (any org member, row-scoped) ────────────
