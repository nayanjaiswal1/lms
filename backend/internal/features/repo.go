package features

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

// GrantedFeatureKeys returns every feature_key directly granted to userID.
func (r *Repo) GrantedFeatureKeys(ctx context.Context, userID string) ([]string, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT feature_key FROM feature_grants WHERE user_id = $1`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("features: granted keys: %w", err)
	}
	defer rows.Close()

	keys := []string{}
	for rows.Next() {
		var key string
		if err := rows.Scan(&key); err != nil {
			return nil, fmt.Errorf("features: scan granted key: %w", err)
		}
		keys = append(keys, key)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("features: granted keys: %w", err)
	}
	return keys, nil
}
