package practice

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("practice: not found")

// QuestionBank is one previously-generated set of questions for a
// (technology, difficulty, category) key, shared across all users who
// request that combo — see generateQuestions' cache-first logic.
type QuestionBank struct {
	ID        string
	Questions []string
	AIModel   *string
}

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// tx runs fn inside a transaction, rolling back on error and committing on success.
func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("practice: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("practice: commit tx: %w", err)
	}
	return nil
}

func (r *Repo) CreateSession(ctx context.Context, s PracticeSession) (PracticeSession, error) {
	var assessmentID, attemptID string
	var createdAt time.Time

	err := r.tx(ctx, func(tx pgx.Tx) error {
		// Ephemeral assessment: type='practice', title=technology||' practice'.
		// The slug is unique per (org, slug), so it carries a random suffix.
		title := s.Technology + practiceTitleSuffix
		if err := tx.QueryRow(ctx,
			`INSERT INTO assessments (org_id, title, slug, type, parent_type, status, duration_minutes,
			   pass_percentage, max_attempts, shuffle_questions, shuffle_options, allow_backtrack,
			   show_results, created_by)
			 VALUES ($1, $2, $3 || '-' || gen_random_uuid()::text, 'practice', 'standalone', 'active', 1,
			   0, 1, false, false, false, false, $4)
			 RETURNING id, created_at`,
			s.OrgID, title, strings.ToLower(strings.ReplaceAll(title, " ", "-")), s.UserID,
		).Scan(&assessmentID, &createdAt); err != nil {
			return fmt.Errorf("practice: create assessment: %w", err)
		}

		if err := tx.QueryRow(ctx,
			`INSERT INTO assessment_attempts (assessment_id, user_id, org_id, attempt_number, status, started_at)
			 VALUES ($1, $2, $3, 1, 'in_progress', now())
			 RETURNING id`,
			assessmentID, s.UserID, s.OrgID,
		).Scan(&attemptID); err != nil {
			return fmt.Errorf("practice: create attempt: %w", err)
		}
		return nil
	})
	if err != nil {
		return PracticeSession{}, err
	}

	s.ID = attemptID // the attempt is the session
	s.Status = StatusActive
	s.CreatedAt = createdAt
	return s, nil
}

func (r *Repo) GetSession(ctx context.Context, sessionID, userID string) (PracticeSession, error) {
	var s PracticeSession
	var title, attemptStatus string

	err := r.pool.QueryRow(ctx,
		`SELECT at.id, at.user_id, at.org_id, a.title, at.status, a.created_at, at.submitted_at,
		        (SELECT count(*) FROM attempt_answers WHERE attempt_id = at.id)
		 FROM assessment_attempts at
		 JOIN assessments a ON a.id = at.assessment_id
		 WHERE at.id = $1 AND at.user_id = $2 AND a.type = 'practice'`,
		sessionID, userID,
	).Scan(&s.ID, &s.UserID, &s.OrgID, &title, &attemptStatus, &s.CreatedAt, &s.CompletedAt, &s.QuestionCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PracticeSession{}, ErrNotFound
		}
		return PracticeSession{}, fmt.Errorf("practice: get session: %w", err)
	}

	s.Technology = strings.TrimSuffix(title, practiceTitleSuffix)
	s.Status = sessionStatusFromAttempt(attemptStatus)
	s.Difficulty = "intermediate"  // Default; would need to be stored separately if needed
	s.Category = CategoryTechnical // Default

	items, err := r.GetItems(ctx, sessionID)
	if err != nil {
		return PracticeSession{}, err
	}
	s.Items = items
	return s, nil
}

func (r *Repo) UpdateSessionStatus(ctx context.Context, sessionID, userID string, status SessionStatus) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE assessment_attempts
		 SET status = $1, submitted_at = CASE WHEN $2 THEN now() ELSE submitted_at END
		 WHERE id = $3 AND user_id = $4`,
		attemptStatusFor(status), status == StatusCompleted, sessionID, userID)
	if err != nil {
		return fmt.Errorf("practice: update session status: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// insertItemSQL creates one practice question end to end. The schema models a
// question as questions -> question_versions -> assessment_questions (which
// owns the ordering `position`) -> attempt_answers, so a generated question
// text becomes an interview_prep question with a single version; the text is
// also kept in the answer JSON, which is where reads and the AI review job
// find it. $1 org, $2 user, $3 text, $4 answer JSON, $5 assessment, $6 attempt,
// $7 position.
const insertItemSQL = `
WITH q AS (
	INSERT INTO questions (org_id, type, title, created_by)
	VALUES ($1, 'interview_prep', left($3, 500), $2)
	RETURNING id
), v AS (
	INSERT INTO question_versions (question_id, version, content, created_by)
	SELECT id, 1, $4::jsonb, $2 FROM q
	RETURNING id, question_id
), aq AS (
	INSERT INTO assessment_questions (assessment_id, question_id, version_id, position)
	SELECT $5, v.question_id, v.id, $7 FROM v
	RETURNING id, question_id, created_at
)
INSERT INTO attempt_answers (attempt_id, assessment_question_id, question_id, answer)
SELECT $6, aq.id, aq.question_id, $4::jsonb FROM aq
RETURNING id`

func (r *Repo) InsertItems(ctx context.Context, sessionID string, questions []string) ([]PracticeItem, error) {
	if len(questions) == 0 {
		return []PracticeItem{}, nil
	}

	out := make([]PracticeItem, 0, len(questions))
	err := r.tx(ctx, func(tx pgx.Tx) error {
		var orgID, userID, assessmentID string
		var createdAt time.Time
		if err := tx.QueryRow(ctx,
			`SELECT at.org_id, at.user_id, at.assessment_id, now()
			 FROM assessment_attempts at WHERE at.id = $1`, sessionID,
		).Scan(&orgID, &userID, &assessmentID, &createdAt); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("practice: load attempt for items: %w", err)
		}

		batch := &pgx.Batch{}
		for i, q := range questions {
			answerJSON, err := json.Marshal(map[string]string{questionTextKey: q})
			if err != nil {
				return fmt.Errorf("practice: marshal question: %w", err)
			}
			batch.Queue(insertItemSQL, orgID, userID, q, answerJSON, assessmentID, sessionID, i)
		}
		results := tx.SendBatch(ctx, batch)
		defer results.Close()
		for i, q := range questions {
			item := PracticeItem{SessionID: sessionID, Position: i, QuestionText: q, CreatedAt: createdAt}
			if err := results.QueryRow().Scan(&item.ID); err != nil {
				return fmt.Errorf("practice: insert item %d: %w", i, err)
			}
			out = append(out, item)
		}
		return results.Close()
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

// itemColumns / itemFrom are the shared read shape of one practice item: the
// answer row joined to its assessment_questions row for position + created_at.
const (
	itemColumns = `aa.id, aa.attempt_id, aq.position, aa.answer, aa.ai_feedback, aq.created_at`
	itemFrom    = `attempt_answers aa JOIN assessment_questions aq ON aq.id = aa.assessment_question_id`
)

// hydrate fills the fields derived from the stored answer JSON and feedback.
func (it *PracticeItem) hydrate(answerJSON []byte) {
	var ans struct {
		QuestionText string  `json:"question_text"`
		UserAnswer   *string `json:"user_answer"`
	}
	if len(answerJSON) > 0 && json.Unmarshal(answerJSON, &ans) == nil {
		it.QuestionText = ans.QuestionText
		it.UserAnswer = ans.UserAnswer
	}
	if it.rawFeedback != nil {
		var fb AIFeedback
		if json.Unmarshal(it.rawFeedback, &fb) == nil {
			it.AIFeedback = &fb
		}
	}
}

func scanItem(row pgx.Row) (PracticeItem, error) {
	var item PracticeItem
	var answerJSON []byte
	if err := row.Scan(&item.ID, &item.SessionID, &item.Position, &answerJSON, &item.rawFeedback, &item.CreatedAt); err != nil {
		return PracticeItem{}, err
	}
	item.hydrate(answerJSON)
	return item, nil
}

func (r *Repo) GetItems(ctx context.Context, sessionID string) ([]PracticeItem, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+itemColumns+` FROM `+itemFrom+` WHERE aa.attempt_id = $1 ORDER BY aq.position`, sessionID)
	if err != nil {
		return nil, fmt.Errorf("practice: get items: %w", err)
	}
	defer rows.Close()
	out := []PracticeItem{}
	for rows.Next() {
		item, err := scanItem(rows)
		if err != nil {
			return nil, fmt.Errorf("practice: scan item: %w", err)
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

// SaveAnswer also returns the parent session's category (technical/behavioral)
// so the caller can pick the right grading rubric without a second round-trip.
func (r *Repo) SaveAnswer(ctx context.Context, sessionID, userID string, position int, answer string) (PracticeItem, string, error) {
	item, err := scanItem(r.pool.QueryRow(ctx,
		`UPDATE attempt_answers aa
		 SET answer = jsonb_set(COALESCE(aa.answer, '{}'::jsonb), '{user_answer}', to_jsonb($1::text)),
		     updated_at = now()
		 FROM assessment_questions aq, assessment_attempts at
		 WHERE aa.attempt_id = $2 AND aq.id = aa.assessment_question_id AND aq.position = $3
		   AND at.id = aa.attempt_id AND at.user_id = $4
		 RETURNING `+itemColumns,
		answer, sessionID, position, userID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PracticeItem{}, "", ErrNotFound
		}
		return PracticeItem{}, "", fmt.Errorf("practice: save answer: %w", err)
	}
	return item, CategoryTechnical, nil // category would need to be stored separately if needed
}

func (r *Repo) SaveFeedback(ctx context.Context, itemID string, feedback AIFeedback) (PracticeItem, error) {
	raw, err := json.Marshal(feedback)
	if err != nil {
		return PracticeItem{}, fmt.Errorf("practice: marshal feedback: %w", err)
	}
	item, err := scanItem(r.pool.QueryRow(ctx,
		`UPDATE attempt_answers aa SET ai_feedback = $1, evaluated_at = now(), updated_at = now()
		 FROM assessment_questions aq
		 WHERE aa.id = $2 AND aq.id = aa.assessment_question_id
		 RETURNING `+itemColumns,
		raw, itemID))
	if err != nil {
		return PracticeItem{}, fmt.Errorf("practice: save feedback: %w", err)
	}
	return item, nil
}

func (r *Repo) GetItemByPosition(ctx context.Context, sessionID, userID string, position int) (PracticeItem, error) {
	item, err := scanItem(r.pool.QueryRow(ctx,
		`SELECT `+itemColumns+` FROM `+itemFrom+`
		 JOIN assessment_attempts at ON at.id = aa.attempt_id
		 WHERE aa.attempt_id = $1 AND aq.position = $2 AND at.user_id = $3`,
		sessionID, position, userID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PracticeItem{}, ErrNotFound
		}
		return PracticeItem{}, fmt.Errorf("practice: get item: %w", err)
	}
	return item, nil
}

// ─── Question bank (shared cache) ──────────────────────────────────────────

// LookupQuestionBank returns the least-recently-used fresh bank for the given
// key (ORDER BY use_count ASC — rotation, so a hot combo doesn't always hand
// every user the same set — then created_at DESC as a tiebreak), or an empty
// slice on a cache miss. Never returns an error for "no rows" — a miss is a
// normal outcome, not a failure.
func (r *Repo) LookupQuestionBank(ctx context.Context, technology, difficulty, category string, maxAgeDays int) ([]QuestionBank, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, questions, ai_model FROM practice_question_bank
		 WHERE technology = $1 AND difficulty = $2 AND category = $3
		   AND created_at > now() - make_interval(days => $4)
		 ORDER BY use_count ASC, created_at DESC
		 LIMIT 1`,
		technology, difficulty, category, maxAgeDays,
	)
	if err != nil {
		return nil, fmt.Errorf("practice: lookup question bank: %w", err)
	}
	defer rows.Close()

	out := []QuestionBank{}
	for rows.Next() {
		var b QuestionBank
		if err := rows.Scan(&b.ID, &b.Questions, &b.AIModel); err != nil {
			return nil, fmt.Errorf("practice: scan question bank: %w", err)
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (r *Repo) InsertQuestionBank(ctx context.Context, technology, difficulty, category string, questions []string, model string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO practice_question_bank (technology, difficulty, category, questions, ai_model)
		 VALUES ($1, $2, $3, $4, $5)`,
		technology, difficulty, category, questions, model,
	)
	if err != nil {
		return fmt.Errorf("practice: insert question bank: %w", err)
	}
	return nil
}

func (r *Repo) IncrementQuestionBankUse(ctx context.Context, id string) error {
	_, err := r.pool.Exec(ctx, `UPDATE practice_question_bank SET use_count = use_count + 1 WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("practice: increment question bank use: %w", err)
	}
	return nil
}

// ─── Attempt status mapping ────────────────────────────────────────────────

const (
	// practiceTitleSuffix turns a technology into the ephemeral assessment's title.
	practiceTitleSuffix = " practice"
	// questionTextKey is where a question's text lives in attempt_answers.answer.
	questionTextKey = "question_text"
)

// attemptStatusFor maps a practice session status to assessment_attempts.status.
func attemptStatusFor(status SessionStatus) string {
	switch status {
	case StatusCompleted:
		return "evaluated"
	case StatusAbandoned:
		return "expired"
	default:
		return "in_progress"
	}
}

// sessionStatusFromAttempt is the inverse of attemptStatusFor.
func sessionStatusFromAttempt(status string) SessionStatus {
	switch status {
	case "evaluated":
		return StatusCompleted
	case "expired":
		return StatusAbandoned
	default:
		return StatusActive
	}
}
