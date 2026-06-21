package assessment

import (
	"encoding/json"
	"time"
)

// ─── Enumerations (mirror the DB CHECK constraints) ──────────────────────────

const (
	QuestionTypeMCQ        = "mcq"
	QuestionTypeCoding     = "coding"
	QuestionTypeSubjective = "subjective"

	AssessmentTypeMCQ    = "mcq"
	AssessmentTypeCoding = "coding"
	AssessmentTypeMixed  = "mixed"

	StatusDraft     = "draft"
	StatusPublished = "published"
	StatusScheduled = "scheduled"
	StatusActive    = "active"
	StatusCompleted = "completed"
	StatusArchived  = "archived"

	AttemptCreated     = "created"
	AttemptInProgress  = "in_progress"
	AttemptSubmitted   = "submitted"
	AttemptEvaluating  = "evaluating"
	AttemptEvaluated   = "evaluated"
	AttemptEvalFailed  = "eval_failed"
	AttemptExpired     = "expired"

	AssigneeStudent = "student"
	AssigneeBatch   = "batch"

	ParentStandalone = "standalone"
)

// ValidDifficulties / ValidParentTypes back validation without scattering literals.
var (
	ValidDifficulties = []string{"beginner", "intermediate", "advanced", "expert"}
	ValidParentTypes  = []string{"standalone", "course", "module", "roadmap", "batch", "bootcamp"}
)

// ─── Proctoring configuration ────────────────────────────────────────────────

// ProctoringConfig is the anti-cheat policy stored on each assessment.
// Zero value is not the intended default; always build via DefaultProctoring then
// overlay caller-supplied fields so an omitted field keeps its safe default.
type ProctoringConfig struct {
	RequireFullscreen     bool `json:"require_fullscreen"`
	BlockCopyPaste        bool `json:"block_copy_paste"`
	BlockRightClick       bool `json:"block_right_click"`
	BlockDevtools         bool `json:"block_devtools"`
	MaxTabSwitches        int  `json:"max_tab_switches"`         // 0 = unlimited
	MaxFocusLoss          int  `json:"max_focus_loss"`           // 0 = unlimited
	AutoSubmitOnViolation bool `json:"auto_submit_on_violation"` // hard-submit when a hard cap is hit
	HeartbeatSeconds      int  `json:"heartbeat_seconds"`
	RequireCamera         bool `json:"require_camera"`          // show camera & mic preflight step
	AllowSecondaryCamera  bool `json:"allow_secondary_camera"`  // show secondary phone camera step
}

// DefaultProctoring returns the platform's safe default proctoring policy.
func DefaultProctoring() ProctoringConfig {
	return ProctoringConfig{
		RequireFullscreen:     true,
		BlockCopyPaste:        true,
		BlockRightClick:       true,
		BlockDevtools:         true,
		MaxTabSwitches:        3,
		MaxFocusLoss:          5,
		AutoSubmitOnViolation: true,
		HeartbeatSeconds:      15,
		RequireCamera:         true,
		AllowSecondaryCamera:  true,
	}
}

// ─── Question content payloads (question_versions.content) ───────────────────

// MCQOption is a single choice. IsCorrect is server-only and is stripped before
// any student-facing serialization (see toStudentView).
type MCQOption struct {
	ID        string `json:"id"`
	Text      string `json:"text"`
	IsCorrect bool   `json:"is_correct,omitempty"`
}

// MCQContent is the gradable payload for an MCQ question version.
type MCQContent struct {
	Prompt      string      `json:"prompt"`
	Multiple    bool        `json:"multiple"`
	Options     []MCQOption `json:"options"`
	Explanation string      `json:"explanation,omitempty"`
}

// TestCase is one coding test case. Hidden cases are never sent to students.
type TestCase struct {
	ID       string  `json:"id"`
	Stdin    string  `json:"stdin"`
	Expected string  `json:"expected"`
	Hidden   bool    `json:"hidden"`
	Weight   float64 `json:"weight"`
}

// CodingContent is the gradable payload for a coding question version.
type CodingContent struct {
	Prompt        string            `json:"prompt"`
	Languages     []string          `json:"languages"`
	StarterCode   map[string]string `json:"starter_code"`
	TimeLimitMs   int               `json:"time_limit_ms"`
	MemoryLimitKb int               `json:"memory_limit_kb"`
	TestCases     []TestCase        `json:"test_cases"`
}

// SubjectiveContent is the AI-graded payload for a subjective question version.
// ReferenceAnswer and ExpectedTopics are server-only — never sent to students.
type SubjectiveContent struct {
	Prompt          string   `json:"prompt"`
	ExpectedTopics  []string `json:"expected_topics"`
	ReferenceAnswer string   `json:"reference_answer"`
	Skills          []string `json:"skills"`
}

// ─── Domain rows ─────────────────────────────────────────────────────────────

type Category struct {
	ID       string  `json:"id"`
	OrgID    string  `json:"org_id"`
	ParentID *string `json:"parent_id"`
	Name     string  `json:"name"`
	Slug     string  `json:"slug"`
}

type Question struct {
	ID             string          `json:"id"`
	OrgID          string          `json:"org_id"`
	CategoryID     *string         `json:"category_id"`
	Type           string          `json:"type"`
	Title          string          `json:"title"`
	Difficulty     string          `json:"difficulty"`
	DefaultPoints  float64         `json:"default_points"`
	Tags           []string        `json:"tags"`
	Status         string          `json:"status"`
	CurrentVersion int             `json:"current_version"`
	Content        json.RawMessage `json:"content,omitempty"` // current version content (server view)
	CreatedBy      string          `json:"created_by"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
}

type Batch struct {
	ID          string    `json:"id"`
	OrgID       string    `json:"org_id"`
	Name        string    `json:"name"`
	Slug        string    `json:"slug"`
	Description *string   `json:"description"`
	MentorID    *string   `json:"mentor_id"`
	Status      string    `json:"status"`
	MemberCount int       `json:"member_count"`
	CreatedBy   string    `json:"created_by"`
	CreatedAt   time.Time `json:"created_at"`
}

type Assessment struct {
	ID               string           `json:"id"`
	OrgID            string           `json:"org_id"`
	Title            string           `json:"title"`
	Slug             string           `json:"slug"`
	Description      *string          `json:"description"`
	Type             string           `json:"type"`
	Status           string           `json:"status"`
	ParentType       string           `json:"parent_type"`
	ParentID         *string          `json:"parent_id"`
	DurationMinutes  int              `json:"duration_minutes"`
	PassPercentage   float64          `json:"pass_percentage"`
	MaxAttempts      int              `json:"max_attempts"`
	TotalPoints      float64          `json:"total_points"`
	MockMode         bool             `json:"mock_mode"`
	ShuffleQuestions bool             `json:"shuffle_questions"`
	ShuffleOptions   bool             `json:"shuffle_options"`
	AllowBacktrack   bool             `json:"allow_backtrack"`
	ShowResults      bool             `json:"show_results"`
	StartsAt         *time.Time       `json:"starts_at"`
	EndsAt           *time.Time       `json:"ends_at"`
	Proctoring       ProctoringConfig `json:"proctoring"`
	QuestionCount    int              `json:"question_count"`
	CreatedBy        string           `json:"created_by"`
	PublishedAt      *time.Time       `json:"published_at"`
	CreatedAt        time.Time        `json:"created_at"`
	UpdatedAt        time.Time        `json:"updated_at"`
}

type Attempt struct {
	ID                string          `json:"id"`
	AssessmentID      string          `json:"assessment_id"`
	UserID            string          `json:"user_id"`
	OrgID             string          `json:"org_id"`
	AttemptNumber     int             `json:"attempt_number"`
	Status            string          `json:"status"`
	StartedAt         *time.Time      `json:"started_at"`
	SubmittedAt       *time.Time      `json:"submitted_at"`
	EvaluatedAt       *time.Time      `json:"evaluated_at"`
	ExpiresAt         *time.Time      `json:"expires_at"`
	DurationSeconds   int             `json:"duration_seconds"`
	Score             *float64        `json:"score"`
	MaxScore          *float64        `json:"max_score"`
	Percentage        *float64        `json:"percentage"`
	Passed            *bool           `json:"passed"`
	AutoSubmitted     bool            `json:"auto_submitted"`
	Snapshot          json.RawMessage `json:"snapshot,omitempty"`
	ProctoringSummary json.RawMessage `json:"proctoring_summary,omitempty"`
	CreatedAt         time.Time       `json:"created_at"`
}
