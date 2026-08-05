package features

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

// GrantedFeatureKeys returns every feature_key granted to userID via permissions.
// Feature grants are now stored as permission codes (e.g., "features.what_now") in
// user_permission_overrides. This queries them directly.
func (r *Repo) GrantedFeatureKeys(ctx context.Context, userID string) ([]string, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT p.code FROM user_permission_overrides upo
		 JOIN permissions p ON p.id = upo.permission_id AND p.is_active = true
		 WHERE upo.user_id = $1 AND p.code LIKE 'features.%'`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("features: granted keys: %w", err)
	}
	defer rows.Close()

	keys := []string{}
	for rows.Next() {
		var code string
		if err := rows.Scan(&code); err != nil {
			return nil, fmt.Errorf("features: scan granted key: %w", err)
		}
		// Strip "features." prefix to get the feature key
		key := code[9:] // len("features.") == 9
		keys = append(keys, key)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("features: granted keys: %w", err)
	}
	return keys, nil
}

// EntitledUserIDs returns every active user holding a "features.<featureKey>"
// permission grant, for batch jobs that need to fan out over an entitled
// cohort rather than resolve one user's config at a time (see EntitledUser's
// doc comment). One row per user: when a user has been granted the same key
// more than once (re-grant after a revoke), DISTINCT ON keeps only their most
// recent grant, which is also where OrgID comes from — user_permission_overrides
// carries org_id per grant, same as GrantedFeatureKeys reads from it, just
// without that query's per-user WHERE filter.
func (r *Repo) EntitledUserIDs(ctx context.Context, featureKey string) ([]EntitledUser, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT DISTINCT ON (u.id) u.id, upo.org_id, u.email, u.name,
		        COALESCE(up.timezone, 'UTC'), up.notifications
		   FROM user_permission_overrides upo
		   JOIN permissions p ON p.id = upo.permission_id AND p.is_active = true
		   JOIN users u ON u.id = upo.user_id AND u.email <> '' AND u.status = 'active'
		   LEFT JOIN user_profiles up ON up.user_id = u.id
		  WHERE p.code = 'features.' || $1
		  ORDER BY u.id, upo.granted_at DESC`,
		featureKey,
	)
	if err != nil {
		return nil, fmt.Errorf("features: entitled user ids: %w", err)
	}
	defer rows.Close()

	out := []EntitledUser{}
	for rows.Next() {
		var eu EntitledUser
		var notifRaw []byte
		if err := rows.Scan(&eu.UserID, &eu.OrgID, &eu.Email, &eu.Name, &eu.Timezone, &notifRaw); err != nil {
			return nil, fmt.Errorf("features: scan entitled user: %w", err)
		}
		if len(notifRaw) > 0 {
			if err := json.Unmarshal(notifRaw, &eu.Notifications); err != nil {
				return nil, fmt.Errorf("features: unmarshal notifications: %w", err)
			}
		}
		out = append(out, eu)
	}
	return out, rows.Err()
}

// OrgFeatureOverrides returns every org_feature_flags row for orgID as a
// key->enabled map. A key absent from the map has never been toggled by a
// platform admin — callers fall back to the code default (alwaysOrgEnabled).
func (r *Repo) OrgFeatureOverrides(ctx context.Context, orgID string) (map[string]bool, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT feature_key, enabled FROM org_feature_flags WHERE org_id = $1`,
		orgID,
	)
	if err != nil {
		return nil, fmt.Errorf("features: org feature overrides: %w", err)
	}
	defer rows.Close()

	overrides := map[string]bool{}
	for rows.Next() {
		var key string
		var enabled bool
		if err := rows.Scan(&key, &enabled); err != nil {
			return nil, fmt.Errorf("features: scan org feature override: %w", err)
		}
		overrides[key] = enabled
	}
	return overrides, rows.Err()
}

// SetOrgFeatureFlag upserts a platform admin's org-level on/off decision for
// featureKey. Validating featureKey against the toggleable domain is the
// caller's job (Service.SetOrgFeatureFlag).
func (r *Repo) SetOrgFeatureFlag(ctx context.Context, orgID, featureKey string, enabled bool, updatedBy string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO org_feature_flags (org_id, feature_key, enabled, updated_by, updated_at)
		 VALUES ($1, $2, $3, $4, now())
		 ON CONFLICT (org_id, feature_key) DO UPDATE
		   SET enabled = EXCLUDED.enabled, updated_by = EXCLUDED.updated_by, updated_at = now()`,
		orgID, featureKey, enabled, updatedBy,
	)
	if err != nil {
		return fmt.Errorf("features: set org feature flag: %w", err)
	}
	return nil
}

// ClearOrgFeatureFlag removes an explicit org-level override, reverting the
// feature back to its code default.
func (r *Repo) ClearOrgFeatureFlag(ctx context.Context, orgID, featureKey string) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM org_feature_flags WHERE org_id = $1 AND feature_key = $2`,
		orgID, featureKey,
	)
	if err != nil {
		return fmt.Errorf("features: clear org feature flag: %w", err)
	}
	return nil
}

// UserFeatureOverrides returns every user_feature_flags row for (orgID,
// userID) as a key->enabled map, same absent-means-default contract as
// OrgFeatureOverrides.
func (r *Repo) UserFeatureOverrides(ctx context.Context, orgID, userID string) (map[string]bool, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT feature_key, enabled FROM user_feature_flags WHERE org_id = $1 AND user_id = $2`,
		orgID, userID,
	)
	if err != nil {
		return nil, fmt.Errorf("features: user feature overrides: %w", err)
	}
	defer rows.Close()

	overrides := map[string]bool{}
	for rows.Next() {
		var key string
		var enabled bool
		if err := rows.Scan(&key, &enabled); err != nil {
			return nil, fmt.Errorf("features: scan user feature override: %w", err)
		}
		overrides[key] = enabled
	}
	return overrides, rows.Err()
}

// SetUserFeatureFlag upserts an org admin's per-member on/off decision for
// featureKey. Validating featureKey and that the org has the feature enabled
// is the caller's job (Service.SetUserFeatureFlag).
func (r *Repo) SetUserFeatureFlag(ctx context.Context, orgID, userID, featureKey string, enabled bool, updatedBy string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_feature_flags (org_id, user_id, feature_key, enabled, updated_by, updated_at)
		 VALUES ($1, $2, $3, $4, $5, now())
		 ON CONFLICT (org_id, user_id, feature_key) DO UPDATE
		   SET enabled = EXCLUDED.enabled, updated_by = EXCLUDED.updated_by, updated_at = now()`,
		orgID, userID, featureKey, enabled, updatedBy,
	)
	if err != nil {
		return fmt.Errorf("features: set user feature flag: %w", err)
	}
	return nil
}

// ClearUserFeatureFlag removes an explicit per-member override, reverting the
// member back to the org's default entitlement for that feature.
func (r *Repo) ClearUserFeatureFlag(ctx context.Context, orgID, userID, featureKey string) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM user_feature_flags WHERE org_id = $1 AND user_id = $2 AND feature_key = $3`,
		orgID, userID, featureKey,
	)
	if err != nil {
		return fmt.Errorf("features: clear user feature flag: %w", err)
	}
	return nil
}

// IsActiveOrgMember reports whether userID is an active (non-removed) member
// of orgID — the IDOR guard before an org admin can toggle a feature for
// someone outside their own org.
func (r *Repo) IsActiveOrgMember(ctx context.Context, orgID, userID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM org_members WHERE org_id = $1 AND user_id = $2 AND status <> 'removed')`,
		orgID, userID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("features: is active org member: %w", err)
	}
	return exists, nil
}

// OrgAIConnectorEnabled reports whether orgID has the AI Connector (MCP)
// feature turned on. No row (never toggled, or orgID doesn't exist) defaults
// to true — the connector shipped enabled for every org, and toggling it off
// is an explicit admin opt-out, not an opt-in.
func (r *Repo) OrgAIConnectorEnabled(ctx context.Context, orgID string) (bool, error) {
	var enabledPtr *bool
	err := r.pool.QueryRow(ctx,
		`SELECT (ai_connector->>'enabled')::boolean FROM org_settings WHERE org_id = $1`,
		orgID,
	).Scan(&enabledPtr)
	if errors.Is(err, pgx.ErrNoRows) {
		return true, nil
	}
	if err != nil {
		return false, fmt.Errorf("features: org ai connector enabled: %w", err)
	}
	if enabledPtr == nil {
		return true, nil
	}
	return *enabledPtr, nil
}

// OrgSessionBookingEnabled reports whether orgID has mentor session booking
// turned on. Like the AI connector above, no row means "never toggled" and
// defaults to true — ad-hoc session scheduling already worked for every org
// before the booking domain existed, so shipping it off would silently
// withdraw a capability people are already using. The org admin turns it off
// explicitly. Mirrors sessions.DefaultConfig().Enabled.
func (r *Repo) OrgSessionBookingEnabled(ctx context.Context, orgID string) (bool, error) {
	var enabledPtr *bool
	err := r.pool.QueryRow(ctx,
		`SELECT (session_booking->>'enabled')::boolean FROM org_settings WHERE org_id = $1`,
		orgID,
	).Scan(&enabledPtr)
	if errors.Is(err, pgx.ErrNoRows) {
		return true, nil
	}
	if err != nil {
		return false, fmt.Errorf("features: org session booking enabled: %w", err)
	}
	if enabledPtr == nil {
		return true, nil
	}
	return *enabledPtr, nil
}
