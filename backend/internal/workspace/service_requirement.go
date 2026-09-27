package workspace

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/pagination"
)

// service_requirement.go extends service_project.go's Phase 1 requirement
// flow with Phase 3's Q&A clarification loop and the AI gap-check
// (contract-phase3.md).

// ListQuestions cursor-paginates a project's question log, newest first.
func (s *Service) ListQuestions(ctx context.Context, pc *ProjectCtx, cursor string, limit int) (Page[RequirementQuestion], error) {
	limit = clampLimit(limit)
	cursorAt, cursorID, err := pagination.DecodeCursor(cursor, "workspace_questions")
	if err != nil {
		cursorAt, cursorID = time.Time{}, ""
	}
	items, err := s.repo.ListQuestions(ctx, s.pool, pc.ProjectID, cursorAt, cursorID, limit+1)
	if err != nil {
		return Page[RequirementQuestion]{}, err
	}
	page := Page[RequirementQuestion]{Items: items}
	if len(items) > limit {
		page.Items = items[:limit]
		last := page.Items[limit-1]
		page.NextCursor = pagination.EncodeCursor(last.CreatedAt, last.ID)
	}
	return page, nil
}

// AskQuestion appends a clarifying question, or — when a near-identical one
// already exists (trgm, SimilarityThreshold) — returns it instead with
// Duplicate=true so the composer can point the asker at the existing thread.
// Only while the brief is raw or clarifying (route gate StatusesDiscuss
// covers project status; brief-status is checked here since the gate can't
// express it).
func (s *Service) AskQuestion(ctx context.Context, pc *ProjectCtx, req AskQuestionRequest) (*AskQuestionResult, error) {
	if pc.BriefStatus == BriefAgreed {
		return nil, fmt.Errorf("%w: the brief is already agreed — update the requirement to reopen clarification", ErrInvalidState)
	}
	q := strings.TrimSpace(req.Question)
	if len(q) < QuestionMinLen || len(q) > QuestionMaxLen {
		return nil, &FieldError{Fields: map[string]string{
			"question": fmt.Sprintf("Question must be %d-%d characters.", QuestionMinLen, QuestionMaxLen),
		}}
	}

	var result *AskQuestionResult
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		project, err := s.repo.GetProject(ctx, tx, pc.OrgID, pc.ProjectID)
		if err != nil {
			return err
		}
		dup, err := s.repo.FindDuplicateQuestion(ctx, tx, pc.ProjectID, q)
		if err != nil {
			return err
		}
		if dup != nil {
			result = &AskQuestionResult{Question: *dup, Duplicate: true}
			return nil
		}
		inserted, err := s.repo.InsertQuestion(ctx, tx, pc.ProjectID, project.RequirementVersion, pc.UserID, q)
		if err != nil {
			return fmt.Errorf("workspace: ask question: %w", err)
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_question.asked", "requirement_question", inserted.ID, nil)
		result = &AskQuestionResult{Question: *inserted}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// SimilarQuestions is the composer's debounced "already asked?" check.
func (s *Service) SimilarQuestions(ctx context.Context, pc *ProjectCtx, q string) ([]RequirementQuestion, error) {
	q = strings.TrimSpace(q)
	if len(q) < 1 || len(q) > QuestionMaxLen {
		return nil, fmt.Errorf("%w: q must be 1-%d characters", ErrInvalidInput, QuestionMaxLen)
	}
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:similar:"+pc.UserID, s.cfg.Workspace.SimilarPerUserMinute, time.Minute); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}
	var out []RequirementQuestion
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		items, err := s.repo.ListSimilarQuestions(ctx, tx, pc.ProjectID, q)
		if err != nil {
			return err
		}
		out = items
		return nil
	})
	return out, err
}

// AnswerQuestion records the owner's answer (or a manager's "you decide"
// assumption after QuestionAssumptionAfter of silence).
func (s *Service) AnswerQuestion(ctx context.Context, pc *ProjectCtx, questionID string, req AnswerQuestionRequest) (*RequirementQuestion, error) {
	answer := strings.TrimSpace(req.Answer)
	if len(answer) == 0 || len(answer) > AnswerMaxLen {
		return nil, &FieldError{Fields: map[string]string{
			"answer": fmt.Sprintf("Answer must be 1-%d characters.", AnswerMaxLen),
		}}
	}

	var updated *RequirementQuestion
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		question, err := s.repo.LockQuestion(ctx, tx, pc.ProjectID, questionID)
		if err != nil {
			return err
		}
		if question.AnsweredAt != nil {
			return ErrQuestionAnswered
		}
		// contract-phase3.md: the project owner may answer for real, any time;
		// a manager may only record an unanswered question as an assumption,
		// and only once it's been idle QuestionAssumptionAfter (ErrTooEarly).
		switch {
		case req.IsAssumption:
			if !RoleAtLeast(pc.Role, RoleManager) {
				return ErrForbidden
			}
			if s.now().Sub(question.CreatedAt) < QuestionAssumptionAfter {
				return ErrTooEarly
			}
		default:
			if pc.Role != RoleOwner {
				return ErrForbidden
			}
		}

		out, err := s.repo.SetAnswer(ctx, tx, pc.ProjectID, questionID, answer, pc.UserID, req.IsAssumption)
		if err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "workspace_question.answered", "requirement_question", questionID,
			map[string]bool{"is_assumption": req.IsAssumption})
		updated = out
		return nil
	})
	if err != nil {
		return nil, err
	}
	return updated, nil
}

// RequirementGaps runs the AI gap-check against the current requirement text
// plus its Q&A log, cached per requirement version (D11: AI called once).
func (s *Service) RequirementGaps(ctx context.Context, pc *ProjectCtx) (*RequirementGaps, error) {
	if !RoleAtLeast(pc.Role, RoleManager) {
		return nil, ErrForbidden
	}
	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	cacheKey := fmt.Sprintf("req:v%d", project.RequirementVersion)

	var cached RequirementGaps
	if found, err := s.repo.GetAICache(ctx, s.pool, pc.ProjectID, "requirement_gaps", cacheKey, &cached); err != nil {
		return nil, err
	} else if found {
		return &cached, nil
	}

	if s.ai == nil || !s.ai.Available() {
		return nil, fmt.Errorf("%w: AI is not configured", ErrInvalidState)
	}
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:ai:"+pc.ProjectID, s.cfg.Workspace.AIPerProjectDay, 24*time.Hour); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}

	answered, err := s.repo.ListAnsweredQuestions(ctx, s.pool, pc.ProjectID, project.RequirementVersion)
	if err != nil {
		return nil, err
	}

	var b strings.Builder
	fmt.Fprintf(&b, "Requirement: %s\n", delimited(project.Requirement))
	if len(answered) > 0 {
		b.WriteString("\nAnswered questions:\n")
		for _, q := range answered {
			ans := ""
			if q.Answer != nil {
				ans = *q.Answer
			}
			fmt.Fprintf(&b, "- Q: %s\n  A: %s\n", delimited(q.Question), delimited(ans))
		}
	}

	resp, err := s.ai.Complete(ctx, ai.CompletionRequest{
		SystemPrompt: ai.WorkspaceRequirementGapsSystemPrompt,
		UserPrompt:   b.String(),
		MaxTokens:    600,
		Temperature:  0.2,
		JSONMode:     true,
	})
	if err != nil {
		return nil, fmt.Errorf("workspace: requirement gaps: %w", err)
	}
	var parsed RequirementGaps
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		return nil, fmt.Errorf("workspace: requirement gaps: parse response: %w", err)
	}
	if parsed.Gaps == nil {
		parsed.Gaps = []string{}
	}

	if err := s.repo.SetAICache(ctx, s.pool, pc.ProjectID, "requirement_gaps", cacheKey, parsed); err != nil {
		return nil, err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "workspace_requirement.gaps_computed", "workspace_project", pc.ProjectID, nil)
	return &parsed, nil
}
