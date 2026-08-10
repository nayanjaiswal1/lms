package courses

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// seedProposalFixture inserts the minimum org/user/course rows CreateProposal
// and ListProposalsForCourse need — organizations.slug/name, users.email/name,
// and courses.org_id/creator_id/title/slug all have NOT NULL or CHECK
// constraints that a bare INSERT would trip.
func seedProposalFixture(t *testing.T, ctx context.Context, pool *pgxpool.Pool) (orgID, userID, courseID string) {
	t.Helper()

	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('acme-corp', 'Acme Corp') RETURNING id`,
	).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ('proposer@example.com', 'Proposer') RETURNING id`,
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO courses (org_id, creator_id, title, slug) VALUES ($1, $2, 'Target Course', 'target-course') RETURNING id`,
		orgID, userID,
	).Scan(&courseID); err != nil {
		t.Fatalf("seed course: %v", err)
	}
	return orgID, userID, courseID
}

// TestListProposalsForCourse exercises the pending-proposals review queue
// query (repo.go's ListProposalsForCourse) against a real database — the
// jsonb requested_change round trip through CreateProposal/scanProposal and
// the org/subject/status WHERE clause can't be checked with pure-Go tests.
func TestListProposalsForCourse(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	orgID, userID, courseID := seedProposalFixture(t, ctx, pool)

	created, err := repo.CreateProposal(ctx, CourseContentProposal{
		OrgID:          orgID,
		ProposerID:     userID,
		TargetCourseID: courseID,
		Title:          "Add a section on channels",
		Type:           "lesson",
		ContentBody:    "Channels are Go's concurrency primitive for...",
	})
	if err != nil {
		t.Fatalf("CreateProposal: %v", err)
	}
	if created.Status != ProposalStatusPending {
		t.Fatalf("expected new proposal to be pending, got %q", created.Status)
	}

	all, err := repo.ListProposalsForCourse(ctx, orgID, courseID, "", 100, 0)
	if err != nil {
		t.Fatalf("ListProposalsForCourse(all): %v", err)
	}
	if len(all) != 1 {
		t.Fatalf("expected 1 proposal, got %d", len(all))
	}
	got := all[0]
	if got.ID != created.ID {
		t.Errorf("expected id %q, got %q", created.ID, got.ID)
	}
	if got.Title != "Add a section on channels" || got.ContentBody != "Channels are Go's concurrency primitive for..." {
		t.Errorf("requested_change jsonb round trip mismatch: got title=%q body=%q", got.Title, got.ContentBody)
	}
	if got.ProposerID != userID || got.TargetCourseID != courseID {
		t.Errorf("expected proposer=%q target=%q, got proposer=%q target=%q", userID, courseID, got.ProposerID, got.TargetCourseID)
	}

	pending, err := repo.ListProposalsForCourse(ctx, orgID, courseID, ProposalStatusPending, 100, 0)
	if err != nil {
		t.Fatalf("ListProposalsForCourse(pending): %v", err)
	}
	if len(pending) != 1 {
		t.Fatalf("expected 1 pending proposal, got %d", len(pending))
	}

	approved, err := repo.ListProposalsForCourse(ctx, orgID, courseID, ProposalStatusApproved, 100, 0)
	if err != nil {
		t.Fatalf("ListProposalsForCourse(approved): %v", err)
	}
	if len(approved) != 0 {
		t.Fatalf("expected 0 approved proposals, got %d", len(approved))
	}
}
