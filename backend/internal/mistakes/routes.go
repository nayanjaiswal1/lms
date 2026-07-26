package mistakes

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// New builds the fully-wired mistakes handler.
func New(pool *pgxpool.Pool) *Handler {
	repo := NewRepo(pool)
	return NewHandler(repo, NewService(repo, pool))
}

// RegisterRoutes mounts the mistakes API onto the given router.
// The caller is responsible for applying RequireAuth + RequireCSRF before this.
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/api/mistakes", h.HandleList)
	r.Post("/api/mistakes", h.HandleCreate)
	r.Get("/api/mistakes/summary", h.HandleSummary)
	r.Post("/api/mistakes/{id}/resolve", h.HandleResolve)
}
