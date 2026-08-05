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
func (r *Repo) Upsert(ctx context.Context, orgID *string, subjectType SubjectType, subjectID, userID string, kind Kind, rating *int, comment *string, skipped bool) (Feedback, error) {
	var f Feedback
	err := r.pool.QueryRow(ctx,
		`INSERT INTO feedback (org_id, subject_type, subject_id, user_id, kind, rating, comment, skipped_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, CASE WHEN $8 THEN now() ELSE NULL END)
		 ON CONFLICT (subject_type, subject_id, user_id) DO UPDATE
		   SET rating     = EXCLUDED.rating,
		       comment    = EXCLUDED.comment,
		       skipped_at = EXCLUDED.skipped_at,
		       updated_at = now()
		 RETURNING id, org_id, subject_type, subject_id, user_id, kind, rating, comment, skipped_at, created_at, updated_at`,
		orgID, subjectType, subjectID, userID, kind, rating, comment, skipped,
	).Scan(&f.ID, &f.OrgID, &f.SubjectType, &f.SubjectID, &f.UserID, &f.Kind,
		&f.Rating, &f.Comment, &f.SkippedAt, &f.CreatedAt, &f.UpdatedAt)
	if err != nil {
		return Feedback{}, fmt.Errorf("feedback: upsert: %w", err)
	}
	return f, nil
}

// ListPublic returns the most recent written reviews (rating + comment, both
// required) for a subject, newest first — the reviewer's current name and
// role at read time, not as of when they wrote it.
func (r *Repo) ListPublic(ctx context.Context, orgID *string, subjectType SubjectType, subjectID string, limit int) ([]PublicReview, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT f.id, u.name, p.current_role, f.rating, f.comment, f.created_at
		 FROM feedback f
		 JOIN users u ON u.id = f.user_id
		 LEFT JOIN user_profiles p ON p.user_id = u.id
		 WHERE f.org_id IS NOT DISTINCT FROM $1 AND f.subject_type = $2 AND f.subject_id = $3
		   AND f.rating IS NOT NULL AND f.comment IS NOT NULL AND f.comment != ''
		 ORDER BY f.created_at DESC
		 LIMIT $4`,
		orgID, subjectType, subjectID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("feedback: list public reviews: %w", err)
	}
	defer rows.Close()

	out := []PublicReview{}
	for rows.Next() {
		var rv PublicReview
		if err := rows.Scan(&rv.ID, &rv.ReviewerName, &rv.ReviewerRole, &rv.Rating, &rv.Comment, &rv.CreatedAt); err != nil {
			return nil, fmt.Errorf("feedback: scan public review: %w", err)
		}
		out = append(out, rv)
	}
	return out, rows.Err()
}

// GetMine returns the authenticated user's existing feedback for a subject.
// Returns ErrNotFound if the user has neither rated nor skipped it yet.
func (r *Repo) GetMine(ctx context.Context, subjectType SubjectType, subjectID, userID string) (Feedback, error) {
	var f Feedback
	err := r.pool.QueryRow(ctx,
		`SELECT id, org_id, subject_type, subject_id, user_id, kind, rating, comment, skipped_at, created_at, updated_at
		 FROM feedback
		 WHERE subject_type = $1 AND subject_id = $2 AND user_id = $3`,
		subjectType, subjectID, userID,
	).Scan(&f.ID, &f.OrgID, &f.SubjectType, &f.SubjectID, &f.UserID, &f.Kind,
		&f.Rating, &f.Comment, &f.SkippedAt, &f.CreatedAt, &f.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Feedback{}, ErrNotFound
		}
		return Feedback{}, fmt.Errorf("feedback: get mine: %w", err)
	}
	return f, nil
}
