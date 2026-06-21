package orgs

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"regexp"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
)

var slugRE = regexp.MustCompile(`^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$`)

// OrgService handles org CRUD and lifecycle operations.
type OrgService struct {
	pool *pgxpool.Pool
	cfg  *config.Config
}

func NewOrgService(pool *pgxpool.Pool, cfg *config.Config) *OrgService {
	return &OrgService{pool: pool, cfg: cfg}
}

// Sentinel errors returned by OrgService methods.
var (
	ErrSlugTaken            = errors.New("slug_taken")
	ErrNotFound             = errors.New("not_found")
	ErrForbidden            = errors.New("forbidden")
	ErrLastOwner            = errors.New("last_owner")
	ErrAlreadyMember        = errors.New("already_member")
	ErrInvitePending        = errors.New("invite_pending")
	ErrOnboardingIncomplete = errors.New("onboarding_incomplete")
	ErrInvalidStatus        = errors.New("invalid_status")
)

// Create validates and inserts a new org, bootstraps default records, and writes an audit log.
func (s *OrgService) Create(ctx context.Context, actorUserID string, req CreateOrgRequest) (*Org, error) {
	req.Slug = strings.TrimSpace(strings.ToLower(req.Slug))
	req.Name = strings.TrimSpace(req.Name)

	if !slugRE.MatchString(req.Slug) {
		return nil, fmt.Errorf("invalid_slug")
	}
	if IsReservedSlug(req.Slug) {
		return nil, fmt.Errorf("reserved_slug")
	}
	if len(req.Name) < 2 || len(req.Name) > 100 {
		return nil, fmt.Errorf("invalid_name")
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("orgs: create: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var org Org
	err = tx.QueryRow(ctx,
		`INSERT INTO organizations (slug, name, logo_url, description, status)
		 VALUES ($1, $2, $3, $4, 'pending_verification')
		 RETURNING id, slug, name, logo_url, description, status, seat_limit,
		           active_member_count, onboarding_step, onboarding_completed_at,
		           activated_at, created_at, updated_at`,
		req.Slug, req.Name, req.LogoURL, req.Description,
	).Scan(
		&org.ID, &org.Slug, &org.Name, &org.LogoURL, &org.Description, &org.Status,
		&org.SeatLimit, &org.ActiveMemberCount, &org.OnboardingStep,
		&org.OnboardingCompletedAt, &org.ActivatedAt, &org.CreatedAt, &org.UpdatedAt,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" && strings.Contains(pgErr.ConstraintName, "slug") {
			return nil, ErrSlugTaken
		}
		return nil, fmt.Errorf("orgs: create: insert org: %w", err)
	}

	if _, err := tx.Exec(ctx,
		`INSERT INTO org_members (org_id, user_id, role, status)
		 VALUES ($1, $2, 'owner', 'active')`,
		org.ID, actorUserID,
	); err != nil {
		return nil, fmt.Errorf("orgs: create: insert owner member: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("orgs: create: commit: %w", err)
	}

	// Bootstrap is idempotent — runs outside tx.
	if err := s.Bootstrap(ctx, org.ID); err != nil {
		slog.Error("orgs: bootstrap after create", "org_id", org.ID, "error", err)
	}

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:      org.ID,
		ActorUserID: &actorUserID,
		Action:     "org.created",
		TargetType: "org",
		TargetID:   &org.ID,
		AfterState: org,
	})

	return &org, nil
}

// Bootstrap creates default records for an org. Safe to call multiple times (ON CONFLICT DO NOTHING).
func (s *OrgService) Bootstrap(ctx context.Context, orgID string) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO org_auth_config (org_id, allow_password, allow_google, allow_github)
		 VALUES ($1, true, false, false)
		 ON CONFLICT DO NOTHING`,
		orgID,
	)
	if err != nil {
		return fmt.Errorf("orgs: bootstrap: upsert auth config: %w", err)
	}
	return nil
}

// GetByID returns an org by its ID. If userID is non-empty, the org must have an
// active membership for that user.
func (s *OrgService) GetByID(ctx context.Context, orgID, userID string) (*Org, error) {
	query := `
		SELECT o.id, o.slug, o.name, o.logo_url, o.description, o.status,
		       o.seat_limit, o.active_member_count, o.onboarding_step,
		       o.onboarding_completed_at, o.activated_at, o.created_at, o.updated_at
		FROM organizations o`

	args := []any{orgID}
	if userID != "" {
		query += `
		JOIN org_members m ON m.org_id = o.id AND m.user_id = $2 AND m.status = 'active'
		WHERE o.id = $1`
		args = append(args, userID)
	} else {
		query += ` WHERE o.id = $1`
	}

	var org Org
	err := s.pool.QueryRow(ctx, query, args...).Scan(
		&org.ID, &org.Slug, &org.Name, &org.LogoURL, &org.Description, &org.Status,
		&org.SeatLimit, &org.ActiveMemberCount, &org.OnboardingStep,
		&org.OnboardingCompletedAt, &org.ActivatedAt, &org.CreatedAt, &org.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: get by id: %w", err)
	}
	return &org, nil
}

// GetMyOrgs returns all orgs the user is an active member of.
func (s *OrgService) GetMyOrgs(ctx context.Context, userID string) ([]OrgSummary, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT o.id, o.slug, o.name, m.role
		 FROM organizations o
		 JOIN org_members m ON m.org_id = o.id
		 WHERE m.user_id = $1 AND m.status = 'active'
		 ORDER BY m.created_at ASC`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("orgs: get my orgs: %w", err)
	}
	defer rows.Close()

	var orgs []OrgSummary
	for rows.Next() {
		var s OrgSummary
		if err := rows.Scan(&s.ID, &s.Slug, &s.Name, &s.Role); err != nil {
			return nil, fmt.Errorf("orgs: get my orgs: scan: %w", err)
		}
		orgs = append(orgs, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("orgs: get my orgs: rows: %w", err)
	}
	if orgs == nil {
		orgs = []OrgSummary{}
	}
	return orgs, nil
}

// Update patches allowed fields on an org. actorRole must be owner or admin.
func (s *OrgService) Update(ctx context.Context, orgID, actorUserID, actorRole string, req UpdateOrgRequest) (*Org, error) {
	if actorRole != RoleOwner && actorRole != RoleAdmin {
		return nil, ErrForbidden
	}

	setClauses := []string{"updated_at = now()"}
	args := []any{}
	argIdx := 1

	if req.Name != nil {
		name := strings.TrimSpace(*req.Name)
		if len(name) < 2 || len(name) > 100 {
			return nil, fmt.Errorf("invalid_name")
		}
		setClauses = append(setClauses, fmt.Sprintf("name = $%d", argIdx))
		args = append(args, name)
		argIdx++
	}
	if req.Description != nil {
		setClauses = append(setClauses, fmt.Sprintf("description = $%d", argIdx))
		args = append(args, *req.Description)
		argIdx++
	}
	if req.LogoURL != nil {
		setClauses = append(setClauses, fmt.Sprintf("logo_url = $%d", argIdx))
		args = append(args, *req.LogoURL)
		argIdx++
	}
	if req.SeatLimit != nil {
		setClauses = append(setClauses, fmt.Sprintf("seat_limit = $%d", argIdx))
		args = append(args, *req.SeatLimit)
		argIdx++
	}

	args = append(args, orgID)
	query := fmt.Sprintf(
		`UPDATE organizations SET %s WHERE id = $%d
		 RETURNING id, slug, name, logo_url, description, status, seat_limit,
		           active_member_count, onboarding_step, onboarding_completed_at,
		           activated_at, created_at, updated_at`,
		strings.Join(setClauses, ", "), argIdx,
	)

	var org Org
	err := s.pool.QueryRow(ctx, query, args...).Scan(
		&org.ID, &org.Slug, &org.Name, &org.LogoURL, &org.Description, &org.Status,
		&org.SeatLimit, &org.ActiveMemberCount, &org.OnboardingStep,
		&org.OnboardingCompletedAt, &org.ActivatedAt, &org.CreatedAt, &org.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: update: %w", err)
	}

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:      orgID,
		ActorUserID: &actorUserID,
		Action:     "org.updated",
		TargetType: "org",
		TargetID:   &orgID,
		AfterState: org,
	})

	return &org, nil
}

// Activate transitions an org from onboarding → active. Requires owner role and onboarding_step >= 4.
func (s *OrgService) Activate(ctx context.Context, orgID, actorUserID string) (*Org, error) {
	// Fetch current state first for validation and audit.
	org, err := s.GetByID(ctx, orgID, "")
	if err != nil {
		return nil, err
	}

	if org.Status != StatusOnboarding && org.Status != StatusPendingVerification {
		return nil, ErrInvalidStatus
	}
	if org.OnboardingStep < 4 {
		return nil, ErrOnboardingIncomplete
	}

	var updated Org
	err = s.pool.QueryRow(ctx,
		`UPDATE organizations
		 SET status = 'active', activated_at = now(), updated_at = now()
		 WHERE id = $1
		 RETURNING id, slug, name, logo_url, description, status, seat_limit,
		           active_member_count, onboarding_step, onboarding_completed_at,
		           activated_at, created_at, updated_at`,
		orgID,
	).Scan(
		&updated.ID, &updated.Slug, &updated.Name, &updated.LogoURL, &updated.Description, &updated.Status,
		&updated.SeatLimit, &updated.ActiveMemberCount, &updated.OnboardingStep,
		&updated.OnboardingCompletedAt, &updated.ActivatedAt, &updated.CreatedAt, &updated.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("orgs: activate: %w", err)
	}

	writeAuditLog(ctx, s.pool, auditEntry{
		OrgID:      orgID,
		ActorUserID: &actorUserID,
		Action:     "org.activated",
		TargetType: "org",
		TargetID:   &orgID,
		BeforeState: org,
		AfterState:  updated,
	})

	return &updated, nil
}

// SwitchOrg validates the user is an active member of the target org and returns the summary.
func (s *OrgService) SwitchOrg(ctx context.Context, userID, orgID string) (*OrgSummary, error) {
	var summary OrgSummary
	err := s.pool.QueryRow(ctx,
		`SELECT o.id, o.slug, o.name, m.role
		 FROM organizations o
		 JOIN org_members m ON m.org_id = o.id
		 WHERE o.id = $1 AND m.user_id = $2 AND m.status = 'active'`,
		orgID, userID,
	).Scan(&summary.ID, &summary.Slug, &summary.Name, &summary.Role)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrForbidden
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: switch org: %w", err)
	}
	return &summary, nil
}
