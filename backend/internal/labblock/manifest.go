package labblock

import (
	"bytes"
	"encoding/json"
	"fmt"

	"gopkg.in/yaml.v3"
)

// Known stacks and difficulties. Stacks are Go constants (not a DB CHECK) so a
// new lab kind can add one without a migration; difficulty is the platform's
// closed 4-level rubric (lab_catalog_meta CHECK).
var (
	Stacks       = []string{"django", "fastapi", "react", "fullstack", "any"}
	Difficulties = []string{"beginner", "intermediate", "advanced", "expert"}
)

// KindPreset is the block kind shared by every lab kind (the rest come from
// Kind.BlockKinds()): a saved parameter preset for one other block.
const KindPreset = "preset"

// TextKinds are the block kinds an org instructor may author in the UI: pure
// markdown/params content that is rendered as text and never executed
// (docs/debug-labs.md §B7 trust boundary). Every other kind is repo-only.
var TextKinds = []string{"ticket", "hints", "rubric", KindPreset}

// Manifest is a parsed block.yaml (docs/debug-labs.md §B1). One kind-specific
// section (named after Kind) carries the kind's fields; the ticket/hints/
// rubric/preset text kinds carry their content inline in theirs.
type Manifest struct {
	Kind       string   `yaml:"kind" json:"kind"`
	ID         string   `yaml:"id" json:"id"`
	Version    string   `yaml:"version" json:"version"`
	Stack      string   `yaml:"stack" json:"stack"`
	Title      string   `yaml:"title" json:"title"`
	Summary    string   `yaml:"summary" json:"summary"`
	Category   string   `yaml:"category" json:"category"`
	Difficulty string   `yaml:"difficulty" json:"difficulty"`
	Skills     []string `yaml:"skills" json:"skills"`
	Changelog  string   `yaml:"changelog" json:"changelog,omitempty"`
	// Params is a JSON Schema (object) for the block's parameters. A property
	// may carry `randomize: {choices: [...]}` or `randomize: {range: {min,
	// max, step}}`, and string properties must declare `x-mf-use` (see
	// labauthor's param rules).
	Params    map[string]any `yaml:"params" json:"params,omitempty"`
	Requires  []string       `yaml:"requires" json:"requires,omitempty"`
	Provides  []string       `yaml:"provides" json:"provides,omitempty"`
	Conflicts []string       `yaml:"conflicts" json:"conflicts,omitempty"`
	// Budget is this block's contribution to the recipe's setup/size budgets
	// (rule 7). Zero values contribute nothing.
	Budget Budget `yaml:"budget" json:"budget"`

	App    *AppSection    `yaml:"app" json:"app,omitempty"`
	Fault  *FaultSection  `yaml:"fault" json:"fault,omitempty"`
	Data   *DataSection   `yaml:"data" json:"data,omitempty"`
	Stub   *StubSection   `yaml:"stub" json:"stub,omitempty"`
	Env    *EnvSection    `yaml:"env" json:"env,omitempty"`
	Check  *CheckSection  `yaml:"check" json:"check,omitempty"`
	Ticket *TicketSection `yaml:"ticket" json:"ticket,omitempty"`
	Hints  *HintsSection  `yaml:"hints" json:"hints,omitempty"`
	Rubric *RubricSection `yaml:"rubric" json:"rubric,omitempty"`
	Preset *PresetSection `yaml:"preset" json:"preset,omitempty"`
	Custom *CustomSection `yaml:"custom" json:"custom,omitempty"`
}

// Budget is a block's estimated resource contribution (rule 7).
type Budget struct {
	SetupSeconds   int `yaml:"setup_seconds" json:"setup_seconds"`
	WorkspaceBytes int `yaml:"workspace_bytes" json:"workspace_bytes"`
	GraderBytes    int `yaml:"grader_bytes" json:"grader_bytes"`
}

// Slot types (docs/debug-labs.md §B2).
const (
	SlotRegion    = "region"
	SlotValue     = "value"
	SlotFile      = "file"
	SlotMigration = "migration"
)

// Literal types a `value` slot / string param may declare. The renderer must
// format the value with labauthor.RenderLiteral for that type.
const (
	LitPythonStr   = "python_str"
	LitPythonInt   = "python_int"
	LitPythonFloat = "python_float"
	LitPythonBool  = "python_bool"
	LitJSON        = "json"
	LitJSString    = "js_string"
	LitJSNumber    = "js_number"
	LitJSBool      = "js_bool"
)

// SlotDecl is one named slot in an app's slot catalog.
type SlotDecl struct {
	Name        string `yaml:"name" json:"name"`
	Type        string `yaml:"type" json:"type"`
	Default     string `yaml:"default" json:"default,omitempty"`
	Description string `yaml:"description" json:"description,omitempty"`
	// Dir and Scheme are required for migration slots: the workspace
	// directory holding the app's migrations, and how new ones are numbered
	// and chained ("django": NNNN_name.py + dependencies on the previous
	// stem; "alembic": <rev>_name.py + down_revision = current head).
	Dir    string `yaml:"dir" json:"dir,omitempty"`
	Scheme string `yaml:"scheme" json:"scheme,omitempty"`
	// Literal is required for value slots: the literal type the slot's
	// position in source accepts (e.g. python_bool for `USE_TZ = {{slot}}`).
	Literal string `yaml:"literal" json:"literal,omitempty"`
}

// HistoryCommit is one app history/noise commit. Feature tags the regression
// tests that cover the commit (rule 6's carrier coverage).
type HistoryCommit struct {
	Message string   `yaml:"message" json:"message"`
	Persona string   `yaml:"persona" json:"persona,omitempty"`
	Feature string   `yaml:"feature" json:"feature,omitempty"`
	Paths   []string `yaml:"paths" json:"paths,omitempty"`
}

// AppSection is the kind=app payload description.
type AppSection struct {
	Language  string          `yaml:"language" json:"language"` // python | js — picks the literal escaper family
	Slots     []SlotDecl      `yaml:"slots" json:"slots"`
	History   []HistoryCommit `yaml:"history" json:"history"`
	Noise     []HistoryCommit `yaml:"noise" json:"noise,omitempty"`
	Services  []string        `yaml:"services" json:"services,omitempty"`
	Ports     []int           `yaml:"ports" json:"ports,omitempty"`
	Protected []string        `yaml:"protected" json:"protected,omitempty"`
	// Features lists the feature tags the app's regression suite covers.
	Features []string `yaml:"features" json:"features"`
	// Setup are shell commands run in the workspace root (DATABASE_URL and
	// MF_WORKDIR set) to prepare the app: migrations, static assets. They run
	// for the student's dev database at session start and inside every grader
	// mode, so the dev and graded environments are built identically.
	Setup []string `yaml:"setup" json:"setup,omitempty"`
	// ReadinessPath is polled on the first port to decide the app is up
	// (default "/").
	ReadinessPath string `yaml:"readiness_path" json:"readiness_path,omitempty"`
	// TestGlobs select which changed files count as the student's own tests
	// for the student-test mode (fnmatch; default tests/*, */test_*.py, test_*.py).
	TestGlobs []string `yaml:"test_globs" json:"test_globs,omitempty"`
}

// SlotOverride sets one slot to inline Value or the contents of File (a path
// inside the block dir). Value may reference `{{params.<name>}}` only for
// `value` slots (checked by the debug kind). A migration slot takes File only:
// the file is inserted as the next migration in the slot's directory.
type SlotOverride struct {
	Slot  string `yaml:"slot" json:"slot"`
	Value string `yaml:"value" json:"value,omitempty"`
	File  string `yaml:"file" json:"file,omitempty"`
}

// FileOp adds/replaces one workspace file from a file in the block dir.
type FileOp struct {
	Path string `yaml:"path" json:"path"`
	From string `yaml:"from" json:"from"`
}

// Overrides is a set of slot overrides + file ops: the shape of a fault's
// inject, fix, carrier, and each cheat. Migrations are slot overrides on
// migration-type slots.
type Overrides struct {
	Slots []SlotOverride `yaml:"slots" json:"slots,omitempty"`
	Files []FileOp       `yaml:"files" json:"files,omitempty"`
}

// Cheat is an override set that must still FAIL grading (verified by the build).
type Cheat struct {
	Name      string `yaml:"name" json:"name"`
	Overrides `yaml:",inline"`
}

// Carrier is the real feature shipped in the fault commit so `git revert`
// fails the regression suite. Feature must be tagged in the app's Features.
type Carrier struct {
	Feature   string `yaml:"feature" json:"feature"`
	Overrides `yaml:",inline"`
}

// CommitTemplate describes the fault commit.
type CommitTemplate struct {
	Message  string `yaml:"message" json:"message"`
	Persona  string `yaml:"persona" json:"persona,omitempty"`
	Position string `yaml:"position" json:"position,omitempty"` // e.g. "late" (between the last 2-4 features)
}

// Check roles.
const (
	CheckSymptom    = "symptom"
	CheckRegression = "regression"
)

// CheckRef references a check block by key with fault-specific params.
type CheckRef struct {
	Ref    string         `yaml:"ref" json:"ref"`
	Role   string         `yaml:"role" json:"role"`
	Params map[string]any `yaml:"params" json:"params,omitempty"`
}

// Symptom is the fault's ticket variables and expected log/trace signature.
type Symptom struct {
	Vars      map[string]string `yaml:"vars" json:"vars,omitempty"`
	Signature string            `yaml:"signature" json:"signature,omitempty"`
	Capture   string            `yaml:"capture" json:"capture,omitempty"` // traceback | slow_query_log | log_excerpt
}

// Chain modes.
const (
	ChainMasks     = "masks"
	ChainCompounds = "compounds"
)

// Chain says fault B follows fault After: masks (B's symptom only appears once
// A is fixed) or compounds (both visible at once).
type Chain struct {
	After string `yaml:"after" json:"after"`
	Mode  string `yaml:"mode" json:"mode"`
}

// RubricDefaults are the write-up rubric key points + misconceptions.
type RubricDefaults struct {
	KeyPoints      []string `yaml:"key_points" json:"key_points"`
	Misconceptions []string `yaml:"misconceptions" json:"misconceptions,omitempty"`
}

// FaultSection is the kind=fault payload description.
type FaultSection struct {
	Inject  Overrides      `yaml:"inject" json:"inject"`
	Fix     Overrides      `yaml:"fix" json:"fix"`
	Cheats  []Cheat        `yaml:"cheats" json:"cheats,omitempty"`
	Carrier Carrier        `yaml:"carrier" json:"carrier"`
	Commit  CommitTemplate `yaml:"commit" json:"commit"`
	Checks  []CheckRef     `yaml:"checks" json:"checks"`
	Symptom Symptom        `yaml:"symptom" json:"symptom"`
	Hints   []string       `yaml:"hints" json:"hints,omitempty"`
	Rubric  RubricDefaults `yaml:"rubric" json:"rubric"`
	Chain   *Chain         `yaml:"chain" json:"chain,omitempty"`
	// RootCause is the debrief's root-cause explanation (Markdown), shown to
	// the student only after the session completes.
	RootCause string `yaml:"root_cause" json:"root_cause"`
}

// DataSection is the kind=data description. Rows feeds the automatic
// `data:rows>=N` provide.
type DataSection struct {
	Generator string `yaml:"generator" json:"generator"`
	Rows      int    `yaml:"rows" json:"rows,omitempty"`
}

// StubSection is the kind=stub description (a process with a fault API).
type StubSection struct {
	Process  string `yaml:"process" json:"process"`
	Port     int    `yaml:"port" json:"port,omitempty"`
	FaultAPI bool   `yaml:"fault_api" json:"fault_api,omitempty"`
}

// EnvSection is the kind=env description.
type EnvSection struct {
	Overlay    []FileOp `yaml:"overlay" json:"overlay,omitempty"`
	Supervisor []string `yaml:"supervisor" json:"supervisor,omitempty"`
	Pins       []string `yaml:"pins" json:"pins,omitempty"`
	MissingVar string   `yaml:"missing_var" json:"missing_var,omitempty"`
}

// Probe kinds (docs/debug-labs.md §B1 check row): P/Q/C/M/L/H/T, plus J (hidden
// vitest tests for React labs).
var ProbeKinds = []string{"P", "Q", "C", "M", "L", "H", "T", "J"}

// CheckSection is the kind=check description: a root-owned grader probe.
type CheckSection struct {
	Probe string `yaml:"probe" json:"probe"`
	// Entry is reserved: probes are the image's root-owned library selected
	// by Probe kind; a block only supplies parameters (never probe code).
	Entry          string `yaml:"entry" json:"entry,omitempty"`
	FailureMessage string `yaml:"failure_message" json:"failure_message"`
}

// TicketSection is the student brief. Exactly one of TemplateMD (inline; org
// text blocks) or TemplateFile (repo blocks) is set.
type TicketSection struct {
	TemplateMD   string   `yaml:"template_md" json:"template_md,omitempty"`
	TemplateFile string   `yaml:"template_file" json:"template_file,omitempty"`
	RedHerrings  []string `yaml:"red_herrings" json:"red_herrings,omitempty"`
	Severity     string   `yaml:"severity" json:"severity,omitempty"`
	Persona      string   `yaml:"persona" json:"persona,omitempty"`
}

// HintsSection is the 3-level hint ladder.
type HintsSection struct {
	Ladder []string `yaml:"ladder" json:"ladder"`
}

// RubricSection overrides/extends the fault's default rubric.
type RubricSection struct {
	RubricDefaults `yaml:",inline"`
}

// PresetSection is a saved parameter preset for one target block key.
type PresetSection struct {
	Target string         `yaml:"target" json:"target"`
	Values map[string]any `yaml:"values" json:"values"`
}

// CustomSection is the hand-made scenario escape hatch.
type CustomSection struct {
	Root         string   `yaml:"root" json:"root"`
	CombinesWith []string `yaml:"combines_with" json:"combines_with,omitempty"`
}

// ParseManifest decodes block.yaml strictly: unknown fields are errors, so a
// typo'd key cannot silently drop authored content.
func ParseManifest(data []byte) (*Manifest, error) {
	var m Manifest
	dec := yaml.NewDecoder(bytes.NewReader(data))
	dec.KnownFields(true)
	if err := dec.Decode(&m); err != nil {
		return nil, fmt.Errorf("labblock.ParseManifest: %w", err)
	}
	return &m, nil
}

// CanonicalJSON is the deterministic JSON encoding of the manifest stored in
// lab_block_versions.manifest (map keys sorted by encoding/json).
func (m *Manifest) CanonicalJSON() ([]byte, error) {
	raw, err := json.Marshal(m)
	if err != nil {
		return nil, fmt.Errorf("labblock.Manifest.CanonicalJSON: %w", err)
	}
	return raw, nil
}

// ManifestFromJSON decodes a lab_block_versions.manifest value.
func ManifestFromJSON(raw []byte) (*Manifest, error) {
	var m Manifest
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, fmt.Errorf("labblock.ManifestFromJSON: %w", err)
	}
	return &m, nil
}
