package auth

import (
	"fmt"
	"log/slog"
	"net/smtp"
	"strings"

	"github.com/mindforge/backend/internal/config"
)

// SendVerification sends the email-verification link to the given address.
// In development it logs to stdout instead of using SMTP.
func SendVerification(cfg *config.Config, to, token string) error {
	if !cfg.IsProd() {
		slog.Info("DEV EMAIL: Verification token", "to", to, "token", token)
		return nil
	}
	subject := "Verify your MindForge account"
	link := cfg.FrontendURL + "/auth/verify-email?token=" + token
	body := "Click the link below to verify your email address:\n\n" + link +
		"\n\nThis link expires in 24 hours."
	return sendSMTP(cfg, to, subject, body)
}

// SendPasswordReset sends the password-reset link to the given address.
// In development it logs to stdout instead of using SMTP.
func SendPasswordReset(cfg *config.Config, to, token string) error {
	if !cfg.IsProd() {
		slog.Info("DEV EMAIL: Password reset token", "to", to, "token", token)
		return nil
	}
	subject := "Reset your MindForge password"
	link := cfg.FrontendURL + "/auth/reset-password?token=" + token
	body := "Click the link below to reset your password:\n\n" + link +
		"\n\nThis link expires in 30 minutes. If you did not request a reset, ignore this email."
	return sendSMTP(cfg, to, subject, body)
}

// SendDuplicateRegistration notifies an existing account holder that someone
// attempted to register with their email. It is sent instead of revealing the
// account's existence in the registration API response (anti-enumeration).
// In development it logs to stdout instead of using SMTP.
func SendDuplicateRegistration(cfg *config.Config, to string) error {
	if !cfg.IsProd() {
		slog.Info("DEV EMAIL: Duplicate registration attempt", "to", to)
		return nil
	}
	subject := "You already have a MindForge account"
	body := "Someone just tried to create a MindForge account with this email address.\n\n" +
		"If this was you, you already have an account — simply sign in, or reset your " +
		"password at " + cfg.FrontendURL + "/auth/forgot-password if you've forgotten it.\n\n" +
		"If this wasn't you, no action is needed; no new account was created."
	return sendSMTP(cfg, to, subject, body)
}

// ─── internal ─────────────────────────────────────────────────────────────────

func sendSMTP(cfg *config.Config, to, subject, body string) error {
	addr := cfg.SMTPHost + ":" + cfg.SMTPPort

	var auth smtp.Auth
	if cfg.SMTPUser != "" {
		auth = smtp.PlainAuth("", cfg.SMTPUser, cfg.SMTPPass, cfg.SMTPHost)
	}

	msg := buildMessage(cfg.EmailFrom, to, subject, body)

	if err := smtp.SendMail(addr, auth, cfg.EmailFrom, []string{to}, []byte(msg)); err != nil {
		return fmt.Errorf("auth: send email to %s: %w", to, err)
	}
	return nil
}

func buildMessage(from, to, subject, body string) string {
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
