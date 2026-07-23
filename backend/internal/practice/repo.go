package practice

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

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

func (r *Repo) CreateSession(ctx context.Context, s PracticeSession) (PracticeSession, error) {
	err := r.pool.QueryRow(ctx,
		`INSERT INTO practice_sessions (user_id, org_id, technology, difficulty, category, question_count, ai_model)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 RETURNING id, created_at`,
		s.UserID, s.OrgID, s.Technology, s.Difficulty, s.Category, s.QuestionCount, s.AIModel,
	).Scan(&s.ID, &s.CreatedAt)
	if err != nil {
		return PracticeSession{}, fmt.Errorf("practice: create session: %w", err)
	}
	s.Status = StatusActive
	return s, nil
}

func (r *Repo) GetSession(ctx context.Context, sessionID, userID string) (PracticeSession, error) {
	var s PracticeSession
	err := r.pool.QueryRow(ctx,
		`SELECT id, user_id, org_id, technology, difficulty, category, question_count, status, ai_model, created_at, completed_at
		 FROM practice_sessions WHERE id = $1 AND user_id = $2`, sessionID, userID,
	).Scan(&s.ID, &s.UserID, &s.OrgID, &s.Technology, &s.Difficulty, &s.Category,
		&s.QuestionCount, &s.Status, &s.AIModel, &s.CreatedAt, &s.CompletedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PracticeSession{}, ErrNotFound
		}
		return PracticeSession{}, fmt.Errorf("practice: get session: %w", err)
	}

	items, err := r.GetItems(ctx, sessionID)
	if err != nil {
		return PracticeSession{}, err
	}
	s.Items = items
	return s, nil
}

func (r *Repo) UpdateSessionStatus(ctx context.Context, sessionID, userID string, status SessionStatus) error {
	var completedAt *string
	if status == StatusCompleted {
		now := "now()"
		completedAt = &now
	}
	var tag interface{ RowsAffected() int64 }
	var err error
	if completedAt != nil {
		tag, err = r.pool.Exec(ctx,
			`UPDATE practice_sessions SET status = $1, completed_at = now() WHERE id = $2 AND user_id = $3`,
			status, sessionID, userID)
	} else {
		tag, err = r.pool.Exec(ctx,
			`UPDATE practice_sessions SET status = $1 WHERE id = $2 AND user_id = $3`,
			status, sessionID, userID)
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

	// Build a single multi-row INSERT instead of one round-trip per question.
	// pgx accepts [][]any for batch values; we use a VALUES ($1,$2,$3),($4,$5,$6)…
	// pattern so the planner sees one statement with a single network round-trip.
	args := make([]any, 0, len(questions)*3)
	valuesClauses := make([]string, 0, len(questions))
	for i, q := range questions {
		base := i * 3
		valuesClauses = append(valuesClauses,
			fmt.Sprintf("($%d, $%d, $%d)", base+1, base+2, base+3))
		args = append(args, sessionID, i, q)
	}

	rows, err := r.pool.Query(ctx,
		"INSERT INTO practice_items (session_id, position, question_text) VALUES "+
			strings.Join(valuesClauses, ",")+
			" RETURNING id, session_id, position, question_text, created_at",
		args...)
	if err != nil {
		return nil, fmt.Errorf("practice: insert items: %w", err)
	}
	defer rows.Close()

	out := make([]PracticeItem, 0, len(questions))
	for rows.Next() {
		var item PracticeItem
		if err := rows.Scan(&item.ID, &item.SessionID, &item.Position, &item.QuestionText, &item.CreatedAt); err != nil {
			return nil, fmt.Errorf("practice: scan inserted item: %w", err)
		}
		out = append(out, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("practice: insert items rows: %w", err)
	}
	return out, nil
}

func (r *Repo) GetItems(ctx context.Context, sessionID string) ([]PracticeItem, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, session_id, position, question_text, user_answer, ai_feedback, answered_at, feedback_at, created_at
		 FROM practice_items WHERE session_id = $1 ORDER BY position`, sessionID)
	if err != nil {
		return nil, fmt.Errorf("practice: get items: %w", err)
	}
	defer rows.Close()
	out := []PracticeItem{}
	for rows.Next() {
		var item PracticeItem
		if err := rows.Scan(&item.ID, &item.SessionID, &item.Position, &item.QuestionText,
			&item.UserAnswer, &item.rawFeedback, &item.AnsweredAt, &item.FeedbackAt, &item.CreatedAt); err != nil {
			return nil, fmt.Errorf("practice: scan item: %w", err)
		}
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
	err := r.pool.QueryRow(ctx,
		`UPDATE practice_items pi
		 SET user_answer = $1, answered_at = now()
		 FROM practice_sessions ps
		 WHERE pi.session_id = $2 AND pi.position = $3
		   AND pi.session_id = ps.id AND ps.user_id = $4
		   AND pi.user_answer IS NULL
		 RETURNING pi.id, pi.session_id, pi.position, pi.question_text, pi.user_answer,
		           pi.ai_feedback, pi.answered_at, pi.feedback_at, pi.created_at, ps.category`,
		answer, sessionID, position, userID,
	).Scan(&item.ID, &item.SessionID, &item.Position, &item.QuestionText,
		&item.UserAnswer, &item.rawFeedback, &item.AnsweredAt, &item.FeedbackAt, &item.CreatedAt, &category)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PracticeItem{}, "", ErrNotFound
		}
		return PracticeItem{}, "", fmt.Errorf("practice: save answer: %w", err)
	}
	return item, category, nil
}

func (r *Repo) SaveFeedback(ctx context.Context, itemID string, feedback AIFeedback) (PracticeItem, error) {
	raw, err := json.Marshal(feedback)
	if err != nil {
		return PracticeItem{}, fmt.Errorf("practice: marshal feedback: %w", err)
	}
	var item PracticeItem
	err = r.pool.QueryRow(ctx,
		`UPDATE practice_items SET ai_feedback = $1, feedback_at = now()
		 WHERE id = $2
		 RETURNING id, session_id, position, question_text, user_answer, ai_feedback, answered_at, feedback_at, created_at`,
		raw, itemID,
	).Scan(&item.ID, &item.SessionID, &item.Position, &item.QuestionText,
		&item.UserAnswer, &item.rawFeedback, &item.AnsweredAt, &item.FeedbackAt, &item.CreatedAt)
	if err != nil {
		return PracticeItem{}, fmt.Errorf("practice: save feedback: %w", err)
	}
	item.AIFeedback = &feedback
	return item, nil
}

func (r *Repo) GetItemByPosition(ctx context.Context, sessionID, userID string, position int) (PracticeItem, error) {
	var item PracticeItem
	err := r.pool.QueryRow(ctx,
		`SELECT pi.id, pi.session_id, pi.position, pi.question_text, pi.user_answer,
		        pi.ai_feedback, pi.answered_at, pi.feedback_at, pi.created_at
		 FROM practice_items pi
		 JOIN practice_sessions ps ON ps.id = pi.session_id
		 WHERE pi.session_id = $1 AND pi.position = $2 AND ps.user_id = $3`,
		sessionID, position, userID,
	).Scan(&item.ID, &item.SessionID, &item.Position, &item.QuestionText,
		&item.UserAnswer, &item.rawFeedback, &item.AnsweredAt, &item.FeedbackAt, &item.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return PracticeItem{}, ErrNotFound
		}
		return PracticeItem{}, fmt.Errorf("practice: get item: %w", err)
	}
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
