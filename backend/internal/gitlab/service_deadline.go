package gitlab

import (
	"context"
	"fmt"
	"log/slog"
)

// Job handler key for this file's job — see service_provision.go's own
// jobProvisionTeam doc comment for why these are plain string literals
// rather than a shared constants import. MUST stay in sync with
// handlers.HandlerGitlabDeadlineSnapshot in
// internal/jobs/handlers/constants.go.
const jobDeadlineSnapshot = "gitlab.deadline_snapshot"

const deadlineSnapshotTimeoutMS = 120000

// SnapshotDueCheckpoints is the gitlab.deadline_snapshot job body (cron
// */5min, cmd/server/main.go): finds every checkpoint past its due_at whose
// team hasn't been snapshotted yet, and records that team's current HEAD sha
// on the assignment's default branch as the deadline snapshot.
//
// From that point on, no separate late-flagging step is needed here:
// service_webhook.go's ingestPushEvent already calls Repo.FlagLateCommits on
// every incoming commit (wired since Batch 3 — confirmed directly against
// repo_activity.go rather than assumed), which flags is_late/increments
// late_commit_count purely off snapshot_at being non-null. This job's entire
// job is taking that one snapshot; it does no late-flagging of its own.
func (s *Service) SnapshotDueCheckpoints(ctx context.Context) error {
	due, err := s.repo.ListDueCheckpointsNeedingSnapshot(ctx)
	if err != nil {
		return fmt.Errorf("gitlab: snapshot due checkpoints: list due: %w", err)
	}
	if len(due) == 0 {
		return nil
	}

	clientCache := map[string]*Client{}
	for _, d := range due {
		cacheKey := d.OrgID
		if d.InstallationID != nil {
			cacheKey += "|" + *d.InstallationID
		}
		client, ok := clientCache[cacheKey]
		if !ok {
			cl, err := s.clientFor(ctx, d.OrgID, d.InstallationID)
			if err != nil {
				slog.ErrorContext(ctx, "gitlab: snapshot due checkpoints: resolve client failed", "org_id", d.OrgID, "error", err)
				continue
			}
			clientCache[cacheKey] = cl
			client = cl
		}

		branch, err := client.GetBranch(ctx, d.GitlabProjectID, d.DefaultBranch)
		if err != nil {
			slog.ErrorContext(ctx, "gitlab: snapshot due checkpoints: get branch failed",
				"team_id", d.TeamID, "checkpoint_id", d.CheckpointID, "error", err)
			continue
		}
		if err := s.repo.SnapshotTeamCheckpoint(ctx, d.OrgID, d.TeamID, d.CheckpointID, branch.Commit.ID); err != nil {
			slog.ErrorContext(ctx, "gitlab: snapshot due checkpoints: persist snapshot failed",
				"team_id", d.TeamID, "checkpoint_id", d.CheckpointID, "error", err)
		}
	}
	return nil
}
