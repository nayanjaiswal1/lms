package main

import (
	"context"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/ratelimit"
	"github.com/redis/go-redis/v9"
)

const (
	// wsReadLimitBytes caps a single WebSocket message in either direction
	// (audit M-21). Terminal keystrokes and ttyd frames are far smaller.
	wsReadLimitBytes = 1 << 20
	// maxConnsPerUser bounds concurrent terminal relays per user across all
	// proxy replicas (audit M-21).
	maxConnsPerUser = 5
)

// parseAllowedOrigins splits a comma-separated origin list, dropping blanks
// and trailing slashes.
func parseAllowedOrigins(csv string) []string {
	var out []string
	for _, o := range strings.Split(csv, ",") {
		if o = strings.TrimRight(strings.TrimSpace(o), "/"); o != "" {
			out = append(out, strings.ToLower(o))
		}
	}
	return out
}

// originAllowed implements the upgrader's CheckOrigin (audit M-19). A request
// with no Origin header is a non-browser client and is allowed (the signed
// session token still gates it); a browser Origin must be on the allowlist,
// so an empty allowlist rejects every browser origin (fail closed).
func originAllowed(r *http.Request, allowed []string) bool {
	origin := r.Header.Get("Origin")
	if origin == "" {
		return true
	}
	u, err := url.Parse(origin)
	if err != nil || u.Scheme == "" || u.Host == "" {
		return false
	}
	norm := strings.ToLower(u.Scheme + "://" + u.Host)
	for _, a := range allowed {
		if a == norm {
			return true
		}
	}
	return false
}

// connLeaseTTL bounds how long a crashed replica can hold terminal slots; live
// relays renew their lease every connLeaseTTL/3.
const connLeaseTTL = 30 * time.Second

// connLimiter caps live terminal relays per user across ALL labproxy replicas
// via the shared Redis semaphore (leases lapse if a replica dies).
type connLimiter struct {
	sem *ratelimit.Semaphore
}

func newConnLimiter(rdb *redis.Client) *connLimiter {
	return &connLimiter{sem: ratelimit.NewSemaphore(rdb)}
}

// acquire reserves a slot for userID. A nil lease with nil error means the cap
// is reached; callers must Release a non-nil lease.
func (l *connLimiter) acquire(ctx context.Context, userID string) (*ratelimit.Lease, error) {
	return l.sem.TryAcquire(ctx, "labproxy:conns:"+userID, maxConnsPerUser, connLeaseTTL)
}
