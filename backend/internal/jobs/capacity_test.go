package jobs

import (
	"context"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/testdb"
)

// Regression: a burst of long-running lab build jobs (no org, so no per-org
// cap) could occupy every worker slot. With a per-handler cap, a capped
// handler at its limit is skipped and another handler's job is claimed even
// though the capped one has higher priority.
func TestClaimOneCappedSkipsHandlerAtCap(t *testing.T) {
	ctx := context.Background()
	pool := testdb.New(t)
	if _, err := pool.Exec(ctx, `
		INSERT INTO jobs (handler, status, priority) VALUES
		  ('lab.recipe_build', 'running', 5),
		  ('lab.recipe_build', 'queued', 1),
		  ('email.send', 'queued', 4)`); err != nil {
		t.Fatalf("seed: %v", err)
	}
	reg := NewRegistry()
	reg.SetMaxConcurrent("lab.recipe_build", 1)

	claimed, err := ClaimOneCapped(ctx, pool, "w1", reg)
	if err != nil || claimed == nil {
		t.Fatalf("claim: %v %v", claimed, err)
	}
	if claimed.Job.Handler != "email.send" {
		t.Fatalf("claimed %s, want email.send (lab.recipe_build is at its cap)", claimed.Job.Handler)
	}
	if again, err := ClaimOneCapped(ctx, pool, "w1", reg); err != nil || again != nil {
		t.Fatalf("second claim = %v, %v; want nothing (capped)", again, err)
	}
}

// executeInterrupted claims a job of handler, runs it in a worker whose
// context is cancelled mid-handler (a shutdown), and returns the job's status
// and retry_count afterwards.
func executeInterrupted(t *testing.T, resumable bool) (string, int) {
	t.Helper()
	ctx := context.Background()
	pool := testdb.New(t)
	if _, err := pool.Exec(ctx,
		`INSERT INTO jobs (handler, status, priority, max_retries) VALUES ('lab.recipe_build', 'queued', 3, 2)`); err != nil {
		t.Fatalf("seed: %v", err)
	}
	reg := NewRegistry()
	started := make(chan struct{})
	reg.Register("lab.recipe_build", handlerFunc(func(ctx context.Context, _ Job) error {
		close(started)
		<-ctx.Done()
		return ctx.Err()
	}))
	if resumable {
		reg.SetResumable("lab.recipe_build")
	}
	claimed, err := ClaimOneCapped(ctx, pool, "w1", reg)
	if err != nil || claimed == nil {
		t.Fatalf("claim: %v %v", claimed, err)
	}
	wp := NewWorkerPool(pool, nil, reg, &config.Config{WorkerHeartbeatInterval: time.Hour}, "w1")
	wctx, shutdown := context.WithCancel(ctx)
	done := make(chan struct{})
	go func() { wp.executeJob(wctx, 1, claimed); close(done) }()
	<-started
	shutdown()
	<-done

	var status string
	var retries int
	if err := pool.QueryRow(ctx, `SELECT status, retry_count FROM jobs WHERE id = $1`, claimed.Job.ID).Scan(&status, &retries); err != nil {
		t.Fatalf("read job: %v", err)
	}
	return status, retries
}

// Regression: a job interrupted by shutdown (deploy, air reload) was left
// running for the orphan reaper, whose Fail consumed a retry - two reloads
// killed a healthy lab build. A resumable handler is requeued at once without
// consuming a retry.
func TestShutdownRequeuesResumableJobWithoutRetry(t *testing.T) {
	status, retries := executeInterrupted(t, true)
	if status != StatusQueued || retries != 0 {
		t.Fatalf("status=%s retry_count=%d, want queued/0", status, retries)
	}
}

// Control: a handler not marked resumable keeps the conservative path (left
// running for the orphan reaper).
func TestShutdownLeavesNonResumableJobForReaper(t *testing.T) {
	status, _ := executeInterrupted(t, false)
	if status != StatusRunning {
		t.Fatalf("status=%s, want running (reaper path)", status)
	}
}

type handlerFunc func(ctx context.Context, job Job) error

func (f handlerFunc) Handle(ctx context.Context, job Job) error { return f(ctx, job) }
