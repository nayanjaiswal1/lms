package srs

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the SRS domain.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// ErrNotFound is returned when a card does not exist or does not belong to the
// requesting user.
var ErrNotFound = errors.New("srs: not found")

// GetDueCards returns up to 20 cards that are due today or earlier for the
// given user, ordered by oldest due date first.
func (r *Repo) GetDueCards(ctx context.Context, userID string) ([]Card, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, question_id, front, back, source_type,
		        interval_days, repetitions, ease_factor,
		        to_char(due_date, 'YYYY-MM-DD'), last_reviewed_at, created_at
		 FROM srs_cards
		 WHERE user_id = $1 AND due_date <= CURRENT_DATE
		 ORDER BY due_date
		 LIMIT 20`, userID)
	if err != nil {
		return nil, fmt.Errorf("srs: get due cards: %w", err)
	}
	defer rows.Close()

	out := []Card{}
	for rows.Next() {
		var c Card
		if err := rows.Scan(
			&c.ID, &c.UserID, &c.QuestionID, &c.Front, &c.Back, &c.SourceType,
			&c.IntervalDays, &c.Repetitions, &c.EaseFactor,
			&c.DueDate, &c.LastReviewedAt, &c.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("srs: scan due card: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// CreateCard inserts a new SRS card for the user and returns the full row.
func (r *Repo) CreateCard(ctx context.Context, userID string, req CreateCardRequest) (Card, error) {
	var c Card
	err := r.pool.QueryRow(ctx,
		`INSERT INTO srs_cards (user_id, question_id, front, back, source_type)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, user_id, question_id, front, back, source_type,
		           interval_days, repetitions, ease_factor,
		           to_char(due_date, 'YYYY-MM-DD'), last_reviewed_at, created_at`,
		userID, req.QuestionID, req.Front, req.Back, req.SourceType,
	).Scan(
		&c.ID, &c.UserID, &c.QuestionID, &c.Front, &c.Back, &c.SourceType,
		&c.IntervalDays, &c.Repetitions, &c.EaseFactor,
		&c.DueDate, &c.LastReviewedAt, &c.CreatedAt,
	)
	if err != nil {
		return Card{}, fmt.Errorf("srs: create card: %w", err)
	}
	return c, nil
}

// UpdateCardAfterReview writes the new SM-2 scheduling values after a review.
// nextDue is a YYYY-MM-DD string.
func (r *Repo) UpdateCardAfterReview(ctx context.Context, cardID string, newInterval, newReps int, newEF float64, nextDue string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE srs_cards
		 SET interval_days    = $2,
		     repetitions      = $3,
		     ease_factor      = $4,
		     due_date         = $5::date,
		     last_reviewed_at = now()
		 WHERE id = $1`,
		cardID, newInterval, newReps, newEF, nextDue)
	if err != nil {
		return fmt.Errorf("srs: update card after review: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// CardExists reports whether the user already has an SRS card for the given
// question. Both IDs must be valid UUIDs; it is the caller's responsibility to
// validate them before calling.
func (r *Repo) CardExists(ctx context.Context, userID, questionID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM srs_cards
		   WHERE user_id = $1 AND question_id = $2
		 )`, userID, questionID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("srs: card exists: %w", err)
	}
	return exists, nil
}

// GetCard returns one card by ID, verifying it belongs to userID.
func (r *Repo) GetCard(ctx context.Context, cardID, userID string) (Card, error) {
	var c Card
	err := r.pool.QueryRow(ctx,
		`SELECT id, user_id, question_id, front, back, source_type,
		        interval_days, repetitions, ease_factor,
		        to_char(due_date, 'YYYY-MM-DD'), last_reviewed_at, created_at
		 FROM srs_cards
		 WHERE id = $1 AND user_id = $2`, cardID, userID,
	).Scan(
		&c.ID, &c.UserID, &c.QuestionID, &c.Front, &c.Back, &c.SourceType,
		&c.IntervalDays, &c.Repetitions, &c.EaseFactor,
		&c.DueDate, &c.LastReviewedAt, &c.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Card{}, ErrNotFound
		}
		return Card{}, fmt.Errorf("srs: get card: %w", err)
	}
	return c, nil
}

// MaybeCreateCard creates an SRS card for a user+question pair only if one does
// not already exist. It is called from the assessment package after a wrong
// answer is recorded and must be safe to call with a nil questionID (in which
// case the check is skipped and the card is always inserted).
func MaybeCreateCard(ctx context.Context, pool *pgxpool.Pool, userID string, req CreateCardRequest) error {
	r := NewRepo(pool)
	if req.QuestionID != nil && *req.QuestionID != "" {
		exists, err := r.CardExists(ctx, userID, *req.QuestionID)
		if err != nil {
			return err
		}
		if exists {
			return nil
		}
	}
	_, err := r.CreateCard(ctx, userID, req)
	return err
}
