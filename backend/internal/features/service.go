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
func (s *Service) Resolve(ctx context.Context, userID string) (FeatureConfig, error) {
	granted, err := s.repo.GrantedFeatureKeys(ctx, userID)
	if err != nil {
		return FeatureConfig{}, fmt.Errorf("features: resolve: %w", err)
	}

	entitlements := slices.Clone(alwaysEntitled)
	for _, key := range granted {
		if !slices.Contains(entitlements, key) {
			entitlements = append(entitlements, key)
		}
	}

	return FeatureConfig{
		OrgFeatures:  alwaysOrgEnabled,
		Entitlements: entitlements,
		LockedInfo:   map[string]LockedFeatureInfo{},
	}, nil
}
