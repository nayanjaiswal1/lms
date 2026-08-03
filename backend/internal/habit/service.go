package habit

import (
	"context"
	"errors"
	"strings"
	"time"
)

var (
	ErrNameEmpty        = errors.New("habit: name is required")
	ErrNameTooLong      = errors.New("habit: name exceeds 60 characters")
	ErrInvalidCadence   = errors.New("habit: invalid cadence")
	ErrInvalidMonth     = errors.New("habit: month must be formatted YYYY-MM")
	ErrInvalidPeriod    = errors.New("habit: period must be formatted YYYY-MM-DD")
	ErrInvalidColor     = errors.New("habit: invalid color")
	ErrInvalidTarget    = errors.New("habit: target_count must be between 1 and 7")
	ErrInvalidWeekday   = errors.New("habit: weekdays must be unique values between 0 and 6")
	ErrConflictingModes = errors.New("habit: target_count and weekdays are mutually exclusive weekly modes")
)

const maxNameLength = 60

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
	return s.repo.Create(ctx, userID, req)
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

func (s *Service) UpdateColor(ctx context.Context, userID, habitID string, color Color) error {
	if !validColor(color) {
		return ErrInvalidColor
	}
	return s.repo.UpdateColor(ctx, habitID, userID, color)
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

// mondayOfWeek returns the Monday on or before d — the ISO week start. A
// month that doesn't start on Monday needs this so the weekly section's first
// row (shared with the tail of the previous month) is still included.
func mondayOfWeek(d time.Time) time.Time {
	offset := (int(d.Weekday()) + 6) % 7 // days since Monday; Sunday=0 -> 6
	return d.AddDate(0, 0, -offset)
}
