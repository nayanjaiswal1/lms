package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
)

// LLMPayload is the JSON payload for llm.task jobs.
type LLMPayload struct {
	Task     string         `json:"task"`      // course_outline | interview_review
	EntityID string         `json:"entity_id"` // course_id or practice_session_id
	Params   map[string]any `json:"params"`
}

// LLMHandler implements jobs.Handler for HandlerLLM jobs.
type LLMHandler struct {
	pool *pgxpool.Pool
	ai   ai.LLMProvider
	cfg  *config.Config
}

// NewLLMHandler constructs an LLMHandler with all dependencies injected.
func NewLLMHandler(pool *pgxpool.Pool, aiProvider ai.LLMProvider, cfg *config.Config) *LLMHandler {
	return &LLMHandler{
		pool: pool,
		ai:   aiProvider,
		cfg:  cfg,
	}
}

// Handle dispatches an LLM job to the appropriate task handler.
func (h *LLMHandler) Handle(ctx context.Context, job jobs.Job) error {
	var p LLMPayload
	if err := json.Unmarshal(job.Payload, &p); err != nil {
		return fmt.Errorf("handlers.llm: unmarshal payload: %w", err)
	}
	if p.Task == "" {
		return fmt.Errorf("handlers.llm: payload missing task")
	}
	if p.EntityID == "" {
		return fmt.Errorf("handlers.llm: payload missing entity_id")
	}

	switch p.Task {
	case "course_outline":
		return h.handleCourseOutline(ctx, job, p)
	case "interview_review":
		return h.handleInterviewReview(ctx, job, p)
	default:
		return fmt.Errorf("handlers.llm: unknown LLM task: %s", p.Task)
	}
}

// handleCourseOutline generates and stores an AI course outline for a course that
// has only its default "Introduction" section and no modules yet.
func (h *LLMHandler) handleCourseOutline(ctx context.Context, job jobs.Job, p LLMPayload) error {
	// Fetch the course to verify it exists and retrieve org_id for tenant isolation.
	var courseOrgID, courseTitle, courseDifficulty string
	var courseDescription *string
	err := h.pool.QueryRow(ctx,
		`SELECT org_id, title, difficulty, description FROM courses WHERE id = $1`, p.EntityID,
	).Scan(&courseOrgID, &courseTitle, &courseDifficulty, &courseDescription)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("handlers.llm: course_outline: course %s not found", p.EntityID)
		}
		return fmt.Errorf("handlers.llm: course_outline: fetch course %s: %w", p.EntityID, err)
	}

	// Tenant isolation: if the job is scoped to an org, verify the course belongs to it.
	if job.OrgID != nil && *job.OrgID != "" && courseOrgID != *job.OrgID {
		return fmt.Errorf("handlers.llm: course_outline: org_id mismatch, refusing to process (course %s)", p.EntityID)
	}

	// Idempotency: skip if the course already has at least one module generated.
	// A freshly created course has exactly one section ("Introduction") and no modules.
	var moduleCount int
	if err := h.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM course_modules WHERE course_id = $1 AND deleted_at IS NULL`, p.EntityID,
	).Scan(&moduleCount); err != nil {
		return fmt.Errorf("handlers.llm: course_outline: count modules %s: %w", p.EntityID, err)
	}
	if moduleCount > 0 {
		slog.InfoContext(ctx, "handlers.llm: course_outline already generated, skipping",
			"course_id", p.EntityID, "module_count", moduleCount)
		return nil
	}

	if !h.ai.Available() {
		return fmt.Errorf("handlers.llm: course_outline: AI provider not available")
	}

	// Resolve generation parameters from job payload overrides or course defaults.
	level := courseDifficulty
	if v, ok := p.Params["level"].(string); ok && v != "" {
		level = v
	}
	moduleCount = 8
	if v, ok := p.Params["module_count"].(float64); ok && v > 0 {
		moduleCount = int(v)
		if moduleCount > 30 {
			moduleCount = 30
		}
	}

	topic := courseTitle
	if courseDescription != nil && *courseDescription != "" {
		topic = courseTitle + ": " + *courseDescription
	}
	topic = ai.SanitizeTopic(topic, 200)

	llmCtx, cancel := context.WithTimeout(ctx, h.cfg.LLMTimeout)
	defer cancel()

	userPrompt := fmt.Sprintf("Topic: %s\nDifficulty: %s\nNumber of modules: %d", topic, level, moduleCount)

	resp, err := h.ai.Complete(llmCtx, ai.CompletionRequest{
		SystemPrompt: ai.CourseOutlineSystemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    2048,
		JSONMode:     true,
	})
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			return fmt.Errorf("handlers.llm: course_outline: AI timed out (course %s): %w", p.EntityID, err)
		}
		return fmt.Errorf("handlers.llm: course_outline: AI call (course %s): %w", p.EntityID, err)
	}

	// Parse the outline.
	var outline struct {
		Title       string `json:"title"`
		Description string `json:"description"`
		Sections    []struct {
			Title   string `json:"title"`
			Modules []struct {
				Title            string `json:"title"`
				Type             string `json:"type"`
				Description      string `json:"description"`
				EstimatedMinutes int    `json:"estimated_minutes"`
			} `json:"modules"`
		} `json:"sections"`
	}
	if err := json.Unmarshal([]byte(resp.Content), &outline); err != nil {
		return fmt.Errorf("handlers.llm: course_outline: parse AI response (course %s): %w", p.EntityID, err)
	}
	if len(outline.Sections) == 0 {
		return fmt.Errorf("handlers.llm: course_outline: AI returned no sections (course %s)", p.EntityID)
	}

	// Persist the outline inside a transaction.
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("handlers.llm: course_outline: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Remove the auto-created "Introduction" section so we can replace it with the
	// AI-generated structure.
	if _, err := tx.Exec(ctx,
		`DELETE FROM course_sections WHERE course_id = $1`, p.EntityID,
	); err != nil {
		return fmt.Errorf("handlers.llm: course_outline: delete default section (course %s): %w", p.EntityID, err)
	}

	for sectionPos, sec := range outline.Sections {
		var sectionID string
		if err := tx.QueryRow(ctx,
			`INSERT INTO course_sections (course_id, title, position) VALUES ($1, $2, $3) RETURNING id`,
			p.EntityID, sec.Title, sectionPos,
		).Scan(&sectionID); err != nil {
			return fmt.Errorf("handlers.llm: course_outline: insert section %d (course %s): %w", sectionPos, p.EntityID, err)
		}

		for modPos, mod := range sec.Modules {
			modType := mod.Type
			switch modType {
			case "video", "pdf", "notes", "assessment":
			default:
				modType = "notes"
			}
			estimatedMin := mod.EstimatedMinutes
			var estimatedMinPtr *int
			if estimatedMin > 0 {
				estimatedMinPtr = &estimatedMin
			}
			var contentBody *string
			if mod.Description != "" {
				contentBody = &mod.Description
			}
			if _, err := tx.Exec(ctx,
				`INSERT INTO course_modules (course_id, section_id, title, type, position, content_body, estimated_minutes)
				 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
				p.EntityID, sectionID, mod.Title, modType, modPos, contentBody, estimatedMinPtr,
			); err != nil {
				return fmt.Errorf("handlers.llm: course_outline: insert module %d in section %d (course %s): %w", modPos, sectionPos, p.EntityID, err)
			}
		}
	}

	// Update the course updated_at so the frontend knows generation is complete.
	if _, err := tx.Exec(ctx,
		`UPDATE courses SET updated_at = now() WHERE id = $1`, p.EntityID,
	); err != nil {
		return fmt.Errorf("handlers.llm: course_outline: update course updated_at (course %s): %w", p.EntityID, err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("handlers.llm: course_outline: commit tx (course %s): %w", p.EntityID, err)
	}

	slog.InfoContext(ctx, "handlers.llm: course outline generated and stored",
		"course_id", p.EntityID,
		"sections", len(outline.Sections),
		"model", resp.Model)
	return nil
}

// handleInterviewReview generates and stores AI feedback for a practice session item.
// EntityID is the practice_session_id. The position of the item to review is taken
// from p.Params["position"] (float64 from JSON). If not provided, the first
// unanswered-but-answered item without feedback is processed.
func (h *LLMHandler) handleInterviewReview(ctx context.Context, job jobs.Job, p LLMPayload) error {
	// Fetch the session to verify ownership and org_id for tenant isolation.
	var sessionOrgID *string
	err := h.pool.QueryRow(ctx,
		`SELECT org_id FROM practice_sessions WHERE id = $1`, p.EntityID,
	).Scan(&sessionOrgID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("handlers.llm: interview_review: session %s not found", p.EntityID)
		}
		return fmt.Errorf("handlers.llm: interview_review: fetch session %s: %w", p.EntityID, err)
	}

	// Tenant isolation.
	if job.OrgID != nil && *job.OrgID != "" {
		if sessionOrgID == nil || *sessionOrgID != *job.OrgID {
			return fmt.Errorf("handlers.llm: interview_review: org_id mismatch, refusing to process (session %s)", p.EntityID)
		}
	}

	// Determine which item to review.
	// Params["position"] optionally pins a specific item; otherwise pick the first
	// pending item (answered but no feedback).
	var itemID, questionText, userAnswer string
	if posRaw, ok := p.Params["position"]; ok {
		pos := int(posRaw.(float64))
		err = h.pool.QueryRow(ctx,
			`SELECT id, question_text, user_answer
			 FROM practice_items
			 WHERE session_id = $1 AND position = $2
			   AND user_answer IS NOT NULL AND feedback_at IS NULL`,
			p.EntityID, pos,
		).Scan(&itemID, &questionText, &userAnswer)
	} else {
		err = h.pool.QueryRow(ctx,
			`SELECT id, question_text, user_answer
			 FROM practice_items
			 WHERE session_id = $1
			   AND user_answer IS NOT NULL AND feedback_at IS NULL
			 ORDER BY position
			 LIMIT 1`,
			p.EntityID,
		).Scan(&itemID, &questionText, &userAnswer)
	}
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Idempotency: feedback already stored or no answered item pending review.
			slog.InfoContext(ctx, "handlers.llm: interview_review: no pending items, skipping",
				"session_id", p.EntityID)
			return nil
		}
		return fmt.Errorf("handlers.llm: interview_review: fetch pending item (session %s): %w", p.EntityID, err)
	}

	if !h.ai.Available() {
		return fmt.Errorf("handlers.llm: interview_review: AI provider not available")
	}

	llmCtx, cancel := context.WithTimeout(ctx, h.cfg.LLMTimeout)
	defer cancel()

	userPrompt := fmt.Sprintf("Question: %s\n\nCandidate's answer: %s",
		questionText, ai.SanitizeAnswer(userAnswer))

	resp, err := h.ai.Complete(llmCtx, ai.CompletionRequest{
		SystemPrompt: ai.InterviewReviewSystemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    1024,
		Temperature:  0.3,
		JSONMode:     true,
	})
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			return fmt.Errorf("handlers.llm: interview_review: AI timed out (item %s): %w", itemID, err)
		}
		return fmt.Errorf("handlers.llm: interview_review: AI call (item %s): %w", itemID, err)
	}

	// Validate JSON is parseable before storing.
	var feedbackCheck map[string]any
	if err := json.Unmarshal([]byte(resp.Content), &feedbackCheck); err != nil {
		return fmt.Errorf("handlers.llm: interview_review: parse AI response (item %s): %w", itemID, err)
	}

	// Inject the model name into the stored JSON.
	feedbackCheck["model"] = resp.Model
	feedbackRaw, err := json.Marshal(feedbackCheck)
	if err != nil {
		return fmt.Errorf("handlers.llm: interview_review: re-marshal feedback (item %s): %w", itemID, err)
	}

	// Store feedback — only if feedback_at is still NULL (guard against concurrent runs).
	tag, err := h.pool.Exec(ctx,
		`UPDATE practice_items
		 SET ai_feedback = $1, feedback_at = now()
		 WHERE id = $2 AND feedback_at IS NULL`,
		feedbackRaw, itemID,
	)
	if err != nil {
		return fmt.Errorf("handlers.llm: interview_review: save feedback (item %s): %w", itemID, err)
	}
	if tag.RowsAffected() == 0 {
		// Another worker already stored feedback — idempotent success.
		slog.InfoContext(ctx, "handlers.llm: interview_review: feedback already stored by concurrent worker",
			"item_id", itemID)
		return nil
	}

	slog.InfoContext(ctx, "handlers.llm: interview review stored",
		"session_id", p.EntityID,
		"item_id", itemID,
		"model", resp.Model)
	return nil
}
