package labs

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
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
	limits   RuntimeLimits
	network  NetworkPolicy
}

// RuntimeLimits are the per-container resource caps every lab container gets
// on top of --cpus/--memory (audit H-12). Zero PidsLimit falls back to
// DefaultContainerPidsLimit; an ImageProfile.PidsLimit overrides it per image.
type RuntimeLimits struct {
	PidsLimit int
}

// NetworkPolicy decides how lab containers are networked (audit H-13).
// Docker's inter-container-connectivity switch cannot be used on the shared
// bridge because labproxy is itself a container on it, so isolation is done
// with one network per session instead: the session container is the only
// member besides labproxy.
type NetworkPolicy struct {
	// PerSession gives every non-profile-networked container its own network
	// (named after the container) and attaches ProxyContainer to it.
	PerSession bool
	// Internal creates those networks with --internal: no egress at all.
	Internal bool
	// ProxyContainer is the labproxy container joined to each session network.
	ProxyContainer string
}

// SetHardening applies resource limits and network policy. Separate from the
// constructor so existing callers (coursegen) keep the default shared-bridge
// behaviour.
func (c *DockerContainerService) SetHardening(l RuntimeLimits, n NetworkPolicy) {
	c.limits, c.network = l, n
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

// Start provisions a new Docker container for the given lab session. See
// ContainerRuntime.Start — readiness waiting and lab setup are the caller's,
// not this method's.
func (c *DockerContainerService) Start(ctx context.Context, sessionID string, resetCount int, image string) (containerID, containerHost string, err error) {
	return c.startNamed(ctx, fmt.Sprintf("mindforge-lab-%s-%d", sessionID, resetCount), image)
}

// StartWarm provisions an unbound warm-pool sandbox. See ContainerRuntime.
func (c *DockerContainerService) StartWarm(ctx context.Context, warmID string, image string) (containerID, containerHost string, err error) {
	return c.startNamed(ctx, WarmContainerNamePrefix+warmID, image)
}

// StartValidation provisions a validation/clean-room sandbox. See ContainerRuntime.
func (c *DockerContainerService) StartValidation(ctx context.Context, id string, image string) (containerID, containerHost string, err error) {
	return c.startNamed(ctx, ValidationContainerNamePrefix+id, image)
}

// buildRunArgs is the pure "what flags does this container get" decision,
// pulled out of startNamed so the profile-driven branch is unit-testable
// without shelling out to a real Docker daemon — this is the single place
// that decides whether a container is elevated, so it gets its own tests
// asserting standard-profile output is untouched and each DockerMechanism
// has exactly the documented flags (see docs/labs.md "Nested Docker labs").
// --privileged is never emitted (audit H-11): a start that the scoped
// capability set cannot satisfy fails closed instead of being retried with
// every capability.
func (c *DockerContainerService) buildRunArgs(name, image string) []string {
	profile := c.Classify(image)

	cpu := profile.CPU
	if cpu == "" {
		cpu = ContainerCPU
	}
	memMB := profile.MemoryMB
	if memMB == 0 {
		memMB = ContainerMemoryMB
	}
	network := c.networkFor(name, profile)
	pids := profile.PidsLimit
	if pids == 0 {
		pids = c.limits.PidsLimit
	}
	if pids == 0 {
		pids = DefaultContainerPidsLimit
	}
	mem := fmt.Sprintf("%dm", memMB)

	// --memory-swap == --memory disables swap; pids/ulimits bound fork bombs
	// and fd exhaustion. A read-only rootfs and --storage-opt size are NOT
	// set: lab setup scripts install packages as root and storage-opt needs
	// an xfs/pquota host (see docs/labs.md).
	args := []string{"run", "-d", "--name", name, "--cpus", cpu, "--memory", mem, "--memory-swap", mem,
		"--pids-limit", strconv.Itoa(pids),
		"--ulimit", fmt.Sprintf("nofile=%d:%d", ContainerNofileLimit, ContainerNofileLimit),
		"--ulimit", "core=0"}

	switch profile.DockerMechanism {
	case "sysbox-runc":
		// No added capabilities at all — the preferred elevation mechanism
		// when the host has sysbox-runc installed.
		args = append(args, "--cap-drop", "ALL", "--runtime", "sysbox-runc")
	case "rootless-dind":
		// Nested Docker-in-Docker: this container is treated as potentially
		// host-root (see docs/labs.md "Nested Docker labs" for the residual
		// risk this does NOT eliminate).
		//
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
		// child setup, not a dockerd-level error). NET_ADMIN is separate
		// from all of that: it's not needed to start the nested dockerd,
		// only for the containers *it* then creates — libnetwork needs
		// it to configure a new container's veth/sysctls (e.g. disabling
		// IPv6 on eth0), and without it every `docker run` a student
		// issues inside the lab fails at that step, not at dockerd
		// startup.
		args = append(args,
			"--cap-drop", "ALL",
			"--cap-add", "SYS_ADMIN",
			"--cap-add", "SETUID",
			"--cap-add", "SETGID",
			"--cap-add", "NET_ADMIN",
			"--device", "/dev/fuse",
			"--device", "/dev/net/tun",
			"--security-opt", "seccomp=unconfined",
			"--security-opt", "apparmor=unconfined",
		)
	default:
		args = append(args, "--cap-drop", "ALL", "--security-opt", "no-new-privileges")
	}

	return append(args, "--network", network, "--restart", "no", image)
}

// networkFor returns the network a container joins: the profile's own
// network if set, else the per-session network when enabled, else the shared
// bridge.
func (c *DockerContainerService) networkFor(name string, profile ImageProfile) string {
	switch {
	case profile.Network != "":
		return profile.Network
	case c.network.PerSession:
		return name
	default:
		return SharedLabNetwork
	}
}

// usesSessionNetwork reports whether name's network is created per session.
func (c *DockerContainerService) usesSessionNetwork(name string, profile ImageProfile) bool {
	return c.network.PerSession && c.networkFor(name, profile) == name
}

// sessionNetworkCreateArgs / sessionNetworkConnectArgs are the pure argument
// builders for the per-session network lifecycle.
func (c *DockerContainerService) sessionNetworkCreateArgs(name string) []string {
	args := []string{"network", "create", "--label", SessionNetworkLabel}
	if c.network.Internal {
		args = append(args, "--internal")
	}
	return append(args, name)
}

func (c *DockerContainerService) sessionNetworkConnectArgs(name string) []string {
	return []string{"network", "connect", name, c.network.ProxyContainer}
}

// startNamed provisions the named container. There is deliberately no
// --privileged retry (audit H-11): if the scoped capability set cannot start
// the container the error is returned as-is. Docker Desktop's proxied socket
// drops the nested-docker device/capability combination, so nested labs are
// unsupported there — run them on a real Docker Engine host (or sysbox).
func (c *DockerContainerService) startNamed(ctx context.Context, name, image string) (containerID, containerHost string, err error) {
	profile := c.Classify(image)
	perSession := c.usesSessionNetwork(name, profile)
	if perSession {
		if c.network.ProxyContainer == "" {
			return "", "", errors.New("labs.DockerContainerService.Start: per-session networks need LABS_PROXY_CONTAINER")
		}
		if _, err := runCmd(ctx, "docker", c.sessionNetworkCreateArgs(name)...); err != nil {
			return "", "", fmt.Errorf("labs.DockerContainerService.Start: network create: %w", err)
		}
		if _, err := runCmd(ctx, "docker", c.sessionNetworkConnectArgs(name)...); err != nil {
			c.removeNetwork(name)
			return "", "", fmt.Errorf("labs.DockerContainerService.Start: network connect proxy: %w", err)
		}
	}

	out, err := runCmd(ctx, "docker", c.buildRunArgs(name, image)...)
	if err != nil {
		if perSession {
			c.removeNetwork(name)
		}
		return "", "", fmt.Errorf("labs.DockerContainerService.Start: docker run: %w", err)
	}
	containerID = strings.TrimSpace(out)

	// `docker run -d` prints the full 64-char ID and nothing else, but this
	// runs inside a fire-and-forget provisioning goroutine — a slice on a
	// short/garbled value would panic the whole API process rather than fail
	// one session. Validate instead of slicing blind.
	if len(containerID) < 12 {
		_ = c.Kill(context.Background(), containerID)
		if perSession {
			c.removeNetwork(name)
		}
		return "", "", fmt.Errorf("labs.DockerContainerService.Start: docker run returned an unusable container id %q", containerID)
	}

	containerHost = fmt.Sprintf("%s:7681", containerID[:12])
	return containerID, containerHost, nil
}

// removeNetwork best-effort removes a per-session network; the proxy is
// disconnected first because a network with an attached endpoint cannot be
// removed.
func (c *DockerContainerService) removeNetwork(name string) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if c.network.ProxyContainer != "" {
		_, _ = runCmd(ctx, "docker", "network", "disconnect", "-f", name, c.network.ProxyContainer)
	}
	_, _ = runCmd(ctx, "docker", "network", "rm", name)
}

// Kill force-removes a container by ID.
// With per-session networks enabled the container's own network (named after
// the container) is removed too.
func (c *DockerContainerService) Kill(ctx context.Context, containerID string) error {
	var name string
	if c.network.PerSession {
		if out, err := runCmd(ctx, "docker", "inspect", "--format", "{{.Name}}", containerID); err == nil {
			name = strings.TrimPrefix(strings.TrimSpace(out), "/")
		}
	}
	if _, err := runCmd(ctx, "docker", "rm", "-f", containerID); err != nil {
		return fmt.Errorf("labs.DockerContainerService.Kill: %w", err)
	}
	if name != "" {
		c.removeNetwork(name)
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

// ExecSetup runs a lab's setup_script as root. See ContainerRuntime.ExecSetup
// for why this is a separate method from Exec rather than a flag on it.
func (c *DockerContainerService) ExecSetup(ctx context.Context, containerID, script string, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
	return c.execAs(ctx, "root", containerID, script, nil, timeoutSec)
}

// ExecCapture runs script as labuser with a caller-chosen output cap (see
// ContainerRuntime.ExecCapture). No `timeout` wrapper: the caller's ctx
// bounds it. Trusted callers only.
func (c *DockerContainerService) ExecCapture(ctx context.Context, containerID, script string, maxBytes int) (stdout, stderr string, exitCode int, err error) {
	cmd := exec.CommandContext(ctx, "docker", "exec", "--user", "labuser", containerID, "bash", "-c", script)
	outBuf, errBuf := newBoundedBufferN(maxBytes), newBoundedBufferN(MaxExecOutputBytes)
	cmd.Stdout = outBuf
	cmd.Stderr = errBuf
	err = cmd.Run()
	stdout, stderr = outBuf.String(), errBuf.String()
	if err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			return stdout, stderr, exitErr.ExitCode(), nil
		}
		return stdout, stderr, -1, fmt.Errorf("labs.DockerContainerService.ExecCapture: %w", err)
	}
	return stdout, stderr, 0, nil
}

func (c *DockerContainerService) execWithStdin(ctx context.Context, containerID, script string, stdin []byte, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
	return c.execAs(ctx, "labuser", containerID, script, stdin, timeoutSec)
}

func (c *DockerContainerService) execAs(ctx context.Context, user, containerID, script string, stdin []byte, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
	escaped := strings.ReplaceAll(script, "'", "'\\''")
	args := []string{"exec"}
	if stdin != nil {
		args = append(args, "-i")
	}
	args = append(args, "--user", user, containerID,
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
	limit     int
}

func newBoundedBuffer() *boundedBuffer { return newBoundedBufferN(MaxExecOutputBytes) }

func newBoundedBufferN(limit int) *boundedBuffer { return &boundedBuffer{limit: limit} }

func (b *boundedBuffer) Write(p []byte) (int, error) {
	if room := b.limit - b.buf.Len(); room > 0 {
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
