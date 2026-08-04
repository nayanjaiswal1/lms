package payments

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	razorpay "github.com/razorpay/razorpay-go"
)

// RazorpayProvider implements Provider against Razorpay Orders + Checkout.js
// (a client-side modal, not a hosted redirect) confirmed via webhook.
type RazorpayProvider struct {
	client        *razorpay.Client
	keyID         string
	webhookSecret string
}

// NewRazorpayProvider builds a RazorpayProvider. webhookSecret must be
// non-empty — config.Load enforces this at startup whenever a Razorpay key
// id is set.
func NewRazorpayProvider(keyID, keySecret, webhookSecret string) *RazorpayProvider {
	return &RazorpayProvider{client: razorpay.NewClient(keyID, keySecret), keyID: keyID, webhookSecret: webhookSecret}
}

func (p *RazorpayProvider) Name() string { return "razorpay" }

func (p *RazorpayProvider) CreateCheckout(ctx context.Context, cp CheckoutParams) (Checkout, error) {
	// Razorpay order amounts/currency are int/string via a generic map (the
	// Go SDK has no typed request struct); "receipt" is capped at 40 chars
	// by the API, so it carries a shortened id rather than the full UUID.
	receiptSuffix := cp.PurchaseID
	if len(receiptSuffix) > 8 {
		receiptSuffix = receiptSuffix[:8]
	}
	data := map[string]interface{}{
		"amount":   cp.AmountCents,
		"currency": cp.Currency,
		"receipt":  "purchase_" + receiptSuffix,
		"notes": map[string]interface{}{
			"purchase_id": cp.PurchaseID,
			"org_id":      cp.OrgID,
			"user_id":     cp.UserID,
			"course_id":   cp.CourseID,
		},
	}
	// Razorpay's Create endpoint has no idempotency-key header in the Go
	// SDK, so double-submission protection for retries on our side comes
	// from mentoring.Service reusing a live pending purchase row, not from
	// gateway-side dedup here.
	resp, err := p.client.Order.Create(data, nil)
	if err != nil {
		return Checkout{}, fmt.Errorf("payments: razorpay create order: %w", err)
	}
	orderID, _ := resp["id"].(string)
	if orderID == "" {
		return Checkout{}, fmt.Errorf("payments: razorpay create order: response missing id")
	}

	return Checkout{
		ProviderRef: orderID,
		ClientParams: map[string]string{
			"key_id":        p.keyID,
			"order_id":      orderID,
			"amount":        strconv.Itoa(cp.AmountCents),
			"currency":      cp.Currency,
			"name":          cp.CourseTitle,
			"prefill_email": cp.CustomerEmail,
		},
	}, nil
}

// Refund reverses paymentRef (a Razorpay payment id, "pay_...") in full. The
// Go SDK always sends "amount" in the refund request body (there is no
// "omit for full refund" option like Stripe's), so amountCents — the
// purchase's original AmountCents — must be passed through explicitly for
// a full refund to actually be a full refund rather than a zero-amount one.
func (p *RazorpayProvider) Refund(ctx context.Context, paymentRef string, amountCents int) error {
	if _, err := p.client.Payment.Refund(paymentRef, amountCents, nil, nil); err != nil {
		return fmt.Errorf("payments: razorpay refund: %w", err)
	}
	return nil
}

// razorpayWebhookTolerance bounds how old a signed webhook delivery may be
// before it's rejected — mirrors Stripe's own DefaultTolerance (5 minutes).
// A validly-signed payload has no expiry of its own otherwise, so without
// this a captured payload+signature (leaked logs, a compromised
// intermediary, anything short of the webhook secret itself) could be
// replayed indefinitely; payment_events' UNIQUE(provider, event_id) already
// makes a replay of an event we've SEEN a no-op, but this closes the gap for
// any path that doesn't go through that dedup check first.
const razorpayWebhookTolerance = 5 * time.Minute

// razorpayWebhookPayload covers only the fields this integration needs from
// payment.captured / payment.failed deliveries — Razorpay's webhook bodies
// carry many more fields depending on event type.
type razorpayWebhookPayload struct {
	Event   string `json:"event"`
	Payload struct {
		Payment struct {
			Entity struct {
				ID       string `json:"id"`
				OrderID  string `json:"order_id"`
				Amount   int    `json:"amount"`
				Currency string `json:"currency"`
			} `json:"entity"`
		} `json:"payment"`
	} `json:"payload"`
	CreatedAt int64 `json:"created_at"`
}

func (p *RazorpayProvider) ParseWebhook(rawBody []byte, h http.Header) (Event, error) {
	// The #1 Razorpay integration bug: verifying against a body that's
	// already been through a JSON decoder upstream, which does not
	// reproduce the exact bytes the HMAC was computed over. rawBody here is
	// the untouched request body (see mentoring/handler_webhook.go) and this
	// verification happens before any json.Unmarshal call in this function.
	if !verifyRazorpaySignature(rawBody, h.Get("X-Razorpay-Signature"), p.webhookSecret) {
		return Event{}, ErrInvalidSignature
	}

	var payload razorpayWebhookPayload
	if err := json.Unmarshal(rawBody, &payload); err != nil {
		return Event{}, fmt.Errorf("payments: razorpay decode webhook payload: %w", err)
	}

	// A valid signature only proves the delivery is authentically from
	// Razorpay, not that it's fresh — reject anything outside the tolerance
	// window rather than trust a signature with no expiry of its own.
	if payload.CreatedAt == 0 || time.Since(time.Unix(payload.CreatedAt, 0)) > razorpayWebhookTolerance {
		return Event{}, ErrInvalidSignature
	}

	// Razorpay sends X-Razorpay-Event-Id on most deliveries, but it is not
	// universally guaranteed across every webhook configuration — fall back
	// to a deterministic composite key so payment_events dedup still works
	// even when the header is absent, instead of silently losing dedup.
	eventID := h.Get("X-Razorpay-Event-Id")
	if eventID == "" {
		eventID = payload.Event + ":" + payload.Payload.Payment.Entity.ID + ":" + strconv.FormatInt(payload.CreatedAt, 10)
	}

	switch payload.Event {
	case "payment.captured":
		return Event{
			ID:          eventID,
			Type:        payload.Event,
			ProviderRef: payload.Payload.Payment.Entity.OrderID,
			PaymentRef:  payload.Payload.Payment.Entity.ID,
			Currency:    payload.Payload.Payment.Entity.Currency,
			Status:      StatusSucceeded,
			AmountCents: payload.Payload.Payment.Entity.Amount,
			Raw:         rawBody,
		}, nil
	case "payment.failed":
		return Event{
			ID:          eventID,
			Type:        payload.Event,
			ProviderRef: payload.Payload.Payment.Entity.OrderID,
			PaymentRef:  payload.Payload.Payment.Entity.ID,
			Status:      StatusFailed,
			Raw:         rawBody,
		}, nil
	default:
		return Event{ID: eventID, Type: payload.Event, Status: StatusIgnored, Raw: rawBody}, nil
	}
}

// verifyRazorpaySignature implements Razorpay's documented webhook signature
// scheme: hex(HMAC-SHA256(rawBody, webhookSecret)), constant-time compared
// against X-Razorpay-Signature.
func verifyRazorpaySignature(rawBody []byte, signatureHex, secret string) bool {
	if signatureHex == "" {
		return false
	}
	sig, err := hex.DecodeString(signatureHex)
	if err != nil {
		return false
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(rawBody)
	return hmac.Equal(mac.Sum(nil), sig)
}
