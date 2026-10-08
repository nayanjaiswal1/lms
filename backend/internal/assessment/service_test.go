package assessment

import (
	"encoding/json"
	"testing"
	"time"
)

func TestBreachedHardCap(t *testing.T) {
	def := DefaultProctoring() // MaxTabSwitches=3, MaxFocusLoss=5
	tests := []struct {
		name  string
		p     ProctoringConfig
		tally EventTally
		want  bool
	}{
		{"tab switch at cap", def, EventTally{"tab_switch": 3}, false},
		{"tab switch over cap", def, EventTally{"tab_switch": 4}, true},
		{"tab+visibility combined over cap", def, EventTally{"tab_switch": 2, "visibility_hidden": 2}, true},
		{"tab+visibility combined at cap", def, EventTally{"tab_switch": 1, "visibility_hidden": 2}, false},
		{"focus loss at cap", def, EventTally{"focus_loss": 5}, false},
		{"focus loss over cap", def, EventTally{"focus_loss": 6}, true},
		{"zero caps unlimited", ProctoringConfig{}, EventTally{"tab_switch": 100, "focus_loss": 100}, false},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := breachedHardCap(tc.p, tc.tally); got != tc.want {
				t.Fatalf("breachedHardCap = %v, want %v", got, tc.want)
			}
		})
	}
}

func TestAssertOpen(t *testing.T) {
	future := time.Now().Add(time.Hour)
	past := time.Now().Add(-time.Hour)

	cases := []struct {
		name string
		a    Assessment
		ok   bool
	}{
		{"draft closed", Assessment{Status: StatusDraft}, false},
		{"published open", Assessment{Status: StatusPublished}, true},
		{"archived closed", Assessment{Status: StatusArchived}, false},
		{"scheduled future closed", Assessment{Status: StatusScheduled, StartsAt: &future}, false},
		{"window ended closed", Assessment{Status: StatusActive, EndsAt: &past}, false},
		{"window active open", Assessment{Status: StatusActive, StartsAt: &past, EndsAt: &future}, true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			err := assertOpen(c.a)
			if c.ok && err != nil {
				t.Fatalf("want open, got %v", err)
			}
			if !c.ok && err == nil {
				t.Fatal("want closed, got open")
			}
		})
	}
}

func TestToStudentView_StripsAnswers(t *testing.T) {
	aq := AssessmentQuestion{
		ID: "aq1", QuestionID: "q1", Type: QuestionTypeMCQ, Title: "T", Points: 5,
		Content: rawJSON(MCQContent{
			Prompt:      "p",
			Options:     []MCQOption{{ID: "a", Text: "A", IsCorrect: true}, {ID: "b", Text: "B"}},
			Explanation: "secret reasoning",
		}),
	}
	sq, err := toStudentView(aq, false)
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]any
	if err := json.Unmarshal(sq.Content, &got); err != nil {
		t.Fatal(err)
	}
	if _, leaked := got["explanation"]; leaked {
		t.Fatal("explanation must not reach the student view")
	}
	opts, _ := got["options"].([]any)
	for _, o := range opts {
		if m, ok := o.(map[string]any); ok {
			if _, leaked := m["is_correct"]; leaked {
				t.Fatal("is_correct must not reach the student view")
			}
		}
	}
}

func TestToStudentView_HidesHiddenTestCases(t *testing.T) {
	aq := AssessmentQuestion{
		ID: "aq2", QuestionID: "q2", Type: QuestionTypeCoding, Title: "C", Points: 10,
		Content: rawJSON(CodingContent{
			Prompt:    "p",
			Languages: []string{"python"},
			TestCases: []TestCase{
				{ID: "t1", Stdin: "1", Expected: "1", Hidden: false},
				{ID: "t2", Stdin: "2", Expected: "2", Hidden: true},
			},
		}),
	}
	sq, err := toStudentView(aq, false)
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]any
	if err := json.Unmarshal(sq.Content, &got); err != nil {
		t.Fatal(err)
	}
	samples, _ := got["sample_cases"].([]any)
	if len(samples) != 1 {
		t.Fatalf("only the visible case should be exposed, got %d", len(samples))
	}
	if hc, _ := got["hidden_count"].(float64); hc != 1 {
		t.Fatalf("hidden_count should be 1, got %v", got["hidden_count"])
	}
}
