package authz

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// Unauthenticated requests must be rejected before the service (nil here) is
// ever consulted.
func TestPermissionMiddlewareUnauthenticatedIs401(t *testing.T) {
	cases := map[string]func(http.Handler) http.Handler{
		"RequirePermission":    RequirePermission(nil, "x.read"),
		"RequireAnyPermission": RequireAnyPermission(nil, "x.read"),
	}
	for name, mw := range cases {
		t.Run(name, func(t *testing.T) {
			reached := false
			h := mw(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { reached = true }))
			rec := httptest.NewRecorder()
			h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/x", nil))
			if rec.Code != http.StatusUnauthorized || reached {
				t.Fatalf("got %d reached=%v, want 401 not reached", rec.Code, reached)
			}
		})
	}
}
