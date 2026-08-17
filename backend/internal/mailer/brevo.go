package mailer

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

// brevoAPIURL is Brevo's transactional email endpoint. Reached over HTTPS
// (port 443), unlike SMTPSender's port 587 — needed because some hosts
// (e.g. Render's free web services) block outbound traffic to SMTP ports
// entirely, so a relay that only offers SMTP cannot be reached at all from
// there. See BrevoAPISender.
const brevoAPIURL = "https://api.brevo.com/v3/smtp/email"

// BrevoAPISender delivers email via Brevo's HTTPS transactional email API
// instead of SMTP. Use this (via NewBrevoAPISender) wherever the deploy
// target blocks outbound SMTP ports; SMTPSender still works fine anywhere
// that doesn't (e.g. a local Mailpit relay in dev).
type BrevoAPISender struct {
	apiKey    string
	fromEmail string
	fromName  string
}

// NewBrevoAPISender constructs a BrevoAPISender. fromName may be empty.
func NewBrevoAPISender(apiKey, fromEmail, fromName string) *BrevoAPISender {
	return &BrevoAPISender{apiKey: apiKey, fromEmail: fromEmail, fromName: fromName}
}

func (s *BrevoAPISender) Send(ctx context.Context, to, subject, body string, headers map[string]string) error {
	// headers (Message-Id/In-Reply-To/References for reply threading) has no
	// equivalent in Brevo's structured API payload — the same gap SMTPSender
	// doesn't have since it writes raw RFC 5322 headers directly. No caller
	// wires a mailer.Sender through email threading today (only the direct
	// SendViaBrevoAPI callers in internal/auth and invite.go build their own
	// message, and neither uses this parameter either), so this is a known,
	// currently-inert limitation rather than a silent behavior change.
	return SendViaBrevoAPI(ctx, s.apiKey, s.fromEmail, s.fromName, to, subject, body)
}

// SendViaBrevoAPI delivers one plain-text email through Brevo's transactional
// email API. Mirrors SendRaw's error classification: a 4xx response from
// Brevo is wrapped as PermanentError (the request itself is malformed or
// rejected — retrying unchanged won't help); a network error or 5xx is left
// as-is so normal retry/backoff applies.
func SendViaBrevoAPI(ctx context.Context, apiKey, fromEmail, fromName, to, subject, body string) error {
	if _, ok := ctx.Deadline(); !ok {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, defaultTimeout)
		defer cancel()
	}

	payload, err := json.Marshal(brevoSendRequest{
		Sender:      brevoContact{Name: fromName, Email: fromEmail},
		To:          []brevoContact{{Email: to}},
		Subject:     subject,
		TextContent: body,
	})
	if err != nil {
		return fmt.Errorf("mailer: encode brevo request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, brevoAPIURL, bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("mailer: build brevo request: %w", err)
	}
	req.Header.Set("api-key", apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("mailer: brevo request to %s: %w", to, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}

	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	sendErr := fmt.Errorf("mailer: brevo send to %s: status %d: %s", to, resp.StatusCode, respBody)
	if resp.StatusCode >= 400 && resp.StatusCode < 500 {
		return &PermanentError{err: sendErr}
	}
	return sendErr
}

type brevoContact struct {
	Name  string `json:"name,omitempty"`
	Email string `json:"email"`
}

type brevoSendRequest struct {
	Sender      brevoContact   `json:"sender"`
	To          []brevoContact `json:"to"`
	Subject     string         `json:"subject"`
	TextContent string         `json:"textContent"`
}
