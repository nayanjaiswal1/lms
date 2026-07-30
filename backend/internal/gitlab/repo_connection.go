package gitlab

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// ─── gitlab_installations ─────────────────────────────────────────────────

const installationColumns = `
	id, org_id, name, is_default, base_url, tier, gitlab_user_id, gitlab_username,
	access_token_enc, access_token_expires_at, refresh_token_enc, auth_kind,
	oauth_client_id, oauth_client_secret_enc, root_group_id, root_group_path,
	webhook_secret_enc, webhook_mode, status, last_error, last_verified_at,
	created_by, created_at, updated_at`

func scanInstallation(row pgx.Row) (*GitlabInstallation, error) {
	var inst GitlabInstallation
	err := row.Scan(
		&inst.ID, &inst.OrgID, &inst.Name, &inst.IsDefault, &inst.BaseURL, &inst.Tier, &inst.GitlabUserID, &inst.GitlabUsername,
		&inst.AccessTokenEnc, &inst.AccessTokenExpiresAt, &inst.RefreshTokenEnc, &inst.AuthKind,
		&inst.OAuthClientID, &inst.OAuthClientSecretEnc, &inst.RootGroupID, &inst.RootGroupPath,
		&inst.WebhookSecretEnc, &inst.WebhookMode, &inst.Status, &inst.LastError, &inst.LastVerifiedAt,
		&inst.CreatedBy, &inst.CreatedAt, &inst.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan installation: %w", err)
	}
	return &inst, nil
}

// GetInstallationByID returns one installation, scoped by both id and org_id
// so a request can never resolve another org's row even with a guessed ID.
func (r *Repo) GetInstallationByID(ctx context.Context, orgID, id string) (*GitlabInstallation, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+installationColumns+` FROM gitlab_installations WHERE id = $1 AND org_id = $2`,
		id, orgID,
	)
	return scanInstallation(row)
}

// GetDefaultInstallation returns the org's current default installation, or
// ErrNotFound if the org has never connected one — callers treat that as
// "GitLab not configured for this org" rather than a logged error.
func (r *Repo) GetDefaultInstallation(ctx context.Context, orgID string) (*GitlabInstallation, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+installationColumns+` FROM gitlab_installations WHERE org_id = $1 AND is_default`,
		orgID,
	)
	return scanInstallation(row)
}

// ListInstallations returns every installation in the org's pool, default
// first — the settings page's list view.
func (r *Repo) ListInstallations(ctx context.Context, orgID string) ([]GitlabInstallation, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+installationColumns+` FROM gitlab_installations WHERE org_id = $1 ORDER BY is_default DESC, created_at`,
		orgID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list installations: %w", err)
	}
	defer rows.Close()

	var out []GitlabInstallation
	for rows.Next() {
		inst, err := scanInstallation(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *inst)
	}
	return out, rows.Err()
}

// CreateInstallationPAT adds a new named installation to the org's pool
// using a verified Personal Access Token — completes synchronously, no
// pending state. Becomes the org's default automatically when it's the
// org's first installation (the partial unique index requires exactly one
// default per org that has any installations at all).
func (r *Repo) CreateInstallationPAT(ctx context.Context, orgID, name, baseURL, tier string, gitlabUserID int64, gitlabUsername string, accessTokenEnc []byte, oauthClientID *string, oauthClientSecretEnc []byte, createdBy string) (*GitlabInstallation, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO gitlab_installations
			(org_id, name, is_default, base_url, tier, gitlab_user_id, gitlab_username, access_token_enc,
			 auth_kind, oauth_client_id, oauth_client_secret_enc, status, last_verified_at, created_by)
		 VALUES ($1, $2, NOT EXISTS (SELECT 1 FROM gitlab_installations WHERE org_id = $1),
		         $3, $4, $5, $6, $7, 'pat', $8, $9, 'active', now(), $10)
		 RETURNING `+installationColumns,
		orgID, name, baseURL, tier, gitlabUserID, gitlabUsername, accessTokenEnc, oauthClientID, oauthClientSecretEnc, createdBy,
	)
	inst, err := scanInstallation(row)
	if err != nil {
		if isUniqueViolation(err) {
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("gitlab: create installation: %w", err)
	}
	return inst, nil
}

// UpdateInstallationPAT replaces an existing installation's credentials
// in-place with a freshly verified Personal Access Token — name and
// is_default are untouched (renaming/re-defaulting are their own actions).
func (r *Repo) UpdateInstallationPAT(ctx context.Context, orgID, id, baseURL, tier string, gitlabUserID int64, gitlabUsername string, accessTokenEnc []byte, oauthClientID *string, oauthClientSecretEnc []byte) (*GitlabInstallation, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE gitlab_installations SET
			base_url = $3, tier = $4, gitlab_user_id = $5, gitlab_username = $6,
			access_token_enc = $7, access_token_expires_at = NULL, refresh_token_enc = NULL,
			auth_kind = 'pat', oauth_client_id = $8, oauth_client_secret_enc = $9,
			status = 'active', last_error = NULL, last_verified_at = now(), updated_at = now()
		 WHERE id = $1 AND org_id = $2
		 RETURNING `+installationColumns,
		id, orgID, baseURL, tier, gitlabUserID, gitlabUsername, accessTokenEnc, oauthClientID, oauthClientSecretEnc,
	)
	return scanInstallation(row)
}

// FinalizeInstallationOAuthCreate completes an installation-purpose OAuth
// callback that's creating a brand-new pool entry: deletes the consumed
// oauth_state row and inserts the installation with its new service-account
// tokens, in one transaction so a mid-failure never leaves a consumable
// state row behind.
func (r *Repo) FinalizeInstallationOAuthCreate(ctx context.Context, state string, orgID, name, baseURL, tier string, gitlabUserID int64, gitlabUsername string, accessTokenEnc []byte, accessTokenExpiresAt time.Time, refreshTokenEnc []byte, oauthClientID *string, oauthClientSecretEnc []byte, createdBy string) (*GitlabInstallation, error) {
	var inst *GitlabInstallation
	err := r.tx(ctx, func(tx pgx.Tx) error {
		if err := consumeOAuthState(ctx, tx, state); err != nil {
			return err
		}
		row := tx.QueryRow(ctx,
			`INSERT INTO gitlab_installations
				(org_id, name, is_default, base_url, tier, gitlab_user_id, gitlab_username,
				 access_token_enc, access_token_expires_at, refresh_token_enc,
				 auth_kind, oauth_client_id, oauth_client_secret_enc, status, last_verified_at, created_by)
			 VALUES ($1, $2, NOT EXISTS (SELECT 1 FROM gitlab_installations WHERE org_id = $1),
			         $3, $4, $5, $6, $7, $8, $9, 'oauth', $10, $11, 'active', now(), $12)
			 RETURNING `+installationColumns,
			orgID, name, baseURL, tier, gitlabUserID, gitlabUsername,
			accessTokenEnc, accessTokenExpiresAt, refreshTokenEnc,
			oauthClientID, oauthClientSecretEnc, createdBy,
		)
		var err error
		inst, err = scanInstallation(row)
		return err
	})
	if err != nil {
		return nil, err
	}
	return inst, nil
}

// FinalizeInstallationOAuthUpdate completes an installation-purpose OAuth
// callback that's reconnecting an existing pool entry (name/is_default
// untouched), in the same consume-state-then-write transaction shape as the
// create path above.
func (r *Repo) FinalizeInstallationOAuthUpdate(ctx context.Context, state string, orgID, id, baseURL, tier string, gitlabUserID int64, gitlabUsername string, accessTokenEnc []byte, accessTokenExpiresAt time.Time, refreshTokenEnc []byte, oauthClientID *string, oauthClientSecretEnc []byte) (*GitlabInstallation, error) {
	var inst *GitlabInstallation
	err := r.tx(ctx, func(tx pgx.Tx) error {
		if err := consumeOAuthState(ctx, tx, state); err != nil {
			return err
		}
		row := tx.QueryRow(ctx,
			`UPDATE gitlab_installations SET
				base_url = $3, tier = $4, gitlab_user_id = $5, gitlab_username = $6,
				access_token_enc = $7, access_token_expires_at = $8, refresh_token_enc = $9,
				auth_kind = 'oauth', oauth_client_id = $10, oauth_client_secret_enc = $11,
				status = 'active', last_error = NULL, last_verified_at = now(), updated_at = now()
			 WHERE id = $1 AND org_id = $2
			 RETURNING `+installationColumns,
			id, orgID, baseURL, tier, gitlabUserID, gitlabUsername,
			accessTokenEnc, accessTokenExpiresAt, refreshTokenEnc,
			oauthClientID, oauthClientSecretEnc,
		)
		var err error
		inst, err = scanInstallation(row)
		return err
	})
	if err != nil {
		return nil, err
	}
	return inst, nil
}

// consumeOAuthState deletes the state row a callback is completing —
// returns ErrNotFound if it's already been consumed (double-submit/replay).
func consumeOAuthState(ctx context.Context, tx pgx.Tx, state string) error {
	tag, err := tx.Exec(ctx, `DELETE FROM gitlab_oauth_states WHERE state = $1`, state)
	if err != nil {
		return fmt.Errorf("delete consumed oauth state: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SetDefaultInstallation atomically moves the org's default flag onto id —
// clears the current default, then sets the new one, in one transaction so
// no window ever has zero or two defaults for the org.
func (r *Repo) SetDefaultInstallation(ctx context.Context, orgID, id string) error {
	return r.tx(ctx, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx,
			`UPDATE gitlab_installations SET is_default = false, updated_at = now() WHERE org_id = $1 AND is_default`,
			orgID,
		); err != nil {
			return fmt.Errorf("clear current default: %w", err)
		}
		tag, err := tx.Exec(ctx,
			`UPDATE gitlab_installations SET is_default = true, updated_at = now() WHERE id = $1 AND org_id = $2`,
			id, orgID,
		)
		if err != nil {
			return fmt.Errorf("set new default: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrNotFound
		}
		return nil
	})
}

// UpdateInstallationVerification records the result of a re-verify call
// (POST /api/gitlab/installations/{id}/verify or the token-refresh job).
func (r *Repo) UpdateInstallationVerification(ctx context.Context, id string, ok bool, lastError *string) error {
	status := InstallationStatusActive
	if !ok {
		status = InstallationStatusError
	}
	_, err := r.pool.Exec(ctx,
		`UPDATE gitlab_installations
		 SET status = $2, last_error = $3, last_verified_at = CASE WHEN $4 THEN now() ELSE last_verified_at END, updated_at = now()
		 WHERE id = $1`,
		id, status, lastError, ok,
	)
	if err != nil {
		return fmt.Errorf("gitlab: update installation verification: %w", err)
	}
	return nil
}

// UpdateInstallationTokens persists a refreshed OAuth access/refresh token
// pair for the installation (called by the token-refresh job).
func (r *Repo) UpdateInstallationTokens(ctx context.Context, id string, accessTokenEnc []byte, expiresAt time.Time, refreshTokenEnc []byte) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE gitlab_installations
		 SET access_token_enc = $2, access_token_expires_at = $3, refresh_token_enc = $4,
		     status = 'active', last_error = NULL, updated_at = now()
		 WHERE id = $1`,
		id, accessTokenEnc, expiresAt, refreshTokenEnc,
	)
	if err != nil {
		return fmt.Errorf("gitlab: update installation tokens: %w", err)
	}
	return nil
}

// MarkInstallationExpired flags an installation whose OAuth refresh failed
// (e.g. invalid_grant — the admin revoked access on the GitLab side).
func (r *Repo) MarkInstallationExpired(ctx context.Context, id string, lastError string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE gitlab_installations SET status = 'expired', last_error = $2, updated_at = now() WHERE id = $1`,
		id, lastError,
	)
	if err != nil {
		return fmt.Errorf("gitlab: mark installation expired: %w", err)
	}
	return nil
}

// ListExpiringOAuthInstallations returns OAuth-kind, active installations
// whose access token expires before `before` — used by the token-refresh job.
// PAT-kind installations are never returned: PATs have no refresh_token to
// exchange, and access_token_expires_at stays NULL for them.
func (r *Repo) ListExpiringOAuthInstallations(ctx context.Context, before time.Time) ([]GitlabInstallation, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+installationColumns+`
		 FROM gitlab_installations
		 WHERE auth_kind = 'oauth' AND status = 'active'
		   AND access_token_expires_at IS NOT NULL AND access_token_expires_at < $1`,
		before,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list expiring installations: %w", err)
	}
	defer rows.Close()

	var out []GitlabInstallation
	for rows.Next() {
		inst, err := scanInstallation(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *inst)
	}
	return out, rows.Err()
}

// SetInstallationWebhookSecret persists a newly generated webhook secret the
// first time a team's provisioning flow needs one to register a project
// hook (see Service.ensureWebhookSecret) — installations created before
// Batch 3 have no secret on file yet, so this is generated lazily rather
// than only at connect time.
func (r *Repo) SetInstallationWebhookSecret(ctx context.Context, id string, webhookSecretEnc []byte) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE gitlab_installations SET webhook_secret_enc = $2, updated_at = now() WHERE id = $1`,
		id, webhookSecretEnc,
	)
	if err != nil {
		return fmt.Errorf("gitlab: set installation webhook secret: %w", err)
	}
	return nil
}

// SetInstallationWebhookMode flips webhook_mode to 'webhook' once a project
// hook has actually been registered successfully — installations otherwise
// default to 'poll' (migration 023's column default) until this fires, so
// gitlab.poll_sync's self-healing sweep only ever treats an installation as
// poll-only before its first successful hook registration, not forever after.
func (r *Repo) SetInstallationWebhookMode(ctx context.Context, id, mode string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE gitlab_installations SET webhook_mode = $2, updated_at = now() WHERE id = $1`,
		id, mode,
	)
	if err != nil {
		return fmt.Errorf("gitlab: set installation webhook mode: %w", err)
	}
	return nil
}

// DeleteInstallationByID hard-deletes one pool installation. Returns
// ErrCannotDeleteDefault if it's the org's current default and other
// installations still exist — the admin must set a different one as default
// first (SetDefaultInstallation) rather than leaving the org's "default"
// concept dangling. Deleting an org's *only* installation is fine: it
// returns the org to "GitLab not configured", the same ErrNotFound state
// every installation-dependent code path already treats as expected.
// project_assignments.installation_id's ON DELETE RESTRICT (migration 024)
// separately blocks deleting one still pinned to a live assignment.
func (r *Repo) DeleteInstallationByID(ctx context.Context, orgID, id string) error {
	return r.tx(ctx, func(tx pgx.Tx) error {
		var isDefault bool
		var otherCount int
		if err := tx.QueryRow(ctx,
			`SELECT is_default, (SELECT count(*) FROM gitlab_installations WHERE org_id = $2 AND id != $1)
			 FROM gitlab_installations WHERE id = $1 AND org_id = $2`,
			id, orgID,
		).Scan(&isDefault, &otherCount); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("gitlab: check installation before delete: %w", err)
		}
		if isDefault && otherCount > 0 {
			return ErrCannotDeleteDefault
		}

		tag, err := tx.Exec(ctx, `DELETE FROM gitlab_installations WHERE id = $1 AND org_id = $2`, id, orgID)
		if err != nil {
			return fmt.Errorf("gitlab: delete installation: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrNotFound
		}
		return nil
	})
}

// ─── gitlab_connections ────────────────────────────────────────────────────

const connectionColumns = `
	id, org_id, user_id, gitlab_user_id, gitlab_username, gitlab_email, avatar_url,
	access_token_enc, access_token_expires_at, refresh_token_enc, scopes, status,
	last_used_at, created_at, updated_at, revoked_at`

func scanConnection(row pgx.Row) (*GitlabConnection, error) {
	var c GitlabConnection
	err := row.Scan(
		&c.ID, &c.OrgID, &c.UserID, &c.GitlabUserID, &c.GitlabUsername, &c.GitlabEmail, &c.AvatarURL,
		&c.AccessTokenEnc, &c.AccessTokenExpiresAt, &c.RefreshTokenEnc, &c.Scopes, &c.Status,
		&c.LastUsedAt, &c.CreatedAt, &c.UpdatedAt, &c.RevokedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan connection: %w", err)
	}
	return &c, nil
}

// GetConnection returns a user's own GitLab connection, or ErrNotFound if
// they haven't connected one.
func (r *Repo) GetConnection(ctx context.Context, orgID, userID string) (*GitlabConnection, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+connectionColumns+` FROM gitlab_connections WHERE org_id = $1 AND user_id = $2`,
		orgID, userID,
	)
	return scanConnection(row)
}

// FinalizeConnectionOAuth completes a connection-purpose OAuth callback:
// deletes the consumed oauth_state row and upserts the member's connection,
// in one transaction.
func (r *Repo) FinalizeConnectionOAuth(ctx context.Context, state, orgID, userID string, gitlabUserID int64, gitlabUsername string, gitlabEmail, avatarURL *string, accessTokenEnc []byte, accessTokenExpiresAt time.Time, refreshTokenEnc []byte, scopes []string) (*GitlabConnection, error) {
	var conn *GitlabConnection
	err := r.tx(ctx, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `DELETE FROM gitlab_oauth_states WHERE state = $1`, state)
		if err != nil {
			return fmt.Errorf("delete consumed oauth state: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrNotFound
		}

		row := tx.QueryRow(ctx,
			`INSERT INTO gitlab_connections
				(org_id, user_id, gitlab_user_id, gitlab_username, gitlab_email, avatar_url,
				 access_token_enc, access_token_expires_at, refresh_token_enc, scopes, status, last_used_at)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'active', now())
			 ON CONFLICT (org_id, user_id) DO UPDATE SET
				gitlab_user_id = EXCLUDED.gitlab_user_id,
				gitlab_username = EXCLUDED.gitlab_username,
				gitlab_email = EXCLUDED.gitlab_email,
				avatar_url = EXCLUDED.avatar_url,
				access_token_enc = EXCLUDED.access_token_enc,
				access_token_expires_at = EXCLUDED.access_token_expires_at,
				refresh_token_enc = EXCLUDED.refresh_token_enc,
				scopes = EXCLUDED.scopes,
				status = 'active',
				last_used_at = now(),
				revoked_at = NULL,
				updated_at = now()
			 RETURNING `+connectionColumns,
			orgID, userID, gitlabUserID, gitlabUsername, gitlabEmail, avatarURL,
			accessTokenEnc, accessTokenExpiresAt, refreshTokenEnc, scopes,
		)
		conn, err = scanConnection(row)
		return err
	})
	if err != nil {
		return nil, err
	}
	return conn, nil
}

// UpdateConnectionTokens persists a refreshed OAuth access/refresh token pair
// for a member's connection (called by the token-refresh job).
func (r *Repo) UpdateConnectionTokens(ctx context.Context, orgID, userID string, accessTokenEnc []byte, expiresAt time.Time, refreshTokenEnc []byte) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE gitlab_connections
		 SET access_token_enc = $3, access_token_expires_at = $4, refresh_token_enc = $5,
		     status = 'active', updated_at = now()
		 WHERE org_id = $1 AND user_id = $2`,
		orgID, userID, accessTokenEnc, expiresAt, refreshTokenEnc,
	)
	if err != nil {
		return fmt.Errorf("gitlab: update connection tokens: %w", err)
	}
	return nil
}

// MarkConnectionExpired flags a connection whose OAuth refresh failed (e.g.
// the member revoked access on the GitLab side).
func (r *Repo) MarkConnectionExpired(ctx context.Context, orgID, userID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE gitlab_connections SET status = 'expired', updated_at = now() WHERE org_id = $1 AND user_id = $2`,
		orgID, userID,
	)
	if err != nil {
		return fmt.Errorf("gitlab: mark connection expired: %w", err)
	}
	return nil
}

// ListExpiringConnections returns active connections whose access token
// expires before `before` — used by the token-refresh job.
func (r *Repo) ListExpiringConnections(ctx context.Context, before time.Time) ([]GitlabConnection, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+connectionColumns+`
		 FROM gitlab_connections
		 WHERE status = 'active' AND access_token_expires_at IS NOT NULL AND access_token_expires_at < $1`,
		before,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list expiring connections: %w", err)
	}
	defer rows.Close()

	var out []GitlabConnection
	for rows.Next() {
		c, err := scanConnection(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

// DeleteConnection hard-deletes a member's own connection row (disconnect).
func (r *Repo) DeleteConnection(ctx context.Context, orgID, userID string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM gitlab_connections WHERE org_id = $1 AND user_id = $2`, orgID, userID)
	if err != nil {
		return fmt.Errorf("gitlab: delete connection: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ─── gitlab_oauth_states ───────────────────────────────────────────────────

// InsertOAuthState persists a new PKCE flow's server-side state ahead of
// redirecting the browser to GitLab's /oauth/authorize.
func (r *Repo) InsertOAuthState(ctx context.Context, st GitlabOAuthState) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO gitlab_oauth_states
			(state, org_id, user_id, purpose, code_verifier, base_url, oauth_client_id, oauth_client_secret_enc, redirect_to, name, installation_id, expires_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
		st.State, st.OrgID, st.UserID, st.Purpose, st.CodeVerifier, st.BaseURL, st.OAuthClientID, st.OAuthClientSecretEnc, st.RedirectTo, st.Name, st.InstallationID, st.ExpiresAt,
	)
	if err != nil {
		return fmt.Errorf("gitlab: insert oauth state: %w", err)
	}
	return nil
}

// GetOAuthState looks up a pending flow's state without consuming it — used
// by the callback handler to decide how to complete the flow before the
// finalize step deletes the row as part of its own transaction.
func (r *Repo) GetOAuthState(ctx context.Context, state string) (*GitlabOAuthState, error) {
	var st GitlabOAuthState
	err := r.pool.QueryRow(ctx,
		`SELECT state, org_id, user_id, purpose, code_verifier, base_url, oauth_client_id, oauth_client_secret_enc, redirect_to, name, installation_id, expires_at, created_at
		 FROM gitlab_oauth_states WHERE state = $1`,
		state,
	).Scan(&st.State, &st.OrgID, &st.UserID, &st.Purpose, &st.CodeVerifier, &st.BaseURL, &st.OAuthClientID, &st.OAuthClientSecretEnc, &st.RedirectTo, &st.Name, &st.InstallationID, &st.ExpiresAt, &st.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: get oauth state: %w", err)
	}
	if st.ExpiresAt.Before(time.Now()) {
		// Best-effort cleanup; the row's own TTL sweep (if any is added later)
		// is not required for correctness — expired states never validate.
		_, _ = r.pool.Exec(ctx, `DELETE FROM gitlab_oauth_states WHERE state = $1`, state)
		return nil, ErrStateExpired
	}
	return &st, nil
}

// ─── gitlab_org_config ─────────────────────────────────────────────────────

// GetOrgConfig returns the org's GitLab policy row, or ErrNotFound if it's
// never set one — callers treat that as AllowProjectOverride: true (the
// column's own default), the same "absence means default" convention
// GetDefaultInstallation uses for "not connected yet".
func (r *Repo) GetOrgConfig(ctx context.Context, orgID string) (*GitlabOrgConfig, error) {
	var cfg GitlabOrgConfig
	err := r.pool.QueryRow(ctx,
		`SELECT org_id, allow_project_override, updated_at FROM gitlab_org_config WHERE org_id = $1`,
		orgID,
	).Scan(&cfg.OrgID, &cfg.AllowProjectOverride, &cfg.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: get org config: %w", err)
	}
	return &cfg, nil
}

// UpsertOrgConfig sets the org's allow_project_override policy.
func (r *Repo) UpsertOrgConfig(ctx context.Context, orgID string, allowOverride bool) (*GitlabOrgConfig, error) {
	var cfg GitlabOrgConfig
	err := r.pool.QueryRow(ctx,
		`INSERT INTO gitlab_org_config (org_id, allow_project_override)
		 VALUES ($1, $2)
		 ON CONFLICT (org_id) DO UPDATE SET allow_project_override = EXCLUDED.allow_project_override, updated_at = now()
		 RETURNING org_id, allow_project_override, updated_at`,
		orgID, allowOverride,
	).Scan(&cfg.OrgID, &cfg.AllowProjectOverride, &cfg.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("gitlab: upsert org config: %w", err)
	}
	return &cfg, nil
}
