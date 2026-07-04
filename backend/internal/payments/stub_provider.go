package payments

import (
	"context"

	"github.com/google/uuid"
)

// StubProvider simulates an instant, always-successful charge with no
// external call. It is the default Provider until a real gateway
// (Stripe/Razorpay) is wired in — course_purchases.provider/provider_ref are
// shaped so that swap requires no schema change, only a new Provider impl.
type StubProvider struct{}

// NewStubProvider constructs a StubProvider.
func NewStubProvider() *StubProvider {
	return &StubProvider{}
}

// Charge always succeeds immediately, returning a synthetic provider reference.
func (p *StubProvider) Charge(ctx context.Context, params ChargeParams) (ChargeResult, error) {
	return ChargeResult{
		ProviderRef: "stub_" + uuid.NewString(),
		Status:      "completed",
	}, nil
}
