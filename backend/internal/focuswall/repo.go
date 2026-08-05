package focuswall

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound          = errors.New("focuswall: not found")
	ErrCategoryNotFound  = errors.New("focuswall: category not found")
	ErrCategoryDuplicate = errors.New("focuswall: category already exists")
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

func (r *Repo) Create(ctx context.Context, userID string, req CreateRequest) (Note, error) {
	var n Note
	err := r.pool.QueryRow(ctx,
		`INSERT INTO focus_wall_notes (user_id, text, color, category, position_x, position_y, rotation)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 RETURNING id, user_id, text, color, category, position_x, position_y, rotation, created_at, updated_at`,
		userID, req.Text, req.Color, req.Category, req.PositionX, req.PositionY, req.Rotation,
	).Scan(
		&n.ID, &n.UserID, &n.Text, &n.Color, &n.Category,
		&n.PositionX, &n.PositionY, &n.Rotation, &n.CreatedAt, &n.UpdatedAt,
	)
	if err != nil {
		return Note{}, fmt.Errorf("focuswall: create: %w", err)
	}
	return n, nil
}

// Update patches a user-owned note. COALESCE only falls back to the existing
// column value on a true SQL NULL, so each field is independently optional.
// Returns ErrNotFound when the note does not exist or belongs to another user.
func (r *Repo) Update(ctx context.Context, noteID, userID string, req UpdateRequest) (Note, error) {
	var n Note
	err := r.pool.QueryRow(ctx,
		`UPDATE focus_wall_notes
		 SET text = COALESCE($3, text),
		     color = COALESCE($4, color),
		     category = COALESCE($5, category),
		     position_x = COALESCE($6, position_x),
		     position_y = COALESCE($7, position_y),
		     rotation = COALESCE($8, rotation),
		     updated_at = now()
		 WHERE id = $1 AND user_id = $2
		 RETURNING id, user_id, text, color, category, position_x, position_y, rotation, created_at, updated_at`,
		noteID, userID, req.Text, req.Color, req.Category, req.PositionX, req.PositionY, req.Rotation,
	).Scan(
		&n.ID, &n.UserID, &n.Text, &n.Color, &n.Category,
		&n.PositionX, &n.PositionY, &n.Rotation, &n.CreatedAt, &n.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Note{}, ErrNotFound
		}
		return Note{}, fmt.Errorf("focuswall: update: %w", err)
	}
	return n, nil
}

// Delete removes a user-owned note. Returns ErrNotFound when the note does
// not exist or belongs to another user.
func (r *Repo) Delete(ctx context.Context, noteID, userID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM focus_wall_notes WHERE id = $1 AND user_id = $2`, noteID, userID)
	if err != nil {
		return fmt.Errorf("focuswall: delete: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ListByUser returns all of a user's notes, oldest first — stable ordering
// so notes don't visually reshuffle on every reload.
func (r *Repo) ListByUser(ctx context.Context, userID string) ([]Note, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, text, color, category, position_x, position_y, rotation, created_at, updated_at
		 FROM focus_wall_notes WHERE user_id = $1 ORDER BY created_at ASC`, userID)
	if err != nil {
		return nil, fmt.Errorf("focuswall: list by user: %w", err)
	}
	defer rows.Close()

	out := []Note{}
	for rows.Next() {
		var n Note
		if err := rows.Scan(
			&n.ID, &n.UserID, &n.Text, &n.Color, &n.Category,
			&n.PositionX, &n.PositionY, &n.Rotation, &n.CreatedAt, &n.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("focuswall: scan note: %w", err)
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

// ListDistinctCategories returns all distinct categories used by userID in
// their notes, ordered alphabetically. This includes both built-in categories
// (personal, study, urgent) and any custom categories assigned to notes.
func (r *Repo) ListDistinctCategories(ctx context.Context, userID string) ([]string, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT DISTINCT category FROM focus_wall_notes WHERE user_id = $1 ORDER BY category ASC`,
		userID)
	if err != nil {
		return nil, fmt.Errorf("focuswall: list distinct categories: %w", err)
	}
	defer rows.Close()

	var categories []string
	for rows.Next() {
		var cat string
		if err := rows.Scan(&cat); err != nil {
			return nil, fmt.Errorf("focuswall: scan category: %w", err)
		}
		categories = append(categories, cat)
	}
	return categories, rows.Err()
}
