package habit

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("habit: not found")

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// Create inserts a habit, appending it after the user's existing habits and
// assigning it the next slot in the fixed color palette (rotating by how
// many habits the user already has) so a freshly added habit never lands on
// the same color as the one before it.
func (r *Repo) Create(ctx context.Context, userID string, req CreateRequest) (Habit, error) {
	// Weekdays defaults to a non-nil empty slice so pgx encodes it as '{}'
	// rather than NULL against the NOT NULL column.
	weekdays := req.Weekdays
	if weekdays == nil {
		weekdays = []int32{}
	}
	var h Habit
	err := r.pool.QueryRow(ctx,
		`WITH existing AS (
		     SELECT COUNT(*) AS n, COALESCE(MAX(sort_order) + 1, 0) AS next_order
		     FROM habits WHERE user_id = $1
		 )
		 INSERT INTO habits (user_id, name, cadence, sort_order, color, target_count, weekdays)
		 SELECT $1, $2, $3, next_order,
		        (ARRAY['blue','orange','aqua','yellow','magenta','green','violet','red'])[(n % 8) + 1],
		        $4, $5
		 FROM existing
		 RETURNING id, user_id, name, cadence, sort_order, color, target_count, weekdays, created_at`,
		userID, req.Name, req.Cadence, req.TargetCount, weekdays,
	).Scan(&h.ID, &h.UserID, &h.Name, &h.Cadence, &h.SortOrder, &h.Color, &h.TargetCount, &h.Weekdays, &h.CreatedAt)
	if err != nil {
		return Habit{}, fmt.Errorf("habit: create: %w", err)
	}
	return h, nil
}

// UpdateColor changes a user-owned habit's palette slot. Returns ErrNotFound
// if the habit doesn't exist or belongs to another user.
func (r *Repo) UpdateColor(ctx context.Context, habitID, userID string, color Color) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE habits SET color = $1 WHERE id = $2 AND user_id = $3`, color, habitID, userID)
	if err != nil {
		return fmt.Errorf("habit: update color: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Delete removes a user-owned habit and cascades its completions. Returns
// ErrNotFound when the habit does not exist or belongs to another user.
func (r *Repo) Delete(ctx context.Context, habitID, userID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM habits WHERE id = $1 AND user_id = $2`, habitID, userID)
	if err != nil {
		return fmt.Errorf("habit: delete: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ListForRange returns userID's habits, ordered for display, and every
// completion of theirs whose period_start falls within [rangeStart, rangeEnd].
func (r *Repo) ListForRange(ctx context.Context, userID string, rangeStart, rangeEnd time.Time) ([]Habit, []Completion, error) {
	hrows, err := r.pool.Query(ctx,
		`SELECT id, user_id, name, cadence, sort_order, color, target_count, weekdays, created_at
		 FROM habits WHERE user_id = $1 ORDER BY sort_order, created_at`, userID)
	if err != nil {
		return nil, nil, fmt.Errorf("habit: list habits: %w", err)
	}
	habits := []Habit{}
	for hrows.Next() {
		var h Habit
		if err := hrows.Scan(&h.ID, &h.UserID, &h.Name, &h.Cadence, &h.SortOrder, &h.Color, &h.TargetCount, &h.Weekdays, &h.CreatedAt); err != nil {
			hrows.Close()
			return nil, nil, fmt.Errorf("habit: scan habit: %w", err)
		}
		habits = append(habits, h)
	}
	hrows.Close()
	if err := hrows.Err(); err != nil {
		return nil, nil, fmt.Errorf("habit: list habits: %w", err)
	}

	crows, err := r.pool.Query(ctx,
		`SELECT hc.habit_id, hc.period_start, hc.count
		 FROM habit_completions hc
		 JOIN habits h ON h.id = hc.habit_id
		 WHERE h.user_id = $1 AND hc.period_start BETWEEN $2 AND $3
		 ORDER BY hc.period_start`,
		userID, rangeStart, rangeEnd)
	if err != nil {
		return nil, nil, fmt.Errorf("habit: list completions: %w", err)
	}
	defer crows.Close()

	completions := []Completion{}
	for crows.Next() {
		var c Completion
		var periodStart time.Time
		if err := crows.Scan(&c.HabitID, &periodStart, &c.Count); err != nil {
			return nil, nil, fmt.Errorf("habit: scan completion: %w", err)
		}
		c.PeriodStart = periodStart.Format("2006-01-02")
		completions = append(completions, c)
	}
	return habits, completions, crows.Err()
}

// owned reports whether habitID exists and belongs to userID.
func (r *Repo) owned(ctx context.Context, habitID, userID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM habits WHERE id = $1 AND user_id = $2)`,
		habitID, userID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("habit: check ownership: %w", err)
	}
	return exists, nil
}

// SetCompletion adds one check-in to periodStart for a user-owned habit.
// Idempotent past the habit's target_count — an "any N times a week" habit
// caps its count there instead of growing unbounded, and a target_count-1
// habit (daily/monthly/specific-weekday weekly) behaves exactly as a plain
// presence check always did. Returns ErrNotFound if the habit doesn't exist
// or belongs to another user.
func (r *Repo) SetCompletion(ctx context.Context, habitID, userID string, periodStart time.Time) error {
	ok, err := r.owned(ctx, habitID, userID)
	if err != nil {
		return err
	}
	if !ok {
		return ErrNotFound
	}
	if _, err := r.pool.Exec(ctx,
		`INSERT INTO habit_completions (habit_id, period_start, count)
		 VALUES ($1, $2, 1)
		 ON CONFLICT (habit_id, period_start) DO UPDATE
		 SET count = LEAST(habit_completions.count + 1,
		     (SELECT target_count FROM habits WHERE id = $1))`,
		habitID, periodStart,
	); err != nil {
		return fmt.Errorf("habit: set completion: %w", err)
	}
	return nil
}

// ClearCompletion unmarks periodStart for a user-owned habit. Idempotent —
// clearing an already-unmarked period is a no-op. Returns ErrNotFound if the
// habit doesn't exist or belongs to another user.
func (r *Repo) ClearCompletion(ctx context.Context, habitID, userID string, periodStart time.Time) error {
	ok, err := r.owned(ctx, habitID, userID)
	if err != nil {
		return err
	}
	if !ok {
		return ErrNotFound
	}
	if _, err := r.pool.Exec(ctx,
		`DELETE FROM habit_completions WHERE habit_id = $1 AND period_start = $2`,
		habitID, periodStart,
	); err != nil {
		return fmt.Errorf("habit: clear completion: %w", err)
	}
	return nil
}
