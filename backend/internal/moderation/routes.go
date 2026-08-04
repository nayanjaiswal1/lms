package moderation

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/authz"
)

// Router wires the content-moderation HTTP API.
type Router struct {
	handler *Handler
	Service *Service
}

// New wires the moderation package's repo/service/handler dependency graph.
func New(pool *pgxpool.Pool, authzSvc *authz.Service) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: &Handler{service: service, authzSvc: authzSvc}, Service: service}
}

// RegisterRoutes mounts the moderation API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	// File a report — any authenticated org member.
	r.Post("/api/content-reports", rt.handler.CreateReport)

	// Staff queue — gated by content.moderate.
	r.Group(func(r chi.Router) {
		r.Use(authz.RequirePermission(rt.handler.authzSvc, PermissionModerate))
		r.Get("/api/content-reports", rt.handler.ListReports)
		r.Patch("/api/content-reports/{reportID}", rt.handler.Resolve)
	})
}
