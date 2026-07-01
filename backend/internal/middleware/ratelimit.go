package middleware

import (
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/mindforge/backend/internal/httputil"
	"github.com/redis/go-redis/v9"
)

// slidingWindowScript atomically implements a sliding-window rate limiter using
// a Redis sorted set. It removes expired entries, checks the current count, and
// either admits the request (ZADD + PEXPIRE) or rejects it.
//
// KEYS[1]  = rate limit key
// ARGV[1]  = current Unix time in milliseconds
// ARGV[2]  = window size in milliseconds
// ARGV[3]  = max requests per window
// ARGV[4]  = unique member (nanosecond timestamp) — prevents score collisions
//
// Returns 0 if allowed, 1 if rate-limited.
const slidingWindowScript = `
local key    = KEYS[1]
local now    = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local max    = tonumber(ARGV[3])
local member = ARGV[4]
local cutoff = now - window
redis.call('ZREMRANGEBYSCORE', key, 0, cutoff)
local count = redis.call('ZCARD', key)
if count < max then
    redis.call('ZADD', key, now, member)
    redis.call('PEXPIRE', key, window)
    return 0
end
return 1
`

// inMemorySlidingWindow is a goroutine-safe in-process sliding window used as
// the fallback when Redis is unreachable. It provides per-replica enforcement
// rather than global, but preserves protection through Redis outages.
type inMemorySlidingWindow struct {
	mu      sync.Mutex
	buckets map[string][]int64 // key -> Unix ms timestamps, ascending
}

func newInMemorySlidingWindow() *inMemorySlidingWindow {
	return &inMemorySlidingWindow{buckets: make(map[string][]int64)}
}

func (s *inMemorySlidingWindow) allow(key string, max int, windowMs int64) bool {
	now := time.Now().UnixMilli()
	cutoff := now - windowMs
	s.mu.Lock()
	defer s.mu.Unlock()
	ts := s.buckets[key]
	// Evict entries that have fallen outside the window.
	i := 0
	for i < len(ts) && ts[i] <= cutoff {
		i++
	}
	ts = ts[i:]
	if len(ts) >= max {
		s.buckets[key] = ts
		return false
	}
	s.buckets[key] = append(ts, now)
	return true
}

// RateLimit returns a middleware that enforces a sliding-window request limit
// per client IP per URL path.
//
// Redis sorted sets + a Lua script provide atomic, distributed enforcement.
// When Redis is unreachable the middleware falls back to an in-process sliding
// window so a Redis outage degrades gracefully (per-replica accounting) rather
// than bypassing rate limiting entirely.
//
// A Retry-After header is always included on 429 responses.
func RateLimit(rdb *redis.Client, max int, window time.Duration) func(http.Handler) http.Handler {
	script := redis.NewScript(slidingWindowScript)
	fallback := newInMemorySlidingWindow()
	windowMs := window.Milliseconds()
	retryAfter := fmt.Sprintf("%d", int(window.Seconds()))

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := r.Context()
			key := "rl:" + r.URL.Path + ":" + clientIP(r)
			now := time.Now()
			// Nanosecond precision as member prevents score collisions under bursts.
			member := fmt.Sprintf("%d", now.UnixNano())

			result, err := script.Run(ctx, rdb, []string{key},
				now.UnixMilli(), windowMs, max, member,
			).Int64()

			if err != nil {
				// Redis unreachable — use in-process fallback.
				if !fallback.allow(key, max, windowMs) {
					w.Header().Set("Retry-After", retryAfter)
					httputil.WriteError(w, http.StatusTooManyRequests, "Too many requests. Please try again later.")
					return
				}
				next.ServeHTTP(w, r)
				return
			}

			if result == 1 {
				w.Header().Set("Retry-After", retryAfter)
				httputil.WriteError(w, http.StatusTooManyRequests, "Too many requests. Please try again later.")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// clientIP extracts the real client IP from r.RemoteAddr, stripping the port.
// chi's RealIP middleware normalises RemoteAddr before this runs so the value
// is always a bare IP (IPv4 or IPv6) or host:port pair.
func clientIP(r *http.Request) string {
	addr := r.RemoteAddr
	for i := len(addr) - 1; i >= 0; i-- {
		if addr[i] == ':' {
			return addr[:i]
		}
	}
	return addr
}
