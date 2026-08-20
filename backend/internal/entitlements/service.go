package entitlements

import (
	"context"
	"fmt"
	"slices"

	"github.com/mindforge/backend/internal/pricing"
)

type Service struct {
	repo *Repo
	// defaultOrgID is cfg.DefaultOrgID — the shared org every individual
	// (non-customer-org) user belongs to. See ResolveAccount.
	defaultOrgID string
}

func NewService(repo *Repo, defaultOrgID string) *Service {
	return &Service{repo: repo, defaultOrgID: defaultOrgID}
}

// ResolveAccount decides which account a tier check runs against. Every
// individual user shares cfg.DefaultOrgID (there is no per-user personal
// org), so orgID == defaultOrgID means "this is an individual account" —
// the tier and account_id are the user's own. Any other orgID is a real
// customer org: the tier and account_id belong to the org, shared by every
// member. Same shape docs/entitlements.md §3 describes ("account_id
// resolves to a user_id for individual plans or an org_id for org plans").
func (s *Service) ResolveAccount(ctx context.Context, userID, orgID string) (accountID, tierID, audience string, err error) {
	if orgID == "" || orgID == s.defaultOrgID {
		tierID, err = s.repo.UserTier(ctx, userID)
		if err != nil {
			return "", "", "", fmt.Errorf("entitlements: resolve account: %w", err)
		}
		return userID, tierID, pricing.AudienceIndividual, nil
	}
	tierID, err = s.repo.OrgTier(ctx, orgID)
	if err != nil {
		return "", "", "", fmt.Errorf("entitlements: resolve account: %w", err)
	}
	return orgID, tierID, pricing.AudienceOrg, nil
}

// GateEnabled reports whether tierID's plan_limits row for featureKey is on.
// No row (feature_key not in the seeded allowlist, or tier never
// configured) defaults to true, same "absent means unrestricted" convention
// as every other override table in this codebase — a key only ever
// restricts once an admin has actually seeded a row for it.
func (s *Service) GateEnabled(ctx context.Context, tierID, featureKey string) (bool, error) {
	enabled, found, err := s.repo.GateEnabled(ctx, tierID, featureKey)
	if err != nil {
		return false, err
	}
	if !found {
		return true, nil
	}
	return enabled, nil
}

// UnlockInfo builds the "how do I get this" contract for a gated-off
// feature — the lowest tier in audience that grants it.
func (s *Service) UnlockInfo(ctx context.Context, audience, featureKey string) (UnlockInfo, error) {
	tierName, found, err := s.repo.FirstUnlockingTier(ctx, audience, featureKey)
	if err != nil {
		return UnlockInfo{}, err
	}
	if !found {
		return UnlockInfo{UnlockVia: "plan", CTALabel: "Contact us", Reason: "Not available on any current plan."}, nil
	}
	if audience == pricing.AudienceOrg {
		return UnlockInfo{
			UnlockVia: "plan",
			CTALabel:  "Ask your admin to upgrade",
			Reason:    fmt.Sprintf("Available on the %s plan.", tierName),
		}, nil
	}
	return UnlockInfo{
		UnlockVia: "plan",
		CTALabel:  fmt.Sprintf("Upgrade to %s", tierName),
		Reason:    fmt.Sprintf("Available on the %s plan.", tierName),
	}, nil
}

// TierName exposes the display name for tierID — see Repo.TierName.
func (s *Service) TierName(ctx context.Context, tierID string) (string, error) {
	return s.repo.TierName(ctx, tierID)
}

// QuotaLimit exposes the raw plan_limits quota row for a domain package
// (labs) to enforce against — see docs/entitlements.md §6's "each domain
// package still owns its own call site" reasoning: this stays a lookup, not
// a check, so labs can combine it with its own live/accrued usage query.
func (s *Service) QuotaLimit(ctx context.Context, tierID, featureKey string) (limit int, period string, found bool, err error) {
	return s.repo.QuotaLimit(ctx, tierID, featureKey)
}

// MonthlySecondsUsed and AddMonthlySeconds back the lab_hours quota:
// labs.Service reads the former before starting a session, and its usage
// writer (RecordSessionContainerUsage/Batch) calls the latter once a session
// closes and its real duration is known.
func (s *Service) MonthlySecondsUsed(ctx context.Context, accountID, featureKey string) (int64, error) {
	return s.repo.GetMonthlySecondsUsed(ctx, accountID, featureKey)
}

func (s *Service) AddMonthlySeconds(ctx context.Context, accountID, featureKey string, seconds int64) error {
	return s.repo.AddMonthlySeconds(ctx, accountID, featureKey, seconds)
}

// ─── Platform admin ──────────────────────────────────────────────────────

// ListPlanLimits returns tierID's rows for the fixed allowlist only —
// including keys with no row yet (defaulted to enabled/unlimited) — so the
// admin editor always shows every editable key, not just the ones already
// configured.
func (s *Service) ListPlanLimits(ctx context.Context, tierID string) ([]PlanLimit, error) {
	audience, err := s.repo.TierAudience(ctx, tierID)
	if err != nil {
		return nil, fmt.Errorf("%w", ErrInvalidTier)
	}

	existing, err := s.repo.ListPlanLimits(ctx, tierID)
	if err != nil {
		return nil, err
	}
	byKey := make(map[string]PlanLimit, len(existing))
	for _, pl := range existing {
		byKey[pl.FeatureKey] = pl
	}

	gateKeys := IndividualGateKeys
	if audience == pricing.AudienceOrg {
		gateKeys = OrgGateKeys
	}

	out := make([]PlanLimit, 0, len(gateKeys)+len(QuotaKeys))
	for _, key := range gateKeys {
		if pl, ok := byKey[key]; ok {
			out = append(out, pl)
			continue
		}
		enabled := true
		out = append(out, PlanLimit{TierID: tierID, FeatureKey: key, Kind: KindGate, BoolValue: &enabled})
	}
	if audience == pricing.AudienceIndividual {
		for _, key := range QuotaKeys {
			if pl, ok := byKey[key]; ok {
				out = append(out, pl)
			}
		}
	}
	return out, nil
}

// UpsertPlanLimit validates feature_key against the fixed allowlist for
// tierID's audience and kind consistency before writing — the admin editor
// can only ever set a value on a key something actually reads.
func (s *Service) UpsertPlanLimit(ctx context.Context, pl PlanLimit, updatedBy string) error {
	audience, err := s.repo.TierAudience(ctx, pl.TierID)
	if err != nil {
		return ErrInvalidTier
	}

	gateKeys := IndividualGateKeys
	if audience == pricing.AudienceOrg {
		gateKeys = OrgGateKeys
	}

	switch {
	case slices.Contains(gateKeys, pl.FeatureKey):
		if pl.Kind != KindGate || pl.BoolValue == nil {
			return fmt.Errorf("%w: %s is a gate key", ErrUnknownFeatureKey, pl.FeatureKey)
		}
		pl.NumericValue, pl.Period = nil, nil
	case audience == pricing.AudienceIndividual && slices.Contains(QuotaKeys, pl.FeatureKey):
		if pl.Kind != KindQuota || pl.NumericValue == nil || pl.Period == nil {
			return fmt.Errorf("%w: %s is a quota key", ErrUnknownFeatureKey, pl.FeatureKey)
		}
		pl.BoolValue = nil
	default:
		return ErrUnknownFeatureKey
	}

	return s.repo.UpsertPlanLimit(ctx, pl, updatedBy)
}

// SetAccountTier assigns tierID to a user or an org, rejecting a tier from
// the wrong audience (an org can't be put on an individual plan and vice
// versa).
func (s *Service) SetAccountTier(ctx context.Context, kind, accountID, tierID, updatedBy string) error {
	audience, err := s.repo.TierAudience(ctx, tierID)
	if err != nil {
		return ErrInvalidTier
	}
	switch kind {
	case "user":
		if audience != pricing.AudienceIndividual {
			return ErrInvalidTier
		}
		return s.repo.SetUserTier(ctx, accountID, tierID, updatedBy)
	case "org":
		if audience != pricing.AudienceOrg {
			return ErrInvalidTier
		}
		return s.repo.SetOrgTier(ctx, accountID, tierID, updatedBy)
	default:
		return fmt.Errorf("entitlements: unknown account kind %q", kind)
	}
}
