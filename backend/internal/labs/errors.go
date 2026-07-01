package labs

import "errors"

var (
	// ErrNotFound is returned when a lab, session, or task does not exist or is
	// not visible to the caller's org.
	ErrNotFound = errors.New("labs: not found")

	// ErrForbidden is returned when the caller does not own the requested session.
	ErrForbidden = errors.New("labs: forbidden")

	// ErrSessionActive is returned when a user already has an active
	// (provisioning, running, or paused) session for the requested lab.
	ErrSessionActive = errors.New("labs: user already has an active session for this lab")

	// ErrCapacityReached is returned when the org's max_concurrent_sessions cap
	// has been reached and no new session can be provisioned.
	ErrCapacityReached = errors.New("labs: org concurrent session capacity reached")

	// ErrSessionNotRunning is returned when an action (verify, hint, etc.)
	// requires the session to be in the running state.
	ErrSessionNotRunning = errors.New("labs: session is not running")

	// ErrSessionTerminal is returned when an action is attempted on a session
	// that is in a terminal state (completed, expired, failed, terminated_abuse).
	ErrSessionTerminal = errors.New("labs: session is in a terminal state")

	// ErrLabNotPublished is returned when a student tries to start a session for
	// a lab that has no published version.
	ErrLabNotPublished = errors.New("labs: lab has no published version")

	// ErrMaxResetsReached is returned when reset_count has reached the lab's
	// max_resets limit.
	ErrMaxResetsReached = errors.New("labs: maximum number of resets reached")

	// ErrTaskAlreadyPassed is returned when verify is called on a task that the
	// session has already passed.
	ErrTaskAlreadyPassed = errors.New("labs: task has already been passed")

	// ErrMaxHintsReached is returned when hints_used has reached MaxHintsPerTask
	// for the given task completion record.
	ErrMaxHintsReached = errors.New("labs: maximum hints per task reached")

	// ErrTaskNotOptional is returned when skip is called on a task that is not
	// marked is_optional.
	ErrTaskNotOptional = errors.New("labs: task is not optional and cannot be skipped")

	// ErrRateLimited is returned when verify is called within VerifyRateLimitSeconds
	// of the previous attempt on the same task.
	ErrRateLimited = errors.New("labs: verification rate limit exceeded")

	// ErrExecutorUnavailable is returned when the Piston code runner is not
	// configured (PISTON_URL not set in env). Verify degrades gracefully — the
	// endpoint returns 503 so the frontend can show a clear message.
	ErrExecutorUnavailable = errors.New("labs: code executor not configured")
)
