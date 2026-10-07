package middleware

import (
	"crypto/subtle"
	"net/http"
	"strings"

	"github.com/mindforge/backend/internal/config"
)

// RequireMetricsToken guards the Prometheus endpoint. With cfg.MetricsToken
// set, callers must present it as a bearer token. With it unset the endpoint is
// open outside production and answers 404 in production, so a missing secret
// can never leave metrics public.
func RequireMetricsToken(cfg *config.Config, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if cfg.MetricsToken == "" {
			if cfg.Env == "production" {
				http.NotFound(w, r)
				return
			}
			next.ServeHTTP(w, r)
			return
		}
		got := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if subtle.ConstantTimeCompare([]byte(got), []byte(cfg.MetricsToken)) != 1 {
			w.Header().Set("WWW-Authenticate", "Bearer")
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}
