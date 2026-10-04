package main

import "testing"

// TestDeriveContainerCredential covers the ttyd auth fix (docs/labs.md
// "Proxy ↔ Container Channel Security"; docs/debug-labs.md Phase 0):
// deterministic per (secret, sessionID), and different for any different
// input — the property the whole scheme depends on, since labs.
// writeTTYDCredential and this function must independently land on the
// exact same value for the same session, and a different student's session
// must never collide.
func TestDeriveContainerCredential(t *testing.T) {
	const secret = "test-lab-jwt-secret"

	a := deriveContainerCredential(secret, "session-a")
	b := deriveContainerCredential(secret, "session-a")
	if a != b {
		t.Fatalf("derivation is not deterministic: %q != %q", a, b)
	}
	if a == "" {
		t.Fatal("derived credential must not be empty")
	}

	other := deriveContainerCredential(secret, "session-b")
	if a == other {
		t.Fatal("different session IDs must derive different credentials")
	}

	otherSecret := deriveContainerCredential("a-different-secret", "session-a")
	if a == otherSecret {
		t.Fatal("different secrets must derive different credentials")
	}
}

// TestDeriveContainerCredential_KnownVector pins the exact algorithm
// (HMAC-SHA256, hex-encoded) against an independently computed value
// (Python hmac/hashlib). labs.DeriveContainerCredential
// (internal/labs/credential.go) has the identical test with the identical
// expected string — the two implementations are duplicated on purpose (see
// deriveContainerCredential's doc comment) and must never silently drift
// apart, or the container's credential and the one labproxy presents on
// connect stop matching.
func TestDeriveContainerCredential_KnownVector(t *testing.T) {
	const want = "fbfdd69dca7a9357827c62d6163431f1167f57b976044d6e18534e4a495de092"
	got := deriveContainerCredential("test-lab-jwt-secret", "session-a")
	if got != want {
		t.Fatalf("deriveContainerCredential known vector mismatch: got %q, want %q", got, want)
	}
}

// TestDeriveContainerCredential_HexEncoded guards the wire format: ttyd's
// -c user:pass flag and the HTTP Basic Auth header both need a value with
// no ':' or control characters in it.
func TestDeriveContainerCredential_HexEncoded(t *testing.T) {
	cred := deriveContainerCredential("secret", "session-id")
	if len(cred) != 64 { // hex-encoded SHA-256 = 32 bytes = 64 hex chars
		t.Fatalf("expected 64 hex chars (SHA-256), got %d: %q", len(cred), cred)
	}
	for _, c := range cred {
		isHex := (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')
		if !isHex {
			t.Fatalf("credential contains non-hex character %q: %q", c, cred)
		}
	}
}
