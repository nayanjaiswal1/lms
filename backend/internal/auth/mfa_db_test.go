package auth

import (
	"context"
	"errors"
	"github.com/mindforge/backend/internal/testdomain"
	"testing"
	"time"

	"golang.org/x/crypto/bcrypt"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/secrets"
	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

func newMFAHandler(t *testing.T) (*Handler, string) {
	t.Helper()
	pool := testdb.New(t)
	vault, err := secrets.New(&config.Config{EncryptionKey: "0123456789abcdef0123456789abcdef"})
	if err != nil {
		t.Fatalf("vault: %v", err)
	}
	var userID string
	if err := pool.QueryRow(context.Background(),
		`INSERT INTO users (email, name) VALUES ('mfa-user@`+testdomain.Domain+`', 'MFA User') RETURNING id`,
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return &Handler{pool: pool, vault: vault}, userID
}

// enrol runs setup + confirm using the TOTP step one period behind now, so a
// later code at a newer step is still accepted by the replay guard.
func enrol(t *testing.T, h *Handler, userID string) (secret []byte, recovery []string) {
	t.Helper()
	ctx := context.Background()
	b32, _, err := h.beginMFASetup(ctx, userID, "mfa-user@"+testdomain.Domain)
	if err != nil {
		t.Fatalf("beginMFASetup: %v", err)
	}
	if secret, err = base32NoPad.DecodeString(b32); err != nil {
		t.Fatalf("decode secret: %v", err)
	}
	cur := time.Now().Unix() / totpPeriod
	if recovery, err = h.confirmMFA(ctx, userID, totpCode(secret, cur-1)); err != nil {
		t.Fatalf("confirmMFA: %v", err)
	}
	return secret, recovery
}

func TestMFAEnrolAndVerify(t *testing.T) {
	h, userID := newMFAHandler(t)
	ctx := context.Background()

	if _, err := h.confirmMFA(ctx, userID, "000000"); !errors.Is(err, errMFANoPending) {
		t.Fatalf("confirm without setup: want errMFANoPending, got %v", err)
	}
	secret, recovery := enrol(t, h, userID)
	if len(recovery) == 0 {
		t.Fatal("expected recovery codes")
	}
	if on, err := h.mfaEnabled(ctx, userID); err != nil || !on {
		t.Fatalf("mfaEnabled = %v, %v", on, err)
	}
	if _, _, err := h.beginMFASetup(ctx, userID, "x@"+testdomain.Domain); !errors.Is(err, errMFAAlreadyEnabled) {
		t.Fatalf("setup when enabled: want errMFAAlreadyEnabled, got %v", err)
	}

	cur := time.Now().Unix() / totpPeriod
	code := totpCode(secret, cur+1)
	if rec, err := h.checkSecondFactor(ctx, userID, code); err != nil || rec {
		t.Fatalf("valid totp: recovery=%v err=%v", rec, err)
	}
	if _, err := h.checkSecondFactor(ctx, userID, code); !errors.Is(err, errMFABadCode) {
		t.Fatalf("replayed totp must be rejected, got %v", err)
	}
	if rec, err := h.checkSecondFactor(ctx, userID, recovery[0]); err != nil || !rec {
		t.Fatalf("valid recovery: recovery=%v err=%v", rec, err)
	}
	if _, err := h.checkSecondFactor(ctx, userID, recovery[0]); !errors.Is(err, errMFABadCode) {
		t.Fatalf("spent recovery code must be rejected, got %v", err)
	}
}

func TestRegenerateRecoveryCodes(t *testing.T) {
	h, userID := newMFAHandler(t)
	ctx := context.Background()
	secret, old := enrol(t, h, userID)

	if _, err := h.regenerateRecoveryCodes(ctx, userID, old[0]); !errors.Is(err, errMFABadCode) {
		t.Fatalf("recovery code must not authorise regeneration, got %v", err)
	}
	if _, err := h.regenerateRecoveryCodes(ctx, userID, "000000"); !errors.Is(err, errMFABadCode) {
		t.Fatalf("wrong totp: want errMFABadCode, got %v", err)
	}

	fresh, err := h.regenerateRecoveryCodes(ctx, userID, totpCode(secret, time.Now().Unix()/totpPeriod+1))
	if err != nil {
		t.Fatalf("regenerate: %v", err)
	}
	if len(fresh) != len(old) {
		t.Fatalf("want %d new codes, got %d", len(old), len(fresh))
	}
	if _, err := h.checkSecondFactor(ctx, userID, old[1]); !errors.Is(err, errMFABadCode) {
		t.Fatalf("old recovery code must be invalidated, got %v", err)
	}
	if rec, err := h.checkSecondFactor(ctx, userID, fresh[0]); err != nil || !rec {
		t.Fatalf("new recovery code: recovery=%v err=%v", rec, err)
	}
}

func TestApplyPasswordChange(t *testing.T) {
	h, userID := newMFAHandler(t)
	ctx := context.Background()
	hash, err := bcrypt.GenerateFromPassword([]byte("new-password-123"), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("bcrypt: %v", err)
	}
	var before int
	if err := h.pool.QueryRow(ctx, `SELECT session_version FROM users WHERE id = $1`, userID).Scan(&before); err != nil {
		t.Fatalf("read version: %v", err)
	}
	if _, err := h.pool.Exec(ctx,
		`INSERT INTO refresh_tokens (jti, family_id, user_id, expires_at) VALUES (gen_random_uuid(), gen_random_uuid(), $1, now() + interval '1 day')`, userID); err != nil {
		t.Fatalf("seed refresh token: %v", err)
	}

	version, err := h.applyPasswordChange(ctx, userID, string(hash))
	if err != nil {
		t.Fatalf("applyPasswordChange: %v", err)
	}
	if version != before+1 {
		t.Errorf("session_version = %d, want %d", version, before+1)
	}
	var stored string
	var live int
	if err := h.pool.QueryRow(ctx,
		`SELECT password_hash, (SELECT count(*) FROM refresh_tokens WHERE user_id = $1 AND revoked_at IS NULL)
		 FROM users WHERE id = $1`, userID).Scan(&stored, &live); err != nil {
		t.Fatalf("read back: %v", err)
	}
	if bcrypt.CompareHashAndPassword([]byte(stored), []byte("new-password-123")) != nil {
		t.Error("stored hash does not match the new password")
	}
	if live != 0 {
		t.Errorf("%d refresh tokens still live, want 0", live)
	}
}
