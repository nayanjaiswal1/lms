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

	titleMinLen       = 3
	titleMaxLen       = 200
	moduleTitleMinLen = 1
	moduleTitleMaxLen = 200
	descriptionMaxLen = 2000

	// KindOrg is the existing shared, instructor-authored course (default).
	KindOrg = "org"
	// KindSelf is a student's own private course — owned by owner_id, never
	// listed in the org browse/public catalogs, editable only by its owner
	// (including via their connected MCP client, with no review gate).
	KindSelf = "self"

	ProposalStatusPending  = "pending"
	ProposalStatusApproved = "approved"
	ProposalStatusRejected = "rejected"
)

var validDifficulties = map[string]bool{
	DifficultyBeginner: true, DifficultyIntermediate: true, DifficultyAdvanced: true,
}

// IsValidDifficulty is the single source of truth for the allowed difficulty
// values — shared by the org course-creation handler and the self-course
// path (both HTTP and, via Service, the MCP tool) so the two never drift.
func IsValidDifficulty(d string) bool { return validDifficulties[d] }

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
	// Kind distinguishes a shared, instructor-authored course ("org", the
	// default) from a student's own private course ("self"). OwnerID is set
	// only for kind="self" — the one user who can read/edit it and whose
	// connected AI (via MCP) is allowed to write its modules directly.
	Kind      string    `json:"kind"`
	OwnerID   *string   `json:"owner_id,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
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
	// Source distinguishes a student-typed reflection ("manual", the default)
	// from one written by their connected AI client via the log_understanding
	// MCP tool ("ai") — revisionplan can weight the two differently.
	Source    string    `json:"source"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// LessonNote is a student's personal, editable overlay on a lesson — separate
// from the graded/ungraded module content itself. One row per (user, module);
// saving replaces the previous note. Source distinguishes a manual edit from
// one written by the student's connected AI client via the save_my_lesson_note
// MCP tool.
type LessonNote struct {
	ID        string    `json:"id"`
	OrgID     string    `json:"-"`
	UserID    string    `json:"-"`
	ModuleID  string    `json:"module_id"`
	Content   string    `json:"content"`
	Source    string    `json:"source"`
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

// LearningContext is a single, pre-aggregated snapshot of where a student
// currently stands — the answer to "what does my connected AI already know
// without me re-explaining it." It exists because an MCP tool call only ever
// returns what it's asked for; without one call that summarizes everything
// relevant, an AI client would need to make several separate lookups (and
// often wouldn't bother, defaulting back to asking the student to recap).
type LearningContext struct {
	Courses            []CourseProgressBrief `json:"courses"`
	RecentReflections  []ReflectionSummary   `json:"recent_reflections"`
	RecentSelfActivity []SelfModuleSummary   `json:"recent_self_course_activity"`
}

// CourseProgressBrief is one enrolled course's completion state — enough to
// answer "what am I enrolled in and how far along am I" without loading each
// course's full section/module tree.
type CourseProgressBrief struct {
	CourseID  string  `json:"course_id"`
	Title     string  `json:"title"`
	Kind      string  `json:"kind"`
	Completed int     `json:"completed_modules"`
	Total     int     `json:"total_modules"`
	Pct       float64 `json:"pct"`
}

// ReflectionSummary is one lesson_reflections row with its lesson/course
// title joined in, so a reader doesn't need a second lookup per reflection
// to know what it's about.
type ReflectionSummary struct {
	CourseTitle string    `json:"course_title"`
	ModuleTitle string    `json:"module_title"`
	ModuleID    string    `json:"module_id"`
	Response    string    `json:"response"`
	Source      string    `json:"source"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// SelfModuleSummary is one recently-touched module in one of the student's
// own self-courses — the "what have I been building lately" feed.
type SelfModuleSummary struct {
	CourseID    string    `json:"course_id"`
	CourseTitle string    `json:"course_title"`
	ModuleID    string    `json:"module_id"`
	ModuleTitle string    `json:"module_title"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// CourseContentProposal is a student's proposal to contribute a module they
// authored in one of their own self-courses into a shared org course. It
// never writes to course_modules on its own — an org admin/instructor must
// Approve it first (see Service.ApproveProposal), which is the only path
// that turns a proposal into a real module row.
type CourseContentProposal struct {
	ID              string     `json:"id"`
	OrgID           string     `json:"-"`
	ProposerID      string     `json:"proposer_id"`
	SourceCourseID  *string    `json:"source_course_id,omitempty"`
	SourceModuleID  *string    `json:"source_module_id,omitempty"`
	TargetCourseID  string     `json:"target_course_id"`
	TargetSectionID *string    `json:"target_section_id,omitempty"`
	Title           string     `json:"title"`
	Type            string     `json:"type"`
	ContentBody     string     `json:"content_body"`
	Status          string     `json:"status"`
	ReviewNote      *string    `json:"review_note,omitempty"`
	ReviewedBy      *string    `json:"reviewed_by,omitempty"`
	ReviewedAt      *time.Time `json:"reviewed_at,omitempty"`
	CreatedModuleID *string    `json:"created_module_id,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

type StudentProgress struct {
	UserID    string  `json:"user_id"`
	Name      string  `json:"name"`
	Email     string  `json:"email"`
	Completed int     `json:"completed"`
	Total     int     `json:"total"`
	Pct       float64 `json:"pct"`
}
