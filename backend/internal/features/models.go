package features

// FeatureConfig mirrors the frontend's FeatureConfig contract
// (frontend/lib/server/features.ts) exactly — field names and casing must
// match so the frontend can decode the response with no translation layer.
type FeatureConfig struct {
	OrgFeatures  []string                     `json:"orgFeatures"`
	Entitlements []string                     `json:"entitlements"`
	LockedInfo   map[string]LockedFeatureInfo `json:"lockedInfo"`
}

// LockedFeatureInfo mirrors frontend/lib/features.ts's LockedFeatureInfo.
type LockedFeatureInfo struct {
	UnlockVia string `json:"unlock_via"`
	CTALabel  string `json:"cta_label"`
	Reason    string `json:"reason"`
}

// OrgFeatureFlag is one org-toggleable feature's resolved state, for the
// platform admin's per-org feature-flags page. Overridden is false when no
// row exists in org_feature_flags yet — Enabled then reflects the code
// default (see alwaysOrgEnabled in service.go), not an explicit admin choice.
type OrgFeatureFlag struct {
	Key        string `json:"key"`
	Enabled    bool   `json:"enabled"`
	Overridden bool   `json:"overridden"`
}

// UserFeatureFlag is one user-toggleable feature's resolved state for a
// single member, for the org admin's per-user feature-flags page. Only
// features the org itself currently has enabled are ever returned — see
// Service.ListUserFeatureFlags.
type UserFeatureFlag struct {
	Key        string `json:"key"`
	Enabled    bool   `json:"enabled"`
	Overridden bool   `json:"overridden"`
}

// EntitledUser is one user holding a features.<key> permission grant, plus
// the contact/preference fields a batch job needs to act on that grant
// without a second round-trip per user — used by fan-out jobs (e.g. the
// nightly revision digest, internal/jobs/handlers/digest_nightly.go) that
// iterate every entitled user rather than resolve one user's FeatureConfig
// at a time via Service.Resolve.
type EntitledUser struct {
	UserID        string
	OrgID         string
	Email         string
	Name          string
	Timezone      string
	Notifications map[string]any
}
