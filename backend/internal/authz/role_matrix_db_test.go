package authz

import (
	"context"
	"encoding/json"
	"os"
	"reflect"
	"slices"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
)

const roleMatrixGolden = "testdata/role_matrix.golden.json"

// systemRoleMatrix loads every system role's granted permission codes.
func systemRoleMatrix(t *testing.T, pool *pgxpool.Pool) map[string][]string {
	t.Helper()
	rows, err := pool.Query(context.Background(),
		`SELECT r.name, coalesce(array_agg(p.code ORDER BY p.code) FILTER (WHERE p.code IS NOT NULL), '{}')
		 FROM roles r
		 LEFT JOIN role_permissions rp ON rp.role_id = r.id
		 LEFT JOIN permissions p ON p.id = rp.permission_id
		 WHERE r.is_system GROUP BY r.name`)
	if err != nil {
		t.Fatalf("query role matrix: %v", err)
	}
	defer rows.Close()
	got := map[string][]string{}
	for rows.Next() {
		var name string
		var codes []string
		if err := rows.Scan(&name, &codes); err != nil {
			t.Fatalf("scan role matrix: %v", err)
		}
		got[name] = codes
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("iterate role matrix: %v", err)
	}
	return got
}

// TestSystemRoleMatrix_Golden pins the full system role -> permission matrix
// of a fully migrated database. Any grant change in a migration must update
// testdata/role_matrix.golden.json (UPDATE_GOLDEN=1 go test -run
// TestSystemRoleMatrix_Golden ./internal/authz rewrites it) and docs/rbac.md §3.
func TestSystemRoleMatrix_Golden(t *testing.T) {
	got := systemRoleMatrix(t, testdb.New(t))
	if os.Getenv("UPDATE_GOLDEN") == "1" {
		b, err := json.MarshalIndent(got, "", "  ")
		if err != nil {
			t.Fatalf("marshal golden: %v", err)
		}
		if err := os.WriteFile(roleMatrixGolden, append(b, '\n'), 0o644); err != nil {
			t.Fatalf("write golden: %v", err)
		}
	}
	raw, err := os.ReadFile(roleMatrixGolden)
	if err != nil {
		t.Fatalf("read golden: %v", err)
	}
	var want map[string][]string
	if err := json.Unmarshal(raw, &want); err != nil {
		t.Fatalf("parse golden: %v", err)
	}
	for _, role := range []string{"viewer", "member", "instructor", "mentor", "tenant_admin", "support_agent"} {
		if _, ok := want[role]; !ok {
			t.Errorf("golden is missing system role %s", role)
		}
	}
	if !reflect.DeepEqual(got, want) {
		b, _ := json.MarshalIndent(got, "", "  ")
		t.Fatalf("system role matrix drifted from %s; got:\n%s", roleMatrixGolden, b)
	}
}

// TestMigration010_RoundTrip rolls 010 back, seeds owner/admin memberships
// with and without learner activity plus a custom role and override holding
// a dead code, then runs 010 up and down again.
func TestMigration010_RoundTrip(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	golden := systemRoleMatrix(t, pool)
	dead := []string{"content.interview_board", "content.load_test"}

	runMigration(t, pool, "010_role_matrix_cleanup.down.sql")
	before := systemRoleMatrix(t, pool)
	for _, c := range []string{"practice.use", "content.srs", "content.interview_board"} {
		if !slices.Contains(before["tenant_admin"], c) {
			t.Fatalf("after down tenant_admin lacks %s", c)
		}
	}
	if !slices.Contains(before["viewer"], "projects.view") {
		t.Fatal("after down viewer lacks projects.view")
	}

	// journaler: owner of exactly one org with a journal entry -> backfilled.
	orgA, journaler := seedOrgAndUser(t, pool, "rb010-journaler")
	seedMember(t, pool, orgA, journaler, "owner", "active", "tenant_admin")
	exec(t, pool, `INSERT INTO learning_journal_entries (user_id, category, subcategory, title, content)
	               VALUES ($1, 'go', 'basics', 't', 'c')`, journaler)
	// multi: admin of two orgs, journal entry (user-scoped -> ambiguous) and a
	// roadmap in orgA only -> backfilled in orgA, not orgB.
	orgB, multi := seedOrgAndUser(t, pool, "rb010-multi")
	seedMember(t, pool, orgA, multi, "admin", "active", "tenant_admin")
	seedMember(t, pool, orgB, multi, "admin", "suspended", "tenant_admin")
	exec(t, pool, `INSERT INTO learning_journal_entries (user_id, category, subcategory, title, content)
	               VALUES ($1, 'go', 'basics', 't', 'c')`, multi)
	exec(t, pool, `INSERT INTO roadmaps (user_id, org_id, title, goal_description) VALUES ($1, $2, 'r', 'g')`, multi, orgA)
	// idle: admin with no activity -> nothing. prior: admin already holding
	// member -> not tracked, survives down.
	_, idle := seedOrgAndUser(t, pool, "rb010-idle")
	seedMember(t, pool, orgA, idle, "admin", "active", "tenant_admin")
	_, prior := seedOrgAndUser(t, pool, "rb010-prior")
	seedMember(t, pool, orgA, prior, "admin", "active", "tenant_admin", "member")
	exec(t, pool, `INSERT INTO diary_entries (user_id, entry_date, content) VALUES ($1, CURRENT_DATE, 'x')`, prior)

	var custom string
	if err := pool.QueryRow(ctx, `INSERT INTO roles (org_id, name) VALUES ($1, 'Board Fans') RETURNING id`, orgA).Scan(&custom); err != nil {
		t.Fatalf("seed custom role: %v", err)
	}
	exec(t, pool, `INSERT INTO role_permissions (role_id, permission_id)
	               SELECT $1, id FROM permissions WHERE code = ANY($2::text[]) OR code = 'content.srs'`, custom, dead)
	exec(t, pool, `INSERT INTO user_permission_overrides (user_id, org_id, permission_id)
	               SELECT $1, $2, id FROM permissions WHERE code = 'content.load_test'`, idle, orgA)

	runMigration(t, pool, "010_role_matrix_cleanup.sql")
	if got := systemRoleMatrix(t, pool); !reflect.DeepEqual(got, golden) {
		t.Fatalf("matrix after re-up = %v, want %v", got, golden)
	}
	type grant struct{ user, org string }
	tracked := map[grant]bool{}
	rows, err := pool.Query(ctx, `SELECT b.user_id::text, b.org_id::text FROM rbac_backfill_010 b
	                              JOIN roles r ON r.id = b.role_id AND r.name = 'member' AND r.is_system`)
	if err != nil {
		t.Fatalf("query backfill: %v", err)
	}
	for rows.Next() {
		var g grant
		if err := rows.Scan(&g.user, &g.org); err != nil {
			t.Fatalf("scan backfill: %v", err)
		}
		tracked[g] = true
	}
	rows.Close()
	want := map[grant]bool{{journaler, orgA}: true, {multi, orgA}: true}
	if !reflect.DeepEqual(tracked, want) {
		t.Fatalf("rbac_backfill_010 = %v, want %v", tracked, want)
	}
	var n int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM role_permissions WHERE role_id = $1`, custom).Scan(&n); err != nil || n != 1 {
		t.Fatalf("custom role grants after up = %d (err %v), want 1 (content.srs kept)", n, err)
	}
	codes, err := NewRepo(pool).GetEffectivePermissions(ctx, journaler, orgA)
	if err != nil || !slices.Contains(codes, "content.learning_journal") || !slices.Contains(codes, "admin.manage_org") {
		t.Fatalf("backfilled owner codes = %v (err %v), want member + tenant_admin codes", codes, err)
	}

	runMigration(t, pool, "010_role_matrix_cleanup.down.sql")
	if got := systemRoleMatrix(t, pool); !reflect.DeepEqual(got, before) {
		t.Fatalf("matrix after second down = %v, want %v", got, before)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM role_permissions WHERE role_id = $1`, custom).Scan(&n); err != nil || n != 3 {
		t.Fatalf("custom role grants after down = %d (err %v), want 3", n, err)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM user_permission_overrides WHERE user_id = $1`, idle).Scan(&n); err != nil || n != 1 {
		t.Fatalf("override after down = %d (err %v), want 1", n, err)
	}
	for _, u := range []string{journaler, multi, prior} {
		var hasMember bool
		if err := pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id
		                              WHERE ur.user_id = $1 AND r.name = 'member' AND r.is_system)`, u).Scan(&hasMember); err != nil {
			t.Fatalf("check member: %v", err)
		}
		if hasMember != (u == prior) {
			t.Errorf("user %s member after down = %v, want %v", u, hasMember, u == prior)
		}
	}
	var leftover *string
	if err := pool.QueryRow(ctx, `SELECT to_regclass('rbac_backfill_010')::text`).Scan(&leftover); err != nil || leftover != nil {
		t.Fatalf("rbac_backfill_010 after down = %v (err %v), want dropped", leftover, err)
	}
}
