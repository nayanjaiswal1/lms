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
	ID            string
	Handler       string
	Status        Status
	Priority      Priority
	Payload       json.RawMessage
	JobType       string
	Schedule      *string
	RunAt         time.Time
	NextRunAt     *time.Time
	LastRunAt     *time.Time
	LastDurationMS *int
	LastError     *string
	MaxRetries    int
	RetryCount    int
	TimeoutMS     int
	IdempotencyKey *string
	OrgID         *string
	CreatedBy     *string
	WorkerID      *string
	ClaimedAt     *time.Time
	CreatedAt     time.Time
	UpdatedAt     time.Time
	DeletedAt     *time.Time
	// Attempt is populated from job_runs when worker claims the job
	Attempt       int
}

type JobRun struct {
	ID          string
	JobID       string
	Status      string
	Attempt     int
	WorkerID    string
	StartedAt   *time.Time
	FinishedAt  *time.Time
	DurationMS  *int
	Error       *string
	HeartbeatAt *time.Time
	CreatedAt   time.Time
}

type EnqueueParams struct {
	Handler        string
	Priority       Priority
	Payload        any
	JobType        string    // defaults to "one_time"
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
	OrgID     string
	OrgName   string
	Running   int
	Queued    int
	Failed    int
	Dead      int
	Quota     Quota
}

type Quota struct {
	MaxConcurrent int
	MaxQueued     int
	PriorityFloor Priority
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
