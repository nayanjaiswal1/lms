package mailer

import (
	"context"
	"errors"
	"fmt"
	"io"
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
	sess := NewSession(host, port, user, pass, envelopeFrom)
	defer sess.Close()
	return sess.Send(ctx, to, message)
}

// Session reuses one SMTP connection across several messages — used by
// invite.bulk so a 50-invite chunk costs one dial/handshake/auth instead of
// fifty (which also trips provider connection-rate limits). The connection is
// opened lazily on first Send and reopened automatically if a transport error
// breaks it. Not safe for concurrent use.
type Session struct {
	host, port, user, pass, from string
	conn                         net.Conn
	client                       *smtp.Client
}

// NewSession returns a Session; no connection is made until the first Send.
func NewSession(host, port, user, pass, envelopeFrom string) *Session {
	return &Session{host: host, port: port, user: user, pass: pass, from: envelopeFrom}
}

// Close ends the session's connection, if any.
func (s *Session) Close() {
	if s.client != nil {
		_ = s.client.Quit()
		_ = s.client.Close()
	}
	s.client, s.conn = nil, nil
}

func (s *Session) open(ctx context.Context) error {
	addr := s.host + ":" + s.port
	dialCtx, cancel := context.WithDeadline(ctx, deadlineFor(ctx))
	defer cancel()
	var d net.Dialer
	conn, err := d.DialContext(dialCtx, "tcp", addr)
	if err != nil {
		return fmt.Errorf("dial %s: %w", addr, err)
	}
	s.conn = conn
	// Bounded per message in Send; the handshake gets the same bound.
	_ = conn.SetDeadline(deadlineFor(ctx))
	client, err := smtp.NewClient(conn, s.host)
	if err != nil {
		conn.Close()
		s.conn = nil
		return classify(fmt.Errorf("smtp handshake with %s: %w", addr, err))
	}
	s.client = client
	if s.user != "" {
		if ok, _ := client.Extension("AUTH"); ok {
			if err := client.Auth(smtp.PlainAuth("", s.user, s.pass, s.host)); err != nil {
				s.Close()
				return classify(fmt.Errorf("smtp auth with %s: %w", addr, err))
			}
		}
	}
	return nil
}

// deadlineFor is ctx's deadline, or now+defaultTimeout when ctx has none.
func deadlineFor(ctx context.Context) time.Time {
	if d, ok := ctx.Deadline(); ok {
		return d
	}
	return time.Now().Add(defaultTimeout)
}

// Send delivers one message on the session's connection. See SendRaw for the
// error classification (5xx permanent, 4xx throttle).
func (s *Session) Send(ctx context.Context, to string, message []byte) error {
	if s.client == nil {
		if err := s.open(ctx); err != nil {
			return err
		}
	} else {
		// smtp.Client has no context awareness; bounding the raw connection is
		// what stops a stalled DATA write from hanging past ctx's deadline.
		_ = s.conn.SetDeadline(deadlineFor(ctx))
		if err := s.client.Reset(); err != nil {
			s.Close()
			return s.Send(ctx, to, message)
		}
	}
	err := s.deliver(to, message)
	var protoErr *textproto.Error
	if err != nil && !errors.As(err, &protoErr) {
		s.Close() // transport-level failure: connection state is unknown
	}
	return err
}

func (s *Session) deliver(to string, message []byte) error {
	if err := s.client.Mail(s.from); err != nil {
		return classify(fmt.Errorf("smtp MAIL FROM (%s): %w", s.from, err))
	}
	if err := s.client.Rcpt(to); err != nil {
		return classify(fmt.Errorf("smtp RCPT TO (%s): %w", to, err))
	}
	w, err := s.client.Data()
	if err != nil {
		return classify(fmt.Errorf("smtp DATA to %s: %w", to, err))
	}
	if _, err := w.Write(message); err != nil {
		return classify(fmt.Errorf("smtp write to %s: %w", to, err))
	}
	if err := w.Close(); err != nil {
		return classify(fmt.Errorf("smtp finalize message to %s: %w", to, err))
	}
	return nil
}

// classify wraps err as permanent when the relay rejected it with a 5xx SMTP
// reply, and as a ThrottleError for a 4xx reply (421/450/451/452 are the
// rate-limit / try-later family). Connection-level errors are left as-is so
// normal retry/backoff applies.
func classify(err error) error {
	var protoErr *textproto.Error
	if errors.As(err, &protoErr) {
		switch {
		case protoErr.Code >= 500 && protoErr.Code < 600:
			return &PermanentError{err: err}
		case protoErr.Code >= 400 && protoErr.Code < 500:
			return &ThrottleError{err: err}
		}
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

// ThrottleError marks a 4xx SMTP reply (or HTTP 429 from an API relay): the
// provider asked us to slow down or come back later. Retrying immediately
// makes it worse, so the job queue backs off for longer than normal (see
// jobs.RetryAfter) and the circuit breaker counts it.
type ThrottleError struct{ err error }

func (e *ThrottleError) Error() string { return e.err.Error() }
func (e *ThrottleError) Unwrap() error { return e.err }

// IsThrottle reports whether err (or anything it wraps) is a ThrottleError.
func IsThrottle(err error) bool {
	var t *ThrottleError
	return errors.As(err, &t)
}

// IsTransient reports whether err is a delivery-infrastructure failure worth
// counting against the circuit breaker: a throttle reply, a network error, or
// a timeout. Permanent rejections (bad recipient) are about one message, not
// the relay's health, and do not count.
func IsTransient(err error) bool {
	if err == nil || IsPermanent(err) {
		return false
	}
	var ne net.Error
	return IsThrottle(err) || errors.As(err, &ne) ||
		errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) ||
		errors.Is(err, context.DeadlineExceeded)
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
