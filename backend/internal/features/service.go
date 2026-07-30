package features

import (
	"context"
	"fmt"
	"slices"
)

// alwaysOrgEnabled lists feature keys with no org-admin toggle or plan/add-on
// concept — personal utility features that every org "has" unconditionally.
// Access is gated entirely by RBAC (requiredPermission in frontend/lib/nav.ts)
// and, where applicable, feature_grants (see Repo.GrantedFeatureKeys).
//
// Every key below has no org-level toggle UI or plan/billing concept built
// yet — same situation "assessments" was in (see its own history in this
// list): without the key here, AccessGate's org check (frontend/components/
// shared/access-gate.tsx) returns null unconditionally, hiding the nav item
// and blocking the page for every user regardless of role or permission.
var alwaysOrgEnabled = []string{
	"what_now",
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
	// gitlab_integration: no org-level toggle UI or plan/billing concept —
	// same situation every other entry here is in. The feature is inert
	// until an org admin explicitly connects a GitLab installation
	// (internal/gitlab), so there is nothing unsafe about it being
	// unconditionally "on" for every org from day one.
	"gitlab_integration",
}

// alwaysEntitled is alwaysOrgEnabled minus "what_now" — none of these have a
// plan/add-on to gate behind either, so once the org has a feature, every
// user is entitled to it too; badging them "Upgrade" (AccessGate's fallback
// when orgEnabled but not entitled) is a false upsell with no unlock path.
// "what_now" is deliberately excluded: it's a genuine per-user opt-in via
// feature_grants (nav.ts sets it to mode: "hide" — invisible until granted),
// not a base feature, so it must stay entitlement-gated.
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
	// ai_connector: org-gated only (see Resolve), no per-user plan/seat
	// concept — once an org has it on, every member is entitled.
	"ai_connector",
}

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

// Resolve builds the full feature config for a user. There is currently no
// plan/add-on/org-grant entitlement system for anything other than "what_now"
// above, so LockedInfo is always empty — there is no unlock path to advertise.
//
// ai_connector is the first feature key with a real, DB-backed per-org
// on/off switch (org_ai_connector_config) rather than a static
// alwaysOrgEnabled entry — everything else in that list is unconditionally
// "on" for every org today.
func (s *Service) Resolve(ctx context.Context, userID, orgID string) (FeatureConfig, error) {
	granted, err := s.repo.GrantedFeatureKeys(ctx, userID)
	if err != nil {
		return FeatureConfig{}, fmt.Errorf("features: resolve: %w", err)
	}

	orgFeatures := slices.Clone(alwaysOrgEnabled)
	aiConnectorOn, err := s.repo.OrgAIConnectorEnabled(ctx, orgID)
	if err != nil {
		return FeatureConfig{}, fmt.Errorf("features: resolve: %w", err)
	}
	if aiConnectorOn {
		orgFeatures = append(orgFeatures, "ai_connector")
	}

	entitlements := slices.Clone(alwaysEntitled)
	for _, key := range granted {
		if !slices.Contains(entitlements, key) {
			entitlements = append(entitlements, key)
		}
	}

	return FeatureConfig{
		OrgFeatures:  orgFeatures,
		Entitlements: entitlements,
		LockedInfo:   map[string]LockedFeatureInfo{},
	}, nil
}
