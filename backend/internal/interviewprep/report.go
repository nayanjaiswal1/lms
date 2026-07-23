package interviewprep

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/practice"
	"github.com/mindforge/backend/internal/srs"
)

// ErrRoundsIncomplete is returned when GetReport is called before both rounds
// have been completed — there is nothing to aggregate yet.
var ErrRoundsIncomplete = fmt.Errorf("interviewprep: rounds not yet completed")

// ErrNoReportForQuickPlan is returned for quick plans, which never generate a
// report — that's the defining cost difference from targeted plans (targeted
// always pays for one summarization call regardless of round count; quick
// never does).
var ErrNoReportForQuickPlan = fmt.Errorf("interviewprep: quick plans do not generate a report")

// GetReport returns the plan's aggregate readiness report, generating it (once)
// the first time both rounds are completed, and returning the cached copy on
// every call after — mirrors the "AI called once" rule used by revision plans.
func (s *Service) GetReport(ctx context.Context, planID, userID string) (Report, error) {
	plan, err := s.repo.GetPlan(ctx, planID, userID)
	if err != nil {
		return Report{}, err
	}
	if plan.PlanType == ModeQuick {
		return Report{}, ErrNoReportForQuickPlan
	}
	if plan.Report != nil {
		return *plan.Report, nil
	}
	if !s.ai.Available() {
		return Report{}, fmt.Errorf("interviewprep: AI provider not available")
	}

	// primary is the conceptual (technical) or behavioral (non-technical) round —
	// always present, always order_index 0. secondary is the coding round, only
	// present for technical plans; non-technical plans are single-round.
	var primary, secondary *Round
	for i := range plan.Rounds {
		switch plan.Rounds[i].RoundType {
		case RoundConceptual, RoundBehavioral:
			primary = &plan.Rounds[i]
		case RoundCoding:
			secondary = &plan.Rounds[i]
		}
	}
	if primary == nil || (secondary != nil && secondary.Status != RoundCompleted) {
		return Report{}, ErrRoundsIncomplete
	}

	// The primary round has no explicit "submit round" step of its own — it is
	// complete once every generated question has been answered in its linked
	// practice session (matching how the practice UI itself treats a session as
	// done: all items answered, regardless of whether AI feedback finished).
	if primary.PracticeSessionID == nil {
		return Report{}, fmt.Errorf("interviewprep: primary round has no linked practice session")
	}
	session, err := s.practiceRepo.GetSession(ctx, *primary.PracticeSessionID, userID)
	if err != nil {
		return Report{}, fmt.Errorf("interviewprep: load primary session: %w", err)
	}
	primaryPct, primarySkills, primaryDone := scoreConceptualItems(session.Items, session.Technology)
	if !primaryDone {
		return Report{}, ErrRoundsIncomplete
	}

	var secondaryItems []CodingItem
	var secondaryPct float64
	readiness := primaryPct
	if secondary != nil {
		secondaryItems = secondary.Items
		if secondary.Score != nil {
			secondaryPct = *secondary.Score
		}
		readiness = 0.5*primaryPct + 0.5*secondaryPct
	}

	strong, weak := splitSkills(secondaryItems, primaryPct, primarySkills)

	summary, nextSteps, model, err := s.summarizeReport(ctx, plan, readiness, primaryPct, secondaryPct, strong, weak)
	if err != nil {
		return Report{}, err
	}

	cardsAdded := s.createRevisionCards(ctx, userID, session.Items, secondaryItems)

	report := Report{
		ReadinessScore:     round1(readiness),
		ConceptualScorePct: round1(primaryPct),
		CodingPassRatePct:  round1(secondaryPct),
		StrongSkills:       strong,
		WeakSkills:         weak,
		Summary:            summary,
		NextSteps:          nextSteps,
		CardsAdded:         cardsAdded,
		AIModel:            model,
	}

	saved, err := s.repo.SaveReport(ctx, planID, report)
	if err != nil {
		return Report{}, err
	}
	if !saved {
		// Lost the race to a concurrent request — return whatever it wrote.
		refetched, err := s.repo.GetPlan(ctx, planID, userID)
		if err != nil {
			return Report{}, err
		}
		if refetched.Report != nil {
			return *refetched.Report, nil
		}
	}
	return report, nil
}

// scoreConceptualItems computes the average score percentage from a practice
// session's per-item AI feedback, the skill tags implied by the round (the
// session's technology field, split back into skills), and whether every
// question has been answered yet. Pure function — no I/O — so it and
// createRevisionCards can both operate on one already-fetched session.
func scoreConceptualItems(items []practice.PracticeItem, technology string) (pct float64, skills []string, done bool) {
	done = len(items) > 0
	var total, scored float64
	for _, item := range items {
		if item.AnsweredAt == nil {
			done = false
		}
		if item.AIFeedback == nil || item.AIFeedback.MaxScore == 0 {
			continue
		}
		total += float64(item.AIFeedback.Score) / float64(item.AIFeedback.MaxScore) * 100
		scored++
	}
	if scored > 0 {
		pct = total / scored
	}

	skills = []string{}
	for _, part := range strings.Split(technology, ",") {
		if part = strings.TrimSpace(part); part != "" {
			skills = append(skills, part)
		}
	}
	return pct, skills, done
}

// createRevisionCards turns the weak spots from this plan into SRS flashcards
// so the student can drill exactly what they got wrong via the existing
// spaced-repetition review queue (/review) instead of a bespoke revision UI.
// Conceptual items score below 70%; coding items that were attempted and
// failed. Best-effort: a card-creation failure is logged, not fatal — the
// report itself must still be returned even if revision-card seeding fails.
func (s *Service) createRevisionCards(ctx context.Context, userID string, conceptualItems []practice.PracticeItem, codingItems []CodingItem) int {
	created := 0
	for _, item := range conceptualItems {
		if item.AIFeedback == nil || item.AIFeedback.MaxScore == 0 {
			continue
		}
		pct := float64(item.AIFeedback.Score) / float64(item.AIFeedback.MaxScore) * 100
		if pct >= 70 {
			continue
		}
		back := item.AIFeedback.SuggestedAnswer
		if len(item.AIFeedback.Gaps) > 0 {
			back += "\n\nGaps: " + strings.Join(item.AIFeedback.Gaps, "; ")
		}
		if err := srs.MaybeCreateCard(ctx, s.pool, userID, srs.CreateCardRequest{
			Front:      item.QuestionText,
			Back:       back,
			SourceType: "interview_prep",
		}); err != nil {
			slog.WarnContext(ctx, "interviewprep: create revision card for conceptual item failed", "error", err)
			continue
		}
		created++
	}

	for _, item := range codingItems {
		if item.Passed == nil || *item.Passed {
			continue
		}
		back := fmt.Sprintf("Skill: %s\n\nRe-attempt this problem — you didn't pass all test cases last time.", item.Skill)
		if err := srs.MaybeCreateCard(ctx, s.pool, userID, srs.CreateCardRequest{
			Front:      item.Prompt,
			Back:       back,
			SourceType: "interview_prep",
		}); err != nil {
			slog.WarnContext(ctx, "interviewprep: create revision card for coding item failed", "error", err)
			continue
		}
		created++
	}
	return created
}

// splitSkills merges coding-item-level pass/fail with the conceptual round's
// whole-session skill list (conceptual items carry no per-item skill tag, only
// the practice session's joined "technology" field) into deduped strong/weak sets.
func splitSkills(codingItems []CodingItem, conceptualPct float64, conceptualSkills []string) (strong, weak []string) {
	seen := map[string]bool{}
	add := func(skill string, isWeak bool) {
		if skill == "" || seen[skill] {
			return
		}
		seen[skill] = true
		if isWeak {
			weak = append(weak, skill)
		} else {
			strong = append(strong, skill)
		}
	}
	for _, item := range codingItems {
		add(item.Skill, item.Passed == nil || !*item.Passed)
	}
	for _, skill := range conceptualSkills {
		add(skill, conceptualPct < 60)
	}
	return strong, weak
}

type reportSummary struct {
	Summary   string   `json:"summary"`
	NextSteps []string `json:"next_steps"`
}

func (s *Service) summarizeReport(ctx context.Context, plan Plan, readiness, conceptualPct, codingPct float64, strong, weak []string) (string, []string, string, error) {
	userPrompt := fmt.Sprintf(
		"Role: %s\nSeniority: %s\nReadiness score: %.0f/100\nConceptual round: %.0f%%\nCoding round: %.0f%%\nStrong skills: %s\nWeak skills: %s",
		plan.ExtractedRole, plan.ExtractedSeniority, readiness, conceptualPct, codingPct,
		strings.Join(strong, ", "), strings.Join(weak, ", "))

	llmCtx, cancel := context.WithTimeout(ctx, s.cfg.LLMTimeout)
	defer cancel()

	resp, err := s.ai.Complete(llmCtx, ai.CompletionRequest{
		SystemPrompt: ai.PrepReportSystemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    512,
		Temperature:  0.4,
		JSONMode:     true,
	})
	if err != nil {
		return "", nil, "", fmt.Errorf("interviewprep: summarize report: %w", err)
	}

	var out reportSummary
	if err := json.Unmarshal([]byte(resp.Content), &out); err != nil {
		return "", nil, "", fmt.Errorf("interviewprep: parse report summary: %w", err)
	}
	return out.Summary, out.NextSteps, resp.Model, nil
}

func round1(f float64) float64 {
	return float64(int(f*10+0.5)) / 10
}
