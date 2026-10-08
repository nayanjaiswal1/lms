package mistakes

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/practice"
)

// New builds the fully-wired mistakes handler.
func New(pool *pgxpool.Pool, jobsRegistry *jobs.Registry) *Handler {
	repo := NewRepo(pool)
	return NewHandler(repo, NewService(repo, pool, jobsRegistry))
}

// RegisterRoutes mounts the mistakes API, gated on practice.use — logging a
// mistake enqueues an LLM job, the same quota the practice domain spends.
// The caller is responsible for applying RequireAuth + RequireCSRF before this.
func (h *Handler) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	r = r.With(authz.RequirePermission(authzSvc, practice.PermUse))
	r.Get("/api/mistakes", h.HandleList)
	r.Post("/api/mistakes", h.HandleCreate)
	r.Get("/api/mistakes/summary", h.HandleSummary)
	r.Post("/api/mistakes/{id}/resolve", h.HandleResolve)
}
