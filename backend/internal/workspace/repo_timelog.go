package workspace

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// repo_timelog.go — Phase 4 (contract-phase4.md 4b) data layer for
// work_item_time_logs.

const timeLogColumns = `tl.id, tl.item_id, p.key_prefix || '-' || w.key_num, tl.user_id, COALESCE(u.name, 'Former member'),
	tl.minutes, tl.note, tl.logged_on, tl.created_at`

func scanTimeLog(row pgx.Row, callerID string) (*TimeLog, error) {
	var t TimeLog
	var loggedOn time.Time
	err := row.Scan(&t.ID, &t.ItemID, &t.ItemKey, &t.UserID, &t.UserName, &t.Minutes, &t.Note, &loggedOn, &t.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan time log: %w", err)
	}
	t.LoggedOn = loggedOn.Format("2006-01-02")
	t.Editable = t.UserID != nil && *t.UserID == callerID && time.Since(t.CreatedAt) <= TimeLogEditWindow
	return &t, nil
}

// ListTimeLogs cursor-paginates time logs, newest first, optionally scoped to
// one item and/or one user. Visibility is resolved by the caller
// (service_timelog.go) into userFilter/itemFilter before this is called.
// Mirrors ListWorkItems' own dynamic-WHERE builder (repo_items.go).
func (r *Repo) ListTimeLogs(ctx context.Context, db DBTX, projectID, itemFilter, userFilter, callerID string, cursorAt time.Time, cursorID string, limit int) ([]TimeLog, error) {
	where := []string{"tl.project_id = $1"}
	args := []any{projectID}
	arg := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}
	if itemFilter != "" {
		where = append(where, "tl.item_id = "+arg(itemFilter))
	}
	if userFilter != "" {
		where = append(where, "tl.user_id = "+arg(userFilter))
	}
	if cursorID != "" {
		where = append(where, fmt.Sprintf("(tl.created_at, tl.id) < (%s, %s)", arg(cursorAt), arg(cursorID)))
	}
	args = append(args, limit)

	query := `SELECT ` + timeLogColumns + `
		FROM work_item_time_logs tl
		JOIN work_items w ON w.id = tl.item_id
		JOIN workspace_projects p ON p.id = tl.project_id
		LEFT JOIN users u ON u.id = tl.user_id
		WHERE ` + joinAnd(where) + ` ORDER BY tl.created_at DESC, tl.id DESC LIMIT $` + fmt.Sprintf("%d", len(args))
	rows, err := db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("workspace: list time logs: %w", err)
	}
	defer rows.Close()
	out := []TimeLog{}
	for rows.Next() {
		t, err := scanTimeLog(rows, callerID)
		if err != nil {
			return nil, err
		}
		out = append(out, *t)
	}
	return out, rows.Err()
}

// LockDailyMinutes takes the per-user-per-day advisory lock (contract-
// phase4.md: pg_advisory_xact_lock(hashtextextended('time_log:'||user||':'
// ||day,0))) and returns the sum of minutes already logged that day, minus
// excludeLogID's own minutes when updating an existing row. Held for the rest
// of tx — the daily-cap check and the write it gates happen in one
// transaction (agent-hard-rules.md: "locks cover both the check and the
// write").
func (r *Repo) LockDailyMinutes(ctx context.Context, tx pgx.Tx, userID, loggedOn, excludeLogID string) (int, error) {
	lockKey := "time_log:" + userID + ":" + loggedOn
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`, lockKey); err != nil {
		return 0, fmt.Errorf("workspace: lock daily minutes: %w", err)
	}
	var sum int
	if err := tx.QueryRow(ctx,
		`SELECT COALESCE(SUM(minutes), 0) FROM work_item_time_logs
		  WHERE user_id = $1 AND logged_on = $2::date AND ($3 = '' OR id <> $3::uuid)`,
		userID, loggedOn, excludeLogID,
	).Scan(&sum); err != nil {
		return 0, fmt.Errorf("workspace: sum daily minutes: %w", err)
	}
	return sum, nil
}

// InsertTimeLog inserts one log row; caller already holds the daily-minutes
// advisory lock in the same tx.
func (r *Repo) InsertTimeLog(ctx context.Context, tx pgx.Tx, projectID, itemID, userID string, minutes int, note *string, loggedOn string) (*TimeLog, error) {
	var id string
	if err := tx.QueryRow(ctx,
		`INSERT INTO work_item_time_logs (project_id, item_id, user_id, minutes, note, logged_on)
		 VALUES ($1,$2,$3,$4,$5,$6::date) RETURNING id`,
		projectID, itemID, userID, minutes, note, loggedOn,
	).Scan(&id); err != nil {
		return nil, fmt.Errorf("workspace: insert time log: %w", err)
	}
	return r.GetTimeLog(ctx, tx, id, userID)
}

// GetTimeLog returns one time log row (callerID drives the returned
// Editable flag — see scanTimeLog).
func (r *Repo) GetTimeLog(ctx context.Context, db DBTX, id, callerID string) (*TimeLog, error) {
	return scanTimeLog(db.QueryRow(ctx,
		`SELECT `+timeLogColumns+`
		   FROM work_item_time_logs tl
		   JOIN work_items w ON w.id = tl.item_id
		   JOIN workspace_projects p ON p.id = tl.project_id
		   LEFT JOIN users u ON u.id = tl.user_id
		  WHERE tl.id = $1`,
		id), callerID)
}

// LockTimeLogRow locks and returns the row backing UpdateTimeLog/DeleteTimeLog
// so its user_id/created_at (the ownership and edit-window checks) can't
// change between the check and the write.
func (r *Repo) LockTimeLogRow(ctx context.Context, tx pgx.Tx, projectID, id string) (userID string, minutes int, loggedOn string, createdAt time.Time, err error) {
	var uid *string
	var logged time.Time
	err = tx.QueryRow(ctx,
		`SELECT user_id, minutes, logged_on, created_at FROM work_item_time_logs WHERE id = $1 AND project_id = $2 FOR UPDATE`,
		id, projectID,
	).Scan(&uid, &minutes, &logged, &createdAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", 0, "", time.Time{}, ErrNotFound
	}
	if err != nil {
		return "", 0, "", time.Time{}, fmt.Errorf("workspace: lock time log row: %w", err)
	}
	if uid != nil {
		userID = *uid
	}
	return userID, minutes, logged.Format("2006-01-02"), createdAt, nil
}

// UpdateTimeLog applies a validated edit inside the caller's tx.
func (r *Repo) UpdateTimeLog(ctx context.Context, tx pgx.Tx, id string, minutes int, note *string, loggedOn string) error {
	if _, err := tx.Exec(ctx,
		`UPDATE work_item_time_logs SET minutes = $2, note = $3, logged_on = $4::date, updated_at = now() WHERE id = $1`,
		id, minutes, note, loggedOn,
	); err != nil {
		return fmt.Errorf("workspace: update time log: %w", err)
	}
	return nil
}

func (r *Repo) DeleteTimeLog(ctx context.Context, db DBTX, projectID, id string) error {
	tag, err := db.Exec(ctx, `DELETE FROM work_item_time_logs WHERE id = $1 AND project_id = $2`, id, projectID)
	if err != nil {
		return fmt.Errorf("workspace: delete time log: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
