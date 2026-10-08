package notifications_test

import (
	"context"
	"errors"
	"testing"

	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// Notifications are read and written by (user_id, id); org_id is a stored
// attribute, not a read filter. A user in tenant B must not see, count, or
// mark-read tenant A's notification.
func TestNotifications_OtherTenantUserCannotReadOrModify(t *testing.T) {
	pool := testdb.New(t)
	repo := notifications.NewRepo(pool)
	ctx := context.Background()

	var orgA, orgB, userA, userB string
	for _, s := range []struct {
		slug string
		dst  *string
	}{{"notif-a", &orgA}, {"notif-b", &orgB}} {
		if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ($1, $1) RETURNING id`, s.slug).Scan(s.dst); err != nil {
			t.Fatalf("seed org %s: %v", s.slug, err)
		}
	}
	for _, s := range []struct {
		email string
		org   string
		dst   *string
	}{{"na@" + testdomain.Domain, orgA, &userA}, {"nb@" + testdomain.Domain, orgB, &userB}} {
		if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ($1, 'n') RETURNING id`, s.email).Scan(s.dst); err != nil {
			t.Fatalf("seed user: %v", err)
		}
		if _, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id) VALUES ($1, $2)`, s.org, *s.dst); err != nil {
			t.Fatalf("seed member: %v", err)
		}
	}

	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	inserted, err := repo.Insert(ctx, tx, notifications.New{OrgID: orgA, UserID: userA, Type: "test", Title: "A only", Priority: "normal", DedupeKey: "k1"})
	if err != nil || !inserted {
		t.Fatalf("insert: inserted=%v err=%v", inserted, err)
	}
	if err := tx.Commit(ctx); err != nil {
		t.Fatalf("commit: %v", err)
	}
	var id string
	if err := pool.QueryRow(ctx, `SELECT id FROM notifications WHERE user_id = $1`, userA).Scan(&id); err != nil {
		t.Fatalf("load id: %v", err)
	}

	if got, err := repo.List(ctx, userB, 50); err != nil || len(got) != 0 {
		t.Fatalf("List as B = %d rows err=%v, want 0", len(got), err)
	}
	if n, err := repo.UnreadCount(ctx, userB); err != nil || n != 0 {
		t.Fatalf("UnreadCount as B = %d err=%v, want 0", n, err)
	}
	if err := repo.MarkRead(ctx, userB, id); !errors.Is(err, notifications.ErrNotFound) {
		t.Fatalf("MarkRead as B: err=%v, want ErrNotFound", err)
	}
	if err := repo.MarkAllRead(ctx, userB); err != nil {
		t.Fatalf("MarkAllRead as B: %v", err)
	}

	if n, err := repo.UnreadCount(ctx, userA); err != nil || n != 1 {
		t.Fatalf("A's unread after B's attempts = %d err=%v, want 1 (untouched)", n, err)
	}
}
