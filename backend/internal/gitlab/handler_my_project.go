package gitlab

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// GetMyProjectDetail handles GET /api/my/projects/{teamID}/detail — the
// team detail page's team + assignment context + contributions + checkpoints
// in one response, replacing four separate round trips (GetMyProject,
// ListMyProjects, GetMyProjectContributions, GetMyProjectCheckpoints).
// 404s (not 403) for a team the caller doesn't belong to, same as
// GetMyProject.
func (h *Handler) GetMyProjectDetail(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetMyProjectDetail(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "teamID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}
