package assessment

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// AssignedAssessment is an assessment visible to a student plus their progress.
type AssignedAssessment struct {
	Assessment
	AttemptsUsed        int      `json:"attempts_used"`
	BestPercentage      *float64 `json:"best_percentage"`
	BestPassed          *bool    `json:"best_passed"`
	ActiveAttempt       *string  `json:"active_attempt_id"`
	EvaluatingAttemptID *string  `json:"evaluating_attempt_id"`
}

// ListAssignedForUser returns assessments the user must take (assigned directly or
// via batch) that are in a takeable state, with the user's attempt summary.
func (r *Repo) ListAssignedForUser(ctx context.Context, orgID, userID string) ([]AssignedAssessment, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT a.id, a.org_id, a.title, a.slug, a.description, a.type, a.status,
		        a.parent_type, a.parent_id, a.duration_minutes, a.pass_percentage,
		        a.max_attempts, a.total_points, a.mock_mode, a.shuffle_questions, a.shuffle_options,
		        a.allow_backtrack, a.show_results, a.starts_at, a.ends_at, a.proctoring,
		        a.created_by, a.published_at, a.created_at, a.updated_at,
		        (SELECT count(*) FROM assessment_questions aq WHERE aq.assessment_id = a.id),
		        (SELECT count(*) FROM assessment_attempts at
		           WHERE at.assessment_id = a.id AND at.user_id = $2
		             AND at.status IN ('submitted','evaluating','evaluated','eval_failed','expired')),
		        (SELECT max(at.percentage) FROM assessment_attempts at
		           WHERE at.assessment_id = a.id AND at.user_id = $2
		             AND at.status IN ('evaluated')),
		        (SELECT bool_or(at.passed) FROM assessment_attempts at
		           WHERE at.assessment_id = a.id AND at.user_id = $2 AND at.status = 'evaluated'),
		        (SELECT at.id FROM assessment_attempts at
		           WHERE at.assessment_id = a.id AND at.user_id = $2
		             AND at.status IN ('created','in_progress') LIMIT 1),
		        (SELECT at.id FROM assessment_attempts at
		           WHERE at.assessment_id = a.id AND at.user_id = $2
		             AND at.status IN ('submitted','evaluating') LIMIT 1)
		 FROM assessments a
		 WHERE a.org_id = $1
		   AND a.status IN ('published','scheduled','active')
		   AND EXISTS (
		     SELECT 1 FROM assessment_assignments aa
		     WHERE aa.assessment_id = a.id
		       AND ((aa.assignee_type = 'student' AND aa.assignee_id = $2)
		         OR (aa.assignee_type = 'batch' AND aa.assignee_id IN
		             (SELECT batch_id FROM batch_members WHERE user_id = $2)))
		   )
		 ORDER BY a.updated_at DESC`, orgID, userID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list assigned: %w", err)
	}
	defer rows.Close()

	out := []AssignedAssessment{}
	for rows.Next() {
		var aa AssignedAssessment
		var proctoring []byte
		if err := rows.Scan(&aa.ID, &aa.OrgID, &aa.Title, &aa.Slug, &aa.Description, &aa.Type, &aa.Status,
			&aa.ParentType, &aa.ParentID, &aa.DurationMinutes, &aa.PassPercentage,
			&aa.MaxAttempts, &aa.TotalPoints, &aa.MockMode, &aa.ShuffleQuestions, &aa.ShuffleOptions,
			&aa.AllowBacktrack, &aa.ShowResults, &aa.StartsAt, &aa.EndsAt, &proctoring,
			&aa.CreatedBy, &aa.PublishedAt, &aa.CreatedAt, &aa.UpdatedAt, &aa.QuestionCount,
			&aa.AttemptsUsed, &aa.BestPercentage, &aa.BestPassed, &aa.ActiveAttempt,
			&aa.EvaluatingAttemptID); err != nil {
			return nil, fmt.Errorf("assessment: scan assigned: %w", err)
		}
		aa.Proctoring = DefaultProctoring()
		if len(proctoring) > 0 {
			if err := json.Unmarshal(proctoring, &aa.Proctoring); err != nil {
				return nil, fmt.Errorf("assessment: decode proctoring: %w", err)
			}
		}
		out = append(out, aa)
	}
	return out, rows.Err()
}

// CountFinalAttempts counts a user's spent attempts (anything past in-progress).
func (r *Repo) CountFinalAttempts(ctx context.Context, assessmentID, userID string) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT count(*) FROM assessment_attempts
		 WHERE assessment_id = $1 AND user_id = $2
		   AND status IN ('submitted','evaluating','evaluated','eval_failed','expired')`,
		assessmentID, userID).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("assessment: count attempts: %w", err)
	}
	return n, nil
}

// FindActiveAttempt returns an in-flight attempt id for resume, if any.
func (r *Repo) FindActiveAttempt(ctx context.Context, assessmentID, userID string) (string, bool, error) {
	var id string
	err := r.pool.QueryRow(ctx,
		`SELECT id FROM assessment_attempts
		 WHERE assessment_id = $1 AND user_id = $2 AND status IN ('created','in_progress')
		 ORDER BY created_at DESC LIMIT 1`, assessmentID, userID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, nil
	}
	if err != nil {
		return "", false, fmt.Errorf("assessment: find active attempt: %w", err)
	}
	return id, true, nil
}

// CreateAttempt inserts a started attempt with its snapshot and seeds blank
// answer rows for each question, all in one transaction.
func (r *Repo) CreateAttempt(ctx context.Context, a Attempt, questions []AssessmentQuestion) (Attempt, error) {
	err := r.tx(ctx, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx,
			`INSERT INTO assessment_attempts
			   (assessment_id, user_id, org_id, attempt_number, status, started_at,
			    expires_at, snapshot)
			 VALUES ($1, $2, $3, $4, 'in_progress', $5, $6, $7)
			 RETURNING id, created_at`,
			a.AssessmentID, a.UserID, a.OrgID, a.AttemptNumber, a.StartedAt,
			a.ExpiresAt, a.Snapshot).Scan(&a.ID, &a.CreatedAt)
		if err != nil {
			return fmt.Errorf("assessment: insert attempt: %w", err)
		}
		for _, q := range questions {
			if _, err := tx.Exec(ctx,
				`INSERT INTO attempt_answers
				   (attempt_id, assessment_question_id, question_id, max_points)
				 VALUES ($1, $2, $3, $4)`,
				a.ID, q.ID, q.QuestionID, q.Points); err != nil {
				return fmt.Errorf("assessment: seed answer row: %w", err)
			}
		}
		return nil
	})
	if err != nil {
		return Attempt{}, err
	}
	a.Status = AttemptInProgress
	return a, nil
}

// GetAttempt loads an attempt scoped to org and (optionally) owner.
func (r *Repo) GetAttempt(ctx context.Context, attemptID string) (Attempt, error) {
	var a Attempt
	err := r.pool.QueryRow(ctx,
		`SELECT id, assessment_id, user_id, org_id, attempt_number, status,
		        started_at, submitted_at, evaluated_at, expires_at, duration_seconds,
		        score, max_score, percentage, passed, auto_submitted,
		        snapshot, proctoring_summary, created_at
		 FROM assessment_attempts WHERE id = $1`, attemptID,
	).Scan(&a.ID, &a.AssessmentID, &a.UserID, &a.OrgID, &a.AttemptNumber, &a.Status,
		&a.StartedAt, &a.SubmittedAt, &a.EvaluatedAt, &a.ExpiresAt, &a.DurationSeconds,
		&a.Score, &a.MaxScore, &a.Percentage, &a.Passed, &a.AutoSubmitted,
		&a.Snapshot, &a.ProctoringSummary, &a.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Attempt{}, ErrNotFound
		}
		return Attempt{}, fmt.Errorf("assessment: get attempt: %w", err)
	}
	return a, nil
}

// SaveAnswer upserts a student's answer for one question during an attempt.
// transcript is non-nil only for subjective questions.
func (r *Repo) SaveAnswer(ctx context.Context, attemptID, assessmentQuestionID string, answer json.RawMessage, transcript *string, timeSpent int) error {
	answer = orEmptyJSON(answer)
	tag, err := r.pool.Exec(ctx,
		`UPDATE attempt_answers
		   SET answer                = $3,
		       transcript            = COALESCE($4, transcript),
		       time_spent_seconds    = time_spent_seconds + $5,
		       updated_at            = now()
		 WHERE attempt_id = $1 AND assessment_question_id = $2`,
		attemptID, assessmentQuestionID, answer, transcript, timeSpent)
	if err != nil {
		return fmt.Errorf("assessment: save answer: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// AnswerRow is a stored answer joined to its pinned question content for grading.
type AnswerRow struct {
	ID                   string
	AssessmentQuestionID string
	QuestionID           string
	Type                 string
	Title                string
	Answer               json.RawMessage
	Transcript           *string
	MaxPoints            float64
	Content              json.RawMessage
}

// ListAnswersForGrading returns every answer of an attempt with the question type
// and pinned content needed to evaluate it.
func (r *Repo) ListAnswersForGrading(ctx context.Context, attemptID string) ([]AnswerRow, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT ans.id, ans.assessment_question_id, ans.question_id, q.type, q.title,
		        ans.answer, ans.transcript, ans.max_points, qv.content
		 FROM attempt_answers ans
		 JOIN assessment_questions aq ON aq.id = ans.assessment_question_id
		 JOIN questions q ON q.id = ans.question_id
		 JOIN question_versions qv ON qv.id = aq.version_id
		 WHERE ans.attempt_id = $1
		 ORDER BY aq.position`, attemptID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list answers for grading: %w", err)
	}
	defer rows.Close()

	out := []AnswerRow{}
	for rows.Next() {
		var a AnswerRow
		var answer, content []byte
		if err := rows.Scan(&a.ID, &a.AssessmentQuestionID, &a.QuestionID, &a.Type, &a.Title,
			&answer, &a.Transcript, &a.MaxPoints, &content); err != nil {
			return nil, fmt.Errorf("assessment: scan answer row: %w", err)
		}
		a.Answer = answer
		a.Content = content
		out = append(out, a)
	}
	return out, rows.Err()
}

// GradedAnswer is the evaluation result for one answer.
type GradedAnswer struct {
	AnswerID      string
	IsCorrect     bool
	PointsAwarded float64
}

// FinalizeAttempt writes per-answer grades and the attempt's aggregate result in
// one transaction, moving the attempt to the given final status.
func (r *Repo) FinalizeAttempt(ctx context.Context, attemptID, status string, score, maxScore, percentage float64, passed, autoSubmitted bool, durationSeconds int, summary json.RawMessage, graded []GradedAnswer) error {
	return r.tx(ctx, func(tx pgx.Tx) error {
		if len(graded) > 0 {
			// Batch-update all graded answers in a single statement using unnest
			// instead of one UPDATE per answer (N+1).
			answerIDs := make([]string, len(graded))
			isCorrects := make([]bool, len(graded))
			pointsAwarded := make([]float64, len(graded))
			for i, g := range graded {
				answerIDs[i] = g.AnswerID
				isCorrects[i] = g.IsCorrect
				pointsAwarded[i] = g.PointsAwarded
			}
			if _, err := tx.Exec(ctx,
				`UPDATE attempt_answers ans
				 SET is_correct     = u.is_correct,
				     points_awarded = u.points_awarded,
				     evaluated_at   = now()
				 FROM unnest($1::uuid[], $2::boolean[], $3::numeric[])
				      AS u(id, is_correct, points_awarded)
				 WHERE ans.id = u.id`,
				answerIDs, isCorrects, pointsAwarded); err != nil {
				return fmt.Errorf("assessment: write graded answers: %w", err)
			}
		}
		tag, err := tx.Exec(ctx,
			`UPDATE assessment_attempts
			   SET status = $2, score = $3, max_score = $4, percentage = $5,
			       passed = $6, auto_submitted = $7, duration_seconds = $8,
			       submitted_at = COALESCE(submitted_at, now()),
			       evaluated_at = CASE WHEN $2 = 'evaluated' THEN now() ELSE evaluated_at END,
			       proctoring_summary = $9, updated_at = now()
			 WHERE id = $1 AND status IN ('created','in_progress','submitted','evaluating')`,
			attemptID, status, score, maxScore, percentage, passed, autoSubmitted,
			durationSeconds, summary)
		if err != nil {
			return fmt.Errorf("assessment: finalize attempt: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrConflict
		}
		return nil
	})
}

// RecordCodingSubmission persists a coding execution result linked to an answer.
func (r *Repo) RecordCodingSubmission(ctx context.Context, answerID, language, source string, res RunResult) error {
	resultJSON, err := json.Marshal(res.Cases)
	if err != nil {
		return fmt.Errorf("assessment: marshal coding result: %w", err)
	}
	_, err = r.pool.Exec(ctx,
		`INSERT INTO coding_submissions
		   (attempt_answer_id, language, source_code, status, tests_total, tests_passed,
		    runtime_ms, memory_kb, compile_output, result, evaluated_at)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, now())`,
		answerID, language, source, res.Status, res.TestsTotal, res.TestsPassed,
		res.RuntimeMs, res.MemoryKb, res.CompileOutput, resultJSON)
	if err != nil {
		return fmt.Errorf("assessment: record coding submission: %w", err)
	}
	return nil
}

// ReviewItem is the per-question breakdown shown to a student after grading or
// to staff when inspecting an attempt. Correct answers and explanations are
// resolved from the pinned version content.
type ReviewItem struct {
	QuestionID    string          `json:"question_id"`
	Title         string          `json:"title"`
	Type          string          `json:"type"`
	Position      int             `json:"position"`
	MaxPoints     float64         `json:"max_points"`
	PointsAwarded float64         `json:"points_awarded"`
	IsCorrect     *bool           `json:"is_correct"`
	Answer        json.RawMessage `json:"answer"`
	CorrectAnswer json.RawMessage `json:"correct_answer,omitempty"`
	Explanation   string          `json:"explanation,omitempty"`
	Coding        json.RawMessage `json:"coding_result,omitempty"`
}

// AttemptReview assembles the per-question review for a finished attempt.
func (r *Repo) AttemptReview(ctx context.Context, attemptID string) ([]ReviewItem, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT q.id, q.title, q.type, aq.position, ans.max_points, ans.points_awarded,
		        ans.is_correct, ans.answer, qv.content, ans.id
		 FROM attempt_answers ans
		 JOIN assessment_questions aq ON aq.id = ans.assessment_question_id
		 JOIN questions q ON q.id = ans.question_id
		 JOIN question_versions qv ON qv.id = aq.version_id
		 WHERE ans.attempt_id = $1
		 ORDER BY aq.position`, attemptID)
	if err != nil {
		return nil, fmt.Errorf("assessment: attempt review: %w", err)
	}
	defer rows.Close()

	out := []ReviewItem{}
	answerIDs := []string{}
	for rows.Next() {
		var it ReviewItem
		var answer, content []byte
		var answerID string
		if err := rows.Scan(&it.QuestionID, &it.Title, &it.Type, &it.Position, &it.MaxPoints,
			&it.PointsAwarded, &it.IsCorrect, &answer, &content, &answerID); err != nil {
			return nil, fmt.Errorf("assessment: scan review: %w", err)
		}
		it.Answer = answer

		switch it.Type {
		case QuestionTypeMCQ:
			var c MCQContent
			if err := json.Unmarshal(content, &c); err == nil {
				correct := []string{}
				for _, o := range c.Options {
					if o.IsCorrect {
						correct = append(correct, o.ID)
					}
				}
				if ca, err := json.Marshal(map[string]any{"selected": correct}); err == nil {
					it.CorrectAnswer = ca
				}
				it.Explanation = c.Explanation
			}
		}
		out = append(out, it)
		answerIDs = append(answerIDs, answerID)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	if len(answerIDs) == 0 {
		return out, nil
	}

	// Batch-load the latest coding submission for every answer in one query,
	// avoiding a per-answer N+1. We use DISTINCT ON to get only the most recent
	// row per answer, ordered by created_at DESC.
	codingRows, err := r.pool.Query(ctx,
		`SELECT DISTINCT ON (attempt_answer_id)
		        attempt_answer_id, status, tests_passed, tests_total
		 FROM coding_submissions
		 WHERE attempt_answer_id = ANY($1)
		 ORDER BY attempt_answer_id, created_at DESC`, answerIDs)
	if err != nil {
		return nil, fmt.Errorf("assessment: load coding summaries: %w", err)
	}
	defer codingRows.Close()

	codingByAnswerID := make(map[string]json.RawMessage, len(answerIDs))
	for codingRows.Next() {
		var answerID, status string
		var passed, total int
		if err := codingRows.Scan(&answerID, &status, &passed, &total); err != nil {
			return nil, fmt.Errorf("assessment: scan coding summary: %w", err)
		}
		summary, _ := json.Marshal(map[string]any{
			"status": status, "tests_passed": passed, "tests_total": total,
		})
		codingByAnswerID[answerID] = summary
	}
	if err := codingRows.Err(); err != nil {
		return nil, fmt.Errorf("assessment: coding summaries rows: %w", err)
	}

	for i, answerID := range answerIDs {
		if out[i].Type != QuestionTypeCoding {
			continue
		}
		if summary, ok := codingByAnswerID[answerID]; ok {
			out[i].Coding = summary
		}
	}

	return out, nil
}

// ─── Anti-cheat events ───────────────────────────────────────────────────────

// orEmptyJSON guarantees a non-NULL jsonb payload for NOT NULL columns whose
// caller may pass an omitted (nil) value.
func orEmptyJSON(b json.RawMessage) json.RawMessage {
	if len(b) == 0 {
		return json.RawMessage(`{}`)
	}
	return b
}

// InsertEvent appends a proctoring event to the attempt's log.
func (r *Repo) InsertEvent(ctx context.Context, attemptID, userID, eventType, severity string, metadata json.RawMessage, clientTS *time.Time) error {
	metadata = orEmptyJSON(metadata)
	_, err := r.pool.Exec(ctx,
		`INSERT INTO attempt_events (attempt_id, user_id, event_type, severity, metadata, client_ts)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		attemptID, userID, eventType, severity, metadata, clientTS)
	if err != nil {
		return fmt.Errorf("assessment: insert event: %w", err)
	}
	return nil
}

// EventTally is a per-type count of proctoring events for an attempt.
type EventTally map[string]int

// TallyEvents counts events grouped by type for an attempt.
func (r *Repo) TallyEvents(ctx context.Context, attemptID string) (EventTally, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT event_type, count(*) FROM attempt_events
		 WHERE attempt_id = $1 GROUP BY event_type`, attemptID)
	if err != nil {
		return nil, fmt.Errorf("assessment: tally events: %w", err)
	}
	defer rows.Close()

	tally := EventTally{}
	for rows.Next() {
		var t string
		var n int
		if err := rows.Scan(&t, &n); err != nil {
			return nil, fmt.Errorf("assessment: scan tally: %w", err)
		}
		tally[t] = n
	}
	return tally, rows.Err()
}

// ProctoringEvent is one row in the attempt event log, for review screens.
type ProctoringEvent struct {
	EventType string          `json:"event_type"`
	Severity  string          `json:"severity"`
	Metadata  json.RawMessage `json:"metadata"`
	CreatedAt time.Time       `json:"created_at"`
}

func (r *Repo) ListEvents(ctx context.Context, attemptID string) ([]ProctoringEvent, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT event_type, severity, metadata, created_at
		 FROM attempt_events WHERE attempt_id = $1 ORDER BY created_at`, attemptID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list events: %w", err)
	}
	defer rows.Close()

	out := []ProctoringEvent{}
	for rows.Next() {
		var e ProctoringEvent
		var meta []byte
		if err := rows.Scan(&e.EventType, &e.Severity, &meta, &e.CreatedAt); err != nil {
			return nil, fmt.Errorf("assessment: scan event: %w", err)
		}
		e.Metadata = meta
		out = append(out, e)
	}
	return out, rows.Err()
}
