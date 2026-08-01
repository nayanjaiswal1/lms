package labs

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// setupScriptRetryAttempts and setupScriptRetryDelay bound how long Start
// retries a failing setup_script before giving up. docker run -d returns as
// soon as the container's PID 1 starts, but an image's own background
// services (e.g. lab-k8s's etcd/kube-apiserver, started by entrypoint.sh)
// take a moment to come up — a setup_script whose own readiness check (e.g.
// "kubectl cluster-info || exit 1") runs before that moment fails with no
// useful stderr. Retrying is image-agnostic: each image defines its own
// readiness check inside setup_script; Start just gives it a few chances
// rather than baking any one image's specific check in here. Mirrors the
// same "retry a moment" reasoning as entrypoint.sh's own apply_retry helper
// for kwok's CRD race.
const (
	setupScriptRetryAttempts = 10
	setupScriptRetryDelay    = 500 * time.Millisecond
)

// DockerContainerService implements ContainerRuntime via the Docker CLI —
// used for VPS/Docker Compose deploys. See runtime_kubernetes.go for the
// cluster-deploy implementation.
type DockerContainerService struct {
	// profiles is the operator-configured image -> ImageProfile mapping
	// (config.LabsImageProfiles resolved against main.go's profile catalog)
	// that decides each image's container config in buildRunArgs. An image
	// with no entry gets the zero-value (standard) profile: the platform's
	// normal --cap-drop ALL / no-new-privileges / no added capabilities
	// config.
	profiles map[string]ImageProfile
}

// NewDockerContainerService returns a DockerContainerService backed by the
// local Docker daemon. profiles maps an environment image to the
// ImageProfile deciding its container config — see profile.go and
// docs/labs.md "Nested Docker labs" before adding entries.
func NewDockerContainerService(profiles map[string]ImageProfile) *DockerContainerService {
	if profiles == nil {
		profiles = map[string]ImageProfile{}
	}
	return &DockerContainerService{profiles: profiles}
}

// Classify implements ContainerRuntime. This is the ONLY thing that decides
// elevated container config — never the environment string's contents or
// any instructor-authored field, since either would make lab content itself
// the security boundary. An unmapped image returns the zero-value
// (standard) ImageProfile.
func (c *DockerContainerService) Classify(image string) ImageProfile {
	return c.profiles[image]
}

// Start provisions a new Docker container for the given lab session and runs the
// optional setup script inside it as root. On setup failure the container is
// force-removed before the error is returned.
func (c *DockerContainerService) Start(ctx context.Context, sessionID string, resetCount int, image, setupScript string) (containerID, containerHost string, err error) {
	return c.startNamed(ctx, fmt.Sprintf("mindforge-lab-%s-%d", sessionID, resetCount), image, setupScript)
}

// StartWarm provisions an unbound warm-pool sandbox. See ContainerRuntime.
func (c *DockerContainerService) StartWarm(ctx context.Context, warmID string, image, setupScript string) (containerID, containerHost string, err error) {
	return c.startNamed(ctx, "mindforge-warm-"+warmID, image, setupScript)
}

// buildRunArgs is the pure "what flags does this container get" decision,
// pulled out of startNamed so the profile-driven branch is unit-testable
// without shelling out to a real Docker daemon — this is the single place
// that decides whether a container is elevated, so it gets its own tests
// asserting standard-profile output is untouched and each DockerMechanism
// has exactly the documented flags (see docs/labs.md "Nested Docker labs").
// privileged is only ever true for the startNamed retry described there —
// the initial attempt for every "rootless-dind" image is always
// privileged=false.
func (c *DockerContainerService) buildRunArgs(name, image string, privileged bool) []string {
	profile := c.Classify(image)

	cpu := profile.CPU
	if cpu == "" {
		cpu = ContainerCPU
	}
	memMB := profile.MemoryMB
	if memMB == 0 {
		memMB = ContainerMemoryMB
	}
	network := profile.Network
	if network == "" {
		network = "mindforge-labs"
	}

	args := []string{"run", "-d", "--name", name, "--cpus", cpu, "--memory", fmt.Sprintf("%dm", memMB)}

	switch profile.DockerMechanism {
	case "sysbox-runc":
		// No added capabilities at all — the preferred elevation mechanism
		// when the host has sysbox-runc installed.
		args = append(args, "--cap-drop", "ALL", "--runtime", "sysbox-runc")
	case "rootless-dind":
		// Nested Docker-in-Docker: this container is treated as potentially
		// host-root (see docs/labs.md "Nested Docker labs" for the residual
		// risk this does NOT eliminate). The scoped rootless-dind capability
		// set below is the default, and the only thing a real Linux Docker
		// Engine host ever needs; --privileged (see startNamed's retry) is
		// only reached when the scoped set demonstrably failed to produce a
		// running container.
		if privileged {
			// --cap-drop ALL is intentionally omitted: --privileged already
			// grants every capability regardless, so pairing the two is
			// only confusing, never more restrictive.
			args = append(args, "--privileged")
		} else {
			// Verified interactively against mindforge/lab-docker (docker:*-
			// dind-rootless): SYS_ADMIN + /dev/fuse alone is NOT enough.
			// Rootless dockerd's startup calls newuidmap/newgidmap (setuid-
			// root helpers) to build its user-namespace UID/GID map — those
			// need real SETUID/SETGID capabilities, not just SYS_ADMIN, or
			// they fail with "operation not permitted" even though
			// --cap-drop ALL was already lifted for SYS_ADMIN. And
			// rootlesskit's default vpnkit network driver creates a tap
			// interface at startup, which needs /dev/net/tun — without it
			// dockerd never reaches a running state (fails in rootlesskit's
			// child setup, not a dockerd-level error).
			args = append(args,
				"--cap-drop", "ALL",
				"--cap-add", "SYS_ADMIN",
				"--cap-add", "SETUID",
				"--cap-add", "SETGID",
				"--device", "/dev/fuse",
				"--device", "/dev/net/tun",
				"--security-opt", "seccomp=unconfined",
				"--security-opt", "apparmor=unconfined",
			)
		}
	default:
		args = append(args, "--cap-drop", "ALL", "--security-opt", "no-new-privileges")
	}

	return append(args, "--network", network, "--restart", "no", image)
}

// startNamed provisions the named container, retrying once with --privileged
// for "rootless-dind" images when the scoped capability set fails. That
// scoped set is the correct, tightest grant on a real Linux Docker Engine
// host — the ordinary case, and where this retry never triggers. It only
// fails on hosts where /var/run/docker.sock is itself a proxy rather than
// the real daemon socket (Docker Desktop for Windows/Mac route requests
// through their own docker.proxy.sock, which silently drops this specific
// device/capability combination — verified interactively: the identical
// `docker run` succeeds every time from the real host CLI and fails
// identically every time through the proxied socket, both against the same
// daemon). --privileged is a strict superset of the scoped grant that the
// proxy does forward correctly, so it's a safe, self-detecting fallback
// rather than a config flag someone has to remember to set per host.
// "sysbox-runc" and the standard profile never retry.
func (c *DockerContainerService) startNamed(ctx context.Context, name, image, setupScript string) (containerID, containerHost string, err error) {
	containerID, containerHost, err = c.startNamedWithMode(ctx, name, image, setupScript, false)
	if err != nil && c.Classify(image).DockerMechanism == "rootless-dind" {
		containerID, containerHost, err = c.startNamedWithMode(ctx, name, image, setupScript, true)
	}
	return containerID, containerHost, err
}

func (c *DockerContainerService) startNamedWithMode(ctx context.Context, name, image, setupScript string, privileged bool) (containerID, containerHost string, err error) {
	args := c.buildRunArgs(name, image, privileged)

	out, err := runCmd(ctx, "docker", args...)
	if err != nil {
		return "", "", fmt.Errorf("labs.DockerContainerService.Start: docker run: %w", err)
	}
	containerID = strings.TrimSpace(out)

	if setupScript != "" {
		escaped := strings.ReplaceAll(setupScript, "'", "'\\''")
		cmd := fmt.Sprintf("timeout 120 bash -c '%s'", escaped)

		var setupErr error
	retryLoop:
		for attempt := 1; attempt <= setupScriptRetryAttempts; attempt++ {
			_, setupErr = runCmd(ctx, "docker", "exec", "--user", "root", containerID, "bash", "-c", cmd)
			if setupErr == nil {
				break
			}
			if attempt < setupScriptRetryAttempts {
				select {
				case <-time.After(setupScriptRetryDelay):
				case <-ctx.Done():
					setupErr = ctx.Err()
					break retryLoop
				}
			}
		}
		if setupErr != nil {
			_ = c.Kill(context.Background(), containerID)
			return "", "", fmt.Errorf("labs.DockerContainerService.Start: setup script (after %d attempts): %w", setupScriptRetryAttempts, setupErr)
		}
	}

	// `docker run -d` prints the full 64-char ID and nothing else, but this
	// runs inside a fire-and-forget provisioning goroutine — a slice on a
	// short/garbled value would panic the whole API process rather than fail
	// one session. Validate instead of slicing blind.
	if len(containerID) < 12 {
		_ = c.Kill(context.Background(), containerID)
		return "", "", fmt.Errorf("labs.DockerContainerService.Start: docker run returned an unusable container id %q", containerID)
	}

	containerHost = fmt.Sprintf("%s:7681", containerID[:12])
	return containerID, containerHost, nil
}

// Kill force-removes a container by ID.
func (c *DockerContainerService) Kill(ctx context.Context, containerID string) error {
	if _, err := runCmd(ctx, "docker", "rm", "-f", containerID); err != nil {
		return fmt.Errorf("labs.DockerContainerService.Kill: %w", err)
	}
	return nil
}

// Pause suspends a running container (SIGSTOP on the whole process tree via
// the freezer cgroup), freeing CPU while keeping memory, disk and process
// state intact. This is what lab.expire_sessions does to an idle session
// instead of destroying it.
func (c *DockerContainerService) Pause(ctx context.Context, containerID string) error {
	if _, err := runCmd(ctx, "docker", "pause", containerID); err != nil {
		return fmt.Errorf("labs.DockerContainerService.Pause: %w", err)
	}
	return nil
}

// Unpause resumes a paused container.
func (c *DockerContainerService) Unpause(ctx context.Context, containerID string) error {
	if _, err := runCmd(ctx, "docker", "unpause", containerID); err != nil {
		return fmt.Errorf("labs.DockerContainerService.Unpause: %w", err)
	}
	return nil
}

// Exec runs a script inside the container as labuser. stdout and stderr are
// captured separately and each bounded at MaxExecOutputBytes — see
// boundedBuffer for why silently truncating beats erroring here.
// exitCode is 0 on success; a process exit error yields the real exit code
// without propagating an error value.
func (c *DockerContainerService) Exec(ctx context.Context, containerID, script string, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
	return c.execWithStdin(ctx, containerID, script, nil, timeoutSec)
}

// ExecStdin is Exec plus a piped stdin payload — see ContainerRuntime's doc
// comment for why WriteFile uses this instead of embedding content in the
// script string.
func (c *DockerContainerService) ExecStdin(ctx context.Context, containerID, script string, stdin []byte, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
	return c.execWithStdin(ctx, containerID, script, stdin, timeoutSec)
}

func (c *DockerContainerService) execWithStdin(ctx context.Context, containerID, script string, stdin []byte, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
	escaped := strings.ReplaceAll(script, "'", "'\\''")
	args := []string{"exec"}
	if stdin != nil {
		args = append(args, "-i")
	}
	args = append(args, "--user", "labuser", containerID,
		"bash", "-c", fmt.Sprintf("timeout %d bash -c '%s'", timeoutSec, escaped))
	cmd := exec.CommandContext(ctx, "docker", args...)
	if stdin != nil {
		cmd.Stdin = bytes.NewReader(stdin)
	}
	outBuf, errBuf := newBoundedBuffer(), newBoundedBuffer()
	cmd.Stdout = outBuf
	cmd.Stderr = errBuf
	err = cmd.Run()
	stdout = outBuf.String()
	stderr = errBuf.String()
	if err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			return stdout, stderr, exitErr.ExitCode(), nil
		}
		return stdout, stderr, -1, fmt.Errorf("labs.DockerContainerService.Exec: %w", err)
	}
	return stdout, stderr, 0, nil
}

// boundedBuffer accumulates at most MaxExecOutputBytes and silently discards
// the rest, appending a truncation marker when it does.
//
// Discarding rather than erroring is deliberate: os/exec and the Kubernetes
// SPDY executor both copy the child's output through this Writer, and a Write
// that returns an error aborts that copy — which leaves the child blocked on
// a full pipe until its `timeout` kills it, turning a large-output script
// into a guaranteed 10-second stall. Absorbing everything and keeping only
// the head lets the command finish immediately and still yields the part a
// human would actually read.
type boundedBuffer struct {
	buf       bytes.Buffer
	truncated bool
}

func newBoundedBuffer() *boundedBuffer { return &boundedBuffer{} }

func (b *boundedBuffer) Write(p []byte) (int, error) {
	if room := MaxExecOutputBytes - b.buf.Len(); room > 0 {
		if len(p) <= room {
			return b.buf.Write(p)
		}
		if _, err := b.buf.Write(p[:room]); err != nil {
			return 0, err
		}
	}
	b.truncated = true
	return len(p), nil
}

func (b *boundedBuffer) String() string {
	if b.truncated {
		return b.buf.String() + "\n…(output truncated)"
	}
	return b.buf.String()
}

// IsRunning reports whether the container is currently in the running state.
func (c *DockerContainerService) IsRunning(ctx context.Context, containerID string) bool {
	out, err := runCmd(ctx, "docker", "inspect", "--format", "{{.State.Running}}", containerID)
	if err != nil {
		return false
	}
	return strings.TrimSpace(out) == "true"
}

// dockerPSCreatedAtLayouts are the layouts `docker ps --format {{.CreatedAt}}`
// is known to emit: `T.Format("2006-01-02 15:04:05 -0700 MST")` — Go's
// default time.Time string layout without the sub-second component most
// builds omit, but a couple of nearby variants are included defensively
// since the exact precision has drifted across Docker CLI versions. This is
// NOT RFC3339 (no "T" separator, space before the zone) — parsing it as
// RFC3339 (the previous code) always failed, silently zeroing CreatedAt to
// the Go zero value on every container, which made every "is this container
// too young to touch yet" guard in jobs/handlers/labs.go permanently false
// (a zero-value timestamp is always "more than 2 minutes old").
var dockerPSCreatedAtLayouts = []string{
	"2006-01-02 15:04:05 -0700 MST",
	"2006-01-02 15:04:05.999999999 -0700 MST",
}

func parseDockerPSCreatedAt(s string) (time.Time, error) {
	var lastErr error
	for _, layout := range dockerPSCreatedAtLayouts {
		if t, err := time.Parse(layout, s); err == nil {
			return t, nil
		} else {
			lastErr = err
		}
	}
	return time.Time{}, fmt.Errorf("unrecognized docker ps CreatedAt format %q: %w", s, lastErr)
}

// List returns every container (running or stopped) whose name starts with
// namePrefix, for LabCleanupHandler's orphan scan.
func (c *DockerContainerService) List(ctx context.Context, namePrefix string) ([]ContainerInfo, error) {
	out, err := runCmd(ctx, "docker", "ps", "-a",
		"--filter", "name="+namePrefix,
		"--format", "{{.Names}}\t{{.ID}}\t{{.CreatedAt}}",
	)
	if err != nil {
		return nil, fmt.Errorf("labs.DockerContainerService.List: %w", err)
	}
	var infos []ContainerInfo
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "\t", 3)
		if len(parts) != 3 {
			continue
		}
		createdAt, parseErr := parseDockerPSCreatedAt(parts[2])
		if parseErr != nil {
			// Fail toward "just created" rather than "ancient": the only
			// consumer of CreatedAt is a young-container skip-removal guard,
			// so treating an unparseable timestamp as now() means this tick
			// leaves the container alone instead of risking removal of one
			// that's actually still mid-creation. It will be re-evaluated
			// (and, if genuinely orphaned, removed) on the next tick.
			createdAt = time.Now()
		}
		infos = append(infos, ContainerInfo{Name: parts[0], ID: parts[1], CreatedAt: createdAt})
	}
	return infos, nil
}

// runCmd runs a command and returns its stdout. Stderr is captured and folded
// into the returned error so Docker's actual failure reason reaches the
// application logs instead of a bare "exit status 1".
func runCmd(ctx context.Context, name string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	var outBuf, errBuf bytes.Buffer
	cmd.Stdout = &outBuf
	cmd.Stderr = &errBuf
	if err := cmd.Run(); err != nil {
		if stderr := strings.TrimSpace(errBuf.String()); stderr != "" {
			return "", fmt.Errorf("%w: %s", err, stderr)
		}
		return "", err
	}
	return outBuf.String(), nil
}
