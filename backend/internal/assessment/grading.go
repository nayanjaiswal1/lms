package assessment

import (
	"context"
	"encoding/json"
	"fmt"
)

// mcqAnswer is the student's MCQ selection payload.
type mcqAnswer struct {
	Selected []string `json:"selected"`
}

// codingAnswer is the student's coding submission payload.
type codingAnswer struct {
	Language string `json:"language"`
	Code     string `json:"code"`
}

// gradeMCQ scores a single MCQ answer against its version content.
//
// Single-select: full points only if the one correct option is the sole selection.
// Multi-select:  proportional credit = (correctChosen − incorrectChosen) / totalCorrect,
//                clamped to [0,1], so guessing every option cannot pass.
func gradeMCQ(content, answer json.RawMessage, maxPoints float64) (bool, float64, error) {
	var c MCQContent
	if err := json.Unmarshal(content, &c); err != nil {
		return false, 0, fmt.Errorf("assessment: decode mcq content: %w", err)
	}
	var a mcqAnswer
	if len(answer) > 0 {
		if err := json.Unmarshal(answer, &a); err != nil {
			return false, 0, fmt.Errorf("assessment: decode mcq answer: %w", err)
		}
	}

	correct := map[string]bool{}
	totalCorrect := 0
	for _, o := range c.Options {
		if o.IsCorrect {
			correct[o.ID] = true
			totalCorrect++
		}
	}
	if totalCorrect == 0 {
		return false, 0, nil // misconfigured question grades as zero, never panics
	}

	selected := map[string]bool{}
	for _, id := range a.Selected {
		selected[id] = true
	}

	if !c.Multiple {
		isCorrect := len(a.Selected) == 1 && correct[a.Selected[0]]
		if isCorrect {
			return true, maxPoints, nil
		}
		return false, 0, nil
	}

	correctChosen, incorrectChosen := 0, 0
	for id := range selected {
		if correct[id] {
			correctChosen++
		} else {
			incorrectChosen++
		}
	}
	ratio := float64(correctChosen-incorrectChosen) / float64(totalCorrect)
	if ratio < 0 {
		ratio = 0
	}
	fullyCorrect := correctChosen == totalCorrect && incorrectChosen == 0
	return fullyCorrect, maxPoints * ratio, nil
}

// gradeCoding runs the submission through the executor and scores by weighted
// test-case pass ratio. When the executor is unavailable it returns ungraded so
// the caller can leave the answer pending for manual review.
func gradeCoding(ctx context.Context, exec CodeExecutor, content, answer json.RawMessage, maxPoints float64) (graded bool, correct bool, points float64, run RunResult, lang, source string, err error) {
	var a codingAnswer
	if len(answer) > 0 {
		if err := json.Unmarshal(answer, &a); err != nil {
			return false, false, 0, RunResult{}, "", "", fmt.Errorf("assessment: decode coding answer: %w", err)
		}
	}
	if a.Code == "" {
		return true, false, 0, RunResult{Status: "failed"}, a.Language, a.Code, nil
	}
	if !exec.Available() {
		return false, false, 0, RunResult{Status: "pending"}, a.Language, a.Code, nil
	}

	var c CodingContent
	if err := json.Unmarshal(content, &c); err != nil {
		return false, false, 0, RunResult{}, a.Language, a.Code, fmt.Errorf("assessment: decode coding content: %w", err)
	}

	result, err := exec.Run(ctx, a.Language, a.Code, c)
	if err != nil {
		return false, false, 0, RunResult{Status: "error"}, a.Language, a.Code, err
	}

	var weightTotal, weightPassed float64
	for _, cr := range result.Cases {
		w := cr.Weight
		if w <= 0 {
			w = 1
		}
		weightTotal += w
		if cr.Passed {
			weightPassed += w
		}
	}
	if weightTotal == 0 {
		return true, false, 0, result, a.Language, a.Code, nil
	}
	ratio := weightPassed / weightTotal
	allPassed := result.TestsPassed == result.TestsTotal && result.Status == "passed"
	return true, allPassed, maxPoints * ratio, result, a.Language, a.Code, nil
}
