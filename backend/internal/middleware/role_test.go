package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/mindforge/backend/internal/auth"
)

const testOrgID = "org-1"

// serve runs a request through mw wrapping a handler that records whether it
// was reached, and returns the status code and the reached flag.
func serve(t *testing.T, mw func(http.Handler) http.Handler, ctx context.Context) (int, bool) {
	t.Helper()
	reached := false
	h := mw(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		reached = true
		w.WriteHeader(http.StatusOK)
	}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/x", nil).WithContext(ctx))
	return rec.Code, reached
}

func orgCtx(role string) context.Context {
	ctx := auth.SetClaims(context.Background(), &auth.Claims{UserID: "u1", OrgID: testOrgID})
	return context.WithValue(ctx, orgKey, &OrgCtx{OrgID: testOrgID, CallerRole: role})
}

func TestRequireOrgRole(t *testing.T) {
	// pool is nil: every case below resolves the role from the OrgCtx that
	// RequireOrgMember would have set, so the DB is never consulted.
	mw := RequireOrgRole(nil, RoleOwner, RoleAdmin)

	t.Run("allowed role passes", func(t *testing.T) {
		code, reached := serve(t, mw, orgCtx(RoleAdmin))
		if code != http.StatusOK || !reached {
			t.Fatalf("got %d reached=%v, want 200 reached", code, reached)
		}
	})
	t.Run("wrong role is 403 and handler not reached", func(t *testing.T) {
		code, reached := serve(t, mw, orgCtx(RoleMentor))
		if code != http.StatusForbidden || reached {
			t.Fatalf("got %d reached=%v, want 403 not reached", code, reached)
		}
	})
	t.Run("unauthenticated is 401 and handler not reached", func(t *testing.T) {
		code, reached := serve(t, mw, context.Background())
		if code != http.StatusUnauthorized || reached {
			t.Fatalf("got %d reached=%v, want 401 not reached", code, reached)
		}
	})
	t.Run("org without role claim and no membership is 403", func(t *testing.T) {
		ctx := auth.SetClaims(context.Background(), &auth.Claims{UserID: "u1"})
		code, reached := serve(t, mw, ctx)
		if code != http.StatusForbidden || reached {
			t.Fatalf("got %d reached=%v, want 403 not reached", code, reached)
		}
	})
	t.Run("route without the middleware is not gated", func(t *testing.T) {
		reached := false
		h := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { reached = true })
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/open", nil))
		if rec.Code != http.StatusOK || !reached {
			t.Fatalf("ungated route got %d reached=%v, want 200 reached", rec.Code, reached)
		}
	})
	t.Run("role from a different org context is ignored", func(t *testing.T) {
		// OrgCtx for another org must not satisfy the check for claims.OrgID;
		// with no pool and a mismatched org the lookup would need the DB, so
		// use an empty claims.OrgID to exercise the deny path without one.
		ctx := auth.SetClaims(context.Background(), &auth.Claims{UserID: "u1"})
		ctx = context.WithValue(ctx, orgKey, &OrgCtx{OrgID: "other-org", CallerRole: RoleOwner})
		code, reached := serve(t, mw, ctx)
		if code != http.StatusForbidden || reached {
			t.Fatalf("got %d reached=%v, want 403 not reached", code, reached)
		}
	})
}
