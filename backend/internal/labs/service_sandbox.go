package labs

import (
	"context"
	"fmt"
	"log/slog"
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
	set, rErr := s.rdb.SetNX(ctx, rateLimitKey, 1, runRateLimitSeconds*time.Second).Result()
	if rErr != nil {
		slog.Error("labs.Service.RunScript: rate limit check", "error", rErr)
	} else if !set {
		return nil, ErrRateLimited
	}

	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}
	lab, err := s.repo.GetLab(ctx, session.LabID, session.OrgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.RunScript: get lab: %w", err)
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
	set, rErr := s.rdb.SetNX(ctx, rateLimitKey, 1, submitRateLimitSeconds*time.Second).Result()
	if rErr != nil {
		slog.Error("labs.Service.SubmitAll: rate limit check", "error", rErr)
	} else if !set {
		return nil, ErrRateLimited
	}

	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}
	lab, err := s.repo.GetLab(ctx, session.LabID, session.OrgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.SubmitAll: get lab: %w", err)
	}
	// Code labs verify per task with the student's editor code — a batch
	// submit has no code to run, so the endpoint does not exist for them.
	if lab.LabType == LabTypeCode {
		return nil, ErrNotFound
	}

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

	results := make([]SubmitTaskResult, 0, len(tasks))
	completed := session.Status == SessionStatusCompleted
	for i := range tasks {
		task := &tasks[i]
		if alreadyPassed[task.ID] {
			results = append(results, SubmitTaskResult{TaskID: task.ID, Passed: true})
			continue
		}

		attempts, err := s.bumpTaskAttempt(ctx, session.ID, task.ID)
		if err != nil {
			return nil, fmt.Errorf("labs.Service.SubmitAll: %w", err)
		}
		result, err := s.verifyContainerTask(ctx, session, lab, tasks, task, attempts)
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
