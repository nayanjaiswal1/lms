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

	AttemptCreated    = "created"
	AttemptInProgress = "in_progress"
	AttemptSubmitted  = "submitted"
	AttemptEvaluating = "evaluating"
	AttemptEvaluated  = "evaluated"
	AttemptEvalFailed = "eval_failed"
	AttemptExpired    = "expired"

	AssigneeStudent = "student"
	AssigneeBatch   = "batch"

	ParentStandalone = "standalone"
	ParentHiring     = "hiring"
)

// ValidDifficulties / ValidParentTypes back validation without scattering literals.
var (
	ValidDifficulties = []string{"beginner", "intermediate", "advanced", "expert"}
	ValidParentTypes  = []string{"standalone", "course", "module", "roadmap", "batch", "bootcamp", "hiring"}
)

// ─── Proctoring configuration ────────────────────────────────────────────────

// Fullscreen exit action values — what happens when the student exits fullscreen
// while RequireFullscreen is true.
const (
	FullscreenExitPause      = "pause"       // freeze timer; student must re-enter to resume
	FullscreenExitContinue   = "continue"    // hide questions but timer keeps running
	FullscreenExitAutoSubmit = "auto_submit" // immediately submit the attempt
)

// ProctoringConfig is the anti-cheat policy stored on each assessment.
// Zero value is not the intended default; always build via DefaultProctoring then
// overlay caller-supplied fields so an omitted field keeps its safe default.
type ProctoringConfig struct {
	RequireFullscreen     bool   `json:"require_fullscreen"`
	FullscreenExitAction  string `json:"fullscreen_exit_action"` // pause | continue | auto_submit
	BlockCopyPaste        bool   `json:"block_copy_paste"`
	BlockRightClick       bool   `json:"block_right_click"`
	BlockDevtools         bool   `json:"block_devtools"`
	MaxTabSwitches        int    `json:"max_tab_switches"`         // 0 = unlimited
	MaxFocusLoss          int    `json:"max_focus_loss"`           // 0 = unlimited
	AutoSubmitOnViolation bool   `json:"auto_submit_on_violation"` // hard-submit when a hard cap is hit
	HeartbeatSeconds      int    `json:"heartbeat_seconds"`
	RequireCamera         bool   `json:"require_camera"`         // show camera & mic preflight step
	AllowSecondaryCamera  bool   `json:"allow_secondary_camera"` // show secondary phone camera step
}

// DefaultProctoring returns the platform's safe default proctoring policy.
func DefaultProctoring() ProctoringConfig {
	return ProctoringConfig{
		RequireFullscreen:     true,
		FullscreenExitAction:  FullscreenExitPause,
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
//
// Runtime selects the grading engine: "" (or "stdio") runs the existing
// Piston/Judge0 stdin/stdout diff path via TestCase.Stdin/Expected. "sandbox"
// runs the submission in a real Docker container (see executor_sandbox.go) —
// in that mode Stdin/Expected are unused and TestCase.ID must instead match a
// JUnit <testcase name="..."> emitted by VerifyCommand, so Hidden/Weight still
// apply per named test. SandboxImage/SubmitPath/VerifyFiles/VerifyCommand are
// only meaningful when Runtime == "sandbox"; VerifyFiles/VerifyCommand are
// server-only and must be stripped before sending content to students, same as
// MCQOption.IsCorrect.
type CodingContent struct {
	Prompt        string            `json:"prompt"`
	Languages     []string          `json:"languages"`
	StarterCode   map[string]string `json:"starter_code"`
	TimeLimitMs   int               `json:"time_limit_ms"`
	MemoryLimitKb int               `json:"memory_limit_kb"`
	TestCases     []TestCase        `json:"test_cases"`

	Runtime      string            `json:"runtime,omitempty"`
	SandboxImage string            `json:"sandbox_image,omitempty"`
	SubmitPath   string            `json:"submit_path,omitempty"`
	VerifyFiles  map[string]string `json:"verify_files,omitempty"`
	// VerifyCommand must write its JUnit XML report to the fixed path
	// /tmp/mindforge-grade-result.xml, e.g.
	// "pytest --junitxml=/tmp/mindforge-grade-result.xml -q test_app.py" or
	// "vitest run --reporter=junit --outputFile=/tmp/mindforge-grade-result.xml".
	VerifyCommand string `json:"verify_command,omitempty"`
}

// RuntimeSandbox marks a CodingContent as graded by executing real code in a
// Docker container rather than the stdio Piston/Judge0 diff path.
const RuntimeSandbox = "sandbox"

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

// QuestionUsage is one (question, assessment) pin — a question can be pinned
// into several assessments, so a question's usage is a list, not a single
// value. CourseID/CourseTitle carry the same course_modules back-reference as
// Assessment.CourseID, resolved for the assessment side of the pin.
type QuestionUsage struct {
	QuestionID      string  `json:"question_id"`
	AssessmentID    string  `json:"assessment_id"`
	AssessmentTitle string  `json:"assessment_title"`
	CourseID        *string `json:"course_id"`
	CourseTitle     *string `json:"course_title"`
}

type Batch struct {
	ID            string     `json:"id"`
	OrgID         string     `json:"org_id"`
	Name          string     `json:"name"`
	Slug          string     `json:"slug"`
	Description   *string    `json:"description"`
	MentorID      *string    `json:"mentor_id"`
	Status        string     `json:"status"`
	MemberCount   int        `json:"member_count"`
	CreatedBy     string     `json:"created_by"`
	StartsAt      *time.Time `json:"starts_at"`
	EndsAt        *time.Time `json:"ends_at"`
	ImageURL      *string    `json:"image_url"`
	CohortGroupID *string    `json:"cohort_group_id"`
	// CohortGroupName is denormalized in from cohort_groups only by
	// ListBatchesForUser (the student-facing "/api/my/batches" query) — group
	// CRUD/listing is staff-only, so a student's own dashboard has no other way
	// to resolve a display name for their batch's group. Nil on the
	// admin-listing queries (ListBatches/GetBatch), which have no such join.
	CohortGroupName *string   `json:"cohort_group_name,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// CohortGroup is an optional grouping node above batches (e.g. Class/Section)
// for orgs that need more than one level of cohort hierarchy. Self-referencing
// via ParentID; LevelLabel is free text so each org names its own levels.
type CohortGroup struct {
	ID         string    `json:"id"`
	OrgID      string    `json:"org_id"`
	ParentID   *string   `json:"parent_id"`
	Name       string    `json:"name"`
	Slug       string    `json:"slug"`
	LevelLabel *string   `json:"level_label"`
	Status     string    `json:"status"`
	BatchCount int       `json:"batch_count"`
	ChildCount int       `json:"child_count"`
	CreatedBy  string    `json:"created_by"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
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
	ShortCode        *string          `json:"short_code,omitempty"`
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
	// CourseID/CourseTitle are resolved from course_modules.assessment_id (the
	// actual course-embedding link — parent_type/parent_id above are just a
	// self-reported tag and are never set when a module embeds an assessment).
	// Nil when the assessment isn't used as any course module's content.
	CourseID    *string `json:"course_id"`
	CourseTitle *string `json:"course_title"`
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
	RewardResult      json.RawMessage `json:"reward_result,omitempty"`
	CreatedAt         time.Time       `json:"created_at"`
	// ActiveSessionToken locks the attempt to whichever device most recently
	// opened it (see RotateSessionToken). Never serialized — it is only ever
	// returned once, inline in the attempt-start/resume payload.
	ActiveSessionToken *string `json:"-"`
}
