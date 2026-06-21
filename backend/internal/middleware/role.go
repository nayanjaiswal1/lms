package middleware

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Org-level roles, mirrored from the org_members.role CHECK constraint.
// Centralised here so route guards never compare bare strings.
const (
	RoleAdmin      = "admin"
	RoleInstructor = "instructor"
	RoleMentor     = "mentor"
)

// Platform-level roles, mirrored from the users.platform_role CHECK constraint.
const (
	PlatformRoleSuperAdmin = "super_admin"
	PlatformRoleUser       = "user"
)

// RequireOrgRole returns middleware that allows the request only if the
// authenticated user's org role is one of the permitted roles. It must be
// chained after RequireAuth, which populates the Claims in context.
func RequireOrgRole(allowed ...string) func(http.Handler) http.Handler {
	permitted := make(map[string]struct{}, len(allowed))
	for _, role := range allowed {
		permitted[role] = struct{}{}
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.GetClaims(r.Context())
			if !ok {
				httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
				return
			}
			if _, allowed := permitted[claims.OrgRole]; !allowed {
				httputil.WriteError(w, http.StatusForbidden, "You do not have permission to perform this action.")
				return
			}
			next.ServeHTTP(w, r.WithContext(r.Context()))
		})
	}
}

// RequirePlatformRole returns middleware that allows the request only if the
// authenticated user's platform_role (stored in the users table) is one of the
// permitted roles. It must be chained after RequireAuth. Because platform_role
// is not embedded in the JWT, this middleware performs a single DB lookup.
func RequirePlatformRole(pool *pgxpool.Pool, allowed ...string) func(http.Handler) http.Handler {
	permitted := make(map[string]struct{}, len(allowed))
	for _, role := range allowed {
		permitted[role] = struct{}{}
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.GetClaims(r.Context())
			if !ok {
				httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
				return
			}

			var platformRole string
			err := pool.QueryRow(r.Context(),
				`SELECT platform_role FROM users WHERE id = $1`,
				claims.UserID,
			).Scan(&platformRole)
			if err != nil {
				if errors.Is(err, pgx.ErrNoRows) {
					httputil.WriteError(w, http.StatusUnauthorized, "User not found.")
					return
				}
				slog.ErrorContext(r.Context(), "RequirePlatformRole: db query failed",
					"user_id", claims.UserID,
					"err", err,
				)
				httputil.WriteError(w, http.StatusInternalServerError, "Failed to verify platform role.")
				return
			}

			if _, ok := permitted[platformRole]; !ok {
				httputil.WriteError(w, http.StatusForbidden, "You do not have permission to perform this action.")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
