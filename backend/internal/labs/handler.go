package labs

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/ratelimit"
)

// Handler exposes the labs domain over HTTP.
type Handler struct {
	repo      *Repo
	service   *Service
	pool      *pgxpool.Pool
	rdb       *redis.Client
	jwtSecret string
	jwtIssuer string
	piston    *labPiston
}

// Service exposes the wired *Service so other domains can reuse it instead
// of building a second one — library.Service's "try" endpoint reuses this to
// call StartSession with is_test=true, the same path an instructor's own
// "test my lab" button already goes through.
func (h *Handler) Service() *Service { return h.service }

// Repo exposes the wired *Repo so other domains needing read access to labs
// (library.Service's Attach eligibility check, list/preview) reuse the same
// stateless query surface instead of duplicating SQL.
func (h *Handler) Repo() *Repo { return h.repo }

// NewHandler builds the labs HTTP handler from wired dependencies.
func NewHandler(repo *Repo, service *Service, pool *pgxpool.Pool, rdb *redis.Client, jwtSecret, jwtIssuer string, piston *labPiston) *Handler {
	return &Handler{
		repo:      repo,
		service:   service,
		pool:      pool,
		rdb:       rdb,
		jwtSecret: jwtSecret,
		jwtIssuer: jwtIssuer,
		piston:    piston,
	}
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

// writeDomainError maps labs domain errors to appropriate HTTP responses.
func writeDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteErrorCode(w, http.StatusNotFound, CodeNotFound, "Not found.")
	case errors.Is(err, ErrForbidden):
		httputil.WriteErrorCode(w, http.StatusForbidden, CodeForbidden, "Forbidden.")
	case errors.Is(err, ErrSessionActive):
		// StartSession resolves this internally on the normal path (returns
		// the existing session instead of the error); reaching here means the
		// race-resolution lookup itself failed, so surface a real error
		// rather than a silent empty 200 the client would misread as "session
		// started".
		httputil.WriteErrorCode(w, http.StatusConflict, CodeSessionActive, "A session for this lab is already active.")
	case errors.Is(err, ErrCapacityReached):
		httputil.WriteErrorCode(w, http.StatusTooManyRequests, CodeCapacityReached, "Lab capacity reached, try again shortly.")
	case errors.Is(err, ErrUserHasActiveSession):
		httputil.WriteErrorCode(w, http.StatusConflict, CodeUserHasActiveSession, "You already have a lab running. End it before starting another.")
	case errors.Is(err, ErrSessionNotRunning):
		httputil.WriteErrorCode(w, http.StatusConflict, CodeSessionNotRunning, "Session is not running.")
	case errors.Is(err, ErrNoRunScript):
		httputil.WriteErrorCode(w, http.StatusBadRequest, CodeNoRunScript, "This lab has no run script.")
	case errors.Is(err, ErrSessionTerminal):
		httputil.WriteErrorCode(w, http.StatusConflict, CodeSessionAlreadyEnded, "Session has already ended.")
	case errors.Is(err, ErrLabNotPublished):
		httputil.WriteErrorCode(w, http.StatusConflict, CodeLabNotPublished, "Lab is not published.")
	case errors.Is(err, ErrMaxResetsReached):
		httputil.WriteErrorCode(w, http.StatusConflict, CodeMaxResetsReached, "Maximum resets reached.")
	case errors.Is(err, ErrTaskAlreadyPassed):
		// finalizeTaskPass already handles the common idempotent-retry case
		// inline (returns Passed:true with the cached attempt count); reaching
		// here is the rarer concurrent-duplicate-pass race. Still succeeded
		// from the caller's point of view — the task IS passed — so 200 with
		// an explicit shape rather than an empty object the client can't use.
		httputil.WriteJSON(w, http.StatusOK, map[string]any{"passed": true})
	case errors.Is(err, ErrMaxHintsReached):
		httputil.WriteErrorCode(w, http.StatusTooManyRequests, CodeMaxHintsReached, "Maximum hints reached for this task.")
	case errors.Is(err, ErrTaskNotOptional):
		httputil.WriteErrorCode(w, http.StatusConflict, CodeTaskNotOptional, "Task cannot be skipped.")
	case errors.Is(err, ErrRateLimited):
		var limited *RateLimitedError
		if errors.As(err, &limited) {
			w.Header().Set("Retry-After", strconv.Itoa(ratelimit.RetryAfterSeconds(limited.RetryAfter)))
		}
		httputil.WriteErrorCode(w, http.StatusTooManyRequests, CodeRateLimited, "Too many requests — wait a moment.")
	case errors.Is(err, ErrExecutorUnavailable):
		httputil.WriteErrorCode(w, http.StatusServiceUnavailable, CodeExecutorUnavailable, "Code executor is not configured on this server.")
	case errors.Is(err, ErrInvalidPath):
		httputil.WriteErrorCode(w, http.StatusBadRequest, CodeInvalidPath, "Invalid file path.")
	case errors.Is(err, ErrImageNotAllowed):
		httputil.WriteErrorCode(w, http.StatusForbidden, CodeImageNotAllowed, "This lab is not available for your organization.")
	case errors.Is(err, ErrLabProvisioningUnstable):
		httputil.WriteErrorCode(w, http.StatusServiceUnavailable, CodeProvisioningUnstable, "This lab is temporarily unavailable — it has failed to start repeatedly. Our team has been notified.")
	case errors.Is(err, ErrSessionCompletedAtDeadline):
		// 409 like the expired case (the session resource still exists — 410 Gone
		// would misstate that); the code is what tells the client the lab succeeded.
		httputil.WriteErrorCode(w, http.StatusConflict, CodeSessionCompletedAtDeadline, "Time's up — your lab was completed.")
	case errors.Is(err, ErrSessionExpired):
		httputil.WriteErrorCode(w, http.StatusConflict, CodeSessionExpired, "This lab session has expired.")
	case errors.Is(err, ErrResetFailed):
		httputil.WriteErrorCode(w, http.StatusInternalServerError, CodeResetFailed, "Could not reset this lab — the session has been ended. Please start a new one.")
	case errors.Is(err, ErrLabTypeUnsupported):
		httputil.WriteErrorCode(w, http.StatusConflict, CodeLabTypeUnsupported, "This action is not available for this lab type.")
	case errors.Is(err, ErrContentTooLarge):
		httputil.WriteErrorCode(w, http.StatusRequestEntityTooLarge, CodeContentTooLarge, "File is too large.")
	case errors.Is(err, ErrAICircuitOpen):
		httputil.WriteErrorCode(w, http.StatusServiceUnavailable, CodeAIUnavailable, "AI hints are temporarily unavailable — try again in a couple of minutes.")
	case errors.Is(err, ErrAIUnavailable):
		httputil.WriteErrorCode(w, http.StatusServiceUnavailable, CodeAIUnavailable, "AI hints are not available right now.")
	case errors.Is(err, ErrKindLabNotBuilt):
		httputil.WriteErrorCode(w, http.StatusConflict, CodeKindLabNotBuilt, "This lab has no runnable build yet.")
	case errors.Is(err, ErrBundleStoreUnavailable):
		httputil.WriteErrorCode(w, http.StatusServiceUnavailable, CodeBundleStoreUnavailable, "Lab content storage is not available right now.")
	case errors.Is(err, ErrGradeBusy):
		httputil.WriteErrorCode(w, http.StatusServiceUnavailable, CodeGraderBusy, "The grader is busy — try again in a few seconds.")
	case errors.Is(err, ErrMaxWriteupReviewsReached):
		httputil.WriteErrorCode(w, http.StatusTooManyRequests, CodeWriteupReviewLimit, "Maximum write-up reviews reached for this session.")
	case errors.Is(err, ErrHintNotSupported):
		httputil.WriteErrorCode(w, http.StatusUnprocessableEntity, CodeHintNotSupported, "Hints are not available for this task.")
	case errors.Is(err, ErrNoDebrief):
		httputil.WriteErrorCode(w, http.StatusConflict, CodeNoDebrief, "The debrief is available once the lab is completed.")
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong. Please try again.")
	}
}

// decodeJSON deserialises the request body into dst, writing 400 on failure.
