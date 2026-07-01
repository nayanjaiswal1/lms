package courses

import (
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

	ProgressNotStarted = "not_started"
	ProgressInProgress = "in_progress"
	ProgressCompleted  = "completed"

	DifficultyBeginner     = "beginner"
	DifficultyIntermediate = "intermediate"
	DifficultyAdvanced     = "advanced"
)

type Course struct {
	ID             string    `json:"id"`
	OrgID          string    `json:"org_id"`
	CreatorID      string    `json:"creator_id"`
	Title          string    `json:"title"`
	Slug           string    `json:"slug"`
	Description    *string   `json:"description"`
	CoverURL       *string   `json:"cover_url"`
	Difficulty     string    `json:"difficulty"`
	Tags           []string  `json:"tags"`
	Status         string    `json:"status"`
	ForkedFromID   *string   `json:"forked_from_id"`
	PriceCents     int       `json:"price_cents"`
	IsFree         bool      `json:"is_free"`
	EstimatedHours *float64  `json:"estimated_hours"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
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
	ID               string    `json:"id"`
	CourseID         string    `json:"course_id"`
	SectionID        string    `json:"section_id"`
	Title            string    `json:"title"`
	Type             string    `json:"type"`
	Position         int       `json:"position"`
	IsFreePreview    bool      `json:"is_free_preview"`
	StorageKey       *string   `json:"storage_key,omitempty"`
	DurationSeconds  *int      `json:"duration_seconds,omitempty"`
	ContentBody      *string   `json:"content_body,omitempty"`
	AssessmentID     *string   `json:"assessment_id,omitempty"`
	EstimatedMinutes *int      `json:"estimated_minutes,omitempty"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
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
