package captures

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/storage"
)

// New builds the fully-wired captures handler.
func New(pool *pgxpool.Pool, storageClient storage.StorageClient, jobsRegistry *jobs.Registry) *Handler {
	return NewHandler(pool, storageClient, jobsRegistry)
}

// RegisterRoutes mounts the captures API onto the given router, gated on
// content.captures. The caller is responsible for applying RequireAuth +
// RequireCSRF before this (see internal/api/router.go).
func (h *Handler) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	r.With(authz.RequirePermission(authzSvc, "content.captures")).Group(func(r chi.Router) {
		r.Get("/api/captures", h.ListCaptures)
		r.Post("/api/captures", h.Create)
		r.Get("/api/captures/{id}", h.GetCapture)
		r.Post("/api/captures/{id}/retry", h.Retry)
		r.Post("/api/captures/{id}/dismiss", h.Dismiss)
		r.Post("/api/captures/{id}/promote", h.Promote)
	})
}
