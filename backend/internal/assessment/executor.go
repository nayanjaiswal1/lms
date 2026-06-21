package assessment

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/config"
)

// maxStdoutBytes and maxStderrBytes cap the amount of output stored per test
// case to prevent oversized payloads from filling the DB or response body.
const (
	maxStdoutBytes = 4000
	maxStderrBytes = 2000
)

// ─── Executor contract ───────────────────────────────────────────────────────

// CaseResult is the outcome of running one test case.
type CaseResult struct {
	CaseID   string  `json:"case_id"`
	Passed   bool    `json:"passed"`
	Hidden   bool    `json:"hidden"`
	Weight   float64 `json:"weight"`
	Stdout   string  `json:"stdout,omitempty"`   // omitted for hidden cases by the caller
	Stderr   string  `json:"stderr,omitempty"`
	Status   string  `json:"status"`             // accepted | wrong_answer | runtime_error | compile_error | tle
	RuntimeMs int    `json:"runtime_ms"`
}

// RunResult aggregates a full execution across all test cases.
type RunResult struct {
	Status        string       `json:"status"` // passed | failed | error
	CompileOutput string       `json:"compile_output,omitempty"`
	TestsTotal    int          `json:"tests_total"`
	TestsPassed   int          `json:"tests_passed"`
	RuntimeMs     int          `json:"runtime_ms"`
	MemoryKb      int          `json:"memory_kb"`
	Cases         []CaseResult `json:"cases"`
}

// CodeExecutor runs a source submission against a set of test cases and reports
// per-case pass/fail. Implementations must be safe for concurrent use.
type CodeExecutor interface {
	// Available reports whether the executor is wired to a backing engine.
	Available() bool
	Run(ctx context.Context, lang, source string, content CodingContent) (RunResult, error)
}

// NewExecutor selects the executor implementation from configuration.
// With JUDGE0_URL set it returns a live Judge0 client; otherwise an unavailable
// executor that defers coding grading to manual review.
func NewExecutor(cfg *config.Config) CodeExecutor {
	if cfg.Judge0URL == "" {
		return unavailableExecutor{}
	}
	return &judge0Executor{
		baseURL: cfg.Judge0URL,
		token:   cfg.Judge0Token,
		client:  &http.Client{Timeout: cfg.Judge0Timeout},
	}
}

// ─── Unavailable executor ────────────────────────────────────────────────────

type unavailableExecutor struct{}

func (unavailableExecutor) Available() bool { return false }
func (unavailableExecutor) Run(context.Context, string, string, CodingContent) (RunResult, error) {
	return RunResult{}, errExecutorUnavailable
}

var errExecutorUnavailable = fmt.Errorf("assessment: code executor not configured")

// ─── Judge0 executor ─────────────────────────────────────────────────────────

// judge0LanguageIDs maps MindForge language keys to Judge0 CE language IDs.
// These are stable IDs in the Judge0 community edition image.
var judge0LanguageIDs = map[string]int{
	"python":     71,
	"python3":    71,
	"javascript": 63,
	"node":       63,
	"typescript": 74,
	"go":         60,
	"java":       62,
	"c":          50,
	"cpp":        54,
	"c++":        54,
	"csharp":     51,
	"ruby":       72,
	"rust":       73,
	"kotlin":     78,
	"php":        68,
}

type judge0Executor struct {
	baseURL string
	token   string
	client  *http.Client
}

func (e *judge0Executor) Available() bool { return true }

type judge0Request struct {
	SourceCode     string `json:"source_code"`
	LanguageID     int    `json:"language_id"`
	Stdin          string `json:"stdin"`
	ExpectedOutput string `json:"expected_output,omitempty"`
	CPUTimeLimit   string `json:"cpu_time_limit,omitempty"`
	MemoryLimit    int    `json:"memory_limit,omitempty"`
}

type judge0Response struct {
	Stdout        string `json:"stdout"`
	Stderr        string `json:"stderr"`
	CompileOutput string `json:"compile_output"`
	Message       string `json:"message"`
	Time          string `json:"time"`
	Memory        int    `json:"memory"`
	Status        struct {
		ID          int    `json:"id"`
		Description string `json:"description"`
	} `json:"status"`
}

// Run executes the submission once per test case (wait=true) and tallies the
// weighted pass count. A compile error short-circuits the whole run.
func (e *judge0Executor) Run(ctx context.Context, lang, source string, content CodingContent) (RunResult, error) {
	langID, ok := judge0LanguageIDs[strings.ToLower(strings.TrimSpace(lang))]
	if !ok {
		return RunResult{Status: "error"}, fmt.Errorf("assessment: unsupported language %q", lang)
	}

	res := RunResult{Status: "passed", TestsTotal: len(content.TestCases)}
	if len(content.TestCases) == 0 {
		res.Status = "error"
		return res, fmt.Errorf("assessment: coding question has no test cases")
	}

	for _, tc := range content.TestCases {
		out, err := e.submit(ctx, judge0Request{
			SourceCode:     source,
			LanguageID:     langID,
			Stdin:          tc.Stdin,
			ExpectedOutput: tc.Expected,
			CPUTimeLimit:   cpuLimitSeconds(content.TimeLimitMs),
			MemoryLimit:    content.MemoryLimitKb,
		})
		if err != nil {
			return RunResult{Status: "error"}, err
		}

		// Judge0 compile error (status 6) aborts the whole submission.
		if out.Status.ID == 6 {
			res.Status = "error"
			res.CompileOutput = strings.TrimSpace(out.CompileOutput + out.Message)
			res.TestsPassed = 0
			res.Cases = nil
			return res, nil
		}

		runtimeMs := parseSecondsToMs(out.Time)
		res.RuntimeMs += runtimeMs
		if out.Memory > res.MemoryKb {
			res.MemoryKb = out.Memory
		}

		passed := out.Status.ID == 3 // 3 = Accepted (stdout matches expected_output)
		if passed {
			res.TestsPassed++
		} else {
			res.Status = "failed"
		}

		res.Cases = append(res.Cases, CaseResult{
			CaseID:    tc.ID,
			Passed:    passed,
			Hidden:    tc.Hidden,
			Weight:    tc.Weight,
			Stdout:    truncate(out.Stdout, maxStdoutBytes),
			Stderr:    truncate(out.Stderr, maxStderrBytes),
			Status:    judge0StatusName(out.Status.ID),
			RuntimeMs: runtimeMs,
		})
	}

	return res, nil
}

func (e *judge0Executor) submit(ctx context.Context, body judge0Request) (judge0Response, error) {
	payload, err := json.Marshal(body)
	if err != nil {
		return judge0Response{}, fmt.Errorf("assessment: marshal judge0 request: %w", err)
	}

	url := e.baseURL + "/submissions?base64_encoded=false&wait=true"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(payload))
	if err != nil {
		return judge0Response{}, fmt.Errorf("assessment: build judge0 request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	if e.token != "" {
		req.Header.Set("X-Auth-Token", e.token)
	}

	resp, err := e.client.Do(req)
	if err != nil {
		return judge0Response{}, fmt.Errorf("assessment: call judge0: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return judge0Response{}, fmt.Errorf("assessment: judge0 returned status %d", resp.StatusCode)
	}

	var out judge0Response
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return judge0Response{}, fmt.Errorf("assessment: decode judge0 response: %w", err)
	}
	return out, nil
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func cpuLimitSeconds(ms int) string {
	if ms <= 0 {
		return ""
	}
	return fmt.Sprintf("%.3f", float64(ms)/1000.0)
}

func parseSecondsToMs(s string) int {
	if s == "" {
		return 0
	}
	var secs float64
	if _, err := fmt.Sscanf(s, "%f", &secs); err != nil {
		return 0
	}
	return int(secs * 1000)
}

func judge0StatusName(id int) string {
	switch id {
	case 3:
		return "accepted"
	case 4:
		return "wrong_answer"
	case 5:
		return "tle"
	case 6:
		return "compile_error"
	default:
		return "runtime_error"
	}
}

func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max] + "…(truncated)"
}

// runDeadline derives a context deadline from the executor's per-run budget so a
// hung engine cannot block an HTTP handler indefinitely.
func runDeadline(parent context.Context, d time.Duration) (context.Context, context.CancelFunc) {
	if d <= 0 {
		d = 30 * time.Second
	}
	return context.WithTimeout(parent, d)
}
