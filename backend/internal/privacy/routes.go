package privacy

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/storage"
)

// Router wires the privacy (data export/deletion) HTTP API.
type Router struct {
	handler *Handler
}

// New wires the privacy package's repo/service/handler dependency graph.
// adminRepo backs account deletion's session-kill (see Service.DeleteAccount).
func New(pool *pgxpool.Pool, adminRepo *authz.AdminRepo, store storage.StorageClient) *Router {
	repo := NewRepo(pool, store)
	service := NewService(repo, adminRepo)
	return &Router{handler: &Handler{service: service, pool: pool}}
}

// RegisterRoutes mounts the privacy API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Get("/api/privacy/export", rt.handler.HandleExport)
	r.Post("/api/privacy/delete-account", rt.handler.HandleDeleteAccount)
	r.Get("/api/privacy/settings", rt.handler.HandleGetSettings)
	r.Put("/api/privacy/ai-consent", rt.handler.HandleSetAIConsent)
	r.Put("/api/privacy/nominee", rt.handler.HandleSetNominee)
}
