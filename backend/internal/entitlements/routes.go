package entitlements

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
)

// Router wires the entitlements domain into the main chi router.
type Router struct {
	handler *Handler
	pool    *pgxpool.Pool
	Service *Service
}

// New builds the entitlements Router with its full dependency graph.
// defaultOrgID is cfg.DefaultOrgID — see Service.ResolveAccount.
func New(pool *pgxpool.Pool, defaultOrgID string) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, defaultOrgID)
	return &Router{handler: newHandler(service), pool: pool, Service: service}
}

// RegisterRoutes mounts the current-account usage endpoint under the
// caller's authenticated group.
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Get("/api/me/usage", rt.handler.GetMyUsage)
}

// RegisterPlatformRoutes mounts the platform admin's (super_admin) plan
// limits editor and tier-assignment endpoints.
func (rt *Router) RegisterPlatformRoutes(r chi.Router) {
	r.Route("/api/admin/plan-limits/{tier_id}", func(r chi.Router) {
		r.Use(apimiddleware.RequirePlatformRole(rt.pool, apimiddleware.PlatformRoleSuperAdmin))

		r.Get("/", rt.handler.AdminListPlanLimits)
		r.Put("/{key}", rt.handler.AdminSetPlanLimit)
	})
	r.Route("/api/admin/users/{id}/tier", func(r chi.Router) {
		r.Use(apimiddleware.RequirePlatformRole(rt.pool, apimiddleware.PlatformRoleSuperAdmin))
		r.Put("/", rt.handler.AdminSetUserTier)
	})
	r.Route("/api/admin/orgs/{id}/tier", func(r chi.Router) {
		r.Use(apimiddleware.RequirePlatformRole(rt.pool, apimiddleware.PlatformRoleSuperAdmin))
		r.Put("/", rt.handler.AdminSetOrgTier)
	})
}
