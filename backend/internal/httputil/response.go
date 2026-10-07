package httputil

import (
	"encoding/json"
	"errors"
	"io"
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

// WriteErrorCode writes an error envelope with a stable machine-readable code:
// {"error": message, "code": code}. Clients switch on code, never on the
// message text or on a status that several conditions share. Codes are
// snake_case and owned by the domain package that emits them.
func WriteErrorCode(w http.ResponseWriter, status int, code, message string) {
	writeEnvelope(w, status, map[string]any{"error": message, "code": code})
}

// DecodeJSON decodes the request body as JSON into dst. On failure it writes
// a 400 {"error": "Invalid request body."} envelope and returns false, so
// handlers can `if !DecodeJSON(w, r, &req) { return }`.
func DecodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

// DecodeJSONAllowEmpty is DecodeJSON for endpoints whose body is optional: an
// empty body decodes to dst's zero value instead of a 400. Malformed JSON is
// still rejected the same way.
func DecodeJSONAllowEmpty(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil && !errors.Is(err, io.EOF) {
		WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
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
// An empty Message falls back to err.Error() at write time. A non-empty Code
// is added to the envelope as "code" (see WriteErrorCode); empty keeps the
// envelope exactly as before.
type ErrSpec struct {
	Status  int
	Message string
	Code    string
	Fields  map[string]string
}

// DomainErrorWriter binds specs and fallbackMessage into a per-package
// writeDomainError(w, err) function.
func DomainErrorWriter(specs map[error]ErrSpec, fallbackMessage string) func(http.ResponseWriter, error) {
	return func(w http.ResponseWriter, err error) {
		WriteDomainError(w, err, specs, fallbackMessage)
	}
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
		if spec.Code != "" {
			WriteErrorCode(w, spec.Status, spec.Code, msg)
			return
		}
		WriteError(w, spec.Status, msg)
		return
	}
	slog.Error("httputil: unhandled domain error", "error", err)
	WriteError(w, http.StatusInternalServerError, fallbackMessage)
}

// WriteErrorWithData writes an error envelope that also carries a payload:
// {"error": message, "data": data}. Used for 409 optimistic-lock conflicts so
// the client can show the current row next to its stale edit.
func WriteErrorWithData(w http.ResponseWriter, status int, message string, data any) {
	writeEnvelope(w, status, map[string]any{"error": message, "data": data})
}

// WriteErrorCodeWithData writes an error envelope carrying both a stable
// machine-readable code and a payload: {"error": message, "code": code,
// "data": data}. Used where the client needs structured detail with the
// failure (e.g. a recipe's validation issues).
func WriteErrorCodeWithData(w http.ResponseWriter, status int, code, message string, data any) {
	writeEnvelope(w, status, map[string]any{"error": message, "code": code, "data": data})
}
