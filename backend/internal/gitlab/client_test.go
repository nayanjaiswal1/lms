package gitlab

import "testing"

// TestPlanToTier covers the GET /license plan-string -> tier mapping
// DetectTier uses to distinguish Premium from Ultimate once an installation
// token proves admin-scoped enough to read /license. Only the HTTP call
// itself (blocking/unblocking on admin scope) is untested here — that part
// is exercised indirectly by every DetectTier caller falling back to
// TierPremium whenever /license errors, which callers already rely on.
func TestPlanToTier(t *testing.T) {
	cases := []struct {
		plan     string
		wantTier string
		wantOK   bool
	}{
		{"ultimate", TierUltimate, true},
		{"Ultimate", TierUltimate, true},
		{"  ultimate  ", TierUltimate, true},
		{"premium", TierPremium, true},
		{"PREMIUM", TierPremium, true},
		{"free", "", false},
		{"starter", "", false},
		{"", "", false},
		{"bronze", "", false},
	}
	for _, tc := range cases {
		tier, ok := planToTier(tc.plan)
		if tier != tc.wantTier || ok != tc.wantOK {
			t.Errorf("planToTier(%q) = (%q, %v), want (%q, %v)", tc.plan, tier, ok, tc.wantTier, tc.wantOK)
		}
	}
}
