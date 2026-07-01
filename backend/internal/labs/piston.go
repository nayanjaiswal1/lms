package labs

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

const (
	maxVerifyStdout = 4000
	maxVerifyStderr = 2000
)

// labPiston is a minimal Piston API client for code-lab task verification.
// It submits the combined student code + verification harness as a single file
// and treats exit 0 as passed, non-zero as failed.
type labPiston struct {
	baseURL string
	client  *http.Client
}

func newLabPiston(baseURL string, timeout time.Duration) *labPiston {
	return &labPiston{
		baseURL: strings.TrimRight(baseURL, "/"),
		client:  &http.Client{Timeout: timeout},
	}
}

func (p *labPiston) available() bool { return p.baseURL != "" && p.client != nil }

var pistonLabLanguages = map[string]string{
	"javascript": "javascript",
	"python":     "python",
	"python3":    "python",
	"typescript": "typescript",
	"go":         "go",
}

type pistonLabRequest struct {
	Language string         `json:"language"`
	Version  string         `json:"version"`
	Files    []pistonLabFile `json:"files"`
}

type pistonLabFile struct {
	Content string `json:"content"`
}

type pistonLabRun struct {
	Stdout string `json:"stdout"`
	Stderr string `json:"stderr"`
	Code   int    `json:"code"`
	Signal string `json:"signal"`
}

type pistonLabResponse struct {
	Run pistonLabRun `json:"run"`
}

// Execute runs the combined student code + verification harness against Piston.
// Returns passed=true when Piston exits 0.
func (p *labPiston) Execute(ctx context.Context, language, combined string) (passed bool, stdout, stderr string, err error) {
	if !p.available() {
		return false, "", "", ErrExecutorUnavailable
	}
	pistonLang, ok := pistonLabLanguages[strings.ToLower(strings.TrimSpace(language))]
	if !ok {
		return false, "", "", fmt.Errorf("labs: unsupported language %q", language)
	}

	body, marshalErr := json.Marshal(pistonLabRequest{
		Language: pistonLang,
		Version:  "*",
		Files:    []pistonLabFile{{Content: combined}},
	})
	if marshalErr != nil {
		return false, "", "", fmt.Errorf("labs: marshal piston request: %w", marshalErr)
	}

	req, reqErr := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/api/v2/execute", bytes.NewReader(body))
	if reqErr != nil {
		return false, "", "", fmt.Errorf("labs: build piston request: %w", reqErr)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, doErr := p.client.Do(req)
	if doErr != nil {
		return false, "", "", fmt.Errorf("labs: call piston: %w", doErr)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return false, "", "", fmt.Errorf("labs: piston returned status %d", resp.StatusCode)
	}

	var out pistonLabResponse
	if decodeErr := json.NewDecoder(resp.Body).Decode(&out); decodeErr != nil {
		return false, "", "", fmt.Errorf("labs: decode piston response: %w", decodeErr)
	}

	return out.Run.Code == 0,
		truncateLabOutput(out.Run.Stdout, maxVerifyStdout),
		truncateLabOutput(out.Run.Stderr, maxVerifyStderr),
		nil
}

func truncateLabOutput(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max] + "…(truncated)"
}
