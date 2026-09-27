package workspace

import (
	"context"
	"fmt"
	"strconv"

	"github.com/jackc/pgx/v5"
)

// eventInsert is one work_item_events row — append-only, exactly one per
// logical change, written in the same tx as the change itself.
type eventInsert struct {
	ProjectID string
	ItemID    string
	ActorID   *string
	Source    string
	Kind      string
	Field     *string
	FromValue *string
	ToValue   *string
	Reason    *string
}

// InsertItemEvent appends one event row.
func (r *Repo) InsertItemEvent(ctx context.Context, db DBTX, e eventInsert) error {
	if _, err := db.Exec(ctx,
		`INSERT INTO work_item_events (project_id, item_id, actor_id, source, kind, field, from_value, to_value, reason)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
		e.ProjectID, e.ItemID, e.ActorID, e.Source, e.Kind, e.Field, e.FromValue, e.ToValue, e.Reason,
	); err != nil {
		return fmt.Errorf("workspace: insert item event: %w", err)
	}
	return nil
}

// ListItemEvents cursor-paginates one item's timeline, oldest id first is not
// useful for a log — newest first, keyset on the IDENTITY id itself (already
// strictly increasing, so no composite cursor is needed).
func (r *Repo) ListItemEvents(ctx context.Context, db DBTX, projectID, itemID string, beforeID int64, limit int) ([]ItemEvent, error) {
	var rows pgx.Rows
	var err error
	const cols = `e.id, e.actor_id, COALESCE(u.name, 'Former member'), e.source, e.kind, e.field, e.from_value, e.to_value, e.reason, e.created_at`
	if beforeID <= 0 {
		rows, err = db.Query(ctx,
			`SELECT `+cols+` FROM work_item_events e LEFT JOIN users u ON u.id = e.actor_id
			  WHERE e.project_id = $1 AND e.item_id = $2 ORDER BY e.id DESC LIMIT $3`,
			projectID, itemID, limit)
	} else {
		rows, err = db.Query(ctx,
			`SELECT `+cols+` FROM work_item_events e LEFT JOIN users u ON u.id = e.actor_id
			  WHERE e.project_id = $1 AND e.item_id = $2 AND e.id < $3 ORDER BY e.id DESC LIMIT $4`,
			projectID, itemID, beforeID, limit)
	}
	if err != nil {
		return nil, fmt.Errorf("workspace: list item events: %w", err)
	}
	defer rows.Close()

	out := []ItemEvent{}
	for rows.Next() {
		var ev ItemEvent
		if err := rows.Scan(&ev.ID, &ev.ActorID, &ev.ActorName, &ev.Source, &ev.Kind, &ev.Field, &ev.FromValue, &ev.ToValue, &ev.Reason, &ev.CreatedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan item event: %w", err)
		}
		out = append(out, ev)
	}
	return out, rows.Err()
}

// CountItemEvents is used by the planning board's "Logs" tab count — a real
// number instead of the old fixture's hardcoded 5.
func (r *Repo) CountItemEvents(ctx context.Context, db DBTX, itemID string) (int, error) {
	var n int
	if err := db.QueryRow(ctx, `SELECT count(*) FROM work_item_events WHERE item_id = $1`, itemID).Scan(&n); err != nil {
		return 0, fmt.Errorf("workspace: count item events: %w", err)
	}
	return n, nil
}

// CountComments counts non-deleted comments on a work item (comments.subject_type
// was widened for 'work_item' in 037) — the issues feed's real "comments" count.
func (r *Repo) CountComments(ctx context.Context, db DBTX, itemID string) (int, error) {
	var n int
	if err := db.QueryRow(ctx,
		`SELECT count(*) FROM comments WHERE subject_type = 'work_item' AND subject_id = $1 AND deleted_at IS NULL`,
		itemID,
	).Scan(&n); err != nil {
		return 0, fmt.Errorf("workspace: count comments: %w", err)
	}
	return n, nil
}

// ListRecentEventsForItems returns the most recent events across a set of
// items (planning board's change log), newest first.
func (r *Repo) ListRecentEventsForItems(ctx context.Context, db DBTX, itemIDs []string, limit int) ([]ItemEvent, error) {
	if len(itemIDs) == 0 {
		return []ItemEvent{}, nil
	}
	rows, err := db.Query(ctx,
		`SELECT e.id, e.actor_id, COALESCE(u.name, 'Former member'), e.source, e.kind, e.field, e.from_value, e.to_value, e.reason, e.created_at
		   FROM work_item_events e LEFT JOIN users u ON u.id = e.actor_id
		  WHERE e.item_id = ANY($1)
		  ORDER BY e.id DESC LIMIT $2`,
		itemIDs, limit)
	if err != nil {
		return nil, fmt.Errorf("workspace: list recent events: %w", err)
	}
	defer rows.Close()
	out := []ItemEvent{}
	for rows.Next() {
		var ev ItemEvent
		if err := rows.Scan(&ev.ID, &ev.ActorID, &ev.ActorName, &ev.Source, &ev.Kind, &ev.Field, &ev.FromValue, &ev.ToValue, &ev.Reason, &ev.CreatedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan recent event: %w", err)
		}
		out = append(out, ev)
	}
	return out, rows.Err()
}

// GetUserName is the planning board's own tiny lookup for the caller's
// display name (claims carries no name — see internal/auth.Claims).
func (r *Repo) GetUserName(ctx context.Context, db DBTX, userID string) (string, error) {
	var name string
	if err := db.QueryRow(ctx, `SELECT name FROM users WHERE id = $1`, userID).Scan(&name); err != nil {
		return "", fmt.Errorf("workspace: get user name: %w", err)
	}
	return name, nil
}

// beforeIDFromCursor / cursorFromID: ListItemEvents' cursor is just the
// event id itself, base10 — no need for pagination.EncodeCursor's
// (time,id) pair since work_item_events.id is already a strictly
// increasing IDENTITY column.
func beforeIDFromCursor(cursor string) int64 {
	n, _ := strconv.ParseInt(cursor, 10, 64)
	return n
}

func cursorFromID(id int64) string {
	return strconv.FormatInt(id, 10)
}
