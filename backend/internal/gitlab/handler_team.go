package gitlab

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// ListTeams handles GET /api/workspace-cohorts/{assignmentID}/teams.
func (h *Handler) ListTeams(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	teams, err := h.service.ListTeams(r.Context(), claims.OrgID, chi.URLParam(r, "assignmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, teams)
}

// ReprovisionTeam handles POST /api/workspace-cohorts/teams/{teamID}/reprovision —
// force-enqueues a fresh gitlab.provision_team job, e.g. after a failure.
func (h *Handler) ReprovisionTeam(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.ReprovisionTeam(r.Context(), claims.OrgID, chi.URLParam(r, "teamID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusAccepted, map[string]any{"reprovisioning": true})
}
