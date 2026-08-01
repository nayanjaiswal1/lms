package middleware

import (
	"log/slog"
	"net"
	"net/http"
	"os"
	"strings"

	"github.com/mindforge/backend/internal/config"
)

// RealIP rewrites r.RemoteAddr to the client address reported by a forwarding
// header, but only when the immediate peer is inside one of the configured
// trusted proxy networks.
//
// This replaces chi's middleware.RealIP, which believes X-Forwarded-For from
// anyone. That is safe only when the service can be reached exclusively through
// a proxy that overwrites the header; if the service is reachable directly, an
// untrusted client can put an arbitrary value in X-Forwarded-For and mint an
// unlimited number of rate-limit buckets (see RateLimit, which keys on the
// client IP), defeating the auth rate limiter entirely.
//
// X-Forwarded-For is a comma-separated chain appended to by each hop. The
// right-most entry is the one written by our own trusted proxy, so we walk the
// chain from the right and take the first address that is not itself a trusted
// proxy — that is the furthest-out address our infrastructure can vouch for.
// Entries to the left of it were supplied by the client and are discarded.
func RealIP(cfg *config.Config) func(http.Handler) http.Handler {
	trusted := parseCIDRs(cfg.TrustedProxyCIDRs)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if ip := clientAddr(r, trusted); ip != "" {
				r.RemoteAddr = ip
			}
			next.ServeHTTP(w, r)
		})
	}
}

// clientAddr returns the address to treat as the client's, or "" to keep
// RemoteAddr as-is.
func clientAddr(r *http.Request, trusted []*net.IPNet) string {
	peer := net.ParseIP(hostOnly(r.RemoteAddr))
	if peer == nil || !inAny(peer, trusted) {
		// Direct connection from an untrusted peer — its own address is the
		// only trustworthy signal, whatever headers it chose to send.
		return ""
	}

	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		for i := len(parts) - 1; i >= 0; i-- {
			ip := net.ParseIP(strings.TrimSpace(parts[i]))
			if ip == nil {
				// A malformed entry means the chain can no longer be walked
				// reliably; stop rather than trusting anything further left.
				break
			}
			if !inAny(ip, trusted) {
				return ip.String()
			}
		}
	}

	if xr := strings.TrimSpace(r.Header.Get("X-Real-IP")); xr != "" {
		if ip := net.ParseIP(xr); ip != nil {
			return ip.String()
		}
	}

	return ""
}

func inAny(ip net.IP, nets []*net.IPNet) bool {
	for _, n := range nets {
		if n.Contains(ip) {
			return true
		}
	}
	return false
}

func parseCIDRs(raw []string) []*net.IPNet {
	nets := make([]*net.IPNet, 0, len(raw))
	for _, c := range raw {
		_, n, err := net.ParseCIDR(c)
		if err != nil {
			// config.Load already validates these, so reaching here means the
			// list was built by something that skipped validation.
			slog.Error("middleware: invalid trusted proxy CIDR", "cidr", c, "error", err)
			os.Exit(1)
		}
		nets = append(nets, n)
	}
	return nets
}

// hostOnly strips the :port from an address, tolerating a bare IP (including a
// bare IPv6 address, which SplitHostPort rejects).
func hostOnly(addr string) string {
	if h, _, err := net.SplitHostPort(addr); err == nil {
		return h
	}
	return strings.Trim(addr, "[]")
}
