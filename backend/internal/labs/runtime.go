package labs

import (
	"context"
	"fmt"
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
	// Start provisions a new sandbox for the given session. It returns as soon
	// as the sandbox exists — it does NOT wait for the image's background
	// services to come up and does NOT run any lab setup. Callers pair it with
	// WaitContainerReady (the image's own readiness contract) and then
	// Service.prepareLabEnvironment (the lab's starter files + setup_script),
	// which is exactly what makes a warm sandbox interchangeable between every
	// lab sharing its image. containerHost is "<host>:7681", dialed directly by
	// labproxy for the in-browser terminal.
	Start(ctx context.Context, sessionID string, resetCount int, image string) (containerID, containerHost string, err error)

	// StartWarm provisions a pool sandbox that is not yet bound to any
	// session — identical to Start except it is named after the
	// lab_warm_containers row ("mindforge-warm-<warmID>") so the cleanup job
	// can reconcile warm sandboxes against the pool table instead of
	// lab_sessions. When a session later claims it, the container keeps its
	// warm name; the session row carries the coordinates.
	StartWarm(ctx context.Context, warmID string, image string) (containerID, containerHost string, err error)

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

	// ExecSetup runs a lab's setup_script — the one exec that is privileged
	// (Docker: --user root) rather than running as the sandbox's ordinary
	// student user. Kept as its own method rather than a bool on Exec so that
	// "which call sites can run as root" stays answerable by grep: exactly one
	// caller, Service.prepareLabEnvironment, with an instructor-authored
	// script. Everything student-reachable goes through Exec/ExecStdin and can
	// never escalate.
	//
	// The Kubernetes runtime cannot grant this — a Pod's securityContext is
	// fixed at creation — so there it runs as the image's default user. Lab
	// images are built so setup does not require root (world-writable workdir,
	// traversable home); see lab-images/*/entrypoint.sh.
	ExecSetup(ctx context.Context, containerID, script string, timeoutSec int) (stdout, stderr string, exitCode int, err error)

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

// ─── Image readiness contract ────────────────────────────────────────────────
//
// A sandbox is "ready" when the background services its image starts (lab-k8s:
// etcd + kube-apiserver + kube-controller-manager + kube-scheduler + kwok;
// lab-docker: rootless dockerd) are actually serving. That is knowledge the
// IMAGE owns, so the image ships the check as an executable at
// ReadinessProbePath and the platform just polls it. Two things follow:
//
//   - Warm containers can be pooled per image. "Ready" no longer means "some
//     lab's setup_script happened to pass", it means "this image's services
//     are up" — the same statement for every lab that shares the image.
//   - Lab authors stop hand-writing readiness loops in setup_script. The
//     previous design had every k8s lab open with `kubectl cluster-info ||
//     exit 1` and every Docker lab with a 70-iteration `docker info` poll,
//     re-deriving one image-level fact in 20 places, and container.go
//     compensated by blindly retrying setup_script 10 times because it could
//     not tell "not ready yet" from "genuinely broken".
//
// An image with no probe (lab-node-web, lab-python-web — nothing to wait for
// beyond the shell) is ready the moment it starts, which is what the
// `[ -x ... ] || exit 0` prefix encodes.
const (
	// ReadinessProbePath is where a lab image places its own readiness check.
	// Must exit 0 when the sandbox is serving, non-zero while it is still
	// coming up. Absent or non-executable = ready immediately.
	ReadinessProbePath = "/usr/local/bin/lab-ready"
	// ReadinessProbeTimeoutSeconds bounds a single probe invocation, so a
	// wedged probe costs one interval instead of the whole budget.
	ReadinessProbeTimeoutSeconds = 10
	// ReadinessPollInterval is the gap between probe attempts.
	ReadinessPollInterval = 1 * time.Second
)

// readinessProbeScript runs the image's probe, treating "no probe shipped" as
// ready. Kept as one string constant so both runtimes issue byte-identical
// checks — a readiness definition that drifted between Docker and Kubernetes
// would make pool behaviour depend on the deploy target.
const readinessProbeScript = `[ -x ` + ReadinessProbePath + ` ] || exit 0; exec ` + ReadinessProbePath

// ProbeContainerReady runs the image's readiness check exactly once. Used on
// its own when claiming a warm sandbox: that container already passed the probe
// when the planner published it, so this is a liveness re-check, and a single
// failed probe means "this one is spoiled, cold-start instead" rather than
// "wait longer" — blocking there would hand the student the very delay the pool
// was holding the container to avoid.
func ProbeContainerReady(ctx context.Context, rt ContainerRuntime, containerID string) bool {
	_, _, exitCode, err := rt.Exec(ctx, containerID, readinessProbeScript, ReadinessProbeTimeoutSeconds)
	return err == nil && exitCode == 0
}

// WaitContainerReady blocks until the sandbox's image reports ready, ctx
// expires, or the sandbox dies. Returns the time waited, which the warm-pool
// planner feeds into its measured per-image warmup average (Little's Law
// sizing needs a real number, not a guess).
//
// A dead container short-circuits: without that check a sandbox whose
// entrypoint exited (lab-k8s's `exit 1` when kube-apiserver never came up)
// would be polled uselessly until the caller's whole provisioning budget
// drained, turning a 5-second failure into a 3-minute one.
func WaitContainerReady(ctx context.Context, rt ContainerRuntime, containerID string) (time.Duration, error) {
	start := time.Now()
	for {
		if ProbeContainerReady(ctx, rt, containerID) {
			return time.Since(start), nil
		}
		if !rt.IsRunning(ctx, containerID) {
			return time.Since(start), fmt.Errorf("labs.WaitContainerReady: sandbox %s exited before becoming ready", containerID)
		}
		select {
		case <-time.After(ReadinessPollInterval):
		case <-ctx.Done():
			return time.Since(start), fmt.Errorf("labs.WaitContainerReady: sandbox %s not ready after %s: %w", containerID, time.Since(start).Round(time.Second), ctx.Err())
		}
	}
}
