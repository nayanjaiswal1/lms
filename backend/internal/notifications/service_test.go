package notifications_test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/stretchr/testify/require"
)

// testPool connects to TEST_DATABASE_URL, skipping (not failing) the test
// when it's unset — matches the convention in internal/gitlab/internal/
// assessment's own test files (duplicated per-package rather than shared).
func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	require.NoError(t, err)
	t.Cleanup(func() { pool.Close() })
	return pool
}

func seedOrgAndUser(t *testing.T, pool *pgxpool.Pool) (orgID, userID string) {
	t.Helper()
	ctx := context.Background()
	suffix := fmt.Sprintf("%d", time.Now().UnixNano())

	err := pool.QueryRow(ctx,
		`INSERT INTO organizations (name, slug) VALUES ($1, $2) RETURNING id`,
		"Notifications Test Org "+suffix, "notif-test-"+suffix,
	).Scan(&orgID)
	require.NoError(t, err)
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM organizations WHERE id = $1`, orgID) }) //nolint:errcheck

	err = pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
		fmt.Sprintf("notif-test-%s@example.com", suffix), "Notifications Test User",
	).Scan(&userID)
	require.NoError(t, err)
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID) }) //nolint:errcheck

	return orgID, userID
}

// TestNotify_DedupeKeyPreventsDuplicateRow proves ON CONFLICT(user_id,
// dedupe_key) DO NOTHING makes calling Notify twice with the same dedupe_key
// (e.g. a redelivered webhook triggering the same logical notification
// twice) result in exactly one row.
func TestNotify_DedupeKeyPreventsDuplicateRow(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	orgID, userID := seedOrgAndUser(t, pool)

	registry := jobs.NewRegistry()
	svc := notifications.NewService(pool, registry)

	n := notifications.New{
		OrgID: orgID, UserID: userID, Type: "gitlab.ci_failed",
		Title: "CI failed", DedupeKey: "dedupe-test-key",
	}

	tx1, err := pool.Begin(ctx)
	require.NoError(t, err)
	require.NoError(t, svc.Notify(ctx, tx1, n))
	require.NoError(t, tx1.Commit(ctx))

	tx2, err := pool.Begin(ctx)
	require.NoError(t, err)
	require.NoError(t, svc.Notify(ctx, tx2, n))
	require.NoError(t, tx2.Commit(ctx))

	var count int
	require.NoError(t, pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND dedupe_key = $2`,
		userID, n.DedupeKey,
	).Scan(&count))
	require.Equal(t, 1, count, "expected exactly one row after calling Notify twice with the same dedupe_key")
}

// TestMarkRead_And_UnreadCount proves UnreadCount only counts unread rows and
// MarkRead flips exactly the targeted row (never another user's).
func TestMarkRead_And_UnreadCount(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	orgID, userID := seedOrgAndUser(t, pool)
	_, otherUserID := seedOrgAndUser(t, pool)

	registry := jobs.NewRegistry()
	svc := notifications.NewService(pool, registry)

	for i := 0; i < 3; i++ {
		tx, err := pool.Begin(ctx)
		require.NoError(t, err)
		require.NoError(t, svc.Notify(ctx, tx, notifications.New{
			OrgID: orgID, UserID: userID, Type: "gitlab.mr_comment",
			Title: fmt.Sprintf("Comment %d", i), DedupeKey: fmt.Sprintf("comment-%d", i),
		}))
		require.NoError(t, tx.Commit(ctx))
	}
	// A notification for a different user must never affect userID's count.
	tx, err := pool.Begin(ctx)
	require.NoError(t, err)
	require.NoError(t, svc.Notify(ctx, tx, notifications.New{
		OrgID: orgID, UserID: otherUserID, Type: "gitlab.mr_comment",
		Title: "Other user's comment", DedupeKey: "other-user-comment",
	}))
	require.NoError(t, tx.Commit(ctx))

	count, err := svc.UnreadCount(ctx, userID)
	require.NoError(t, err)
	require.Equal(t, 3, count)

	notifs, err := svc.List(ctx, userID, 10)
	require.NoError(t, err)
	require.Len(t, notifs, 3)

	require.NoError(t, svc.MarkRead(ctx, userID, notifs[0].ID))

	count, err = svc.UnreadCount(ctx, userID)
	require.NoError(t, err)
	require.Equal(t, 2, count, "marking one notification read should decrement the unread count by exactly one")

	// Re-marking the same notification read again is an idempotent no-op, not an error.
	require.NoError(t, svc.MarkRead(ctx, userID, notifs[0].ID))

	// MarkAllRead clears the rest.
	require.NoError(t, svc.MarkAllRead(ctx, userID))
	count, err = svc.UnreadCount(ctx, userID)
	require.NoError(t, err)
	require.Equal(t, 0, count)

	// otherUserID's notification must be untouched by userID's MarkAllRead.
	otherCount, err := svc.UnreadCount(ctx, otherUserID)
	require.NoError(t, err)
	require.Equal(t, 1, otherCount)
}
