package auth

import (
	"context"
	"crypto/sha1" //nolint:gosec // mirrors the production index, not a security primitive
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/config"
)

func rangeStub(t *testing.T, body string, status int) *config.Config {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(status)
		_, _ = w.Write([]byte(body))
	}))
	t.Cleanup(srv.Close)
	return &config.Config{
		PasswordBreachCheckEnabled: true,
		PasswordBreachAPIURL:       srv.URL + "/",
		PasswordBreachTimeout:      2 * time.Second,
	}
}

// suffixOf returns the last 35 hex chars of the SHA-1 digest — the half of the
// hash the range API echoes back.
func suffixOf(password string) string {
	sum := sha1.Sum([]byte(password)) //nolint:gosec
	return strings.ToUpper(hex.EncodeToString(sum[:]))[5:]
}

func TestBreachCorpusRejectsKnownPassword(t *testing.T) {
	pw := "correct horse battery staple"
	cfg := rangeStub(t, "0011223344556677889900AABBCCDDEEFF0:5\r\n"+suffixOf(pw)+":42\r\n", http.StatusOK)

	if got := checkBreachCorpus(context.Background(), cfg, pw); got == nil {
		t.Fatal("expected a breached password to be rejected")
	}
}

func TestBreachCorpusAllowsUnlistedPassword(t *testing.T) {
	cfg := rangeStub(t, "0011223344556677889900AABBCCDDEEFF0:5\r\n", http.StatusOK)

	if got := checkBreachCorpus(context.Background(), cfg, "a password not in the list"); got != nil {
		t.Fatalf("expected acceptance, got rejection: %s", got.Reason)
	}
}

// Padding entries share the prefix but carry a count of 0. Treating one as a hit
// would reject arbitrary passwords, so this is the case worth pinning.
func TestBreachCorpusIgnoresZeroCountPadding(t *testing.T) {
	pw := "some padded password"
	cfg := rangeStub(t, suffixOf(pw)+":0\r\n", http.StatusOK)

	if got := checkBreachCorpus(context.Background(), cfg, pw); got != nil {
		t.Fatalf("padding entry must not count as a breach, got: %s", got.Reason)
	}
}

// The check is a strengthening layer, not a gate: an outage must not stop people
// registering or resetting their password.
func TestBreachCorpusFailsOpen(t *testing.T) {
	cfg := rangeStub(t, "upstream exploded", http.StatusInternalServerError)
	if got := checkBreachCorpus(context.Background(), cfg, "anything"); got != nil {
		t.Fatalf("a failing upstream must fail open, got: %s", got.Reason)
	}

	unreachable := &config.Config{
		PasswordBreachCheckEnabled: true,
		// Reserved TEST-NET-1 address on a closed port — never routable.
		PasswordBreachAPIURL:  "http://192.0.2.1:9/",
		PasswordBreachTimeout: 100 * time.Millisecond,
	}
	if got := checkBreachCorpus(context.Background(), unreachable, "anything"); got != nil {
		t.Fatalf("an unreachable upstream must fail open, got: %s", got.Reason)
	}
}

func TestBreachCorpusSkippedWhenDisabled(t *testing.T) {
	pw := "breached"
	cfg := rangeStub(t, suffixOf(pw)+":99\r\n", http.StatusOK)
	cfg.PasswordBreachCheckEnabled = false

	if got := checkBreachCorpus(context.Background(), cfg, pw); got != nil {
		t.Fatalf("expected the check to be skipped, got: %s", got.Reason)
	}
}

func TestContextTerms(t *testing.T) {
	tests := []struct {
		name     string
		password string
		terms    []string
		rejected bool
	}{
		{"password is the email", "jane@example.com", []string{"jane@example.com", "Jane"}, true},
		{"password is the email local part", "jane", []string{"jane@example.com"}, true},
		{"password is the name, different case", "JANE DOE", []string{"jane@example.com", "Jane Doe"}, true},
		{"unrelated password", "an unrelated passphrase", []string{"jane@example.com", "Jane Doe"}, false},
		{"empty terms are ignored", "whatever", []string{"", "  "}, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := checkContextTerms(tt.password, tt.terms...)
			if tt.rejected && got == nil {
				t.Fatal("expected rejection")
			}
			if !tt.rejected && got != nil {
				t.Fatalf("expected acceptance, got: %s", got.Reason)
			}
		})
	}
}

// A locked account must be refused, and the message must not distinguish a
// suspension from a self-deactivation.
func TestAccountLockedMessage(t *testing.T) {
	if msg := accountLockedMessage(StatusActive); msg != "" {
		t.Fatalf("active account must not be locked, got %q", msg)
	}

	suspended := accountLockedMessage(StatusSuspended)
	deactivated := accountLockedMessage(StatusDeactivated)
	if suspended == "" || deactivated == "" {
		t.Fatal("non-active statuses must produce a message")
	}
	if suspended != deactivated {
		t.Fatalf("messages must not distinguish the two states: %q vs %q", suspended, deactivated)
	}
}
