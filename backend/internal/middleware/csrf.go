package middleware

import (
	"crypto/subtle"
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
)

// RequireCSRF enforces a signed double-submit cookie CSRF pattern.
// It expects the X-CSRF-Token request header to match the csrf_token cookie AND
// the value to carry a valid HMAC signature (see auth.CreateCSRFToken), so a
// csrf_token cookie injected by an attacker — which cannot be validly signed —
// is rejected. Safe methods (GET, HEAD, OPTIONS) are exempted.
// Apply only to authenticated mutation routes — public endpoints do not have
// a csrf_token cookie yet and must not be guarded here.
func RequireCSRF(cfg *config.Config) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet, http.MethodHead, http.MethodOptions:
				next.ServeHTTP(w, r)
				return
			}

			cookie, err := r.Cookie("csrf_token")
			if err != nil || cookie.Value == "" {
				httputil.WriteError(w, http.StatusForbidden, "CSRF token missing.")
				return
			}

			headerToken := r.Header.Get("X-CSRF-Token")

			// Both tokens must carry a valid server-issued HMAC signature, and they
			// must match each other. All three comparisons are constant-time to
			// prevent timing side-channels; a plain string == is deliberately avoided.
			if !auth.ValidCSRFToken(cfg, cookie.Value) ||
				!auth.ValidCSRFToken(cfg, headerToken) ||
				subtle.ConstantTimeCompare([]byte(headerToken), []byte(cookie.Value)) != 1 {
				httputil.WriteError(w, http.StatusForbidden, "CSRF token invalid.")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
