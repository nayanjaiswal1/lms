package handlers

import (
	"testing"
	"time"

	"github.com/mindforge/backend/internal/labs"
)

// Regression: the validate-sandbox sweep aged Pods from creation, so a build
// Pod that waited Pending for capacity was killed minutes into its real run.
// Age counts from when the container started running.
func TestValidateSandboxLiveAgesFromStart(t *testing.T) {
	now := time.Now()
	cases := []struct {
		name string
		sb   labs.ContainerInfo
		live bool
	}{
		{"pending long, running briefly", labs.ContainerInfo{CreatedAt: now.Add(-20 * time.Minute), StartedAt: now.Add(-5 * time.Minute)}, true},
		{"running past budget", labs.ContainerInfo{CreatedAt: now.Add(-20 * time.Minute), StartedAt: now.Add(-16 * time.Minute)}, false},
		{"never started, orphaned", labs.ContainerInfo{CreatedAt: now.Add(-16 * time.Minute)}, false},
		{"no start reported, young", labs.ContainerInfo{CreatedAt: now.Add(-time.Minute)}, true},
	}
	for _, c := range cases {
		if got := validateSandboxLive(c.sb, now); got != c.live {
			t.Errorf("%s: live=%v, want %v", c.name, got, c.live)
		}
	}
}
