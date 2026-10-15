package weeklyrecap

import (
	"fmt"
	"strings"

	"github.com/mindforge/backend/internal/activity"
	"github.com/mindforge/backend/internal/habit"
)

// Subject is the recap email subject.
const Subject = "Your week on MindForge"

// kindOrder fixes the display order and labels of activity kinds; kinds
// missing from it (e.g. highlight/mistake annotations) are not shown.
var kindOrder = []struct{ Kind, Label string }{
	{activity.KindModuleCompleted, "Lessons completed"},
	{activity.KindCourseCompleted, "Courses completed"},
	{activity.KindQuizAttempt, "Quizzes taken"},
	{activity.KindLabCompleted, "Labs completed"},
	{activity.KindSheetSolved, "Sheet problems solved"},
	{activity.KindCardReviewed, "Flashcards reviewed"},
	{activity.KindReflection, "Reflections written"},
}

var cadenceUnit = map[habit.Cadence]string{
	habit.CadenceDaily:   "day",
	habit.CadenceWeekly:  "week",
	habit.CadenceMonthly: "month",
}

// HasContent reports whether a recap is worth sending: any activity in the
// window or any active streak.
func HasContent(counts map[string]int, streaks []HabitStreak) bool {
	return len(streaks) > 0 || total(counts) > 0
}

func total(counts map[string]int) int {
	n := 0
	for _, o := range kindOrder {
		n += counts[o.Kind]
	}
	return n
}

// Render builds the plain-text body, matching the digest email's format.
func Render(counts map[string]int, streaks []HabitStreak) string {
	var b strings.Builder
	b.WriteString("Here is your last 7 days.\n\n")

	if total(counts) > 0 {
		b.WriteString("Activity:\n")
		for _, o := range kindOrder {
			if n := counts[o.Kind]; n > 0 {
				fmt.Fprintf(&b, "- %s: %d\n", o.Label, n)
			}
		}
		b.WriteString("\n")
	}

	if len(streaks) > 0 {
		b.WriteString("Habit streaks:\n")
		for _, s := range streaks {
			unit := cadenceUnit[s.Cadence]
			plural := "s"
			if s.Streak == 1 {
				plural = ""
			}
			fmt.Fprintf(&b, "- %s: %d %s%s\n", s.Name, s.Streak, unit, plural)
		}
	}
	return strings.TrimSpace(b.String())
}
