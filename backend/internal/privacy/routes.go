package privacy

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/authz"
)

// Router wires the privacy (data export/deletion) HTTP API.
type Router struct {
	handler *Handler
}

// New wires the privacy package's repo/service/handler dependency graph.
// adminRepo backs account deletion's session-kill (see Service.DeleteAccount).
func New(pool *pgxpool.Pool, adminRepo *authz.AdminRepo) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, adminRepo)
	return &Router{handler: &Handler{service: service}}
}

// RegisterRoutes mounts the privacy API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Get("/api/privacy/export", rt.handler.HandleExport)
	r.Post("/api/privacy/delete-account", rt.handler.HandleDeleteAccount)
}
