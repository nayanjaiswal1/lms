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

// domainErrors maps labs domain errors to HTTP responses.
var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound: {Status: http.StatusNotFound, Code: CodeNotFound, Message: "Not found."},
	ErrForbidden: {Status: http.StatusForbidden, Code: CodeForbidden, Message: "Forbidden."},
	ErrSessionActive: {Status: http.StatusConflict, Code: CodeSessionActive, Message: "A session for this lab is already active."},
	ErrCapacityReached: {Status: http.StatusTooManyRequests, Code: CodeCapacityReached, Message: "Lab capacity reached, try again shortly."},
	ErrUserHasActiveSession: {Status: http.StatusConflict, Code: CodeUserHasActiveSession, Message: "You already have a lab running. End it before starting another."},
	ErrSessionNotRunning: {Status: http.StatusConflict, Code: CodeSessionNotRunning, Message: "Session is not running."},
	ErrNoRunScript: {Status: http.StatusBadRequest, Code: CodeNoRunScript, Message: "This lab has no run script."},
	ErrSessionTerminal: {Status: http.StatusConflict, Code: CodeSessionAlreadyEnded, Message: "Session has already ended."},
	ErrLabNotPublished: {Status: http.StatusConflict, Code: CodeLabNotPublished, Message: "Lab is not published."},
	ErrMaxResetsReached: {Status: http.StatusConflict, Code: CodeMaxResetsReached, Message: "Maximum resets reached."},
	ErrMaxHintsReached: {Status: http.StatusTooManyRequests, Code: CodeMaxHintsReached, Message: "Maximum hints reached for this task."},
	ErrTaskNotOptional: {Status: http.StatusConflict, Code: CodeTaskNotOptional, Message: "Task cannot be skipped."},
	ErrExecutorUnavailable: {Status: http.StatusServiceUnavailable, Code: CodeExecutorUnavailable, Message: "Code executor is not configured on this server."},
	ErrInvalidPath: {Status: http.StatusBadRequest, Code: CodeInvalidPath, Message: "Invalid file path."},
	ErrImageNotAllowed: {Status: http.StatusForbidden, Code: CodeImageNotAllowed, Message: "This lab is not available for your organization."},
	ErrLabProvisioningUnstable: {Status: http.StatusServiceUnavailable, Code: CodeProvisioningUnstable, Message: "This lab is temporarily unavailable — it has failed to start repeatedly. Our team has been notified."},
	ErrSessionCompletedAtDeadline: {Status: http.StatusConflict, Code: CodeSessionCompletedAtDeadline, Message: "Time's up — your lab was completed."},
	ErrSessionExpired: {Status: http.StatusConflict, Code: CodeSessionExpired, Message: "This lab session has expired."},
	ErrResetFailed: {Status: http.StatusInternalServerError, Code: CodeResetFailed, Message: "Could not reset this lab — the session has been ended. Please start a new one."},
	ErrLabTypeUnsupported: {Status: http.StatusConflict, Code: CodeLabTypeUnsupported, Message: "This action is not available for this lab type."},
	ErrContentTooLarge: {Status: http.StatusRequestEntityTooLarge, Code: CodeContentTooLarge, Message: "File is too large."},
	ErrAICircuitOpen: {Status: http.StatusServiceUnavailable, Code: CodeAIUnavailable, Message: "AI hints are temporarily unavailable — try again in a couple of minutes."},
	ErrAIUnavailable: {Status: http.StatusServiceUnavailable, Code: CodeAIUnavailable, Message: "AI hints are not available right now."},
	ErrKindLabNotBuilt: {Status: http.StatusConflict, Code: CodeKindLabNotBuilt, Message: "This lab has no runnable build yet."},
	ErrBundleStoreUnavailable: {Status: http.StatusServiceUnavailable, Code: CodeBundleStoreUnavailable, Message: "Lab content storage is not available right now."},
	ErrGradeBusy: {Status: http.StatusServiceUnavailable, Code: CodeGraderBusy, Message: "The grader is busy — try again in a few seconds."},
	ErrMaxWriteupReviewsReached: {Status: http.StatusTooManyRequests, Code: CodeWriteupReviewLimit, Message: "Maximum write-up reviews reached for this session."},
	ErrHintNotSupported: {Status: http.StatusUnprocessableEntity, Code: CodeHintNotSupported, Message: "Hints are not available for this task."},
	ErrNoDebrief: {Status: http.StatusConflict, Code: CodeNoDebrief, Message: "The debrief is available once the lab is completed."},
}

var writeDomainError = httputil.DomainErrorWriter(domainErrors, "Something went wrong. Please try again.",
	// finalizeTaskPass already handles the common idempotent-retry case
	// inline (returns Passed:true with the cached attempt count); reaching
	// here is the rarer concurrent-duplicate-pass race. Still succeeded
	// from the caller's point of view — the task IS passed — so 200 with
	// an explicit shape rather than an empty object the client can't use.
	func(w http.ResponseWriter, err error) bool {
		if !errors.Is(err, ErrTaskAlreadyPassed) {
			return false
		}
		httputil.WriteJSON(w, http.StatusOK, map[string]any{"passed": true})
		return true
	},
	func(w http.ResponseWriter, err error) bool {
		if !errors.Is(err, ErrRateLimited) {
			return false
		}
		var limited *RateLimitedError
		if errors.As(err, &limited) {
			w.Header().Set("Retry-After", strconv.Itoa(ratelimit.RetryAfterSeconds(limited.RetryAfter)))
		}
		httputil.WriteErrorCode(w, http.StatusTooManyRequests, CodeRateLimited, "Too many requests — wait a moment.")
		return true
	},
)

// decodeJSON deserialises the request body into dst, writing 400 on failure.
