package revisionplan

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
)

// New wires the revisionplan package: a self-serve "I finished this course,
// build me a revision plan from my actual performance" flow. Generation runs
// async through the shared job queue (handlers.HandlerLLM, task
// "revision_plan_generate" — see jobs/handlers/llm.go), same as
// internal/roadmap, so the AI call never holds an HTTP request open.
func New(pool *pgxpool.Pool, jobsRegistry *jobs.Registry) *Handler {
	repo := NewRepo(pool)
	service := NewService(repo, pool, jobsRegistry)
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Post("/api/courses/{courseID}/revision-plan", h.Generate)
	r.Get("/api/courses/{courseID}/revision-plan/me", h.GetMine)
}
