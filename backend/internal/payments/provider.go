// Package payments defines the seam every payment gateway (Stripe, Razorpay,
// or the local stub) implements, without the checkout/webhook orchestration
// in the mentoring package ever needing to know which one is in use.
package payments

import (
	"context"
	"errors"
	"net/http"
)

// CheckoutParams describes a single course-purchase checkout request. The
// caller has already computed AmountCents as the final, post-discount price
// — providers never see or apply a discount themselves.
type CheckoutParams struct {
	PurchaseID    string // our course_purchases.id — carried through as gateway metadata/receipt so a webhook can be matched back to this purchase even before ProviderRef is known
	OrgID         string
	UserID        string
	CourseID      string
	CourseTitle   string
	AmountCents   int
	Currency      string
	CustomerEmail string
	SuccessURL    string
	CancelURL     string
}

// Checkout is what a provider hands back after creating a checkout session.
// Exactly one of RedirectURL (a hosted checkout page, e.g. Stripe) or
// ClientParams (fields a client-side SDK needs to open its own checkout UI,
// e.g. Razorpay's Checkout.js) is populated, depending on the provider.
type Checkout struct {
	ProviderRef  string            // the gateway's own session/order id
	RedirectURL  string            // hosted checkout URL; empty when the provider uses a client-side modal instead
	ClientParams map[string]string // client-side checkout params; nil when the provider redirects instead
}

// EventStatus is the outcome ParseWebhook derived from a single gateway
// event, normalized across providers.
type EventStatus int

const (
	// StatusIgnored means the event is real and correctly authenticated but
	// irrelevant to purchase confirmation (e.g. a subscription event on a
	// gateway also used for other products) — callers ack it and do nothing.
	StatusIgnored EventStatus = iota
	StatusSucceeded
	StatusFailed
)

// Event is a single normalized webhook delivery. ProviderRef matches the
// Checkout.ProviderRef returned by CreateCheckout, letting the caller look up
// the pending course_purchases row this event confirms or fails.
type Event struct {
	ID          string // the gateway's own event id — the caller's dedup key (see payment_events.event_id)
	Type        string
	ProviderRef string
	PaymentRef  string // the underlying charge/payment id (refund handle), distinct from ProviderRef (the session/order id)
	Currency    string
	Status      EventStatus
	AmountCents int
	Raw         []byte
}

// Provider is implemented by every payment gateway integration. All methods
// must be safe for concurrent use.
type Provider interface {
	// Name identifies the provider ("stripe", "razorpay", "stub") — this is
	// what's persisted in course_purchases.provider and payment_events.provider,
	// and what a checkout request's Provider field selects by by.
	Name() string

	// CreateCheckout starts a real checkout with the gateway. It must be
	// idempotent per CheckoutParams.PurchaseID — retried calls with the same
	// PurchaseID must not create a second charge-able session.
	CreateCheckout(ctx context.Context, p CheckoutParams) (Checkout, error)

	// ParseWebhook authenticates rawBody against h using the provider's own
	// signature scheme and returns the normalized Event it describes.
	// Implementations must verify the signature against rawBody exactly as
	// received — before any JSON decoding — since re-serializing a decoded
	// body does not reproduce the exact bytes the signature was computed
	// over. Returns ErrInvalidSignature if authentication fails.
	ParseWebhook(rawBody []byte, h http.Header) (Event, error)
}

var (
	// ErrUnknownProvider is returned by Registry.Get for a name with no
	// registered Provider.
	ErrUnknownProvider = errors.New("payments: unknown provider")
	// ErrInvalidSignature is returned by ParseWebhook when the request's
	// signature does not authenticate against the provider's configured
	// secret — the caller must reject the request (401), never process it.
	ErrInvalidSignature = errors.New("payments: invalid webhook signature")
)
