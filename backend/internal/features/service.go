package features

import (
	"context"
	"errors"
	"fmt"
	"slices"

	"golang.org/x/sync/errgroup"

	ent "github.com/mindforge/backend/internal/entitlements"
	"github.com/mindforge/backend/internal/pricing"
)

// alwaysOrgEnabled lists every feature key a platform admin can toggle on/off
// per org via org_feature_flags (Service.SetOrgFeatureFlag). A key with no
// row in org_feature_flags for a given org defaults to enabled — every org
// behaves exactly as before an admin ever touches this table. The keys in
// entitlements.OrgGateKeys/IndividualGateKeys are the exception: their
// default now comes from the account's pricing tier (see Resolve), and
// org_feature_flags/user_feature_flags still override that default exactly
// as before.
//
// ai_connector and session_booking are deliberately absent: they keep their
// own dedicated org_settings columns (see OrgAIConnectorEnabled/
// OrgSessionBookingEnabled) because "enabled" there lives alongside other
// policy fields in the same settings blob — folding just the flag into this
// generic table would fork that state into two sources of truth. social_auth,
// magic_link, ai_features, quizzes, payments, anonymous_tests, multi_org,
// profile, and batch_chat are also absent: Resolve never gates on them today,
// so there is nothing for a toggle to control yet.
var alwaysOrgEnabled = []string{
	"what_now",
	"revision_digest",
	"assessments",
	"courses",
	"practice_ai",
	"flashcards",
	"sheet_tracker",
	"mentors",
	"certificates",
	"wiki",
	"system_design",
	"interview_board",
	"load_test",
	"interview_exp",
	"gitlab_integration",
	"lesson_compiler_bottom_dock",
}

// alwaysEntitled is alwaysOrgEnabled minus "what_now" and "revision_digest":
// once an org has one of these on, every member is entitled by default (no
// plan/add-on to gate behind), unless an org admin explicitly revokes it for
// that member via user_feature_flags (Service.SetUserFeatureFlag).
var alwaysEntitled = []string{
	"assessments",
	"courses",
	"practice_ai",
	"flashcards",
	"sheet_tracker",
	"mentors",
	"certificates",
	"wiki",
	"system_design",
	"interview_board",
	"load_test",
	"interview_exp",
	"gitlab_integration",
	"ai_connector",
	"session_booking",
	"lesson_compiler_bottom_dock",
}

// userToggleable is alwaysEntitled minus "ai_connector" and "session_booking"
// — the set of feature keys an org admin can grant/revoke per member via
// user_feature_flags. ai_connector/session_booking stay org-gated-only by
// design (see their doc comments in repo.go): what a member may do with them
// is bounded by other domain-specific limits, not a per-user entitlement, so
// exposing a redundant per-user toggle here would just be a second, weaker
// copy of a limit already enforced elsewhere.
var userToggleable = []string{
	"assessments",
	"courses",
	"practice_ai",
	"flashcards",
	"sheet_tracker",
	"mentors",
	"certificates",
	"wiki",
	"system_design",
	"interview_board",
	"load_test",
	"interview_exp",
	"gitlab_integration",
	"lesson_compiler_bottom_dock",
}

// Sentinel errors returned by the admin-facing Set/List methods below.
var (
	ErrUnknownFeatureKey    = errors.New("features: unknown feature key")
	ErrFeatureNotOrgEnabled = errors.New("features: org has not enabled this feature")
	ErrNotOrgMember         = errors.New("features: user is not an active member of this org")
)

type Service struct {
	repo         *Repo
	entitlements *ent.Service
}

func NewService(repo *Repo, entitlementsSvc *ent.Service) *Service {
	return &Service{repo: repo, entitlements: entitlementsSvc}
}

// Resolve builds the full feature config for a user. Every key in
// alwaysOrgEnabled/alwaysEntitled defaults to on, same as before
// org_feature_flags/user_feature_flags existed, EXCEPT the keys in
// entitlements.OrgGateKeys/IndividualGateKeys — those default to whatever
// the account's pricing tier says (see entitlements.Service.ResolveAccount
// for the individual-vs-org axis split), with org_feature_flags/
// user_feature_flags still able to override that default same as always. An
// explicit override row flips the default for one org or one member.
// what_now/revision_digest also stay on the permission-grant mechanism
// (GrantedFeatureKeys) for entitlement, gated additionally by the org-level
// toggle so a platform admin can still kill either org-wide.
func (s *Service) Resolve(ctx context.Context, userID, orgID string) (FeatureConfig, error) {
	// The six reads are independent, so they run concurrently — sequentially
	// they dominated /api/me/features (hit by every page render via bootstrap).
	var (
		granted          []string
		orgOverrides     map[string]bool
		userOverrides    map[string]bool
		tierID, audience string
		aiConnectorOn    bool
		sessionBookingOn bool
	)
	g, gctx := errgroup.WithContext(ctx)
	g.Go(func() (err error) { granted, err = s.repo.GrantedFeatureKeys(gctx, userID); return })
	g.Go(func() (err error) { orgOverrides, err = s.repo.OrgFeatureOverrides(gctx, orgID); return })
	g.Go(func() (err error) { userOverrides, err = s.repo.UserFeatureOverrides(gctx, orgID, userID); return })
	g.Go(func() (err error) { aiConnectorOn, err = s.repo.OrgAIConnectorEnabled(gctx, orgID); return })
	g.Go(func() (err error) { sessionBookingOn, err = s.repo.OrgSessionBookingEnabled(gctx, orgID); return })
	g.Go(func() (err error) {
		_, tierID, audience, err = s.entitlements.ResolveAccount(gctx, userID, orgID)
		return
	})
	if err := g.Wait(); err != nil {
		return FeatureConfig{}, fmt.Errorf("features: resolve: %w", err)
	}

	gates, err := s.entitlements.GateMap(ctx, tierID)
	if err != nil {
		return FeatureConfig{}, fmt.Errorf("features: resolve: %w", err)
	}

	orgFeatures := []string{}
	orgFeatureSet := map[string]bool{}
	for _, key := range alwaysOrgEnabled {
		enabled := true
		if audience == pricing.AudienceOrg && slices.Contains(ent.OrgGateKeys, key) {
			enabled = gates.Enabled(key)
		}
		if v, ok := orgOverrides[key]; ok {
			enabled = v
		}
		if enabled {
			orgFeatures = append(orgFeatures, key)
			orgFeatureSet[key] = true
		}
	}
	if aiConnectorOn {
		orgFeatures = append(orgFeatures, "ai_connector")
		orgFeatureSet["ai_connector"] = true
	}
	if sessionBookingOn {
		orgFeatures = append(orgFeatures, "session_booking")
		orgFeatureSet["session_booking"] = true
	}

	entitlementList := []string{}
	locked := map[string]bool{}
	for _, key := range alwaysEntitled {
		if !orgFeatureSet[key] {
			continue
		}
		if key == "ai_connector" || key == "session_booking" {
			entitlementList = append(entitlementList, key)
			continue
		}
		enabled := true
		tierGated := audience == pricing.AudienceIndividual && slices.Contains(ent.IndividualGateKeys, key)
		if tierGated {
			enabled = gates.Enabled(key)
		}
		if v, ok := userOverrides[key]; ok {
			enabled = v
		}
		if enabled {
			entitlementList = append(entitlementList, key)
		} else if tierGated {
			locked[key] = true
		}
	}
	for _, key := range granted {
		if orgFeatureSet[key] && !slices.Contains(entitlementList, key) {
			entitlementList = append(entitlementList, key)
			delete(locked, key)
		}
	}

	lockedInfo := map[string]LockedFeatureInfo{}
	if len(locked) > 0 {
		unlock, err := s.entitlements.UnlockInfos(ctx, pricing.AudienceIndividual)
		if err != nil {
			return FeatureConfig{}, fmt.Errorf("features: resolve: %w", err)
		}
		for key := range locked {
			info := unlock.For(key)
			lockedInfo[key] = LockedFeatureInfo{UnlockVia: info.UnlockVia, CTALabel: info.CTALabel, Reason: info.Reason}
		}
	}

	return FeatureConfig{
		OrgFeatures:  orgFeatures,
		Entitlements: entitlementList,
		LockedInfo:   lockedInfo,
	}, nil
}

// ListOrgFeatureFlags returns the resolved state of every org-toggleable
// feature for orgID, for the platform admin's per-org feature-flags page.
func (s *Service) ListOrgFeatureFlags(ctx context.Context, orgID string) ([]OrgFeatureFlag, error) {
	overrides, err := s.repo.OrgFeatureOverrides(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("features: list org feature flags: %w", err)
	}

	flags := make([]OrgFeatureFlag, 0, len(alwaysOrgEnabled))
	for _, key := range alwaysOrgEnabled {
		v, overridden := overrides[key]
		enabled := true
		if overridden {
			enabled = v
		}
		flags = append(flags, OrgFeatureFlag{Key: key, Enabled: enabled, Overridden: overridden})
	}
	return flags, nil
}

// SetOrgFeatureFlag records a platform admin's on/off decision for
// featureKey within orgID.
func (s *Service) SetOrgFeatureFlag(ctx context.Context, orgID, featureKey string, enabled bool, updatedBy string) error {
	if !slices.Contains(alwaysOrgEnabled, featureKey) {
		return ErrUnknownFeatureKey
	}
	return s.repo.SetOrgFeatureFlag(ctx, orgID, featureKey, enabled, updatedBy)
}

// ClearOrgFeatureFlag reverts featureKey back to its code default for orgID.
func (s *Service) ClearOrgFeatureFlag(ctx context.Context, orgID, featureKey string) error {
	if !slices.Contains(alwaysOrgEnabled, featureKey) {
		return ErrUnknownFeatureKey
	}
	return s.repo.ClearOrgFeatureFlag(ctx, orgID, featureKey)
}

// ListUserFeatureFlags returns the resolved state of every user-toggleable
// feature the org currently has enabled, for one member — for the org
// admin's per-user feature-flags dialog. Features the org itself doesn't
// have are omitted entirely: there is nothing for the org admin to grant.
func (s *Service) ListUserFeatureFlags(ctx context.Context, orgID, userID string) ([]UserFeatureFlag, error) {
	isMember, err := s.repo.IsActiveOrgMember(ctx, orgID, userID)
	if err != nil {
		return nil, fmt.Errorf("features: list user feature flags: %w", err)
	}
	if !isMember {
		return nil, ErrNotOrgMember
	}

	orgOverrides, err := s.repo.OrgFeatureOverrides(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("features: list user feature flags: %w", err)
	}
	userOverrides, err := s.repo.UserFeatureOverrides(ctx, orgID, userID)
	if err != nil {
		return nil, fmt.Errorf("features: list user feature flags: %w", err)
	}

	flags := []UserFeatureFlag{}
	for _, key := range userToggleable {
		orgEnabled := true
		if v, ok := orgOverrides[key]; ok {
			orgEnabled = v
		}
		if !orgEnabled {
			continue
		}
		v, overridden := userOverrides[key]
		enabled := true
		if overridden {
			enabled = v
		}
		flags = append(flags, UserFeatureFlag{Key: key, Enabled: enabled, Overridden: overridden})
	}
	return flags, nil
}

// SetUserFeatureFlag records an org admin's on/off decision for featureKey
// for one member. Rejects keys the org hasn't enabled — granting a feature
// the org itself doesn't have would create a dangling override that never
// takes effect and is confusing to audit later.
func (s *Service) SetUserFeatureFlag(ctx context.Context, orgID, userID, featureKey string, enabled bool, updatedBy string) error {
	if !slices.Contains(userToggleable, featureKey) {
		return ErrUnknownFeatureKey
	}
	isMember, err := s.repo.IsActiveOrgMember(ctx, orgID, userID)
	if err != nil {
		return fmt.Errorf("features: set user feature flag: %w", err)
	}
	if !isMember {
		return ErrNotOrgMember
	}

	orgOverrides, err := s.repo.OrgFeatureOverrides(ctx, orgID)
	if err != nil {
		return fmt.Errorf("features: set user feature flag: %w", err)
	}
	orgEnabled := true
	if v, ok := orgOverrides[featureKey]; ok {
		orgEnabled = v
	}
	if !orgEnabled {
		return ErrFeatureNotOrgEnabled
	}

	return s.repo.SetUserFeatureFlag(ctx, orgID, userID, featureKey, enabled, updatedBy)
}

// ClearUserFeatureFlag reverts featureKey back to the org's default
// entitlement for one member.
func (s *Service) ClearUserFeatureFlag(ctx context.Context, orgID, userID, featureKey string) error {
	if !slices.Contains(userToggleable, featureKey) {
		return ErrUnknownFeatureKey
	}
	isMember, err := s.repo.IsActiveOrgMember(ctx, orgID, userID)
	if err != nil {
		return fmt.Errorf("features: clear user feature flag: %w", err)
	}
	if !isMember {
		return ErrNotOrgMember
	}
	return s.repo.ClearUserFeatureFlag(ctx, orgID, userID, featureKey)
}
