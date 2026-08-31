package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/diary"
	"github.com/mindforge/backend/internal/habit"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/revisionplan"
	"github.com/mindforge/backend/internal/roadmap"
	"github.com/mindforge/backend/internal/whatnow"
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
	case "roadmap_generate":
		return h.handleRoadmapGenerate(ctx, job, p)
	case "revision_plan_generate":
		return h.handleRevisionPlanGenerate(ctx, job, p)
	case "mistake_card_generate":
		return h.handleMistakeCardGenerate(ctx, job, p)
	case "diary_analyze":
		return h.handleDiaryAnalyze(ctx, job, p)
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
	// Fetch the session (an assessment_attempts row, see practice.Repo.CreateSession)
	// to verify ownership and org_id for tenant isolation.
	var sessionOrgID *string
	err := h.pool.QueryRow(ctx,
		`SELECT org_id FROM assessment_attempts WHERE id = $1`, p.EntityID,
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
			`SELECT id, answer->>'question_text', answer->>'user_answer'
			 FROM attempt_answers
			 WHERE attempt_id = $1 AND position = $2
			   AND answer ? 'user_answer' AND evaluated_at IS NULL`,
			p.EntityID, pos,
		).Scan(&itemID, &questionText, &userAnswer)
	} else {
		err = h.pool.QueryRow(ctx,
			`SELECT id, answer->>'question_text', answer->>'user_answer'
			 FROM attempt_answers
			 WHERE attempt_id = $1
			   AND answer ? 'user_answer' AND evaluated_at IS NULL
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
		`UPDATE attempt_answers
		 SET ai_feedback = $1, evaluated_at = now()
		 WHERE id = $2 AND evaluated_at IS NULL`,
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

// handleRoadmapGenerate generates and stores an AI personalized learning
// roadmap (phases -> milestones -> modules) for the roadmap row at EntityID.
// ReplaceGeneratedTree deletes-then-reinserts the tree, so re-running this
// (job retry, or a user-triggered regenerate that reset status to
// 'generating' before re-enqueueing) is naturally idempotent — there is no
// separate "already generated" guard to get out of sync with retries.
func (h *LLMHandler) handleRoadmapGenerate(ctx context.Context, job jobs.Job, p LLMPayload) error {
	repo := roadmap.NewRepo(h.pool)

	rm, err := repo.GetByID(ctx, p.EntityID)
	if err != nil {
		if errors.Is(err, roadmap.ErrNotFound) {
			slog.InfoContext(ctx, "handlers.llm: roadmap_generate: roadmap not found or deleted, skipping",
				"roadmap_id", p.EntityID)
			return nil
		}
		return fmt.Errorf("handlers.llm: roadmap_generate: fetch roadmap %s: %w", p.EntityID, err)
	}

	// Tenant isolation: if the job is scoped to an org, verify the roadmap belongs to it.
	if job.OrgID != nil && *job.OrgID != "" {
		if rm.OrgID == nil || *rm.OrgID != *job.OrgID {
			return fmt.Errorf("handlers.llm: roadmap_generate: org_id mismatch, refusing to process (roadmap %s)", p.EntityID)
		}
	}

	if !h.ai.Available() {
		if err := repo.MarkFailed(ctx, rm.ID, "AI provider not available"); err != nil {
			return fmt.Errorf("handlers.llm: roadmap_generate: mark failed (roadmap %s): %w", p.EntityID, err)
		}
		return nil
	}

	llmCtx, cancel := context.WithTimeout(ctx, h.cfg.LLMTimeout)
	defer cancel()

	resp, err := h.ai.Complete(llmCtx, ai.CompletionRequest{
		SystemPrompt: ai.RoadmapSystemPrompt,
		UserPrompt:   buildRoadmapPrompt(rm),
		MaxTokens:    4096,
		JSONMode:     true,
	})
	if err != nil {
		reason := "AI generation failed. Please try regenerating."
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			reason = "AI generation timed out. Please try regenerating."
		}
		if markErr := repo.MarkFailed(ctx, rm.ID, reason); markErr != nil {
			return fmt.Errorf("handlers.llm: roadmap_generate: mark failed (roadmap %s): %w", p.EntityID, markErr)
		}
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			return fmt.Errorf("handlers.llm: roadmap_generate: AI timed out (roadmap %s): %w", p.EntityID, err)
		}
		return fmt.Errorf("handlers.llm: roadmap_generate: AI call (roadmap %s): %w", p.EntityID, err)
	}

	phases, err := roadmap.ParseAndMatchGenerated(ctx, h.pool, rm.OrgID, []byte(resp.Content))
	if err != nil {
		if markErr := repo.MarkFailed(ctx, rm.ID, "Could not parse the generated roadmap. Please try regenerating."); markErr != nil {
			return fmt.Errorf("handlers.llm: roadmap_generate: mark failed (roadmap %s): %w", p.EntityID, markErr)
		}
		return fmt.Errorf("handlers.llm: roadmap_generate: %w", err)
	}

	if err := repo.ReplaceGeneratedTree(ctx, rm.ID, phases); err != nil {
		return fmt.Errorf("handlers.llm: roadmap_generate: persist tree (roadmap %s): %w", p.EntityID, err)
	}

	slog.InfoContext(ctx, "handlers.llm: roadmap generated and stored",
		"roadmap_id", rm.ID, "phases", len(phases), "model", resp.Model)
	return nil
}

// handleRevisionPlanGenerate generates and stores an AI revision plan (ranked
// weak topics) for the revision_plans row at EntityID, reading the target
// user's actual per-course performance signals (lesson reflections +
// knowledge-check accuracy) as the only input the model is given to reason
// from. Idempotent the same way handleRoadmapGenerate is: ReplaceTopics
// deletes-then-reinserts, so a job retry or a user-triggered regenerate is
// safe to re-run.
func (h *LLMHandler) handleRevisionPlanGenerate(ctx context.Context, job jobs.Job, p LLMPayload) error {
	repo := revisionplan.NewRepo(h.pool)

	plan, err := repo.GetByID(ctx, p.EntityID)
	if err != nil {
		if errors.Is(err, revisionplan.ErrNotFound) {
			slog.InfoContext(ctx, "handlers.llm: revision_plan_generate: plan not found, skipping",
				"revision_plan_id", p.EntityID)
			return nil
		}
		return fmt.Errorf("handlers.llm: revision_plan_generate: fetch plan %s: %w", p.EntityID, err)
	}

	// Tenant isolation: if the job is scoped to an org, verify the plan belongs to it.
	if job.OrgID != nil && *job.OrgID != "" && plan.OrgID != *job.OrgID {
		return fmt.Errorf("handlers.llm: revision_plan_generate: org_id mismatch, refusing to process (plan %s)", p.EntityID)
	}

	if !h.ai.Available() {
		if err := repo.MarkFailed(ctx, plan.ID, "AI provider not available"); err != nil {
			return fmt.Errorf("handlers.llm: revision_plan_generate: mark failed (plan %s): %w", p.EntityID, err)
		}
		return nil
	}

	signals, err := repo.GatherSignals(ctx, plan.UserID, plan.CourseID)
	if err != nil {
		return fmt.Errorf("handlers.llm: revision_plan_generate: gather signals (plan %s): %w", p.EntityID, err)
	}
	validModuleIDs := make(map[string]bool, len(signals.Modules))
	for _, m := range signals.Modules {
		validModuleIDs[m.ModuleID] = true
	}

	llmCtx, cancel := context.WithTimeout(ctx, h.cfg.LLMTimeout)
	defer cancel()

	resp, err := h.ai.Complete(llmCtx, ai.CompletionRequest{
		SystemPrompt: ai.RevisionPlanSystemPrompt,
		UserPrompt:   revisionplan.BuildPrompt(signals),
		MaxTokens:    2048,
		JSONMode:     true,
	})
	if err != nil {
		reason := "AI generation failed. Please try again."
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			reason = "AI generation timed out. Please try again."
		}
		if markErr := repo.MarkFailed(ctx, plan.ID, reason); markErr != nil {
			return fmt.Errorf("handlers.llm: revision_plan_generate: mark failed (plan %s): %w", p.EntityID, markErr)
		}
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			return fmt.Errorf("handlers.llm: revision_plan_generate: AI timed out (plan %s): %w", p.EntityID, err)
		}
		return fmt.Errorf("handlers.llm: revision_plan_generate: AI call (plan %s): %w", p.EntityID, err)
	}

	topics, err := revisionplan.ParseTopics(resp.Content, validModuleIDs)
	if err != nil {
		if markErr := repo.MarkFailed(ctx, plan.ID, "Could not parse the generated plan. Please try again."); markErr != nil {
			return fmt.Errorf("handlers.llm: revision_plan_generate: mark failed (plan %s): %w", p.EntityID, markErr)
		}
		return fmt.Errorf("handlers.llm: revision_plan_generate: %w", err)
	}

	if err := repo.ReplaceTopics(ctx, plan.ID, topics); err != nil {
		return fmt.Errorf("handlers.llm: revision_plan_generate: persist topics (plan %s): %w", p.EntityID, err)
	}

	slog.InfoContext(ctx, "handlers.llm: revision plan generated and stored",
		"revision_plan_id", plan.ID, "topics", len(topics), "model", resp.Model)
	return nil
}

// handleMistakeCardGenerate rewrites the naive templated front/back on the SRS
// card auto-created when a mistake is logged (mistakes.Service.LogMistake)
// into an AI-authored flashcard, using the mistake's own original/corrected
// text as the only input. EntityID is the mistake's learning_annotations row
// id; the card to update is looked up by mistake_entry_id rather than passed
// in the payload, so a stale/replayed job always targets whatever card
// currently exists for that mistake. The templated card already works fine
// on its own, so an unavailable AI provider is a no-op skip, not a failure.
func (h *LLMHandler) handleMistakeCardGenerate(ctx context.Context, job jobs.Job, p LLMPayload) error {
	var category, originalText, correctedText string
	err := h.pool.QueryRow(ctx,
		`SELECT (meta->>'category')::text, text, (meta->>'corrected_text')::text
		 FROM learning_annotations
		 WHERE id = $1 AND annotation_type = 'mistake'`, p.EntityID,
	).Scan(&category, &originalText, &correctedText)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			slog.InfoContext(ctx, "handlers.llm: mistake_card_generate: mistake not found, skipping",
				"mistake_id", p.EntityID)
			return nil
		}
		return fmt.Errorf("handlers.llm: mistake_card_generate: fetch mistake %s: %w", p.EntityID, err)
	}

	var cardID string
	err = h.pool.QueryRow(ctx,
		`SELECT id FROM srs_cards WHERE mistake_entry_id = $1 AND source_type = 'mistake' LIMIT 1`,
		p.EntityID,
	).Scan(&cardID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			slog.InfoContext(ctx, "handlers.llm: mistake_card_generate: card not found (deleted?), skipping",
				"mistake_id", p.EntityID)
			return nil
		}
		return fmt.Errorf("handlers.llm: mistake_card_generate: fetch card for mistake %s: %w", p.EntityID, err)
	}

	if !h.ai.Available() {
		slog.InfoContext(ctx, "handlers.llm: mistake_card_generate: AI provider not available, leaving templated card as-is",
			"mistake_id", p.EntityID)
		return nil
	}

	llmCtx, cancel := context.WithTimeout(ctx, h.cfg.LLMTimeout)
	defer cancel()

	userPrompt := fmt.Sprintf("Category: %s\nOriginal (incorrect): %s\nCorrected: %s",
		category, ai.SanitizeAnswer(originalText), ai.SanitizeAnswer(correctedText))

	resp, err := h.ai.Complete(llmCtx, ai.CompletionRequest{
		SystemPrompt: ai.MistakeCardSystemPrompt,
		UserPrompt:   userPrompt,
		MaxTokens:    512,
		Temperature:  0.4,
		JSONMode:     true,
	})
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			return fmt.Errorf("handlers.llm: mistake_card_generate: AI timed out (mistake %s): %w", p.EntityID, err)
		}
		return fmt.Errorf("handlers.llm: mistake_card_generate: AI call (mistake %s): %w", p.EntityID, err)
	}

	var card struct {
		Front string `json:"front"`
		Back  string `json:"back"`
	}
	if err := json.Unmarshal([]byte(resp.Content), &card); err != nil {
		return fmt.Errorf("handlers.llm: mistake_card_generate: parse AI response (mistake %s): %w", p.EntityID, err)
	}
	card.Front = strings.TrimSpace(card.Front)
	card.Back = strings.TrimSpace(card.Back)
	if card.Front == "" || card.Back == "" {
		return fmt.Errorf("handlers.llm: mistake_card_generate: AI returned empty front/back (mistake %s)", p.EntityID)
	}

	if _, err := h.pool.Exec(ctx,
		`UPDATE srs_cards SET front = $1, back = $2 WHERE id = $3`,
		card.Front, card.Back, cardID,
	); err != nil {
		return fmt.Errorf("handlers.llm: mistake_card_generate: save card %s: %w", cardID, err)
	}

	slog.InfoContext(ctx, "handlers.llm: mistake card generated and stored",
		"mistake_id", p.EntityID, "card_id", cardID, "model", resp.Model)
	return nil
}

// handleDiaryAnalyze re-scans a saved diary entry (EntityID) for habit/task
// mentions and writes the resulting habit completions / whatnow task
// mutations into the writer's real records — see
// internal/diary.Service.Analyze for the actual resolution/dedup logic;
// this handler only fetches the entry, re-checks the content hash (a rapid
// series of saves can enqueue several diary_analyze jobs for the same entry;
// only the latest content is worth an AI call), and delegates.
func (h *LLMHandler) handleDiaryAnalyze(ctx context.Context, job jobs.Job, p LLMPayload) error {
	repo := diary.NewRepo(h.pool)
	entry, err := repo.GetByID(ctx, p.EntityID)
	if err != nil {
		if errors.Is(err, diary.ErrNotFound) {
			slog.InfoContext(ctx, "handlers.llm: diary_analyze: entry not found, skipping",
				"entry_id", p.EntityID)
			return nil
		}
		return fmt.Errorf("handlers.llm: diary_analyze: fetch entry %s: %w", p.EntityID, err)
	}

	if entry.AnalyzedHash == diary.ContentHash(entry.Content) {
		slog.InfoContext(ctx, "handlers.llm: diary_analyze: content unchanged since last analysis, skipping",
			"entry_id", p.EntityID)
		return nil
	}

	if !h.ai.Available() {
		slog.InfoContext(ctx, "handlers.llm: diary_analyze: AI provider not available, skipping",
			"entry_id", p.EntityID)
		return nil
	}

	llmCtx, cancel := context.WithTimeout(ctx, h.cfg.LLMTimeout)
	defer cancel()

	svc := diary.NewService(repo, h.ai, habit.NewService(habit.NewRepo(h.pool)), whatnow.NewService(whatnow.NewRepo(h.pool)))
	if err := svc.Analyze(llmCtx, entry); err != nil {
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			return fmt.Errorf("handlers.llm: diary_analyze: AI timed out (entry %s): %w", p.EntityID, err)
		}
		return fmt.Errorf("handlers.llm: diary_analyze: entry %s: %w", p.EntityID, err)
	}

	slog.InfoContext(ctx, "handlers.llm: diary entry analyzed", "entry_id", p.EntityID)
	return nil
}

// buildRoadmapPrompt turns a roadmap's stored inputs into the user prompt for
// ai.RoadmapSystemPrompt. All free-text fields are sanitized the same way as
// every other user-supplied AI input in this file (ai.SanitizeTopic).
func buildRoadmapPrompt(rm roadmap.Roadmap) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Goal: %s\n", ai.SanitizeTopic(rm.GoalDescription, 2000))
	if rm.TargetRole != nil && *rm.TargetRole != "" {
		fmt.Fprintf(&b, "Target role: %s\n", ai.SanitizeTopic(*rm.TargetRole, 200))
	}
	if rm.SkillLevel != nil && *rm.SkillLevel != "" {
		fmt.Fprintf(&b, "Current skill level: %s\n", ai.SanitizeTopic(*rm.SkillLevel, 100))
	}
	if rm.TimeframeWeeks != nil && *rm.TimeframeWeeks > 0 {
		fmt.Fprintf(&b, "Target timeframe: %d weeks\n", *rm.TimeframeWeeks)
	}
	if len(rm.FocusAreas) > 0 {
		fmt.Fprintf(&b, "Focus areas: %s\n", ai.SanitizeTopic(strings.Join(rm.FocusAreas, ", "), 500))
	}
	return b.String()
}
