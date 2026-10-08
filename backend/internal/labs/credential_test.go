package labs

import (
	"context"
	"strings"
	"testing"
)


// TestDeriveContainerCredential_KnownVector pins the exact algorithm
// against an independently computed value (Python hmac/hashlib) — the
// identical vector cmd/labproxy/proxy_test.go pins its duplicated
// implementation against, so the two can never silently drift apart.
func TestDeriveContainerCredential_KnownVector(t *testing.T) {
	const want = "fbfdd69dca7a9357827c62d6163431f1167f57b976044d6e18534e4a495de092"
	got := DeriveContainerCredential("test-lab-jwt-secret", "session-a")
	if got != want {
		t.Fatalf("DeriveContainerCredential known vector mismatch: got %q, want %q", got, want)
	}
}

// fakeExecRuntime is a minimal ContainerRuntime stub for exercising
// writeTTYDCredential's script/error plumbing without a real Docker/k8s
// daemon — it records the script and stdin it was asked to run and returns
// canned results.
type fakeExecRuntime struct {
	ContainerRuntime
	gotScript string
	gotStdin  []byte
	stdout    string
	stderr    string
	exitCode  int
	err       error
}

func (f *fakeExecRuntime) ExecStdin(ctx context.Context, containerID, script string, stdin []byte, timeoutSec int) (string, string, int, error) {
	f.gotScript = script
	f.gotStdin = stdin
	return f.stdout, f.stderr, f.exitCode, f.err
}

// TestWriteTTYDCredential_Success asserts the delivered payload is exactly
// "user:derivedHex" — the format both ttyd's -c flag and
// deriveContainerCredential's HTTP Basic Auth header on the labproxy side
// expect — and that it is piped via stdin (never embedded in the script
// string, so it can never leak into a process listing or shell history).
func TestWriteTTYDCredential_Success(t *testing.T) {
	rt := &fakeExecRuntime{exitCode: 0}
	err := writeTTYDCredential(context.Background(), rt, "container-1", "session-a", "test-lab-jwt-secret")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	wantCred := TTYDCredentialUser + ":" + DeriveContainerCredential("test-lab-jwt-secret", "session-a")
	if string(rt.gotStdin) != wantCred {
		t.Fatalf("stdin payload = %q, want %q", rt.gotStdin, wantCred)
	}
	if !strings.Contains(rt.gotScript, ttydCredentialFile) {
		t.Fatalf("script %q does not reference the credential file path", rt.gotScript)
	}
	if strings.Contains(rt.gotScript, wantCred) {
		t.Fatal("the credential must never be embedded directly in the exec'd script")
	}
}

// TestWriteTTYDCredential_NonZeroExit asserts a failed write surfaces as an
// error carrying the container's stderr rather than being swallowed —
// acquireSandbox treats this the same as a spoiled container.
func TestWriteTTYDCredential_NonZeroExit(t *testing.T) {
	rt := &fakeExecRuntime{exitCode: 1, stderr: "permission denied"}
	err := writeTTYDCredential(context.Background(), rt, "container-1", "session-a", "secret")
	if err == nil || !strings.Contains(err.Error(), "permission denied") {
		t.Fatalf("expected error surfacing stderr, got %v", err)
	}
}
