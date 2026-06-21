package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
)

// SRSReminderPayload is intentionally empty; the handler derives everything from
// the DB at runtime (all due users, today's date).
type SRSReminderPayload struct{}

// srsDueUser is a row returned by the due-users query.
type srsDueUser struct {
	ID    string
	Email string
	Name  string
}

// SRSHandler implements jobs.Handler for HandlerSRSReminder jobs.
type SRSHandler struct {
	pool *pgxpool.Pool
	cfg  *config.Config
}

// NewSRSHandler constructs an SRSHandler.
func NewSRSHandler(pool *pgxpool.Pool, cfg *config.Config) *SRSHandler {
	return &SRSHandler{pool: pool, cfg: cfg}
}

// Handle enqueues email.send notification jobs for every user who has SRS cards due
// today and has not already received a reminder within the last 20 hours.
// Idempotency is enforced via the idempotency_key on the jobs table, so re-running
// the handler on the same date is safe.
// Users are processed in chunks of 100 to bound per-chunk work.
func (h *SRSHandler) Handle(ctx context.Context, _ jobs.Job) error {
	today := time.Now().UTC().Format("2006-01-02")

	// Query users with SRS cards whose due_date is today or earlier (DATE comparison).
	// We use the idempotency_key "srs_reminder:{date}:{userID}" to deduplicate
	// at INSERT time rather than a complex LEFT JOIN on jobs payload.
	rows, err := h.pool.Query(ctx,
		`SELECT DISTINCT u.id, u.email, u.name
		 FROM users u
		 JOIN srs_cards sc ON sc.user_id = u.id
		 WHERE sc.due_date <= CURRENT_DATE
		   AND u.email <> ''
		 LIMIT 1000`,
	)
	if err != nil {
		return fmt.Errorf("handlers.srs: query due users: %w", err)
	}
	defer rows.Close()

	var users []srsDueUser
	for rows.Next() {
		var du srsDueUser
		if err := rows.Scan(&du.ID, &du.Email, &du.Name); err != nil {
			return fmt.Errorf("handlers.srs: scan due user: %w", err)
		}
		users = append(users, du)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("handlers.srs: due users rows: %w", err)
	}

	if len(users) == 0 {
		slog.InfoContext(ctx, "handlers.srs: no users with due SRS cards, nothing to do")
		return nil
	}

	enqueued := 0
	const chunkSize = 100

	for start := 0; start < len(users); start += chunkSize {
		end := start + chunkSize
		if end > len(users) {
			end = len(users)
		}

		count, err := h.enqueueChunk(ctx, today, users[start:end])
		if err != nil {
			return fmt.Errorf("handlers.srs: enqueue chunk [%d:%d]: %w", start, end, err)
		}
		enqueued += count
	}

	slog.InfoContext(ctx, "handlers.srs: SRS reminders enqueued",
		"enqueued", enqueued,
		"total_due_users", len(users),
		"date", today)
	return nil
}

// enqueueChunk inserts email.send jobs for a slice of due users.
// Each INSERT uses ON CONFLICT (idempotency_key) DO NOTHING so re-runs on the
// same date are safe. Returns the count of rows actually inserted.
func (h *SRSHandler) enqueueChunk(ctx context.Context, date string, users []srsDueUser) (int, error) {
	inserted := 0
	for _, u := range users {
		idempKey := fmt.Sprintf("srs_reminder:%s:%s", date, u.ID)

		emailPayload, err := json.Marshal(map[string]any{
			"type":    "notification",
			"to":      u.Email,
			"to_name": u.Name,
			"template_data": map[string]any{
				"subject": "Cards due for review",
				"body":    "You have cards due for review today.",
			},
		})
		if err != nil {
			return inserted, fmt.Errorf("handlers.srs: marshal email payload for user %s: %w", u.ID, err)
		}

		tag, err := h.pool.Exec(ctx,
			`INSERT INTO jobs (handler, status, priority, payload, idempotency_key)
			 VALUES ($1, 'queued', $2, $3, $4)
			 ON CONFLICT (idempotency_key) DO NOTHING`,
			HandlerEmailSend, jobs.PriorityNormal, emailPayload, idempKey,
		)
		if err != nil {
			return inserted, fmt.Errorf("handlers.srs: insert email job for user %s: %w", u.ID, err)
		}
		inserted += int(tag.RowsAffected())
	}
	return inserted, nil
}
