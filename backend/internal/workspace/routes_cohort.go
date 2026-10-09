package workspace

import (
	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/middleware"
)

// registerCohortRoutes mounts the cohort-scoped workspace routes, gated to the
// same org roles as the gitlab cohort (assignment) routes.
func (h *Handler) registerCohortRoutes(r chi.Router) {
	r.Group(func(r chi.Router) {
		r.Use(middleware.RequireOrgRole(h.service.repo.Pool(), middleware.RoleOwner, middleware.RoleAdmin, middleware.RoleInstructor))
		r.Post("/api/workspace-cohorts/{cohortID}/workspaces", h.CreateCohortWorkspace)
	})
}
