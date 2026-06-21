package assessment

import (
	"context"

	"github.com/mindforge/backend/internal/ai"
)

// EvalQuestionRow is the exported alias for evalQuestionRow.
// It is used by the jobs/handlers package to call EvalQuestion without
// duplicating the type definition.
type EvalQuestionRow = evalQuestionRow

// CandidateContext is the exported alias for candidateContext.
// It is used by the jobs/handlers package to call EvalQuestion without
// duplicating the type definition.
type CandidateContext = candidateContext

// EvalQuestion is the exported wrapper around the package-private evalQuestion.
// It evaluates a single subjective question via the LLM, applies injection
// defences, and returns a fully populated EvaluationResult.
func EvalQuestion(ctx context.Context, provider ai.LLMProvider, q EvalQuestionRow, cand CandidateContext, flagged bool, injScore int) (EvaluationResult, error) {
	return evalQuestion(ctx, provider, q, cand, flagged, injScore)
}

// EvalOverall is the exported wrapper around the package-private evalOverall.
// It calls the LLM for a holistic interview readiness summary after all
// per-question evaluations are complete.
func EvalOverall(ctx context.Context, provider ai.LLMProvider, questions []EvalQuestionRow, perQuestion []EvaluationResult) (EvaluationResult, error) {
	return evalOverall(ctx, provider, questions, perQuestion)
}

// BuildSkillScores derives per-skill composite averages from per-question results
// for O(1) trend queries. Called by the jobs/handlers package after all per-question
// evaluations are complete.
func BuildSkillScores(questions []EvalQuestionRow, results []EvaluationResult) []SkillScore {
	type acc struct {
		total float64
		count int
	}
	bySkill := map[string]*acc{}
	for i, q := range questions {
		if i >= len(results) {
			break
		}
		for _, skill := range q.Content.Skills {
			if skill == "" {
				continue
			}
			if bySkill[skill] == nil {
				bySkill[skill] = &acc{}
			}
			bySkill[skill].total += results[i].CompositeScore
			bySkill[skill].count++
		}
	}
	out := make([]SkillScore, 0, len(bySkill))
	for skill, a := range bySkill {
		out = append(out, SkillScore{
			Skill:          skill,
			CompositeScore: a.total / float64(a.count),
			QuestionCount:  a.count,
		})
	}
	return out
}
