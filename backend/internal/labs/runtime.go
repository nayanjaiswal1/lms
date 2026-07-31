package labs

import (
	"context"
	"time"
)

// ContainerInfo describes one live lab sandbox for orphan-scan purposes —
// returned by List so the cleanup job can reconcile against lab_sessions
// without needing runtime-specific knowledge (container IDs vs Pod names).
type ContainerInfo struct {
	ID        string
	Name      string
	CreatedAt time.Time
}

// ContainerRuntime provisions and controls lab sandboxes. DockerContainerService
// (container.go) implements it via the Docker CLI for VPS/Compose deploys;
// KubernetesContainerService (runtime_kubernetes.go) implements it via the
// Kubernetes API for cluster deploys. Selected once at startup based on
// config.LabsRuntime — see internal/api/router.go.
type ContainerRuntime interface {
	// Start provisions a new sandbox for the given session and, if setupScript
	// is non-empty, runs it before returning. containerHost is "<host>:7681",
	// dialed directly by labproxy for the in-browser terminal.
	Start(ctx context.Context, sessionID string, resetCount int, image, setupScript string) (containerID, containerHost string, err error)

	// StartWarm provisions a pool sandbox that is not yet bound to any
	// session — identical to Start except it is named after the
	// lab_warm_containers row ("mindforge-warm-<warmID>") so the cleanup job
	// can reconcile warm sandboxes against the pool table instead of
	// lab_sessions. When a session later claims it, the container keeps its
	// warm name; the session row carries the coordinates.
	StartWarm(ctx context.Context, warmID string, image, setupScript string) (containerID, containerHost string, err error)

	// Kill force-removes a sandbox by ID.
	Kill(ctx context.Context, containerID string) error

	// Exec runs a script inside the sandbox as its default non-root user.
	// exitCode is 0 on success; a process exit error yields the real exit
	// code without propagating an error value.
	Exec(ctx context.Context, containerID, script string, timeoutSec int) (stdout, stderr string, exitCode int, err error)

	// IsRunning reports whether the sandbox is currently up.
	IsRunning(ctx context.Context, containerID string) bool

	// Unpause resumes a paused sandbox. No code path currently transitions a
	// session to "paused" (see docs/labs.md history) — Kubernetes implements
	// this as a no-op since Pods have no pause primitive; Docker's real
	// docker-pause/unpause behavior is preserved for when that path is used.
	Unpause(ctx context.Context, containerID string) error

	// List returns every live sandbox whose name starts with namePrefix (e.g.
	// "mindforge-lab-" or "mindforge-validate-") — used by LabCleanupHandler
	// to find and remove sandboxes with no corresponding active session row.
	List(ctx context.Context, namePrefix string) ([]ContainerInfo, error)

	// IsNestedImage reports whether image is on this runtime's operator-
	// configured nested-Docker allowlist (config.LabsNestedDockerImages) —
	// the ONLY thing that decides elevated container config, never the
	// image string's own content. Service.StartSession uses this to also
	// require the image be in the requesting org's lab_org_config.
	// allowed_images before a session for it is allowed to start, and the
	// warm-pool planner uses it to never pre-provision one unclaimed.
	IsNestedImage(image string) bool
}
