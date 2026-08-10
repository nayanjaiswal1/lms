package habit

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Router wires the habit domain into the main chi router.
type Router struct {
	handler *Handler
}

// New builds the habit Router with its full dependency graph.
func New(pool *pgxpool.Pool) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: newHandler(service)}
}

// RegisterRoutes mounts habit endpoints under the caller's authenticated
// group. The caller must have already applied requireAuth + requireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Post("/api/habits", rt.handler.Create)
	r.Get("/api/habits", rt.handler.MonthView)
	r.Patch("/api/habits/{habitID}", rt.handler.Update)
	r.Delete("/api/habits/{habitID}", rt.handler.Delete)

	r.Put("/api/habits/{habitID}/completions/{period}", rt.handler.SetCompletion)
	r.Delete("/api/habits/{habitID}/completions/{period}", rt.handler.ClearCompletion)
	r.Put("/api/habits/{habitID}/completions/{period}/metadata", rt.handler.SetCompletionMetadata)
}
