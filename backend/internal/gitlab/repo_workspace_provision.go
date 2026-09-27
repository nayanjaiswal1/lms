package gitlab

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// EnsureWorkspaceBatch returns the id of the org's hidden workspace batch,
// creating it on first use. batches has a real UNIQUE(org_id, slug)
// constraint, so this is race-safe: INSERT ... ON CONFLICT DO NOTHING first,
// then a plain SELECT if another concurrent call won the insert.
func (r *Repo) EnsureWorkspaceBatch(ctx context.Context, orgID, createdBy, name, slug string) (string, error) {
	var id string
	err := r.pool.QueryRow(ctx,
		`INSERT INTO batches (org_id, name, slug, created_by) VALUES ($1,$2,$3,$4)
		 ON CONFLICT (org_id, slug) DO NOTHING RETURNING id`,
		orgID, name, slug, createdBy,
	).Scan(&id)
	if err == nil {
		return id, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", fmt.Errorf("gitlab: ensure workspace batch: insert: %w", err)
	}
	if err := r.pool.QueryRow(ctx, `SELECT id FROM batches WHERE org_id = $1 AND slug = $2`, orgID, slug).Scan(&id); err != nil {
		return "", fmt.Errorf("gitlab: ensure workspace batch: lookup: %w", err)
	}
	return id, nil
}
