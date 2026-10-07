package orgs

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	// DNSVerificationLabel is prepended to the domain to form the TXT record
	// name an org must publish: _mindforge-verification.<domain>.
	DNSVerificationLabel = "_mindforge-verification"
	// DNSVerificationValuePrefix precedes the token in the TXT record value.
	DNSVerificationValuePrefix = "mindforge-verification="

	verificationMethodDNS = "dns_txt"
	dnsLookupTimeout      = 5 * time.Second
	pgUniqueViolation     = "23505"
)

// DomainService manages org email domain entries.
type DomainService struct {
	pool *pgxpool.Pool
	// lookupTXT resolves TXT records; a field so tests can stub DNS.
	lookupTXT func(ctx context.Context, name string) ([]string, error)
}

func NewDomainService(pool *pgxpool.Pool) *DomainService {
	return &DomainService{pool: pool, lookupTXT: net.DefaultResolver.LookupTXT}
}

// dnsProvesOwnership reports whether the domain publishes this org's token at
// _mindforge-verification.<domain>.
func (s *DomainService) dnsProvesOwnership(ctx context.Context, domain, token string) (bool, error) {
	ctx, cancel := context.WithTimeout(ctx, dnsLookupTimeout)
	defer cancel()
	records, err := s.lookupTXT(ctx, DNSVerificationLabel+"."+domain)
	if err != nil {
		var dnsErr *net.DNSError
		if errors.As(err, &dnsErr) && dnsErr.IsNotFound {
			return false, nil
		}
		return false, fmt.Errorf("orgs: verify domain: dns lookup: %w", err)
	}
	want := DNSVerificationValuePrefix + token
	for _, rec := range records {
		if strings.TrimSpace(rec) == want {
			return true, nil
		}
	}
	return false, nil
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
	if req.VerificationMethod != verificationMethodDNS {
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
		OrgID:       orgID,
		ActorUserID: &actorUserID,
		Action:      "domain.added",
		TargetType:  "domain",
		TargetID:    &d.ID,
		AfterState:  map[string]string{"domain": d.Domain, "method": req.VerificationMethod},
	})

	return &d, nil
}

// List returns all domain entries configured for orgID, most recently added first.
func (s *DomainService) List(ctx context.Context, orgID string) ([]Domain, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT id, org_id, domain, verified, verification_method, verification_token, verified_at, auto_join_enabled, created_at
		 FROM org_domains WHERE org_id = $1 ORDER BY created_at DESC`,
		orgID,
	)
	if err != nil {
		return nil, fmt.Errorf("orgs: list domains: %w", err)
	}
	defer rows.Close()

	domains := make([]Domain, 0)
	for rows.Next() {
		var d Domain
		if err := rows.Scan(
			&d.ID, &d.OrgID, &d.Domain, &d.Verified, &d.VerificationMethod,
			&d.VerificationToken, &d.VerifiedAt, &d.AutoJoinEnabled, &d.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("orgs: list domains: scan: %w", err)
		}
		domains = append(domains, d)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("orgs: list domains: rows: %w", err)
	}
	return domains, nil
}

// Verify marks a domain as verified once its DNS TXT record carries the org's
// verification token. The token is never accepted from the caller: it is
// returned by Add, so echoing it back would prove nothing.
func (s *DomainService) Verify(ctx context.Context, orgID, domainID string) (*Domain, error) {
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
	proven, err := s.dnsProvesOwnership(ctx, d.Domain, d.VerificationToken)
	if err != nil {
		return nil, err
	}
	if !proven {
		return nil, fmt.Errorf("dns_record_not_found")
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
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == pgUniqueViolation {
			return nil, fmt.Errorf("domain_already_verified")
		}
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
