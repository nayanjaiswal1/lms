package features

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

// OrgAIConnectorEnabled reports whether orgID has the AI Connector (MCP)
// feature turned on. No row (never toggled, or orgID doesn't exist) defaults
// to true — the connector shipped enabled for every org, and toggling it off
// is an explicit admin opt-out, not an opt-in.
func (r *Repo) OrgAIConnectorEnabled(ctx context.Context, orgID string) (bool, error) {
	var enabled bool
	err := r.pool.QueryRow(ctx,
		`SELECT enabled FROM org_ai_connector_config WHERE org_id = $1`,
		orgID,
	).Scan(&enabled)
	if errors.Is(err, pgx.ErrNoRows) {
		return true, nil
	}
	if err != nil {
		return false, fmt.Errorf("features: org ai connector enabled: %w", err)
	}
	return enabled, nil
}
