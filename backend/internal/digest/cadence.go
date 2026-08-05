package digest

import "time"

// DueCadences reports which periodic cadences (d3/weekly/monthly — "daily"
// is decided separately by MergeCadences) close on today, given anchorDate —
// the user's very first digest_date. Anchoring per-user rather than to a
// fixed calendar epoch means cohorts who join on different days don't all
// receive their weekly/monthly digest on the same night, spreading the AI
// call volume out instead of spiking it once a week. anchorDate.IsZero()
// (no prior digest at all) always returns no periodic cadence — a student's
// first-ever digest is daily-only by construction, since day 0 divides
// evenly by everything and would otherwise wrongly fire every cadence at
// once.
func DueCadences(anchorDate, today time.Time) []Cadence {
	if anchorDate.IsZero() {
		return nil
	}
	days := daysBetween(anchorDate, today)
	if days <= 0 {
		return nil
	}
	var out []Cadence
	if days%3 == 0 {
		out = append(out, CadenceD3)
	}
	if days%7 == 0 {
		out = append(out, CadenceWeekly)
	}
	if days%30 == 0 {
		out = append(out, CadenceMonthly)
	}
	return out
}

func daysBetween(from, to time.Time) int {
	from = from.Truncate(24 * time.Hour)
	to = to.Truncate(24 * time.Hour)
	return int(to.Sub(from).Hours() / 24)
}

// MergeCadences decides tonight's full cadence list. hasActivityToday gates
// "daily" specifically — a nightly recap of a day with nothing recorded is
// noise a student will learn to ignore. The periodic cadences in due apply
// regardless of today's activity: a weekly digest still covers a genuine
// 7-day window even when today itself was quiet. Combined with due cadences
// from DueCadences, this is also where the "multiple cadences due the same
// night merge into one email" rule actually happens — the caller sends
// however many cadences come back from here as exactly one digest, never one
// per cadence.
func MergeCadences(hasActivityToday bool, due []Cadence) []Cadence {
	var out []Cadence
	if hasActivityToday {
		out = append(out, CadenceDaily)
	}
	out = append(out, due...)
	return out
}

// ShouldSend reports whether tonight's merged cadence list is worth sending
// — false means "no activity today and nothing periodic due", the one case
// where no digest (not even a fallback one) goes out.
func ShouldSend(cadences []Cadence) bool {
	return len(cadences) > 0
}

// WindowFor returns the [start, end) range covering every cadence in
// cadences — end is always now, start is the earliest lookback among them,
// since the daily cadence's 1-day window is always a subset of any periodic
// cadence's wider one. One GatherSources call this way satisfies every
// cadence due the same night instead of one query per cadence.
func WindowFor(cadences []Cadence, now time.Time) (start, end time.Time) {
	maxDays := 1
	for _, c := range cadences {
		if d := c.PeriodDays(); d > maxDays {
			maxDays = d
		}
	}
	return now.AddDate(0, 0, -maxDays), now
}
