package auth

import (
	"context"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/ratelimit"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func membershipRoles(t *testing.T, pool *pgxpool.Pool, orgID, userID string) []string {
	t.Helper()
	rows, err := pool.Query(context.Background(),
		`SELECT r.name FROM user_roles ur JOIN roles r ON r.id = ur.role_id
		 WHERE ur.user_id = $1 AND ur.org_id = $2 ORDER BY r.name`, userID, orgID)
	if err != nil {
		t.Fatalf("list roles: %v", err)
	}
	defer rows.Close()
	names := []string{}
	for rows.Next() {
		var n string
		if err := rows.Scan(&n); err != nil {
			t.Fatalf("scan role: %v", err)
		}
		names = append(names, n)
	}
	return names
}

func membershipOrg(t *testing.T, pool *pgxpool.Pool, slug string) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(),
		`INSERT INTO organizations (slug, name) VALUES ($1, $1) RETURNING id`, slug,
	).Scan(&id); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	return id
}

func TestRegister_AssignsMemberRole(t *testing.T) {
	pool := testdb.New(t)
	orgID := membershipOrg(t, pool, "register-rbac")
	// Unreachable Redis: the limiter falls back to its in-memory window.
	rdb := redis.NewClient(&redis.Options{Addr: "127.0.0.1:1", DialTimeout: 50 * time.Millisecond})
	t.Cleanup(func() { _ = rdb.Close() })
	h := &Handler{
		pool:    pool,
		limiter: ratelimit.New(rdb),
		cfg: &config.Config{
			DefaultOrgID:         orgID,
			AuthRateLimitMax:     100,
			AuthRateLimitWindow:  time.Minute,
			EmailVerificationTTL: time.Hour,
		},
	}

	email := "register-rbac@" + testdomain.Domain
	body := `{"name":"Reg User","email":"` + email + `","password":"a-long-unique-passphrase","accept_terms":true,"age_declared":true}`
	rec := httptest.NewRecorder()
	h.HandleRegister(rec, httptest.NewRequest(http.MethodPost, "/api/auth/register", strings.NewReader(body)))
	if rec.Code != http.StatusCreated {
		t.Fatalf("register status = %d: %s", rec.Code, rec.Body)
	}

	var userID string
	if err := pool.QueryRow(context.Background(), `SELECT id FROM users WHERE email = $1`, email).Scan(&userID); err != nil {
		t.Fatalf("lookup user: %v", err)
	}
	if got := membershipRoles(t, pool, orgID, userID); !slices.Equal(got, []string{"member"}) {
		t.Fatalf("roles = %v, want [member]", got)
	}
}

func TestSocialSignup_AssignsMemberRole(t *testing.T) {
	pool := testdb.New(t)
	orgID := membershipOrg(t, pool, "social-rbac")
	h := &Handler{pool: pool, cfg: &config.Config{DefaultOrgID: orgID}}

	userID, _, err := h.findOrCreateSocialUser(context.Background(), "github",
		&providerUser{ProviderUID: "gh-1", Email: "social-rbac@" + testdomain.Domain, EmailVerified: true, Name: "Social"}, true)
	if err != nil {
		t.Fatalf("social signup: %v", err)
	}
	if got := membershipRoles(t, pool, orgID, userID); !slices.Equal(got, []string{"member"}) {
		t.Fatalf("roles = %v, want [member]", got)
	}
}

func TestFindOrCreateUserByEmail_AssignsMemberRoleOnlyForNewMembership(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	orgID := membershipOrg(t, pool, "provision-rbac")

	userID, err := FindOrCreateUserByEmail(ctx, pool, orgID, "provision-rbac@"+testdomain.Domain, "Prov")
	if err != nil {
		t.Fatalf("provision: %v", err)
	}
	if got := membershipRoles(t, pool, orgID, userID); !slices.Equal(got, []string{"member"}) {
		t.Fatalf("roles = %v, want [member]", got)
	}

	// An existing membership (here an instructor deliberately held to viewer)
	// is left exactly as it is.
	other := membershipOrg(t, pool, "provision-rbac-2")
	if _, err := pool.Exec(ctx,
		`INSERT INTO org_members (org_id, user_id, role) VALUES ($1, $2, 'instructor')`, other, userID,
	); err != nil {
		t.Fatalf("seed existing membership: %v", err)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO user_roles (user_id, role_id, org_id) SELECT $1, id, $2 FROM roles WHERE name = 'viewer' AND is_system`,
		userID, other,
	); err != nil {
		t.Fatalf("seed viewer: %v", err)
	}
	if _, err := FindOrCreateUserByEmail(ctx, pool, other, "provision-rbac@"+testdomain.Domain, "Prov"); err != nil {
		t.Fatalf("provision existing: %v", err)
	}
	if got := membershipRoles(t, pool, other, userID); !slices.Equal(got, []string{"viewer"}) {
		t.Fatalf("roles = %v, want [viewer]", got)
	}
}
