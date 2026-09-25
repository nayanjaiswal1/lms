package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

// writeJSONError writes a {"error": message} JSON envelope with the given
// status — the same shape the main API's httputil.WriteError produces, so
// labproxy clients see one consistent error contract. Kept local rather than
// importing internal/httputil because this binary is deliberately free of the
// main backend's dependency graph (see NewProxyHandler's doc comment).
func writeJSONError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(map[string]any{"error": message}); err != nil {
		slog.Error("labproxy: write error response", "error", err)
	}
}
