package jobs

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

// ─── cursor helpers ───────────────────────────────────────────────────────────

func encodeCursor(createdAt time.Time, id string) string {
	raw := fmt.Sprintf("%d:%s", createdAt.UnixMicro(), id)
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

func decodeCursor(cursor string) (time.Time, string, error) {
	if cursor == "" {
		return time.Time{}, "", nil
	}
	b, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, "", fmt.Errorf("jobs: decode cursor: base64: %w", err)
	}
	parts := strings.SplitN(string(b), ":", 2)
	if len(parts) != 2 {
		return time.Time{}, "", fmt.Errorf("jobs: decode cursor: invalid format")
	}
	var micro int64
	if _, err := fmt.Sscanf(parts[0], "%d", &micro); err != nil {
		return time.Time{}, "", fmt.Errorf("jobs: decode cursor: parse timestamp: %w", err)
	}
	return time.UnixMicro(micro), parts[1], nil
}

// ─── scan helper ─────────────────────────────────────────────────────────────

func scanJob(row pgx.Row) (Job, error) {
	var j Job
	err := row.Scan(
		&j.ID, &j.Handler, &j.Status, &j.Priority, &j.Payload,
		&j.JobType, &j.Schedule, &j.RunAt, &j.NextRunAt, &j.LastRunAt,
		&j.LastDurationMS, &j.LastError, &j.MaxRetries, &j.RetryCount,
		&j.TimeoutMS, &j.IdempotencyKey, &j.OrgID, &j.CreatedBy,
		&j.WorkerID, &j.ClaimedAt, &j.CreatedAt, &j.UpdatedAt, &j.DeletedAt,
	)
	return j, err
}

func scanJobFromRows(rows pgx.Rows) (Job, error) {
	var j Job
	err := rows.Scan(
		&j.ID, &j.Handler, &j.Status, &j.Priority, &j.Payload,
		&j.JobType, &j.Schedule, &j.RunAt, &j.NextRunAt, &j.LastRunAt,
		&j.LastDurationMS, &j.LastError, &j.MaxRetries, &j.RetryCount,
		&j.TimeoutMS, &j.IdempotencyKey, &j.OrgID, &j.CreatedBy,
		&j.WorkerID, &j.ClaimedAt, &j.CreatedAt, &j.UpdatedAt, &j.DeletedAt,
	)
	return j, err
}

const jobColumns = `id, handler, status, priority, payload, job_type, schedule,
	run_at, next_run_at, last_run_at, last_duration_ms, last_error,
	max_retries, retry_count, timeout_ms, idempotency_key,
	org_id, created_by, worker_id, claimed_at, created_at, updated_at, deleted_at`

// ─── Core queue operations ────────────────────────────────────────────────────

// Enqueue inserts a new job. When params.OrgID is set, quota rules are enforced
// first. Returns ErrDuplicateKey (and the existing job) on idempotency collision.
func Enqueue(ctx context.Context, pool *pgxpool.Pool, registry *Registry, params EnqueueParams) (Job, error) {
	if params.OrgID != nil {
		if _, ok := registry.Get(params.Handler); !ok {
			return Job{}, ErrUnknownHandler
		}

		quota, err := GetQuota(ctx, pool, *params.OrgID)
		if err != nil {
			return Job{}, fmt.Errorf("jobs.Enqueue: get quota: %w", err)
		}

		if err := EnforcePriorityFloor(&params, quota); err != nil {
			return Job{}, fmt.Errorf("jobs.Enqueue: priority floor: %w", err)
		}

		if err := CheckEnqueueQuota(ctx, pool, *params.OrgID, quota); err != nil {
			return Job{}, fmt.Errorf("jobs.Enqueue: quota check: %w", err)
		}
	}

	payloadBytes, err := json.Marshal(params.Payload)
	if err != nil {
		return Job{}, fmt.Errorf("jobs.Enqueue: marshal payload: %w", err)
	}

	runAt := time.Now().UTC()
	if params.RunAt != nil {
		runAt = params.RunAt.UTC()
	}

	status := StatusQueued
	if runAt.After(time.Now().UTC()) {
		status = StatusPending
	}

	jobType := params.JobType
	if jobType == "" {
		jobType = "one_time"
	}

	maxRetries := 3
	if params.MaxRetries != nil {
		maxRetries = *params.MaxRetries
	}

	timeoutMS := 30000
	if params.TimeoutMS != nil {
		timeoutMS = *params.TimeoutMS
	}

	priority := params.Priority
	if priority == 0 {
		priority = PriorityNormal
	}

	row := pool.QueryRow(ctx, `
		INSERT INTO jobs (
			handler, status, priority, payload, job_type, schedule,
			run_at, max_retries, timeout_ms, idempotency_key,
			org_id, created_by
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		ON CONFLICT (idempotency_key) DO NOTHING
		RETURNING `+jobColumns,
		params.Handler, status, priority, payloadBytes, jobType, params.Schedule,
		runAt, maxRetries, timeoutMS, params.IdempotencyKey,
		params.OrgID, params.CreatedBy,
	)

	job, err := scanJob(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Conflict — idempotency key already exists; fetch existing row.
			var existing Job
			fetchErr := pool.QueryRow(ctx,
				`SELECT `+jobColumns+` FROM jobs WHERE idempotency_key = $1 AND deleted_at IS NULL`,
				params.IdempotencyKey,
			).Scan(
				&existing.ID, &existing.Handler, &existing.Status, &existing.Priority, &existing.Payload,
				&existing.JobType, &existing.Schedule, &existing.RunAt, &existing.NextRunAt, &existing.LastRunAt,
				&existing.LastDurationMS, &existing.LastError, &existing.MaxRetries, &existing.RetryCount,
				&existing.TimeoutMS, &existing.IdempotencyKey, &existing.OrgID, &existing.CreatedBy,
				&existing.WorkerID, &existing.ClaimedAt, &existing.CreatedAt, &existing.UpdatedAt, &existing.DeletedAt,
			)
			if fetchErr != nil {
				return Job{}, fmt.Errorf("jobs.Enqueue: fetch on conflict: %w", fetchErr)
			}
			return existing, ErrDuplicateKey
		}
		return Job{}, fmt.Errorf("jobs.Enqueue: insert: %w", err)
	}

	return job, nil
}

// ActivateDue transitions all due pending jobs to queued status.
// Returns the number of rows updated.
func ActivateDue(ctx context.Context, pool *pgxpool.Pool) (int64, error) {
	tag, err := pool.Exec(ctx,
		`UPDATE jobs
		 SET status = 'queued', updated_at = NOW()
		 WHERE status = 'pending'
		   AND run_at <= NOW()
		   AND deleted_at IS NULL`,
	)
	if err != nil {
		return 0, fmt.Errorf("jobs.ActivateDue: %w", err)
	}
	return tag.RowsAffected(), nil
}

// ClaimOne atomically claims the highest-priority available job for a worker.
// Returns nil, nil when no job is available.
func ClaimOne(ctx context.Context, pool *pgxpool.Pool, workerID string) (*ClaimedJob, error) {
	row := pool.QueryRow(ctx, `
		UPDATE jobs SET status = 'running', worker_id = $1, claimed_at = NOW(), updated_at = NOW()
		WHERE id = (
		  SELECT id FROM jobs
		  WHERE status = 'queued'
		    AND run_at <= NOW()
		    AND deleted_at IS NULL
		    AND (
		      priority <= 2
		      OR (
		        SELECT COUNT(*) FROM jobs j2
		        WHERE j2.org_id = jobs.org_id AND j2.status = 'running'
		      ) < COALESCE(
		        (SELECT max_concurrent FROM org_job_quotas WHERE org_id = jobs.org_id), 5
		      )
		    )
		  ORDER BY priority ASC, run_at ASC
		  LIMIT 1
		  FOR UPDATE SKIP LOCKED
		)
		RETURNING `+jobColumns,
		workerID,
	)

	job, err := scanJob(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("jobs.ClaimOne: claim: %w", err)
	}

	attempt := job.RetryCount + 1
	runID, err := InsertJobRun(ctx, pool, job.ID, workerID, attempt)
	if err != nil {
		return nil, fmt.Errorf("jobs.ClaimOne: insert job run: %w", err)
	}

	job.Attempt = attempt
	return &ClaimedJob{Job: job, RunID: runID}, nil
}

// InsertJobRun records a new job_runs row for the current attempt.
// Returns the generated run ID.
func InsertJobRun(ctx context.Context, pool *pgxpool.Pool, jobID, workerID string, attempt int) (string, error) {
	var runID string
	err := pool.QueryRow(ctx,
		`INSERT INTO job_runs (job_id, status, attempt, worker_id, started_at)
		 VALUES ($1, 'running', $2, $3, NOW())
		 RETURNING id`,
		jobID, attempt, workerID,
	).Scan(&runID)
	if err != nil {
		return "", fmt.Errorf("jobs.InsertJobRun: %w", err)
	}
	return runID, nil
}

// Heartbeat refreshes the heartbeat timestamp for a running job_run.
func Heartbeat(ctx context.Context, pool *pgxpool.Pool, runID string) error {
	_, err := pool.Exec(ctx,
		`UPDATE job_runs SET heartbeat_at = NOW() WHERE id = $1 AND status = 'running'`,
		runID,
	)
	if err != nil {
		return fmt.Errorf("jobs.Heartbeat: %w", err)
	}
	return nil
}

// Complete marks a job and its run row as successfully finished.
func Complete(ctx context.Context, pool *pgxpool.Pool, jobID, runID string, durationMS int) error {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("jobs.Complete: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	_, err = tx.Exec(ctx,
		`UPDATE jobs
		 SET status = 'success', last_run_at = NOW(), last_duration_ms = $2,
		     worker_id = NULL, claimed_at = NULL, updated_at = NOW()
		 WHERE id = $1`,
		jobID, durationMS,
	)
	if err != nil {
		return fmt.Errorf("jobs.Complete: update job: %w", err)
	}

	_, err = tx.Exec(ctx,
		`UPDATE job_runs
		 SET status = 'success', finished_at = NOW(), duration_ms = $2
		 WHERE id = $1`,
		runID, durationMS,
	)
	if err != nil {
		return fmt.Errorf("jobs.Complete: update job_run: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("jobs.Complete: commit: %w", err)
	}
	return nil
}

// Fail handles a job execution failure. If retries remain the job is re-queued
// with exponential backoff; otherwise it is moved to dead status.
func Fail(ctx context.Context, pool *pgxpool.Pool, jobID, runID string, jobErr error, durationMS int) error {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("jobs.Fail: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var retryCount, maxRetries int
	if err := tx.QueryRow(ctx,
		`SELECT retry_count, max_retries FROM jobs WHERE id = $1`,
		jobID,
	).Scan(&retryCount, &maxRetries); err != nil {
		return fmt.Errorf("jobs.Fail: fetch counts: %w", err)
	}

	errMsg := jobErr.Error()

	if retryCount+1 < maxRetries {
		// Exponential backoff: 2^retryCount * 2s, capped at 5 minutes.
		backoffSeconds := 1 << retryCount * 2
		const maxBackoffSeconds = 5 * 60
		if backoffSeconds > maxBackoffSeconds {
			backoffSeconds = maxBackoffSeconds
		}
		backoff := fmt.Sprintf("%d seconds", backoffSeconds)

		_, err = tx.Exec(ctx,
			`UPDATE jobs
			 SET status = 'queued', retry_count = retry_count + 1,
			     run_at = NOW() + $2::interval,
			     worker_id = NULL, claimed_at = NULL, updated_at = NOW()
			 WHERE id = $1`,
			jobID, backoff,
		)
	} else {
		_, err = tx.Exec(ctx,
			`UPDATE jobs
			 SET status = 'dead', last_error = $2,
			     worker_id = NULL, claimed_at = NULL, updated_at = NOW()
			 WHERE id = $1`,
			jobID, errMsg,
		)
	}
	if err != nil {
		return fmt.Errorf("jobs.Fail: update job: %w", err)
	}

	_, err = tx.Exec(ctx,
		`UPDATE job_runs
		 SET status = 'failed', finished_at = NOW(), duration_ms = $2, error = $3
		 WHERE id = $1`,
		runID, durationMS, errMsg,
	)
	if err != nil {
		return fmt.Errorf("jobs.Fail: update job_run: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("jobs.Fail: commit: %w", err)
	}
	return nil
}

// Cancel transitions a pending or queued job to cancelled status.
// If orgID is non-nil it is used as an additional ownership filter.
func Cancel(ctx context.Context, pool *pgxpool.Pool, jobID string, orgID *string) error {
	tag, err := pool.Exec(ctx,
		`UPDATE jobs
		 SET status = 'cancelled', updated_at = NOW()
		 WHERE id = $1
		   AND status IN ('pending', 'queued')
		   AND (org_id = $2 OR $2 IS NULL)
		   AND deleted_at IS NULL`,
		jobID, orgID,
	)
	if err != nil {
		return fmt.Errorf("jobs.Cancel: %w", err)
	}
	if tag.RowsAffected() == 0 {
		var exists bool
		_ = pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM jobs WHERE id = $1 AND deleted_at IS NULL)`, jobID,
		).Scan(&exists)
		if !exists {
			return ErrJobNotFound
		}
		return fmt.Errorf("jobs.Cancel: job cannot be cancelled in current state")
	}
	return nil
}

// ForceRetry re-queues a failed or dead job, resetting its retry counter.
func ForceRetry(ctx context.Context, pool *pgxpool.Pool, jobID string) error {
	tag, err := pool.Exec(ctx,
		`UPDATE jobs
		 SET status = 'queued', retry_count = 0, run_at = NOW(), updated_at = NOW()
		 WHERE id = $1
		   AND status IN ('failed', 'dead')
		   AND deleted_at IS NULL`,
		jobID,
	)
	if err != nil {
		return fmt.Errorf("jobs.ForceRetry: %w", err)
	}
	if tag.RowsAffected() == 0 {
		var exists bool
		_ = pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM jobs WHERE id = $1 AND deleted_at IS NULL)`, jobID,
		).Scan(&exists)
		if !exists {
			return ErrJobNotFound
		}
		return fmt.Errorf("jobs.ForceRetry: job cannot be retried in current state")
	}
	return nil
}

// List returns a cursor-paginated slice of jobs matching the given filter.
// Results are ordered by created_at DESC, id DESC. Max page size is 50.
func List(ctx context.Context, pool *pgxpool.Pool, filter ListFilter) ([]Job, string, error) {
	limit := filter.Limit
	if limit <= 0 || limit > 50 {
		limit = 50
	}

	cursorCreatedAt, cursorID, err := decodeCursor(filter.After)
	if err != nil {
		// Treat a malformed cursor as no cursor rather than hard-failing.
		cursorCreatedAt = time.Time{}
		cursorID = ""
	}

	args := []any{}
	conds := []string{"deleted_at IS NULL"}
	argIdx := 1

	if filter.OrgID != nil {
		args = append(args, *filter.OrgID)
		conds = append(conds, fmt.Sprintf("org_id = $%d", argIdx))
		argIdx++
	}
	if filter.Status != nil {
		args = append(args, *filter.Status)
		conds = append(conds, fmt.Sprintf("status = $%d", argIdx))
		argIdx++
	}
	if filter.Handler != nil {
		args = append(args, *filter.Handler)
		conds = append(conds, fmt.Sprintf("handler = $%d", argIdx))
		argIdx++
	}
	if cursorID != "" {
		args = append(args, cursorCreatedAt, cursorID)
		conds = append(conds, fmt.Sprintf("(created_at, id) < ($%d, $%d)", argIdx, argIdx+1))
		argIdx += 2
	}

	where := strings.Join(conds, " AND ")

	args = append(args, limit+1)
	query := fmt.Sprintf(
		`SELECT `+jobColumns+`
		 FROM jobs
		 WHERE %s
		 ORDER BY created_at DESC, id DESC
		 LIMIT $%d`,
		where, argIdx,
	)

	rows, err := pool.Query(ctx, query, args...)
	if err != nil {
		return nil, "", fmt.Errorf("jobs.List: query: %w", err)
	}
	defer rows.Close()

	jobs := []Job{}
	for rows.Next() {
		j, err := scanJobFromRows(rows)
		if err != nil {
			return nil, "", fmt.Errorf("jobs.List: scan: %w", err)
		}
		jobs = append(jobs, j)
	}
	if err := rows.Err(); err != nil {
		return nil, "", fmt.Errorf("jobs.List: rows error: %w", err)
	}

	var nextCursor string
	if len(jobs) > limit {
		jobs = jobs[:limit]
		last := jobs[limit-1]
		nextCursor = encodeCursor(last.CreatedAt, last.ID)
	}

	return jobs, nextCursor, nil
}

// GetByID returns a single job by ID, optionally scoped to an org.
func GetByID(ctx context.Context, pool *pgxpool.Pool, jobID string, orgID *string) (Job, error) {
	row := pool.QueryRow(ctx,
		`SELECT `+jobColumns+`
		 FROM jobs
		 WHERE id = $1 AND (org_id = $2 OR $2 IS NULL) AND deleted_at IS NULL`,
		jobID, orgID,
	)
	job, err := scanJob(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Job{}, ErrJobNotFound
		}
		return Job{}, fmt.Errorf("jobs.GetByID: %w", err)
	}
	return job, nil
}

// GetRuns returns the most recent job_runs rows for the given job.
func GetRuns(ctx context.Context, pool *pgxpool.Pool, jobID string, limit int) ([]JobRun, error) {
	if limit <= 0 {
		limit = 20
	}
	rows, err := pool.Query(ctx,
		`SELECT id, job_id, status, attempt, worker_id,
		        started_at, finished_at, duration_ms, error, heartbeat_at, created_at
		 FROM job_runs
		 WHERE job_id = $1
		 ORDER BY created_at DESC
		 LIMIT $2`,
		jobID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("jobs.GetRuns: query: %w", err)
	}
	defer rows.Close()

	out := []JobRun{}
	for rows.Next() {
		var r JobRun
		if err := rows.Scan(
			&r.ID, &r.JobID, &r.Status, &r.Attempt, &r.WorkerID,
			&r.StartedAt, &r.FinishedAt, &r.DurationMS, &r.Error, &r.HeartbeatAt, &r.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("jobs.GetRuns: scan: %w", err)
		}
		out = append(out, r)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("jobs.GetRuns: rows error: %w", err)
	}
	return out, nil
}

// OrgStats returns job counts by status for an org, plus its quota.
func OrgStats(ctx context.Context, pool *pgxpool.Pool, orgID string) (OrgJobStats, error) {
	rows, err := pool.Query(ctx,
		`SELECT status, COUNT(*) FROM jobs WHERE org_id = $1 AND deleted_at IS NULL GROUP BY status`,
		orgID,
	)
	if err != nil {
		return OrgJobStats{}, fmt.Errorf("jobs.OrgStats: query: %w", err)
	}
	defer rows.Close()

	stats := OrgJobStats{OrgID: orgID}
	for rows.Next() {
		var status string
		var count int
		if err := rows.Scan(&status, &count); err != nil {
			return OrgJobStats{}, fmt.Errorf("jobs.OrgStats: scan: %w", err)
		}
		switch status {
		case StatusRunning:
			stats.Running = count
		case StatusQueued:
			stats.Queued = count
		case StatusFailed:
			stats.Failed = count
		case StatusDead:
			stats.Dead = count
		}
	}
	if err := rows.Err(); err != nil {
		return OrgJobStats{}, fmt.Errorf("jobs.OrgStats: rows error: %w", err)
	}

	quota, err := GetQuota(ctx, pool, orgID)
	if err != nil {
		return OrgJobStats{}, fmt.Errorf("jobs.OrgStats: get quota: %w", err)
	}
	stats.Quota = quota

	return stats, nil
}

// PlatformStats returns per-org job counts for the admin dashboard.
func PlatformStats(ctx context.Context, pool *pgxpool.Pool) ([]OrgJobStats, error) {
	rows, err := pool.Query(ctx,
		`SELECT o.id, o.name,
		        COUNT(CASE WHEN j.status = 'running' THEN 1 END)  AS running,
		        COUNT(CASE WHEN j.status = 'queued'  THEN 1 END)  AS queued,
		        COUNT(CASE WHEN j.status = 'failed'  THEN 1 END)  AS failed,
		        COUNT(CASE WHEN j.status = 'dead'    THEN 1 END)  AS dead
		 FROM organizations o
		 LEFT JOIN jobs j ON j.org_id = o.id AND j.deleted_at IS NULL
		 GROUP BY o.id, o.name
		 ORDER BY o.name`,
	)
	if err != nil {
		return nil, fmt.Errorf("jobs.PlatformStats: query: %w", err)
	}
	defer rows.Close()

	out := []OrgJobStats{}
	for rows.Next() {
		var s OrgJobStats
		if err := rows.Scan(&s.OrgID, &s.OrgName, &s.Running, &s.Queued, &s.Failed, &s.Dead); err != nil {
			return nil, fmt.Errorf("jobs.PlatformStats: scan: %w", err)
		}
		out = append(out, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("jobs.PlatformStats: rows error: %w", err)
	}
	return out, nil
}

// ─── Quota ────────────────────────────────────────────────────────────────────

// GetQuota returns the job quota for an org, falling back to safe platform defaults.
func GetQuota(ctx context.Context, pool *pgxpool.Pool, orgID string) (Quota, error) {
	var q Quota
	err := pool.QueryRow(ctx,
		`SELECT max_concurrent, max_queued, priority_floor
		 FROM org_job_quotas
		 WHERE org_id = $1`,
		orgID,
	).Scan(&q.MaxConcurrent, &q.MaxQueued, &q.PriorityFloor)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Quota{MaxConcurrent: 5, MaxQueued: 200, PriorityFloor: 5}, nil
		}
		return Quota{}, fmt.Errorf("jobs.GetQuota: %w", err)
	}
	return q, nil
}

// UpdateQuota upserts the quota row for an org.
func UpdateQuota(ctx context.Context, pool *pgxpool.Pool, orgID string, q Quota) error {
	_, err := pool.Exec(ctx,
		`INSERT INTO org_job_quotas (org_id, max_concurrent, max_queued, priority_floor)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (org_id) DO UPDATE
		   SET max_concurrent  = EXCLUDED.max_concurrent,
		       max_queued      = EXCLUDED.max_queued,
		       priority_floor  = EXCLUDED.priority_floor,
		       updated_at      = NOW()`,
		orgID, q.MaxConcurrent, q.MaxQueued, q.PriorityFloor,
	)
	if err != nil {
		return fmt.Errorf("jobs.UpdateQuota: %w", err)
	}
	return nil
}

// ─── Cron ─────────────────────────────────────────────────────────────────────

// SetNextCronRun updates the next_run_at field for a recurring job.
func SetNextCronRun(ctx context.Context, pool *pgxpool.Pool, jobID string, nextRunAt time.Time) error {
	_, err := pool.Exec(ctx,
		`UPDATE jobs SET next_run_at = $2, updated_at = NOW() WHERE id = $1`,
		jobID, nextRunAt,
	)
	if err != nil {
		return fmt.Errorf("jobs.SetNextCronRun: %w", err)
	}
	return nil
}

// ─── Redis ────────────────────────────────────────────────────────────────────

// RegisterWorker publishes a worker's slot usage into Redis with a 30-second TTL.
// Called by each worker instance on every heartbeat cycle.
func RegisterWorker(ctx context.Context, rdb *redis.Client, instanceID string, busy, total int) error {
	payload, err := json.Marshal(map[string]any{
		"instance_id": instanceID,
		"slots_busy":  busy,
		"slots_total": total,
		"last_seen":   time.Now().UTC(),
	})
	if err != nil {
		return fmt.Errorf("jobs.RegisterWorker: marshal: %w", err)
	}
	key := "jobs:worker:" + instanceID
	if err := rdb.Set(ctx, key, payload, 30*time.Second).Err(); err != nil {
		return fmt.Errorf("jobs.RegisterWorker: set: %w", err)
	}
	return nil
}

// ListWorkers returns all currently registered workers from Redis.
// Workers whose TTL has expired are naturally absent.
func ListWorkers(ctx context.Context, rdb *redis.Client) ([]WorkerInfo, error) {
	keys, err := rdb.Keys(ctx, "jobs:worker:*").Result()
	if err != nil {
		return nil, fmt.Errorf("jobs.ListWorkers: keys: %w", err)
	}

	out := []WorkerInfo{}
	for _, key := range keys {
		val, err := rdb.Get(ctx, key).Result()
		if err != nil {
			// Key expired between KEYS and GET — skip it.
			if errors.Is(err, redis.Nil) {
				continue
			}
			return nil, fmt.Errorf("jobs.ListWorkers: get %s: %w", key, err)
		}

		var w WorkerInfo
		if err := json.Unmarshal([]byte(val), &w); err != nil {
			return nil, fmt.Errorf("jobs.ListWorkers: unmarshal %s: %w", key, err)
		}
		// Derive InstanceID from the key suffix in case the JSON field is missing.
		if w.InstanceID == "" {
			w.InstanceID = strings.TrimPrefix(key, "jobs:worker:")
		}
		out = append(out, w)
	}
	return out, nil
}

// GetSchedulerLeader returns the instance ID of the current scheduler leader,
// or "" when no leader lock is held (not an error).
func GetSchedulerLeader(ctx context.Context, rdb *redis.Client) (string, error) {
	val, err := rdb.Get(ctx, "jobs:scheduler:leader").Result()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return "", nil
		}
		return "", fmt.Errorf("jobs.GetSchedulerLeader: %w", err)
	}
	return val, nil
}
