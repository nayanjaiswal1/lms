package middleware

import (
	"net/http"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/auth"
)

// LLMQuotaContext attributes every LLM call made while serving the request to
// the signed-in user (see ai.QuotaProvider). Handlers surface provider errors
// in their own ways, so when the quota rejected a call this rewrites any
// error status they chose to 429. It must run after RequireAuth.
func LLMQuotaContext(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, ok := auth.GetClaims(r.Context())
		if !ok {
			next.ServeHTTP(w, r)
			return
		}
		ctx, trip := ai.WithQuotaUser(r.Context(), claims.UserID)
		next.ServeHTTP(&quotaWriter{ResponseWriter: w, trip: trip}, r.WithContext(ctx))
	})
}

type quotaWriter struct {
	http.ResponseWriter
	trip *ai.QuotaTrip
}

func (q *quotaWriter) WriteHeader(code int) {
	if code >= http.StatusInternalServerError && q.trip.Tripped() {
		q.Header().Set("Retry-After", "3600")
		code = http.StatusTooManyRequests
	}
	q.ResponseWriter.WriteHeader(code)
}

// Unwrap lets http.ResponseController reach the underlying writer (flush, hijack).
func (q *quotaWriter) Unwrap() http.ResponseWriter { return q.ResponseWriter }
