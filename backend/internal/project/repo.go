package project

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// Create inserts a new project owned by userID.
func (r *Repo) Create(ctx context.Context, userID string, req CreateRequest) (Project, error) {
	var p Project
	err := r.pool.QueryRow(ctx,
		`INSERT INTO projects (user_id, name, description)
		 VALUES ($1, $2, $3)
		 RETURNING id, name, description, created_at`,
		userID, req.Name, req.Description,
	).Scan(&p.ID, &p.Name, &p.Description, &p.CreatedAt)
	if err != nil {
		return Project{}, fmt.Errorf("project: create: %w", err)
	}
	return p, nil
}

// ListByUser returns all of a user's projects, newest first.
func (r *Repo) ListByUser(ctx context.Context, userID string) ([]Project, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, name, description, created_at FROM projects
		 WHERE user_id = $1 ORDER BY created_at DESC`, userID)
	if err != nil {
		return nil, fmt.Errorf("project: list by user: %w", err)
	}
	defer rows.Close()

	out := []Project{}
	for rows.Next() {
		var p Project
		if err := rows.Scan(&p.ID, &p.Name, &p.Description, &p.CreatedAt); err != nil {
			return nil, fmt.Errorf("project: scan project: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}
