package labs

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/httputil"
)

// ─── Standalone snippet execution (in-lesson code runner) ────────────────────
//
// Lesson code blocks are illustrative, not graded: there is no lab session,
// no verification harness, no attempts tracking and no scoring. The endpoint
// just pipes the snippet through Piston and returns raw stdout/stderr plus
// the exit status, gated by auth and a per-user rate limit.

const (
	// snippetRateLimitSeconds is the per-user cooldown between snippet runs.
	snippetRateLimitSeconds = 2
	// maxSnippetCodeBytes bounds the request body — lesson snippets are small.
	maxSnippetCodeBytes = 64 * 1024
)

// SnippetResult is the response body for POST /api/labs/run.
type SnippetResult struct {
	ExitOK bool   `json:"exit_ok"`
	Stdout string `json:"stdout"`
	Stderr string `json:"stderr"`
}

// RunSnippet executes a standalone code snippet through Piston without a lab
// session. language must already be validated against the Piston allow-list
// (see HandleRunSnippet) so arbitrary interpreter names never reach the
// executor.
func (s *Service) RunSnippet(ctx context.Context, userID, language, code string) (*SnippetResult, error) {
	// Per-user rate limit — snippet runs share one cooldown regardless of
	// which lesson they come from. Fail open on Redis errors (same policy
	// as VerifyTask).
	rateLimitKey := fmt.Sprintf("lab:snippet:rate:%s", userID)
	set, rErr := s.rdb.SetNX(ctx, rateLimitKey, 1, snippetRateLimitSeconds*time.Second).Result()
	if rErr != nil {
		slog.Error("labs.Service.RunSnippet: rate limit check", "error", rErr)
	} else if !set {
		return nil, ErrRateLimited
	}

	execCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	exitOK, stdout, stderr, execErr := s.piston.Execute(execCtx, language, code)
	if execErr != nil {
		if errors.Is(execErr, ErrExecutorUnavailable) {
			return nil, ErrExecutorUnavailable
		}
		slog.Error("labs.Service.RunSnippet: execute", "error", execErr)
		return &SnippetResult{ExitOK: false, Stderr: "Execution failed. Please try again."}, nil
	}
	return &SnippetResult{ExitOK: exitOK, Stdout: stdout, Stderr: stderr}, nil
}

// HandleRunSnippet executes a standalone lesson code snippet through Piston.
// No lab session is required — authentication plus a per-user rate limit
// only. The language is validated against the fixed Piston allow-list here,
// before it ever reaches the executor.
//
//	POST /api/labs/run
func (h *Handler) HandleRunSnippet(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	var body struct {
		Language string `json:"language"`
		Code     string `json:"code"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Code) == "" {
		httputil.WriteError(w, http.StatusBadRequest, "code is required.")
		return
	}
	if len(body.Code) > maxSnippetCodeBytes {
		httputil.WriteError(w, http.StatusBadRequest, "Code is too long to run.")
		return
	}
	lang := strings.ToLower(strings.TrimSpace(body.Language))
	if _, supported := pistonLabLanguages[lang]; !supported {
		httputil.WriteError(w, http.StatusBadRequest, "Unsupported language.")
		return
	}

	result, err := h.service.RunSnippet(r.Context(), claims.UserID, lang, body.Code)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}
