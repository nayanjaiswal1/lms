package labs

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ─── startBudget ──────────────────────────────────────────────────────────

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

// ─── computeWarmTarget: Little's Law sizing ───────────────────────────────

// autoInputs builds the mode=auto signal snapshot for a lab image seeing
// startsPerHour real starts and taking warmupSeconds to become ready.
func autoInputs(startsPerHour int, warmupSeconds float64) warmPoolInputs {
	return warmPoolInputs{
		PlatformActive15m: 25,
		EnrolledActive:    10,
		RecentStarts60m:   startsPerHour,
		WarmupSeconds:     warmupSeconds,
		WarmupSamples:     50,
		MaxSize:           WarmPoolDefaultMaxSize,
		Mode:              WarmPoolModeAuto,
	}
}

// The property the whole re-architecture turns on: at IDENTICAL traffic, an
// image that is expensive to boot gets warmed and a cheap one does not. The
// predecessor formula (ceil(starts/2), no warmup term) returned the same
// number for both, which over-warmed cheap images and under-warmed the only
// kind that pays for a pool.
func TestComputeWarmTarget_WarmupCostDecidesAtEqualTraffic(t *testing.T) {
	slow, slowReason := computeWarmTarget(WarmPoolOverride{}, autoInputs(10, 30))
	fast, fastReason := computeWarmTarget(WarmPoolOverride{}, autoInputs(10, 2))

	assert.Equal(t, 1, slow, "30s boot at 10 starts/h: 0.167 expected arrivals per warmup window → warm one")
	assert.Equal(t, 0, fast, "2s boot at the same traffic: 0.011 expected arrivals → not worth the RAM")
	assert.Contains(t, slowReason, "30s")
	assert.Contains(t, fastReason, "below the warming threshold")
}

func TestComputeWarmTarget_ScalesWithArrivalRate(t *testing.T) {
	// λ=500/3600, W=2s, safety 2 → 0.56 → 1. A cheap image DOES pool once
	// traffic is high enough; the threshold is about expected arrivals, not a
	// blanket "fast images never warm" rule.
	assert.Equal(t, 1, mustTarget(t, autoInputs(500, 2)))

	// Same traffic, W=30s → 8.33 → 9, clamped by MaxSize.
	assert.Equal(t, WarmPoolDefaultMaxSize, mustTarget(t, autoInputs(500, 30)))
}

func TestComputeWarmTarget_ScheduledCohortSetsFloor(t *testing.T) {
	// A dated spike bypasses the arrival-rate model entirely: 40 students due
	// within the hour on an image with zero recent traffic still warms up to
	// the ceiling.
	in := autoInputs(0, 30)
	in.ScheduledStarts60m = 40
	target, reason := computeWarmTarget(WarmPoolOverride{}, in)
	assert.Equal(t, WarmPoolDefaultMaxSize, target)
	assert.Contains(t, reason, "40 students due within 60m")
}

func TestComputeWarmTarget_ZeroWhenPlatformIdle(t *testing.T) {
	in := autoInputs(100, 30)
	in.PlatformActive15m = 0
	target, reason := computeWarmTarget(WarmPoolOverride{}, in)
	assert.Equal(t, 0, target, "nobody on the platform → hold nothing, whatever history says")
	assert.Contains(t, reason, "scale to zero")
}

func TestComputeWarmTarget_HistoryAloneHedgesWithOne(t *testing.T) {
	// History predicts real demand but no enrolled user is active and nothing
	// is scheduled — warm exactly one as a cheap hedge, never a fleet.
	in := autoInputs(0, 30)
	in.EnrolledActive = 0
	in.HistExpectedStarts = 100
	target, reason := computeWarmTarget(WarmPoolOverride{}, in)
	assert.Equal(t, 1, target)
	assert.Contains(t, reason, "hedge with 1")
}

func TestComputeWarmTarget_OperatorOverrides(t *testing.T) {
	in := autoInputs(500, 30)

	off, offReason := computeWarmTarget(WarmPoolOverride{Mode: WarmPoolModeOff}, in)
	assert.Equal(t, 0, off, "mode=off wins over any demand signal")
	assert.Contains(t, offReason, "LABS_WARM_POOL_OVERRIDES")

	fixed, fixedReason := computeWarmTarget(WarmPoolOverride{Mode: WarmPoolModeFixed, Size: 3}, in)
	assert.Equal(t, 3, fixed)
	assert.Contains(t, fixedReason, "pinned pool at 3")
}

func TestComputeWarmTarget_FixedIsClampedToMaxSize(t *testing.T) {
	in := autoInputs(10, 30)
	in.MaxSize = 2
	target, _ := computeWarmTarget(WarmPoolOverride{Mode: WarmPoolModeFixed, Size: 9}, in)
	assert.Equal(t, 2, target)
}

func mustTarget(t *testing.T, in warmPoolInputs) int {
	t.Helper()
	target, _ := computeWarmTarget(WarmPoolOverride{}, in)
	return target
}

// ─── effectiveWarmupSeconds ────────────────────────────────────────────────

func TestEffectiveWarmupSeconds_FallsBackUntilMeasured(t *testing.T) {
	assert.Equal(t, WarmPoolDefaultWarmupSeconds,
		effectiveWarmupSeconds(WarmPoolImage{WarmupSamples: 0, WarmupSeconds: 0}),
		"never measured → pessimistic default")
	assert.Equal(t, WarmPoolDefaultWarmupSeconds,
		effectiveWarmupSeconds(WarmPoolImage{WarmupSamples: 5, WarmupSeconds: 0}),
		"samples but a nonsense zero average → default, not a 0s warmup that zeroes every target")
	assert.Equal(t, 42.0,
		effectiveWarmupSeconds(WarmPoolImage{WarmupSamples: 5, WarmupSeconds: 42}))
}

// ─── ParseWarmPoolOverrides ───────────────────────────────────────────────

func TestParseWarmPoolOverrides(t *testing.T) {
	got, err := ParseWarmPoolOverrides(
		"mindforge/lab-k8s:1.31=fixed:2, mindforge/lab-docker:27=off ,mindforge/lab-node-web:22=auto:3")
	require.NoError(t, err)
	assert.Equal(t, map[string]WarmPoolOverride{
		// Split on "=" not the last colon — the image's own tag is a colon.
		"mindforge/lab-k8s:1.31":    {Mode: WarmPoolModeFixed, Size: 2},
		"mindforge/lab-docker:27":   {Mode: WarmPoolModeOff},
		"mindforge/lab-node-web:22": {Mode: WarmPoolModeAuto, Size: 3},
	}, got)
}

func TestParseWarmPoolOverrides_EmptyIsNoOverrides(t *testing.T) {
	got, err := ParseWarmPoolOverrides("   ")
	require.NoError(t, err)
	assert.Nil(t, got)
}

func TestParseWarmPoolOverrides_RejectsMalformed(t *testing.T) {
	cases := map[string]string{
		"no separator":       "mindforge/lab-k8s:1.31",
		"empty spec":         "mindforge/lab-k8s:1.31=",
		"unknown mode":       "mindforge/lab-k8s:1.31=warm",
		"fixed without size": "mindforge/lab-k8s:1.31=fixed",
		"non-numeric size":   "mindforge/lab-k8s:1.31=fixed:many",
		"size above ceiling": "mindforge/lab-k8s:1.31=fixed:999",
		"negative size":      "mindforge/lab-k8s:1.31=fixed:-1",
	}
	for name, raw := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := ParseWarmPoolOverrides(raw)
			assert.Error(t, err, "a typo must fail startup, never silently leave an image warming")
		})
	}
}

// ─── applyGlobalCap (heap-based trim) ─────────────────────────────────────

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

// ─── scaleUpOrder ──────────────────────────────────────────────────────────

func TestScaleUpOrder_SortsByDeficitDescending(t *testing.T) {
	// image A: target 5, have 0 -> deficit 5 (largest gap, should go first)
	// image B: target 6, have 5 -> deficit 1
	// image C: target 2, have 2 -> deficit 0, excluded entirely
	plans := []warmPoolPlan{
		{img: WarmPoolImage{Image: "B", Ready: 3, Warming: 2}, target: 6},
		{img: WarmPoolImage{Image: "C", Ready: 2, Warming: 0}, target: 2},
		{img: WarmPoolImage{Image: "A", Ready: 0, Warming: 0}, target: 5},
	}
	order := scaleUpOrder(plans)
	require.Len(t, order, 2, "image C has no deficit and must be excluded")
	assert.Equal(t, "A", plans[order[0]].img.Image, "largest deficit (5) claims the budget first")
	assert.Equal(t, "B", plans[order[1]].img.Image)
}

func TestScaleUpOrder_EmptyWhenNoDeficit(t *testing.T) {
	plans := []warmPoolPlan{
		{img: WarmPoolImage{Ready: 2}, target: 2},
		{img: WarmPoolImage{Ready: 5}, target: 3},
	}
	assert.Empty(t, scaleUpOrder(plans))
}

// ─── skipDecisionWrite ──────────────────────────────────────────────────────

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

// ─── Readiness probe ───────────────────────────────────────────────────────

// fakeRuntime is a ContainerRuntime whose readiness probe fails for the first
// probeFailures calls, and whose liveness is controllable.
type fakeRuntime struct {
	probeFailures int
	probeCalls    int
	running       bool
}

func (f *fakeRuntime) Exec(_ context.Context, _, _ string, _ int) (string, string, int, error) {
	f.probeCalls++
	if f.probeCalls <= f.probeFailures {
		return "", "not ready", 1, nil
	}
	return "", "", 0, nil
}
func (f *fakeRuntime) IsRunning(_ context.Context, _ string) bool { return f.running }

func (f *fakeRuntime) Start(context.Context, string, int, string) (string, string, error) {
	return "", "", nil
}
func (f *fakeRuntime) StartWarm(context.Context, string, string) (string, string, error) {
	return "", "", nil
}
func (f *fakeRuntime) Kill(context.Context, string) error    { return nil }
func (f *fakeRuntime) Pause(context.Context, string) error   { return nil }
func (f *fakeRuntime) Unpause(context.Context, string) error { return nil }
func (f *fakeRuntime) ExecStdin(context.Context, string, string, []byte, int) (string, string, int, error) {
	return "", "", 0, nil
}
func (f *fakeRuntime) ExecSetup(context.Context, string, string, int) (string, string, int, error) {
	return "", "", 0, nil
}
func (f *fakeRuntime) List(context.Context, string) ([]ContainerInfo, error) { return nil, nil }
func (f *fakeRuntime) Classify(string) ImageProfile                          { return ImageProfile{} }

func TestProbeContainerReady(t *testing.T) {
	ready := &fakeRuntime{running: true}
	assert.True(t, ProbeContainerReady(context.Background(), ready, "c1"))

	notReady := &fakeRuntime{running: true, probeFailures: 1}
	assert.False(t, notReady.probeCalls > 0)
	assert.False(t, ProbeContainerReady(context.Background(), notReady, "c1"),
		"a single failed probe is a definitive not-ready — the warm-claim path must not retry")
	assert.Equal(t, 1, notReady.probeCalls, "single-shot: exactly one probe, never a loop")
}

func TestWaitContainerReady_ReturnsOnceReady(t *testing.T) {
	rt := &fakeRuntime{running: true}
	elapsed, err := WaitContainerReady(context.Background(), rt, "c1")
	require.NoError(t, err)
	assert.Less(t, elapsed, ReadinessPollInterval, "an already-ready sandbox must not sleep a poll interval first")
}

func TestWaitContainerReady_ShortCircuitsOnDeadSandbox(t *testing.T) {
	// The sandbox's entrypoint exited (lab-k8s bails when kube-apiserver never
	// came up). Without the liveness check this would poll until the caller's
	// entire provisioning budget drained, turning a 5s failure into a 3m one.
	rt := &fakeRuntime{running: false, probeFailures: 100}
	_, err := WaitContainerReady(context.Background(), rt, "c1")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "exited before becoming ready")
	assert.Equal(t, 1, rt.probeCalls, "gives up on the first probe once the sandbox is known dead")
}
