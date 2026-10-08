package handlers

import (
	"testing"

	"github.com/mindforge/backend/internal/config"
)

func TestRetentionSteps(t *testing.T) {
	// auth_events purge must opt in to the append-only trigger bypass.
	if s := findRetentionStep(t, &config.Config{RetentionAuthEventsDays: 5}, "auth_events"); !s.allowAuthEventsDelete {
		t.Fatal("auth_events purge must opt in to the append-only trigger bypass")
	}
	if s := findRetentionStep(t, &config.Config{RetentionMCPConnectionDays: 90}, "mcp_connections"); !s.needsWindow || s.days != 90 {
		t.Fatalf("mcp_connections step misconfigured: %+v", s)
	}
}

func findRetentionStep(t *testing.T, cfg *config.Config, name string) retentionStep {
	t.Helper()
	for _, s := range retentionSteps(cfg) {
		if s.name == name {
			return s
		}
	}
	t.Fatalf("%s step missing", name)
	return retentionStep{}
}
