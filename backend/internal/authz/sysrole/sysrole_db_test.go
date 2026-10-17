package sysrole_test

import (
	"context"
	"os"
	"slices"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/authz/sysrole"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func seedOrg(t *testing.T, pool *pgxpool.Pool, slug string) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(),
		`INSERT INTO organizations (slug, name) VALUES ($1, $1) RETURNING id`, slug,
	).Scan(&id); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	return id
}

func seedMember(t *testing.T, pool *pgxpool.Pool, orgID, local, label, status string) string {
	t.Helper()
	ctx := context.Background()
	var id string
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
		local+"@"+testdomain.Domain, local,
	).Scan(&id); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO org_members (org_id, user_id, role, status) VALUES ($1, $2, $3, $4)`,
		orgID, id, label, status,
	); err != nil {
		t.Fatalf("seed member: %v", err)
	}
	return id
}

func grant(t *testing.T, pool *pgxpool.Pool, orgID, userID, roleID string) {
	t.Helper()
	if _, err := pool.Exec(context.Background(),
		`INSERT INTO user_roles (user_id, role_id, org_id) VALUES ($1, $2, $3)`, userID, roleID, orgID,
	); err != nil {
		t.Fatalf("grant role: %v", err)
	}
}

func systemRoleID(t *testing.T, pool *pgxpool.Pool, name string) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(),
		`SELECT id FROM roles WHERE name = $1 AND is_system`, name,
	).Scan(&id); err != nil {
		t.Fatalf("system role %s: %v", name, err)
	}
	return id
}

func rolesOf(t *testing.T, pool *pgxpool.Pool, orgID, userID string) []string {
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
	if err := rows.Err(); err != nil {
		t.Fatalf("list roles: %v", err)
	}
	return names
}

func assertRoles(t *testing.T, pool *pgxpool.Pool, orgID, userID string, want ...string) {
	t.Helper()
	if want == nil {
		want = []string{}
	}
	if got := rolesOf(t, pool, orgID, userID); !slices.Equal(got, want) {
		t.Fatalf("roles = %v, want %v", got, want)
	}
}

func TestSync_LabelChangeSwapsMappedRoleAndKeepsExtras(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	orgID := seedOrg(t, pool, "sysrole-swap")
	userID := seedMember(t, pool, orgID, "swap", "learner", "active")

	var customID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO roles (org_id, name) VALUES ($1, 'Reviewer') RETURNING id`, orgID,
	).Scan(&customID); err != nil {
		t.Fatalf("seed custom role: %v", err)
	}
	grant(t, pool, orgID, userID, customID)
	grant(t, pool, orgID, userID, systemRoleID(t, pool, "viewer"))

	if err := sysrole.Sync(ctx, pool, orgID, userID, "learner", ""); err != nil {
		t.Fatalf("sync learner: %v", err)
	}
	// Idempotent.
	if err := sysrole.Sync(ctx, pool, orgID, userID, "learner", ""); err != nil {
		t.Fatalf("sync learner again: %v", err)
	}
	assertRoles(t, pool, orgID, userID, "Reviewer", "member", "viewer")

	if err := sysrole.Sync(ctx, pool, orgID, userID, "instructor", "learner"); err != nil {
		t.Fatalf("sync instructor: %v", err)
	}
	assertRoles(t, pool, orgID, userID, "Reviewer", "instructor", "viewer")

	if err := sysrole.Sync(ctx, pool, orgID, userID, "admin", "instructor"); err != nil {
		t.Fatalf("sync admin: %v", err)
	}
	assertRoles(t, pool, orgID, userID, "Reviewer", "tenant_admin", "viewer")
}

func TestSync_OwnerAdminShareTenantAdmin(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	orgID := seedOrg(t, pool, "sysrole-owner")
	userID := seedMember(t, pool, orgID, "owner", "owner", "active")

	if err := sysrole.Sync(ctx, pool, orgID, userID, "owner", ""); err != nil {
		t.Fatalf("sync owner: %v", err)
	}
	if err := sysrole.Sync(ctx, pool, orgID, userID, "admin", "owner"); err != nil {
		t.Fatalf("sync owner->admin: %v", err)
	}
	assertRoles(t, pool, orgID, userID, "tenant_admin")
	if err := sysrole.Sync(ctx, pool, orgID, userID, "owner", "admin"); err != nil {
		t.Fatalf("sync admin->owner: %v", err)
	}
	assertRoles(t, pool, orgID, userID, "tenant_admin")
}

func TestSync_RejectsUnknownLabel(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	orgID := seedOrg(t, pool, "sysrole-unknown")
	userID := seedMember(t, pool, orgID, "unknown", "learner", "active")

	if err := sysrole.Sync(ctx, pool, orgID, userID, "superuser", ""); err == nil {
		t.Fatal("expected error for unknown label")
	}
	if err := sysrole.Sync(ctx, pool, orgID, userID, "learner", "superuser"); err == nil {
		t.Fatal("expected error for unknown previous label")
	}
	assertRoles(t, pool, orgID, userID)
}

func execMigration(t *testing.T, pool *pgxpool.Pool, file string) {
	t.Helper()
	sql, err := os.ReadFile("../../../db/migrations/" + file)
	if err != nil {
		t.Fatalf("read %s: %v", file, err)
	}
	if _, err := pool.Exec(context.Background(), string(sql)); err != nil {
		t.Fatalf("apply %s: %v", file, err)
	}
}

// TestMigration008_BackfillRoundTrip seeds pre-008 drift, then runs the
// migration up and down. The template database already applied 008 when it
// was empty, so the test first rolls it back to get a clean starting point.
func TestMigration008_BackfillRoundTrip(t *testing.T) {
	pool := testdb.New(t)
	execMigration(t, pool, "008_rbac_membership_backfill.down.sql")

	orgID := seedOrg(t, pool, "backfill-008")
	instructorRole := systemRoleID(t, pool, "instructor")

	// A: staff missing their mapped role, one already holding it.
	admin := seedMember(t, pool, orgID, "bf-admin", "admin", "active")
	mentor := seedMember(t, pool, orgID, "bf-mentor", "mentor", "suspended")
	instructor := seedMember(t, pool, orgID, "bf-instructor", "instructor", "active")
	grant(t, pool, orgID, instructor, instructorRole)
	// B: learner with no roles at all.
	learner := seedMember(t, pool, orgID, "bf-learner", "learner", "active")
	// C: learner deliberately held to viewer.
	viewer := seedMember(t, pool, orgID, "bf-viewer", "learner", "active")
	grant(t, pool, orgID, viewer, systemRoleID(t, pool, "viewer"))
	// Removed memberships are not backfilled.
	removed := seedMember(t, pool, orgID, "bf-removed", "admin", "removed")

	execMigration(t, pool, "008_rbac_membership_backfill.sql")
	assertRoles(t, pool, orgID, admin, "tenant_admin")
	assertRoles(t, pool, orgID, mentor, "mentor")
	assertRoles(t, pool, orgID, instructor, "instructor")
	assertRoles(t, pool, orgID, learner, "member")
	assertRoles(t, pool, orgID, viewer, "viewer")
	assertRoles(t, pool, orgID, removed)

	var tracked int
	if err := pool.QueryRow(context.Background(), `SELECT count(*) FROM rbac_backfill_008`).Scan(&tracked); err != nil {
		t.Fatalf("count tracking rows: %v", err)
	}
	if tracked != 3 {
		t.Fatalf("tracked rows = %d, want 3 (admin, mentor, learner)", tracked)
	}

	execMigration(t, pool, "008_rbac_membership_backfill.down.sql")
	assertRoles(t, pool, orgID, admin)
	assertRoles(t, pool, orgID, mentor)
	assertRoles(t, pool, orgID, instructor, "instructor")
	assertRoles(t, pool, orgID, learner)
	assertRoles(t, pool, orgID, viewer, "viewer")

	var exists bool
	if err := pool.QueryRow(context.Background(),
		`SELECT to_regclass('rbac_backfill_008') IS NOT NULL`).Scan(&exists); err != nil {
		t.Fatalf("check tracking table: %v", err)
	}
	if exists {
		t.Fatal("rbac_backfill_008 should be dropped by the down migration")
	}
}
