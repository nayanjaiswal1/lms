package canonical

// Kind discriminates the three canonical markdown document types.
type Kind string

const (
	KindLesson Kind = "lesson"
	KindQuiz   Kind = "quiz"
	KindLab    Kind = "lab"
)

// Common holds the frontmatter fields shared by every document kind.
type Common struct {
	Kind             Kind     `yaml:"kind"`
	IDKey            string   `yaml:"id_key"`  // stable string key, seeds a UUIDv5 — never changes once authored
	Course           string   `yaml:"course"`  // course slug, e.g. "fast-kubernetes"
	Section          string   `yaml:"section"` // section slug
	SectionTitle     string   `yaml:"section_title"`
	SectionPosition  int      `yaml:"section_position"`
	Title            string   `yaml:"title"`
	Position         int      `yaml:"position"` // position within the section
	EstimatedMinutes int      `yaml:"estimated_minutes"`
	Source           []string `yaml:"source"` // upstream filenames this content was derived from — required for coverage auditing
}

// Lesson maps to course_modules(type='notes'); Body becomes content_body.
// ModuleType optionally overrides the default 'notes' type — currently only
// 'system_design' is allowed, for lessons that pair a design question's
// guidance markdown with the whiteboard practice board.
type Lesson struct {
	Common     `yaml:",inline"`
	ModuleType string `yaml:"type,omitempty"`
	Body       string `yaml:"-"` // markdown body — not part of frontmatter, set by the parser after splitting
}

// QuizOption is one answer choice on an mcq Question.
type QuizOption struct {
	Text    string `yaml:"text"`
	Correct bool   `yaml:"correct"`
}

// QuizTestCase is one coding test case on a coding Question.
type QuizTestCase struct {
	Stdin    string  `yaml:"stdin"`
	Expected string  `yaml:"expected"`
	Hidden   bool    `yaml:"hidden"`
	Weight   float64 `yaml:"weight"`
}

// Question question types mirror backend/internal/assessment's questions.type
// column: "mcq" | "coding" | "subjective" (see assessment.QuestionTypeMCQ etc
// in backend/internal/assessment/models.go). Fields are grouped per-type below;
// a field left zero-valued for a type it doesn't apply to is expected — the
// generator reads only the fields relevant to Type when building
// question_versions.content.
type Question struct {
	IDKey       string            `yaml:"id_key"`
	Type        string            `yaml:"type"`
	Difficulty  string            `yaml:"difficulty"`
	Points      int               `yaml:"points"`
	Prompt      string            `yaml:"prompt"`
	Multiple    bool              `yaml:"multiple"` // mcq only: multiple correct answers allowed
	Options     []QuizOption      `yaml:"options"`  // mcq only
	Explanation string            `yaml:"explanation"`
	Languages   []string          `yaml:"languages"`    // coding only
	StarterCode map[string]string `yaml:"starter_code"` // coding only, keyed by language
	TestCases   []QuizTestCase    `yaml:"test_cases"`   // coding only
}

// Quiz maps to questions + question_versions + assessments + assessment_questions
// + course_modules(type='assessment').
type Quiz struct {
	Common          `yaml:",inline"`
	PassPercentage  int        `yaml:"pass_percentage"`
	DurationMinutes int        `yaml:"duration_minutes"`
	Questions       []Question `yaml:"questions"`
}

// LabFile is a starter file written into the lab container's workdir before
// the student's first session.
type LabFile struct {
	Path    string `yaml:"path"` // relative path inside the lab container's workdir
	Content string `yaml:"content"`
}

// Task is one gradable step of a Lab.
type Task struct {
	IDKey              string `yaml:"id_key"`
	Title              string `yaml:"title"`
	Points             int    `yaml:"points"`
	IsOptional         bool   `yaml:"is_optional"`
	IsStateful         bool   `yaml:"is_stateful"`
	Description        string `yaml:"description"`
	VerificationScript string `yaml:"verification_script"`
	HintContext        string `yaml:"hint_context"`
	ExplanationContext string `yaml:"explanation_context"`
	// SolutionScript is parsed for the generator's optional self-test mode only
	// (spins a disposable container, runs solution scripts through the real
	// tasks, confirms every verification_script passes before committing). It
	// must NEVER be written to any generated SQL/DB row or any
	// student/proxy-facing output — mirrors docs/labs.md's rule that
	// solution_script is never exposed.
	SolutionScript string `yaml:"solution_script"`
}

// Lab maps to lab_definitions + lab_tasks + lab_task_versions + publish +
// course_modules(type='lab').
type Lab struct {
	Common      `yaml:",inline"`
	LabType     string `yaml:"lab_type"` // must be one of terminal|code|playground|guided|sandbox
	Environment string `yaml:"environment"`
	PreviewPort int    `yaml:"preview_port"` // container port of the lab's running app; 0 = no live preview pane
	// RunScript is the student-visible sample-test command for sandbox labs
	// (the Run button); empty = no Run button. Unlike solution_script it IS
	// written to the DB, but its content never reaches the client.
	RunScript      string    `yaml:"run_script"`
	MaxDuration    int       `yaml:"max_duration"`
	MaxResets      int       `yaml:"max_resets"`
	HintPenaltyPct int       `yaml:"hint_penalty_pct"`
	IsRequired     bool      `yaml:"is_required"`
	SetupScript    string    `yaml:"setup_script"`
	Files          []LabFile `yaml:"files"`
	Tasks          []Task    `yaml:"tasks"`
}
