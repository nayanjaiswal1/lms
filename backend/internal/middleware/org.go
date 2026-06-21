package middleware

import (
	"context"
	"errors"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type orgCtxKey int

const orgKey orgCtxKey = 0

// OrgCtx holds the resolved org context for the current request.
type OrgCtx struct {
	OrgID      string
	OrgStatus  string
	MemberID   string
	CallerRole string
}

// GetOrgCtx retrieves the OrgCtx injected by RequireOrgMember.
func GetOrgCtx(ctx context.Context) (*OrgCtx, bool) {
	v, ok := ctx.Value(orgKey).(*OrgCtx)
	return v, ok
}

// RequireOrgMember validates that the authenticated user is an active member of
// the target organization. It must be chained after RequireAuth.
//
// Org resolution order:
//  1. Chi URL param {id} — used for /orgs/{id}/... routes.
//  2. X-Org-Id header.
//  3. OrgID embedded in the JWT claims.
func RequireOrgMember(pool *pgxpool.Pool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := auth.GetClaims(r.Context())
			if !ok {
				httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
				return
			}

			// Resolve the target org ID.
			orgID := chi.URLParam(r, "id")
			if orgID == "" {
				orgID = r.Header.Get("X-Org-Id")
			}
			if orgID == "" {
				orgID = claims.OrgID
			}
			if orgID == "" {
				httputil.WriteError(w, http.StatusBadRequest, "No organization context provided.")
				return
			}

			var (
				resolvedOrgID  string
				orgStatus      string
				memberID       string
				callerRole     string
			)

			err := pool.QueryRow(r.Context(),
				`SELECT o.id, o.status, om.id, om.role
				 FROM organizations o
				 JOIN org_members om ON o.id = om.org_id
				 WHERE o.id = $1 AND om.user_id = $2 AND om.status = 'active'`,
				orgID, claims.UserID,
			).Scan(&resolvedOrgID, &orgStatus, &memberID, &callerRole)
			if err != nil {
				if errors.Is(err, pgx.ErrNoRows) {
					httputil.WriteError(w, http.StatusForbidden, "Not a member of this organization.")
					return
				}
				slog.ErrorContext(r.Context(), "RequireOrgMember: db query failed",
					"org_id", orgID,
					"user_id", claims.UserID,
					"err", err,
				)
				httputil.WriteError(w, http.StatusInternalServerError, "Failed to verify organization membership.")
				return
			}

			ctx := context.WithValue(r.Context(), orgKey, &OrgCtx{
				OrgID:      resolvedOrgID,
				OrgStatus:  orgStatus,
				MemberID:   memberID,
				CallerRole: callerRole,
			})
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// OrgStatusGate returns middleware that allows the request only when the org's
// current status is one of allowedStatuses. It must be chained after
// RequireOrgMember, which populates OrgCtx.
//
// If allowedStatuses is empty it defaults to ["active"].
func OrgStatusGate(allowedStatuses ...string) func(http.Handler) http.Handler {
	if len(allowedStatuses) == 0 {
		allowedStatuses = []string{"active"}
	}

	permitted := make(map[string]struct{}, len(allowedStatuses))
	for _, s := range allowedStatuses {
		permitted[s] = struct{}{}
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			orgCtx, ok := GetOrgCtx(r.Context())
			if !ok {
				// Misconfigured middleware chain — RequireOrgMember was not applied.
				slog.ErrorContext(r.Context(), "OrgStatusGate: OrgCtx missing from context; ensure RequireOrgMember is applied first")
				httputil.WriteError(w, http.StatusInternalServerError, "Internal server error.")
				return
			}

			if _, allowed := permitted[orgCtx.OrgStatus]; !allowed {
				var msg string
				switch orgCtx.OrgStatus {
				case "archived":
					msg = "This organization is archived."
				case "suspended":
					msg = "This organization is suspended."
				case "pending_verification":
					msg = "Please verify your organization email first."
				case "onboarding":
					msg = "Please complete organization onboarding first."
				default:
					msg = "Organization is not available."
				}
				httputil.WriteError(w, http.StatusForbidden, msg)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
