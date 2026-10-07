package middleware

import (
	"net/http"
	"strings"
)

// hstsValue is two years with subdomains; sent only over HTTPS.
const hstsValue = "max-age=63072000; includeSubDomains"

// SecureHeaders sets X-Content-Type-Options: nosniff on every response and
// Strict-Transport-Security when the request arrived over TLS (directly or via
// a proxy reporting X-Forwarded-Proto: https) — audit M-18.
func SecureHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		if r.TLS != nil || strings.EqualFold(r.Header.Get("X-Forwarded-Proto"), "https") {
			h.Set("Strict-Transport-Security", hstsValue)
		}
		next.ServeHTTP(w, r)
	})
}

// MaxBody caps every non-multipart request body at limit bytes (audit M-17),
// so httputil.DecodeJSON and friends can never buffer an unbounded payload.
// Multipart endpoints (uploads) are skipped: each sets its own, larger cap.
// Handlers that install a stricter http.MaxBytesReader keep it.
func MaxBody(limit int64) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Body != nil && !strings.HasPrefix(r.Header.Get("Content-Type"), "multipart/") {
				r.Body = http.MaxBytesReader(w, r.Body, limit)
			}
			next.ServeHTTP(w, r)
		})
	}
}
