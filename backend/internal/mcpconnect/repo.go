package mcpconnect

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound     = errors.New("mcpconnect: not found")
	ErrExpired      = errors.New("mcpconnect: expired")
	ErrInvalidGrant = errors.New("mcpconnect: invalid grant")
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// OrgAIConnectorEnabled reports whether orgID has the AI Connector feature
// turned on by reading org_settings.ai_connector jsonb. Missing row or empty
// jsonb defaults to enabled=true for backward compatibility.
func (r *Repo) OrgAIConnectorEnabled(ctx context.Context, orgID string) (bool, error) {
	var raw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(ai_connector, '{}'::jsonb) FROM org_settings WHERE org_id = $1`,
		orgID,
	).Scan(&raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return true, nil
	}
	if err != nil {
		return false, fmt.Errorf("mcpconnect: org ai connector enabled: %w", err)
	}

	// Default to enabled=true when jsonb is empty or key is missing
	enabled := true
	if len(raw) > 2 { // Skip empty {}
		type aiConnectorJSON struct {
			Enabled *bool `json:"enabled"`
		}
		var parsed aiConnectorJSON
		if err := json.Unmarshal(raw, &parsed); err != nil {
			return false, fmt.Errorf("mcpconnect: unmarshal ai connector config: %w", err)
		}
		if parsed.Enabled != nil {
			enabled = *parsed.Enabled
		}
	}
	return enabled, nil
}

// RegisterClient inserts a new Dynamic-Client-Registration record.
func (r *Repo) RegisterClient(ctx context.Context, clientID, clientName string, redirectURIs []string) (Client, error) {
	c := Client{ClientID: clientID, ClientName: clientName, RedirectURIs: redirectURIs}
	err := r.pool.QueryRow(ctx,
		`INSERT INTO mcp_clients (client_id, client_name, redirect_uris)
		 VALUES ($1,$2,$3) RETURNING created_at`,
		c.ClientID, c.ClientName, c.RedirectURIs,
	).Scan(&c.CreatedAt)
	if err != nil {
		return Client{}, fmt.Errorf("mcpconnect: register client: %w", err)
	}
	return c, nil
}

// GetClient looks up a previously registered client by its public client_id.
func (r *Repo) GetClient(ctx context.Context, clientID string) (Client, error) {
	var c Client
	err := r.pool.QueryRow(ctx,
		`SELECT client_id, client_name, redirect_uris, created_at FROM mcp_clients WHERE client_id = $1`,
		clientID,
	).Scan(&c.ClientID, &c.ClientName, &c.RedirectURIs, &c.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Client{}, ErrNotFound
		}
		return Client{}, fmt.Errorf("mcpconnect: get client: %w", err)
	}
	return c, nil
}

// InsertAuthCode stores a single-use authorization code in auth_tokens with
// purpose='mcp_auth_code' and the auth code details in the payload jsonb.
func (r *Repo) InsertAuthCode(ctx context.Context, code AuthCode) error {
	payloadJSON, err := json.Marshal(map[string]interface{}{
		"client_id":      code.ClientID,
		"scopes":         code.Scopes,
		"code_challenge": code.CodeChallenge,
		"redirect_uri":   code.RedirectURI,
	})
	if err != nil {
		return fmt.Errorf("mcpconnect: marshal auth code payload: %w", err)
	}

	_, err = r.pool.Exec(ctx,
		`INSERT INTO auth_tokens (purpose, token_hash, org_id, user_id, payload, expires_at)
		 VALUES ('mcp_auth_code', $1, $2, $3, $4::jsonb, $5)`,
		code.Code, code.OrgID, code.UserID, string(payloadJSON), code.ExpiresAt,
	)
	if err != nil {
		return fmt.Errorf("mcpconnect: insert auth code: %w", err)
	}
	return nil
}

// ConsumeAuthCode deletes and returns a code from auth_tokens in one statement,
// so a code can never be exchanged twice even under concurrent requests.
func (r *Repo) ConsumeAuthCode(ctx context.Context, code string) (AuthCode, error) {
	var ac AuthCode
	var payloadRaw []byte
	err := r.pool.QueryRow(ctx,
		`DELETE FROM auth_tokens WHERE purpose = 'mcp_auth_code' AND token_hash = $1
		 RETURNING token_hash, org_id, user_id, payload, expires_at`,
		code,
	).Scan(&ac.Code, &ac.OrgID, &ac.UserID, &payloadRaw, &ac.ExpiresAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AuthCode{}, ErrInvalidGrant
		}
		return AuthCode{}, fmt.Errorf("mcpconnect: consume auth code: %w", err)
	}
	if time.Now().After(ac.ExpiresAt) {
		return AuthCode{}, ErrExpired
	}

	// Unmarshal the payload to extract code details
	type authCodePayload struct {
		ClientID      string   `json:"client_id"`
		Scopes        []string `json:"scopes"`
		CodeChallenge string   `json:"code_challenge"`
		RedirectURI   string   `json:"redirect_uri"`
	}
	var payload authCodePayload
	if err := json.Unmarshal(payloadRaw, &payload); err != nil {
		return AuthCode{}, fmt.Errorf("mcpconnect: unmarshal auth code payload: %w", err)
	}

	ac.ClientID = payload.ClientID
	ac.Scopes = payload.Scopes
	ac.CodeChallenge = payload.CodeChallenge
	ac.RedirectURI = payload.RedirectURI

	return ac, nil
}

// UpsertConnection creates or refreshes a (user, client) connection — a user
// re-approving the same client rotates its refresh token and scopes rather
// than accumulating duplicate rows.
func (r *Repo) UpsertConnection(ctx context.Context, orgID, userID, clientID string, scopes []string, refreshTokenHash string, refreshExpiresAt time.Time) (string, error) {
	var id string
	err := r.pool.QueryRow(ctx,
		`INSERT INTO mcp_connections (org_id, user_id, client_id, scopes, refresh_token_hash, refresh_token_expires_at, status)
		 VALUES ($1,$2,$3,$4,$5,$6,'active')
		 ON CONFLICT (user_id, client_id) DO UPDATE
		   SET scopes = EXCLUDED.scopes,
		       refresh_token_hash = EXCLUDED.refresh_token_hash,
		       refresh_token_expires_at = EXCLUDED.refresh_token_expires_at,
		       status = 'active',
		       revoked_at = NULL
		 RETURNING id`,
		orgID, userID, clientID, scopes, refreshTokenHash, refreshExpiresAt,
	).Scan(&id)
	if err != nil {
		return "", fmt.Errorf("mcpconnect: upsert connection: %w", err)
	}
	return id, nil
}

// connectionRow is the shape shared by refresh-token and access-token lookups.
type connectionRow struct {
	ID       string
	OrgID    string
	UserID   string
	ClientID string
	Scopes   []string
	Status   string
}

// GetConnectionByRefreshHash resolves a presented refresh token (already
// hashed by the caller) to its connection, only when active and unexpired.
func (r *Repo) GetConnectionByRefreshHash(ctx context.Context, hash string) (connectionRow, error) {
	var c connectionRow
	err := r.pool.QueryRow(ctx,
		`SELECT id, org_id, user_id, client_id, scopes, status FROM mcp_connections
		 WHERE refresh_token_hash = $1 AND status = 'active' AND refresh_token_expires_at > now()`,
		hash,
	).Scan(&c.ID, &c.OrgID, &c.UserID, &c.ClientID, &c.Scopes, &c.Status)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return connectionRow{}, ErrInvalidGrant
		}
		return connectionRow{}, fmt.Errorf("mcpconnect: get connection by refresh hash: %w", err)
	}
	return c, nil
}

// RotateRefreshToken replaces a connection's refresh token hash — called on
// every refresh_token grant (rotation-on-use) so a stolen-but-unused refresh
// token stops working the moment the legitimate client refreshes.
func (r *Repo) RotateRefreshToken(ctx context.Context, connectionID, newHash string, newExpiresAt time.Time) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE mcp_connections SET refresh_token_hash = $2, refresh_token_expires_at = $3 WHERE id = $1`,
		connectionID, newHash, newExpiresAt,
	)
	if err != nil {
		return fmt.Errorf("mcpconnect: rotate refresh token: %w", err)
	}
	return nil
}

// InsertAccessToken mints a short-lived bearer token for a connection in auth_tokens
// with purpose='mcp_access_token' and connection_id in the payload jsonb.
func (r *Repo) InsertAccessToken(ctx context.Context, connectionID, tokenHash string, expiresAt time.Time) error {
	payloadJSON, err := json.Marshal(map[string]interface{}{
		"connection_id": connectionID,
	})
	if err != nil {
		return fmt.Errorf("mcpconnect: marshal access token payload: %w", err)
	}

	_, err = r.pool.Exec(ctx,
		`INSERT INTO auth_tokens (purpose, token_hash, payload, expires_at)
		 VALUES ('mcp_access_token', $1, $2::jsonb, $3)`,
		tokenHash, string(payloadJSON), expiresAt,
	)
	if err != nil {
		return fmt.Errorf("mcpconnect: insert access token: %w", err)
	}
	return nil
}

// GetConnectionByAccessHash resolves a presented access token to its connection
// by looking up the auth_tokens row and extracting the connection_id from its payload.
// Touches last_used_at on the connection — called on every /mcp request.
func (r *Repo) GetConnectionByAccessHash(ctx context.Context, hash string) (connectionRow, error) {
	var payloadRaw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT payload FROM auth_tokens
		 WHERE purpose = 'mcp_access_token' AND token_hash = $1 AND expires_at > now()`,
		hash,
	).Scan(&payloadRaw)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return connectionRow{}, ErrInvalidGrant
		}
		return connectionRow{}, fmt.Errorf("mcpconnect: get access token: %w", err)
	}

	// Extract connection_id from payload
	type accessTokenPayload struct {
		ConnectionID string `json:"connection_id"`
	}
	var payload accessTokenPayload
	if err := json.Unmarshal(payloadRaw, &payload); err != nil {
		return connectionRow{}, fmt.Errorf("mcpconnect: unmarshal access token payload: %w", err)
	}

	// Now fetch the connection details
	var c connectionRow
	err = r.pool.QueryRow(ctx,
		`SELECT id, org_id, user_id, client_id, scopes, status
		 FROM mcp_connections WHERE id = $1 AND status = 'active'`,
		payload.ConnectionID,
	).Scan(&c.ID, &c.OrgID, &c.UserID, &c.ClientID, &c.Scopes, &c.Status)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return connectionRow{}, ErrInvalidGrant
		}
		return connectionRow{}, fmt.Errorf("mcpconnect: get connection by access token: %w", err)
	}

	_, _ = r.pool.Exec(ctx, `UPDATE mcp_connections SET last_used_at = now() WHERE id = $1`, c.ID)
	return c, nil
}

// ListMyConnections returns a user's approved connections, newest first, for
// the settings page.
func (r *Repo) ListMyConnections(ctx context.Context, userID string) ([]Connection, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT mc.id, mc.client_id, cl.client_name, mc.scopes, mc.status, mc.last_used_at, mc.created_at
		 FROM mcp_connections mc
		 JOIN mcp_clients cl ON cl.client_id = mc.client_id
		 WHERE mc.user_id = $1 AND mc.status = 'active'
		 ORDER BY mc.created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("mcpconnect: list my connections: %w", err)
	}
	defer rows.Close()

	var conns []Connection
	for rows.Next() {
		var c Connection
		if err := rows.Scan(&c.ID, &c.ClientID, &c.ClientName, &c.Scopes, &c.Status, &c.LastUsedAt, &c.CreatedAt); err != nil {
			return nil, fmt.Errorf("mcpconnect: scan connection: %w", err)
		}
		conns = append(conns, c)
	}
	return conns, rows.Err()
}

// RevokeConnection marks a connection revoked, scoped to the owning user so
// one user can never revoke another's connection by guessing an id.
func (r *Repo) RevokeConnection(ctx context.Context, userID, connectionID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE mcp_connections SET status = 'revoked', revoked_at = now()
		 WHERE id = $1 AND user_id = $2 AND status = 'active'`,
		connectionID, userID,
	)
	if err != nil {
		return fmt.Errorf("mcpconnect: revoke connection: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ─── action log ─────────────────────────────────────────────────────────────

// InsertActionLog records one completed tool call in audit_logs table with source='mcp'.
// BeforeState/AfterState arrive as raw Go values and are marshaled to JSON here,
// the same approach internal/orgs.writeAuditLog uses for audit_logs.
func (r *Repo) InsertActionLog(ctx context.Context, e ActionLogEntry) error {
	var beforeJSON, afterJSON []byte
	if e.BeforeState != nil {
		b, err := json.Marshal(*e.BeforeState)
		if err != nil {
			return fmt.Errorf("mcpconnect: insert action log: marshal before state: %w", err)
		}
		beforeJSON = b
	}
	if e.AfterState != nil {
		b, err := json.Marshal(*e.AfterState)
		if err != nil {
			return fmt.Errorf("mcpconnect: insert action log: marshal after state: %w", err)
		}
		afterJSON = b
	}

	var targetType, targetID *string
	if e.TargetType != "" {
		targetType = &e.TargetType
	}
	if e.TargetID != "" {
		targetID = &e.TargetID
	}

	_, err := r.pool.Exec(ctx,
		`INSERT INTO audit_logs (org_id, actor_user_id, source, action, target_type, target_id, before_state, after_state, connection_id, revertible)
		 VALUES ($1, $2, 'mcp', $3, $4, $5, $6::jsonb, $7::jsonb, $8, $9)`,
		e.OrgID, e.UserID, e.ToolName, targetType, targetID, beforeJSON, afterJSON, e.ConnectionID, e.Revertible,
	)
	if err != nil {
		return fmt.Errorf("mcpconnect: insert action log: %w", err)
	}
	return nil
}

const actionLogColumns = `id, action as tool_name, target_type, target_id, before_state, after_state, revertible, reverted_at, reverted_by, connection_id, created_at`

// rowScanner is satisfied by both pgx.Row (QueryRow) and pgx.Rows (Query's
// per-row iterator), so scanActionLogEntry works for both a single-row fetch
// and a multi-row list without duplicating the Scan call.
type rowScanner interface {
	Scan(dest ...any) error
}

func scanActionLogEntry(row rowScanner) (ActionLogEntry, error) {
	var e ActionLogEntry
	var targetType, targetID, revertedBy *string
	if err := row.Scan(&e.ID, &e.ToolName, &targetType, &targetID,
		&e.BeforeState, &e.AfterState, &e.Revertible, &e.RevertedAt, &revertedBy, &e.ConnectionID, &e.CreatedAt); err != nil {
		return ActionLogEntry{}, err
	}
	if targetType != nil {
		e.TargetType = *targetType
	}
	if targetID != nil {
		e.TargetID = *targetID
	}
	e.RevertedBy = revertedBy
	return e, nil
}

// ListActionLog returns a page of the given user's own tool-call history,
// newest first, cursor-paginated on (created_at, id) — the same composite
// cursor shape internal/orgs uses for audit_logs, duplicated rather than
// exported across the package boundary (see action_log.go).
func (r *Repo) ListActionLog(ctx context.Context, userID string, cursorCreatedAt time.Time, cursorID string, limit int) ([]ActionLogEntry, error) {
	var rows pgx.Rows
	var err error
	if cursorID == "" {
		rows, err = r.pool.Query(ctx,
			`SELECT `+actionLogColumns+`
			 FROM audit_logs
			 WHERE source = 'mcp' AND actor_user_id = $1
			 ORDER BY created_at DESC, id DESC
			 LIMIT $2`,
			userID, limit)
	} else {
		rows, err = r.pool.Query(ctx,
			`SELECT `+actionLogColumns+`
			 FROM audit_logs
			 WHERE source = 'mcp' AND actor_user_id = $1 AND (created_at, id) < ($2, $3::uuid)
			 ORDER BY created_at DESC, id DESC
			 LIMIT $4`,
			userID, cursorCreatedAt, cursorID, limit)
	}
	if err != nil {
		return nil, fmt.Errorf("mcpconnect: list action log: %w", err)
	}
	defer rows.Close()

	var entries []ActionLogEntry
	for rows.Next() {
		e, err := scanActionLogEntry(rows)
		if err != nil {
			return nil, fmt.Errorf("mcpconnect: scan action log: %w", err)
		}
		entries = append(entries, e)
	}
	return entries, rows.Err()
}

// GetActionLogEntry fetches one entry scoped to the owning user, so a
// guessed id can never surface or revert another user's AI activity.
func (r *Repo) GetActionLogEntry(ctx context.Context, userID, entryID string) (ActionLogEntry, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+actionLogColumns+` FROM audit_logs WHERE source = 'mcp' AND id = $1 AND actor_user_id = $2`,
		entryID, userID)
	e, err := scanActionLogEntry(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ActionLogEntry{}, ErrNotFound
		}
		return ActionLogEntry{}, fmt.Errorf("mcpconnect: get action log entry: %w", err)
	}
	e.UserID = userID
	return e, nil
}

// MarkReverted stamps an entry as reverted, scoped to the owning user and
// to entries not already reverted — a concurrent double-revert loses the
// race here rather than double-applying whatever the tool's Revert did.
func (r *Repo) MarkReverted(ctx context.Context, entryID, userID string) (ActionLogEntry, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE audit_logs SET reverted_at = now(), reverted_by = $2
		 WHERE source = 'mcp' AND id = $1 AND actor_user_id = $2 AND reverted_at IS NULL
		 RETURNING `+actionLogColumns,
		entryID, userID)
	e, err := scanActionLogEntry(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ActionLogEntry{}, ErrNotFound
		}
		return ActionLogEntry{}, fmt.Errorf("mcpconnect: mark action log reverted: %w", err)
	}
	e.UserID = userID
	return e, nil
}
