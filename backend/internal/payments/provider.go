// Package payments defines the seam a real payment gateway (Stripe,
// Razorpay, ...) implements later, without the mentoring/ticket logic that
// depends on it ever needing to change.
package payments

import "context"

// ChargeParams describes a single course-purchase charge request.
type ChargeParams struct {
	OrgID       string
	UserID      string
	CourseID    string
	AmountCents int
	Currency    string
}

// ChargeResult is the outcome of a successful charge.
type ChargeResult struct {
	ProviderRef string
	Status      string
}

// Provider charges a user for a course purchase. Implementations must either
// return a ChargeResult with Status "completed" (or another terminal status
// the caller understands) or a non-nil error — there is no pending/async path
// in v1.
type Provider interface {
	Charge(ctx context.Context, p ChargeParams) (ChargeResult, error)
}
