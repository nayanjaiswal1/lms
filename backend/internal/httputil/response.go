package httputil

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

// WriteJSON writes a JSON response envelope: {"data": data}.
func WriteJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(map[string]any{"data": data}); err != nil {
		slog.Error("httputil: write json response", "error", err)
	}
}

// WriteError writes a JSON error envelope: {"error": message}.
func WriteError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(map[string]any{"error": message}); err != nil {
		slog.Error("httputil: write error response", "error", err)
	}
}

// WriteFieldErrors writes a validation error envelope:
// {"error": "validation failed", "fields": {"field": "message"}}.
func WriteFieldErrors(w http.ResponseWriter, status int, fields map[string]string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	body := map[string]any{
		"error":  "validation failed",
		"fields": fields,
	}
	if err := json.NewEncoder(w).Encode(body); err != nil {
		slog.Error("httputil: write field errors response", "error", err)
	}
}
