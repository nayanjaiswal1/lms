package roadmap

import "time"

const (
	ModeGenerated = "generated"
	ModeDefined   = "defined"

	StatusGenerating = "generating"
	StatusActive     = "active"
	StatusCompleted  = "completed"
	StatusArchived   = "archived"
	StatusFailed     = "failed"

	ModuleTypeCourse     = "course"
	ModuleTypeLab        = "lab"
	ModuleTypeDSAProblem = "dsa_problem"
	ModuleTypeProject    = "project"
	ModuleTypeReading    = "reading"
	ModuleTypeQuiz       = "quiz"

	ResourceTypeCourse   = "course"
	ResourceTypeLab      = "lab"
	ResourceTypeQuestion = "question"
)

// Roadmap is one user's AI-generated (or since-edited) learning path.
type Roadmap struct {
	ID              string     `json:"id"`
	UserID          string     `json:"user_id"`
	OrgID           *string    `json:"org_id,omitempty"`
	Title           string     `json:"title"`
	Mode            string     `json:"mode"`
	Status          string     `json:"status"`
	IsPublic        bool       `json:"is_public"`
	GoalDescription string     `json:"goal_description"`
	TargetRole      *string    `json:"target_role,omitempty"`
	SkillLevel      *string    `json:"skill_level,omitempty"`
	TimeframeWeeks  *int       `json:"timeframe_weeks,omitempty"`
	FocusAreas      []string   `json:"focus_areas"`
	GenerationError *string    `json:"generation_error,omitempty"`
	GeneratedAt     *time.Time `json:"generated_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	ModuleCount     int        `json:"module_count"`
	CompletedCount  int        `json:"completed_count"`
	Phases          []Phase    `json:"phases,omitempty"`
}

// Phase is a top-level stage of a roadmap (e.g. "Foundations").
type Phase struct {
	ID             string      `json:"id"`
	RoadmapID      string      `json:"roadmap_id"`
	Title          string      `json:"title"`
	Description    *string     `json:"description,omitempty"`
	Position       int         `json:"position"`
	EstimatedWeeks *int        `json:"estimated_weeks,omitempty"`
	Milestones     []Milestone `json:"milestones"`
}

// Milestone is a checkpoint within a phase.
type Milestone struct {
	ID             string   `json:"id"`
	PhaseID        string   `json:"phase_id"`
	Title          string   `json:"title"`
	Description    *string  `json:"description,omitempty"`
	Position       int      `json:"position"`
	EstimatedHours *int     `json:"estimated_hours,omitempty"`
	Modules        []Module `json:"modules"`
}

// Module is a single actionable unit of work within a milestone. When
// ResourceType/ResourceID are set, the frontend links directly to that real
// course/lab/question; otherwise it renders as a plain checklist item.
type Module struct {
	ID           string  `json:"id"`
	MilestoneID  string  `json:"milestone_id"`
	Title        string  `json:"title"`
	Description  *string `json:"description,omitempty"`
	Position     int     `json:"position"`
	ModuleType   string  `json:"module_type"`
	ResourceType *string `json:"resource_type,omitempty"`
	ResourceID   *string `json:"resource_id,omitempty"`
	// ResourceTitle/ResourceSlug are resolved at read time (join against the
	// catalog table resource_type points at), never persisted — always
	// reflects the resource's current title/slug rather than a stale copy.
	ResourceTitle    *string    `json:"resource_title,omitempty"`
	ResourceSlug     *string    `json:"resource_slug,omitempty"`
	EstimatedMinutes *int       `json:"estimated_minutes,omitempty"`
	CompletedAt      *time.Time `json:"completed_at,omitempty"`
}

// CreateRequest is the body of POST /api/roadmaps.
type CreateRequest struct {
	Title           string   `json:"title"`
	GoalDescription string   `json:"goal_description"`
	TargetRole      string   `json:"target_role"`
	SkillLevel      string   `json:"skill_level"`
	TimeframeWeeks  int      `json:"timeframe_weeks"`
	FocusAreas      []string `json:"focus_areas"`
}

// ─── AI generation response shape ──────────────────────────────────────────
// Mirrors ai.RoadmapSystemPrompt's required JSON exactly. Kept separate from
// the persisted Phase/Milestone/Module structs since the AI never supplies
// IDs, positions, or resource links — those are assigned server-side.

type generatedRoadmap struct {
	Phases []generatedPhase `json:"phases"`
}

type generatedPhase struct {
	Title          string               `json:"title"`
	Description    string               `json:"description"`
	EstimatedWeeks int                  `json:"estimated_weeks"`
	Milestones     []generatedMilestone `json:"milestones"`
}

type generatedMilestone struct {
	Title          string            `json:"title"`
	Description    string            `json:"description"`
	EstimatedHours int               `json:"estimated_hours"`
	Modules        []generatedModule `json:"modules"`
}

type generatedModule struct {
	Title            string `json:"title"`
	Description      string `json:"description"`
	ModuleType       string `json:"module_type"`
	EstimatedMinutes int    `json:"estimated_minutes"`
}

var validModuleTypes = map[string]bool{
	ModuleTypeCourse:     true,
	ModuleTypeLab:        true,
	ModuleTypeDSAProblem: true,
	ModuleTypeProject:    true,
	ModuleTypeReading:    true,
	ModuleTypeQuiz:       true,
}
