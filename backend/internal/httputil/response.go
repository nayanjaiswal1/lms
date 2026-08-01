package httputil

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
)

func writeEnvelope(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(body); err != nil {
		slog.Error("httputil: write response", "error", err)
	}
}

// WriteJSON writes a JSON response envelope: {"data": data}.
func WriteJSON(w http.ResponseWriter, status int, data any) {
	writeEnvelope(w, status, map[string]any{"data": data})
}

// WriteError writes a JSON error envelope: {"error": message}.
func WriteError(w http.ResponseWriter, status int, message string) {
	writeEnvelope(w, status, map[string]any{"error": message})
}

// WriteFieldErrors writes a validation error envelope:
// {"error": "validation failed", "fields": {"field": "message"}}.
func WriteFieldErrors(w http.ResponseWriter, status int, fields map[string]string) {
	writeEnvelope(w, status, map[string]any{
		"error":  "validation failed",
		"fields": fields,
	})
}

// ErrSpec maps a domain sentinel error to an HTTP response. When Fields is
// set, the response is a field-validation error; otherwise a plain message.
// An empty Message falls back to err.Error() at write time.
type ErrSpec struct {
	Status  int
	Message string
	Fields  map[string]string
}

// WriteDomainError looks up err against specs (via errors.Is on each key) and
// writes the matching response, or a generic 500 with fallbackMessage on no match.
func WriteDomainError(w http.ResponseWriter, err error, specs map[error]ErrSpec, fallbackMessage string) {
	for sentinel, spec := range specs {
		if !errors.Is(err, sentinel) {
			continue
		}
		if spec.Fields != nil {
			WriteFieldErrors(w, spec.Status, spec.Fields)
			return
		}
		msg := spec.Message
		if msg == "" {
			msg = err.Error()
		}
		WriteError(w, spec.Status, msg)
		return
	}
	slog.Error("httputil: unhandled domain error", "error", err)
	WriteError(w, http.StatusInternalServerError, fallbackMessage)
}
