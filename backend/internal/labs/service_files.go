package labs

import (
	"context"
	"encoding/json"
	"fmt"
	"path"
	"strings"
)

// labWorkdir is the fixed directory inside every terminal/guided lab
// container where starter files are written (see the fixture generator's
// setup_script heredocs) and where students create/edit/delete their own
// files. It matches lab-images/lab-k8s's labuser home layout.
const labWorkdir = "/home/labuser/work"

const fileExecTimeoutSec = 10
const resourcesExecTimeoutSec = 15

// LabFileEntry is one row of a ListFiles response.
type LabFileEntry struct {
	Path string `json:"path"` // relative to labWorkdir, forward-slash separated
	Type string `json:"type"` // "file" or "dir"
}

// ValidateResult is the response shape for ValidateFile.
type ValidateResult struct {
	Valid  bool   `json:"valid"`
	Stdout string `json:"stdout,omitempty"`
	Stderr string `json:"stderr,omitempty"`
}

// resolveWorkdirPath validates a client-supplied relative path and returns
// it cleaned, guaranteeing it can never resolve outside labWorkdir once
// joined. Rejects: empty paths, absolute paths, and any ".." segment that
// would traverse above labWorkdir (including via "." segments or repeated
// slashes designed to obscure the traversal).
func resolveWorkdirPath(rel string) (string, error) {
	if strings.TrimSpace(rel) == "" {
		return "", fmt.Errorf("%w: path is required", ErrInvalidPath)
	}
	if path.IsAbs(rel) {
		return "", fmt.Errorf("%w: path must be relative", ErrInvalidPath)
	}
	cleaned := path.Clean(rel)
	if cleaned == "." || cleaned == ".." || cleaned == "/" ||
		strings.HasPrefix(cleaned, "../") || strings.HasPrefix(cleaned, "/") {
		return "", fmt.Errorf("%w: path escapes the lab workdir", ErrInvalidPath)
	}
	return cleaned, nil
}

// containerPath joins a resolveWorkdirPath-validated relative path onto
// labWorkdir for use inside a container-exec'd shell command.
func containerPath(rel string) string {
	return labWorkdir + "/" + rel
}

// hasKubectl reports whether a lab's environment image bundles kubectl and a
// local cluster (see docs/labs.md: "mindforge/lab-k8s — kubectl, minikube").
// Every other environment (mindforge/lab-docker, lab-node-web, lab-linux,
// piston:*, ...) is a plain container with no cluster to query — ValidateFile
// and GetResources are meaningless there and must be gated on this rather
// than attempted unconditionally.
func hasKubectl(environment string) bool {
	return strings.Contains(environment, "k8s")
}

// shellQuote wraps s in single quotes for safe embedding as one shell
// argument, matching the escaping ContainerService.Start/Exec already use
// for setup_script/verification_script bodies.
func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
}

// loadRunnableSession is the shared precondition for every file-ops method:
// IDOR-checked session lookup, expiry/status check + idle-heartbeat bump
// (requireSessionLive), and paused-container auto-resume — the same
// sequence VerifyTask's dispatcher and verifyContainerTask already apply to
// verification.
func (s *Service) loadRunnableSession(ctx context.Context, sessionID, userID string) (*LabSession, error) {
	session, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}
	if err := s.requireSessionLive(ctx, session); err != nil {
		return nil, err
	}
	// requireSessionLive alone would also accept 'provisioning' (no container
	// yet) — file ops need a container to exec into, so narrow further here
	// rather than let a nil-container case surface as a generic 500 out of
	// ensureContainerResumed's guard.
	if session.Status != SessionStatusRunning && session.Status != SessionStatusPaused {
		return nil, ErrSessionNotRunning
	}
	if err := s.ensureContainerResumed(ctx, session); err != nil {
		return nil, fmt.Errorf("labs.Service: %w", err)
	}
	return session, nil
}

// ─── ListFiles ────────────────────────────────────────────────────────────────

// ListFiles returns every file and directory under the session's workdir.
func (s *Service) ListFiles(ctx context.Context, sessionID, userID string) ([]LabFileEntry, error) {
	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}

	// `find -printf` is GNU-only — lab images built on Alpine/BusyBox (e.g.
	// mindforge/lab-docker) reject the flag outright ("unrecognized: -printf"),
	// so every call failed on those images. `-mindepth` and a `while read`
	// loop are POSIX/BusyBox-safe and work identically on GNU find.
	script := fmt.Sprintf(
		`cd %s && mkdir -p %s && find . -mindepth 1 | while IFS= read -r f; do rel=${f#./}; if [ -d "$f" ]; then echo "d $rel"; else echo "f $rel"; fi; done`,
		shellQuote(labWorkdir), shellQuote(labWorkdir),
	)
	stdout, stderr, exitCode, err := s.container.Exec(ctx, *session.ContainerID, script, fileExecTimeoutSec)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.ListFiles: exec: %w", err)
	}
	if exitCode != 0 {
		return nil, fmt.Errorf("labs.Service.ListFiles: find failed: %s", stderr)
	}

	entries := []LabFileEntry{}
	for _, line := range strings.Split(strings.TrimRight(stdout, "\n"), "\n") {
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, " ", 2)
		if len(parts) != 2 {
			continue
		}
		typ := "file"
		if parts[0] == "d" {
			typ = "dir"
		}
		entries = append(entries, LabFileEntry{Path: parts[1], Type: typ})
	}
	return entries, nil
}

// ─── ReadFile ─────────────────────────────────────────────────────────────────

// ReadFile returns the content of a file under the session's workdir.
func (s *Service) ReadFile(ctx context.Context, sessionID, userID, relPath string) (string, error) {
	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return "", err
	}
	rel, err := resolveWorkdirPath(relPath)
	if err != nil {
		return "", err
	}

	script := fmt.Sprintf("cat %s", shellQuote(containerPath(rel)))
	stdout, stderr, exitCode, err := s.container.Exec(ctx, *session.ContainerID, script, fileExecTimeoutSec)
	if err != nil {
		return "", fmt.Errorf("labs.Service.ReadFile: exec: %w", err)
	}
	if exitCode != 0 {
		return "", fmt.Errorf("labs.Service.ReadFile: %w: %s", ErrNotFound, stderr)
	}
	return stdout, nil
}

// ─── WriteFile ────────────────────────────────────────────────────────────────

// WriteFile creates or overwrites a file under the session's workdir with
// content, creating any missing parent directories.
func (s *Service) WriteFile(ctx context.Context, sessionID, userID, relPath, content string) error {
	if len(content) > MaxWriteFileBytes {
		return ErrContentTooLarge
	}

	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return err
	}
	rel, err := resolveWorkdirPath(relPath)
	if err != nil {
		return err
	}

	full := containerPath(rel)
	dir := path.Dir(full)
	// Content travels over stdin, never embedded in the command string. The
	// old heredoc body (`cat > FILE <<'EOF' ... EOF`) put student content
	// directly into the script text: a quoted heredoc delimiter disables
	// shell *expansion* ($VARS, backticks) but not the delimiter itself — a
	// file containing a line reading exactly "MF_LABFILE_EOF" closed the
	// heredoc early, truncating the file and running the remainder of that
	// line as a shell command. Piping via ExecStdin has no delimiter to
	// collide with (script itself contains only the already-shellQuote'd
	// dir/file paths, never content) and no host execve() argument-length
	// ceiling to hit either — content this size would already have exceeded
	// Linux's ~128KB single-argv-string limit if embedded, which a base64-
	// in-argv version of this fix would still have hit for any file above
	// roughly 90KB.
	script := fmt.Sprintf("mkdir -p %s && cat > %s", shellQuote(dir), shellQuote(full))
	_, stderr, exitCode, err := s.container.ExecStdin(ctx, *session.ContainerID, script, []byte(content), fileExecTimeoutSec)
	if err != nil {
		return fmt.Errorf("labs.Service.WriteFile: exec: %w", err)
	}
	if exitCode != 0 {
		return fmt.Errorf("labs.Service.WriteFile: write failed: %s", stderr)
	}
	return nil
}

// ─── CreateDirectory ────────────────────────────────────────────────────────

// CreateDirectory makes an empty directory (and any missing parents) under
// the session's workdir.
func (s *Service) CreateDirectory(ctx context.Context, sessionID, userID, relPath string) error {
	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return err
	}
	rel, err := resolveWorkdirPath(relPath)
	if err != nil {
		return err
	}

	script := fmt.Sprintf("mkdir -p %s", shellQuote(containerPath(rel)))
	_, stderr, exitCode, err := s.container.Exec(ctx, *session.ContainerID, script, fileExecTimeoutSec)
	if err != nil {
		return fmt.Errorf("labs.Service.CreateDirectory: exec: %w", err)
	}
	if exitCode != 0 {
		return fmt.Errorf("labs.Service.CreateDirectory: mkdir failed: %s", stderr)
	}
	return nil
}

// ─── RenameFile ───────────────────────────────────────────────────────────────

// RenameFile moves a file from one path to another within the session's
// workdir, creating any missing parent directory for the destination.
func (s *Service) RenameFile(ctx context.Context, sessionID, userID, fromPath, toPath string) error {
	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return err
	}
	from, err := resolveWorkdirPath(fromPath)
	if err != nil {
		return err
	}
	to, err := resolveWorkdirPath(toPath)
	if err != nil {
		return err
	}

	fullFrom, fullTo := containerPath(from), containerPath(to)
	script := fmt.Sprintf("mkdir -p %s && mv %s %s", shellQuote(path.Dir(fullTo)), shellQuote(fullFrom), shellQuote(fullTo))
	_, stderr, exitCode, err := s.container.Exec(ctx, *session.ContainerID, script, fileExecTimeoutSec)
	if err != nil {
		return fmt.Errorf("labs.Service.RenameFile: exec: %w", err)
	}
	if exitCode != 0 {
		return fmt.Errorf("labs.Service.RenameFile: %w: %s", ErrNotFound, stderr)
	}
	return nil
}

// ─── DeleteFile ───────────────────────────────────────────────────────────────

// DeleteFile removes a file (or empty/non-empty directory) under the
// session's workdir.
func (s *Service) DeleteFile(ctx context.Context, sessionID, userID, relPath string) error {
	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return err
	}
	rel, err := resolveWorkdirPath(relPath)
	if err != nil {
		return err
	}

	script := fmt.Sprintf("rm -rf %s", shellQuote(containerPath(rel)))
	_, stderr, exitCode, err := s.container.Exec(ctx, *session.ContainerID, script, fileExecTimeoutSec)
	if err != nil {
		return fmt.Errorf("labs.Service.DeleteFile: exec: %w", err)
	}
	if exitCode != 0 {
		return fmt.Errorf("labs.Service.DeleteFile: delete failed: %s", stderr)
	}
	return nil
}

// ─── ValidateFile ─────────────────────────────────────────────────────────────

// ValidateFile runs `kubectl apply --dry-run=server` against a manifest file
// already in the session's workdir, validating it against the real
// apiserver schema without applying it. stdout/stderr are always returned
// (regardless of exit code) so the student sees kubectl's real error text.
func (s *Service) ValidateFile(ctx context.Context, sessionID, userID, relPath string) (*ValidateResult, error) {
	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}
	lab, err := s.repo.GetLab(ctx, session.LabID, session.OrgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.ValidateFile: get lab: %w", err)
	}
	if !hasKubectl(lab.Environment) {
		return nil, ErrLabTypeUnsupported
	}
	rel, err := resolveWorkdirPath(relPath)
	if err != nil {
		return nil, err
	}

	script := fmt.Sprintf("kubectl apply --dry-run=server -f %s", shellQuote(containerPath(rel)))
	stdout, stderr, exitCode, err := s.container.Exec(ctx, *session.ContainerID, script, fileExecTimeoutSec)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.ValidateFile: exec: %w", err)
	}
	return &ValidateResult{Valid: exitCode == 0, Stdout: stdout, Stderr: stderr}, nil
}

// ─── GetResources ─────────────────────────────────────────────────────────────

// GetResources runs a broad `kubectl get -A -o json` across the resource
// kinds a student is likely to have created in this lab and returns the raw
// JSON verbatim. Refresh-on-demand only — no watch/stream — matching the
// plan's "don't over-engineer" scope for the resources panel.
func (s *Service) GetResources(ctx context.Context, sessionID, userID string) (json.RawMessage, error) {
	session, err := s.loadRunnableSession(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}
	lab, err := s.repo.GetLab(ctx, session.LabID, session.OrgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.GetResources: get lab: %w", err)
	}
	if !hasKubectl(lab.Environment) {
		return nil, ErrLabTypeUnsupported
	}

	script := "kubectl get all,ns,pv,pvc,cm,secret -A -o json"
	stdout, stderr, exitCode, err := s.container.Exec(ctx, *session.ContainerID, script, resourcesExecTimeoutSec)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.GetResources: exec: %w", err)
	}
	if exitCode != 0 {
		return nil, fmt.Errorf("labs.Service.GetResources: kubectl get failed: %s", stderr)
	}
	if !json.Valid([]byte(stdout)) {
		return nil, fmt.Errorf("labs.Service.GetResources: kubectl returned non-JSON output (%d bytes)", len(stdout))
	}
	return json.RawMessage(stdout), nil
}
