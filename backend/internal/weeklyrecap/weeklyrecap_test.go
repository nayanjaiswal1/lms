package weeklyrecap

import (
	"strings"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/activity"
	"github.com/mindforge/backend/internal/habit"
)

// 2026-10-09 is a Friday.
var friday = time.Date(2026, 10, 9, 15, 0, 0, 0, time.UTC)

func TestCurrentStreak(t *testing.T) {
	daily := habit.Habit{Cadence: habit.CadenceDaily, TargetCount: 1}
	weekdays := habit.Habit{Cadence: habit.CadenceWeekly, TargetCount: 1, Weekdays: []int32{1, 3, 5}} // Mon, Wed, Fri
	weekly3 := habit.Habit{Cadence: habit.CadenceWeekly, TargetCount: 3}
	monthly := habit.Habit{Cadence: habit.CadenceMonthly, TargetCount: 1}

	cases := []struct {
		name string
		h    habit.Habit
		c    map[string]int
		want int
	}{
		{"daily run through today", daily, map[string]int{"2026-10-09": 1, "2026-10-08": 1, "2026-10-07": 1}, 3},
		{"daily today not yet done keeps the run", daily, map[string]int{"2026-10-08": 1, "2026-10-07": 1}, 2},
		{"daily gap breaks", daily, map[string]int{"2026-10-09": 1, "2026-10-07": 1}, 1},
		{"daily none", daily, map[string]int{}, 0},
		{"weekdays skip unscheduled days", weekdays, map[string]int{"2026-10-09": 1, "2026-10-07": 1, "2026-10-05": 1}, 3},
		{"weekdays missed scheduled day breaks", weekdays, map[string]int{"2026-10-09": 1, "2026-10-05": 1}, 1},
		{"weekly needs target count", weekly3, map[string]int{"2026-10-05": 3, "2026-09-28": 3, "2026-09-21": 2}, 2},
		{"weekly current week unmet keeps last week", weekly3, map[string]int{"2026-10-05": 1, "2026-09-28": 3}, 1},
		{"monthly counts any day in month", monthly, map[string]int{"2026-10-01": 1, "2026-09-01": 1, "2026-07-01": 1}, 2},
	}
	for _, tc := range cases {
		if got := CurrentStreak(tc.h, tc.c, friday); got != tc.want {
			t.Errorf("%s: got %d, want %d", tc.name, got, tc.want)
		}
	}
}

func TestStreaksOmitsInactiveHabits(t *testing.T) {
	habits := []habit.Habit{
		{ID: "a", Name: "Read", Cadence: habit.CadenceDaily, TargetCount: 1},
		{ID: "b", Name: "Gym", Cadence: habit.CadenceDaily, TargetCount: 1},
	}
	comps := []habit.Completion{{HabitID: "a", PeriodStart: "2026-10-09", Count: 1}}
	got := Streaks(habits, comps, friday)
	if len(got) != 1 || got[0].Name != "Read" || got[0].Streak != 1 {
		t.Fatalf("got %+v", got)
	}
}

func TestHasContentAndRender(t *testing.T) {
	if HasContent(map[string]int{"annotation:highlight": 5}, nil) {
		t.Error("untracked kinds and no streaks must not count as content")
	}
	counts := map[string]int{activity.KindModuleCompleted: 4, activity.KindCardReviewed: 1}
	streaks := []HabitStreak{{Name: "Read", Streak: 1, Cadence: habit.CadenceDaily}, {Name: "Gym", Streak: 3, Cadence: habit.CadenceWeekly}}
	if !HasContent(counts, nil) || !HasContent(nil, streaks) {
		t.Fatal("activity or streaks alone must count as content")
	}
	body := Render(counts, streaks)
	for _, want := range []string{"Lessons completed: 4", "Flashcards reviewed: 1", "Read: 1 day\n", "Gym: 3 weeks"} {
		if !strings.Contains(body+"\n", want) {
			t.Errorf("body missing %q:\n%s", want, body)
		}
	}
	if strings.Contains(body, "Quizzes") {
		t.Errorf("zero-count kinds must be omitted:\n%s", body)
	}
}
