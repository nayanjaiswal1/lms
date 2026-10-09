package workspace

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/ai"
)

// interestRankDelimiter wraps every untrusted applicant-supplied field before
// it reaches the prompt (02 §6): the delimiter itself is stripped out of the
// raw field first, so nothing the applicant typed can forge a closing tag and
// smuggle instructions past it.
const interestRankDelimiter = "@@@APPLICANT_DATA@@@"

func stripRankDelimiter(s string) string { return strings.ReplaceAll(s, interestRankDelimiter, "") }

func delimited(s string) string {
	return interestRankDelimiter + stripRankDelimiter(s) + interestRankDelimiter
}

// buildInterestRankPrompt never includes the applicant's name or email — only
// skills, free-text message, and the *host* of their portfolio link (never
// the full URL, and it is never fetched).
func buildInterestRankPrompt(skills []string, message, portfolioHost string) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Skills: %s\n", delimited(strings.Join(skills, ", ")))
	fmt.Fprintf(&b, "Message: %s\n", delimited(message))
	fmt.Fprintf(&b, "Portfolio host: %s\n", delimited(portfolioHost))
	return b.String()
}

// RankInterest scores one interest against the project's skills/requirement
// on the owner/manager's click — never automatically on submit (00-decisions
// D20). The result is cached on the row (ai_scored_at) and never recomputed;
// re-upserting the interest (a fresh submission) clears the cache.
func (s *Service) RankInterest(ctx context.Context, pc *ProjectCtx, interestID string) (*Interest, error) {
	interest, err := s.repo.GetInterest(ctx, s.pool, pc.ProjectID, interestID)
	if err != nil {
		return nil, err
	}
	if interest.AIScoredAt != nil {
		return interest, nil
	}
	if s.ai == nil || !s.ai.Available() {
		return nil, fmt.Errorf("%w: AI is not configured", ErrInvalidState)
	}
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:ai:"+pc.ProjectID, s.cfg.Workspace.AIPerProjectDay, 24*time.Hour); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}

	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}

	portfolioHost := ""
	if interest.PortfolioURL != nil {
		if u, err := url.Parse(*interest.PortfolioURL); err == nil {
			portfolioHost = u.Host
		}
	}
	message := ""
	if interest.Message != nil {
		message = *interest.Message
	}

	var b strings.Builder
	fmt.Fprintf(&b, "Project title: %s\nRequired skills: %s\n\n", project.Title, strings.Join(project.Skills, ", "))
	b.WriteString(buildInterestRankPrompt(interest.Skills, message, portfolioHost))

	if interest.UserID != nil && s.profile != nil {
		b.WriteString(s.applicantProfileSignal(ctx, *interest.UserID))
	}

	resp, err := s.ai.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.WorkspaceInterestRankSystemPrompt,
		UserPrompt:   b.String(),
		MaxTokens:    300,
		Temperature:  0.2,
		JSONMode:     true,
	})
	if err != nil {
		return nil, fmt.Errorf("workspace: rank interest: %w", err)
	}

	var parsed struct {
		Score     float64 `json:"score"`
		Rationale string  `json:"rationale"`
	}
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return nil, fmt.Errorf("workspace: rank interest: parse response: %w", err)
	}
	if parsed.Score < 0 {
		parsed.Score = 0
	}
	if parsed.Score > 100 {
		parsed.Score = 100
	}

	if err := s.repo.SetInterestAIScore(ctx, s.pool, interestID, parsed.Score, parsed.Rationale); err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "project.interest_ranked", "project_interest", interestID, nil)
	return s.repo.GetInterest(ctx, s.pool, pc.ProjectID, interestID)
}

// applicantProfileSignal renders a signed-in applicant's profile skills and
// public GitHub summary for the rank prompt. Best-effort: a missing profile
// or GitHub link only reduces evidence, it never fails the ranking.
func (s *Service) applicantProfileSignal(ctx context.Context, userID string) string {
	var b strings.Builder
	if skills, err := s.profile.GetSkills(ctx, userID); err == nil && len(skills) > 0 {
		names := make([]string, 0, len(skills))
		for _, sk := range skills {
			names = append(names, sk.SkillName+" ("+sk.SkillLevel+")")
		}
		fmt.Fprintf(&b, "Profile skills: %s\n", delimited(strings.Join(names, ", ")))
	}
	if links, err := s.profile.GetSocialLinks(ctx, userID); err == nil && links != nil && links.GitHub != nil {
		if signal := fetchGitHubSignal(ctx, *links.GitHub); signal != "" {
			fmt.Fprintf(&b, "Applicant's %s\n", delimited(signal))
		}
	}
	return b.String()
}
