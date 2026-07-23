package certificates

import (
	"testing"

	"github.com/mindforge/backend/internal/assessment"
)

// TestToStudentQuestions_StripsGradingFields guards the one thing this
// function must never regress on: leaking an answer key or grading secret to
// the client that will take the test.
func TestToStudentQuestions_StripsGradingFields(t *testing.T) {
	qs := []Question{
		{
			ID: "q1", Type: QuestionMCQ, Points: 5,
			MCQ: &assessment.MCQContent{
				Prompt: "2+2?",
				Options: []assessment.MCQOption{
					{ID: "a", Text: "3"},
					{ID: "b", Text: "4", IsCorrect: true},
				},
			},
		},
		{
			ID: "q2", Type: QuestionCoding, Points: 10,
			Coding: &assessment.CodingContent{
				Prompt: "reverse a string",
				TestCases: []assessment.TestCase{
					{ID: "t1", Stdin: "abc", Expected: "cba", Hidden: false, Weight: 1},
					{ID: "t2", Stdin: "secret-input", Expected: "secret-output", Hidden: true, Weight: 2},
				},
				VerifyFiles:   map[string]string{"test_app.py": "..."},
				VerifyCommand: "pytest --junitxml=/tmp/x.xml",
			},
		},
	}

	out := toStudentQuestions(qs)
	if len(out) != 2 {
		t.Fatalf("expected 2 questions, got %d", len(out))
	}

	for _, opt := range out[0].MCQ.Options {
		if opt.IsCorrect {
			t.Errorf("mcq option %s: IsCorrect leaked to student view", opt.ID)
		}
	}

	coding := out[1].Coding
	if coding.VerifyFiles != nil {
		t.Errorf("coding question: VerifyFiles leaked to student view")
	}
	if coding.VerifyCommand != "" {
		t.Errorf("coding question: VerifyCommand leaked to student view")
	}
	for _, tc := range coding.TestCases {
		if tc.Hidden && (tc.Stdin != "" || tc.Expected != "") {
			t.Errorf("hidden test case %s: Stdin/Expected leaked to student view", tc.ID)
		}
		if !tc.Hidden && (tc.Stdin != "abc" || tc.Expected != "cba") {
			t.Errorf("visible test case %s: unexpected content %q/%q", tc.ID, tc.Stdin, tc.Expected)
		}
	}
}
