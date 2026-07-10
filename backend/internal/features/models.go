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
