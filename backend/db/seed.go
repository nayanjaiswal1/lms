package db

import (
	"context"
	"embed"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed fixtures/dev_seed.sql
var devSeedFS embed.FS

// SeedDev applies dev_seed.sql once per startup (all statements use ON CONFLICT DO NOTHING,
// so re-runs are safe). Only called when ENV != "production".
func SeedDev(ctx context.Context, pool *pgxpool.Pool) error {
	sql, err := devSeedFS.ReadFile("fixtures/dev_seed.sql")
	if err != nil {
		return fmt.Errorf("seed: read dev_seed.sql: %w", err)
	}

	if _, err := pool.Exec(ctx, string(sql)); err != nil {
		return fmt.Errorf("seed: apply dev_seed.sql: %w", err)
	}

	slog.Info("dev seed OK")
	return nil
}
