package digest

import (
	"testing"
	"time"
)

func day(n int) time.Time {
	return time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC).AddDate(0, 0, n)
}

func TestDueCadences_FirstDigestIsAnchorOnly(t *testing.T) {
	// No prior digest at all (zero anchor) — always no periodic cadence,
	// even though 0 % anything == 0 would otherwise wrongly fire every one.
	if got := DueCadences(time.Time{}, day(0)); got != nil {
		t.Fatalf("expected nil for zero anchor, got %v", got)
	}
}

func TestDueCadences_AnchorDayItselfIsNotDue(t *testing.T) {
	anchor := day(0)
	if got := DueCadences(anchor, anchor); got != nil {
		t.Fatalf("expected nil on the anchor day itself, got %v", got)
	}
}

func TestDueCadences_Merge(t *testing.T) {
	anchor := day(0)
	// Day 21 is a multiple of both 3 and 7 — d3 and weekly must both fire,
	// merged into one slice (never two separate sends).
	got := DueCadences(anchor, day(21))
	want := map[Cadence]bool{CadenceD3: true, CadenceWeekly: true}
	if len(got) != len(want) {
		t.Fatalf("expected %d cadences, got %v", len(want), got)
	}
	for _, c := range got {
		if !want[c] {
			t.Fatalf("unexpected cadence %v in %v", c, got)
		}
	}
}

func TestDueCadences_Monthly(t *testing.T) {
	anchor := day(0)
	// Day 30 is also a multiple of 3 (every multiple of 30 is), so d3
	// legitimately fires alongside monthly — both belong in the merge.
	got := DueCadences(anchor, day(30))
	want := map[Cadence]bool{CadenceD3: true, CadenceMonthly: true}
	if len(got) != len(want) {
		t.Fatalf("expected %d cadences, got %v", len(want), got)
	}
	for _, c := range got {
		if !want[c] {
			t.Fatalf("unexpected cadence %v in %v", c, got)
		}
	}
}

func TestMergeCadences_NoActivityNoDue(t *testing.T) {
	got := MergeCadences(false, nil)
	if ShouldSend(got) {
		t.Fatalf("expected ShouldSend=false when there is no activity and nothing due, got cadences %v", got)
	}
}

func TestMergeCadences_ActivityOnly(t *testing.T) {
	got := MergeCadences(true, nil)
	if !ShouldSend(got) || len(got) != 1 || got[0] != CadenceDaily {
		t.Fatalf("expected [daily], got %v", got)
	}
}

func TestMergeCadences_QuietNightButWeeklyDue(t *testing.T) {
	// No activity today, but a periodic cadence still closes — the digest
	// still sends, since a weekly window covers real history even when
	// today itself was quiet.
	got := MergeCadences(false, []Cadence{CadenceWeekly})
	if !ShouldSend(got) || len(got) != 1 || got[0] != CadenceWeekly {
		t.Fatalf("expected [weekly], got %v", got)
	}
}

func TestMergeCadences_EverythingAtOnce(t *testing.T) {
	got := MergeCadences(true, []Cadence{CadenceD3, CadenceWeekly, CadenceMonthly})
	if len(got) != 4 {
		t.Fatalf("expected 4 merged cadences (1 email, never split), got %v", got)
	}
}

func TestWindowFor_WidestCadenceWins(t *testing.T) {
	now := day(100)
	start, end := WindowFor([]Cadence{CadenceDaily, CadenceWeekly, CadenceD3}, now)
	if !end.Equal(now) {
		t.Fatalf("expected end == now, got %v", end)
	}
	wantStart := now.AddDate(0, 0, -7)
	if !start.Equal(wantStart) {
		t.Fatalf("expected start = now-7d (weekly is the widest), got %v want %v", start, wantStart)
	}
}
