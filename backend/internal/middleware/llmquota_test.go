package middleware

import "net/http"

// SSE handlers (lab readiness) assert w.(http.Flusher); the quota wrapper must keep that working.
var _ http.Flusher = (*quotaWriter)(nil)
