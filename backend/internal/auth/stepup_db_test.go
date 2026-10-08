package auth

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"

	"github.com/mindforge/backend/internal/ratelimit"
)

// TestVerifyStepUp: a password account must re-enter its password, an MFA
// account must also present a current code, and an account with neither
// factor passes on its session alone.
func TestVerifyStepUp(t *testing.T) {
	h, userID := newMFAHandler(t)
	// Unreachable Redis: the limiter falls back to its in-process window.
	h.limiter = ratelimit.New(redis.NewClient(&redis.Options{Addr: "127.0.0.1:1", MaxRetries: -1}))
	ctx := context.Background()

	check := func(password, code string) int {
		rec := httptest.NewRecorder()
		if h.VerifyStepUp(rec, httptest.NewRequest(http.MethodPost, "/", nil), userID, password, code) {
			return http.StatusOK
		}
		return rec.Code
	}

	if got := check("", ""); got != http.StatusOK {
		t.Fatalf("no factors: got %d, want pass", got)
	}

	hash, err := bcrypt.GenerateFromPassword([]byte("s3cret-pass"), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("hash: %v", err)
	}
	if _, err := h.pool.Exec(ctx, `UPDATE users SET password_hash = $2 WHERE id = $1`, userID, string(hash)); err != nil {
		t.Fatalf("set password: %v", err)
	}
	if got := check("wrong", ""); got != http.StatusForbidden {
		t.Fatalf("wrong password: got %d, want 403", got)
	}
	if got := check("s3cret-pass", ""); got != http.StatusOK {
		t.Fatalf("right password: got %d, want pass", got)
	}

	secret, _ := enrol(t, h, userID)
	if got := check("s3cret-pass", ""); got != http.StatusForbidden {
		t.Fatalf("mfa without code: got %d, want 403", got)
	}
	code := totpCode(secret, time.Now().Unix()/totpPeriod+1)
	if got := check("s3cret-pass", code); got != http.StatusOK {
		t.Fatalf("password + code: got %d, want pass", got)
	}
}
