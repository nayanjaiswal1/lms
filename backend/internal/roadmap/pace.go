package roadmap

import (
	"errors"
	"math"
	"time"
)

const (
	// BehindThresholdPct: a roadmap is behind when completion trails the
	// elapsed share of its timeframe by more than this many percentage points.
	BehindThresholdPct = 15.0
	// DefaultModuleMinutes is used for modules without estimated_minutes.
	DefaultModuleMinutes = 60
	// MinWeeklyMinutes floors the observed pace so a stalled learner still
	// gets a finite plan.
	MinWeeklyMinutes = 120
	// MinTimeframeWeeks / MaxTimeframeWeeks mirror roadmaps_timeframe_weeks_check.
	MinTimeframeWeeks = 1
	MaxTimeframeWeeks = 104

	hoursPerWeek = 24 * 7
)

var (
	ErrNotBehind = errors.New("roadmap: not behind schedule")
	ErrNotActive = errors.New("roadmap: not active")
)

// Pace is the deterministic schedule status of a roadmap (no AI involved).
type Pace struct {
	ExpectedPct    float64
	ProgressPct    float64
	IsBehind       bool
	WeeksRemaining int
}

func elapsedWeeks(start, now time.Time) float64 {
	return math.Max(0, now.Sub(start).Hours()/hoursPerWeek)
}

// ComputePace compares completion with the elapsed share of the timeframe.
// A roadmap with no modules, no timeframe, or every module done is never behind.
func ComputePace(total, done, timeframeWeeks int, start, now time.Time) Pace {
	if total <= 0 || timeframeWeeks <= 0 {
		return Pace{}
	}
	elapsed := elapsedWeeks(start, now)
	p := Pace{
		ExpectedPct:    math.Min(100, elapsed/float64(timeframeWeeks)*100),
		ProgressPct:    float64(done) / float64(total) * 100,
		WeeksRemaining: max(0, int(math.Ceil(float64(timeframeWeeks)-elapsed))),
	}
	p.IsBehind = done < total && p.ExpectedPct-p.ProgressPct > BehindThresholdPct
	return p
}

// applyPace fills the schedule fields; only active roadmaps with a timeframe get them.
func (rm *Roadmap) applyPace(now time.Time) {
	if rm.Status != StatusActive || rm.TimeframeWeeks == nil {
		return
	}
	start := rm.CreatedAt
	if rm.GeneratedAt != nil {
		start = *rm.GeneratedAt
	}
	p := ComputePace(rm.ModuleCount, rm.CompletedCount, *rm.TimeframeWeeks, start, now)
	rm.ExpectedPct, rm.ProgressPct, rm.IsBehind, rm.WeeksRemaining = p.ExpectedPct, p.ProgressPct, p.IsBehind, p.WeeksRemaining
}

// ReplanWeeks returns the new total timeframe: weeks already elapsed (ceil,
// at least 1) plus the weeks the remaining minutes need at the observed pace
// (completed minutes per elapsed week, floored at MinWeeklyMinutes), clamped
// to the DB range. It also returns the weeks left from now.
func ReplanWeeks(elapsed float64, completedMinutes, remainingMinutes int) (total, remaining int) {
	elapsedCeil := max(MinTimeframeWeeks, int(math.Ceil(elapsed)))
	pace := math.Max(MinWeeklyMinutes, float64(completedMinutes)/math.Max(elapsed, 1))
	remaining = int(math.Ceil(float64(remainingMinutes) / pace))
	total = min(MaxTimeframeWeeks, max(MinTimeframeWeeks, elapsedCeil+remaining))
	return total, max(0, total-elapsedCeil)
}

// distributeWeeks splits weeks across phases proportionally to their remaining
// minutes (nil for phases with no remaining work); each open phase gets >= 1.
func distributeWeeks(weeks int, remainingMinutes []int) []*int {
	sum := 0
	for _, m := range remainingMinutes {
		sum += m
	}
	out := make([]*int, len(remainingMinutes))
	for i, m := range remainingMinutes {
		if m <= 0 || sum == 0 {
			continue
		}
		w := max(1, int(math.Round(float64(weeks)*float64(m)/float64(sum))))
		out[i] = &w
	}
	return out
}
