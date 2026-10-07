package handlers

import (
	"testing"

	"github.com/mindforge/backend/internal/config"
)

func TestRetentionStepsHonoursWindows(t *testing.T) {
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
}

func TestRetentionAuthEventsStepBypassesTrigger(t *testing.T) {
	for _, s := range retentionSteps(&config.Config{RetentionAuthEventsDays: 5}) {
		if s.name == "auth_events" && !s.allowAuthEventsDelete {
			t.Fatal("auth_events purge must opt in to the append-only trigger bypass")
		}
	}
}

func TestRetentionMCPConnectionsStep(t *testing.T) {
	for _, s := range retentionSteps(&config.Config{RetentionMCPConnectionDays: 90}) {
		if s.name == "mcp_connections" {
			if !s.needsWindow || s.days != 90 {
				t.Fatalf("mcp_connections step misconfigured: %+v", s)
			}
			return
		}
	}
	t.Fatal("mcp_connections step missing")
}
