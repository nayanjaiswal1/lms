# /implement-jobs — MindForge Job Management System

Implement a production-grade Job Management & Scheduling System for MindForge.
This replaces the ad-hoc Redis eval queue with a unified, multi-tenant, priority-aware
job system backed by PostgreSQL SKIP LOCKED. Execute using subagents in the order defined
below. Rounds within a group are parallel; groups are sequential.

---

## Codebase Context (Read Before Spawning Anything)

**Stack:** Go 1.26 + Chi v5 + pgx/v5 + go-redis/v9 · PostgreSQL · Redis · Next.js 16 + React 19 + Tailwind v4 + shadcn/ui

**Backend root:** `mindforge/backend/`
**Frontend root:** `mindforge/frontend/`
**Go module:** `github.com/mindforge/backend`
**Next migration number:** `015`

**Build verification command (run after every agent group):**
```
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "/c/Users/jaisw/OneDrive/Desktop/dream/mindforge/backend:/app" \
  -w /app golang:1.26-alpine \
  sh -c "go build ./..."
```

### Files That Already Exist — Read Before Writing

| File | Relevant For |
|---|---|
| `internal/assessment/eval_worker.go` | Port this logic into `handlers/eval.go`, then delete |
| `internal/assessment/eval_queue.go` | Delete after porting |
| `internal/assessment/evaluator.go` | Eval handler calls functions from here |
| `internal/assessment/repo_eval.go` | Eval handler uses this repo |
| `internal/auth/email.go` | Email handler wraps these functions |
| `internal/ai/provider.go` | LLM handler uses this interface |
| `internal/orgs/cursor.go` | Copy cursor encode/decode logic into jobs store — do NOT import it |
| `internal/config/config.go` | Add new env vars here |
| `internal/api/router.go` | Wire job HTTP handler here |
| `internal/middleware/role.go` | Use RequireOrgRole / RequirePlatformRole |
| `internal/middleware/org.go` | Use GetOrgCtx |
| `cmd/server/main.go` | Refactor worker wiring in Round 6 |
| `db/migrations/001_schema.sql` | Jobs schema is already consolidated here |

### What Gets Deleted After Porting

- `internal/assessment/eval_queue.go`
- `internal/assessment/eval_worker.go`
- The `evalQueue`, `workerPool`, and recovery ticker goroutine in `cmd/server/main.go`

---

## Architecture

### Priority Levels

```go
const (
    PriorityCritical   Priority = 1  // password reset, security alert — user blocked
    PriorityHigh       Priority = 2  // assessment eval, email verification
    PriorityNormal     Priority = 3  // LLM calls, notifications
    PriorityLow        Priority = 4  // bulk invite chunks, report generation
    PriorityBackground Priority = 5  // cron: SRS reminders, analytics rollup, cleanup
)
```

### Job Lifecycle

```
pending → queued → running → success
                           → failed → (retry_count < max_retries) → queued
                                    → (retry_count >= max_retries) → dead
                           → cancelled
```

Pending: job inserted but not ready to run (delayed).
Queued: ready to be claimed by a worker.
Workers only claim `queued` rows with `run_at <= NOW()`.

### Noisy Neighbor Prevention

- P1/P2 jobs: bypass per-org concurrency quota entirely
- P3-P5 jobs: claim only when `running_count_for_org < max_concurrent`
- Default max_concurrent per org: 5
- System cron jobs (org_id IS NULL): always claimable, no quota

### Horizontal Scaling

- All instances run workers (claim from same pg table, SKIP LOCKED prevents double-claim)
- Only one instance runs the scheduler: leader election via Redis SETNX with 30s TTL + 10s renewal
- Stateless workers — any instance handles any job type
- No external queue daemon needed; PostgreSQL is the queue

### Core Claim Query

```sql
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
RETURNING *;
```

---

## Migration 015 — Full Schema

Schema is already in `db/migrations/001_schema.sql` (jobs section). No migration file to create.

```sql
CREATE TABLE jobs (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    handler          TEXT NOT NULL,
    status           TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','queued','running','success','failed','dead','cancelled')),
    priority         SMALLINT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    payload          JSONB NOT NULL DEFAULT '{}',
    job_type         TEXT NOT NULL DEFAULT 'one_time' CHECK (job_type IN ('one_time','cron')),
    schedule         TEXT,
    run_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    next_run_at      TIMESTAMPTZ,
    last_run_at      TIMESTAMPTZ,
    last_duration_ms INT,
    last_error       TEXT,
    max_retries      SMALLINT NOT NULL DEFAULT 3,
    retry_count      SMALLINT NOT NULL DEFAULT 0,
    timeout_ms       INT NOT NULL DEFAULT 30000,
    idempotency_key  TEXT UNIQUE,
    org_id           UUID REFERENCES organizations(id) ON DELETE CASCADE,
    created_by       UUID REFERENCES users(id) ON DELETE SET NULL,
    worker_id        TEXT,
    claimed_at       TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at       TIMESTAMPTZ
);

CREATE TABLE job_runs (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id       UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    status       TEXT NOT NULL
                 CHECK (status IN ('running','success','failed','timeout','cancelled')),
    attempt      SMALLINT NOT NULL DEFAULT 1,
    worker_id    TEXT NOT NULL,
    started_at   TIMESTAMPTZ,
    finished_at  TIMESTAMPTZ,
    duration_ms  INT,
    error        TEXT,
    heartbeat_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE org_job_quotas (
    org_id          UUID PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
    max_concurrent  INT NOT NULL DEFAULT 5,
    max_queued      INT NOT NULL DEFAULT 200,
    priority_floor  SMALLINT NOT NULL DEFAULT 5,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_jobs_claim    ON jobs (priority ASC, run_at ASC)
    WHERE status = 'queued' AND deleted_at IS NULL;
CREATE INDEX idx_jobs_org_list ON jobs (org_id, created_at DESC)
    WHERE deleted_at IS NULL;
CREATE INDEX idx_jobs_orphan   ON jobs (claimed_at)
    WHERE status = 'running';
CREATE INDEX idx_jobs_cron     ON jobs (next_run_at ASC)
    WHERE job_type = 'cron' AND deleted_at IS NULL AND status != 'cancelled';
CREATE INDEX idx_runs_job      ON job_runs (job_id, created_at DESC);
CREATE INDEX idx_runs_heartbeat ON job_runs (heartbeat_at)
    WHERE status = 'running';
```

---

## Package Structure

```
internal/jobs/
  types.go           Job, JobRun, EnqueueParams, Status/Priority consts,
                     Handler interface, sentinel errors
  store.go           All DB ops: Enqueue, ClaimOne, Heartbeat, Complete,
                     Fail, Cancel, ForceRetry, List, GetByID, OrgStats,
                     PlatformStats, UpdateQuota, GetQuota, SetNextCronRun,
                     ActivateDue (pending→queued)
  registry.go        Thread-safe handler registry: Register, Get, MustGet, All
  quota.go           CheckEnqueueQuota (count queued for org vs max_queued),
                     EnforcePriorityFloor (clamp priority to org's priority_floor)
  worker.go          Worker pool: N goroutines, claim loop, heartbeat ticker,
                     panic recovery, timeout context, graceful drain on SIGTERM
  scheduler.go       Leader election (Redis SETNX), cron dispatcher, orphan reaper,
                     delayed job activator, missed-cron recovery on startup
  handler_http.go    Chi HTTP routes: org admin API + super admin API

internal/jobs/handlers/
  eval.go            Port of eval_worker.go processJob() — implements Handler
  email.go           Email delivery (auth_verify, password_reset, eval_complete,
                     notification) — wraps internal/auth/email.go
  invite.go          Bulk invite splitter: receives full list, chunks 50/batch,
                     enqueues each chunk as email.bulk_invite P4 job
  llm.go             course_outline + interview_review via ai.LLMProvider
  srs.go             Daily SRS reminder: query due users, enqueue email.notification
  analytics.go       Nightly rollup + expired token/session/jti cleanup
```

---

## Config Additions

Add to `internal/config/config.go` (env name → field name → default):

```
WORKER_POOL_SIZE              WorkerPoolSize              10
WORKER_HEARTBEAT_INTERVAL     WorkerHeartbeatInterval     15s
WORKER_DRAIN_TIMEOUT          WorkerDrainTimeout          30s
ORPHAN_REAPER_INTERVAL        OrphanReaperInterval        30s
ORPHAN_THRESHOLD              OrphanThreshold             60s
SCHEDULER_LEADER_TTL          SchedulerLeaderTTL          30s
SCHEDULER_LEADER_RENEW        SchedulerLeaderRenew        10s
```

Parse durations with `time.ParseDuration`. Fatal on invalid values.

---

## Handler Interface & Payload Schemas

```go
// types.go
type Handler interface {
    Handle(ctx context.Context, job Job) error
}

type Job struct {
    ID             string
    Handler        string
    Priority       Priority
    Payload        json.RawMessage
    OrgID          *string
    Attempt        int
    MaxRetries     int
    TimeoutMS      int
}
```

Each handler defines its own payload struct and unmarshals in `Handle`.

```go
// handlers/eval.go
type EvalPayload struct {
    AttemptID string `json:"attempt_id"`
}

// handlers/email.go
type EmailPayload struct {
    Type         string         `json:"type"` // auth_verify|password_reset|eval_complete|notification
    To           string         `json:"to"`
    ToName       string         `json:"to_name"`
    TemplateData map[string]any `json:"template_data"`
}

// handlers/invite.go
type BulkInvitePayload struct {
    OrgID     string   `json:"org_id"`
    InviterID string   `json:"inviter_id"`
    Emails    []string `json:"emails"`   // this chunk's emails (max 50)
    Role      string   `json:"role"`
}

// handlers/llm.go
type LLMPayload struct {
    Task     string         `json:"task"`      // course_outline|interview_review
    EntityID string         `json:"entity_id"` // course_id or practice_session_id
    Params   map[string]any `json:"params"`
}

// handlers/srs.go
type SRSReminderPayload struct{}

// handlers/analytics.go
type AnalyticsPayload struct {
    Date string `json:"date"` // YYYY-MM-DD for rollup
}
```

---

## HTTP API Surface

### Org Admin (RequireOrgRole: admin, instructor)

```
GET  /api/orgs/{orgID}/jobs
     Query: status, handler, priority, after (cursor), limit (max 50)
     Response: {data: {jobs: [...], next_cursor: string}}

GET  /api/orgs/{orgID}/jobs/{jobID}
     Response: {data: {job: {...}, runs: [last 20 runs]}}

POST /api/orgs/{orgID}/jobs/{jobID}/cancel
     Only for status in (pending, queued). Returns 409 otherwise.

POST /api/orgs/{orgID}/jobs/{jobID}/retry
     Only for status in (failed, dead). Resets retry_count=0, status=queued.

PATCH /api/orgs/{orgID}/jobs/{jobID}
     Body: {paused: true|false}. Only for job_type=cron.
     Pausing sets deleted_at=NOW(). Resuming clears deleted_at.
```

### Super Admin (RequirePlatformRole: super_admin)

```
GET  /api/admin/jobs
     Query: org_id, status, handler, after, limit

GET  /api/admin/jobs/workers
     Response: {data: {workers: [{instance_id, slots_busy, last_seen}], leader: string}}
     Workers register their heartbeat in Redis key jobs:worker:{id} (TTL 30s)

GET  /api/admin/jobs/stats
     Response: {data: {per_org: [{org_id, org_name, running, queued, failed, dead, quota}]}}

PATCH /api/admin/orgs/{orgID}/job-quotas
     Body: {max_concurrent, max_queued, priority_floor}

POST /api/admin/orgs/{orgID}/jobs/pause-all
     Cancels all pending+queued jobs for the org. Returns {data: {cancelled: N}}.

POST /api/admin/jobs/{jobID}/force-retry
     Bypasses org quotas. Sets status=queued, retry_count=0.
```

---

## Edge Cases — Every Agent Must Handle These

### Worker Edge Cases

1. **SIGTERM during job execution** — context is cancelled. Worker must NOT mark job failed.
   Leave it running in DB; orphan reaper will reclaim it within OrphanThreshold.
   Worker drain: stop claiming, wait for in-flight jobs to finish up to WorkerDrainTimeout, then exit.

2. **Handler panic** — wrap `Handle()` in `recover()`. Convert panic to error, mark job failed,
   log with `slog.Error` including stack trace from `runtime/debug.Stack()`.

3. **Job timeout** — use `context.WithTimeout(workerCtx, time.Duration(job.TimeoutMS)*time.Millisecond)`.
   Cancel context when timeout fires. Treat context.DeadlineExceeded as a retriable failure.

4. **Heartbeat DB failure** — log warning and continue job. Job heartbeat failure is non-fatal.
   The reaper will eventually reclaim if the worker truly dies.

5. **Handler not in registry** — `MustGet` panics at startup if a handler key registered in
   cron config is missing. At runtime, if ClaimOne returns a job with unknown handler,
   log error and mark job dead immediately (do not retry — handler is missing in this binary).

### Scheduler Edge Cases

6. **Cron double-enqueue prevention** — before enqueueing a cron job, check:
   `SELECT COUNT(*) FROM jobs WHERE handler=$1 AND org_id IS NULL AND status IN ('queued','running')`
   If > 0, skip this tick. Log "cron skipped: already running".

7. **Missed cron ticks** — on startup, before opening HTTP: query cron jobs where
   `next_run_at < NOW() - interval '1 minute'`. Set their `next_run_at = NOW()` so they
   run once on the next scheduler tick, not once per missed tick.

8. **Leader failover** — the new leader will pick up scheduling naturally on its next tick.
   No special recovery needed beyond the missed-cron startup fix above.

9. **Clock skew across instances** — use `run_at <= NOW()` queries only. Never compare
   local time to DB time directly.

### Enqueue Edge Cases

10. **Duplicate idempotency_key** — use `INSERT ... ON CONFLICT (idempotency_key) DO NOTHING`.
    If 0 rows inserted, query and return the existing job. This is not an error — return 200 with existing job.

11. **Org at max_queued limit** — before INSERT, count:
    `SELECT COUNT(*) FROM jobs WHERE org_id=$1 AND status IN ('pending','queued')`.
    If >= max_queued, return ErrQuotaExceeded. HTTP layer maps to 429.

12. **Priority floor enforcement** — if enqueued priority < org's priority_floor, silently clamp
    to priority_floor. (Lower priority number = higher urgency; floor = least urgent allowed.)

13. **Unknown handler key** — validate handler exists in registry before DB insert. Return ErrUnknownHandler.
    HTTP layer maps to 400.

14. **Null org_id for system jobs** — cron and cleanup jobs have org_id=nil. Skip quota check for these.

### Tenant Isolation

15. **Org admin list scoped by org_id** — every query in org-admin endpoints has `AND org_id = $orgID`
    where $orgID comes from the JWT middleware org context, never from query params.

16. **Cross-org payload reference prevention** — handlers that load DB rows (eval, llm) must
    verify the loaded entity's org_id matches job.OrgID before processing.
    If mismatch, mark job dead with error "org_id mismatch, refusing to process".

17. **Super admin cannot execute as another org** — super admin can retry/cancel jobs but cannot
    enqueue jobs on behalf of another org from the admin API.

### Observability

18. **Every state transition logs** — log at `slog.Info` with fields:
    `job_id, handler, status, attempt, org_id, duration_ms`. Use `"jobs"` as the component key.

19. **Failed jobs log full context** — `slog.Error` with `job_id, handler, attempt, error`.
    Payload is logged only if it contains no PII (email addresses redacted, tokens omitted).

20. **Worker pool health log** — every 60s: `slog.Info("worker pool", "busy", N, "total", M)`.

21. **Cron scheduler log** — every tick: `slog.Info("cron tick", "handler", h, "next_run_at", t, "skipped", bool)`.

22. **Worker registration in Redis** — each worker instance sets `jobs:worker:{instanceID}` with
    JSON payload `{slots_busy, slots_total, started_at}` and TTL 30s, renewed every 10s.
    Super admin workers endpoint reads these keys to show live health.

---

## DRY Rules — One Place for Everything

| Concern | Where It Lives | Nowhere Else |
|---|---|---|
| DB enqueue | `store.Enqueue` | No direct INSERT outside this function |
| DB claim | `store.ClaimOne` | No other code sets status='running' |
| Status transitions | `store.Complete`, `store.Fail`, `store.Cancel` | No UPDATE status outside store.go |
| Cursor encode/decode | `store.go` (copy from orgs/cursor.go, do not import) | No second cursor package |
| Error→HTTP mapping | `handler_http.go mapError()` | Handlers return domain errors only |
| Quota check | `quota.CheckEnqueueQuota`, `quota.EnforcePriorityFloor` | Called from store.Enqueue |
| Structured logging | `slog` stdlib | No fmt.Printf, no custom logger |
| Handler payload unmarshal | Inside each handler's `Handle()` | Not in worker.go or store.go |

---

## Subagent Execution Plan

Run agents as specified — parallel groups can be spawned simultaneously.
Each agent must read the files listed in "Files That Already Exist" above before writing.
Every agent uses `model: "sonnet"` unless marked `(haiku)`.

---

### GROUP 1 — Foundation (spawn all in parallel)

**Agent A — Migration + Types** `(haiku)`

Write two files:

1. `internal/jobs/types.go` — package `jobs`. Define:
   - `type Priority = int` with constants P1–P5
   - `type Status = string` with all status constants
   - `type Job struct` with all fields (id, handler, status, priority, payload json.RawMessage, job_type, schedule, run_at, next_run_at, org_id *string, created_by *string, attempt int, max_retries int, timeout_ms int, worker_id *string)
   - `type JobRun struct` with all fields
   - `type EnqueueParams struct` (handler, priority, payload any, job_type, schedule, run_at *time.Time, max_retries *int, timeout_ms *int, idempotency_key *string, org_id *string, created_by *string)
   - `type Handler interface { Handle(ctx context.Context, job Job) error }`
   - Sentinel errors: `ErrJobNotFound`, `ErrQuotaExceeded`, `ErrUnknownHandler`, `ErrDuplicateKey`

**Agent B — Config additions** `(haiku)`

Read `internal/config/config.go` fully. Add the seven new fields listed in the Config Additions
section above. Follow the existing pattern exactly (same struct, same env loading style, same fatal
validation). Do not break any existing fields.

---

### GROUP 2 — Core Store + Registry (after Group 1)

**Agent C — Store**

Read `internal/jobs/types.go` (from Agent A). Read `internal/orgs/cursor.go` for the
cursor encode/decode pattern.

Write `internal/jobs/store.go`. Implement every function:

- `Enqueue(ctx, pool, registry, params EnqueueParams) (Job, error)`:
  1. Validate handler exists in registry → ErrUnknownHandler
  2. Enforce priority floor from org quota → clamp if needed
  3. Check max_queued for org → ErrQuotaExceeded
  4. INSERT with ON CONFLICT (idempotency_key) DO NOTHING
  5. If 0 rows inserted, SELECT existing and return with ErrDuplicateKey (caller decides if error)
  6. Set initial status='pending' if run_at > NOW(), else 'queued'

- `ActivateDue(ctx, pool) (int64, error)`:
  UPDATE jobs SET status='queued' WHERE status='pending' AND run_at <= NOW() — returns rows affected

- `ClaimOne(ctx, pool, workerID string) (*Job, error)`:
  Exact claim query from the Architecture section. Returns nil, nil if nothing available.

- `Heartbeat(ctx, pool, runID string) error`
- `Complete(ctx, pool, jobID, runID string, durationMS int) error` — in transaction: update job (success, last_run_at, last_duration_ms, clear worker_id/claimed_at), update run (success, finished_at)
- `Fail(ctx, pool, jobID, runID string, jobErr error, durationMS int) error` — in transaction:
  if retry_count+1 < max_retries → status=queued, retry_count++, run_at=NOW()+backoff(retry_count)
  else → status=dead, last_error=err.Error()
  Backoff: 2^retry_count * 2 seconds (capped at 5 minutes)
- `Cancel(ctx, pool, jobID string, orgID *string) error` — scoped by orgID if not nil, only pending/queued
- `ForceRetry(ctx, pool, jobID string) error` — sets status=queued, retry_count=0, no org scope check
- `List(ctx, pool, filter ListFilter) ([]Job, string, error)` — cursor paginated (base64url encode created_at:id), max 50
- `GetByID(ctx, pool, jobID string, orgID *string) (Job, error)` — scoped by orgID if not nil
- `GetRuns(ctx, pool, jobID string, limit int) ([]JobRun, error)`
- `OrgStats(ctx, pool, orgID string) (OrgJobStats, error)` — counts by status
- `PlatformStats(ctx, pool) ([]OrgJobStats, error)` — per org, joined with organizations.name
- `GetQuota(ctx, pool, orgID string) (Quota, error)`
- `UpdateQuota(ctx, pool, orgID string, q Quota) error`
- `SetNextCronRun(ctx, pool, jobID string, nextRunAt time.Time) error`
- `RegisterWorker(ctx, rdb *redis.Client, instanceID string, busy, total int) error` — SETEX jobs:worker:{id} 30s JSON
- `ListWorkers(ctx, rdb *redis.Client) ([]WorkerInfo, error)` — KEYS jobs:worker:* + GET each
- `GetSchedulerLeader(ctx, rdb *redis.Client) (string, error)` — GET jobs:scheduler:leader

**Agent D — Registry + Quota** `(haiku)`

Read `internal/jobs/types.go`.

Write `internal/jobs/registry.go`:
- Thread-safe (sync.RWMutex) map[string]Handler
- `Register(key string, h Handler)` — panics if key already registered
- `Get(key string) (Handler, bool)`
- `MustGet(key string) Handler` — panics if not found (used at startup validation)
- `All() []string` — returns sorted list of registered handler keys

Write `internal/jobs/quota.go`:
- `CheckEnqueueQuota(ctx, pool, orgID string, quota Quota) error` — count pending+queued, compare to max_queued
- `EnforcePriorityFloor(requested Priority, floor Priority) Priority` — returns max(requested, floor)
  (higher number = lower urgency, so max clamps to least urgent)
- Both functions are pure helpers called from store.Enqueue

---

### GROUP 3 — Runtime (after Group 2)

**Agent E — Worker Pool**

Read `internal/jobs/types.go`, `internal/jobs/store.go`, `internal/jobs/registry.go`,
`internal/config/config.go`.
Read `internal/assessment/eval_worker.go` to understand the existing pattern.

Write `internal/jobs/worker.go`. Implement:

```go
type WorkerPool struct { /* pool, rdb, registry, cfg, instanceID */ }
func NewWorkerPool(pool *pgxpool.Pool, rdb *redis.Client, registry *Registry, cfg *config.Config) *WorkerPool
func (p *WorkerPool) Start(ctx context.Context)     // blocks until all workers exit
func (p *WorkerPool) SlotsBusy() int                // atomic counter for monitoring
```

Each worker goroutine loop:
1. Call `store.ClaimOne` — if nil, sleep 500ms and retry
2. Create `job_run` record via store (insert with status=running)
3. Start heartbeat goroutine: every WorkerHeartbeatInterval call `store.Heartbeat(runID)`, stop on done channel
4. Wrap handler call: `context.WithTimeout(ctx, timeout)` + `recover()` for panics
5. On success: stop heartbeat, call `store.Complete`
6. On error (including panic recovery): stop heartbeat, call `store.Fail`
7. On unknown handler: call `store.Fail` with a permanent error, mark dead immediately
8. Log every state with slog.Info/Error

Graceful drain on ctx.Done():
- Stop claiming immediately
- Let in-flight jobs finish
- Wait up to WorkerDrainTimeout
- Exit

Health registration: every 10s call `store.RegisterWorker(ctx, rdb, instanceID, busy, total)`.

**Agent F — Scheduler**

Read `internal/jobs/types.go`, `internal/jobs/store.go`, `internal/config/config.go`.

Write `internal/jobs/scheduler.go`. Implement:

```go
type Scheduler struct { /* pool, rdb, cfg, instanceID, cronJobs []CronJobDef */ }
type CronJobDef struct { Handler string; Schedule string; Priority Priority; TimeoutMS int }
func NewScheduler(pool, rdb, cfg, instanceID string, cronJobs []CronJobDef) *Scheduler
func (s *Scheduler) Start(ctx context.Context)  // blocks until ctx done
```

Four loops (all started in Start as goroutines, wait on WaitGroup):

1. **Leader election loop** (runs always, every SchedulerLeaderRenew):
   Try SETNX `jobs:scheduler:leader` with SchedulerLeaderTTL. If won, set `isLeader=true`.
   If lost, EXPIRE to renew if we already hold it. Track `isLeader` atomically.

2. **Cron dispatcher** (runs every 60s, only if isLeader):
   For each registered CronJobDef: parse schedule, check if next_run_at <= NOW().
   Before enqueue, verify no queued/running job with same handler + nil org_id.
   Enqueue if due, update next_run_at via `store.SetNextCronRun`.

3. **Delayed job activator** (runs every 5s, only if isLeader):
   Call `store.ActivateDue` — moves pending → queued for jobs where run_at <= NOW().

4. **Orphan reaper** (runs every OrphanReaperInterval, only if isLeader):
   Query: `SELECT j.id, jr.id as run_id FROM jobs j JOIN job_runs jr ON jr.job_id=j.id
   WHERE j.status='running' AND jr.status='running' AND jr.heartbeat_at < NOW() - $threshold`.
   For each: call `store.Fail(jobID, runID, errors.New("orphan: worker heartbeat lost"), 0)`.

5. **Missed cron recovery** (runs once on startup, before loops):
   Query cron jobs where next_run_at < NOW() - 1 minute.
   Set next_run_at = NOW() for each so they fire on the next cron tick.

---

### GROUP 4 — Handlers (after Group 3, spawn all in parallel)

**Agent G — Eval Handler**

Read ALL of the following before writing:
- `internal/assessment/eval_worker.go` — port `processJob` exactly
- `internal/assessment/evaluator.go` — understand `evalQuestion`, `evalOverall`
- `internal/assessment/repo_eval.go` — understand repo methods used
- `internal/assessment/models.go` — understand types
- `internal/jobs/types.go` — Handler interface

Write `internal/jobs/handlers/eval.go`:
- Package `handlers`
- Struct `EvalHandler` with dependencies: `repo *assessment.Repo`, `ai ai.LLMProvider`, `cfg *config.Config`
- `func NewEvalHandler(repo, ai, cfg) *EvalHandler`
- `func (h *EvalHandler) Handle(ctx, job jobs.Job) error` — unmarshal EvalPayload, run full eval logic
  ported from processJob. Do NOT call `p.queue.Ack` — the worker pool handles completion.
  Do NOT call `sendEvalComplete` — enqueue an email.notification job via jobs.Store instead.
- Handler key constant: `const HandlerEvalSubjective = "eval.subjective"`

After writing, confirm all eval_worker.go logic is covered. Do NOT delete eval_worker.go yet
(that happens in Agent K).

**Agent H — Email + Invite Handlers**

Read `internal/auth/email.go`, `internal/jobs/types.go`.

Write `internal/jobs/handlers/email.go`:
- Struct `EmailHandler` with `cfg *config.Config`
- `Handle` unmarshals EmailPayload, switches on Type:
  - `auth_verify` → call `auth.SendVerificationEmail`
  - `password_reset` → call `auth.SendPasswordResetEmail`
  - `eval_complete` → call `assessment.SendEvalCompleteEmail`
  - `notification` → call generic notify function
- All functions already exist — this handler is a dispatcher. Import them.

Write `internal/jobs/handlers/invite.go`:
- Struct `InviteHandler` with `store` (jobs store reference), `orgInviteService`
- `Handle` receives BulkInvitePayload with a chunk of emails (max 50)
- Calls org invite service to send each email in the chunk
- Returns error if any single send fails (worker retries the whole chunk)
- The chunking happens in the HTTP layer (invite creation), not here

**Agent I — LLM + Cron Handlers**

Read `internal/ai/provider.go`, `internal/courses/handler_ai.go`, `internal/practice/handler.go`,
`internal/srs/repo.go`, `internal/jobs/types.go`.

Write `internal/jobs/handlers/llm.go`:
- Struct `LLMHandler` with `pool`, `ai ai.LLMProvider`, `cfg`
- `Handle` unmarshals LLMPayload, switches on Task:
  - `course_outline` → call existing outline gen logic from courses/handler_ai.go, store result
  - `interview_review` → call existing review logic from practice/handler.go, store result
- Check DB first: if outline/review already exists, skip LLM call (idempotency). CLAUDE.md rule 6.
- Handle `ai.ErrUnavailable` → return error (worker retries)
- Handle context timeout → return error (worker retries)

Write `internal/jobs/handlers/srs.go`:
- Struct `SRSHandler` with `pool`, `store jobsStore` (interface for enqueue)
- `Handle` runs the full batch: query all users where next review due, enqueue one
  `email.notification` job per user (P3). Chunked to avoid overwhelming the email handler.
- Handler key: `"srs.review_reminder"`

Write `internal/jobs/handlers/analytics.go`:
- Struct `AnalyticsHandler` with `pool`
- `Handle` switches on AnalyticsPayload.Date:
  If date set: aggregate assessment_scores, org activity for that date into analytics_summaries
  If date empty: run cleanup (DELETE FROM jti_blocklist WHERE expires_at < NOW(),
    DELETE FROM refresh_tokens WHERE expires_at < NOW(),
    DELETE FROM email_verifications WHERE expires_at < NOW() AND verified_at IS NOT NULL,
    DELETE FROM oauth_exchanges WHERE expires_at < NOW())
- All in a single transaction per operation

---

### GROUP 5 — HTTP Handler (after Group 4)

**Agent J — HTTP Handler**

Read `internal/jobs/store.go`, `internal/jobs/types.go`, `internal/middleware/role.go`,
`internal/middleware/org.go`, `internal/orgs/handler.go` (for response pattern),
`internal/httputil/response.go`.

Write `internal/jobs/handler_http.go`. Implement a `Handler` struct with `pool`, `rdb`, `cfg`.

Org admin routes (middleware: RequireAuth → RequireOrgMember → RequireOrgRole(admin, instructor)):
- `GET /api/orgs/{orgID}/jobs` — parse filter params, call store.List scoped to orgID from path
- `GET /api/orgs/{orgID}/jobs/{jobID}` — store.GetByID + store.GetRuns(20)
- `POST /api/orgs/{orgID}/jobs/{jobID}/cancel` — store.Cancel with orgID guard
- `POST /api/orgs/{orgID}/jobs/{jobID}/retry` — store.ForceRetry after verifying org ownership
- `PATCH /api/orgs/{orgID}/jobs/{jobID}` — pause/resume cron job (set/clear deleted_at)

Super admin routes (middleware: RequireAuth → RequirePlatformRole(super_admin)):
- `GET /api/admin/jobs` — store.List without org scope
- `GET /api/admin/jobs/workers` — store.ListWorkers + store.GetSchedulerLeader
- `GET /api/admin/jobs/stats` — store.PlatformStats
- `PATCH /api/admin/orgs/{orgID}/job-quotas` — store.UpdateQuota
- `POST /api/admin/orgs/{orgID}/jobs/pause-all` — cancel all pending+queued for org
- `POST /api/admin/jobs/{jobID}/force-retry` — store.ForceRetry no org check

`mapError(err error) (int, string)` — maps sentinel errors to HTTP status codes:
- ErrJobNotFound → 404
- ErrQuotaExceeded → 429
- ErrUnknownHandler → 400
- ErrDuplicateKey → 200 (return existing job, not error)
- default → 500

`RegisterRoutes(r chi.Router)` — attaches all routes with correct middleware.

---

### GROUP 6 — Wire-in + Cleanup (after Group 5)

**Agent K — Wire + Delete**

Read `cmd/server/main.go`, `internal/api/router.go`, all handler files.

Task 1: Refactor `cmd/server/main.go`:
- Remove: `evalQueue`, `workerPool`, recovery ticker goroutine
- Add after Redis init:
  ```go
  jobsRegistry := jobs.NewRegistry()
  jobsRegistry.Register(handlers.HandlerEvalSubjective, handlers.NewEvalHandler(...))
  jobsRegistry.Register(handlers.HandlerEmailSend, handlers.NewEmailHandler(cfg))
  jobsRegistry.Register(handlers.HandlerBulkInvite, handlers.NewInviteHandler(...))
  jobsRegistry.Register(handlers.HandlerLLM, handlers.NewLLMHandler(pool, aiProvider, cfg))
  jobsRegistry.Register(handlers.HandlerSRSReminder, handlers.NewSRSHandler(pool, jobsStore))
  jobsRegistry.Register(handlers.HandlerAnalytics, handlers.NewAnalyticsHandler(pool))

  jobsStore := jobs.NewStore()
  instanceID := os.Getenv("INSTANCE_ID") // default: hostname
  workerPool := jobs.NewWorkerPool(pool, rdb, jobsRegistry, cfg)
  cronDefs := []jobs.CronJobDef{
      {Handler: handlers.HandlerSRSReminder, Schedule: "0 8 * * *", Priority: jobs.PriorityBackground, TimeoutMS: 120000},
      {Handler: handlers.HandlerAnalytics, Schedule: "0 2 * * *", Priority: jobs.PriorityBackground, TimeoutMS: 300000},
      {Handler: handlers.HandlerAnalytics, Schedule: "0 * * * *", Priority: jobs.PriorityBackground, TimeoutMS: 60000},
  }
  scheduler := jobs.NewScheduler(pool, rdb, cfg, instanceID, cronDefs)

  go workerPool.Start(workerCtx)
  go scheduler.Start(workerCtx)
  ```
- Pass `jobsStore` and `jobsRegistry` into router for assessment handler to enqueue eval jobs

Task 2: Update `internal/api/router.go`:
- Remove evalQueue parameter
- Add jobsStore, jobsRegistry parameters
- Pass to assessment.New() so the attempt submit handler calls `jobsStore.Enqueue(...)` instead of `evalQueue.Enqueue(...)`
- Register `jobsHandler.RegisterRoutes(r)` inside the authed group

Task 3: Update `internal/assessment/handler_attempt.go`:
- Replace `evalQueue.Enqueue(EvalJob{AttemptID: id})` with
  `jobsStore.Enqueue(ctx, jobs.EnqueueParams{Handler: handlers.HandlerEvalSubjective, Priority: jobs.PriorityHigh, Payload: handlers.EvalPayload{AttemptID: id}, OrgID: &orgID, IdempotencyKey: &id})`

Task 4: Delete `internal/assessment/eval_queue.go` and `internal/assessment/eval_worker.go`.

Task 5: Run build verification. Fix any import cycle or missing symbol.
Build must pass: `go build ./...`

---

### GROUP 7 — Frontend + E2E Tests (after Group 6, spawn in parallel)

**Agent L — Org Admin Jobs UI**

Read `frontend/CLAUDE.md` fully before writing any frontend file.
Read `frontend/app/org/settings/` for the existing settings layout pattern.
Read `frontend/lib/server/orgs.ts` for the fetch pattern.

Write these files following CLAUDE.md frontend rules (server components, server actions,
semantic tokens only, max 300 lines/file, max 2 useState, no useEffect, no raw colors):

1. `frontend/lib/server/jobs.ts` — typed fetch functions:
   `fetchOrgJobs(orgID, filter)`, `fetchJob(orgID, jobID)`, `cancelJob(orgID, jobID)`,
   `retryJob(orgID, jobID)`, `pauseJob(orgID, jobID, paused)`.

2. `frontend/lib/jobs/types.ts` — TypeScript types matching the Go Job, JobRun, OrgJobStats.

3. `frontend/app/org/settings/jobs/page.tsx` — server component:
   - Status filter tabs (All / Running / Failed / Dead / Completed)
   - Handler filter dropdown
   - Job list table: handler, status badge, priority badge, created_at, duration, actions
   - Cursor-based pagination (Next page button, URL search param `after`)
   - Quota bar: X/Y slots used

4. `frontend/app/org/settings/jobs/[id]/page.tsx` — server component:
   - Job metadata card (handler, status, priority, payload preview, retry info)
   - Run history table (attempt, status, duration, error, started_at)
   - Action buttons: Cancel (if queued/pending), Retry (if failed/dead), Pause/Resume (if cron)
   - All actions as server actions in a co-located `actions.ts`

5. Add "Jobs" link to the org settings nav (wherever the nav list lives in `app/org/settings/`).

**Agent M — Super Admin Jobs UI**

Read `frontend/CLAUDE.md`. Read Agent L's output files for type reuse.

Write:

1. `frontend/lib/server/admin-jobs.ts` — `fetchAdminJobs`, `fetchWorkerHealth`, `fetchPlatformStats`, `updateOrgQuota`, `pauseOrgJobs`, `forceRetryJob`.

2. `frontend/app/admin/jobs/page.tsx` — platform-wide job list + per-org stats summary table.
   Stats table columns: Org name, Running, Queued, Failed, Dead, Quota (concurrent/max).
   Click row → filter list to that org.

3. `frontend/app/admin/jobs/workers/page.tsx` — worker health:
   Table: Instance ID, Slots busy/total, Last seen (relative), Leader badge.
   Auto-refreshes via router.refresh() on a 15s interval (one `setInterval` useEffect is justified here — mark with eslint-disable + reason comment).

4. `frontend/app/admin/orgs/[id]/quotas/page.tsx` — quota management form:
   Fields: max_concurrent, max_queued, priority_floor (select: 1–5).
   Server action to PATCH. Show current values. Confirm before save.

**Agent N — E2E Tests**

Read `internal/jobs/types.go`, `internal/jobs/store.go`, `internal/jobs/worker.go`,
`internal/jobs/scheduler.go`, `internal/jobs/registry.go`.
Read `internal/assessment/service_test.go` for the existing test pattern.

Write `internal/jobs/e2e_test.go`. Use `TEST_DATABASE_URL` env var for a real PostgreSQL
connection (skip tests if env not set: `t.Skipf("TEST_DATABASE_URL not set")`).
No mocks. No in-memory fakes. Real DB, real queries.

Test function names must start with `TestE2E_`:

1. `TestE2E_EnqueueAndClaim` — enqueue a job, call ClaimOne, verify status=running, call Complete, verify status=success.

2. `TestE2E_RetryOnFailure` — enqueue with max_retries=2, call ClaimOne + Fail, verify retry_count=1 status=queued. Claim again, Fail again, verify status=dead.

3. `TestE2E_IdempotentEnqueue` — enqueue same idempotency_key twice. Second enqueue must return same job ID. DB must have exactly one row.

4. `TestE2E_QuotaEnforcement` — create org with max_concurrent=2. Enqueue 5 P4 jobs. Claim in a loop. Verify at most 2 are claimed simultaneously (3rd ClaimOne returns nil).

5. `TestE2E_PriorityBypassesQuota` — same org at concurrent limit with 2 P4 jobs running. Enqueue a P2 job. ClaimOne must return the P2 job despite quota.

6. `TestE2E_OrphanRecovery` — insert a job_run directly with status=running and heartbeat_at=NOW()-5m. Run orphan reaper. Verify job is re-queued and retry_count incremented.

7. `TestE2E_CronScheduling` — insert a cron job with next_run_at=NOW()-1m. Run scheduler cron dispatch. Verify a new job_run is created and next_run_at is updated to the future.

8. `TestE2E_CancelJob` — enqueue a job, cancel it, call ClaimOne, verify nothing is returned.

9. `TestE2E_BulkInviteChunking` — register a fake InviteHandler that counts calls. Enqueue a bulk invite with 120 emails. Verify 3 jobs are created (50+50+20). Run all three workers. Verify handler called 3 times.

10. `TestE2E_TenantIsolation` — create two orgs. HTTP GET `/api/orgs/orgA/jobs/{jobB_id}` (job belongs to orgB) must return 404. Use `httptest.NewRecorder` + the real Chi router.

Use `t.Cleanup` to delete all test-created rows. Use a unique prefix on idempotency keys
to avoid collision across parallel test runs.

---

## Verification After All Agents Complete

```bash
# 1. Backend: build
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "/c/Users/jaisw/OneDrive/Desktop/dream/mindforge/backend:/app" \
  -w /app golang:1.26-alpine sh -c "go build ./..."

# 2. Backend: e2e tests (needs TEST_DATABASE_URL)
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "/c/Users/jaisw/OneDrive/Desktop/dream/mindforge/backend:/app" \
  -w /app \
  -e TEST_DATABASE_URL=postgres://... \
  golang:1.26-alpine \
  sh -c "go test ./internal/jobs/... -v -run TestE2E_ -timeout 120s"

# 3. Frontend: type check
cd mindforge/frontend && node_modules/.bin/tsc --noEmit

# 4. Confirm deletions
ls mindforge/backend/internal/assessment/eval_queue.go   # must NOT exist
ls mindforge/backend/internal/assessment/eval_worker.go  # must NOT exist
```

---

## Non-Negotiable Coding Rules

These apply to every agent, every file:

1. No stubs — every file is complete and production-ready. No `// TODO`, no `// FIXME`, no placeholder returns.
2. No hardcoded values — all config from `internal/config/config.go` env vars.
3. `fmt.Errorf("context: %w", err)` on every error path.
4. Multi-table writes inside `pgx` transactions.
5. Every protected HTTP route uses existing middleware (RequireAuth, RequireOrgMember, RequireOrgRole, RequirePlatformRole).
6. Validate handler key at enqueue boundary — not deep inside store or worker.
7. Frontend: semantic tokens only (`--primary`, `--muted`, `bg-background` etc.), no raw Tailwind colors, server components by default, server actions for mutations, max 300 lines/file.
8. `go build ./...` must pass after Agent K. `tsc --noEmit` must pass after Agent M.
