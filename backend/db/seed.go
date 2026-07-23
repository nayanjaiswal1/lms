package db

import (
	"context"
	"embed"
	"fmt"
	"io/fs"
	"log/slog"
	"path"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed fixtures/dev_seed.sql fixtures/grant_all_roles_jaiswal.sql fixtures/*.generated.sql fixtures/warm_pool_seed.sql
var devSeedFS embed.FS

// seedRank buckets a fixture filename into its load-order group. Lower loads
// first. Files within a bucket load in alphabetical order (deterministic, and
// order truly doesn't matter within a bucket today).
//
// A new fixture only needs a matching go:embed pattern above to be picked up
// automatically — nothing else in this file needs to change. That's the whole
// point: the previous version hardcoded a filename list that silently drifted
// out of sync with the actual fixtures/ directory (renamed/consolidated files
// left stale entries pointing at nothing), and SeedDev failed on the first
// missing name — logged as non-fatal, so dev seeding silently no-opped for
// days before anyone noticed. Discovering files from the embed FS instead of
// a hand-maintained list makes that whole failure mode structurally
// impossible: there is no second place to remember to update.
func seedRank(name string) int {
	switch {
	case name == "dev_seed.sql":
		return 0
	case name == "grant_all_roles_jaiswal.sql":
		return 1
	case strings.HasSuffix(name, ".generated.sql"):
		// Pipeline-generated course content (backend/cmd/coursegen) — each file
		// is self-contained and idempotent, order among them doesn't matter, but
		// all must load after dev_seed.sql since they reference its seeded org/users.
		return 2
	default:
		// Anything else (e.g. warm_pool_seed.sql) may reference IDs from the
		// generated files above, so it loads last.
		return 3
	}
}

// SeedDev applies every embedded dev fixture file on every startup, ordered by
// seedRank. All statements are idempotent (ON CONFLICT DO NOTHING / UPDATE).
// Only called when ENV != "production".
func SeedDev(ctx context.Context, pool *pgxpool.Pool) error {
	entries, err := fs.ReadDir(devSeedFS, "fixtures")
	if err != nil {
		return fmt.Errorf("seed: read fixtures dir: %w", err)
	}

	names := make([]string, 0, len(entries))
	for _, e := range entries {
		if !e.IsDir() {
			names = append(names, e.Name())
		}
	}
	sort.SliceStable(names, func(i, j int) bool {
		ri, rj := seedRank(names[i]), seedRank(names[j])
		if ri != rj {
			return ri < rj
		}
		return names[i] < names[j]
	})

	for _, name := range names {
		file := path.Join("fixtures", name)
		sql, err := devSeedFS.ReadFile(file)
		if err != nil {
			return fmt.Errorf("seed: read %s: %w", file, err)
		}
		if _, err := pool.Exec(ctx, string(sql)); err != nil {
			return fmt.Errorf("seed: apply %s: %w", file, err)
		}
		slog.Debug("seed applied", "file", file)
	}

	slog.Info("dev seed OK", "files", len(names))
	return nil
}
