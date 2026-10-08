package ai

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/ratelimit"
	"github.com/redis/go-redis/v9"
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

// countingProvider counts the completions that actually reached the model.
type countingProvider struct {
	NoopProvider
	calls atomic.Int64
}

func (c *countingProvider) Complete(context.Context, CompletionRequest) (CompletionResponse, error) {
	c.calls.Add(1)
	return CompletionResponse{}, nil
}

// The quota is a sliding-window limiter (Redis, with an in-process fallback),
// not a DB counter. Pointing the real limiter at an unreachable Redis drives
// the production outage path: 60 concurrent callers against a budget of 7
// must let exactly 7 through to the model, never more.
func TestQuotaProvider_ConcurrentCallsNeverExceedLimit(t *testing.T) {
	const budget, callers = 7, 60
	rdb := redis.NewClient(&redis.Options{Addr: "127.0.0.1:1", MaxRetries: -1, DialTimeout: time.Second})
	t.Cleanup(func() { _ = rdb.Close() })
	inner := &countingProvider{}
	p := NewQuotaProvider(inner, ratelimit.New(rdb), budget, 1000)

	var rejected atomic.Int64
	var wg sync.WaitGroup
	start := make(chan struct{})
	for i := 0; i < callers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			ctx, _ := WithQuotaUser(context.Background(), "u-concurrent")
			if _, err := p.Complete(ctx, CompletionRequest{}); errors.Is(err, ErrQuotaExceeded) {
				rejected.Add(1)
			} else if err != nil {
				t.Errorf("unexpected error: %v", err)
			}
		}()
	}
	close(start)
	wg.Wait()

	if got := inner.calls.Load(); got != budget {
		t.Fatalf("model calls = %d, want exactly %d", got, budget)
	}
	if rejected.Load() != callers-budget {
		t.Fatalf("rejected = %d, want %d", rejected.Load(), callers-budget)
	}
}
