package workspace

import (
	"context"
	"errors"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/ratelimit"
	"github.com/mindforge/backend/internal/testdomain"
)

func TestApplyDuplicateWithdraw(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(pool.Close)

	sfx := time.Now().UnixNano()
	var orgID, ownerID, applicantID, projectID string
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ($1,$2) RETURNING id`,
		fmt.Sprintf("Apply Org %d", sfx), fmt.Sprintf("apply-org-%d", sfx)).Scan(&orgID); err != nil {
		t.Fatalf("org: %v", err)
	}
	t.Cleanup(func() { pool.Exec(ctx, `DELETE FROM organizations WHERE id = $1`, orgID) }) //nolint:errcheck
	for i, dst := range []*string{&ownerID, &applicantID} {
		if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ($1,$2) RETURNING id`,
			fmt.Sprintf("apply-%d-%d@%s", sfx, i, testdomain.Domain), fmt.Sprintf("Applicant %d", i)).Scan(dst); err != nil {
			t.Fatalf("user: %v", err)
		}
		uid := *dst
		t.Cleanup(func() { pool.Exec(ctx, `DELETE FROM users WHERE id = $1`, uid) }) //nolint:errcheck
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO workspace_projects (org_id, title, requirement, team_size_min, team_size_max, key_prefix, project_status, share_token, created_by)
		 VALUES ($1,'Apply Test Project',repeat('r',60),2,5,'APT','recruiting',$2,$3) RETURNING id`,
		orgID, fmt.Sprintf("apply-token-%d-aaaaaaaaaaaa", sfx), ownerID).Scan(&projectID); err != nil {
		t.Fatalf("project: %v", err)
	}

	cfg := &config.Config{}
	cfg.Workspace.InterestPerEmailDay = 100
	// Unreachable Redis makes the limiter use its in-process fallback.
	svc := &Service{repo: NewRepo(pool), pool: pool, cfg: cfg,
		limiter: ratelimit.New(redis.NewClient(&redis.Options{Addr: "127.0.0.1:1"}))}

	page, err := svc.ListDiscoverable(ctx, orgID, applicantID, "", 10)
	if err != nil || len(page.Items) != 1 || page.Items[0].ID != projectID {
		t.Fatalf("discover = %+v, %v", page, err)
	}
	if err := svc.ApplyInterest(ctx, orgID, applicantID, projectID, SubmitInterestRequest{Message: "hi"}); err != nil {
		t.Fatalf("apply: %v", err)
	}
	if err := svc.ApplyInterest(ctx, orgID, applicantID, projectID, SubmitInterestRequest{}); !errors.Is(err, ErrConflict) {
		t.Fatalf("duplicate apply err = %v, want ErrConflict", err)
	}
	mine, err := svc.ListMyInterests(ctx, orgID, applicantID)
	if err != nil || len(mine) != 1 || mine[0].WorkspaceID != projectID || mine[0].Status != InterestNew {
		t.Fatalf("my interests = %+v, %v", mine, err)
	}
	if err := svc.WithdrawInterest(ctx, orgID, applicantID, projectID); err != nil {
		t.Fatalf("withdraw: %v", err)
	}
	if err := svc.WithdrawInterest(ctx, orgID, applicantID, projectID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("second withdraw err = %v, want ErrNotFound", err)
	}
}
