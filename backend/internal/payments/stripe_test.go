package payments

import (
	"errors"
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/stripe/stripe-go/v82/webhook"
)

func TestStripeParseWebhook_ValidSignatureSucceeds(t *testing.T) {
	secret := "whsec_test_secret"
	body := []byte(`{
		"id": "evt_test123",
		"type": "checkout.session.completed",
		"data": {
			"object": {
				"id": "cs_test123",
				"payment_status": "paid",
				"currency": "usd",
				"amount_total": 999
			}
		}
	}`)
	signed := webhook.GenerateTestSignedPayload(&webhook.UnsignedPayload{Payload: body, Secret: secret, Timestamp: time.Now()})

	p := NewStripeProvider("sk_test_dummy", secret)
	h := http.Header{}
	h.Set("Stripe-Signature", signed.Header)

	ev, err := p.ParseWebhook(signed.Payload, h)
	if err != nil {
		t.Fatalf("ParseWebhook: %v", err)
	}
	if ev.Status != StatusSucceeded {
		t.Errorf("status = %v, want StatusSucceeded", ev.Status)
	}
	if ev.ProviderRef != "cs_test123" {
		t.Errorf("provider ref = %q, want cs_test123", ev.ProviderRef)
	}
	if ev.AmountCents != 999 {
		t.Errorf("amount cents = %d, want 999", ev.AmountCents)
	}
}

// TestStripeParseWebhook_UnpaidSessionIsIgnored proves an async payment
// method's "completed" event (session exists, but payment_status isn't
// "paid" yet) is not mistaken for a confirmed purchase — the separate
// async_payment_succeeded event is what actually confirms those.
func TestStripeParseWebhook_UnpaidSessionIsIgnored(t *testing.T) {
	secret := "whsec_test_secret"
	body := []byte(`{
		"id": "evt_test456",
		"type": "checkout.session.completed",
		"data": {
			"object": {
				"id": "cs_test456",
				"payment_status": "unpaid",
				"currency": "usd",
				"amount_total": 999
			}
		}
	}`)
	signed := webhook.GenerateTestSignedPayload(&webhook.UnsignedPayload{Payload: body, Secret: secret, Timestamp: time.Now()})

	p := NewStripeProvider("sk_test_dummy", secret)
	h := http.Header{}
	h.Set("Stripe-Signature", signed.Header)

	ev, err := p.ParseWebhook(signed.Payload, h)
	if err != nil {
		t.Fatalf("ParseWebhook: %v", err)
	}
	if ev.Status != StatusIgnored {
		t.Errorf("status = %v, want StatusIgnored", ev.Status)
	}
}

func TestStripeParseWebhook_BadSignatureRejected(t *testing.T) {
	body := []byte(`{"id":"evt_test789","type":"checkout.session.completed","data":{"object":{"id":"cs_test789","payment_status":"paid"}}}`)
	tests := []struct {
		name          string
		signSecret    string
		providerKey   string
		tamperPayload bool
	}{
		// The signature covers the original bytes, so flipping one must fail.
		{"tampered body", "whsec_test_secret", "whsec_test_secret", true},
		{"wrong secret", "whsec_correct", "whsec_wrong", false},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			signed := webhook.GenerateTestSignedPayload(&webhook.UnsignedPayload{Payload: body, Secret: tc.signSecret, Timestamp: time.Now()})
			payload := append([]byte{}, signed.Payload...)
			if tc.tamperPayload {
				payload[len(payload)-3] = 'X'
			}
			p := NewStripeProvider("sk_test_dummy", tc.providerKey)
			h := http.Header{}
			h.Set("Stripe-Signature", signed.Header)
			if _, err := p.ParseWebhook(payload, h); !errors.Is(err, ErrInvalidSignature) {
				t.Fatalf("expected ErrInvalidSignature, got %v", err)
			}
		})
	}
}

func signedStripeEvent(t *testing.T, body string) (*StripeProvider, []byte, http.Header) {
	t.Helper()
	secret := "whsec_test_secret"
	signed := webhook.GenerateTestSignedPayload(&webhook.UnsignedPayload{Payload: []byte(body), Secret: secret, Timestamp: time.Now()})
	h := http.Header{}
	h.Set("Stripe-Signature", signed.Header)
	return NewStripeProvider("sk_test_dummy", secret), signed.Payload, h
}

func TestStripeParseWebhook_ChargeRefunded(t *testing.T) {
	cases := []struct {
		name       string
		refunded   bool
		wantStatus EventStatus
	}{
		{"full refund", true, StatusRefunded},
		{"partial refund is ignored", false, StatusIgnored},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			body := fmt.Sprintf(`{"id":"evt_r1","type":"charge.refunded","data":{"object":{"id":"ch_1","object":"charge","refunded":%t,"amount_refunded":999,"currency":"usd","payment_intent":"pi_123"}}}`, c.refunded)
			p, payload, h := signedStripeEvent(t, body)
			ev, err := p.ParseWebhook(payload, h)
			if err != nil {
				t.Fatalf("ParseWebhook: %v", err)
			}
			if ev.Status != c.wantStatus {
				t.Fatalf("status = %v, want %v", ev.Status, c.wantStatus)
			}
			if c.wantStatus == StatusRefunded && (ev.PaymentRef != "pi_123" || ev.AmountCents != 999) {
				t.Errorf("payment ref/amount = %q/%d, want pi_123/999", ev.PaymentRef, ev.AmountCents)
			}
		})
	}
}

func TestStripeParseWebhook_DisputeIsFullReversal(t *testing.T) {
	body := `{"id":"evt_d1","type":"charge.dispute.created","data":{"object":{"id":"dp_1","object":"dispute","amount":999,"payment_intent":"pi_456"}}}`
	p, payload, h := signedStripeEvent(t, body)
	ev, err := p.ParseWebhook(payload, h)
	if err != nil {
		t.Fatalf("ParseWebhook: %v", err)
	}
	// AmountCents 0 is the contract for "dispute, always a full reversal".
	if ev.Status != StatusRefunded || ev.PaymentRef != "pi_456" || ev.AmountCents != 0 {
		t.Errorf("got status=%v ref=%q amount=%d, want refunded/pi_456/0", ev.Status, ev.PaymentRef, ev.AmountCents)
	}
}
