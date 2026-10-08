package jobs_test

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/stretchr/testify/require"
)

// TestFail_AnyDeadHooksFireAndPanicDoesNotAffectFail proves OnAnyDead hooks run
// alongside the per-handler hook with full retry info, and that a panicking
// hook never makes Fail error or stops the other hooks.
func TestFail_AnyDeadHooksFireAndPanicDoesNotAffectFail(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()

	var jobID string
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO jobs (handler, status, max_retries, retry_count) VALUES ('h.test', 'running', 2, 1) RETURNING id`).Scan(&jobID))
	var runID int64
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO job_runs (job_id, status, worker_id) VALUES ($1, 'running', 'w') RETURNING id`, jobID).Scan(&runID))

	reg := jobs.NewRegistry()
	got := make(chan jobs.Job, 2)
	var perHandler atomic.Bool
	reg.OnDead("h.test", func(context.Context, jobs.Job) { perHandler.Store(true) })
	reg.OnAnyDead(func(context.Context, jobs.Job) { panic("hook exploded") })
	reg.OnAnyDead(func(_ context.Context, j jobs.Job) { got <- j })

	require.NoError(t, jobs.Fail(ctx, pool, reg, jobID, runID, errors.New("fatal"), 1))

	select {
	case j := <-got:
		require.Equal(t, "h.test", j.Handler)
		require.Equal(t, 2, j.RetryCount)
		require.Equal(t, 2, j.MaxRetries)
		require.NotNil(t, j.LastError)
	case <-time.After(5 * time.Second):
		t.Fatal("any-dead hook did not fire")
	}
	require.Eventually(t, perHandler.Load, 5*time.Second, 10*time.Millisecond)

	var status string
	require.NoError(t, pool.QueryRow(ctx, `SELECT status FROM jobs WHERE id = $1`, jobID).Scan(&status))
	require.Equal(t, "dead", status)
}
