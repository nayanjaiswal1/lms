package gitlab

import (
	"context"
	"testing"
	"time"
)

// TestFlagLateCommits_MarksLateAfterSnapshot is the deadline-late-flagging DB
// test kind-herding-cookie.md's own Verification section calls for: seed a
// checkpoint whose team already has a deadline snapshot on file (simulating
// what gitlab.deadline_snapshot's cron would have recorded once the
// checkpoint went past due_at), then simulate a commit landing after that
// snapshot via Repo.FlagLateCommits — the exact function
// service_webhook.go's ingestPushEvent calls for every incoming commit
// (confirmed wired since Batch 3, not something this batch needed to add) —
// and assert is_late flips true with late_commit_count incremented.
//
// This deliberately exercises the DB layer directly (Repo.SnapshotTeamCheckpoint
// + Repo.FlagLateCommits) rather than a real webhook payload, matching this
// package's own testing convention (checkpoint_test.go: exercise the
// decision/data logic, not GitLab's HTTP surface).
func TestFlagLateCommits_MarksLateAfterSnapshot(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	orgID := seedTeamTestOrg(t, pool)
	instructorID := seedTeamTestUser(t, pool)
	batchID := seedTeamTestBatch(t, pool, orgID, instructorID)

	assignment, err := repo.CreateAssignment(ctx, ProjectAssignment{
		OrgID: orgID, BatchID: batchID, Title: "Deadline Snapshot Test Assignment", Slug: "deadline-snapshot-test-assignment",
		Visibility: VisibilityPrivate, RequiredApprovals: 1, ProtectDefaultBranch: true,
		DefaultBranch: "main", CreatedBy: instructorID,
	})
	if err != nil {
		t.Fatalf("create assignment: %v", err)
	}
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM project_assignments WHERE id = $1`, assignment.ID) //nolint:errcheck
	})

	team, err := repo.CreateTeam(ctx, ProjectTeam{
		OrgID: orgID, AssignmentID: assignment.ID, Name: "Deadline Snapshot Test Team", Slug: "deadline-snapshot-test-team", CreatedBy: &instructorID,
	})
	if err != nil {
		t.Fatalf("create team: %v", err)
	}
	gitlabProjectID := time.Now().UnixNano() % 1_000_000_000
	if err := repo.SetTeamForkResult(ctx, team.ID, gitlabProjectID, "deadline-test-group/deadline-test-team", "https://gitlab.example.com/deadline-test-group/deadline-test-team"); err != nil {
		t.Fatalf("set team fork result: %v", err)
	}

	// due_at in the past — this is what gitlab.deadline_snapshot's cron sweep
	// would have picked up via ListDueCheckpointsNeedingSnapshot.
	dueAt := time.Now().Add(-2 * time.Hour)
	cp, err := repo.CreateCheckpoint(ctx, ProjectCheckpoint{
		OrgID: orgID, AssignmentID: assignment.ID, Title: "Checkpoint 1", Position: 1,
		DueAt: &dueAt, Weight: 100, RequiresMR: true, RequiresCIPass: false,
	})
	if err != nil {
		t.Fatalf("create checkpoint: %v", err)
	}

	// Confirm this checkpoint+team pair is actually surfaced by the cron
	// job's own work-queue query before taking the snapshot.
	due, err := repo.ListDueCheckpointsNeedingSnapshot(ctx)
	if err != nil {
		t.Fatalf("list due checkpoints needing snapshot: %v", err)
	}
	found := false
	for _, d := range due {
		if d.TeamID == team.ID && d.CheckpointID == cp.ID {
			found = true
			if d.GitlabProjectID != gitlabProjectID {
				t.Fatalf("expected gitlab_project_id %d, got %d", gitlabProjectID, d.GitlabProjectID)
			}
			if d.DefaultBranch != "main" {
				t.Fatalf("expected default_branch 'main', got %q", d.DefaultBranch)
			}
		}
	}
	if !found {
		t.Fatalf("expected ListDueCheckpointsNeedingSnapshot to surface team %s / checkpoint %s", team.ID, cp.ID)
	}

	// Take the snapshot — the same call the deadline_snapshot job makes after
	// resolving the team's HEAD sha via client.GetBranch.
	snapshotSHA := "abc123deadbeef"
	if err := repo.SnapshotTeamCheckpoint(ctx, orgID, team.ID, cp.ID, snapshotSHA); err != nil {
		t.Fatalf("snapshot team checkpoint: %v", err)
	}

	// Once snapshotted, the pair must no longer appear in the due-work queue.
	due, err = repo.ListDueCheckpointsNeedingSnapshot(ctx)
	if err != nil {
		t.Fatalf("list due checkpoints needing snapshot (after snapshot): %v", err)
	}
	for _, d := range due {
		if d.TeamID == team.ID && d.CheckpointID == cp.ID {
			t.Fatalf("expected team %s / checkpoint %s to no longer need a snapshot", team.ID, cp.ID)
		}
	}

	ptc, err := repo.GetTeamCheckpoint(ctx, team.ID, cp.ID)
	if err != nil {
		t.Fatalf("get team checkpoint: %v", err)
	}
	if ptc.SnapshotSHA == nil || *ptc.SnapshotSHA != snapshotSHA {
		t.Fatalf("expected snapshot_sha %q, got %v", snapshotSHA, ptc.SnapshotSHA)
	}
	if ptc.SnapshotAt == nil {
		t.Fatal("expected snapshot_at to be set")
	}
	if ptc.IsLate {
		t.Fatal("expected is_late to still be false before any commit lands after the snapshot")
	}

	// Simulate a commit arriving after the snapshot — the exact call
	// service_webhook.go's ingestPushEvent makes for every incoming commit.
	afterSnapshot := ptc.SnapshotAt.Add(5 * time.Minute)
	if err := repo.FlagLateCommits(ctx, team.ID, afterSnapshot); err != nil {
		t.Fatalf("flag late commits: %v", err)
	}

	ptc, err = repo.GetTeamCheckpoint(ctx, team.ID, cp.ID)
	if err != nil {
		t.Fatalf("get team checkpoint (after late commit): %v", err)
	}
	if !ptc.IsLate {
		t.Fatal("expected is_late to be true after a commit landed past the snapshot")
	}
	if ptc.LateCommitCount != 1 {
		t.Fatalf("expected late_commit_count 1, got %d", ptc.LateCommitCount)
	}

	// A second late commit increments the counter again rather than staying
	// pinned at 1.
	if err := repo.FlagLateCommits(ctx, team.ID, afterSnapshot.Add(time.Minute)); err != nil {
		t.Fatalf("flag late commits (second commit): %v", err)
	}
	ptc, err = repo.GetTeamCheckpoint(ctx, team.ID, cp.ID)
	if err != nil {
		t.Fatalf("get team checkpoint (after second late commit): %v", err)
	}
	if ptc.LateCommitCount != 2 {
		t.Fatalf("expected late_commit_count 2 after a second late commit, got %d", ptc.LateCommitCount)
	}

	// A commit BEFORE the snapshot must never be flagged late — guards
	// against FlagLateCommits' WHERE clause direction being backwards.
	beforeSnapshot := ptc.SnapshotAt.Add(-time.Hour)
	if err := repo.FlagLateCommits(ctx, team.ID, beforeSnapshot); err != nil {
		t.Fatalf("flag late commits (before snapshot): %v", err)
	}
	ptc, err = repo.GetTeamCheckpoint(ctx, team.ID, cp.ID)
	if err != nil {
		t.Fatalf("get team checkpoint (after before-snapshot commit): %v", err)
	}
	if ptc.LateCommitCount != 2 {
		t.Fatalf("expected late_commit_count to remain 2 after a pre-snapshot commit, got %d", ptc.LateCommitCount)
	}
}
