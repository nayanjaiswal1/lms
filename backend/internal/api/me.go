package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"strings"
	"sync"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// meIncludes maps each ?include= name on GET /api/me to the endpoint whose
// "data" payload it embeds.
var meIncludes = map[string]string{
	"permissions":         "/api/me/permissions",
	"features":            "/api/me/features",
	"active_lab_sessions": "/api/labs/sessions/active",
}

// meHandler serves GET /api/me[?include=permissions,features,active_lab_sessions,org]
// — the caller (always, under "me") plus any related resources asked for, so
// the frontend app shell reads everything it needs per render in one call.
// It fans the existing endpoints out in parallel in-process through the
// router instead of re-implementing them, so each part still runs its own
// middleware (auth, org membership, feature gates) and handler.
//
// Response: {"data": {"me": …, "<include>": …}} — each value is exactly that
// endpoint's own "data" payload. "org" is the caller's active org (omitted
// without one). A part whose endpoint didn't return 200 is omitted, and the
// frontend falls back per part. An unknown include is a 422.
func meHandler(mux http.Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims, ok := auth.RequireClaims(w, r)
		if !ok {
			return
		}

		parts := map[string]string{"me": "/api/auth/me"}
		for _, name := range strings.Split(r.URL.Query().Get("include"), ",") {
			switch name = strings.TrimSpace(name); {
			case name == "":
			case name == "org":
				if claims.OrgID != "" {
					parts["org"] = "/api/orgs/" + url.PathEscape(claims.OrgID)
				}
			case meIncludes[name] != "":
				parts[name] = meIncludes[name]
			default:
				httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
					"include": "unknown include " + strconv.Quote(name) + "; allowed: permissions, features, active_lab_sessions, org",
				})
				return
			}
		}

		out := make(map[string]json.RawMessage, len(parts))
		var mu sync.Mutex
		var wg sync.WaitGroup
		for key, path := range parts {
			wg.Add(1)
			go func() {
				defer wg.Done()
				if data, ok := dispatchGet(mux, r, path); ok {
					mu.Lock()
					out[key] = data
					mu.Unlock()
				}
			}()
		}
		wg.Wait()

		httputil.WriteJSON(w, http.StatusOK, out)
	}
}

// dispatchGet runs a GET for path through mux with the caller's headers and
// cookies, returning the response envelope's "data" on a 200.
func dispatchGet(mux http.Handler, r *http.Request, path string) (json.RawMessage, bool) {
	// Clear chi's route context — Mux.ServeHTTP reuses one found in ctx
	// instead of routing, which would dispatch to the bootstrap route itself.
	ctx := context.WithValue(r.Context(), chi.RouteCtxKey, nil)
	sub := r.Clone(ctx)
	sub.Method = http.MethodGet
	sub.URL = &url.URL{Path: path}
	sub.RequestURI = path
	sub.Body = http.NoBody
	sub.ContentLength = 0

	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, sub)
	if rec.Code != http.StatusOK {
		return nil, false
	}

	var envelope struct {
		Data json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &envelope); err != nil {
		return nil, false
	}
	return envelope.Data, true
}
