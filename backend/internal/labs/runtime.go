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
	// code without propagating an error value. Implementations MUST bound
	// captured output at MaxExecOutputBytes per stream — the script is
	// effectively student-controlled (it can cat any file in their own
	// container), so unbounded capture is an API-process OOM waiting to
	// happen.
	Exec(ctx context.Context, containerID, script string, timeoutSec int) (stdout, stderr string, exitCode int, err error)

	// ExecStdin is Exec with a byte stream piped to the script's stdin —
	// used by WriteFile to deliver file content without ever embedding it in
	// the command string. Two problems that come from embedding student
	// content directly in a shell command (the pre-fix WriteFile heredoc)
	// don't exist here even in principle: there is no delimiter or quoting
	// scheme for arbitrary bytes to break out of, and there is no host
	// execve() argument-length ceiling to hit (Linux caps a single argv
	// string at MAX_ARG_STRLEN, ~128KB — comfortably smaller than a single
	// source file) since stdin is a stream, not part of argv.
	ExecStdin(ctx context.Context, containerID, script string, stdin []byte, timeoutSec int) (stdout, stderr string, exitCode int, err error)

	// IsRunning reports whether the sandbox is currently up.
	IsRunning(ctx context.Context, containerID string) bool

	// Pause suspends a sandbox's process tree without destroying it, so an
	// idle session stops burning CPU while keeping the student's work intact
	// (lab.expire_sessions pauses at IdleTimeoutMinutes). Kubernetes has no
	// Pod-level pause primitive, so its implementation reports
	// ErrPauseUnsupported and the reaper leaves the session running until the
	// harder IdleReapMinutes / expires_at deadlines close it out.
	Pause(ctx context.Context, containerID string) error

	// Unpause resumes a paused sandbox — the counterpart to Pause, called
	// from Service.ensureContainerResumed before any exec or terminal
	// attach. A no-op on runtimes that never pause.
	Unpause(ctx context.Context, containerID string) error

	// List returns every live sandbox whose name starts with namePrefix (e.g.
	// "mindforge-lab-" or "mindforge-validate-") — used by LabCleanupHandler
	// to find and remove sandboxes with no corresponding active session row.
	List(ctx context.Context, namePrefix string) ([]ContainerInfo, error)

	// Classify resolves image to its ImageProfile via this runtime's
	// operator-configured mapping (config.LabsImageProfiles) — the ONLY
	// thing that decides elevated container config, never the image
	// string's own content or any instructor-authored field. An image with
	// no mapping resolves to the zero-value ImageProfile (standard: default
	// CPU/mem, no elevation, no org-allowlist requirement, pre-warm
	// eligible). Service.StartSession uses ImageProfile.RequiresOrgAllowlist
	// to also require the image be in the requesting org's lab_org_config.
	// allowed_images before a session for it is allowed to start, and the
	// warm-pool planner uses ImageProfile.SkipPreWarm to decide whether to
	// ever pre-provision one unclaimed.
	Classify(image string) ImageProfile
}
