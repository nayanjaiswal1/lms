// Package entitlements links pricing_tiers (migration 004, marketing-only)
// to real enforcement: which tier an account is on, and what that tier
// allows. See docs/entitlements.md for the full design and what's
// deliberately not built yet.
package entitlements

import (
	"errors"
	"time"
)

type Kind string

const (
	KindGate      Kind = "gate"
	KindQuota     Kind = "quota"
	KindUnlimited Kind = "unlimited"
)

const (
	PeriodDay        = "day"
	PeriodMonth      = "month"
	PeriodConcurrent = "concurrent"
)

// OrgGateKeys and IndividualGateKeys are the fixed, known feature_key
// allowlists for kind=gate plan_limits rows — one key per axis (org tier vs
// individual tier), matching which resolver actually reads it
// (features.Service.Resolve, see its DefaultOrgID branch). Admin writes
// reject any feature_key outside these lists: a row nothing reads is dead
// config, not a feature.
var (
	OrgGateKeys = []string{"assessments", "gitlab_integration"}

	// what_now/revision_digest are deliberately excluded: they're per-user
	// opt-in beta grants (features.Service's GrantedFeatureKeys mechanism),
	// "no unlock path to advertise" per frontend/lib/features.ts's
	// REVISION_DIGEST comment — tier-gating them would contradict that.
	IndividualGateKeys = []string{
		"system_design", "interview_board", "load_test", "certificates",
	}

	// QuotaKeys are individual-tier only today — labs.Service is the one
	// reader (StartSession pre-check, RecordSessionContainerUsage accrual).
	QuotaKeys = []string{"lab_sessions_concurrent", "lab_hours"}
)

var (
	ErrUnknownFeatureKey = errors.New("entitlements: unknown feature key")
	ErrInvalidTier       = errors.New("entitlements: tier does not exist or wrong audience")
	ErrQuotaExceeded     = errors.New("entitlements: quota exceeded")
)

// PlanLimit is one (tier, feature_key) row — the admin-editable unit.
type PlanLimit struct {
	TierID       string    `json:"tier_id"`
	FeatureKey   string    `json:"feature_key"`
	Kind         Kind      `json:"kind"`
	BoolValue    *bool     `json:"bool_value,omitempty"`
	NumericValue *int      `json:"numeric_value,omitempty"`
	Period       *string   `json:"period,omitempty"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// UnlockInfo mirrors frontend/lib/features.ts's LockedFeatureInfo shape
// (UnlockVia/CTALabel/Reason) without importing the features package — see
// features.Service.Resolve, which converts this 1:1 into its own
// LockedFeatureInfo to avoid an entitlements<->features import cycle.
type UnlockInfo struct {
	UnlockVia string
	CTALabel  string
	Reason    string
}

// UsageStatus is one quota key's current standing for an account, for the
// "My Plan" usage bars (GET /api/me/usage).
type UsageStatus struct {
	FeatureKey string `json:"feature_key"`
	Used       int    `json:"used"`
	Limit      int    `json:"limit"`
	Period     string `json:"period"`
}
