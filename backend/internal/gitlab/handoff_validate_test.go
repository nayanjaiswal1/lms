package gitlab

import "testing"

func TestValidateHandoffRequest(t *testing.T) {
	if f := ValidateHandoffRequest(HandoffRequest{UserID: "u", Mode: HandoffModeFork, TargetNamespaceID: 1}); len(f) != 0 {
		t.Fatalf("valid request rejected: %v", f)
	}
	f := ValidateHandoffRequest(HandoffRequest{Mode: "copy"})
	for _, k := range []string{"user_id", "mode", "target_namespace_id"} {
		if f[k] == "" {
			t.Errorf("missing field error for %s", k)
		}
	}
}
