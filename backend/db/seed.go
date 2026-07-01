package db

import (
	"context"
	"embed"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed fixtures/dev_seed.sql fixtures/grant_all_roles_jaiswal.sql fixtures/k8s_*.sql
var devSeedFS embed.FS

// SeedDev applies all dev fixture files on every startup.
// All statements are idempotent (ON CONFLICT DO NOTHING / UPDATE). Only called when ENV != "production".
func SeedDev(ctx context.Context, pool *pgxpool.Pool) error {
	files := []string{
		"fixtures/dev_seed.sql",
		"fixtures/grant_all_roles_jaiswal.sql",
		// K8s courses — run in dependency order
		"fixtures/k8s_01_setup.sql",
		"fixtures/k8s_02_questions_q1q2.sql",
		"fixtures/k8s_03_questions_q3q4.sql",
		"fixtures/k8s_04_questions_q5q6.sql",
		"fixtures/k8s_05_questions_q7q8.sql",
		"fixtures/k8s_06_assessments.sql",
		"fixtures/k8s_07_courses.sql",
		"fixtures/k8s_08_lab1.sql",
		"fixtures/k8s_09_lab2.sql",
		"fixtures/k8s_10_lab3.sql",
		"fixtures/k8s_11_lab4.sql",
		"fixtures/k8s_12_lab5.sql",
		"fixtures/k8s_13_lab6.sql",
		"fixtures/k8s_14_lab7.sql",
		"fixtures/k8s_15_lab8.sql",
		"fixtures/k8s_16_enrollments.sql",
	}

	for _, name := range files {
		sql, err := devSeedFS.ReadFile(name)
		if err != nil {
			return fmt.Errorf("seed: read %s: %w", name, err)
		}
		if _, err := pool.Exec(ctx, string(sql)); err != nil {
			return fmt.Errorf("seed: apply %s: %w", name, err)
		}
		slog.Debug("seed applied", "file", name)
	}

	slog.Info("dev seed OK")
	return nil
}
