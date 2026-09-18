package whatsnew

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
)

// Router wires the whatsnew domain into the main chi router.
type Router struct {
	handler *Handler
	pool    *pgxpool.Pool
}

func New(pool *pgxpool.Pool) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: newHandler(service), pool: pool}
}

// RegisterRoutes mounts the read-only feed behind the sidebar's sparkle-icon
// panel — any authenticated user. Caller must already be inside an
// authenticated group (RequireAuth + RequireCSRF).
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Get("/api/whats-new", rt.handler.List)
}

// RegisterPlatformRoutes mounts the platform admin's (super_admin) changelog
// editor. Caller must already be inside an authenticated group, matching
// every other RegisterPlatformRoutes in this repo.
func (rt *Router) RegisterPlatformRoutes(r chi.Router) {
	r.Route("/api/admin/whats-new", func(r chi.Router) {
		r.Use(apimiddleware.RequirePlatformRole(rt.pool, apimiddleware.PlatformRoleSuperAdmin))

		r.Get("/", rt.handler.AdminList)
		r.Post("/", rt.handler.AdminCreate)
		r.Patch("/{id}", rt.handler.AdminUpdate)
		r.Delete("/{id}", rt.handler.AdminDelete)
	})
}
