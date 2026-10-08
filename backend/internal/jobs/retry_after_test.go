package jobs_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/testdb"
)

// failOnce inserts a queued job with maxRetries, claims it, fails it with
// jobErr, and returns the resulting status, retry_count and seconds until run_at.
func failOnce(t *testing.T, maxRetries int, jobErr error) (status string, retryCount int, runInSecs float64) {
	t.Helper()
	ctx := context.Background()
	pool := testdb.New(t)
	if _, err := pool.Exec(ctx,
		`INSERT INTO jobs (handler, status, priority, max_retries) VALUES ('email.send', 'queued', 2, $1)`, maxRetries); err != nil {
		t.Fatalf("seed job: %v", err)
	}
	claimed, err := jobs.ClaimOne(ctx, pool, "w1")
	if err != nil || claimed == nil {
		t.Fatalf("claim: %v %v", claimed, err)
	}
	if err := jobs.Fail(ctx, pool, nil, claimed.Job.ID, claimed.RunID, jobErr, 5); err != nil {
		t.Fatalf("Fail: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`SELECT status, retry_count, EXTRACT(EPOCH FROM run_at - now()) FROM jobs WHERE id = $1`, claimed.Job.ID,
	).Scan(&status, &retryCount, &runInSecs); err != nil {
		t.Fatalf("read job: %v", err)
	}
	return status, retryCount, runInSecs
}

func TestFailPlainErrorAtLastRetryGoesDead(t *testing.T) {
	if status, _, _ := failOnce(t, 1, errors.New("boom")); status != "dead" {
		t.Fatalf("control: plain error on final retry should be dead, got %s", status)
	}
}

func TestFailRetryAfterDefersWithoutConsumingRetry(t *testing.T) {
	// max_retries=1 would kill a plain error; RetryAfter must requeue instead,
	// with the requested (much longer than 2s exponential) delay.
	status, retryCount, runIn := failOnce(t, 1, jobs.RetryAfter(errors.New("throttled"), 10*time.Minute))
	if status != "queued" {
		t.Fatalf("status = %s, want queued", status)
	}
	if retryCount != 0 {
		t.Fatalf("retry_count = %d, want 0 (deferral must not consume a retry)", retryCount)
	}
	if runIn < 9*60 || runIn > 10*60+5 {
		t.Fatalf("run_at in %.0fs, want ~600s", runIn)
	}
}
