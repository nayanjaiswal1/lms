// Package opsalert turns job-system failures into in-app (and, for high
// severity, email) notifications for operators: dead-letter jobs, health-check
// findings and a daily digest. Frequency is controlled per handler by the
// ops_alert_rules table (see docs/ops-alerts.md).
package opsalert

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
)

const (
	// DefaultRuleHandler is the ops_alert_rules key used for any handler
	// without its own row.
	DefaultRuleHandler = "*"

	// AdminJobsLink is the existing platform-admin jobs UI route.
	AdminJobsLink = "/platform/jobs"

	TypeJobDead  = "ops.job_dead"
	TypeJobStorm = "ops.job_storm"
	TypeHealth   = "ops.health"
	TypeDigest   = "ops.digest"

	// emailSendHandler duplicates handlers.HandlerEmailSend (import cycle:
	// handlers imports this package). Dead email.send alerts never email.
	emailSendHandler = "email.send"
)

// Severity values stored in ops_alert_rules.severity.
const (
	SeverityLow    = "low"
	SeverityNormal = "normal"
	SeverityHigh   = "high"
)

// Alert is one operator notification, fanned out to recipients by Service.
type Alert struct {
	Type      string
	Title     string
	Body      string
	LinkURL   string
	DedupeKey string
	Priority  string
	AlsoEmail bool
}

type recipient struct{ UserID, OrgID string }

// Service sends operator alerts.
type Service struct {
	pool  *pgxpool.Pool
	notif *notifications.Service
}

// NewService builds the alert Service.
func NewService(pool *pgxpool.Pool, notif *notifications.Service) *Service {
	return &Service{pool: pool, notif: notif}
}

// OnJobDead is a jobs.DeadLetterHook body (register via Registry.OnAnyDead).
// It never returns an error: failures are logged so the worker is unaffected.
func (s *Service) OnJobDead(ctx context.Context, job jobs.Job) {
	if err := s.onJobDead(ctx, job); err != nil {
		slog.ErrorContext(ctx, "opsalert: dead job alert failed", "handler", job.Handler, "job_id", job.ID, "error", err)
	}
}

func (s *Service) onJobDead(ctx context.Context, job jobs.Job) error {
	rule, err := s.Rule(ctx, job.Handler)
	if err != nil {
		return err
	}
	if !rule.Enabled {
		return nil
	}

	scope := "platform"
	if job.OrgID != nil {
		scope = *job.OrgID
	}
	// Alerting on a dead email.send by email would loop when SMTP is the problem.
	alsoEmail := rule.Severity == SeverityHigh && job.Handler != emailSendHandler
	priority := notifications.PriorityNormal
	switch rule.Severity {
	case SeverityHigh:
		priority = notifications.PriorityHigh
	case SeverityLow:
		priority = notifications.PriorityLow
	}

	var dead int
	if err := s.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM jobs
		 WHERE handler = $1 AND status = 'dead' AND updated_at > NOW() - make_interval(mins => $2)`,
		job.Handler, rule.StormWindowMinutes,
	).Scan(&dead); err != nil {
		return fmt.Errorf("count dead jobs: %w", err)
	}

	alert := Alert{LinkURL: AdminJobsLink, Priority: priority, AlsoEmail: alsoEmail, Body: lastErrorBody(job)}
	now := time.Now().Unix()
	if dead > rule.StormThreshold {
		alert.Type = TypeJobStorm
		alert.Title = fmt.Sprintf("%d dead %s jobs in %d min — likely systemic outage", dead, job.Handler, rule.StormWindowMinutes)
		alert.DedupeKey = fmt.Sprintf("deadstorm:%s:%s:%d", job.Handler, scope, now/int64(rule.StormWindowMinutes*60))
		alert.Priority = notifications.PriorityHigh
	} else {
		alert.Type = TypeJobDead
		alert.Title = fmt.Sprintf("Job %s died after %d/%d attempts", job.Handler, job.RetryCount, job.MaxRetries)
		alert.DedupeKey = fmt.Sprintf("deadjob:%s:%s:%d", job.Handler, scope, now/int64(rule.DedupeWindowMinutes*60))
	}

	recips, err := s.recipients(ctx, job.OrgID)
	if err != nil {
		return err
	}
	return s.send(ctx, recips, alert)
}

func lastErrorBody(job jobs.Job) string {
	if job.LastError == nil {
		return "No error recorded."
	}
	return *job.LastError
}

// NotifyPlatformAdmins sends alert to every active super admin.
func (s *Service) NotifyPlatformAdmins(ctx context.Context, alert Alert) error {
	recips, err := s.recipients(ctx, nil)
	if err != nil {
		return err
	}
	return s.send(ctx, recips, alert)
}

// NotifyOrgAdmins sends alert to the owners/admins of orgID.
func (s *Service) NotifyOrgAdmins(ctx context.Context, orgID string, alert Alert) error {
	recips, err := s.recipients(ctx, &orgID)
	if err != nil {
		return err
	}
	return s.send(ctx, recips, alert)
}

// recipients resolves who to alert: an org's active owners/admins, or (orgID
// nil) all super admins, each attributed to their oldest active org because
// notifications.org_id is NOT NULL. Super admins without any org are skipped
// with a warning.
func (s *Service) recipients(ctx context.Context, orgID *string) ([]recipient, error) {
	var (
		rows pgx.Rows
		err  error
	)
	if orgID != nil {
		rows, err = s.pool.Query(ctx,
			`SELECT user_id, org_id FROM org_members
			 WHERE org_id = $1 AND status = 'active' AND role IN ('owner', 'admin')`, *orgID)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT u.id, (SELECT m.org_id FROM org_members m
			               WHERE m.user_id = u.id AND m.status = 'active'
			               ORDER BY m.joined_at LIMIT 1)
			 FROM users u WHERE u.platform_role = 'super_admin'`)
	}
	if err != nil {
		return nil, fmt.Errorf("query recipients: %w", err)
	}
	defer rows.Close()

	var out []recipient
	for rows.Next() {
		var userID string
		var org *string
		if err := rows.Scan(&userID, &org); err != nil {
			return nil, fmt.Errorf("scan recipient: %w", err)
		}
		if org == nil {
			slog.WarnContext(ctx, "opsalert: super admin has no active org membership; skipping", "user_id", userID)
			continue
		}
		out = append(out, recipient{UserID: userID, OrgID: *org})
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate recipients: %w", err)
	}
	return out, nil
}

func (s *Service) send(ctx context.Context, recips []recipient, a Alert) error {
	if len(recips) == 0 {
		return nil
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	body, link := a.Body, a.LinkURL
	for _, r := range recips {
		n := notifications.New{
			OrgID: r.OrgID, UserID: r.UserID, Type: a.Type, Title: a.Title,
			Body: &body, LinkURL: &link, Priority: a.Priority,
			DedupeKey: a.DedupeKey, AlsoEmail: a.AlsoEmail,
		}
		if err := s.notif.Notify(ctx, tx, n); err != nil {
			return fmt.Errorf("notify %s: %w", r.UserID, err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit: %w", err)
	}
	return nil
}
