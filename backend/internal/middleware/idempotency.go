package middleware

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
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

// Idempotency returns middleware that replays stored responses for duplicate
// mutating requests that carry an Idempotency-Key header.
//
// Behaviour:
//   - GET, DELETE, and OPTIONS are passed through unchanged.
//   - POST, PUT, PATCH without an Idempotency-Key are passed through unchanged.
//   - When a key is seen for the first time the downstream response is captured;
//     only 2xx responses are persisted to idempotency_keys.
//   - When a key is seen again the stored status + body are replayed immediately
//     with the Idempotency-Replayed: true header set.
//   - DB errors are logged and silently ignored — the request is never failed
//     solely because of idempotency storage.
//
// The middleware scopes keys per (idem_key, endpoint, user_id) so that two
// different users can reuse the same opaque key without collision.
func Idempotency(pool *pgxpool.Pool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Only intercept mutating methods.
			switch r.Method {
			case http.MethodGet, http.MethodDelete, http.MethodOptions, http.MethodHead:
				next.ServeHTTP(w, r)
				return
			}

			idemKey := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
			if idemKey == "" {
				next.ServeHTTP(w, r)
				return
			}

			// Scope by user when authenticated; NULL for unauthenticated routes.
			var userIDPtr *string
			if claims, ok := auth.GetClaims(r.Context()); ok {
				uid := claims.UserID
				userIDPtr = &uid
			}

			// Buffer and restore the request body so downstream handlers can
			// read it, and hash it for future conflict detection.
			bodyBytes, err := io.ReadAll(r.Body)
			if err != nil {
				httputil.WriteError(w, http.StatusInternalServerError, "Failed to read request body.")
				return
			}
			r.Body = io.NopCloser(bytes.NewReader(bodyBytes))

			sum := sha256.Sum256(bodyBytes)
			reqHash := hex.EncodeToString(sum[:])
			endpoint := r.Method + " " + r.URL.Path

			// Check for an existing idempotency record.
			var storedStatus int
			var storedBody string
			err = pool.QueryRow(r.Context(),
				`SELECT status_code, response_body
				 FROM idempotency_keys
				 WHERE idem_key = $1
				   AND endpoint = $2
				   AND (user_id = $3 OR (user_id IS NULL AND $3 IS NULL))`,
				idemKey, endpoint, userIDPtr,
			).Scan(&storedStatus, &storedBody)

			if err == nil {
				// Replay the previously stored response.
				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("Idempotency-Replayed", "true")
				w.WriteHeader(storedStatus)
				if _, werr := w.Write([]byte(storedBody)); werr != nil {
					slog.ErrorContext(r.Context(), "Idempotency: failed to write replayed response", "err", werr)
				}
				return
			}

			if !errors.Is(err, pgx.ErrNoRows) {
				// DB error on the lookup — log and fall through to process the
				// request normally rather than failing the client.
				slog.ErrorContext(r.Context(), "Idempotency: lookup query failed",
					"idem_key", idemKey,
					"endpoint", endpoint,
					"err", err,
				)
			}

			// Capture the downstream response.
			rc := &responseCapture{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(rc, r)

			// Persist only successful responses so that retries after partial
			// failures trigger a real re-execution rather than replaying an error.
			if rc.status >= 200 && rc.status < 300 {
				_, storeErr := pool.Exec(r.Context(),
					`INSERT INTO idempotency_keys
					   (idem_key, endpoint, user_id, request_hash, status_code, response_body)
					 VALUES ($1, $2, $3, $4, $5, $6)
					 ON CONFLICT (idem_key, endpoint, user_id) DO NOTHING`,
					idemKey, endpoint, userIDPtr, reqHash, rc.status, rc.body.String(),
				)
				if storeErr != nil {
					slog.ErrorContext(r.Context(), "Idempotency: failed to store response",
						"idem_key", idemKey,
						"endpoint", endpoint,
						"err", storeErr,
					)
				}
			}
		})
	}
}
