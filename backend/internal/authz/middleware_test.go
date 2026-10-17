package authz

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
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

// seedMember inserts userID into orgID with an org_members label and grants
// the named system roles there.
func seedMember(t *testing.T, pool *pgxpool.Pool, orgID, userID, label, status string, roles ...string) {
	t.Helper()
	ctx := context.Background()
	if _, err := pool.Exec(ctx,
		`INSERT INTO org_members (org_id, user_id, role, status) VALUES ($1, $2, $3, $4)`,
		orgID, userID, label, status); err != nil {
		t.Fatalf("seed member: %v", err)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO user_roles (user_id, role_id, org_id)
		 SELECT $1, id, $2 FROM roles WHERE is_system AND name = ANY($3)`,
		userID, orgID, roles); err != nil {
		t.Fatalf("seed roles: %v", err)
	}
}

func seedOrgAndUser(t *testing.T, pool *pgxpool.Pool, slug string) (orgID, userID string) {
	t.Helper()
	ctx := context.Background()
	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (name, slug) VALUES ($1, $1) RETURNING id`, slug).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`, slug+"@"+testdomain.Domain, slug).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return orgID, userID
}

// newDBService builds a Service over pool whose Redis is unreachable, so
// every lookup reads the database.
func newDBService(pool *pgxpool.Pool) *Service {
	rdb := redis.NewClient(&redis.Options{Addr: "127.0.0.1:1", MaxRetries: -1})
	return NewService(NewRepo(pool), NewCache(rdb))
}

// TestRequirePermission_CrossOrgCtx: when RequireOrgMember resolves an org
// other than the JWT org (X-Org-Id), RequirePermission must find the code in
// that org too, while RequireOrgCtxPermission checks only the resolved org.
func TestRequirePermission_CrossOrgCtx(t *testing.T) {
	pool := testdb.New(t)
	svc := newDBService(pool)
	orgA, user := seedOrgAndUser(t, pool, "cross-org-a")
	orgB, _ := seedOrgAndUser(t, pool, "cross-org-b")
	seedMember(t, pool, orgA, user, "admin", "active", "tenant_admin")
	seedMember(t, pool, orgB, user, "mentor", "active", "mentor")

	call := func(mw func(http.Handler) http.Handler, jwtOrg, headerOrg string) int {
		h := middleware.RequireOrgMember(pool)(mw(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusOK)
		})))
		req := httptest.NewRequest(http.MethodGet, "/x", nil)
		if headerOrg != "" {
			req.Header.Set("X-Org-Id", headerOrg)
		}
		req = req.WithContext(auth.SetClaims(req.Context(), &auth.Claims{UserID: user, OrgID: jwtOrg}))
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec.Code
	}

	manageOrg := RequirePermission(svc, "admin.manage_org")
	anyManage := RequireAnyPermission(svc, "admin.manage_org", "projects.manage")
	cases := []struct {
		name              string
		mw                func(http.Handler) http.Handler
		jwtOrg, headerOrg string
		want              int
	}{
		{"admin in JWT org, no header", manageOrg, orgA, "", http.StatusOK},
		{"admin in JWT org, header names org where only mentor", manageOrg, orgA, orgB, http.StatusForbidden},
		{"any-of: header org grants none of the codes", anyManage, orgA, orgB, http.StatusForbidden},
		{"mentor JWT org, header names org where admin", manageOrg, orgB, orgA, http.StatusForbidden},
		{"org-ctx guard: only the resolved org counts", RequireOrgCtxPermission(svc, "admin.manage_org"), orgB, orgA, http.StatusOK},
		{"org-ctx guard: resolved org lacks the code", RequireOrgCtxPermission(svc, "admin.manage_org"), orgA, orgB, http.StatusForbidden},
	}
	for _, c := range cases {
		if got := call(c.mw, c.jwtOrg, c.headerOrg); got != c.want {
			t.Errorf("%s: status %d, want %d", c.name, got, c.want)
		}
	}
}

// The unified audit log (GET /api/admin/rbac/audit) is the only audit
// endpoint; its gate must stay admin.view_audit_log.
func TestRequirePermission_AuditLogGate(t *testing.T) {
	pool := testdb.New(t)
	svc := newDBService(pool)
	org, admin := seedOrgAndUser(t, pool, "audit-gate")
	_, mentor := seedOrgAndUser(t, pool, "audit-gate-mentor")
	seedMember(t, pool, org, admin, "admin", "active", "tenant_admin")
	seedMember(t, pool, org, mentor, "mentor", "active", "mentor")

	call := func(user string) int {
		h := RequirePermission(svc, "admin.view_audit_log")(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusOK)
		}))
		req := httptest.NewRequest(http.MethodGet, "/audit", nil)
		req = req.WithContext(auth.SetClaims(req.Context(), &auth.Claims{UserID: user, OrgID: org}))
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec.Code
	}
	if got := call(admin); got != http.StatusOK {
		t.Errorf("tenant_admin: status %d, want 200", got)
	}
	if got := call(mentor); got != http.StatusForbidden {
		t.Errorf("mentor: status %d, want 403", got)
	}
}
