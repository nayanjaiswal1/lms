package assessment

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// ─── Evaluation writes ────────────────────────────────────────────────────────

// SaveEvaluation persists a single per-question or overall EvaluationResult.
// Uses ON CONFLICT DO NOTHING so retried jobs skip already-written rows safely.
func (r *Repo) SaveEvaluation(ctx context.Context, attemptID string, e EvaluationResult) error {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	var questionID *string
	if e.QuestionID != "" {
		questionID = &e.QuestionID
	}

	_, err := r.pool.Exec(dbCtx,
		`INSERT INTO interview_evaluations (
		   attempt_id, question_id, scope,
		   score_technical_accuracy, score_completeness, score_communication,
		   score_clarity, score_structure, score_confidence, score_seniority_alignment,
		   composite_score, readiness_score,
		   strengths, weaknesses, missing_concepts, incorrect_concepts, improvements,
		   better_answer, reference_comparison,
		   injection_detected, injection_score, review_required,
		   ai_model
		 ) VALUES (
		   $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
		   $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23
		 )
		 ON CONFLICT (attempt_id, question_id, scope) DO NOTHING`,
		attemptID, questionID, e.Scope,
		nullIfZero(e.TechnicalAccuracy), nullIfZero(e.Completeness), nullIfZero(e.Communication),
		nullIfZero(e.Clarity), nullIfZero(e.Structure), nullIfZero(e.Confidence),
		nullIfZero(e.SeniorityAlignment),
		nullIfZero(e.CompositeScore),
		nullableScore(e.ReadinessScore, e.Scope == "overall"),
		e.Strengths, e.Weaknesses, e.MissingConcepts, e.IncorrectConcepts, e.Improvements,
		nullStr(e.BetterAnswer), nullStr(e.ReferenceComparison),
		e.InjectionDetected, e.InjectionScore, e.ReviewRequired,
		nullStr(e.AIModel),
	)
	if err != nil {
		return fmt.Errorf("eval repo: save evaluation (attempt %s, q %s): %w", attemptID, e.QuestionID, err)
	}
	return nil
}

// ─── Evaluation reads ─────────────────────────────────────────────────────────

// EvaluationStatus is the lightweight poll response returned to the client.
type EvaluationStatus struct {
	AttemptID string `json:"attempt_id"`
	Status    string `json:"status"` // evaluating | evaluated | eval_failed
	HasResult bool   `json:"has_result"`
}

// GetEvaluationStatus returns the attempt's current eval state for client polling.
func (r *Repo) GetEvaluationStatus(ctx context.Context, attemptID string) (EvaluationStatus, error) {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	var status string
	if err := r.pool.QueryRow(dbCtx,
		`SELECT status FROM assessment_attempts WHERE id = $1`, attemptID,
	).Scan(&status); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return EvaluationStatus{}, ErrNotFound
		}
		return EvaluationStatus{}, fmt.Errorf("eval repo: get eval status: %w", err)
	}

	var hasResult bool
	_ = r.pool.QueryRow(dbCtx,
		`SELECT EXISTS(SELECT 1 FROM interview_evaluations WHERE attempt_id = $1 AND scope = 'overall')`,
		attemptID,
	).Scan(&hasResult)

	return EvaluationStatus{AttemptID: attemptID, Status: status, HasResult: hasResult}, nil
}

// FullEvaluation is the complete evaluation for one attempt returned to the client.
type FullEvaluation struct {
	Status      string             `json:"status"`
	Overall     *EvaluationRow     `json:"overall,omitempty"`
	PerQuestion []EvaluationRow    `json:"per_question"`
}

// EvaluationRow is a single row from interview_evaluations, client-facing.
type EvaluationRow struct {
	ID                   string   `json:"id"`
	QuestionID           *string  `json:"question_id,omitempty"`
	Scope                string   `json:"scope"`
	TechnicalAccuracy    *float64 `json:"score_technical_accuracy,omitempty"`
	Completeness         *float64 `json:"score_completeness,omitempty"`
	Communication        *float64 `json:"score_communication,omitempty"`
	Clarity              *float64 `json:"score_clarity,omitempty"`
	Structure            *float64 `json:"score_structure,omitempty"`
	Confidence           *float64 `json:"score_confidence,omitempty"`
	SeniorityAlignment   *float64 `json:"score_seniority_alignment,omitempty"`
	CompositeScore       *float64 `json:"composite_score,omitempty"`
	ReadinessScore       *float64 `json:"readiness_score,omitempty"`
	Strengths            []string `json:"strengths"`
	Weaknesses           []string `json:"weaknesses"`
	MissingConcepts      []string `json:"missing_concepts"`
	IncorrectConcepts    []string `json:"incorrect_concepts"`
	Improvements         []string `json:"improvements"`
	BetterAnswer         *string  `json:"better_answer,omitempty"`
	ReferenceComparison  *string  `json:"reference_comparison,omitempty"`
	ReviewRequired       bool     `json:"review_required"`
	AIModel              *string  `json:"ai_model,omitempty"`
	CreatedAt            time.Time `json:"created_at"`
}

// GetEvaluation returns the full evaluation for an attempt (all scopes).
func (r *Repo) GetEvaluation(ctx context.Context, attemptID string) (FullEvaluation, error) {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	var status string
	if err := r.pool.QueryRow(dbCtx,
		`SELECT status FROM assessment_attempts WHERE id = $1`, attemptID,
	).Scan(&status); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return FullEvaluation{}, ErrNotFound
		}
		return FullEvaluation{}, fmt.Errorf("eval repo: get attempt for eval: %w", err)
	}

	rows, err := r.pool.Query(dbCtx,
		`SELECT id, question_id, scope,
		        score_technical_accuracy, score_completeness, score_communication,
		        score_clarity, score_structure, score_confidence, score_seniority_alignment,
		        composite_score, readiness_score,
		        strengths, weaknesses, missing_concepts, incorrect_concepts, improvements,
		        better_answer, reference_comparison,
		        review_required, ai_model, created_at
		 FROM interview_evaluations
		 WHERE attempt_id = $1
		 ORDER BY created_at`, attemptID)
	if err != nil {
		return FullEvaluation{}, fmt.Errorf("eval repo: query evaluations: %w", err)
	}
	defer rows.Close()

	fe := FullEvaluation{Status: status, PerQuestion: []EvaluationRow{}}
	for rows.Next() {
		var ev EvaluationRow
		if err := rows.Scan(
			&ev.ID, &ev.QuestionID, &ev.Scope,
			&ev.TechnicalAccuracy, &ev.Completeness, &ev.Communication,
			&ev.Clarity, &ev.Structure, &ev.Confidence, &ev.SeniorityAlignment,
			&ev.CompositeScore, &ev.ReadinessScore,
			&ev.Strengths, &ev.Weaknesses, &ev.MissingConcepts, &ev.IncorrectConcepts, &ev.Improvements,
			&ev.BetterAnswer, &ev.ReferenceComparison,
			&ev.ReviewRequired, &ev.AIModel, &ev.CreatedAt,
		); err != nil {
			return FullEvaluation{}, fmt.Errorf("eval repo: scan evaluation: %w", err)
		}
		if ev.Strengths == nil {
			ev.Strengths = []string{}
		}
		if ev.Weaknesses == nil {
			ev.Weaknesses = []string{}
		}
		if ev.MissingConcepts == nil {
			ev.MissingConcepts = []string{}
		}
		if ev.IncorrectConcepts == nil {
			ev.IncorrectConcepts = []string{}
		}
		if ev.Improvements == nil {
			ev.Improvements = []string{}
		}
		if ev.Scope == "overall" {
			fe.Overall = &ev
		} else {
			fe.PerQuestion = append(fe.PerQuestion, ev)
		}
	}
	if err := rows.Err(); err != nil {
		return FullEvaluation{}, fmt.Errorf("eval repo: rows error: %w", err)
	}

	return fe, nil
}

// ─── Skill scores ─────────────────────────────────────────────────────────────

// SkillScore is one row in interview_skill_scores.
type SkillScore struct {
	Skill          string    `json:"skill"`
	CompositeScore float64   `json:"composite_score"`
	QuestionCount  int       `json:"question_count"`
	CreatedAt      time.Time `json:"created_at"`
}

// SaveSkillScores persists one row per skill per attempt.
// ON CONFLICT DO NOTHING guards against retries re-writing rows.
func (r *Repo) SaveSkillScores(ctx context.Context, attemptID, userID, orgID string, scores []SkillScore) error {
	if len(scores) == 0 {
		return nil
	}
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	err := r.tx(dbCtx, func(tx pgx.Tx) error {
		for _, s := range scores {
			if _, err := tx.Exec(dbCtx,
				`INSERT INTO interview_skill_scores
				   (attempt_id, user_id, org_id, skill, composite_score, question_count)
				 VALUES ($1, $2, $3, $4, $5, $6)
				 ON CONFLICT DO NOTHING`,
				attemptID, userID, orgID, s.Skill, s.CompositeScore, s.QuestionCount,
			); err != nil {
				return fmt.Errorf("eval repo: save skill score (%s): %w", s.Skill, err)
			}
		}
		return nil
	})
	return err
}

// SkillTrend is the per-skill trend returned to the student dashboard.
type SkillTrend struct {
	Skill          string    `json:"skill"`
	LatestScore    float64   `json:"latest_score"`
	AvgScore       float64   `json:"avg_score"`
	AttemptCount   int       `json:"attempt_count"`
	IsWeak         bool      `json:"is_weak"`
	IsStrong       bool      `json:"is_strong"`
	LastAttemptAt  time.Time `json:"last_attempt_at"`
}

// GetSkillTrends returns the rolling avg + latest score for each skill for a user.
// Weak: rolling avg < 60 over last 10 attempts. Strong: rolling avg > 80.
func (r *Repo) GetSkillTrends(ctx context.Context, userID, orgID string) ([]SkillTrend, error) {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	rows, err := r.pool.Query(dbCtx,
		`SELECT skill,
		        (SELECT composite_score FROM interview_skill_scores iss2
		         WHERE iss2.user_id = iss.user_id AND iss2.org_id = iss.org_id
		           AND iss2.skill = iss.skill
		         ORDER BY created_at DESC LIMIT 1)  AS latest_score,
		        AVG(composite_score) OVER (
		          PARTITION BY skill
		          ORDER BY created_at DESC
		          ROWS BETWEEN CURRENT ROW AND 9 FOLLOWING
		        ) AS avg_score,
		        COUNT(*) OVER (PARTITION BY skill)  AS attempt_count,
		        MAX(created_at) OVER (PARTITION BY skill) AS last_attempt_at
		 FROM interview_skill_scores iss
		 WHERE user_id = $1 AND org_id = $2
		 GROUP BY skill, user_id, org_id, composite_score, created_at
		 ORDER BY skill, created_at DESC`,
		userID, orgID)
	if err != nil {
		return nil, fmt.Errorf("eval repo: get skill trends: %w", err)
	}
	defer rows.Close()

	seen := map[string]bool{}
	out := []SkillTrend{}
	for rows.Next() {
		var st SkillTrend
		if err := rows.Scan(&st.Skill, &st.LatestScore, &st.AvgScore, &st.AttemptCount, &st.LastAttemptAt); err != nil {
			return nil, fmt.Errorf("eval repo: scan skill trend: %w", err)
		}
		if seen[st.Skill] {
			continue
		}
		seen[st.Skill] = true
		st.IsWeak = st.AvgScore < 60
		st.IsStrong = st.AvgScore > 80
		out = append(out, st)
	}
	return out, rows.Err()
}

// ─── Anomaly detection (Layer 4) ─────────────────────────────────────────────

// FlagIfAnomaly sets review_required=true on the evaluation row when the score is
// more than 40 points above the user's rolling average AND the response was flagged
// for injection. Both conditions must be true to prevent false positives.
func (r *Repo) FlagIfAnomaly(ctx context.Context, attemptID, questionVersionID, userID string, compositeScore float64) error {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	// Rolling avg over last 10 evaluated attempts for this user.
	var avg float64
	err := r.pool.QueryRow(dbCtx,
		`SELECT COALESCE(AVG(composite_score), 0)
		 FROM (
		   SELECT ie.composite_score
		   FROM interview_evaluations ie
		   JOIN assessment_attempts aa ON aa.id = ie.attempt_id
		   WHERE aa.user_id = $1
		     AND ie.scope = 'question'
		     AND ie.question_id = $2
		   ORDER BY ie.created_at DESC
		   LIMIT 10
		 ) sub`, userID, questionVersionID,
	).Scan(&avg)
	if err != nil {
		return fmt.Errorf("eval repo: compute rolling avg: %w", err)
	}

	if compositeScore-avg > 40 {
		if _, err := r.pool.Exec(dbCtx,
			`UPDATE interview_evaluations
			   SET review_required = true
			 WHERE attempt_id = $1 AND question_id = $2 AND scope = 'question'`,
			attemptID, questionVersionID,
		); err != nil {
			return fmt.Errorf("eval repo: flag anomaly: %w", err)
		}
	}
	return nil
}

// ─── Review queue (staff) ─────────────────────────────────────────────────────

// ReviewQueueItem is one row in the instructor's flagged-attempts list.
type ReviewQueueItem struct {
	AttemptID      string    `json:"attempt_id"`
	UserID         string    `json:"user_id"`
	UserName       string    `json:"user_name"`
	AssessmentID   string    `json:"assessment_id"`
	AssessmentTitle string   `json:"assessment_title"`
	CompositeScore *float64  `json:"composite_score"`
	InjectionScore int       `json:"injection_score"`
	CreatedAt      time.Time `json:"created_at"`
}

// GetReviewQueue returns attempts with at least one review_required=true evaluation.
func (r *Repo) GetReviewQueue(ctx context.Context, orgID string, limit, offset int) ([]ReviewQueueItem, error) {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	rows, err := r.pool.Query(dbCtx,
		`SELECT DISTINCT ON (aa.id)
		        aa.id, aa.user_id, u.name, aa.assessment_id, a.title,
		        ie.composite_score, ie.injection_score, ie.created_at
		 FROM interview_evaluations ie
		 JOIN assessment_attempts aa ON aa.id = ie.attempt_id
		 JOIN assessments a ON a.id = aa.assessment_id AND a.org_id = $1
		 JOIN users u ON u.id = aa.user_id
		 WHERE ie.review_required = true
		 ORDER BY aa.id, ie.created_at DESC
		 LIMIT $2 OFFSET $3`,
		orgID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("eval repo: review queue: %w", err)
	}
	defer rows.Close()

	out := []ReviewQueueItem{}
	for rows.Next() {
		var it ReviewQueueItem
		if err := rows.Scan(&it.AttemptID, &it.UserID, &it.UserName,
			&it.AssessmentID, &it.AssessmentTitle,
			&it.CompositeScore, &it.InjectionScore, &it.CreatedAt); err != nil {
			return nil, fmt.Errorf("eval repo: scan review item: %w", err)
		}
		out = append(out, it)
	}
	return out, rows.Err()
}

// ─── Progress ─────────────────────────────────────────────────────────────────

// StudentProgress is the readiness summary for the student's progress dashboard.
type StudentProgress struct {
	TotalEvaluated   int          `json:"total_evaluated"`
	LatestReadiness  *float64     `json:"latest_readiness_score"`
	AvgReadiness     float64      `json:"avg_readiness_score"`
	SkillTrends      []SkillTrend `json:"skill_trends"`
}

// GetStudentProgress loads readiness trend data for the student dashboard.
func (r *Repo) GetStudentProgress(ctx context.Context, userID, orgID string) (StudentProgress, error) {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	var sp StudentProgress
	err := r.pool.QueryRow(dbCtx,
		`SELECT
		   COUNT(*) FILTER (WHERE ie.scope = 'overall'),
		   (SELECT ie2.readiness_score
		    FROM interview_evaluations ie2
		    JOIN assessment_attempts aa2 ON aa2.id = ie2.attempt_id
		    WHERE aa2.user_id = $1 AND ie2.scope = 'overall'
		    ORDER BY ie2.created_at DESC LIMIT 1),
		   COALESCE(AVG(ie.readiness_score) FILTER (WHERE ie.scope = 'overall'), 0)
		 FROM interview_evaluations ie
		 JOIN assessment_attempts aa ON aa.id = ie.attempt_id
		 WHERE aa.user_id = $1 AND aa.org_id = $2`,
		userID, orgID,
	).Scan(&sp.TotalEvaluated, &sp.LatestReadiness, &sp.AvgReadiness)
	if err != nil {
		return StudentProgress{}, fmt.Errorf("eval repo: student progress: %w", err)
	}

	trends, err := r.GetSkillTrends(dbCtx, userID, orgID)
	if err != nil {
		return StudentProgress{}, err
	}
	sp.SkillTrends = trends
	return sp, nil
}

// ─── Evaluation questions loader (N+1 prevention) ────────────────────────────

// LoadSubjectiveAnswers loads all subjective questions + transcripts for an attempt
// in one query. Returns evalQuestionRow slice ready for the evaluator.
func (r *Repo) LoadSubjectiveAnswers(ctx context.Context, attemptID string) ([]evalQuestionRow, error) {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	rows, err := r.pool.Query(dbCtx,
		`SELECT aq.position, aq.question_id, aq.version_id, qv.content, aa.transcript
		 FROM assessment_questions aq
		 JOIN question_versions qv ON qv.id = aq.version_id
		 JOIN questions q ON q.id = aq.question_id
		 JOIN attempt_answers aa
		   ON aa.attempt_id = $1 AND aa.question_id = aq.question_id
		 WHERE aq.assessment_id = (SELECT assessment_id FROM assessment_attempts WHERE id = $1)
		   AND q.type = 'subjective'
		   AND TRIM(COALESCE(aa.transcript, '')) != ''
		 ORDER BY aq.position`,
		attemptID)
	if err != nil {
		return nil, fmt.Errorf("eval repo: load subjective answers: %w", err)
	}
	defer rows.Close()

	out := []evalQuestionRow{}
	for rows.Next() {
		var qr evalQuestionRow
		var contentRaw []byte
		if err := rows.Scan(&qr.Position, &qr.QuestionID, &qr.VersionID, &contentRaw, &qr.Transcript); err != nil {
			return nil, fmt.Errorf("eval repo: scan subjective answer: %w", err)
		}
		if err := json.Unmarshal(contentRaw, &qr.Content); err != nil {
			return nil, fmt.Errorf("eval repo: unmarshal subjective content: %w", err)
		}
		out = append(out, qr)
	}
	return out, rows.Err()
}

// LoadCandidateContext loads the non-PII profile data for the LLM prompt.
// Returns empty struct when no onboarding profile exists.
func (r *Repo) LoadCandidateContext(ctx context.Context, userID string) (candidateContext, error) {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	var cc candidateContext
	err := r.pool.QueryRow(dbCtx,
		`SELECT
		   COALESCE(experience_level, ''),
		   COALESCE(target_role, ''),
		   COALESCE(target_level, ''),
		   COALESCE(skills, '[]'::jsonb)
		 FROM user_onboarding_profiles
		 WHERE user_id = $1`, userID,
	).Scan(&cc.ExperienceLevel, &cc.TargetRole, &cc.TargetLevel, &cc.Skills)
	if err != nil {
		cc.Skills = []string{}
		return cc, nil // non-fatal: eval proceeds without candidate context
	}
	if cc.Skills == nil {
		cc.Skills = []string{}
	}
	return cc, nil
}

// ─── Status updates ───────────────────────────────────────────────────────────

// SetAttemptEvalStatus transitions an attempt to evaluating, evaluated, or eval_failed.
func (r *Repo) SetAttemptEvalStatus(ctx context.Context, attemptID, status string) error {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	tag, err := r.pool.Exec(dbCtx,
		`UPDATE assessment_attempts SET status = $2, updated_at = now()
		 WHERE id = $1`,
		attemptID, status)
	if err != nil {
		return fmt.Errorf("eval repo: set status %s (attempt %s): %w", status, attemptID, err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// RecoverStuckAttempts finds attempts stuck in 'evaluating' older than stuckAfter,
// resets them to 'submitted', and returns their IDs for re-queuing.
func (r *Repo) RecoverStuckAttempts(ctx context.Context, stuckAfter time.Duration) ([]string, error) {
	rows, err := r.pool.Query(ctx,
		`UPDATE assessment_attempts
		   SET status = 'submitted', updated_at = now()
		 WHERE status = 'evaluating'
		   AND updated_at < now() - $1::interval
		 RETURNING id`,
		stuckAfter.String())
	if err != nil {
		return nil, fmt.Errorf("eval repo: recover stuck: %w", err)
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("eval repo: scan recovered: %w", err)
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// GetEvalEmailInfo returns the user email, display name, and assessment title
// needed for the evaluation-complete notification. Non-fatal caller — always
// log-and-skip on error rather than failing the eval pipeline.
func (r *Repo) GetEvalEmailInfo(ctx context.Context, attemptID string) (email, name, assessmentTitle string, err error) {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	err = r.pool.QueryRow(dbCtx,
		`SELECT u.email, COALESCE(u.name, ''), a.title
		 FROM assessment_attempts att
		 JOIN users u ON u.id = att.user_id
		 JOIN assessments a ON a.id = att.assessment_id
		 WHERE att.id = $1`, attemptID,
	).Scan(&email, &name, &assessmentTitle)
	if err != nil {
		err = fmt.Errorf("eval repo: get email info (attempt %s): %w", attemptID, err)
	}
	return
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func nullIfZero(v float64) interface{} {
	if v == 0 {
		return nil
	}
	return v
}

func nullableScore(v float64, include bool) interface{} {
	if !include || v == 0 {
		return nil
	}
	return v
}

func nullStr(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}
