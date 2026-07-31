package payments

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"testing"
	"time"
)

func signRazorpay(body []byte, secret string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

func razorpayBody(t *testing.T, event string, createdAt int64) []byte {
	t.Helper()
	body, err := json.Marshal(map[string]any{
		"event": event,
		"payload": map[string]any{
			"payment": map[string]any{
				"entity": map[string]any{
					"id":       "pay_test123",
					"order_id": "order_test123",
					"amount":   999,
					"currency": "INR",
				},
			},
		},
		"created_at": createdAt,
	})
	if err != nil {
		t.Fatalf("marshal fixture: %v", err)
	}
	return body
}

func TestRazorpayParseWebhook_ValidSignatureSucceeds(t *testing.T) {
	secret := "razorpay_test_secret"
	body := razorpayBody(t, "payment.captured", time.Now().Unix())

	p := NewRazorpayProvider("rzp_test_key", "rzp_test_secret", secret)
	h := http.Header{}
	h.Set("X-Razorpay-Signature", signRazorpay(body, secret))
	h.Set("X-Razorpay-Event-Id", "evt_test123")

	ev, err := p.ParseWebhook(body, h)
	if err != nil {
		t.Fatalf("ParseWebhook: %v", err)
	}
	if ev.Status != StatusSucceeded {
		t.Errorf("status = %v, want StatusSucceeded", ev.Status)
	}
	if ev.ProviderRef != "order_test123" {
		t.Errorf("provider ref = %q, want order_test123", ev.ProviderRef)
	}
	if ev.ID != "evt_test123" {
		t.Errorf("event id = %q, want header value used verbatim", ev.ID)
	}
}

func TestRazorpayParseWebhook_InvalidSignatureRejected(t *testing.T) {
	secret := "razorpay_test_secret"
	body := razorpayBody(t, "payment.captured", time.Now().Unix())

	p := NewRazorpayProvider("rzp_test_key", "rzp_test_secret", secret)
	h := http.Header{}
	h.Set("X-Razorpay-Signature", "0000deadbeef")

	if _, err := p.ParseWebhook(body, h); !errors.Is(err, ErrInvalidSignature) {
		t.Fatalf("expected ErrInvalidSignature, got %v", err)
	}
}

func TestRazorpayParseWebhook_WrongSecretRejected(t *testing.T) {
	body := razorpayBody(t, "payment.captured", time.Now().Unix())

	p := NewRazorpayProvider("rzp_test_key", "rzp_test_secret", "correct_secret")
	h := http.Header{}
	h.Set("X-Razorpay-Signature", signRazorpay(body, "wrong_secret"))

	if _, err := p.ParseWebhook(body, h); !errors.Is(err, ErrInvalidSignature) {
		t.Fatalf("expected ErrInvalidSignature, got %v", err)
	}
}

// TestRazorpayParseWebhook_StaleTimestampRejected proves a validly-signed
// but old payload is rejected — a signature has no expiry of its own, so a
// captured payload+signature (leaked logs, a compromised intermediary — not
// the webhook secret itself) must not be replayable indefinitely.
func TestRazorpayParseWebhook_StaleTimestampRejected(t *testing.T) {
	secret := "razorpay_test_secret"
	old := time.Now().Add(-10 * time.Minute).Unix() // older than razorpayWebhookTolerance (5m)
	body := razorpayBody(t, "payment.captured", old)

	p := NewRazorpayProvider("rzp_test_key", "rzp_test_secret", secret)
	h := http.Header{}
	h.Set("X-Razorpay-Signature", signRazorpay(body, secret))

	if _, err := p.ParseWebhook(body, h); !errors.Is(err, ErrInvalidSignature) {
		t.Fatalf("expected ErrInvalidSignature for a stale timestamp, got %v", err)
	}
}

func TestRazorpayParseWebhook_EventIDFallsBackToCompositeKey(t *testing.T) {
	secret := "razorpay_test_secret"
	createdAt := time.Now().Unix()
	body := razorpayBody(t, "payment.failed", createdAt)

	p := NewRazorpayProvider("rzp_test_key", "rzp_test_secret", secret)
	h := http.Header{}
	h.Set("X-Razorpay-Signature", signRazorpay(body, secret))
	// No X-Razorpay-Event-Id header — must fall back to a deterministic key.

	ev, err := p.ParseWebhook(body, h)
	if err != nil {
		t.Fatalf("ParseWebhook: %v", err)
	}
	if ev.Status != StatusFailed {
		t.Errorf("status = %v, want StatusFailed", ev.Status)
	}
	if ev.ID == "" {
		t.Error("expected a non-empty fallback event id")
	}
}
