package assessment

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
)

// ─── Categories ──────────────────────────────────────────────────────────────

func (r *Repo) CreateCategory(ctx context.Context, orgID string, parentID *string, name, slug string) (Category, error) {
	var c Category
	err := r.pool.QueryRow(ctx,
		`INSERT INTO question_categories (org_id, parent_id, name, slug)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, org_id, parent_id, name, slug`,
		orgID, parentID, name, slug,
	).Scan(&c.ID, &c.OrgID, &c.ParentID, &c.Name, &c.Slug)
	if err != nil {
		return Category{}, fmt.Errorf("assessment: create category: %w", err)
	}
	return c, nil
}

func (r *Repo) ListCategories(ctx context.Context, orgID string) ([]Category, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, org_id, parent_id, name, slug
		 FROM question_categories WHERE org_id = $1 ORDER BY name`, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list categories: %w", err)
	}
	defer rows.Close()

	out := []Category{}
	for rows.Next() {
		var c Category
		if err := rows.Scan(&c.ID, &c.OrgID, &c.ParentID, &c.Name, &c.Slug); err != nil {
			return nil, fmt.Errorf("assessment: scan category: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// ─── Questions ───────────────────────────────────────────────────────────────

// CreateQuestion inserts the question and its first version in one transaction.
func (r *Repo) CreateQuestion(ctx context.Context, q Question, content json.RawMessage) (Question, error) {
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`INSERT INTO questions
			   (org_id, category_id, type, title, difficulty, default_points, tags, created_by)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
			 RETURNING id, current_version, created_at, updated_at`,
			q.OrgID, q.CategoryID, q.Type, q.Title, q.Difficulty, q.DefaultPoints, q.Tags, q.CreatedBy)
		if err := row.Scan(&q.ID, &q.CurrentVersion, &q.CreatedAt, &q.UpdatedAt); err != nil {
			return fmt.Errorf("assessment: insert question: %w", err)
		}

		if _, err := tx.Exec(ctx,
			`INSERT INTO question_versions (question_id, version, content, created_by)
			 VALUES ($1, $2, $3, $4)`,
			q.ID, q.CurrentVersion, content, q.CreatedBy); err != nil {
			return fmt.Errorf("assessment: insert question version: %w", err)
		}
		return nil
	})
	if err != nil {
		return Question{}, err
	}
	q.Content = content
	q.Status = StatusActive
	return q, nil
}

// UpdateQuestion writes metadata and, when content is non-nil, appends a new
// version and bumps current_version atomically.
func (r *Repo) UpdateQuestion(ctx context.Context, orgID string, q Question, content json.RawMessage) (Question, error) {
	err := r.tx(ctx, func(tx pgx.Tx) error {
		var nextVersion int
		row := tx.QueryRow(ctx,
			`UPDATE questions SET
			   category_id    = $3,
			   title          = $4,
			   difficulty     = $5,
			   default_points = $6,
			   tags           = $7,
			   current_version = CASE WHEN $8::jsonb IS NULL THEN current_version ELSE current_version + 1 END,
			   updated_at     = now()
			 WHERE id = $1 AND org_id = $2
			 RETURNING current_version, type, status, created_by, created_at, updated_at`,
			q.ID, orgID, q.CategoryID, q.Title, q.Difficulty, q.DefaultPoints, q.Tags, content)
		if err := row.Scan(&nextVersion, &q.Type, &q.Status, &q.CreatedBy, &q.CreatedAt, &q.UpdatedAt); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("assessment: update question: %w", err)
		}
		q.CurrentVersion = nextVersion

		if content != nil {
			if _, err := tx.Exec(ctx,
				`INSERT INTO question_versions (question_id, version, content, created_by)
				 VALUES ($1, $2, $3, $4)`,
				q.ID, nextVersion, content, q.CreatedBy); err != nil {
				return fmt.Errorf("assessment: insert new question version: %w", err)
			}
		}
		return nil
	})
	if err != nil {
		return Question{}, err
	}
	q.OrgID = orgID
	q.Content = content
	return q, nil
}

// GetQuestion returns the question with its current version content.
func (r *Repo) GetQuestion(ctx context.Context, orgID, id string) (Question, error) {
	var q Question
	var content []byte
	err := r.pool.QueryRow(ctx,
		`SELECT q.id, q.org_id, q.category_id, q.type, q.title, q.difficulty,
		        q.default_points, q.tags, q.status, q.current_version,
		        qv.content, q.created_by, q.created_at, q.updated_at
		 FROM questions q
		 JOIN question_versions qv
		   ON qv.question_id = q.id AND qv.version = q.current_version
		 WHERE q.id = $1 AND q.org_id = $2`,
		id, orgID,
	).Scan(&q.ID, &q.OrgID, &q.CategoryID, &q.Type, &q.Title, &q.Difficulty,
		&q.DefaultPoints, &q.Tags, &q.Status, &q.CurrentVersion,
		&content, &q.CreatedBy, &q.CreatedAt, &q.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Question{}, ErrNotFound
		}
		return Question{}, fmt.Errorf("assessment: get question: %w", err)
	}
	q.Content = content
	return q, nil
}

// QuestionFilter narrows a question-bank listing.
type QuestionFilter struct {
	Type       string
	CategoryID string
	Difficulty string
	Tags       []string
	Search     string
	Status     string
	Limit      int
	Offset     int
}

// ListQuestions returns metadata rows (no content) matching the filter.
func (r *Repo) ListQuestions(ctx context.Context, orgID string, f QuestionFilter) ([]Question, int, error) {
	conds := []string{"org_id = $1"}
	args := []any{orgID}
	add := func(clause string, val any) {
		args = append(args, val)
		conds = append(conds, fmt.Sprintf(clause, len(args)))
	}

	if f.Type != "" {
		add("type = $%d", f.Type)
	}
	if f.CategoryID != "" {
		add("category_id = $%d", f.CategoryID)
	}
	if f.Difficulty != "" {
		add("difficulty = $%d", f.Difficulty)
	}
	if f.Status != "" {
		add("status = $%d", f.Status)
	} else {
		conds = append(conds, "status = 'active'")
	}
	if len(f.Tags) > 0 {
		add("tags && $%d", f.Tags)
	}
	if f.Search != "" {
		add("title ILIKE $%d", "%"+f.Search+"%")
	}
	where := strings.Join(conds, " AND ")

	var total int
	if err := r.pool.QueryRow(ctx,
		`SELECT count(*) FROM questions WHERE `+where, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("assessment: count questions: %w", err)
	}

	limit := f.Limit
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	args = append(args, limit, f.Offset)
	query := fmt.Sprintf(
		`SELECT id, org_id, category_id, type, title, difficulty, default_points,
		        tags, status, current_version, created_by, created_at, updated_at
		 FROM questions WHERE %s
		 ORDER BY updated_at DESC
		 LIMIT $%d OFFSET $%d`, where, len(args)-1, len(args))

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("assessment: list questions: %w", err)
	}
	defer rows.Close()

	out := []Question{}
	for rows.Next() {
		var q Question
		if err := rows.Scan(&q.ID, &q.OrgID, &q.CategoryID, &q.Type, &q.Title, &q.Difficulty,
			&q.DefaultPoints, &q.Tags, &q.Status, &q.CurrentVersion,
			&q.CreatedBy, &q.CreatedAt, &q.UpdatedAt); err != nil {
			return nil, 0, fmt.Errorf("assessment: scan question: %w", err)
		}
		out = append(out, q)
	}
	return out, total, rows.Err()
}

// ArchiveQuestion soft-deletes by flipping status to archived.
func (r *Repo) ArchiveQuestion(ctx context.Context, orgID, id string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE questions SET status = 'archived', updated_at = now()
		 WHERE id = $1 AND org_id = $2`, id, orgID)
	if err != nil {
		return fmt.Errorf("assessment: archive question: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

