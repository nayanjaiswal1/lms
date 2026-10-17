package workspace

import (
	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/authz"
)

// registerCohortRoutes mounts the cohort-scoped workspace routes, gated on
// projects.manage like the gitlab cohort (assignment) routes.
func (h *Handler) registerCohortRoutes(r chi.Router, perms *authz.Service) {
	r.With(authz.RequirePermission(perms, "projects.manage")).
		Post("/api/workspace-cohorts/{cohortID}/workspaces", h.CreateCohortWorkspace)
}
