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
// Demand-driven sizing of the pre-warmed sandbox pool. Every tick (cron,
// 1 min) the planner:
//
//  1. retires stale rows (version bumps, ended sessions, stuck warming)
//  2. gathers live demand signals in a handful of aggregate queries
//  3. computes a per-lab target (conservative: 0 whenever nobody is around)
//  4. applies the global container cap
//  5. records every decision — target, previous target, the exact input
//     snapshot, and a human-readable reason — in lab_warm_pool_decisions,
//     so /admin/labs/warm-pools can show what was decided, based on what,
//     at what time
//  6. converges reality: starts missing containers (bounded per tick),
//     trims excess ready ones
//
// Scale-up is deliberately slower than scale-down: an idle warm container
// costs RAM every minute, while a cold start costs one student ~30s once.

const (
	// warmPoolActiveWindow defines "someone is on the platform right now".
	warmPoolActiveWindow = 15 * time.Minute
	// warmPoolStartsWindow is the recent-demand lookback.
	warmPoolStartsWindow = 60 * time.Minute
	// warmPoolScheduleHorizon is how far ahead batch/module schedules count.
	warmPoolScheduleHorizon = 60 * time.Minute
	// warmPoolStuckAfter retires warming rows that never became ready.
	warmPoolStuckAfter = 10 * time.Minute
	// warmPoolHeartbeat forces a decision row even when the target is
	// unchanged, so the admin page always shows a recent "why" for any lab
	// with active or wanted pool state. A lab that is stably idle (target 0,
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

// WarmPoolPlanner owns the reconcile tick. Constructed once in main.go and
// shared by the cron job handler.
type WarmPoolPlanner struct {
	repo      *Repo
	runtime   ContainerRuntime
	globalMax int
}

// NewWarmPoolPlanner returns a planner. globalMax caps total warm containers
// across all labs (LABS_WARM_POOL_GLOBAL_MAX).
func NewWarmPoolPlanner(pool *pgxpool.Pool, runtime ContainerRuntime, globalMax int) *WarmPoolPlanner {
	return &WarmPoolPlanner{repo: NewRepo(pool), runtime: runtime, globalMax: globalMax}
}

// warmPoolInputs is the exact signal snapshot a decision was computed from;
// persisted as lab_warm_pool_decisions.inputs.
type warmPoolInputs struct {
	PlatformActive15m  int     `json:"platform_active_15m"`
	EnrolledActive     int     `json:"enrolled_active"`
	RecentStarts60m    int     `json:"recent_starts_60m"`
	HistExpectedStarts float64 `json:"hist_expected_starts"`
	ScheduledStarts60m int     `json:"scheduled_starts_60m"`
	Ready              int     `json:"ready"`
	Warming            int     `json:"warming"`
	MaxSize            int     `json:"max_size"`
	GlobalCap          int     `json:"global_cap"`
	Mode               string  `json:"mode"`
}

type warmPoolPlan struct {
	lab    WarmPoolLab
	inputs warmPoolInputs
	target int
	reason string
}

// Tick runs one reconcile pass. Errors on individual labs are logged and
// skipped so one bad lab cannot stall the whole pool.
func (p *WarmPoolPlanner) Tick(ctx context.Context) error {
	if err := p.retireStale(ctx); err != nil {
		slog.Error("labs.WarmPoolPlanner: retire stale", "error", err)
	}
	if err := p.repo.PruneWarmPoolDecisions(ctx, warmPoolDecisionRetention); err != nil {
		slog.Error("labs.WarmPoolPlanner: prune decisions", "error", err)
	}

	allPoolLabs, err := p.repo.ListWarmPoolLabs(ctx)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	// Any image whose ImageProfile.SkipPreWarm is true is never pre-warmed —
	// e.g. today's nested-Docker (Docker-in-Docker) labs: an idle elevated
	// container sitting unclaimed is pure risk with no student waiting on
	// it, and its ~30s+ dockerd boot means the pool can't verify "ready" the
	// way it does for an ordinary lab anyway. These sessions always
	// cold-start via Service.StartSession instead.
	poolLabs := make([]WarmPoolLab, 0, len(allPoolLabs))
	for _, lab := range allPoolLabs {
		if p.runtime.Classify(lab.Image).SkipPreWarm {
			continue
		}
		poolLabs = append(poolLabs, lab)
	}
	if len(poolLabs) == 0 {
		return nil
	}

	platformActive, err := p.repo.CountPlatformActiveUsers(ctx, warmPoolActiveWindow)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	starts, err := p.repo.CountRecentStartsByLab(ctx, warmPoolStartsWindow)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	enrolled, err := p.repo.CountEnrolledActiveByLab(ctx, warmPoolActiveWindow)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	hist, err := p.repo.HistExpectedStartsByLab(ctx)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	scheduled, err := p.repo.CountScheduledStartsByLab(ctx, warmPoolScheduleHorizon)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}
	lastDecisions, err := p.repo.LatestWarmPoolDecisions(ctx)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
	}

	plans := make([]warmPoolPlan, 0, len(poolLabs))
	for _, lab := range poolLabs {
		in := warmPoolInputs{
			PlatformActive15m:  platformActive,
			EnrolledActive:     enrolled[lab.LabID],
			RecentStarts60m:    starts[lab.LabID],
			HistExpectedStarts: hist[lab.LabID],
			ScheduledStarts60m: scheduled[lab.LabID],
			Ready:              lab.Ready,
			Warming:            lab.Warming,
			MaxSize:            lab.MaxSize,
			GlobalCap:          p.globalMax,
			Mode:               lab.Mode,
		}
		target, reason := computeWarmTarget(lab, in)
		plans = append(plans, warmPoolPlan{lab: lab, inputs: in, target: target, reason: reason})
	}

	applyGlobalCap(plans, p.globalMax)

	for i := range plans {
		p.recordDecision(ctx, &plans[i], lastDecisions)
	}

	p.converge(ctx, plans)
	return nil
}

// computeWarmTarget is the sizing policy. Conservative by design: any
// "nobody is around" signal zeroes the pool, and history alone never warms
// more than one sandbox. Every branch states its reasoning — this string is
// what admins see, verbatim.
func computeWarmTarget(lab WarmPoolLab, in warmPoolInputs) (int, string) {
	clamp := func(v int) int {
		if v < 0 {
			return 0
		}
		if v > lab.MaxSize {
			return lab.MaxSize
		}
		return v
	}

	switch lab.Mode {
	case "off":
		return 0, "mode=off: pre-warming disabled by operator"
	case "fixed":
		t := clamp(lab.FixedSize)
		return t, fmt.Sprintf("mode=fixed: operator pinned pool at %d (max %d)", t, lab.MaxSize)
	}

	// mode=auto
	if in.PlatformActive15m == 0 {
		return 0, "auto: 0 users active on the platform in the last 15m → scale to zero"
	}

	fromStarts := int(math.Ceil(float64(in.RecentStarts60m) / 2.0))
	fromHist := int(math.Ceil(in.HistExpectedStarts * 0.75))
	fromSched := in.ScheduledStarts60m
	if fromSched > lab.MaxSize {
		fromSched = lab.MaxSize
	}

	target := fromStarts
	dominant := fmt.Sprintf("%d starts in last 60m → ceil(%d/2)=%d", in.RecentStarts60m, in.RecentStarts60m, fromStarts)
	if fromHist > target {
		target = fromHist
		dominant = fmt.Sprintf("history: ~%.1f starts expected this hour (4-week same-hour avg) → ceil(%.1f×0.75)=%d", in.HistExpectedStarts, in.HistExpectedStarts, fromHist)
	}
	if fromSched > target {
		target = fromSched
		dominant = fmt.Sprintf("schedule: %d students due within 60m", fromSched)
	}

	if target == 0 {
		return 0, fmt.Sprintf("auto: no demand (0 recent starts, ~%.1f expected from history, 0 scheduled; %d enrolled users active) → scale to zero", in.HistExpectedStarts, in.EnrolledActive)
	}

	// History alone (nobody enrolled-active, nothing scheduled, no recent
	// starts) warms at most one sandbox — a cheap hedge, not a fleet.
	if in.RecentStarts60m == 0 && in.ScheduledStarts60m == 0 && in.EnrolledActive == 0 && target > 1 {
		return 1, fmt.Sprintf("auto: only history predicts demand (~%.1f starts) but no enrolled user is active → hedge with 1", in.HistExpectedStarts)
	}

	t := clamp(target)
	reason := fmt.Sprintf("auto: %s; %d enrolled users active, %d on platform", dominant, in.EnrolledActive, in.PlatformActive15m)
	if t < target {
		reason += fmt.Sprintf(" (capped at max_size %d)", lab.MaxSize)
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
// of the (sum - globalMax) single-container trims is an O(log labs) pop +
// push instead of an O(labs) rescan of the whole plan list — O(excess log
// labs) overall rather than O(excess × labs).
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

// recordDecision writes an audit row when the target changed, or as a
// heartbeat when the last row is older than warmPoolHeartbeat — except when
// the lab is in a stable idle state (target 0, previous target 0: nothing
// warm, nothing wanted, nothing changed), which skips the write regardless
// of how long it has been since the last row, since there is nothing new
// for an admin to see either way. A lab with a nonzero target still gets
// the heartbeat, and any target change to/from zero is still written
// immediately (it fails the idle check on whichever side is nonzero).
// skipDecisionWrite reports whether recordDecision should skip writing an
// audit row: either the target is unchanged and still within the heartbeat
// window, or the lab is in a stable idle state (target 0, previous target
// 0 — nothing warm, nothing wanted, nothing changed) regardless of how long
// it has been since the last row.
func skipDecisionWrite(target, prevTarget int, hasPrev bool, prevDecidedAt time.Time) bool {
	if hasPrev && prevTarget == target && time.Since(prevDecidedAt) < warmPoolHeartbeat {
		return true
	}
	return target == 0 && prevTarget == 0
}

func (p *WarmPoolPlanner) recordDecision(ctx context.Context, pl *warmPoolPlan, last map[string]WarmPoolDecision) {
	prev, hasPrev := last[pl.lab.LabID]
	prevTarget := 0
	if hasPrev {
		prevTarget = prev.Target
	}
	if skipDecisionWrite(pl.target, prevTarget, hasPrev, prev.DecidedAt) {
		return
	}
	inputsJSON, err := json.Marshal(pl.inputs)
	if err != nil {
		slog.Error("labs.WarmPoolPlanner: marshal inputs", "lab_id", pl.lab.LabID, "error", err)
		return
	}
	if err := p.repo.InsertWarmPoolDecision(ctx, WarmPoolDecision{
		LabID:          pl.lab.LabID,
		Mode:           pl.lab.Mode,
		Target:         pl.target,
		PreviousTarget: prevTarget,
		Inputs:         inputsJSON,
		Reason:         pl.reason,
	}); err != nil {
		slog.Error("labs.WarmPoolPlanner: record decision", "lab_id", pl.lab.LabID, "error", err)
	}
}

// scaleUpOrder returns the indices of plans that still need scale-up (have <
// target), sorted by demand deficit (target - have) descending — largest
// gap first — so converge's shared per-tick budget goes to the labs with
// the strongest demand signal instead of whichever lab happens to come
// first in plans' arbitrary DB order.
func scaleUpOrder(plans []warmPoolPlan) []int {
	deficit := func(i int) int {
		return plans[i].target - (plans[i].lab.Ready + plans[i].lab.Warming)
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
// Scale-down runs first for every lab unconditionally (no budget contention,
// order doesn't matter); scale-up then spends the shared per-tick budget on
// labs in descending order of demand deficit (target - have), so a lab
// early in plans' arbitrary DB order wanting many containers can no longer
// starve every other lab's scale-up in the same tick.
func (p *WarmPoolPlanner) converge(ctx context.Context, plans []warmPoolPlan) {
	budget := startBudget(p.globalMax)
	var wg sync.WaitGroup

	for i := range plans {
		pl := &plans[i]
		if pl.lab.Ready <= pl.target {
			continue
		}
		excess, err := p.repo.ListExcessReadyWarmContainers(ctx, pl.lab.LabID, pl.lab.TaskVersionID, pl.lab.Ready-pl.target)
		if err != nil {
			slog.Error("labs.WarmPoolPlanner: list excess", "lab_id", pl.lab.LabID, "error", err)
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
		have := pl.lab.Ready + pl.lab.Warming
		for have < pl.target && budget > 0 {
			have++
			budget--
			warmID, err := p.repo.InsertWarmContainer(ctx, pl.lab.LabID, pl.lab.TaskVersionID, pl.lab.Image)
			if err != nil {
				slog.Error("labs.WarmPoolPlanner: insert warming row", "lab_id", pl.lab.LabID, "error", err)
				continue
			}
			setup := ""
			if pl.lab.SetupScript != nil {
				setup = *pl.lab.SetupScript
			}
			wg.Add(1)
			go func(warmID, image, setup, labID string) {
				defer wg.Done()
				// A container slow to boot (image pull, a slow setup_script)
				// can legitimately take up to ProvisionTimeoutSeconds — the
				// same budget an ordinary cold-started session gets. Using
				// the tick's own ctx here instead would tie that budget to
				// the reconciler job's scheduler-level timeout, which
				// defends against a different failure mode (the job hanging)
				// and is set well below ProvisionTimeoutSeconds; inheriting
				// it would abort every warm start for any image slow enough
				// to legitimately need the full cold-start budget, which
				// converge would then never successfully pre-warm no matter
				// how many ticks it tried.
				startCtx, cancel := context.WithTimeout(context.Background(), ProvisionTimeoutSeconds*time.Second)
				defer cancel()
				cid, host, err := p.runtime.StartWarm(startCtx, warmID, image, setup)
				if err != nil {
					slog.Error("labs.WarmPoolPlanner: start warm", "lab_id", labID, "warm_id", warmID, "error", err)
					if delErr := p.repo.DeleteWarmContainer(context.Background(), warmID); delErr != nil {
						slog.Error("labs.WarmPoolPlanner: delete failed warming row", "warm_id", warmID, "error", delErr)
					}
					return
				}
				if err := p.repo.MarkWarmContainerReady(context.Background(), warmID, cid, host); err != nil {
					slog.Error("labs.WarmPoolPlanner: mark ready", "warm_id", warmID, "error", err)
					_ = p.runtime.Kill(context.Background(), cid)
					_ = p.repo.DeleteWarmContainer(context.Background(), warmID)
				}
			}(warmID, pl.lab.Image, setup, pl.lab.LabID)
		}
	}
	wg.Wait()
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
