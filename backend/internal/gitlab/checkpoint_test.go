package gitlab

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
)

// seedCheckpointTest seeds an org/instructor/batch/assignment(requiredApprovals)/
// team/checkpoint(requires_ci_pass=false, so the CI gate never interferes
// with this test's sole focus: the approvals arithmetic)/project_team_checkpoints
// row (mr_iid set, approvals_count as given) — everything
// Service.TryMergeCheckpoint reads before ever calling GitLab, and
// deliberately nothing beyond that (no gitlab_installations row). That
// absence is what lets the "enough approvals" test below prove the gate was
// passed without a real or mocked GitLab API: the next thing
// TryMergeCheckpoint touches past the approvals/CI checks is s.clientFor,
// which fails with ErrNotFound precisely because no installation exists — a
// clearly different error from ErrInsufficientApprovals.
func seedCheckpointTest(t *testing.T, pool *pgxpool.Pool, repo *Repo, requiredApprovals, approvalsCount int) (orgID, teamID, checkpointID string) {
	t.Helper()
	ctx := context.Background()

	orgID = seedTeamTestOrg(t, pool)
	instructorID := seedTeamTestUser(t, pool)
	batchID := seedTeamTestBatch(t, pool, orgID, instructorID)

	assignment, err := repo.CreateAssignment(ctx, ProjectAssignment{
		OrgID: orgID, BatchID: batchID, Title: "Merge Gate Test Assignment", Slug: "merge-gate-test-assignment",
		Visibility: VisibilityPrivate, RequiredApprovals: requiredApprovals, ProtectDefaultBranch: true,
		DefaultBranch: "main", CreatedBy: instructorID,
	})
	if err != nil {
		t.Fatalf("create assignment: %v", err)
	}
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM project_assignments WHERE id = $1`, assignment.ID) //nolint:errcheck
	})

	team, err := repo.CreateTeam(ctx, ProjectTeam{OrgID: orgID, AssignmentID: assignment.ID, Name: "Merge Gate Test Team", Slug: "merge-gate-test-team", CreatedBy: &instructorID})
	if err != nil {
		t.Fatalf("create team: %v", err)
	}
	gitlabProjectID := time.Now().UnixNano() % 1_000_000_000
	if err := repo.SetTeamForkResult(ctx, team.ID, gitlabProjectID, "merge-gate-test-group/merge-gate-test-team", "https://gitlab.example.com/merge-gate-test-group/merge-gate-test-team"); err != nil {
		t.Fatalf("set team fork result: %v", err)
	}

	cp, err := repo.CreateCheckpoint(ctx, ProjectCheckpoint{
		OrgID: orgID, AssignmentID: assignment.ID, Title: "Checkpoint 1", Position: 1,
		Weight: 100, RequiresMR: true, RequiresCIPass: false,
	})
	if err != nil {
		t.Fatalf("create checkpoint: %v", err)
	}

	status := CheckpointStatusSubmitted
	if _, err := repo.UpsertTeamCheckpointMR(ctx, orgID, team.ID, cp.ID, 1, 1001,
		"https://gitlab.example.com/merge-gate-test-group/merge-gate-test-team/-/merge_requests/1",
		MRStateOpened, &status); err != nil {
		t.Fatalf("upsert team checkpoint mr: %v", err)
	}
	if _, err := pool.Exec(ctx,
		`UPDATE project_team_checkpoints SET approvals_count = $3 WHERE team_id = $1 AND checkpoint_id = $2`,
		team.ID, cp.ID, approvalsCount,
	); err != nil {
		t.Fatalf("set approvals count: %v", err)
	}

	return orgID, team.ID, cp.ID
}

// TestTryMergeCheckpoint_RejectsInsufficientApprovals proves the merge-gate
// arithmetic (approvals_count >= required_approvals) rejects a merge attempt
// when there aren't enough approvals yet — and, critically, that
// client.MergeMergeRequest is never reached (there is no gitlab_installations
// row seeded at all, so any code path that tried to call GitLab would fail
// with a *different* error than ErrInsufficientApprovals) and no state
// changes (status stays 'submitted', never flips to 'merged').
func TestTryMergeCheckpoint_RejectsInsufficientApprovals(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	vault := testVault(t)
	registry := jobs.NewRegistry()
	notifSvc := notifications.NewService(pool, registry)
	svc := NewService(pool, &config.Config{BackendURL: "http://localhost:8080"}, vault, registry, notifSvc)
	ctx := context.Background()

	orgID, teamID, checkpointID := seedCheckpointTest(t, pool, repo, 2, 1) // 1 of 2 required

	_, err := svc.TryMergeCheckpoint(ctx, orgID, teamID, checkpointID)
	if !errors.Is(err, ErrInsufficientApprovals) {
		t.Fatalf("expected ErrInsufficientApprovals, got: %v", err)
	}

	ptc, getErr := repo.GetTeamCheckpoint(ctx, teamID, checkpointID)
	if getErr != nil {
		t.Fatalf("get team checkpoint: %v", getErr)
	}
	if ptc.Status != CheckpointStatusSubmitted {
		t.Fatalf("expected status to remain %q after a rejected merge attempt, got %q", CheckpointStatusSubmitted, ptc.Status)
	}
	if ptc.ApprovalsCount != 1 {
		t.Fatalf("expected approvals_count to remain unchanged at 1, got %d", ptc.ApprovalsCount)
	}
}

// TestTryMergeCheckpoint_EnoughApprovalsProceedsPastTheGate proves the
// opposite arithmetic direction: with approvals_count >= required_approvals,
// TryMergeCheckpoint does NOT reject on ErrInsufficientApprovals — it
// proceeds to the next step (resolving a GitLab client), which in this test
// environment fails with ErrNotFound because no gitlab_installations row was
// seeded (this package's own test convention never calls a real GitLab API —
// see webhook_test.go's own seeded-team pattern). That specific failure mode
// is exactly the proof the arithmetic passed: had the approvals check failed
// first, the error would be ErrInsufficientApprovals instead.
func TestTryMergeCheckpoint_EnoughApprovalsProceedsPastTheGate(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	vault := testVault(t)
	registry := jobs.NewRegistry()
	notifSvc := notifications.NewService(pool, registry)
	svc := NewService(pool, &config.Config{BackendURL: "http://localhost:8080"}, vault, registry, notifSvc)
	ctx := context.Background()

	orgID, teamID, checkpointID := seedCheckpointTest(t, pool, repo, 2, 2) // 2 of 2 required

	_, err := svc.TryMergeCheckpoint(ctx, orgID, teamID, checkpointID)
	if err == nil {
		t.Fatal("expected an error since no gitlab_installations row exists for this org, got nil")
	}
	if errors.Is(err, ErrInsufficientApprovals) {
		t.Fatalf("approvals check should have passed (2 of 2 required), but got ErrInsufficientApprovals: %v", err)
	}
	if !errors.Is(err, ErrNotFound) {
		t.Fatalf("expected the failure past the gate to be ErrNotFound (no installation configured), got: %v", err)
	}
}
