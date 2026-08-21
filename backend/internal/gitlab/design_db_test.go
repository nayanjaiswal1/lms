package gitlab

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
)

// TestMain wires internal/testdb's shared Postgres testcontainer for this
// package's *_db_test.go files (design_db_test.go, ownership_db_test.go).
// The pre-existing team_test.go/checkpoint_test.go/dashboard_test.go/
// webhook_test.go files use their own env-var-gated testPool(t) instead —
// unaffected by this, since they never call testdb.New(t).
func TestMain(m *testing.M) { testdb.RunMain(m) }

// seedDesignProposalFixture creates an org/instructor/batch/assignment/team
// (via team_test.go's own seed helpers) plus one checkpoint and two student
// users — the minimum needed to exercise proposal submission and voting.
func seedDesignProposalFixture(t *testing.T, ctx context.Context, pool *pgxpool.Pool, repo *Repo) (orgID, teamID, checkpointID, studentA, studentB string) {
	t.Helper()

	orgID = seedTeamTestOrg(t, pool)
	instructorID := seedTeamTestUser(t, pool)
	batchID := seedTeamTestBatch(t, pool, orgID, instructorID)

	assignment, err := repo.CreateAssignment(ctx, ProjectAssignment{
		OrgID: orgID, BatchID: batchID, Title: "Design Proposal Test Assignment", Slug: "design-proposal-test-assignment",
		Visibility: VisibilityPrivate, RequiredApprovals: 1, ProtectDefaultBranch: true,
		DefaultBranch: "main", CreatedBy: instructorID,
	})
	if err != nil {
		t.Fatalf("create assignment: %v", err)
	}

	team, err := repo.CreateTeam(ctx, ProjectTeam{OrgID: orgID, AssignmentID: assignment.ID, Name: "Design Test Team", Slug: "design-test-team", CreatedBy: &instructorID})
	if err != nil {
		t.Fatalf("create team: %v", err)
	}

	checkpoint, err := repo.CreateCheckpoint(ctx, ProjectCheckpoint{
		OrgID: orgID, AssignmentID: assignment.ID, Title: "Architecture Review", Position: 1, Weight: 100, Kind: CheckpointKindArchitectureReview,
	})
	if err != nil {
		t.Fatalf("create checkpoint: %v", err)
	}

	studentA = seedTeamTestUser(t, pool)
	studentB = seedTeamTestUser(t, pool)

	return orgID, team.ID, checkpoint.ID, studentA, studentB
}

// TestDesignProposalVotingAndAccept exercises the full Batch 7 flow against
// a real database: two proposals, votes from both students, ranking by vote
// count, and — the riskiest query in this batch — AcceptDesignProposal's
// clear-then-set transaction, which must never let two proposals for the
// same (checkpoint, team) end up accepted at once (migration 022's partial
// unique index would reject that at the SQL level if the transaction were
// wrong).
func TestDesignProposalVotingAndAccept(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	orgID, teamID, checkpointID, studentA, studentB := seedDesignProposalFixture(t, ctx, pool, repo)

	proposalA, err := repo.CreateDesignProposal(ctx, ProjectDesignProposal{
		OrgID: orgID, CheckpointID: checkpointID, TeamID: teamID, SubmittedBy: studentA, Title: "Microservices",
	})
	if err != nil {
		t.Fatalf("create proposal A: %v", err)
	}
	proposalB, err := repo.CreateDesignProposal(ctx, ProjectDesignProposal{
		OrgID: orgID, CheckpointID: checkpointID, TeamID: teamID, SubmittedBy: studentB, Title: "Monolith first",
	})
	if err != nil {
		t.Fatalf("create proposal B: %v", err)
	}

	// Proposal A gets 2 votes, proposal B gets 1 — A should rank first.
	if err := repo.VoteForProposal(ctx, proposalA.ID, studentA); err != nil {
		t.Fatalf("vote A by studentA: %v", err)
	}
	if err := repo.VoteForProposal(ctx, proposalA.ID, studentB); err != nil {
		t.Fatalf("vote A by studentB: %v", err)
	}
	// Voting twice from the same user must not double-count (ON CONFLICT DO NOTHING).
	if err := repo.VoteForProposal(ctx, proposalA.ID, studentA); err != nil {
		t.Fatalf("re-vote A by studentA: %v", err)
	}
	if err := repo.VoteForProposal(ctx, proposalB.ID, studentB); err != nil {
		t.Fatalf("vote B by studentB: %v", err)
	}

	ranked, err := repo.ListDesignProposals(ctx, checkpointID, teamID, studentA)
	if err != nil {
		t.Fatalf("list design proposals: %v", err)
	}
	if len(ranked) != 2 {
		t.Fatalf("expected 2 proposals, got %d", len(ranked))
	}
	if ranked[0].ID != proposalA.ID || ranked[0].VoteCount != 2 {
		t.Fatalf("expected proposal A first with 2 votes, got id=%s votes=%d", ranked[0].ID, ranked[0].VoteCount)
	}
	if !ranked[0].MyVote {
		t.Errorf("expected MyVote=true for studentA on proposal A")
	}
	if ranked[1].ID != proposalB.ID || ranked[1].VoteCount != 1 {
		t.Fatalf("expected proposal B second with 1 vote, got id=%s votes=%d", ranked[1].ID, ranked[1].VoteCount)
	}

	// Accept B first, then A — B must flip back to not-accepted, and at no
	// point should the underlying UPDATEs be able to leave both accepted
	// (the partial unique index would surface that as an error here).
	if _, err := repo.AcceptDesignProposal(ctx, orgID, proposalB.ID); err != nil {
		t.Fatalf("accept proposal B: %v", err)
	}
	acceptedA, err := repo.AcceptDesignProposal(ctx, orgID, proposalA.ID)
	if err != nil {
		t.Fatalf("accept proposal A: %v", err)
	}
	if !acceptedA.IsAccepted {
		t.Errorf("expected proposal A to be accepted")
	}

	all, err := repo.ListDesignProposals(ctx, checkpointID, teamID, studentA)
	if err != nil {
		t.Fatalf("list design proposals after accept: %v", err)
	}
	acceptedCount := 0
	for _, p := range all {
		if p.IsAccepted {
			acceptedCount++
			if p.ID != proposalA.ID {
				t.Errorf("expected only proposal A accepted, but %s is also accepted", p.ID)
			}
		}
	}
	if acceptedCount != 1 {
		t.Fatalf("expected exactly 1 accepted proposal, got %d", acceptedCount)
	}

	// RemoveVote must be idempotent and actually remove the vote.
	if err := repo.RemoveVote(ctx, proposalA.ID, studentB); err != nil {
		t.Fatalf("remove vote: %v", err)
	}
	afterRemove, err := repo.ListDesignProposals(ctx, checkpointID, teamID, studentA)
	if err != nil {
		t.Fatalf("list design proposals after remove vote: %v", err)
	}
	for _, p := range afterRemove {
		if p.ID == proposalA.ID && p.VoteCount != 1 {
			t.Errorf("expected proposal A to have 1 vote after removal, got %d", p.VoteCount)
		}
	}
}
