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
)

// Platform-level roles, mirrored from the users.platform_role CHECK constraint.
const (
	PlatformRoleSuperAdmin = "super_admin"
	PlatformRoleUser       = "user"
)

// RequireOrgRole returns middleware that allows the request only if the
// authenticated user's role in the active org is one of the permitted roles.
// It must be chained after RequireAuth, which populates the Claims in context.
//
// The role is read from the database, not from the JWT's org_role claim. The
// claim is minted at sign-in and lives for ACCESS_TOKEN_TTL, so authorizing
// against it meant a demoted admin kept admin on every route guarded here until
// their token happened to expire — while RequireOrgMember, sitting in the same
// chains, was already reading the live value. Two answers to "what may this
// user do", and the guard used the stale one.
//
// When RequireOrgMember ran earlier in the chain it has already performed this
// exact lookup, so its result is reused rather than queried a second time.
func RequireOrgRole(pool *pgxpool.Pool, allowed ...string) func(http.Handler) http.Handler {
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

			role, ok := liveOrgRole(r, pool, claims)
			if !ok {
				httputil.WriteError(w, http.StatusForbidden, "Not a member of this organization.")
				return
			}

			if _, allowed := permitted[role]; !allowed {
				httputil.WriteError(w, http.StatusForbidden, "You do not have permission to perform this action.")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// liveOrgRole resolves the caller's current role in their JWT's org
// (claims.OrgID), preferring the value RequireOrgMember already resolved.
// Reports false when the user is not an active member of that org.
//
// The org is always claims.OrgID, never the X-Org-Id request header: the
// header is caller-controlled, and every handler downstream of this
// authorization check writes using claims.OrgID, not the header. Trusting
// the header here would let a caller pass the role check for an org they
// pick (e.g. one they made themselves an admin of) while every write still
// lands in their real JWT org — a cross-org privilege escalation.
// RequireOrgMember is a separate, legitimate multi-org-switching flow and is
// free to keep reading the header; this function is only for authorization
// decisions.
func liveOrgRole(r *http.Request, pool *pgxpool.Pool, claims *auth.Claims) (string, bool) {
	if orgCtx, ok := GetOrgCtx(r.Context()); ok {
		return orgCtx.CallerRole, true
	}
	if claims.OrgID == "" {
		return "", false
	}
	return LiveOrgRole(r.Context(), pool, claims.UserID, claims.OrgID)
}

// LiveOrgRole looks up userID's current role in orgID directly from the
// database. Exported so handlers that authorize outside the RequireOrgRole
// middleware chain — e.g. comparing against a role instead of gating the
// whole route — can use the same live lookup instead of reading the stale
// claims.OrgRole JWT claim (see the rationale on RequireOrgRole above).
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
