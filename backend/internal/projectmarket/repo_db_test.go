package projectmarket

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// seedOrgAndUsers creates one organization and n users — the minimum every
// projectmarket repo method needs (project_requirements.org_id/created_by,
// project_applications.org_id/user_id all carry NOT NULL FKs).
func seedOrgAndUsers(t *testing.T, ctx context.Context, pool *pgxpool.Pool, n int) (orgID string, userIDs []string) {
	t.Helper()

	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('pm-test-org', 'PM Test Org') RETURNING id`,
	).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	suffix := time.Now().UnixNano()
	for i := 0; i < n; i++ {
		var userID string
		if err := pool.QueryRow(ctx,
			`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
			fmt.Sprintf("pm-test-%d-%d@example.com", suffix, i), fmt.Sprintf("Test User %d", i),
		).Scan(&userID); err != nil {
			t.Fatalf("seed user %d: %v", i, err)
		}
		userIDs = append(userIDs, userID)
	}
	return orgID, userIDs
}

// TestCreateRequirementAndBoardFlow exercises the full staff-post ->
// publish -> student-apply -> board-listing path against a real database —
// ListBoard's LEFT JOIN + GROUP BY + MAX(CASE...) aggregation for
// application_count/my_status can't be checked with pure-Go tests.
func TestCreateRequirementAndBoardFlow(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	orgID, users := seedOrgAndUsers(t, ctx, pool, 2)
	staffID, studentID := users[0], users[1]

	req, err := repo.CreateRequirement(ctx, ProjectRequirement{
		OrgID: orgID, Title: "Realtime Whiteboard", Brief: "Build a collaborative canvas.",
		RequiredSkills: []string{"React", "WebSockets"}, TeamSizeMin: 2, TeamSizeMax: 4,
		ApplicationDeadline: time.Now().Add(48 * time.Hour), Status: RequirementStatusDraft, CreatedBy: staffID,
	})
	if err != nil {
		t.Fatalf("create requirement: %v", err)
	}

	// A draft requirement must not appear on the open board yet.
	board, err := repo.ListBoard(ctx, orgID, studentID)
	if err != nil {
		t.Fatalf("list board (draft): %v", err)
	}
	if len(board) != 0 {
		t.Fatalf("expected 0 board rows while draft, got %d", len(board))
	}

	published, err := repo.SetRequirementStatus(ctx, orgID, req.ID, RequirementStatusDraft, RequirementStatusOpen)
	if err != nil {
		t.Fatalf("publish requirement: %v", err)
	}
	if published.Status != RequirementStatusOpen {
		t.Fatalf("expected status open, got %s", published.Status)
	}

	// Wrong fromStatus must be rejected, not silently succeed.
	if _, err := repo.SetRequirementStatus(ctx, orgID, req.ID, RequirementStatusDraft, RequirementStatusOpen); err == nil {
		t.Fatal("expected error re-publishing an already-open requirement from 'draft'")
	}

	board, err = repo.ListBoard(ctx, orgID, studentID)
	if err != nil {
		t.Fatalf("list board (open): %v", err)
	}
	if len(board) != 1 {
		t.Fatalf("expected 1 board row once open, got %d", len(board))
	}
	if board[0].ApplicationCount != 0 {
		t.Errorf("expected application_count=0 before any application, got %d", board[0].ApplicationCount)
	}
	if board[0].MyStatus != nil {
		t.Errorf("expected my_status=nil before applying, got %v", *board[0].MyStatus)
	}

	motivation := "I love real-time systems."
	app, err := repo.CreateApplication(ctx, ProjectApplication{
		OrgID: orgID, RequirementID: req.ID, UserID: studentID, Motivation: &motivation, Status: ApplicationStatusSubmitted,
	})
	if err != nil {
		t.Fatalf("create application: %v", err)
	}

	// A duplicate application from the same student must fail with ErrAlreadyApplied.
	if _, err := repo.CreateApplication(ctx, ProjectApplication{
		OrgID: orgID, RequirementID: req.ID, UserID: studentID, Status: ApplicationStatusSubmitted,
	}); err == nil {
		t.Fatal("expected ErrAlreadyApplied on duplicate application")
	} else if err != ErrAlreadyApplied {
		t.Fatalf("expected ErrAlreadyApplied, got %v", err)
	}

	board, err = repo.ListBoard(ctx, orgID, studentID)
	if err != nil {
		t.Fatalf("list board (after apply): %v", err)
	}
	if board[0].ApplicationCount != 1 {
		t.Errorf("expected application_count=1 after applying, got %d", board[0].ApplicationCount)
	}
	if board[0].MyStatus == nil || *board[0].MyStatus != ApplicationStatusSubmitted {
		t.Errorf("expected my_status=submitted, got %v", board[0].MyStatus)
	}

	// Staff review list must join the applicant's name/email.
	staffView, err := repo.ListApplicationsForStaff(ctx, orgID, req.ID)
	if err != nil {
		t.Fatalf("list applications for staff: %v", err)
	}
	if len(staffView) != 1 || staffView[0].ID != app.ID {
		t.Fatalf("expected exactly the one seeded application, got %+v", staffView)
	}
	if staffView[0].Name == "" || staffView[0].Email == "" {
		t.Errorf("expected joined name/email on staff view, got name=%q email=%q", staffView[0].Name, staffView[0].Email)
	}

	// WithdrawApplication must be scoped to the caller — a foreign user_id must not withdraw it.
	if err := repo.WithdrawApplication(ctx, orgID, app.ID, staffID); err == nil {
		t.Fatal("expected error withdrawing another user's application")
	}
	if err := repo.WithdrawApplication(ctx, orgID, app.ID, studentID); err != nil {
		t.Fatalf("withdraw own application: %v", err)
	}
	board, err = repo.ListBoard(ctx, orgID, studentID)
	if err != nil {
		t.Fatalf("list board (after withdraw): %v", err)
	}
	if board[0].ApplicationCount != 0 {
		t.Errorf("expected application_count=0 after withdrawal, got %d", board[0].ApplicationCount)
	}
}

// TestListApplicationsForStaff_OrdersByAIScoreDescNullsLast verifies the
// ranking ListApplicationsForStaff exists to produce: highest AI score
// first, unscored applications last — the whole point of running AI scoring
// before staff review.
func TestListApplicationsForStaff_OrdersByAIScoreDescNullsLast(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	orgID, users := seedOrgAndUsers(t, ctx, pool, 4)
	staffID := users[0]

	req, err := repo.CreateRequirement(ctx, ProjectRequirement{
		OrgID: orgID, Title: "Ranking Test", Brief: "Brief.", TeamSizeMin: 1, TeamSizeMax: 1,
		ApplicationDeadline: time.Now().Add(48 * time.Hour), Status: RequirementStatusOpen, CreatedBy: staffID,
	})
	if err != nil {
		t.Fatalf("create requirement: %v", err)
	}

	var appLow, appHigh, appUnscored *ProjectApplication
	for i, userID := range users[1:] {
		app, err := repo.CreateApplication(ctx, ProjectApplication{OrgID: orgID, RequirementID: req.ID, UserID: userID, Status: ApplicationStatusSubmitted})
		if err != nil {
			t.Fatalf("create application %d: %v", i, err)
		}
		switch i {
		case 0:
			appLow = app
		case 1:
			appHigh = app
		case 2:
			appUnscored = app
		}
	}

	if err := repo.SetApplicationScore(ctx, appLow.ID, 40, "Some relevant experience."); err != nil {
		t.Fatalf("set score low: %v", err)
	}
	if err := repo.SetApplicationScore(ctx, appHigh.ID, 90, "Strong fit."); err != nil {
		t.Fatalf("set score high: %v", err)
	}
	// appUnscored deliberately left with ai_score = NULL.

	ranked, err := repo.ListApplicationsForStaff(ctx, orgID, req.ID)
	if err != nil {
		t.Fatalf("list applications for staff: %v", err)
	}
	if len(ranked) != 3 {
		t.Fatalf("expected 3 applications, got %d", len(ranked))
	}
	if ranked[0].ID != appHigh.ID {
		t.Errorf("expected highest score first, got %s (score=%v)", ranked[0].ID, ranked[0].AIScore)
	}
	if ranked[1].ID != appLow.ID {
		t.Errorf("expected second-highest score second, got %s (score=%v)", ranked[1].ID, ranked[1].AIScore)
	}
	if ranked[2].ID != appUnscored.ID || ranked[2].AIScore != nil {
		t.Errorf("expected unscored application last with nil score, got %s (score=%v)", ranked[2].ID, ranked[2].AIScore)
	}

	unscored, err := repo.ListUnscoredApplications(ctx, orgID, req.ID)
	if err != nil {
		t.Fatalf("list unscored applications: %v", err)
	}
	if len(unscored) != 1 || unscored[0].ID != appUnscored.ID {
		t.Fatalf("expected only appUnscored in the unscored list, got %+v", unscored)
	}
}
