package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/activity"
	"github.com/mindforge/backend/internal/habit"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/weeklyrecap"
)

// weeklyRecapWindow is how far back the recap looks.
const weeklyRecapWindow = 7 * 24 * time.Hour

// recapRecipient is one active user with an email and their earliest active
// org (the activity feed is org-scoped; see activity.eventsCTE).
type recapRecipient struct {
	UserID, OrgID, Email, Name string
	Notifications              map[string]any
}

// WeeklyRecapKey is the ISO "year-week" the recap idempotency keys use.
func WeeklyRecapKey(t time.Time) string {
	y, w := t.UTC().ISOWeek()
	return fmt.Sprintf("%d-W%02d", y, w)
}

// WeeklyRecapHandler is the fan-out half of the weekly recap email: one
// weekly_recap.user job per active user who has not opted out. It runs on a
// weekly UTC cron (cmd/server/main.go) - unlike digest.nightly it does not
// honor per-user local hours, since a once-a-week send does not need them.
type WeeklyRecapHandler struct {
	pool *pgxpool.Pool
}

func NewWeeklyRecapHandler(pool *pgxpool.Pool) *WeeklyRecapHandler {
	return &WeeklyRecapHandler{pool: pool}
}

func (h *WeeklyRecapHandler) Handle(ctx context.Context, _ jobs.Job) error {
	recipients, err := h.recipients(ctx)
	if err != nil {
		return fmt.Errorf("handlers.weekly_recap: recipients: %w", err)
	}
	week := WeeklyRecapKey(time.Now())
	enqueued := 0
	for _, r := range recipients {
		if optedOut(r.Notifications, notifKeyWeeklyRecap) {
			continue
		}
		payload, err := json.Marshal(WeeklyRecapUserPayload{UserID: r.UserID, OrgID: r.OrgID, Week: week})
		if err != nil {
			return fmt.Errorf("handlers.weekly_recap: marshal payload (user %s): %w", r.UserID, err)
		}
		tag, err := h.pool.Exec(ctx,
			`INSERT INTO jobs (handler, status, priority, payload, idempotency_key)
			 VALUES ($1, 'queued', $2, $3, $4)
			 ON CONFLICT (idempotency_key) DO NOTHING`,
			HandlerWeeklyRecapUser, jobs.PriorityBackground, payload, fmt.Sprintf("weekly_recap:%s:%s", week, r.UserID),
		)
		if err != nil {
			return fmt.Errorf("handlers.weekly_recap: enqueue (user %s): %w", r.UserID, err)
		}
		enqueued += int(tag.RowsAffected())
	}
	slog.InfoContext(ctx, "handlers.weekly_recap: weekly_recap.user jobs enqueued",
		"enqueued", enqueued, "candidates", len(recipients), "week", week)
	return nil
}

func (h *WeeklyRecapHandler) recipients(ctx context.Context) ([]recapRecipient, error) {
	rows, err := h.pool.Query(ctx,
		`SELECT DISTINCT ON (u.id) u.id, om.org_id, u.email, u.name, up.notifications
		   FROM users u
		   JOIN org_members om ON om.user_id = u.id AND om.status = 'active'
		   LEFT JOIN user_profiles up ON up.user_id = u.id
		  WHERE u.status = 'active' AND u.email <> ''
		  ORDER BY u.id, om.joined_at`)
	if err != nil {
		return nil, fmt.Errorf("query: %w", err)
	}
	defer rows.Close()
	out := []recapRecipient{}
	for rows.Next() {
		var r recapRecipient
		var notifRaw []byte
		if err := rows.Scan(&r.UserID, &r.OrgID, &r.Email, &r.Name, &notifRaw); err != nil {
			return nil, fmt.Errorf("scan: %w", err)
		}
		if len(notifRaw) > 0 {
			if err := json.Unmarshal(notifRaw, &r.Notifications); err != nil {
				return nil, fmt.Errorf("unmarshal notifications (user %s): %w", r.UserID, err)
			}
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// WeeklyRecapUserPayload is the JSON payload of weekly_recap.user jobs.
type WeeklyRecapUserPayload struct {
	UserID string `json:"user_id"`
	OrgID  string `json:"org_id"`
	Week   string `json:"week"` // WeeklyRecapKey
}

// WeeklyRecapUserHandler builds and queues one user's recap email, or sends
// nothing when the week had no activity and no habit streak is running. The
// email.send job honors cfg.ShouldSendRealEmail like every other email.
type WeeklyRecapUserHandler struct {
	pool     *pgxpool.Pool
	activity *activity.Repo
	habits   *habit.Repo
	registry *jobs.Registry
}

func NewWeeklyRecapUserHandler(pool *pgxpool.Pool, registry *jobs.Registry) *WeeklyRecapUserHandler {
	return &WeeklyRecapUserHandler{pool: pool, activity: activity.NewRepo(pool), habits: habit.NewRepo(pool), registry: registry}
}

func (h *WeeklyRecapUserHandler) Handle(ctx context.Context, job jobs.Job) error {
	var p WeeklyRecapUserPayload
	if err := json.Unmarshal(job.Payload, &p); err != nil {
		return fmt.Errorf("handlers.weekly_recap_user: unmarshal payload: %w", err)
	}
	if p.UserID == "" || p.OrgID == "" || p.Week == "" {
		return jobs.Permanent(fmt.Errorf("handlers.weekly_recap_user: payload missing user_id/org_id/week"))
	}

	now := time.Now().UTC()
	counts, err := h.activity.CountByKind(ctx, p.UserID, p.OrgID, now.Add(-weeklyRecapWindow), now)
	if err != nil {
		return fmt.Errorf("handlers.weekly_recap_user: counts (user %s): %w", p.UserID, err)
	}
	today := now.Truncate(24 * time.Hour)
	from := today.AddDate(0, 0, -weeklyrecap.MaxStreakLookbackDays)
	habits, completions, err := h.habits.ListForRange(ctx, p.UserID, from, today)
	if err != nil {
		return fmt.Errorf("handlers.weekly_recap_user: habits (user %s): %w", p.UserID, err)
	}
	streaks := weeklyrecap.Streaks(habits, completions, today)
	if !weeklyrecap.HasContent(counts, streaks) {
		return nil
	}

	var email, name string
	if err := h.pool.QueryRow(ctx, `SELECT email, name FROM users WHERE id = $1`, p.UserID).Scan(&email, &name); err != nil {
		return fmt.Errorf("handlers.weekly_recap_user: user contact (user %s): %w", p.UserID, err)
	}
	idemKey := fmt.Sprintf("weekly_recap_email:%s:%s", p.Week, p.UserID)
	_, err = jobs.Enqueue(ctx, h.pool, h.registry, jobs.EnqueueParams{
		Handler:  HandlerEmailSend,
		Priority: jobs.PriorityNormal,
		Payload: EmailPayload{
			Type: emailTypeNotification, To: email, ToName: name,
			TemplateData: map[string]any{"subject": weeklyrecap.Subject, "body": weeklyrecap.Render(counts, streaks)},
		},
		OrgID:          &p.OrgID,
		IdempotencyKey: &idemKey,
	})
	if err != nil && !errors.Is(err, jobs.ErrDuplicateKey) {
		return fmt.Errorf("handlers.weekly_recap_user: enqueue email (user %s): %w", p.UserID, err)
	}
	return nil
}
