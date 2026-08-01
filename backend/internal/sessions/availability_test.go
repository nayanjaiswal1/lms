package sessions

import (
	"testing"
	"time"
)

// baseCfg is a permissive policy so each test exercises the one rule it is
// about rather than tripping over the notice/horizon guards.
func baseCfg() Config {
	c := DefaultConfig("org")
	c.MinNoticeHours = 0
	c.BookingHorizonDays = 365
	return c
}

func mustLoad(t *testing.T, name string) *time.Location {
	t.Helper()
	loc, err := time.LoadLocation(name)
	if err != nil {
		t.Skipf("tzdata for %s unavailable on this platform: %v", name, err)
	}
	return loc
}

// A Tuesday 09:00-12:00 rule with 30-minute slots is six slots, starting at
// wall-clock 09:00 in the mentor's zone.
func TestExpandSlots_WeeklyRule(t *testing.T) {
	loc := mustLoad(t, "Asia/Kolkata")
	rules := []AvailabilityRule{{
		Weekday: int(time.Tuesday), StartMinute: 9 * 60, EndMinute: 12 * 60,
		SlotMinutes: 30, Timezone: "Asia/Kolkata", Active: true,
	}}

	// Tuesday 2026-08-04.
	from := time.Date(2026, 8, 4, 0, 0, 0, 0, loc)
	to := from.AddDate(0, 0, 1)
	now := from.AddDate(0, 0, -7)

	slots, err := ExpandSlots(rules, nil, nil, from, to, now, baseCfg())
	if err != nil {
		t.Fatalf("ExpandSlots: %v", err)
	}
	if len(slots) != 6 {
		t.Fatalf("got %d slots, want 6", len(slots))
	}
	first := slots[0].StartsAt.In(loc)
	if first.Hour() != 9 || first.Minute() != 0 {
		t.Errorf("first slot starts at %s, want 09:00 local", first.Format("15:04"))
	}
	if got := slots[5].EndsAt.In(loc); got.Hour() != 12 {
		t.Errorf("last slot ends at %s, want 12:00 local", got.Format("15:04"))
	}
	for _, s := range slots {
		if s.Taken {
			t.Errorf("slot %s marked taken with no bookings", s.StartsAt)
		}
	}
}

// An inactive rule publishes nothing — a mentor pausing availability must
// actually stop showing up as bookable.
func TestExpandSlots_InactiveRuleIgnored(t *testing.T) {
	loc := mustLoad(t, "UTC")
	rules := []AvailabilityRule{{
		Weekday: int(time.Tuesday), StartMinute: 9 * 60, EndMinute: 12 * 60,
		SlotMinutes: 30, Timezone: "UTC", Active: false,
	}}
	from := time.Date(2026, 8, 4, 0, 0, 0, 0, loc)
	slots, err := ExpandSlots(rules, nil, nil, from, from.AddDate(0, 0, 1), from.AddDate(0, 0, -7), baseCfg())
	if err != nil {
		t.Fatalf("ExpandSlots: %v", err)
	}
	if len(slots) != 0 {
		t.Fatalf("got %d slots from an inactive rule, want 0", len(slots))
	}
}

// A blocking exception wins over the weekly rule it overlaps.
func TestExpandSlots_BlockingExceptionWins(t *testing.T) {
	loc := mustLoad(t, "UTC")
	rules := []AvailabilityRule{{
		Weekday: int(time.Tuesday), StartMinute: 9 * 60, EndMinute: 12 * 60,
		SlotMinutes: 60, Timezone: "UTC", Active: true,
	}}
	start, end := 10*60, 11*60
	exceptions := []AvailabilityException{{
		OnDate: "2026-08-04", StartMinute: &start, EndMinute: &end,
		IsBlocked: true, SlotMinutes: 60, Timezone: "UTC",
	}}

	from := time.Date(2026, 8, 4, 0, 0, 0, 0, loc)
	slots, err := ExpandSlots(rules, exceptions, nil, from, from.AddDate(0, 0, 1), from.AddDate(0, 0, -7), baseCfg())
	if err != nil {
		t.Fatalf("ExpandSlots: %v", err)
	}
	if len(slots) != 2 {
		t.Fatalf("got %d slots, want 2 (09:00 and 11:00, with 10:00 blocked)", len(slots))
	}
	for _, s := range slots {
		if s.StartsAt.In(loc).Hour() == 10 {
			t.Error("the 10:00 slot survived a blocking exception")
		}
	}
}

// A whole-day block clears the day, and only a block may span a whole day.
func TestExpandSlots_WholeDayBlock(t *testing.T) {
	loc := mustLoad(t, "UTC")
	rules := []AvailabilityRule{{
		Weekday: int(time.Tuesday), StartMinute: 9 * 60, EndMinute: 17 * 60,
		SlotMinutes: 60, Timezone: "UTC", Active: true,
	}}
	exceptions := []AvailabilityException{{
		OnDate: "2026-08-04", IsBlocked: true, SlotMinutes: 60, Timezone: "UTC",
	}}
	from := time.Date(2026, 8, 4, 0, 0, 0, 0, loc)
	slots, err := ExpandSlots(rules, exceptions, nil, from, from.AddDate(0, 0, 1), from.AddDate(0, 0, -7), baseCfg())
	if err != nil {
		t.Fatalf("ExpandSlots: %v", err)
	}
	if len(slots) != 0 {
		t.Fatalf("got %d slots on a fully blocked day, want 0", len(slots))
	}
}

// A booked session marks its slot taken — it must still be returned, so the
// grid shows a busy time rather than a hole (see Slot's doc comment).
func TestExpandSlots_BusyMarkedNotDropped(t *testing.T) {
	loc := mustLoad(t, "UTC")
	rules := []AvailabilityRule{{
		Weekday: int(time.Tuesday), StartMinute: 9 * 60, EndMinute: 11 * 60,
		SlotMinutes: 60, Timezone: "UTC", Active: true,
	}}
	from := time.Date(2026, 8, 4, 0, 0, 0, 0, loc)
	busy := []timeRange{{
		Start: time.Date(2026, 8, 4, 9, 0, 0, 0, loc),
		End:   time.Date(2026, 8, 4, 10, 0, 0, 0, loc),
	}}

	slots, err := ExpandSlots(rules, nil, busy, from, from.AddDate(0, 0, 1), from.AddDate(0, 0, -7), baseCfg())
	if err != nil {
		t.Fatalf("ExpandSlots: %v", err)
	}
	if len(slots) != 2 {
		t.Fatalf("got %d slots, want 2", len(slots))
	}
	if !slots[0].Taken {
		t.Error("the 09:00 slot overlaps a booking but is not marked taken")
	}
	if slots[1].Taken {
		t.Error("the 10:00 slot has no booking but is marked taken")
	}
}

// min_notice_hours hides slots too soon to book. Returning them would render
// a free slot the server then refuses.
func TestExpandSlots_MinNoticeHidesImminentSlots(t *testing.T) {
	loc := mustLoad(t, "UTC")
	rules := []AvailabilityRule{{
		Weekday: int(time.Tuesday), StartMinute: 9 * 60, EndMinute: 17 * 60,
		SlotMinutes: 60, Timezone: "UTC", Active: true,
	}}
	cfg := baseCfg()
	cfg.MinNoticeHours = 4

	from := time.Date(2026, 8, 4, 0, 0, 0, 0, loc)
	now := time.Date(2026, 8, 4, 9, 0, 0, 0, loc) // 09:00 — 13:00 is the earliest bookable

	slots, err := ExpandSlots(rules, nil, nil, from, from.AddDate(0, 0, 1), now, cfg)
	if err != nil {
		t.Fatalf("ExpandSlots: %v", err)
	}
	if len(slots) == 0 {
		t.Fatal("got no slots at all; want the afternoon ones")
	}
	if got := slots[0].StartsAt.In(loc).Hour(); got != 13 {
		t.Errorf("first bookable slot is %02d:00, want 13:00 (09:00 + 4h notice)", got)
	}
}

// The horizon caps how far ahead slots are published.
func TestExpandSlots_HorizonCapsFutureSlots(t *testing.T) {
	loc := mustLoad(t, "UTC")
	rules := []AvailabilityRule{{
		Weekday: int(time.Tuesday), StartMinute: 9 * 60, EndMinute: 10 * 60,
		SlotMinutes: 60, Timezone: "UTC", Active: true,
	}}
	cfg := baseCfg()
	cfg.BookingHorizonDays = 3

	now := time.Date(2026, 8, 4, 0, 0, 0, 0, loc) // a Tuesday
	from := now
	to := now.AddDate(0, 0, 21)

	slots, err := ExpandSlots(rules, nil, nil, from, to, now, cfg)
	if err != nil {
		t.Fatalf("ExpandSlots: %v", err)
	}
	// Only this Tuesday falls inside a 3-day horizon; the next one is 7 days out.
	if len(slots) != 1 {
		t.Fatalf("got %d slots, want 1 inside a 3-day horizon", len(slots))
	}
}

// A weekly rule is a wall-clock promise: "Sundays at 09:00" stays 09:00 local
// across a DST transition, even though the UTC instant moves. This is the
// whole reason the rule stores a timezone instead of UTC minutes.
func TestExpandSlots_WallClockSurvivesDST(t *testing.T) {
	loc := mustLoad(t, "America/New_York")
	rules := []AvailabilityRule{{
		Weekday: int(time.Sunday), StartMinute: 9 * 60, EndMinute: 10 * 60,
		SlotMinutes: 60, Timezone: "America/New_York", Active: true,
	}}

	// US DST ends Sunday 2026-11-01. Span the Sundays either side of it.
	from := time.Date(2026, 10, 24, 0, 0, 0, 0, loc)
	to := time.Date(2026, 11, 9, 0, 0, 0, 0, loc)
	now := from.AddDate(0, 0, -1)

	slots, err := ExpandSlots(rules, nil, nil, from, to, now, baseCfg())
	if err != nil {
		t.Fatalf("ExpandSlots: %v", err)
	}
	if len(slots) < 2 {
		t.Fatalf("got %d slots, want at least 2 Sundays", len(slots))
	}

	var offsets = map[int]bool{}
	for _, s := range slots {
		local := s.StartsAt.In(loc)
		if local.Hour() != 9 {
			t.Errorf("slot on %s starts at %02d:00 local, want 09:00", local.Format("2006-01-02"), local.Hour())
		}
		_, offset := local.Zone()
		offsets[offset] = true
	}
	// Same wall clock, different UTC offsets — proof the conversion is
	// happening per-date rather than once.
	if len(offsets) < 2 {
		t.Error("every slot has the same UTC offset; the DST transition was not applied")
	}
}

// An opening exception adds a window the weekly pattern does not cover.
func TestExpandSlots_OpeningException(t *testing.T) {
	loc := mustLoad(t, "UTC")
	start, end := 14*60, 16*60
	exceptions := []AvailabilityException{{
		OnDate: "2026-08-05", StartMinute: &start, EndMinute: &end,
		IsBlocked: false, SlotMinutes: 60, Timezone: "UTC",
	}}

	// No weekly rules at all — the exception is the only availability.
	from := time.Date(2026, 8, 5, 0, 0, 0, 0, loc)
	slots, err := ExpandSlots(nil, exceptions, nil, from, from.AddDate(0, 0, 1), from.AddDate(0, 0, -7), baseCfg())
	if err != nil {
		t.Fatalf("ExpandSlots: %v", err)
	}
	if len(slots) != 2 {
		t.Fatalf("got %d slots from a 14:00-16:00 opening, want 2", len(slots))
	}
	if got := slots[0].StartsAt.In(loc).Hour(); got != 14 {
		t.Errorf("opening starts at %02d:00, want 14:00", got)
	}
}

// A window that does not divide evenly by the slot length drops the short
// tail rather than publishing a slot the mentor did not offer.
func TestExpandSlots_PartialTrailingSlotDropped(t *testing.T) {
	loc := mustLoad(t, "UTC")
	rules := []AvailabilityRule{{
		Weekday: int(time.Tuesday), StartMinute: 9 * 60, EndMinute: 10*60 + 45,
		SlotMinutes: 60, Timezone: "UTC", Active: true,
	}}
	from := time.Date(2026, 8, 4, 0, 0, 0, 0, loc)
	slots, err := ExpandSlots(rules, nil, nil, from, from.AddDate(0, 0, 1), from.AddDate(0, 0, -7), baseCfg())
	if err != nil {
		t.Fatalf("ExpandSlots: %v", err)
	}
	if len(slots) != 1 {
		t.Fatalf("got %d slots from a 105-minute window of 60-minute slots, want 1", len(slots))
	}
}

// Two sources publishing the same slot collapse to one, and a taken copy
// beats a free one.
func TestExpandSlots_DuplicateSlotKeepsTaken(t *testing.T) {
	loc := mustLoad(t, "UTC")
	rules := []AvailabilityRule{{
		Weekday: int(time.Tuesday), StartMinute: 9 * 60, EndMinute: 10 * 60,
		SlotMinutes: 60, Timezone: "UTC", Active: true,
	}}
	start, end := 9*60, 10*60
	exceptions := []AvailabilityException{{
		OnDate: "2026-08-04", StartMinute: &start, EndMinute: &end,
		IsBlocked: false, SlotMinutes: 60, Timezone: "UTC",
	}}
	from := time.Date(2026, 8, 4, 0, 0, 0, 0, loc)
	busy := []timeRange{{
		Start: time.Date(2026, 8, 4, 9, 0, 0, 0, loc),
		End:   time.Date(2026, 8, 4, 10, 0, 0, 0, loc),
	}}

	slots, err := ExpandSlots(rules, exceptions, busy, from, from.AddDate(0, 0, 1), from.AddDate(0, 0, -7), baseCfg())
	if err != nil {
		t.Fatalf("ExpandSlots: %v", err)
	}
	if len(slots) != 1 {
		t.Fatalf("got %d slots, want 1 after deduplication", len(slots))
	}
	if !slots[0].Taken {
		t.Error("the deduplicated slot lost its taken flag")
	}
}

// The range guard keeps an unbounded ?from=&to= from forcing a year of
// arithmetic per request.
func TestExpandSlots_RejectsHugeRange(t *testing.T) {
	from := time.Now()
	if _, err := ExpandSlots(nil, nil, nil, from, from.AddDate(1, 0, 0), from, baseCfg()); err == nil {
		t.Fatal("a one-year range was accepted; want ErrInvalid")
	}
	if _, err := ExpandSlots(nil, nil, nil, from, from, from, baseCfg()); err == nil {
		t.Fatal("an empty range was accepted; want ErrInvalid")
	}
}

func TestValidateRule(t *testing.T) {
	valid := AvailabilityRule{Weekday: 2, StartMinute: 540, EndMinute: 720, SlotMinutes: 30, Timezone: "UTC"}
	if err := validateRule(valid); err != nil {
		t.Fatalf("valid rule rejected: %v", err)
	}

	cases := map[string]AvailabilityRule{
		"weekday out of range":     {Weekday: 7, StartMinute: 540, EndMinute: 720, SlotMinutes: 30, Timezone: "UTC"},
		"end before start":         {Weekday: 2, StartMinute: 720, EndMinute: 540, SlotMinutes: 30, Timezone: "UTC"},
		"end past midnight":        {Weekday: 2, StartMinute: 540, EndMinute: 1500, SlotMinutes: 30, Timezone: "UTC"},
		"slot longer than window":  {Weekday: 2, StartMinute: 540, EndMinute: 570, SlotMinutes: 60, Timezone: "UTC"},
		"unknown timezone":         {Weekday: 2, StartMinute: 540, EndMinute: 720, SlotMinutes: 30, Timezone: "Mars/Olympus"},
		"slot below the 5m floor":  {Weekday: 2, StartMinute: 540, EndMinute: 720, SlotMinutes: 1, Timezone: "UTC"},
		"slot above the 8h ceilng": {Weekday: 2, StartMinute: 0, EndMinute: 1440, SlotMinutes: 600, Timezone: "UTC"},
	}
	for name, rule := range cases {
		if err := validateRule(rule); err == nil {
			t.Errorf("%s: accepted, want ErrInvalid", name)
		}
	}
}

func TestValidateException(t *testing.T) {
	start, end := 540, 720
	valid := AvailabilityException{OnDate: "2026-08-04", StartMinute: &start, EndMinute: &end, SlotMinutes: 30, Timezone: "UTC"}
	if err := validateException(valid); err != nil {
		t.Fatalf("valid exception rejected: %v", err)
	}

	// A whole-day entry is legal as a block...
	wholeDayBlock := AvailabilityException{OnDate: "2026-08-04", IsBlocked: true, SlotMinutes: 30, Timezone: "UTC"}
	if err := validateException(wholeDayBlock); err != nil {
		t.Errorf("whole-day block rejected: %v", err)
	}
	// ...but not as an opening, which would be a 24-hour shift nobody means.
	wholeDayOpen := AvailabilityException{OnDate: "2026-08-04", IsBlocked: false, SlotMinutes: 30, Timezone: "UTC"}
	if err := validateException(wholeDayOpen); err == nil {
		t.Error("whole-day opening accepted, want ErrInvalid")
	}

	onlyStart := AvailabilityException{OnDate: "2026-08-04", StartMinute: &start, IsBlocked: true, SlotMinutes: 30, Timezone: "UTC"}
	if err := validateException(onlyStart); err == nil {
		t.Error("half-specified window accepted, want ErrInvalid")
	}
	badDate := AvailabilityException{OnDate: "04-08-2026", IsBlocked: true, SlotMinutes: 30, Timezone: "UTC"}
	if err := validateException(badDate); err == nil {
		t.Error("malformed date accepted, want ErrInvalid")
	}
}
