package labs

import (
	"context"
	"fmt"
	"log/slog"
	"slices"
	"time"
)

// ─── Sandbox Run / Submit (HackerEarth-style) ────────────────────────────────
//
// Sandbox labs replace the per-task "Check" button with two workspace-level
// actions: Run executes the instructor-authored, student-visible run_script
// (sample tests — unlimited, never scored) and Submit runs every task's
// hidden verification_script in one batch through the same scoring and
// completion pipeline single-task verify uses.

const (
	runRateLimitSeconds    = 3
	submitRateLimitSeconds = 10
	runScriptTimeoutSec    = 30
	// maxSubmitAllDuration hard-bounds one SubmitAll request. Each task's own
	// verifyContainerTask exec is independently capped at 10s by the
	// `timeout 10` wrapper inside ContainerRuntime.Exec, but that guards each
	// docker/kubectl exec call, not the request as a whole — without an
	// aggregate deadline a lab with many tasks (or a daemon-level hang that
	// exec's own in-container `timeout` can't reach) ties up the request
	// goroutine for an unbounded time.
	maxSubmitAllDuration = 5 * time.Minute
)

// RunScriptResult is the response body for POST /sessions/:id/run.
type RunScriptResult struct {
	ExitCode int    `json:"exit_code"`
	Stdout   string `json:"stdout"`
	Stderr   string `json:"stderr"`
}

// SubmitTaskResult is one task's outcome inside a SubmitResult. Stdout and
// Stderr carry the failure output as hint context, mirroring the single-task
// verify response (verification scripts echo their hints to stdout). Empty
// on pass.
type SubmitTaskResult struct {
	TaskID string `json:"task_id"`
	Passed bool   `json:"passed"`
	Stdout string `json:"stdout,omitempty"`
	Stderr string `json:"stderr,omitempty"`
}

// SubmitResult is the response body for POST /sessions/:id/submit.
type SubmitResult struct {
	Results          []SubmitTaskResult `json:"results"`
	Score            int                `json:"score"`
	SessionCompleted bool               `json:"session_completed"`
}

// RunScript executes the lab's run_script inside the session container and
// returns its raw output. No attempts tracking, no scoring, no DB writes —
// sample tests are feedback, not grading.
func (s *Service) RunScript(ctx context.Context, sessionID, userID string) (*RunScriptResult, error) {
	// Rate limit before touching the container. Fail open on Redis errors
	// (same policy as VerifyTask / RunSnippet).
	rateLimitKey := fmt.Sprintf("lab:run:rate:%s", sessionID)
	if err := s.acquireCooldown(ctx, rateLimitKey, runRateLimitSeconds*time.Second, "labs.Service.RunScript"); err != nil {
		return nil, fmt.Errorf("labs.RunScript: %w", err)
	}

	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return nil, fmt.Errorf("labs.RunScript: %w", err)
	}
	lab, err := s.repo.GetLab(ctx, session.LabID, session.OrgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.RunScript: get lab: %w", err)
	}
	// Run/Submit are sandbox-workspace-only actions (docs/labs.md: "playground
	// labs also render the IDE shell, just with no Run/Submit"; terminal/
	// guided use the per-task Check flow instead). Checking lab_type
	// explicitly here — rather than relying on ErrNoRunScript's nil check
	// alone — means a terminal/guided lab can never expose this endpoint even
	// if a run_script were somehow set on it, and gives a correct 409 instead
	// of piggybacking on "no run script configured".
	if lab.LabType != LabTypeSandbox {
		return nil, ErrLabTypeUnsupported
	}
	if lab.RunScript == nil || *lab.RunScript == "" {
		return nil, ErrNoRunScript
	}

	stdout, stderr, exitCode, err := s.container.Exec(ctx, *session.ContainerID, *lab.RunScript, runScriptTimeoutSec)
	if err != nil {
		slog.Error("labs.Service.RunScript: exec", "session", session.ID, "error", err)
		return &RunScriptResult{ExitCode: 1, Stderr: "Run failed. Please try again."}, nil
	}
	return &RunScriptResult{ExitCode: exitCode, Stdout: stdout, Stderr: stderr}, nil
}

// SubmitAll runs every task's hidden verification script in snapshot order
// through the same attempt/score/completion pipeline as single-task verify.
// Already-passed tasks are reported passed without re-running (verification
// is idempotent per task, matching finalizeTaskPass's ErrTaskAlreadyPassed
// handling). Session completion — including course-module unlock — happens
// inside finalizeTaskPass exactly as it does for per-task Check.
func (s *Service) SubmitAll(ctx context.Context, sessionID, userID string) (*SubmitResult, error) {
	rateLimitKey := fmt.Sprintf("lab:submit:rate:%s", sessionID)
	if err := s.acquireCooldown(ctx, rateLimitKey, submitRateLimitSeconds*time.Second, "labs.Service.SubmitAll"); err != nil {
		return nil, fmt.Errorf("labs.SubmitAll: %w", err)
	}

	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return nil, fmt.Errorf("labs.SubmitAll: %w", err)
	}
	lab, err := s.repo.GetLab(ctx, session.LabID, session.OrgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.SubmitAll: get lab: %w", err)
	}
	// Run/Submit are sandbox-workspace-only actions — see RunScript's doc
	// comment. This used to only exclude LabTypeCode, which meant a
	// terminal/guided lab could reach this endpoint and batch-run every
	// task's verification script through a single 10s rate limit, bypassing
	// the per-task 3s VerifyRateLimitSeconds those lab types are meant to
	// use.
	kind, isKind := kindFor(lab)
	if lab.LabType != LabTypeSandbox && !isKind {
		return nil, ErrLabTypeUnsupported
	}

	// Bounds the whole batch, not just each task's own exec — see
	// maxSubmitAllDuration's doc comment.
	// A client disconnect must not abandon a half-graded Check (grading and
	// score persistence run to completion); the deadline still bounds it.
	ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), maxSubmitAllDuration)
	defer cancel()

	tasks, err := s.repo.GetPublishedVersion(ctx, session.TaskVersionID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.SubmitAll: get version: %w", err)
	}

	completions, err := s.repo.GetTaskCompletions(ctx, session.ID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.SubmitAll: get completions: %w", err)
	}
	alreadyPassed := map[string]bool{}
	for _, c := range completions {
		if c.Status == TaskStatusPassed {
			alreadyPassed[c.TaskID] = true
		}
	}

	// Lab kinds: one clean-room sandbox grades every pending script task in
	// this Check (one start, one cooldown), instead of one sandbox per task.
	var kindResults map[string]*GradeResult
	if isKind {
		var modes []string
		for i := range tasks {
			t := &tasks[i]
			if alreadyPassed[t.ID] || t.Grader == GraderWriteupReview {
				continue
			}
			mode, err := kindTaskMode(kind, t)
			if err != nil {
				return nil, fmt.Errorf("labs.Service.SubmitAll: %w", err)
			}
			if !slices.Contains(modes, mode) {
				modes = append(modes, mode)
			}
		}
		if len(modes) > 0 {
			if err := s.acquireGradeCooldown(ctx, session.ID); err != nil {
				return nil, fmt.Errorf("labs.SubmitAll: %w", err)
			}
			var err error
			if kindResults, err = s.gradeKindModes(ctx, session, lab, modes); err != nil {
				s.releaseGradeCooldown(ctx, session.ID)
				return nil, fmt.Errorf("labs.SubmitAll: %w", err)
			}
		}
	}

	results := make([]SubmitTaskResult, 0, len(tasks))
	completed := session.Status == SessionStatusCompleted
	for i := range tasks {
		task := &tasks[i]
		if alreadyPassed[task.ID] {
			results = append(results, SubmitTaskResult{TaskID: task.ID, Passed: true})
			continue
		}
		// writeup_review tasks are completed only via the writeup-review
		// endpoint, never by a Check.
		if isKind && task.Grader == GraderWriteupReview {
			continue
		}

		attempts, err := s.bumpTaskAttempt(ctx, session.ID, task.ID)
		if err != nil {
			return nil, fmt.Errorf("labs.Service.SubmitAll: %w", err)
		}
		var result *VerifyResult
		if isKind {
			mode, _ := kindTaskMode(kind, task)
			result, err = s.applyKindResult(ctx, session, lab, tasks, task, attempts, kindResults[mode])
		} else {
			result, err = s.verifyContainerTask(ctx, session, lab, tasks, task, attempts)
		}
		if err != nil {
			return nil, fmt.Errorf("labs.Service.SubmitAll: task %s: %w", task.ID, err)
		}
		taskResult := SubmitTaskResult{TaskID: task.ID, Passed: result.Passed}
		if !result.Passed {
			taskResult.Stdout = result.Stdout
			taskResult.Stderr = result.Stderr
		}
		results = append(results, taskResult)

		// finalizeTaskPass computes the completion-time score from the
		// in-memory session.Score — keep it current across the batch so a
		// later task completing the session doesn't clobber earlier points.
		if result.Passed {
			session.Score += result.ScoreAdded
		}
		if result.SessionCompleted {
			completed = true
		}
	}

	return &SubmitResult{Results: results, Score: session.Score, SessionCompleted: completed}, nil
}
