package authz

import (
	"context"
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/middleware"
)

// permCheck is HasAllPermissions or HasAnyPermission.
type permCheck func(ctx context.Context, userID, orgID string, codes ...string) (bool, error)

// RequirePermission returns middleware that allows the request only when the
// authenticated user holds ALL of the given permission codes in their JWT org
// and, when RequireOrgMember resolved a different org earlier in the chain,
// in that org too.
// Responds 401 if no claims are present, 403 if a required code is missing,
// and 500 on an unexpected service error.
func RequirePermission(svc *Service, codes ...string) func(http.Handler) http.Handler {
	return guard(svc.HasAllPermissions, codes)
}

// RequireAnyPermission is RequirePermission's at-least-one-of variant: each
// checked org must grant at least one of codes.
func RequireAnyPermission(svc *Service, codes ...string) func(http.Handler) http.Handler {
	return guard(svc.HasAnyPermission, codes)
}

// RequireOrgCtxPermission is for routes whose handlers act only on the org
// RequireOrgMember resolved ({id} URL param or X-Org-Id), never on the JWT
// org — e.g. /api/orgs/{id}/... settings. The caller must hold code in that
// org; their JWT org is irrelevant. Must be chained after RequireOrgMember.
func RequireOrgCtxPermission(svc *Service, code string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.GetClaims(r.Context())
			if !ok {
				httputil.WriteError(w, http.StatusUnauthorized, "authentication required")
				return
			}
			orgCtx, ok := middleware.GetOrgCtx(r.Context())
			if !ok {
				httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
				return
			}
			allowed, err := svc.HasPermission(r.Context(), claims.UserID, orgCtx.OrgID, code)
			if err != nil {
				httputil.WriteError(w, http.StatusInternalServerError, "permission check failed")
				return
			}
			if !allowed {
				httputil.WriteError(w, http.StatusForbidden, "insufficient permissions")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func guard(check permCheck, codes []string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.GetClaims(r.Context())
			if !ok {
				httputil.WriteError(w, http.StatusUnauthorized, "authentication required")
				return
			}

			allowed, err := check(r.Context(), claims.UserID, claims.OrgID, codes...)
			// When RequireOrgMember resolved a different org (URL {id} or
			// X-Org-Id), handlers may act on that org, so the permission must
			// hold there as well; otherwise an admin of org A could operate on
			// org B where they hold less.
			if err == nil && allowed {
				if orgCtx, ok := middleware.GetOrgCtx(r.Context()); ok && orgCtx.OrgID != claims.OrgID {
					allowed, err = check(r.Context(), claims.UserID, orgCtx.OrgID, codes...)
				}
			}
			if err != nil {
				httputil.WriteError(w, http.StatusInternalServerError, "permission check failed")
				return
			}
			if !allowed {
				httputil.WriteError(w, http.StatusForbidden, "insufficient permissions")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
