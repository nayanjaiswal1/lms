package generator

// taskSnapshotJSON mirrors backend/internal/labs/models.go's TaskSnapshot —
// the exact shape frozen into lab_task_versions.tasks JSONB at publish time.
// solution_script is deliberately absent: it must never reach this shape.
type taskSnapshotJSON struct {
	ID                 string `json:"id"`
	LabID              string `json:"lab_id"`
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

// mcqOptionJSON mirrors the "options" entries inside an mcq question's
// question_versions.content (see backend/db/fixtures/k8s_02_questions_q1q2.sql).
type mcqOptionJSON struct {
	ID        string `json:"id"`
	Text      string `json:"text"`
	IsCorrect bool   `json:"is_correct"`
}

// mcqContentJSON mirrors an mcq question's question_versions.content.
type mcqContentJSON struct {
	Prompt      string          `json:"prompt"`
	Multiple    bool            `json:"multiple"`
	Options     []mcqOptionJSON `json:"options"`
	Explanation string          `json:"explanation"`
}

// codingTestCaseJSON mirrors a coding question's test_cases entries.
type codingTestCaseJSON struct {
	ID       string  `json:"id"`
	Stdin    string  `json:"stdin"`
	Expected string  `json:"expected"`
	Hidden   bool    `json:"hidden"`
	Weight   float64 `json:"weight"`
}

// codingContentJSON mirrors a coding question's question_versions.content.
// TimeLimitMs/MemoryLimitKb have no canonical-markdown source field (the
// schema doesn't expose per-question overrides yet), so the renderer applies
// the same fixed defaults the hand-written k8s fixtures used.
type codingContentJSON struct {
	Prompt        string               `json:"prompt"`
	Languages     []string             `json:"languages"`
	StarterCode   map[string]string    `json:"starter_code"`
	TimeLimitMs   int                  `json:"time_limit_ms"`
	MemoryLimitKB int                  `json:"memory_limit_kb"`
	TestCases     []codingTestCaseJSON `json:"test_cases"`
}

// subjectiveRubricCriterionJSON mirrors one entry of a subjective question's
// rubric.
type subjectiveRubricCriterionJSON struct {
	Criterion   string  `json:"criterion"`
	Weight      float64 `json:"weight"`
	Description string  `json:"description"`
}

// subjectiveContentJSON mirrors a subjective question's
// question_versions.content. Canonical markdown has no word_limit/rubric
// fields yet, so the renderer synthesizes a single-criterion rubric from the
// question's Explanation and a fixed default word limit.
type subjectiveContentJSON struct {
	Prompt    string                          `json:"prompt"`
	WordLimit int                             `json:"word_limit"`
	Rubric    []subjectiveRubricCriterionJSON `json:"rubric"`
}

const (
	defaultCodingTimeLimitMs   = 2000
	defaultCodingMemoryLimitKB = 262144
	defaultSubjectiveWordLimit = 400
)
