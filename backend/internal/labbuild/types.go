// Package labbuild is the lab-authoring build pipeline (docs/debug-labs.md
// Part 2 B3/B5, Phase 1c-ii): it renders a recipe's variants in a sandbox,
// verifies them through the same clean-room grader students use, and publishes
// a verified build into a course as a normal versioned lab.
//
// Flow: POST .../recipes/{id}/builds -> lab_builds row (queued) + job
// lab.recipe_build (render: queued -> rendering -> verifying) -> job
// lab.recipe_verify (verifying -> verified | failed) -> publish (one
// transaction, only for a verified build whose recipe hash still matches).
package labbuild

import (
	"encoding/json"
	"time"

	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/labblock"
)

// Build lifecycle (lab_builds.status CHECK).
const (
	StatusQueued    = "queued"
	StatusRendering = "rendering"
	StatusVerifying = "verifying"
	StatusVerified  = "verified"
	StatusFailed    = "failed"
)

// Job handler names.
const (
	HandlerRecipeBuild     = "lab.recipe_build"
	HandlerRecipeVerify    = "lab.recipe_verify"
	HandlerPlatformRecipes = "lab.platform_recipes_sync"
	HandlerBuildGC         = "lab.build_gc"
)

// Snapshot is lab_builds.spec_snapshot: the recipe as it was when the build was
// requested (a build freezes its inputs), plus what to do once verified.
type Snapshot struct {
	LabKind string        `json:"lab_kind"`
	OrgID   string        `json:"org_id"`
	Spec    labblock.Spec `json:"spec"`
	// AutoPublish (platform recipes) publishes the build as soon as it verifies.
	AutoPublish bool `json:"auto_publish,omitempty"`
}

// Build is a lab_builds row.
type Build struct {
	ID         string `json:"id"`
	RecipeID   string `json:"recipe_id"`
	RecipeHash string `json:"recipe_hash"`
	// RuntimeID is the lab-image stamp the build was made and verified against.
	RuntimeID         string          `json:"runtime_id"`
	Status            string          `json:"status"`
	Report            json.RawMessage `json:"report"`
	DerivedDifficulty *string         `json:"derived_difficulty"`
	CreatedBy         string          `json:"created_by"`
	CreatedAt         time.Time       `json:"created_at"`
	FinishedAt        *time.Time      `json:"finished_at"`
	Snapshot          Snapshot        `json:"-"`
}

// Report is lab_builds.report: a structured account of the build so the
// author can poll it live. Author-facing only; never sent to students.
type Report struct {
	// Error is set when the build failed before/outside verification.
	Error string `json:"error,omitempty"`
	// Issues are the composition validator's findings if validation failed.
	Issues []labblock.Issue `json:"issues,omitempty"`
	// Analysis summary.
	RecipeHash string `json:"recipe_hash,omitempty"`
	// RuntimeID: which lab-image runtime (grader bundle) verified this build.
	RuntimeID    string  `json:"runtime_id,omitempty"`
	Difficulty   string  `json:"difficulty,omitempty"`
	VariantCount int     `json:"variant_count,omitempty"`
	RenderSecs   float64 `json:"render_seconds,omitempty"`
	// Variants holds the per-variant verification matrix results.
	Variants []VariantReport `json:"variants,omitempty"`
}

// VariantReport is one variant's verification outcome.
type VariantReport struct {
	Key         string      `json:"variant_key"`
	Passed      bool        `json:"passed"`
	Runs        []RunReport `json:"runs"`
	BriefFilled bool        `json:"brief_filled"`
	CaptureNote string      `json:"capture_note,omitempty"`
	// Pending lists matrix runs not yet executed because no verification slot
	// was free; the verify job re-enqueues itself to finish them.
	Pending []string `json:"pending_runs,omitempty"`
	// Captured is the real app output captured from the broken run, kept so a
	// re-enqueued verify job can still fill the ticket.
	Captured map[string]string `json:"captured,omitempty"`
}

// RunReport is one verification run: what was expected, what happened.
type RunReport struct {
	Name         string          `json:"name"`
	Description  string          `json:"description"`
	Overlay      string          `json:"overlay"`
	Passed       bool            `json:"passed"`
	Expectations []string        `json:"expectations"`
	Failures     []string        `json:"failures,omitempty"`
	Seeds        []SeedResult    `json:"seeds"`
	SetupSeconds float64         `json:"setup_seconds"`
	StderrTail   string          `json:"stderr_tail,omitempty"`
	Error        string          `json:"error,omitempty"`
	Messages     []string        `json:"author_messages,omitempty"`
	Extra        json.RawMessage `json:"extra,omitempty"`
}

// SeedResult is the grader output of one seed of a run, per mode.
type SeedResult struct {
	Seed  string                `json:"seed"`
	Modes map[string]ModeResult `json:"modes"`
}

// ModeResult is one grade mode's verdict.
type ModeResult struct {
	Passed bool          `json:"passed"`
	Error  string        `json:"error,omitempty"`
	Checks []CheckResult `json:"checks"`
}

// CheckResult is one named grader check (author-written messages only).
type CheckResult struct {
	Name    string `json:"name"`
	Passed  bool   `json:"passed"`
	Message string `json:"message,omitempty"`
}

// VariantRow is a stored lab_build_variants row (bundle keys, never bytes).
type VariantRow struct {
	BuildID           string
	Key               string
	WorkspaceKey      string
	WorkspaceSHA      string
	GraderKey         string
	GraderSHA         string
	BriefMD           string
	ProtectedManifest json.RawMessage
	AppPorts          []int
	Payload           json.RawMessage
}

// VerifyBundle names the overlay bundle stored in a variant's payload.
type VerifyBundle struct {
	Key string `json:"verify_bundle_key"`
	SHA string `json:"verify_bundle_sha256"`
}

// Analysis re-exports the engine result the build stores.
type Analysis = labauthor.Analysis
