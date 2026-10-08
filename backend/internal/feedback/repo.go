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

// Upsert records (or updates) userID's feedback of req.Kind for a subject.
// A skip sets skipped_at; a later real answer overwrites it and clears it.
func (r *Repo) Upsert(ctx context.Context, orgID *string, userID string, req SubmitRequest) (Feedback, error) {
	var f Feedback
	err := r.pool.QueryRow(ctx,
		`INSERT INTO feedback (org_id, subject_type, subject_id, user_id, kind, rating, experience, comment, skipped_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, CASE WHEN $9 THEN now() ELSE NULL END)
		 ON CONFLICT (kind, subject_type, subject_id, user_id) DO UPDATE
		   SET rating     = EXCLUDED.rating,
		       experience = EXCLUDED.experience,
		       comment    = EXCLUDED.comment,
		       skipped_at = EXCLUDED.skipped_at,
		       updated_at = now()
		 RETURNING `+feedbackColumns,
		orgID, req.SubjectType, req.SubjectID, userID, req.Kind, req.Rating, req.Experience, req.Comment, req.Skip,
	).Scan(feedbackDest(&f)...)
	if err != nil {
		return Feedback{}, fmt.Errorf("feedback: upsert: %w", err)
	}
	return f, nil
}

const feedbackColumns = `id, org_id, subject_type, subject_id, user_id, kind, rating, experience, comment, skipped_at, created_at, updated_at`

func feedbackDest(f *Feedback) []any {
	return []any{&f.ID, &f.OrgID, &f.SubjectType, &f.SubjectID, &f.UserID, &f.Kind,
		&f.Rating, &f.Experience, &f.Comment, &f.SkippedAt, &f.CreatedAt, &f.UpdatedAt}
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
		 WHERE f.org_id IS NOT DISTINCT FROM $1 AND f.kind = 'rating' AND f.subject_type = $2 AND f.subject_id = $3
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

// GetMine returns userID's own feedback of one kind for a subject.
// Returns ErrNotFound if they have neither answered nor skipped it yet.
func (r *Repo) GetMine(ctx context.Context, kind Kind, subjectType SubjectType, subjectID, userID string) (Feedback, error) {
	var f Feedback
	err := r.pool.QueryRow(ctx,
		`SELECT `+feedbackColumns+` FROM feedback
		 WHERE kind = $1 AND subject_type = $2 AND subject_id = $3 AND user_id = $4`,
		kind, subjectType, subjectID, userID,
	).Scan(feedbackDest(&f)...)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Feedback{}, ErrNotFound
		}
		return Feedback{}, fmt.Errorf("feedback: get mine: %w", err)
	}
	return f, nil
}
