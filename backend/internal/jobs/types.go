package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"time"
)

type Priority = int

const (
	PriorityCritical   Priority = 1
	PriorityHigh       Priority = 2
	PriorityNormal     Priority = 3
	PriorityLow        Priority = 4
	PriorityBackground Priority = 5
)

type Status = string

const (
	StatusPending   Status = "pending"
	StatusQueued    Status = "queued"
	StatusRunning   Status = "running"
	StatusSuccess   Status = "success"
	StatusFailed    Status = "failed"
	StatusDead      Status = "dead"
	StatusCancelled Status = "cancelled"
)

// Sentinel errors
var (
	ErrJobNotFound    = errors.New("job not found")
	ErrQuotaExceeded  = errors.New("org job quota exceeded")
	ErrUnknownHandler = errors.New("unknown job handler")
	ErrDuplicateKey   = errors.New("idempotency key already exists")
)

type Handler interface {
	Handle(ctx context.Context, job Job) error
}

type Job struct {
	ID             string          `json:"id"`
	Handler        string          `json:"handler"`
	Status         Status          `json:"status"`
	Priority       Priority        `json:"priority"`
	Payload        json.RawMessage `json:"payload"`
	JobType        string          `json:"job_type"`
	Schedule       *string         `json:"schedule"`
	RunAt          time.Time       `json:"run_at"`
	NextRunAt      *time.Time      `json:"next_run_at"`
	LastRunAt      *time.Time      `json:"last_run_at"`
	LastDurationMS *int            `json:"last_duration_ms"`
	LastError      *string         `json:"last_error"`
	MaxRetries     int             `json:"max_retries"`
	RetryCount     int             `json:"retry_count"`
	TimeoutMS      int             `json:"timeout_ms"`
	IdempotencyKey *string         `json:"idempotency_key"`
	OrgID          *string         `json:"org_id"`
	CreatedBy      *string         `json:"created_by"`
	WorkerID       *string         `json:"worker_id"`
	ClaimedAt      *time.Time      `json:"claimed_at"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
	DeletedAt      *time.Time      `json:"deleted_at"`
	// Attempt is populated from job_runs when worker claims the job
	Attempt int `json:"-"`
}

type JobRun struct {
	ID          string     `json:"id"`
	JobID       string     `json:"job_id"`
	Status      string     `json:"status"`
	Attempt     int        `json:"attempt"`
	WorkerID    string     `json:"worker_id"`
	StartedAt   *time.Time `json:"started_at"`
	FinishedAt  *time.Time `json:"finished_at"`
	DurationMS  *int       `json:"duration_ms"`
	Error       *string    `json:"error"`
	HeartbeatAt *time.Time `json:"heartbeat_at"`
	CreatedAt   time.Time  `json:"created_at"`
}

type EnqueueParams struct {
	Handler        string
	Priority       Priority
	Payload        any
	JobType        string // defaults to "one_time"
	Schedule       *string
	RunAt          *time.Time
	MaxRetries     *int
	TimeoutMS      *int
	IdempotencyKey *string
	OrgID          *string
	CreatedBy      *string
}

type ListFilter struct {
	OrgID   *string
	Status  *string
	Handler *string
	After   string // cursor
	Limit   int
}

type OrgJobStats struct {
	OrgID   string `json:"org_id"`
	OrgName string `json:"org_name"`
	Running int    `json:"running"`
	Queued  int    `json:"queued"`
	Failed  int    `json:"failed"`
	Dead    int    `json:"dead"`
	Quota   Quota  `json:"quota"`
}

type Quota struct {
	MaxConcurrent int      `json:"max_concurrent"`
	MaxQueued     int      `json:"max_queued"`
	PriorityFloor Priority `json:"priority_floor"`
}

type WorkerInfo struct {
	InstanceID string    `json:"instance_id"`
	SlotsBusy  int       `json:"slots_busy"`
	SlotsTotal int       `json:"slots_total"`
	StartedAt  time.Time `json:"started_at"`
	LastSeen   time.Time `json:"last_seen"`
}

// ClaimedJob is returned by ClaimOne so the worker has both the job details
// and the job_runs row ID needed for heartbeat/complete/fail calls.
type ClaimedJob struct {
	Job   Job
	RunID string
}
