package ratelimit

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log/slog"
	"time"

	"github.com/redis/go-redis/v9"
)

// Semaphore is a distributed counting semaphore over Redis: at most `limit`
// leases per key across every process. Unlike Limiter it never falls back to
// in-process state - a shared cap that silently became per-replica would break
// at two replicas - so a Redis error is returned to the caller.
//
// Leases are members of a sorted set scored by their expiry time. A lease must
// be renewed (Lease does this itself, every ttl/3) or it lapses, so a crashed
// holder frees its slot after at most one ttl instead of leaking it.

// acquireScript: KEYS[1]=key ARGV[1]=now ms, ARGV[2]=ttl ms, ARGV[3]=limit,
// ARGV[4]=lease id. Returns 1 if the lease was taken, 0 if the semaphore is full.
const acquireScript = `
redis.call('ZREMRANGEBYSCORE', KEYS[1], 0, tonumber(ARGV[1]))
if redis.call('ZCARD', KEYS[1]) < tonumber(ARGV[3]) then
    redis.call('ZADD', KEYS[1], tonumber(ARGV[1]) + tonumber(ARGV[2]), ARGV[4])
    redis.call('PEXPIRE', KEYS[1], tonumber(ARGV[2]))
    return 1
end
return 0
`

// renewScript extends a lease only if it is still held (not yet expired and
// reaped). Returns 1 if renewed, 0 if the lease was lost.
const renewScript = `
if redis.call('ZSCORE', KEYS[1], ARGV[3]) == false then
    return 0
end
redis.call('ZADD', KEYS[1], 'XX', tonumber(ARGV[1]) + tonumber(ARGV[2]), ARGV[3])
redis.call('PEXPIRE', KEYS[1], tonumber(ARGV[2]) * 2)
return 1
`

// Semaphore hands out leases. Construct with NewSemaphore.
type Semaphore struct {
	rdb     *redis.Client
	acquire *redis.Script
	renew   *redis.Script
}

// NewSemaphore returns a Semaphore over rdb.
func NewSemaphore(rdb *redis.Client) *Semaphore {
	return &Semaphore{rdb: rdb, acquire: redis.NewScript(acquireScript), renew: redis.NewScript(renewScript)}
}

// Lease is one held semaphore slot. Ctx is cancelled if the lease is lost
// (Redis lost it, or renewal kept failing past the ttl), so work guarded by the
// lease stops rather than running unmetered. Call Release exactly once.
type Lease struct {
	Ctx    context.Context
	sem    *Semaphore
	key    string
	id     string
	cancel context.CancelFunc
	done   chan struct{}
}

// TryAcquire takes a lease on key if fewer than limit are held, else returns
// (nil, nil). It never blocks: callers that find it full reschedule themselves
// instead of spinning. ttl bounds how long a crashed holder can occupy a slot.
func (s *Semaphore) TryAcquire(ctx context.Context, key string, limit int, ttl time.Duration) (*Lease, error) {
	var raw [12]byte
	if _, err := rand.Read(raw[:]); err != nil {
		return nil, fmt.Errorf("ratelimit.Semaphore.TryAcquire: id: %w", err)
	}
	id := hex.EncodeToString(raw[:])
	got, err := s.acquire.Run(ctx, s.rdb, []string{key}, time.Now().UnixMilli(), ttl.Milliseconds(), limit, id).Int64()
	if err != nil {
		return nil, fmt.Errorf("ratelimit.Semaphore.TryAcquire: %w", err)
	}
	if got == 0 {
		return nil, nil
	}
	lctx, cancel := context.WithCancel(ctx)
	l := &Lease{Ctx: lctx, sem: s, key: key, id: id, cancel: cancel, done: make(chan struct{})}
	go l.heartbeat(ttl)
	return l, nil
}

// heartbeat renews the lease every ttl/3. If it is lost, or renewal has been
// failing for a whole ttl, the lease context is cancelled.
func (l *Lease) heartbeat(ttl time.Duration) {
	defer close(l.done)
	tick := time.NewTicker(ttl / 3)
	defer tick.Stop()
	lastOK := time.Now()
	for {
		select {
		case <-l.Ctx.Done():
			return
		case <-tick.C:
			got, err := l.sem.renew.Run(l.Ctx, l.sem.rdb, []string{l.key}, time.Now().UnixMilli(), ttl.Milliseconds(), l.id).Int64()
			switch {
			case err == nil && got == 1:
				lastOK = time.Now()
			case err == nil:
				slog.Warn("ratelimit.Semaphore: lease lost", "key", l.key)
				l.cancel()
				return
			case time.Since(lastOK) >= ttl:
				slog.Warn("ratelimit.Semaphore: lease renewal failing, giving up", "key", l.key, "error", err)
				l.cancel()
				return
			}
		}
	}
}

// Release frees the slot and stops the heartbeat. Safe with a cancelled parent
// context: the release itself uses a fresh, short-lived one.
func (l *Lease) Release() {
	l.cancel()
	<-l.done
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := l.sem.rdb.ZRem(ctx, l.key, l.id).Err(); err != nil {
		slog.Warn("ratelimit.Semaphore: release failed (lease will expire)", "key", l.key, "error", err)
	}
}
