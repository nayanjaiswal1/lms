package features

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Router wires the features domain into the main chi router.
type Router struct {
	handler *Handler
}

// New builds the features Router with its full dependency graph.
func New(pool *pgxpool.Pool) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: newHandler(service)}
}

// RegisterRoutes mounts feature endpoints under the caller's authenticated group.
// The caller must have already applied requireAuth + requireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Get("/api/me/features", rt.handler.GetMyFeatures)
}
