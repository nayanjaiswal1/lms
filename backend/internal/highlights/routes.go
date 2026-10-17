package highlights

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/authz"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/practice"
)

// Router wires the highlights domain into the main chi router.
type Router struct {
	handler *Handler
	pool    *pgxpool.Pool
}

// New builds the highlights Router with its full dependency graph.
func New(pool *pgxpool.Pool, provider ai.LLMProvider) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, provider)
	return &Router{handler: newHandler(service), pool: pool}
}

// RegisterRoutes mounts highlight endpoints under the caller's authenticated group.
// The caller must have already applied requireAuth + requireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	// Learner tools — practice.use (Explain spends LLM quota).
	r.Group(func(r chi.Router) {
		r.Use(authz.RequirePermission(authzSvc, practice.PermUse))
		r.Post("/api/highlights", rt.handler.Create)
		r.With(apimiddleware.Idempotency(rt.pool)).Post("/api/highlights/explain", rt.handler.Explain)
		r.Get("/api/highlights", rt.handler.List)
		r.Patch("/api/highlights/{highlightID}/revision", rt.handler.ToggleRevision)
	})

	// Analytics — super_admin only (platform-level role, requires a DB lookup).
	r.Group(func(r chi.Router) {
		r.Use(apimiddleware.RequirePlatformRole(rt.pool, apimiddleware.PlatformRoleSuperAdmin))
		r.Get("/api/admin/highlights/analytics", rt.handler.Analytics)
	})
}
