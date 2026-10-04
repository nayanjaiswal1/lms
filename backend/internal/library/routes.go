package library

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/middleware"
)

// New wires the full library dependency graph and returns the HTTP handler.
// coursesRepo/labsRepo/labsSvc/assessmentRepo are the already-constructed
// instances internal/api/router.go builds for the courses/labs/assessment
// domains themselves — library reuses them rather than standing up a second
// copy (labsSvc in particular is stateful: warm pool, container runtime,
// Redis client).
func New(pool *pgxpool.Pool, coursesRepo *courses.Repo, labsRepo *labs.Repo, labsSvc *labs.Service, assessmentRepo *assessment.Repo) *Handler {
	repo := NewRepo(pool)
	service := NewService(pool, repo, coursesRepo, labsRepo, labsSvc, assessmentRepo)
	return NewHandler(service)
}

// Service exposes the library service (the single placement path) to build publish.
func (h *Handler) Service() *Service { return h.service }

// RegisterRoutes mounts the library API. Every route uses the same
// RequireOrgRole(owner, admin, instructor) guard courses' module routes use
// (docs/debug-labs.md L4) — placing library content is an authoring action,
// not a student-facing one, even for the read-only list/preview/try
// endpoints (a student doesn't get a library picker of its own in Phase A).
func (h *Handler) RegisterRoutes(r chi.Router, pool *pgxpool.Pool) {
	instructor := middleware.RequireOrgRole(pool, middleware.RoleOwner, middleware.RoleAdmin, middleware.RoleInstructor)
	r.Group(func(r chi.Router) {
		r.Use(instructor)
		r.Get("/api/library", h.HandleList)
		r.Get("/api/library/{kind}/{id}/preview", h.HandlePreview)
		r.Post("/api/library/{kind}/{id}/try", h.HandleTry)
		r.Post("/api/sections/{sectionID}/library-items", h.HandleAttach)
	})
}
