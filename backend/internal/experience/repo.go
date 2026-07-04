package experience

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("experience: not found")

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// Upsert records (or updates) the authenticated user's experience report for
// a subject. skipped sets skipped_at to now(); a subsequent real submission
// overwrites both experience/description and clears skipped_at.
func (r *Repo) Upsert(ctx context.Context, orgID string, subjectType SubjectType, subjectID, userID string, experience *Experience, description *string, skipped bool) (Report, error) {
	var rep Report
	err := r.pool.QueryRow(ctx,
		`INSERT INTO experience_reports (org_id, subject_type, subject_id, user_id, experience, description, skipped_at)
		 VALUES ($1, $2, $3, $4, $5, $6, CASE WHEN $7 THEN now() ELSE NULL END)
		 ON CONFLICT (subject_type, subject_id, user_id) DO UPDATE
		   SET experience  = EXCLUDED.experience,
		       description = EXCLUDED.description,
		       skipped_at  = EXCLUDED.skipped_at,
		       updated_at  = now()
		 RETURNING id, org_id, subject_type, subject_id, user_id, experience, description, skipped_at, created_at, updated_at`,
		orgID, subjectType, subjectID, userID, experience, description, skipped,
	).Scan(&rep.ID, &rep.OrgID, &rep.SubjectType, &rep.SubjectID, &rep.UserID,
		&rep.Experience, &rep.Description, &rep.SkippedAt, &rep.CreatedAt, &rep.UpdatedAt)
	if err != nil {
		return Report{}, fmt.Errorf("experience: upsert: %w", err)
	}
	return rep, nil
}

// GetMine returns the authenticated user's existing experience report for a
// subject. Returns ErrNotFound if the user has neither reported nor skipped
// it yet.
func (r *Repo) GetMine(ctx context.Context, subjectType SubjectType, subjectID, userID string) (Report, error) {
	var rep Report
	err := r.pool.QueryRow(ctx,
		`SELECT id, org_id, subject_type, subject_id, user_id, experience, description, skipped_at, created_at, updated_at
		 FROM experience_reports
		 WHERE subject_type = $1 AND subject_id = $2 AND user_id = $3`,
		subjectType, subjectID, userID,
	).Scan(&rep.ID, &rep.OrgID, &rep.SubjectType, &rep.SubjectID, &rep.UserID,
		&rep.Experience, &rep.Description, &rep.SkippedAt, &rep.CreatedAt, &rep.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Report{}, ErrNotFound
		}
		return Report{}, fmt.Errorf("experience: get mine: %w", err)
	}
	return rep, nil
}
