package entitlements

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// UserTier returns userID's current pricing_tiers.id.
func (r *Repo) UserTier(ctx context.Context, userID string) (string, error) {
	var tierID string
	if err := r.pool.QueryRow(ctx, `SELECT tier_id FROM users WHERE id = $1`, userID).Scan(&tierID); err != nil {
		return "", fmt.Errorf("entitlements: user tier: %w", err)
	}
	return tierID, nil
}

// OrgTier returns orgID's current pricing_tiers.id.
func (r *Repo) OrgTier(ctx context.Context, orgID string) (string, error) {
	var tierID string
	if err := r.pool.QueryRow(ctx, `SELECT tier_id FROM organizations WHERE id = $1`, orgID).Scan(&tierID); err != nil {
		return "", fmt.Errorf("entitlements: org tier: %w", err)
	}
	return tierID, nil
}

// TierName returns the pricing_tiers.name for tierID, for display (e.g. the
// "My Plan" page's current-tier badge).
func (r *Repo) TierName(ctx context.Context, tierID string) (string, error) {
	var name string
	if err := r.pool.QueryRow(ctx, `SELECT name FROM pricing_tiers WHERE id = $1`, tierID).Scan(&name); err != nil {
		return "", fmt.Errorf("entitlements: tier name: %w", err)
	}
	return name, nil
}

// TierAudience returns the pricing_tiers.audience for tierID, or
// pgx.ErrNoRows if tierID doesn't exist — the caller's guard before pointing
// a user or org at a tier of the wrong audience.
func (r *Repo) TierAudience(ctx context.Context, tierID string) (string, error) {
	var audience string
	if err := r.pool.QueryRow(ctx, `SELECT audience FROM pricing_tiers WHERE id = $1`, tierID).Scan(&audience); err != nil {
		return "", err
	}
	return audience, nil
}

func (r *Repo) SetUserTier(ctx context.Context, userID, tierID, updatedBy string) error {
	if _, err := r.pool.Exec(ctx, `UPDATE users SET tier_id = $2, updated_at = now() WHERE id = $1`, userID, tierID); err != nil {
		return fmt.Errorf("entitlements: set user tier: %w", err)
	}
	return nil
}

func (r *Repo) SetOrgTier(ctx context.Context, orgID, tierID, updatedBy string) error {
	if _, err := r.pool.Exec(ctx, `UPDATE organizations SET tier_id = $2, updated_at = now() WHERE id = $1`, orgID, tierID); err != nil {
		return fmt.Errorf("entitlements: set org tier: %w", err)
	}
	return nil
}

// GateMap returns tierID's gate-kind plan_limits rows keyed by feature_key.
// A key with no row is absent from the map (callers treat that as enabled).
func (r *Repo) GateMap(ctx context.Context, tierID string) (map[string]bool, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT feature_key, bool_value FROM plan_limits WHERE tier_id = $1 AND kind = 'gate'`,
		tierID,
	)
	if err != nil {
		return nil, fmt.Errorf("entitlements: gate map: %w", err)
	}
	defer rows.Close()
	gates := map[string]bool{}
	for rows.Next() {
		var key string
		var enabled bool
		if err := rows.Scan(&key, &enabled); err != nil {
			return nil, fmt.Errorf("entitlements: scan gate: %w", err)
		}
		gates[key] = enabled
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("entitlements: gate rows: %w", err)
	}
	return gates, nil
}

// QuotaLimit reads one quota-kind plan_limits row. found=false means
// unlimited — no row restricts featureKey for this tier.
func (r *Repo) QuotaLimit(ctx context.Context, tierID, featureKey string) (limit int, period string, found bool, err error) {
	err = r.pool.QueryRow(ctx,
		`SELECT numeric_value, period FROM plan_limits WHERE tier_id = $1 AND feature_key = $2 AND kind = 'quota'`,
		tierID, featureKey,
	).Scan(&limit, &period)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, "", false, nil
	}
	if err != nil {
		return 0, "", false, fmt.Errorf("entitlements: quota limit: %w", err)
	}
	return limit, period, true, nil
}

// FirstUnlockingTiers maps each gated feature_key in audience to the name of
// the lowest tier that grants it. Keys no tier grants are absent.
func (r *Repo) FirstUnlockingTiers(ctx context.Context, audience string) (map[string]string, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT DISTINCT ON (pl.feature_key) pl.feature_key, t.name FROM plan_limits pl
		 JOIN pricing_tiers t ON t.id = pl.tier_id
		 WHERE t.audience = $1 AND pl.kind = 'gate' AND pl.bool_value = true
		 ORDER BY pl.feature_key, t.position ASC`,
		audience,
	)
	if err != nil {
		return nil, fmt.Errorf("entitlements: first unlocking tiers: %w", err)
	}
	defer rows.Close()
	tiers := map[string]string{}
	for rows.Next() {
		var key, name string
		if err := rows.Scan(&key, &name); err != nil {
			return nil, fmt.Errorf("entitlements: scan unlocking tier: %w", err)
		}
		tiers[key] = name
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("entitlements: unlocking tier rows: %w", err)
	}
	return tiers, nil
}

// ListPlanLimits returns every plan_limits row for tierID, for the admin
// limits editor.
func (r *Repo) ListPlanLimits(ctx context.Context, tierID string) ([]PlanLimit, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT tier_id, feature_key, kind, bool_value, numeric_value, period, updated_at
		 FROM plan_limits WHERE tier_id = $1 ORDER BY feature_key`,
		tierID,
	)
	if err != nil {
		return nil, fmt.Errorf("entitlements: list plan limits: %w", err)
	}
	defer rows.Close()

	out := []PlanLimit{}
	for rows.Next() {
		var pl PlanLimit
		if err := rows.Scan(&pl.TierID, &pl.FeatureKey, &pl.Kind, &pl.BoolValue, &pl.NumericValue, &pl.Period, &pl.UpdatedAt); err != nil {
			return nil, fmt.Errorf("entitlements: scan plan limit: %w", err)
		}
		out = append(out, pl)
	}
	return out, rows.Err()
}

// UpsertPlanLimit writes one gate or quota row. Validating feature_key
// against the allowlist and kind/audience consistency is the caller's job
// (Service.UpsertPlanLimit).
func (r *Repo) UpsertPlanLimit(ctx context.Context, pl PlanLimit, updatedBy string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO plan_limits (tier_id, feature_key, kind, bool_value, numeric_value, period, updated_by, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, now())
		 ON CONFLICT (tier_id, feature_key) DO UPDATE
		   SET kind = EXCLUDED.kind, bool_value = EXCLUDED.bool_value, numeric_value = EXCLUDED.numeric_value,
		       period = EXCLUDED.period, updated_by = EXCLUDED.updated_by, updated_at = now()`,
		pl.TierID, pl.FeatureKey, pl.Kind, pl.BoolValue, pl.NumericValue, pl.Period, updatedBy,
	)
	if err != nil {
		return fmt.Errorf("entitlements: upsert plan limit: %w", err)
	}
	return nil
}

// currentMonthBounds returns [start, end) for the calendar month now() falls
// in, in UTC — the bucket key every lab_hours row for "this month" shares.
func currentMonthBounds() (start, end time.Time) {
	now := time.Now().UTC()
	start = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	end = start.AddDate(0, 1, 0)
	return start, end
}

// GetMonthlySecondsUsed returns accountID's used_count (container-seconds)
// for featureKey in the current calendar month, 0 if no row exists yet.
func (r *Repo) GetMonthlySecondsUsed(ctx context.Context, accountID, featureKey string) (int64, error) {
	start, _ := currentMonthBounds()
	var used int64
	err := r.pool.QueryRow(ctx,
		`SELECT used_count FROM usage_counters WHERE account_id = $1 AND feature_key = $2 AND period_start = $3`,
		accountID, featureKey, start,
	).Scan(&used)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("entitlements: get monthly usage: %w", err)
	}
	return used, nil
}

// AddMonthlySeconds accrues seconds container-usage onto accountID's current
// month bucket for featureKey, creating the row on first use. No limit check
// here — the pre-flight read (GetMonthlySecondsUsed, called before the
// session that produces this usage starts) is where enforcement happens; see
// docs/entitlements.md §6's note on continuous usage accruing after the
// fact.
func (r *Repo) AddMonthlySeconds(ctx context.Context, accountID, featureKey string, seconds int64) error {
	if seconds <= 0 {
		return nil
	}
	start, end := currentMonthBounds()
	_, err := r.pool.Exec(ctx,
		`INSERT INTO usage_counters (account_id, feature_key, period_start, period_end, used_count, updated_at)
		 VALUES ($1, $2, $3, $4, $5, now())
		 ON CONFLICT (account_id, feature_key, period_start) DO UPDATE
		   SET used_count = usage_counters.used_count + EXCLUDED.used_count, updated_at = now()`,
		accountID, featureKey, start, end, seconds,
	)
	if err != nil {
		return fmt.Errorf("entitlements: add monthly seconds: %w", err)
	}
	return nil
}
