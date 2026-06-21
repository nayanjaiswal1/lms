package jobs

import (
	"context"
	"fmt"
	"log/slog"
	"runtime/debug"
	"sync"
	"sync/atomic"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/redis/go-redis/v9"
)

// WorkerPool pulls jobs from the database and executes them concurrently.
// Start blocks until all goroutines have exited (SIGTERM + drain).
type WorkerPool struct {
	pool       *pgxpool.Pool
	rdb        *redis.Client
	registry   *Registry
	cfg        *config.Config
	instanceID string
	busy       atomic.Int64
}

// NewWorkerPool constructs a WorkerPool with all dependencies injected.
func NewWorkerPool(
	pool *pgxpool.Pool,
	rdb *redis.Client,
	registry *Registry,
	cfg *config.Config,
	instanceID string,
) *WorkerPool {
	return &WorkerPool{
		pool:       pool,
		rdb:        rdb,
		registry:   registry,
		cfg:        cfg,
		instanceID: instanceID,
	}
}

// SlotsBusy returns the number of goroutines currently executing a job handler.
func (p *WorkerPool) SlotsBusy() int {
	return int(p.busy.Load())
}

// Start launches cfg.WorkerPoolSize worker goroutines plus background maintenance
// goroutines (Redis registration, health logging). It blocks until all worker
// goroutines have exited after the context is cancelled, or until the drain
// timeout elapses.
func (p *WorkerPool) Start(ctx context.Context) {
	slog.Info("worker pool starting", "workers", p.cfg.WorkerPoolSize, "instance", p.instanceID)

	// Background: publish slot usage to Redis every 10 seconds.
	go p.runRegistration(ctx)

	// Background: log pool health every 60 seconds.
	go p.runHealthLog(ctx)

	var wg sync.WaitGroup
	wg.Add(p.cfg.WorkerPoolSize)
	for i := range p.cfg.WorkerPoolSize {
		go func(id int) {
			defer wg.Done()
			p.runWorker(ctx, id+1)
		}(i)
	}

	// Wait for all workers to acknowledge context cancellation.
	workersDone := make(chan struct{})
	go func() {
		wg.Wait()
		close(workersDone)
	}()

	select {
	case <-workersDone:
		slog.Info("worker pool stopped cleanly", "instance", p.instanceID)
	case <-time.After(p.cfg.WorkerDrainTimeout):
		slog.Warn("worker pool drain timeout elapsed; some jobs may be reclaimed by orphan reaper",
			"drain_timeout", p.cfg.WorkerDrainTimeout, "instance", p.instanceID)
	}
}

// ─── internal goroutines ──────────────────────────────────────────────────────

// runWorker is the main loop for a single worker slot.
func (p *WorkerPool) runWorker(ctx context.Context, workerID int) {
	slog.Info("worker started", "worker", workerID, "instance", p.instanceID)
	for {
		// Stop claiming new work as soon as the context is done.
		if ctx.Err() != nil {
			slog.Info("worker stopping", "worker", workerID, "instance", p.instanceID)
			return
		}

		claimed, err := ClaimOne(ctx, p.pool, p.instanceID)
		if err != nil {
			// Context cancelled during claim — exit cleanly.
			if ctx.Err() != nil {
				slog.Info("worker stopping", "worker", workerID, "instance", p.instanceID)
				return
			}
			slog.Error("worker: claim failed", "worker", workerID, "error", err, "instance", p.instanceID)
			// Brief pause to avoid a hot error loop.
			select {
			case <-time.After(500 * time.Millisecond):
			case <-ctx.Done():
				return
			}
			continue
		}

		if claimed == nil {
			// No queued job — back off and retry.
			select {
			case <-time.After(500 * time.Millisecond):
			case <-ctx.Done():
				slog.Info("worker stopping", "worker", workerID, "instance", p.instanceID)
				return
			}
			continue
		}

		p.busy.Add(1)
		p.executeJob(ctx, workerID, claimed)
		p.busy.Add(-1)
	}
}

// executeJob runs a single claimed job end-to-end: handler lookup, heartbeat,
// handler execution with panic recovery, and final state update.
func (p *WorkerPool) executeJob(ctx context.Context, workerID int, claimed *ClaimedJob) {
	job := claimed.Job
	runID := claimed.RunID
	start := time.Now()

	// Resolve handler before doing any further work.
	handler, ok := p.registry.Get(job.Handler)
	if !ok {
		slog.Error("worker: unknown handler — marking job dead",
			"job_id", job.ID, "handler", job.Handler, "worker", workerID)
		p.markDeadUnknownHandler(ctx, job.ID, runID, job.Handler)
		return
	}

	// Job-scoped timeout context.
	jobCtx, cancelJob := context.WithTimeout(ctx, time.Duration(job.TimeoutMS)*time.Millisecond)
	defer cancelJob()

	// Heartbeat goroutine: keeps job_runs.heartbeat_at fresh so the orphan
	// reaper does not reclaim a running job. Stops when done is closed.
	done := make(chan struct{})
	go p.runHeartbeat(jobCtx, done, runID, workerID)

	// Execute handler with panic recovery.
	handlerErr := runHandler(jobCtx, handler, job)

	// Stop heartbeat before updating final state.
	close(done)
	cancelJob()

	durationMS := int(time.Since(start).Milliseconds())

	// Determine outcome and update DB accordingly.
	switch {
	case handlerErr == nil:
		if err := Complete(ctx, p.pool, job.ID, runID, durationMS); err != nil {
			slog.Error("worker: complete failed", "job_id", job.ID, "error", err, "worker", workerID)
		}
		p.logJobDone(job, StatusSuccess, durationMS)

	case ctx.Err() == context.Canceled:
		// Parent context cancelled (SIGTERM). Do NOT call Fail — the orphan
		// reaper will reclaim the job once the heartbeat stops being refreshed.
		slog.Info("worker: job interrupted by shutdown, orphan reaper will reclaim",
			"job_id", job.ID, "handler", job.Handler, "worker", workerID)

	default:
		// Handler returned an error (including DeadlineExceeded from the job-level
		// timeout context). Call Fail to handle retry or dead transition.
		if err := Fail(ctx, p.pool, job.ID, runID, handlerErr, durationMS); err != nil {
			slog.Error("worker: fail update failed", "job_id", job.ID, "error", err, "worker", workerID)
		}
		p.logJobDone(job, StatusFailed, durationMS)
	}
}

// runHeartbeat ticks every cfg.WorkerHeartbeatInterval and refreshes the
// job_run heartbeat timestamp. It exits when done is closed or jobCtx expires.
func (p *WorkerPool) runHeartbeat(jobCtx context.Context, done <-chan struct{}, runID string, workerID int) {
	ticker := time.NewTicker(p.cfg.WorkerHeartbeatInterval)
	defer ticker.Stop()
	for {
		select {
		case <-done:
			return
		case <-jobCtx.Done():
			return
		case <-ticker.C:
			if err := Heartbeat(jobCtx, p.pool, runID); err != nil {
				// Non-fatal — log and continue. A missed beat does not immediately
				// kill the job; the orphan reaper threshold provides a grace window.
				slog.Warn("worker: heartbeat failed", "run_id", runID, "worker", workerID, "error", err)
			}
		}
	}
}

// runRegistration publishes worker slot usage to Redis every 10 seconds.
func (p *WorkerPool) runRegistration(ctx context.Context) {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := RegisterWorker(ctx, p.rdb, p.instanceID, int(p.busy.Load()), p.cfg.WorkerPoolSize); err != nil {
				slog.Warn("worker: register worker failed", "instance", p.instanceID, "error", err)
			}
		}
	}
}

// runHealthLog logs pool utilisation every 60 seconds.
func (p *WorkerPool) runHealthLog(ctx context.Context) {
	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			slog.Info("worker pool", "busy", p.busy.Load(), "total", p.cfg.WorkerPoolSize, "instance", p.instanceID)
		}
	}
}

// markDeadUnknownHandler immediately transitions a job to dead status when its
// handler key is not registered in the registry. No retry is attempted because
// the handler is structurally absent — retrying would produce the same outcome.
func (p *WorkerPool) markDeadUnknownHandler(ctx context.Context, jobID, runID, handlerKey string) {
	errMsg := fmt.Sprintf("unknown handler: %s", handlerKey)

	_, dbErr := p.pool.Exec(ctx,
		`UPDATE jobs
		 SET status = 'dead', last_error = $2,
		     worker_id = NULL, claimed_at = NULL, updated_at = NOW()
		 WHERE id = $1`,
		jobID, errMsg,
	)
	if dbErr != nil {
		slog.Error("worker: mark dead (unknown handler) — job update failed",
			"job_id", jobID, "handler", handlerKey, "error", dbErr)
	}

	_, runErr := p.pool.Exec(ctx,
		`UPDATE job_runs
		 SET status = 'failed', finished_at = NOW(), error = $2
		 WHERE id = $1`,
		runID, errMsg,
	)
	if runErr != nil {
		slog.Error("worker: mark dead (unknown handler) — run update failed",
			"job_id", jobID, "run_id", runID, "handler", handlerKey, "error", runErr)
	}
}

// logJobDone emits the structured completion log entry.
func (p *WorkerPool) logJobDone(job Job, finalStatus Status, durationMS int) {
	slog.Info("jobs",
		"event", "job_done",
		"job_id", job.ID,
		"handler", job.Handler,
		"status", finalStatus,
		"attempt", job.Attempt,
		"org_id", job.OrgID,
		"duration_ms", durationMS,
	)
}

// ─── handler execution ────────────────────────────────────────────────────────

// runHandler calls handler.Handle and converts any panic into an error so the
// worker can call Fail rather than crashing the goroutine.
func runHandler(ctx context.Context, handler Handler, job Job) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("panic: %v\n%s", r, debug.Stack())
		}
	}()
	return handler.Handle(ctx, job)
}
