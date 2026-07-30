package notifications

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
)

// emailSendHandler is the job handler key for the existing generic email job
// (internal/jobs/handlers/constants.go's HandlerEmailSend = "email.send"),
// duplicated here as a plain string literal rather than imported. Mirrors
// gitlab/service_webhook.go's own jobIngestEvent constant and for the same
// reason: internal/jobs/handlers imports domain packages (including this one,
// transitively — gitlab calls Service.Notify) to build their job handlers, so
// this package must not import jobs/handlers back, or a future handler that
// itself calls notifications.Notify would create an import cycle. MUST stay
// in sync with handlers.HandlerEmailSend.
const emailSendHandler = "email.send"

const emailJobTimeoutMS = 30000

// emailJobPayload mirrors internal/jobs/handlers/email.go's EmailPayload
// JSON shape exactly (duplicated locally for the same import-cycle reason as
// emailSendHandler above) — its "notification" Type case reads
// template_data.subject/body.
type emailJobPayload struct {
	Type         string         `json:"type"`
	To           string         `json:"to"`
	ToName       string         `json:"to_name"`
	TemplateData map[string]any `json:"template_data"`
}

// Service is the notifications domain's business logic layer — a generic,
// dependency-free package any domain can call to write an in-app
// notification, optionally also emailing it (see this package's own doc
// comment for why it has zero knowledge of any specific caller domain).
type Service struct {
	repo         *Repo
	pool         *pgxpool.Pool
	jobsRegistry *jobs.Registry
}

// NewService builds the notifications Service. jobsRegistry backs the
// AlsoEmail side-effect (enqueues the existing email.send job).
func NewService(pool *pgxpool.Pool, jobsRegistry *jobs.Registry) *Service {
	return &Service{repo: NewRepo(pool), pool: pool, jobsRegistry: jobsRegistry}
}

// Notify dedupe-inserts one notification inside the caller's own transaction
// tx — callers doing a multi-table write (e.g. gitlab's merge gate: update
// project_team_checkpoints AND notify the team) pass their own tx so both
// writes commit or roll back together. ON CONFLICT(user_id, dedupe_key) DO
// NOTHING makes this safe to call twice for the same logical event (e.g. a
// redelivered webhook) — see Repo.Insert's own doc comment. The AlsoEmail
// side-effect only fires on a genuinely fresh insert, never on a dedupe
// no-op, so a redelivery never double-emails either.
func (s *Service) Notify(ctx context.Context, tx pgx.Tx, n New) error {
	if n.Priority == "" {
		n.Priority = PriorityNormal
	}
	inserted, err := s.repo.Insert(ctx, tx, n)
	if err != nil {
		return fmt.Errorf("notifications: notify: %w", err)
	}
	if inserted && n.AlsoEmail {
		if err := s.enqueueEmail(ctx, n); err != nil {
			return fmt.Errorf("notifications: notify: enqueue email: %w", err)
		}
	}
	return nil
}

// NotifyMany calls Notify once per recipient inside the same tx, for
// broadcasting one event (e.g. a CI failure) to every team member — callers
// that need to notify a whole group don't have to loop by hand.
func (s *Service) NotifyMany(ctx context.Context, tx pgx.Tx, base New, userIDs []string) error {
	for _, userID := range userIDs {
		n := base
		n.UserID = userID
		if err := s.Notify(ctx, tx, n); err != nil {
			return err
		}
	}
	return nil
}

// enqueueEmail enqueues the existing generic email.send job. The job is
// enqueued against s.pool, not the caller's tx — a queued job row is its own
// independent unit of work (same reasoning as gitlab's enqueueCommitStats:
// enqueue right after the triggering write, not gated on the outer
// transaction's eventual commit).
func (s *Service) enqueueEmail(ctx context.Context, n New) error {
	email, name, err := s.repo.userContact(ctx, n.UserID)
	if err != nil {
		return err
	}
	body := n.Title
	if n.Body != nil && *n.Body != "" {
		body = *n.Body
	}
	timeout := emailJobTimeoutMS
	orgID := n.OrgID
	_, err = jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler:  emailSendHandler,
		Priority: jobs.PriorityNormal,
		Payload: emailJobPayload{
			Type: "notification", To: email, ToName: name,
			TemplateData: map[string]any{"subject": n.Title, "body": body},
		},
		OrgID:     &orgID,
		TimeoutMS: &timeout,
	})
	if err != nil && !errors.Is(err, jobs.ErrDuplicateKey) {
		return fmt.Errorf("enqueue email.send: %w", err)
	}
	return nil
}

// List returns a user's notifications newest-first.
func (s *Service) List(ctx context.Context, userID string, limit int) ([]Notification, error) {
	notifs, err := s.repo.List(ctx, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("notifications: list: %w", err)
	}
	return notifs, nil
}

// UnreadCount returns how many of a user's notifications are unread.
func (s *Service) UnreadCount(ctx context.Context, userID string) (int, error) {
	count, err := s.repo.UnreadCount(ctx, userID)
	if err != nil {
		return 0, fmt.Errorf("notifications: unread count: %w", err)
	}
	return count, nil
}

// MarkRead marks one of userID's own notifications read.
func (s *Service) MarkRead(ctx context.Context, userID, id string) error {
	return s.repo.MarkRead(ctx, userID, id)
}

// MarkAllRead marks every unread notification for userID read.
func (s *Service) MarkAllRead(ctx context.Context, userID string) error {
	return s.repo.MarkAllRead(ctx, userID)
}
