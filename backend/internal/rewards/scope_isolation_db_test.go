package rewards

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// Leaderboard scope ids come from the client; ScopeInOrg is the tenancy gate.
// A cohort group owned by org A must not be accepted as an org B scope.
// (XP/achievement tables are per-user with no by-id read/update API, so the
// scope owner check is the cross-tenant read boundary in this repo.)
func TestScopeInOrg_RejectsOtherTenantsGroup(t *testing.T) {
	pool := testdb.New(t)
	repo := NewRepo(pool, nil)
	ctx := context.Background()

	var orgA, orgB, userID, groupID string
	for slug, dst := range map[string]*string{"rw-a": &orgA, "rw-b": &orgB} {
		if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ($1, $1) RETURNING id`, slug).Scan(dst); err != nil {
			t.Fatalf("seed org %s: %v", slug, err)
		}
	}
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('rw@`+testdomain.Domain+`', 'RW') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO cohort_groups (org_id, name, slug, created_by) VALUES ($1, 'G', 'g', $2) RETURNING id`,
		orgA, userID).Scan(&groupID); err != nil {
		t.Fatalf("seed group: %v", err)
	}

	if ok, err := repo.ScopeInOrg(ctx, "group", groupID, orgA); err != nil || !ok {
		t.Fatalf("owner org: ok=%v err=%v, want true", ok, err)
	}
	if ok, err := repo.ScopeInOrg(ctx, "group", groupID, orgB); err != nil || ok {
		t.Fatalf("other org: ok=%v err=%v, want false", ok, err)
	}
}
