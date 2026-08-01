package gitlab

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// ─── staff+mentor dashboards ────────────────────────────────────────────────

// GetAssignmentDashboard handles GET /api/projects/assignments/{assignmentID}/dashboard.
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

// GetTeamContributions handles GET /api/projects/teams/{teamID}/contributions.
func (h *Handler) GetTeamContributions(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetTeamContributions(r.Context(), claims.OrgID, chi.URLParam(r, "teamID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// GetAssignmentBurndown handles GET /api/projects/assignments/{assignmentID}/burndown.
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

// GetAssignmentLeaderboard handles GET /api/projects/assignments/{assignmentID}/leaderboard.
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

// ListMyProjects handles GET /api/my/projects — the authenticated user's own
// team memberships only (see Service.ListMyProjects).
func (h *Handler) ListMyProjects(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	projects, err := h.service.ListMyProjects(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, projects)
}

// GetMyProject handles GET /api/my/projects/{teamID} — returns "not found"
// (rather than "forbidden") for a team the caller doesn't belong to, so no
// information about a team's existence leaks to a non-member.
func (h *Handler) GetMyProject(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	team, err := h.service.GetMyProject(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "teamID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, team)
}

// GetMyProjectContributions handles GET /api/my/projects/{teamID}/contributions.
func (h *Handler) GetMyProjectContributions(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetMyProjectContributions(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "teamID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// GetMyProjectCheckpoints handles GET /api/my/projects/{teamID}/checkpoints —
// the student-scoped counterpart to ListCheckpoints+ListSubmissions, row
// scoped via Service.GetMyProjectCheckpoints's membership check.
func (h *Handler) GetMyProjectCheckpoints(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetMyProjectCheckpoints(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "teamID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}
