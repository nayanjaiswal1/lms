package assessment

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/ai"
)

// candidateContext holds the non-PII profile data sent to the LLM.
type candidateContext struct {
	ExperienceLevel string   `json:"experience_level"`
	TargetRole      string   `json:"target_role"`
	TargetLevel     string   `json:"target_level"`
	Skills          []string `json:"skills"`
}

// evalQuestionRow is the minimal shape loaded for each subjective question before evaluation.
type evalQuestionRow struct {
	Position   int
	QuestionID string
	VersionID  string
	Content    SubjectiveContent
	Transcript string
}

// llmQuestionResponse mirrors the per-question JSON schema returned by the LLM.
type llmQuestionResponse struct {
	TechnicalAccuracy  float64  `json:"score_technical_accuracy"`
	Completeness       float64  `json:"score_completeness"`
	Communication      float64  `json:"score_communication"`
	Clarity            float64  `json:"score_clarity"`
	Structure          float64  `json:"score_structure"`
	Confidence         float64  `json:"score_confidence"`
	SeniorityAlignment float64  `json:"score_seniority_alignment"`
	CompositeScore     float64  `json:"composite_score"` // ignored — recomputed
	Strengths          []string `json:"strengths"`
	Weaknesses         []string `json:"weaknesses"`
	MissingConcepts    []string `json:"missing_concepts"`
	IncorrectConcepts  []string `json:"incorrect_concepts"`
	Improvements       []string `json:"improvements"`
	BetterAnswer       string   `json:"better_answer"`
	ReferenceComparison string  `json:"reference_comparison"`
}

// llmOverallResponse mirrors the overall JSON schema returned by the LLM.
type llmOverallResponse struct {
	CompositeScore            float64  `json:"composite_score"`
	ReadinessScore            float64  `json:"readiness_score"`
	OverallStrengths          []string `json:"overall_strengths"`
	OverallWeaknesses         []string `json:"overall_weaknesses"`
	OverallImprovements       []string `json:"overall_improvements"`
	InterviewReadinessSummary string   `json:"interview_readiness_summary"`
}

// computeComposite derives a composite score from the 7 dimensions with equal weights.
// The LLM's self-reported composite is never trusted.
func computeComposite(r llmQuestionResponse) float64 {
	sum := r.TechnicalAccuracy + r.Completeness + r.Communication +
		r.Clarity + r.Structure + r.Confidence + r.SeniorityAlignment
	return clampScore(sum / 7.0)
}

// clampScore enforces [0, 100].
func clampScore(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 100 {
		return 100
	}
	return v
}

// clampAll clamps every dimension in a response to [0, 100].
func clampAll(r *llmQuestionResponse) {
	r.TechnicalAccuracy = clampScore(r.TechnicalAccuracy)
	r.Completeness = clampScore(r.Completeness)
	r.Communication = clampScore(r.Communication)
	r.Clarity = clampScore(r.Clarity)
	r.Structure = clampScore(r.Structure)
	r.Confidence = clampScore(r.Confidence)
	r.SeniorityAlignment = clampScore(r.SeniorityAlignment)
}

// applyInjectionPenalty caps all scores at 60 when injection was detected and
// every score is suspiciously high (≥ 95), indicating a successful manipulation.
func applyInjectionPenalty(r *llmQuestionResponse, flagged bool) {
	if !flagged {
		return
	}
	allHigh := r.TechnicalAccuracy >= 95 && r.Completeness >= 95 &&
		r.Communication >= 95 && r.Clarity >= 95 &&
		r.Structure >= 95 && r.Confidence >= 95 && r.SeniorityAlignment >= 95
	if !allHigh {
		return
	}
	r.TechnicalAccuracy = 60
	r.Completeness = 60
	r.Communication = 60
	r.Clarity = 60
	r.Structure = 60
	r.Confidence = 60
	r.SeniorityAlignment = 60
}

// validateEvalResponse checks that required qualitative fields are non-empty
// and that at least one score dimension is > 0 (detecting a null/zero response).
func validateEvalResponse(r llmQuestionResponse) error {
	if len(r.Strengths)+len(r.Weaknesses)+len(r.Improvements) == 0 {
		return fmt.Errorf("evaluator: response has no qualitative feedback")
	}
	if r.TechnicalAccuracy == 0 && r.Completeness == 0 && r.Communication == 0 &&
		r.Clarity == 0 && r.Structure == 0 && r.Confidence == 0 && r.SeniorityAlignment == 0 {
		return fmt.Errorf("evaluator: all scores are zero — likely empty or invalid response")
	}
	return nil
}

// BuildQuestionPrompt constructs the user prompt for a single subjective question.
func BuildQuestionPrompt(q evalQuestionRow, cand candidateContext) string {
	topics := strings.Join(q.Content.ExpectedTopics, ", ")
	candJSON, _ := json.Marshal(cand)

	return fmt.Sprintf(
		"<QUESTION>%s</QUESTION>\n"+
			"<EXPECTED_TOPICS>%s</EXPECTED_TOPICS>\n"+
			"<CANDIDATE_CONTEXT>%s</CANDIDATE_CONTEXT>\n"+
			"<CANDIDATE_ANSWER>%s</CANDIDATE_ANSWER>\n\n"+
			"Evaluate the candidate answer using the JSON schema in the system prompt.",
		q.Content.Prompt,
		topics,
		string(candJSON),
		q.Transcript,
	)
}

// BuildOverallPrompt constructs the user prompt for the holistic summary call.
func BuildOverallPrompt(questions []evalQuestionRow, perQuestion []EvaluationResult) string {
	type qSummary struct {
		Question        string   `json:"question"`
		CompositeScore  float64  `json:"composite_score"`
		Strengths       []string `json:"strengths"`
		Weaknesses      []string `json:"weaknesses"`
		MissingConcepts []string `json:"missing_concepts"`
	}
	summaries := make([]qSummary, 0, len(perQuestion))
	qMap := make(map[string]evalQuestionRow, len(questions))
	for _, q := range questions {
		qMap[q.VersionID] = q
	}
	for _, e := range perQuestion {
		q := qMap[e.QuestionID]
		summaries = append(summaries, qSummary{
			Question:        q.Content.Prompt,
			CompositeScore:  e.CompositeScore,
			Strengths:       e.Strengths,
			Weaknesses:      e.Weaknesses,
			MissingConcepts: e.MissingConcepts,
		})
	}
	raw, _ := json.Marshal(summaries)
	return fmt.Sprintf(
		"Per-question evaluation results:\n%s\n\n"+
			"Provide a holistic interview readiness summary using the JSON schema in the system prompt.",
		string(raw),
	)
}

// EvaluationResult holds the parsed, validated, server-recomputed scores for one question.
type EvaluationResult struct {
	QuestionID          string
	Scope               string
	TechnicalAccuracy   float64
	Completeness        float64
	Communication       float64
	Clarity             float64
	Structure           float64
	Confidence          float64
	SeniorityAlignment  float64
	CompositeScore      float64
	ReadinessScore      float64
	Strengths           []string
	Weaknesses          []string
	MissingConcepts     []string
	IncorrectConcepts   []string
	Improvements        []string
	BetterAnswer        string
	ReferenceComparison string
	InjectionDetected   bool
	InjectionScore      int
	ReviewRequired      bool
	AIModel             string
}

// evalQuestion calls the LLM for a single subjective question, validates the response,
// and applies the injection defence layers. Retries once on invalid JSON.
func evalQuestion(ctx context.Context, provider ai.LLMProvider, q evalQuestionRow, cand candidateContext, flagged bool, injScore int) (EvaluationResult, error) {
	userPrompt := BuildQuestionPrompt(q, cand)

	var raw string
	var model string
	for attempt := 0; attempt <= 1; attempt++ {
		llmCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
		resp, err := provider.Complete(llmCtx, ai.CompletionRequest{
			SystemPrompt: ai.SubjectiveEvalSystemPrompt,
			UserPrompt:   userPrompt,
			MaxTokens:    1200,
			Temperature:  0.2,
			JSONMode:     true,
		})
		cancel()
		if err != nil {
			if attempt == 0 {
				continue
			}
			return EvaluationResult{}, fmt.Errorf("evaluator: llm call (q %s): %w", q.VersionID, err)
		}
		raw = resp.Content
		model = resp.Model
		break
	}

	var parsed llmQuestionResponse
	if err := json.Unmarshal([]byte(raw), &parsed); err != nil {
		// Retry once on malformed JSON.
		llmCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
		resp, retryErr := provider.Complete(llmCtx, ai.CompletionRequest{
			SystemPrompt: ai.SubjectiveEvalSystemPrompt,
			UserPrompt:   userPrompt,
			MaxTokens:    1200,
			Temperature:  0.2,
			JSONMode:     true,
		})
		cancel()
		if retryErr != nil {
			return EvaluationResult{}, fmt.Errorf("evaluator: retry llm call (q %s): %w", q.VersionID, retryErr)
		}
		if err2 := json.Unmarshal([]byte(resp.Content), &parsed); err2 != nil {
			return EvaluationResult{}, fmt.Errorf("evaluator: parse response (q %s): %w", q.VersionID, err2)
		}
		model = resp.Model
	}

	// Layer 3: clamp, recompute composite, injection penalty.
	clampAll(&parsed)
	applyInjectionPenalty(&parsed, flagged)

	if err := validateEvalResponse(parsed); err != nil {
		return EvaluationResult{}, err
	}

	composite := computeComposite(parsed)

	// Ensure non-nil slices for consistent DB writes.
	if parsed.Strengths == nil {
		parsed.Strengths = []string{}
	}
	if parsed.Weaknesses == nil {
		parsed.Weaknesses = []string{}
	}
	if parsed.MissingConcepts == nil {
		parsed.MissingConcepts = []string{}
	}
	if parsed.IncorrectConcepts == nil {
		parsed.IncorrectConcepts = []string{}
	}
	if parsed.Improvements == nil {
		parsed.Improvements = []string{}
	}

	return EvaluationResult{
		QuestionID:          q.VersionID,
		Scope:               "question",
		TechnicalAccuracy:   parsed.TechnicalAccuracy,
		Completeness:        parsed.Completeness,
		Communication:       parsed.Communication,
		Clarity:             parsed.Clarity,
		Structure:           parsed.Structure,
		Confidence:          parsed.Confidence,
		SeniorityAlignment:  parsed.SeniorityAlignment,
		CompositeScore:      composite,
		Strengths:           parsed.Strengths,
		Weaknesses:          parsed.Weaknesses,
		MissingConcepts:     parsed.MissingConcepts,
		IncorrectConcepts:   parsed.IncorrectConcepts,
		Improvements:        parsed.Improvements,
		BetterAnswer:        parsed.BetterAnswer,
		ReferenceComparison: parsed.ReferenceComparison,
		InjectionDetected:   flagged,
		InjectionScore:      injScore,
		AIModel:             model,
	}, nil
}

// evalOverall calls the LLM for the holistic summary after all per-question evals.
func evalOverall(ctx context.Context, provider ai.LLMProvider, questions []evalQuestionRow, perQuestion []EvaluationResult) (EvaluationResult, error) {
	userPrompt := BuildOverallPrompt(questions, perQuestion)

	llmCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	resp, err := provider.Complete(llmCtx, ai.CompletionRequest{
		SystemPrompt: ai.SubjectiveOverallEvalSystemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    800,
		Temperature:  0.2,
		JSONMode:     true,
	})
	cancel()
	if err != nil {
		return EvaluationResult{}, fmt.Errorf("evaluator: overall llm call: %w", err)
	}

	var parsed llmOverallResponse
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return EvaluationResult{}, fmt.Errorf("evaluator: parse overall response: %w", err)
	}

	if parsed.OverallStrengths == nil {
		parsed.OverallStrengths = []string{}
	}
	if parsed.OverallWeaknesses == nil {
		parsed.OverallWeaknesses = []string{}
	}
	if parsed.OverallImprovements == nil {
		parsed.OverallImprovements = []string{}
	}

	return EvaluationResult{
		Scope:          "overall",
		CompositeScore: clampScore(parsed.CompositeScore),
		ReadinessScore: clampScore(parsed.ReadinessScore),
		Strengths:      parsed.OverallStrengths,
		Weaknesses:     parsed.OverallWeaknesses,
		Improvements:   parsed.OverallImprovements,
		BetterAnswer:   parsed.InterviewReadinessSummary,
		AIModel:        resp.Model,
	}, nil
}
