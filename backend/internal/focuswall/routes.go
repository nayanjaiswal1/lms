package focuswall

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Router wires the focuswall domain into the main chi router.
type Router struct {
	handler *Handler
}

// New builds the focuswall Router with its full dependency graph.
func New(pool *pgxpool.Pool) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: newHandler(service)}
}

// RegisterRoutes mounts focus-wall endpoints under the caller's authenticated
// group. The caller must have already applied requireAuth + requireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Post("/api/focus-wall/notes", rt.handler.Create)
	r.Get("/api/focus-wall/notes", rt.handler.ListMine)
	r.Patch("/api/focus-wall/notes/{noteID}", rt.handler.Update)
	r.Delete("/api/focus-wall/notes/{noteID}", rt.handler.Delete)

	r.Get("/api/focus-wall/categories", rt.handler.ListCategories)
}
