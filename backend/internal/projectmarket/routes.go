package projectmarket

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/profile"
)

// New builds the fully-wired projectmarket Handler from the shared pool.
// profileRepo/aiProvider/jobsRegistry/gitlabSvc/notifSvc are the shared
// instances the rest of the app already builds (see internal/api/router.go)
// — see NewService's own doc comment for what each backs.
func New(pool *pgxpool.Pool, profileRepo *profile.Repo, aiProvider ai.LLMProvider, jobsRegistry *jobs.Registry, gitlabSvc *gitlab.Service, notifSvc *notifications.Service) *Handler {
	return NewHandler(NewService(pool, profileRepo, aiProvider, jobsRegistry, gitlabSvc, notifSvc))
}

// RegisterRoutes mounts the authenticated project-marketplace API onto the
// given router. The caller is responsible for applying RequireAuth +
// RequireCSRF before this (see internal/api/router.go). Posting/managing
// requirements and reviewing applications is staff (owner/admin/instructor);
// browsing the board, applying, and withdrawing is any authenticated org
// member — same "no role group, row-scoped" placement gitlab.Handler uses
// for its own student-facing surfaces (see internal/gitlab/routes.go).
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Group(func(r chi.Router) {
		r.Use(middleware.RequireOrgRole(h.service.pool, middleware.RoleOwner, middleware.RoleAdmin, middleware.RoleInstructor))

		r.Post("/api/project-marketplace/requirements", h.CreateRequirement)
		r.Get("/api/project-marketplace/requirements", h.ListRequirements)
		r.Get("/api/project-marketplace/requirements/{requirementID}", h.GetRequirement)
		r.Patch("/api/project-marketplace/requirements/{requirementID}", h.UpdateRequirement)
		r.Post("/api/project-marketplace/requirements/{requirementID}/publish", h.PublishRequirement)
		r.Post("/api/project-marketplace/requirements/{requirementID}/close", h.CloseRequirement)
		r.Get("/api/project-marketplace/requirements/{requirementID}/applications", h.ListApplicationsForRequirement)
		r.Patch("/api/project-marketplace/applications/{applicationID}", h.ReviewApplication)
		r.Post("/api/project-marketplace/requirements/{requirementID}/score", h.RequestScoring)
		r.Post("/api/project-marketplace/requirements/{requirementID}/create-team", h.CreateTeamFromSelection)
	})

	r.Get("/api/project-marketplace/board", h.GetBoard)
	r.Get("/api/project-marketplace/board/{requirementID}", h.GetRequirement)
	r.Post("/api/project-marketplace/board/{requirementID}/apply", h.Apply)
	r.Delete("/api/project-marketplace/applications/{applicationID}", h.WithdrawApplication)
	r.Get("/api/my/project-applications", h.ListMyApplications)
}
