package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// SSE handlers (lab readiness) assert w.(http.Flusher); the quota wrapper must keep that working.
func TestQuotaWriterFlushes(t *testing.T) {
	rec := httptest.NewRecorder()
	var w http.ResponseWriter = &quotaWriter{ResponseWriter: rec}

	f, ok := w.(http.Flusher)
	require.True(t, ok, "quotaWriter must implement http.Flusher")
	f.Flush()
	assert.True(t, rec.Flushed)
}
