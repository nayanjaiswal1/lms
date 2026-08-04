package legal

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Router wires the legal-consent HTTP API.
type Router struct {
	handler *Handler
	Service *Service
}

// New wires the legal package's repo/service/handler dependency graph.
func New(pool *pgxpool.Pool) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: &Handler{service: service}, Service: service}
}

// RegisterRoutes mounts the legal API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Get("/api/legal/status", rt.handler.HandleStatus)
	r.Post("/api/legal/accept", rt.handler.HandleAccept)
}
