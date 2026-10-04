// Package labkinds is the pluggable "lab kind" registry — the seam that
// keeps the core labs package generic as the platform grows more than one
// composed lab type ("debug" first; "learn"/build-a-feature and others
// later, per the architecture note in docs/debug-labs.md).
//
// lab_definitions.lab_type (a closed, DB-enumerated set — see migration 045)
// is the RUNTIME/WORKSPACE shape: it drives container image/profile
// selection and which frontend workspace component renders. lab_recipes.
// lab_kind is the open-ended AUTHORING-PLUGIN identity a Kind implementation
// here answers to. For v1 there is a 1:1 mapping (lab_kind="debug" always
// runs on lab_type="debug"), but the two are independent by design: nothing
// stops a future lab_kind reusing the "debug" IDE workspace shape with
// different composition rules, or a new lab_type existing with no composed
// lab_kind behind it (every non-debug lab today).
//
// The core labs package (backend/internal/labs) never special-cases "debug"
// — everywhere it needs kind-specific behavior (which task templates a build
// publishes, what the session's workspace block looks like, how the debrief
// is built, which rubric backs a writeup_review task), it does exactly one
// thing: labkinds.Get(lab.LabType), then calls through the Kind interface.
// Adding a second kind means adding one file here (a Kind implementation
// that self-registers via init()) and one CHECK-constraint value on
// lab_type if it needs a genuinely new workspace shape — nothing in labs
// itself changes.
package labkinds

import (
	"encoding/json"
	"fmt"

	"github.com/mindforge/backend/internal/labblock"
)

// TaskTemplate is one task a lab kind's build publishes into lab_tasks/
// lab_task_version_items.
type TaskTemplate struct {
	// Key is a stable, kind-scoped slug (e.g. "symptom") — never a database
	// id; the builder (a later phase) uses it to generate deterministic task
	// ids the same way coursegen derives content ids elsewhere.
	Key         string
	Title       string
	Description string
	// Grader is "script" (dispatches through the generic exec-based grader —
	// see VariantView/GradeModes) or "writeup_review" (dispatches through the
	// generic AI-rubric review flow — see WriteupFilePath/WriteupRubric).
	Grader string
	// Mode is the grade.sh mode this task runs, e.g. "symptom" — only
	// meaningful when Grader == "script". Must be one of GradeModes().
	Mode       string
	Points     int
	IsOptional bool
}

// VerifyIssue describes one authored problem ("issue": for debug, one fault)
// of a built recipe, in chain order, so a kind can plan its verification.
type VerifyIssue struct {
	// Label is a short human name for reports (never shown to students).
	Label string
	// Masked is true when this issue only surfaces once an earlier one is fixed.
	Masked bool
	// Cheats are the names of this issue's cheat overlays.
	Cheats []string
}

// VerifyInput is what a kind needs to plan a build's verification runs.
type VerifyInput struct {
	Issues []VerifyIssue
	// Seeds is how many distinct grader seeds the full-fix run must pass.
	Seeds int
}

// Overlay selectors: which editable overlay a verification run applies on top
// of the pristine (broken) workspace. The renderer emits one overlay tarball
// per selector. OverlayNone grades the broken workspace as-is.
const OverlayNone = ""

// OverlayFix selects the reference fix of the first n issues, in chain order
// (n == len(issues) is the full fix).
func OverlayFix(n int) string { return fmt.Sprintf("fix:%d", n) }

// OverlayCheat selects cheat cheat of issue issue (0-based).
func OverlayCheat(issue, cheat int) string { return fmt.Sprintf("cheat:%d:%d", issue, cheat) }

// IssueCheckPrefix is the check-name prefix the renderer gives every check of
// issue i when a recipe has several issues, so verification can attribute
// grader results to issues without seeing which fault they belong to.
func IssueCheckPrefix(i, total int) string {
	if total <= 1 {
		return ""
	}
	return fmt.Sprintf("Issue %d: ", i+1)
}

// IssueOfCheck returns the 0-based issue a check name belongs to ("Issue 2: x"
// -> 1). Unprefixed names belong to issue 0 (single-issue recipes).
func IssueOfCheck(name string) int {
	var n int
	if _, err := fmt.Sscanf(name, "Issue %d: ", &n); err == nil && n >= 1 {
		return n - 1
	}
	return 0
}

// VerifyRun is one entry in a lab kind's build-verification matrix — a
// grading run the build pipeline executes (through the same clean-room grader
// students use) before a build may be marked verified.
type VerifyRun struct {
	Name        string
	Description string
	// Overlay is the editable overlay applied for the run (see OverlayNone,
	// OverlayFix, OverlayCheat).
	Overlay string
	// Modes are the grade modes executed, in order.
	Modes []string
	// Seeds is how many distinct grader seeds the run repeats under (0 = 1).
	Seeds int
	// ExpectTasksPass/Fail are task keys (Kind.Tasks()): pass = every check of
	// the task passes; fail = at least one check fails.
	ExpectTasksPass []string
	ExpectTasksFail []string
	// ExpectAnyRequiredFail is satisfied when at least one non-optional task
	// fails (cheats: a cheat must not earn completion).
	ExpectAnyRequiredFail bool
	// ExpectIssuesPass/Fail are 0-based issue indices: every check of a passing
	// issue passes; a failing issue has at least one failing check.
	ExpectIssuesPass []int
	ExpectIssuesFail []int
	// MaxSetupSeconds bounds the measured sandbox setup time (0 = unchecked).
	MaxSetupSeconds int
	// Capture marks the run whose app output feeds {{captured.*}} placeholders.
	Capture bool
}

// RenderInput is everything a kind needs to turn one variant of a recipe into
// the JSON its in-sandbox renderer consumes.
type RenderInput struct {
	Recipe *labblock.Recipe
	// VariantKey/Seed identify the variant; ActiveIDs are the block_version_ids
	// active in it (pool members not picked are absent).
	VariantKey string
	Seed       int64
	ActiveIDs  map[string]bool
	// AxisParams overlays, per block key, the variant's randomized param values.
	AxisParams map[string]map[string]any
	// BlockDirs maps block_version_id to the directory the block payload is
	// unpacked under in the renderer's input tar.
	BlockDirs map[string]string
	// ReadFile returns a file from a block's (already downloaded and verified)
	// payload, by block_version_id and payload-relative path.
	ReadFile func(versionID, path string) ([]byte, error)
	// Literal renders a parameter as a source literal of the given literal
	// type (labauthor.RenderLiteral) - the only sanctioned way a param enters code.
	Literal func(lit string, v any) (string, error)
}

// VariantView is the generic projection of one lab_build_variants row a Kind
// implementation is handed — everything the core labs package already knows
// how to seed/grade/report without any kind-specific knowledge, plus the
// kind-specific Payload it alone knows how to interpret.
type VariantView struct {
	BuildID    string
	VariantKey string
	// WorkspaceBundle/GraderBundle are the raw tar.gz bytes downloaded from
	// the private bundle store (backend/internal/storage.PrivateStore) —
	// never serialized, never handed to a student-facing response.
	WorkspaceBundle []byte
	GraderBundle    []byte
	BriefMD         string
	// ProtectedManifest is {path: sha256} — files the grader's clean-room
	// copy step must never pull from the student's container (see
	// labs.GradeInCleanRoom).
	ProtectedManifest json.RawMessage
	AppPorts          []int
	IDEPort           int
	// Payload is the kind-specific artifact JSON (for "debug":
	// {root_cause_md, fix_diff, rubric, hint_ladder, baseline_commit}) — a
	// new lab kind defines its own shape here without a migration.
	Payload json.RawMessage
}

// HintContext is the ground truth a kind gives the hint prompt (never shown
// to the student verbatim).
type HintContext struct {
	// GroundTruth is the authored root cause / expected diagnosis.
	GroundTruth string
	// Ladder is the authored hint ladder (index 0 = level 1, static & free).
	Ladder []string
	// ReferenceFix is the reference solution diff, used ONLY by the leak
	// filter to reject AI output that reproduces its added lines.
	ReferenceFix string
	// BaselineRef is a git ref/commit in the workspace; the student's diff
	// against it is fed to the prompt. "" = no diff context.
	BaselineRef string
}

// CompletionPolicy says when a session of a lab kind becomes 'completed'.
type CompletionPolicy string

const (
	// CompleteOnRequiredPass completes the session the moment the last
	// required task passes (every hand-authored lab type; the default).
	CompleteOnRequiredPass CompletionPolicy = "required_pass"
	// CompleteOnFinish credits the course module when the required tasks
	// pass but keeps the session active — so optional tasks (e.g. a write-up)
	// can still be done — until the student finishes (POST /end) or the
	// deadline closes it, both as 'completed' once required tasks passed.
	CompleteOnFinish CompletionPolicy = "finish"
)

// Kind is one pluggable lab authoring/runtime behavior. See this package's
// doc comment for the lab_type/lab_kind distinction.
type Kind interface {
	// Name is the lab_type this Kind handles — the registry key.
	Name() string
	// BlockKinds lists the lab_blocks.kind values this kind's builder
	// accepts when composing a recipe.
	BlockKinds() []string
	// Tasks returns the standard task set a build of this kind publishes.
	Tasks() []TaskTemplate
	// CompletionPolicy says when a session of this kind completes.
	CompletionPolicy() CompletionPolicy
	// GradeModes lists the modes grade.sh accepts for this kind, in the
	// order grade.sh's own usage output should list them.
	GradeModes() []string
	// VerifyMatrix plans the build-verification runs the pipeline must
	// execute before a build can be marked verified.
	VerifyMatrix(in VerifyInput) []VerifyRun
	// VerifyInput describes a built variant (from its stored payload) to the
	// verification planner: how many issues, which are masked, which cheats.
	VerifyInput(payload json.RawMessage) VerifyInput
	// SetupScript is the lab_definitions.setup_script published labs of this
	// kind run (as root, via ExecSetup) right after the pristine workspace is
	// seeded: it must prepare the dev environment the way the grader does.
	SetupScript() string
	// Image is the sandbox image builds render and verify in (the same image
	// students' labs of this kind run).
	Image() string
	// RenderSpec builds the renderer's per-variant input document. It is
	// opaque to the pipeline, which streams it to the in-sandbox renderer.
	RenderSpec(in RenderInput) (json.RawMessage, error)
	// ValidateRecipe runs this kind's composition rules over one concrete
	// recipe (pools already collapsed to a single member each, params
	// resolved). The engine (internal/labauthor) has already applied the
	// generic rules - stack, capability satisfaction, conflicts, budgets,
	// org scoping, parameter schemas - so implementations add only what is
	// specific to the kind (for debug: fault slot exclusivity, chains,
	// check/carrier coverage, value-slot literal safety). pv validates
	// parameter maps against a block's JSON Schema.
	ValidateRecipe(r *labblock.Recipe, pv labblock.ParamValidator) []labblock.Issue
	// DeriveDifficulty returns the difficulty (one of labblock.Difficulties)
	// this kind derives for the recipe, or "" if it cannot derive one.
	DeriveDifficulty(r *labblock.Recipe) string
	// SessionPayload builds the student-safe workspace block for GET
	// /api/labs/sessions/{id} (e.g. debug's "debug": {brief, ide_port,
	// app_ports}) from a variant. Never includes root cause/fix/rubric/
	// bundles.
	SessionPayload(v *VariantView) any
	// Debrief builds the post-completion debrief payload — root cause,
	// reference fix, etc. Only ever called once the session is completed.
	Debrief(v *VariantView) any
	// HintContext extracts the hint-prompt ground truth from a variant.
	HintContext(v *VariantView) HintContext
	// WriteupFilePath is the in-workspace file a writeup_review task grades
	// (e.g. "INCIDENT.md"); "" if this kind has no writeup_review task.
	WriteupFilePath() string
	// WriteupRubric extracts this kind's rubric (key points to credit,
	// misconceptions to watch for) from a variant's payload, for the
	// writeup-review AI prompt and scoring.
	WriteupRubric(v *VariantView) (keyPoints, misconceptions []string)
}
