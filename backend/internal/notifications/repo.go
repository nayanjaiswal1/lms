package notifications

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the notifications domain.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// ErrNotFound — row does not exist or is not visible to the caller.
var ErrNotFound = errors.New("notifications: not found")

const notificationColumns = `
	id, org_id, user_id, type, title, body, link_url, entity_type, entity_id,
	actor_user_id, priority, dedupe_key, read_at, created_at`

func scanNotification(row pgx.Row) (*Notification, error) {
	var n Notification
	err := row.Scan(
		&n.ID, &n.OrgID, &n.UserID, &n.Type, &n.Title, &n.Body, &n.LinkURL, &n.EntityType, &n.EntityID,
		&n.ActorUserID, &n.Priority, &n.DedupeKey, &n.ReadAt, &n.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("notifications: scan: %w", err)
	}
	return &n, nil
}

// Insert dedupe-inserts one notification row inside the caller's own
// transaction tx, keyed UNIQUE(user_id, dedupe_key) — ON CONFLICT DO NOTHING
// so calling this twice for the same logical event (e.g. a redelivered
// webhook) produces exactly one row. Returns inserted=false (not an error)
// on a dedupe no-op — Service.Notify uses this to decide whether to also
// fire the AlsoEmail side-effect, so a redelivery never double-emails either.
func (r *Repo) Insert(ctx context.Context, tx pgx.Tx, n New) (bool, error) {
	tag, err := tx.Exec(ctx,
		`INSERT INTO notifications
			(org_id, user_id, type, title, body, link_url, entity_type, entity_id, actor_user_id, priority, dedupe_key)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		 ON CONFLICT (user_id, dedupe_key) DO NOTHING`,
		n.OrgID, n.UserID, n.Type, n.Title, n.Body, n.LinkURL, n.EntityType, n.EntityID, n.ActorUserID, n.Priority, n.DedupeKey,
	)
	if err != nil {
		return false, fmt.Errorf("notifications: insert: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

// userContact resolves userID's email/name for the AlsoEmail side-effect —
// New carries a UserID, not an email address, so Service.enqueueEmail looks
// it up here rather than requiring every caller to already have it in hand.
func (r *Repo) userContact(ctx context.Context, userID string) (email, name string, err error) {
	err = r.pool.QueryRow(ctx, `SELECT email, name FROM users WHERE id = $1`, userID).Scan(&email, &name)
	if err != nil {
		return "", "", fmt.Errorf("notifications: resolve user contact: %w", err)
	}
	return email, name, nil
}

// List returns a user's notifications newest-first, capped at limit.
func (r *Repo) List(ctx context.Context, userID string, limit int) ([]Notification, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+notificationColumns+` FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`,
		userID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("notifications: list: %w", err)
	}
	defer rows.Close()

	out := []Notification{}
	for rows.Next() {
		n, err := scanNotification(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *n)
	}
	return out, rows.Err()
}

// UnreadCount returns how many of a user's notifications are unread.
func (r *Repo) UnreadCount(ctx context.Context, userID string) (int, error) {
	var count int
	if err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND read_at IS NULL`, userID).Scan(&count); err != nil {
		return 0, fmt.Errorf("notifications: unread count: %w", err)
	}
	return count, nil
}

// MarkRead marks one notification read — scoped to userID so a caller can
// never mark another user's notification, idempotent (re-marking an already
// read notification, or one that doesn't exist for this user, is only an
// error in the latter case).
func (r *Repo) MarkRead(ctx context.Context, userID, id string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE notifications SET read_at = now() WHERE id = $1 AND user_id = $2 AND read_at IS NULL`,
		id, userID,
	)
	if err != nil {
		return fmt.Errorf("notifications: mark read: %w", err)
	}
	if tag.RowsAffected() > 0 {
		return nil
	}
	var exists bool
	if err := r.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM notifications WHERE id = $1 AND user_id = $2)`, id, userID).Scan(&exists); err != nil {
		return fmt.Errorf("notifications: mark read: check existence: %w", err)
	}
	if !exists {
		return ErrNotFound
	}
	// Row exists but was already read — repeat mark-read calls from the
	// frontend are a normal no-op, not an error.
	return nil
}

// MarkAllRead marks every unread notification for userID read in one statement.
func (r *Repo) MarkAllRead(ctx context.Context, userID string) error {
	_, err := r.pool.Exec(ctx, `UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL`, userID)
	if err != nil {
		return fmt.Errorf("notifications: mark all read: %w", err)
	}
	return nil
}
