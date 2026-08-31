package middleware

import (
	"fmt"
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/session"
)

// validateSession runs the cookie → JWT → JTI-block → session-version checks
// shared by RequireAuth and OptionalAuth. Returns the validated claims, or an
// error describing which check failed (never written to the response here —
// callers decide whether that's fatal).
func validateSession(r *http.Request, cfg *config.Config, cache *session.Cache) (*auth.Claims, error) {
	cookie, err := r.Cookie("access_token")
	if err != nil {
		return nil, fmt.Errorf("no access_token cookie: %w", err)
	}

	claims, err := auth.ParseToken(cfg, cookie.Value)
	if err != nil {
		return nil, fmt.Errorf("invalid or expired token: %w", err)
	}

	if cache.IsJTIBlocked(r.Context(), claims.ID) {
		return nil, fmt.Errorf("session revoked (blocked jti)")
	}

	if err := cache.CheckVersion(r.Context(), claims.UserID, claims.SessionVersion); err != nil {
		return nil, fmt.Errorf("session revoked (version mismatch): %w", err)
	}

	return claims, nil
}

// RequireAuth validates the access_token cookie and injects Claims into ctx.
// Checks (in order): cookie present → JWT valid → JTI not blocked →
// session_version matches DB value. Returns 401 on any failure.
//
// Also touches users.last_active_at — the WHERE clause skips the write
// unless the stored value is stale by more than 5 minutes, so a user
// clicking around the app doesn't turn every request into a write. Best
// effort: a failed touch is logged but never fails the request, since
// presence tracking isn't worth rejecting an otherwise-valid session over.
func RequireAuth(cfg *config.Config, cache *session.Cache, pool *pgxpool.Pool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, err := validateSession(r, cfg, cache)
			if err != nil {
				httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
				return
			}

			if _, err := pool.Exec(r.Context(),
				`UPDATE users SET last_active_at = now()
				 WHERE id = $1 AND (last_active_at IS NULL OR last_active_at < now() - interval '5 minutes')`,
				claims.UserID,
			); err != nil {
				slog.ErrorContext(r.Context(), "RequireAuth: failed to touch last_active_at",
					"user_id", claims.UserID,
					"err", err,
				)
			}

			ctx := auth.SetClaims(r.Context(), claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// OptionalAuth validates the access_token cookie the same way RequireAuth
// does, but never rejects the request — a missing, invalid, or revoked
// cookie just means the request proceeds with no Claims in ctx. For routes
// that serve both an owner's full view and a public read-only view from the
// same URL (e.g. a roadmap that's either yours or shared is_public), so the
// handler itself branches on auth.GetClaims instead of the URL carrying a
// separate "public" path.
func OptionalAuth(cfg *config.Config, cache *session.Cache) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, err := validateSession(r, cfg, cache)
			if err != nil {
				next.ServeHTTP(w, r)
				return
			}
			ctx := auth.SetClaims(r.Context(), claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
