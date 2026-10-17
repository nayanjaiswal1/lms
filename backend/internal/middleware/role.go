package middleware

import (
	"context"
	"errors"
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool" //nolint:staticcheck // shared pool type

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Org-level roles, mirrored from the org_members.role CHECK constraint.
// Centralised here so route guards never compare bare strings.
const (
	RoleOwner      = "owner"
	RoleAdmin      = "admin"
	RoleInstructor = "instructor"
	RoleMentor     = "mentor"
	RoleLearner    = "learner"
)

// OrgRoleRank orders org_members.role labels for "may the actor manage or
// grant this role" checks. The single copy shared by orgs and authz.
var OrgRoleRank = map[string]int{
	RoleOwner:      5,
	RoleAdmin:      4,
	RoleMentor:     3,
	RoleInstructor: 2,
	RoleLearner:    1,
}

// Platform-level roles, mirrored from the users.platform_role CHECK constraint.
const (
	PlatformRoleSuperAdmin = "super_admin"
	PlatformRoleUser       = "user"
)

// LiveOrgRole looks up userID's current org_members.role label in orgID
// directly from the database, never from the JWT's org_role claim (minted at
// sign-in, it outlives a demotion). Authorization is permission-code based
// (authz.RequirePermission); this label is only for membership checks,
// ownership and the OrgRoleRank grant-ceiling rules.
// Reports false when the user is not an active member of orgID.
func LiveOrgRole(ctx context.Context, pool *pgxpool.Pool, userID, orgID string) (string, bool) {
	if orgID == "" {
		return "", false
	}

	var role string
	err := pool.QueryRow(ctx,
		`SELECT role FROM org_members
		 WHERE org_id = $1 AND user_id = $2 AND status = 'active'`,
		orgID, userID,
	).Scan(&role)
	if err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			slog.ErrorContext(ctx, "LiveOrgRole: db query failed",
				"org_id", orgID, "user_id", userID, "err", err)
		}
		return "", false
	}
	return role, true
}

// IsPlatformSuperAdmin reports whether userID currently holds the super_admin
// platform role, looked up live (the role is not in the JWT).
func IsPlatformSuperAdmin(ctx context.Context, pool *pgxpool.Pool, userID string) bool {
	var role string
	if err := pool.QueryRow(ctx, `SELECT platform_role FROM users WHERE id = $1`, userID).Scan(&role); err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			slog.ErrorContext(ctx, "IsPlatformSuperAdmin: db query failed", "user_id", userID, "err", err)
		}
		return false
	}
	return role == PlatformRoleSuperAdmin
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
