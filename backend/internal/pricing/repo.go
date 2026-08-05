package pricing

import (
	"context"
	"encoding/json"
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

const tierColumns = `id, audience, position, name, price, billing_note, tagline, features, cta_label, cta_disabled, cta_href, highlighted, updated_by, updated_at`

func marshalFeatures(features []string) ([]byte, error) {
	if features == nil {
		features = []string{}
	}
	return json.Marshal(features)
}

func scanTier(row pgx.Row) (Tier, error) {
	var t Tier
	var featuresRaw []byte
	err := row.Scan(&t.ID, &t.Audience, &t.Position, &t.Name, &t.Price, &t.BillingNote, &t.Tagline,
		&featuresRaw, &t.CTALabel, &t.CTADisabled, &t.CTAHref, &t.Highlighted, &t.UpdatedBy, &t.UpdatedAt)
	if err != nil {
		return Tier{}, err
	}
	t.Features = []string{}
	if len(featuresRaw) > 0 {
		if err := json.Unmarshal(featuresRaw, &t.Features); err != nil {
			return Tier{}, fmt.Errorf("pricing: unmarshal features: %w", err)
		}
	}
	return t, nil
}

// ListByAudience returns the published tiers for one landing page, ordered
// for direct display — the audience the public /api/public/pricing endpoint
// always passes explicitly (there is no "both" case for a single page).
func (r *Repo) ListByAudience(ctx context.Context, audience string) ([]Tier, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+tierColumns+` FROM pricing_tiers WHERE audience = $1 ORDER BY position`,
		audience,
	)
	if err != nil {
		return nil, fmt.Errorf("pricing: list by audience: %w", err)
	}
	defer rows.Close()

	out := []Tier{}
	for rows.Next() {
		t, err := scanTier(rows)
		if err != nil {
			return nil, fmt.Errorf("pricing: scan tier: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListAll returns every tier across both audiences, for the platform admin
// page that edits the whole pricing table at once.
func (r *Repo) ListAll(ctx context.Context) ([]Tier, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+tierColumns+` FROM pricing_tiers ORDER BY audience, position`,
	)
	if err != nil {
		return nil, fmt.Errorf("pricing: list all: %w", err)
	}
	defer rows.Close()

	out := []Tier{}
	for rows.Next() {
		t, err := scanTier(rows)
		if err != nil {
			return nil, fmt.Errorf("pricing: scan tier: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// Update overwrites the editable fields of an existing tier (id, audience,
// and position are structural — fixed by the seed migration, not editable
// through this admin surface) and stamps who changed it.
func (r *Repo) Update(ctx context.Context, id string, t Tier, updatedBy string) (Tier, error) {
	featuresRaw, err := marshalFeatures(t.Features)
	if err != nil {
		return Tier{}, fmt.Errorf("pricing: marshal features: %w", err)
	}

	row := r.pool.QueryRow(ctx,
		`UPDATE pricing_tiers
		    SET name = $2, price = $3, billing_note = $4, tagline = $5, features = $6,
		        cta_label = $7, cta_disabled = $8, cta_href = $9, highlighted = $10,
		        updated_by = $11, updated_at = now()
		  WHERE id = $1
		  RETURNING `+tierColumns,
		id, t.Name, t.Price, t.BillingNote, t.Tagline, featuresRaw,
		t.CTALabel, t.CTADisabled, t.CTAHref, t.Highlighted, updatedBy,
	)
	updated, err := scanTier(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Tier{}, ErrNotFound
		}
		return Tier{}, fmt.Errorf("pricing: update: %w", err)
	}
	return updated, nil
}
