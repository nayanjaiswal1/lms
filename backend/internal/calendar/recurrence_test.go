package calendar

import (
	"testing"
	"time"
)

func mustRule(t *testing.T, rule string) *string {
	t.Helper()
	if _, err := ParseRRule(rule); err != nil {
		t.Fatalf("ParseRRule(%q) failed: %v", rule, err)
	}
	return &rule
}

// TestExpandOccurrences_FarFutureDaily proves a far-future window (10 years
// out) resolves via the closed-form jump, not a scan: maxOccurrenceScan is
// only 400, so a 1-day-INTERVAL rule scanning from base.StartsAt would never
// reach 10 years out (3650+ steps) without the jump landing the loop's start
// index there directly.
func TestExpandOccurrences_FarFutureDaily(t *testing.T) {
	start := time.Date(2026, 1, 1, 9, 0, 0, 0, time.UTC)
	base := Event{
		StartsAt:       start,
		RecurrenceRule: mustRule(t, "FREQ=DAILY;INTERVAL=1"),
	}

	from := start.AddDate(10, 0, 0)             // 10 years out
	to := from.AddDate(0, 0, 5)                 // a narrow 5-day window

	occs, err := ExpandOccurrences(base, from, to)
	if err != nil {
		t.Fatalf("ExpandOccurrences: %v", err)
	}
	if len(occs) == 0 {
		t.Fatalf("expected occurrences in the 10-years-out window, got none")
	}
	if occs[0].StartsAt.Before(from) {
		t.Errorf("first occurrence %v is before window start %v", occs[0].StartsAt, from)
	}
	if occs[0].StartsAt.After(to) {
		t.Errorf("first occurrence %v is after window end %v", occs[0].StartsAt, to)
	}
	// The occurrence stream is daily starting at `start`, so every date in
	// [from, to] should appear.
	wantCount := int(to.Sub(from).Hours()/24) + 1
	if len(occs) != wantCount {
		t.Errorf("got %d occurrences, want %d", len(occs), wantCount)
	}
}

// TestExpandOccurrences_FarFutureWeekly is the WEEKLY analogue of the DAILY
// far-future test above.
func TestExpandOccurrences_FarFutureWeekly(t *testing.T) {
	start := time.Date(2026, 1, 5, 18, 0, 0, 0, time.UTC) // a Monday
	base := Event{
		StartsAt:       start,
		RecurrenceRule: mustRule(t, "FREQ=WEEKLY;INTERVAL=2"),
	}

	from := start.AddDate(10, 0, 0)
	to := from.AddDate(0, 0, 30)

	occs, err := ExpandOccurrences(base, from, to)
	if err != nil {
		t.Fatalf("ExpandOccurrences: %v", err)
	}
	if len(occs) == 0 {
		t.Fatalf("expected occurrences in the 10-years-out window, got none")
	}
	for _, occ := range occs {
		if occ.StartsAt.Before(from) || occ.StartsAt.After(to) {
			t.Errorf("occurrence %v outside window [%v, %v]", occ.StartsAt, from, to)
		}
		// Every occurrence must land exactly on a 14-day step from start.
		diffDays := int(occ.StartsAt.Sub(start).Hours() / 24)
		if diffDays%14 != 0 {
			t.Errorf("occurrence %v is not a 14-day step from start %v (diffDays=%d)", occ.StartsAt, start, diffDays)
		}
	}
}

// TestExpandOccurrences_CountExhaustedBeforeWindow proves a COUNT-bounded
// rule whose occurrences all fall before `from` returns nothing, without
// scanning up to `from`.
func TestExpandOccurrences_CountExhaustedBeforeWindow(t *testing.T) {
	start := time.Date(2026, 1, 1, 9, 0, 0, 0, time.UTC)
	base := Event{
		StartsAt:       start,
		RecurrenceRule: mustRule(t, "FREQ=DAILY;INTERVAL=1;COUNT=5"),
	}

	from := start.AddDate(5, 0, 0) // far past the 5th (and last) occurrence
	to := from.AddDate(0, 0, 5)

	occs, err := ExpandOccurrences(base, from, to)
	if err != nil {
		t.Fatalf("ExpandOccurrences: %v", err)
	}
	if len(occs) != 0 {
		t.Errorf("expected no occurrences past COUNT, got %d", len(occs))
	}
}

// TestExpandOccurrences_ExcludedOccurrenceStillSkippedAfterJump proves the
// closed-form jump lands on the correct absolute occurrence (not merely a
// nearby one), so an excluded occurrence at the exact jump target is still
// excluded.
func TestExpandOccurrences_ExcludedOccurrenceStillSkippedAfterJump(t *testing.T) {
	start := time.Date(2026, 1, 1, 9, 0, 0, 0, time.UTC)
	target := start.AddDate(3, 0, 0) // some occurrence 3 years out
	base := Event{
		StartsAt:            start,
		RecurrenceRule:      mustRule(t, "FREQ=DAILY;INTERVAL=1"),
		ExcludedOccurrences: []time.Time{target},
	}

	occs, err := ExpandOccurrences(base, target, target)
	if err != nil {
		t.Fatalf("ExpandOccurrences: %v", err)
	}
	if len(occs) != 0 {
		t.Errorf("expected the excluded occurrence to be skipped, got %d occurrences", len(occs))
	}
}

// TestOccurrenceIndexAtOrAfter checks the closed-form index computation
// directly, including a DST-transition case where wall-clock elapsed
// duration doesn't divide evenly by 24h per day, to prove the correction
// loop lands on the exact index rather than an off-by-one neighbor.
func TestOccurrenceIndexAtOrAfter(t *testing.T) {
	nyc, err := time.LoadLocation("America/New_York")
	if err != nil {
		t.Skipf("America/New_York tzdata unavailable: %v", err)
	}

	t.Run("from before start", func(t *testing.T) {
		start := time.Date(2026, 6, 1, 9, 0, 0, 0, time.UTC)
		if idx := occurrenceIndexAtOrAfter(start, 1, start.AddDate(0, 0, -10)); idx != 0 {
			t.Errorf("got idx %d, want 0", idx)
		}
	})

	t.Run("from exactly on start", func(t *testing.T) {
		start := time.Date(2026, 6, 1, 9, 0, 0, 0, time.UTC)
		if idx := occurrenceIndexAtOrAfter(start, 1, start); idx != 0 {
			t.Errorf("got idx %d, want 0", idx)
		}
	})

	t.Run("exact multiple lands on that index", func(t *testing.T) {
		start := time.Date(2026, 6, 1, 9, 0, 0, 0, time.UTC)
		from := start.AddDate(0, 0, 30) // exactly 10 steps of 3 days
		idx := occurrenceIndexAtOrAfter(start, 3, from)
		if idx != 10 {
			t.Errorf("got idx %d, want 10", idx)
		}
	})

	t.Run("one day past an occurrence rounds up to the next", func(t *testing.T) {
		start := time.Date(2026, 6, 1, 9, 0, 0, 0, time.UTC)
		from := start.AddDate(0, 0, 31) // one day past the 10th step (step=3)
		idx := occurrenceIndexAtOrAfter(start, 3, from)
		want := 11 // start + 33 days is the first occurrence >= start+31
		if idx != want {
			t.Errorf("got idx %d, want %d", idx, want)
		}
		if start.AddDate(0, 0, idx*3).Before(from) {
			t.Errorf("candidate at idx %d is before from", idx)
		}
		if idx > 0 && !start.AddDate(0, 0, (idx-1)*3).Before(from) {
			t.Errorf("idx %d is not minimal: idx-1 candidate is also >= from", idx)
		}
	})

	t.Run("across a DST spring-forward transition", func(t *testing.T) {
		// 2026-03-08 is when America/New_York springs forward.
		start := time.Date(2026, 3, 1, 9, 0, 0, 0, nyc)
		from := start.AddDate(0, 0, 20)
		idx := occurrenceIndexAtOrAfter(start, 1, from)
		got := start.AddDate(0, 0, idx*1)
		if got.Before(from) {
			t.Errorf("candidate %v is before from %v", got, from)
		}
		if idx > 0 {
			prev := start.AddDate(0, 0, (idx-1)*1)
			if !prev.Before(from) {
				t.Errorf("idx %d not minimal: previous candidate %v is also >= from %v", idx, prev, from)
			}
		}
	})
}
