package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/mindforge/backend/internal/config"
)

// The auth rate limiter keys on the address RealIP leaves in RemoteAddr, so a
// client that can steer this value can mint an unlimited number of buckets.
// These cases pin the trust boundary.
func TestRealIPTrustBoundary(t *testing.T) {
	cfg := &config.Config{TrustedProxyCIDRs: []string{"10.0.0.0/8", "127.0.0.1/32"}}

	tests := []struct {
		name       string
		remoteAddr string
		xff        string
		xRealIP    string
		want       string
	}{
		{
			name:       "untrusted peer cannot forge XFF",
			remoteAddr: "203.0.113.9:5000",
			xff:        "1.2.3.4",
			want:       "203.0.113.9:5000", // unchanged
		},
		{
			name:       "untrusted peer cannot forge X-Real-IP",
			remoteAddr: "203.0.113.9:5000",
			xRealIP:    "1.2.3.4",
			want:       "203.0.113.9:5000",
		},
		{
			name:       "trusted proxy forwards the client address",
			remoteAddr: "10.1.2.3:5000",
			xff:        "198.51.100.7",
			want:       "198.51.100.7",
		},
		{
			name:       "client-supplied entries left of our proxy are discarded",
			remoteAddr: "10.1.2.3:5000",
			xff:        "9.9.9.9, 198.51.100.7, 10.0.0.5",
			want:       "198.51.100.7",
		},
		{
			name:       "trusted peer with no forwarding header keeps RemoteAddr",
			remoteAddr: "10.1.2.3:5000",
			want:       "10.1.2.3:5000",
		},
		{
			name:       "trusted peer falls back to X-Real-IP",
			remoteAddr: "127.0.0.1:5000",
			xRealIP:    "198.51.100.7",
			want:       "198.51.100.7",
		},
		{
			name:       "malformed XFF entry stops the walk",
			remoteAddr: "10.1.2.3:5000",
			xff:        "198.51.100.7, not-an-ip",
			want:       "10.1.2.3:5000",
		},
		{
			name:       "an all-trusted chain yields no client address",
			remoteAddr: "10.1.2.3:5000",
			xff:        "10.0.0.4, 10.0.0.5",
			want:       "10.1.2.3:5000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got string
			h := RealIP(cfg)(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
				got = r.RemoteAddr
			}))

			r := httptest.NewRequest(http.MethodGet, "/", nil)
			r.RemoteAddr = tt.remoteAddr
			if tt.xff != "" {
				r.Header.Set("X-Forwarded-For", tt.xff)
			}
			if tt.xRealIP != "" {
				r.Header.Set("X-Real-IP", tt.xRealIP)
			}

			h.ServeHTTP(httptest.NewRecorder(), r)

			if got != tt.want {
				t.Fatalf("RemoteAddr = %q, want %q", got, tt.want)
			}
		})
	}
}

// clientIP must not mistake an IPv6 address's own colons for a port separator,
// or every IPv6 client collapses into a handful of truncated rate-limit keys.
func TestClientIP(t *testing.T) {
	tests := []struct{ addr, want string }{
		{"192.0.2.1:443", "192.0.2.1"},
		{"192.0.2.1", "192.0.2.1"},
		{"[2001:db8::1]:443", "2001:db8::1"},
		{"2001:db8::1", "2001:db8::1"},
	}
	for _, tt := range tests {
		r := httptest.NewRequest(http.MethodGet, "/", nil)
		r.RemoteAddr = tt.addr
		if got := clientIP(r); got != tt.want {
			t.Errorf("clientIP(%q) = %q, want %q", tt.addr, got, tt.want)
		}
	}
}
