package pricing

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
)

// Router wires the pricing domain into the main chi router.
type Router struct {
	handler *Handler
	pool    *pgxpool.Pool
}

func New(pool *pgxpool.Pool) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: newHandler(service), pool: pool}
}

// RegisterPublicRoutes mounts the anonymous read used by the / and /org
// landing pages — no auth, same as the public course catalog.
func (rt *Router) RegisterPublicRoutes(r chi.Router) {
	r.Get("/api/public/pricing", rt.handler.ListPublic)
}

// RegisterPlatformRoutes mounts the platform admin's (super_admin) pricing
// editor. Caller must already be inside an authenticated group (RequireAuth
// + RequireCSRF), matching every other RegisterPlatformRoutes in this repo.
func (rt *Router) RegisterPlatformRoutes(r chi.Router) {
	r.Route("/api/admin/pricing", func(r chi.Router) {
		r.Use(apimiddleware.RequirePlatformRole(rt.pool, apimiddleware.PlatformRoleSuperAdmin))

		r.Get("/", rt.handler.AdminList)
		r.Patch("/{id}", rt.handler.AdminUpdate)
	})
}
