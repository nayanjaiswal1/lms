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
type DockerContainerService struct{}

// NewDockerContainerService returns a DockerContainerService backed by the local Docker daemon.
func NewDockerContainerService() *DockerContainerService { return &DockerContainerService{} }

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

func (c *DockerContainerService) startNamed(ctx context.Context, name, image, setupScript string) (containerID, containerHost string, err error) {
	args := []string{
		"run", "-d",
		"--name", name,
		"--cpus", ContainerCPU,
		"--memory", fmt.Sprintf("%dm", ContainerMemoryMB),
		"--cap-drop", "ALL",
		"--security-opt", "no-new-privileges",
		"--network", "mindforge-labs",
		"--restart", "no",
		image,
	}
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

// Pause suspends a running container.
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
// captured separately. exitCode is 0 on success; a process exit error yields
// the real exit code without propagating an error value.
func (c *DockerContainerService) Exec(ctx context.Context, containerID, script string, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
	escaped := strings.ReplaceAll(script, "'", "'\\''")
	cmd := exec.CommandContext(ctx, "docker", "exec", "--user", "labuser", containerID,
		"bash", "-c", fmt.Sprintf("timeout %d bash -c '%s'", timeoutSec, escaped))
	var outBuf, errBuf bytes.Buffer
	cmd.Stdout = &outBuf
	cmd.Stderr = &errBuf
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

// IsRunning reports whether the container is currently in the running state.
func (c *DockerContainerService) IsRunning(ctx context.Context, containerID string) bool {
	out, err := runCmd(ctx, "docker", "inspect", "--format", "{{.State.Running}}", containerID)
	if err != nil {
		return false
	}
	return strings.TrimSpace(out) == "true"
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
		createdAt, parseErr := time.Parse(time.RFC3339, parts[2])
		if parseErr != nil {
			createdAt = time.Time{}
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
