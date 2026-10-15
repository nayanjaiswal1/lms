package roadmap

import (
	"testing"
	"time"
)

func TestComputePace(t *testing.T) {
	now := time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC)
	weeksAgo := func(w int) time.Time { return now.Add(-time.Duration(w) * hoursPerWeek * time.Hour) }
	cases := []struct {
		name                     string
		total, done, timeframe   int
		start                    time.Time
		wantBehind               bool
		wantExpected, wantRemain float64
	}{
		{"on track", 10, 5, 10, weeksAgo(5), false, 50, 5},
		{"slightly behind within threshold", 10, 4, 10, weeksAgo(5), false, 50, 5},
		{"behind", 10, 2, 10, weeksAgo(5), true, 50, 5},
		{"finished late", 10, 10, 4, weeksAgo(8), false, 100, 0},
		{"elapsed beyond timeframe", 10, 5, 4, weeksAgo(8), true, 100, 0},
		{"zero modules", 0, 0, 4, weeksAgo(3), false, 0, 0},
		{"no timeframe", 5, 0, 0, weeksAgo(3), false, 0, 0},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p := ComputePace(c.total, c.done, c.timeframe, c.start, now)
			if p.IsBehind != c.wantBehind || p.ExpectedPct != c.wantExpected || float64(p.WeeksRemaining) != c.wantRemain {
				t.Fatalf("got %+v", p)
			}
		})
	}
}

func TestReplanWeeks(t *testing.T) {
	cases := []struct {
		name                       string
		elapsed                    float64
		completedMin, remainingMin int
		wantTotal, wantRemaining   int
	}{
		{"observed pace", 4, 480, 1200, 14, 10},               // 120/wk -> 10 wks left
		{"stalled uses floor", 4, 0, 600, 9, 5},               // floor 120/wk -> 5
		{"fractional elapsed rounds up", 2.2, 600, 600, 6, 3}, // ceil(2.2)=3, pace 600/2.2=272 -> 3
		{"clamped to max", 50, 0, 1000000, MaxTimeframeWeeks, MaxTimeframeWeeks - 50},
		{"nothing left", 3, 100, 0, 3, 0},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			total, rem := ReplanWeeks(c.elapsed, c.completedMin, c.remainingMin)
			if total != c.wantTotal || rem != c.wantRemaining {
				t.Fatalf("got total=%d remaining=%d", total, rem)
			}
		})
	}
}

func TestDistributeWeeks(t *testing.T) {
	got := distributeWeeks(6, []int{0, 300, 100})
	if got[0] != nil || *got[1] != 5 || *got[2] != 2 {
		t.Fatalf("got %v %v %v", got[0], *got[1], *got[2])
	}
}
