package labs

import "testing"

// TestRequiresRuntimeClass covers the split of Elevated from Name
// (docs/debug-labs.md Phase 0): a resource-only profile like the future
// debug-ide (named, but not elevated) must NOT be forced through
// KubernetesContainerService.startPod's RuntimeClass requirement — only
// Elevated does that.
func TestRequiresRuntimeClass(t *testing.T) {
	cases := []struct {
		name    string
		profile ImageProfile
		want    bool
	}{
		{
			name:    "standard zero-value profile",
			profile: ImageProfile{},
			want:    false,
		},
		{
			name:    "named but not elevated (resource-only, e.g. debug-ide)",
			profile: ImageProfile{Name: "debug-ide", Elevated: false, CPU: "2", MemoryMB: 2048},
			want:    false,
		},
		{
			name:    "elevated with no RuntimeClass configured — must fail",
			profile: ImageProfile{Name: ImageProfileNestedDocker, Elevated: true},
			want:    true,
		},
		{
			name:    "elevated with RuntimeClass configured — allowed",
			profile: ImageProfile{Name: ImageProfileNestedDocker, Elevated: true, K8sRuntimeClass: "sysbox-runc"},
			want:    false,
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := requiresRuntimeClass(tc.profile); got != tc.want {
				t.Errorf("requiresRuntimeClass(%+v) = %v, want %v", tc.profile, got, tc.want)
			}
		})
	}
}
