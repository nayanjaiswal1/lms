package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/rewards"
)

// EvalPayload is the JSON payload stored in jobs.payload for eval.subjective jobs.
type EvalPayload struct {
	AttemptID string `json:"attempt_id"`
}

// EvalHandler implements jobs.Handler for HandlerEvalSubjective jobs.
// It ports the full processJob logic from assessment.EvalWorkerPool into the
// Job Management System, preserving every DB call, AI call, and state transition.
type EvalHandler struct {
	repo       *assessment.Repo
	ai         ai.LLMProvider
	cfg        *config.Config
	pool       *pgxpool.Pool
	rewardsSvc *rewards.Service
}

// NewEvalHandler constructs an EvalHandler with all dependencies injected.
func NewEvalHandler(repo *assessment.Repo, aiProvider ai.LLMProvider, cfg *config.Config, pool *pgxpool.Pool, rewardsSvc *rewards.Service) *EvalHandler {
	return &EvalHandler{
		repo:       repo,
		ai:         aiProvider,
		cfg:        cfg,
		pool:       pool,
		rewardsSvc: rewardsSvc,
	}
}

// Handle processes a single eval.subjective job. The worker pool handles retry
// and final failure transitions — Handle only needs to return an error on failure.
func (h *EvalHandler) Handle(ctx context.Context, job jobs.Job) error {
	var payload EvalPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("handlers.eval: unmarshal payload: %w", err)
	}
	if payload.AttemptID == "" {
		return fmt.Errorf("handlers.eval: payload missing attempt_id")
	}

	jobCtx, cancel := context.WithTimeout(ctx, h.cfg.EvalJobTimeout)
	defer cancel()

	start := time.Now()

	// Mark attempt as evaluating in DB (source of truth).
	if err := h.repo.SetAttemptEvalStatus(jobCtx, payload.AttemptID, "evaluating"); err != nil {
		return fmt.Errorf("handlers.eval: mark evaluating (attempt %s): %w", payload.AttemptID, err)
	}

	// Load subjective questions + transcripts (2 queries total, no N+1).
	questions, err := h.repo.LoadSubjectiveAnswers(jobCtx, payload.AttemptID)
	if err != nil {
		return fmt.Errorf("handlers.eval: load answers (attempt %s): %w", payload.AttemptID, err)
	}
	if len(questions) == 0 {
		// No subjective answers — mark evaluated immediately.
		if err := h.repo.SetAttemptEvalStatus(jobCtx, payload.AttemptID, "evaluated"); err != nil {
			return fmt.Errorf("handlers.eval: mark evaluated (attempt %s): %w", payload.AttemptID, err)
		}
		return nil
	}

	// Load attempt to get user_id for candidate context + skill score writes.
	// Also used for tenant isolation: verify the attempt belongs to the job's org.
	attempt, err := h.repo.GetAttempt(jobCtx, payload.AttemptID)
	if err != nil {
		return fmt.Errorf("handlers.eval: get attempt (attempt %s): %w", payload.AttemptID, err)
	}
	if job.OrgID != nil && *job.OrgID != "" && attempt.OrgID != *job.OrgID {
		return fmt.Errorf("handlers.eval: org_id mismatch, refusing to process (attempt %s)", payload.AttemptID)
	}

	cand, err := h.repo.LoadCandidateContext(jobCtx, attempt.UserID)
	if err != nil {
		return fmt.Errorf("handlers.eval: load candidate context (attempt %s): %w", payload.AttemptID, err)
	}

	slog.Info("eval started", "attempt", payload.AttemptID, "questions", len(questions))

	// Per-question evaluation loop.
	perQuestion := make([]assessment.EvaluationResult, 0, len(questions))
	for i, q := range questions {
		qStart := time.Now()

		// Layer 1: sanitize transcript.
		cleaned, flagged, injScore := assessment.SanitizeTranscript(q.Transcript)
		q.Transcript = cleaned

		result, err := assessment.EvalQuestion(jobCtx, h.ai, q, cand, flagged, injScore)
		if err != nil {
			return fmt.Errorf("handlers.eval: question %d/%d (attempt %s): %w", i+1, len(questions), payload.AttemptID, err)
		}
		result.InjectionDetected = flagged
		result.InjectionScore = injScore

		// Layer 4: anomaly detection (flag if score spikes + injection).
		if flagged {
			if flagErr := h.repo.FlagIfAnomaly(jobCtx, payload.AttemptID, q.VersionID, attempt.UserID, result.CompositeScore); flagErr != nil {
				slog.Warn("handlers.eval: anomaly detection failed", "attempt", payload.AttemptID, "q", q.VersionID, "error", flagErr)
			}
			if result.ReviewRequired {
				result.ReviewRequired = true
			}
		}

		if err := h.repo.SaveEvaluation(jobCtx, payload.AttemptID, result); err != nil {
			return fmt.Errorf("handlers.eval: save evaluation q %d (attempt %s): %w", i+1, payload.AttemptID, err)
		}

		slog.Info("question done", "attempt", payload.AttemptID, "q", i+1, "score", result.CompositeScore,
			"ms", time.Since(qStart).Milliseconds())

		perQuestion = append(perQuestion, result)
	}

	// Overall evaluation.
	overall, err := assessment.EvalOverall(jobCtx, h.ai, questions, perQuestion)
	if err != nil {
		return fmt.Errorf("handlers.eval: overall (attempt %s): %w", payload.AttemptID, err)
	}
	if err := h.repo.SaveEvaluation(jobCtx, payload.AttemptID, overall); err != nil {
		return fmt.Errorf("handlers.eval: save overall (attempt %s): %w", payload.AttemptID, err)
	}

	// Write skill scores for O(1) trend queries.
	skillScores := assessment.BuildSkillScores(questions, perQuestion)
	if err := h.repo.SaveSkillScores(jobCtx, payload.AttemptID, attempt.UserID, attempt.OrgID, skillScores); err != nil {
		slog.Warn("handlers.eval: save skill scores", "attempt", payload.AttemptID, "error", err)
		// non-fatal: trend queries degrade gracefully if this row is missing
	}

	// Mark attempt evaluated in DB.
	if err := h.repo.SetAttemptEvalStatus(jobCtx, payload.AttemptID, "evaluated"); err != nil {
		return fmt.Errorf("handlers.eval: mark evaluated (attempt %s): %w", payload.AttemptID, err)
	}

	// Award XP based on the overall composite score (non-fatal).
	if h.rewardsSvc != nil {
		h.awardEvalXP(jobCtx, payload.AttemptID, attempt, overall.CompositeScore)
	}

	// Notify the student (non-fatal — eval is complete regardless of email delivery).
	email, uname, title, infoErr := h.repo.GetEvalEmailInfo(jobCtx, payload.AttemptID)
	if infoErr != nil {
		slog.Warn("handlers.eval: get email info", "attempt", payload.AttemptID, "error", infoErr)
	} else {
		if err := h.enqueueEmailNotification(jobCtx, attempt.OrgID, email, uname, title, payload.AttemptID); err != nil {
			slog.Warn("handlers.eval: enqueue email notification", "attempt", payload.AttemptID, "error", err)
		}
	}

	slog.Info("eval complete", "attempt", payload.AttemptID, "overall", overall.CompositeScore,
		"ms", time.Since(start).Milliseconds())
	return nil
}

// awardEvalXP awards XP for a subjective/interview attempt based on the overall
// composite score (0–100). A score ≥ 70 counts as a pass. All errors are logged
// and swallowed — reward failures must not prevent eval completion.
func (h *EvalHandler) awardEvalXP(ctx context.Context, attemptID string, att assessment.Attempt, compositeScore float64) {
	const passThreshold = 70.0
	if compositeScore < passThreshold {
		return
	}
	xp := rewards.XPQuizPassedRepeat
	if att.AttemptNumber == 1 {
		xp = rewards.XPQuizPassedFirst
	}
	refType := "attempt"
	result := h.rewardsSvc.AwardXP(ctx, rewards.AwardXPRequest{
		UserID:  att.UserID,
		OrgID:   att.OrgID,
		Reason:  "quiz_passed",
		RefID:   &att.ID,
		RefType: &refType,
		XP:      xp,
	})
	if compositeScore == 100 {
		perfect := h.rewardsSvc.AwardXP(ctx, rewards.AwardXPRequest{
			UserID:  att.UserID,
			OrgID:   att.OrgID,
			Reason:  "quiz_perfect",
			RefID:   &att.ID,
			RefType: &refType,
			XP:      rewards.XPQuizPerfectBonus,
		})
		result.XPGained += perfect.XPGained
		result.NewAchievements = append(result.NewAchievements, perfect.NewAchievements...)
		if perfect.NewLevel != nil {
			result.NewLevel = perfect.NewLevel
		}
	}
	// Streak update — mirrors the sync MCQ path in awardAttemptXP.
	streakResult := h.rewardsSvc.UpdateStreakAndCheckMilestones(ctx, att.UserID, att.OrgID)
	result.XPGained += streakResult.XPGained
	result.NewAchievements = append(result.NewAchievements, streakResult.NewAchievements...)
	if streakResult.NewLevel != nil {
		result.NewLevel = streakResult.NewLevel
	}

	if err := h.repo.SetAttemptRewardResult(ctx, attemptID, result); err != nil {
		slog.Warn("handlers.eval: persist reward result", "attempt", attemptID, "err", err)
	}
}

// enqueueEmailNotification inserts an email.send job directly into the jobs table
// via the pool, bypassing the store layer to avoid a circular import. The
// idempotency key guarantees exactly-once delivery even if Handle is retried.
func (h *EvalHandler) enqueueEmailNotification(ctx context.Context, orgID, to, toName, assessmentTitle, attemptID string) error {
	payload, err := json.Marshal(map[string]any{
		"type":    "eval_complete",
		"to":      to,
		"to_name": toName,
		"template_data": map[string]any{
			"attempt_id":       attemptID,
			"assessment_title": assessmentTitle,
		},
	})
	if err != nil {
		return fmt.Errorf("handlers.eval: marshal email payload: %w", err)
	}

	idempKey := "eval_complete:" + attemptID
	_, execErr := h.pool.Exec(ctx, `
		INSERT INTO jobs (handler, status, priority, payload, org_id, idempotency_key)
		VALUES ($1, 'queued', $2, $3, $4, $5)
		ON CONFLICT (idempotency_key) DO NOTHING`,
		HandlerEmailSend, jobs.PriorityHigh, payload, orgID, idempKey,
	)
	if execErr != nil {
		return fmt.Errorf("handlers.eval: insert email job: %w", execErr)
	}
	return nil
}
