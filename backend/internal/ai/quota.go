package ai

import (
	"context"
	"errors"
	"sync/atomic"
	"time"
)

// ErrQuotaExceeded is returned by a QuotaProvider when the calling user has
// used up their LLM budget.
var ErrQuotaExceeded = errors.New("ai: user quota exceeded")

// Allower is the sliding-window limiter a QuotaProvider spends from.
// *ratelimit.Limiter satisfies it.
type Allower interface {
	Allow(ctx context.Context, key string, max int, window time.Duration) (bool, time.Duration)
}

// QuotaTrip records, per request, that the quota rejected an LLM call, so the
// HTTP layer can answer 429 whatever error the calling handler chose to
// surface.
type QuotaTrip struct{ tripped atomic.Bool }

// Tripped reports whether a call in this request was rejected by the quota.
func (t *QuotaTrip) Tripped() bool { return t.tripped.Load() }

type quotaCtxKey struct{}

type quotaCtx struct {
	userID string
	trip   *QuotaTrip
}

// WithQuotaUser attributes LLM calls made with the returned context to userID
// and returns the trip recorder for the request. Calls without a user (background
// jobs) are not metered here.
func WithQuotaUser(ctx context.Context, userID string) (context.Context, *QuotaTrip) {
	trip := &QuotaTrip{}
	return context.WithValue(ctx, quotaCtxKey{}, quotaCtx{userID: userID, trip: trip}), trip
}

// QuotaProvider wraps an LLMProvider with a per-user hourly and daily call cap.
type QuotaProvider struct {
	LLMProvider
	limiter Allower
	perHour int
	perDay  int
}

// NewQuotaProvider caps each user at perHour and perDay completions.
func NewQuotaProvider(inner LLMProvider, limiter Allower, perHour, perDay int) *QuotaProvider {
	return &QuotaProvider{LLMProvider: inner, limiter: limiter, perHour: perHour, perDay: perDay}
}

// Complete spends one unit of the caller's quota before delegating.
func (q *QuotaProvider) Complete(ctx context.Context, req CompletionRequest) (CompletionResponse, error) {
	if qc, ok := ctx.Value(quotaCtxKey{}).(quotaCtx); ok {
		hourOK, _ := q.limiter.Allow(ctx, "llm:h:"+qc.userID, q.perHour, time.Hour)
		dayOK := false
		if hourOK {
			dayOK, _ = q.limiter.Allow(ctx, "llm:d:"+qc.userID, q.perDay, 24*time.Hour)
		}
		if !hourOK || !dayOK {
			qc.trip.tripped.Store(true)
			return CompletionResponse{}, ErrQuotaExceeded
		}
	}
	return q.LLMProvider.Complete(ctx, req)
}
