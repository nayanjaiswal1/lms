package main

import (
	"net/http"
	"net/url"
	"strings"
	"sync"
)

const (
	// wsReadLimitBytes caps a single WebSocket message in either direction
	// (audit M-21). Terminal keystrokes and ttyd frames are far smaller.
	wsReadLimitBytes = 1 << 20
	// maxConnsPerUser bounds concurrent terminal relays per user per proxy
	// instance (audit M-21).
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

// connLimiter counts live relays per user.
type connLimiter struct {
	mu sync.Mutex
	n  map[string]int
}

// acquire reserves a slot for userID, reporting false when at the cap.
func (l *connLimiter) acquire(userID string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.n == nil {
		l.n = map[string]int{}
	}
	if l.n[userID] >= maxConnsPerUser {
		return false
	}
	l.n[userID]++
	return true
}

func (l *connLimiter) release(userID string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.n[userID] <= 1 {
		delete(l.n, userID)
		return
	}
	l.n[userID]--
}
