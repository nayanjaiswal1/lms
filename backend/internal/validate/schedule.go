// Package validate holds shared input-validation helpers used at the
// boundary (handlers and services) before any DB or AI call.
package validate

import "time"

// scheduleEndMessage is the single canonical message for an end date that
// does not fall after its start date.
const scheduleEndMessage = "End date must be after start date."

// CheckRange validates the shared starts_at/ends_at ordering rule: when both
// are set, endsAt must be strictly after startsAt. Violations are recorded
// in fields["ends_at"] so callers can return them via
// httputil.WriteFieldErrors alongside their other field errors.
func CheckRange(startsAt, endsAt *time.Time, fields map[string]string) {
	if endsAt != nil && startsAt != nil && !endsAt.After(*startsAt) {
		fields["ends_at"] = scheduleEndMessage
	}
}

// ValidRange reports whether end is strictly after start.
func ValidRange(start, end time.Time) bool {
	return end.After(start)
}

// ValidOptionalRange reports whether an optional end time is valid against
// start: a nil end is always valid, otherwise it must be strictly after
// start. Services keep their own sentinel-wrapped error messages and use
// this for the ordering predicate only.
func ValidOptionalRange(start time.Time, end *time.Time) bool {
	return end == nil || end.After(start)
}
