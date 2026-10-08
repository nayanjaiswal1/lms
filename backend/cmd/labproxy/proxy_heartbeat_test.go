package main

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/testdomain"
	"github.com/redis/go-redis/v9"
)

// testPool/testRedis connect to TEST_DATABASE_URL/TEST_REDIS_URL, skipping
// (not failing) when unset or unreachable — same convention as
// internal/rewards/cohort_group_leaderboard_e2e_test.go.

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
	t.Cleanup(pool.Close)
	return pool
}

func testRedis(t *testing.T) *redis.Client {
	t.Helper()
	url := os.Getenv("TEST_REDIS_URL")
	if url == "" {
		t.Skip("TEST_REDIS_URL not set")
	}
	opts, err := redis.ParseURL(url)
	if err != nil {
		t.Fatalf("parse redis url: %v", err)
	}
	rdb := redis.NewClient(opts)
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis not reachable at %s: %v", url, err)
	}
	t.Cleanup(func() { _ = rdb.Close() })
	return rdb
}

// TestHeartbeatPreview_Debounced is the behavior item 3 of Phase 0 exists
// for: repeated preview traffic for the same session must write
// last_active_at at most once per previewHeartbeatDebounce window, matching
// the terminal relay's own 5s cadence (ServeHTTP) — never once per request.
func TestHeartbeatPreview_Debounced(t *testing.T) {
	pool := testPool(t)
	rdb := testRedis(t)
	ctx := context.Background()

	suffix := time.Now().UnixNano()
	var orgID, userID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ($1, 'Heartbeat Test Org') RETURNING id`,
		fmt.Sprintf("heartbeat-test-org-%d", suffix),
	).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ($1, 'Heartbeat Test') RETURNING id`,
		fmt.Sprintf("heartbeat-test-%d@%s", suffix, testdomain.Domain),
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	var labID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO lab_definitions (org_id, title, lab_type, environment, created_by, scope)
		 VALUES ($1, 'Heartbeat Test Lab', 'terminal', 'mindforge/lab-python-web:1', $2, 'standalone') RETURNING id`,
		orgID, userID,
	).Scan(&labID); err != nil {
		t.Fatalf("seed lab: %v", err)
	}
	var versionID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO lab_task_versions (lab_id, version, tasks, published_by) VALUES ($1, 1, '[]', $2) RETURNING id`,
		labID, userID,
	).Scan(&versionID); err != nil {
		t.Fatalf("seed task version: %v", err)
	}
	var sessionID string
	// Postgres timestamptz keeps microseconds; truncate so Equal compares the
	// value that round-trips through the DB.
	pastActive := time.Now().Add(-1 * time.Hour).Truncate(time.Microsecond)
	if err := pool.QueryRow(ctx,
		`INSERT INTO lab_sessions (lab_id, task_version_id, user_id, org_id, status, expires_at, last_active_at)
		 VALUES ($1, $2, $3, $4, 'running', now() + interval '1 hour', $5) RETURNING id`,
		labID, versionID, userID, orgID, pastActive,
	).Scan(&sessionID); err != nil {
		t.Fatalf("seed session: %v", err)
	}

	h := &ProxyHandler{pool: pool, rdb: rdb}

	h.heartbeatPreview(ctx, sessionID)

	var firstActive time.Time
	if err := pool.QueryRow(ctx, `SELECT last_active_at FROM lab_sessions WHERE id=$1`, sessionID).Scan(&firstActive); err != nil {
		t.Fatalf("read last_active_at: %v", err)
	}
	if !firstActive.After(pastActive) {
		t.Fatalf("first heartbeatPreview call did not update last_active_at: got %v, seeded %v", firstActive, pastActive)
	}

	// Force the DB row backwards so a second write (if not debounced) would
	// be observable, then call again immediately — within the debounce
	// window the Redis key from the first call must still be set, so this
	// call must be a no-op.
	if _, err := pool.Exec(ctx, `UPDATE lab_sessions SET last_active_at=$1 WHERE id=$2`, pastActive, sessionID); err != nil {
		t.Fatalf("rewind last_active_at: %v", err)
	}
	h.heartbeatPreview(ctx, sessionID)

	var secondActive time.Time
	if err := pool.QueryRow(ctx, `SELECT last_active_at FROM lab_sessions WHERE id=$1`, sessionID).Scan(&secondActive); err != nil {
		t.Fatalf("read last_active_at (2nd): %v", err)
	}
	if !secondActive.Equal(pastActive) {
		t.Fatalf("second heartbeatPreview call within the debounce window wrote again: got %v, want unchanged %v", secondActive, pastActive)
	}
}
