package middleware

import (
	"net/http"
	"time"

	"github.com/mindforge/backend/internal/httputil"
	"github.com/redis/go-redis/v9"
)

// RateLimit returns a middleware that enforces a fixed-window request limit
// per client IP per URL path bucket using Redis as shared backing store.
// max is the maximum number of requests allowed within window.
// The middleware fails open: if Redis is unavailable, all requests are allowed
// through so that a Redis outage does not lock users out.
func RateLimit(rdb *redis.Client, max int, window time.Duration) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := r.Context()
			key := "ratelimit:" + r.URL.Path + ":" + clientIP(r)

			count, err := rdb.Incr(ctx, key).Result()
			if err != nil {
				next.ServeHTTP(w, r)
				return
			}

			if count == 1 {
				if err := rdb.Expire(ctx, key, window).Err(); err != nil {
					// Expiry failed — the key has no TTL; delete it to avoid a
					// permanent counter, then fail open so the request proceeds.
					_ = rdb.Del(ctx, key).Err()
					next.ServeHTTP(w, r)
					return
				}
			}

			if count > int64(max) {
				httputil.WriteError(w, http.StatusTooManyRequests, "Too many requests. Please try again later.")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// clientIP extracts the client IP from r.RemoteAddr, stripping the port.
// chi's RealIP middleware normalises RemoteAddr before this runs so the value
// is always a bare IP or host:port pair.
func clientIP(r *http.Request) string {
	addr := r.RemoteAddr
	for i := len(addr) - 1; i >= 0; i-- {
		if addr[i] == ':' {
			return addr[:i]
		}
	}
	return addr
}
