package wiki

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/httputil"
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
	return &Router{handler: newHandler(service, pool), pool: pool}
}

// requireWikiOrProjectAccess admits a caller who either holds content.wiki
// (the normal RBAC gate the frontend's nav entry and <AccessGate> already
// check) or is an active member of at least one Project Workspace in the
// org — a project-scoped wiki space (02 §7.0) is reached by project role,
// not by content.wiki, and many project members (e.g. an org "learner") are
// never granted that permission. This only gets the request past the front
// gate; the service's own per-space ACL (canReadSpace/canEditOrDeletePage)
// still decides what the caller may actually see or change on any given
// space, project-scoped or not.
func requireWikiOrProjectAccess(authzSvc *authz.Service, pool *pgxpool.Pool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.GetClaims(r.Context())
			if !ok {
				httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
				return
			}
			if has, err := authzSvc.HasPermission(r.Context(), claims.UserID, claims.OrgID, "content.wiki"); err == nil && has {
				next.ServeHTTP(w, r)
				return
			}
			var member bool
			err := pool.QueryRow(r.Context(),
				`SELECT EXISTS(SELECT 1 FROM project_members pm JOIN workspace_projects p ON p.id = pm.project_id
				  WHERE pm.user_id = $1 AND pm.status IN ('active','invited') AND p.org_id = $2)`,
				claims.UserID, claims.OrgID,
			).Scan(&member)
			if err == nil && member {
				next.ServeHTTP(w, r)
				return
			}
			httputil.WriteError(w, http.StatusForbidden, "You do not have permission to perform this action.")
		})
	}
}

// RegisterRoutes mounts wiki endpoints under the caller's authenticated
// group, gated on content.wiki or active project-workspace membership (see
// requireWikiOrProjectAccess) — enforced again here since UI gates are UX,
// not security. Space deletion is additionally restricted to org admins at
// the route layer (defense in depth on top of the service check).
func (rt *Router) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	r.With(requireWikiOrProjectAccess(authzSvc, rt.pool)).Group(func(r chi.Router) {
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

		// OKF (github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf)
		// export/import — same pages, same RBAC, a markdown+frontmatter
		// representation instead of raw TipTap JSON.
		r.Get("/api/wiki/pages/{id}/okf", rt.handler.GetPageOKF)
		r.Put("/api/wiki/pages/{id}/okf", rt.handler.UpdatePageOKF)
		r.Get("/api/wiki/spaces/{slug}/okf", rt.handler.GetSpaceOKF)

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
