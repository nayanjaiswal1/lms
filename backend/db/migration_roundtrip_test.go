package db_test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

const driftMigration = "062_fix_baseline_drift"

// 062's down only drops purchases.created_at's default (it does not touch
// data), so it is safe on the disposable per-test database: apply down,
// verify the effect, re-apply up, verify it is restored.
func TestMigration062_DownThenUpRoundTrips(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()

	run := func(file string) {
		t.Helper()
		sql, err := os.ReadFile(filepath.Join("migrations", file))
		if err != nil {
			t.Fatalf("read %s: %v", file, err)
		}
		if _, err := pool.Exec(ctx, string(sql)); err != nil {
			t.Fatalf("apply %s: %v", file, err)
		}
	}
	createdAtDefault := func() *string {
		t.Helper()
		var def *string
		if err := pool.QueryRow(ctx,
			`SELECT column_default FROM information_schema.columns
			  WHERE table_schema = 'public' AND table_name = 'purchases' AND column_name = 'created_at'`,
		).Scan(&def); err != nil {
			t.Fatalf("read purchases.created_at default: %v", err)
		}
		return def
	}

	if createdAtDefault() == nil {
		t.Fatal("precondition: 062 up should leave a default on purchases.created_at")
	}
	run(driftMigration + ".down.sql")
	if def := createdAtDefault(); def != nil {
		t.Fatalf("after down, created_at default = %q, want none", *def)
	}
	run(driftMigration + ".sql")
	if createdAtDefault() == nil {
		t.Fatal("after re-applying up, created_at default is missing")
	}
	var trigger bool
	if err := pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_member_join_enroll')`).Scan(&trigger); err != nil || trigger {
		t.Fatalf("broken trigger present=%v err=%v after up, want dropped", trigger, err)
	}
}
