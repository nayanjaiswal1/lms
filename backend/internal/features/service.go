package features

import (
	"context"
	"fmt"
)

// alwaysOrgEnabled lists feature keys with no org-admin toggle or plan/add-on
// concept — personal utility features that every org "has" unconditionally.
// Access is gated entirely by feature_grants (see Repo.GrantedFeatureKeys).
var alwaysOrgEnabled = []string{"what_now"}

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

// Resolve builds the full feature config for a user. There is currently no
// plan/add-on/org-grant entitlement system for anything other than the
// always-org-enabled personal features above, so LockedInfo is always empty —
// there is no unlock path to advertise.
func (s *Service) Resolve(ctx context.Context, userID string) (FeatureConfig, error) {
	granted, err := s.repo.GrantedFeatureKeys(ctx, userID)
	if err != nil {
		return FeatureConfig{}, fmt.Errorf("features: resolve: %w", err)
	}

	return FeatureConfig{
		OrgFeatures:  alwaysOrgEnabled,
		Entitlements: granted,
		LockedInfo:   map[string]LockedFeatureInfo{},
	}, nil
}
