package roadmap

import (
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
	r.Get("/api/roadmaps/public", h.ListPublicRoadmaps)
	r.Get("/api/roadmaps/{roadmapID}", h.GetRoadmap)
	r.Post("/api/roadmaps/{roadmapID}/regenerate", h.RegenerateRoadmap)
	r.Post("/api/roadmaps/{roadmapID}/start", h.StartRoadmap)
	r.Patch("/api/roadmaps/{roadmapID}", h.UpdateRoadmap)
	r.Delete("/api/roadmaps/{roadmapID}", h.DeleteRoadmap)
	r.Patch("/api/roadmaps/{roadmapID}/modules/{moduleID}", h.UpdateModule)
	r.Delete("/api/roadmaps/{roadmapID}/modules/{moduleID}", h.DeleteModule)
	r.Post("/api/roadmaps/{roadmapID}/modules/{moduleID}/progress", h.UpdateModuleProgress)
}
