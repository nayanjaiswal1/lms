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

// EmailPayload is the JSON payload stored in jobs.payload for email.send jobs.
type EmailPayload struct {
	Type         string         `json:"type"` // auth_verify|password_reset|eval_complete|notification
	To           string         `json:"to"`
	ToName       string         `json:"to_name"`
	TemplateData map[string]any `json:"template_data"`
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
			return fmt.Errorf("handlers.email: send verification (to=%s): %w", p.To, err)
		}

	case "password_reset":
		token, _ := p.TemplateData["token"].(string)
		if token == "" {
			return fmt.Errorf("handlers.email: password_reset requires template_data.token")
		}
		if err := auth.SendPasswordReset(h.cfg, p.To, token); err != nil {
			return fmt.Errorf("handlers.email: send password reset (to=%s): %w", p.To, err)
		}

	case "eval_complete":
		title, _ := p.TemplateData["assessment_title"].(string)
		attemptID, _ := p.TemplateData["attempt_id"].(string)
		if err := h.sendEvalComplete(ctx, p.To, p.ToName, title, attemptID); err != nil {
			return fmt.Errorf("handlers.email: send eval complete (to=%s): %w", p.To, err)
		}

	case "notification":
		subject, _ := p.TemplateData["subject"].(string)
		body, _ := p.TemplateData["body"].(string)
		if subject == "" || body == "" {
			slog.WarnContext(ctx, "handlers.email: notification missing subject or body, skipping",
				"to", p.To)
			return nil
		}
		if err := h.sender.Send(ctx, p.To, subject, body); err != nil {
			return fmt.Errorf("handlers.email: send notification (to=%s): %w", p.To, err)
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
	return h.sender.Send(ctx, to, subject, body)
}
