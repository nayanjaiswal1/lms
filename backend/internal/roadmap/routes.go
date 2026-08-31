package roadmap

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
)

// New wires the roadmap package: a self-serve "state a goal, get an AI
// personalized learning path" flow. Generation runs async through the shared
// job queue (handlers.HandlerLLM, task "roadmap_generate" — see
// jobs/handlers/llm.go) so a large phases->milestones->modules generation
// never holds an HTTP request open.
func New(pool *pgxpool.Pool, jobsRegistry *jobs.Registry) *Handler {
	repo := NewRepo(pool)
	service := NewService(repo, pool, jobsRegistry)
	return &Handler{service: service, repo: repo}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Post("/api/roadmaps", h.CreateRoadmap)
	r.Get("/api/roadmaps", h.ListRoadmaps)
	r.Post("/api/roadmaps/{roadmapID}/regenerate", h.RegenerateRoadmap)
	r.Post("/api/roadmaps/{roadmapID}/start", h.StartRoadmap)
	r.Patch("/api/roadmaps/{roadmapID}", h.UpdateRoadmap)
	r.Delete("/api/roadmaps/{roadmapID}", h.DeleteRoadmap)
	r.Patch("/api/roadmaps/{roadmapID}/modules/{moduleID}", h.UpdateModule)
	r.Delete("/api/roadmaps/{roadmapID}/modules/{moduleID}", h.DeleteModule)
	r.Post("/api/roadmaps/{roadmapID}/modules/{moduleID}/progress", h.UpdateModuleProgress)
}

// RegisterOptionalAuthRoutes mounts routes that work both signed in and
// anonymous — mw sets Claims in ctx when a valid session exists but never
// rejects the request otherwise (see middleware.OptionalAuth). GetRoadmap
// itself branches on whether Claims are present: owner gets the full
// editable view, anyone else gets the read-only public view if the roadmap
// is is_public. Kept out of RegisterRoutes' strict-auth group specifically
// so this one path can serve both without a separate "public" URL.
func (h *Handler) RegisterOptionalAuthRoutes(r chi.Router, mw func(http.Handler) http.Handler) {
	r.With(mw).Get("/api/roadmaps/{roadmapID}", h.GetRoadmap)
}

// RegisterPublicRoutes mounts the Discover gallery listing — no
// authentication, ever. An owner opts a roadmap in via is_public (PATCH
// /api/roadmaps/:id, under RegisterRoutes).
func (h *Handler) RegisterPublicRoutes(r chi.Router) {
	r.Get("/api/roadmaps/discover", h.ListPublicRoadmaps)
}
