package courses

import (
	"encoding/json"
	"time"
)

const (
	StatusDraft     = "draft"
	StatusReview    = "review"
	StatusPublished = "published"
	StatusArchived  = "archived"

	ModuleTypeVideo      = "video"
	ModuleTypePDF        = "pdf"
	ModuleTypeNotes      = "notes"
	ModuleTypeAssessment = "assessment"
	// ModuleTypeLab modules are provisioned through the labs domain (see
	// db/fixtures + internal/labs), never created via the generic
	// CreateModule endpoint — only UpdateModule needs to recognize it so
	// existing lab modules stay editable.
	ModuleTypeLab = "lab"

	ProgressNotStarted = "not_started"
	ProgressInProgress = "in_progress"
	ProgressCompleted  = "completed"

	DifficultyBeginner     = "beginner"
	DifficultyIntermediate = "intermediate"
	DifficultyAdvanced     = "advanced"
)

type Course struct {
	ID             string     `json:"id"`
	OrgID          string     `json:"org_id"`
	CreatorID      string     `json:"creator_id"`
	Title          string     `json:"title"`
	Slug           string     `json:"slug"`
	Description    *string    `json:"description"`
	CoverURL       *string    `json:"cover_url"`
	Difficulty     string     `json:"difficulty"`
	Tags           []string   `json:"tags"`
	Status         string     `json:"status"`
	ForkedFromID   *string    `json:"forked_from_id"`
	PriceCents     int        `json:"price_cents"`
	IsFree         bool       `json:"is_free"`
	IsPublic       bool       `json:"is_public"`
	EstimatedHours *float64   `json:"estimated_hours"`
	InstructorName string     `json:"instructor_name"`
	AvgRating      *float64   `json:"avg_rating"`
	ReviewCount    int        `json:"review_count"`
	StartsAt       *time.Time `json:"starts_at"`
	EndsAt         *time.Time `json:"ends_at"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

// CourseReview is one student's star rating (1-5) for a course. A user may
// have at most one review per course (see UNIQUE constraint) — resubmitting
// updates the existing row rather than creating a new one.
type CourseReview struct {
	ID        string    `json:"id"`
	CourseID  string    `json:"course_id"`
	UserID    string    `json:"user_id"`
	Rating    int       `json:"rating"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CourseSection struct {
	ID        string         `json:"id"`
	CourseID  string         `json:"course_id"`
	Title     string         `json:"title"`
	Position  int            `json:"position"`
	CreatedAt time.Time      `json:"created_at"`
	Modules   []CourseModule `json:"modules,omitempty"`
}

type CourseModule struct {
	ID               string                   `json:"id"`
	CourseID         string                   `json:"course_id"`
	SectionID        string                   `json:"section_id"`
	Title            string                   `json:"title"`
	Type             string                   `json:"type"`
	Position         int                      `json:"position"`
	IsFreePreview    bool                     `json:"is_free_preview"`
	StorageKey       *string                  `json:"storage_key,omitempty"`
	DurationSeconds  *int                     `json:"duration_seconds,omitempty"`
	ContentBody      *string                  `json:"content_body,omitempty"`
	AssessmentID     *string                  `json:"assessment_id,omitempty"`
	EstimatedMinutes *int                     `json:"estimated_minutes,omitempty"`
	KnowledgeCheck   []KnowledgeCheckQuestion `json:"knowledge_check,omitempty"`
	StartsAt         *time.Time               `json:"starts_at"`
	EndsAt           *time.Time               `json:"ends_at"`
	CreatedAt        time.Time                `json:"created_at"`
	UpdatedAt        time.Time                `json:"updated_at"`
}

// KnowledgeCheckQuestion is one entry of a notes module's knowledge_check
// jsonb column — the server-side grading/gating key for an embedded question
// authored via a lesson's ```knowledge-check fenced block (see
// contentpipeline/generator/render_lesson.go). Correct is populated only for
// "mcq" questions; "sql" questions have no server-side executor to verify
// against (see backend/internal/assessment/executor.go), so they carry no
// answer key and stay client-graded like the pre-existing sql-challenge
// lesson segment already does.
type KnowledgeCheckQuestion struct {
	ID      string `json:"id"`
	Type    string `json:"type"`
	Correct string `json:"correct,omitempty"`
}

// LessonCheckAttempt is one row of lesson_check_attempts — a single submit of
// one knowledge-check question, correct or wrong.
type LessonCheckAttempt struct {
	ID           string          `json:"id"`
	OrgID        string          `json:"-"`
	UserID       string          `json:"-"`
	ModuleID     string          `json:"module_id"`
	QuestionID   string          `json:"question_id"`
	QuestionType string          `json:"question_type"`
	Answer       json.RawMessage `json:"answer"`
	IsCorrect    bool            `json:"is_correct"`
	CreatedAt    time.Time       `json:"created_at"`
}

// LessonReflection is one student's free-text "what did you understand from
// this lesson" reflection for a notes module — captured at the bottom of
// every lesson page, below the mcq knowledge-check. Ungraded, one row per
// (user, module); resubmitting replaces the previous answer rather than
// accumulating a history, since only the student's current stated
// understanding matters to a future revision-plan / concept-dependency-graph
// reader, which does not exist yet — this table only captures the raw input.
type LessonReflection struct {
	ID        string    `json:"id"`
	OrgID     string    `json:"-"`
	UserID    string    `json:"-"`
	ModuleID  string    `json:"module_id"`
	Response  string    `json:"response"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CourseTree struct {
	Course
	Sections []SectionWithModules `json:"sections"`
}

type SectionWithModules struct {
	CourseSection
	Modules []CourseModule `json:"modules"`
}

type Enrollment struct {
	ID          string     `json:"id"`
	UserID      string     `json:"user_id"`
	CourseID    string     `json:"course_id"`
	BatchID     *string    `json:"batch_id"`
	EnrolledBy  *string    `json:"enrolled_by"`
	EnrolledAt  time.Time  `json:"enrolled_at"`
	CompletedAt *time.Time `json:"completed_at"`
	Course      Course     `json:"course"`
}

type ModuleProgress struct {
	ID                  string     `json:"id"`
	UserID              string     `json:"user_id"`
	ModuleID            string     `json:"module_id"`
	CourseID            string     `json:"course_id"`
	Status              string     `json:"status"`
	LastPositionSeconds int        `json:"last_position_seconds"`
	CompletedAt         *time.Time `json:"completed_at"`
	UpdatedAt           time.Time  `json:"updated_at"`
}

type CourseProgress struct {
	Completed int     `json:"completed"`
	Total     int     `json:"total"`
	Pct       float64 `json:"pct"`
}

// CourseProgressSummary is the response shape for GET /api/courses/{id}/progress/me —
// aggregate completion plus the per-module rows the frontend needs to render
// completion badges and resume-at-the-right-module navigation.
type CourseProgressSummary struct {
	Completed int              `json:"completed"`
	Total     int              `json:"total"`
	Pct       float64          `json:"pct"`
	Modules   []ModuleProgress `json:"modules"`
}

type ModuleContent struct {
	Module     CourseModule `json:"module"`
	ContentURL *string      `json:"content_url,omitempty"`
}

type CourseOutline struct {
	Title       string           `json:"title"`
	Description string           `json:"description"`
	Sections    []OutlineSection `json:"sections"`
}

type OutlineSection struct {
	Title   string          `json:"title"`
	Modules []OutlineModule `json:"modules"`
}

type OutlineModule struct {
	Title            string `json:"title"`
	Type             string `json:"type"`
	Description      string `json:"description"`
	EstimatedMinutes int    `json:"estimated_minutes"`
}

type StudentProgress struct {
	UserID    string  `json:"user_id"`
	Name      string  `json:"name"`
	Email     string  `json:"email"`
	Completed int     `json:"completed"`
	Total     int     `json:"total"`
	Pct       float64 `json:"pct"`
}
