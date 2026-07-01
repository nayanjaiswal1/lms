package labs

import (
	"encoding/json"
	"time"
)

// ─── Platform constants ───────────────────────────────────────────────────────

const (
	MaxConcurrentSessionsDefault = 20
	MaxSessionDurationDefault    = 120 // minutes
	MaxHintsPerTask              = 3
	VerifyRateLimitSeconds       = 3
	ProvisionTimeoutSeconds      = 30
	IdleTimeoutMinutes           = 15
	ContainerCPU                 = "1.0"
	ContainerMemoryMB            = 512
	ContainerDiskGB              = 3
)

// ─── Enumerations (mirror the DB CHECK constraints) ──────────────────────────

const (
	// Lab scopes
	ScopeModule     = "module"
	ScopeCourse     = "course"
	ScopeStandalone = "standalone"

	// Lab types
	LabTypeTerminal   = "terminal"
	LabTypeCode       = "code"
	LabTypePlayground = "playground"
	LabTypeGuided     = "guided"

	// Session statuses
	SessionStatusProvisioning      = "provisioning"
	SessionStatusRunning           = "running"
	SessionStatusPaused            = "paused"
	SessionStatusCompleted         = "completed"
	SessionStatusExpired           = "expired"
	SessionStatusFailed            = "failed"
	SessionStatusTerminatedAbuse   = "terminated_abuse"

	// Task completion statuses
	TaskStatusPending = "pending"
	TaskStatusPassed  = "passed"
	TaskStatusSkipped = "skipped"

	// AI interaction types
	InteractionTypeHint      = "hint"
	InteractionTypeExplain   = "explain"
	InteractionTypeDiagnose  = "diagnose"
	InteractionTypeGenerate  = "generate"

	// Egress rule protocols
	ProtocolHTTP  = "http"
	ProtocolHTTPS = "https"
	ProtocolTCP   = "tcp"

	// Usage event types
	UsageEventContainerSeconds    = "container_seconds"
	UsageEventAITokens            = "ai_tokens"
	UsageEventValidationSeconds   = "validation_seconds"
)

// ─── Org-level defaults ───────────────────────────────────────────────────────

// LabOrgConfigDefaults holds the platform-wide default values applied when an
// org has no explicit lab_org_config row.
type LabOrgConfigDefaults struct {
	MaxConcurrentSessions int
	MaxSessionDuration    int // minutes
}

// DefaultLabOrgConfig returns the platform defaults for org-level lab config.
func DefaultLabOrgConfig() LabOrgConfigDefaults {
	return LabOrgConfigDefaults{
		MaxConcurrentSessions: MaxConcurrentSessionsDefault,
		MaxSessionDuration:    MaxSessionDurationDefault,
	}
}

// ─── JSONB payload types ──────────────────────────────────────────────────────

// TaskSnapshot is the shape of a single task record stored inside the
// lab_task_versions.tasks JSONB array. It freezes the task content at publish
// time so future edits to lab_tasks do not alter historical sessions.
type TaskSnapshot struct {
	ID                  string `json:"id"`
	Position            int    `json:"position"`
	Title               string `json:"title"`
	Description         string `json:"description"`
	VerificationScript  string `json:"verification_script"`
	HintContext         string `json:"hint_context,omitempty"`
	ExplanationContext  string `json:"explanation_context,omitempty"`
	Points              int    `json:"points"`
	IsOptional          bool   `json:"is_optional"`
	IsStateful          bool   `json:"is_stateful"`
}

// ─── Domain rows ─────────────────────────────────────────────────────────────

type LabOrgConfig struct {
	OrgID                  string    `json:"org_id"`
	MaxConcurrentSessions  int       `json:"max_concurrent_sessions"`
	MaxSessionDuration     int       `json:"max_session_duration"`
	AllowedImages          []string  `json:"allowed_images"`
	EgressProxyEnabled     bool      `json:"egress_proxy_enabled"`
	UpdatedAt              time.Time `json:"updated_at"`
}

type LabDefinition struct {
	ID                 string     `json:"id"`
	OrgID              string     `json:"org_id"`
	CourseID           *string    `json:"course_id"`
	ModuleID           *string    `json:"module_id"`
	Scope              string     `json:"scope"`
	Title              string     `json:"title"`
	Description        *string    `json:"description"`
	LabType            string     `json:"lab_type"`
	Environment        string     `json:"environment"`
	SetupScript        *string    `json:"setup_script"`
	MaxDuration        int        `json:"max_duration"`
	MaxResets          int        `json:"max_resets"`
	HintPenaltyPct     int        `json:"hint_penalty_pct"`
	IsRequired         bool       `json:"is_required"`
	IsPublished        bool       `json:"is_published"`
	PublishedVersionID *string    `json:"published_version_id"`
	CreatedBy          string     `json:"created_by"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

type LabTask struct {
	ID                 string    `json:"id"`
	LabID              string    `json:"lab_id"`
	Position           int       `json:"position"`
	Title              string    `json:"title"`
	Description        string    `json:"description"`
	VerificationScript string    `json:"verification_script"`
	HintContext        *string   `json:"hint_context"`
	ExplanationContext *string   `json:"explanation_context"`
	Points             int       `json:"points"`
	IsOptional         bool      `json:"is_optional"`
	IsStateful         bool      `json:"is_stateful"`
	CreatedAt          time.Time `json:"created_at"`
}

type LabTaskVersion struct {
	ID          string          `json:"id"`
	LabID       string          `json:"lab_id"`
	Version     int             `json:"version"`
	Tasks       json.RawMessage `json:"tasks"` // []TaskSnapshot
	PublishedBy string          `json:"published_by"`
	PublishedAt time.Time       `json:"published_at"`
}

type LabSession struct {
	ID             string     `json:"id"`
	LabID          string     `json:"lab_id"`
	TaskVersionID  string     `json:"task_version_id"`
	UserID         string     `json:"user_id"`
	OrgID          string     `json:"org_id"`
	ContainerID    *string    `json:"container_id"`
	ContainerHost  *string    `json:"container_host"`
	Status         string     `json:"status"`
	ResetCount     int        `json:"reset_count"`
	Score          int        `json:"score"`
	IsTest         bool       `json:"is_test"`
	StartedAt      time.Time  `json:"started_at"`
	ExpiresAt      time.Time  `json:"expires_at"`
	PausedSeconds  int        `json:"paused_seconds"`
	CompletedAt    *time.Time `json:"completed_at"`
	LastActiveAt   time.Time  `json:"last_active_at"`
}

type LabTaskCompletion struct {
	ID          string     `json:"id"`
	SessionID   string     `json:"session_id"`
	TaskID      string     `json:"task_id"`
	Status      string     `json:"status"`
	Attempts    int        `json:"attempts"`
	HintsUsed   int        `json:"hints_used"`
	CompletedAt *time.Time `json:"completed_at"`
}

type LabAIInteraction struct {
	ID              string    `json:"id"`
	SessionID       string    `json:"session_id"`
	TaskID          *string   `json:"task_id"`
	InteractionType string    `json:"interaction_type"`
	HintLevel       *int      `json:"hint_level"`
	CacheKey        *string   `json:"cache_key"`
	Prompt          string    `json:"prompt"`
	Response        string    `json:"response"`
	TokensUsed      *int      `json:"tokens_used"`
	CreatedAt       time.Time `json:"created_at"`
}

type LabEgressRule struct {
	ID        string    `json:"id"`
	LabID     string    `json:"lab_id"`
	Host      string    `json:"host"`
	Port      *int      `json:"port"`
	Protocol  string    `json:"protocol"`
	Reason    *string   `json:"reason"`
	CreatedAt time.Time `json:"created_at"`
}

type LabUsageEvent struct {
	ID         string    `json:"id"`
	OrgID      string    `json:"org_id"`
	SessionID  *string   `json:"session_id"`
	EventType  string    `json:"event_type"`
	Quantity   int64     `json:"quantity"`
	Image      *string   `json:"image"`
	RecordedAt time.Time `json:"recorded_at"`
}

type LabAnalytics struct {
	LabID              string          `json:"lab_id"`
	Day                time.Time       `json:"day"`
	SessionsStarted    int             `json:"sessions_started"`
	SessionsCompleted  int             `json:"sessions_completed"`
	AvgDurationSec     int             `json:"avg_duration_sec"`
	AvgScore           float64         `json:"avg_score"`
	TotalHintsUsed     int             `json:"total_hints_used"`
	PerTaskPassRate    json.RawMessage `json:"per_task_pass_rate"` // map[taskID]float64
	ComputedAt         time.Time       `json:"computed_at"`
}
