package diary

import (
	"testing"

	"github.com/mindforge/backend/internal/habit"
)

func TestAllowedHabitMetadata(t *testing.T) {
	sleepHabit := habit.Habit{Type: habit.HabitTypeSleep}

	got := allowedHabitMetadata(sleepHabit, map[string]any{
		"slept_at": "23:30",
		"woke_up":  "07:00",
		"made_up":  "should be dropped",
	})
	if got["slept_at"] != "23:30" || got["woke_up"] != "07:00" {
		t.Fatalf("expected known sleep fields to pass through, got %v", got)
	}
	if _, ok := got["made_up"]; ok {
		t.Fatalf("expected unknown field to be dropped, got %v", got)
	}

	if got := allowedHabitMetadata(habit.Habit{Type: habit.HabitTypeGeneric}, map[string]any{"x": 1}); len(got) != 0 {
		t.Fatalf("generic habit has no fields, expected nothing to pass through, got %v", got)
	}

	if got := allowedHabitMetadata(sleepHabit, nil); got != nil {
		t.Fatalf("nil input should return nil, got %v", got)
	}
}
