package habit

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
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
	customFields := req.CustomFields
	if customFields == nil {
		customFields = []CustomField{}
	}
	customFieldsJSON, err := json.Marshal(customFields)
	if err != nil {
		return Habit{}, fmt.Errorf("habit: encode custom fields: %w", err)
	}
	tags := req.Tags
	if tags == nil {
		tags = []string{}
	}

	var h Habit
	var customFieldsRaw []byte
	err = r.pool.QueryRow(ctx,
		`WITH existing AS (
		     SELECT COUNT(*) AS n, COALESCE(MAX(sort_order) + 1, 0) AS next_order
		     FROM habits WHERE user_id = $1
		 )
		 INSERT INTO habits (user_id, name, cadence, sort_order, color, target_count, weekdays, type, custom_fields, icon, tags)
		 SELECT $1, $2, $3, next_order,
		        (ARRAY['blue','orange','aqua','yellow','magenta','green','violet','red'])[(n % 8) + 1],
		        $4, $5, $6, $7::jsonb, $8, $9
		 FROM existing
		 RETURNING id, user_id, name, cadence, sort_order, color, target_count, weekdays, type, custom_fields, icon, tags, created_at`,
		userID, req.Name, req.Cadence, req.TargetCount, weekdays, req.Type, customFieldsJSON, req.Icon, tags,
	).Scan(&h.ID, &h.UserID, &h.Name, &h.Cadence, &h.SortOrder, &h.Color, &h.TargetCount, &h.Weekdays, &h.Type, &customFieldsRaw, &h.Icon, &h.Tags, &h.CreatedAt)
	if err != nil {
		return Habit{}, fmt.Errorf("habit: create: %w", err)
	}
	if err := json.Unmarshal(customFieldsRaw, &h.CustomFields); err != nil {
		return Habit{}, fmt.Errorf("habit: decode custom fields: %w", err)
	}
	return h, nil
}

// Get returns a user-owned habit. Returns ErrNotFound if it doesn't exist or
// belongs to another user.
func (r *Repo) Get(ctx context.Context, habitID, userID string) (Habit, error) {
	var h Habit
	var customFieldsRaw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT id, user_id, name, cadence, sort_order, color, target_count, weekdays, type, custom_fields, icon, tags, created_at
		 FROM habits WHERE id = $1 AND user_id = $2`, habitID, userID,
	).Scan(&h.ID, &h.UserID, &h.Name, &h.Cadence, &h.SortOrder, &h.Color, &h.TargetCount, &h.Weekdays, &h.Type, &customFieldsRaw, &h.Icon, &h.Tags, &h.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Habit{}, ErrNotFound
	}
	if err != nil {
		return Habit{}, fmt.Errorf("habit: get: %w", err)
	}
	if err := json.Unmarshal(customFieldsRaw, &h.CustomFields); err != nil {
		return Habit{}, fmt.Errorf("habit: decode custom fields: %w", err)
	}
	return h, nil
}

// Update applies whichever fields of req are non-nil to a user-owned habit —
// each field its own single-column UPDATE, scoped to this one row, so
// changing a habit's color/icon/tags today never touches any other habit's
// row or any habit_completions row (past months stay exactly as they were).
// Returns ErrNotFound if the habit doesn't exist or belongs to another user.
func (r *Repo) Update(ctx context.Context, habitID, userID string, req UpdateRequest) error {
	ok, err := r.owned(ctx, habitID, userID)
	if err != nil {
		return err
	}
	if !ok {
		return ErrNotFound
	}
	if req.Color != nil {
		if _, err := r.pool.Exec(ctx, `UPDATE habits SET color = $1 WHERE id = $2`, *req.Color, habitID); err != nil {
			return fmt.Errorf("habit: update color: %w", err)
		}
	}
	if req.Icon != nil {
		if _, err := r.pool.Exec(ctx, `UPDATE habits SET icon = $1 WHERE id = $2`, *req.Icon, habitID); err != nil {
			return fmt.Errorf("habit: update icon: %w", err)
		}
	}
	if req.Tags != nil {
		tags := *req.Tags
		if tags == nil {
			tags = []string{}
		}
		if _, err := r.pool.Exec(ctx, `UPDATE habits SET tags = $1 WHERE id = $2`, tags, habitID); err != nil {
			return fmt.Errorf("habit: update tags: %w", err)
		}
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
		`SELECT id, user_id, name, cadence, sort_order, color, target_count, weekdays, type, custom_fields, icon, tags, created_at
		 FROM habits WHERE user_id = $1 ORDER BY sort_order, created_at`, userID)
	if err != nil {
		return nil, nil, fmt.Errorf("habit: list habits: %w", err)
	}
	habits := []Habit{}
	for hrows.Next() {
		var h Habit
		var customFieldsRaw []byte
		if err := hrows.Scan(&h.ID, &h.UserID, &h.Name, &h.Cadence, &h.SortOrder, &h.Color, &h.TargetCount, &h.Weekdays, &h.Type, &customFieldsRaw, &h.Icon, &h.Tags, &h.CreatedAt); err != nil {
			hrows.Close()
			return nil, nil, fmt.Errorf("habit: scan habit: %w", err)
		}
		if err := json.Unmarshal(customFieldsRaw, &h.CustomFields); err != nil {
			hrows.Close()
			return nil, nil, fmt.Errorf("habit: decode custom fields: %w", err)
		}
		habits = append(habits, h)
	}
	hrows.Close()
	if err := hrows.Err(); err != nil {
		return nil, nil, fmt.Errorf("habit: list habits: %w", err)
	}

	crows, err := r.pool.Query(ctx,
		`SELECT hc.habit_id, hc.period_start, hc.count, hc.metadata
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
		var metadataRaw []byte
		if err := crows.Scan(&c.HabitID, &periodStart, &c.Count, &metadataRaw); err != nil {
			return nil, nil, fmt.Errorf("habit: scan completion: %w", err)
		}
		c.PeriodStart = periodStart.Format("2006-01-02")
		if err := json.Unmarshal(metadataRaw, &c.Metadata); err != nil {
			return nil, nil, fmt.Errorf("habit: decode completion metadata: %w", err)
		}
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

// UpsertCompletionMetadata saves periodStart's structured entry for a
// user-owned habit. If the period has no completion row yet, one is created
// with count=1 — saving an entry (e.g. today's workout) also checks the
// habit off for that day, same as clicking its grid cell would. Returns
// ErrNotFound if the habit doesn't exist or belongs to another user.
func (r *Repo) UpsertCompletionMetadata(ctx context.Context, habitID, userID string, periodStart time.Time, metadata map[string]any) error {
	ok, err := r.owned(ctx, habitID, userID)
	if err != nil {
		return err
	}
	if !ok {
		return ErrNotFound
	}
	if metadata == nil {
		metadata = map[string]any{}
	}
	metadataJSON, err := json.Marshal(metadata)
	if err != nil {
		return fmt.Errorf("habit: encode completion metadata: %w", err)
	}
	if _, err := r.pool.Exec(ctx,
		`INSERT INTO habit_completions (habit_id, period_start, count, metadata)
		 VALUES ($1, $2, 1, $3::jsonb)
		 ON CONFLICT (habit_id, period_start) DO UPDATE SET metadata = EXCLUDED.metadata`,
		habitID, periodStart, metadataJSON,
	); err != nil {
		return fmt.Errorf("habit: set completion metadata: %w", err)
	}
	return nil
}
