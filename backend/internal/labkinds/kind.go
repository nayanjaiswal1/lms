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

import "encoding/json"

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

// VerifyRun is one entry in a lab kind's build-verification matrix — the
// runs the (later-phase) builder pipeline executes before a build may be
// marked verified. Kept descriptive rather than executable here: the
// builder interprets these against its own render/verify pipeline.
type VerifyRun struct {
	Name            string
	Description     string
	ExpectTasksPass []string
	ExpectTasksFail []string
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
	// VerifyMatrix returns the build-verification runs the (later-phase)
	// builder pipeline must execute before a build can be marked verified.
	VerifyMatrix() []VerifyRun
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
