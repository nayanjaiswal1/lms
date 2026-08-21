package projectmarket

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/jobs"
)

// Job handler key — plain string literal (not a shared constants import),
// same reasoning as gitlab package's own job constants: internal/jobs/handlers
// imports this package to build its handler, so this package cannot import
// handlers back without a cycle. MUST stay in sync with
// handlers.HandlerProjectmarketScoreRequirement in
// internal/jobs/handlers/constants.go.
const jobScoreRequirement = "projectmarket.score_requirement"

// scoreRequirementTimeoutMS bounds one scoring run — one GitHub fetch plus
// one AI call per unscored applicant, so this scales with applicant count;
// generous for the expected class-sized applicant pools this targets.
const scoreRequirementTimeoutMS = 300000

// ErrAIUnavailable — the configured AI provider isn't available right now.
var ErrAIUnavailable = errors.New("projectmarket: AI scoring is not available right now")

// RequestScoring enqueues a projectmarket.score_requirement job to rank
// every not-yet-scored application against requirementID. Idempotent by
// design — ListUnscoredApplications inside the job is the "AI called once"
// cache check, so running this again after new applications arrive only
// scores the new ones. The idempotency key additionally collapses a
// double-click into a single job: while a run for this requirement is
// still pending/in flight, a second RequestScoring call is a silent no-op
// rather than a second concurrent pass over the same (mostly already-
// scored) applications.
func (s *Service) RequestScoring(ctx context.Context, orgID, requirementID, requestedBy string) error {
	if _, err := s.repo.GetRequirement(ctx, orgID, requirementID); err != nil {
		return err
	}
	timeout := scoreRequirementTimeoutMS
	idempotencyKey := "projectmarket.score_requirement:" + requirementID
	if _, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler: jobScoreRequirement, Priority: jobs.PriorityBackground,
		Payload: map[string]string{"org_id": orgID, "requirement_id": requirementID}, OrgID: &orgID, TimeoutMS: &timeout,
		CreatedBy: &requestedBy, IdempotencyKey: &idempotencyKey,
	}); err != nil && !errors.Is(err, jobs.ErrDuplicateKey) {
		return fmt.Errorf("projectmarket: enqueue scoring: %w", err)
	}
	return nil
}

// ScoreRequirement is the score_requirement job's body — see
// internal/jobs/handlers/projectmarket_score.go for the jobs.Handler wrapper
// that calls this.
func (s *Service) ScoreRequirement(ctx context.Context, orgID, requirementID string) error {
	if !s.aiProvider.Available() {
		return ErrAIUnavailable
	}

	req, err := s.repo.GetRequirement(ctx, orgID, requirementID)
	if err != nil {
		return err
	}
	unscored, err := s.repo.ListUnscoredApplications(ctx, orgID, requirementID)
	if err != nil {
		return err
	}

	for _, app := range unscored {
		score, rationale, err := s.scoreOneApplication(ctx, req, app)
		if err != nil {
			// One bad AI response shouldn't abandon the rest of the batch —
			// it stays unscored (ai_score IS NULL) and a re-run of this same
			// job will retry it, same as any other applicant that hasn't
			// been scored yet.
			continue
		}
		if err := s.repo.SetApplicationScore(ctx, app.ID, score, rationale); err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) scoreOneApplication(ctx context.Context, req *ProjectRequirement, app ProjectApplication) (float64, string, error) {
	var githubSignal string
	if links, err := s.profileRepo.GetSocialLinks(ctx, app.UserID); err == nil && links.GitHub != nil {
		githubSignal = fetchGitHubSignal(ctx, *links.GitHub)
	}

	var b strings.Builder
	fmt.Fprintf(&b, "Project: %s\nRequired skills: %s\nBrief: %s\n\n", req.Title, strings.Join(req.RequiredSkills, ", "), req.Brief)
	if app.Motivation != nil && *app.Motivation != "" {
		fmt.Fprintf(&b, "Applicant's motivation: %s\n\n", *app.Motivation)
	} else {
		b.WriteString("Applicant's motivation: (none provided)\n\n")
	}
	if app.ResumeText != nil && *app.ResumeText != "" {
		fmt.Fprintf(&b, "Applicant's resume:\n%s\n\n", *app.ResumeText)
	} else {
		b.WriteString("Applicant's resume: (none provided)\n\n")
	}
	if githubSignal != "" {
		fmt.Fprintf(&b, "Applicant's %s\n", githubSignal)
	} else {
		b.WriteString("Applicant's GitHub: (not linked)\n")
	}

	resp, err := s.aiProvider.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.ProjectApplicationScoreSystemPrompt,
		UserPrompt:   b.String(),
		MaxTokens:    300,
		Temperature:  0.2,
		JSONMode:     true,
	})
	if err != nil {
		return 0, "", fmt.Errorf("projectmarket: score application %s: %w", app.ID, err)
	}

	var parsed struct {
		Score     float64 `json:"score"`
		Rationale string  `json:"rationale"`
	}
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return 0, "", fmt.Errorf("projectmarket: parse score for application %s: %w", app.ID, err)
	}
	if parsed.Score < 0 {
		parsed.Score = 0
	}
	if parsed.Score > 100 {
		parsed.Score = 100
	}
	return parsed.Score, parsed.Rationale, nil
}
