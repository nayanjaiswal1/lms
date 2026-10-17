package profile

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/redis/go-redis/v9"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/authz/sysrole"
	"github.com/mindforge/backend/internal/certificates"
	"github.com/mindforge/backend/internal/testdb"
)

// Reading another member's full profile needs admin.manage_members in the
// caller's org: owner and admin (both tenant_admin) pass, instructor and
// mentor stay denied as under the old admin-only rule, and a cross-org target
// is a 404 so admins cannot probe other tenants.
func TestHandleGetUserProfile_MemberPermission(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	rdb := redis.NewClient(&redis.Options{Addr: "127.0.0.1:1", MaxRetries: -1})
	h := newHandler(NewService(NewRepo(pool), nil, nil, certificates.NewRepo(pool), nil), pool)
	h.perms = authz.NewService(authz.NewRepo(pool), authz.NewCache(rdb))

	seedUser := func(email string) string {
		var id string
		if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ($1::text, $1::text) RETURNING id`, email).Scan(&id); err != nil {
			t.Fatalf("seed user: %v", err)
		}
		return id
	}
	seedOrg := func(slug string) string {
		var id string
		if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ($1, $1) RETURNING id`, slug).Scan(&id); err != nil {
			t.Fatalf("seed org: %v", err)
		}
		return id
	}
	join := func(orgID, userID, label string) {
		if _, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id, role) VALUES ($1, $2, $3)`, orgID, userID, label); err != nil {
			t.Fatalf("seed member: %v", err)
		}
		if err := sysrole.Sync(ctx, pool, orgID, userID, label, ""); err != nil {
			t.Fatalf("sync role: %v", err)
		}
	}
	get := func(orgID, callerID, targetID string) int {
		rctx := chi.NewRouteContext()
		rctx.URLParams.Add("userID", targetID)
		req := httptest.NewRequest(http.MethodGet, "/api/profile/user/"+targetID, nil)
		reqCtx := context.WithValue(req.Context(), chi.RouteCtxKey, rctx)
		req = req.WithContext(auth.SetClaims(reqCtx, &auth.Claims{UserID: callerID, OrgID: orgID}))
		rec := httptest.NewRecorder()
		h.HandleGetUserProfile(rec, req)
		return rec.Code
	}

	orgA, orgB := seedOrg("org-a"), seedOrg("org-b")
	insider, outsider := seedUser("in@a.test"), seedUser("out@b.test")
	join(orgA, insider, "learner")
	join(orgB, outsider, "learner")

	for _, c := range []struct {
		label string
		want  int
	}{
		{"owner", http.StatusOK},
		{"admin", http.StatusOK},
		{"instructor", http.StatusForbidden},
		{"mentor", http.StatusForbidden},
		{"learner", http.StatusForbidden},
	} {
		caller := seedUser(c.label + "@a.test")
		join(orgA, caller, c.label)
		if got := get(orgA, caller, insider); got != c.want {
			t.Errorf("%s reading same-org member: got %d, want %d", c.label, got, c.want)
		}
		if c.want == http.StatusOK {
			if got := get(orgA, caller, outsider); got != http.StatusNotFound {
				t.Errorf("%s reading other-org user: got %d, want 404", c.label, got)
			}
		}
		if got := get(orgA, caller, caller); got != http.StatusOK {
			t.Errorf("%s reading self: got %d, want 200", c.label, got)
		}
	}

	// platform_role grants nothing here: a super_admin who is only a learner
	// in the org is denied like any learner (no platform-wide bypass).
	super := seedUser("super@a.test")
	if _, err := pool.Exec(ctx, `UPDATE users SET platform_role = 'super_admin' WHERE id = $1`, super); err != nil {
		t.Fatalf("seed super_admin: %v", err)
	}
	join(orgA, super, "learner")
	if got := get(orgA, super, insider); got != http.StatusForbidden {
		t.Errorf("super_admin learner reading member: got %d, want 403", got)
	}
}
