package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/mail"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/mailer"
	"github.com/mindforge/backend/internal/orgs"
	"github.com/mindforge/backend/internal/ratelimit"
	"github.com/redis/go-redis/v9"
)

// Email types handled by EmailHandler.
const (
	emailTypeAuthVerify            = "auth_verify"
	emailTypePasswordReset         = "password_reset"
	emailTypeEvalComplete          = "eval_complete"
	emailTypeNotification          = "notification"
	emailTypeOrgInvite             = "org_invite"
	emailTypeDuplicateRegistration = "duplicate_registration"
	emailTypePasskeyCloneAlert     = "passkey_clone_alert"
)

// Org invite email delivery states (org_invites.email_status).
const (
	inviteEmailPending = "pending"
	inviteEmailSent    = "sent"
	inviteEmailFailed  = "failed"
)

// Per-org send-quota windows and the ratelimit key namespace.
const (
	quotaMinuteWindow = time.Minute
	quotaDayWindow    = 24 * time.Hour
	quotaKeyPrefix    = "email:org:"
	// minDeferral keeps a RetryAfter from rounding down to 0 seconds.
	minDeferral = time.Second
	// maxEmailErrorLen bounds org_invites.email_error.
	maxEmailErrorLen = 500
)

// classifyErr wraps formatted (the error to actually return from Handle) as
// jobs.Permanent when raw — the underlying send error before formatting —
// was a 5xx SMTP rejection (see mailer.IsPermanent). A permanent send
// failure (bad recipient, sender rejected) will produce the identical
// outcome on every retry, so the job goes straight to dead instead of
// spending its retry budget re-attempting it.
func classifyErr(raw, formatted error) error {
	if mailer.IsPermanent(raw) {
		return jobs.Permanent(formatted)
	}
	return formatted
}

// truncateErr shortens s to at most n bytes for storage in a status column.
func truncateErr(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// NewEmailDeadHook returns a DeadLetterHook for HandlerEmailSend. email.send
// backs auth_verify/password_reset/eval_complete/notification/org_invite alike,
// so beyond a structured, alertable log line (a dead password reset otherwise
// leaves only last_error on the jobs row) the only resource it flips is the
// invite behind a dead org_invite email, so the admin sees "Failed — resend".
func NewEmailDeadHook(pool *pgxpool.Pool) jobs.DeadLetterHook {
	return func(ctx context.Context, job jobs.Job) {
		var p EmailPayload
		if err := json.Unmarshal(job.Payload, &p); err != nil {
			slog.Error("email.send dead hook: unmarshal payload", "job_id", job.ID, "error", err)
			return
		}
		lastErr := ""
		if job.LastError != nil {
			lastErr = *job.LastError
		}
		slog.Error("email.send permanently failed — exhausted retries or hit a permanent SMTP rejection",
			"job_id", job.ID, "email_type", p.Type, "to", p.To, "org_id", job.OrgID, "last_error", lastErr)
		if p.Type == emailTypeOrgInvite {
			id, _ := p.TemplateData["invite_id"].(string)
			setInviteEmailStatus(ctx, pool, id, inviteEmailFailed, truncateErr(lastErr, maxEmailErrorLen))
		}
	}
}

// EmailPayload is the JSON payload stored in jobs.payload for email.send jobs.
type EmailPayload struct {
	Type         string         `json:"type"` // one of the emailType* constants
	To           string         `json:"to"`
	ToName       string         `json:"to_name"`
	TemplateData map[string]any `json:"template_data"`
	// MessageID/InReplyTo thread a "notification" email into an existing
	// conversation (e.g. a ticket) — set by the enqueuing package (see
	// internal/tickets), consumed only by the "notification" case below.
	// InReplyTo doubles as References since MindForge threads are flat
	// (every message replies to the same root, never to another reply).
	MessageID string `json:"message_id,omitempty"`
	InReplyTo string `json:"in_reply_to,omitempty"`
}

// EmailHandler implements jobs.Handler for HandlerEmailSend jobs.
//
// Around every send it applies, in order: recipient-shape validation, the
// shared circuit breaker, and the per-org quota. A provider throttle reply and
// the two guards return jobs.RetryAfter so the job waits without spending its
// retry budget.
type EmailHandler struct {
	cfg     *config.Config
	sender  mailer.Sender
	pool    *pgxpool.Pool
	limiter *ratelimit.Limiter
	breaker *mailer.Breaker
	orgRepo *orgs.Repo
}

// NewEmailHandler constructs an EmailHandler. sender is the delivery
// transport (mailer.SMTPSender today — see internal/mailer's package doc for
// why swapping it later is a one-line change here, not a new abstraction).
// rdb backs the circuit breaker and the per-org quota counters; both degrade
// to per-process state if Redis is unreachable.
func NewEmailHandler(cfg *config.Config, sender mailer.Sender, pool *pgxpool.Pool, rdb *redis.Client) *EmailHandler {
	return &EmailHandler{
		cfg:     cfg,
		sender:  sender,
		pool:    pool,
		limiter: ratelimit.New(rdb),
		breaker: mailer.NewBreaker(rdb, cfg.EmailBreakerThreshold, cfg.EmailBreakerCooldown),
		orgRepo: orgs.NewRepo(pool, nil),
	}
}

// Handle validates the job, applies the breaker and quota guards, then sends.
func (h *EmailHandler) Handle(ctx context.Context, job jobs.Job) error {
	var p EmailPayload
	if err := json.Unmarshal(job.Payload, &p); err != nil {
		return fmt.Errorf("handlers.email: unmarshal payload: %w", err)
	}
	if p.Type == "" {
		return fmt.Errorf("handlers.email: payload missing type")
	}
	if p.To == "" {
		return fmt.Errorf("handlers.email: payload missing to")
	}
	// A malformed address would only earn a 5xx at RCPT TO after a full SMTP
	// round-trip; it can never succeed, so fail it dead before dialing.
	if addr, err := mail.ParseAddress(p.To); err != nil || addr.Address != p.To {
		bad := fmt.Errorf("handlers.email: malformed recipient address %q", p.To)
		h.markInviteFailed(ctx, p, bad)
		return jobs.Permanent(bad)
	}

	if remaining := h.breaker.Remaining(ctx); remaining > 0 {
		return jobs.RetryAfter(fmt.Errorf("handlers.email: send circuit open, pausing sends for %s", remaining.Round(time.Second)), remaining)
	}
	if job.OrgID != nil {
		if wait, window := h.checkOrgQuota(ctx, *job.OrgID); wait > 0 {
			return jobs.RetryAfter(fmt.Errorf("handlers.email: org %s %s email quota exceeded", *job.OrgID, window), wait)
		}
	}

	err := h.deliver(ctx, p)
	h.breaker.Record(ctx, err)
	if mailer.IsThrottle(err) {
		return jobs.RetryAfter(err, h.cfg.EmailThrottleBackoff)
	}
	if permErr := new(jobs.PermanentError); errors.As(err, &permErr) {
		h.markInviteFailed(ctx, p, err)
	}
	return err
}

// checkOrgQuota consumes one send from the org's per-minute and per-day
// windows. When either is exhausted it returns how long until a slot frees and
// which window blocked. Limits are EMAIL_ORG_MAX_PER_MINUTE/DAY unless
// org_settings.jobs overrides them.
func (h *EmailHandler) checkOrgQuota(ctx context.Context, orgID string) (time.Duration, string) {
	perMin, perDay := h.cfg.EmailOrgMaxPerMinute, h.cfg.EmailOrgMaxPerDay
	if s, err := h.orgRepo.GetJobsSettings(ctx, orgID); err != nil {
		slog.WarnContext(ctx, "handlers.email: read org quota override, using defaults", "org_id", orgID, "error", err)
	} else {
		if s.EmailMaxPerMinute != nil {
			perMin = *s.EmailMaxPerMinute
		}
		if s.EmailMaxPerDay != nil {
			perDay = *s.EmailMaxPerDay
		}
	}
	// Day first: a day-blocked send must not also burn a minute slot.
	if ok, wait := h.limiter.Allow(ctx, quotaKeyPrefix+"day:"+orgID, perDay, quotaDayWindow); !ok {
		return max(wait, minDeferral), "daily"
	}
	if ok, wait := h.limiter.Allow(ctx, quotaKeyPrefix+"min:"+orgID, perMin, quotaMinuteWindow); !ok {
		return max(wait, minDeferral), "per-minute"
	}
	return 0, ""
}

// deliver sends one validated email; its error is the raw send outcome
// (wrapped jobs.Permanent for 5xx rejections).
func (h *EmailHandler) deliver(ctx context.Context, p EmailPayload) error {
	switch p.Type {
	case emailTypeAuthVerify:
		token, _ := p.TemplateData["token"].(string)
		if token == "" {
			return fmt.Errorf("handlers.email: auth_verify requires template_data.token")
		}
		if err := auth.SendVerification(h.cfg, p.To, token); err != nil {
			return classifyErr(err, fmt.Errorf("handlers.email: send verification (to=%s): %w", p.To, err))
		}

	case emailTypePasswordReset:
		token, _ := p.TemplateData["token"].(string)
		if token == "" {
			return fmt.Errorf("handlers.email: password_reset requires template_data.token")
		}
		if err := auth.SendPasswordReset(h.cfg, p.To, token); err != nil {
			return classifyErr(err, fmt.Errorf("handlers.email: send password reset (to=%s): %w", p.To, err))
		}

	case emailTypeEvalComplete:
		title, _ := p.TemplateData["assessment_title"].(string)
		attemptID, _ := p.TemplateData["attempt_id"].(string)
		if err := h.sendEvalComplete(ctx, p.To, p.ToName, title, attemptID); err != nil {
			return classifyErr(err, fmt.Errorf("handlers.email: send eval complete (to=%s): %w", p.To, err))
		}

	case emailTypeNotification:
		subject, _ := p.TemplateData["subject"].(string)
		body, _ := p.TemplateData["body"].(string)
		if subject == "" || body == "" {
			slog.WarnContext(ctx, "handlers.email: notification missing subject or body, skipping",
				"to", p.To)
			return nil
		}
		var headers map[string]string
		if p.MessageID != "" || p.InReplyTo != "" {
			headers = map[string]string{}
			if p.MessageID != "" {
				headers["Message-Id"] = p.MessageID
			}
			if p.InReplyTo != "" {
				headers["In-Reply-To"] = p.InReplyTo
				headers["References"] = p.InReplyTo
			}
		}
		if err := h.sender.Send(ctx, p.To, subject, body, headers); err != nil {
			return classifyErr(err, fmt.Errorf("handlers.email: send notification (to=%s): %w", p.To, err))
		}

	case emailTypeOrgInvite:
		token, _ := p.TemplateData["token"].(string)
		role, _ := p.TemplateData["role"].(string)
		if token == "" || role == "" {
			return fmt.Errorf("handlers.email: org_invite requires template_data.token and role")
		}
		if h.cfg.ShouldSendRealEmail(p.To) {
			subject, body := inviteEmailContent(h.cfg, role, token)
			if err := h.sender.Send(ctx, p.To, subject, body, nil); err != nil {
				return classifyErr(err, fmt.Errorf("handlers.email: send org invite (to=%s): %w", p.To, err))
			}
		} else {
			slog.Info("DEV EMAIL: org invite suppressed (dev)", "to", p.To)
		}
		id, _ := p.TemplateData["invite_id"].(string)
		setInviteEmailStatus(ctx, h.pool, id, inviteEmailSent, "")

	case emailTypeDuplicateRegistration:
		return h.sendAccountNotice(ctx, p, "Duplicate registration attempt", auth.DuplicateRegistrationMessage)

	case emailTypePasskeyCloneAlert:
		return h.sendAccountNotice(ctx, p, "Passkey clone warning", auth.PasskeyCloneAlertMessage)

	default:
		return fmt.Errorf("handlers.email: unknown email type: %s", p.Type)
	}

	return nil
}

// sendAccountNotice sends a fixed-text account-security email built by msg.
// Dev gating matches every other email path (config.Config.ShouldSendRealEmail).
func (h *EmailHandler) sendAccountNotice(ctx context.Context, p EmailPayload, devLabel string, msg func(*config.Config) (string, string)) error {
	if !h.cfg.ShouldSendRealEmail(p.To) {
		slog.Info("DEV EMAIL: "+devLabel, "to", p.To)
		return nil
	}
	subject, body := msg(h.cfg)
	if err := h.sender.Send(ctx, p.To, subject, body, nil); err != nil {
		return classifyErr(err, fmt.Errorf("handlers.email: send %s (to=%s): %w", p.Type, p.To, err))
	}
	return nil
}

// inviteEmailContent is the org-invite email shared by the queued org_invite
// type and invite.bulk's batched sender.
func inviteEmailContent(cfg *config.Config, role, token string) (subject, body string) {
	subject = "You've been invited to join an organization on MindForge"
	link := cfg.FrontendURL + "/orgs/join?token=" + token
	body = "You have been invited to join an organization on MindForge as " + role + ".\n\n" +
		"Click the link below to accept your invitation:\n\n" + link + "\n\n" +
		"This invitation expires in 7 days. If you did not expect this email, no action is needed."
	return subject, body
}

// setInviteEmailStatus records an invite email's delivery result on its
// org_invites row (email_status/email_error).
func setInviteEmailStatus(ctx context.Context, pool *pgxpool.Pool, inviteID, status, errMsg string) {
	if pool == nil || inviteID == "" {
		return
	}
	var e *string
	if errMsg != "" {
		e = &errMsg
	}
	if _, err := pool.Exec(ctx,
		`UPDATE org_invites SET email_status = $2, email_error = $3, updated_at = now() WHERE id = $1`,
		inviteID, status, e,
	); err != nil {
		slog.ErrorContext(ctx, "handlers.email: update invite email status", "invite_id", inviteID, "status", status, "error", err)
	}
}

// markInviteFailed flags the invite behind a permanently failed org_invite
// email so the admin sees "Failed — resend". No-op for every other type.
func (h *EmailHandler) markInviteFailed(ctx context.Context, p EmailPayload, cause error) {
	if p.Type != emailTypeOrgInvite {
		return
	}
	id, _ := p.TemplateData["invite_id"].(string)
	setInviteEmailStatus(ctx, h.pool, id, inviteEmailFailed, truncateErr(cause.Error(), maxEmailErrorLen))
}

// sendEvalComplete sends the assessment-evaluation-complete notification.
// In local dev, logs to stdout instead of using SMTP unless `to` is in
// config.Config.DevEmailAllowlist (see Config.ShouldSendRealEmail).
func (h *EmailHandler) sendEvalComplete(ctx context.Context, to, toName, assessmentTitle, attemptID string) error {
	if !h.cfg.ShouldSendRealEmail(to) {
		slog.Info("DEV EMAIL: Eval complete",
			"to", to, "to_name", toName,
			"assessment_title", assessmentTitle, "attempt_id", attemptID)
		return nil
	}
	subject := "Your assessment has been evaluated — " + assessmentTitle
	link := h.cfg.FrontendURL + "/assessments/attempts/" + attemptID
	greeting := "Hi"
	if toName != "" {
		greeting = "Hi " + toName
	}
	body := greeting + ",\n\n" +
		"Your submission for \"" + assessmentTitle + "\" has been evaluated.\n\n" +
		"View your results here:\n" + link + "\n\n" +
		"The MindForge Team"
	return h.sender.Send(ctx, to, subject, body, nil)
}
