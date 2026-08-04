package payments

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/google/uuid"
)

// StubProvider simulates a checkout with no external call and no signature
// requirement — it exists so the whole checkout/webhook flow is curl-testable
// offline (see docs verification section) and so CI never needs gateway
// credentials. FromConfig never registers it when cfg.Env == "production".
type StubProvider struct{}

// NewStubProvider constructs a StubProvider.
func NewStubProvider() *StubProvider {
	return &StubProvider{}
}

func (p *StubProvider) Name() string { return "stub" }

// CreateCheckout returns SuccessURL as RedirectURL — there is no real
// checkout page to visit, so a local dev client following the redirect lands
// immediately on the return page (whose poll then waits for a webhook
// delivery, exactly like the real flow, just triggered by hand via curl).
func (p *StubProvider) CreateCheckout(ctx context.Context, cp CheckoutParams) (Checkout, error) {
	return Checkout{ProviderRef: "stub_" + uuid.NewString(), RedirectURL: cp.SuccessURL}, nil
}

// stubWebhookBody is the plain, unsigned JSON body a local test posts to
// /api/payments/webhooks/stub to simulate a gateway confirming or failing a
// checkout — see the migration/verification docs for a curl example.
type stubWebhookBody struct {
	EventID     string `json:"event_id"`
	ProviderRef string `json:"provider_ref"`
	Status      string `json:"status"` // "succeeded" | "failed"
	AmountCents int    `json:"amount_cents"`
	Currency    string `json:"currency"`
}

// Refund is a no-op — there is no external gateway to call, matching how
// CreateCheckout/ParseWebhook simulate the flow without a real charge.
func (p *StubProvider) Refund(ctx context.Context, paymentRef string, amountCents int) error {
	return nil
}

func (p *StubProvider) ParseWebhook(rawBody []byte, h http.Header) (Event, error) {
	var body stubWebhookBody
	if err := json.Unmarshal(rawBody, &body); err != nil {
		return Event{}, fmt.Errorf("payments: stub decode webhook body: %w", err)
	}
	if body.EventID == "" || body.ProviderRef == "" {
		return Event{}, ErrInvalidSignature
	}

	status := StatusIgnored
	switch body.Status {
	case "succeeded":
		status = StatusSucceeded
	case "failed":
		status = StatusFailed
	}

	return Event{
		ID:          body.EventID,
		Type:        "stub." + body.Status,
		ProviderRef: body.ProviderRef,
		PaymentRef:  body.ProviderRef,
		Currency:    body.Currency,
		Status:      status,
		AmountCents: body.AmountCents,
		Raw:         rawBody,
	}, nil
}
