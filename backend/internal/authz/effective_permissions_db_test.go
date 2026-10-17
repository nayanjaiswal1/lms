package authz

import (
	"context"
	"os"
	"slices"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
)

// TestOrgPermissionHolders covers the effective_permissions filters: only
// active members, only active roles, and direct overrides count; other orgs
// never leak in.
func TestOrgPermissionHolders(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)
	const code = "admin.manage_org"

	org, admin := seedOrgAndUser(t, pool, "holders-org")
	other, otherAdmin := seedOrgAndUser(t, pool, "holders-other")
	_, suspended := seedOrgAndUser(t, pool, "holders-suspended")
	_, inactiveRole := seedOrgAndUser(t, pool, "holders-inactive-role")
	_, override := seedOrgAndUser(t, pool, "holders-override")
	_, suspendedOverride := seedOrgAndUser(t, pool, "holders-suspended-override")

	seedMember(t, pool, org, admin, "admin", "active", "tenant_admin")
	seedMember(t, pool, other, otherAdmin, "admin", "active", "tenant_admin")
	seedMember(t, pool, org, suspended, "admin", "suspended", "tenant_admin")
	seedMember(t, pool, org, inactiveRole, "learner", "active", "member")
	seedMember(t, pool, org, override, "learner", "active", "member")
	seedMember(t, pool, org, suspendedOverride, "learner", "suspended", "member")

	var customRole string
	if err := pool.QueryRow(ctx,
		`INSERT INTO roles (org_id, name, is_active) VALUES ($1, 'Disabled Admin', false) RETURNING id`, org,
	).Scan(&customRole); err != nil {
		t.Fatalf("seed custom role: %v", err)
	}
	exec(t, pool, `INSERT INTO role_permissions (role_id, permission_id) SELECT $1, id FROM permissions WHERE code = $2`, customRole, code)
	exec(t, pool, `INSERT INTO user_roles (user_id, role_id, org_id) VALUES ($1, $2, $3)`, inactiveRole, customRole, org)
	for _, u := range []string{override, suspendedOverride} {
		exec(t, pool, `INSERT INTO user_permission_overrides (user_id, org_id, permission_id)
		               SELECT $1, $2, id FROM permissions WHERE code = $3`, u, org, code)
	}

	got, err := repo.OrgPermissionHolders(ctx, org, code)
	if err != nil {
		t.Fatalf("OrgPermissionHolders: %v", err)
	}
	slices.Sort(got)
	want := []string{admin, override}
	slices.Sort(want)
	if !slices.Equal(got, want) {
		t.Fatalf("holders = %v, want %v (admin, override)", got, want)
	}

	// Per-user resolution reads the same view.
	codes, err := repo.GetEffectivePermissions(ctx, override, org)
	if err != nil || !slices.Contains(codes, code) || !slices.Contains(codes, "practice.use") {
		t.Fatalf("override user codes = %v (err %v), want role grants plus %s", codes, err, code)
	}
	if codes, err := repo.GetEffectivePermissions(ctx, suspended, org); err != nil || len(codes) != 0 {
		t.Fatalf("suspended member codes = %v (err %v), want none", codes, err)
	}
}

// TestMigration009_RoundTrip rolls 009 back and forward on a migrated
// database: the down drops the view, the three codes and their grants; the up
// restores them with the documented holders.
func TestMigration009_RoundTrip(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	codes := []string{"messaging.moderate", "wiki.manage_spaces", "wiki.create_spaces", "mentoring.claim_tickets"}

	runMigration(t, pool, "009_staff_permission_codes.down.sql")
	var view *string
	if err := pool.QueryRow(ctx, `SELECT to_regclass('effective_permissions')::text`).Scan(&view); err != nil || view != nil {
		t.Fatalf("view after down = %v (err %v), want dropped", view, err)
	}
	var n int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM permissions WHERE code = ANY($1)`, codes).Scan(&n); err != nil || n != 0 {
		t.Fatalf("codes after down = %d (err %v), want 0", n, err)
	}

	runMigration(t, pool, "009_staff_permission_codes.sql")
	rows, err := pool.Query(ctx,
		`SELECT p.code, string_agg(r.name, ',' ORDER BY r.name)
		 FROM permissions p JOIN role_permissions rp ON rp.permission_id = p.id
		 JOIN roles r ON r.id = rp.role_id AND r.is_system
		 WHERE p.code = ANY($1) GROUP BY p.code`, codes)
	if err != nil {
		t.Fatalf("query grants: %v", err)
	}
	got := map[string]string{}
	for rows.Next() {
		var c, roles string
		if err := rows.Scan(&c, &roles); err != nil {
			t.Fatalf("scan grants: %v", err)
		}
		got[c] = roles
	}
	rows.Close()
	want := map[string]string{
		"messaging.moderate":      "instructor,mentor,tenant_admin",
		"wiki.manage_spaces":      "instructor,mentor,tenant_admin",
		"wiki.create_spaces":      "instructor,tenant_admin",
		"mentoring.claim_tickets": "mentor",
	}
	for c, roles := range want {
		if got[c] != roles {
			t.Errorf("%s granted to %q, want %q", c, got[c], roles)
		}
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM effective_permissions`).Scan(&n); err != nil {
		t.Fatalf("view after up: %v", err)
	}
}

func runMigration(t *testing.T, pool *pgxpool.Pool, file string) {
	t.Helper()
	sql, err := os.ReadFile("../../db/migrations/" + file)
	if err != nil {
		t.Fatalf("read %s: %v", file, err)
	}
	exec(t, pool, string(sql))
}

func exec(t *testing.T, pool *pgxpool.Pool, sql string, args ...any) {
	t.Helper()
	if _, err := pool.Exec(context.Background(), sql, args...); err != nil {
		t.Fatalf("exec %.60q: %v", sql, err)
	}
}
