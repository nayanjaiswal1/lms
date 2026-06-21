package srs

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// New builds the fully-wired SRS handler.
func New(pool *pgxpool.Pool) *Handler {
	return NewHandler(pool)
}

// RegisterRoutes mounts the SRS API onto the given router.
// The caller is responsible for applying RequireAuth + RequireCSRF before this.
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/api/srs/due", h.GetDueCards)
	r.Post("/api/srs/review", h.ReviewCard)
	r.Post("/api/srs/cards", h.CreateCard)
}
