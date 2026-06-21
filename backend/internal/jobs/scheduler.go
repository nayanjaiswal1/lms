package jobs

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/redis/go-redis/v9"
)

// CronJobDef describes a recurring system job managed by the Scheduler.
type CronJobDef struct {
	Handler   string
	Schedule  string
	Priority  Priority
	TimeoutMS int
}

// Scheduler is a distributed singleton that manages cron dispatch, delayed job
// activation, and orphan reaping. Only the elected leader instance performs
// scheduling work; followers idle on the leader-election ticker.
type Scheduler struct {
	pool       *pgxpool.Pool
	rdb        *redis.Client
	cfg        *config.Config
	registry   *Registry
	instanceID string
	cronJobs   []CronJobDef
	isLeader   atomic.Bool
}

// NewScheduler constructs a Scheduler with all dependencies injected.
func NewScheduler(
	pool *pgxpool.Pool,
	rdb *redis.Client,
	cfg *config.Config,
	registry *Registry,
	instanceID string,
	cronJobs []CronJobDef,
) *Scheduler {
	return &Scheduler{
		pool:       pool,
		rdb:        rdb,
		cfg:        cfg,
		registry:   registry,
		instanceID: instanceID,
		cronJobs:   cronJobs,
	}
}

// Start runs missed-cron recovery synchronously, then blocks on four concurrent
// loops until ctx is cancelled. All loops exit cleanly before Start returns.
func (s *Scheduler) Start(ctx context.Context) {
	slog.Info("scheduler starting", "instance", s.instanceID)

	s.recoverMissedCrons(ctx)

	var wg sync.WaitGroup
	wg.Add(4)

	go func() { defer wg.Done(); s.runLeaderElection(ctx) }()
	go func() { defer wg.Done(); s.runCronDispatcher(ctx) }()
	go func() { defer wg.Done(); s.runDelayedActivator(ctx) }()
	go func() { defer wg.Done(); s.runOrphanReaper(ctx) }()

	wg.Wait()
	slog.Info("scheduler stopped", "instance", s.instanceID)
}

// ─── loop 1: leader election ──────────────────────────────────────────────────

func (s *Scheduler) runLeaderElection(ctx context.Context) {
	ticker := time.NewTicker(s.cfg.SchedulerLeaderRenew)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			s.isLeader.Store(false)
			return
		case <-ticker.C:
			s.electLeader(ctx)
		}
	}
}

func (s *Scheduler) electLeader(ctx context.Context) {
	const leaderKey = "jobs:scheduler:leader"

	set, err := s.rdb.SetNX(ctx, leaderKey, s.instanceID, s.cfg.SchedulerLeaderTTL).Result()
	if err != nil {
		slog.Warn("scheduler: leader election setnx failed", "instance", s.instanceID, "error", err)
		return
	}

	if set {
		s.isLeader.Store(true)
		slog.Info("scheduler: became leader", "instance", s.instanceID)
		return
	}

	// We did not win the lock — check whether we already hold it.
	val, err := s.rdb.Get(ctx, leaderKey).Result()
	if err != nil {
		slog.Warn("scheduler: leader election get failed", "instance", s.instanceID, "error", err)
		s.isLeader.Store(false)
		return
	}

	if val == s.instanceID {
		// We are the current leader — refresh the TTL.
		if err := s.rdb.Expire(ctx, leaderKey, s.cfg.SchedulerLeaderTTL).Err(); err != nil {
			slog.Warn("scheduler: leader ttl refresh failed", "instance", s.instanceID, "error", err)
		}
		s.isLeader.Store(true)
	} else {
		s.isLeader.Store(false)
	}
}

// ─── loop 2: cron dispatcher ──────────────────────────────────────────────────

func (s *Scheduler) runCronDispatcher(ctx context.Context) {
	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if !s.isLeader.Load() {
				continue
			}
			s.dispatchCrons(ctx)
		}
	}
}

func (s *Scheduler) dispatchCrons(ctx context.Context) {
	for _, def := range s.cronJobs {
		if err := s.tickCronJob(ctx, def); err != nil {
			slog.Error("scheduler: cron tick failed",
				"handler", def.Handler,
				"error", err,
			)
		}
	}
}

func (s *Scheduler) tickCronJob(ctx context.Context, def CronJobDef) error {
	// Find the canonical cron row for this handler (system-level: org_id IS NULL).
	var cronID string
	var nextRunAt *time.Time

	err := s.pool.QueryRow(ctx,
		`SELECT id, next_run_at
		 FROM jobs
		 WHERE handler = $1
		   AND org_id IS NULL
		   AND job_type = 'cron'
		   AND deleted_at IS NULL
		 LIMIT 1`,
		def.Handler,
	).Scan(&cronID, &nextRunAt)

	now := time.Now().UTC()

	if err != nil {
		// No cron row yet — create the canonical record.
		schedule := def.Schedule
		firstNext, parseErr := nextCronTime(def.Schedule, now)
		if parseErr != nil {
			return fmt.Errorf("scheduler: parse cron schedule %q: %w", def.Schedule, parseErr)
		}

		timeoutMS := def.TimeoutMS
		if timeoutMS == 0 {
			timeoutMS = 30000
		}

		_, enqErr := Enqueue(ctx, s.pool, s.registry, EnqueueParams{
			Handler:   def.Handler,
			Priority:  def.Priority,
			Payload:   nil,
			JobType:   "cron",
			Schedule:  &schedule,
			RunAt:     &firstNext,
			TimeoutMS: &timeoutMS,
			OrgID:     nil,
		})
		if enqErr != nil && !errors.Is(enqErr, ErrDuplicateKey) {
			return fmt.Errorf("scheduler: enqueue initial cron %q: %w", def.Handler, enqErr)
		}

		slog.Info("scheduler: cron registered",
			"handler", def.Handler,
			"next_run_at", firstNext,
		)
		return nil
	}

	// Cron row exists but is not yet due.
	if nextRunAt != nil && nextRunAt.After(now) {
		slog.Info("scheduler: cron tick",
			"handler", def.Handler,
			"next_run_at", nextRunAt,
			"skipped", true,
		)
		return nil
	}

	// Cron is due — guard against double-dispatch by checking for an already
	// active instance (queued or running) for this handler.
	var activeCount int
	if err := s.pool.QueryRow(ctx,
		`SELECT COUNT(*)
		 FROM jobs
		 WHERE handler = $1
		   AND org_id IS NULL
		   AND status IN ('queued', 'running')
		   AND deleted_at IS NULL`,
		def.Handler,
	).Scan(&activeCount); err != nil {
		return fmt.Errorf("scheduler: check active cron %q: %w", def.Handler, err)
	}

	if activeCount > 0 {
		slog.Info("scheduler: cron tick",
			"handler", def.Handler,
			"next_run_at", nextRunAt,
			"skipped", true,
		)
		return nil
	}

	// Enqueue a one_time execution for this cron handler.
	timeoutMS := def.TimeoutMS
	if timeoutMS == 0 {
		timeoutMS = 30000
	}

	_, enqErr := Enqueue(ctx, s.pool, s.registry, EnqueueParams{
		Handler:   def.Handler,
		Priority:  def.Priority,
		Payload:   nil,
		JobType:   "one_time",
		TimeoutMS: &timeoutMS,
		OrgID:     nil,
	})
	if enqErr != nil && !errors.Is(enqErr, ErrDuplicateKey) {
		return fmt.Errorf("scheduler: enqueue cron execution %q: %w", def.Handler, enqErr)
	}

	// Compute next fire time and persist it back to the canonical cron row.
	nextRun, parseErr := nextCronTime(def.Schedule, now)
	if parseErr != nil {
		return fmt.Errorf("scheduler: compute next cron time %q: %w", def.Schedule, parseErr)
	}

	if err := SetNextCronRun(ctx, s.pool, cronID, nextRun); err != nil {
		return fmt.Errorf("scheduler: set next cron run %q: %w", def.Handler, err)
	}

	slog.Info("scheduler: cron tick",
		"handler", def.Handler,
		"next_run_at", nextRun,
		"skipped", false,
	)
	return nil
}

// ─── loop 3: delayed job activator ───────────────────────────────────────────

func (s *Scheduler) runDelayedActivator(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if !s.isLeader.Load() {
				continue
			}
			n, err := ActivateDue(ctx, s.pool)
			if err != nil {
				slog.Error("scheduler: activate due jobs failed", "error", err)
				continue
			}
			if n > 0 {
				slog.Info("scheduler: jobs activated", "count", n)
			}
		}
	}
}

// ─── loop 4: orphan reaper ────────────────────────────────────────────────────

func (s *Scheduler) runOrphanReaper(ctx context.Context) {
	ticker := time.NewTicker(s.cfg.OrphanReaperInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if !s.isLeader.Load() {
				continue
			}
			s.reapOrphans(ctx)
		}
	}
}

func (s *Scheduler) reapOrphans(ctx context.Context) {
	threshold := fmt.Sprintf("%d seconds", int(s.cfg.OrphanThreshold.Seconds()))

	rows, err := s.pool.Query(ctx,
		`SELECT j.id, jr.id AS run_id
		 FROM jobs j
		 JOIN job_runs jr ON jr.job_id = j.id
		 WHERE j.status = 'running'
		   AND jr.status = 'running'
		   AND jr.heartbeat_at < NOW() - $1::interval
		   AND j.deleted_at IS NULL`,
		threshold,
	)
	if err != nil {
		slog.Error("scheduler: orphan reaper query failed", "error", err)
		return
	}
	defer rows.Close()

	type orphan struct {
		jobID string
		runID string
	}
	var orphans []orphan
	for rows.Next() {
		var o orphan
		if err := rows.Scan(&o.jobID, &o.runID); err != nil {
			slog.Error("scheduler: orphan reaper scan failed", "error", err)
			return
		}
		orphans = append(orphans, o)
	}
	if err := rows.Err(); err != nil {
		slog.Error("scheduler: orphan reaper rows error", "error", err)
		return
	}

	for _, o := range orphans {
		if err := Fail(ctx, s.pool, o.jobID, o.runID, errors.New("orphan: worker heartbeat lost"), 0); err != nil {
			slog.Error("scheduler: orphan reaper fail job",
				"job_id", o.jobID,
				"run_id", o.runID,
				"error", err,
			)
			continue
		}
		slog.Info("scheduler: orphan reaped", "job_id", o.jobID, "run_id", o.runID)
	}
}

// ─── startup: missed cron recovery ───────────────────────────────────────────

func (s *Scheduler) recoverMissedCrons(ctx context.Context) {
	rows, err := s.pool.Query(ctx,
		`SELECT id
		 FROM jobs
		 WHERE job_type = 'cron'
		   AND next_run_at < NOW() - interval '1 minute'
		   AND deleted_at IS NULL
		   AND status != 'cancelled'`,
	)
	if err != nil {
		slog.Error("scheduler: missed cron recovery query failed", "error", err)
		return
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			slog.Error("scheduler: missed cron recovery scan failed", "error", err)
			return
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		slog.Error("scheduler: missed cron recovery rows error", "error", err)
		return
	}

	for _, id := range ids {
		if _, err := s.pool.Exec(ctx,
			`UPDATE jobs SET next_run_at = NOW(), updated_at = NOW() WHERE id = $1`,
			id,
		); err != nil {
			slog.Error("scheduler: missed cron recovery update failed", "job_id", id, "error", err)
			continue
		}
		slog.Info("scheduler: missed cron recovery", "job_id", id)
	}
}

// ─── cron schedule parser ─────────────────────────────────────────────────────

// nextCronTime returns the next time after `after` that matches the given
// standard 5-field cron expression (minute hour dom month dow).
// Each field is either "*" (any value) or a single integer literal.
// The search is capped at 1 year (525,600 minutes) to prevent infinite loops
// on unsatisfiable expressions.
func nextCronTime(schedule string, after time.Time) (time.Time, error) {
	fields := strings.Fields(schedule)
	if len(fields) != 5 {
		return time.Time{}, fmt.Errorf("scheduler: invalid cron expression %q: expected 5 fields, got %d", schedule, len(fields))
	}

	parseField := func(s string, min, max int) ([]int, error) {
		if s == "*" {
			vals := make([]int, max-min+1)
			for i := range vals {
				vals[i] = min + i
			}
			return vals, nil
		}
		n, err := strconv.Atoi(s)
		if err != nil {
			return nil, fmt.Errorf("scheduler: invalid cron field %q: %w", s, err)
		}
		if n < min || n > max {
			return nil, fmt.Errorf("scheduler: cron field %q out of range [%d, %d]", s, min, max)
		}
		return []int{n}, nil
	}

	minutes, err := parseField(fields[0], 0, 59)
	if err != nil {
		return time.Time{}, err
	}
	hours, err := parseField(fields[1], 0, 23)
	if err != nil {
		return time.Time{}, err
	}
	doms, err := parseField(fields[2], 1, 31)
	if err != nil {
		return time.Time{}, err
	}
	months, err := parseField(fields[3], 1, 12)
	if err != nil {
		return time.Time{}, err
	}
	dows, err := parseField(fields[4], 0, 6)
	if err != nil {
		return time.Time{}, err
	}

	contains := func(vals []int, v int) bool {
		for _, x := range vals {
			if x == v {
				return true
			}
		}
		return false
	}

	// Start one minute after `after` (current minute is already past).
	t := after.UTC().Truncate(time.Minute).Add(time.Minute)

	const maxMinutes = 525600 // 1 year
	for i := 0; i < maxMinutes; i++ {
		if contains(months, int(t.Month())) &&
			contains(doms, t.Day()) &&
			contains(dows, int(t.Weekday())) &&
			contains(hours, t.Hour()) &&
			contains(minutes, t.Minute()) {
			return t, nil
		}
		t = t.Add(time.Minute)
	}

	return time.Time{}, fmt.Errorf("scheduler: no next time found within 1 year for schedule %q", schedule)
}
