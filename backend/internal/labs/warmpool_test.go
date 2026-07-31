package labs

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ─── B2: startBudget ──────────────────────────────────────────────────────

func TestStartBudget(t *testing.T) {
	cases := []struct {
		globalMax int
		want      int
	}{
		{globalMax: 0, want: 3},    // unset/disabled — floor still applies
		{globalMax: 20, want: 3},   // small deployment — same as the old flat constant
		{globalMax: 29, want: 3},   // still below the floor after the ratio
		{globalMax: 500, want: 50}, // large deployment — ratio, not the old flat 3
	}
	for _, c := range cases {
		assert.Equalf(t, c.want, startBudget(c.globalMax), "globalMax=%d", c.globalMax)
	}
}

// ─── B4: applyGlobalCap (heap-based trim) ─────────────────────────────────

func TestApplyGlobalCap_NoOpBelowCap(t *testing.T) {
	plans := []warmPoolPlan{{target: 2}, {target: 3}}
	applyGlobalCap(plans, 10)
	assert.Equal(t, 2, plans[0].target)
	assert.Equal(t, 3, plans[1].target)
	assert.Empty(t, plans[0].reason)
}

func TestApplyGlobalCap_DisabledCap(t *testing.T) {
	plans := []warmPoolPlan{{target: 100}}
	applyGlobalCap(plans, 0)
	assert.Equal(t, 100, plans[0].target, "globalMax<=0 means uncapped")
}

func TestApplyGlobalCap_TrimsLargestFirstDownToCap(t *testing.T) {
	plans := []warmPoolPlan{{target: 5}, {target: 3}, {target: 3}}
	applyGlobalCap(plans, 8)

	sum := 0
	for _, pl := range plans {
		sum += pl.target
	}
	require.Equal(t, 8, sum, "trims exactly down to the cap")
	assert.LessOrEqual(t, plans[0].target, 5, "the largest pool never grows")
	for _, pl := range plans {
		assert.LessOrEqual(t, pl.target, 5)
	}
}

func TestApplyGlobalCap_ReasonRecordsEachDecrement(t *testing.T) {
	plans := []warmPoolPlan{{target: 5, reason: "auto"}}
	applyGlobalCap(plans, 2)
	assert.Equal(t, 2, plans[0].target)
	assert.Contains(t, plans[0].reason, "(−1 by global cap 2)")
}

// ─── B1: scaleUpOrder ──────────────────────────────────────────────────────

func TestScaleUpOrder_SortsByDeficitDescending(t *testing.T) {
	// lab A: target 5, have 0 -> deficit 5 (largest gap, should go first)
	// lab B: target 6, have 5 -> deficit 1
	// lab C: target 2, have 2 -> deficit 0, excluded entirely
	plans := []warmPoolPlan{
		{lab: WarmPoolLab{LabID: "B", Ready: 3, Warming: 2}, target: 6},
		{lab: WarmPoolLab{LabID: "C", Ready: 2, Warming: 0}, target: 2},
		{lab: WarmPoolLab{LabID: "A", Ready: 0, Warming: 0}, target: 5},
	}
	order := scaleUpOrder(plans)
	require.Len(t, order, 2, "lab C has no deficit and must be excluded")
	assert.Equal(t, "A", plans[order[0]].lab.LabID, "largest deficit (5) claims the budget first")
	assert.Equal(t, "B", plans[order[1]].lab.LabID)
}

func TestScaleUpOrder_EmptyWhenNoDeficit(t *testing.T) {
	plans := []warmPoolPlan{
		{lab: WarmPoolLab{Ready: 2}, target: 2},
		{lab: WarmPoolLab{Ready: 5}, target: 3},
	}
	assert.Empty(t, scaleUpOrder(plans))
}

// ─── B3: skipDecisionWrite ──────────────────────────────────────────────────

func TestSkipDecisionWrite(t *testing.T) {
	now := time.Now()
	cases := []struct {
		name          string
		target        int
		prevTarget    int
		hasPrev       bool
		prevDecidedAt time.Time
		want          bool
	}{
		{"no previous row at all, nonzero target -> write", 3, 0, false, time.Time{}, false},
		{"stable idle: no previous row, target 0 -> skip", 0, 0, false, time.Time{}, true},
		{"unchanged target, recent heartbeat -> skip", 3, 3, true, now, true},
		{"unchanged target, stale heartbeat -> write", 3, 3, true, now.Add(-warmPoolHeartbeat - time.Second), false},
		{"stable idle regardless of heartbeat age -> skip", 0, 0, true, now.Add(-24 * time.Hour), true},
		{"target changed 0 -> nonzero -> write", 2, 0, true, now, false},
		{"target changed nonzero -> 0 -> write", 0, 2, true, now, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			assert.Equal(t, c.want, skipDecisionWrite(c.target, c.prevTarget, c.hasPrev, c.prevDecidedAt))
		})
	}
}
