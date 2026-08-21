package gitlab

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

// TestUpsertCommitFilesAndListFileOwnership exercises the pgx.Batch insert
// (UpsertCommitFiles) and the DISTINCT ON aggregation (ListFileOwnership)
// against a real database — neither can be checked with pure-Go tests: the
// batch insert's per-statement error handling and the DISTINCT ON query's
// tie-break-by-count behavior both depend on Postgres actually running the
// SQL.
func TestUpsertCommitFilesAndListFileOwnership(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	orgID := seedTeamTestOrg(t, pool)
	instructorID := seedTeamTestUser(t, pool)
	batchID := seedTeamTestBatch(t, pool, orgID, instructorID)
	assignment, err := repo.CreateAssignment(ctx, ProjectAssignment{
		OrgID: orgID, BatchID: batchID, Title: "Ownership Test Assignment", Slug: "ownership-test-assignment",
		Visibility: VisibilityPrivate, RequiredApprovals: 1, ProtectDefaultBranch: true,
		DefaultBranch: "main", CreatedBy: instructorID,
	})
	if err != nil {
		t.Fatalf("create assignment: %v", err)
	}
	team, err := repo.CreateTeam(ctx, ProjectTeam{OrgID: orgID, AssignmentID: assignment.ID, Name: "Ownership Test Team", Slug: "ownership-test-team", CreatedBy: &instructorID})
	if err != nil {
		t.Fatalf("create team: %v", err)
	}

	authorMain := seedTeamTestUser(t, pool)
	authorMinor := seedTeamTestUser(t, pool)

	// authorMain touches main.go 3 times (across 3 commits) and shared.go once;
	// authorMinor touches main.go once and shared.go twice. Expected top
	// owner: authorMain for main.go (3 > 1), authorMinor for shared.go (2 > 1).
	seedCommitFile := func(sha, path, author string) {
		if err := repo.UpsertCommitFiles(ctx, orgID, team.ID, sha, nil, &author, nil, []string{path}, nil, nil); err != nil {
			t.Fatalf("upsert commit files (sha=%s path=%s): %v", sha, path, err)
		}
	}
	seedCommitFile("sha1", "main.go", authorMain)
	seedCommitFile("sha2", "main.go", authorMain)
	seedCommitFile("sha3", "main.go", authorMain)
	seedCommitFile("sha4", "shared.go", authorMain)
	seedCommitFile("sha5", "main.go", authorMinor)
	seedCommitFile("sha6", "shared.go", authorMinor)
	seedCommitFile("sha7", "shared.go", authorMinor)

	// Redelivery of an already-seen (sha, file_path) pair must be a silent
	// no-op (ON CONFLICT DO NOTHING), not a duplicate row that would skew
	// the aggregation.
	seedCommitFile("sha1", "main.go", authorMain)

	owners, err := repo.ListFileOwnership(ctx, team.ID)
	if err != nil {
		t.Fatalf("list file ownership: %v", err)
	}
	if len(owners) != 2 {
		t.Fatalf("expected 2 files, got %d: %+v", len(owners), owners)
	}

	byPath := map[string]FileOwnershipRow{}
	for _, o := range owners {
		byPath[o.FilePath] = o
	}

	mainOwner, ok := byPath["main.go"]
	if !ok {
		t.Fatal("expected main.go in ownership results")
	}
	if mainOwner.AuthorUserID == nil || *mainOwner.AuthorUserID != authorMain {
		t.Errorf("expected main.go owned by authorMain, got %v", mainOwner.AuthorUserID)
	}
	if mainOwner.ChangeCount != 3 {
		t.Errorf("expected main.go change_count=3 (redelivery must not double-count), got %d", mainOwner.ChangeCount)
	}

	sharedOwner, ok := byPath["shared.go"]
	if !ok {
		t.Fatal("expected shared.go in ownership results")
	}
	if sharedOwner.AuthorUserID == nil || *sharedOwner.AuthorUserID != authorMinor {
		t.Errorf("expected shared.go owned by authorMinor, got %v", sharedOwner.AuthorUserID)
	}
	if sharedOwner.ChangeCount != 2 {
		t.Errorf("expected shared.go change_count=2, got %d", sharedOwner.ChangeCount)
	}

	// A "removed" file must never count toward ownership.
	if err := repo.UpsertCommitFiles(ctx, orgID, team.ID, "sha8", nil, &authorMinor, nil, nil, nil, []string{"gone.go"}); err != nil {
		t.Fatalf("upsert removed file: %v", err)
	}
	afterRemoval, err := repo.ListFileOwnership(ctx, team.ID)
	if err != nil {
		t.Fatalf("list file ownership after removal: %v", err)
	}
	for _, o := range afterRemoval {
		if o.FilePath == "gone.go" {
			t.Errorf("removed-only file should not appear in ownership results")
		}
	}
}
