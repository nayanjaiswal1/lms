package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/mailer"
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

// NewEmailDeadHook returns a DeadLetterHook for HandlerEmailSend. There is no
// single owning resource to flip (unlike eval.subjective's assessment
// attempt) — email.send backs auth_verify/password_reset/eval_complete/
// notification alike — so this only turns a silent permanent failure into a
// structured, alertable log line. Previously a dead email.send job left
// nothing but last_error on the jobs row; nobody was told an email a user is
// waiting on (e.g. a password reset) will never arrive.
func NewEmailDeadHook() jobs.DeadLetterHook {
	return func(_ context.Context, job jobs.Job) {
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
	}
}

// EmailPayload is the JSON payload stored in jobs.payload for email.send jobs.
type EmailPayload struct {
	Type         string         `json:"type"` // auth_verify|password_reset|eval_complete|notification
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
type EmailHandler struct {
	cfg    *config.Config
	sender mailer.Sender
}

// NewEmailHandler constructs an EmailHandler. sender is the delivery
// transport (mailer.SMTPSender today — see internal/mailer's package doc for
// why swapping it later is a one-line change here, not a new abstraction).
func NewEmailHandler(cfg *config.Config, sender mailer.Sender) *EmailHandler {
	return &EmailHandler{cfg: cfg, sender: sender}
}

// Handle dispatches the email job to the appropriate send function based on Type.
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

	switch p.Type {
	case "auth_verify":
		token, _ := p.TemplateData["token"].(string)
		if token == "" {
			return fmt.Errorf("handlers.email: auth_verify requires template_data.token")
		}
		if err := auth.SendVerification(h.cfg, p.To, token); err != nil {
			return classifyErr(err, fmt.Errorf("handlers.email: send verification (to=%s): %w", p.To, err))
		}

	case "password_reset":
		token, _ := p.TemplateData["token"].(string)
		if token == "" {
			return fmt.Errorf("handlers.email: password_reset requires template_data.token")
		}
		if err := auth.SendPasswordReset(h.cfg, p.To, token); err != nil {
			return classifyErr(err, fmt.Errorf("handlers.email: send password reset (to=%s): %w", p.To, err))
		}

	case "eval_complete":
		title, _ := p.TemplateData["assessment_title"].(string)
		attemptID, _ := p.TemplateData["attempt_id"].(string)
		if err := h.sendEvalComplete(ctx, p.To, p.ToName, title, attemptID); err != nil {
			return classifyErr(err, fmt.Errorf("handlers.email: send eval complete (to=%s): %w", p.To, err))
		}

	case "notification":
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

	default:
		return fmt.Errorf("handlers.email: unknown email type: %s", p.Type)
	}

	return nil
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
