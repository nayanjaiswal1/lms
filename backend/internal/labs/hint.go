package labs

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/ai"
	"github.com/redis/go-redis/v9"
)

// redisClient is the small slice of *redis.Client the AI circuit breaker
// needs — extracted so aiCircuitOpen/recordAIFailure/recordAISuccess are
// unit-testable against a fake without a live Redis (see hint_test.go).
// *redis.Client satisfies this structurally; Service.rdb is passed as-is.
type redisClient interface {
	Exists(ctx context.Context, keys ...string) *redis.IntCmd
	Incr(ctx context.Context, key string) *redis.IntCmd
	Expire(ctx context.Context, key string, expiration time.Duration) *redis.BoolCmd
	Set(ctx context.Context, key string, value any, expiration time.Duration) *redis.StatusCmd
	Del(ctx context.Context, keys ...string) *redis.IntCmd
}

// ─── Generic lab hint endpoint (docs/labs.md "AI Integration" § Hint System;
// docs/debug-labs.md "Genuinely new" #5 — documented as labs Phase 3 but
// never built until now) ────────────────────────────────────────────────────

// HintResult is the payload returned to the caller after a hint request.
type HintResult struct {
	Level          int    `json:"level"`
	Content        string `json:"content"`
	HintsUsed      int    `json:"hints_used"`
	HintsRemaining int    `json:"hints_remaining"`
	// HintPenaltyPct is the lab's configured penalty (0 = hints free) — the
	// frontend shows this as a warning before the student confirms revealing
	// a hint (docs/debug-labs.md frontend requirement). The score-side
	// effect is applied where it already lived before this endpoint existed:
	// MarkTaskPassed reads hints_used at pass time (finalizeTaskPass) and
	// computes points*max(0, 1-hints_used*pct/100) — this endpoint only
	// needs to increment hints_used correctly, never touch scoring itself.
	HintPenaltyPct int `json:"hint_penalty_pct"`
}

// hintCacheKey mirrors docs/labs.md exactly: sha256(session_id + task_id +
// hint_level). Scoped to session (not user), so a hint generated from one
// attempt's terminal state is never replayed against a later attempt of the
// same lab — see that section's own reasoning.
func hintCacheKey(sessionID, taskID string, level int) string {
	sum := sha256.Sum256([]byte(fmt.Sprintf("%s%s%d", sessionID, taskID, level)))
	return hex.EncodeToString(sum[:])
}

// hintSystemPrompt instructs the model to behave like a lab TA giving a
// nudge, never the answer — the same rule for every level; only how much of
// a nudge escalates.
const hintSystemPrompt = `You are a patient teaching assistant helping a student debug a hands-on lab exercise.
Give a SOCRATIC hint: one guiding question or one specific place to look — never the solution, never a code snippet that solves the task, never the exact command to run.

Hint levels:
- Level 1 (conceptual nudge): point at the general approach or concept, phrased as a question. Do not name specific files, commands, or flags.
- Level 2 (specific direction): name the command category, file, or area of the system to look at — still no exact syntax.
- Level 3 (near-answer): give the exact syntax or command shape with ONE gap left for the student to fill in themselves (e.g. a blank, a placeholder, or "what value goes here?").

Keep it to 1-3 sentences. Never reveal the full verification script or the complete solution.`

// buildHintUserPrompt assembles the student-specific context. Terminal/
// grader output would strengthen this (docs/debug-labs.md's stated design),
// but no PTY ring buffer exists yet to source it from (see docs/labs.md
// "Terminal history source" — that capture lives in labproxy's terminal
// relay, not yet built) — this deliberately uses only what is genuinely
// available today: the task's own authored content and the attempt count.
func buildHintUserPrompt(task *TaskSnapshot, level, attempts int) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Task: %s\n\n", task.Title)
	fmt.Fprintf(&b, "Task description:\n%s\n\n", task.Description)
	if strings.TrimSpace(task.HintContext) != "" {
		fmt.Fprintf(&b, "Instructor's hint context (for you only, never quote verbatim):\n%s\n\n", task.HintContext)
	}
	fmt.Fprintf(&b, "Student's attempt count so far: %d\n", attempts)
	fmt.Fprintf(&b, "Hint level requested: %d of %d\n", level, MaxHintsPerTask)
	return b.String()
}

// aiCircuitOpenKey/FailureKey are process-independent (Redis-backed) so
// every API replica shares one breaker state — see AICircuitFailureThreshold.
const (
	aiCircuitOpenKey    = "lab:ai:circuit:open"
	aiCircuitFailureKey = "lab:ai:circuit:failures"
)

// aiCircuitOpen reports whether the shared AI circuit breaker is currently
// open. Fails OPEN on a Redis error (treats the breaker as closed) — a Redis
// outage must not additionally take down every AI feature on top of
// whatever else it's already breaking; the provider call itself still has
// its own error handling if it also happens to be unavailable.
func aiCircuitOpen(ctx context.Context, rdb redisClient) bool {
	n, err := rdb.Exists(ctx, aiCircuitOpenKey).Result()
	if err != nil {
		slog.Warn("labs: AI circuit breaker open-check failed, failing open", "error", err)
		return false
	}
	return n > 0
}

// recordAIFailure increments the shared consecutive-failure counter (reset
// by recordAISuccess) and opens the circuit once AICircuitFailureThreshold
// is reached within AICircuitFailureWindow.
func recordAIFailure(ctx context.Context, rdb redisClient) {
	count, err := rdb.Incr(ctx, aiCircuitFailureKey).Result()
	if err != nil {
		slog.Warn("labs: AI circuit breaker failure increment failed", "error", err)
		return
	}
	if count == 1 {
		if err := rdb.Expire(ctx, aiCircuitFailureKey, AICircuitFailureWindow).Err(); err != nil {
			slog.Warn("labs: AI circuit breaker set failure window failed", "error", err)
		}
	}
	if count >= AICircuitFailureThreshold {
		if err := rdb.Set(ctx, aiCircuitOpenKey, 1, AICircuitOpenDuration).Err(); err != nil {
			slog.Warn("labs: AI circuit breaker open failed", "error", err)
		}
	}
}

// recordAISuccess resets the consecutive-failure counter — only CONSECUTIVE
// failures within the window should ever trip the breaker.
func recordAISuccess(ctx context.Context, rdb redisClient) {
	if err := rdb.Del(ctx, aiCircuitFailureKey).Err(); err != nil {
		slog.Warn("labs: AI circuit breaker reset failed", "error", err)
	}
}

// RequestHint serves one Socratic hint for (sessionID, taskID), auto-
// advancing the level (1 -> 2 -> 3) each call:
//
//  1. IDOR + liveness (GetSession scopes to userID; requireSessionLive also
//     ticks the idle heartbeat, same as every other session-touching call).
//  2. Per-(session,task) rate limit collapses accidental double-submits
//     before any DB/AI work — the same role VerifyTask's own rate limit
//     plays, and the reason no row lock is needed around the read-then-
//     increment below (see this function's inline comments).
//  3. hints_used >= MaxHintsPerTask -> ErrMaxHintsReached (the 3rd hint
//     already given IS the max; the frontend keeps showing it — see
//     hint-drawer.tsx — this just refuses a 4th generation).
//  4. cache_key = sha256(session+task+level); a cache hit skips the AI call
//     entirely ("AI called once" — docs/labs.md "AI Integration").
//  5. On a miss: the shared circuit breaker gates the call; a real Claude
//     failure counts against it and returns ErrAIUnavailable WITHOUT
//     incrementing hints_used, so a flaky provider never burns a student's
//     hint budget for nothing.
//  6. Only once content exists (cache hit or a fresh, successfully stored
//     generation) does hints_used advance — matching the "attempts" counter
//     precedent (VerifyTask) of counting real, completed requests only.
func (s *Service) RequestHint(ctx context.Context, sessionID, taskID, userID, idemKey string) (*HintResult, error) {
	session, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}
	if err := s.requireSessionLive(ctx, session); err != nil {
		return nil, err
	}
	if session.Status != SessionStatusRunning && session.Status != SessionStatusPaused {
		return nil, ErrSessionNotRunning
	}

	// Client idempotency key: a replayed request (double-click, retry) returns
	// the original result instead of consuming another level. Checked before
	// the rate limit so a legitimate replay is never a 429.
	idemRedisKey := ""
	if idemKey != "" {
		sum := sha256.Sum256([]byte(idemKey))
		idemRedisKey = fmt.Sprintf("lab:hint:idem:%s:%s:%s", sessionID, taskID, hex.EncodeToString(sum[:]))
		if raw, gErr := s.rdb.Get(ctx, idemRedisKey).Result(); gErr == nil {
			var prior HintResult
			if json.Unmarshal([]byte(raw), &prior) == nil {
				return &prior, nil
			}
		}
	}

	rateLimitKey := fmt.Sprintf("lab:hint:rate:%s:%s", sessionID, taskID)
	if err := s.acquireCooldown(ctx, rateLimitKey, time.Duration(HintRateLimitSeconds)*time.Second, "labs.Service.RequestHint"); err != nil {
		return nil, err
	}

	tasks, err := s.repo.GetPublishedVersion(ctx, session.TaskVersionID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.RequestHint: get version: %w", err)
	}
	var task *TaskSnapshot
	for i := range tasks {
		if tasks[i].ID == taskID {
			task = &tasks[i]
			break
		}
	}
	if task == nil {
		return nil, ErrNotFound
	}
	if task.Grader == GraderWriteupReview {
		return nil, ErrHintNotSupported
	}

	if err := s.repo.EnsureTaskCompletion(ctx, sessionID, taskID); err != nil {
		return nil, fmt.Errorf("labs.Service.RequestHint: ensure completion: %w", err)
	}
	completions, err := s.repo.GetTaskCompletions(ctx, sessionID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.RequestHint: get completions: %w", err)
	}
	var hintsUsed, attempts int
	for _, c := range completions {
		if c.TaskID == taskID {
			hintsUsed = c.HintsUsed
			attempts = c.Attempts
			break
		}
	}
	if hintsUsed >= MaxHintsPerTask {
		return nil, ErrMaxHintsReached
	}

	lab, err := s.repo.GetLabForPlacement(ctx, session.LabID, session.OrgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.RequestHint: get lab: %w", err)
	}

	level := hintsUsed + 1
	cacheKey := hintCacheKey(sessionID, taskID, level)

	cached, err := s.repo.GetAIInteractionByCacheKey(ctx, cacheKey)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.RequestHint: cache lookup: %w", err)
	}

	var content string
	if cached != nil {
		content = cached.Response
	} else {
		extra, staticHint := s.buildHintExtra(ctx, session, lab, level)
		if staticHint != "" {
			// Authored level-1 hint: free, cannot leak, no AI call.
			content = staticHint
		} else {
			content, err = s.generateHint(ctx, task, level, attempts, sessionID, taskID, cacheKey, extra)
			if err != nil {
				return nil, err
			}
		}
	}

	newHintsUsed, err := s.repo.IncrementHintsUsed(ctx, sessionID, taskID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.RequestHint: increment hints_used: %w", err)
	}

	result := &HintResult{
		Level:          level,
		Content:        content,
		HintsUsed:      newHintsUsed,
		HintsRemaining: max(0, MaxHintsPerTask-newHintsUsed),
		HintPenaltyPct: lab.HintPenaltyPct,
	}
	if idemRedisKey != "" {
		if raw, mErr := json.Marshal(result); mErr == nil {
			if sErr := s.rdb.Set(ctx, idemRedisKey, raw, HintIdempotencyTTL).Err(); sErr != nil {
				slog.Warn("labs.Service.RequestHint: store idempotent result", "error", sErr)
			}
		}
	}
	return result, nil
}

// generateHint calls the AI provider (gated by the circuit breaker),
// persists the result via INSERT ... ON CONFLICT DO NOTHING, and re-reads
// the cache to return whichever row actually won — its own generation, or a
// concurrent request's that landed first on the same cache key.
func (s *Service) generateHint(ctx context.Context, task *TaskSnapshot, level, attempts int, sessionID, taskID, cacheKey string, extra hintExtra) (string, error) {
	if aiCircuitOpen(ctx, s.rdb) {
		return "", ErrAICircuitOpen
	}
	if s.aiProvider == nil || !s.aiProvider.Available() {
		return "", ErrAIUnavailable
	}

	userPrompt := buildHintUserPrompt(task, level, attempts)
	if extra.Context != "" {
		userPrompt += "\n" + extra.Context
	}
	complete := func() (ai.CompletionResponse, error) {
		return s.aiProvider.Complete(ctx, ai.CompletionRequest{
			SystemPrompt: hintSystemPrompt,
			UserPrompt:   userPrompt,
			MaxTokens:    300,
			Temperature:  0.4,
		})
	}
	resp, err := complete()
	if err != nil {
		recordAIFailure(ctx, s.rdb)
		slog.Error("labs.Service.generateHint: AI completion failed", "session_id", sessionID, "task_id", taskID, "level", level, "error", err)
		return "", ErrAIUnavailable
	}
	recordAISuccess(ctx, s.rdb)

	// Leak filter: output reproducing a reference-fix line is regenerated
	// once, then replaced by the authored fallback.
	if leaksFix(resp.Content, extra.LeakLines) {
		if retry, rErr := complete(); rErr == nil && !leaksFix(retry.Content, extra.LeakLines) {
			resp = retry
		} else {
			fallback := extra.Fallback
			if fallback == "" {
				fallback = "Re-read the failing check's output and trace the code path it exercises, one step at a time."
			}
			resp.Content = fallback
		}
	}

	content := strings.TrimSpace(resp.Content)
	hintLevel := level
	tokens := resp.Usage.InputTokens + resp.Usage.OutputTokens
	if err := s.repo.InsertAIInteraction(ctx, &LabAIInteraction{
		SessionID:       sessionID,
		TaskID:          &taskID,
		InteractionType: "hint",
		HintLevel:       &hintLevel,
		CacheKey:        &cacheKey,
		Prompt:          userPrompt,
		Response:        content,
		TokensUsed:      &tokens,
	}); err != nil {
		return "", fmt.Errorf("labs.Service.generateHint: store interaction: %w", err)
	}

	// Re-read rather than trusting the local `content`: a concurrent request
	// for the exact same cache key may have won the INSERT — reading back
	// guarantees every caller for this (session, task, level) converges on
	// the one persisted response, never two different hints for "level 2".
	winner, err := s.repo.GetAIInteractionByCacheKey(ctx, cacheKey)
	if err != nil {
		return "", fmt.Errorf("labs.Service.generateHint: re-read: %w", err)
	}
	if winner == nil {
		return "", fmt.Errorf("labs.Service.generateHint: cache key %s missing immediately after insert", cacheKey)
	}
	return winner.Response, nil
}
