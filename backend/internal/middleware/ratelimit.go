package middleware

import (
	"fmt"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/ratelimit"
	"github.com/redis/go-redis/v9"
)

// RateLimit returns a middleware that enforces a sliding-window request limit
// per client IP per URL path.
//
// The window itself lives in internal/ratelimit so auth handlers can apply a
// second, account-scoped limit on the same request without an import cycle.
// The IP limit alone is not sufficient for credential-stuffing defence: every
// browser-facing auth call reaches this service from the Next.js server, so a
// great many users share one source address (see RealIP and
// auth.Handler.limitByAccount).
//
// A Retry-After header is always included on 429 responses.
func RateLimit(rdb *redis.Client, max int, window time.Duration) func(http.Handler) http.Handler {
	limiter := ratelimit.New(rdb)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := "rl:" + r.URL.Path + ":" + clientIP(r)
			if allowed, retryAfter := limiter.Allow(r.Context(), key, max, window); !allowed {
				w.Header().Set("Retry-After", fmt.Sprintf("%d", ratelimit.RetryAfterSeconds(retryAfter)))
				httputil.WriteError(w, http.StatusTooManyRequests, "Too many requests. Please try again later.")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// clientIP extracts the client IP from r.RemoteAddr, stripping the port.
// RealIP has already replaced RemoteAddr with the forwarded client address when
// the request arrived through a trusted proxy.
func clientIP(r *http.Request) string {
	if host, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		return host
	}
	return strings.Trim(r.RemoteAddr, "[]")
}
