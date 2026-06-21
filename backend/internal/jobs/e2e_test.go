package jobs_test

import (
	"context"
	"errors"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/stretchr/testify/require"
)

// ─── DB setup ────────────────────────────────────────────────────────────────

func setupTestDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(func() { pool.Close() })
	return pool
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

// randomSuffix returns a nanosecond-resolution string suffix for unique naming.
func randomSuffix() string {
	return fmt.Sprintf("%d", time.Now().UnixNano())
}

// createTestOrg inserts a minimal organization and registers a cleanup. Returns the org UUID.
// The slug must satisfy the constraint ^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$.
// We produce "ta" + last-12-digits of UnixNano which is 14 chars total — always valid.
func createTestOrg(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	suffix := fmt.Sprintf("%012d", time.Now().UnixNano()%1_000_000_000_000)
	slug := "ta" + suffix
	name := "Test Org " + suffix

	var id string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO organizations (name, slug) VALUES ($1, $2) RETURNING id`,
		name, slug,
	).Scan(&id)
	require.NoError(t, err)

	t.Cleanup(func() {
		// Cascade on organizations removes jobs and org_job_quotas automatically,
		// but we do it explicitly to keep test isolation clear.
		pool.Exec(context.Background(), `DELETE FROM organizations WHERE id = $1`, id) //nolint:errcheck
	})
	return id
}

// setQuota upserts an org_job_quotas row and registers no additional cleanup
// because the row is cascade-deleted when the org is deleted.
func setQuota(t *testing.T, pool *pgxpool.Pool, orgID string, q jobs.Quota) {
	t.Helper()
	err := jobs.UpdateQuota(context.Background(), pool, orgID, q)
	require.NoError(t, err)
}

// setupRegistry builds a Registry pre-loaded with the given handlers.
func setupRegistry(handlers map[string]jobs.Handler) *jobs.Registry {
	r := jobs.NewRegistry()
	for k, h := range handlers {
		r.Register(k, h)
	}
	return r
}

// fakeHandler is a Handler whose error value is fixed at construction time.
type fakeHandler struct{ err error }

func (f *fakeHandler) Handle(_ context.Context, _ jobs.Job) error { return f.err }

// enqueueForOrg enqueues a job scoped to orgID using a fresh single-handler registry.
func enqueueForOrg(
	t *testing.T,
	pool *pgxpool.Pool,
	orgID, handlerKey string,
	priority jobs.Priority,
	maxRetries int,
) jobs.Job {
	t.Helper()
	reg := setupRegistry(map[string]jobs.Handler{handlerKey: &fakeHandler{}})
	p := jobs.EnqueueParams{
		Handler:    handlerKey,
		Priority:   priority,
		Payload:    map[string]string{"test": "true"},
		MaxRetries: &maxRetries,
		OrgID:      &orgID,
	}
	j, err := jobs.Enqueue(context.Background(), pool, reg, p)
	require.NoError(t, err)
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM jobs WHERE id = $1`, j.ID) //nolint:errcheck
	})
	return j
}

// resetRunAt forces a job's run_at to now so ClaimOne can pick it up immediately
// after a Fail call (which adds an exponential-backoff delay to run_at).
func resetRunAt(t *testing.T, pool *pgxpool.Pool, jobID string) {
	t.Helper()
	_, err := pool.Exec(context.Background(),
		`UPDATE jobs SET run_at = NOW() WHERE id = $1`, jobID,
	)
	require.NoError(t, err)
}

// jobStatus fetches only the status and retry_count of a job from the DB.
func jobStatus(t *testing.T, pool *pgxpool.Pool, jobID string) (status string, retryCount int) {
	t.Helper()
	err := pool.QueryRow(context.Background(),
		`SELECT status, retry_count FROM jobs WHERE id = $1`, jobID,
	).Scan(&status, &retryCount)
	require.NoError(t, err)
	return
}

// workerID is a fixed test worker name so ClaimOne calls are attributable.
const workerID = "test-worker-e2e"

// ─── Tests ───────────────────────────────────────────────────────────────────

// TestE2E_EnqueueAndClaim verifies the happy path: enqueue → claim → complete.
func TestE2E_EnqueueAndClaim(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	orgID := createTestOrg(t, pool)
	setQuota(t, pool, orgID, jobs.Quota{MaxConcurrent: 5, MaxQueued: 100, PriorityFloor: 5})

	const handlerKey = "e2e.enqueue_and_claim"
	j := enqueueForOrg(t, pool, orgID, handlerKey, jobs.PriorityNormal, 3)

	claimed, err := jobs.ClaimOne(ctx, pool, workerID)
	require.NoError(t, err)
	require.NotNil(t, claimed, "expected a claimed job")
	require.Equal(t, j.ID, claimed.Job.ID)
	require.Equal(t, jobs.StatusRunning, claimed.Job.Status)
	require.Equal(t, handlerKey, claimed.Job.Handler)
	require.NotEmpty(t, claimed.RunID)

	err = jobs.Complete(ctx, pool, claimed.Job.ID, claimed.RunID, 42)
	require.NoError(t, err)

	status, _ := jobStatus(t, pool, j.ID)
	require.Equal(t, jobs.StatusSuccess, status)
}

// TestE2E_RetryOnFailure verifies exponential-retry and eventual dead transition.
// max_retries=2: first fail → queued (retry_count=1), second fail → dead.
func TestE2E_RetryOnFailure(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	orgID := createTestOrg(t, pool)
	setQuota(t, pool, orgID, jobs.Quota{MaxConcurrent: 5, MaxQueued: 100, PriorityFloor: 5})

	const handlerKey = "e2e.retry_on_failure"
	j := enqueueForOrg(t, pool, orgID, handlerKey, jobs.PriorityNormal, 2)

	// First claim + fail — should re-queue with retry_count=1.
	claimed, err := jobs.ClaimOne(ctx, pool, workerID)
	require.NoError(t, err)
	require.NotNil(t, claimed)
	require.Equal(t, j.ID, claimed.Job.ID)

	err = jobs.Fail(ctx, pool, claimed.Job.ID, claimed.RunID, errors.New("first failure"), 10)
	require.NoError(t, err)

	status, retryCount := jobStatus(t, pool, j.ID)
	require.Equal(t, jobs.StatusQueued, status, "job should be re-queued after first failure")
	require.Equal(t, 1, retryCount, "retry_count should be 1 after first failure")

	// Reset run_at so ClaimOne can see it immediately (Fail adds backoff delay).
	resetRunAt(t, pool, j.ID)

	// Second claim + fail — retry_count+1 = 2 = max_retries → dead.
	claimed, err = jobs.ClaimOne(ctx, pool, workerID)
	require.NoError(t, err)
	require.NotNil(t, claimed)
	require.Equal(t, j.ID, claimed.Job.ID)

	err = jobs.Fail(ctx, pool, claimed.Job.ID, claimed.RunID, errors.New("second failure"), 10)
	require.NoError(t, err)

	status, _ = jobStatus(t, pool, j.ID)
	require.Equal(t, jobs.StatusDead, status, "job should be dead after exhausting max_retries")
}

// TestE2E_IdempotentEnqueue verifies that a second enqueue with the same
// idempotency key returns ErrDuplicateKey and leaves exactly one row in the DB.
func TestE2E_IdempotentEnqueue(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	orgID := createTestOrg(t, pool)
	setQuota(t, pool, orgID, jobs.Quota{MaxConcurrent: 5, MaxQueued: 100, PriorityFloor: 5})

	ikey := fmt.Sprintf("test-%d-idempotent", time.Now().UnixNano())
	const handlerKey = "e2e.idempotent_enqueue"
	reg := setupRegistry(map[string]jobs.Handler{handlerKey: &fakeHandler{}})
	maxRetries := 3

	first, err := jobs.Enqueue(ctx, pool, reg, jobs.EnqueueParams{
		Handler:        handlerKey,
		Priority:       jobs.PriorityNormal,
		Payload:        nil,
		MaxRetries:     &maxRetries,
		OrgID:          &orgID,
		IdempotencyKey: &ikey,
	})
	require.NoError(t, err)
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM jobs WHERE id = $1`, first.ID) //nolint:errcheck
	})

	_, err = jobs.Enqueue(ctx, pool, reg, jobs.EnqueueParams{
		Handler:        handlerKey,
		Priority:       jobs.PriorityNormal,
		Payload:        nil,
		MaxRetries:     &maxRetries,
		OrgID:          &orgID,
		IdempotencyKey: &ikey,
	})
	require.ErrorIs(t, err, jobs.ErrDuplicateKey, "second enqueue with same key must return ErrDuplicateKey")

	var count int
	err = pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM jobs WHERE idempotency_key = $1`, ikey,
	).Scan(&count)
	require.NoError(t, err)
	require.Equal(t, 1, count, "exactly one job row must exist for the idempotency key")
}

// TestE2E_QuotaEnforcement verifies that ClaimOne respects max_concurrent for
// low-priority (P4) jobs and returns nil once the quota is saturated.
func TestE2E_QuotaEnforcement(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	orgID := createTestOrg(t, pool)
	// max_concurrent=2 so the third P4 claim must be blocked.
	setQuota(t, pool, orgID, jobs.Quota{MaxConcurrent: 2, MaxQueued: 100, PriorityFloor: 5})

	const handlerKey = "e2e.quota_enforcement"
	reg := setupRegistry(map[string]jobs.Handler{handlerKey: &fakeHandler{}})
	maxRetries := 3

	var jobIDs []string
	for i := 0; i < 5; i++ {
		j, err := jobs.Enqueue(ctx, pool, reg, jobs.EnqueueParams{
			Handler:    handlerKey,
			Priority:   jobs.PriorityLow,
			Payload:    nil,
			MaxRetries: &maxRetries,
			OrgID:      &orgID,
		})
		require.NoError(t, err)
		jobIDs = append(jobIDs, j.ID)
	}
	t.Cleanup(func() {
		for _, id := range jobIDs {
			pool.Exec(context.Background(), `DELETE FROM jobs WHERE id = $1`, id) //nolint:errcheck
		}
	})

	// First two claims must succeed.
	c1, err := jobs.ClaimOne(ctx, pool, workerID)
	require.NoError(t, err)
	require.NotNil(t, c1, "first claim must succeed")

	c2, err := jobs.ClaimOne(ctx, pool, workerID)
	require.NoError(t, err)
	require.NotNil(t, c2, "second claim must succeed")

	// Third claim must be blocked: two P4 jobs are running for this org, quota=2.
	c3, err := jobs.ClaimOne(ctx, pool, workerID)
	require.NoError(t, err)
	require.Nil(t, c3, "third claim must be nil: quota saturated at max_concurrent=2")

	// Cleanup: complete the two running jobs so their rows can be deleted cleanly.
	_ = jobs.Complete(ctx, pool, c1.Job.ID, c1.RunID, 1)
	_ = jobs.Complete(ctx, pool, c2.Job.ID, c2.RunID, 1)
}

// TestE2E_PriorityBypassesQuota verifies that a P2 (PriorityHigh) job is claimed
// even when the org's concurrent quota is already saturated by P4 jobs.
// ClaimOne's SQL bypasses the quota check for priority <= 2.
func TestE2E_PriorityBypassesQuota(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	orgID := createTestOrg(t, pool)
	setQuota(t, pool, orgID, jobs.Quota{MaxConcurrent: 2, MaxQueued: 100, PriorityFloor: 5})

	const lowKey = "e2e.priority_bypass_low"
	const highKey = "e2e.priority_bypass_high"
	reg := setupRegistry(map[string]jobs.Handler{
		lowKey:  &fakeHandler{},
		highKey: &fakeHandler{},
	})
	maxRetries := 3

	// Enqueue and claim two P4 jobs to fill the quota.
	var lowJobIDs []string
	for i := 0; i < 2; i++ {
		j, err := jobs.Enqueue(ctx, pool, reg, jobs.EnqueueParams{
			Handler:    lowKey,
			Priority:   jobs.PriorityLow,
			Payload:    nil,
			MaxRetries: &maxRetries,
			OrgID:      &orgID,
		})
		require.NoError(t, err)
		lowJobIDs = append(lowJobIDs, j.ID)
	}
	t.Cleanup(func() {
		for _, id := range lowJobIDs {
			pool.Exec(context.Background(), `DELETE FROM jobs WHERE id = $1`, id) //nolint:errcheck
		}
	})

	c1, err := jobs.ClaimOne(ctx, pool, workerID)
	require.NoError(t, err)
	require.NotNil(t, c1)

	c2, err := jobs.ClaimOne(ctx, pool, workerID)
	require.NoError(t, err)
	require.NotNil(t, c2)

	// Enqueue the high-priority job after quota is saturated.
	highJob, err := jobs.Enqueue(ctx, pool, reg, jobs.EnqueueParams{
		Handler:    highKey,
		Priority:   jobs.PriorityHigh, // priority=2, bypasses quota
		Payload:    nil,
		MaxRetries: &maxRetries,
		OrgID:      &orgID,
	})
	require.NoError(t, err)
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM jobs WHERE id = $1`, highJob.ID) //nolint:errcheck
	})

	// P2 job must be claimed despite the concurrent limit being full.
	c3, err := jobs.ClaimOne(ctx, pool, workerID)
	require.NoError(t, err)
	require.NotNil(t, c3, "P2 job must bypass quota and be claimed")
	require.Equal(t, highJob.ID, c3.Job.ID, "claimed job must be the high-priority one")
	require.Equal(t, jobs.PriorityHigh, c3.Job.Priority)

	// Cleanup running jobs.
	_ = jobs.Complete(ctx, pool, c1.Job.ID, c1.RunID, 1)
	_ = jobs.Complete(ctx, pool, c2.Job.ID, c2.RunID, 1)
	_ = jobs.Complete(ctx, pool, c3.Job.ID, c3.RunID, 1)
}

// TestE2E_OrphanRecovery verifies that a job whose job_run heartbeat has gone
// stale is re-queued and has its retry_count incremented when Fail is called
// with the orphan error (mimicking what the scheduler's reapOrphans does).
func TestE2E_OrphanRecovery(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	orgID := createTestOrg(t, pool)
	setQuota(t, pool, orgID, jobs.Quota{MaxConcurrent: 5, MaxQueued: 100, PriorityFloor: 5})

	// Insert a job directly in 'running' state.
	var jobID string
	err := pool.QueryRow(ctx,
		`INSERT INTO jobs (handler, status, priority, payload, max_retries, retry_count, timeout_ms, org_id)
		 VALUES ('e2e.orphan', 'running', 3, '{}', 3, 0, 30000, $1)
		 RETURNING id`,
		orgID,
	).Scan(&jobID)
	require.NoError(t, err)
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM jobs WHERE id = $1`, jobID) //nolint:errcheck
	})

	// Insert a job_run with a stale heartbeat (5 minutes ago).
	var runID string
	err = pool.QueryRow(ctx,
		`INSERT INTO job_runs (job_id, status, attempt, worker_id, started_at, heartbeat_at)
		 VALUES ($1, 'running', 1, $2, NOW() - interval '5 minutes', NOW() - interval '5 minutes')
		 RETURNING id`,
		jobID, workerID,
	).Scan(&runID)
	require.NoError(t, err)

	// Run the same orphan detection query the scheduler uses (threshold: 2 minutes).
	const threshold = "2 minutes"
	rows, err := pool.Query(ctx,
		`SELECT j.id, jr.id AS run_id
		 FROM jobs j
		 JOIN job_runs jr ON jr.job_id = j.id
		 WHERE j.status = 'running'
		   AND jr.status = 'running'
		   AND jr.heartbeat_at < NOW() - $1::interval
		   AND j.deleted_at IS NULL`,
		threshold,
	)
	require.NoError(t, err)
	defer rows.Close()

	type orphan struct{ jobID, runID string }
	var orphans []orphan
	for rows.Next() {
		var o orphan
		require.NoError(t, rows.Scan(&o.jobID, &o.runID))
		orphans = append(orphans, o)
	}
	require.NoError(t, rows.Err())

	// Verify our test job was detected.
	found := false
	for _, o := range orphans {
		if o.jobID == jobID {
			found = true
		}
	}
	require.True(t, found, "orphan detection must find the stale job")

	// Reap: call Fail for each orphan just like the scheduler does.
	for _, o := range orphans {
		if o.jobID != jobID {
			continue
		}
		err = jobs.Fail(ctx, pool, o.jobID, o.runID, errors.New("orphan: worker heartbeat lost"), 0)
		require.NoError(t, err)
	}

	// Job must now be re-queued with retry_count incremented to 1.
	status, retryCount := jobStatus(t, pool, jobID)
	require.Equal(t, jobs.StatusQueued, status, "orphan must be re-queued")
	require.Equal(t, 1, retryCount, "retry_count must be 1 after orphan reap")
}

// TestE2E_CancelJob verifies that a queued job can be cancelled and will not
// be returned by a subsequent ClaimOne call.
func TestE2E_CancelJob(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	orgID := createTestOrg(t, pool)
	setQuota(t, pool, orgID, jobs.Quota{MaxConcurrent: 5, MaxQueued: 100, PriorityFloor: 5})

	const handlerKey = "e2e.cancel_job"
	j := enqueueForOrg(t, pool, orgID, handlerKey, jobs.PriorityNormal, 3)

	err := jobs.Cancel(ctx, pool, j.ID, &orgID)
	require.NoError(t, err)

	status, _ := jobStatus(t, pool, j.ID)
	require.Equal(t, jobs.StatusCancelled, status)

	// ClaimOne must not return the cancelled job.
	claimed, err := jobs.ClaimOne(ctx, pool, workerID)
	require.NoError(t, err)
	// Either nil (no other jobs) or a job with a different ID.
	if claimed != nil {
		require.NotEqual(t, j.ID, claimed.Job.ID, "cancelled job must not be claimed")
		// Cleanup any accidental claim.
		_ = jobs.Complete(ctx, pool, claimed.Job.ID, claimed.RunID, 1)
	}
}

// TestE2E_TenantIsolation verifies that GetByID scoped to orgA cannot retrieve
// a job belonging to orgB, while the same call scoped to orgB succeeds.
func TestE2E_TenantIsolation(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	orgAID := createTestOrg(t, pool)
	orgBID := createTestOrg(t, pool)

	setQuota(t, pool, orgAID, jobs.Quota{MaxConcurrent: 5, MaxQueued: 100, PriorityFloor: 5})
	setQuota(t, pool, orgBID, jobs.Quota{MaxConcurrent: 5, MaxQueued: 100, PriorityFloor: 5})

	const handlerKey = "e2e.tenant_isolation"
	j := enqueueForOrg(t, pool, orgBID, handlerKey, jobs.PriorityNormal, 3)

	// orgA must not see orgB's job.
	_, err := jobs.GetByID(ctx, pool, j.ID, &orgAID)
	require.ErrorIs(t, err, jobs.ErrJobNotFound, "orgA must not be able to retrieve orgB's job")

	// orgB must see its own job.
	got, err := jobs.GetByID(ctx, pool, j.ID, &orgBID)
	require.NoError(t, err)
	require.Equal(t, j.ID, got.ID)
}

// TestE2E_ForceRetry verifies that a dead job can be force-retried, resetting
// its status to queued and its retry_count to 0.
func TestE2E_ForceRetry(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	orgID := createTestOrg(t, pool)
	setQuota(t, pool, orgID, jobs.Quota{MaxConcurrent: 5, MaxQueued: 100, PriorityFloor: 5})

	// max_retries=1: first fail has retry_count=0 → 0+1=1 = max_retries → dead immediately.
	const handlerKey = "e2e.force_retry"
	j := enqueueForOrg(t, pool, orgID, handlerKey, jobs.PriorityNormal, 1)

	claimed, err := jobs.ClaimOne(ctx, pool, workerID)
	require.NoError(t, err)
	require.NotNil(t, claimed)
	require.Equal(t, j.ID, claimed.Job.ID)

	err = jobs.Fail(ctx, pool, claimed.Job.ID, claimed.RunID, errors.New("fatal error"), 5)
	require.NoError(t, err)

	status, _ := jobStatus(t, pool, j.ID)
	require.Equal(t, jobs.StatusDead, status, "job with max_retries=1 must die on first failure")

	// ForceRetry must reset the job to queued with retry_count=0.
	err = jobs.ForceRetry(ctx, pool, j.ID)
	require.NoError(t, err)

	status, retryCount := jobStatus(t, pool, j.ID)
	require.Equal(t, jobs.StatusQueued, status)
	require.Equal(t, 0, retryCount, "retry_count must be reset to 0 after ForceRetry")
}

// TestE2E_ListWithCursor verifies cursor-based pagination over a set of 5 jobs:
// page 1 (limit=2) → page 2 (limit=2) → page 3 (limit=2, returns 1 job, no cursor).
func TestE2E_ListWithCursor(t *testing.T) {
	pool := setupTestDB(t)
	ctx := context.Background()

	orgID := createTestOrg(t, pool)
	setQuota(t, pool, orgID, jobs.Quota{MaxConcurrent: 5, MaxQueued: 100, PriorityFloor: 5})

	const handlerKey = "e2e.list_cursor"
	reg := setupRegistry(map[string]jobs.Handler{handlerKey: &fakeHandler{}})
	maxRetries := 3

	var allIDs []string
	for i := 0; i < 5; i++ {
		// Small sleep to guarantee distinct created_at values for deterministic ordering.
		time.Sleep(2 * time.Millisecond)
		j, err := jobs.Enqueue(ctx, pool, reg, jobs.EnqueueParams{
			Handler:    handlerKey,
			Priority:   jobs.PriorityNormal,
			Payload:    nil,
			MaxRetries: &maxRetries,
			OrgID:      &orgID,
		})
		require.NoError(t, err)
		allIDs = append(allIDs, j.ID)
	}
	t.Cleanup(func() {
		for _, id := range allIDs {
			pool.Exec(context.Background(), `DELETE FROM jobs WHERE id = $1`, id) //nolint:errcheck
		}
	})

	// Page 1: limit=2.
	page1, cursor1, err := jobs.List(ctx, pool, jobs.ListFilter{
		OrgID: &orgID,
		Limit: 2,
	})
	require.NoError(t, err)
	require.Len(t, page1, 2, "page 1 must have exactly 2 jobs")
	require.NotEmpty(t, cursor1, "page 1 must return a next cursor")

	// Page 2: limit=2, starting after page 1.
	page2, cursor2, err := jobs.List(ctx, pool, jobs.ListFilter{
		OrgID: &orgID,
		Limit: 2,
		After: cursor1,
	})
	require.NoError(t, err)
	require.Len(t, page2, 2, "page 2 must have exactly 2 jobs")
	require.NotEmpty(t, cursor2, "page 2 must return a next cursor")

	// Page 1 and page 2 must be disjoint.
	page1IDs := map[string]bool{page1[0].ID: true, page1[1].ID: true}
	for _, j := range page2 {
		require.False(t, page1IDs[j.ID], "page 2 must not overlap with page 1")
	}

	// Page 3: limit=2, starting after page 2 — only 1 job left, no cursor.
	page3, cursor3, err := jobs.List(ctx, pool, jobs.ListFilter{
		OrgID: &orgID,
		Limit: 2,
		After: cursor2,
	})
	require.NoError(t, err)
	require.Len(t, page3, 1, "page 3 must have exactly 1 job (the last remaining)")
	require.Empty(t, cursor3, "page 3 must have no next cursor (end of results)")

	// All 5 jobs must appear exactly once across all three pages.
	seen := map[string]bool{}
	for _, j := range append(append(page1, page2...), page3...) {
		require.False(t, seen[j.ID], "each job must appear exactly once across pages")
		seen[j.ID] = true
	}
	for _, id := range allIDs {
		require.True(t, seen[id], "all enqueued jobs must appear in paginated results")
	}
}
