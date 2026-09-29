package labkinds

import "encoding/json"

// Grader/mode literals duplicated here rather than imported from labs (which
// imports labkinds — importing back would be a cycle) — same
// "cmd/labproxy duplicates labs constants" pattern used elsewhere in this
// codebase (see internal/labs/credential.go's doc comment). Must stay in
// sync with labs.GraderScript/GraderWriteupReview and
// labs.DebugGradeMode{Symptom,Regression,StudentTest}.
const (
	graderScript        = "script"
	graderWriteupReview = "writeup_review"

	modeSymptom     = "symptom"
	modeRegression  = "regression"
	modeStudentTest = "student-test"
)

func init() { Register(&DebugKind{}) }

// DebugKind is the "debug" lab kind (docs/debug-labs.md) — the platform's
// first, and so far only, pluggable composition target. A student gets a
// small broken Django/FastAPI/React app and debugs it: reproduce, root
// cause, fix, prove it, write it up.
type DebugKind struct{}

// Name implements Kind.
func (DebugKind) Name() string { return "debug" }

// BlockKinds implements Kind (docs/debug-labs.md Part 2 §B1).
func (DebugKind) BlockKinds() []string {
	return []string{"app", "fault", "data", "stub", "env", "check", "ticket", "hints", "rubric", "custom"}
}

// Tasks implements Kind — the standard 4 tasks every debug scenario
// publishes (docs/debug-labs.md §3's table). Completion + section unlock
// need symptom+regression; student-test and writeup are optional/points-only.
func (DebugKind) Tasks() []TaskTemplate {
	return []TaskTemplate{
		{
			Key: "symptom", Title: "Symptom resolved",
			Description: "The reported symptom no longer reproduces against the live app.",
			Grader:      graderScript, Mode: modeSymptom, Points: 40,
		},
		{
			Key: "regression", Title: "No regressions",
			Description: "The app's existing behavior still passes the regression suite.",
			Grader:      graderScript, Mode: modeRegression, Points: 30,
		},
		{
			Key: "student-test", Title: "Regression test proves the fix",
			Description: "A test you added fails on the broken baseline and passes on your fix.",
			Grader:      graderScript, Mode: modeStudentTest, Points: 15, IsOptional: true,
		},
		{
			Key: "writeup", Title: "Root-cause write-up",
			Description: "Fill in INCIDENT.md: symptom, reproduction, root cause, fix, prevention.",
			Grader:      graderWriteupReview, Points: 15, IsOptional: true,
		},
	}
}

// CompletionPolicy implements Kind: the write-up (optional) can only happen
// while the session is live, so the session waits for the student's Finish.
func (DebugKind) CompletionPolicy() CompletionPolicy { return CompleteOnFinish }

// GradeModes implements Kind.
func (DebugKind) GradeModes() []string { return []string{modeSymptom, modeRegression, modeStudentTest} }

// VerifyMatrix implements Kind (docs/debug-labs.md §4's build-verification
// table, restated per-run for the later-phase builder pipeline to execute).
func (DebugKind) VerifyMatrix() []VerifyRun {
	return []VerifyRun{
		{
			Name:            "broken",
			Description:     "every symptom task fails; regression passes; setup <= 30s",
			ExpectTasksFail: []string{"symptom"},
			ExpectTasksPass: []string{"regression"},
		},
		{
			Name:            "full-fix",
			Description:     "all tasks pass across 3 grader seeds (catches flaky probes)",
			ExpectTasksPass: []string{"symptom", "regression"},
		},
		{
			Name:            "student-test-on-fix",
			Description:     "the fault's reference test fails on baseline, passes on the fix",
			ExpectTasksPass: []string{"student-test"},
		},
		{
			Name:            "each-cheat",
			Description:     "every cheats/*.patch fails at least one required task",
			ExpectTasksFail: []string{"symptom"},
		},
	}
}

// debugPayload is lab_build_variants.payload's shape for lab_kind="debug".
type debugPayload struct {
	RootCauseMD    string          `json:"root_cause_md"`
	FixDiff        string          `json:"fix_diff"`
	Rubric         json.RawMessage `json:"rubric"`
	HintLadder     json.RawMessage `json:"hint_ladder"`
	BaselineCommit string          `json:"baseline_commit"`
}

func decodeDebugPayload(raw json.RawMessage) debugPayload {
	var p debugPayload
	_ = json.Unmarshal(raw, &p)
	return p
}

// SessionPayload implements Kind — never includes root cause/fix/rubric/
// bundles (docs/debug-labs.md §8: GET /sessions/{id} "never root cause, fix,
// rubric or bundles").
func (DebugKind) SessionPayload(v *VariantView) any {
	return map[string]any{
		"brief":     v.BriefMD,
		"ide_port":  v.IDEPort,
		"app_ports": v.AppPorts,
	}
}

// Debrief implements Kind — only reached once the session is completed
// (enforced by the caller, labs.Service.GetDebrief).
func (DebugKind) Debrief(v *VariantView) any {
	p := decodeDebugPayload(v.Payload)
	return map[string]any{
		"root_cause": p.RootCauseMD,
		"fix_diff":   p.FixDiff,
	}
}

// HintContext implements Kind.
func (DebugKind) HintContext(v *VariantView) HintContext {
	p := decodeDebugPayload(v.Payload)
	var ladder []string
	_ = json.Unmarshal(p.HintLadder, &ladder)
	return HintContext{GroundTruth: p.RootCauseMD, Ladder: ladder, ReferenceFix: p.FixDiff, BaselineRef: p.BaselineCommit}
}

// WriteupFilePath implements Kind.
func (DebugKind) WriteupFilePath() string { return "INCIDENT.md" }

// WriteupRubric implements Kind.
func (DebugKind) WriteupRubric(v *VariantView) (keyPoints, misconceptions []string) {
	p := decodeDebugPayload(v.Payload)
	var r struct {
		KeyPoints      []string `json:"key_points"`
		Misconceptions []string `json:"misconceptions"`
	}
	_ = json.Unmarshal(p.Rubric, &r)
	return r.KeyPoints, r.Misconceptions
}
