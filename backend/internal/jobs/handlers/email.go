package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/smtp"
	"strings"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
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
	cfg *config.Config
}

// NewEmailHandler constructs an EmailHandler.
func NewEmailHandler(cfg *config.Config) *EmailHandler {
	return &EmailHandler{cfg: cfg}
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
		if err := h.sendEvalComplete(p.To, p.ToName, title, attemptID); err != nil {
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
		if err := h.sendRaw(p.To, subject, body); err != nil {
			return fmt.Errorf("handlers.email: send notification (to=%s): %w", p.To, err)
		}

	default:
		return fmt.Errorf("handlers.email: unknown email type: %s", p.Type)
	}

	return nil
}

// sendEvalComplete sends the assessment-evaluation-complete notification.
// In development it logs to stdout instead of using SMTP.
func (h *EmailHandler) sendEvalComplete(to, toName, assessmentTitle, attemptID string) error {
	if !h.cfg.IsProd() {
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
	return h.sendRaw(to, subject, body)
}

// sendRaw sends a plain-text email via the configured SMTP server.
func (h *EmailHandler) sendRaw(to, subject, body string) error {
	addr := h.cfg.SMTPHost + ":" + h.cfg.SMTPPort

	var smtpAuth smtp.Auth
	if h.cfg.SMTPUser != "" {
		smtpAuth = smtp.PlainAuth("", h.cfg.SMTPUser, h.cfg.SMTPPass, h.cfg.SMTPHost)
	}

	msg := buildEmailMessage(h.cfg.EmailFrom, to, subject, body)
	if err := smtp.SendMail(addr, smtpAuth, h.cfg.EmailFrom, []string{to}, []byte(msg)); err != nil {
		return fmt.Errorf("handlers.email: smtp send to %s: %w", to, err)
	}
	return nil
}

// buildEmailMessage constructs a minimal RFC 5322 plain-text message.
func buildEmailMessage(from, to, subject, body string) string {
	var sb strings.Builder
	sb.WriteString("From: " + from + "\r\n")
	sb.WriteString("To: " + to + "\r\n")
	sb.WriteString("Subject: " + subject + "\r\n")
	sb.WriteString("MIME-Version: 1.0\r\n")
	sb.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
	sb.WriteString("\r\n")
	sb.WriteString(body)
	return sb.String()
}
