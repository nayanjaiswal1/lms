package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/calendar"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
)

// CalendarReminderHandler implements jobs.Handler for HandlerCalendarReminder
// jobs. On each tick it finds calendar_events (real and, for recurring
// masters, expanded occurrences) starting within the next
// CALENDAR_REMINDER_LEAD_MINUTES, and enqueues a reminder email.send job per
// attendee — same pattern as SRSHandler/MentorEscalationHandler: a periodic
// sweep, deduplicated via idempotency_key, with no per-event scheduling call
// required (see calendar.Service.CreateEvent's doc comment).
type CalendarReminderHandler struct {
	pool *pgxpool.Pool
	cfg  *config.Config
	repo *calendar.Repo
}

// NewCalendarReminderHandler constructs a CalendarReminderHandler.
func NewCalendarReminderHandler(pool *pgxpool.Pool, cfg *config.Config) *CalendarReminderHandler {
	return &CalendarReminderHandler{pool: pool, cfg: cfg, repo: calendar.NewRepo(pool)}
}

// Handle scans for events starting within the configured reminder lead time
// and enqueues one deduplicated notification email per attendee.
func (h *CalendarReminderHandler) Handle(ctx context.Context, _ jobs.Job) error {
	now := time.Now().UTC()
	leadMinutes := h.cfg.CalendarReminderLeadMinutes
	if leadMinutes <= 0 {
		leadMinutes = 30
	}
	windowEnd := now.Add(time.Duration(leadMinutes) * time.Minute)

	candidates, err := h.repo.ListDueForReminder(ctx, now, windowEnd)
	if err != nil {
		return fmt.Errorf("handlers.calendar_reminder: list due events: %w", err)
	}
	if len(candidates) == 0 {
		return nil
	}

	enqueued := 0
	for _, base := range candidates {
		occurrences := []calendar.Event{base}
		if base.RecurrenceRule != nil && *base.RecurrenceRule != "" {
			occurrences, err = calendar.ExpandOccurrences(base, now, windowEnd)
			if err != nil {
				slog.WarnContext(ctx, "handlers.calendar_reminder: skipping event with unparseable recurrence rule",
					"event_id", base.ID, "error", err)
				continue
			}
		}

		for _, occ := range occurrences {
			n, err := h.remindOccurrence(ctx, occ)
			if err != nil {
				return fmt.Errorf("handlers.calendar_reminder: event %s: %w", occ.ID, err)
			}
			enqueued += n
		}
	}

	if enqueued > 0 {
		slog.InfoContext(ctx, "handlers.calendar_reminder: reminders enqueued", "count", enqueued)
	}
	return nil
}

// remindOccurrence enqueues one deduplicated email.send job per attendee of
// occ. The idempotency key includes the occurrence's own start time so a
// recurring event's distinct occurrences each get their own reminder.
func (h *CalendarReminderHandler) remindOccurrence(ctx context.Context, occ calendar.Event) (int, error) {
	attendees, err := h.repo.GetAttendees(ctx, occ.ID)
	if err != nil {
		return 0, fmt.Errorf("list attendees: %w", err)
	}
	if len(attendees) == 0 {
		return 0, nil
	}

	subject := fmt.Sprintf("Reminder: %s starts soon", occ.Title)
	body := reminderBody(occ, h.cfg.FrontendURL)

	enqueued := 0
	for _, a := range attendees {
		if a.Email == nil || *a.Email == "" {
			continue
		}
		idempKey := fmt.Sprintf("calendar_reminder:%s:%d:%s", occ.ID, occ.StartsAt.UTC().Unix(), a.UserID)

		name := ""
		if a.Name != nil {
			name = *a.Name
		}
		payload, err := json.Marshal(map[string]any{
			"type":    "notification",
			"to":      *a.Email,
			"to_name": name,
			"template_data": map[string]any{
				"subject": subject,
				"body":    body,
			},
		})
		if err != nil {
			return enqueued, fmt.Errorf("marshal reminder payload for attendee %s: %w", a.UserID, err)
		}

		tag, err := h.pool.Exec(ctx,
			`INSERT INTO jobs (handler, status, priority, payload, idempotency_key)
			 VALUES ($1, 'queued', $2, $3, $4)
			 ON CONFLICT (idempotency_key) DO NOTHING`,
			HandlerEmailSend, jobs.PriorityHigh, payload, idempKey,
		)
		if err != nil {
			return enqueued, fmt.Errorf("insert reminder email job for attendee %s: %w", a.UserID, err)
		}
		enqueued += int(tag.RowsAffected())
	}
	return enqueued, nil
}

func reminderBody(occ calendar.Event, frontendURL string) string {
	when := occ.StartsAt.Local().Format("Mon Jan 2, 3:04 PM MST")
	body := fmt.Sprintf("\"%s\" starts at %s.", occ.Title, when)
	if occ.MeetingURL != nil && *occ.MeetingURL != "" {
		body += "\n\nJoin: " + *occ.MeetingURL
	}
	body += "\n\nView it on your calendar:\n" + frontendURL + "/calendar"
	return body
}
