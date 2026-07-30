package gitlab

import (
	"context"
	"errors"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// testPool connects to TEST_DATABASE_URL, skipping (not failing) the test
// when it's unset — matches the convention in internal/assessment's own
// test files (testPool is duplicated per-package rather than shared).
func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(func() { pool.Close() })
	return pool
}

func seedTeamTestOrg(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	suffix := fmt.Sprintf("%012d", time.Now().UnixNano()%1_000_000_000_000)
	var orgID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO organizations (name, slug) VALUES ($1, $2) RETURNING id`,
		"GitLab Team Test Org "+suffix, "gl-team-test-"+suffix,
	).Scan(&orgID)
	if err != nil {
		t.Fatalf("create org: %v", err)
	}
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM organizations WHERE id = $1`, orgID) //nolint:errcheck
	})
	return orgID
}

func seedTeamTestUser(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	suffix := time.Now().UnixNano()
	var userID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
		fmt.Sprintf("gl-team-test-%d@example.com", suffix), "GitLab Team Test User",
	).Scan(&userID)
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID) //nolint:errcheck
	})
	return userID
}

func seedTeamTestBatch(t *testing.T, pool *pgxpool.Pool, orgID, createdBy string) string {
	t.Helper()
	suffix := time.Now().UnixNano()
	var batchID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO batches (org_id, name, slug, created_by) VALUES ($1, $2, $3, $4) RETURNING id`,
		orgID, "GitLab Team Test Batch", fmt.Sprintf("gl-team-test-batch-%d", suffix), createdBy,
	).Scan(&batchID)
	if err != nil {
		t.Fatalf("create batch: %v", err)
	}
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM batches WHERE id = $1`, batchID) //nolint:errcheck
	})
	return batchID
}

// TestProjectTeamMembers_OneTeamPerStudentPerAssignment proves the composite
// FK trick from migration 023 — project_team_members_team_assignment_fk
// (team_id, assignment_id) -> project_teams(id, assignment_id), paired with
// UNIQUE(assignment_id, user_id) — actually rejects a second team membership
// for the same student under the same assignment as a real Postgres
// constraint, not just app-code enforcement, and that Repo.AddTeamMember
// surfaces it as the clean ErrAlreadyOnTeam domain error rather than a raw
// pg constraint-violation string.
func TestProjectTeamMembers_OneTeamPerStudentPerAssignment(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	orgID := seedTeamTestOrg(t, pool)
	instructorID := seedTeamTestUser(t, pool)
	studentID := seedTeamTestUser(t, pool)
	batchID := seedTeamTestBatch(t, pool, orgID, instructorID)

	assignment, err := repo.CreateAssignment(ctx, ProjectAssignment{
		OrgID: orgID, BatchID: batchID, Title: "Test Assignment", Slug: "test-assignment",
		Visibility: VisibilityPrivate, RequiredApprovals: 1, ProtectDefaultBranch: true,
		DefaultBranch: "main", CreatedBy: instructorID,
	})
	if err != nil {
		t.Fatalf("create assignment: %v", err)
	}
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM project_assignments WHERE id = $1`, assignment.ID) //nolint:errcheck
	})

	teamA, err := repo.CreateTeam(ctx, ProjectTeam{OrgID: orgID, AssignmentID: assignment.ID, Name: "Team A", Slug: "team-a", CreatedBy: &instructorID})
	if err != nil {
		t.Fatalf("create team A: %v", err)
	}
	teamB, err := repo.CreateTeam(ctx, ProjectTeam{OrgID: orgID, AssignmentID: assignment.ID, Name: "Team B", Slug: "team-b", CreatedBy: &instructorID})
	if err != nil {
		t.Fatalf("create team B: %v", err)
	}
	// Both teams cascade-delete when the assignment is cleaned up above
	// (project_teams_assignment_fk ON DELETE CASCADE) — no separate cleanup.

	if _, err := repo.AddTeamMember(ctx, ProjectTeamMember{
		TeamID: teamA.ID, UserID: studentID, AssignmentID: assignment.ID,
		Role: MemberRoleLead, GitlabAccessLevel: AccessLevelMaintainer,
	}); err != nil {
		t.Fatalf("add student to team A: %v", err)
	}

	_, err = repo.AddTeamMember(ctx, ProjectTeamMember{
		TeamID: teamB.ID, UserID: studentID, AssignmentID: assignment.ID,
		Role: MemberRoleMember, GitlabAccessLevel: AccessLevelDeveloper,
	})
	if err == nil {
		t.Fatal("expected adding the same student to a second team for the same assignment to fail, got nil error")
	}
	if !errors.Is(err, ErrAlreadyOnTeam) {
		t.Fatalf("expected ErrAlreadyOnTeam, got: %v", err)
	}

	members, err := repo.ListTeamMembers(ctx, teamB.ID)
	if err != nil {
		t.Fatalf("list team B members: %v", err)
	}
	if len(members) != 0 {
		t.Fatalf("expected team B to have no members after the rejected insert, got %d", len(members))
	}
}
