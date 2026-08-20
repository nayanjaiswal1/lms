package features

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	ent "github.com/mindforge/backend/internal/entitlements"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
)

// Router wires the features domain into the main chi router.
type Router struct {
	handler *Handler
	pool    *pgxpool.Pool
}

// New builds the features Router with its full dependency graph.
// entitlementsSvc resolves which pricing tier gates the keys in
// entitlements.OrgGateKeys/IndividualGateKeys — see Service.Resolve.
func New(pool *pgxpool.Pool, entitlementsSvc *ent.Service) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, entitlementsSvc)
	return &Router{handler: newHandler(service), pool: pool}
}

// RegisterRoutes mounts feature endpoints under the caller's authenticated group.
// The caller must have already applied requireAuth + requireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Get("/api/me/features", rt.handler.GetMyFeatures)
}

// RegisterOrgAdminRoutes mounts the org admin's per-member feature-flags
// surface: the owner/admin of an org grants or revokes a feature for one
// member, scoped to features the org itself already has enabled. Distinct
// path segment ("user-features") from internal/orgs's own "/members/..."
// routes so this package needs no dependency on internal/orgs.
func (rt *Router) RegisterOrgAdminRoutes(r chi.Router) {
	r.Route("/api/orgs/{id}/user-features/{member_id}", func(r chi.Router) {
		r.Use(apimiddleware.RequireOrgMember(rt.pool))

		r.Get("/", rt.handler.ListMemberFeatureFlags)
		r.Patch("/{key}", rt.handler.SetMemberFeatureFlag)
		r.Delete("/{key}", rt.handler.ClearMemberFeatureFlag)
	})
}

// RegisterPlatformRoutes mounts the platform admin's (super_admin) per-org
// feature-flags surface.
func (rt *Router) RegisterPlatformRoutes(r chi.Router) {
	r.Route("/api/admin/orgs/{id}/feature-flags", func(r chi.Router) {
		r.Use(apimiddleware.RequirePlatformRole(rt.pool, apimiddleware.PlatformRoleSuperAdmin))

		r.Get("/", rt.handler.AdminListOrgFeatureFlags)
		r.Patch("/{key}", rt.handler.AdminSetOrgFeatureFlag)
		r.Delete("/{key}", rt.handler.AdminClearOrgFeatureFlag)
	})
}
