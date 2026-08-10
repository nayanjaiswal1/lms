package calendar

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

// RRule is a deliberately small RFC 5545 RRULE subset: FREQ (DAILY or
// WEEKLY), INTERVAL, and one bound (COUNT or UNTIL). No BYDAY, BYMONTH,
// BYSETPOS, or any other modifier — every recurring event MindForge schedules
// (weekly mentor sessions, recurring live classes) fits "every N days/weeks,
// stopping after COUNT occurrences or on UNTIL".
type RRule struct {
	Freq     string // "DAILY" | "WEEKLY"
	Interval int
	Count    int // 0 = unbounded (Until governs instead, if set)
	Until    *time.Time
}

// ParseRRule parses a semicolon-separated "KEY=VALUE" RRULE string, e.g.
// "FREQ=WEEKLY;INTERVAL=1;COUNT=10" or "FREQ=DAILY;UNTIL=20261231T000000Z".
func ParseRRule(rule string) (RRule, error) {
	r := RRule{Interval: 1}
	rule = strings.TrimSpace(rule)
	if rule == "" {
		return RRule{}, fmt.Errorf("calendar: empty recurrence rule")
	}

	sawFreq := false
	for _, part := range strings.Split(rule, ";") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		kv := strings.SplitN(part, "=", 2)
		if len(kv) != 2 {
			return RRule{}, fmt.Errorf("calendar: invalid recurrence segment %q", part)
		}
		key, val := strings.ToUpper(strings.TrimSpace(kv[0])), strings.TrimSpace(kv[1])

		switch key {
		case "FREQ":
			val = strings.ToUpper(val)
			if val != "DAILY" && val != "WEEKLY" {
				return RRule{}, fmt.Errorf("calendar: unsupported FREQ %q (only DAILY, WEEKLY are supported)", val)
			}
			r.Freq = val
			sawFreq = true
		case "INTERVAL":
			n, err := strconv.Atoi(val)
			if err != nil || n <= 0 {
				return RRule{}, fmt.Errorf("calendar: invalid INTERVAL %q", val)
			}
			r.Interval = n
		case "COUNT":
			n, err := strconv.Atoi(val)
			if err != nil || n <= 0 {
				return RRule{}, fmt.Errorf("calendar: invalid COUNT %q", val)
			}
			r.Count = n
		case "UNTIL":
			t, err := parseRRuleTime(val)
			if err != nil {
				return RRule{}, fmt.Errorf("calendar: invalid UNTIL %q: %w", val, err)
			}
			r.Until = &t
		default:
			return RRule{}, fmt.Errorf("calendar: unsupported recurrence field %q (only FREQ, INTERVAL, COUNT, UNTIL are supported)", key)
		}
	}
	if !sawFreq {
		return RRule{}, fmt.Errorf("calendar: recurrence rule missing FREQ")
	}
	if r.Count > 0 && r.Until != nil {
		// RFC 5545 forbids setting both; UNTIL wins deterministically instead
		// of rejecting the whole rule.
		r.Count = 0
	}
	return r, nil
}

// parseRRuleTime accepts the RFC 5545 UTC basic form (20060102T150405Z), a
// bare date (20060102), or RFC3339 — whichever the caller supplied.
func parseRRuleTime(val string) (time.Time, error) {
	if t, err := time.Parse("20060102T150405Z", val); err == nil {
		return t, nil
	}
	if t, err := time.Parse("20060102", val); err == nil {
		return t, nil
	}
	return time.Parse(time.RFC3339, val)
}

// maxOccurrenceScan bounds the enumeration loop ExpandOccurrences runs once
// it has already closed-form-jumped to the first occurrence at or after
// `from` (see occurrenceIndexAtOrAfter) — a defensive cap on the size of the
// [from, to] window itself (e.g. a 1-day INTERVAL queried across a
// multi-year window), not on the distance from the event's start date, which
// is what used to make this loop the bottleneck. It also doubles as the
// fallback scan length for any future RRule extension that can't jump in
// closed form (e.g. BYDAY/BYSETPOS); unreachable today since RRule only
// supports plain DAILY/WEEKLY INTERVAL rules, every one of which has a
// constant per-occurrence day step and jumps exactly.
const maxOccurrenceScan = 400

// occurrenceIndexAtOrAfter returns the 0-based index (i.e. the occurrence at
// start.AddDate(0, 0, i*stepDays)) of the first occurrence at or after
// `from`, computed directly instead of by iterating every occurrence
// between start and from — the closed-form window jump this package used to
// defer behind a bounded scan. stepDays is always a whole number of days
// (DAILY/WEEKLY are the only supported FREQs), so dividing the elapsed
// wall-clock duration by it gives an exact-or-near estimate; the correction
// loops below nudge that estimate to the true index and are bounded by a
// small constant (DST shifts wall-clock duration by at most a couple hours
// around a transition), never by the number of occurrences skipped.
func occurrenceIndexAtOrAfter(start time.Time, stepDays int, from time.Time) int {
	if !from.After(start) {
		return 0
	}
	elapsedDays := from.Sub(start).Hours() / 24
	idx := int(elapsedDays / float64(stepDays))
	if idx < 0 {
		idx = 0
	}
	for start.AddDate(0, 0, idx*stepDays).Before(from) {
		idx++
	}
	for idx > 0 && !start.AddDate(0, 0, (idx-1)*stepDays).Before(from) {
		idx--
	}
	return idx
}

// ExpandOccurrences returns concrete occurrences of a recurring base event
// (base.RecurrenceRule must be set) whose start falls within [from, to],
// skipping any occurrence start present in base.ExcludedOccurrences (set when
// a single occurrence has been detached into its own row — see
// Service.UpdateEvent). Each returned Event is a shallow copy of base with
// StartsAt/EndsAt shifted to that occurrence; ID is unchanged since these are
// virtual instances of the same logical event, not separate rows.
func ExpandOccurrences(base Event, from, to time.Time) ([]Event, error) {
	if base.RecurrenceRule == nil || strings.TrimSpace(*base.RecurrenceRule) == "" {
		return nil, fmt.Errorf("calendar: ExpandOccurrences requires a recurrence rule")
	}
	rule, err := ParseRRule(*base.RecurrenceRule)
	if err != nil {
		return nil, err
	}

	var stepDays int
	switch rule.Freq {
	case "DAILY":
		stepDays = rule.Interval
	case "WEEKLY":
		stepDays = 7 * rule.Interval
	}

	var duration time.Duration
	if base.EndsAt != nil {
		duration = base.EndsAt.Sub(base.StartsAt)
	}

	excluded := make(map[int64]struct{}, len(base.ExcludedOccurrences))
	for _, ex := range base.ExcludedOccurrences {
		excluded[ex.UTC().Unix()] = struct{}{}
	}

	startIdx := occurrenceIndexAtOrAfter(base.StartsAt, stepDays, from)
	if rule.Count > 0 && startIdx >= rule.Count {
		return nil, nil
	}

	var out []Event
	cur := base.StartsAt.AddDate(0, 0, startIdx*stepDays)
	for i := startIdx; i < startIdx+maxOccurrenceScan; i++ {
		if rule.Count > 0 && i >= rule.Count {
			break
		}
		if rule.Until != nil && cur.After(*rule.Until) {
			break
		}
		if cur.After(to) {
			break
		}
		if _, skip := excluded[cur.UTC().Unix()]; !skip {
			occ := base
			occ.StartsAt = cur
			if base.EndsAt != nil {
				end := cur.Add(duration)
				occ.EndsAt = &end
			}
			out = append(out, occ)
		}
		cur = cur.AddDate(0, 0, stepDays)
	}
	return out, nil
}
