package middleware

import (
	"net/http"
	"net/url"
	"regexp"
)

// secretPathSegments matches routes whose last path segment is a bearer
// credential: public attempt tokens and calendar invite tokens.
var secretPathSegments = regexp.MustCompile(`^(/api/p/[^/]+/(?:submit|result)/)[^/?]+|^(/api/calendar/invites/)[^/?]+|^(/preview/)[^/?]+`)

// secretQueryParams are query parameters that carry credentials (the ICS feed
// URL token).
var secretQueryParams = []string{"token"}

const redacted = "REDACTED"

// RedactedURI returns requestURI with credential path segments and query
// parameters masked, for access logs.
func RedactedURI(requestURI string) string {
	u, err := url.ParseRequestURI(requestURI)
	if err != nil {
		return "REDACTED-URI"
	}
	path := secretPathSegments.ReplaceAllString(u.Path, "${1}${2}${3}"+redacted)
	q := u.Query()
	for _, k := range secretQueryParams {
		if q.Has(k) {
			q.Set(k, redacted)
		}
	}
	out := path
	if enc := q.Encode(); enc != "" {
		out += "?" + enc
	}
	return out
}

// RedactRequestURI must run before chimiddleware.Logger, which logs
// r.RequestURI: downstream handlers route on r.URL and are unaffected.
func RedactRequestURI(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		r2 := r.Clone(r.Context())
		r2.RequestURI = RedactedURI(r.RequestURI)
		next.ServeHTTP(w, r2)
	})
}
