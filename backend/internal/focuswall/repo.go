package focuswall

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/db"
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
// maxNotesPerUser caps the canvas query — the wall renders every note at
// once (no pagination UI fits a spatial board), so this is a safety net
// against a runaway scan, not a page size.
const maxNotesPerUser = 2000

func (r *Repo) ListByUser(ctx context.Context, userID string) ([]Note, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, text, color, category, position_x, position_y, rotation, created_at, updated_at
		 FROM focus_wall_notes WHERE user_id = $1 ORDER BY created_at ASC LIMIT $2`, userID, maxNotesPerUser)
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

// ListCategories returns the user's custom categories, oldest first.
func (r *Repo) ListCategories(ctx context.Context, userID string) ([]FocusCategory, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, name, created_at FROM focus_wall_categories
		 WHERE user_id = $1 ORDER BY created_at ASC, id ASC`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("focuswall: list categories: %w", err)
	}
	defer rows.Close()

	categories := []FocusCategory{}
	for rows.Next() {
		var c FocusCategory
		if err := rows.Scan(&c.ID, &c.UserID, &c.Name, &c.CreatedAt); err != nil {
			return nil, fmt.Errorf("focuswall: scan category: %w", err)
		}
		categories = append(categories, c)
	}
	return categories, rows.Err()
}

// CreateCategory inserts a custom category; the per-user case-insensitive
// unique index maps to ErrCategoryDuplicate.
func (r *Repo) CreateCategory(ctx context.Context, userID, name string) (FocusCategory, error) {
	var c FocusCategory
	err := r.pool.QueryRow(ctx,
		`INSERT INTO focus_wall_categories (user_id, name) VALUES ($1, $2)
		 RETURNING id, user_id, name, created_at`,
		userID, name,
	).Scan(&c.ID, &c.UserID, &c.Name, &c.CreatedAt)
	if db.IsUniqueViolation(err) {
		return FocusCategory{}, ErrCategoryDuplicate
	}
	if err != nil {
		return FocusCategory{}, fmt.Errorf("focuswall: create category: %w", err)
	}
	return c, nil
}

// DeleteCategory removes a category owned by userID.
func (r *Repo) DeleteCategory(ctx context.Context, userID, categoryID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM focus_wall_categories WHERE id = $1 AND user_id = $2`,
		categoryID, userID,
	)
	if err != nil {
		return fmt.Errorf("focuswall: delete category: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrCategoryNotFound
	}
	return nil
}
