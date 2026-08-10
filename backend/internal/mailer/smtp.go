package mailer

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/smtp"
	"net/textproto"
	"strings"
	"time"
)

// defaultTimeout bounds an SMTP delivery attempt (dial + handshake + data)
// when the caller's context carries no deadline of its own. Without this,
// neither net.Dial nor net/smtp enforce any timeout, so a down or
// black-holed relay blocks the calling goroutine — a worker slot — for
// however long the OS takes to give up on the TCP handshake, which is not a
// value this service controls.
const defaultTimeout = 20 * time.Second

// SMTPSender delivers email over plain SMTP — MindForge's only Sender today
// (see mailer.go's package doc).
type SMTPSender struct {
	host, port, user, pass, from string
}

// NewSMTPSender constructs an SMTPSender. user may be empty (no SMTP auth —
// e.g. a local dev relay like Mailpit).
func NewSMTPSender(host, port, user, pass, from string) *SMTPSender {
	return &SMTPSender{host: host, port: port, user: user, pass: pass, from: from}
}

func (s *SMTPSender) Send(ctx context.Context, to, subject, body string, headers map[string]string) error {
	msg := buildMessage(s.from, to, subject, body, headers)
	if err := SendRaw(ctx, s.host, s.port, s.user, s.pass, s.from, to, []byte(msg)); err != nil {
		return fmt.Errorf("mailer: smtp send to %s: %w", to, err)
	}
	return nil
}

// SendRaw delivers a single pre-built RFC 5322 message over SMTP, bounded by
// ctx's deadline (or defaultTimeout if ctx carries none). Exported so callers
// that build their own message (e.g. internal/auth, whose transactional
// emails use a display-name-annotated From header that doesn't fit
// SMTPSender's envelope-from-is-header-from shape) get the same
// timeout-bounded transaction and permanent/transient error classification
// as SMTPSender, instead of duplicating raw net/smtp handling.
//
// Errors rejected by the relay with a 5xx SMTP reply (bad recipient, sender
// refused, malformed message) are wrapped as a PermanentError — see
// IsPermanent — so callers going through the job queue can skip straight to
// dead instead of retrying an outcome that cannot change.
func SendRaw(ctx context.Context, host, port, user, pass, envelopeFrom, to string, message []byte) error {
	if _, ok := ctx.Deadline(); !ok {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, defaultTimeout)
		defer cancel()
	}

	addr := host + ":" + port
	var d net.Dialer
	conn, err := d.DialContext(ctx, "tcp", addr)
	if err != nil {
		return fmt.Errorf("dial %s: %w", addr, err)
	}
	if deadline, ok := ctx.Deadline(); ok {
		// smtp.Client has no context awareness of its own; bounding the raw
		// connection is what actually stops a stalled handshake or a slow
		// DATA write from hanging past ctx's deadline.
		_ = conn.SetDeadline(deadline)
	}

	client, err := smtp.NewClient(conn, host)
	if err != nil {
		conn.Close()
		return classify(fmt.Errorf("smtp handshake with %s: %w", addr, err))
	}
	defer client.Close()

	if user != "" {
		if ok, _ := client.Extension("AUTH"); ok {
			if err := client.Auth(smtp.PlainAuth("", user, pass, host)); err != nil {
				return classify(fmt.Errorf("smtp auth with %s: %w", addr, err))
			}
		}
	}

	if err := client.Mail(envelopeFrom); err != nil {
		return classify(fmt.Errorf("smtp MAIL FROM (%s): %w", envelopeFrom, err))
	}
	if err := client.Rcpt(to); err != nil {
		return classify(fmt.Errorf("smtp RCPT TO (%s): %w", to, err))
	}

	w, err := client.Data()
	if err != nil {
		return classify(fmt.Errorf("smtp DATA to %s: %w", to, err))
	}
	if _, err := w.Write(message); err != nil {
		return classify(fmt.Errorf("smtp write to %s: %w", to, err))
	}
	if err := w.Close(); err != nil {
		return classify(fmt.Errorf("smtp finalize message to %s: %w", to, err))
	}

	_ = client.Quit()
	return nil
}

// classify wraps err as permanent when the relay rejected it with a 5xx SMTP
// reply. A 4xx reply (e.g. a temporary rate limit) or a connection-level
// error is left as-is so normal retry/backoff applies.
func classify(err error) error {
	var protoErr *textproto.Error
	if errors.As(err, &protoErr) && protoErr.Code >= 500 && protoErr.Code < 600 {
		return &PermanentError{err: err}
	}
	return err
}

// PermanentError marks an SMTP failure that will not succeed on retry — a
// 5xx rejection from the relay. See IsPermanent.
type PermanentError struct{ err error }

func (e *PermanentError) Error() string { return e.err.Error() }
func (e *PermanentError) Unwrap() error { return e.err }

// IsPermanent reports whether err (or anything it wraps) is a PermanentError.
func IsPermanent(err error) bool {
	var permErr *PermanentError
	return errors.As(err, &permErr)
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
