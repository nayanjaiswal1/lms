package whatnow

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the What Now? domain.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// ErrNotFound is returned when a task does not exist or does not belong to
// the requesting user.
var ErrNotFound = errors.New("whatnow: not found")

const taskColumns = `id, user_id, title, status, duration_min,
	to_char(deadline, 'YYYY-MM-DD'), category, vague, chips, task_trigger,
	resume_note, depends_on, plan_position, pinned_until, created_at,
	touched_at, completed_at, revived_at, decayed_at, scheduled_start`

type scanner interface {
	Scan(dest ...any) error
}

func scanTask(row scanner) (Task, error) {
	var t Task
	var duration *int
	var deadline, category, trigger, resumeNote *string
	var chipsJSON []byte
	var dependsOn []string
	var completedAt *time.Time
	var createdAt time.Time

	if err := row.Scan(
		&t.ID, &t.userID, &t.Title, &t.Status, &duration,
		&deadline, &category, &t.Vague, &chipsJSON, &trigger,
		&resumeNote, &dependsOn, &t.planPosition, &t.pinnedUntil, &createdAt,
		&t.touchedAt, &completedAt, &t.revivedAt, &t.decayedAt, &t.scheduledStart,
	); err != nil {
		return Task{}, err
	}

	t.DurationMin = duration
	if deadline != nil {
		t.Deadline = *deadline
	}
	if category != nil {
		t.Category = *category
	}
	if trigger != nil {
		t.Trigger = *trigger
	}
	if resumeNote != nil {
		t.ResumeNote = *resumeNote
	}
	t.DependsOn = dependsOn
	t.CreatedAt = createdAt.Format(time.RFC3339)
	if completedAt != nil {
		t.CompletedAt = completedAt.Format(time.RFC3339)
	}
	if t.scheduledStart != nil {
		t.ScheduledStart = t.scheduledStart.Format(time.RFC3339)
	}
	if len(chipsJSON) > 0 {
		if err := json.Unmarshal(chipsJSON, &t.Chips); err != nil {
			return Task{}, fmt.Errorf("whatnow: unmarshal chips: %w", err)
		}
	}
	return t, nil
}

// GetTask returns one task by ID, verifying it belongs to userID.
func (r *Repo) GetTask(ctx context.Context, id, userID string) (Task, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+taskColumns+` FROM whatnow_tasks WHERE id = $1 AND user_id = $2`,
		id, userID)
	t, err := scanTask(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Task{}, ErrNotFound
		}
		return Task{}, fmt.Errorf("whatnow: get task: %w", err)
	}
	return t, nil
}

// ListByStatuses returns every task for userID whose status is in statuses.
func (r *Repo) ListByStatuses(ctx context.Context, userID string, statuses []TaskStatus) ([]Task, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+taskColumns+` FROM whatnow_tasks WHERE user_id = $1 AND status = ANY($2)
		 ORDER BY created_at`,
		userID, statuses)
	if err != nil {
		return nil, fmt.Errorf("whatnow: list by statuses: %w", err)
	}
	defer rows.Close()

	out := []Task{}
	for rows.Next() {
		t, err := scanTask(rows)
		if err != nil {
			return nil, fmt.Errorf("whatnow: scan task: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListPlanned returns planned tasks ordered by plan_position (nulls last,
// then created_at) for today's plan.
func (r *Repo) ListPlanned(ctx context.Context, userID string) ([]Task, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+taskColumns+` FROM whatnow_tasks WHERE user_id = $1 AND status = 'planned'
		 ORDER BY plan_position NULLS LAST, created_at`,
		userID)
	if err != nil {
		return nil, fmt.Errorf("whatnow: list planned: %w", err)
	}
	defer rows.Close()

	out := []Task{}
	for rows.Next() {
		t, err := scanTask(rows)
		if err != nil {
			return nil, fmt.Errorf("whatnow: scan task: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListScheduledForDay returns planned tasks whose scheduled_start falls in
// [dayStart, dayEnd), ordered by scheduled_start, for the Plan Day timeline.
func (r *Repo) ListScheduledForDay(ctx context.Context, userID string, dayStart, dayEnd time.Time) ([]Task, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+taskColumns+` FROM whatnow_tasks
		 WHERE user_id = $1 AND status = 'planned'
		   AND scheduled_start >= $2 AND scheduled_start < $3
		 ORDER BY scheduled_start`,
		userID, dayStart, dayEnd)
	if err != nil {
		return nil, fmt.Errorf("whatnow: list scheduled for day: %w", err)
	}
	defer rows.Close()

	out := []Task{}
	for rows.Next() {
		t, err := scanTask(rows)
		if err != nil {
			return nil, fmt.Errorf("whatnow: scan task: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListPlannedUnscheduled returns planned tasks with no scheduled_start,
// ordered by plan_position (nulls last, then created_at) — the Plan Day
// backlog, ranked the same way the Shelf's Today list already is.
func (r *Repo) ListPlannedUnscheduled(ctx context.Context, userID string) ([]Task, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+taskColumns+` FROM whatnow_tasks
		 WHERE user_id = $1 AND status = 'planned' AND scheduled_start IS NULL
		 ORDER BY plan_position NULLS LAST, created_at`,
		userID)
	if err != nil {
		return nil, fmt.Errorf("whatnow: list planned unscheduled: %w", err)
	}
	defer rows.Close()

	out := []Task{}
	for rows.Next() {
		t, err := scanTask(rows)
		if err != nil {
			return nil, fmt.Errorf("whatnow: scan task: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListCompletedTasks returns every 'done' task for userID, newest completion
// first — backs the learning journal's day-timeline merge (see
// journal.Handler.ListEntries), which projects each into a read-only entry
// on the day it was completed.
func (r *Repo) ListCompletedTasks(ctx context.Context, userID string) ([]Task, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+taskColumns+` FROM whatnow_tasks
		 WHERE user_id = $1 AND status = 'done' AND completed_at IS NOT NULL
		 ORDER BY completed_at DESC`,
		userID)
	if err != nil {
		return nil, fmt.Errorf("whatnow: list completed tasks: %w", err)
	}
	defer rows.Close()

	out := []Task{}
	for rows.Next() {
		t, err := scanTask(rows)
		if err != nil {
			return nil, fmt.Errorf("whatnow: scan task: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListDoneIDs returns the set of task IDs with status 'done', used to check
// whether a task's dependencies have all been completed.
func (r *Repo) ListDoneIDs(ctx context.Context, userID string) (map[string]bool, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id FROM whatnow_tasks WHERE user_id = $1 AND status = 'done'`, userID)
	if err != nil {
		return nil, fmt.Errorf("whatnow: list done ids: %w", err)
	}
	defer rows.Close()

	out := map[string]bool{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("whatnow: scan done id: %w", err)
		}
		out[id] = true
	}
	return out, rows.Err()
}

// InsertTask creates a new task and returns the full row.
func (r *Repo) InsertTask(ctx context.Context, userID string, t Task) (Task, error) {
	chipsJSON, err := json.Marshal(t.Chips)
	if err != nil {
		return Task{}, fmt.Errorf("whatnow: marshal chips: %w", err)
	}
	row := r.pool.QueryRow(ctx,
		`INSERT INTO whatnow_tasks (user_id, title, status, duration_min, deadline, category, vague, chips)
		 VALUES ($1, $2, $3, $4, NULLIF($5, '')::date, NULLIF($6, ''), $7, $8)
		 RETURNING `+taskColumns,
		userID, t.Title, t.Status, t.DurationMin, t.Deadline, t.Category, t.Vague, chipsJSON)
	created, err := scanTask(row)
	if err != nil {
		return Task{}, fmt.Errorf("whatnow: insert task: %w", err)
	}
	return created, nil
}

// UpdateTask writes back the full row for t (an in-memory-merged Task).
// Callers are expected to load, mutate, then call UpdateTask — no dynamic
// SQL builder, matching the store.ts Object.assign merge pattern.
func (r *Repo) UpdateTask(ctx context.Context, t Task) error {
	chipsJSON, err := json.Marshal(t.Chips)
	if err != nil {
		return fmt.Errorf("whatnow: marshal chips: %w", err)
	}
	var completedAt any
	if t.CompletedAt != "" {
		parsed, err := time.Parse(time.RFC3339, t.CompletedAt)
		if err != nil {
			return fmt.Errorf("whatnow: parse completed_at: %w", err)
		}
		completedAt = parsed
	}

	tag, err := r.pool.Exec(ctx,
		`UPDATE whatnow_tasks SET
			title = $2, status = $3, duration_min = $4,
			deadline = NULLIF($5, '')::date, category = NULLIF($6, ''), vague = $7,
			chips = $8, task_trigger = NULLIF($9, ''), resume_note = NULLIF($10, ''),
			depends_on = $11, plan_position = $12, pinned_until = $13,
			touched_at = $14, completed_at = $15, revived_at = $16, decayed_at = $17,
			scheduled_start = $19
		 WHERE id = $1 AND user_id = $18`,
		t.ID, t.Title, t.Status, t.DurationMin,
		t.Deadline, t.Category, t.Vague,
		chipsJSON, t.Trigger, t.ResumeNote,
		t.DependsOn, t.planPosition, t.pinnedUntil,
		t.touchedAt, completedAt, t.revivedAt, t.decayedAt,
		t.userID, t.scheduledStart,
	)
	if err != nil {
		return fmt.Errorf("whatnow: update task: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// DeleteTask removes a task (used when a breakdown replaces its parent).
func (r *Repo) DeleteTask(ctx context.Context, id, userID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM whatnow_tasks WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return fmt.Errorf("whatnow: delete task: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// InsertBreakdownStep inserts one chained breakdown step (used by
// ConfirmBreakdown inside a transaction).
func (r *Repo) InsertBreakdownStep(ctx context.Context, tx pgx.Tx, userID string, t Task) (Task, error) {
	chipsJSON, err := json.Marshal(t.Chips)
	if err != nil {
		return Task{}, fmt.Errorf("whatnow: marshal chips: %w", err)
	}
	dependsOn := t.DependsOn
	if dependsOn == nil {
		dependsOn = []string{}
	}
	row := tx.QueryRow(ctx,
		`INSERT INTO whatnow_tasks (user_id, title, status, duration_min, deadline, category, chips, depends_on)
		 VALUES ($1, $2, $3, $4, NULLIF($5, '')::date, NULLIF($6, ''), $7, $8)
		 RETURNING `+taskColumns,
		userID, t.Title, t.Status, t.DurationMin, t.Deadline, t.Category, chipsJSON, dependsOn)
	created, err := scanTask(row)
	if err != nil {
		return Task{}, fmt.Errorf("whatnow: insert breakdown step: %w", err)
	}
	return created, nil
}

// WithTx runs fn inside a transaction.
func (r *Repo) WithTx(ctx context.Context, fn func(tx pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("whatnow: begin tx: %w", err)
	}
	defer tx.Rollback(ctx)
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// DeleteTaskTx is DeleteTask scoped to an in-flight transaction.
func (r *Repo) DeleteTaskTx(ctx context.Context, tx pgx.Tx, id, userID string) error {
	tag, err := tx.Exec(ctx, `DELETE FROM whatnow_tasks WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return fmt.Errorf("whatnow: delete task tx: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SweepDecayed marks inbox/planned tasks untouched for 14+ days as decayed.
func (r *Repo) SweepDecayed(ctx context.Context, userID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE whatnow_tasks SET status = 'decayed', decayed_at = now()
		 WHERE user_id = $1 AND status IN ('inbox', 'planned')
		   AND touched_at < now() - interval '14 days'`,
		userID)
	if err != nil {
		return fmt.Errorf("whatnow: sweep decayed: %w", err)
	}
	return nil
}

// WeeklyStats counts completions/revivals/releases and throughput over the
// last 7 days for the weekly recap and PickNow's tired-brain scoring.
type WeeklyStats struct {
	Completed  int
	Revived    int
	Released   int
	Throughput int
}

// GetWeeklyStats aggregates the last 7 days of task activity for userID.
func (r *Repo) GetWeeklyStats(ctx context.Context, userID string) (WeeklyStats, error) {
	var s WeeklyStats
	err := r.pool.QueryRow(ctx,
		`SELECT
			count(*) FILTER (WHERE completed_at >= now() - interval '7 days'),
			count(*) FILTER (WHERE revived_at >= now() - interval '7 days'),
			count(*) FILTER (WHERE status = 'decayed' AND decayed_at >= now() - interval '7 days')
		 FROM whatnow_tasks WHERE user_id = $1`,
		userID,
	).Scan(&s.Completed, &s.Revived, &s.Released)
	if err != nil {
		return WeeklyStats{}, fmt.Errorf("whatnow: get weekly stats: %w", err)
	}
	s.Throughput = max(1, int(math.Round(float64(s.Completed)/7)))
	return s, nil
}

// GetUserState returns the user's energy state, defaulting to EnergySharp
// when no profile row exists yet or none was ever set.
func (r *Repo) GetUserState(ctx context.Context, userID string) (Energy, error) {
	var energy *Energy
	err := r.pool.QueryRow(ctx,
		`SELECT whatnow_energy FROM user_profiles WHERE user_id = $1`, userID,
	).Scan(&energy)
	if errors.Is(err, pgx.ErrNoRows) {
		return EnergySharp, nil
	}
	if err != nil {
		return "", fmt.Errorf("whatnow: get user state: %w", err)
	}
	if energy == nil {
		return EnergySharp, nil
	}
	return *energy, nil
}

// UpsertUserState sets the user's energy state.
func (r *Repo) UpsertUserState(ctx context.Context, userID string, energy Energy) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_profiles (user_id, whatnow_energy, updated_at)
		 VALUES ($1, $2, now())
		 ON CONFLICT (user_id) DO UPDATE SET whatnow_energy = $2, updated_at = now()`,
		userID, energy)
	if err != nil {
		return fmt.Errorf("whatnow: upsert user state: %w", err)
	}
	return nil
}
