package labs

import (
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
	// unchanged, so the admin page always shows a recent "why".
	warmPoolHeartbeat = 15 * time.Minute
	// warmPoolDecisionRetention bounds the audit log.
	warmPoolDecisionRetention = 14 * 24 * time.Hour
	// warmPoolMaxStartsPerTick bounds provisioning burst per tick — a big
	// scale-up spreads over a few minutes instead of hammering the host.
	warmPoolMaxStartsPerTick = 3
)

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

	poolLabs, err := p.repo.ListWarmPoolLabs(ctx)
	if err != nil {
		return fmt.Errorf("labs.WarmPoolPlanner.Tick: %w", err)
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

// applyGlobalCap trims targets so their sum never exceeds the global
// container budget. Largest pools shrink first (they hurt least per unit),
// and every trimmed plan's reason records the cap.
func applyGlobalCap(plans []warmPoolPlan, globalMax int) {
	sum := 0
	for _, pl := range plans {
		sum += pl.target
	}
	if globalMax <= 0 || sum <= globalMax {
		return
	}
	idx := make([]int, len(plans))
	for i := range idx {
		idx[i] = i
	}
	sort.SliceStable(idx, func(a, b int) bool { return plans[idx[a]].target > plans[idx[b]].target })
	for sum > globalMax {
		trimmed := false
		for _, i := range idx {
			if plans[i].target > 0 {
				plans[i].target--
				plans[i].reason += fmt.Sprintf(" (−1 by global cap %d)", globalMax)
				sum--
				trimmed = true
				if sum <= globalMax {
					break
				}
			}
		}
		if !trimmed {
			break
		}
	}
}

// recordDecision writes an audit row when the target changed, or as a
// heartbeat when the last row is older than warmPoolHeartbeat.
func (p *WarmPoolPlanner) recordDecision(ctx context.Context, pl *warmPoolPlan, last map[string]WarmPoolDecision) {
	prev, hasPrev := last[pl.lab.LabID]
	prevTarget := 0
	if hasPrev {
		prevTarget = prev.Target
	}
	if hasPrev && prev.Target == pl.target && time.Since(prev.DecidedAt) < warmPoolHeartbeat {
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

// converge starts missing containers (bounded per tick) and trims excess.
func (p *WarmPoolPlanner) converge(ctx context.Context, plans []warmPoolPlan) {
	budget := warmPoolMaxStartsPerTick
	var wg sync.WaitGroup
	for _, pl := range plans {
		have := pl.lab.Ready + pl.lab.Warming

		// Scale down: trim oldest ready sandboxes beyond target.
		if pl.lab.Ready > pl.target {
			excess, err := p.repo.ListExcessReadyWarmContainers(ctx, pl.lab.LabID, pl.lab.TaskVersionID, pl.target)
			if err != nil {
				slog.Error("labs.WarmPoolPlanner: list excess", "lab_id", pl.lab.LabID, "error", err)
			} else {
				for _, e := range excess {
					if e.ContainerID != nil {
						if err := p.runtime.Kill(ctx, *e.ContainerID); err != nil {
							slog.Error("labs.WarmPoolPlanner: kill excess", "container", *e.ContainerID, "error", err)
						}
					}
					if err := p.repo.DeleteWarmContainer(ctx, e.ID); err != nil {
						slog.Error("labs.WarmPoolPlanner: delete excess row", "warm_id", e.ID, "error", err)
					}
				}
			}
			continue
		}

		// Scale up: provision missing sandboxes in parallel, bounded per tick.
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
				cid, host, err := p.runtime.StartWarm(ctx, warmID, image, setup)
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
