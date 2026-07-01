package labs

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/mindforge/backend/internal/auth"
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

// ctxClaims extracts the authenticated claims or writes 401 and returns false.
func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

// writeDomainError maps labs domain errors to appropriate HTTP responses.
func writeDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrForbidden):
		httputil.WriteError(w, http.StatusForbidden, "Forbidden.")
	case errors.Is(err, ErrSessionActive):
		// Resolved internally by StartSession; this branch is a safety net.
		httputil.WriteJSON(w, http.StatusOK, map[string]any{})
	case errors.Is(err, ErrCapacityReached):
		httputil.WriteError(w, http.StatusTooManyRequests, "Lab capacity reached, try again shortly.")
	case errors.Is(err, ErrSessionNotRunning):
		httputil.WriteError(w, http.StatusConflict, "Session is not running.")
	case errors.Is(err, ErrSessionTerminal):
		httputil.WriteError(w, http.StatusConflict, "Session has already ended.")
	case errors.Is(err, ErrLabNotPublished):
		httputil.WriteError(w, http.StatusConflict, "Lab is not published.")
	case errors.Is(err, ErrMaxResetsReached):
		httputil.WriteError(w, http.StatusConflict, "Maximum resets reached.")
	case errors.Is(err, ErrTaskAlreadyPassed):
		// Idempotent — the handler returns the cached result; this is a safety net.
		httputil.WriteJSON(w, http.StatusOK, map[string]any{})
	case errors.Is(err, ErrMaxHintsReached):
		httputil.WriteError(w, http.StatusTooManyRequests, "Maximum hints reached for this task.")
	case errors.Is(err, ErrTaskNotOptional):
		httputil.WriteError(w, http.StatusConflict, "Task cannot be skipped.")
	case errors.Is(err, ErrRateLimited):
		httputil.WriteError(w, http.StatusTooManyRequests, "Verify too soon — wait a moment.")
	case errors.Is(err, ErrExecutorUnavailable):
		httputil.WriteError(w, http.StatusServiceUnavailable, "Code executor is not configured on this server.")
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
