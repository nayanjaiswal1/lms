package orgs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/secrets"
)

// Repo is the data-access layer for org configuration.
// All methods read/write the org_settings JSONB table and handle encryption where needed.
type Repo struct {
	pool  *pgxpool.Pool
	vault *secrets.Vault
}

// NewRepo constructs a Repo over the shared connection pool and secrets vault.
func NewRepo(pool *pgxpool.Pool, vault *secrets.Vault) *Repo {
	return &Repo{pool: pool, vault: vault}
}

// ─── org_settings namespace structs ───────────────────────────────────────

// AuthSettings represents org_settings.auth namespace.
// Unmarshalled from JSONB with sensible zero-value defaults when empty.
type AuthSettings struct {
	SSOEnabled       *bool   `json:"sso_enabled,omitempty"`
	OIDCIssuerURL    *string `json:"oidc_issuer_url,omitempty"`
	OIDCClientID     *string `json:"oidc_client_id,omitempty"`
	SAMLMetadataXML  *string `json:"saml_metadata_xml,omitempty"`
}

// AIConnectorSettings represents org_settings.ai_connector namespace.
type AIConnectorSettings struct {
	Enabled *bool `json:"enabled,omitempty"`
}

// JobsSettings represents org_settings.jobs namespace.
type JobsSettings struct {
	MaxConcurrentJobs    *int `json:"max_concurrent_jobs,omitempty"`
	QueuedJobTTLMinutes  *int `json:"queued_job_ttl_minutes,omitempty"`
	ActiveJobTimeoutHrs  *int `json:"active_job_timeout_hrs,omitempty"`
}

// GitlabSettings represents org_settings.gitlab namespace.
type GitlabSettings struct {
	AllowProjectOverride *bool `json:"allow_project_override,omitempty"`
}

// LabsSettings represents org_settings.labs namespace.
type LabsSettings struct {
	MaxConcurrentSessions *int      `json:"max_concurrent_sessions,omitempty"`
	MaxSessionDurationMin *int      `json:"max_session_duration,omitempty"`
	AllowedImages         []string  `json:"allowed_images,omitempty"`
	EgressProxyEnabled    *bool     `json:"egress_proxy_enabled,omitempty"`
}

// SessionBookingSettings represents org_settings.session_booking namespace.
type SessionBookingSettings struct {
	Enabled                 *bool   `json:"enabled,omitempty"`
	CreditsPerSession       *int    `json:"credits_per_session,omitempty"`
	CancellationWindow      *int    `json:"cancellation_window,omitempty"`
	FeedbackRequired        *bool   `json:"feedback_required,omitempty"`
	MinSessionDurationMins  *int    `json:"min_session_duration_mins,omitempty"`
	MaxSessionDurationMins  *int    `json:"max_session_duration_mins,omitempty"`
}

// ─── AuthSettings accessors ───────────────────────────────────────────────

// GetAuthSettings reads the auth namespace from org_settings, returning
// zero-value AuthSettings when the row or column is empty.
func (r *Repo) GetAuthSettings(ctx context.Context, orgID string) (*AuthSettings, error) {
	var raw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(auth, '{}'::jsonb) FROM org_settings WHERE org_id = $1`,
		orgID,
	).Scan(&raw)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("orgs: get auth settings: %w", err)
	}

	var settings AuthSettings
	if len(raw) > 0 && string(raw) != "{}" {
		if err := json.Unmarshal(raw, &settings); err != nil {
			return nil, fmt.Errorf("orgs: unmarshal auth settings: %w", err)
		}
	}
	return &settings, nil
}

// UpsertAuthSettings writes the auth namespace, creating org_settings row if needed.
func (r *Repo) UpsertAuthSettings(ctx context.Context, orgID string, settings *AuthSettings) error {
	raw, err := json.Marshal(settings)
	if err != nil {
		return fmt.Errorf("orgs: marshal auth settings: %w", err)
	}

	_, err = r.pool.Exec(ctx,
		`INSERT INTO org_settings (org_id, auth, updated_at)
		 VALUES ($1, $2::jsonb, now())
		 ON CONFLICT (org_id) DO UPDATE SET auth = EXCLUDED.auth, updated_at = now()`,
		orgID, raw,
	)
	if err != nil {
		return fmt.Errorf("orgs: upsert auth settings: %w", err)
	}
	return nil
}

// ─── OIDC secret encryption (in org_auth_config table) ────────────────────

// GetOIDCSecret reads the OIDC client secret for an org, decrypting from
// oidc_client_secret_enc (bytea) if available, with a fallback to the
// deprecated plaintext oidc_client_secret column. Returns ("", nil) when
// no secret is configured.
func (r *Repo) GetOIDCSecret(ctx context.Context, orgID string) (string, error) {
	var encryptedSecret []byte
	var plaintextSecret *string

	err := r.pool.QueryRow(ctx,
		`SELECT oidc_client_secret_enc, oidc_client_secret
		 FROM org_auth_config
		 WHERE org_id = $1`,
		orgID,
	).Scan(&encryptedSecret, &plaintextSecret)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", nil
		}
		return "", fmt.Errorf("orgs: read oidc secret: %w", err)
	}

	// Prefer encrypted, fallback to plaintext.
	if len(encryptedSecret) > 0 {
		decrypted, err := r.vault.Decrypt(encryptedSecret)
		if err != nil {
			return "", fmt.Errorf("orgs: decrypt oidc secret: %w", err)
		}
		return string(decrypted), nil
	}

	if plaintextSecret != nil {
		return *plaintextSecret, nil
	}

	return "", nil
}

// SetOIDCSecret encrypts and writes the OIDC client secret to oidc_client_secret_enc.
// Creates org_auth_config row if needed. Clears the plaintext column to encourage
// backfill (though backfill is async).
func (r *Repo) SetOIDCSecret(ctx context.Context, orgID, secret string) error {
	encrypted, err := r.vault.Encrypt([]byte(secret))
	if err != nil {
		return fmt.Errorf("orgs: encrypt oidc secret: %w", err)
	}

	_, err = r.pool.Exec(ctx,
		`INSERT INTO org_auth_config (org_id, oidc_client_secret_enc, oidc_client_secret)
		 VALUES ($1, $2, NULL)
		 ON CONFLICT (org_id) DO UPDATE SET
		   oidc_client_secret_enc = EXCLUDED.oidc_client_secret_enc,
		   oidc_client_secret = NULL,
		   updated_at = now()`,
		orgID, encrypted,
	)
	if err != nil {
		return fmt.Errorf("orgs: set oidc secret: %w", err)
	}
	return nil
}

// BackfillOIDCSecrets is a one-time migration job that reads plaintext OIDC secrets
// from org_auth_config.oidc_client_secret and encrypts them into oidc_client_secret_enc.
// Idempotent — skips rows already encrypted. Returns the number of rows backfilled.
func (r *Repo) BackfillOIDCSecrets(ctx context.Context) (int, error) {
	// Find rows with plaintext secret but no encrypted version.
	rows, err := r.pool.Query(ctx,
		`SELECT org_id, oidc_client_secret
		 FROM org_auth_config
		 WHERE oidc_client_secret IS NOT NULL
		   AND oidc_client_secret_enc IS NULL`,
	)
	if err != nil {
		return 0, fmt.Errorf("orgs: backfill: read plaintext secrets: %w", err)
	}
	defer rows.Close()

	var backfilled int
	for rows.Next() {
		var orgID, plaintext string
		if err := rows.Scan(&orgID, &plaintext); err != nil {
			return backfilled, fmt.Errorf("orgs: backfill: scan row: %w", err)
		}

		encrypted, err := r.vault.Encrypt([]byte(plaintext))
		if err != nil {
			return backfilled, fmt.Errorf("orgs: backfill: encrypt secret for %s: %w", orgID, err)
		}

		// Write encrypted version; don't touch plaintext yet.
		_, err = r.pool.Exec(ctx,
			`UPDATE org_auth_config
			 SET oidc_client_secret_enc = $2, updated_at = now()
			 WHERE org_id = $1`,
			orgID, encrypted,
		)
		if err != nil {
			return backfilled, fmt.Errorf("orgs: backfill: write encrypted for %s: %w", orgID, err)
		}

		backfilled++
	}

	return backfilled, rows.Err()
}

// ─── AIConnectorSettings accessors ─────────────────────────────────────────

// GetAIConnectorSettings reads the ai_connector namespace from org_settings.
func (r *Repo) GetAIConnectorSettings(ctx context.Context, orgID string) (*AIConnectorSettings, error) {
	var raw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(ai_connector, '{}'::jsonb) FROM org_settings WHERE org_id = $1`,
		orgID,
	).Scan(&raw)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("orgs: get ai connector settings: %w", err)
	}

	var settings AIConnectorSettings
	if len(raw) > 0 && string(raw) != "{}" {
		if err := json.Unmarshal(raw, &settings); err != nil {
			return nil, fmt.Errorf("orgs: unmarshal ai connector settings: %w", err)
		}
	}
	return &settings, nil
}

// UpsertAIConnectorSettings writes the ai_connector namespace.
func (r *Repo) UpsertAIConnectorSettings(ctx context.Context, orgID string, settings *AIConnectorSettings) error {
	raw, err := json.Marshal(settings)
	if err != nil {
		return fmt.Errorf("orgs: marshal ai connector settings: %w", err)
	}

	_, err = r.pool.Exec(ctx,
		`INSERT INTO org_settings (org_id, ai_connector, updated_at)
		 VALUES ($1, $2::jsonb, now())
		 ON CONFLICT (org_id) DO UPDATE SET ai_connector = EXCLUDED.ai_connector, updated_at = now()`,
		orgID, raw,
	)
	if err != nil {
		return fmt.Errorf("orgs: upsert ai connector settings: %w", err)
	}
	return nil
}

// ─── JobsSettings accessors ───────────────────────────────────────────────

// GetJobsSettings reads the jobs namespace from org_settings.
func (r *Repo) GetJobsSettings(ctx context.Context, orgID string) (*JobsSettings, error) {
	var raw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(jobs, '{}'::jsonb) FROM org_settings WHERE org_id = $1`,
		orgID,
	).Scan(&raw)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("orgs: get jobs settings: %w", err)
	}

	var settings JobsSettings
	if len(raw) > 0 && string(raw) != "{}" {
		if err := json.Unmarshal(raw, &settings); err != nil {
			return nil, fmt.Errorf("orgs: unmarshal jobs settings: %w", err)
		}
	}
	return &settings, nil
}

// UpsertJobsSettings writes the jobs namespace.
func (r *Repo) UpsertJobsSettings(ctx context.Context, orgID string, settings *JobsSettings) error {
	raw, err := json.Marshal(settings)
	if err != nil {
		return fmt.Errorf("orgs: marshal jobs settings: %w", err)
	}

	_, err = r.pool.Exec(ctx,
		`INSERT INTO org_settings (org_id, jobs, updated_at)
		 VALUES ($1, $2::jsonb, now())
		 ON CONFLICT (org_id) DO UPDATE SET jobs = EXCLUDED.jobs, updated_at = now()`,
		orgID, raw,
	)
	if err != nil {
		return fmt.Errorf("orgs: upsert jobs settings: %w", err)
	}
	return nil
}

// ─── GitlabSettings accessors ──────────────────────────────────────────────

// GetGitlabSettings reads the gitlab namespace from org_settings.
func (r *Repo) GetGitlabSettings(ctx context.Context, orgID string) (*GitlabSettings, error) {
	var raw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(gitlab, '{}'::jsonb) FROM org_settings WHERE org_id = $1`,
		orgID,
	).Scan(&raw)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("orgs: get gitlab settings: %w", err)
	}

	var settings GitlabSettings
	if len(raw) > 0 && string(raw) != "{}" {
		if err := json.Unmarshal(raw, &settings); err != nil {
			return nil, fmt.Errorf("orgs: unmarshal gitlab settings: %w", err)
		}
	}
	return &settings, nil
}

// UpsertGitlabSettings writes the gitlab namespace.
func (r *Repo) UpsertGitlabSettings(ctx context.Context, orgID string, settings *GitlabSettings) error {
	raw, err := json.Marshal(settings)
	if err != nil {
		return fmt.Errorf("orgs: marshal gitlab settings: %w", err)
	}

	_, err = r.pool.Exec(ctx,
		`INSERT INTO org_settings (org_id, gitlab, updated_at)
		 VALUES ($1, $2::jsonb, now())
		 ON CONFLICT (org_id) DO UPDATE SET gitlab = EXCLUDED.gitlab, updated_at = now()`,
		orgID, raw,
	)
	if err != nil {
		return fmt.Errorf("orgs: upsert gitlab settings: %w", err)
	}
	return nil
}

// ─── LabsSettings accessors ───────────────────────────────────────────────

// GetLabsSettings reads the labs namespace from org_settings.
func (r *Repo) GetLabsSettings(ctx context.Context, orgID string) (*LabsSettings, error) {
	var raw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(labs, '{}'::jsonb) FROM org_settings WHERE org_id = $1`,
		orgID,
	).Scan(&raw)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("orgs: get labs settings: %w", err)
	}

	var settings LabsSettings
	if len(raw) > 0 && string(raw) != "{}" {
		if err := json.Unmarshal(raw, &settings); err != nil {
			return nil, fmt.Errorf("orgs: unmarshal labs settings: %w", err)
		}
	}
	return &settings, nil
}

// UpsertLabsSettings writes the labs namespace.
func (r *Repo) UpsertLabsSettings(ctx context.Context, orgID string, settings *LabsSettings) error {
	raw, err := json.Marshal(settings)
	if err != nil {
		return fmt.Errorf("orgs: marshal labs settings: %w", err)
	}

	_, err = r.pool.Exec(ctx,
		`INSERT INTO org_settings (org_id, labs, updated_at)
		 VALUES ($1, $2::jsonb, now())
		 ON CONFLICT (org_id) DO UPDATE SET labs = EXCLUDED.labs, updated_at = now()`,
		orgID, raw,
	)
	if err != nil {
		return fmt.Errorf("orgs: upsert labs settings: %w", err)
	}
	return nil
}

// ─── SessionBookingSettings accessors ──────────────────────────────────────

// GetSessionBookingSettings reads the session_booking namespace from org_settings.
func (r *Repo) GetSessionBookingSettings(ctx context.Context, orgID string) (*SessionBookingSettings, error) {
	var raw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(session_booking, '{}'::jsonb) FROM org_settings WHERE org_id = $1`,
		orgID,
	).Scan(&raw)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("orgs: get session booking settings: %w", err)
	}

	var settings SessionBookingSettings
	if len(raw) > 0 && string(raw) != "{}" {
		if err := json.Unmarshal(raw, &settings); err != nil {
			return nil, fmt.Errorf("orgs: unmarshal session booking settings: %w", err)
		}
	}
	return &settings, nil
}

// UpsertSessionBookingSettings writes the session_booking namespace.
func (r *Repo) UpsertSessionBookingSettings(ctx context.Context, orgID string, settings *SessionBookingSettings) error {
	raw, err := json.Marshal(settings)
	if err != nil {
		return fmt.Errorf("orgs: marshal session booking settings: %w", err)
	}

	_, err = r.pool.Exec(ctx,
		`INSERT INTO org_settings (org_id, session_booking, updated_at)
		 VALUES ($1, $2::jsonb, now())
		 ON CONFLICT (org_id) DO UPDATE SET session_booking = EXCLUDED.session_booking, updated_at = now()`,
		orgID, raw,
	)
	if err != nil {
		return fmt.Errorf("orgs: upsert session booking settings: %w", err)
	}
	return nil
}
