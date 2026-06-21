package orgs

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// OrgOnboardingService handles step-by-step onboarding progress.
type OrgOnboardingService struct {
	pool *pgxpool.Pool
}

func NewOrgOnboardingService(pool *pgxpool.Pool) *OrgOnboardingService {
	return &OrgOnboardingService{pool: pool}
}

// GetState returns the current onboarding state (org data + auth config + step).
func (s *OrgOnboardingService) GetState(ctx context.Context, orgID string) (*OnboardingState, error) {
	var org Org
	err := s.pool.QueryRow(ctx,
		`SELECT id, slug, name, logo_url, description, status, seat_limit,
		        active_member_count, onboarding_step, onboarding_completed_at,
		        activated_at, created_at, updated_at
		 FROM organizations WHERE id = $1`,
		orgID,
	).Scan(
		&org.ID, &org.Slug, &org.Name, &org.LogoURL, &org.Description, &org.Status,
		&org.SeatLimit, &org.ActiveMemberCount, &org.OnboardingStep,
		&org.OnboardingCompletedAt, &org.ActivatedAt, &org.CreatedAt, &org.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: onboarding get state: fetch org: %w", err)
	}

	authCfg, err := s.fetchAuthConfig(ctx, orgID)
	if err != nil {
		return nil, err
	}

	return &OnboardingState{
		Step:                  org.OnboardingStep,
		OnboardingCompletedAt: org.OnboardingCompletedAt,
		Org:                   &org,
		AuthConfig:            authCfg,
	}, nil
}

// SaveStep upserts data for the given step number and advances onboarding_step if needed.
// Step 4 completion sets onboarding_completed_at.
func (s *OrgOnboardingService) SaveStep(ctx context.Context, orgID string, step int, req SaveOnboardingRequest) (*OnboardingState, error) {
	switch step {
	case 1:
		if err := s.saveStep1(ctx, orgID, req); err != nil {
			return nil, err
		}
	case 2:
		if err := s.saveStep2(ctx, orgID, req); err != nil {
			return nil, err
		}
	case 3:
		if err := s.saveStep3(ctx, orgID, req); err != nil {
			return nil, err
		}
	case 4:
		if err := s.saveStep4(ctx, orgID); err != nil {
			return nil, err
		}
	default:
		return nil, fmt.Errorf("orgs: onboarding: invalid step %d", step)
	}

	return s.GetState(ctx, orgID)
}

func (s *OrgOnboardingService) saveStep1(ctx context.Context, orgID string, req SaveOnboardingRequest) error {
	setClauses := []string{"onboarding_step = GREATEST(onboarding_step, 1)", "updated_at = now()"}
	args := []any{}
	argIdx := 1

	if req.Name != nil {
		name := strings.TrimSpace(*req.Name)
		if len(name) < 2 || len(name) > 100 {
			return fmt.Errorf("invalid_name")
		}
		setClauses = append(setClauses, fmt.Sprintf("name = $%d", argIdx))
		args = append(args, name)
		argIdx++
	}
	if req.Slug != nil {
		slug := strings.TrimSpace(strings.ToLower(*req.Slug))
		if !slugRE.MatchString(slug) {
			return fmt.Errorf("invalid_slug")
		}
		if IsReservedSlug(slug) {
			return fmt.Errorf("reserved_slug")
		}
		setClauses = append(setClauses, fmt.Sprintf("slug = $%d", argIdx))
		args = append(args, slug)
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

	args = append(args, orgID)
	query := fmt.Sprintf(
		`UPDATE organizations SET %s WHERE id = $%d`,
		strings.Join(setClauses, ", "), argIdx,
	)
	if _, err := s.pool.Exec(ctx, query, args...); err != nil {
		return fmt.Errorf("orgs: onboarding step1: %w", err)
	}
	return nil
}

func (s *OrgOnboardingService) saveStep2(ctx context.Context, orgID string, req SaveOnboardingRequest) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("orgs: onboarding step2: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	// Upsert auth config.
	upsertClauses := []string{}
	args := []any{orgID}
	argIdx := 2

	upsertArgs := []string{"$1"}
	insertCols := []string{"org_id"}

	if req.SSOEnabled != nil {
		insertCols = append(insertCols, "sso_enabled")
		upsertArgs = append(upsertArgs, fmt.Sprintf("$%d", argIdx))
		upsertClauses = append(upsertClauses, fmt.Sprintf("sso_enabled = $%d", argIdx))
		args = append(args, *req.SSOEnabled)
		argIdx++
	}
	if req.SSOProvider != nil {
		insertCols = append(insertCols, "sso_provider")
		upsertArgs = append(upsertArgs, fmt.Sprintf("$%d", argIdx))
		upsertClauses = append(upsertClauses, fmt.Sprintf("sso_provider = $%d", argIdx))
		args = append(args, *req.SSOProvider)
		argIdx++
	}
	if req.AllowedDomains != nil {
		insertCols = append(insertCols, "allowed_domains")
		upsertArgs = append(upsertArgs, fmt.Sprintf("$%d", argIdx))
		upsertClauses = append(upsertClauses, fmt.Sprintf("allowed_domains = $%d", argIdx))
		args = append(args, *req.AllowedDomains)
		argIdx++
	}

	var upsertQuery string
	if len(upsertClauses) > 0 {
		upsertQuery = fmt.Sprintf(
			`INSERT INTO org_auth_config (%s) VALUES (%s)
			 ON CONFLICT (org_id) DO UPDATE SET %s, updated_at = now()`,
			strings.Join(insertCols, ", "),
			strings.Join(upsertArgs, ", "),
			strings.Join(upsertClauses, ", "),
		)
	} else {
		upsertQuery = `INSERT INTO org_auth_config (org_id) VALUES ($1) ON CONFLICT DO NOTHING`
	}

	if _, err := tx.Exec(ctx, upsertQuery, args...); err != nil {
		return fmt.Errorf("orgs: onboarding step2: upsert auth config: %w", err)
	}

	// Advance org status and step.
	if _, err := tx.Exec(ctx,
		`UPDATE organizations
		 SET onboarding_step = GREATEST(onboarding_step, 2),
		     status = CASE WHEN status = 'pending_verification' THEN 'onboarding' ELSE status END,
		     updated_at = now()
		 WHERE id = $1`,
		orgID,
	); err != nil {
		return fmt.Errorf("orgs: onboarding step2: update org: %w", err)
	}

	return tx.Commit(ctx)
}

func (s *OrgOnboardingService) saveStep3(ctx context.Context, orgID string, req SaveOnboardingRequest) error {
	setClauses := []string{"onboarding_step = GREATEST(onboarding_step, 3)", "updated_at = now()"}
	args := []any{}
	argIdx := 1

	if req.SeatLimit != nil {
		setClauses = append(setClauses, fmt.Sprintf("seat_limit = $%d", argIdx))
		args = append(args, *req.SeatLimit)
		argIdx++
	}

	args = append(args, orgID)
	query := fmt.Sprintf(
		`UPDATE organizations SET %s WHERE id = $%d`,
		strings.Join(setClauses, ", "), argIdx,
	)
	if _, err := s.pool.Exec(ctx, query, args...); err != nil {
		return fmt.Errorf("orgs: onboarding step3: %w", err)
	}
	return nil
}

func (s *OrgOnboardingService) saveStep4(ctx context.Context, orgID string) error {
	if _, err := s.pool.Exec(ctx,
		`UPDATE organizations
		 SET onboarding_step = 4,
		     onboarding_completed_at = COALESCE(onboarding_completed_at, now()),
		     status = CASE WHEN status NOT IN ('active', 'suspended', 'archived') THEN 'onboarding' ELSE status END,
		     updated_at = now()
		 WHERE id = $1`,
		orgID,
	); err != nil {
		return fmt.Errorf("orgs: onboarding step4: %w", err)
	}
	return nil
}

func (s *OrgOnboardingService) fetchAuthConfig(ctx context.Context, orgID string) (*OrgAuthConfig, error) {
	var cfg OrgAuthConfig
	var allowedDomains []string
	err := s.pool.QueryRow(ctx,
		`SELECT org_id, sso_enabled, sso_provider, password_policy, allowed_domains
		 FROM org_auth_config WHERE org_id = $1`,
		orgID,
	).Scan(&cfg.OrgID, &cfg.SSOEnabled, &cfg.SSOProvider, &cfg.PasswordPolicy, &allowedDomains)
	if errors.Is(err, pgx.ErrNoRows) {
		// Bootstrap may not have run yet — return a zero config rather than an error.
		return &OrgAuthConfig{OrgID: orgID, AllowedDomains: []string{}}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("orgs: fetch auth config: %w", err)
	}
	if allowedDomains == nil {
		allowedDomains = []string{}
	}
	cfg.AllowedDomains = allowedDomains
	return &cfg, nil
}
