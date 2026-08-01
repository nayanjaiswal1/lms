package labs

import (
	"container/heap"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
	"sort"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// ─── Warm pool planner ───────────────────────────────────────────────────────
//
// Demand-driven sizing of the pre-warmed sandbox pool, one pool per IMAGE.
// Every tick (cron, 1 min) the planner:
//
//  1. retires stale rows (image left the catalog, ended sessions, stuck warming)
//  2. gathers live demand signals in a handful of aggregate queries
//  3. computes a per-image target from Little's Law against the image's own
//     MEASURED warm-start latency
//  4. applies the global container cap
//  5. records every decision — target, previous target, the exact input
//     snapshot, and a human-readable reason — in lab_warm_pool_decisions,
//     so /admin/labs/warm-pools can show what was decided, based on what,
//     at what time
//  6. converges reality: starts missing containers (bounded per tick),
//     trims excess ready ones
//
// Scale-up is deliberately slower than scale-down: an idle warm container
// costs RAM every minute, while a cold start costs one student one warmup
// window, once.

const (
	// warmPoolActiveWindow defines "someone is on the platform right now".
	warmPoolActiveWindow = 15 * time.Minute
	// warmPoolStartsWindow is the recent-demand lookback, and the denominator
	// of the measured arrival rate.
	warmPoolStartsWindow = 60 * time.Minute
	// warmPoolScheduleHorizon is how far ahead batch/module schedules count.
	warmPoolScheduleHorizon = 60 * time.Minute
	// warmPoolStuckAfter retires warming rows that never became ready.
	warmPoolStuckAfter = 10 * time.Minute
	// warmPoolHeartbeat forces a decision row even when the target is
	// unchanged, so the admin page always shows a recent "why" for any image
	// with active or wanted pool state. An image that is stably idle (target 0,
	// previous target 0 — nothing warm, nothing wanted) skips even this
	// heartbeat: see recordDecision's idle-skip.
	warmPoolHeartbeat = 15 * time.Minute
	// warmPoolDecisionRetention bounds the audit log.
	warmPoolDecisionRetention = 14 * 24 * time.Hour
)

// startBudget bounds how many warm containers a single reconciler run may
// provision, so a fleet-wide deficit ramps up gradually instead of
// saturating the host in one tick. Proportional to the global cap rather
// than a flat constant: a small deployment (globalMax=20) still gets the
// same 3/tick as before, but a large one (globalMax=500) gets ~50/tick
// instead of the same 3 — convergence time no longer scales linearly with
// catalog size. Floor of 3 keeps a tiny/unset deployment from being left
// with 0 budget.
func startBudget(globalMax int) int {
	b := globalMax / 10
	if b < 3 {
		return 3
	}
	return b
}

// WarmPoolOverride is an operator's manual override for one image's pool,
// parsed from LABS_WARM_POOL_OVERRIDES. Absent = mode "auto" with the default
// ceiling, which is the intended steady state — the overrides exist for
// incidents ("stop warming this image now") and for load tests, not for
// routine tuning, because the auto policy sizes from measured demand and
// measured warmup and has nothing a human would hand-tune better.
type WarmPoolOverride struct {
	// Mode is WarmPoolModeAuto, WarmPoolModeFixed, or WarmPoolModeOff.
	Mode string
	// Size is the pinned pool size when Mode is "fixed"; it is also the
	// ceiling for "auto" when non-zero, replacing WarmPoolDefaultMaxSize.
	Size int
}

// WarmPoolPlanner owns the reconcile tick. Constructed once in main.go and
// shared by the cron job handler.
type WarmPoolPlanner struct {
	repo      *Repo
	runtime   ContainerRuntime
	globalMax int
	overrides map[string]WarmPoolOverride
}

// NewWarmPoolPlanner returns a planner. globalMax caps total warm containers
// across all images (LABS_WARM_POOL_GLOBAL_MAX); overrides is the parsed
// LABS_WARM_POOL_OVERRIDES map (may be nil).
func NewWarmPoolPlanner(pool *pgxpool.Pool, runtime ContainerRuntime, globalMax int, overrides map[string]WarmPoolOverride) *WarmPoolPlanner {
	if overrides == nil {
		overrides = map[string]WarmPoolOverride{}
	}
	return &WarmPoolPlanner{repo: NewRepo(pool), runtime: runtime, globalMax: globalMax, overrides: overrides}
}

// warmPoolInputs is the exact signal snapshot a decision was computed from;
// persisted as lab_warm_pool_decisions.inputs.
type warmPoolInputs struct {
	PlatformActive15m  int     `json:"platform_active_15m"`
	EnrolledActive     int     `json:"enrolled_active"`
	RecentStarts60m    int     `json:"recent_starts_60m"`
	HistExpectedStarts float64 `json:"hist_expected_starts"`
	ScheduledStarts60m int     `json:"scheduled_starts_60m"`
	WarmupSeconds      float64 `json:"warmup_seconds"`
	WarmupSamples      int64   `json:"warmup_samples"`
	Ready              int     `json:"ready"`
	Warming            int     `json:"warming"`
	MaxSize            int     `json:"max_size"`
	GlobalCap          int     `json:"global_cap"`
	Mode               string  `json:"mode"`
}

type warmPoolPlan struct {
	img    WarmPoolImage
	inputs warmPoolInputs
	target int
	reason string
}

// Tick runs one reconcile pass. Errors on individual images are logged and
// skipped so one bad image cannot stall the whole pool.
func (p *WarmPoolPlanner) Tick(ctx context.Context) error {
	if err := p.retireStale(ctx); err != nil {
		slog.Error("labs.WarmPoolPlanner: retire stale", "error", err)
	}
	if err := p.repo.PruneWarmPoolDecisions(ctx, warmPoolDecisionRetention); err != nil {
		slog.Error("labs.WarmPoolPlanner: prune decisions", "error", err)
	}

	allImages, err := p.repo.ListWarmPoolImages(ctx)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	// Any image whose ImageProfile.SkipPreWarm is true is never pre-warmed —
	// e.g. today's nested-Docker (Docker-in-Docker) labs: an idle elevated
	// container sitting unclaimed is pure risk with no student waiting on it.
	// These sessions always cold-start via Service.StartSession instead.
	images := make([]WarmPoolImage, 0, len(allImages))
	for _, img := range allImages {
		if p.runtime.Classify(img.Image).SkipPreWarm {
			continue
		}
		images = append(images, img)
	}
	if len(images) == 0 {
		return nil
	}

	platformActive, err := p.repo.CountPlatformActiveUsers(ctx, warmPoolActiveWindow)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	starts, err := p.repo.CountRecentStartsByImage(ctx, warmPoolStartsWindow)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	enrolled, err := p.repo.CountEnrolledActiveByImage(ctx, warmPoolActiveWindow)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	hist, err := p.repo.HistExpectedStartsByImage(ctx)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	scheduled, err := p.repo.CountScheduledStartsByImage(ctx, warmPoolScheduleHorizon)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	lastDecisions, err := p.repo.LatestWarmPoolDecisions(ctx)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}

	plans := make([]warmPoolPlan, 0, len(images))
	for _, img := range images {
		override := p.overrides[img.Image]
		in := warmPoolInputs{
			PlatformActive15m:  platformActive,
			EnrolledActive:     enrolled[img.Image],
			RecentStarts60m:    starts[img.Image],
			HistExpectedStarts: hist[img.Image],
			ScheduledStarts60m: scheduled[img.Image],
			WarmupSeconds:      effectiveWarmupSeconds(img),
			WarmupSamples:      img.WarmupSamples,
			Ready:              img.Ready,
			Warming:            img.Warming,
			MaxSize:            effectiveMaxSize(override),
			GlobalCap:          p.globalMax,
			Mode:               effectiveMode(override),
		}
		target, reason := computeWarmTarget(override, in)
		plans = append(plans, warmPoolPlan{img: img, inputs: in, target: target, reason: reason})
	}

	applyGlobalCap(plans, p.globalMax)

	for i := range plans {
		p.recordDecision(ctx, &plans[i], lastDecisions)
	}

	p.converge(ctx, plans)
	return nil
}

// effectiveWarmupSeconds is the image's measured warm-start latency, falling
// back to WarmPoolDefaultWarmupSeconds until the pool has actually started one.
// The fallback is deliberately on the high side: over-estimating warmup warms
// one container too many, under-estimating hands a student the cold start the
// pool exists to prevent.
func effectiveWarmupSeconds(img WarmPoolImage) float64 {
	if img.WarmupSamples == 0 || img.WarmupSeconds <= 0 {
		return WarmPoolDefaultWarmupSeconds
	}
	return img.WarmupSeconds
}

func effectiveMode(o WarmPoolOverride) string {
	if o.Mode == "" {
		return WarmPoolModeAuto
	}
	return o.Mode
}

func effectiveMaxSize(o WarmPoolOverride) int {
	if o.Size > 0 {
		return o.Size
	}
	return WarmPoolDefaultMaxSize
}

// computeWarmTarget is the sizing policy: Little's Law against the image's own
// measured warm-start latency.
//
//	N = λ × W × safety
//	λ = arrivals per second (measured, or predicted from the same hour last month)
//	W = seconds this image takes to become ready (measured)
//
// λ×W is the expected number of students who will ask for this image during one
// warmup window — precisely the number of containers that need to already exist
// for nobody to wait. The safety factor covers arrival burstiness (real traffic
// is not Poisson-smooth; a class of students clicks together).
//
// The predecessor policy was `ceil(starts_60m / 2)` with no W term at all,
// which sized a 2-second image and a 30-second image identically. That is
// backwards twice over: it over-warmed cheap images (holding RAM to save
// nobody anything) and under-warmed expensive ones (the only case where a warm
// pool pays for itself). WarmPoolMinExpectedArrivals is the other half of that
// fix — below it, warming is not worth the RAM, and the pool correctly holds
// nothing at all for a fast image with light traffic.
//
// Every branch states its reasoning — this string is what admins see, verbatim.
func computeWarmTarget(override WarmPoolOverride, in warmPoolInputs) (int, string) {
	clamp := func(v int) int {
		if v < 0 {
			return 0
		}
		if v > in.MaxSize {
			return in.MaxSize
		}
		return v
	}

	switch effectiveMode(override) {
	case WarmPoolModeOff:
		return 0, "mode=off: pre-warming disabled by operator (LABS_WARM_POOL_OVERRIDES)"
	case WarmPoolModeFixed:
		t := clamp(override.Size)
		return t, fmt.Sprintf("mode=fixed: operator pinned pool at %d (LABS_WARM_POOL_OVERRIDES)", t)
	}

	// mode=auto
	if in.PlatformActive15m == 0 {
		return 0, "auto: 0 users active on the platform in the last 15m → scale to zero"
	}

	// Arrival rate per second. History is a prediction of the hour ahead, so it
	// competes with (rather than adds to) the measured trailing hour.
	lambdaNow := float64(in.RecentStarts60m) / warmPoolStartsWindow.Seconds()
	lambdaHist := in.HistExpectedStarts / warmPoolStartsWindow.Seconds()
	lambda, source := lambdaNow, fmt.Sprintf("%d starts in last 60m", in.RecentStarts60m)
	if lambdaHist > lambda {
		lambda, source = lambdaHist, fmt.Sprintf("history predicts ~%.1f starts this hour (4-week same-hour avg)", in.HistExpectedStarts)
	}

	expected := lambda * in.WarmupSeconds * WarmPoolSafetyFactor
	target := 0
	dominant := ""
	if expected >= WarmPoolMinExpectedArrivals {
		target = int(math.Ceil(expected))
		dominant = fmt.Sprintf("%s; warm start measured at %.0fs → λ×W×%.0f = %.2f → %d",
			source, in.WarmupSeconds, WarmPoolSafetyFactor, expected, target)
	}

	// A scheduled cohort is a known, dated spike rather than a rate — it sets a
	// floor directly, without going through the arrival-rate model.
	if fromSched := min(in.ScheduledStarts60m, in.MaxSize); fromSched > target {
		target = fromSched
		// Report the real cohort size, not the clamped one — an operator
		// reading "40 students due, pool 5" knows to raise the ceiling.
		dominant = fmt.Sprintf("schedule: %d students due within 60m", in.ScheduledStarts60m)
	}

	if target == 0 {
		return 0, fmt.Sprintf(
			"auto: demand below the warming threshold (%s, warm start %.0fs → expected %.2f arrivals per warmup window, need %.2f) → scale to zero",
			source, in.WarmupSeconds, expected, WarmPoolMinExpectedArrivals)
	}

	// History alone (nobody enrolled-active, nothing scheduled, no recent
	// starts) warms at most one sandbox — a cheap hedge, not a fleet.
	if in.RecentStarts60m == 0 && in.ScheduledStarts60m == 0 && in.EnrolledActive == 0 && target > 1 {
		return 1, fmt.Sprintf("auto: only history predicts demand (~%.1f starts) but no enrolled user is active → hedge with 1", in.HistExpectedStarts)
	}

	t := clamp(target)
	reason := fmt.Sprintf("auto: %s; %d enrolled users active, %d on platform", dominant, in.EnrolledActive, in.PlatformActive15m)
	if t < target {
		reason += fmt.Sprintf(" (capped at max_size %d)", in.MaxSize)
	}
	return t, reason
}

// warmPoolCapHeap is a max-heap (by current target) of indices into a shared
// plans slice — lets applyGlobalCap always trim the single largest pool
// without rescanning the whole list on every decrement.
type warmPoolCapHeap struct {
	idx   []int
	plans []warmPoolPlan
}

func (h warmPoolCapHeap) Len() int { return len(h.idx) }
func (h warmPoolCapHeap) Less(a, b int) bool {
	return h.plans[h.idx[a]].target > h.plans[h.idx[b]].target // max-heap: largest target first
}
func (h warmPoolCapHeap) Swap(a, b int) { h.idx[a], h.idx[b] = h.idx[b], h.idx[a] }
func (h *warmPoolCapHeap) Push(x any)   { h.idx = append(h.idx, x.(int)) }
func (h *warmPoolCapHeap) Pop() any {
	old := h.idx
	n := len(old)
	v := old[n-1]
	h.idx = old[:n-1]
	return v
}

// applyGlobalCap trims targets so their sum never exceeds the global
// container budget. Largest pools shrink first (they hurt least per unit),
// and every trimmed plan's reason records the cap. Uses a max-heap so each
// of the (sum - globalMax) single-container trims is an O(log images) pop +
// push instead of an O(images) rescan of the whole plan list.
func applyGlobalCap(plans []warmPoolPlan, globalMax int) {
	sum := 0
	for _, pl := range plans {
		sum += pl.target
	}
	if globalMax <= 0 || sum <= globalMax {
		return
	}

	h := &warmPoolCapHeap{plans: plans}
	for i := range plans {
		if plans[i].target > 0 {
			h.idx = append(h.idx, i)
		}
	}
	heap.Init(h)

	for sum > globalMax && h.Len() > 0 {
		i := heap.Pop(h).(int)
		plans[i].target--
		plans[i].reason += fmt.Sprintf(" (−1 by global cap %d)", globalMax)
		sum--
		if plans[i].target > 0 {
			heap.Push(h, i)
		}
	}
}

// skipDecisionWrite reports whether recordDecision should skip writing an
// audit row: either the target is unchanged and still within the heartbeat
// window, or the image is in a stable idle state (target 0, previous target
// 0 — nothing warm, nothing wanted, nothing changed) regardless of how long
// it has been since the last row.
func skipDecisionWrite(target, prevTarget int, hasPrev bool, prevDecidedAt time.Time) bool {
	if hasPrev && prevTarget == target && time.Since(prevDecidedAt) < warmPoolHeartbeat {
		return true
	}
	return target == 0 && prevTarget == 0
}

func (p *WarmPoolPlanner) recordDecision(ctx context.Context, pl *warmPoolPlan, last map[string]WarmPoolDecision) {
	prev, hasPrev := last[pl.img.Image]
	prevTarget := 0
	if hasPrev {
		prevTarget = prev.Target
	}
	if skipDecisionWrite(pl.target, prevTarget, hasPrev, prev.DecidedAt) {
		return
	}
	inputsJSON, err := json.Marshal(pl.inputs)
	if err != nil {
		slog.Error("labs.WarmPoolPlanner: marshal inputs", "image", pl.img.Image, "error", err)
		return
	}
	if err := p.repo.InsertWarmPoolDecision(ctx, WarmPoolDecision{
		Image:          pl.img.Image,
		Mode:           pl.inputs.Mode,
		Target:         pl.target,
		PreviousTarget: prevTarget,
		Inputs:         inputsJSON,
		Reason:         pl.reason,
	}); err != nil {
		slog.Error("labs.WarmPoolPlanner: record decision", "image", pl.img.Image, "error", err)
	}
}

// scaleUpOrder returns the indices of plans that still need scale-up (have <
// target), sorted by demand deficit (target - have) descending — largest
// gap first — so converge's shared per-tick budget goes to the images with
// the strongest demand signal instead of whichever image happens to come
// first in plans' arbitrary DB order.
func scaleUpOrder(plans []warmPoolPlan) []int {
	deficit := func(i int) int {
		return plans[i].target - (plans[i].img.Ready + plans[i].img.Warming)
	}
	idx := make([]int, 0, len(plans))
	for i := range plans {
		if deficit(i) > 0 {
			idx = append(idx, i)
		}
	}
	sort.SliceStable(idx, func(a, b int) bool { return deficit(idx[a]) > deficit(idx[b]) })
	return idx
}

// converge starts missing containers (bounded per tick) and trims excess.
// Scale-down runs first for every image unconditionally (no budget contention,
// order doesn't matter); scale-up then spends the shared per-tick budget on
// images in descending order of demand deficit (target - have).
func (p *WarmPoolPlanner) converge(ctx context.Context, plans []warmPoolPlan) {
	budget := startBudget(p.globalMax)
	var wg sync.WaitGroup

	for i := range plans {
		pl := &plans[i]
		if pl.img.Ready <= pl.target {
			continue
		}
		excess, err := p.repo.ListExcessReadyWarmContainers(ctx, pl.img.Image, pl.img.Ready-pl.target)
		if err != nil {
			slog.Error("labs.WarmPoolPlanner: list excess", "image", pl.img.Image, "error", err)
			continue
		}
		for _, e := range excess {
			// Atomic delete-if-still-ready: a container listed here a moment
			// ago may have been claimed by a student's StartSession in the
			// meantime. deleted=false means exactly that happened — the
			// container now belongs to a live session and must not be
			// killed (see DeleteReadyWarmContainer's own doc comment).
			containerID, deleted, err := p.repo.DeleteReadyWarmContainer(ctx, e.ID)
			if err != nil {
				slog.Error("labs.WarmPoolPlanner: delete excess row", "warm_id", e.ID, "error", err)
				continue
			}
			if !deleted {
				continue
			}
			if containerID != nil {
				if err := p.runtime.Kill(ctx, *containerID); err != nil {
					slog.Error("labs.WarmPoolPlanner: kill excess", "container", *containerID, "error", err)
				}
			}
		}
	}

	for _, i := range scaleUpOrder(plans) {
		pl := &plans[i]
		have := pl.img.Ready + pl.img.Warming
		for have < pl.target && budget > 0 {
			have++
			budget--
			warmID, err := p.repo.InsertWarmContainer(ctx, pl.img.Image)
			if err != nil {
				slog.Error("labs.WarmPoolPlanner: insert warming row", "image", pl.img.Image, "error", err)
				continue
			}
			wg.Add(1)
			go func(warmID, image string) {
				defer wg.Done()
				p.startWarmContainer(warmID, image)
			}(warmID, pl.img.Image)
		}
	}
	wg.Wait()
}

// startWarmContainer provisions one pool sandbox end to end: start it, wait for
// the image's own readiness probe, record how long that took, and publish the
// row as claimable. On any failure the row is removed so the next tick retries
// from a clean state.
//
// It runs on context.Background() with its own ProvisionTimeoutSeconds budget
// rather than the tick's ctx: a container slow to boot can legitimately take
// the same budget an ordinary cold-started session gets, while the reconciler
// job's scheduler-level timeout defends against a different failure mode (the
// job hanging) and is set well below it. Inheriting the tick's deadline would
// abort every warm start for any image slow enough to need the full cold-start
// budget — exactly the images a warm pool exists for.
func (p *WarmPoolPlanner) startWarmContainer(warmID, image string) {
	ctx, cancel := context.WithTimeout(context.Background(), ProvisionTimeoutSeconds*time.Second)
	defer cancel()

	drop := func() {
		if err := p.repo.DeleteWarmContainer(context.Background(), warmID); err != nil {
			slog.Error("labs.WarmPoolPlanner: delete failed warming row", "warm_id", warmID, "error", err)
		}
	}

	started := time.Now()
	cid, host, err := p.runtime.StartWarm(ctx, warmID, image)
	if err != nil {
		slog.Error("labs.WarmPoolPlanner: start warm", "image", image, "warm_id", warmID, "error", err)
		drop()
		return
	}

	if _, err := WaitContainerReady(ctx, p.runtime, cid); err != nil {
		slog.Error("labs.WarmPoolPlanner: warm container never became ready", "image", image, "warm_id", warmID, "error", err)
		_ = p.runtime.Kill(context.Background(), cid)
		drop()
		return
	}

	// Measure the whole start-to-ready span, not just the probe wait — that is
	// what a student cold-starting this image actually pays, and therefore the
	// W that belongs in Little's Law.
	if err := p.repo.RecordWarmupSample(context.Background(), image, time.Since(started).Seconds()); err != nil {
		slog.Error("labs.WarmPoolPlanner: record warmup sample", "image", image, "error", err)
	}

	if err := p.repo.MarkWarmContainerReady(context.Background(), warmID, cid, host); err != nil {
		slog.Error("labs.WarmPoolPlanner: mark ready", "warm_id", warmID, "error", err)
		_ = p.runtime.Kill(context.Background(), cid)
		drop()
	}
}

// retireStale kills/deletes rows that no longer serve any purpose.
func (p *WarmPoolPlanner) retireStale(ctx context.Context) error {
	stale, err := p.repo.ListStaleWarmContainers(ctx, warmPoolStuckAfter)
	if err != nil {
		return err
	}
	for _, s := range stale {
		if s.Kill && s.ContainerID != nil {
			if err := p.runtime.Kill(ctx, *s.ContainerID); err != nil {
				slog.Error("labs.WarmPoolPlanner: kill stale", "container", *s.ContainerID, "error", err)
			}
		}
		if err := p.repo.DeleteWarmContainer(ctx, s.ID); err != nil {
			slog.Error("labs.WarmPoolPlanner: delete stale row", "warm_id", s.ID, "error", err)
		}
	}
	return nil
}
