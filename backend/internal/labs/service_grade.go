package labs

import (
	"context"
	crand "crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"sort"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/labkinds"
)

// ─── Clean-room grading (docs/debug-labs.md §4) ──────────────────────────────
//
// A Check never runs hidden tests inside the student's own container. It
// starts a SEPARATE short-lived sandbox from the same image, seeds it with
// the pristine workspace bundle, overlays ONLY the student's editable
// regular files (protected paths and .git are never copied), streams the
// grader bundle in, runs grade.sh there, and destroys the sandbox. Hidden
// tests/fixtures therefore never exist in the student's container, and
// tampering with runners, Postgres, or extensions in their own container
// cannot influence grading.

const (
	// CleanRoomMaxConcurrent bounds simultaneous clean-room grader sandboxes
	// per API replica (each is a full 2 CPU / 2 GB sandbox). It is per-PROCESS
	// on purpose: it protects this node's CPU/memory, which only this process
	// can account for. It is NOT the org-wide verification cap: that one is
	// global, a Redis semaphore in labbuild (LAB_VERIFY_PARALLEL_PER_ORG).
	CleanRoomMaxConcurrent = 4
	// MaxCapturedWorkspaceBytes caps the student-workspace tar pulled out via
	// ExecCapture (16 MB — the same cap builder jobs use).
	MaxCapturedWorkspaceBytes = 16 * 1024 * 1024
	cleanRoomQueueWait        = 5 * time.Second
	cleanRoomReadyBudget      = 60 * time.Second
	lastGradeOutputTTL        = 2 * time.Hour
	lastGradeOutputMaxBytes   = 4096
)

// cleanRoomSem is deliberately per-replica, not a Redis semaphore: it protects
// THIS node's container runtime/CPU from concurrent clean-room sandboxes, so
// N replicas each running CleanRoomMaxConcurrent is the intended capacity.
var cleanRoomSem = make(chan struct{}, CleanRoomMaxConcurrent)

// GradeCheck is one named check in grade.sh's JSON output. Message is
// author-written text only — never test source or expected values.
type GradeCheck struct {
	Name    string `json:"name"`
	Passed  bool   `json:"passed"`
	Message string `json:"message,omitempty"`
}

// GradeResult is grade.sh's stdout contract.
type GradeResult struct {
	Mode   string       `json:"mode"`
	Passed bool         `json:"passed"`
	Checks []GradeCheck `json:"checks"`
	Error  string       `json:"error,omitempty"`

	// Build-verification diagnostics, never serialized to students: how long
	// the sandbox took to start and be seeded, and the grader's stderr tail.
	SetupSeconds float64 `json:"-"`
	StderrTail   string  `json:"-"`
}

// parseGradeResult decodes grade.sh's JSON output. Anything that is not the
// contract is an error (callers treat it as a failed grade, never a pass).
func parseGradeResult(stdout string) (*GradeResult, error) {
	trimmed := strings.TrimSpace(stdout)
	if trimmed == "" {
		return nil, fmt.Errorf("labs.parseGradeResult: empty grader output")
	}
	var r GradeResult
	if err := json.Unmarshal([]byte(trimmed), &r); err != nil {
		return nil, fmt.Errorf("labs.parseGradeResult: %w", err)
	}
	if r.Error == "" && len(r.Checks) == 0 {
		return nil, fmt.Errorf("labs.parseGradeResult: no checks reported")
	}
	// A pass claim must be backed by every check passing.
	if r.Passed {
		for _, c := range r.Checks {
			if !c.Passed {
				r.Passed = false
				break
			}
		}
	}
	if r.Error != "" {
		r.Passed = false
	}
	return &r, nil
}

// failureText renders the student-facing failure feedback: failing check
// names with their author messages only.
func (r *GradeResult) failureText() string {
	var b strings.Builder
	if r.Error != "" {
		b.WriteString(r.Error + "\n")
	}
	for _, c := range r.Checks {
		if c.Passed {
			continue
		}
		b.WriteString("FAIL " + c.Name)
		if c.Message != "" {
			b.WriteString(": " + c.Message)
		}
		b.WriteString("\n")
	}
	return strings.TrimSpace(b.String())
}

// protectedPaths lists the manifest's file paths (sorted, stable).
func protectedPaths(manifest json.RawMessage) ([]string, error) {
	if len(manifest) == 0 {
		return nil, nil
	}
	var m map[string]string
	if err := json.Unmarshal(manifest, &m); err != nil {
		return nil, fmt.Errorf("labs.protectedPaths: %w", err)
	}
	out := make([]string, 0, len(m))
	for p := range m {
		out = append(out, p)
	}
	sort.Strings(out)
	return out, nil
}

// editableTarScript builds the fixed script that tars the student's editable
// regular files (no symlinks, no .git, no dependency/cache dirs, no protected
// paths). Paths come from the pristine bundle's manifest, never the student,
// and are shell-quoted regardless.
func editableTarScript(protected []string) string {
	var b strings.Builder
	b.WriteString("cd " + shellQuote(labWorkdir) + " && find . -type f")
	for _, p := range []string{".git", "node_modules", ".venv", "__pycache__", ".pytest_cache", "logs"} {
		b.WriteString(" -not -path " + shellQuote("./"+p+"/*") + " -not -path " + shellQuote("*/"+p+"/*"))
	}
	for _, p := range protected {
		b.WriteString(" -not -path " + shellQuote("./"+strings.TrimPrefix(p, "./")))
	}
	b.WriteString(" -print0 | tar --null --no-recursion -T - -czf -")
	return b.String()
}

// captureEditableWorkspace pulls the student's editable files out of their
// container as a tar.gz via the trusted ExecCapture.
func (s *Service) captureEditableWorkspace(ctx context.Context, containerID string, v *labkinds.VariantView) ([]byte, error) {
	protected, err := protectedPaths(v.ProtectedManifest)
	if err != nil {
		return nil, fmt.Errorf("labs.captureEditableWorkspace: %w", err)
	}
	stdout, stderr, exitCode, err := s.container.ExecCapture(ctx, containerID, editableTarScript(protected), MaxCapturedWorkspaceBytes)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.captureEditableWorkspace: exec: %w", err)
	}
	if exitCode != 0 {
		return nil, fmt.Errorf("labs.Service.captureEditableWorkspace: tar exited %d: %s", exitCode, strings.TrimSpace(stderr))
	}
	if len(stdout) >= MaxCapturedWorkspaceBytes || strings.HasSuffix(stdout, "(output truncated)") {
		return nil, fmt.Errorf("labs.Service.captureEditableWorkspace: workspace exceeds %d bytes", MaxCapturedWorkspaceBytes)
	}
	return []byte(stdout), nil
}

// GradeTarget identifies what a clean-room run is graded on behalf of.
type GradeTarget struct {
	Image     string // sandbox image (the lab's environment)
	OrgID     string // org the validation seconds are metered against
	SessionID string // triggering session ("" = build verification, metered without a session)
	Budget    time.Duration // whole-run deadline; 0 = derived from the per-mode constants
	// AfterGrade, when set, runs once after every mode has been graded and
	// before the sandbox is destroyed. Build verification uses it to capture the
	// broken app's real log/traceback. Its error is logged, never fatal.
	AfterGrade func(ctx context.Context, containerID string) error
}

// stderrTailBytes bounds the grader stderr kept per result for reports.
const stderrTailBytes = 1500

// GradeInCleanRoom grades one mode in a throwaway sandbox. Reusable by the
// build-verification jobs, which pass their own editableTar (e.g. the
// reference fix or a cheat) instead of a student's.
func (s *Service) GradeInCleanRoom(ctx context.Context, target GradeTarget, v *labkinds.VariantView, editableTar []byte, mode, seed string) (*GradeResult, error) {
	res, err := s.GradeModesInCleanRoom(ctx, target, v, editableTar, []string{mode}, seed)
	if err != nil {
		return nil, fmt.Errorf("labs.GradeInCleanRoom: %w", err)
	}
	return res[mode], nil
}

// GradeModesInCleanRoom runs several modes against ONE clean-room sandbox
// (a Check covers symptom+regression+student-test with a single start).
func (s *Service) GradeModesInCleanRoom(ctx context.Context, target GradeTarget, v *labkinds.VariantView, editableTar []byte, modes []string, seed string) (map[string]*GradeResult, error) {
	select {
	case cleanRoomSem <- struct{}{}:
		defer func() { <-cleanRoomSem }()
	case <-time.After(cleanRoomQueueWait):
		return nil, ErrGradeBusy
	case <-ctx.Done():
		return nil, ctx.Err()
	}

	started := time.Now()
	defer func() {
		if target.OrgID != "" {
			seconds := int64(time.Since(started).Seconds()) + 1
			if mErr := s.repo.RecordValidationUsage(context.Background(), target.OrgID, target.SessionID, target.Image, seconds); mErr != nil {
				slog.Error("labs.Service.GradeModesInCleanRoom: meter validation usage", "error", mErr)
			}
		}
	}()
	return GradeModesInSandbox(ctx, s.container, target, v, editableTar, modes, seed)
}

// GradeModesInSandbox is the clean-room grade itself: a throwaway sandbox
// seeded with the pristine workspace then the overlay, every mode graded, the
// sandbox killed. No concurrency cap and no metering (Service.GradeModesInCleanRoom
// adds both); used directly by offline tooling (`coursegen blocks verify`).
func GradeModesInSandbox(ctx context.Context, rt ContainerRuntime, target GradeTarget, v *labkinds.VariantView, editableTar []byte, modes []string, seed string) (map[string]*GradeResult, error) {
	if len(v.WorkspaceBundle) == 0 || len(v.GraderBundle) == 0 {
		return nil, fmt.Errorf("labs.GradeModesInSandbox: variant bundles not loaded")
	}
	budget := target.Budget
	if budget <= 0 {
		budget = cleanRoomReadyBudget + time.Duration(len(modes))*DebugGradeTimeoutSeconds*time.Second
	}
	ctx, cancel := context.WithTimeout(ctx, budget)
	defer cancel()

	idBytes := make([]byte, 8)
	if _, err := crand.Read(idBytes); err != nil {
		return nil, fmt.Errorf("labs.GradeModesInSandbox: id: %w", err)
	}
	started := time.Now()
	containerID, _, err := rt.StartValidation(ctx, "grade-"+hex.EncodeToString(idBytes), target.Image)
	if err != nil {
		return nil, fmt.Errorf("labs.GradeModesInSandbox: start: %w", err)
	}
	defer func() { _ = rt.Kill(context.Background(), containerID) }()
	if _, err := WaitContainerReady(ctx, rt, containerID); err != nil {
		return nil, fmt.Errorf("labs.GradeModesInSandbox: %w", err)
	}

	// Pristine first, then the student's overlay — order is load-bearing.
	seeds := []struct {
		label   string
		payload []byte
	}{{"pristine", v.WorkspaceBundle}, {"overlay", editableTar}}
	for _, sd := range seeds {
		if len(sd.payload) == 0 {
			continue
		}
		_, stderr, exitCode, err := rt.ExecStdin(ctx, containerID, extractBundleScript, sd.payload, SetupScriptTimeoutSeconds)
		if err != nil {
			return nil, fmt.Errorf("labs.GradeModesInSandbox: seed %s: %w", sd.label, err)
		}
		if exitCode != 0 {
			return nil, fmt.Errorf("labs.GradeModesInSandbox: seed %s exited %d: %s", sd.label, exitCode, strings.TrimSpace(stderr))
		}
	}

	setupSeconds := time.Since(started).Seconds()
	results := make(map[string]*GradeResult, len(modes))
	for _, mode := range modes {
		script := "/opt/mindforge/grade.sh " + shellQuote(mode) + " --seed " + shellQuote(seed)
		stdout, stderr, exitCode, err := rt.ExecStdin(ctx, containerID, script, v.GraderBundle, DebugGradeTimeoutSeconds)
		// A canceled/expired context can surface as exit=1 with empty output
		// and no error; that is an interrupted grade, never "unusable output".
		if cerr := gradeInterruption(ctx); cerr != nil {
			return nil, fmt.Errorf("labs.GradeModesInSandbox: run %s: %w", mode, cerr)
		}
		if err != nil {
			return nil, fmt.Errorf("labs.GradeModesInSandbox: run %s: %w", mode, err)
		}
		res, perr := parseGradeResult(stdout)
		if perr != nil {
			slog.Error("labs.GradeModesInSandbox: unusable grader output",
				"mode", mode, "exit", exitCode, "stderr", strings.TrimSpace(stderr), "error", perr)
			res = &GradeResult{Error: "The grader could not complete this check. Try again; if it persists, contact your instructor."}
		}
		res.Mode = mode
		res.SetupSeconds = setupSeconds
		res.StderrTail = tailString(strings.TrimSpace(stderr), stderrTailBytes)
		results[mode] = res
	}
	if target.AfterGrade != nil {
		if err := target.AfterGrade(ctx, containerID); err != nil {
			slog.Warn("labs.GradeModesInSandbox: after-grade hook", "error", err)
		}
	}
	return results, nil
}

// gradeInterruption maps a finished grading context to a typed, retryable error.
func gradeInterruption(ctx context.Context) error {
	switch {
	case errors.Is(ctx.Err(), context.DeadlineExceeded):
		return ErrGradeTimeout
	case ctx.Err() != nil:
		return ErrGradeInterrupted
	}
	return nil
}

func tailString(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[len(s)-n:]
}

// newGradeSeed returns a crypto-random per-Check seed.
func newGradeSeed() (string, error) {
	b := make([]byte, 16)
	if _, err := crand.Read(b); err != nil {
		return "", fmt.Errorf("labs.newGradeSeed: %w", err)
	}
	return hex.EncodeToString(b), nil
}

func gradeCooldownKey(sessionID string) string { return "lab:kindgrade:cooldown:" + sessionID }
func lastGradeKey(sessionID string) string     { return "lab:kindgrade:last:" + sessionID }

// acquireGradeCooldown enforces the per-session grade cooldown; returns
// a *RateLimitedError (Is ErrRateLimited) while cooling down. Fails open on Redis errors.
func (s *Service) acquireGradeCooldown(ctx context.Context, sessionID string) error {
	return s.acquireCooldown(ctx, gradeCooldownKey(sessionID), DebugGradeCooldownSeconds*time.Second, "labs.Service.acquireGradeCooldown")
}

// releaseGradeCooldown clears the cooldown after an infrastructure failure,
// so the student is not penalized for the platform's error.
func (s *Service) releaseGradeCooldown(ctx context.Context, sessionID string) {
	if err := s.rdb.Del(ctx, gradeCooldownKey(sessionID)).Err(); err != nil {
		slog.Warn("labs.Service.releaseGradeCooldown", "error", err)
	}
}

// gradeKindModes runs the given modes for a session in one clean room and
// stores the failure text for the hint prompt.
func (s *Service) gradeKindModes(ctx context.Context, session *LabSession, lab *LabDefinition, modes []string) (map[string]*GradeResult, error) {
	if err := s.ensureContainerResumed(ctx, session); err != nil {
		return nil, fmt.Errorf("labs.Service.gradeKindModes: %w", err)
	}
	v, err := s.sessionVariant(ctx, lab, session, true, true)
	if err != nil {
		return nil, fmt.Errorf("labs.gradeKindModes: %w", err)
	}
	tar, err := s.captureEditableWorkspace(ctx, *session.ContainerID, v)
	if err != nil {
		return nil, fmt.Errorf("labs.gradeKindModes: %w", err)
	}
	seed, err := newGradeSeed()
	if err != nil {
		return nil, fmt.Errorf("labs.gradeKindModes: %w", err)
	}
	results, err := s.GradeModesInCleanRoom(ctx, GradeTarget{Image: lab.Environment, OrgID: session.OrgID, SessionID: session.ID, Budget: s.gradeTimeout}, v, tar, modes, seed)
	if err != nil {
		return nil, fmt.Errorf("labs.gradeKindModes: %w", err)
	}
	var last strings.Builder
	for _, m := range modes {
		if t := results[m].failureText(); t != "" {
			last.WriteString("[" + m + "]\n" + t + "\n")
		}
	}
	out := last.String()
	if len(out) > lastGradeOutputMaxBytes {
		out = out[:lastGradeOutputMaxBytes]
	}
	if serr := s.rdb.Set(ctx, lastGradeKey(session.ID), out, lastGradeOutputTTL).Err(); serr != nil {
		slog.Warn("labs.Service.gradeKindModes: store last output", "error", serr)
	}
	return results, nil
}

// kindTaskMode validates that a script-graded task's mode belongs to its kind.
func kindTaskMode(kind labkinds.Kind, task *TaskSnapshot) (string, error) {
	if task.Grader == GraderWriteupReview {
		return "", ErrLabTypeUnsupported
	}
	mode := strings.TrimSpace(task.VerificationScript)
	if !slices.Contains(kind.GradeModes(), mode) {
		return "", fmt.Errorf("labs.kindTaskMode: task %s has grade mode %q not offered by kind %q", task.ID, mode, kind.Name())
	}
	return mode, nil
}

// verifyKindTask is VerifyTask's path for a lab whose lab_type has a
// registered Kind: script-graded tasks run in a clean room; writeup_review
// tasks are never run here.
func (s *Service) verifyKindTask(ctx context.Context, session *LabSession, lab *LabDefinition, kind labkinds.Kind, tasks []TaskSnapshot, task *TaskSnapshot, attempts int) (*VerifyResult, error) {
	// A student closing the tab must not abandon a half-graded Check.
	ctx = context.WithoutCancel(ctx)
	mode, err := kindTaskMode(kind, task)
	if err != nil {
		return nil, fmt.Errorf("labs.verifyKindTask: %w", err)
	}
	if err := s.acquireGradeCooldown(ctx, session.ID); err != nil {
		return nil, fmt.Errorf("labs.verifyKindTask: %w", err)
	}
	results, err := s.gradeKindModes(ctx, session, lab, []string{mode})
	if err != nil {
		s.releaseGradeCooldown(ctx, session.ID)
		return nil, fmt.Errorf("labs.verifyKindTask: %w", err)
	}
	return s.applyKindResult(ctx, session, lab, tasks, task, attempts, results[mode])
}

// applyKindResult turns a GradeResult into the VerifyResult/score pipeline.
func (s *Service) applyKindResult(ctx context.Context, session *LabSession, lab *LabDefinition, tasks []TaskSnapshot, task *TaskSnapshot, attempts int, res *GradeResult) (*VerifyResult, error) {
	if res.Passed {
		return s.finalizeTaskPass(ctx, session, lab, tasks, task.ID, task.Points, attempts, "All checks passed.", "")
	}
	return &VerifyResult{Passed: false, Attempts: attempts, Stdout: res.failureText()}, nil
}
