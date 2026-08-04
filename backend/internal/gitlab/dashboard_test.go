package gitlab

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// seedDashboardTestTeam creates an org/instructor/batch/assignment/team via
// the existing team_test.go helpers (seedTeamTestOrg/seedTeamTestUser/
// seedTeamTestBatch, same package) and adds three student members to the
// team, so a contribution/free-rider test has a real roster to aggregate
// against.
func seedDashboardTestTeam(t *testing.T, pool *pgxpool.Pool, repo *Repo) (teamID string, students [3]string) {
	t.Helper()
	ctx := context.Background()

	orgID := seedTeamTestOrg(t, pool)
	instructorID := seedTeamTestUser(t, pool)
	batchID := seedTeamTestBatch(t, pool, orgID, instructorID)

	assignment, err := repo.CreateAssignment(ctx, ProjectAssignment{
		OrgID: orgID, BatchID: batchID, Title: "Dashboard Test Assignment", Slug: fmt.Sprintf("dashboard-test-assignment-%d", time.Now().UnixNano()),
		Visibility: VisibilityPrivate, RequiredApprovals: 1, ProtectDefaultBranch: true,
		DefaultBranch: "main", CreatedBy: instructorID,
	})
	if err != nil {
		t.Fatalf("create assignment: %v", err)
	}
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM project_assignments WHERE id = $1`, assignment.ID) //nolint:errcheck
	})

	team, err := repo.CreateTeam(ctx, ProjectTeam{OrgID: orgID, AssignmentID: assignment.ID, Name: "Dashboard Test Team", Slug: "dashboard-test-team", CreatedBy: &instructorID})
	if err != nil {
		t.Fatalf("create team: %v", err)
	}

	for i := range students {
		students[i] = seedTeamTestUser(t, pool)
		if _, err := repo.AddTeamMember(ctx, ProjectTeamMember{
			TeamID: team.ID, UserID: students[i], AssignmentID: assignment.ID,
			Role: MemberRoleMember, GitlabAccessLevel: AccessLevelDeveloper,
		}); err != nil {
			t.Fatalf("add student %d to team: %v", i, err)
		}
	}

	return team.ID, students
}

// seedCommit inserts one gitlab_commits row attributed to userID via
// Repo.UpsertCommit, then backfills additions/deletions the same way the
// commit_stats job would (UpsertCommit itself always leaves them NULL on
// first insert, matching the real webhook->stats-fetch flow).
func seedCommit(t *testing.T, pool *pgxpool.Pool, repo *Repo, orgID, teamID, userID string, sha string, additions, deletions int) {
	t.Helper()
	ctx := context.Background()
	now := time.Now()
	if err := repo.UpsertCommit(ctx, GitlabCommit{
		OrgID: orgID, TeamID: teamID, SHA: sha, UserID: &userID, CommittedAt: &now,
	}); err != nil {
		t.Fatalf("seed commit %s: %v", sha, err)
	}
	var commitID string
	if err := pool.QueryRow(ctx, `SELECT id FROM gitlab_commits WHERE team_id = $1 AND sha = $2`, teamID, sha).Scan(&commitID); err != nil {
		t.Fatalf("look up seeded commit %s: %v", sha, err)
	}
	if err := repo.UpdateCommitStats(ctx, commitID, additions, deletions); err != nil {
		t.Fatalf("update commit stats for %s: %v", sha, err)
	}
}

// TestGetTeamContributions_AggregatesPerUserAndFlagsFreeRider seeds a known
// number of commits for two of three team members and asserts the direct
// GROUP BY-style aggregation (Repo.GetTeamContributions — no rollup table,
// per kind-herding-cookie.md §0.6) returns the exact per-user commit counts,
// and that the third member (zero seeded commits) is correctly flagged
// IsFreeRider — the "zero commits" MVP signal §7's batch-4 scope calls for.
func TestGetTeamContributions_AggregatesPerUserAndFlagsFreeRider(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	teamID, students := seedDashboardTestTeam(t, pool, repo)
	team, err := repo.GetTeamByID(ctx, teamID)
	if err != nil {
		t.Fatalf("get team: %v", err)
	}
	orgID := team.OrgID

	// Student 0: 3 commits. Student 1: 1 commit. Student 2: 0 commits (free rider).
	suffix := time.Now().UnixNano()
	seedCommit(t, pool, repo, orgID, teamID, students[0], fmt.Sprintf("sha-%d-a1", suffix), 10, 2)
	seedCommit(t, pool, repo, orgID, teamID, students[0], fmt.Sprintf("sha-%d-a2", suffix), 5, 1)
	seedCommit(t, pool, repo, orgID, teamID, students[0], fmt.Sprintf("sha-%d-a3", suffix), 20, 0)
	seedCommit(t, pool, repo, orgID, teamID, students[1], fmt.Sprintf("sha-%d-b1", suffix), 3, 3)

	rows, err := repo.GetTeamContributions(ctx, teamID)
	if err != nil {
		t.Fatalf("get team contributions: %v", err)
	}
	if len(rows) != 3 {
		t.Fatalf("expected 3 contribution rows (one per team member), got %d", len(rows))
	}

	byUser := make(map[string]ContributionRow, len(rows))
	for _, row := range rows {
		byUser[row.UserID] = row
	}

	student0 := byUser[students[0]]
	if student0.CommitCount != 3 {
		t.Fatalf("expected student 0 to have 3 commits, got %d", student0.CommitCount)
	}
	if student0.Additions != 35 || student0.Deletions != 3 {
		t.Fatalf("expected student 0 to have 35 additions/3 deletions, got %d/%d", student0.Additions, student0.Deletions)
	}
	if student0.IsFreeRider {
		t.Fatal("expected student 0 (3 commits) to not be flagged as a free rider")
	}

	student1 := byUser[students[1]]
	if student1.CommitCount != 1 {
		t.Fatalf("expected student 1 to have 1 commit, got %d", student1.CommitCount)
	}
	if student1.IsFreeRider {
		t.Fatal("expected student 1 (1 commit) to not be flagged as a free rider")
	}

	student2 := byUser[students[2]]
	if student2.CommitCount != 0 {
		t.Fatalf("expected student 2 to have 0 commits, got %d", student2.CommitCount)
	}
	if !student2.IsFreeRider {
		t.Fatal("expected student 2 (0 commits) to be flagged as a free rider")
	}
}

// TestGetAssignmentLeaderboard_RanksByCommitCount proves the assignment-wide
// leaderboard query (widened from GetTeamContributions to every team under
// an assignment) ranks students by descending commit count and includes a
// zero-commit member at the bottom rather than omitting them.
func TestGetAssignmentLeaderboard_RanksByCommitCount(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	teamID, students := seedDashboardTestTeam(t, pool, repo)
	team, err := repo.GetTeamByID(ctx, teamID)
	if err != nil {
		t.Fatalf("get team: %v", err)
	}

	suffix := time.Now().UnixNano()
	seedCommit(t, pool, repo, team.OrgID, teamID, students[1], fmt.Sprintf("sha-%d-lb1", suffix), 1, 1)
	seedCommit(t, pool, repo, team.OrgID, teamID, students[0], fmt.Sprintf("sha-%d-lb2", suffix), 1, 1)
	seedCommit(t, pool, repo, team.OrgID, teamID, students[0], fmt.Sprintf("sha-%d-lb3", suffix), 1, 1)

	leaderboard, err := repo.GetAssignmentLeaderboard(ctx, team.AssignmentID)
	if err != nil {
		t.Fatalf("get assignment leaderboard: %v", err)
	}
	if len(leaderboard) != 3 {
		t.Fatalf("expected 3 leaderboard rows, got %d", len(leaderboard))
	}
	if leaderboard[0].UserID != students[0] || leaderboard[0].CommitCount != 2 || leaderboard[0].Rank != 1 {
		t.Fatalf("expected student 0 to rank first with 2 commits, got %+v", leaderboard[0])
	}
	if leaderboard[len(leaderboard)-1].CommitCount != 0 {
		t.Fatalf("expected the zero-commit student to appear last with 0 commits, got %+v", leaderboard[len(leaderboard)-1])
	}
}

// TestGetTeamMembersByAssignment_GroupsByTeam proves the batched
// (one-query-for-the-whole-assignment) member lookup returns the same
// roster ListTeamMembers would for the team, keyed under the right team_id —
// the query the assignment detail page's dashboard now uses instead of a
// per-team ListTeamMembers/getProjectTeamMembers round trip.
func TestGetTeamMembersByAssignment_GroupsByTeam(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	teamID, students := seedDashboardTestTeam(t, pool, repo)
	team, err := repo.GetTeamByID(ctx, teamID)
	if err != nil {
		t.Fatalf("get team: %v", err)
	}

	byTeam, err := repo.GetTeamMembersByAssignment(ctx, team.AssignmentID)
	if err != nil {
		t.Fatalf("get team members by assignment: %v", err)
	}
	members := byTeam[teamID]
	if len(members) != 3 {
		t.Fatalf("expected 3 members for the seeded team, got %d", len(members))
	}
	seen := map[string]bool{}
	for _, m := range members {
		if m.TeamID != teamID {
			t.Fatalf("expected every row to be keyed under the seeded team, got team_id %q", m.TeamID)
		}
		seen[m.UserID] = true
	}
	for _, s := range students {
		if !seen[s] {
			t.Fatalf("expected student %q in the assignment-wide member map, got %+v", s, members)
		}
	}
}

// TestGetTeamActivityByAssignment_ReturnsCommitsAndLatestPipeline proves the
// batched LATERAL json_agg activity query returns the same per-team shape
// GetTeamActivity does — recent commits newest-first and the latest
// pipeline — for the whole assignment in one query, and that a team with no
// pipeline yet gets a nil Pipeline (not a zero-valued struct).
func TestGetTeamActivityByAssignment_ReturnsCommitsAndLatestPipeline(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	teamID, students := seedDashboardTestTeam(t, pool, repo)
	team, err := repo.GetTeamByID(ctx, teamID)
	if err != nil {
		t.Fatalf("get team: %v", err)
	}

	suffix := time.Now().UnixNano()
	seedCommit(t, pool, repo, team.OrgID, teamID, students[0], fmt.Sprintf("sha-%d-act1", suffix), 4, 1)
	seedCommit(t, pool, repo, team.OrgID, teamID, students[1], fmt.Sprintf("sha-%d-act2", suffix), 2, 0)

	if err := repo.UpsertPipeline(ctx, GitlabPipeline{
		OrgID: team.OrgID, TeamID: teamID, PipelineID: suffix, Status: CIStatusSuccess,
	}); err != nil {
		t.Fatalf("upsert pipeline: %v", err)
	}

	byTeam, err := repo.GetTeamActivityByAssignment(ctx, team.AssignmentID)
	if err != nil {
		t.Fatalf("get team activity by assignment: %v", err)
	}
	activity, ok := byTeam[teamID]
	if !ok {
		t.Fatalf("expected an activity entry for the seeded team, got %+v", byTeam)
	}
	if len(activity.Commits) != 2 {
		t.Fatalf("expected 2 commits, got %d: %+v", len(activity.Commits), activity.Commits)
	}
	if activity.Pipeline == nil {
		t.Fatal("expected a non-nil latest pipeline after UpsertPipeline")
	}
	if activity.Pipeline.Status != CIStatusSuccess {
		t.Fatalf("expected latest pipeline status %q, got %q", CIStatusSuccess, activity.Pipeline.Status)
	}
}
