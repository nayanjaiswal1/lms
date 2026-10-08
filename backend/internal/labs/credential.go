package labs

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
)

// ─── Per-session container credential (docs/labs.md "Proxy ↔ Container
// Channel Security"; docs/debug-labs.md "Pre-existing problems" + §2
// "Isolation") ────────────────────────────────────────────────────────────
//
// Every Docker lab container shares the "mindforge-labs" bridge network, so
// without a credential any container can open a WebSocket straight to
// another session's ttyd on :7681 and get a shell — the proxy's own
// session/IDOR checks are bypassed entirely because they never enter into
// it. The fix: derive a per-session secret the container proves on connect.
//
// TTYDCredentialUser is the ttyd basic-auth username. It carries no secrecy
// of its own — DeriveContainerCredential's HMAC output is the only thing
// that matters — a fixed, well-known username keeps entrypoint.sh and
// labproxy from having to agree on anything except the derivation.
const TTYDCredentialUser = "mindforge"

// ttydCredentialFile is where the credential is written inside the
// container, read back by lab-images/shared/entrypoint.sh before it starts
// ttyd. It lives in labuser's own home (mode 600 via the umask the write
// script sets), not the world-writable /home/labuser/work workdir a lab's
// setup_script and the student's own shell both touch.
const ttydCredentialFile = "/home/labuser/.mf-ttyd-cred"

// CredentialWriteTimeoutSeconds bounds the docker/kubectl exec that delivers
// the credential file — a plain `cat > file` from a few bytes of stdin,
// generous headroom over what it could ever legitimately take.
const CredentialWriteTimeoutSeconds = 10

// DeriveContainerCredential computes the per-session container credential:
// HMAC-SHA256(LAB_TOKEN_SECRET, sessionID), hex-encoded. Nothing about this
// value is ever stored in the database or handed to the browser — both
// sides (this process, writing it into the container at claim/start time,
// and labproxy, presenting it on every upstream connection) independently
// recompute it from the session ID and the shared secret. The same
// derivation secures the IDE port in Phase 1 (docs/debug-labs.md §2): one
// helper, reused for every per-container credentialed port a session opens.
// containerCredentialDomain prefixes the HMAC input — must match the copy in
// the other process (internal/labs/credential.go ↔ cmd/labproxy/proxy.go).
const containerCredentialDomain = "mindforge/container-credential/v1:"

func DeriveContainerCredential(secret, sessionID string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	// Domain-separation prefix: the secret also signs auth JWTs and the
	// student can read their own credential inside the container, so the
	// HMAC input must never be able to coincide with a JWT signing input.
	mac.Write([]byte(containerCredentialDomain + sessionID))
	return hex.EncodeToString(mac.Sum(nil))
}

// writeTTYDCredential delivers the session's derived credential into the
// container as "user:pass" (ttyd's -c basic-auth format), for
// entrypoint.sh to read once and pass to ttyd -c. Runs via the runtime's
// ordinary ExecStdin (the container's own non-root user — labuser on
// Docker, the image's default user on Kubernetes; see ContainerRuntime.
// ExecStdin), not a privileged exec: labuser already owns its home
// directory, and nothing about this file needs root to create.
//
// Called from acquireSandbox at the single point BOTH provisioning paths
// (cold Start and warm-pool claim) converge, so a warm container — created
// long before any session exists to derive a credential from — gets one
// the moment it is actually claimed, and a cold-started container gets one
// before anything waits on its readiness. entrypoint.sh blocks ttyd from
// starting at all until this file exists, so there is no window where the
// container's shell is reachable without it.
func writeTTYDCredential(ctx context.Context, rt ContainerRuntime, containerID, sessionID, jwtSecret string) error {
	credential := TTYDCredentialUser + ":" + DeriveContainerCredential(jwtSecret, sessionID)
	script := fmt.Sprintf(`umask 077 && cat > %s`, ttydCredentialFile)
	_, stderr, exitCode, err := rt.ExecStdin(ctx, containerID, script, []byte(credential), CredentialWriteTimeoutSeconds)
	if err != nil {
		return fmt.Errorf("labs.writeTTYDCredential: exec: %w", err)
	}
	if exitCode != 0 {
		return fmt.Errorf("labs.writeTTYDCredential: write exited %d: %s", exitCode, stderr)
	}
	return nil
}

// ─── IDE (openvscode-server) connection token ───────────────────────────────
//
// The debug lab's IDE port gets its own credential, derived with a DISTINCT
// HMAC domain from the ttyd one so that leaking one (the student can read
// both files inside their own container) never yields the other, and neither
// can be replayed as the other. Written raw (no "user:") because
// openvscode-server's --connection-token-file takes the bare token.
const ideCredentialFile = "/home/labuser/.mf-ide-cred"

// ideCredentialDomain must match cmd/labproxy/proxy.go's copy.
const ideCredentialDomain = "mindforge/container-credential/ide/v1:"

// DeriveIDECredential is HMAC-SHA256(secret, ideCredentialDomain+sessionID),
// hex. labproxy recomputes it and injects it on requests to the session's
// ide_port only; the browser never sees it.
func DeriveIDECredential(secret, sessionID string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(ideCredentialDomain + sessionID))
	return hex.EncodeToString(mac.Sum(nil))
}

func writeIDECredential(ctx context.Context, rt ContainerRuntime, containerID, sessionID, jwtSecret string) error {
	script := fmt.Sprintf(`umask 077 && cat > %s`, ideCredentialFile)
	_, stderr, exitCode, err := rt.ExecStdin(ctx, containerID, script, []byte(DeriveIDECredential(jwtSecret, sessionID)), CredentialWriteTimeoutSeconds)
	if err != nil {
		return fmt.Errorf("labs.writeIDECredential: exec: %w", err)
	}
	if exitCode != 0 {
		return fmt.Errorf("labs.writeIDECredential: write exited %d: %s", exitCode, stderr)
	}
	return nil
}

// writeContainerCredentials writes every per-session credential (ttyd + IDE)
// at the single points where a container becomes bound to a session (warm
// claim, cold start, reset replacement). Images that don't read the IDE file
// simply ignore it.
func writeContainerCredentials(ctx context.Context, rt ContainerRuntime, containerID, sessionID, jwtSecret string) error {
	if err := writeTTYDCredential(ctx, rt, containerID, sessionID, jwtSecret); err != nil {
		return fmt.Errorf("labs.writeContainerCredentials: %w", err)
	}
	return writeIDECredential(ctx, rt, containerID, sessionID, jwtSecret)
}
