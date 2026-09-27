package workspace

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// repo_requirement.go — requirement_questions data layer (Phase 3: vague
// requirement → agreed brief, contract-phase3.md).

const questionColumns = `q.id, q.requirement_version, q.asked_by, COALESCE(u.name, 'Former member'), q.question,
	q.answer, q.answered_by, q.is_assumption, q.answered_at, q.created_at, q.updated_at,
	(SELECT count(*) FROM comments c WHERE c.subject_type = 'requirement_question' AND c.subject_id = q.id AND c.deleted_at IS NULL)`

func scanQuestion(row pgx.Row) (*RequirementQuestion, error) {
	var q RequirementQuestion
	err := row.Scan(&q.ID, &q.RequirementVersion, &q.AskedBy, &q.AskerName, &q.Question,
		&q.Answer, &q.AnsweredBy, &q.IsAssumption, &q.AnsweredAt, &q.CreatedAt, &q.UpdatedAt, &q.CommentCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan question: %w", err)
	}
	return &q, nil
}

// InsertQuestion appends a requirement_questions row and returns it joined to
// the asker's current name.
func (r *Repo) InsertQuestion(ctx context.Context, db DBTX, projectID string, requirementVersion int, askedBy, question string) (*RequirementQuestion, error) {
	row := db.QueryRow(ctx,
		`WITH ins AS (
			INSERT INTO requirement_questions (project_id, requirement_version, asked_by, question)
			VALUES ($1,$2,$3,$4)
			RETURNING id
		 )
		 SELECT `+questionColumns+`
		   FROM requirement_questions q LEFT JOIN users u ON u.id = q.asked_by
		  WHERE q.id = (SELECT id FROM ins)`,
		projectID, requirementVersion, askedBy, question,
	)
	return scanQuestion(row)
}

// FindDuplicateQuestion returns the closest near-duplicate question in this
// project (any requirement version — an old answer is still context), or nil
// if none clears SimilarityThreshold. The threshold is set SET LOCAL so it
// never leaks past this transaction on a pooled connection (mirrors
// repo_items.go's ListSimilarItems).
func (r *Repo) FindDuplicateQuestion(ctx context.Context, tx pgx.Tx, projectID, q string) (*RequirementQuestion, error) {
	if _, err := tx.Exec(ctx, fmt.Sprintf("SET LOCAL pg_trgm.similarity_threshold = %f", SimilarityThreshold)); err != nil {
		return nil, fmt.Errorf("workspace: set similarity threshold: %w", err)
	}
	row := tx.QueryRow(ctx,
		`SELECT `+questionColumns+`
		   FROM requirement_questions q LEFT JOIN users u ON u.id = q.asked_by
		  WHERE q.project_id = $1 AND q.question % $2
		  ORDER BY similarity(q.question, $2) DESC LIMIT 1`,
		projectID, q,
	)
	found, err := scanQuestion(row)
	if errors.Is(err, ErrNotFound) {
		return nil, nil
	}
	return found, err
}

// ListSimilarQuestions is the composer's debounced "already asked?" check —
// same trgm convention, up to SimilarLimit hits.
func (r *Repo) ListSimilarQuestions(ctx context.Context, tx pgx.Tx, projectID, q string) ([]RequirementQuestion, error) {
	if _, err := tx.Exec(ctx, fmt.Sprintf("SET LOCAL pg_trgm.similarity_threshold = %f", SimilarityThreshold)); err != nil {
		return nil, fmt.Errorf("workspace: set similarity threshold: %w", err)
	}
	rows, err := tx.Query(ctx,
		`SELECT `+questionColumns+`
		   FROM requirement_questions q LEFT JOIN users u ON u.id = q.asked_by
		  WHERE q.project_id = $1 AND q.question % $2
		  ORDER BY similarity(q.question, $2) DESC LIMIT $3`,
		projectID, q, SimilarLimit,
	)
	if err != nil {
		return nil, fmt.Errorf("workspace: list similar questions: %w", err)
	}
	defer rows.Close()
	out := []RequirementQuestion{}
	for rows.Next() {
		item, err := scanQuestion(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *item)
	}
	return out, rows.Err()
}

// ListQuestions cursor-paginates a project's question log, newest first.
func (r *Repo) ListQuestions(ctx context.Context, db DBTX, projectID string, cursorAt time.Time, cursorID string, limit int) ([]RequirementQuestion, error) {
	var rows pgx.Rows
	var err error
	if cursorAt.IsZero() {
		rows, err = db.Query(ctx,
			`SELECT `+questionColumns+` FROM requirement_questions q LEFT JOIN users u ON u.id = q.asked_by
			  WHERE q.project_id = $1 ORDER BY q.created_at DESC, q.id DESC LIMIT $2`,
			projectID, limit)
	} else {
		rows, err = db.Query(ctx,
			`SELECT `+questionColumns+` FROM requirement_questions q LEFT JOIN users u ON u.id = q.asked_by
			  WHERE q.project_id = $1 AND (q.created_at, q.id) < ($2, $3)
			  ORDER BY q.created_at DESC, q.id DESC LIMIT $4`,
			projectID, cursorAt, cursorID, limit)
	}
	if err != nil {
		return nil, fmt.Errorf("workspace: list questions: %w", err)
	}
	defer rows.Close()
	out := []RequirementQuestion{}
	for rows.Next() {
		item, err := scanQuestion(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *item)
	}
	return out, rows.Err()
}

// GetQuestion scopes a single question to its project — the IDOR guard for
// the comments endpoints (no lock; those never write the question row).
func (r *Repo) GetQuestion(ctx context.Context, db DBTX, projectID, questionID string) (*RequirementQuestion, error) {
	return scanQuestion(db.QueryRow(ctx,
		`SELECT `+questionColumns+` FROM requirement_questions q LEFT JOIN users u ON u.id = q.asked_by
		  WHERE q.id = $1 AND q.project_id = $2`,
		questionID, projectID))
}

// LockQuestion is GetQuestion under FOR UPDATE — AnswerQuestion's own
// check-and-write lock.
func (r *Repo) LockQuestion(ctx context.Context, tx pgx.Tx, projectID, questionID string) (*RequirementQuestion, error) {
	return scanQuestion(tx.QueryRow(ctx,
		`SELECT `+questionColumns+` FROM requirement_questions q LEFT JOIN users u ON u.id = q.asked_by
		  WHERE q.id = $1 AND q.project_id = $2 FOR UPDATE OF q`,
		questionID, projectID))
}

// SetAnswer records the answer (or assumption) on an unanswered question.
// 0 rows means it was already answered concurrently — ErrQuestionAnswered.
func (r *Repo) SetAnswer(ctx context.Context, tx pgx.Tx, projectID, questionID, answer, answeredBy string, isAssumption bool) (*RequirementQuestion, error) {
	row := tx.QueryRow(ctx,
		`WITH upd AS (
			UPDATE requirement_questions SET answer = $3, answered_by = $4, answered_at = now(),
				is_assumption = $5, updated_at = now()
			 WHERE id = $1 AND project_id = $2 AND answered_at IS NULL
			RETURNING id
		 )
		 SELECT `+questionColumns+`
		   FROM requirement_questions q LEFT JOIN users u ON u.id = q.asked_by
		  WHERE q.id = (SELECT id FROM upd)`,
		questionID, projectID, answer, answeredBy, isAssumption,
	)
	q, err := scanQuestion(row)
	if errors.Is(err, ErrNotFound) {
		return nil, ErrQuestionAnswered
	}
	return q, err
}

// ListAnsweredQuestions returns every answered question for a requirement
// version, oldest first — CreateBriefPage's "Q&A log" section source.
func (r *Repo) ListAnsweredQuestions(ctx context.Context, db DBTX, projectID string, requirementVersion int) ([]RequirementQuestion, error) {
	rows, err := db.Query(ctx,
		`SELECT `+questionColumns+` FROM requirement_questions q LEFT JOIN users u ON u.id = q.asked_by
		  WHERE q.project_id = $1 AND q.requirement_version = $2 AND q.answered_at IS NOT NULL
		  ORDER BY q.answered_at ASC`,
		projectID, requirementVersion)
	if err != nil {
		return nil, fmt.Errorf("workspace: list answered questions: %w", err)
	}
	defer rows.Close()
	out := []RequirementQuestion{}
	for rows.Next() {
		item, err := scanQuestion(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *item)
	}
	return out, rows.Err()
}
