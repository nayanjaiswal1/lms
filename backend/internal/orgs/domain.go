package orgs

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// DomainService manages org email domain entries.
type DomainService struct {
	pool *pgxpool.Pool
}

func NewDomainService(pool *pgxpool.Pool) *DomainService {
	return &DomainService{pool: pool}
}

// Add creates a new domain entry with a verification token.
// Rejects domains in the public email domain blocklist.
func (s *DomainService) Add(ctx context.Context, orgID, actorUserID string, req AddDomainRequest) (*Domain, error) {
	if req.Domain == "" {
		return nil, fmt.Errorf("invalid_domain")
	}
	if IsPublicEmailDomain(req.Domain) {
		return nil, fmt.Errorf("public_email_domain")
	}
	if req.VerificationMethod == "" {
		return nil, fmt.Errorf("invalid_verification_method")
	}

	token, err := generateVerificationToken()
	if err != nil {
		return nil, fmt.Errorf("orgs: add domain: generate token: %w", err)
	}

	var d Domain
	err = s.pool.QueryRow(ctx,
		`INSERT INTO org_domains (org_id, domain, verification_method, verification_token)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, org_id, domain, verified, verification_method, verification_token, verified_at, auto_join_enabled, created_at`,
		orgID, req.Domain, req.VerificationMethod, token,
	).Scan(
		&d.ID, &d.OrgID, &d.Domain, &d.Verified, &d.VerificationMethod,
		&d.VerificationToken, &d.VerifiedAt, &d.AutoJoinEnabled, &d.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("orgs: add domain: insert: %w", err)
	}

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:      orgID,
		ActorUserID: &actorUserID,
		Action:     "domain.added",
		TargetType: "domain",
		TargetID:   &d.ID,
		AfterState: map[string]string{"domain": d.Domain, "method": req.VerificationMethod},
	})

	return &d, nil
}

// Verify marks a domain as verified if the verification_token matches.
func (s *DomainService) Verify(ctx context.Context, orgID, domainID, token string) (*Domain, error) {
	var d Domain
	err := s.pool.QueryRow(ctx,
		`SELECT id, org_id, domain, verified, verification_method, verification_token, verified_at, auto_join_enabled, created_at
		 FROM org_domains WHERE id = $1 AND org_id = $2`,
		domainID, orgID,
	).Scan(
		&d.ID, &d.OrgID, &d.Domain, &d.Verified, &d.VerificationMethod,
		&d.VerificationToken, &d.VerifiedAt, &d.AutoJoinEnabled, &d.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: verify domain: fetch: %w", err)
	}

	if d.Verified {
		return &d, nil // idempotent
	}
	if d.VerificationToken != token {
		return nil, fmt.Errorf("invalid_token")
	}

	err = s.pool.QueryRow(ctx,
		`UPDATE org_domains
		 SET verified = true, verified_at = now(), updated_at = now()
		 WHERE id = $1 AND org_id = $2
		 RETURNING id, org_id, domain, verified, verification_method, verification_token, verified_at, auto_join_enabled, created_at`,
		domainID, orgID,
	).Scan(
		&d.ID, &d.OrgID, &d.Domain, &d.Verified, &d.VerificationMethod,
		&d.VerificationToken, &d.VerifiedAt, &d.AutoJoinEnabled, &d.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("orgs: verify domain: update: %w", err)
	}

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:      orgID,
		Action:     "domain.verified",
		TargetType: "domain",
		TargetID:   &domainID,
		AfterState: map[string]string{"domain": d.Domain},
	})

	return &d, nil
}

// SetAutoJoin enables or disables auto-join on a verified domain.
func (s *DomainService) SetAutoJoin(ctx context.Context, orgID, domainID string, enabled bool) (*Domain, error) {
	var d Domain
	err := s.pool.QueryRow(ctx,
		`UPDATE org_domains
		 SET auto_join_enabled = $1, updated_at = now()
		 WHERE id = $2 AND org_id = $3 AND verified = true
		 RETURNING id, org_id, domain, verified, verification_method, verification_token, verified_at, auto_join_enabled, created_at`,
		enabled, domainID, orgID,
	).Scan(
		&d.ID, &d.OrgID, &d.Domain, &d.Verified, &d.VerificationMethod,
		&d.VerificationToken, &d.VerifiedAt, &d.AutoJoinEnabled, &d.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		// Either the domain doesn't exist or it's not verified.
		return nil, fmt.Errorf("domain_not_verified_or_not_found")
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: set auto-join: %w", err)
	}
	return &d, nil
}

// Remove deletes a domain entry.
func (s *DomainService) Remove(ctx context.Context, orgID, domainID string) error {
	tag, err := s.pool.Exec(ctx,
		`DELETE FROM org_domains WHERE id = $1 AND org_id = $2`,
		domainID, orgID,
	)
	if err != nil {
		return fmt.Errorf("orgs: remove domain: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func generateVerificationToken() (string, error) {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("rand read: %w", err)
	}
	return hex.EncodeToString(buf), nil
}
