package workspace

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"
	"unicode/utf8"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func seedCohortUser(t *testing.T, s *Service, label string) string {
	t.Helper()
	var id string
	err := s.pool.QueryRow(context.Background(),
		`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
		fmt.Sprintf("cohort-%s-%d@%s", label, time.Now().UnixNano(), testdomain.Domain), "Cohort "+label,
	).Scan(&id)
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	return id
}

type cohortFixture struct {
	s                       *Service
	orgID, cohortID         string
	owner, m1, m2, outsider string
}

// newCohortFixture seeds an org with owner/m1/m2 as active members, one
// outsider user who is not in the org, and a cohort with the given description.
func newCohortFixture(t *testing.T, description *string) cohortFixture {
	t.Helper()
	pool := testdb.New(t)
	ctx := context.Background()
	s := &Service{repo: NewRepo(pool), pool: pool, gitlab: gitlab.NewService(pool, nil, nil, nil, nil, nil)}
	f := cohortFixture{s: s}
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ('Cohort Org', $1) RETURNING id`,
		fmt.Sprintf("cohort-org-%d", time.Now().UnixNano())).Scan(&f.orgID); err != nil {
		t.Fatalf("create org: %v", err)
	}
	f.owner, f.m1, f.m2, f.outsider = seedCohortUser(t, s, "owner"), seedCohortUser(t, s, "m1"), seedCohortUser(t, s, "m2"), seedCohortUser(t, s, "out")
	for _, u := range []string{f.owner, f.m1, f.m2} {
		if _, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id, role) VALUES ($1, $2, 'learner')`, f.orgID, u); err != nil {
			t.Fatalf("add org member: %v", err)
		}
	}
	var batchID string
	if err := pool.QueryRow(ctx, `INSERT INTO batches (org_id, name, slug, created_by) VALUES ($1,'B',$2,$3) RETURNING id`,
		f.orgID, fmt.Sprintf("cohort-batch-%d", time.Now().UnixNano()), f.owner).Scan(&batchID); err != nil {
		t.Fatalf("create batch: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO project_assignments (org_id, batch_id, title, slug, description, visibility, required_approvals, protect_default_branch, default_branch, created_by)
		 VALUES ($1,$2,'Cohort A','cohort-a',$4,'private',1,true,'main',$3) RETURNING id`,
		f.orgID, batchID, f.owner, description).Scan(&f.cohortID); err != nil {
		t.Fatalf("create cohort: %v", err)
	}
	return f
}

// CreateCohortWorkspace must link the workspace to both the cohort and its
// new gitlab team, and roster the members on both sides.
func TestCreateCohortWorkspace_LinksTeamAndCohortAndRostersMembers(t *testing.T) {
	f := newCohortFixture(t, nil)
	s, pool, ctx := f.s, f.s.pool, context.Background()
	orgID, owner, m1, m2, cohortID := f.orgID, f.owner, f.m1, f.m2, f.cohortID

	p, err := s.CreateCohortWorkspace(ctx, orgID, owner, cohortID, CreateCohortWorkspaceRequest{
		Title: "Team Alpha", MemberUserIDs: []string{m1, m2, m1},
	})
	if err != nil {
		t.Fatalf("CreateCohortWorkspace: %v", err)
	}
	if p.CohortID == nil || *p.CohortID != cohortID {
		t.Fatalf("cohort_id = %v, want %s", p.CohortID, cohortID)
	}
	if p.TeamID == nil {
		t.Fatal("team_id not set")
	}
	if len(p.Requirement) < RequirementMinLen {
		t.Fatalf("requirement too short: %d", len(p.Requirement))
	}
	var wsMembers, teamMembers int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM project_members WHERE project_id=$1 AND status='active'`, p.ID).Scan(&wsMembers); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM project_team_members WHERE team_id=$1`, *p.TeamID).Scan(&teamMembers); err != nil {
		t.Fatal(err)
	}
	if wsMembers != 3 || teamMembers != 2 {
		t.Fatalf("workspace members=%d (want 3), team members=%d (want 2)", wsMembers, teamMembers)
	}
}

func TestCreateCohortWorkspace_RejectsForeignOrgAndMalformedMembers(t *testing.T) {
	f := newCohortFixture(t, nil)
	ctx := context.Background()
	_, err := f.s.CreateCohortWorkspace(ctx, f.orgID, f.owner, f.cohortID, CreateCohortWorkspaceRequest{
		Title: "Team Beta", MemberUserIDs: []string{f.outsider}})
	if !errors.Is(err, ErrNotOrgMember) {
		t.Fatalf("outsider: err = %v, want ErrNotOrgMember", err)
	}
	var fe *FieldError
	_, err = f.s.CreateCohortWorkspace(ctx, f.orgID, f.owner, f.cohortID, CreateCohortWorkspaceRequest{
		Title: "Team Beta", MemberUserIDs: []string{"not-a-uuid"}})
	if !errors.As(err, &fe) {
		t.Fatalf("malformed id: err = %v, want FieldError", err)
	}
	var teams int
	if err := f.s.pool.QueryRow(ctx, `SELECT count(*) FROM project_teams WHERE assignment_id=$1`, f.cohortID).Scan(&teams); err != nil || teams != 0 {
		t.Fatalf("teams after rejected creates = %d (err %v), want 0", teams, err)
	}
}

func TestCreateCohortWorkspace_MemberOnAnotherTeamIs409Conflict(t *testing.T) {
	f := newCohortFixture(t, nil)
	ctx := context.Background()
	if _, err := f.s.CreateCohortWorkspace(ctx, f.orgID, f.owner, f.cohortID, CreateCohortWorkspaceRequest{
		Title: "Team One", MemberUserIDs: []string{f.m1}}); err != nil {
		t.Fatalf("first team: %v", err)
	}
	_, err := f.s.CreateCohortWorkspace(ctx, f.orgID, f.m2, f.cohortID, CreateCohortWorkspaceRequest{
		Title: "Team Two", MemberUserIDs: []string{f.m1}})
	if !errors.Is(err, ErrConflict) {
		t.Fatalf("duplicate team member: err = %v, want ErrConflict", err)
	}
	var projects int
	if err := f.s.pool.QueryRow(ctx, `SELECT count(*) FROM workspace_projects WHERE cohort_id=$1`, f.cohortID).Scan(&projects); err != nil || projects != 1 {
		t.Fatalf("workspaces = %d (err %v), want 1 (second create fully rolled back)", projects, err)
	}
}

func TestCreateCohortWorkspace_LongNonASCIIDescription(t *testing.T) {
	long := strings.Repeat("é", RequirementMaxLen)
	f := newCohortFixture(t, &long)
	p, err := f.s.CreateCohortWorkspace(context.Background(), f.orgID, f.owner, f.cohortID, CreateCohortWorkspaceRequest{Title: "Team Gamma"})
	if err != nil {
		t.Fatalf("CreateCohortWorkspace: %v", err)
	}
	if len(p.Requirement) > RequirementMaxLen || !utf8.ValidString(p.Requirement) {
		t.Fatalf("requirement len=%d valid=%v", len(p.Requirement), utf8.ValidString(p.Requirement))
	}
}

func TestDeleteDraftCohort_BlockedByWorkspace(t *testing.T) {
	f := newCohortFixture(t, nil)
	ctx := context.Background()
	if _, err := f.s.CreateCohortWorkspace(ctx, f.orgID, f.owner, f.cohortID, CreateCohortWorkspaceRequest{Title: "Team Delta"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	if err := f.s.gitlab.DeleteAssignment(ctx, f.orgID, f.cohortID); !errors.Is(err, gitlab.ErrConflict) {
		t.Fatalf("delete err = %v, want gitlab.ErrConflict", err)
	}
}
