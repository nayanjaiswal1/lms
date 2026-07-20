package interviewprep

import "time"

const (
	StatusGenerating = "generating"
	StatusReady      = "ready"
	StatusInProgress = "in_progress"
	StatusCompleted  = "completed"
	StatusFailed     = "failed"

	RoundConceptual = "conceptual"
	RoundCoding     = "coding"

	RoundPending   = "pending"
	RoundActive    = "active"
	RoundCompleted = "completed"
)

// Plan is one self-serve interview-prep run, created from a job title / JD.
type Plan struct {
	ID                 string     `json:"id"`
	UserID             string     `json:"user_id"`
	OrgID              *string    `json:"org_id"`
	JobTitle           string     `json:"job_title"`
	JDText             *string    `json:"jd_text,omitempty"`
	ExtractedRole      string     `json:"extracted_role"`
	ExtractedSeniority string     `json:"extracted_seniority"`
	ExtractedSkills    []string   `json:"extracted_skills"`
	Status             string     `json:"status"`
	Report             *Report    `json:"report,omitempty"`
	AIModel            *string    `json:"ai_model,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
	CompletedAt        *time.Time `json:"completed_at"`
	Rounds             []Round    `json:"rounds,omitempty"`
}

// TestCase is one input/expected-output pair for a generated coding item.
// Hidden cases are stripped before the item is sent to the student.
type TestCase struct {
	Stdin    string `json:"stdin"`
	Expected string `json:"expected"`
	Hidden   bool   `json:"hidden"`
}

// CodingRunResult mirrors assessment.RunResult's shape closely enough for the
// frontend to render, without importing assessment's full type for a JSON blob.
type CodingRunResult struct {
	Status      string `json:"status"` // passed | failed | error
	TestsTotal  int    `json:"tests_total"`
	TestsPassed int    `json:"tests_passed"`
}

// CodingItem is one AI-generated coding problem, frozen as JSON on the round row.
type CodingItem struct {
	ID            string           `json:"id"`
	Prompt        string           `json:"prompt"`
	Language      string           `json:"language"`
	StarterCode   string           `json:"starter_code"`
	TestCases     []TestCase       `json:"test_cases"`
	Skill         string           `json:"skill"`
	SubmittedCode string           `json:"submitted_code,omitempty"`
	RunResult     *CodingRunResult `json:"run_result,omitempty"`
	Passed        *bool            `json:"passed,omitempty"`
}

// Round is one stage of a plan. Conceptual rounds delegate to an existing
// practice_sessions row; coding rounds are self-contained (items JSONB).
type Round struct {
	ID                string       `json:"id"`
	PlanID            string       `json:"plan_id"`
	RoundType         string       `json:"round_type"`
	OrderIndex        int          `json:"order_index"`
	PracticeSessionID *string      `json:"practice_session_id,omitempty"`
	Items             []CodingItem `json:"items,omitempty"`
	Status            string       `json:"status"`
	Score             *float64     `json:"score,omitempty"`
	CreatedAt         time.Time    `json:"created_at"`
	CompletedAt       *time.Time   `json:"completed_at"`
}

// Report is the once-generated, cached-forever aggregate readiness summary.
type Report struct {
	ReadinessScore     float64  `json:"readiness_score"`
	ConceptualScorePct float64  `json:"conceptual_score_pct"`
	CodingPassRatePct  float64  `json:"coding_pass_rate_pct"`
	StrongSkills       []string `json:"strong_skills"`
	WeakSkills         []string `json:"weak_skills"`
	Summary            string   `json:"summary"`
	NextSteps          []string `json:"next_steps"`
	CardsAdded         int      `json:"cards_added"`
	AIModel            string   `json:"ai_model,omitempty"`
}
