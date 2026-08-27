package digest

import (
	"fmt"
	"strings"

	"github.com/mindforge/backend/internal/activity"
)

var cadenceLabels = map[Cadence]string{
	CadenceDaily:   "Daily",
	CadenceD3:      "3-Day",
	CadenceWeekly:  "Weekly",
	CadenceMonthly: "Monthly",
}

// Subject builds the email subject from the cadences a digest merged — e.g.
// "Daily + Weekly Revision Digest" on a night both close together.
func Subject(cadences []Cadence) string {
	parts := make([]string, 0, len(cadences))
	for _, c := range cadences {
		if label, ok := cadenceLabels[c]; ok {
			parts = append(parts, label)
		}
	}
	if len(parts) == 0 {
		return "Revision Digest"
	}
	return strings.Join(parts, " + ") + " Revision Digest"
}

// PromptContext renders sources into the plain-text context handed to the AI
// provider as ai.CompletionRequest.UserPrompt — mirrors internal/revisionplan's
// rule that the generator only ever reasons from data actually gathered
// here, never invents activity.
func PromptContext(sources Sources) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Window: %s to %s\n\n", sources.WindowStart.Format("2006-01-02"), sources.WindowEnd.Format("2006-01-02"))

	if len(sources.NextTasks) > 0 {
		b.WriteString("Sheet tasks due or next up:\n")
		for _, t := range sources.NextTasks {
			fmt.Fprintf(&b, "- %s [%s]\n", t.Title, t.Status)
		}
		b.WriteString("\n")
	}

	if len(sources.DueCards) > 0 {
		fmt.Fprintf(&b, "Flashcards due for review (%d):\n", len(sources.DueCards))
		for _, c := range sources.DueCards {
			fmt.Fprintf(&b, "- %s\n", c.Front)
		}
		b.WriteString("\n")
	}

	if len(sources.Activity) == 0 {
		b.WriteString("No other recorded activity in this window.\n")
		return b.String()
	}

	b.WriteString("Activity:\n")
	for _, e := range sources.Activity {
		fmt.Fprintf(&b, "- [%s] %s: %s\n", e.OccurredAt.Format("2006-01-02"), e.Title, e.Summary)
	}
	return b.String()
}

// Render builds the final email subject/body. aiNarrative is the
// Gemini-written recap — empty whenever ai_status isn't "generated" (budget
// cap, provider outage, or a failed call). The deterministic sections below
// always render regardless: dropping the email entirely on an AI failure
// would break a student's streak habit at the worst possible moment (see
// internal/digest package doc and the plan's cost-control rationale), so
// Render's job is to always produce a sendable body, AI or not.
func Render(cadences []Cadence, sources Sources, aiNarrative string) (subject, body string) {
	var b strings.Builder

	if aiNarrative != "" {
		b.WriteString(strings.TrimSpace(aiNarrative))
		b.WriteString("\n\n")
	}

	if len(sources.NextTasks) > 0 {
		b.WriteString("Next up on your sheets:\n")
		for _, t := range sources.NextTasks {
			b.WriteString(fmt.Sprintf("- [%s] %s\n", t.Status, t.Title))
		}
		b.WriteString("\n")
	}

	if len(sources.DueCards) > 0 {
		// Front (the question) only — Back is the answer, and showing it in
		// an email would spoil the recall test the card exists for.
		b.WriteString(fmt.Sprintf("Cards due for review (%d):\n", len(sources.DueCards)))
		for _, c := range sources.DueCards {
			b.WriteString("- " + c.Front + "\n")
		}
		b.WriteString("\n")
	}

	if mistakes := filterByKind(sources.Activity, "annotation:mistake"); len(mistakes) > 0 {
		b.WriteString("Mistakes worth re-checking:\n")
		for _, e := range mistakes {
			b.WriteString("- " + e.Title + "\n")
		}
		b.WriteString("\n")
	}

	if reflections := filterByKind(sources.Activity, activity.KindReflection); len(reflections) > 0 {
		b.WriteString("Your notes from this window:\n")
		for _, e := range reflections {
			b.WriteString("- " + e.Title + ": " + e.Summary + "\n")
		}
		b.WriteString("\n")
	}

	if completions := filterOutKinds(sources.Activity, activity.KindReflection, "annotation:mistake"); len(completions) > 0 {
		b.WriteString("Also this window:\n")
		for _, e := range completions {
			b.WriteString("- " + e.Title + "\n")
		}
	}

	return Subject(cadences), strings.TrimSpace(b.String())
}

func filterByKind(entries []activity.Entry, kind string) []activity.Entry {
	out := make([]activity.Entry, 0, len(entries))
	for _, e := range entries {
		if e.Kind == kind {
			out = append(out, e)
		}
	}
	return out
}

func filterOutKinds(entries []activity.Entry, kinds ...string) []activity.Entry {
	excluded := make(map[string]bool, len(kinds))
	for _, k := range kinds {
		excluded[k] = true
	}
	out := make([]activity.Entry, 0, len(entries))
	for _, e := range entries {
		if !excluded[e.Kind] {
			out = append(out, e)
		}
	}
	return out
}
