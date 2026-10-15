// Package weeklyrecap builds the Sunday "your week" email: per-kind activity
// counts for the last 7 days plus current habit streaks. This file and
// render.go are pure (no I/O) so they unit-test without a database; the DB
// reads live in activity.Repo.CountByKind and habit.Repo.ListForRange, and the
// fan-out/worker jobs in internal/jobs/handlers.
package weeklyrecap

import (
	"time"

	"github.com/mindforge/backend/internal/habit"
)

const (
	dateLayout  = "2006-01-02"
	monthLayout = "2006-01"
	// MaxStreakLookbackDays bounds both the completions fetch and the streak
	// walk; a streak longer than this reports as exactly this many periods.
	MaxStreakLookbackDays = 366
)

// CurrentStreak returns the number of consecutive completed periods of h
// ending at today. The period still in progress never breaks a streak — a
// daily habit not yet ticked today keeps yesterday's streak alive until
// today ends. completions maps period_start ("2006-01-02") to its count.
//
//   - daily, and weekly "specific weekdays": walks days backwards, skipping
//     days the habit is not scheduled for.
//   - weekly "any N times": walks Monday-based weeks, done at count >= TargetCount.
//   - monthly: walks calendar months, done at any completion in the month.
func CurrentStreak(h habit.Habit, completions map[string]int, today time.Time) int {
	today = today.UTC().Truncate(24 * time.Hour)
	switch {
	case h.Cadence == habit.CadenceMonthly:
		return monthlyStreak(completions, today)
	case h.Cadence == habit.CadenceWeekly && len(h.Weekdays) == 0:
		return weeklyStreak(completions, today, h.TargetCount)
	default:
		return dailyStreak(completions, today, scheduledWeekdays(h))
	}
}

func scheduledWeekdays(h habit.Habit) map[time.Weekday]bool {
	if len(h.Weekdays) == 0 {
		return nil // every day
	}
	out := make(map[time.Weekday]bool, len(h.Weekdays))
	for _, d := range h.Weekdays {
		out[time.Weekday(d)] = true
	}
	return out
}

func dailyStreak(completions map[string]int, today time.Time, scheduled map[time.Weekday]bool) int {
	streak := 0
	for i := 0; i < MaxStreakLookbackDays; i++ {
		day := today.AddDate(0, 0, -i)
		if scheduled != nil && !scheduled[day.Weekday()] {
			continue
		}
		if completions[day.Format(dateLayout)] > 0 {
			streak++
		} else if i > 0 {
			break
		}
	}
	return streak
}

func weeklyStreak(completions map[string]int, today time.Time, target int) int {
	if target < 1 {
		target = 1
	}
	monday := today.AddDate(0, 0, -((int(today.Weekday()) + 6) % 7))
	streak := 0
	for i := 0; i < MaxStreakLookbackDays/7; i++ {
		week := monday.AddDate(0, 0, -7*i)
		if completions[week.Format(dateLayout)] >= target {
			streak++
		} else if i > 0 {
			break
		}
	}
	return streak
}

func monthlyStreak(completions map[string]int, today time.Time) int {
	months := make(map[string]bool, len(completions))
	for period, n := range completions {
		if n > 0 && len(period) >= len(monthLayout) {
			months[period[:len(monthLayout)]] = true
		}
	}
	first := time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC)
	streak := 0
	for i := 0; i < MaxStreakLookbackDays/30; i++ {
		if months[first.AddDate(0, -i, 0).Format(monthLayout)] {
			streak++
		} else if i > 0 {
			break
		}
	}
	return streak
}

// HabitStreak is one habit's current streak, for rendering.
type HabitStreak struct {
	Name    string
	Streak  int
	Cadence habit.Cadence
}

// Streaks returns the active (>0) streaks for habits, in input order.
func Streaks(habits []habit.Habit, completions []habit.Completion, today time.Time) []HabitStreak {
	byHabit := make(map[string]map[string]int, len(habits))
	for _, c := range completions {
		if byHabit[c.HabitID] == nil {
			byHabit[c.HabitID] = map[string]int{}
		}
		byHabit[c.HabitID][c.PeriodStart] = c.Count
	}
	out := []HabitStreak{}
	for _, h := range habits {
		if n := CurrentStreak(h, byHabit[h.ID], today); n > 0 {
			out = append(out, HabitStreak{Name: h.Name, Streak: n, Cadence: h.Cadence})
		}
	}
	return out
}
