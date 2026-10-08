package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/mindforge/backend/internal/ai"
)

// SSE handlers (lab readiness) assert w.(http.Flusher) at runtime; the quota
// wrapper must keep that working and reach the underlying writer's Flush.
func TestQuotaWriter_FlushReachesUnderlyingWriter(t *testing.T) {
	rec := httptest.NewRecorder()
	var w http.ResponseWriter = &quotaWriter{ResponseWriter: rec, trip: &ai.QuotaTrip{}}

	f, ok := w.(http.Flusher)
	if !ok {
		t.Fatal("quotaWriter hides http.Flusher from SSE handlers")
	}
	f.Flush()
	if !rec.Flushed {
		t.Fatal("Flush did not reach the underlying ResponseWriter")
	}
}

// A 500 from a handler whose calls were not rejected by the quota must pass
// through unchanged: no 429 rewrite and no Retry-After header.
func TestQuotaWriter_UntrippedServerErrorPassesThrough(t *testing.T) {
	rec := httptest.NewRecorder()
	w := &quotaWriter{ResponseWriter: rec, trip: &ai.QuotaTrip{}}

	w.WriteHeader(http.StatusInternalServerError)
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500 passed through", rec.Code)
	}
	if got := rec.Header().Get("Retry-After"); got != "" {
		t.Fatalf("Retry-After = %q, want none when the quota did not trip", got)
	}
}
