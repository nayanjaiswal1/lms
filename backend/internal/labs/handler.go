package labs

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/mindforge/backend/internal/httputil"
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
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrForbidden):
		httputil.WriteError(w, http.StatusForbidden, "Forbidden.")
	case errors.Is(err, ErrSessionActive):
		// StartSession resolves this internally on the normal path (returns
		// the existing session instead of the error); reaching here means the
		// race-resolution lookup itself failed, so surface a real error
		// rather than a silent empty 200 the client would misread as "session
		// started".
		httputil.WriteError(w, http.StatusConflict, "A session for this lab is already active.")
	case errors.Is(err, ErrCapacityReached):
		httputil.WriteError(w, http.StatusTooManyRequests, "Lab capacity reached, try again shortly.")
	case errors.Is(err, ErrUserHasActiveSession):
		httputil.WriteError(w, http.StatusConflict, "You already have a lab running. End it before starting another.")
	case errors.Is(err, ErrSessionNotRunning):
		httputil.WriteError(w, http.StatusConflict, "Session is not running.")
	case errors.Is(err, ErrNoRunScript):
		httputil.WriteError(w, http.StatusBadRequest, "This lab has no run script.")
	case errors.Is(err, ErrSessionTerminal):
		httputil.WriteError(w, http.StatusConflict, "Session has already ended.")
	case errors.Is(err, ErrLabNotPublished):
		httputil.WriteError(w, http.StatusConflict, "Lab is not published.")
	case errors.Is(err, ErrMaxResetsReached):
		httputil.WriteError(w, http.StatusConflict, "Maximum resets reached.")
	case errors.Is(err, ErrTaskAlreadyPassed):
		// finalizeTaskPass already handles the common idempotent-retry case
		// inline (returns Passed:true with the cached attempt count); reaching
		// here is the rarer concurrent-duplicate-pass race. Still succeeded
		// from the caller's point of view — the task IS passed — so 200 with
		// an explicit shape rather than an empty object the client can't use.
		httputil.WriteJSON(w, http.StatusOK, map[string]any{"passed": true})
	case errors.Is(err, ErrMaxHintsReached):
		httputil.WriteError(w, http.StatusTooManyRequests, "Maximum hints reached for this task.")
	case errors.Is(err, ErrTaskNotOptional):
		httputil.WriteError(w, http.StatusConflict, "Task cannot be skipped.")
	case errors.Is(err, ErrRateLimited):
		httputil.WriteError(w, http.StatusTooManyRequests, "Verify too soon — wait a moment.")
	case errors.Is(err, ErrExecutorUnavailable):
		httputil.WriteError(w, http.StatusServiceUnavailable, "Code executor is not configured on this server.")
	case errors.Is(err, ErrInvalidPath):
		httputil.WriteError(w, http.StatusBadRequest, "Invalid file path.")
	case errors.Is(err, ErrImageNotAllowed):
		httputil.WriteError(w, http.StatusForbidden, "This lab is not available for your organization.")
	case errors.Is(err, ErrLabProvisioningUnstable):
		httputil.WriteError(w, http.StatusServiceUnavailable, "This lab is temporarily unavailable — it has failed to start repeatedly. Our team has been notified.")
	case errors.Is(err, ErrSessionExpired):
		httputil.WriteError(w, http.StatusConflict, "This lab session has expired.")
	case errors.Is(err, ErrResetFailed):
		httputil.WriteError(w, http.StatusInternalServerError, "Could not reset this lab — the session has been ended. Please start a new one.")
	case errors.Is(err, ErrLabTypeUnsupported):
		httputil.WriteError(w, http.StatusConflict, "This action is not available for this lab type.")
	case errors.Is(err, ErrContentTooLarge):
		httputil.WriteError(w, http.StatusRequestEntityTooLarge, "File is too large.")
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong. Please try again.")
	}
}

// decodeJSON deserialises the request body into dst, writing 400 on failure.
func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}
