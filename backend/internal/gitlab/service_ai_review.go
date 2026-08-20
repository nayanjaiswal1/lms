package gitlab

import (
	"context"
	"fmt"
	"strings"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/jobs"
)

// Job handler key — plain string literal, same reasoning as every other job
// constant in this package (internal/jobs/handlers imports gitlab, so gitlab
// cannot import handlers back). MUST stay in sync with
// handlers.HandlerGitlabAIReviewMR in internal/jobs/handlers/constants.go.
const jobAIReviewMR = "gitlab.ai_review_mr"

const aiReviewMRTimeoutMS = 60000

// aiReviewMaxDiffChars bounds the total diff text sent to the AI reviewer —
// large MRs get a truncated review rather than an unbounded prompt/cost.
// ponytail: a flat character cap, not a token-aware one; raise it (or switch
// to a real tokenizer-based budget) if truncation turns out to bite often.
const aiReviewMaxDiffChars = 16000

// aiReviewMaxFiles bounds how many changed files are considered at all —
// same reasoning as aiReviewMaxDiffChars.
const aiReviewMaxFiles = 20

// enqueueAIReview enqueues gitlab.ai_review_mr for one MR row — called once,
// off the MR's first "opened" webhook (service_webhook.go's
// ingestMergeRequestEvent), never re-enqueued once AIReviewedAt is set.
func (s *Service) enqueueAIReview(ctx context.Context, orgID, mrRowID string) error {
	timeout := aiReviewMRTimeoutMS
	if _, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler: jobAIReviewMR, Priority: jobs.PriorityBackground,
		Payload: map[string]string{"mr_id": mrRowID}, OrgID: &orgID, TimeoutMS: &timeout,
	}); err != nil {
		return fmt.Errorf("gitlab: enqueue ai_review_mr: %w", err)
	}
	return nil
}

// ReviewMergeRequest is the ai_review_mr job's body: fetches the MR's diff,
// asks the AI for feedback, and posts it as a plain GitLab MR note — review
// only, never a commit or a merge. No-ops (not an error) if the MR was
// already reviewed (redelivery-safe) or the AI provider isn't configured for
// this deployment.
func (s *Service) ReviewMergeRequest(ctx context.Context, mrRowID string) error {
	if s.aiProvider == nil || !s.aiProvider.Available() {
		return nil
	}

	mr, err := s.repo.GetMergeRequestByID(ctx, mrRowID)
	if err != nil {
		return err
	}
	if mr.AIReviewedAt != nil {
		return nil
	}

	team, err := s.repo.GetTeamByID(ctx, mr.TeamID)
	if err != nil {
		return fmt.Errorf("gitlab: ai review: get team: %w", err)
	}
	if team.GitlabProjectID == nil {
		return nil // team's fork isn't provisioned — nothing to fetch/comment on
	}

	client, err := s.clientForTeam(ctx, mr.OrgID, team.AssignmentID)
	if err != nil {
		return fmt.Errorf("gitlab: ai review: resolve client: %w", err)
	}

	changes, err := client.GetMergeRequestChanges(ctx, *team.GitlabProjectID, mr.MRIID)
	if err != nil {
		return fmt.Errorf("gitlab: ai review: fetch changes: %w", err)
	}

	diffText := buildReviewPrompt(mr, changes.Changes)
	if diffText == "" {
		return s.repo.MarkMergeRequestAIReviewed(ctx, mr.ID)
	}

	resp, err := s.aiProvider.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.MRCodeReviewSystemPrompt,
		UserPrompt:   diffText,
		MaxTokens:    600,
		Temperature:  0.3,
	})
	if err != nil {
		return fmt.Errorf("gitlab: ai review: call AI: %w", err)
	}

	if _, err := client.CreateMRNote(ctx, *team.GitlabProjectID, mr.MRIID, resp.Content); err != nil {
		return fmt.Errorf("gitlab: ai review: post note: %w", err)
	}
	return s.repo.MarkMergeRequestAIReviewed(ctx, mr.ID)
}

// buildReviewPrompt renders the MR title/description plus up to
// aiReviewMaxFiles changed files' diffs, truncated to aiReviewMaxDiffChars
// total — deleted files are skipped (nothing to review), everything else is
// included in changed order until either cap is hit.
func buildReviewPrompt(mr *GitlabMergeRequest, changes []MRChange) string {
	var b strings.Builder
	fmt.Fprintf(&b, "MR title: %s\n", mr.Title)
	if mr.Description != nil && *mr.Description != "" {
		fmt.Fprintf(&b, "MR description: %s\n", *mr.Description)
	}
	b.WriteString("\nChanged files:\n")

	remaining := aiReviewMaxDiffChars
	shown := 0
	for _, c := range changes {
		if c.DeletedFile || shown >= aiReviewMaxFiles || remaining <= 0 {
			continue
		}
		path := c.NewPath
		if path == "" {
			path = c.OldPath
		}
		diff := c.Diff
		if len(diff) > remaining {
			diff = diff[:remaining] + "\n… (truncated)"
		}
		fmt.Fprintf(&b, "\n--- %s ---\n%s\n", path, diff)
		remaining -= len(diff)
		shown++
	}
	if shown == 0 {
		return ""
	}
	return b.String()
}
