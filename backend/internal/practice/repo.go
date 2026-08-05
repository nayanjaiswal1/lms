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
	var createdAt string

	err := r.tx(ctx, func(tx pgx.Tx) error {
		// Create ephemeral assessment: type='practice', title=technology||' practice', no parent.
		title := s.Technology + " practice"
		if err := tx.QueryRow(ctx,
			`INSERT INTO assessments (org_id, title, slug, type, parent_type, status, duration_minutes,
			   pass_percentage, max_attempts, shuffle_questions, shuffle_options, allow_backtrack,
			   show_results, created_by)
			 VALUES ($1, $2, $3, $4, $5, $6, 0, 0, 1, false, false, false, false, $7)
			 RETURNING id, created_at`,
			s.OrgID, title, strings.ToLower(strings.ReplaceAll(title, " ", "-")),
			"practice", "standalone", "active", s.UserID,
		).Scan(&assessmentID, &createdAt); err != nil {
			return fmt.Errorf("practice: create assessment: %w", err)
		}

		// Create assessment_attempts row for this session.
		if err := tx.QueryRow(ctx,
			`INSERT INTO assessment_attempts (assessment_id, user_id, org_id, attempt_number, status, started_at)
			 VALUES ($1, $2, $3, 1, $4, now())
			 RETURNING id`,
			assessmentID, s.UserID, s.OrgID, "in_progress",
		).Scan(&attemptID); err != nil {
			return fmt.Errorf("practice: create attempt: %w", err)
		}

		return nil
	})

	if err != nil {
		return PracticeSession{}, err
	}

	s.ID = attemptID // Use attemptID as session ID
	s.Status = StatusActive
	s.CreatedAt = parseTime(createdAt)
	return s, nil
}

func (r *Repo) GetSession(ctx context.Context, sessionID, userID string) (PracticeSession, error) {
	var s PracticeSession
	var questionCount int
	var createdAt, startedAt string
	var completedAt *string

	err := r.pool.QueryRow(ctx,
		`SELECT DISTINCT ON (aa.attempt_id)
		         aa.attempt_id, aa.user_id, aa.org_id, a.title,
		         aa.status, aa.started_at, aa.submitted_at,
		         COUNT(aa.id) OVER (PARTITION BY aa.attempt_id), a.created_at
		 FROM assessment_attempts aa
		 JOIN assessments a ON a.id = aa.assessment_id
		 WHERE aa.id = $1 AND aa.user_id = $2 AND a.type = 'practice'`,
		sessionID, userID,
	).Scan(&s.ID, &s.UserID, &s.OrgID, &s.Technology, &s.Status, &startedAt, &completedAt, &questionCount, &createdAt)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PracticeSession{}, ErrNotFound
		}
		return PracticeSession{}, fmt.Errorf("practice: get session: %w", err)
	}

	// Parse dates
	s.CreatedAt = parseTime(createdAt)
	if completedAt != nil {
		ct := parseTime(*completedAt)
		s.CompletedAt = &ct
	}
	s.QuestionCount = questionCount

	// Extract technology, difficulty, category from title (stored as "technology practice")
	s.Difficulty = "intermediate" // Default; would need to be stored separately if needed
	s.Category = CategoryTechnical // Default

	items, err := r.GetItems(ctx, sessionID)
	if err != nil {
		return PracticeSession{}, err
	}
	s.Items = items
	return s, nil
}

func (r *Repo) UpdateSessionStatus(ctx context.Context, sessionID, userID string, status SessionStatus) error {
	// Map SessionStatus to assessment_attempts status
	var attemptStatus string
	var submittedAt *string
	switch status {
	case StatusActive:
		attemptStatus = "in_progress"
	case StatusCompleted:
		attemptStatus = "evaluated"
		now := "now()"
		submittedAt = &now
	case StatusAbandoned:
		attemptStatus = "expired"
	default:
		attemptStatus = "in_progress"
	}

	var tag interface{ RowsAffected() int64 }
	var err error
	if submittedAt != nil {
		tag, err = r.pool.Exec(ctx,
			`UPDATE assessment_attempts SET status = $1, submitted_at = now()
			 WHERE id = $2 AND user_id = $3`,
			attemptStatus, sessionID, userID)
	} else {
		tag, err = r.pool.Exec(ctx,
			`UPDATE assessment_attempts SET status = $1
			 WHERE id = $2 AND user_id = $3`,
			attemptStatus, sessionID, userID)
	}
	if err != nil {
		return fmt.Errorf("practice: update session status: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repo) InsertItems(ctx context.Context, sessionID string, questions []string) ([]PracticeItem, error) {
	if len(questions) == 0 {
		return []PracticeItem{}, nil
	}

	// Build a single multi-row INSERT for attempt_answers.
	// Each question becomes one attempt_answer with the question_text stored in the answer field.
	args := make([]any, 0, len(questions)*3)
	valuesClauses := make([]string, 0, len(questions))
	for i, q := range questions {
		base := i * 3
		// Build JSON answer object with question_text
		valuesClauses = append(valuesClauses,
			fmt.Sprintf("($%d, $%d, $%d)", base+1, base+2, base+3))
		// sessionID is the attempt_id; position is i; question_text is q
		answerJSON := map[string]string{"question_text": q}
		answerBytes, _ := json.Marshal(answerJSON)
		args = append(args, sessionID, i, answerBytes)
	}

	rows, err := r.pool.Query(ctx,
		"INSERT INTO attempt_answers (attempt_id, position, answer) VALUES "+
			strings.Join(valuesClauses, ",")+
			" RETURNING id, attempt_id, position, created_at",
		args...)
	if err != nil {
		return nil, fmt.Errorf("practice: insert items: %w", err)
	}
	defer rows.Close()

	out := make([]PracticeItem, 0, len(questions))
	for rows.Next() {
		var item PracticeItem
		var attemptID string
		var createdAtStr string
		if err := rows.Scan(&item.ID, &attemptID, &item.Position, &createdAtStr); err != nil {
			return nil, fmt.Errorf("practice: scan inserted item: %w", err)
		}
		item.SessionID = attemptID
		item.CreatedAt = parseTime(createdAtStr)
		out = append(out, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("practice: insert items rows: %w", err)
	}
	return out, nil
}

func (r *Repo) GetItems(ctx context.Context, sessionID string) ([]PracticeItem, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, attempt_id, position, answer, ai_feedback, position, position, created_at
		 FROM attempt_answers WHERE attempt_id = $1 ORDER BY position`, sessionID)
	if err != nil {
		return nil, fmt.Errorf("practice: get items: %w", err)
	}
	defer rows.Close()
	out := []PracticeItem{}
	for rows.Next() {
		var item PracticeItem
		var answerJSON []byte
		var attemptID string
		var createdAtStr string
		// Scan attempt_answers columns into PracticeItem fields
		if err := rows.Scan(&item.ID, &attemptID, &item.Position, &answerJSON,
			&item.rawFeedback, nil, nil, &createdAtStr); err != nil {
			return nil, fmt.Errorf("practice: scan item: %w", err)
		}

		item.SessionID = attemptID
		item.CreatedAt = parseTime(createdAtStr)

		// Extract question_text from answer JSON
		if len(answerJSON) > 0 {
			var ansObj map[string]interface{}
			if err := json.Unmarshal(answerJSON, &ansObj); err == nil {
				if qt, ok := ansObj["question_text"].(string); ok {
					item.QuestionText = qt
				}
				if ua, ok := ansObj["user_answer"].(string); ok {
					item.UserAnswer = &ua
				}
			}
		}

		// Parse AI feedback if present
		if item.rawFeedback != nil {
			var fb AIFeedback
			if err := json.Unmarshal(item.rawFeedback, &fb); err == nil {
				item.AIFeedback = &fb
			}
		}

		out = append(out, item)
	}
	return out, rows.Err()
}

// SaveAnswer also returns the parent session's category (technical/behavioral)
// so the caller can pick the right grading rubric without a second round-trip.
func (r *Repo) SaveAnswer(ctx context.Context, sessionID, userID string, position int, answer string) (PracticeItem, string, error) {
	var item PracticeItem
	var category string
	var answerJSON []byte
	var createdAtStr string

	err := r.pool.QueryRow(ctx,
		`UPDATE attempt_answers aa
		 SET answer = jsonb_set(COALESCE(answer, '{}'::jsonb), '{user_answer}', to_jsonb($1::text))
		 FROM assessment_attempts at
		 WHERE aa.attempt_id = $2 AND aa.position = $3
		   AND at.id = aa.attempt_id AND at.user_id = $4
		 RETURNING aa.id, aa.attempt_id, aa.position, aa.answer, aa.ai_feedback, aa.created_at`,
		answer, sessionID, position, userID,
	).Scan(&item.ID, &item.SessionID, &item.Position, &answerJSON, &item.rawFeedback, &createdAtStr)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PracticeItem{}, "", ErrNotFound
		}
		return PracticeItem{}, "", fmt.Errorf("practice: save answer: %w", err)
	}

	item.CreatedAt = parseTime(createdAtStr)
	item.UserAnswer = &answer

	// Extract question_text
	if len(answerJSON) > 0 {
		var ansObj map[string]interface{}
		if err := json.Unmarshal(answerJSON, &ansObj); err == nil {
			if qt, ok := ansObj["question_text"].(string); ok {
				item.QuestionText = qt
			}
		}
	}

	// Parse AI feedback
	if item.rawFeedback != nil {
		var fb AIFeedback
		if err := json.Unmarshal(item.rawFeedback, &fb); err == nil {
			item.AIFeedback = &fb
		}
	}

	category = CategoryTechnical // Default; would need to be stored separately if needed
	return item, category, nil
}

func (r *Repo) SaveFeedback(ctx context.Context, itemID string, feedback AIFeedback) (PracticeItem, error) {
	raw, err := json.Marshal(feedback)
	if err != nil {
		return PracticeItem{}, fmt.Errorf("practice: marshal feedback: %w", err)
	}
	var item PracticeItem
	var answerJSON []byte
	var createdAtStr string

	err = r.pool.QueryRow(ctx,
		`UPDATE attempt_answers SET ai_feedback = $1, evaluated_at = now()
		 WHERE id = $2
		 RETURNING id, attempt_id, position, answer, ai_feedback, created_at`,
		raw, itemID,
	).Scan(&item.ID, &item.SessionID, &item.Position, &answerJSON, &item.rawFeedback, &createdAtStr)

	if err != nil {
		return PracticeItem{}, fmt.Errorf("practice: save feedback: %w", err)
	}

	item.CreatedAt = parseTime(createdAtStr)
	item.AIFeedback = &feedback

	// Extract question_text and user_answer
	if len(answerJSON) > 0 {
		var ansObj map[string]interface{}
		if err := json.Unmarshal(answerJSON, &ansObj); err == nil {
			if qt, ok := ansObj["question_text"].(string); ok {
				item.QuestionText = qt
			}
			if ua, ok := ansObj["user_answer"].(string); ok {
				item.UserAnswer = &ua
			}
		}
	}

	return item, nil
}

func (r *Repo) GetItemByPosition(ctx context.Context, sessionID, userID string, position int) (PracticeItem, error) {
	var item PracticeItem
	var answerJSON []byte
	var createdAtStr string

	err := r.pool.QueryRow(ctx,
		`SELECT aa.id, aa.attempt_id, aa.position, aa.answer, aa.ai_feedback, aa.created_at
		 FROM attempt_answers aa
		 JOIN assessment_attempts at ON at.id = aa.attempt_id
		 WHERE aa.attempt_id = $1 AND aa.position = $2 AND at.user_id = $3`,
		sessionID, position, userID,
	).Scan(&item.ID, &item.SessionID, &item.Position, &answerJSON, &item.rawFeedback, &createdAtStr)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PracticeItem{}, ErrNotFound
		}
		return PracticeItem{}, fmt.Errorf("practice: get item: %w", err)
	}

	item.CreatedAt = parseTime(createdAtStr)

	// Extract question_text and user_answer from answer JSON
	if len(answerJSON) > 0 {
		var ansObj map[string]interface{}
		if err := json.Unmarshal(answerJSON, &ansObj); err == nil {
			if qt, ok := ansObj["question_text"].(string); ok {
				item.QuestionText = qt
			}
			if ua, ok := ansObj["user_answer"].(string); ok {
				item.UserAnswer = &ua
			}
		}
	}

	// Parse AI feedback
	if item.rawFeedback != nil {
		var fb AIFeedback
		if err := json.Unmarshal(item.rawFeedback, &fb); err == nil {
			item.AIFeedback = &fb
		}
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

// ─── Helper ────────────────────────────────────────────────────────────────

func parseTime(s string) time.Time {
	t, _ := time.Parse(time.RFC3339, s)
	return t
}

// ponytail: helper for time parsing. Could use time.Parse directly but
// this keeps the pattern consistent if time format changes later.
