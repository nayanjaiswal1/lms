package sessions

import (
	"fmt"
	"sort"
	"time"
)

// timeRange is a half-open [Start, End) interval used while folding rules,
// exceptions, and existing bookings into a slot grid.
type timeRange struct {
	Start time.Time
	End   time.Time
}

func (r timeRange) overlaps(o timeRange) bool {
	return r.Start.Before(o.End) && o.Start.Before(r.End)
}

// maxSlotWindow bounds how wide a single slot query may span. Slot expansion
// is O(days x rules x slots-per-day), so an unbounded ?from=&to= is a cheap
// way to make the server do a year of arithmetic per request.
const maxSlotWindow = 62 * 24 * time.Hour

// ExpandSlots computes every bookable window for one mentor between from and
// to, marking the ones already taken rather than dropping them (see Slot).
//
// Precedence, highest first:
//  1. a blocking exception removes a slot outright — a mentor marking a day
//     off means off, even if a weekly rule says otherwise;
//  2. an opening exception (is_blocked=false) adds a window the weekly rules
//     don't cover;
//  3. the weekly rules themselves.
//
// busy is the mentor's existing scheduled sessions; overlapping slots come
// back Taken=true. Slots starting sooner than minNotice from now, or further
// out than the org's horizon, are not returned at all — an unbookable slot
// rendered as free is a booking the server will only reject later.
func ExpandSlots(rules []AvailabilityRule, exceptions []AvailabilityException, busy []timeRange, from, to, now time.Time, cfg Config) ([]Slot, error) {
	if !to.After(from) {
		return nil, fmt.Errorf("%w: to must be after from", ErrInvalid)
	}
	if to.Sub(from) > maxSlotWindow {
		return nil, fmt.Errorf("%w: slot range cannot exceed %d days", ErrInvalid, int(maxSlotWindow.Hours()/24))
	}

	earliest := now.Add(time.Duration(cfg.MinNoticeHours) * time.Hour)
	latest := now.AddDate(0, 0, cfg.BookingHorizonDays)

	var blocked []timeRange
	var open []struct {
		timeRange
		slotMinutes int
	}

	addOpen := func(r timeRange, slotMinutes int) {
		open = append(open, struct {
			timeRange
			slotMinutes int
		}{r, slotMinutes})
	}

	// Exceptions first: a block is authoritative over everything below it,
	// and an opening exception is an extra window in its own right.
	for _, exc := range exceptions {
		loc, err := time.LoadLocation(exc.Timezone)
		if err != nil {
			// A zone that no longer resolves must not take the whole
			// availability query down with it — skip the one bad row.
			continue
		}
		day, err := time.ParseInLocation("2006-01-02", exc.OnDate, loc)
		if err != nil {
			continue
		}
		y, m, d := day.Date()

		startMin, endMin := 0, 1440
		if exc.StartMinute != nil && exc.EndMinute != nil {
			startMin, endMin = *exc.StartMinute, *exc.EndMinute
		}
		window := timeRange{
			Start: time.Date(y, m, d, 0, startMin, 0, 0, loc),
			End:   time.Date(y, m, d, 0, endMin, 0, 0, loc),
		}
		if exc.IsBlocked {
			blocked = append(blocked, window)
			continue
		}
		addOpen(window, exc.SlotMinutes)
	}

	// Weekly rules, expanded date by date in each rule's own zone. The
	// iteration is padded a day either side because a window that starts on
	// the day before `from` in the mentor's zone can still end inside it.
	for _, rule := range rules {
		if !rule.Active {
			continue
		}
		loc, err := time.LoadLocation(rule.Timezone)
		if err != nil {
			continue
		}
		cursor := from.In(loc).AddDate(0, 0, -1)
		end := to.In(loc).AddDate(0, 0, 1)
		for ; !cursor.After(end); cursor = cursor.AddDate(0, 0, 1) {
			if int(cursor.Weekday()) != rule.Weekday {
				continue
			}
			y, m, d := cursor.Date()
			addOpen(timeRange{
				// time.Date normalizes an out-of-range minute, so a start of
				// 540 becomes 09:00 local — and picks the correct UTC offset
				// for that wall-clock time, which is what makes a "every
				// Tuesday 09:00" rule survive a DST shift.
				Start: time.Date(y, m, d, 0, rule.StartMinute, 0, 0, loc),
				End:   time.Date(y, m, d, 0, rule.EndMinute, 0, 0, loc),
			}, rule.SlotMinutes)
		}
	}

	// Chop each open window into its slot grid, dropping anything blocked,
	// out of range, or outside the bookable horizon.
	seen := make(map[[2]int64]int) // slot bounds -> index into out
	out := []Slot{}
	for _, w := range open {
		if w.slotMinutes <= 0 {
			continue
		}
		step := time.Duration(w.slotMinutes) * time.Minute
		for slotStart := w.Start; !slotStart.Add(step).After(w.End); slotStart = slotStart.Add(step) {
			slot := timeRange{Start: slotStart, End: slotStart.Add(step)}

			if slot.Start.Before(from) || slot.End.After(to) {
				continue
			}
			if slot.Start.Before(earliest) || slot.Start.After(latest) {
				continue
			}
			if anyOverlap(blocked, slot) {
				continue
			}

			key := [2]int64{slot.Start.Unix(), slot.End.Unix()}
			taken := anyOverlap(busy, slot)
			if idx, dup := seen[key]; dup {
				// Two rules can publish the same slot (an opening exception
				// layered over a weekly rule is the common case). Keep one,
				// and let Taken win — a duplicate that says "free" must not
				// mask the copy that knows it is booked.
				if taken {
					out[idx].Taken = true
				}
				continue
			}
			seen[key] = len(out)
			out = append(out, Slot{StartsAt: slot.Start.UTC(), EndsAt: slot.End.UTC(), Taken: taken})
		}
	}

	sort.Slice(out, func(i, j int) bool { return out[i].StartsAt.Before(out[j].StartsAt) })
	return out, nil
}

func anyOverlap(ranges []timeRange, r timeRange) bool {
	for _, other := range ranges {
		if other.overlaps(r) {
			return true
		}
	}
	return false
}

// validateRule checks one availability rule against the same bounds the
// mentor_availability_rules CHECK constraints enforce, so a bad rule is
// rejected with a readable message instead of a 500 from a constraint
// violation. The timezone is validated by actually resolving it — a name the
// server's tzdata doesn't know would silently disable the rule in
// ExpandSlots, which looks like "my availability vanished" to the mentor.
func validateRule(r AvailabilityRule) error {
	if r.Weekday < 0 || r.Weekday > 6 {
		return fmt.Errorf("%w: weekday must be 0 (Sunday) through 6 (Saturday)", ErrInvalid)
	}
	if r.StartMinute < 0 || r.EndMinute > 1440 || r.EndMinute <= r.StartMinute {
		return fmt.Errorf("%w: the window must start at or after 00:00, end by 24:00, and end after it starts", ErrInvalid)
	}
	if r.SlotMinutes < 5 || r.SlotMinutes > 480 {
		return fmt.Errorf("%w: slot length must be between 5 and 480 minutes", ErrInvalid)
	}
	if r.EndMinute-r.StartMinute < r.SlotMinutes {
		return fmt.Errorf("%w: the window is shorter than one %d-minute slot", ErrInvalid, r.SlotMinutes)
	}
	if _, err := time.LoadLocation(r.Timezone); err != nil {
		return fmt.Errorf("%w: %q is not a known timezone", ErrInvalid, r.Timezone)
	}
	return nil
}

// validateException mirrors validateRule for one-off overrides.
func validateException(e AvailabilityException) error {
	if _, err := time.Parse("2006-01-02", e.OnDate); err != nil {
		return fmt.Errorf("%w: on_date must be a YYYY-MM-DD date", ErrInvalid)
	}
	if (e.StartMinute == nil) != (e.EndMinute == nil) {
		return fmt.Errorf("%w: set both start_minute and end_minute, or neither", ErrInvalid)
	}
	if e.StartMinute != nil {
		if *e.StartMinute < 0 || *e.EndMinute > 1440 || *e.EndMinute <= *e.StartMinute {
			return fmt.Errorf("%w: the window must start at or after 00:00, end by 24:00, and end after it starts", ErrInvalid)
		}
	} else if !e.IsBlocked {
		return fmt.Errorf("%w: an availability opening needs a start and end time", ErrInvalid)
	}
	if e.SlotMinutes < 5 || e.SlotMinutes > 480 {
		return fmt.Errorf("%w: slot length must be between 5 and 480 minutes", ErrInvalid)
	}
	if _, err := time.LoadLocation(e.Timezone); err != nil {
		return fmt.Errorf("%w: %q is not a known timezone", ErrInvalid, e.Timezone)
	}
	return nil
}
