package payments

import (
	"errors"
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

func TestStripeParseWebhook_TamperedBodyFailsSignature(t *testing.T) {
	secret := "whsec_test_secret"
	body := []byte(`{"id":"evt_test789","type":"checkout.session.completed","data":{"object":{"id":"cs_test789","payment_status":"paid"}}}`)
	signed := webhook.GenerateTestSignedPayload(&webhook.UnsignedPayload{Payload: body, Secret: secret, Timestamp: time.Now()})

	tampered := append([]byte{}, signed.Payload...)
	// Flip one byte inside the JSON body — the signature was computed over
	// the original bytes, so this must fail verification.
	tampered[len(tampered)-3] = 'X'

	p := NewStripeProvider("sk_test_dummy", secret)
	h := http.Header{}
	h.Set("Stripe-Signature", signed.Header)

	if _, err := p.ParseWebhook(tampered, h); !errors.Is(err, ErrInvalidSignature) {
		t.Fatalf("expected ErrInvalidSignature, got %v", err)
	}
}

func TestStripeParseWebhook_WrongSecretFailsSignature(t *testing.T) {
	body := []byte(`{"id":"evt_test999","type":"checkout.session.completed","data":{"object":{"id":"cs_test999","payment_status":"paid"}}}`)
	signed := webhook.GenerateTestSignedPayload(&webhook.UnsignedPayload{Payload: body, Secret: "whsec_correct", Timestamp: time.Now()})

	p := NewStripeProvider("sk_test_dummy", "whsec_wrong")
	h := http.Header{}
	h.Set("Stripe-Signature", signed.Header)

	if _, err := p.ParseWebhook(signed.Payload, h); !errors.Is(err, ErrInvalidSignature) {
		t.Fatalf("expected ErrInvalidSignature, got %v", err)
	}
}
