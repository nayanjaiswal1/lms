package labs

import (
	"errors"
	"time"
)

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

	// ErrUserHasActiveSession is returned when a user tries to start a session
	// for a lab while a session for a *different* lab is still active. A user
	// may only have one lab running at a time; starting the same lab again
	// resumes the existing session instead of hitting this error.
	ErrUserHasActiveSession = errors.New("labs: user already has a different lab session active")

	// ErrSessionNotRunning is returned when an action (verify, hint, etc.)
	// requires the session to be in the running state.
	ErrSessionNotRunning = errors.New("labs: session is not running")

	// ErrSessionTerminal is returned when an action is attempted on a session
	// that is in a terminal state (completed, expired, failed, terminated_abuse).
	ErrSessionTerminal = errors.New("labs: session is in a terminal state")

	// ErrSessionExpired is returned when a session's hard expires_at deadline
	// has passed but the reaper has not closed it out yet. Checked at request
	// time by every session-touching path so the wall-clock cap is real,
	// rather than "real within one cron tick".
	ErrSessionExpired = errors.New("labs: session has passed its expiry deadline")

	// ErrPauseUnsupported is returned by a ContainerRuntime whose backing
	// technology has no pause primitive (Kubernetes Pods). Callers treat it
	// as "leave the sandbox running", never as a failure.
	ErrPauseUnsupported = errors.New("labs: this runtime cannot pause sandboxes")

	// ErrResetFailed is returned when a staged reset could not bring up a
	// replacement container. The session is closed out rather than left
	// pointing at a container that no longer exists.
	ErrResetFailed = errors.New("labs: could not provision a replacement container for this reset")

	// ErrLabTypeUnsupported is returned when an endpoint is called for a lab
	// type it does not apply to (e.g. /run or /submit on a code lab, which
	// grades per task through the editor instead).
	ErrLabTypeUnsupported = errors.New("labs: this action does not apply to this lab type")

	// ErrContentTooLarge is returned when a file write exceeds
	// MaxWriteFileBytes.
	ErrContentTooLarge = errors.New("labs: file content is too large")

	// ErrNoRunScript is returned when POST /sessions/:id/run is called for a
	// lab that has no run_script authored.
	ErrNoRunScript = errors.New("labs: lab has no run script")

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

	// ErrInvalidPath is returned when a file-ops request path is empty,
	// absolute, or attempts to traverse outside the lab container's workdir.
	ErrInvalidPath = errors.New("labs: invalid file path")

	// ErrImageNotAllowed is returned when a lab's environment image is not in
	// the requesting org's lab_org_config.allowed_images. An image whose
	// ImageProfile.RequiresOrgAllowlist is true (see ContainerRuntime.
	// Classify — nested-Docker images today) is NEVER a platform default and
	// always requires an explicit allowlist entry, even for an org whose
	// allowed_images is otherwise empty (empty historically meant "no
	// restriction" for ordinary images — it must not also mean "elevated
	// images allowed").
	ErrImageNotAllowed = errors.New("labs: this lab's environment image is not allowed for your organization")

	// ErrLabProvisioningUnstable is returned when a lab has failed to
	// provision ProvisionFailureCircuitBreakerThreshold times within
	// ProvisionFailureCircuitBreakerWindow — a broken image or setup_script
	// otherwise lets every retry burn another doomed container on the Docker
	// host ("bombing" it) until an instructor fixes the lab. StartSession
	// refuses new sessions for the lab until the window rolls off.
	ErrLabProvisioningUnstable = errors.New("labs: lab has failed to provision repeatedly and is temporarily unavailable")

	// ErrAICircuitOpen is returned by any AI endpoint (currently: hints)
	// while the shared Redis-backed circuit breaker is open — see
	// AICircuitFailureThreshold's doc comment and docs/labs.md "Runaway AI
	// retry storms".
	ErrAICircuitOpen = errors.New("labs: AI circuit breaker is open")

	// ErrAIUnavailable is returned when the configured ai.LLMProvider is not
	// available (LLM_PROVIDER=disabled or missing API key) or a single
	// completion call failed. Hints degrade to a clear error rather than a
	// silently empty response.
	ErrAIUnavailable = errors.New("labs: AI hint generation is unavailable")

	// ErrPlanQuotaExceeded is returned when an individual account (see
	// entitlements.Service.ResolveAccount) is at its pricing tier's
	// lab_sessions_concurrent or lab_hours limit. Org accounts are unaffected
	// — see docs/entitlements.md §1.1, lab quotas are an individual-plan
	// concept only, orgs keep their existing org_lab_config caps.
	ErrPlanQuotaExceeded = errors.New("labs: individual plan lab quota exceeded")

	// ErrBundleStoreUnavailable is returned when a lab-kind session needs a
	// bundle but no private object store is configured (MinIO unset).
	ErrBundleStoreUnavailable = errors.New("labs: bundle store is not configured")

	// ErrBundleCorrupt is returned when a downloaded bundle's sha256 does not
	// match the value recorded in lab_build_variants.
	ErrBundleCorrupt = errors.New("labs: bundle failed sha256 verification")

	// ErrKindLabNotBuilt is returned when a lab whose lab_type has a
	// registered kind has no build/variants to run.
	ErrKindLabNotBuilt = errors.New("labs: lab has no verified build variants")

	// ErrGradeBusy is returned when the clean-room grader is at capacity.
	ErrGradeBusy = errors.New("labs: grader is busy, try again shortly")

	// ErrMaxWriteupReviewsReached is returned past MaxWriteupReviewsPerSession.
	ErrMaxWriteupReviewsReached = errors.New("labs: maximum write-up reviews for this session reached")

	// ErrNoDebrief is returned when a debrief is requested before completion.
	ErrNoDebrief = errors.New("labs: debrief is only available once the session is completed")
)

// RateLimitedError is ErrRateLimited plus how long until the caller may
// retry, read from the limiter key's remaining TTL. writeDomainError turns it
// into a Retry-After header. errors.Is(err, ErrRateLimited) still holds.
type RateLimitedError struct {
	RetryAfter time.Duration
}

func (e *RateLimitedError) Error() string { return ErrRateLimited.Error() }
func (e *RateLimitedError) Unwrap() error { return ErrRateLimited }

// ErrHintNotSupported is returned when a hint is requested for a task graded
// by a written review (grader=writeup_review): there is nothing to hint at.
var ErrHintNotSupported = errors.New("labs: hints are not available for this task")

// ErrSessionCompletedAtDeadline is returned instead of ErrSessionExpired when a
// request notices the hard deadline and the session closed as 'completed'
// (its required tasks had passed under CompleteOnFinish). The lab succeeded;
// only the time is up, so clients route to the result/debrief page.
var ErrSessionCompletedAtDeadline = errors.New("labs: session completed at its deadline")
