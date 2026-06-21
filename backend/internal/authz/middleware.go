package authz

import (
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// RequirePermission returns middleware that allows the request only when the
// authenticated user holds ALL of the given permission codes within their tenant.
// Responds 401 if no claims are present, 403 if a required code is missing,
// and 500 on an unexpected service error.
func RequirePermission(svc *Service, codes ...string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.GetClaims(r.Context())
			if !ok {
				httputil.WriteError(w, http.StatusUnauthorized, "authentication required")
				return
			}

			allowed, err := svc.HasAllPermissions(r.Context(), claims.UserID, claims.OrgID, codes...)
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

// RequireAnyPermission returns middleware that allows the request when the
// authenticated user holds at least one of the given permission codes within
// their tenant.
// Responds 401 if no claims are present, 403 if none of the codes are held,
// and 500 on an unexpected service error.
func RequireAnyPermission(svc *Service, codes ...string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.GetClaims(r.Context())
			if !ok {
				httputil.WriteError(w, http.StatusUnauthorized, "authentication required")
				return
			}

			allowed, err := svc.HasAnyPermission(r.Context(), claims.UserID, claims.OrgID, codes...)
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
