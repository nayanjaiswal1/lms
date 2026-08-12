package habit

import (
	"context"
	"errors"
	"strings"
	"time"
)

var (
	ErrNameEmpty            = errors.New("habit: name is required")
	ErrNameTooLong          = errors.New("habit: name exceeds 60 characters")
	ErrInvalidCadence       = errors.New("habit: invalid cadence")
	ErrInvalidMonth         = errors.New("habit: month must be formatted YYYY-MM")
	ErrInvalidPeriod        = errors.New("habit: period must be formatted YYYY-MM-DD")
	ErrFuturePeriod         = errors.New("habit: cannot log a completion for a period that hasn't happened yet")
	ErrInvalidColor         = errors.New("habit: invalid color")
	ErrInvalidTarget        = errors.New("habit: target_count must be between 1 and 7")
	ErrInvalidWeekday       = errors.New("habit: weekdays must be unique values between 0 and 6")
	ErrConflictingModes     = errors.New("habit: target_count and weekdays are mutually exclusive weekly modes")
	ErrInvalidHabitType     = errors.New("habit: invalid type")
	ErrCustomFieldsEmpty    = errors.New("habit: custom habits need at least one field")
	ErrTooManyCustomFields  = errors.New("habit: custom habits allow at most 8 fields")
	ErrCustomFieldInvalid   = errors.New("habit: each custom field needs a unique key, a label, and a valid kind")
	ErrHabitHasNoFields     = errors.New("habit: this habit type has no entry fields")
	ErrInvalidMetadataField = errors.New("habit: metadata contains a field not defined for this habit")
	ErrInvalidIcon          = errors.New("habit: invalid icon")
	ErrTooManyTags          = errors.New("habit: at most 6 tags per habit")
	ErrTagTooLong           = errors.New("habit: each tag must not exceed 24 characters")
)

const maxNameLength = 60
const maxCustomFieldLabelLength = 60
const maxCustomFields = 8
const maxTags = 6
const maxTagLength = 24

// builtinMetadataFields is the fixed field set for each non-custom,
// non-generic habit type — the server-side mirror of frontend/lib/habits/
// type-schemas.ts, so metadata is validated even if a client sends something
// the UI would never produce.
var builtinMetadataFields = map[HabitType][]string{
	HabitTypeGym:     {"workout_type", "exercise", "sets", "duration_minutes", "intensity", "notes"},
	HabitTypeSleep:   {"slept_at", "woke_up", "quality"},
	HabitTypeReading: {"book", "pages", "takeaway"},
}

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

func (s *Service) Create(ctx context.Context, userID string, req CreateRequest) (Habit, error) {
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return Habit{}, ErrNameEmpty
	}
	if len(req.Name) > maxNameLength {
		return Habit{}, ErrNameTooLong
	}
	if !validCadence(req.Cadence) {
		return Habit{}, ErrInvalidCadence
	}
	if req.TargetCount == 0 {
		req.TargetCount = 1
	}
	if err := validateWeeklyOptions(req.Cadence, req.TargetCount, req.Weekdays); err != nil {
		return Habit{}, err
	}
	if req.Type == "" {
		req.Type = HabitTypeGeneric
	}
	if !validHabitType(req.Type) {
		return Habit{}, ErrInvalidHabitType
	}
	if req.Type == HabitTypeCustom {
		if err := validateCustomFields(req.CustomFields); err != nil {
			return Habit{}, err
		}
	} else {
		req.CustomFields = nil
	}
	if !validIcon(req.Icon) {
		return Habit{}, ErrInvalidIcon
	}
	cleanedTags, err := normalizeTags(req.Tags)
	if err != nil {
		return Habit{}, err
	}
	req.Tags = cleanedTags
	return s.repo.Create(ctx, userID, req)
}

// normalizeTags trims each tag, drops empties, caps length, and dedupes
// case-insensitively (keeping the first-seen casing) — the filter chips key
// off lowercase, so "Health" and "health" on one habit would otherwise
// render as two indistinguishable chips.
func normalizeTags(tags []string) ([]string, error) {
	if len(tags) > maxTags {
		return nil, ErrTooManyTags
	}
	seen := make(map[string]bool, len(tags))
	cleaned := make([]string, 0, len(tags))
	for _, t := range tags {
		t = strings.TrimSpace(t)
		if t == "" {
			continue
		}
		if len(t) > maxTagLength {
			return nil, ErrTagTooLong
		}
		key := strings.ToLower(t)
		if seen[key] {
			continue
		}
		seen[key] = true
		cleaned = append(cleaned, t)
	}
	return cleaned, nil
}

// validateCustomFields enforces a non-empty, size-capped, key-unique field
// set for a "custom" habit — the entry form's schema comes straight from
// this array, so an invalid one would produce a broken or duplicate form.
func validateCustomFields(fields []CustomField) error {
	if len(fields) == 0 {
		return ErrCustomFieldsEmpty
	}
	if len(fields) > maxCustomFields {
		return ErrTooManyCustomFields
	}
	seen := make(map[string]bool, len(fields))
	for _, f := range fields {
		key := strings.TrimSpace(f.Key)
		label := strings.TrimSpace(f.Label)
		if key == "" || label == "" || len(label) > maxCustomFieldLabelLength || !validCustomFieldKind(f.Kind) {
			return ErrCustomFieldInvalid
		}
		if seen[key] {
			return ErrCustomFieldInvalid
		}
		seen[key] = true
	}
	return nil
}

// allowedMetadataKeys returns the set of metadata keys a habit's type
// permits, or ErrHabitHasNoFields if it has none (generic, or an unknown
// stored type).
func allowedMetadataKeys(h Habit) (map[string]bool, error) {
	if h.Type == HabitTypeCustom {
		keys := make(map[string]bool, len(h.CustomFields))
		for _, f := range h.CustomFields {
			keys[f.Key] = true
		}
		return keys, nil
	}
	fields, ok := builtinMetadataFields[h.Type]
	if !ok {
		return nil, ErrHabitHasNoFields
	}
	keys := make(map[string]bool, len(fields))
	for _, f := range fields {
		keys[f] = true
	}
	return keys, nil
}

// validateWeeklyOptions enforces that TargetCount and Weekdays only ever
// apply to a weekly habit, and that the two weekly modes never combine —
// "any N times a week" (TargetCount > 1) and "specific weekdays" (Weekdays
// non-empty) are alternatives, not stackable settings.
func validateWeeklyOptions(cadence Cadence, targetCount int, weekdays []int32) error {
	if cadence != CadenceWeekly {
		if targetCount != 1 || len(weekdays) > 0 {
			return ErrConflictingModes
		}
		return nil
	}
	if targetCount < 1 || targetCount > 7 {
		return ErrInvalidTarget
	}
	if len(weekdays) == 0 {
		return nil
	}
	if targetCount != 1 {
		return ErrConflictingModes
	}
	seen := make(map[int32]bool, len(weekdays))
	for _, d := range weekdays {
		if d < 0 || d > 6 || seen[d] {
			return ErrInvalidWeekday
		}
		seen[d] = true
	}
	return nil
}

func (s *Service) Delete(ctx context.Context, userID, habitID string) error {
	return s.repo.Delete(ctx, habitID, userID)
}

// Update validates and applies a partial change to a habit's color, icon,
// and/or tags — see UpdateRequest and Repo.Update for why changing these
// "current" attributes never rewrites any other habit_completions row, so
// previous months' tracking data stays exactly as it was.
func (s *Service) Update(ctx context.Context, userID, habitID string, req UpdateRequest) error {
	if req.Color != nil && !validColor(*req.Color) {
		return ErrInvalidColor
	}
	if req.Icon != nil && !validIcon(*req.Icon) {
		return ErrInvalidIcon
	}
	if req.Tags != nil {
		cleaned, err := normalizeTags(*req.Tags)
		if err != nil {
			return err
		}
		req.Tags = &cleaned
	}
	return s.repo.Update(ctx, habitID, userID, req)
}

// MonthView parses month ("2026-08") and returns every habit plus every
// completion whose period overlaps that month — including a weekly row whose
// Monday falls in the prior month but whose week still spans into this one.
func (s *Service) MonthView(ctx context.Context, userID, month string) (MonthView, error) {
	monthStart, err := time.Parse("2006-01", month)
	if err != nil {
		return MonthView{}, ErrInvalidMonth
	}
	monthEnd := monthStart.AddDate(0, 1, -1)
	rangeStart := mondayOfWeek(monthStart)

	habits, completions, err := s.repo.ListForRange(ctx, userID, rangeStart, monthEnd)
	if err != nil {
		return MonthView{}, err
	}
	return MonthView{Habits: habits, Completions: completions}, nil
}

func (s *Service) SetCompletion(ctx context.Context, userID, habitID, period string) error {
	periodStart, err := time.Parse("2006-01-02", period)
	if err != nil {
		return ErrInvalidPeriod
	}
	return s.repo.SetCompletion(ctx, habitID, userID, periodStart)
}

func (s *Service) ClearCompletion(ctx context.Context, userID, habitID, period string) error {
	periodStart, err := time.Parse("2006-01-02", period)
	if err != nil {
		return ErrInvalidPeriod
	}
	return s.repo.ClearCompletion(ctx, habitID, userID, periodStart)
}

// SetCompletionMetadata saves periodStart's structured entry for a
// user-owned habit, after checking every submitted key against that habit's
// type schema (built-in fields for gym/sleep/reading, CustomFields for
// custom) — the jsonb column itself doesn't constrain shape, so this is the
// actual input-boundary validation.
func (s *Service) SetCompletionMetadata(ctx context.Context, userID, habitID, period string, metadata map[string]any) error {
	periodStart, err := time.Parse("2006-01-02", period)
	if err != nil {
		return ErrInvalidPeriod
	}
	h, err := s.repo.Get(ctx, habitID, userID)
	if err != nil {
		return err
	}
	allowed, err := allowedMetadataKeys(h)
	if err != nil {
		return err
	}
	for k := range metadata {
		if !allowed[k] {
			return ErrInvalidMetadataField
		}
	}
	return s.repo.UpsertCompletionMetadata(ctx, habitID, userID, periodStart, metadata)
}

// mondayOfWeek returns the Monday on or before d — the ISO week start. A
// month that doesn't start on Monday needs this so the weekly section's first
// row (shared with the tail of the previous month) is still included.
func mondayOfWeek(d time.Time) time.Time {
	offset := (int(d.Weekday()) + 6) % 7 // days since Monday; Sunday=0 -> 6
	return d.AddDate(0, 0, -offset)
}
