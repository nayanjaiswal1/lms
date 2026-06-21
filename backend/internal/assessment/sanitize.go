package assessment

import (
	"encoding/json"
	"math/rand"
)

// StudentQuestion is the safe, gradable-content-stripped view served to a test
// taker. It never contains correct flags, explanations, or hidden test cases.
type StudentQuestion struct {
	AssessmentQuestionID string          `json:"assessment_question_id"`
	QuestionID           string          `json:"question_id"`
	Type                 string          `json:"type"`
	Title                string          `json:"title"`
	Difficulty           string          `json:"difficulty"`
	Position             int             `json:"position"`
	Points               float64         `json:"points"`
	Content              json.RawMessage `json:"content"`
}

// toStudentView converts a stored question into the sanitized student payload.
// shuffleOptions randomises MCQ option order when the assessment requests it.
func toStudentView(aq AssessmentQuestion, shuffleOptions bool) (StudentQuestion, error) {
	sq := StudentQuestion{
		AssessmentQuestionID: aq.ID,
		QuestionID:           aq.QuestionID,
		Type:                 aq.Type,
		Title:                aq.Title,
		Difficulty:           aq.Difficulty,
		Position:             aq.Position,
		Points:               aq.Points,
	}

	switch aq.Type {
	case QuestionTypeMCQ:
		var c MCQContent
		if err := json.Unmarshal(aq.Content, &c); err != nil {
			return StudentQuestion{}, err
		}
		opts := make([]map[string]string, 0, len(c.Options))
		for _, o := range c.Options {
			opts = append(opts, map[string]string{"id": o.ID, "text": o.Text})
		}
		if shuffleOptions {
			rand.Shuffle(len(opts), func(i, j int) { opts[i], opts[j] = opts[j], opts[i] })
		}
		safe := map[string]any{
			"prompt":   c.Prompt,
			"multiple": c.Multiple,
			"options":  opts,
		}
		raw, err := json.Marshal(safe)
		if err != nil {
			return StudentQuestion{}, err
		}
		sq.Content = raw

	case QuestionTypeCoding:
		var c CodingContent
		if err := json.Unmarshal(aq.Content, &c); err != nil {
			return StudentQuestion{}, err
		}
		// Only sample (non-hidden) cases are exposed; hidden cases stay server-side.
		samples := make([]map[string]string, 0)
		for _, tc := range c.TestCases {
			if !tc.Hidden {
				samples = append(samples, map[string]string{"stdin": tc.Stdin, "expected": tc.Expected})
			}
		}
		safe := map[string]any{
			"prompt":          c.Prompt,
			"languages":       c.Languages,
			"starter_code":    c.StarterCode,
			"time_limit_ms":   c.TimeLimitMs,
			"memory_limit_kb": c.MemoryLimitKb,
			"sample_cases":    samples,
			"hidden_count":    len(c.TestCases) - len(samples),
		}
		raw, err := json.Marshal(safe)
		if err != nil {
			return StudentQuestion{}, err
		}
		sq.Content = raw

	case QuestionTypeSubjective:
		var c SubjectiveContent
		if err := json.Unmarshal(aq.Content, &c); err != nil {
			return StudentQuestion{}, err
		}
		// reference_answer and expected_topics are server-only — never exposed to students.
		safe := map[string]any{
			"prompt": c.Prompt,
		}
		raw, err := json.Marshal(safe)
		if err != nil {
			return StudentQuestion{}, err
		}
		sq.Content = raw

	default:
		sq.Content = json.RawMessage(`{}`)
	}

	return sq, nil
}
