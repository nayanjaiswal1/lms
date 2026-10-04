package legal

import (
	"context"
	"fmt"

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

// LatestVersions returns, per doc_type, the version userID most recently
// accepted — absent from the map if they never have.
func (r *Repo) LatestVersions(ctx context.Context, userID string) (map[string]string, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT DISTINCT ON (doc_type) doc_type, version FROM legal_acceptances
		 WHERE user_id = $1
		 ORDER BY doc_type, accepted_at DESC`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("legal: latest versions: %w", err)
	}
	defer rows.Close()
	latest := map[string]string{}
	for rows.Next() {
		var docType, version string
		if err := rows.Scan(&docType, &version); err != nil {
			return nil, fmt.Errorf("legal: scan latest version: %w", err)
		}
		latest[docType] = version
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("legal: latest versions rows: %w", err)
	}
	return latest, nil
}

