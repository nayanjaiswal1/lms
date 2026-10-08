package main

import (
	"testing"

	"github.com/mindforge/backend/internal/labs"
)

// TestDeriveContainerCredential_KnownVector pins the exact algorithm
// (HMAC-SHA256, hex-encoded) against an independently computed value
// (Python hmac/hashlib), so the credential labproxy presents on connect never
// silently drifts from the one written into the container.
func TestDeriveContainerCredential_KnownVector(t *testing.T) {
	const want = "fbfdd69dca7a9357827c62d6163431f1167f57b976044d6e18534e4a495de092"
	got := labs.DeriveContainerCredential("test-lab-jwt-secret", "session-a")
	if got != want {
		t.Fatalf("DeriveContainerCredential known vector mismatch: got %q, want %q", got, want)
	}
	if labs.DeriveContainerCredential("a-different-secret", "session-a") == want {
		t.Fatal("different secrets must derive different credentials")
	}
}
