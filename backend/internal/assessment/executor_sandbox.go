package assessment

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/xml"
	"fmt"
	"path"
	"strings"
	"time"
)

// SandboxRuntime is the subset of labs.ContainerRuntime this package needs to
// grade a submission by actually running it. Defined locally rather than
// importing internal/labs: neither package imports the other today, and this
// interface is narrow enough that *labs.DockerContainerService (and the
// Kubernetes runtime behind the same labs.ContainerRuntime interface) already
// satisfy it structurally with no wrapper needed.
// Grading images are plain language runtimes with no background services to
// come up, so unlike a lab sandbox there is nothing to wait for between Start
// and the first Exec — which is why this interface needs neither
// labs.ContainerRuntime's readiness probe nor its setup step.
type SandboxRuntime interface {
	Start(ctx context.Context, sessionID string, resetCount int, image string) (containerID, containerHost string, err error)
	Kill(ctx context.Context, containerID string) error
	Exec(ctx context.Context, containerID, script string, timeoutSec int) (stdout, stderr string, exitCode int, err error)
}

// sandboxExecutor grades a submission by running it for real inside an
// ephemeral Docker (or Kubernetes) container, instead of the stdio
// Piston/Judge0 diff path. Selected per-question via CodingContent.Runtime —
// see Service.executorFor.
type sandboxExecutor struct {
	rt SandboxRuntime
}

// NewSandboxExecutor wraps a container runtime as a CodeExecutor. rt may be
// nil (e.g. no Docker/K8s available in this deploy) — Available() reports
// false and grading falls back to "pending manual review", same as an
// unconfigured Piston/Judge0 executor.
func NewSandboxExecutor(rt SandboxRuntime) CodeExecutor {
	return &sandboxExecutor{rt: rt}
}

func (e *sandboxExecutor) Available() bool { return e.rt != nil }

// sandboxResultPath is the fixed path a question's VerifyCommand must write
// its JUnit XML report to, e.g.
// "pytest --junitxml=/tmp/mindforge-grade-result.xml -q test_app.py" or
// "vitest run --reporter=junit --outputFile=/tmp/mindforge-grade-result.xml".
const sandboxResultPath = "/tmp/mindforge-grade-result.xml"

// Run starts a fresh container from content.SandboxImage, writes the
// candidate's submission plus every server-only verification file into it,
// runs VerifyCommand once, and parses the JUnit XML it produces into
// per-test-case results. lang is accepted to satisfy the CodeExecutor
// interface but sandbox grading is language-agnostic — the image and
// VerifyCommand already encode the runtime.
func (e *sandboxExecutor) Run(ctx context.Context, lang, source string, content CodingContent) (RunResult, error) {
	if content.SandboxImage == "" || content.SubmitPath == "" || content.VerifyCommand == "" {
		return RunResult{Status: "error"}, fmt.Errorf("assessment: sandbox question missing image/submit_path/verify_command")
	}

	id, err := randSessionSuffix()
	if err != nil {
		return RunResult{Status: "error"}, fmt.Errorf("assessment: generate sandbox session id: %w", err)
	}

	timeout := time.Duration(content.TimeLimitMs) * time.Millisecond
	if timeout <= 0 {
		timeout = 30 * time.Second
	}
	runCtx, cancel := runDeadline(ctx, timeout+15*time.Second) // container start/write overhead on top of the verify budget
	defer cancel()

	containerID, _, err := e.rt.Start(runCtx, "grade-"+id, 0, content.SandboxImage)
	if err != nil {
		return RunResult{Status: "error"}, fmt.Errorf("assessment: start sandbox container: %w", err)
	}
	defer func() {
		// Container teardown must not be cut short by the grading deadline.
		killCtx, killCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer killCancel()
		_ = e.rt.Kill(killCtx, containerID)
	}()

	if err := e.writeFile(runCtx, containerID, content.SubmitPath, source); err != nil {
		return RunResult{Status: "error"}, err
	}
	for filePath, body := range content.VerifyFiles {
		if err := e.writeFile(runCtx, containerID, filePath, body); err != nil {
			return RunResult{Status: "error"}, err
		}
	}

	verifySeconds := int(timeout / time.Second)
	if verifySeconds <= 0 {
		verifySeconds = 30
	}
	_, verifyStderr, _, err := e.rt.Exec(runCtx, containerID, content.VerifyCommand, verifySeconds)
	if err != nil {
		return RunResult{Status: "error"}, fmt.Errorf("assessment: run sandbox verify command: %w", err)
	}

	xmlOut, catStderr, _, err := e.rt.Exec(runCtx, containerID, "cat "+shellQuote(sandboxResultPath), 5)
	if err != nil || strings.TrimSpace(xmlOut) == "" {
		return RunResult{
			Status:        "error",
			CompileOutput: truncate(strings.TrimSpace(verifyStderr+"\n"+catStderr), maxStderrBytes),
		}, fmt.Errorf("assessment: sandbox produced no JUnit report")
	}

	return parseJUnit(xmlOut, content.TestCases)
}

// writeFile injects body into the container at filePath. Candidate source and
// test fixtures can contain arbitrary shell metacharacters, quotes, and
// backticks, so the content is base64-encoded on the Go side and decoded
// inside the container rather than interpolated into a shell heredoc.
func (e *sandboxExecutor) writeFile(ctx context.Context, containerID, filePath, body string) error {
	dir := path.Dir(filePath)
	encoded := base64.StdEncoding.EncodeToString([]byte(body))
	script := fmt.Sprintf("mkdir -p %s && printf %%s %s | base64 -d > %s",
		shellQuote(dir), shellQuote(encoded), shellQuote(filePath))
	_, stderr, exitCode, err := e.rt.Exec(ctx, containerID, script, 10)
	if err != nil {
		return fmt.Errorf("assessment: write sandbox file %s: %w", filePath, err)
	}
	if exitCode != 0 {
		return fmt.Errorf("assessment: write sandbox file %s: exit %d: %s", filePath, exitCode, truncate(stderr, maxStderrBytes))
	}
	return nil
}

// shellQuote wraps s in single quotes for safe use inside a `bash -c` script,
// escaping any single quotes in s itself. Mirrors the escaping already done in
// labs.DockerContainerService.Exec/Start for setup scripts.
func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

func randSessionSuffix() (string, error) {
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// ─── JUnit XML parsing ────────────────────────────────────────────────────────

type junitTestsuites struct {
	Suites []junitTestsuite `xml:"testsuite"`
	// A bare <testsuite> root (no wrapping <testsuites>) is also valid JUnit —
	// unmarshaled into the same struct via junitTestcases below when Suites is empty.
	junitTestcases
}

type junitTestsuite struct {
	junitTestcases
}

type junitTestcases struct {
	Cases []junitTestcase `xml:"testcase"`
}

type junitTestcase struct {
	Name      string      `xml:"name,attr"`
	ClassName string      `xml:"classname,attr"`
	Time      string      `xml:"time,attr"`
	Failure   *junitEvent `xml:"failure"`
	Error     *junitEvent `xml:"error"`
	Skipped   *junitEvent `xml:"skipped"`
}

type junitEvent struct {
	Message string `xml:"message,attr"`
	Text    string `xml:",chardata"`
}

// parseJUnit maps a JUnit XML report (as emitted by `pytest --junitxml` or
// `vitest run --reporter=junit`) into a RunResult, matching each <testcase
// name="..."> to the TestCase whose ID equals that name so Hidden/Weight carry
// over. Test cases present in expected but missing from the report (e.g. a
// crash before pytest could collect them) are recorded as failed rather than
// silently dropped, so a candidate can't score points by crashing the harness.
func parseJUnit(xmlBody string, expected []TestCase) (RunResult, error) {
	var doc junitTestsuites
	if err := xml.Unmarshal([]byte(xmlBody), &doc); err != nil {
		return RunResult{Status: "error"}, fmt.Errorf("assessment: parse JUnit report: %w", err)
	}

	var all []junitTestcase
	if len(doc.Suites) > 0 {
		for _, s := range doc.Suites {
			all = append(all, s.Cases...)
		}
	} else {
		all = doc.Cases
	}

	byName := make(map[string]junitTestcase, len(all))
	for _, tc := range all {
		byName[tc.Name] = tc
	}

	res := RunResult{Status: "passed", TestsTotal: len(expected)}
	for _, want := range expected {
		got, found := byName[want.ID]
		passed := found && got.Failure == nil && got.Error == nil && got.Skipped == nil

		status := "runtime_error"
		var stderrMsg string
		switch {
		case !found:
			status, stderrMsg = "wrong_answer", "test not reported by verification run"
		case passed:
			status = "accepted"
		case got.Failure != nil:
			status, stderrMsg = "wrong_answer", got.Failure.Message+"\n"+got.Failure.Text
		case got.Error != nil:
			status, stderrMsg = "runtime_error", got.Error.Message+"\n"+got.Error.Text
		case got.Skipped != nil:
			status, stderrMsg = "wrong_answer", "test skipped"
		}

		if passed {
			res.TestsPassed++
		} else {
			res.Status = "failed"
		}

		res.Cases = append(res.Cases, CaseResult{
			CaseID: want.ID,
			Passed: passed,
			Hidden: want.Hidden,
			Weight: want.Weight,
			Status: status,
			Stderr: truncate(strings.TrimSpace(stderrMsg), maxStderrBytes),
		})
	}

	return res, nil
}
