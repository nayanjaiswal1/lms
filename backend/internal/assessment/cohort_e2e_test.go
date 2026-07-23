package assessment

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// seedCohortOrg inserts a minimal organization for cohort-group tests and
// registers cleanup. Mirrors internal/jobs/e2e_test.go's createTestOrg.
func seedCohortOrg(t *testing.T) (*Repo, string) {
	t.Helper()
	pool := testPool(t)
	repo := NewRepo(pool)

	suffix := fmt.Sprintf("%012d", time.Now().UnixNano()%1_000_000_000_000)
	var orgID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO organizations (name, slug) VALUES ($1, $2) RETURNING id`,
		"Cohort Test Org "+suffix, "cg"+suffix,
	).Scan(&orgID)
	if err != nil {
		t.Fatalf("create org: %v", err)
	}
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM organizations WHERE id = $1`, orgID) //nolint:errcheck
	})
	return repo, orgID
}

// seedUser inserts a minimal user row (org-independent — users aren't
// FK-scoped to an org directly, only via org_members/batch_members).
func seedUser(t *testing.T, pool *pgxpool.Pool, orgID string) string {
	t.Helper()
	suffix := time.Now().UnixNano()
	var userID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
		fmt.Sprintf("cohort-test-%d@example.com", suffix), "Cohort Test User",
	).Scan(&userID)
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID) //nolint:errcheck
	})
	return userID
}

// seedBatch creates a flat batch (no cohort group) via the repo's own
// CreateBatch, so it's cleaned up the same way a real batch would be.
func seedBatch(t *testing.T, repo *Repo, orgID, creatorID string) Batch {
	t.Helper()
	b, err := repo.CreateBatch(context.Background(), Batch{
		OrgID:     orgID,
		Name:      "Cohort Test Batch",
		Slug:      fmt.Sprintf("cohort-test-batch-%d", time.Now().UnixNano()),
		CreatedBy: creatorID,
	})
	if err != nil {
		t.Fatalf("create batch: %v", err)
	}
	return b
}

// TestCohortGroup_ThreeLevelHierarchy verifies the Class -> Section -> Batch
// shape: creating nested groups, moving a batch under the deepest one, and
// resolving the whole subtree's batch ids back out via DescendantBatchIDs.
func TestCohortGroup_ThreeLevelHierarchy(t *testing.T) {
	repo, orgID := seedCohortOrg(t)
	ctx := context.Background()
	creator := seedUser(t, repo.pool, orgID)

	class10, err := repo.CreateCohortGroup(ctx, CohortGroup{OrgID: orgID, Name: "Class 10", Slug: "class-10", CreatedBy: creator})
	if err != nil {
		t.Fatalf("create class: %v", err)
	}
	sectionA, err := repo.CreateCohortGroup(ctx, CohortGroup{OrgID: orgID, ParentID: &class10.ID, Name: "Section A", Slug: "section-a", CreatedBy: creator})
	if err != nil {
		t.Fatalf("create section: %v", err)
	}

	batch := seedBatch(t, repo, orgID, creator)
	if err := repo.MoveBatchToGroup(ctx, orgID, batch.ID, &sectionA.ID); err != nil {
		t.Fatalf("move batch to group: %v", err)
	}

	ids, err := repo.DescendantBatchIDs(ctx, orgID, class10.ID)
	if err != nil {
		t.Fatalf("descendant batch ids: %v", err)
	}
	if len(ids) != 1 || ids[0] != batch.ID {
		t.Fatalf("expected [%s], got %v", batch.ID, ids)
	}

	// Direct section lookup must resolve the same batch.
	ids, err = repo.DescendantBatchIDs(ctx, orgID, sectionA.ID)
	if err != nil {
		t.Fatalf("descendant batch ids (section): %v", err)
	}
	if len(ids) != 1 || ids[0] != batch.ID {
		t.Fatalf("expected [%s] from section, got %v", batch.ID, ids)
	}

	// A sibling group with no batches must resolve to none.
	sectionB, err := repo.CreateCohortGroup(ctx, CohortGroup{OrgID: orgID, ParentID: &class10.ID, Name: "Section B", Slug: "section-b", CreatedBy: creator})
	if err != nil {
		t.Fatalf("create section b: %v", err)
	}
	ids, err = repo.DescendantBatchIDs(ctx, orgID, sectionB.ID)
	if err != nil {
		t.Fatalf("descendant batch ids (empty section): %v", err)
	}
	if len(ids) != 0 {
		t.Fatalf("expected no batches under section b, got %v", ids)
	}
}

// TestCohortGroup_RejectsCyclicReparent verifies UpdateCohortGroup refuses to
// move a group under its own descendant — Postgres can't CHECK this
// declaratively, so it must be enforced in Go.
func TestCohortGroup_RejectsCyclicReparent(t *testing.T) {
	repo, orgID := seedCohortOrg(t)
	ctx := context.Background()
	creator := seedUser(t, repo.pool, orgID)

	parent, err := repo.CreateCohortGroup(ctx, CohortGroup{OrgID: orgID, Name: "Parent", Slug: "parent", CreatedBy: creator})
	if err != nil {
		t.Fatalf("create parent: %v", err)
	}
	child, err := repo.CreateCohortGroup(ctx, CohortGroup{OrgID: orgID, ParentID: &parent.ID, Name: "Child", Slug: "child", CreatedBy: creator})
	if err != nil {
		t.Fatalf("create child: %v", err)
	}

	// Attempt to make parent a child of its own child -> cycle.
	_, err = repo.UpdateCohortGroup(ctx, orgID, CohortGroup{ID: parent.ID, ParentID: &child.ID, Name: "Parent"})
	if !errors.Is(err, ErrCyclicParent) {
		t.Fatalf("expected ErrCyclicParent, got %v", err)
	}

	// Self-parent must also be rejected.
	_, err = repo.UpdateCohortGroup(ctx, orgID, CohortGroup{ID: parent.ID, ParentID: &parent.ID, Name: "Parent"})
	if !errors.Is(err, ErrCyclicParent) {
		t.Fatalf("expected ErrCyclicParent for self-parent, got %v", err)
	}
}

// TestCohortGroup_CreateRejectsCrossOrgParent verifies a group cannot be
// created under a parent belonging to a different org.
func TestCohortGroup_CreateRejectsCrossOrgParent(t *testing.T) {
	repo, orgAID := seedCohortOrg(t)
	_, orgBID := seedCohortOrg(t)
	ctx := context.Background()
	creatorA := seedUser(t, repo.pool, orgAID)

	otherOrgGroup, err := repo.CreateCohortGroup(ctx, CohortGroup{OrgID: orgBID, Name: "Other Org Group", Slug: "other-org-group", CreatedBy: seedUser(t, repo.pool, orgBID)})
	if err != nil {
		t.Fatalf("create group in org B: %v", err)
	}

	_, err = repo.CreateCohortGroup(ctx, CohortGroup{OrgID: orgAID, ParentID: &otherOrgGroup.ID, Name: "Leak", Slug: "leak", CreatedBy: creatorA})
	if !errors.Is(err, ErrInvalidParent) {
		t.Fatalf("expected ErrInvalidParent for cross-org parent, got %v", err)
	}
}
