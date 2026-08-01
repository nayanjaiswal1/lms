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
	// Nested-Docker images additionally need room for startNamed's full
	// scoped-then-privileged retry on a proxied-socket host: the scoped
	// attempt runs its entrypoint's own ~70s dockerd-readiness loop to
	// completion before failing, then the privileged retry needs another
	// ~20-30s to boot dockerd for real — comfortably under this budget with
	// margin. A real Linux Docker Engine host never hits the retry at all,
	// so this larger ceiling costs it nothing.
	ProvisionTimeoutSeconds = 180
	// ProvisionReapGraceSeconds is added on top of ProvisionTimeoutSeconds
	// before lab.expire_sessions reaps a 'provisioning' row — the in-process
	// goroutine's own context timeout is the normal path (it marks the
	// session 'failed' itself well before this fires); this is only a
	// backstop for when that goroutine never got to run at all (e.g. the
	// backend restarted mid-provision), so it must stay comfortably above
	// ProvisionTimeoutSeconds to never race the normal path.
	ProvisionReapGraceSeconds = 60
	// ProvisionFailureCircuitBreakerThreshold/Window: if a lab fails to
	// provision this many times within this window (across all users),
	// StartSession stops accepting new sessions for it — see
	// ErrLabProvisioningUnstable. Protects the Docker host from a broken
	// image/setup_script getting hammered by every student's retry.
	ProvisionFailureCircuitBreakerThreshold = 3
	ProvisionFailureCircuitBreakerWindow    = 10 * time.Minute
	// IdleTimeoutMinutes is how long a session may go without any activity
	// (terminal keystroke, verify, file edit, run/submit, ws-token mint —
	// every one of those bumps last_active_at) before lab.expire_sessions
	// PAUSES its container. Pausing stops CPU billing without destroying the
	// student's work; the session is resumed on the next ws-token mint.
	IdleTimeoutMinutes = 15
	// IdleReapMinutes is how long a session may stay paused-and-untouched
	// before it is genuinely closed out and its container destroyed. A paused
	// container still holds its memory and disk, so it cannot be held forever
	// — but the student gets a wide window to come back to it, which the old
	// "kill at 15 minutes" behavior did not give them. expires_at still caps
	// the whole thing regardless.
	IdleReapMinutes = 120
	// MaxExecOutputBytes caps how much stdout (and, separately, stderr) is
	// captured from a single sandbox exec. Without a cap, a student can point
	// any exec-backed endpoint (file read, resources, verify, run) at a
	// multi-gigabyte file they created in their own container and force the
	// API process to buffer all of it in memory. Output past the cap is
	// discarded and the payload is marked truncated.
	MaxExecOutputBytes = 256 * 1024
	// MaxWriteFileBytes bounds a single lab file write. The workdir is a
	// 3 GB container disk; the API has no business relaying anything close to
	// that through a JSON request body.
	MaxWriteFileBytes = 2 * 1024 * 1024
	ContainerCPU      = "1.0"
	ContainerMemoryMB = 512
	ContainerDiskGB   = 3
	// NestedContainerCPU/NestedContainerMemoryMB size the "nested-docker"
	// ImageProfile (see profile.go) — a nested dockerd plus a student
	// `docker build` cannot fit in the default 1 CPU / 512MB; without this
	// override those sessions OOM silently under any real load even though
	// they work fine on an otherwise-idle dev machine.
	NestedContainerCPU      = "2.0"
	NestedContainerMemoryMB = 1536
	// NestedLabNetwork isolates nested-Docker (elevated, SYS_ADMIN-holding)
	// containers onto their own bridge, separate from the shared
	// "mindforge-labs" network every ordinary (--cap-drop ALL, no added
	// capabilities) lab container runs on — see docs/labs.md "Nested Docker
	// labs" for why L2 adjacency to unelevated containers is the risk this
	// avoids. Must exist (docker-compose.*.yml creates it) and must also be
	// attached to the labproxy service so the terminal proxy can still reach
	// these containers' ttyd port. Used as the "nested-docker" ImageProfile's
	// Network field (see profile.go / main.go's profile catalog).
	NestedLabNetwork = "mindforge-labs-dind"
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
	SessionStatusProvisioning    = "provisioning"
	SessionStatusRunning         = "running"
	SessionStatusPaused          = "paused"
	SessionStatusCompleted       = "completed"
	SessionStatusExpired         = "expired"
	SessionStatusFailed          = "failed"
	SessionStatusTerminatedAbuse = "terminated_abuse"
)

// isNonTerminalStatus reports whether a session status is still "alive" —
// provisioning, running, or paused. Used wherever code must decide if a
// session row is still worth acting on (idempotency-key resolution, resume
// paths) rather than duplicating the four terminal statuses at each call
// site.
func isNonTerminalStatus(status string) bool {
	switch status {
	case SessionStatusProvisioning, SessionStatusRunning, SessionStatusPaused:
		return true
	default:
		return false
	}
}

const (
	// End reasons — mirrors the lab_sessions_end_reason_check CHECK
	// constraint. time_limit/idle_timeout come from lab.expire_sessions
	// reaping a running/paused session; provision_timeout is the same job
	// reaping a session stuck in 'provisioning' past ProvisionReapGraceSeconds;
	// provision_failed is provisionContainer's own immediate-failure path
	// (container.Start returned an error before the timeout ever mattered).
	EndReasonTimeLimit        = "time_limit"
	EndReasonIdleTimeout      = "idle_timeout"
	EndReasonProvisionTimeout = "provision_timeout"
	EndReasonProvisionFailed  = "provision_failed"
	// EndReasonResetFailed marks a session terminated because its staged
	// reset could not bring up a replacement container. The old container is
	// already gone at that point, so leaving the session "running" would hand
	// the student a terminal wired to nothing.
	EndReasonResetFailed = "reset_failed"

	// Task completion statuses
	TaskStatusPending = "pending"
	TaskStatusPassed  = "passed"
	TaskStatusSkipped = "skipped"

	// AI interaction types
	InteractionTypeHint     = "hint"
	InteractionTypeExplain  = "explain"
	InteractionTypeDiagnose = "diagnose"
	InteractionTypeGenerate = "generate"

	// Egress rule protocols
	ProtocolHTTP  = "http"
	ProtocolHTTPS = "https"
	ProtocolTCP   = "tcp"

	// Usage event types
	UsageEventContainerSeconds  = "container_seconds"
	UsageEventAITokens          = "ai_tokens"
	UsageEventValidationSeconds = "validation_seconds"

	// Repo-clone statuses (Batch 3 lab-container auto-clone hook — see
	// Service.runRepoClone). RepoCloneStatusPending exists in migration 023's
	// check constraint but is unused here: the clone runs synchronously
	// inside provisionContainer, so a session only ever lands directly on
	// cloned/failed/skipped.
	RepoCloneStatusPending = "pending"
	RepoCloneStatusCloned  = "cloned"
	RepoCloneStatusFailed  = "failed"
	RepoCloneStatusSkipped = "skipped"
)

// ─── JSONB payload types ──────────────────────────────────────────────────────

// TaskSnapshot is the shape of a single task record stored inside the
// lab_task_versions.tasks JSONB array. It freezes the task content at publish
// time so future edits to lab_tasks do not alter historical sessions.
type TaskSnapshot struct {
	ID                 string `json:"id"`
	Position           int    `json:"position"`
	Title              string `json:"title"`
	Description        string `json:"description"`
	VerificationScript string `json:"verification_script"`
	HintContext        string `json:"hint_context,omitempty"`
	ExplanationContext string `json:"explanation_context,omitempty"`
	Points             int    `json:"points"`
	IsOptional         bool   `json:"is_optional"`
	IsStateful         bool   `json:"is_stateful"`
}

// ─── Domain rows ─────────────────────────────────────────────────────────────

type LabOrgConfig struct {
	OrgID                 string    `json:"org_id"`
	MaxConcurrentSessions int       `json:"max_concurrent_sessions"`
	MaxSessionDuration    int       `json:"max_session_duration"`
	AllowedImages         []string  `json:"allowed_images"`
	EgressProxyEnabled    bool      `json:"egress_proxy_enabled"`
	UpdatedAt             time.Time `json:"updated_at"`
}

type LabDefinition struct {
	ID          string  `json:"id"`
	OrgID       string  `json:"org_id"`
	CourseID    *string `json:"course_id"`
	ModuleID    *string `json:"module_id"`
	Scope       string  `json:"scope"`
	Title       string  `json:"title"`
	Description *string `json:"description"`
	LabType     string  `json:"lab_type"`
	Environment string  `json:"environment"`
	// PreviewPort is the container port where the lab's own application
	// listens (Django/FastAPI/Vite web labs); 0 = no live preview pane.
	// Served to the browser through labproxy's /preview/{token}/ proxy.
	PreviewPort int `json:"preview_port"`
	// Language is the authoritative language for a "code" type lab (required
	// by the DB CHECK constraint whenever lab_type = 'code'; nil for
	// terminal/guided/playground labs, which have no student code editor).
	Language    *string `json:"language"`
	SetupScript *string `json:"setup_script"`
	// RunScript is the instructor-authored sample-test command for sandbox
	// labs, executed in the session container by POST /sessions/:id/run.
	// nil = no Run button. Never serialized to students (see labStudentResponse
	// — only a has_run_script boolean crosses the wire).
	RunScript          *string `json:"-"`
	MaxDuration        int     `json:"max_duration"`
	MaxResets          int     `json:"max_resets"`
	HintPenaltyPct     int     `json:"hint_penalty_pct"`
	IsRequired         bool    `json:"is_required"`
	IsPublished        bool    `json:"is_published"`
	PublishedVersionID *string `json:"published_version_id"`
	// WorkspaceLayout selects how the student workspace is arranged: "split"
	// (default, side-by-side task list + terminal/editor) or "console"
	// (Google Cloud Shell style — full-width checklist with a collapsible
	// terminal drawer). See migration 033_lab_workspace_layout.sql.
	WorkspaceLayout string    `json:"workspace_layout"`
	CreatedBy       string    `json:"created_by"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
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
	ID            string    `json:"id"`
	LabID         string    `json:"lab_id"`
	TaskVersionID string    `json:"task_version_id"`
	UserID        string    `json:"user_id"`
	OrgID         string    `json:"org_id"`
	ContainerID   *string   `json:"container_id"`
	ContainerHost *string   `json:"container_host"`
	Status        string    `json:"status"`
	ResetCount    int       `json:"reset_count"`
	Score         int       `json:"score"`
	IsTest        bool      `json:"is_test"`
	StartedAt     time.Time `json:"started_at"`
	ExpiresAt     time.Time `json:"expires_at"`
	PausedSeconds int       `json:"paused_seconds"`
	// PausedAt is when the current pause began; nil unless Status is
	// "paused". Resume folds now()-PausedAt into PausedSeconds and clears it.
	PausedAt     *time.Time `json:"paused_at,omitempty"`
	CompletedAt  *time.Time `json:"completed_at"`
	LastActiveAt time.Time  `json:"last_active_at"`
	// EndReason distinguishes an automatic reaper termination (see the
	// EndReasonXxx constants above) from a normal user-driven end/completion,
	// which leaves this nil. Set only by lab.expire_sessions and
	// provisionContainer's own immediate-failure path.
	EndReason *string `json:"end_reason"`
	// ProvisionError holds the underlying failure detail when EndReason is
	// provision_timeout/provision_failed — nil otherwise.
	ProvisionError *string `json:"provision_error,omitempty"`
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
	LabID             string          `json:"lab_id"`
	Day               time.Time       `json:"day"`
	SessionsStarted   int             `json:"sessions_started"`
	SessionsCompleted int             `json:"sessions_completed"`
	AvgDurationSec    int             `json:"avg_duration_sec"`
	AvgScore          float64         `json:"avg_score"`
	TotalHintsUsed    int             `json:"total_hints_used"`
	PerTaskPassRate   json.RawMessage `json:"per_task_pass_rate"` // map[taskID]float64
	ComputedAt        time.Time       `json:"computed_at"`
}
