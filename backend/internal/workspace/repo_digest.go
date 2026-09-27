package workspace

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// repo_digest.go — workspace_digests (contract-phase4.md 4d, D11): one row
// per project per day, the idempotency guard SendDigests' own "insert first,
// 0 rows -> skip" check relies on, plus the previous day's health colour for
// the "health change vs previous row" notification line.

// ListActiveProjectIDs returns every project currently in status='active' —
// SendDigests' own per-project loop (contract-phase4.md: "one [digest] per
// project per day").
func (r *Repo) ListActiveProjectIDs(ctx context.Context) ([]string, error) {
	rows, err := r.pool.Query(ctx, `SELECT id FROM workspace_projects WHERE project_status = 'active'`)
	if err != nil {
		return nil, fmt.Errorf("workspace: list active project ids: %w", err)
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// InsertDigestIfAbsent inserts today's digest row if one doesn't already
// exist for this project+day — returns false (no error) when one already
// does, which SendDigests treats as "already sent today, skip" (idempotency).
func (r *Repo) InsertDigestIfAbsent(ctx context.Context, projectID string, day time.Time, healthColor string) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO workspace_digests (project_id, digest_date, health_color) VALUES ($1, $2::date, $3)
		 ON CONFLICT (project_id, digest_date) DO NOTHING`,
		projectID, day, healthColor,
	)
	if err != nil {
		return false, fmt.Errorf("workspace: insert digest if absent: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

// PreviousDigestHealth returns the health colour of the most recent digest
// strictly before day, "" if this is the project's first ever digest.
func (r *Repo) PreviousDigestHealth(ctx context.Context, projectID string, day time.Time) (string, error) {
	var color string
	err := r.pool.QueryRow(ctx,
		`SELECT health_color FROM workspace_digests WHERE project_id = $1 AND digest_date < $2::date ORDER BY digest_date DESC LIMIT 1`,
		projectID, day,
	).Scan(&color)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("workspace: previous digest health: %w", err)
	}
	return color, nil
}
