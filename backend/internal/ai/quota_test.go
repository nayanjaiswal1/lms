package ai

import (
	"context"
	"errors"
	"testing"
	"time"
)

type countingAllower struct{ n, max int }

func (c *countingAllower) Allow(context.Context, string, int, time.Duration) (bool, time.Duration) {
	c.n++
	return c.n <= c.max, time.Minute
}

func TestQuotaProvider_BlocksOverBudgetAndTripsRequest(t *testing.T) {
	p := NewQuotaProvider(&NoopProvider{}, &countingAllower{max: 2}, 1, 1)
	ctx, trip := WithQuotaUser(context.Background(), "u1")

	// Noop inner returns ErrAIDisabled, which proves the call was delegated.
	if _, err := p.Complete(ctx, CompletionRequest{}); !errors.Is(err, ErrAIDisabled) {
		t.Fatalf("first call should reach provider, got %v", err)
	}
	if trip.Tripped() {
		t.Fatal("trip set while within budget")
	}
	if _, err := p.Complete(ctx, CompletionRequest{}); !errors.Is(err, ErrQuotaExceeded) {
		t.Fatalf("over-budget call must be rejected, got %v", err)
	}
	if !trip.Tripped() {
		t.Fatal("trip not set after rejection")
	}
}

func TestQuotaProvider_UnattributedCallsAreNotMetered(t *testing.T) {
	a := &countingAllower{max: 0}
	p := NewQuotaProvider(&NoopProvider{}, a, 1, 1)
	if _, err := p.Complete(context.Background(), CompletionRequest{}); !errors.Is(err, ErrAIDisabled) || a.n != 0 {
		t.Fatalf("background call should skip quota, err=%v spent=%d", err, a.n)
	}
}
