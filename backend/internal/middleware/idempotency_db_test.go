package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// TestIdempotencyClaimReplayRelease covers the middleware's contract: one
// execution per key, replay of a success, 409 while the original runs, 422 on
// a reused key with a different body, and a released claim after a failure.
func TestIdempotencyClaimReplayRelease(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	var userID string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('idem@`+testdomain.Domain+`', 'Idem') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("insert user: %v", err)
	}

	var runs atomic.Int32
	status := http.StatusCreated
	var inHandler func()
	h := Idempotency(pool)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		runs.Add(1)
		if inHandler != nil {
			inHandler()
		}
		w.WriteHeader(status)
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	send := func(key, body string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodPost, "/api/things", strings.NewReader(body))
		req.Header.Set("Idempotency-Key", key)
		req = req.WithContext(auth.SetClaims(req.Context(), &auth.Claims{UserID: userID}))
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec
	}

	// A duplicate arriving while the original is still running gets 409.
	inHandler = func() {
		if got := send("k1", `{"a":1}`).Code; got != http.StatusConflict {
			t.Errorf("concurrent duplicate: got %d, want 409", got)
		}
	}
	if got := send("k1", `{"a":1}`).Code; got != http.StatusCreated {
		t.Fatalf("first: got %d, want 201", got)
	}
	inHandler = nil

	replay := send("k1", `{"a":1}`)
	if replay.Code != http.StatusCreated || replay.Header().Get("Idempotency-Replayed") != "true" {
		t.Fatalf("replay: got %d replayed=%q", replay.Code, replay.Header().Get("Idempotency-Replayed"))
	}
	if got := send("k1", `{"a":2}`).Code; got != http.StatusUnprocessableEntity {
		t.Fatalf("mismatched body: got %d, want 422", got)
	}
	if n := runs.Load(); n != 1 {
		t.Fatalf("handler ran %d times for k1, want 1", n)
	}

	// A failed request releases its claim, so a retry executes again.
	status = http.StatusBadGateway
	send("k2", `{}`)
	status = http.StatusCreated
	if got := send("k2", `{}`); got.Code != http.StatusCreated || got.Header().Get("Idempotency-Replayed") != "" {
		t.Fatalf("retry after failure: got %d replayed=%q", got.Code, got.Header().Get("Idempotency-Replayed"))
	}
	if n := runs.Load(); n != 3 {
		t.Fatalf("handler ran %d times total, want 3", n)
	}
}
