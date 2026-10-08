package mailer

import (
	"context"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	breakerFailsKey = "mailer:breaker:fails"
	breakerOpenKey  = "mailer:breaker:open"
)

// Breaker pauses outbound email after a run of consecutive transient/throttle
// failures, so a throttled or down relay is not hammered by every queued job
// (each of which would otherwise burn a retry and extend the throttle).
//
// State lives in Redis so every replica sees the same breaker. If Redis is
// unreachable it degrades to per-process state (best-effort: each replica then
// trips on its own failures), mirroring internal/ratelimit.
type Breaker struct {
	rdb       *redis.Client
	threshold int
	cooldown  time.Duration

	mu        sync.Mutex
	fails     int
	openUntil time.Time
}

// NewBreaker opens after threshold consecutive failures and stays open for
// cooldown. rdb may be nil for process-local state only.
func NewBreaker(rdb *redis.Client, threshold int, cooldown time.Duration) *Breaker {
	return &Breaker{rdb: rdb, threshold: threshold, cooldown: cooldown}
}

// Remaining returns how long sends should stay paused, or 0 when closed.
func (b *Breaker) Remaining(ctx context.Context) time.Duration {
	if b.rdb != nil {
		if ttl, err := b.rdb.PTTL(ctx, breakerOpenKey).Result(); err == nil {
			if ttl > 0 {
				return ttl
			}
			return 0
		}
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	if d := time.Until(b.openUntil); d > 0 {
		return d
	}
	return 0
}

// Record feeds one send outcome in: a transient failure counts toward opening,
// a success resets the run, and a permanent (per-message) failure is ignored.
func (b *Breaker) Record(ctx context.Context, err error) {
	if err != nil && !IsTransient(err) {
		return
	}
	if err == nil {
		b.reset(ctx)
		return
	}
	b.fail(ctx)
}

func (b *Breaker) reset(ctx context.Context) {
	if b.rdb != nil && b.rdb.Del(ctx, breakerFailsKey).Err() == nil {
		return
	}
	b.mu.Lock()
	b.fails = 0
	b.mu.Unlock()
}

func (b *Breaker) fail(ctx context.Context) {
	if b.rdb != nil {
		n, err := b.rdb.Incr(ctx, breakerFailsKey).Result()
		if err == nil {
			_ = b.rdb.Expire(ctx, breakerFailsKey, b.cooldown*2).Err()
			if int(n) >= b.threshold {
				if b.rdb.Set(ctx, breakerOpenKey, 1, b.cooldown).Err() == nil {
					_ = b.rdb.Del(ctx, breakerFailsKey).Err()
					return
				}
			} else {
				return
			}
		}
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	b.fails++
	if b.fails >= b.threshold {
		b.openUntil = time.Now().Add(b.cooldown)
		b.fails = 0
	}
}
