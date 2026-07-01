package labs

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os/exec"
	"strings"
)

// ContainerService manages Docker containers for lab sessions via the Docker CLI.
type ContainerService struct{}

// NewContainerService returns a ContainerService backed by the local Docker daemon.
func NewContainerService() *ContainerService { return &ContainerService{} }

// Start provisions a new Docker container for the given lab session and runs the
// optional setup script inside it as root. On setup failure the container is
// force-removed before the error is returned.
func (c *ContainerService) Start(ctx context.Context, sessionID string, resetCount int, image, setupScript string) (containerID, containerHost string, err error) {
	name := fmt.Sprintf("mindforge-lab-%s-%d", sessionID, resetCount)
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
		return "", "", fmt.Errorf("labs.ContainerService.Start: docker run: %w", err)
	}
	containerID = strings.TrimSpace(out)

	if setupScript != "" {
		escaped := strings.ReplaceAll(setupScript, "'", "'\\''")
		_, err = runCmd(ctx, "docker", "exec", "--user", "root", containerID,
			"bash", "-c", fmt.Sprintf("timeout 120 bash -c '%s'", escaped))
		if err != nil {
			_ = c.Kill(context.Background(), containerID)
			return "", "", fmt.Errorf("labs.ContainerService.Start: setup script: %w", err)
		}
	}

	containerHost = fmt.Sprintf("%s:7681", containerID[:12])
	return containerID, containerHost, nil
}

// Kill force-removes a container by ID.
func (c *ContainerService) Kill(ctx context.Context, containerID string) error {
	if _, err := runCmd(ctx, "docker", "rm", "-f", containerID); err != nil {
		return fmt.Errorf("labs.ContainerService.Kill: %w", err)
	}
	return nil
}

// Pause suspends a running container.
func (c *ContainerService) Pause(ctx context.Context, containerID string) error {
	if _, err := runCmd(ctx, "docker", "pause", containerID); err != nil {
		return fmt.Errorf("labs.ContainerService.Pause: %w", err)
	}
	return nil
}

// Unpause resumes a paused container.
func (c *ContainerService) Unpause(ctx context.Context, containerID string) error {
	if _, err := runCmd(ctx, "docker", "unpause", containerID); err != nil {
		return fmt.Errorf("labs.ContainerService.Unpause: %w", err)
	}
	return nil
}

// Exec runs a script inside the container as labuser. stdout and stderr are
// captured separately. exitCode is 0 on success; a process exit error yields
// the real exit code without propagating an error value.
func (c *ContainerService) Exec(ctx context.Context, containerID, script string, timeoutSec int) (stdout, stderr string, exitCode int, err error) {
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
		return stdout, stderr, -1, fmt.Errorf("labs.ContainerService.Exec: %w", err)
	}
	return stdout, stderr, 0, nil
}

// IsRunning reports whether the container is currently in the running state.
func (c *ContainerService) IsRunning(ctx context.Context, containerID string) bool {
	out, err := runCmd(ctx, "docker", "inspect", "--format", "{{.State.Running}}", containerID)
	if err != nil {
		return false
	}
	return strings.TrimSpace(out) == "true"
}

// runCmd runs a command and returns its stdout. Stderr is inherited by the
// process so Docker error output appears in application logs.
func runCmd(ctx context.Context, name string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	var outBuf bytes.Buffer
	cmd.Stdout = &outBuf
	if err := cmd.Run(); err != nil {
		return "", err
	}
	return outBuf.String(), nil
}
