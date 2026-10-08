package handlers

import (
	"testing"

	"github.com/mindforge/backend/internal/config"
)

func TestRetentionSteps(t *testing.T) {
	cfg := &config.Config{RetentionAuditDays: 30, RetentionAuthEventsDays: 0, RetentionXPEventsDays: 10}
	got := map[string]bool{}
	for _, s := range retentionSteps(cfg) {
		got[s.name] = true
	}
	for _, want := range []string{"audit_logs", "xp_events", "mcp_tokens"} {
		if !got[want] {
			t.Errorf("expected step %q enabled", want)
		}
	}
	for _, off := range []string{"auth_events", "attempt_events", "lab_ai_interactions", "mcp_action_log", "mcp_connections", "public_test_candidates"} {
		if got[off] {
			t.Errorf("step %q should be disabled with a zero window", off)
		}
	}
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
