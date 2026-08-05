package mailer

import (
	"context"
	"fmt"
	"net/smtp"
	"strings"
)

// SMTPSender delivers email over plain SMTP via net/smtp — MindForge's only
// Sender today (see mailer.go's package doc). Moved verbatim out of
// internal/jobs/handlers/email.go's former sendRaw/buildEmailMessage.
type SMTPSender struct {
	host, port, user, pass, from string
}

// NewSMTPSender constructs an SMTPSender. user may be empty (no SMTP auth —
// e.g. a local dev relay like Mailpit).
func NewSMTPSender(host, port, user, pass, from string) *SMTPSender {
	return &SMTPSender{host: host, port: port, user: user, pass: pass, from: from}
}

func (s *SMTPSender) Send(_ context.Context, to, subject, body string, headers map[string]string) error {
	addr := s.host + ":" + s.port

	var auth smtp.Auth
	if s.user != "" {
		auth = smtp.PlainAuth("", s.user, s.pass, s.host)
	}

	msg := buildMessage(s.from, to, subject, body, headers)
	if err := smtp.SendMail(addr, auth, s.from, []string{to}, []byte(msg)); err != nil {
		return fmt.Errorf("mailer: smtp send to %s: %w", to, err)
	}
	return nil
}

// crlf strips CR/LF from a value bound for a raw RFC 5322 header line — every
// header written below runs through it, since From/To/Subject can carry
// caller-supplied text (e.g. a user's ticket subject) and an unescaped
// newline would let it inject arbitrary extra headers into the message.
func crlf(v string) string {
	return strings.NewReplacer("\r", "", "\n", "").Replace(v)
}

// buildMessage constructs a minimal RFC 5322 plain-text message. headers is
// written after the standard From/To/Subject lines — used for Message-Id/
// In-Reply-To/References so a reply threads into an existing client-side
// conversation.
func buildMessage(from, to, subject, body string, headers map[string]string) string {
	var sb strings.Builder
	sb.WriteString("From: " + crlf(from) + "\r\n")
	sb.WriteString("To: " + crlf(to) + "\r\n")
	sb.WriteString("Subject: " + crlf(subject) + "\r\n")
	for k, v := range headers {
		sb.WriteString(crlf(k) + ": " + crlf(v) + "\r\n")
	}
	sb.WriteString("MIME-Version: 1.0\r\n")
	sb.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
	sb.WriteString("\r\n")
	sb.WriteString(body)
	return sb.String()
}
