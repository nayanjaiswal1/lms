package assessment

import (
	"context"
	"encoding/json"
	"testing"
)

func mustJSON(t *testing.T, v any) json.RawMessage {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	return b
}

// rawJSON marshals static test fixtures where an error is not possible.
func rawJSON(v any) json.RawMessage {
	b, _ := json.Marshal(v)
	return b
}

func singleMCQ() json.RawMessage {
	return rawJSON(MCQContent{
		Prompt:   "2+2?",
		Multiple: false,
		Options: []MCQOption{
			{ID: "a", Text: "3"},
			{ID: "b", Text: "4", IsCorrect: true},
			{ID: "c", Text: "5"},
		},
	})
}

func multiMCQ() json.RawMessage {
	return rawJSON(MCQContent{
		Prompt:   "Pick primes",
		Multiple: true,
		Options: []MCQOption{
			{ID: "a", Text: "2", IsCorrect: true},
			{ID: "b", Text: "3", IsCorrect: true},
			{ID: "c", Text: "4"},
			{ID: "d", Text: "9"},
		},
	})
}

func TestGradeMCQ_SingleCorrect(t *testing.T) {
	correct, pts, err := gradeMCQ(singleMCQ(), mustJSON(t, mcqAnswer{Selected: []string{"b"}}), 5)
	if err != nil {
		t.Fatal(err)
	}
	if !correct || pts != 5 {
		t.Fatalf("want correct/5, got %v/%v", correct, pts)
	}
}

func TestGradeMCQ_SingleWrong(t *testing.T) {
	correct, pts, _ := gradeMCQ(singleMCQ(), mustJSON(t, mcqAnswer{Selected: []string{"a"}}), 5)
	if correct || pts != 0 {
		t.Fatalf("want wrong/0, got %v/%v", correct, pts)
	}
}

func TestGradeMCQ_SingleMultipleSelectedRejected(t *testing.T) {
	// Selecting two options on a single-select question must not award credit.
	correct, pts, _ := gradeMCQ(singleMCQ(), mustJSON(t, mcqAnswer{Selected: []string{"a", "b"}}), 5)
	if correct || pts != 0 {
		t.Fatalf("want wrong/0, got %v/%v", correct, pts)
	}
}

func TestGradeMCQ_MultiPartial(t *testing.T) {
	// 1 of 2 correct chosen, 0 wrong → ratio 0.5 → 5 points, but not fully correct.
	correct, pts, _ := gradeMCQ(multiMCQ(), mustJSON(t, mcqAnswer{Selected: []string{"a"}}), 10)
	if correct {
		t.Fatal("partial answer must not be marked fully correct")
	}
	if pts != 5 {
		t.Fatalf("want 5 points, got %v", pts)
	}
}

func TestGradeMCQ_MultiPenalisesWrong(t *testing.T) {
	// 2 correct + 1 wrong → (2-1)/2 = 0.5 → 5 points.
	_, pts, _ := gradeMCQ(multiMCQ(), mustJSON(t, mcqAnswer{Selected: []string{"a", "b", "c"}}), 10)
	if pts != 5 {
		t.Fatalf("want 5 points, got %v", pts)
	}
}

func TestGradeMCQ_MultiAllCorrect(t *testing.T) {
	correct, pts, _ := gradeMCQ(multiMCQ(), mustJSON(t, mcqAnswer{Selected: []string{"a", "b"}}), 10)
	if !correct || pts != 10 {
		t.Fatalf("want correct/10, got %v/%v", correct, pts)
	}
}

func TestGradeMCQ_NoSelection(t *testing.T) {
	correct, pts, _ := gradeMCQ(multiMCQ(), nil, 10)
	if correct || pts != 0 {
		t.Fatalf("want wrong/0, got %v/%v", correct, pts)
	}
}

func TestGradeMCQ_EmptySliceSelection(t *testing.T) {
	// Explicit empty slice (not nil raw message) must score 0 without panicking.
	correct, pts, err := gradeMCQ(multiMCQ(), mustJSON(t, mcqAnswer{Selected: []string{}}), 10)
	if err != nil {
		t.Fatal(err)
	}
	if correct || pts != 0 {
		t.Fatalf("want wrong/0, got %v/%v", correct, pts)
	}
}

func TestGradeMCQ_MultiOverSelection(t *testing.T) {
	// Student picks all 4 options (2 correct + 2 wrong): (2-2)/2 = 0 → 0 points, clamped, never negative.
	_, pts, err := gradeMCQ(multiMCQ(), mustJSON(t, mcqAnswer{Selected: []string{"a", "b", "c", "d"}}), 10)
	if err != nil {
		t.Fatal(err)
	}
	if pts < 0 || pts > 10 {
		t.Fatalf("points must stay in [0, maxPoints], got %v", pts)
	}
	if pts != 0 {
		t.Fatalf("2 correct + 2 wrong → ratio 0, want 0 points, got %v", pts)
	}
}

func TestGradeCoding_EmptyTestCases(t *testing.T) {
	// A coding question with no test cases must return 0 points without panicking.
	exec := fakeExecutor{available: true, result: RunResult{
		Status: "passed", TestsTotal: 0, TestsPassed: 0, Cases: nil,
	}}
	emptyContent := rawJSON(CodingContent{
		Prompt:    "no tests",
		Languages: []string{"python"},
		TestCases: []TestCase{},
	})
	answer := mustJSON(t, codingAnswer{Language: "python", Code: "pass"})
	graded, correct, pts, _, _, _, err := gradeCoding(context.Background(), exec, emptyContent, answer, 10)
	if err != nil {
		t.Fatal(err)
	}
	if !graded {
		t.Fatal("empty test cases must still be considered graded (not deferred)")
	}
	if correct {
		t.Fatal("empty test cases must not mark submission as fully correct")
	}
	if pts != 0 {
		t.Fatalf("empty test cases must award 0 points, got %v", pts)
	}
}

// fakeExecutor returns a fixed run result for coding-grade tests.
type fakeExecutor struct {
	available bool
	result    RunResult
	err       error
}

func (f fakeExecutor) Available() bool { return f.available }
func (f fakeExecutor) Run(context.Context, string, string, CodingContent) (RunResult, error) {
	return f.result, f.err
}

func codingContent() json.RawMessage {
	return rawJSON(CodingContent{
		Prompt:    "echo",
		Languages: []string{"python"},
		TestCases: []TestCase{
			{ID: "t1", Stdin: "1", Expected: "1", Weight: 1},
			{ID: "t2", Stdin: "2", Expected: "2", Hidden: true, Weight: 3},
		},
	})
}

func TestGradeCoding_ExecutorUnavailable(t *testing.T) {
	answer := mustJSON(t, codingAnswer{Language: "python", Code: "print(input())"})
	graded, _, _, _, _, _, err := gradeCoding(context.Background(), unavailableExecutor{}, codingContent(), answer, 10)
	if err != nil {
		t.Fatal(err)
	}
	if graded {
		t.Fatal("unavailable executor must defer grading (graded=false)")
	}
}

func TestGradeCoding_WeightedPass(t *testing.T) {
	// t1 (w1) passes, t2 (w3) fails → 1/4 of points.
	exec := fakeExecutor{available: true, result: RunResult{
		Status: "failed", TestsTotal: 2, TestsPassed: 1,
		Cases: []CaseResult{{CaseID: "t1", Passed: true, Weight: 1}, {CaseID: "t2", Passed: false, Weight: 3}},
	}}
	answer := mustJSON(t, codingAnswer{Language: "python", Code: "x"})
	graded, correct, pts, _, _, _, err := gradeCoding(context.Background(), exec, codingContent(), answer, 8)
	if err != nil {
		t.Fatal(err)
	}
	if !graded || correct {
		t.Fatalf("want graded and not fully correct, got graded=%v correct=%v", graded, correct)
	}
	if pts != 2 { // 1/4 * 8
		t.Fatalf("want 2 points, got %v", pts)
	}
}

func TestGradeCoding_AllPass(t *testing.T) {
	exec := fakeExecutor{available: true, result: RunResult{
		Status: "passed", TestsTotal: 2, TestsPassed: 2,
		Cases: []CaseResult{{CaseID: "t1", Passed: true, Weight: 1}, {CaseID: "t2", Passed: true, Weight: 3}},
	}}
	answer := mustJSON(t, codingAnswer{Language: "python", Code: "x"})
	_, correct, pts, _, _, _, _ := gradeCoding(context.Background(), exec, codingContent(), answer, 8)
	if !correct || pts != 8 {
		t.Fatalf("want correct/8, got %v/%v", correct, pts)
	}
}

func TestGradeCoding_EmptyCodeFailsClosed(t *testing.T) {
	graded, correct, pts, _, _, _, _ := gradeCoding(context.Background(), fakeExecutor{available: true}, codingContent(), mustJSON(t, codingAnswer{Language: "python"}), 8)
	if !graded || correct || pts != 0 {
		t.Fatalf("empty code must grade as 0, got graded=%v correct=%v pts=%v", graded, correct, pts)
	}
}
