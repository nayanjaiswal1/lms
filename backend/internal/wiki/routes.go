package wiki

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/middleware"
)

// Router wires the wiki domain into the main chi router.
type Router struct {
	handler *Handler
	pool    *pgxpool.Pool
}

// New builds the wiki Router with its full dependency graph. coursesRepo is
// shared with the courses package (read-only here) to validate course_id on
// space create and to check enrollment on course-linked spaces.
func New(pool *pgxpool.Pool, coursesRepo *courses.Repo) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, coursesRepo)
	return &Router{handler: newHandler(service), pool: pool}
}

// RegisterRoutes mounts wiki endpoints under the caller's authenticated
// group, gated on content.wiki — the same permission code the frontend's nav
// entry and <AccessGate> already check, enforced again here since UI gates
// are UX, not security. Space deletion is additionally restricted to org
// admins at the route layer (defense in depth on top of the service check).
func (rt *Router) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	r.With(authz.RequirePermission(authzSvc, "content.wiki")).Group(func(r chi.Router) {
		r.Get("/api/wiki/spaces", rt.handler.ListSpaces)
		r.Post("/api/wiki/spaces", rt.handler.CreateSpace)
		r.Get("/api/wiki/spaces/{slug}", rt.handler.GetSpace)
		r.Patch("/api/wiki/spaces/{id}", rt.handler.UpdateSpace)
		r.With(middleware.RequireOrgRole(rt.pool, middleware.RoleOwner, middleware.RoleAdmin)).Delete("/api/wiki/spaces/{id}", rt.handler.DeleteSpace)

		r.Get("/api/wiki/spaces/{spaceId}/pages", rt.handler.GetPageTree)
		r.Post("/api/wiki/spaces/{spaceId}/pages", rt.handler.CreatePage)

		r.Get("/api/wiki/pages/{id}", rt.handler.GetPage)
		r.Patch("/api/wiki/pages/{id}", rt.handler.UpdatePage)
		r.Delete("/api/wiki/pages/{id}", rt.handler.DeletePage)
		r.Post("/api/wiki/pages/{id}/move", rt.handler.MovePage)

		r.Get("/api/wiki/pages/{id}/versions", rt.handler.ListVersions)
		r.Get("/api/wiki/pages/{id}/versions/{version}", rt.handler.GetVersion)
		r.Post("/api/wiki/pages/{id}/versions/{version}/restore", rt.handler.RestoreVersion)

		r.Get("/api/wiki/pages/{id}/comments", rt.handler.ListComments)
		r.Post("/api/wiki/pages/{id}/comments", rt.handler.CreateComment)
		r.Patch("/api/wiki/comments/{id}", rt.handler.UpdateComment)
		r.Delete("/api/wiki/comments/{id}", rt.handler.DeleteComment)

		r.Get("/api/wiki/templates", rt.handler.ListTemplates)
		r.Post("/api/wiki/templates", rt.handler.CreateTemplate)
		r.Delete("/api/wiki/templates/{id}", rt.handler.DeleteTemplate)

		r.Get("/api/wiki/search", rt.handler.Search)
	})
}
