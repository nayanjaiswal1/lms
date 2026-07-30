package notifications

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
)

// Router mounts the notifications HTTP API. Service is exported so other
// domains can call Notify/NotifyMany directly (e.g. internal/api/router.go
// passes this into gitlab.New's notifications dependency) — same pattern as
// calendar.Router's own exported Service field.
type Router struct {
	handler *Handler
	Service *Service
}

// NewRouter builds the notifications Router with its full dependency graph.
// Named NewRouter rather than this codebase's usual New(...) convention
// because New is already taken in this package — it's the dedupe-insert
// input struct Service.Notify takes (see models.go), and that name is fixed
// by this batch's own spec. jobsRegistry backs Service.Notify's AlsoEmail
// side-effect.
func NewRouter(pool *pgxpool.Pool, jobsRegistry *jobs.Registry) *Router {
	service := NewService(pool, jobsRegistry)
	return &Router{handler: NewHandler(service), Service: service}
}

// RegisterRoutes mounts the notifications API under the caller's
// authenticated group — any org member, row-scoped to their own
// notifications. The caller is responsible for applying RequireAuth +
// RequireCSRF before this.
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Get("/api/notifications", rt.handler.List)
	r.Get("/api/notifications/unread-count", rt.handler.UnreadCount)
	r.Post("/api/notifications/{id}/read", rt.handler.MarkRead)
	r.Post("/api/notifications/read-all", rt.handler.MarkAllRead)
}
