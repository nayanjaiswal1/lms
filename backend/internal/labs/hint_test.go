package labs

import (
	"context"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
)

// ─── hintCacheKey ────────────────────────────────────────────────────────────

func TestHintCacheKey_DeterministicAndUnique(t *testing.T) {
	a := hintCacheKey("session-1", "task-1", 1)
	b := hintCacheKey("session-1", "task-1", 1)
	if a != b {
		t.Fatalf("not deterministic: %q != %q", a, b)
	}
	if a == "" {
		t.Fatal("cache key must not be empty")
	}

	cases := []string{
		hintCacheKey("session-2", "task-1", 1), // different session
		hintCacheKey("session-1", "task-2", 1), // different task
		hintCacheKey("session-1", "task-1", 2), // different level
	}
	for i, c := range cases {
		if c == a {
			t.Fatalf("case %d: expected a different cache key, got the same as the base case", i)
		}
	}
}

// ─── buildHintUserPrompt ─────────────────────────────────────────────────────

func TestBuildHintUserPrompt_IncludesContextAndNeverLeaksScript(t *testing.T) {
	task := &TaskSnapshot{
		Title:              "Fix the failing health check",
		Description:        "The /health endpoint returns 500.",
		VerificationScript: "SECRET_VERIFICATION_LOGIC_DO_NOT_LEAK",
		HintContext:        "Check the DB connection pool settings.",
		ExplanationContext: "unrelated",
	}
	prompt := buildHintUserPrompt(task, 2, 4)

	for _, want := range []string{task.Title, task.Description, task.HintContext, "2 of 3", "attempt count so far: 4"} {
		if !contains(prompt, want) {
			t.Errorf("prompt missing expected content %q\nprompt:\n%s", want, prompt)
		}
	}
	if contains(prompt, task.VerificationScript) {
		t.Fatal("prompt must never include the verification script")
	}
}

func TestBuildHintUserPrompt_OmitsEmptyHintContext(t *testing.T) {
	task := &TaskSnapshot{Title: "T", Description: "D", HintContext: ""}
	prompt := buildHintUserPrompt(task, 1, 0)
	if contains(prompt, "Instructor's hint context") {
		t.Fatal("must not mention hint context section when none is authored")
	}
}

func contains(haystack, needle string) bool {
	return len(needle) == 0 || (len(haystack) >= len(needle) && indexOf(haystack, needle) >= 0)
}

func indexOf(haystack, needle string) int {
	for i := 0; i+len(needle) <= len(haystack); i++ {
		if haystack[i:i+len(needle)] == needle {
			return i
		}
	}
	return -1
}

// ─── AI circuit breaker (docs/labs.md "Runaway AI retry storms") ────────────

// fakeRedis is a minimal in-memory stand-in for the 5 redisClient methods
// the circuit breaker uses — no real Redis needed to test the breaker's
// pure state-transition logic.
type fakeRedis struct {
	counters map[string]int64
	exists   map[string]bool
}

func newFakeRedis() *fakeRedis {
	return &fakeRedis{counters: map[string]int64{}, exists: map[string]bool{}}
}

func (f *fakeRedis) Exists(ctx context.Context, keys ...string) *redis.IntCmd {
	cmd := redis.NewIntCmd(ctx)
	var n int64
	for _, k := range keys {
		if f.exists[k] {
			n++
		}
	}
	cmd.SetVal(n)
	return cmd
}

func (f *fakeRedis) Incr(ctx context.Context, key string) *redis.IntCmd {
	cmd := redis.NewIntCmd(ctx)
	f.counters[key]++
	cmd.SetVal(f.counters[key])
	return cmd
}

func (f *fakeRedis) Expire(ctx context.Context, key string, expiration time.Duration) *redis.BoolCmd {
	cmd := redis.NewBoolCmd(ctx)
	cmd.SetVal(true)
	return cmd
}

func (f *fakeRedis) Set(ctx context.Context, key string, value any, expiration time.Duration) *redis.StatusCmd {
	cmd := redis.NewStatusCmd(ctx)
	f.exists[key] = true
	cmd.SetVal("OK")
	return cmd
}

func (f *fakeRedis) Del(ctx context.Context, keys ...string) *redis.IntCmd {
	cmd := redis.NewIntCmd(ctx)
	var n int64
	for _, k := range keys {
		if _, ok := f.counters[k]; ok {
			delete(f.counters, k)
			n++
		}
		delete(f.exists, k)
	}
	cmd.SetVal(n)
	return cmd
}

func TestAICircuitBreaker_OpensAfterThreshold(t *testing.T) {
	ctx := context.Background()
	rdb := newFakeRedis()

	if aiCircuitOpen(ctx, rdb) {
		t.Fatal("circuit must start closed")
	}
	for i := 0; i < AICircuitFailureThreshold-1; i++ {
		recordAIFailure(ctx, rdb)
		if aiCircuitOpen(ctx, rdb) {
			t.Fatalf("circuit opened after only %d failures, threshold is %d", i+1, AICircuitFailureThreshold)
		}
	}
	recordAIFailure(ctx, rdb) // Nth failure trips it
	if !aiCircuitOpen(ctx, rdb) {
		t.Fatalf("circuit did not open after %d consecutive failures", AICircuitFailureThreshold)
	}
}

func TestAICircuitBreaker_SuccessResetsFailureCount(t *testing.T) {
	ctx := context.Background()
	rdb := newFakeRedis()

	recordAIFailure(ctx, rdb)
	recordAIFailure(ctx, rdb)
	recordAISuccess(ctx, rdb) // resets the consecutive counter
	recordAIFailure(ctx, rdb)
	recordAIFailure(ctx, rdb)

	if aiCircuitOpen(ctx, rdb) {
		t.Fatal("circuit must not open when failures are not consecutive (a success reset the streak)")
	}
}

// ─── penalizedPoints ─────────────────────────────────────────────────────────

func TestPenalizedPoints(t *testing.T) {
	cases := []struct{ points, hints, pct, want int }{
		{100, 0, 10, 100}, // no hints, no penalty
		{100, 2, 0, 100},  // authored default: hints are free
		{100, 1, 10, 90},
		{100, 3, 10, 70},
		{50, 2, 25, 25},
		{100, 3, 50, 0}, // floors at zero, never negative
	}
	for _, c := range cases {
		if got := penalizedPoints(c.points, c.hints, c.pct); got != c.want {
			t.Errorf("penalizedPoints(%d,%d,%d) = %d, want %d", c.points, c.hints, c.pct, got, c.want)
		}
	}
}
