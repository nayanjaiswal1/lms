package authz

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// TestUserRoleTrigger_OrgScopeEnforced is the regression check for migration
// 014: fn_check_user_role_tenant_scope (001_baseline.sql) read roles.tenant_id
// and user_roles.tenant_id, columns that don't exist on either table (both
// use org_id), so trg_user_role_tenant_scope raised 42703 on every
// INSERT INTO user_roles and no role could ever be assigned. This inserts
// through the real trigger against a real database and asserts it now
// succeeds when org_id matches, and still rejects a genuine cross-org
// mismatch (proving the fix didn't just silently no-op the check).
func TestUserRoleTrigger_OrgScopeEnforced(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()

	var orgID, otherOrgID, userID, roleID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('trigger-org', 'Trigger Org') RETURNING id`,
	).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('trigger-org-2', 'Trigger Org 2') RETURNING id`,
	).Scan(&otherOrgID); err != nil {
		t.Fatalf("seed other org: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ('trigger-user@example.com', 'Trigger User') RETURNING id`,
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO roles (org_id, name) VALUES ($1, 'Custom Role') RETURNING id`, orgID,
	).Scan(&roleID); err != nil {
		t.Fatalf("seed role: %v", err)
	}

	// Matching org_id must succeed — this is the exact statement shape that
	// used to fail with 42703 column "tenant_id" does not exist.
	if _, err := pool.Exec(ctx,
		`INSERT INTO user_roles (user_id, role_id, org_id) VALUES ($1, $2, $3)`,
		userID, roleID, orgID,
	); err != nil {
		t.Fatalf("INSERT INTO user_roles with matching org_id should succeed, got: %v", err)
	}

	// Mismatched org_id must still be rejected by the trigger's own logic
	// (proves the fix corrected the column names without disabling the check).
	if _, err := pool.Exec(ctx,
		`INSERT INTO user_roles (user_id, role_id, org_id) VALUES ($1, $2, $3)`,
		userID, roleID, otherOrgID,
	); err == nil {
		t.Fatal("expected org-scope violation for mismatched org_id, got no error")
	}

	// A NULL-scoped (system) role bypasses the check entirely, regardless of
	// the target org — same as before the fix.
	var systemRoleID string
	if err := pool.QueryRow(ctx,
		`SELECT id FROM roles WHERE is_system = true LIMIT 1`,
	).Scan(&systemRoleID); err != nil {
		t.Fatalf("find seeded system role: %v", err)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO user_roles (user_id, role_id, org_id) VALUES ($1, $2, $3)`,
		userID, systemRoleID, orgID,
	); err != nil {
		t.Fatalf("INSERT INTO user_roles with a system role should bypass the org check, got: %v", err)
	}
}
