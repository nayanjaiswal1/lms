package feedback

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("feedback: not found")

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// Upsert records (or updates) the authenticated user's feedback for a
// subject. skipped sets skipped_at to now(); a subsequent real submission
// overwrites both rating/comment and clears skipped_at.
func (r *Repo) Upsert(ctx context.Context, orgID string, subjectType SubjectType, subjectID, userID string, rating *int, comment *string, skipped bool) (Feedback, error) {
	var f Feedback
	err := r.pool.QueryRow(ctx,
		`INSERT INTO feedback (org_id, subject_type, subject_id, user_id, rating, comment, skipped_at)
		 VALUES ($1, $2, $3, $4, $5, $6, CASE WHEN $7 THEN now() ELSE NULL END)
		 ON CONFLICT (subject_type, subject_id, user_id) DO UPDATE
		   SET rating     = EXCLUDED.rating,
		       comment    = EXCLUDED.comment,
		       skipped_at = EXCLUDED.skipped_at,
		       updated_at = now()
		 RETURNING id, org_id, subject_type, subject_id, user_id, rating, comment, skipped_at, created_at, updated_at`,
		orgID, subjectType, subjectID, userID, rating, comment, skipped,
	).Scan(&f.ID, &f.OrgID, &f.SubjectType, &f.SubjectID, &f.UserID,
		&f.Rating, &f.Comment, &f.SkippedAt, &f.CreatedAt, &f.UpdatedAt)
	if err != nil {
		return Feedback{}, fmt.Errorf("feedback: upsert: %w", err)
	}
	return f, nil
}

// GetMine returns the authenticated user's existing feedback for a subject.
// Returns ErrNotFound if the user has neither rated nor skipped it yet.
func (r *Repo) GetMine(ctx context.Context, subjectType SubjectType, subjectID, userID string) (Feedback, error) {
	var f Feedback
	err := r.pool.QueryRow(ctx,
		`SELECT id, org_id, subject_type, subject_id, user_id, rating, comment, skipped_at, created_at, updated_at
		 FROM feedback
		 WHERE subject_type = $1 AND subject_id = $2 AND user_id = $3`,
		subjectType, subjectID, userID,
	).Scan(&f.ID, &f.OrgID, &f.SubjectType, &f.SubjectID, &f.UserID,
		&f.Rating, &f.Comment, &f.SkippedAt, &f.CreatedAt, &f.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Feedback{}, ErrNotFound
		}
		return Feedback{}, fmt.Errorf("feedback: get mine: %w", err)
	}
	return f, nil
}
