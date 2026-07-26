package mcpconnect

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

// writeSpecJSON writes a bare JSON body with no envelope. Every OAuth
// (RFC 6749/7591/8414/9728) and MCP JSON-RPC response is spec-shaped at the
// top level — wrapping it in this app's usual {"data": ...} envelope
// (httputil.WriteJSON) would be silently unparseable by a real OAuth/MCP
// client, so none of the protocol-facing handlers in this package use
// httputil. httputil.WriteJSON/WriteError are still used for the handful of
// endpoints our own frontend calls (settings page, consent screen).
func writeSpecJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("mcpconnect: write json response", "error", err)
	}
}

// writeOAuthError writes the RFC 6749 §5.2 error shape:
// {"error": "<code>", "error_description": "..."}. code must be one of the
// spec's registered values (invalid_request, invalid_client, invalid_grant,
// unauthorized_client, unsupported_grant_type, invalid_scope).
func writeOAuthError(w http.ResponseWriter, status int, code, description string) {
	writeSpecJSON(w, status, map[string]string{
		"error":             code,
		"error_description": description,
	})
}
