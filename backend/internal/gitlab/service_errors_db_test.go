package gitlab

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/testdb"
)

// A DB failure inside DeleteAssignment must surface as a wrapped error, never
// be misreported as ErrNotFound/ErrConflict.
func TestDeleteAssignment_DBFailureIsWrappedNotSentinel(t *testing.T) {
	repo := NewRepo(testdb.New(t))
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	err := repo.DeleteAssignment(ctx, "00000000-0000-0000-0000-000000000000", "00000000-0000-0000-0000-000000000000")
	if err == nil {
		t.Fatal("expected error from cancelled context")
	}
	if errors.Is(err, ErrNotFound) || errors.Is(err, ErrConflict) {
		t.Fatalf("DB failure misreported as sentinel: %v", err)
	}
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected wrapped context.Canceled, got: %v", err)
	}
}

// markTeamProvisionFailed must persist the failed status and cause.
func TestMarkTeamProvisionFailed_PersistsStatus(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)
	svc := &Service{repo: repo}

	orgID := seedTeamTestOrg(t, pool)
	instructorID := seedTeamTestUser(t, pool)
	batchID := seedTeamTestBatch(t, pool, orgID, instructorID)
	assignment, err := repo.CreateAssignment(ctx, ProjectAssignment{
		OrgID: orgID, BatchID: batchID, Title: "Provision Fail Assignment", Slug: "provision-fail-assignment",
		Visibility: VisibilityPrivate, RequiredApprovals: 1, ProtectDefaultBranch: true,
		DefaultBranch: "main", CreatedBy: instructorID,
	})
	if err != nil {
		t.Fatalf("create assignment: %v", err)
	}
	team, err := repo.CreateTeam(ctx, ProjectTeam{OrgID: orgID, AssignmentID: assignment.ID, Name: "Provision Fail Team", Slug: "provision-fail-team", CreatedBy: &instructorID})
	if err != nil {
		t.Fatalf("create team: %v", err)
	}

	svc.markTeamProvisionFailed(ctx, team.ID, errors.New("fork import timed out"))

	got, err := repo.GetTeam(ctx, orgID, team.ID)
	if err != nil {
		t.Fatalf("get team: %v", err)
	}
	if got.ProvisionStatus != ProvisionFailed {
		t.Fatalf("provision status = %q, want %q", got.ProvisionStatus, ProvisionFailed)
	}
	if got.ProvisionError == nil || *got.ProvisionError != "fork import timed out" {
		t.Fatalf("provision error = %v, want cause persisted", got.ProvisionError)
	}
}

// The "check exists" Scan inside DeleteAssignment runs only when the DELETE
// affects zero rows. Cancelling the context as the second connection is
// acquired lets the DELETE succeed and fails exactly the Scan step.
func TestDeleteAssignment_ScanFailureIsWrappedNotSentinel(t *testing.T) {
	base := testdb.New(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	cfg := base.Config().Copy()
	acquires := 0
	cfg.BeforeAcquire = func(_ context.Context, _ *pgx.Conn) bool {
		acquires++
		if acquires == 2 {
			cancel()
		}
		return true
	}
	pool, err := pgxpool.NewWithConfig(context.Background(), cfg)
	if err != nil {
		t.Fatalf("new pool: %v", err)
	}
	t.Cleanup(pool.Close)

	err = NewRepo(pool).DeleteAssignment(ctx, "00000000-0000-0000-0000-000000000000", "00000000-0000-0000-0000-000000000000")
	if acquires != 2 {
		t.Fatalf("acquires = %d, want 2 (Exec then Scan)", acquires)
	}
	if err == nil {
		t.Fatal("expected error from failed exists check")
	}
	if errors.Is(err, ErrNotFound) || errors.Is(err, ErrConflict) {
		t.Fatalf("Scan failure misreported as sentinel: %v", err)
	}
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected wrapped context.Canceled, got: %v", err)
	}
}

// recordMemberSyncResult must persist a failed roster sync status and cause.
func TestRecordMemberSyncResult_PersistsFailure(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)
	svc := &Service{repo: repo}

	orgID := seedTeamTestOrg(t, pool)
	userID := seedTeamTestUser(t, pool)
	batchID := seedTeamTestBatch(t, pool, orgID, userID)
	assignment, err := repo.CreateAssignment(ctx, ProjectAssignment{
		OrgID: orgID, BatchID: batchID, Title: "Member Sync Assignment", Slug: "member-sync-assignment",
		Visibility: VisibilityPrivate, RequiredApprovals: 1, ProtectDefaultBranch: true,
		DefaultBranch: "main", CreatedBy: userID,
	})
	if err != nil {
		t.Fatalf("create assignment: %v", err)
	}
	team, err := repo.CreateTeam(ctx, ProjectTeam{OrgID: orgID, AssignmentID: assignment.ID, Name: "Member Sync Team", Slug: "member-sync-team", CreatedBy: &userID})
	if err != nil {
		t.Fatalf("create team: %v", err)
	}
	if _, err := repo.AddTeamMember(ctx, ProjectTeamMember{TeamID: team.ID, UserID: userID, AssignmentID: assignment.ID, Role: "member", GitlabAccessLevel: 30, AddedBy: &userID}); err != nil {
		t.Fatalf("add member: %v", err)
	}

	cause := "gitlab add member: 403"
	svc.recordMemberSyncResult(ctx, team.ID, userID, SyncStatusFailed, &cause)

	got, err := repo.GetTeamMember(ctx, team.ID, userID)
	if err != nil {
		t.Fatalf("get member: %v", err)
	}
	if got.SyncStatus != SyncStatusFailed {
		t.Fatalf("sync status = %q, want %q", got.SyncStatus, SyncStatusFailed)
	}
	if got.SyncError == nil || *got.SyncError != cause {
		t.Fatalf("sync error = %v, want %q", got.SyncError, cause)
	}
}
