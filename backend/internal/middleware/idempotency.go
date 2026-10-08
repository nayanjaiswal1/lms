package middleware

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

const (
	// idemPendingStatus marks a claimed key whose request is still running.
	idemPendingStatus = 0
	// idemPendingTimeout is how long a pending claim blocks retries before it
	// is treated as abandoned (process died mid-request) and can be reclaimed.
	idemPendingTimeout = 5 * time.Minute
	idemMaxKeyLen      = 255
)

// responseCapture wraps http.ResponseWriter to capture status + body while
// still writing through to the underlying writer so the client receives the
// response normally.
type responseCapture struct {
	http.ResponseWriter
	status int
	body   bytes.Buffer
}

func (rc *responseCapture) WriteHeader(status int) {
	rc.status = status
	rc.ResponseWriter.WriteHeader(status)
}

func (rc *responseCapture) Write(b []byte) (int, error) {
	rc.body.Write(b)
	return rc.ResponseWriter.Write(b)
}

// Idempotency returns middleware that runs a request carrying an
// Idempotency-Key header at most once per (key, endpoint, user).
//
// Behaviour:
//   - GET, DELETE, HEAD, OPTIONS, requests without a key, and unauthenticated
//     requests (no user to scope the key to) pass through unchanged.
//   - The key is claimed atomically before the handler runs, so a concurrent
//     duplicate (double-click) gets 409 instead of a second execution.
//   - A 2xx response is stored and replayed for later duplicates with
//     Idempotency-Replayed: true; any other outcome releases the claim so a
//     retry re-executes.
//   - Reusing a key with a different body is 422.
//   - Storage errors are logged and the request runs normally: idempotency
//     storage never fails a request on its own.
//
// Rows are purged by the retention.purge cron.
func Idempotency(pool *pgxpool.Pool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			switch r.Method {
			case http.MethodGet, http.MethodDelete, http.MethodOptions, http.MethodHead:
				next.ServeHTTP(w, r)
				return
			}
			key := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
			claims, authed := auth.GetClaims(r.Context())
			if key == "" || !authed {
				next.ServeHTTP(w, r)
				return
			}
			if len(key) > idemMaxKeyLen {
				httputil.WriteError(w, http.StatusUnprocessableEntity, "Idempotency-Key is too long.")
				return
			}

			body, err := io.ReadAll(r.Body)
			if err != nil {
				httputil.WriteError(w, http.StatusInternalServerError, "Failed to read request body.")
				return
			}
			r.Body = io.NopCloser(bytes.NewReader(body))
			sum := sha256.Sum256(body)
			rec := idemRecord{
				pool: pool, key: key, endpoint: r.Method + " " + r.URL.Path,
				userID: claims.UserID, hash: hex.EncodeToString(sum[:]),
			}

			id, err := rec.claim(r.Context())
			if err != nil {
				slog.ErrorContext(r.Context(), "idempotency: claim", "endpoint", rec.endpoint, "error", err)
				next.ServeHTTP(w, r)
				return
			}
			if id == "" {
				rec.answerDuplicate(w, r)
				return
			}

			rc := &responseCapture{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(rc, r)
			// The client may have gone away; the claim must still be settled.
			if err := rec.settle(context.WithoutCancel(r.Context()), id, rc); err != nil {
				slog.ErrorContext(r.Context(), "idempotency: settle", "endpoint", rec.endpoint, "error", err)
			}
		})
	}
}

type idemRecord struct {
	pool                        *pgxpool.Pool
	key, endpoint, userID, hash string
}

// claim inserts a pending row, or takes over an abandoned pending one. It
// returns the row id, or "" when another request owns the key.
func (rec idemRecord) claim(ctx context.Context) (string, error) {
	var id string
	err := rec.pool.QueryRow(ctx,
		`INSERT INTO idempotency_keys (idem_key, endpoint, user_id, request_hash, status_code, response_body)
		 VALUES ($1, $2, $3, $4, $5, '')
		 ON CONFLICT (idem_key, endpoint, user_id) DO UPDATE
		   SET request_hash = EXCLUDED.request_hash, created_at = now()
		   WHERE idempotency_keys.status_code = $5
		     AND idempotency_keys.created_at < now() - make_interval(secs => $6)
		 RETURNING id`,
		rec.key, rec.endpoint, rec.userID, rec.hash, idemPendingStatus, idemPendingTimeout.Seconds(),
	).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("claim idempotency key: %w", err)
	}
	return id, nil
}

// answerDuplicate replays the stored response, or rejects a mismatched body
// or a still-running original.
func (rec idemRecord) answerDuplicate(w http.ResponseWriter, r *http.Request) {
	var status int
	var body, hash string
	if err := rec.pool.QueryRow(r.Context(),
		`SELECT status_code, response_body, request_hash FROM idempotency_keys
		 WHERE idem_key = $1 AND endpoint = $2 AND user_id = $3`,
		rec.key, rec.endpoint, rec.userID,
	).Scan(&status, &body, &hash); err != nil {
		// The original settled with a failure between our claim and this read.
		slog.WarnContext(r.Context(), "idempotency: duplicate lookup", "endpoint", rec.endpoint, "error", err)
		httputil.WriteError(w, http.StatusConflict, "This request was already submitted. Please retry.")
		return
	}
	switch {
	case hash != rec.hash:
		httputil.WriteError(w, http.StatusUnprocessableEntity, "Idempotency-Key was already used for a different request.")
	case status == idemPendingStatus:
		w.Header().Set("Retry-After", "2")
		httputil.WriteError(w, http.StatusConflict, "This request is already being processed.")
	default:
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Idempotency-Replayed", "true")
		w.WriteHeader(status)
		if _, err := w.Write([]byte(body)); err != nil {
			slog.ErrorContext(r.Context(), "idempotency: write replay", "error", err)
		}
	}
}

// settle stores a successful response for replay, or releases the claim so a
// retry runs again.
func (rec idemRecord) settle(ctx context.Context, id string, rc *responseCapture) error {
	if rc.status >= 200 && rc.status < 300 {
		if _, err := rec.pool.Exec(ctx,
			`UPDATE idempotency_keys SET status_code = $2, response_body = $3 WHERE id = $1`,
			id, rc.status, rc.body.String()); err != nil {
			return fmt.Errorf("store idempotent response: %w", err)
		}
		return nil
	}
	if _, err := rec.pool.Exec(ctx, `DELETE FROM idempotency_keys WHERE id = $1`, id); err != nil {
		return fmt.Errorf("release idempotency key: %w", err)
	}
	return nil
}
