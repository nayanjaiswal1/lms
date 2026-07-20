package revisionplan

import (
	"encoding/json"
	"fmt"
	"strings"
)

type aiTopic struct {
	ModuleID       *string `json:"module_id"`
	Title          string  `json:"title"`
	Reason         string  `json:"reason"`
	Recommendation string  `json:"recommendation"`
	Priority       int     `json:"priority"`
}

type aiResponse struct {
	Topics []aiTopic `json:"topics"`
}

// ParseTopics parses the AI's JSON response into validated Topic rows ready
// for Repo.ReplaceTopics. A topic missing a title, reason, or recommendation
// is dropped rather than stored half-formed; priority is clamped to the 1-5
// range the DB enforces. validModuleIDs is the exact set of module ids given
// to the model in the prompt (see BuildPrompt) — a claimed module_id outside
// that set is a hallucination and is nulled out rather than trusted, since it
// would otherwise fail the topics table's FK (or worse, silently point at an
// unrelated module if IDs were ever reused).
func ParseTopics(content string, validModuleIDs map[string]bool) ([]Topic, error) {
	var parsed aiResponse
	if err := json.Unmarshal([]byte(content), &parsed); err != nil {
		return nil, fmt.Errorf("revisionplan: parse ai response: %w", err)
	}

	topics := make([]Topic, 0, len(parsed.Topics))
	for i, t := range parsed.Topics {
		title := strings.TrimSpace(t.Title)
		reason := strings.TrimSpace(t.Reason)
		rec := strings.TrimSpace(t.Recommendation)
		if title == "" || reason == "" || rec == "" {
			continue
		}
		if len(title) > 200 {
			title = title[:200]
		}
		priority := t.Priority
		if priority < 1 {
			priority = 1
		}
		if priority > 5 {
			priority = 5
		}
		moduleID := t.ModuleID
		if moduleID != nil && !validModuleIDs[*moduleID] {
			moduleID = nil
		}
		topics = append(topics, Topic{
			ModuleID:       moduleID,
			Title:          title,
			Reason:         reason,
			Recommendation: rec,
			Priority:       priority,
			Position:       i,
		})
	}
	if len(topics) == 0 {
		return nil, fmt.Errorf("revisionplan: ai returned no usable topics")
	}
	return topics, nil
}

// BuildPrompt turns aggregated CourseSignals into the user prompt for
// ai.RevisionPlanSystemPrompt. Every module_id handed to the model here is
// echoed back into validModuleIDs by the caller (see
// jobs/handlers/llm.go's handleRevisionPlanGenerate) so ParseTopics can
// reject anything the model didn't actually see.
func BuildPrompt(signals CourseSignals) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Course: %s\n\n", signals.CourseTitle)
	for _, m := range signals.Modules {
		fmt.Fprintf(&b, "Lesson (module_id=%s): %s — %s\n", m.ModuleID, m.SectionTitle, m.Title)
		fmt.Fprintf(&b, "  Knowledge-check: %d/%d questions ever answered correctly, %d wrong attempts total\n",
			m.QuestionsEverCorrect, m.QuestionsTotal, m.WrongAttempts)
		if m.Reflection != "" {
			fmt.Fprintf(&b, "  Student's reflection: %q\n", m.Reflection)
		}
		b.WriteString("\n")
	}
	return b.String()
}
