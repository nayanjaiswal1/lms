package rewards

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

// testPool connects to TEST_DATABASE_URL; skips (rather than fails) when
// unset, matching the convention in internal/jobs/e2e_test.go and
// internal/assessment/import_excel_test.go.
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

// testRedis connects to TEST_REDIS_URL (falling back to the local dev
// instance) — GetUserRank always calls into rdb first, so a real client is
// needed even for the pure-DB-fallback assertions here.
func testRedis(t *testing.T) *redis.Client {
	t.Helper()
	url := os.Getenv("TEST_REDIS_URL")
	if url == "" {
		url = "redis://localhost:6379/0"
	}
	opts, err := redis.ParseURL(url)
	if err != nil {
		t.Fatalf("parse redis url: %v", err)
	}
	rdb := redis.NewClient(opts)
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis not reachable at %s: %v", url, err)
	}
	t.Cleanup(func() { rdb.Close() })
	return rdb
}

// cohortLBFixture seeds a 3-node hierarchy (Class 10 -> Section A / Section B)
// with one batch under each section, one user per batch, and xp_events tagged
// to the right batch_id — the shape a group-scoped leaderboard rolls up.
type cohortLBFixture struct {
	classID, sectionAID, sectionBID string
	batchAID, batchBID              string
	userAID, userBID                string
}

func seedCohortLBFixture(t *testing.T, pool *pgxpool.Pool) cohortLBFixture {
	t.Helper()
	ctx := context.Background()
	suffix := time.Now().UnixNano()

	var orgID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (name, slug) VALUES ($1, $2) RETURNING id`,
		fmt.Sprintf("Rewards Cohort Test Org %d", suffix), fmt.Sprintf("rc%d", suffix%1_000_000_000_000),
	).Scan(&orgID); err != nil {
		t.Fatalf("create org: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM organizations WHERE id = $1`, orgID) }) //nolint:errcheck

	seedUser := func(label string) string {
		var id string
		if err := pool.QueryRow(ctx,
			`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
			fmt.Sprintf("rewards-cohort-%s-%d@example.com", label, suffix), "Rewards Cohort Test User",
		).Scan(&id); err != nil {
			t.Fatalf("create user %s: %v", label, err)
		}
		t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, id) }) //nolint:errcheck
		return id
	}
	creator := seedUser("creator")
	userA := seedUser("a")
	userB := seedUser("b")

	seedGroup := func(name string, parentID *string) string {
		var id string
		if err := pool.QueryRow(ctx,
			`INSERT INTO cohort_groups (org_id, parent_id, name, slug, created_by)
			 VALUES ($1, $2, $3, $4, $5) RETURNING id`,
			orgID, parentID, name, fmt.Sprintf("%s-%d", name, suffix), creator,
		).Scan(&id); err != nil {
			t.Fatalf("create group %s: %v", name, err)
		}
		return id
	}
	classID := seedGroup("class-10", nil)
	sectionAID := seedGroup("section-a", &classID)
	sectionBID := seedGroup("section-b", &classID)

	seedBatch := func(name, groupID string) string {
		var id string
		if err := pool.QueryRow(ctx,
			`INSERT INTO batches (org_id, name, slug, created_by, cohort_group_id)
			 VALUES ($1, $2, $3, $4, $5) RETURNING id`,
			orgID, name, fmt.Sprintf("%s-%d", name, suffix), creator, groupID,
		).Scan(&id); err != nil {
			t.Fatalf("create batch %s: %v", name, err)
		}
		return id
	}
	batchAID := seedBatch("batch-a", sectionAID)
	batchBID := seedBatch("batch-b", sectionBID)

	if _, err := pool.Exec(ctx, `INSERT INTO batch_members (batch_id, user_id) VALUES ($1, $2)`, batchAID, userA); err != nil {
		t.Fatalf("add batch member a: %v", err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO batch_members (batch_id, user_id) VALUES ($1, $2)`, batchBID, userB); err != nil {
		t.Fatalf("add batch member b: %v", err)
	}

	seedXP := func(userID, batchID string, amount int) {
		if _, err := pool.Exec(ctx,
			`INSERT INTO xp_events (user_id, batch_id, xp_amount, reason) VALUES ($1, $2, $3, 'test')`,
			userID, batchID, amount); err != nil {
			t.Fatalf("seed xp: %v", err)
		}
	}
	seedXP(userA, batchAID, 100)
	seedXP(userA, batchAID, 50) // two events -> 150 total for userA in batchA
	seedXP(userB, batchBID, 200)

	return cohortLBFixture{
		classID: classID, sectionAID: sectionAID, sectionBID: sectionBID,
		batchAID: batchAID, batchBID: batchBID,
		userAID: userA, userBID: userB,
	}
}

// TestGroupLeaderboard_RollsUpDescendantBatches verifies the "group" scope in
// leaderboardFromDB sums XP across every batch in a cohort_groups subtree:
// the Class-level board must include both sections' batches, while each
// Section-level board sees only its own batch.
func TestGroupLeaderboard_RollsUpDescendantBatches(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool, testRedis(t))
	fx := seedCohortLBFixture(t, pool)
	ctx := context.Background()

	classEntries, err := repo.leaderboardFromDB(ctx, "leaderboard:group:"+fx.classID, 20, 0)
	if err != nil {
		t.Fatalf("class leaderboard: %v", err)
	}
	xpByUser := map[string]int{}
	for _, e := range classEntries {
		xpByUser[e.UserID] = e.TotalXP
	}
	if xpByUser[fx.userAID] != 150 {
		t.Fatalf("expected userA=150 XP at class scope, got %d (entries=%v)", xpByUser[fx.userAID], classEntries)
	}
	if xpByUser[fx.userBID] != 200 {
		t.Fatalf("expected userB=200 XP at class scope, got %d (entries=%v)", xpByUser[fx.userBID], classEntries)
	}

	sectionAEntries, err := repo.leaderboardFromDB(ctx, "leaderboard:group:"+fx.sectionAID, 20, 0)
	if err != nil {
		t.Fatalf("section A leaderboard: %v", err)
	}
	if len(sectionAEntries) != 1 || sectionAEntries[0].UserID != fx.userAID || sectionAEntries[0].TotalXP != 150 {
		t.Fatalf("expected only userA=150 at section A scope, got %v", sectionAEntries)
	}

	// batch-scope leaderboard must be unaffected by the group rollup.
	batchAEntries, err := repo.leaderboardFromDB(ctx, "leaderboard:batch:"+fx.batchAID, 20, 0)
	if err != nil {
		t.Fatalf("batch A leaderboard: %v", err)
	}
	if len(batchAEntries) != 1 || batchAEntries[0].TotalXP != 150 {
		t.Fatalf("expected batch A leaderboard unaffected (userA=150), got %v", batchAEntries)
	}
}

// TestGroupUserRank_ComputesFromDBWhenRedisCold verifies GetUserRank falls
// back to a live Postgres computation for "group" scope, since (unlike
// batch/org/course) no XP-award path ZIncrBy's a group's Redis key.
func TestGroupUserRank_ComputesFromDBWhenRedisCold(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool, testRedis(t))
	fx := seedCohortLBFixture(t, pool)
	ctx := context.Background()

	rank, xp, err := repo.GetUserRank(ctx, "leaderboard:group:"+fx.classID, fx.userBID)
	if err != nil {
		t.Fatalf("get user rank: %v", err)
	}
	if rank != 0 {
		t.Fatalf("expected userB (200 XP) to rank 0 (0-based, highest) at class scope, got rank=%d", rank)
	}
	if xp != 200 {
		t.Fatalf("expected userB xp=200, got %v", xp)
	}

	rank, xp, err = repo.GetUserRank(ctx, "leaderboard:group:"+fx.classID, fx.userAID)
	if err != nil {
		t.Fatalf("get user rank (userA): %v", err)
	}
	if rank != 1 {
		t.Fatalf("expected userA (150 XP) to rank 1 at class scope, got rank=%d", rank)
	}
	if xp != 150 {
		t.Fatalf("expected userA xp=150, got %v", xp)
	}
}
