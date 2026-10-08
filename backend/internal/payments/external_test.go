package payments

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/stripe/stripe-go/v82"
)

const (
	hangTimeout = 300 * time.Millisecond
	paise499    = 49900 // ₹499.00
)

var testCheckout = CheckoutParams{
	PurchaseID: "11111111-2222-3333-4444-555555555555", OrgID: "o", UserID: "u", CourseID: "c",
	AmountCents: paise499, Currency: "INR", CourseTitle: "Go", SuccessURL: "https://x/s", CancelURL: "https://x/c",
}

func serverError() *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, `{"error":{"description":"boom"}}`, http.StatusInternalServerError)
	}))
}

// hangServer blocks until the client gives up (or the test ends).
func hangServer(t *testing.T) *httptest.Server {
	t.Helper()
	release := make(chan struct{})
	srv := httptest.NewServer(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
		case <-release:
		}
	}))
	t.Cleanup(func() { close(release); srv.Close() })
	return srv
}

func newRazorpay(baseURL string) *RazorpayProvider {
	p := NewRazorpayProvider("rzp_key", "rzp_secret", "whsec")
	p.client.Request.BaseURL = baseURL
	p.client.Request.SetTimeout(1) // SDK takes whole seconds
	return p
}

func newStripe(baseURL string) *StripeProvider {
	backend := stripe.GetBackendWithConfig(stripe.APIBackend, &stripe.BackendConfig{
		URL:               stripe.String(baseURL),
		MaxNetworkRetries: stripe.Int64(0),
	})
	return &StripeProvider{
		client:        stripe.NewClient("sk_test_x", stripe.WithBackends(&stripe.Backends{API: backend})),
		webhookSecret: "whsec",
	}
}

func TestRazorpayCreateCheckoutSendsPaiseUnscaled(t *testing.T) {
	var got map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &got)
		_, _ = w.Write([]byte(`{"id":"order_abc"}`))
	}))
	defer srv.Close()

	co, err := newRazorpay(srv.URL).CreateCheckout(context.Background(), testCheckout)
	if err != nil {
		t.Fatalf("CreateCheckout: %v", err)
	}
	if got["amount"] != float64(paise499) || got["currency"] != "INR" {
		t.Fatalf("wire amount/currency = %v/%v, want 49900/INR", got["amount"], got["currency"])
	}
	if co.ProviderRef != "order_abc" || co.ClientParams["amount"] != "49900" {
		t.Fatalf("checkout = %+v, want ref order_abc and client amount 49900", co)
	}
}

func TestStripeCreateCheckoutSendsPaiseUnscaled(t *testing.T) {
	var form string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		form = string(body)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"id":"cs_1","url":"https://pay/cs_1"}`))
	}))
	defer srv.Close()

	co, err := newStripe(srv.URL).CreateCheckout(context.Background(), testCheckout)
	if err != nil {
		t.Fatalf("CreateCheckout: %v", err)
	}
	if !strings.Contains(form, "unit_amount%5D=49900") && !strings.Contains(form, "unit_amount]=49900") {
		t.Fatalf("form body lacks unit_amount=49900: %s", form)
	}
	if co.ProviderRef != "cs_1" || co.RedirectURL != "https://pay/cs_1" {
		t.Fatalf("checkout = %+v", co)
	}
}

func TestProvidersWrapServerErrors(t *testing.T) {
	srv := serverError()
	defer srv.Close()
	ctx := context.Background()

	_, rzpErr := newRazorpay(srv.URL).CreateCheckout(ctx, testCheckout)
	assertWrapped(t, "razorpay create", rzpErr, "payments: razorpay create order")
	assertWrapped(t, "razorpay refund", newRazorpay(srv.URL).Refund(ctx, "pay_1", paise499), "payments: razorpay refund")

	_, stErr := newStripe(srv.URL).CreateCheckout(ctx, testCheckout)
	assertWrapped(t, "stripe create", stErr, "payments: stripe create checkout session")
	assertWrapped(t, "stripe refund", newStripe(srv.URL).Refund(ctx, "pi_1", paise499), "payments: stripe refund")
}

// The razorpay SDK's timeout is whole seconds (1s minimum), so the hang is
// bounded by the client timeout itself; the assertion is on the error kind, not wall-clock time.
func TestProvidersReturnErrorWhenUpstreamHangs(t *testing.T) {
	srv := hangServer(t)

	t.Run("razorpay", func(t *testing.T) {
		_, err := newRazorpay(srv.URL).CreateCheckout(context.Background(), testCheckout)
		assertWrapped(t, "razorpay hang", err, "payments: razorpay create order")
		assertTimeout(t, "razorpay hang", err)
	})
	t.Run("stripe", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), hangTimeout)
		defer cancel()
		_, err := newStripe(srv.URL).CreateCheckout(ctx, testCheckout)
		assertWrapped(t, "stripe hang", err, "payments: stripe create checkout session")
		assertTimeout(t, "stripe hang", err)
	})
}

func assertWrapped(t *testing.T, name string, err error, prefix string) {
	t.Helper()
	if err == nil {
		t.Fatalf("%s: want error, got nil", name)
	}
	if !strings.HasPrefix(err.Error(), prefix) {
		t.Fatalf("%s: error %q lacks prefix %q", name, err, prefix)
	}
	if errors.Unwrap(err) == nil {
		t.Fatalf("%s: error %q is not wrapped with %%w", name, err)
	}
}

func assertTimeout(t *testing.T, name string, err error) {
	t.Helper()
	var ne net.Error
	if !errors.As(err, &ne) || !ne.Timeout() {
		t.Fatalf("%s: error %q is not a timeout", name, err)
	}
}
