package netguard

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"time"
)

// GuardedTransport returns an http.Transport whose DialContext rejects any
// address that resolves to a denylisted IP (see IsDenylisted) before the
// connection is made. This is the dial-time half of this app's SSRF
// defense — a request-time URL check alone can't close the gap, since a
// hostname's DNS answer can change between validation and the moment this
// transport actually dials it (TOCTOU / DNS rebinding). Shared by any client
// that dials a caller-supplied or admin-configured hostname: internal/gitlab
// (self-hosted GitLab instance URLs) and internal/captures (link captures).
func GuardedTransport(dialTimeout time.Duration) *http.Transport {
	dialer := &net.Dialer{Timeout: dialTimeout}
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.DialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
		host, port, err := net.SplitHostPort(addr)
		if err != nil {
			return nil, fmt.Errorf("netguard: parse dial address %q: %w", addr, err)
		}
		if ip := net.ParseIP(host); ip != nil {
			if IsDenylisted(ip) {
				return nil, fmt.Errorf("netguard: refusing to dial denylisted address %s", host)
			}
			return dialer.DialContext(ctx, network, addr)
		}
		// addr's host is still a hostname (net/http resolves via DialContext
		// itself rather than pre-resolving) — resolve it here so every IP it
		// could connect to is checked, then dial that specific IP directly
		// rather than re-resolving (which could yield a different, unchecked
		// answer under DNS rebinding).
		ips, err := net.DefaultResolver.LookupIP(ctx, "ip", host)
		if err != nil {
			return nil, fmt.Errorf("netguard: resolve %q: %w", host, err)
		}
		for _, ip := range ips {
			if IsDenylisted(ip) {
				continue
			}
			conn, dialErr := dialer.DialContext(ctx, network, net.JoinHostPort(ip.String(), port))
			if dialErr == nil {
				return conn, nil
			}
			err = dialErr
		}
		if err == nil {
			err = fmt.Errorf("netguard: all resolved addresses for %q are denylisted", host)
		}
		return nil, fmt.Errorf("netguard: dial %q: %w", host, err)
	}
	return transport
}
