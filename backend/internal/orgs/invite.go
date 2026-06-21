package orgs

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
)

// InviteService manages org invites.
type InviteService struct {
	pool *pgxpool.Pool
	cfg  *config.Config
}

func NewInviteService(pool *pgxpool.Pool, cfg *config.Config) *InviteService {
	return &InviteService{pool: pool, cfg: cfg}
}

// Create validates and issues an invite for email with the given role.
// The returned Invite does not expose token_hash; the raw token must be
// fetched separately or embedded in the creation response (not stored here).
func (s *InviteService) Create(ctx context.Context, orgID, actorUserID, actorRole string, req CreateInviteRequest) (*Invite, string, error) {
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	if req.Email == "" {
		return nil, "", fmt.Errorf("invalid_email")
	}
	if !CanGrantRole(actorRole, req.Role) {
		return nil, "", ErrForbidden
	}

	// Check if target email is already an active member.
	var exists bool
	err := s.pool.QueryRow(ctx,
		`SELECT EXISTS(
		     SELECT 1 FROM org_members m
		     JOIN users u ON u.id = m.user_id
		     WHERE m.org_id = $1 AND u.email = $2 AND m.status = 'active'
		 )`,
		orgID, req.Email,
	).Scan(&exists)
	if err != nil {
		return nil, "", fmt.Errorf("orgs: create invite: check membership: %w", err)
	}
	if exists {
		return nil, "", ErrAlreadyMember
	}

	// Insert with a placeholder hash first to obtain the invite ID, then update with the
	// real hash (which includes the invite ID in the payload for uniqueness).
	expiresAt := time.Now().Add(7 * 24 * time.Hour)

	var inv Invite
	err = s.pool.QueryRow(ctx,
		`INSERT INTO org_invites (org_id, email, role, invited_by_user_id, token_hash, expires_at)
		 VALUES ($1, $2, $3, $4, 'pending', $5)
		 RETURNING id, org_id, email, role, invited_by_user_id, expires_at, accepted_at, revoked_at, created_at`,
		orgID, req.Email, req.Role, actorUserID, expiresAt,
	).Scan(
		&inv.ID, &inv.OrgID, &inv.Email, &inv.Role, &inv.InvitedByID,
		&inv.ExpiresAt, &inv.AcceptedAt, &inv.RevokedAt, &inv.CreatedAt,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, "", ErrInvitePending
		}
		return nil, "", fmt.Errorf("orgs: create invite: insert: %w", err)
	}

	// Generate raw token and compute hash including the now-known invite ID.
	rawToken, err := generateRawToken()
	if err != nil {
		// Best-effort cleanup; leave the row with placeholder hash, which is effectively unusable.
		_, _ = s.pool.Exec(ctx, `DELETE FROM org_invites WHERE id = $1`, inv.ID)
		return nil, "", fmt.Errorf("orgs: create invite: generate token: %w", err)
	}
	deliverableToken := inv.ID + ":" + rawToken
	tokenHash := hashInviteToken(deliverableToken)

	if _, err := s.pool.Exec(ctx,
		`UPDATE org_invites SET token_hash = $1 WHERE id = $2`,
		tokenHash, inv.ID,
	); err != nil {
		_, _ = s.pool.Exec(ctx, `DELETE FROM org_invites WHERE id = $1`, inv.ID)
		return nil, "", fmt.Errorf("orgs: create invite: set token hash: %w", err)
	}

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:      orgID,
		ActorUserID: &actorUserID,
		Action:     "invite.created",
		TargetType: "invite",
		TargetID:   &inv.ID,
		AfterState: map[string]string{"email": inv.Email, "role": inv.Role},
	})

	return &inv, deliverableToken, nil
}

// Resend regenerates the token and resets expires_at for an existing pending invite.
func (s *InviteService) Resend(ctx context.Context, orgID, actorUserID, actorRole, inviteID string) (*Invite, string, error) {
	// Fetch existing invite to verify ownership and state.
	var inv Invite
	err := s.pool.QueryRow(ctx,
		`SELECT id, org_id, email, role, invited_by_user_id, expires_at, accepted_at, revoked_at, created_at
		 FROM org_invites WHERE id = $1 AND org_id = $2`,
		inviteID, orgID,
	).Scan(
		&inv.ID, &inv.OrgID, &inv.Email, &inv.Role, &inv.InvitedByID,
		&inv.ExpiresAt, &inv.AcceptedAt, &inv.RevokedAt, &inv.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, "", ErrNotFound
	}
	if err != nil {
		return nil, "", fmt.Errorf("orgs: resend invite: fetch: %w", err)
	}
	if inv.RevokedAt != nil || inv.AcceptedAt != nil {
		return nil, "", ErrInvalidStatus
	}
	if !CanGrantRole(actorRole, inv.Role) {
		return nil, "", ErrForbidden
	}

	rawToken, err := generateRawToken()
	if err != nil {
		return nil, "", fmt.Errorf("orgs: resend invite: generate token: %w", err)
	}
	deliverableToken := inviteID + ":" + rawToken
	tokenHash := hashInviteToken(deliverableToken)

	newExpiry := time.Now().Add(7 * 24 * time.Hour)
	err = s.pool.QueryRow(ctx,
		`UPDATE org_invites
		 SET token_hash = $1, expires_at = $2, updated_at = now()
		 WHERE id = $3 AND org_id = $4
		 RETURNING id, org_id, email, role, invited_by_user_id, expires_at, accepted_at, revoked_at, created_at`,
		tokenHash, newExpiry, inviteID, orgID,
	).Scan(
		&inv.ID, &inv.OrgID, &inv.Email, &inv.Role, &inv.InvitedByID,
		&inv.ExpiresAt, &inv.AcceptedAt, &inv.RevokedAt, &inv.CreatedAt,
	)
	if err != nil {
		return nil, "", fmt.Errorf("orgs: resend invite: update: %w", err)
	}

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:      orgID,
		ActorUserID: &actorUserID,
		Action:     "invite.resent",
		TargetType: "invite",
		TargetID:   &inv.ID,
	})

	return &inv, deliverableToken, nil
}

// List returns a cursor-paginated list of pending invites for an org.
func (s *InviteService) List(ctx context.Context, orgID, cursor string, limit int) (*InvitePage, error) {
	cursorCreatedAt, cursorID, err := decodeCursor(cursor)
	if err != nil {
		cursor = "" // treat bad cursor as no cursor
	}

	var rows pgx.Rows
	if cursor == "" {
		rows, err = s.pool.Query(ctx,
			`SELECT id, org_id, email, role, invited_by_user_id, expires_at, accepted_at, revoked_at, created_at
			 FROM org_invites
			 WHERE org_id = $1 AND accepted_at IS NULL AND revoked_at IS NULL
			 ORDER BY created_at ASC, id ASC
			 LIMIT $2`,
			orgID, limit+1,
		)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT id, org_id, email, role, invited_by_user_id, expires_at, accepted_at, revoked_at, created_at
			 FROM org_invites
			 WHERE org_id = $1 AND accepted_at IS NULL AND revoked_at IS NULL
			   AND (created_at, id) > ($2, $3)
			 ORDER BY created_at ASC, id ASC
			 LIMIT $4`,
			orgID, cursorCreatedAt, cursorID, limit+1,
		)
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: list invites: %w", err)
	}
	defer rows.Close()

	var invites []Invite
	for rows.Next() {
		var inv Invite
		if err := rows.Scan(
			&inv.ID, &inv.OrgID, &inv.Email, &inv.Role, &inv.InvitedByID,
			&inv.ExpiresAt, &inv.AcceptedAt, &inv.RevokedAt, &inv.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("orgs: list invites: scan: %w", err)
		}
		invites = append(invites, inv)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("orgs: list invites: rows: %w", err)
	}

	page := &InvitePage{Invites: invites}
	if len(invites) == 0 {
		page.Invites = []Invite{}
	}
	if len(invites) > limit {
		page.Invites = invites[:limit]
		last := page.Invites[limit-1]
		page.NextCursor = encodeCursor(last.CreatedAt, last.ID)
	}
	return page, nil
}

// Revoke sets revoked_at=now() on a pending invite.
func (s *InviteService) Revoke(ctx context.Context, orgID, actorUserID, inviteID, actorRole string) error {
	var inv Invite
	err := s.pool.QueryRow(ctx,
		`SELECT id, role, revoked_at, accepted_at FROM org_invites WHERE id = $1 AND org_id = $2`,
		inviteID, orgID,
	).Scan(&inv.ID, &inv.Role, &inv.RevokedAt, &inv.AcceptedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return fmt.Errorf("orgs: revoke invite: fetch: %w", err)
	}
	if inv.RevokedAt != nil || inv.AcceptedAt != nil {
		return ErrInvalidStatus
	}
	if !CanGrantRole(actorRole, inv.Role) {
		return ErrForbidden
	}

	if _, err := s.pool.Exec(ctx,
		`UPDATE org_invites SET revoked_at = now(), revoke_reason = 'manual', updated_at = now()
		 WHERE id = $1 AND org_id = $2`,
		inviteID, orgID,
	); err != nil {
		return fmt.Errorf("orgs: revoke invite: update: %w", err)
	}

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:      orgID,
		ActorUserID: &actorUserID,
		Action:     "invite.revoked",
		TargetType: "invite",
		TargetID:   &inviteID,
	})
	return nil
}

// Join accepts an invite token, validates it fully, and upserts the user as a member.
func (s *InviteService) Join(ctx context.Context, req JoinOrgRequest, userID string) (*Invite, error) {
	// Token format: "invite_id:raw_hex"
	parts := strings.SplitN(req.Token, ":", 2)
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return nil, fmt.Errorf("invalid_token")
	}
	inviteID := parts[0]
	rawHex := parts[1]

	expectedHash := hashInviteToken(inviteID + ":" + rawHex)

	var inv Invite
	var storedHash string
	err := s.pool.QueryRow(ctx,
		`SELECT id, org_id, email, role, invited_by_user_id, expires_at, accepted_at, revoked_at, created_at, token_hash
		 FROM org_invites WHERE id = $1`,
		inviteID,
	).Scan(
		&inv.ID, &inv.OrgID, &inv.Email, &inv.Role, &inv.InvitedByID,
		&inv.ExpiresAt, &inv.AcceptedAt, &inv.RevokedAt, &inv.CreatedAt, &storedHash,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("invalid_token")
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: join: fetch invite: %w", err)
	}

	if storedHash != expectedHash {
		return nil, fmt.Errorf("invalid_token")
	}
	if time.Now().After(inv.ExpiresAt) {
		return nil, fmt.Errorf("invite_expired")
	}
	if inv.RevokedAt != nil {
		return nil, fmt.Errorf("invite_revoked")
	}
	if inv.AcceptedAt != nil {
		return nil, fmt.Errorf("invite_already_accepted")
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("orgs: join: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	if _, err := tx.Exec(ctx,
		`INSERT INTO org_members (org_id, user_id, role, status)
		 VALUES ($1, $2, $3, 'active')
		 ON CONFLICT (org_id, user_id)
		 DO UPDATE SET status = 'active', role = EXCLUDED.role, updated_at = now()`,
		inv.OrgID, userID, inv.Role,
	); err != nil {
		return nil, fmt.Errorf("orgs: join: upsert member: %w", err)
	}

	now := time.Now()
	if _, err := tx.Exec(ctx,
		`UPDATE org_invites
		 SET accepted_at = $1, accepted_by_user_id = $2, updated_at = now()
		 WHERE id = $3`,
		now, userID, inv.ID,
	); err != nil {
		return nil, fmt.Errorf("orgs: join: mark accepted: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("orgs: join: commit: %w", err)
	}

	inv.AcceptedAt = &now

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:      inv.OrgID,
		ActorUserID: &userID,
		Action:     "invite.accepted",
		TargetType: "invite",
		TargetID:   &inv.ID,
		AfterState: map[string]string{"email": inv.Email, "role": inv.Role},
	})

	return &inv, nil
}

// ─── token helpers ─────────────────────────────────────────────────────────────

// generateRawToken produces 32 random bytes encoded as a hex string.
// The caller constructs the full token payload as "invite_id:rawHex" before hashing.
func generateRawToken() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("rand read: %w", err)
	}
	return hex.EncodeToString(buf), nil
}

// hashInviteToken returns the hex-encoded SHA-256 of the full token payload (invite_id:raw_hex).
func hashInviteToken(payload string) string {
	sum := sha256.Sum256([]byte(payload))
	return hex.EncodeToString(sum[:])
}
