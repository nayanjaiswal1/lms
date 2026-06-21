package middleware

import (
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/session"
)

// RequireAuth validates the access_token cookie and injects Claims into ctx.
// Checks (in order): cookie present → JWT valid → JTI not blocked →
// session_version matches DB value. Returns 401 on any failure.
func RequireAuth(cfg *config.Config, cache *session.Cache) func(http.Handler) http.Handler {
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

			ctx := auth.SetClaims(r.Context(), claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
