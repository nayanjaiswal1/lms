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

// maxOccurrenceScan bounds ExpandOccurrences' loop so an unbounded daily rule
// (no COUNT/UNTIL) queried against a far-future window cannot spin forever.
// ponytail: fixed cap rather than a smarter closed-form jump to the window
// start — 2000 daily steps is ~5.5 years, comfortably past any realistic
// mentor-session/live-class series. Raise if that ever stops being true.
const maxOccurrenceScan = 2000

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

	var out []Event
	cur := base.StartsAt
	for i := 0; i < maxOccurrenceScan; i++ {
		if rule.Count > 0 && i >= rule.Count {
			break
		}
		if rule.Until != nil && cur.After(*rule.Until) {
			break
		}
		if cur.After(to) {
			break
		}
		if !cur.Before(from) {
			if _, skip := excluded[cur.UTC().Unix()]; !skip {
				occ := base
				occ.StartsAt = cur
				if base.EndsAt != nil {
					end := cur.Add(duration)
					occ.EndsAt = &end
				}
				out = append(out, occ)
			}
		}
		cur = cur.AddDate(0, 0, stepDays)
	}
	return out, nil
}
