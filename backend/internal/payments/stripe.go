package payments

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/stripe/stripe-go/v82"
	"github.com/stripe/stripe-go/v82/webhook"
)

// StripeProvider implements Provider against Stripe Checkout (hosted page,
// Mode: payment) confirmed via webhook. No card data ever reaches this
// process — Checkout collects it directly on Stripe's page — only Stripe's
// own session/payment-intent ids are persisted.
type StripeProvider struct {
	client        *stripe.Client
	webhookSecret string
}

// NewStripeProvider builds a StripeProvider. webhookSecret must be non-empty
// — config.Load enforces this at startup whenever a Stripe secret key is set.
func NewStripeProvider(secretKey, webhookSecret string) *StripeProvider {
	return &StripeProvider{client: stripe.NewClient(secretKey), webhookSecret: webhookSecret}
}

func (p *StripeProvider) Name() string { return "stripe" }

func (p *StripeProvider) CreateCheckout(ctx context.Context, cp CheckoutParams) (Checkout, error) {
	params := &stripe.CheckoutSessionCreateParams{
		Mode:              stripe.String(string(stripe.CheckoutSessionModePayment)),
		ClientReferenceID: stripe.String(cp.PurchaseID),
		SuccessURL:        stripe.String(cp.SuccessURL),
		CancelURL:         stripe.String(cp.CancelURL),
		Metadata: map[string]string{
			"purchase_id": cp.PurchaseID,
			"org_id":      cp.OrgID,
			"user_id":     cp.UserID,
			"course_id":   cp.CourseID,
		},
		PaymentIntentData: &stripe.CheckoutSessionCreatePaymentIntentDataParams{
			Metadata: map[string]string{
				"purchase_id": cp.PurchaseID,
				"org_id":      cp.OrgID,
				"user_id":     cp.UserID,
				"course_id":   cp.CourseID,
			},
		},
		LineItems: []*stripe.CheckoutSessionCreateLineItemParams{
			{
				Quantity: stripe.Int64(1),
				PriceData: &stripe.CheckoutSessionCreateLineItemPriceDataParams{
					Currency:   stripe.String(cp.Currency),
					UnitAmount: stripe.Int64(int64(cp.AmountCents)),
					ProductData: &stripe.CheckoutSessionCreateLineItemPriceDataProductDataParams{
						Name: stripe.String(cp.CourseTitle),
					},
				},
			},
		},
	}
	// Stripe rejects an explicitly-empty string for an optional param
	// ("You passed an empty string for 'customer_email'…"), so this is set
	// only when the caller actually knows the address — otherwise Checkout
	// collects it on its own hosted page.
	if cp.CustomerEmail != "" {
		params.CustomerEmail = stripe.String(cp.CustomerEmail)
	}

	// Our own retries (network timeout, redeploy mid-request) must not
	// create a second Stripe session for the same purchase — PurchaseID is
	// stable per pending course_purchases row, so it's a correct idempotency
	// key for this call specifically.
	params.SetIdempotencyKey("checkout_" + cp.PurchaseID)

	session, err := p.client.V1CheckoutSessions.Create(ctx, params)
	if err != nil {
		return Checkout{}, fmt.Errorf("payments: stripe create checkout session: %w", err)
	}
	return Checkout{ProviderRef: session.ID, RedirectURL: session.URL}, nil
}

func (p *StripeProvider) ParseWebhook(rawBody []byte, h http.Header) (Event, error) {
	event, err := webhook.ConstructEventWithOptions(rawBody, h.Get("Stripe-Signature"), p.webhookSecret,
		webhook.ConstructEventOptions{IgnoreAPIVersionMismatch: true})
	if err != nil {
		return Event{}, ErrInvalidSignature
	}

	switch event.Type {
	case stripe.EventTypeCheckoutSessionCompleted, stripe.EventTypeCheckoutSessionAsyncPaymentSucceeded:
		session, err := decodeCheckoutSession(event.Data.Object)
		if err != nil {
			return Event{}, fmt.Errorf("payments: stripe decode checkout session: %w", err)
		}
		// Mode: payment with a card can complete with payment_status still
		// "unpaid" only in edge cases Checkout itself blocks: gate on it
		// explicitly rather than trusting the event type name alone —
		// async payment methods (bank debits) fire *completed* before funds
		// clear and only become "paid" on the separate async_payment_succeeded
		// event, so this check is what actually distinguishes the two.
		if session.PaymentStatus != stripe.CheckoutSessionPaymentStatusPaid {
			return Event{ID: event.ID, Type: string(event.Type), ProviderRef: session.ID, Status: StatusIgnored, Raw: rawBody}, nil
		}
		var paymentRef string
		if session.PaymentIntent != nil {
			paymentRef = session.PaymentIntent.ID
		}
		return Event{
			ID:          event.ID,
			Type:        string(event.Type),
			ProviderRef: session.ID,
			PaymentRef:  paymentRef,
			Currency:    string(session.Currency),
			Status:      StatusSucceeded,
			AmountCents: int(session.AmountTotal),
			Raw:         rawBody,
		}, nil

	case stripe.EventTypeCheckoutSessionExpired, stripe.EventTypeCheckoutSessionAsyncPaymentFailed:
		session, err := decodeCheckoutSession(event.Data.Object)
		if err != nil {
			return Event{}, fmt.Errorf("payments: stripe decode checkout session: %w", err)
		}
		return Event{ID: event.ID, Type: string(event.Type), ProviderRef: session.ID, Status: StatusFailed, Raw: rawBody}, nil

	default:
		return Event{ID: event.ID, Type: string(event.Type), Status: StatusIgnored, Raw: rawBody}, nil
	}
}

// decodeCheckoutSession re-marshals the generic event.Data.Object map into a
// typed CheckoutSession — stripe-go's Event type deliberately keeps this
// field untyped since its shape depends on event.Type.
func decodeCheckoutSession(obj map[string]interface{}) (*stripe.CheckoutSession, error) {
	raw, err := json.Marshal(obj)
	if err != nil {
		return nil, err
	}
	var session stripe.CheckoutSession
	if err := json.Unmarshal(raw, &session); err != nil {
		return nil, err
	}
	return &session, nil
}
