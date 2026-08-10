package auth

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/mailer"
)

// SendVerification sends the email-verification link to the given address.
// In local dev, logs to stdout instead of using SMTP unless `to` is in
// config.Config.DevEmailAllowlist (see Config.ShouldSendRealEmail).
func SendVerification(cfg *config.Config, to, token string) error {
	if !cfg.ShouldSendRealEmail(to) {
		slog.Info("DEV EMAIL: Verification token", "to", to, "token", token)
		return nil
	}
	subject := "Verify your MindForge account"
	link := cfg.FrontendURL + "/verify-email?token=" + token
	body := "Click the link below to verify your email address:\n\n" + link +
		"\n\nThis link expires in 24 hours."
	return sendSMTP(cfg, to, subject, body)
}

// SendPasswordReset sends the password-reset link to the given address.
// In local dev, logs to stdout instead of using SMTP unless `to` is in
// config.Config.DevEmailAllowlist (see Config.ShouldSendRealEmail).
func SendPasswordReset(cfg *config.Config, to, token string) error {
	if !cfg.ShouldSendRealEmail(to) {
		slog.Info("DEV EMAIL: Password reset token", "to", to, "token", token)
		return nil
	}
	subject := "Reset your MindForge password"
	link := cfg.FrontendURL + "/reset-password?token=" + token
	body := "Click the link below to reset your password:\n\n" + link +
		"\n\nThis link expires in 30 minutes. If you did not request a reset, ignore this email."
	return sendSMTP(cfg, to, subject, body)
}

// SendDuplicateRegistration notifies an existing account holder that someone
// attempted to register with their email. It is sent instead of revealing the
// account's existence in the registration API response (anti-enumeration).
// In local dev, logs to stdout instead of using SMTP unless `to` is in
// config.Config.DevEmailAllowlist (see Config.ShouldSendRealEmail).
func SendDuplicateRegistration(cfg *config.Config, to string) error {
	if !cfg.ShouldSendRealEmail(to) {
		slog.Info("DEV EMAIL: Duplicate registration attempt", "to", to)
		return nil
	}
	subject := "You already have a MindForge account"
	body := "Someone just tried to create a MindForge account with this email address.\n\n" +
		"If this was you, you already have an account — simply sign in, or reset your " +
		"password at " + cfg.FrontendURL + "/forgot-password if you've forgotten it.\n\n" +
		"If this wasn't you, no action is needed; no new account was created."
	return sendSMTP(cfg, to, subject, body)
}

// SendPasskeyCloneAlert notifies the user that a passkey sign-in produced a
// signature-counter regression — a signal (not proof) that the credential's
// private key may exist in more than one place. The login is allowed to
// proceed (see webauthn.go); this is advisory, mirroring the existing
// impossible-travel posture. In development it logs to stdout instead of
// using SMTP.
func SendPasskeyCloneAlert(cfg *config.Config, to string) error {
	if !cfg.ShouldSendRealEmail(to) {
		slog.Info("DEV EMAIL: Passkey clone warning", "to", to)
		return nil
	}
	subject := "Unusual passkey activity on your MindForge account"
	body := "We noticed unusual activity from a passkey on your account, which can happen if " +
		"the passkey was copied or restored from a backup.\n\n" +
		"If this was you, no action is needed. If you don't recognize this, review your " +
		"passkeys at " + cfg.FrontendURL + "/settings/security and remove any you don't recognize."
	return sendSMTP(cfg, to, subject, body)
}

// ─── internal ─────────────────────────────────────────────────────────────────

// sendSMTP delegates the actual delivery to mailer.SendRaw, which bounds the
// SMTP transaction to a fixed deadline and classifies 5xx relay rejections as
// permanent (see mailer.IsPermanent) — this package's callers don't carry a
// context of their own, so a fixed timeout is applied here rather than
// leaving the call unbounded like the old direct net/smtp.SendMail did.
func sendSMTP(cfg *config.Config, to, subject, body string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	msg := buildMessage(cfg.EmailFromHeader(), to, subject, body)

	if err := mailer.SendRaw(ctx, cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPUser, cfg.SMTPPass, cfg.EmailFrom, to, []byte(msg)); err != nil {
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
