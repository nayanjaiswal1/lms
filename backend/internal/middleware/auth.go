package middleware

import (
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/session"
)

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
			cookie, err := r.Cookie("access_token")
			if err != nil {
				httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
				return
			}

			claims, err := auth.ParseToken(cfg, cookie.Value)
			if err != nil {
				httputil.WriteError(w, http.StatusUnauthorized, "Invalid or expired session.")
				return
			}

			if cache.IsJTIBlocked(r.Context(), claims.ID) {
				httputil.WriteError(w, http.StatusUnauthorized, "Session has been revoked.")
				return
			}

			if err := cache.CheckVersion(r.Context(), claims.UserID, claims.SessionVersion); err != nil {
				httputil.WriteError(w, http.StatusUnauthorized, "Session has been revoked.")
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
