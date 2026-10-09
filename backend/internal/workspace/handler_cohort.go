package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// CreateCohortWorkspace handles POST /api/workspace-cohorts/{cohortID}/workspaces.
func (h *Handler) CreateCohortWorkspace(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateCohortWorkspaceRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	p, err := h.service.CreateCohortWorkspace(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "cohortID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, p)
}
