package highlights

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
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
func (rt *Router) RegisterRoutes(r chi.Router) {
	// Student-accessible — any authenticated user.
	r.Post("/api/highlights", rt.handler.Create)
	r.Post("/api/highlights/explain", rt.handler.Explain)
	r.Get("/api/highlights", rt.handler.ListBySource)       // ?source_type=&source_id=
	r.Get("/api/highlights/me", rt.handler.ListMine)
	r.Patch("/api/highlights/{highlightID}/revision", rt.handler.ToggleRevision)

	// Analytics — super_admin only (platform-level role, requires a DB lookup).
	r.Group(func(r chi.Router) {
		r.Use(apimiddleware.RequirePlatformRole(rt.pool, apimiddleware.PlatformRoleSuperAdmin))
		r.Get("/api/admin/highlights/analytics", rt.handler.Analytics)
	})
}
