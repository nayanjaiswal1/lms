// Package mailer is the one seam between "MindForge wants to send an email"
// and "how that email actually leaves the building". Today there is exactly
// one Sender (SMTPSender, moved verbatim out of
// internal/jobs/handlers/email.go's former sendRaw/buildEmailMessage), so
// this is deliberately just an interface plus one implementation — no
// provider registry, no config-driven provider selection, no second
// implementation speculatively stubbed in. Add a second Sender (e.g. a
// transactional-email API) only when one is actually being wired in, and
// change EmailHandler's single construction site (cmd/server/main.go) to
// pass it — that is the entire migration.
package mailer

import "context"

// Sender delivers one plain-text email. Implementations own their own
// transport config (SMTP host/port/auth, an API key, etc.) — callers only
// ever see this interface. headers carries additional RFC 5322 headers
// (e.g. Message-Id/In-Reply-To/References for threading a reply into an
// existing conversation) — nil for a standalone email.
type Sender interface {
	Send(ctx context.Context, to, subject, body string, headers map[string]string) error
}
