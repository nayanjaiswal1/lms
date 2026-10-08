package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// TestMeIncludes: GET /api/me always embeds the caller, adds only the parts
// asked for, and rejects an unknown include.
func TestMeIncludes(t *testing.T) {
	mux := chi.NewRouter()
	mux.Get("/api/auth/me", func(w http.ResponseWriter, _ *http.Request) {
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"id": "u1"})
	})
	mux.Get("/api/me/permissions", func(w http.ResponseWriter, _ *http.Request) {
		httputil.WriteJSON(w, http.StatusOK, []string{"courses.view"})
	})
	mux.Get("/api/me", meHandler(mux))

	get := func(query string) (int, map[string]json.RawMessage) {
		req := httptest.NewRequest(http.MethodGet, "/api/me"+query, nil)
		req = req.WithContext(auth.SetClaims(req.Context(), &auth.Claims{UserID: "u1"}))
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)
		var body struct {
			Data map[string]json.RawMessage `json:"data"`
		}
		_ = json.Unmarshal(rec.Body.Bytes(), &body)
		return rec.Code, body.Data
	}

	if code, data := get(""); code != http.StatusOK || len(data) != 1 || data["me"] == nil {
		t.Fatalf("bare /api/me = %d %v, want only me", code, data)
	}
	if code, data := get("?include=permissions,org"); code != http.StatusOK || data["permissions"] == nil || data["org"] != nil {
		t.Fatalf("include permissions,org (no active org) = %d %v", code, data)
	}
	if code, _ := get("?include=secrets"); code != http.StatusUnprocessableEntity {
		t.Fatalf("unknown include = %d, want 422", code)
	}
}
