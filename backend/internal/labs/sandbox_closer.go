package labs

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"
)

const (
	// closeCaptureTimeout bounds the whole snapshot of one session — a slow
	// or wedged sandbox must never hold up closing it.
	closeCaptureTimeout = 12 * time.Second
	// closeCaptureConcurrency bounds parallel snapshots when the reaper
	// closes many sessions in one tick.
	closeCaptureConcurrency = 4
)

// studentDiffScript prints the student's tracked changes against baselineRef
// followed by each untracked, non-ignored file as an added file (a new test
// file is part of the fix but invisible to a plain `git diff`), capped at
// MaxStudentDiffBytes. Failures are swallowed: the diff is best-effort.
func studentDiffScript(baselineRef string) string {
	const excludes = `':!.lab' ':!logs'`
	return fmt.Sprintf(`cd %s && { git diff %s -- . %s; git ls-files -z --others --exclude-standard -- . %s | xargs -0 -r -n1 git diff --no-index -- /dev/null; } 2>/dev/null | head -c %d`,
		shellQuote(labWorkdir), baselineRef, excludes, excludes, MaxStudentDiffBytes)
}

// studentDiff returns the student's changes against baselineRef (≤ 8 KB),
// via a bounded, fixed-shape exec. "" when unavailable.
func studentDiff(ctx context.Context, container ContainerRuntime, containerID, baselineRef string) string {
	if containerID == "" || !commitRefRe.MatchString(baselineRef) || !container.IsRunning(ctx, containerID) {
		return ""
	}
	stdout, _, exitCode, err := container.Exec(ctx, containerID, studentDiffScript(baselineRef), diffExecTimeoutSec)
	if err != nil || exitCode != 0 {
		return ""
	}
	return stdout
}

// SandboxCloser is the one place a session's sandbox is torn down at the end
// of its life: capture the student's diff for the debrief, then kill. Every
// close path (Finish, the request-time deadline check, the lab.expire_sessions
// reaper) goes through it so none can skip the capture. It needs only the
// repo and runtime, so the background job can build its own.
type SandboxCloser struct {
	repo      *Repo
	container ContainerRuntime
}

func NewSandboxCloser(repo *Repo, container ContainerRuntime) *SandboxCloser {
	return &SandboxCloser{repo: repo, container: container}
}

// SnapshotAndKill captures (bounded, best-effort: failures are logged and
// never block) and then kills the session's sandbox. Call it BEFORE marking
// the session closed — a paused sandbox is resumed to be read.
func (c *SandboxCloser) SnapshotAndKill(ctx context.Context, session *LabSession) {
	if session.ContainerID == nil || *session.ContainerID == "" {
		return
	}
	c.Snapshot(ctx, session)
	if err := c.container.Kill(ctx, *session.ContainerID); err != nil {
		slog.Error("labs.SandboxCloser: kill sandbox failed", "session_id", session.ID, "container", *session.ContainerID, "error", err)
	}
}

// SnapshotAndKillAll runs SnapshotAndKill over sessions with bounded
// concurrency (the reaper can close many per tick).
func (c *SandboxCloser) SnapshotAndKillAll(ctx context.Context, sessions []*LabSession) {
	sem := make(chan struct{}, closeCaptureConcurrency)
	var wg sync.WaitGroup
	for _, s := range sessions {
		wg.Add(1)
		sem <- struct{}{}
		go func(s *LabSession) {
			defer wg.Done()
			defer func() { <-sem }()
			c.SnapshotAndKill(ctx, s)
		}(s)
	}
	wg.Wait()
}

// Snapshot stores the student's diff vs the scenario baseline (bounded,
// best-effort). Only lab-kind sessions (pinned variant) have one. Callers that
// must commit the close before killing (EndSession) call this, then kill.
func (c *SandboxCloser) Snapshot(ctx context.Context, session *LabSession) {
	if session.VariantKey == nil || *session.VariantKey == "" {
		return
	}
	ctx, cancel := context.WithTimeout(ctx, closeCaptureTimeout)
	defer cancel()

	lab, err := c.repo.GetLabForPlacement(ctx, session.LabID, session.OrgID)
	if err != nil {
		return
	}
	buildID := sessionBuildID(ctx, c.repo, lab, session)
	if buildID == "" {
		return
	}
	kind, ok := kindFor(lab)
	if !ok {
		return
	}
	rec, err := c.repo.GetVariantRecord(ctx, buildID, *session.VariantKey)
	if err != nil {
		return
	}
	if session.Status == SessionStatusPaused {
		if err := c.container.Unpause(ctx, *session.ContainerID); err != nil {
			return
		}
		if err := c.repo.ResumeFromPause(ctx, session.ID); err != nil {
			slog.Warn("labs.SandboxCloser: resume before snapshot", "session_id", session.ID, "error", err)
		}
	}
	baseline := kind.HintContext(variantViewOf(rec)).BaselineRef
	if diff := studentDiff(ctx, c.container, *session.ContainerID, baseline); diff != "" {
		if err := c.repo.SetStudentDiff(ctx, session.ID, diff); err != nil {
			slog.Error("labs.SandboxCloser: persist student diff", "session_id", session.ID, "error", err)
		}
	}
}
