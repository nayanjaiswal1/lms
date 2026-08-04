package legal

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// RecordAcceptance inserts a new consent row. Append-only — a re-acceptance
// of the same doc_type/version is a new row, never an update, so the table
// stays a complete audit trail.
func (r *Repo) RecordAcceptance(ctx context.Context, userID, docType, version string, ip *string) (Acceptance, error) {
	var a Acceptance
	err := r.pool.QueryRow(ctx,
		`INSERT INTO legal_acceptances (user_id, doc_type, version, ip)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, user_id, doc_type, version, ip, accepted_at`,
		userID, docType, version, ip,
	).Scan(&a.ID, &a.UserID, &a.DocType, &a.Version, &a.IP, &a.AcceptedAt)
	if err != nil {
		return Acceptance{}, fmt.Errorf("legal: record acceptance: %w", err)
	}
	return a, nil
}

// LatestVersion returns the version of docType userID most recently
// accepted, or "" if they never have.
func (r *Repo) LatestVersion(ctx context.Context, userID, docType string) (string, error) {
	var version string
	err := r.pool.QueryRow(ctx,
		`SELECT version FROM legal_acceptances
		 WHERE user_id = $1 AND doc_type = $2
		 ORDER BY accepted_at DESC LIMIT 1`,
		userID, docType,
	).Scan(&version)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", nil
		}
		return "", fmt.Errorf("legal: latest version: %w", err)
	}
	return version, nil
}
