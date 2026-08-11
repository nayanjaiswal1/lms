package srs

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
)

// New builds the fully-wired SRS handler.
func New(pool *pgxpool.Pool) *Handler {
	return NewHandler(pool)
}

// RegisterRoutes mounts the SRS API onto the given router, gated on
// content.srs — the same permission code the frontend's nav entry and
// <AccessGate> already check, enforced again here since UI gates are UX, not
// security. The caller is responsible for applying RequireAuth + RequireCSRF
// before this.
func (h *Handler) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	r.With(authz.RequirePermission(authzSvc, "content.srs")).Group(func(r chi.Router) {
		r.Get("/api/srs/due", h.GetDueCards)
		r.Post("/api/srs/review", h.ReviewCard)
		r.Post("/api/srs/cards", h.CreateCard)
	})
}
