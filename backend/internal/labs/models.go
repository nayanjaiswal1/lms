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
	// ProvisionTimeoutSeconds must cover docker run + the setup_script's
	// readiness probe across DockerContainerService.Start's retry loop.
	// Web-app lab images (lab-python-web, lab-node-web) boot a dev server
	// via their entrypoint's app-runner before the probe passes — Vite cold
	// starts alone can take >15s under the 1-CPU/512MB container limits, so
	// the old 30s budget hard-failed sessions that were about to succeed.
	ProvisionTimeoutSeconds      = 90
	IdleTimeoutMinutes           = 15
	ContainerCPU                 = "1.0"
	ContainerMemoryMB            = 512
	ContainerDiskGB              = 3
	// WarmContainerNamePrefix names pre-provisioned pool sandboxes
	// ("mindforge-warm-{warmID}"), keeping them out of LabCleanupHandler's
	// "mindforge-lab-" orphan scan — the warm-pool reconciler owns their
	// lifecycle instead.
	WarmContainerNamePrefix = "mindforge-warm-"
	// WarmPoolMaxStartsPerTick bounds how many warm containers a single
	// reconciler run may provision, so a fleet-wide deficit ramps up
	// gradually instead of saturating the host in one tick.
	WarmPoolMaxStartsPerTick = 4
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
	LabTypeSandbox    = "sandbox"

	// Workspace layouts
	LabLayoutSplit   = "split"
	LabLayoutConsole = "console"

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
	// PreviewPort is the container port where the lab's own application
	// listens (Django/FastAPI/Vite web labs); 0 = no live preview pane.
	// Served to the browser through labproxy's /preview/{token}/ proxy.
	PreviewPort        int        `json:"preview_port"`
	// Language is the authoritative language for a "code" type lab (required
	// by the DB CHECK constraint whenever lab_type = 'code'; nil for
	// terminal/guided/playground labs, which have no student code editor).
	Language           *string    `json:"language"`
	SetupScript        *string    `json:"setup_script"`
	// RunScript is the instructor-authored sample-test command for sandbox
	// labs, executed in the session container by POST /sessions/:id/run.
	// nil = no Run button. Never serialized to students (see labStudentResponse
	// — only a has_run_script boolean crosses the wire).
	RunScript          *string    `json:"-"`
	MaxDuration        int        `json:"max_duration"`
	MaxResets          int        `json:"max_resets"`
	HintPenaltyPct     int        `json:"hint_penalty_pct"`
	IsRequired         bool       `json:"is_required"`
	IsPublished        bool       `json:"is_published"`
	PublishedVersionID *string    `json:"published_version_id"`
	// WorkspaceLayout selects how the student workspace is arranged: "split"
	// (default, side-by-side task list + terminal/editor) or "console"
	// (Google Cloud Shell style — full-width checklist with a collapsible
	// terminal drawer). See migration 033_lab_workspace_layout.sql.
	WorkspaceLayout    string     `json:"workspace_layout"`
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
	// EndReason distinguishes an automatic reaper termination ("time_limit" or
	// "idle_timeout") from a normal user-driven end/completion, which leaves
	// this nil. Set only by the lab.expire_sessions background job.
	EndReason      *string    `json:"end_reason"`
}

// ActiveLabSession is a lab_sessions row enriched with the lab's title and
// type, for showing a "resume or close" surface across page loads and logins
// without the client having to hold any in-memory launch state.
type ActiveLabSession struct {
	SessionID    string    `json:"session_id"`
	LabID        string    `json:"lab_id"`
	LabTitle     string    `json:"lab_title"`
	LabType      string    `json:"lab_type"`
	Status       string    `json:"status"`
	StartedAt    time.Time `json:"started_at"`
	ExpiresAt    time.Time `json:"expires_at"`
	LastActiveAt time.Time `json:"last_active_at"`
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
	ID         int64     `json:"id"`
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
