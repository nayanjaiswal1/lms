package labs

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
)

const (
	// ideActivityLogPath is where the lab IDE's mindforge-activity extension
	// appends one JSON event per line (lab-images/lab-debug/ide-extensions).
	ideActivityLogPath = "/var/log/mindforge-lab/activity.jsonl"
	// ideActivityLogReadBytes bounds how much of the log one capture reads —
	// the log is student-writable, so it is validated like any client batch.
	ideActivityLogReadBytes = 256 * 1024
)

var readIDEActivityLogScript = fmt.Sprintf("head -c %d %s 2>/dev/null", ideActivityLogReadBytes, ideActivityLogPath)

// parseIDEActivityLog turns the IDE's activity log into validated events:
// malformed lines and anything normalizeActivity rejects are dropped, never
// stored, and at most ActivityMaxPerSession events are kept.
func parseIDEActivityLog(raw string) []ActivityEventInput {
	var events []ActivityEventInput
	sc := bufio.NewScanner(strings.NewReader(raw))
	sc.Buffer(make([]byte, 0, 4096), ideActivityLogReadBytes)
	for sc.Scan() && len(events) < ActivityMaxPerSession {
		var e ActivityEventInput
		if err := json.Unmarshal(sc.Bytes(), &e); err != nil {
			continue
		}
		valid, err := normalizeActivity([]ActivityEventInput{e})
		if err != nil {
			continue
		}
		events = append(events, valid...)
	}
	return events
}

// captureIDEActivity stores the IDE-side activity (file opens, large inserts)
// of a mission session before its sandbox is killed. Best-effort like the diff
// snapshot: failures are logged and never block closing the session.
func (c *SandboxCloser) captureIDEActivity(ctx context.Context, session *LabSession) {
	if session.MissionStartedAt == nil {
		return
	}
	cfg, err := c.repo.GetOrgConfig(ctx, session.OrgID)
	if err != nil || cfg.DebugUI != DebugUINew {
		return
	}
	stdout, _, exitCode, err := c.container.Exec(ctx, *session.ContainerID, readIDEActivityLogScript, diffExecTimeoutSec)
	if err != nil || exitCode != 0 {
		return
	}
	events := parseIDEActivityLog(stdout)
	for start := 0; start < len(events); start += ActivityMaxBatch {
		end := min(start+ActivityMaxBatch, len(events))
		if err := c.repo.InsertActivity(ctx, session.ID, events[start:end]); err != nil {
			slog.Error("labs.SandboxCloser: persist IDE activity", "session_id", session.ID, "error", err)
			return
		}
	}
}
