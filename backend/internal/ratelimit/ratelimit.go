// Package ratelimit provides the sliding-window limiter shared by the HTTP
// middleware (per client IP) and by handlers that need a second, account-scoped
// limit on the same request.
//
// It lives in its own package rather than in internal/middleware because
// internal/middleware imports internal/auth, so the auth handlers cannot import
// it back without a cycle.
package ratelimit

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
)

// slidingWindowScript atomically implements a sliding-window rate limiter using
// a Redis sorted set. It removes expired entries, checks the current count, and
// either admits the request (ZADD + PEXPIRE) or rejects it.
//
// KEYS[1]  = rate limit key
// ARGV[1]  = current Unix time in milliseconds
// ARGV[2]  = window size in milliseconds
// ARGV[3]  = max requests per window
// ARGV[4]  = unique member (nanosecond timestamp) — prevents score collisions
//
// Returns 0 if allowed, 1 if rate-limited.
const slidingWindowScript = `
local key    = KEYS[1]
local now    = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local max    = tonumber(ARGV[3])
local member = ARGV[4]
local cutoff = now - window
redis.call('ZREMRANGEBYSCORE', key, 0, cutoff)
local count = redis.call('ZCARD', key)
if count < max then
    redis.call('ZADD', key, now, member)
    redis.call('PEXPIRE', key, window)
    return 0
end
return 1
`

// Limiter enforces a sliding-window request limit, backed by Redis for atomic,
// distributed accounting and falling back to an in-process window when Redis is
// unreachable so an outage degrades to per-replica enforcement rather than to
// no enforcement at all.
type Limiter struct {
	rdb      *redis.Client
	script   *redis.Script
	fallback *inMemorySlidingWindow
}

// New constructs a Limiter over the given Redis client.
func New(rdb *redis.Client) *Limiter {
	return &Limiter{
		rdb:      rdb,
		script:   redis.NewScript(slidingWindowScript),
		fallback: newInMemorySlidingWindow(),
	}
}

// Allow reports whether the request identified by key may proceed, consuming
// one slot from its window when it may.
func (l *Limiter) Allow(ctx context.Context, key string, max int, window time.Duration) bool {
	now := time.Now()
	windowMs := window.Milliseconds()
	// Nanosecond precision as member prevents score collisions under bursts.
	member := fmt.Sprintf("%d", now.UnixNano())

	result, err := l.script.Run(ctx, l.rdb, []string{key},
		now.UnixMilli(), windowMs, max, member,
	).Int64()
	if err != nil {
		return l.fallback.allow(key, max, windowMs)
	}
	return result == 0
}

// inMemorySlidingWindow is a goroutine-safe in-process sliding window used as
// the fallback when Redis is unreachable.
type inMemorySlidingWindow struct {
	mu      sync.Mutex
	buckets map[string][]int64 // key -> Unix ms timestamps, ascending
	lastGC  time.Time
}

func newInMemorySlidingWindow() *inMemorySlidingWindow {
	return &inMemorySlidingWindow{buckets: make(map[string][]int64), lastGC: time.Now()}
}

func (s *inMemorySlidingWindow) allow(key string, max int, windowMs int64) bool {
	now := time.Now().UnixMilli()
	cutoff := now - windowMs
	s.mu.Lock()
	defer s.mu.Unlock()

	s.gcLocked(now, windowMs)

	ts := s.buckets[key]
	// Evict entries that have fallen outside the window.
	i := 0
	for i < len(ts) && ts[i] <= cutoff {
		i++
	}
	ts = ts[i:]
	if len(ts) >= max {
		s.buckets[key] = ts
		return false
	}
	s.buckets[key] = append(ts, now)
	return true
}

// gcLocked drops fully-expired buckets. Without it the map grows without bound
// during a Redis outage, since every distinct key (and the account-scoped keys
// are attacker-chosen) leaves an entry behind forever. Runs at most once a
// minute so the common path stays O(1).
func (s *inMemorySlidingWindow) gcLocked(nowMs, windowMs int64) {
	now := time.Now()
	if now.Sub(s.lastGC) < time.Minute {
		return
	}
	s.lastGC = now
	cutoff := nowMs - windowMs
	for k, ts := range s.buckets {
		if len(ts) == 0 || ts[len(ts)-1] <= cutoff {
			delete(s.buckets, k)
		}
	}
}
